extends Control
## 纸飞机模拟器 + 肉鸽（demo-08）
## 三阶段循环：折纸（鼠标点两下折线，规则对玩家透明）→ 投掷（角度+蓄力）→ 飞行（自写积分）。
## 关间肉鸽商店：过关得金币（距离/10 + 过关奖励），抽 3 个强化买入，属性带入下一关。
## 60 像素 = 1 米；飞到终点旗或落地即结算；纯代码绘制（draw_* 画纸/飞机/场景），无外部素材。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")

## ---- 物理常量：力都归一成加速度（速度平方律）----
## 满力初速 17 米/秒、重力 6.3 米/秒^2（比真实偏小，纸飞机要飘）；
## 升力上限 1.8 倍重力：防止高速死 loop，同时保留大弧度爬升手感。
const PX_PER_M := 60.0
const GRAV := 380.0             # px/s^2
const LIFT_K := 0.00095         # 升力加速度 = LIFT_K * 升力面积 * speed^2 * cos(攻角)
const LIFT_CAP := 1.8           # 升力上限 = LIFT_CAP * GRAV
const DRAG_K := 0.00009         # 阻力加速度 = DRAG_K * (基础阻力 + drag_f) * speed^2
const BASE_DRAG := 0.35
const LAUNCH_V := 1150.0        # 满力初速 px/s（力气强化每级 x1.2）
const PITCH_FOLLOW := 3.0       # 机头追随速度方向的速率（1/s）
const TRIM_PITCH_RATE := 0.9    # 配平=1 时的抬头/低头角速度 rad/s（配平仪减半）
const PROP_THRUST := 120.0      # 螺旋桨恒推力 px/s^2（沿机头方向）
const TAIL_THRUST := 90.0       # 顺风恒定推力 px/s^2（沿 +x）
const HEAD_DRAG_MULT := 1.25    # 逆风阻力倍率
const MAX_FLIGHT_TIME := 14.0   # 兜底：超时也结算
const LIFT_PER_FOLD := 0.45      # 每条折线升力贡献 = LIFT_PER_FOLD * (0.4 + 0.6 * 外侧度)
const TRIM_PER_FOLD := 0.35     # 每条折线配平贡献 = TRIM_PER_FOLD * 上下度(-1..1)
const DRAG_PER_FOLD := 0.18     # 每条折线阻力贡献 = DRAG_PER_FOLD * 长度比(0..1)
const CHARGE_TIME := 1.2        # 蓄力 0→1 所需秒数
const GROUND_Y := 460.0
const START_X := 60.0
const SAMPLE_STEP := 0.2        # 每 0.2s 采样一次飞行距离

## ---- 关卡表：ratio=纸宽高比 folds=可折次数 target_m=终点(米)
## wind: none/head/tail；reward=过关固定金币（另有距离金币 = 距离/10）
const LEVELS := [
	{name = "第 1 关 · 后山操场", short = "后山操场", ratio = 1.4, folds = 3, target_m = 30.0, wind = "none", reward = 0,
		tip = "纸最宽好折大翼，终点 30 米，无风。折线画在纸的右侧偏上，30 度满力扔"},
	{name = "第 2 关 · 教学楼顶", short = "教学楼顶", ratio = 1.0, folds = 4, target_m = 45.0, wind = "head", reward = 6,
		gate_x = 34.0, gate_h = 12.0, gate_bonus = 3,
		tip = "纸变方正可折 4 次，逆风阻力 1.25 倍，终点 45 米；终点前 34 米有高空门（12 米高），飘得高的折法穿过+3 金币"},
	{name = "第 3 关 · 河堤风口", short = "河堤风口", ratio = 0.8, folds = 5, target_m = 65.0, wind = "tail", reward = 10,
		tip = "纸最窄可折 5 次，顺风给恒定推力，终点 65 米，过了就是全通关"},
]

## 商店池（5 种，每次抽 3 个按价格升序展示）；unique=唯一强化，购后不再进池
const SHOP_POOL := [
	{id = "power", name = "力气", price = 3, desc = "投掷力度上限 +20%，可叠加"},
	{id = "wing", name = "翼面加强", price = 4, desc = "机翼升力面积 +15%，可叠加"},
	{id = "prop", name = "螺旋桨", price = 6, unique = true, desc = "沿机头方向的恒定推力，唯一"},
	{id = "trimtool", name = "配平仪", price = 4, unique = true, desc = "配平对俯仰的影响减半，唯一"},
	{id = "tough", name = "韧性", price = 3, unique = true, desc = "落地弹跳一次不直接判负，唯一"},
]

var state := "menu"          # menu / fold / throw / fly / settle / shop / final
var level_idx := 0
var unlocked := 0            # 本次会话已通关的最高关（索引）
var coins := 0
var upgrades := {power = 0, wing = 0}   # 可叠加强化级数
var owned := []                          # 唯一强化 id 列表
var shop_items := []                     # 当前商店 Array[Dictionary]
var paper_rect := Rect2(90, 160, 420, 300)
var folds := []                # 已折折线（全局坐标 [Vector2, Vector2]）
var folds_used := 0
var fold_p1 := Vector2.ZERO
var fold_has_p1 := false
var plane_params := {lift_area = 0.0, trim = 0.0, drag_f = 0.0}
var throw_angle := 30.0
var charge := 0.0
var charging := false
var plane_pos := Vector2(START_X, GROUND_Y - 40.0)
var velocity := Vector2.ZERO
var pitch := 0.0               # 机头角（弧度，负=抬头）
var eff_lift := 0.0            # 投掷时定格的等效升力面积（含翼面强化）
var flight_time := 0.0
var flight_distance := 0.0     # 米（每 0.2s 采样 + 结算时刷新，取最大）
var apex_m := 0.0              # v2：本掷最高高度（米），轨迹性格验收用
var gate_hit := false          # v2：高空门是否已穿越
var sample_acc := 0.0
var bounced := false
var last_pass := false
var coins_earned := 0
var best_distance := 0.0
var total_distance := 0.0
var trail := []                # 飞行轨迹（世界坐标）
var scroll_x := 0.0            # 摄像机横向滚动
var pulse := 0.0

