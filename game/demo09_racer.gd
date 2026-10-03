extends Control
## 赛车模拟器（demo-09 最小可玩版）
## 两阶段循环：车库设计（3 种预设车身 + 在底盘横梁上自由摆放最多 4 个轮胎、每个可调半径 12~30px）
## → 驾驶（手写悬挂物理：每个轮胎是一个悬挂点，弹簧力 = K*压缩量 + 阻尼*压缩速度，作用于车身产生力+扭矩）。
## 关卡约束表驱动：L1 至少 2 轮；L2 追加两个后轮规则（后半段 x>0.5 至少 2 个）；L3 追加半径上限 20px。
## 翻车判定：车顶触地持续 1.5 秒。车到终点旗过关；对手车与车辆碰撞安排在 v2（结算面板注明）。
## 10 像素 = 1 米；地形 = 固定种子多段正弦叠加（确定性）；纯代码绘制（draw_* 画车/轮/地形），无外部素材、无物理引擎节点。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")

## ---- 物理常量：质量归一为 1，所有力都归一成加速度（沿 demo08 的自写积分风格）----
const PX_PER_M := 10.0
const GRAV := 900.0             # 重力 px/s^2
const SUSP_LEN := 20.0          # 悬挂自然长度 px（锚点到轮心）
const SPRING_K := 60.0          # 弹簧刚度：单轮支撑加速度 = K * 压缩量（1/s^2）
const SUSP_DAMP := 9.0          # 悬挂阻尼：+ DAMP * 压缩速度（约 0.58 倍临界阻尼，略弹手感）
const MAX_COMP := 14.0          # 悬挂最大压缩量（超出按此封顶，防硬着陆爆力）
const MAX_SUSP_ACC := 2600.0    # 单轮悬挂加速度上限（落地冲击防爆）
const DRIVE_ACC := 850.0        # 油门总驱动加速度，平分给接地的驱动轮（驱动轮 = 最后两个轮胎）
const BRAKE_ACC := 420.0        # 刹车/倒车总加速度
const DRAG_K := 0.002           # 风阻加速度 = DRAG_K * 车身风阻系数 * v^2（标准车身极速约 650px/s）
const ROLL_FRIC := 30.0         # 滚动阻力 px/s^2（任一轮接地时）
const ANG_DAMP := 4.0           # 角速度阻尼 1/s
const OMEGA_MAX := 5.0          # 角速度上限 rad/s（防翻滚失控）
const DRIVE_TORQUE_KEEP := 0.15 # 驱动力扭矩保留比例（其余作用于质心高度：防满油门后翻，保留起步翘头手感）
const ROOF_LIMIT := 1.5         # 车顶触地持续秒数 → 判翻车
const AIR_ASSIST := 3.0         # 空中姿态辅助：车头追随速度方向（仅车头大致朝前时生效，保留翻车可能）
const AIR_ASSIST_MIN_SPD := 80.0
const SPEED_MAX := 900.0
const START_X := 120.0
const BASE_GROUND_Y := 430.0
const WHEEL_MAX := 4
const R_MIN := 12.0
const R_MAX := 30.0

## 车库预览横梁（屏幕坐标）：车头在右（x_ratio=0），车尾在左（x_ratio=1）
const RAIL_X0 := 140.0
const RAIL_LEN := 480.0
const RAIL_Y := 330.0
const WHEEL_DISP_Y := 362.0
const RAIL_RECT := Rect2(140, 326, 480, 84)

## 车身预设：宽扁 = 重心低（悬挂锚点离质心近、力臂短）稳但风阻大；高窄 = 重心高（力臂长）易颠但风阻小
const BODIES := [
	{name = "宽扁车身", desc = "重心低 · 稳 · 风阻大", len = 90.0, h = 26.0, beam_y = 9.0, drag = 1.35},
	{name = "标准车身", desc = "均衡之选", len = 76.0, h = 34.0, beam_y = 13.0, drag = 1.0},
	{name = "高窄车身", desc = "重心高 · 易颠 · 风阻小", len = 64.0, h = 44.0, beam_y = 18.0, drag = 0.75},
]

## 关卡表：a/w = 三层正弦的振幅/波长（大波长=长坡，小波长=颠簸，固定种子相位保证确定性）
## min_wheels = 最少轮胎数；rear_min = 后半段（x>0.5）最少数量（两个后轮规则）；max_r = 半径上限（0=不限）
const LEVELS := [
	{name = "第 1 关 · 郊外直道", short = "郊外直道", target_m = 800.0,
		a1 = 9.0, w1 = 300.0, a2 = 4.0, w2 = 110.0, a3 = 7.0, w3 = 900.0,
		min_wheels = 2, rear_min = 0, max_r = 0.0, ground = "8bbf6a", ground_dark = "5d8f42",
		tip = "平缓路面：至少 2 个轮胎、半径不限。前后各放一个大轮就能稳稳跑完"},
	{name = "第 2 关 · 丘陵起伏", short = "丘陵起伏", target_m = 1000.0,
		a1 = 20.0, w1 = 320.0, a2 = 7.0, w2 = 130.0, a3 = 14.0, w3 = 900.0,
		min_wheels = 2, rear_min = 2, max_r = 0.0, ground = "9cb35f", ground_dark = "6b8e3a",
		tip = "丘陵路面：至少 2 个轮胎，且后半段（x>0.5）至少 2 个——两个后轮规则，防止翘头翻车"},
	{name = "第 3 关 · 山地陡坡", short = "山地陡坡", target_m = 1200.0,
		a1 = 28.0, w1 = 380.0, a2 = 11.0, w2 = 160.0, a3 = 20.0, w3 = 900.0,
		min_wheels = 2, rear_min = 2, max_r = 20.0, ground = "a1887f", ground_dark = "6d4c41",
		tip = "山地陡坡：两个后轮 + 轮胎半径上限 20。四个中小轮铺满底盘最稳，过了就是全通关"},
	{name = "第 4 关 · 诊断测试场", short = "诊断测试场", target_m = 450.0,
		a1 = 17.0, w1 = 170.0, a2 = 9.0, w2 = 48.0, a3 = 3.0, w3 = 900.0,
		min_wheels = 2, rear_min = 0, max_r = 0.0, budget = 4300.0, ground = "c9b458", ground_dark = "8a7742",
		tip = "v2 诊断关（450 米短场）：陡坡沟 + 密集小颠簸 + 高速段叠加。轮胎总面积预算 4300（Σπr²）——大轮与多轮不可兼得。试试长轴距大轮/短轴距小轮/三轮偏置谁快谁稳"},
]

var state := "menu"          # menu / build / drive / settle / final
var level_idx := 0
var unlocked := 0            # 本次会话已解锁的最高关（索引）
var body_kind := 1
var wheels: Array[Dictionary] = []   # 车库：{xr, r}；发车后追加 {lx, ly, pc, spin, wx, wy}
var sel_idx := -1
var last_radius := 18.0

var car_pos := Vector2(START_X, BASE_GROUND_Y - 40.0)
var car_angle := 0.0         # 姿态角（弧度，0=水平，正=车头朝下）
var omega := 0.0             # 角速度 rad/s
var vel := Vector2.ZERO
var flight_time := 0.0       # 本关驾驶用时
var max_speed := 0.0         # 本关最高速度（米/秒）
var total_time := 0.0        # 累计用时（全通关结算用）
var last_pass := false
var settle_reason := ""      # finish / flip
var roof_time := 0.0         # 车顶触地累计秒数
var auto_throttle := 0.0     # 测试注入：>0 时按满油门，随时间递减
# v2 遥测（监督者六指标）：最大俯仰/滞空/托底次数/接地率 + Ghost 记忆
var max_pitch := 0.0         # 本掷最大 |姿态角|（弧度）
var airtime_s := 0.0         # 全轮离地累计秒数
var bottom_out := 0          # 悬挂压缩到顶的次数（托底）
var grounded_frames := 0     # 接地帧数
var drive_frames := 0        # 总物理帧数
var launch_layout := []      # 发车时轮胎布局快照 [{xr,r}]
var last_layout_by_level := {}   # level_idx -> 上一次发车布局（车库自动预填=复制上一版）
var last_time_by_level := {}     # level_idx -> 上一次完赛/结算用时
var ghost_pts := []          # 上一次完赛轨迹（世界坐标采样），驾驶时半透明回放
var cur_ghost_pts := []      # 当前掷轨迹采样
var was_bottom := false      # 托底事件边沿检测
var ghost_n := 0             # 轨迹采样计数
var scroll_x := 0.0
var pulse := 0.0
var ph1 := 0.0
var ph2 := 0.0
var ph3 := 0.0

var status_label: Label
var hint_label: Label
var build_ui: Control
var body_buttons: Array = []
var launch_btn: Button
var gate_label: Label
var menu_panel: Panel
var level_buttons: Array = []
var menu_tip: Label
var settle_panel: Panel
var settle_title: Label
var settle_body: Label
var settle_btn: Button
var settle_menu_btn: Button
var final_panel: Panel
var final_body: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_go_menu()
	queue_redraw()


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "赛车模拟器（demo-09）"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("263238"))
	ui.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(16, 40)
	status_label.size = Vector2(830, 24)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("263238"))
	ui.add_child(status_label)
	hint_label = Label.new()
	hint_label.position = Vector2(16, VIEW.y - 28)
	hint_label.size = Vector2(930, 24)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color("455a64"))
	ui.add_child(hint_label)

	# ---- 车库阶段控件（容器统一显隐）----
	build_ui = Control.new()
	build_ui.name = "BuildUI"
	build_ui.visible = false
	ui.add_child(build_ui)
	for i in BODIES.size():
		var bb := Button.new()
		bb.name = "BodyBtn%d" % i
		bb.text = String(BODIES[i].name)
		bb.position = Vector2(140 + i * 164, 112)
		bb.size = Vector2(156, 40)
		bb.pressed.connect(set_body.bind(i))
		build_ui.add_child(bb)
		body_buttons.append(bb)
	var r_minus := Button.new()
	r_minus.name = "RadiusMinusBtn"
	r_minus.text = "半径 −"
	r_minus.position = Vector2(140, 432)
	r_minus.size = Vector2(110, 36)
	r_minus.pressed.connect(_adjust_radius.bind(-2.0))
	build_ui.add_child(r_minus)
	var r_plus := Button.new()
	r_plus.name = "RadiusPlusBtn"
	r_plus.text = "半径 ＋"
	r_plus.position = Vector2(258, 432)
	r_plus.size = Vector2(110, 36)
	r_plus.pressed.connect(_adjust_radius.bind(2.0))
	build_ui.add_child(r_plus)
	var r_del := Button.new()
	r_del.name = "RemoveWheelBtn"
	r_del.text = "移除轮"
	r_del.position = Vector2(376, 432)
	r_del.size = Vector2(110, 36)
	r_del.pressed.connect(_remove_selected)
	build_ui.add_child(r_del)
	var r_clear := Button.new()
	r_clear.name = "ClearWheelsBtn"
	r_clear.text = "清空"
	r_clear.position = Vector2(494, 432)
	r_clear.size = Vector2(110, 36)
	r_clear.pressed.connect(clear_wheels)
	build_ui.add_child(r_clear)
	launch_btn = Button.new()
	launch_btn.name = "LaunchBtn"
	launch_btn.text = "出 发"
	launch_btn.position = Vector2(700, 330)
	launch_btn.size = Vector2(224, 54)
	launch_btn.pressed.connect(do_launch)
	build_ui.add_child(launch_btn)
	gate_label = Label.new()
	gate_label.name = "GateLabel"
	gate_label.position = Vector2(700, 392)
	gate_label.size = Vector2(224, 80)
	gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gate_label.add_theme_font_size_override("font_size", 12)
	build_ui.add_child(gate_label)
	var back_btn := Button.new()
	back_btn.name = "BackBtn"
	back_btn.text = "返回选关"
	back_btn.position = Vector2(852, 40)
	back_btn.size = Vector2(96, 30)
	back_btn.pressed.connect(_go_menu)
	build_ui.add_child(back_btn)

	# ---- 选关面板 ----
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
	mt.text = "赛车模拟器：选关进车库"
	mt.position = Vector2(24, 14)
	mt.add_theme_font_size_override("font_size", 22)
	mt.add_theme_color_override("font_color", Color("111111"))
	menu_panel.add_child(mt)
	for i in LEVELS.size():
		var lb := Button.new()
		lb.name = "LevelBtn%d" % i
		lb.text = "第%d关 · %s" % [i + 1, String(LEVELS[i].short)]
		lb.position = Vector2(24 + i * 155, 58)
		lb.size = Vector2(147, 46)
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
	rules.text = "规则：每关 车库设计 → 驾驶到终点旗，10 像素 = 1 米。\n车身三选一（宽扁稳/高窄灵）；轮胎在底盘横梁上自由摆放（最多 4 个，半径 12~30 可调）——布局决定重心与抓地。\n关卡约束逐关收紧：L1 至少 2 轮；L2 加两个后轮；L3 加半径上限。翻车 = 车顶触地 1.5 秒。\n对手车与车辆碰撞玩法安排在 v2 版本。"
	rules.position = Vector2(24, 168)
	rules.size = Vector2(612, 140)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.add_theme_font_size_override("font_size", 13)
	rules.add_theme_color_override("font_color", Color("555555"))
	menu_panel.add_child(rules)

	# ---- 结算面板 ----
	settle_panel = Panel.new()
	settle_panel.name = "SettlePanel"
	settle_panel.position = Vector2(240, 130)
	settle_panel.size = Vector2(480, 250)
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
	settle_body.size = Vector2(432, 120)
	settle_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settle_body.add_theme_font_size_override("font_size", 15)
	settle_body.add_theme_color_override("font_color", Color("333333"))
	settle_panel.add_child(settle_body)
	settle_btn = Button.new()
	settle_btn.name = "SettleBtn"
	settle_btn.text = "继续"
	settle_btn.position = Vector2(24, 190)
	settle_btn.size = Vector2(200, 42)
	settle_btn.pressed.connect(settle_continue)
	settle_panel.add_child(settle_btn)
	settle_menu_btn = Button.new()
	settle_menu_btn.name = "SettleMenuBtn"
	settle_menu_btn.text = "返回选关"
	settle_menu_btn.position = Vector2(256, 190)
	settle_menu_btn.size = Vector2(200, 42)
	settle_menu_btn.pressed.connect(_go_menu)
	settle_panel.add_child(settle_menu_btn)

	# ---- 全通关面板 ----
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
	btn_again.name = "FinalRetryBtn"
	btn_again.text = "再来一次（清空进度）"
	btn_again.position = Vector2(24, 230)
	btn_again.size = Vector2(230, 44)
	btn_again.pressed.connect(_reset_run)
	final_panel.add_child(btn_again)
	var btn_back := Button.new()
	btn_back.name = "FinalMenuBtn"
	btn_back.text = "返回选关"
	btn_back.position = Vector2(286, 230)
	btn_back.size = Vector2(230, 44)
	btn_back.pressed.connect(_go_menu)
	final_panel.add_child(btn_back)