var status_label: Label
var hint_label: Label
var fold_btn: Button
var menu_panel: Panel
var level_buttons := []
var menu_tip: Label
var settle_panel: Panel
var settle_title: Label
var settle_body: Label
var settle_btn: Button
var settle_menu_btn: Button
var shop_panel: Panel
var shop_coins: Label
var shop_box: Control
var shop_skip: Button
var final_panel: Panel
var final_body: Label


func _ready() -> void:
	# 根 Control 放行鼠标事件，折线点击/蓄力走 _unhandled_input
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_go_menu()
	queue_redraw()


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "纸飞机模拟器 + 肉鸽（demo-08）"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("0d3b4e"))
	ui.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(16, 40)
	status_label.size = Vector2(920, 24)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("0d3b4e"))
	ui.add_child(status_label)
	hint_label = Label.new()
	hint_label.position = Vector2(16, VIEW.y - 28)
	hint_label.size = Vector2(930, 24)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color("37474f"))
	ui.add_child(hint_label)

	# 折纸阶段：完成折叠按钮
	fold_btn = Button.new()
	fold_btn.name = "FoldDoneBtn"
	fold_btn.text = "完成折叠，去投掷"
	fold_btn.position = Vector2(90, 486)
	fold_btn.size = Vector2(190, 42)
	fold_btn.pressed.connect(_on_fold_done)
	fold_btn.visible = false
	ui.add_child(fold_btn)

	# 选关面板
	menu_panel = Panel.new()
	menu_panel.name = "MenuPanel"
	menu_panel.position = Vector2(150, 92)
	menu_panel.size = Vector2(660, 330)
	var mp_style := StyleBoxFlat.new()
	mp_style.bg_color = Color(1, 1, 1, 0.95)
	mp_style.set_corner_radius_all(14)
	menu_panel.add_theme_stylebox_override("panel", mp_style)
	ui.add_child(menu_panel)
	var mt := Label.new()
	mt.text = "纸飞机模拟器 + 肉鸽：选关起飞"
	mt.position = Vector2(24, 14)
	mt.add_theme_font_size_override("font_size", 22)
	mt.add_theme_color_override("font_color", Color("111111"))
	menu_panel.add_child(mt)
	for i in LEVELS.size():
		var lb := Button.new()
		lb.name = "LevelBtn%d" % i
		lb.text = "第%d关 · %s" % [i + 1, String(LEVELS[i].short)]
		lb.position = Vector2(24 + i * 208, 58)
		lb.size = Vector2(196, 46)
		lb.pressed.connect(start_level.bind(i))
		lb.mouse_entered.connect(_on_menu_hover.bind(i))
		menu_panel.add_child(lb)
		level_buttons.append(lb)
	menu_tip = Label.new()
	menu_tip.name = "MenuTip"
	menu_tip.position = Vector2(24, 114)
	menu_tip.size = Vector2(612, 44)
	menu_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_tip.add_theme_font_size_override("font_size", 14)
	menu_tip.add_theme_color_override("font_color", Color("0d47a1"))
	menu_panel.add_child(menu_tip)
	var rules := Label.new()
	rules.text = "规则：每关 折纸定参数 → 蓄力投掷 → 飞行结算，60 像素 = 1 米，到终点旗过关。\n折线中点越靠纸外侧升力越大；越靠上配平越正（抬头）；折线越长阻力越大。\n金币 = 飞行距离/10 + 过关奖励；关间商店买强化带入下一关；第 3 关过关即全通关。"
	rules.position = Vector2(24, 168)
	rules.size = Vector2(612, 100)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.add_theme_font_size_override("font_size", 13)
	rules.add_theme_color_override("font_color", Color("555555"))
	menu_panel.add_child(rules)

	# 结算面板
	settle_panel = Panel.new()
	settle_panel.name = "SettlePanel"
	settle_panel.position = Vector2(240, 130)
	settle_panel.size = Vector2(480, 240)
	var sp_style := StyleBoxFlat.new()
	sp_style.bg_color = Color(1, 1, 1, 0.95)
	sp_style.set_corner_radius_all(14)
	settle_panel.add_theme_stylebox_override("panel", sp_style)
	settle_panel.visible = false
	ui.add_child(settle_panel)
	settle_title = Label.new()
	settle_title.name = "SettleTitle"
	settle_title.position = Vector2(24, 14)
	settle_title.add_theme_font_size_override("font_size", 24)
	settle_title.add_theme_color_override("font_color", Color("111111"))
	settle_panel.add_child(settle_title)
	settle_body = Label.new()
	settle_body.name = "SettleBody"
	settle_body.position = Vector2(24, 58)
	settle_body.size = Vector2(432, 110)
	settle_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settle_body.add_theme_font_size_override("font_size", 15)
	settle_body.add_theme_color_override("font_color", Color("333333"))
	settle_panel.add_child(settle_body)
	settle_btn = Button.new()
	settle_btn.name = "SettleBtn"
	settle_btn.text = "继续"
	settle_btn.position = Vector2(24, 180)
	settle_btn.size = Vector2(200, 42)
	settle_btn.pressed.connect(settle_continue)
	settle_panel.add_child(settle_btn)
	settle_menu_btn = Button.new()
	settle_menu_btn.text = "返回选关"
	settle_menu_btn.position = Vector2(256, 180)
	settle_menu_btn.size = Vector2(200, 42)
	settle_menu_btn.pressed.connect(_go_menu)
	settle_panel.add_child(settle_menu_btn)

	# 肉鸽商店面板
	shop_panel = Panel.new()
	shop_panel.name = "ShopPanel"
	shop_panel.position = Vector2(170, 88)
	shop_panel.size = Vector2(620, 384)
	var sh_style := StyleBoxFlat.new()
	sh_style.bg_color = Color(1, 1, 1, 0.95)
	sh_style.set_corner_radius_all(14)
	shop_panel.add_theme_stylebox_override("panel", sh_style)
	shop_panel.visible = false
	ui.add_child(shop_panel)
	var st := Label.new()
	st.text = "肉鸽商店（强化立即生效，带入下一关）"
	st.position = Vector2(24, 12)
	st.add_theme_font_size_override("font_size", 20)
	st.add_theme_color_override("font_color", Color("111111"))
	shop_panel.add_child(st)
	shop_coins = Label.new()
	shop_coins.name = "ShopCoins"
	shop_coins.position = Vector2(24, 48)
	shop_coins.add_theme_font_size_override("font_size", 15)
	shop_coins.add_theme_color_override("font_color", Color("e65100"))
	shop_panel.add_child(shop_coins)
	shop_box = Control.new()
	shop_box.name = "ShopBox"
	shop_box.position = Vector2(24, 82)
	shop_box.size = Vector2(572, 224)
	shop_panel.add_child(shop_box)
	shop_skip = Button.new()
	shop_skip.name = "ShopSkip"
	shop_skip.text = "跳过，进入下一关"
	shop_skip.position = Vector2(24, 322)
	shop_skip.size = Vector2(572, 44)
	shop_skip.pressed.connect(_on_shop_skip)
	shop_panel.add_child(shop_skip)

	# 全通关结算面板
	final_panel = Panel.new()
	final_panel.name = "FinalPanel"
	final_panel.position = Vector2(210, 110)
	final_panel.size = Vector2(540, 300)
	var fp_style := StyleBoxFlat.new()
	fp_style.bg_color = Color(1, 1, 1, 0.95)
	fp_style.set_corner_radius_all(14)
	final_panel.add_theme_stylebox_override("panel", fp_style)
	final_panel.visible = false
	ui.add_child(final_panel)
	var ft := Label.new()
	ft.text = "全通关！"
	ft.position = Vector2(24, 14)
	ft.add_theme_font_size_override("font_size", 26)
	ft.add_theme_color_override("font_color", Color("1b5e20"))
	final_panel.add_child(ft)
	final_body = Label.new()
	final_body.name = "FinalBody"
	final_body.position = Vector2(24, 60)
	final_body.size = Vector2(492, 150)
	final_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	final_body.add_theme_font_size_override("font_size", 15)
	final_body.add_theme_color_override("font_color", Color("333333"))
	final_panel.add_child(final_body)
	var btn_again := Button.new()
	btn_again.text = "再来一次（清空进度）"
	btn_again.position = Vector2(24, 230)
	btn_again.size = Vector2(230, 44)
	btn_again.pressed.connect(_reset_run)
	final_panel.add_child(btn_again)
	var btn_back := Button.new()
	btn_back.text = "返回选关"
	btn_back.position = Vector2(286, 230)
	btn_back.size = Vector2(230, 44)
	btn_back.pressed.connect(_go_menu)
	final_panel.add_child(btn_back)