# ---------------- 地形（固定种子，确定性） ----------------

func ground_y(x: float) -> float:
	var L: Dictionary = LEVELS[level_idx]
	var ramp: float = clampf((x - 60.0) / 520.0, 0.0, 1.0)   # 起步段平整，出发不打滑
	var h: float = float(L.a1) * sin(x * TAU / float(L.w1) + ph1) \
		+ float(L.a2) * sin(x * TAU / float(L.w2) + ph2) \
		+ float(L.a3) * sin(x * TAU / float(L.w3) + ph3)
	return BASE_GROUND_Y - h * ramp


# ---------------- 流程与公开 API ----------------

func _go_menu() -> void:
	state = "menu"
	menu_panel.visible = true
	settle_panel.visible = false
	final_panel.visible = false
	build_ui.visible = false
	for i in level_buttons.size():
		var lb: Button = level_buttons[i]
		var locked: bool = i > unlocked
		lb.disabled = locked
		lb.text = ("第%d关 · %s" % [i + 1, String(LEVELS[i].short)]) if not locked else ("第%d关（未解锁）" % [i + 1])
	menu_tip.text = "车库三件事：选车身（宽扁稳/高窄灵）→ 横梁上摆轮胎（位置自由、半径可调）→ 满足约束出发"
	_update_status()
	queue_redraw()


func _reset_run() -> void:
	unlocked = 0
	total_time = 0.0
	_go_menu()


func start_level(i: int, restore: bool = false) -> void:
	if i < 0 or i >= LEVELS.size():
		return
	level_idx = i
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + i * 77     # 固定种子：地形每次完全一致（测试与调参可复现）
	ph1 = rng.randf() * TAU
	ph2 = rng.randf() * TAU
	ph3 = rng.randf() * TAU
	wheels = []
	# v2 复制上一版：结算后续玩（重试/下一关）时车库自动预填上次布局（玩家可微调或清空）
	if restore and last_layout_by_level.has(i):
		var saved: Array = last_layout_by_level[i]
		for w in saved:
			wheels.append({xr = float(w.xr), r = float(w.r), pc = 0.0, spin = 0.0, wx = 0.0, wy = 0.0})
	sel_idx = -1
	last_radius = 18.0
	car_pos = Vector2(START_X, BASE_GROUND_Y - 40.0)
	car_angle = 0.0
	omega = 0.0
	vel = Vector2.ZERO
	flight_time = 0.0
	max_speed = 0.0
	max_pitch = 0.0
	airtime_s = 0.0
	bottom_out = 0
	grounded_frames = 0
	drive_frames = 0
	ghost_pts = []
	last_pass = false
	settle_reason = ""
	roof_time = 0.0
	auto_throttle = 0.0
	scroll_x = 0.0
	state = "build"
	menu_panel.visible = false
	settle_panel.visible = false
	final_panel.visible = false
	build_ui.visible = true
	get_viewport().gui_release_focus()
	_update_status()
	queue_redraw()


## 选车身：0 宽扁 / 1 标准 / 2 高窄
func set_body(kind: int) -> void:
	if kind < 0 or kind >= BODIES.size():
		return
	body_kind = kind
	_update_status()
	queue_redraw()


## 放轮胎：x_ratio 0..1（0=车头，1=车尾）。状态不对/超 4 个/x 越界/半径违反本关上限 → false
func add_wheel(x_ratio: float, radius: float) -> bool:
	if state != "build" or wheels.size() >= WHEEL_MAX:
		return false
	if x_ratio < 0.0 or x_ratio > 1.0:
		return false
	var r := clampf(radius, R_MIN, R_MAX)
	var cap: float = float(LEVELS[level_idx].max_r)
	if cap > 0.0 and r > cap:
		return false
	# v3 轮胎总预算：Σπr² ≤ budget（大轮与多轮不可兼得，制造取舍）
	var budget: float = float(LEVELS[level_idx].get("budget", 0.0))
	if budget > 0.0:
		var area_sum := 0.0
		for w in wheels:
			var wr: float = float(w.r)
			area_sum += PI * wr * wr
		if area_sum + PI * r * r > budget:
			return false
	var xr := clampf(x_ratio, 0.03, 0.97)
	wheels.append({xr = xr, r = r, pc = 0.0, spin = 0.0, wx = 0.0, wy = 0.0})
	sel_idx = wheels.size() - 1
	last_radius = r
	_update_status()
	queue_redraw()
	return true


func clear_wheels() -> void:
	wheels = []
	sel_idx = -1
	_update_status()
	queue_redraw()


## 重心偏移 = 轮胎按半径平方加权的平均 x_ratio - 0.5：正 = 偏后（车尾重，起步易翘头），负 = 偏前（易栽头）
func com_offset() -> float:
	var wsum := 0.0
	var acc := 0.0
	for w in wheels:
		var r: float = float(w.r)
		var xr: float = float(w.xr)
		acc += r * r * xr
		wsum += r * r
	if wsum <= 0.0:
		return 0.0
	return acc / wsum - 0.5


func _rear_count() -> int:
	var n := 0
	for w in wheels:
		if float(w.xr) > 0.5:
			n += 1
	return n


func can_launch() -> bool:
	var L: Dictionary = LEVELS[level_idx]
	if wheels.size() < int(L.min_wheels):
		return false
	if _rear_count() < int(L.rear_min):
		return false
	var cap: float = float(L.max_r)
	if cap > 0.0:
		for w in wheels:
			if float(w.r) > cap:
				return false
	return true


## 违规原因（供车库面板提示），合规返回 ""
func launch_block_reason() -> String:
	var L: Dictionary = LEVELS[level_idx]
	if wheels.size() < int(L.min_wheels):
		return "轮胎不足：本关至少 %d 个" % int(L.min_wheels)
	if _rear_count() < int(L.rear_min):
		return "后轮不足：后半段至少 %d 个" % int(L.rear_min)
	var cap: float = float(L.max_r)
	if cap > 0.0:
		for w in wheels:
			if float(w.r) > cap:
				return "轮胎超限：本关半径上限 %d" % int(cap)
	return ""


## 发车：进入 drive 阶段并按当前布局初始化车辆
func do_launch() -> bool:
	if state != "build" or not can_launch():
		return false
	var B: Dictionary = BODIES[body_kind]
	var beam_y: float = float(B.beam_y)
	var n := wheels.size()
	var comp0: float = GRAV / (float(n) * SPRING_K)   # 静止压缩量（每轮平摊重力）
	var r0: float = 18.0
	for w in wheels:
		w.lx = (0.5 - float(w.xr)) * float(B.len)     # xr=0（车头）在局部 +x
		w.ly = beam_y
		w.pc = comp0
		w.spin = 0.0
	r0 = float(wheels[0].r)
	# v2：快照本次布局（结算后写回 last_layout_by_level，下次进库自动预填）
	launch_layout = []
	for w in wheels:
		launch_layout.append({xr = float(w.xr), r = float(w.r)})
	var gy := ground_y(START_X)
	car_pos = Vector2(START_X, gy - beam_y - SUSP_LEN - r0 + comp0)
	car_angle = 0.0
	omega = 0.0
	vel = Vector2.ZERO
	flight_time = 0.0
	max_speed = 0.0
	max_pitch = 0.0
	airtime_s = 0.0
	bottom_out = 0
	grounded_frames = 0
	drive_frames = 0
	ghost_pts = []
	last_pass = false
	settle_reason = ""
	roof_time = 0.0
	auto_throttle = 0.0
	scroll_x = 0.0
	state = "drive"
	build_ui.visible = false
	get_viewport().gui_release_focus()
	_update_status()
	queue_redraw()
	return true


## 测试/教学注入：施加油门 t 秒（满油门，随物理步递减）
func throttle_on(t: float) -> void:
	auto_throttle = maxf(auto_throttle, maxf(0.0, t))


## 结算后继续：过关 → 下一关（最后一关 → 全通关）；翻车 → 就地重试（restore=true 预填上一版布局）
func settle_continue() -> void:
	if state != "settle":
		return
	if last_pass:
		if level_idx >= LEVELS.size() - 1:
			_show_final()
		else:
			start_level(level_idx + 1, true)
	else:
		start_level(level_idx, true)


func _show_settle_panel() -> void:
	var L: Dictionary = LEVELS[level_idx]
	var is_last: bool = level_idx >= LEVELS.size() - 1
	var v2_note: String = "注：对手车与车辆碰撞玩法安排在 v2 版本。"
	var metrics: String = "\n遥测：最大俯仰 %.2f rad · 滞空 %.1f 秒 · 托底 %d 次 · 接地率 %d%%" % [
		max_pitch, airtime_s, bottom_out, int(100.0 * float(grounded_frames) / maxf(1.0, float(drive_frames)))]
	if last_pass:
		settle_title.text = "过关！"
		settle_btn.text = "查看总成绩" if is_last else "下一关"
		settle_body.text = "%s\n用时 %.1f 秒 · 最高速度 %.0f 米/秒 · 终点 %.0f 米%s\n%s" % [
			String(L.name), flight_time, max_speed, float(L.target_m), metrics, v2_note]
	else:
		settle_title.text = "翻车了！"
		settle_btn.text = "就地重试"
		var dist_m: float = (car_pos.x - START_X) / PX_PER_M
		settle_body.text = "%s\n车顶触地超过 %.1f 秒，坚持了 %.1f 秒、跑了 %.0f 米%s。\n轮胎布局影响重心：后重易翘头、前重易栽头，调整布局再来（已自动载入上一版布局）。\n%s" % [
			String(L.name), ROOF_LIMIT, flight_time, dist_m, metrics, v2_note]
	settle_panel.visible = true