# ---------------- 流程与公开 API ----------------

func _go_menu() -> void:
	state = "menu"
	menu_panel.visible = true
	settle_panel.visible = false
	shop_panel.visible = false
	final_panel.visible = false
	fold_btn.visible = false
	for i in level_buttons.size():
		var lb: Button = level_buttons[i]
		var locked: bool = i > unlocked
		lb.disabled = locked
		lb.text = ("第%d关 · %s" % [i + 1, String(LEVELS[i].short)]) if not locked else ("第%d关（未解锁）" % [i + 1])
	menu_tip.text = "折纸三参数：升力面积（折线越靠外越大）· 配平（越靠上越正/抬头）· 阻力（线越长越大）"
	_update_status()
	queue_redraw()


func _reset_run() -> void:
	coins = 0
	upgrades = {power = 0, wing = 0}
	owned = []
	unlocked = 0
	total_distance = 0.0
	best_distance = 0.0
	_go_menu()


func start_level(i: int) -> void:
	if i < 0 or i >= LEVELS.size():
		return
	level_idx = i
	var L: Dictionary = LEVELS[i]
	var ph := 300.0
	var pw := ph * float(L.ratio)
	paper_rect = Rect2(90, GROUND_Y - ph, pw, ph)
	folds = []
	folds_used = 0
	fold_has_p1 = false
	plane_params = {lift_area = 0.0, trim = 0.0, drag_f = 0.0}
	throw_angle = 30.0
	charge = 0.0
	charging = false
	plane_pos = Vector2(START_X, GROUND_Y - 40.0)
	velocity = Vector2.ZERO
	pitch = 0.0
	eff_lift = 0.0
	flight_time = 0.0
	flight_distance = 0.0
	sample_acc = 0.0
	bounced = false
	last_pass = false
	coins_earned = 0
	trail = []
	scroll_x = 0.0
	state = "fold"
	get_viewport().gui_release_focus()
	menu_panel.visible = false
	settle_panel.visible = false
	shop_panel.visible = false
	final_panel.visible = false
	fold_btn.visible = true
	_update_status()
	queue_redraw()


## 折一条线：p1/p2 为全局屏幕坐标，两点都需落在纸面（放宽 10px）。
## 返回是否成功（不在折纸阶段 / 超过折数上限 / 点不在纸上 → false）。
func add_fold(p1: Vector2, p2: Vector2) -> bool:
	if state != "fold" or folds_used >= int(LEVELS[level_idx].folds):
		return false
	if not paper_rect.grow(10.0).has_point(p1) or not paper_rect.grow(10.0).has_point(p2):
		return false
	folds.append([p1, p2])
	folds_used += 1
	var lp1 := p1 - paper_rect.position
	var lp2 := p2 - paper_rect.position
	var mid := (lp1 + lp2) * 0.5
	var out := clampf(mid.x / paper_rect.size.x, 0.0, 1.0)
	var vert := clampf((paper_rect.size.y * 0.5 - mid.y) / (paper_rect.size.y * 0.5), -1.0, 1.0)
	var len_c := clampf(lp1.distance_to(lp2) / paper_rect.size.length(), 0.0, 1.0)
	plane_params.lift_area = float(plane_params.lift_area) + LIFT_PER_FOLD * (0.4 + 0.6 * out)
	plane_params.trim = float(plane_params.trim) + TRIM_PER_FOLD * vert
	plane_params.drag_f = float(plane_params.drag_f) + DRAG_PER_FOLD * len_c
	_update_status()
	queue_redraw()
	return true


func _on_fold_done() -> void:
	if state != "fold":
		return
	state = "throw"
	fold_btn.visible = false
	get_viewport().gui_release_focus()
	_update_status()
	queue_redraw()


## 投掷：angle_deg 0..60（度），power 0..1。直接进入飞行阶段。
func do_throw(angle_deg: float, power: float) -> void:
	if state != "throw":
		return
	throw_angle = clampf(angle_deg, 0.0, 60.0)
	var pw: float = clampf(power, 0.05, 1.0)
	var v0: float = LAUNCH_V * pw * _power_mult()
	eff_lift = float(plane_params.lift_area) * _wing_mult()
	velocity = Vector2.from_angle(-deg_to_rad(throw_angle)) * v0
	pitch = -deg_to_rad(throw_angle)
	plane_pos = Vector2(START_X, GROUND_Y - 40.0)
	flight_time = 0.0
	flight_distance = 0.0
	apex_m = 0.0
	gate_hit = false
	sample_acc = 0.0
	bounced = false
	last_pass = false
	coins_earned = 0
	trail = [plane_pos]
	scroll_x = 0.0
	charging = false
	charge = 0.0
	state = "fly"
	_update_status()
	queue_redraw()


func _settle() -> void:
	flight_distance = maxf(flight_distance, (plane_pos.x - START_X) / PX_PER_M)
	state = "settle"
	last_pass = flight_distance >= float(LEVELS[level_idx].target_m)
	total_distance += flight_distance
	best_distance = maxf(best_distance, flight_distance)
	if last_pass:
		coins_earned = int(flight_distance / 10.0) + int(LEVELS[level_idx].reward)
		coins += coins_earned
		unlocked = maxi(unlocked, mini(level_idx + 1, LEVELS.size() - 1))
	else:
		coins_earned = 0
	_show_settle_panel()
	_update_status()
	queue_redraw()


## 结算后继续：过关 → 下一关商店（最后一关 → 全通关）；失败 → 重试本关。
func settle_continue() -> void:
	if state != "settle":
		return
	if last_pass:
		if level_idx >= LEVELS.size() - 1:
			_show_final()
		else:
			_enter_shop()
	else:
		start_level(level_idx)


func _enter_shop() -> void:
	state = "shop"
	settle_panel.visible = false
	var pool := []
	for it in SHOP_POOL:
		var id: String = String(it.id)
		if it.get("unique", false) and owned.has(id):
			continue
		pool.append(it)
	pool.shuffle()
	var picked: Array = pool.slice(0, 3)
	picked.sort_custom(func(a, b) -> bool: return int(a.price) < int(b.price))
	shop_items = picked
	_refresh_shop()
	shop_panel.visible = true
	_update_status()


func buy(idx: int) -> bool:
	if state != "shop" or idx < 0 or idx >= shop_items.size():
		return false
	var item: Dictionary = shop_items[idx]
	var price: int = int(item.price)
	if coins < price:
		return false
	if bool(item.get("unique", false)) and owned.has(String(item.id)):
		return false
	coins -= price
	var id: String = String(item.id)
	if id == "power":
		upgrades.power = int(upgrades.power) + 1
	elif id == "wing":
		upgrades.wing = int(upgrades.wing) + 1
	else:
		owned.append(id)
	shop_items.remove_at(idx)
	_refresh_shop()
	return true


func _on_shop_skip() -> void:
	if state == "shop":
		start_level(level_idx + 1)


func _show_settle_panel() -> void:
	settle_panel.visible = true
	var L: Dictionary = LEVELS[level_idx]
	var is_last: bool = level_idx >= LEVELS.size() - 1
	if last_pass:
		settle_title.text = "过关！"
		settle_btn.text = "查看总成绩" if is_last else "进入商店"
	else:
		settle_title.text = "挑战失败"
		settle_btn.text = "重试本关"
	var tip_txt: String = String(L.tip)
	var earn_txt: String = "金币 +%d（现有 %d）" % [coins_earned, coins] if last_pass else "折线画靠外靠上一点、30 度满力扔再试试"
	settle_body.text = "%s\n飞行距离 %.1f 米 · 目标 %.0f 米\n%s\n小贴士：%s" % [
		String(L.name), flight_distance, float(L.target_m), earn_txt, tip_txt]