func _show_final() -> void:
	state = "final"
	settle_panel.visible = false
	final_body.text = "四关全部跑到终点旗！\n总用时 %.1f 秒 · 最后一关最高速度 %.0f 米/秒\n你的轮胎布局学毕业了——诊断关数据会告诉你哪种车型适合哪种路。\n感谢试玩！" % [
		total_time, max_speed]
	final_panel.visible = true
	_update_status()
	queue_redraw()


func _on_menu_hover(i: int) -> void:
	menu_tip.text = String(LEVELS[i].tip)


# ---------------- 车库交互（点横梁放轮 / 点轮选中 / 滚轮调半径） ----------------

func _rail_x(xr: float) -> float:
	return RAIL_X0 + RAIL_LEN - xr * RAIL_LEN


func _xr_of(px: float) -> float:
	return clampf((RAIL_X0 + RAIL_LEN - px) / RAIL_LEN, 0.03, 0.97)


func _adjust_radius(d: float) -> void:
	if state != "build" or sel_idx < 0 or sel_idx >= wheels.size():
		return
	var w: Dictionary = wheels[sel_idx]
	var cap: float = float(LEVELS[level_idx].max_r)
	var hi: float = R_MAX if cap <= 0.0 else minf(R_MAX, cap)
	var nr: float = clampf(float(w.r) + d, R_MIN, hi)
	w.r = nr
	last_radius = nr
	_update_status()
	queue_redraw()