func _show_final() -> void:
	state = "final"
	settle_panel.visible = false
	var owned_txt: String = ", ".join(owned) if owned.size() > 0 else "无特殊部件"
	final_body.text = "三关全部飞过终点旗！\n总飞行 %d 米 · 最远一掷 %.1f 米 · 金币余额 %d\n强化：力气 x%d · 翼面 x%d · %s" % [
		int(total_distance), best_distance, coins, int(upgrades.power), int(upgrades.wing), owned_txt]
	final_panel.visible = true
	_update_status()
	queue_redraw()


func _on_menu_hover(i: int) -> void:
	menu_tip.text = String(LEVELS[i].tip)


# ---------------- 强化数值 ----------------

func _power_mult() -> float:
	return 1.0 + 0.2 * float(upgrades.power)


func _wing_mult() -> float:
	return 1.0 + 0.15 * float(upgrades.wing)


func _has_upgrade(id: String) -> bool:
	return owned.has(id)


func _wind_mode() -> String:
	return String(LEVELS[level_idx].wind)


func _wind_name() -> String:
	if _wind_mode() == "head":
		return "逆风"
	if _wind_mode() == "tail":
		return "顺风"
	return "无风"


func _refresh_shop() -> void:
	shop_coins.text = "金币：%d" % coins
	for c in shop_box.get_children():
		c.queue_free()
	for i in shop_items.size():
		var item: Dictionary = shop_items[i]
		var b := Button.new()
		b.name = "ShopItem%d" % i
		b.text = "%s · %d 金币 —— %s" % [String(item.name), int(item.price), String(item.desc)]
		b.position = Vector2(0, i * 62)
		b.size = Vector2(572, 52)
		b.disabled = coins < int(item.price)
		b.pressed.connect(buy.bind(i))
		shop_box.add_child(b)


func _update_status() -> void:
	if status_label == null:
		return
	var L: Dictionary = LEVELS[level_idx]
	if state == "menu":
		status_label.text = "纸飞机模拟器 + 肉鸽 · 已通关 %d/3 关 · 金币 %d" % [unlocked, coins]
		hint_label.text = "选一关起飞：折纸定参数，蓄力投掷，看它飞过终点旗"
	elif state == "fold":
		status_label.text = "%s · 折纸：已折 %d/%d 条 · 目标 %.0f 米 · %s" % [
			String(L.name), folds_used, int(L.folds), float(L.target_m), _wind_name()]
		hint_label.text = "在纸上点两下折一条线；完成后点左下按钮进入投掷"
	elif state == "throw":
		status_label.text = "%s · 投掷：角度 %d° · 力度上限 x%.1f · 目标 %.0f 米" % [
			String(L.name), int(round(throw_angle)), _power_mult(), float(L.target_m)]
		hint_label.text = "鼠标上下或方向键调角度，按住空格/鼠标左键蓄力，松开发射"
	elif state == "fly":
		var live_m := (plane_pos.x - START_X) / PX_PER_M
		var h_m := (GROUND_Y - plane_pos.y) / PX_PER_M
		status_label.text = "%s · 飞行中 %.1f 米 / 目标 %.0f 米 · 高度 %.1f 米" % [
			String(L.name), live_m, float(L.target_m), h_m]
		hint_label.text = ""
	elif state == "settle":
		var head_txt: String = "过关！" if last_pass else "挑战失败"
		status_label.text = head_txt + " · 飞行 %.1f 米 · 金币 %d" % [flight_distance, coins]
		hint_label.text = ""
	elif state == "shop":
		status_label.text = "肉鸽商店 · 金币 %d · 买强化带入第 %d 关" % [coins, level_idx + 2]
		hint_label.text = "买不起就点跳过；金币 = 上关飞行距离/10 + 过关奖励"
	elif state == "final":
		status_label.text = "全通关！三面终点旗都插上了 · 金币 %d" % coins
		hint_label.text = ""


# ---------------- 输入 ----------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if state == "fold" and event.pressed:
			if paper_rect.grow(10.0).has_point(pos):
				if not fold_has_p1:
					fold_p1 = pos
					fold_has_p1 = true
				else:
					add_fold(fold_p1, pos)
					fold_has_p1 = false
				queue_redraw()
		elif state == "throw":
			if event.pressed:
				charging = true
				charge = 0.0
			else:
				_release_throw()
	elif event is InputEventKey:
		if state == "throw":
			var k := event as InputEventKey
			if k.pressed and not k.echo:
				if k.keycode == KEY_UP:
					throw_angle = minf(60.0, throw_angle + 3.0)
				elif k.keycode == KEY_DOWN:
					throw_angle = maxf(0.0, throw_angle - 3.0)
				elif k.keycode == KEY_SPACE:
					charging = true
					charge = 0.0
			elif not k.pressed and k.keycode == KEY_SPACE:
				_release_throw()
	elif event is InputEventMouseMotion and state == "throw" and not charging:
		throw_angle = clampf((VIEW.y - event.position.y) * 60.0 / VIEW.y, 0.0, 60.0)


func _release_throw() -> void:
	if state == "throw" and charging:
		charging = false
		do_throw(throw_angle, charge)
		charge = 0.0


# ---------------- 主循环 ----------------