func _remove_selected() -> void:
	if state != "build" or sel_idx < 0 or sel_idx >= wheels.size():
		return
	wheels.remove_at(sel_idx)
	sel_idx = -1
	_update_status()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if state != "build":
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var pos: Vector2 = mb.position
			var hit := -1
			for i in wheels.size():
				var w: Dictionary = wheels[i]
				var c := Vector2(_rail_x(float(w.xr)), WHEEL_DISP_Y)
				if pos.distance_to(c) <= float(w.r) + 8.0:
					hit = i
					break
			if hit >= 0:
				sel_idx = hit
			elif RAIL_RECT.has_point(pos):
				add_wheel(_xr_of(pos.x), last_radius)
			else:
				sel_idx = -1
			_update_status()
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and sel_idx >= 0:
			_adjust_radius(2.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and sel_idx >= 0:
			_adjust_radius(-2.0)


# ---------------- 主循环 ----------------

func _process(delta: float) -> void:
	pulse += delta * 3.0
	_update_status()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if state == "drive":
		_drive_step(delta)


func _drive_step(dt: float) -> void:
	flight_time += dt
	var B: Dictionary = BODIES[body_kind]
	var blen: float = float(B.len)
	var bh: float = float(B.h)

	# 输入：测试注入优先，其次真实按键（右=油门，左=刹车/倒车）
	var thr := 0.0
	if auto_throttle > 0.0:
		auto_throttle = maxf(0.0, auto_throttle - dt)
		thr = 1.0
	else:
		if Input.is_key_pressed(KEY_RIGHT):
			thr = 1.0
		elif Input.is_key_pressed(KEY_LEFT):
			thr = -1.0

	# 悬挂：每个轮胎对地面做竖直探测，弹簧+阻尼，力作用在锚点（产生力+扭矩）
	var acc := Vector2(0.0, GRAV)
	var torque := 0.0
	var grounded := 0
	for w in wheels:
		var ly: float = float(w.ly)
		var r: float = float(w.r)
		var aw := car_pos + Vector2(float(w.lx), ly).rotated(car_angle)
		var gy := ground_y(aw.x)
		var comp: float = (aw.y + SUSP_LEN + r) - gy
		if comp > 0.0:
			grounded += 1
			comp = minf(comp, MAX_COMP)
			var comp_vel: float = clampf((comp - float(w.pc)) / dt, -2000.0, 2000.0)
			w.pc = comp
			var f: float = SPRING_K * comp + SUSP_DAMP * comp_vel
			f = clampf(f, 0.0, MAX_SUSP_ACC)   # 轮子只能推不能拉
			acc.y -= f
			var rvec := aw - car_pos
			torque += rvec.x * (-f)            # 竖直力对质心的扭矩
			w.wx = aw.x
			w.wy = minf(aw.y + SUSP_LEN, gy - r)
		else:
			w.pc = 0.0
			w.wx = aw.x
			w.wy = aw.y + SUSP_LEN

	# 驱动/刹车：驱动轮 = 最后两个轮胎，力沿地面切向（扭矩只保留一小部分，防满油门后翻）
	var n := wheels.size()
	if thr != 0.0 and grounded > 0:
		var drive0: int = maxi(0, n - 2)
		var dcount := 0
		for k in range(drive0, n):
			var wk: Dictionary = wheels[k]
			if float(wk.pc) > 0.0:
				dcount += 1
		if dcount > 0:
			var mag: float = (DRIVE_ACC if thr > 0.0 else -BRAKE_ACC) / float(dcount)
			for k in range(drive0, n):
				var wd: Dictionary = wheels[k]
				if float(wd.pc) <= 0.0:
					continue
				var wx2: float = float(wd.wx)
				var slope: float = (ground_y(wx2 + 2.0) - ground_y(wx2 - 2.0)) / 4.0
				var fv := Vector2(1.0, slope).normalized() * mag
				acc += fv
				var reff := Vector2(float(wd.lx), float(wd.ly)).rotated(car_angle) * DRIVE_TORQUE_KEEP
				torque += reff.x * fv.y - reff.y * fv.x

	# 风阻（速度平方律）+ 滚动阻力
	var spd := vel.length()
	if spd > 0.01:
		acc += -vel / spd * (DRAG_K * float(B.drag) * spd * spd)
	if grounded > 0 and absf(vel.x) > 4.0:
		acc.x -= signf(vel.x) * ROLL_FRIC

	# v2 遥测六指标采集：max_pitch / airtime / bottom_out / 接地率（finish_time 与 rollover 在结算处）
	drive_frames += 1
	max_pitch = maxf(max_pitch, absf(car_angle))
	if grounded > 0:
		grounded_frames += 1
	else:
		airtime_s += dt
	var bo_now := false
	for w in wheels:
		if float(w.pc) >= MAX_COMP - 0.5:
			bo_now = true
			break
	if bo_now and not was_bottom:
		bottom_out += 1
	was_bottom = bo_now
	ghost_n += 1
	if ghost_n % 6 == 0:
		cur_ghost_pts.append(car_pos)

	# 手写积分（无物理引擎）：线速度 + 角速度
	vel += acc * dt
	if vel.length() > SPEED_MAX:
		vel = vel.normalized() * SPEED_MAX
	var inertia: float = blen * blen / 12.0
	omega += torque / inertia * dt
	omega -= omega * ANG_DAMP * dt
	omega = clampf(omega, -OMEGA_MAX, OMEGA_MAX)
	if grounded == 0 and vel.length() > AIR_ASSIST_MIN_SPD:
		var vd := wrapf(vel.angle() - car_angle, -PI, PI)
		if absf(vd) < 1.75:   # 车头大致朝前才辅助；朝天/翻滚状态不救（保留翻车）
			omega += vd * AIR_ASSIST * dt
	car_pos += vel * dt
	car_angle = wrapf(car_angle + omega * dt, -PI, PI)

	# 车身四角防穿地 + 车顶触地计时（持续 1.5 秒 → 翻车）
	var hl: float = blen * 0.5
	var hh: float = bh * 0.5
	var corners := [Vector2(-hl, -hh), Vector2(hl, -hh), Vector2(-hl, hh), Vector2(hl, hh)]
	var roof_hit := false
	for c in corners:
		var cv: Vector2 = c
		var wp := car_pos + cv.rotated(car_angle)
		var pen: float = wp.y - ground_y(wp.x)
		if pen > -3.0 and cv.y < 0.0:
			roof_hit = true
		if pen > 0.0:
			car_pos.y -= pen
			if cv.y < 0.0:
				vel.y = -absf(vel.y) * 0.08   # 车顶蹭地：减速
				vel.x *= 0.94
			else:
				vel.y = minf(vel.y, 0.0) * -0.12
	if roof_hit:
		roof_time += dt
	else:
		roof_time = maxf(0.0, roof_time - dt * 2.0)
	if roof_time >= ROOF_LIMIT:
		_settle("flip")
		return

	# 轮子自转（纯表现）
	for w in wheels:
		if float(w.pc) > 0.0:
			w.spin = float(w.spin) + vel.x / maxf(float(w.r), 1.0) * dt

	scroll_x = maxf(0.0, car_pos.x - 380.0)
	max_speed = maxf(max_speed, vel.length() / PX_PER_M)
	if car_pos.x >= START_X + float(LEVELS[level_idx].target_m) * PX_PER_M:
		_settle("finish")


func _settle(reason: String) -> void:
	if state != "drive":
		return
	settle_reason = reason
	last_pass = reason == "finish"
	total_time += flight_time
	# v2 记忆：布局/用时/轨迹存档（下次进库预填 + Ghost 回放）
	last_layout_by_level[level_idx] = launch_layout.duplicate(true)
	last_time_by_level[level_idx] = flight_time
	ghost_pts = cur_ghost_pts.duplicate(true)
	if last_pass:
		unlocked = maxi(unlocked, mini(level_idx + 1, LEVELS.size() - 1))
	state = "settle"
	_show_settle_panel()
	_update_status()
	queue_redraw()


# ---------------- 状态栏文案 ----------------

func _update_status() -> void:
	if status_label == null:
		return
	var L: Dictionary = LEVELS[level_idx]
	if state == "menu":
		status_label.text = "赛车模拟器 · 已解锁 %d/%d 关" % [unlocked + 1, LEVELS.size()]
		hint_label.text = "选一关进入车库：摆轮胎定重心，开到终点旗"
	elif state == "build":
		var ok: bool = can_launch()
		status_label.text = "%s · 车库设计：轮胎 %d/%d（后半段 %d 个）· 最大半径 %d · %s" % [
			String(L.name), wheels.size(), WHEEL_MAX, _rear_count(), _max_radius(), "可出发" if ok else "不满足约束"]
		hint_label.text = "点击横梁放轮胎（车头在右，最多 4 个）；点击轮子选中，滚轮或按钮调半径（12~30）；满足约束后点出发"
		if gate_label != null:
			var reason := launch_block_reason()
			gate_label.text = reason if reason != "" else "约束满足，可以出发"
			gate_label.add_theme_color_override("font_color", Color("c62828") if reason != "" else Color("2e7d32"))
		if launch_btn != null:
			launch_btn.disabled = not ok
	elif state == "drive":
		status_label.text = "%s · 速度 %.0f 米/秒 · 里程 %.0f / %.0f 米 · 姿态 %d° · 计时 %.1f 秒" % [
			String(L.name), vel.length() / PX_PER_M, (car_pos.x - START_X) / PX_PER_M,
			float(L.target_m), int(round(rad_to_deg(car_angle))), flight_time]
		hint_label.text = "方向键右 = 油门，左 = 刹车/倒车"
	elif state == "settle":
		if last_pass:
			status_label.text = "过关！用时 %.1f 秒 · 最高速度 %.0f 米/秒" % [flight_time, max_speed]
		else:
			status_label.text = "翻车 · 坚持了 %.1f 秒、跑了 %.0f 米" % [flight_time, (car_pos.x - START_X) / PX_PER_M]
		hint_label.text = ""
	elif state == "final":
		status_label.text = "全通关！三关全部跑到终点"
		hint_label.text = ""


func _max_radius() -> int:
	var mx := 0
	for w in wheels:
		mx = maxi(mx, int(round(float(w.r))))
	return mx


# ---------------- 绘制 ----------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color("bfe3f2"))
	draw_circle(Vector2(830, 70), 30.0, Color("ffe082"))
	_draw_clouds()
	if state == "menu":
		_draw_menu_bg()
		return
	if state == "build":
		_draw_build()
		return
	_draw_world()


func _draw_clouds() -> void:
	var col := Color(1, 1, 1, 0.85)
	for k in 3:
		var cx: float = fmod(pulse * 8.0 + float(k) * 360.0, 1160.0) - 100.0
		var cy: float = 60.0 + 34.0 * float(k % 2)
		draw_circle(Vector2(cx, cy), 15.0, col)
		draw_circle(Vector2(cx + 17.0, cy - 6.0), 12.0, col)
		draw_circle(Vector2(cx - 17.0, cy - 4.0), 11.0, col)


func _draw_menu_bg() -> void:
	# 装饰：地面 + 一辆摆好轮子的展示车
	draw_rect(Rect2(0, 470, VIEW.x, 70), Color("8bbf6a"))
	draw_line(Vector2(0, 470), Vector2(VIEW.x, 470), Color("5d8f42"), 3.0)
	var pts := PackedVector2Array()
	for p in _body_outline(1):
		var pv: Vector2 = p
		pts.append(Vector2(480.0, 452.0) + pv)
	draw_colored_polygon(pts, Color("42a5f5"))
	draw_circle(Vector2(444, 452), 16.0, Color("37474f"))
	draw_circle(Vector2(444, 452), 8.0, Color("b0bec5"))
	draw_circle(Vector2(516, 452), 16.0, Color("37474f"))
	draw_circle(Vector2(516, 452), 8.0, Color("b0bec5"))


func _draw_build() -> void:
	var B: Dictionary = BODIES[body_kind]
	var blen: float = float(B.len)
	var bh: float = float(B.h)
	# 车身按钮说明
	for i in BODIES.size():
		draw_string(FONT, Vector2(142.0 + float(i) * 164.0, 172.0), String(BODIES[i].desc),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("607d8b") if i != body_kind else Color("1e88e5"))
	# 车身预览（车头在右，压在横梁上）
	var sh: float = RAIL_LEN / blen
	var sv: float = minf(2.2, 120.0 / bh)
	var pts := PackedVector2Array()
	for p in _body_outline(body_kind):
		var pv: Vector2 = p
		pts.append(Vector2(380.0 + pv.x * sh, (RAIL_Y - 4.0) + pv.y * sv))
	draw_colored_polygon(pts, Color("42a5f5"))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color("1565c0"), 2.0)
	draw_string(FONT, Vector2(628.0, RAIL_Y - 26.0), "车头", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("2e7d32"))
	draw_string(FONT, Vector2(104.0, RAIL_Y - 26.0), "车尾", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c62828"))
	# 横梁（底盘）
	draw_rect(Rect2(RAIL_X0, RAIL_Y - 4.0, RAIL_LEN, 8.0), Color("546e7a"))
	draw_rect(RAIL_RECT, Color(0.24, 0.31, 0.38, 0.08))
	# 重心标记：几何中心（灰） vs 轮胎加权重心（橙）
	draw_polygon(PackedVector2Array([Vector2(380.0, RAIL_Y - 20.0), Vector2(374.0, RAIL_Y - 8.0), Vector2(386.0, RAIL_Y - 8.0)]),
		PackedColorArray([Color("607d8b")]))
	var off := com_offset()
	var com_x: float = _rail_x(0.5 + off)
	draw_polygon(PackedVector2Array([Vector2(com_x, RAIL_Y - 22.0), Vector2(com_x - 7.0, RAIL_Y - 8.0), Vector2(com_x + 7.0, RAIL_Y - 8.0)]),
		PackedColorArray([Color("ef6c00")]))
	var com_txt: String = "居中"
	if off > 0.05:
		com_txt = "偏后（易翘头）"
	elif off < -0.05:
		com_txt = "偏前（易栽头）"
	draw_string(FONT, Vector2(com_x - 46.0, RAIL_Y + 22.0), com_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ef6c00"))
	# 轮胎
	for i in wheels.size():
		var w: Dictionary = wheels[i]
		var r: float = float(w.r)
		var wxs: float = _rail_x(float(w.xr))
		draw_line(Vector2(wxs, RAIL_Y), Vector2(wxs, WHEEL_DISP_Y - r), Color("455a64"), 3.0)
		draw_circle(Vector2(wxs, WHEEL_DISP_Y), r, Color("37474f"))
		draw_circle(Vector2(wxs, WHEEL_DISP_Y), r * 0.55, Color("eceff1"))
		var spoke := Vector2(r * 0.8, 0.0).rotated(float(w.spin))
		draw_line(Vector2(wxs, WHEEL_DISP_Y), Vector2(wxs, WHEEL_DISP_Y) + spoke, Color("90a4ae"), 2.0)
		if i == sel_idx:
			draw_arc(Vector2(wxs, WHEEL_DISP_Y), r + 5.0, 0.0, TAU, 28, Color("ffb300"), 2.5)
			draw_string(FONT, Vector2(wxs - 10.0, WHEEL_DISP_Y + r + 16.0), "%d" % int(round(r)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e65100"))
	# 右侧约束面板
	var L: Dictionary = LEVELS[level_idx]
	var cap: float = float(L.max_r)
	var lines: Array[String] = [
		String(L.name) + " · 终点 %d 米" % int(float(L.target_m)),
		"本关约束：",
		"轮胎数量 ≥ %d（当前 %d）" % [int(L.min_wheels), wheels.size()],
		("后半段轮胎 ≥ %d（当前 %d）" % [int(L.rear_min), _rear_count()]) if int(L.rear_min) > 0 else "后轮位置不限",
		("轮胎半径 ≤ %d（当前最大 %d）" % [int(cap), _max_radius()]) if cap > 0.0 else "轮胎半径不限",
		"车身：%s · %s" % [String(B.name), String(B.desc)],
		"重心偏移：%+.0f%%（%s）" % [off * 100.0, com_txt],
	]
	var y := 108.0
	for ln in lines:
		draw_string(FONT, Vector2(664.0, y), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("263238"))
		y += 26.0
	draw_string(FONT, Vector2(664.0, y + 8.0), "小贴士：大轮通过性好，小轮重心低；", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("78909c"))
	draw_string(FONT, Vector2(664.0, y + 26.0), "轮子全堆一头会翘头或栽头。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("78909c"))


func _draw_world() -> void:
	var L: Dictionary = LEVELS[level_idx]
	# 地形（屏幕采样，世界坐标减摄像机）
	var surf := PackedVector2Array()
	var fill := PackedVector2Array()
	fill.append(Vector2(0, VIEW.y))
	var sx := 0.0
	while sx <= VIEW.x + 8.0:
		var gy := ground_y(sx + scroll_x)
		surf.append(Vector2(sx, gy))
		fill.append(Vector2(sx, gy))
		sx += 8.0
	fill.append(Vector2(VIEW.x, VIEW.y))
	fill.append(Vector2(0, VIEW.y))
	draw_colored_polygon(fill, Color(String(L.ground)))
	draw_polyline(surf, Color(String(L.ground_dark)), 4.0)
	# 里程标（每 50 米）
	var m := 0
	while m <= int(float(L.target_m)):
		var px: float = START_X + float(m) * PX_PER_M - scroll_x
		if px > -40.0 and px < VIEW.x + 40.0:
			var gy2 := ground_y(START_X + float(m) * PX_PER_M)
			draw_line(Vector2(px, gy2), Vector2(px, gy2 - 12.0), Color(String(L.ground_dark)), 2.0)
			if m % 100 == 0:
				draw_string(FONT, Vector2(px - 18.0, gy2 + 20.0), "%d米" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(String(L.ground_dark)))
		m += 50
	# 起点小旗 + 终点旗
	_draw_flag(START_X, Color("43a047"), "起点")
	_draw_flag(START_X + float(L.target_m) * PX_PER_M, Color("e53935"), "终点")
	# v2 Ghost：上一趟轨迹半透明回放
	if state == "drive" and ghost_pts.size() >= 2:
		var gp := PackedVector2Array()
		for p in ghost_pts:
			var px2: float = float((p as Vector2).x) - scroll_x
			if px2 > -30.0 and px2 < VIEW.x + 30.0:
				gp.append(Vector2(px2, float((p as Vector2).y)))
		if gp.size() >= 2:
			draw_polyline(gp, Color(0.3, 0.5, 0.9, 0.35), 3.0)
	_draw_world_car()
	if state == "drive" and roof_time > 0.15:
		var cx: float = car_pos.x - scroll_x
		draw_string(FONT, Vector2(cx - 90.0, car_pos.y - 70.0), "车顶触地 %.1f / %.1f 秒，快翻了！" % [roof_time, ROOF_LIMIT],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c62828"))
	# v2 HUD：上一趟用时对比
	if state == "drive" and last_time_by_level.has(level_idx):
		var lt: float = float(last_time_by_level[level_idx])
		draw_string(FONT, Vector2(VIEW.x - 240.0, 70.0), "上一趟 %.1f 秒 / 本次 %.1f 秒" % [lt, flight_time],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("37474f"))


func _draw_flag(wx: float, col: Color, txt: String) -> void:
	var fx: float = wx - scroll_x
	if fx < -60.0 or fx > VIEW.x + 60.0:
		return
	var gy := ground_y(wx)
	draw_line(Vector2(fx, gy), Vector2(fx, gy - 120.0), Color("6b4a2f"), 5.0)
	draw_polygon(PackedVector2Array([Vector2(fx, gy - 120.0), Vector2(fx + 42.0, gy - 106.0), Vector2(fx, gy - 92.0)]),
		PackedColorArray([col]))
	draw_string(FONT, Vector2(fx - 16.0, gy - 130.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


func _draw_world_car() -> void:
	var B: Dictionary = BODIES[body_kind]
	var blen: float = float(B.len)
	var cols := ["ef5350", "42a5f5", "66bb6a"]
	# 悬挂 + 轮子
	for w in wheels:
		var r: float = float(w.r)
		var anchor := car_pos + Vector2(float(w.lx), float(w.ly)).rotated(car_angle)
		var a := Vector2(anchor.x - scroll_x, anchor.y)
		var c := Vector2(float(w.wx) - scroll_x, float(w.wy))
		draw_line(a, c, Color("455a64"), 3.0)
		draw_circle(c, r, Color("37474f"))
		draw_circle(c, r * 0.55, Color("eceff1"))
		var spoke := Vector2(r * 0.8, 0.0).rotated(float(w.spin))
		draw_line(c, c + spoke, Color("90a4ae"), 2.0)
	# 车身
	var body_col := Color(String(cols[body_kind]))
	var pts := PackedVector2Array()
	for p in _body_outline(body_kind):
		var pv: Vector2 = p
		pts.append(Vector2(car_pos.x - scroll_x, car_pos.y) + pv.rotated(car_angle))
	draw_colored_polygon(pts, body_col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color("263238"), 2.0)
	# 车窗 + 车灯 + 重心点
	var win := PackedVector2Array()
	for p in [Vector2(-12, -10), Vector2(8, -10), Vector2(14, -4), Vector2(-12, -4)]:
		var pv2: Vector2 = p
		win.append(Vector2(car_pos.x - scroll_x, car_pos.y) + pv2.rotated(car_angle))
	draw_colored_polygon(win, Color("e3f2fd"))
	var nose := Vector2(blen * 0.5 - 5.0, -3.0).rotated(car_angle)
	draw_circle(Vector2(car_pos.x - scroll_x, car_pos.y) + nose, 3.0, Color("fff59d"))
	draw_circle(Vector2(car_pos.x - scroll_x, car_pos.y), 3.0, Color("dd2c00"))


## 车身轮廓（局部坐标：+x 车头，质心在原点）
func _body_outline(kind: int) -> Array:
	if kind == 0:
		return [Vector2(-45, -13), Vector2(28, -13), Vector2(45, -5), Vector2(45, 13), Vector2(-45, 13)]
	if kind == 1:
		return [Vector2(-38, -17), Vector2(6, -17), Vector2(16, -9), Vector2(38, -2), Vector2(38, 17), Vector2(-38, 17)]
	return [Vector2(-32, -22), Vector2(-14, -22), Vector2(-14, -14), Vector2(14, -14), Vector2(26, -5), Vector2(32, -5), Vector2(32, 22), Vector2(-32, 22)]