func _process(delta: float) -> void:
	pulse += delta * 3.0
	if state == "throw" and charging:
		charge = minf(1.0, charge + delta / CHARGE_TIME)
	_update_status()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if state == "fly":
		_fly_step(delta)


func _fly_step(delta: float) -> void:
	flight_time += delta
	var spd := velocity.length()
	# 升力 = 竖直向上的减重加速度，随速度平方增长、封顶 0.95g（保证最终会降落，不会失速画圈）
	var lift_up: float = minf(LIFT_K * eff_lift * spd * spd, GRAV * 0.95)
	# v2 飞行性格（弱非线性，验收=3 种肉眼可辨轨迹）：
	# 配平低（机头重）→ 升力衰减 → 高速低平俯冲；配平高（机头轻）→ 升力后倾 → 飘-掉高（滞空换速度）
	var t_trim: float = clampf(float(plane_params.trim), -1.5, 1.5)
	var lift_scale := 1.0
	var lift_tilt: float = t_trim * 0.22
	if t_trim < -0.05:
		lift_scale = lerpf(1.0, 0.35, clampf((-t_trim - 0.05) / 0.55, 0.0, 1.0))
	elif t_trim > 0.15:
		lift_tilt = lerpf(t_trim * 0.22, 0.55, clampf((t_trim - 0.15) / 0.45, 0.0, 1.0))
	if _has_upgrade("trimtool"):
		lift_tilt *= 0.5
	var lift_dir := Vector2(sin(lift_tilt), -cos(lift_tilt)).normalized()
	var drag_f_v: float = plane_params.drag_f
	var drag_coef := DRAG_K * (BASE_DRAG + drag_f_v)
	if _wind_mode() == "head":
		drag_coef *= HEAD_DRAG_MULT
	var drag_vec := Vector2.ZERO
	if spd > 0.01:
		drag_vec = -velocity / spd * (drag_coef * spd * spd)
	var acc := lift_dir * (lift_up * lift_scale) + drag_vec + Vector2(0.0, GRAV)
	if _wind_mode() == "tail":
		acc += Vector2(TAIL_THRUST, 0.0)
	if _has_upgrade("prop"):
		acc += Vector2.from_angle(pitch) * PROP_THRUST
	velocity += acc * delta
	# 机头视觉上追随速度方向，配平让姿态微微抬头（纯表现）
	var d_ang := wrapf(velocity.angle() - pitch, -PI, PI)
	pitch += (PITCH_FOLLOW * d_ang + 0.35 * clampf(float(plane_params.trim), -1.0, 1.0)) * delta
	var prev_x := plane_pos.x
	plane_pos += velocity * delta
	apex_m = maxf(apex_m, (GROUND_Y - plane_pos.y) / PX_PER_M)
	trail.append(plane_pos)
	if trail.size() > 120:
		trail.pop_front()
	if plane_pos.x - 380.0 > scroll_x:
		scroll_x = plane_pos.x - 380.0
	# 每 0.2s 采样一次距离（x 换算米，取最大）
	sample_acc += delta
	if sample_acc >= SAMPLE_STEP:
		sample_acc -= SAMPLE_STEP
		flight_distance = maxf(flight_distance, (plane_pos.x - START_X) / PX_PER_M)
	# v2 高空得分门：在门的位置处于门高以上穿过 → 额外金币（一次性）
	var gate_x_m: float = float(LEVELS[level_idx].get("gate_x", 0.0))
	if gate_x_m > 0.0 and not gate_hit:
		var gate_px := START_X + gate_x_m * PX_PER_M
		if prev_x < gate_px and plane_pos.x >= gate_px:
			if plane_pos.y <= GROUND_Y - float(LEVELS[level_idx].gate_h) * PX_PER_M:
				gate_hit = true
				var gb: int = int(LEVELS[level_idx].gate_bonus)
				coins += gb
				coins_earned += gb
	var finish_px := START_X + float(LEVELS[level_idx].target_m) * PX_PER_M
	if plane_pos.x >= finish_px:
		_settle()
		return
	if plane_pos.y >= GROUND_Y:
		if _has_upgrade("tough") and not bounced:
			bounced = true
			plane_pos.y = GROUND_Y - 2.0
			velocity.y = -absf(velocity.y) * 0.5 - 60.0
			velocity.x *= 0.8
		else:
			_settle()
			return
	if flight_time >= MAX_FLIGHT_TIME:
		_settle()


# ---------------- 绘制 ----------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color("cfe8f5"))
	_draw_cloud(Vector2(160, 84))
	_draw_cloud(Vector2(470, 124))
	_draw_cloud(Vector2(790, 74))
	if state != "menu":
		_draw_wind()
	draw_rect(Rect2(0, GROUND_Y, VIEW.x, VIEW.y - GROUND_Y), Color("8bbf6a"))
	draw_line(Vector2(0, GROUND_Y), Vector2(VIEW.x, GROUND_Y), Color("5d8f42"), 3.0)
	if state == "menu":
		return
	_draw_ticks_and_flag()
	_draw_thrower()
	if state == "fold":
		_draw_paper()
		_draw_bars()
	if state == "fold" or state == "throw":
		_draw_plane(plane_pos, 0.0)
	elif state == "fly" or state == "settle" or state == "shop" or state == "final":
		_draw_trail()
		_draw_plane(plane_pos, pitch)
		if state == "fly":
			var live_m := (plane_pos.x - START_X) / PX_PER_M
			draw_string(FONT, plane_pos + Vector2(-scroll_x + 18.0, -12.0), "%.1f 米" % live_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("0d3b4e"))
	if state == "throw":
		_draw_throw_ui()


func _draw_cloud(c: Vector2) -> void:
	var col := Color(1, 1, 1, 0.85)
	draw_circle(c, 16.0, col)
	draw_circle(c + Vector2(18.0, -6.0), 13.0, col)
	draw_circle(c + Vector2(-18.0, -4.0), 12.0, col)


func _draw_wind() -> void:
	var wmode := _wind_mode()
	if wmode == "none":
		return
	var head: bool = wmode == "head"
	var col := Color("5c6bc0") if head else Color("43a047")
	var dir := -1.0 if head else 1.0
	for k in 3:
		var yy := 66.0 + k * 18.0
		var off := fmod(pulse * 46.0 + k * 30.0, 110.0)
		var ax: float = (910.0 - off) if head else (620.0 + off)
		var tipx: float = ax + dir * 30.0
		draw_line(Vector2(ax, yy), Vector2(tipx, yy), col, 2.5)
		draw_line(Vector2(tipx, yy), Vector2(tipx - dir * 8.0, yy - 5.0), col, 2.0)
		draw_line(Vector2(tipx, yy), Vector2(tipx - dir * 8.0, yy + 5.0), col, 2.0)
	var label := "逆风 阻力 x1.25" if head else "顺风 恒定推力"
	draw_string(FONT, Vector2(790.0, 56.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


func _draw_ticks_and_flag() -> void:
	var step_m := 5
	var m0: int = maxi(0, int(floorf((scroll_x - 80.0 - START_X) / (PX_PER_M * step_m))) * step_m)
	var m1: int = int(ceilf((scroll_x + VIEW.x + 80.0 - START_X) / (PX_PER_M * step_m))) * step_m
	var m := m0
	while m <= m1:
		var sx: float = START_X + m * PX_PER_M - scroll_x
		var big: bool = m % 10 == 0
		draw_line(Vector2(sx, GROUND_Y), Vector2(sx, GROUND_Y - (14.0 if big else 7.0)), Color("5d8f42"), 2.0)
		if big:
			draw_string(FONT, Vector2(sx - 16.0, GROUND_Y + 24.0), "%d米" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("33691e"))
		m += step_m
	var target_m: float = float(LEVELS[level_idx].target_m)
	var fx := START_X + target_m * PX_PER_M - scroll_x
	if fx > -60.0 and fx < VIEW.x + 60.0:
		draw_line(Vector2(fx, GROUND_Y), Vector2(fx, GROUND_Y - 130.0), Color("6b4a2f"), 5.0)
		draw_polygon(PackedVector2Array([Vector2(fx, GROUND_Y - 130.0), Vector2(fx + 46.0, GROUND_Y - 116.0), Vector2(fx, GROUND_Y - 102.0)]), PackedColorArray([Color("e53935")]))
		draw_string(FONT, Vector2(fx - 34.0, GROUND_Y - 140.0), "终点 %.0f 米" % target_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("b71c1c"))
	# v2 高空得分门（立在地上的高空圆环，穿过=额外金币）
	var gate_x_m: float = float(LEVELS[level_idx].get("gate_x", 0.0))
	if gate_x_m > 0.0:
		var gx := START_X + gate_x_m * PX_PER_M - scroll_x
		var gy := GROUND_Y - float(LEVELS[level_idx].gate_h) * PX_PER_M
		if gx > -80.0 and gx < VIEW.x + 80.0:
			var gcol := Color("ffd54f") if not gate_hit else Color("b0bec5")
			draw_arc(Vector2(gx, gy), 34.0, -PI / 2, PI / 2, 20, gcol, 5.0)
			draw_line(Vector2(gx, GROUND_Y), Vector2(gx, gy), Color("8d6e63"), 3.0)
			draw_string(FONT, Vector2(gx - 40.0, gy - 46.0), "高空门 +%d" % int(LEVELS[level_idx].gate_bonus), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f57f17"))


func _draw_thrower() -> void:
	var bx: float = START_X - 24.0 - scroll_x
	draw_circle(Vector2(bx, GROUND_Y - 46.0), 7.0, Color("ff7043"))
	draw_line(Vector2(bx, GROUND_Y - 39.0), Vector2(bx, GROUND_Y - 16.0), Color("5d4037"), 4.0)
	draw_line(Vector2(bx, GROUND_Y - 16.0), Vector2(bx - 8.0, GROUND_Y), Color("5d4037"), 3.0)
	draw_line(Vector2(bx, GROUND_Y - 16.0), Vector2(bx + 8.0, GROUND_Y), Color("5d4037"), 3.0)
	draw_line(Vector2(bx, GROUND_Y - 34.0), Vector2(bx + 14.0, GROUND_Y - 42.0), Color("5d4037"), 3.0)


func _draw_paper() -> void:
	draw_rect(paper_rect, Color("ffffff"))
	draw_rect(paper_rect, Color("b0bec5"), false, 2.0)
	draw_string(FONT, paper_rect.position + Vector2(0.0, -10.0), "纸张：剩余可折 %d 次" % (int(LEVELS[level_idx].folds) - folds_used), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("455a64"))
	for f in folds:
		var a: Vector2 = f[0]
		var b: Vector2 = f[1]
		draw_line(a, b, Color("78909c"), 2.0)
		draw_circle(a, 3.0, Color("78909c"))
		draw_circle(b, 3.0, Color("78909c"))
	if fold_has_p1:
		draw_circle(fold_p1, 4.0, Color("e53935"))
		draw_line(fold_p1, get_global_mouse_position(), Color(0.86, 0.3, 0.3, 0.5), 1.5)


func _draw_bars() -> void:
	var bx := 545.0
	var by := 152.0
	# v2 监督建议#3：参数从精确数值改档位仪表（保留因果可见，防盯数字局部最优）
	_draw_tier("升力", _tier3(float(plane_params.lift_area), 0.5, 1.0), bx, by, Color("1e88e5"))
	_draw_tier("配平", _trim_tier(float(plane_params.trim)), bx, by + 46.0, Color("43a047"))
	_draw_tier("阻力", _tier3(float(plane_params.drag_f), 0.5, 1.0), bx, by + 92.0, Color("fb8c00"))
	draw_string(FONT, Vector2(bx, by + 150.0), "折纸规则（因果透明）：", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("0d3b4e"))
	draw_string(FONT, Vector2(bx, by + 172.0), "折线中点越靠纸右侧 → 升力越大（滞空久）", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("455a64"))
	draw_string(FONT, Vector2(bx, by + 192.0), "折线中点越靠上 → 配平抬头（飘），靠下俯冲（快）", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("455a64"))
	draw_string(FONT, Vector2(bx, by + 212.0), "折线总长越长 → 阻力越大（越慢越稳）", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("455a64"))


func _tier3(v: float, mid: float, high: float) -> String:
	return "低" if v < mid else ("中" if v < high else "高")


func _trim_tier(v: float) -> String:
	return "俯冲" if v < -0.15 else ("稳定" if v <= 0.35 else "抬头")


func _draw_tier(label: String, tier: String, x: float, y: float, col: Color) -> void:
	draw_string(FONT, Vector2(x, y + 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("37474f"))
	var cells: Array = ["低", "中", "高"] if label != "配平" else ["俯冲", "稳定", "抬头"]
	for k in cells.size():
		var cx := x + 70.0 + k * 92.0
		var active: bool = cells[k] == tier
		var bg := col if active else Color(1, 1, 1, 0.6)
		draw_rect(Rect2(cx, y, 84.0, 22.0), bg)
		if active:
			draw_rect(Rect2(cx, y, 84.0, 22.0), Color("263238"), false, 2.0)
		draw_string(FONT, Vector2(cx + (34.0 if cells[k].length() == 1 else 22.0), y + 16.0), cells[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE if active else Color("607d8b"))


func _draw_bar(label: String, val: float, centered: bool, x: float, y: float, col: Color) -> void:
	var pos := Vector2(x, y)
	var w := 340.0
	var h := 18.0
	draw_string(FONT, pos + Vector2(0.0, 12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("37474f"))
	var bar_y := pos.y + 18.0
	draw_rect(Rect2(pos.x, bar_y, w, h), Color(1, 1, 1, 0.8))
	draw_rect(Rect2(pos.x, bar_y, w, h), Color("90a4ae"), false, 1.5)
	if centered:
		var cx := pos.x + w * 0.5
		var half := w * 0.5
		var v := clampf(val, -1.0, 1.0)
		var fw := absf(v) * half
		var fx := cx if v >= 0.0 else cx - fw
		draw_rect(Rect2(fx, bar_y + 2.0, fw, h - 4.0), col)
		draw_line(Vector2(cx, bar_y - 3.0), Vector2(cx, bar_y + h + 3.0), Color("37474f"), 2.0)
		draw_string(FONT, pos + Vector2(w + 12.0, bar_y + 14.0), "%+.2f" % val, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	else:
		var vmax := 1.5
		var v2 := clampf(val, 0.0, vmax)
		draw_rect(Rect2(pos.x + 2.0, bar_y + 2.0, (w - 4.0) * v2 / vmax, h - 4.0), col)
		draw_string(FONT, pos + Vector2(w + 12.0, bar_y + 14.0), "%.2f" % val, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)


func _draw_throw_ui() -> void:
	var origin := Vector2(START_X - scroll_x, plane_pos.y)
	var dirv := Vector2.from_angle(-deg_to_rad(throw_angle))
	var tip := origin + dirv * 130.0
	draw_line(origin, tip, Color("e53935"), 3.0)
	draw_arc(origin, 60.0, -deg_to_rad(throw_angle), 0.0, 20, Color(0.9, 0.3, 0.3, 0.6), 2.0)
	draw_string(FONT, tip + Vector2(10.0, 0.0), "%d°" % int(round(throw_angle)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e53935"))
	var cb := Rect2(340, 496, 280, 20)
	draw_rect(cb, Color(1, 1, 1, 0.85))
	draw_rect(cb, Color("90a4ae"), false, 1.5)
	draw_rect(Rect2(cb.position.x + 2.0, cb.position.y + 2.0, (cb.size.x - 4.0) * charge, cb.size.y - 4.0), Color("e53935"))
	draw_string(FONT, Vector2(340.0, 490.0), "蓄力 %.0f%%（按住空格/鼠标左键，松开发射）" % (charge * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("37474f"))


func _draw_trail() -> void:
	if trail.size() < 2:
		return
	var pts := PackedVector2Array()
	for p in trail:
		var wp: Vector2 = p
		pts.append(Vector2(wp.x - scroll_x, wp.y))
	draw_polyline(pts, Color(0.36, 0.55, 0.8, 0.55), 2.0)


func _draw_plane(p: Vector2, ang: float) -> void:
	var local := [Vector2(18, 0), Vector2(-14, -9), Vector2(-7, 0), Vector2(-14, 7)]
	var base := Vector2(p.x - scroll_x, p.y)
	var pts := PackedVector2Array()
	for v in local:
		var lv: Vector2 = v
		pts.append(base + lv.rotated(ang))
	draw_colored_polygon(pts, Color("fafafa"))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color("78909c"), 1.5)
