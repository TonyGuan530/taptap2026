extends Control
## 简单美食小摊（demo-07 v2）：四关卡版，绿幕 00ff00 背景 + ChatGPT 生成美术。
## 关卡阶梯（扩展阶梯·补充关卡）：
##   L1 开摊首日（3 料单，熟悉出餐）→ L2 熟客上门（3~4 料）→
##   L3 午餐高峰（双订单并发，自己排产）→ L4 美食节评委（催单耐心环，跑单扣时）
## 规则核心不变：照订单点食材，点满即出餐；点错扣时间断连击。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")

## 食材：图集格子（1024x1536，3 行 2 列，每格 512x512）
const ING := [
	{id = "tomato", name = "番茄", cell = Rect2(0, 0, 512, 512)},
	{id = "lettuce", name = "生菜", cell = Rect2(512, 0, 512, 512)},
	{id = "patty", name = "肉饼", cell = Rect2(0, 512, 512, 512)},
	{id = "bun", name = "面包", cell = Rect2(512, 512, 512, 512)},
	{id = "cheese", name = "奶酪", cell = Rect2(0, 1024, 512, 512)},
	{id = "sauce", name = "酱料", cell = Rect2(512, 1024, 512, 512)},
]

## 关卡配置：omin/omax=订单食材数；twin=双订单并发；rush=催单耐心环；
## target=限时出餐目标；penalty=点错扣秒；patience=每单耐心秒数（rush 关）
const LEVELS := [
	{name = "关卡 1 · 开摊首日", time = 60.0, omin = 3, omax = 3, twin = false, rush = false, target = 5, penalty = 3.0, patience = 0.0,
		tip = "熟悉出餐：照订单点食材，点满自动出餐开下一单"},
	{name = "关卡 2 · 熟客上门", time = 60.0, omin = 3, omax = 4, twin = false, rush = false, target = 7, penalty = 4.0,
		patience = 0.0, tip = "订单变大：3~4 种食材，点错扣的时间更多"},
	{name = "关卡 3 · 午餐高峰", time = 70.0, omin = 4, omax = 4, twin = true, rush = false, target = 8, penalty = 5.0,
		patience = 0.0, tip = "双订单并发：两单共用的食材，点一次同时上两单"},
	{name = "关卡 4 · 美食节评委", time = 75.0, omin = 4, omax = 5, twin = true, rush = true, target = 10, penalty = 6.0,
		patience = 30.0, tip = "评委催单：订单带耐心环，耗尽即跑单（断连+扣 5 秒）"},
	{name = "实验房 · 合单之谜", time = 120.0, omin = 0, omax = 0, twin = true, rush = false, target = 16, penalty = 5.0,
		patience = 0.0, tip = "v3 实验：8 组固定双订单（部分共用食材）。共用食材点一次两单齐进——把同料订单排在一起做更省手速"},
]

## 实验房专用：8 组人工设计双订单（[单A食材, 单B食材]）——共享度从高到低混合
## 验证问题：玩家是否会主动发现并利用「合单」（一次点击推进两单），而不是单纯点得更快
const EXPERIMENT_PAIRS := [
	[["bun", "patty", "sauce"], ["bun", "lettuce", "cheese"]],      # 共享 1：面包
	[["bun", "patty"], ["bun", "patty", "cheese"]],                # 子集：面包+肉饼
	[["tomato", "lettuce"], ["tomato", "lettuce", "sauce"]],       # 子集：番茄+生菜
	[["bun", "patty", "sauce"], ["tomato", "lettuce", "cheese"]],  # 零共享
	[["cheese", "sauce"], ["tomato", "patty"]],                    # 零共享
	[["bun", "tomato", "sauce"], ["bun", "sauce", "cheese"]],      # 共享 2：面包+酱料
	[["patty", "lettuce"], ["patty", "sauce", "tomato"]],          # 共享 1：肉饼
	[["bun", "patty", "cheese", "sauce"], ["bun", "cheese"]],      # 子集：面包+奶酪
]

const RUSH_LOSS := 5.0   # 跑单额外扣秒（penalty 之外）

var sheet: Texture2D = preload("res://assets/food_sheet.png")
var level_idx := 0
var unlocked := 0              # 本次会话已通关的最高关（索引），<=unlocked 可选
var orders := []               # Array[Dictionary]：{items=[id], added=[id], patience=float}
var score := 0
var combo := 0
var time_left := 60.0
var state := "menu"            # menu / play / clear / end
var wrong_flash := 0.0
var served_total := 0
# v3 实验房遥测：总点击 / 合单利用（一次点击推进 ≥2 单的次数）/ 跑单数
var clicks_total := 0
var merge_hits := 0
var rush_outs := 0
var order_queue := []          # 实验房固定订单序列
var queue_pos := 0

var order_boxes := []          # 两块订单框（twin 关两块齐开）
var plate: Control
var status_label: Label
var menu_panel: Panel
var menu_tip: Label
var level_buttons := []
var end_panel: Panel
var end_title: Label
var end_body: Label
var btn_next: Button
var btn_retry: Button
var btn_menu: Button
var box_single := Vector2(340, 80)
var box_twin := [Vector2(150, 80), Vector2(530, 80)]


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#00ff00")
	bg.size = VIEW
	add_child(bg)
	_build_ui()
	_go_menu()
	queue_redraw()


func _mk_icon(cell: Rect2, size: float) -> TextureRect:
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = cell
	var tr := TextureRect.new()
	tr.texture = at
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = Vector2(size, size)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "简单美食小摊（demo-07 v3 · 绿幕版 · 四关卡+实验房）"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("111111"))
	ui.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(16, 40)
	status_label.size = Vector2(900, 26)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("111111"))
	ui.add_child(status_label)

	# 订单框 ×2（单订单关只显示第一块并居中）
	for k in 2:
		var ob := Panel.new()
		ob.name = "OrderBox%d" % k
		ob.size = Vector2(280, 120)
		var ob_style := StyleBoxFlat.new()
		ob_style.bg_color = Color(1, 1, 1, 0.92)
		ob_style.set_corner_radius_all(12)
		ob.add_theme_stylebox_override("panel", ob_style)
		ui.add_child(ob)
		order_boxes.append(ob)
		var ot := Label.new()
		ot.text = "订单 %d" % (k + 1)
		ot.name = "Title"
		ot.position = Vector2(12, 6)
		ot.add_theme_font_size_override("font_size", 13)
		ot.add_theme_color_override("font_color", Color("555555"))
		ob.add_child(ot)

	# 餐盘区（跟当前单走）
	plate = Control.new()
	plate.name = "Plate"
	plate.position = Vector2(340, 230)
	plate.size = Vector2(280, 130)
	ui.add_child(plate)

	# 食材按钮（单行 6 个，确保 540 高度内完整可见）
	for i in ING.size():
		var cell: Rect2 = ING[i].cell
		var holder := Button.new()
		holder.position = Vector2(20 + i * 155, 395)
		holder.size = Vector2(148, 125)
		holder.flat = true
		holder.pressed.connect(_on_ingredient.bind(i))
		ui.add_child(holder)
		var icon := _mk_icon(cell, 100)
		icon.position = Vector2(10, 5)
		holder.add_child(icon)
		var nm := Label.new()
		nm.text = ING[i].name
		nm.position = Vector2(0, 92)
		nm.size = Vector2(120, 20)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 14)
		nm.add_theme_color_override("font_color", Color("111111"))
		holder.add_child(nm)

	# 选关面板
	menu_panel = Panel.new()
	menu_panel.name = "MenuPanel"
	menu_panel.position = Vector2(200, 130)
	menu_panel.size = Vector2(560, 270)
	var mp_style := StyleBoxFlat.new()
	mp_style.bg_color = Color(1, 1, 1, 0.95)
	mp_style.set_corner_radius_all(14)
	menu_panel.add_theme_stylebox_override("panel", mp_style)
	ui.add_child(menu_panel)
	var mt := Label.new()
	mt.text = "选关开摊（5 关）"
	mt.position = Vector2(24, 14)
	mt.add_theme_font_size_override("font_size", 22)
	mt.add_theme_color_override("font_color", Color("111111"))
	menu_panel.add_child(mt)
	for i in LEVELS.size():
		var lb := Button.new()
		lb.name = "LevelBtn%d" % i
		lb.text = "第%d关" % (i + 1)
		lb.position = Vector2(24 + i * 104, 60)
		lb.size = Vector2(96, 44)
		lb.pressed.connect(start_level.bind(i))
		lb.mouse_entered.connect(_on_menu_hover.bind(i))
		menu_panel.add_child(lb)
		level_buttons.append(lb)
	menu_tip = Label.new()
	menu_tip.name = "MenuTip"
	menu_tip.position = Vector2(24, 118)
	menu_tip.size = Vector2(512, 60)
	menu_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_tip.add_theme_font_size_override("font_size", 14)
	menu_tip.add_theme_color_override("font_color", Color("333333"))
	menu_panel.add_child(menu_tip)
	var hint := Label.new()
	hint.text = "通关解锁下一关 · 打烊前完成目标单数即过关"
	hint.position = Vector2(24, 224)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("777777"))
	menu_panel.add_child(hint)

	# 结算面板（过关/打烊共用）
	end_panel = Panel.new()
	end_panel.name = "EndPanel"
	end_panel.position = Vector2(230, 150)
	end_panel.size = Vector2(500, 230)
	var ep_style := StyleBoxFlat.new()
	ep_style.bg_color = Color(1, 1, 1, 0.95)
	ep_style.set_corner_radius_all(14)
	end_panel.add_theme_stylebox_override("panel", ep_style)
	end_panel.visible = false
	ui.add_child(end_panel)
	end_title = Label.new()
	end_title.name = "EndTitle"
	end_title.position = Vector2(24, 16)
	end_title.add_theme_font_size_override("font_size", 24)
	end_title.add_theme_color_override("font_color", Color("111111"))
	end_panel.add_child(end_title)
	end_body = Label.new()
	end_body.name = "Body"
	end_body.position = Vector2(24, 62)
	end_body.size = Vector2(452, 96)
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_body.add_theme_font_size_override("font_size", 16)
	end_body.add_theme_color_override("font_color", Color("333333"))
	end_panel.add_child(end_body)
	btn_next = Button.new()
	btn_next.name = "NextBtn"
	btn_next.text = "下一关 ▶"
	btn_next.position = Vector2(24, 172)
	btn_next.size = Vector2(140, 40)
	btn_next.pressed.connect(func() -> void: start_level(level_idx + 1))
	end_panel.add_child(btn_next)
	btn_retry = Button.new()
	btn_retry.name = "RetryBtn"
	btn_retry.text = "再来一次"
	btn_retry.position = Vector2(178, 172)
	btn_retry.size = Vector2(140, 40)
	btn_retry.pressed.connect(func() -> void: start_level(level_idx))
	end_panel.add_child(btn_retry)
	btn_menu = Button.new()
	btn_menu.name = "MenuBtn"
	btn_menu.text = "返回选关"
	btn_menu.position = Vector2(332, 172)
	btn_menu.size = Vector2(140, 40)
	btn_menu.pressed.connect(_go_menu)
	end_panel.add_child(btn_menu)


func _on_menu_hover(i: int) -> void:
	menu_tip.text = LEVELS[i].tip


func _go_menu() -> void:
	state = "menu"
	end_panel.visible = false
	menu_panel.visible = true
	plate_visible(false)
	for k in 2:
		order_boxes[k].visible = false
	for i in level_buttons.size():
		var lb: Button = level_buttons[i]
		var locked: bool = i > unlocked
		lb.disabled = locked
		lb.text = ("第%d关（未解锁）" % (i + 1)) if locked else ("第%d关 %s" % [i + 1, _lv_short(i)])
	menu_tip.text = LEVELS[mini(unlocked, LEVELS.size() - 1)].tip
	_update_status()


func _lv_short(i: int) -> String:
	var n: String = LEVELS[i].name
	var bits := n.split("·")
	return bits[bits.size() - 1].strip_edges() if bits.size() > 1 else n


func plate_visible(v: bool) -> void:
	plate.visible = v


func start_level(i: int) -> void:
	if i >= LEVELS.size() or i > unlocked:
		return
	level_idx = i
	var L: Dictionary = LEVELS[i]
	time_left = L.time
	score = 0
	combo = 0
	served_total = 0
	clicks_total = 0
	merge_hits = 0
	rush_outs = 0
	orders = []
	order_queue = []
	queue_pos = 0
	if i == LEVELS.size() - 1 and L.omin == 0:
		# 实验房：装载 8 组固定双订单（16 单按序出）
		for pair in EXPERIMENT_PAIRS:
			order_queue.append(pair[0])
			order_queue.append(pair[1])
	var count: int = 2 if L.twin else 1
	for k in count:
		orders.append(_make_order())
	state = "play"
	menu_panel.visible = false
	end_panel.visible = false
	plate_visible(true)
	_layout_boxes()
	_refresh_boxes()
	_refresh_plate()
	_update_status()


func _layout_boxes() -> void:
	var twin: bool = LEVELS[level_idx].twin
	for k in 2:
		var ob: Panel = order_boxes[k]
		ob.position = box_twin[k] if twin else box_single
		ob.visible = k == 0 or twin


func _make_order() -> Dictionary:
	var L: Dictionary = LEVELS[level_idx]
	if order_queue.size() > 0 and queue_pos < order_queue.size():
		var items: Array = order_queue[queue_pos]
		queue_pos += 1
		return {items = items.duplicate(), added = [], patience = L.patience}
	var ids := ING.map(func(g): return g.id)
	ids.shuffle()
	var n: int = randi_range(L.omin, L.omax)
	return {items = ids.slice(0, n), added = [], patience = L.patience}


func _active_idx() -> int:
	for k in orders.size():
		var o: Dictionary = orders[k]
		var added: Array = o.added
		if added.size() < (o.items as Array).size():
			return k
	return -1


func _refresh_boxes() -> void:
	for k in 2:
		var ob: Panel = order_boxes[k]
		for c in ob.get_children():
			if c is TextureRect:
				c.queue_free()
		if k >= orders.size():
			continue
		var items: Array = orders[k].items
		for j in items.size():
			var ing: Dictionary = ING.filter(func(g): return g.id == items[j])[0]
			var icon := _mk_icon(ing.cell, 62)
			icon.position = Vector2(20 + j * 64, 36)
			ob.add_child(icon)
		# 已加的打勾
		var added: Array = orders[k].added
		for a in added:
			var j2 := items.find(a)
			if j2 >= 0:
				var tick := Label.new()
				tick.text = "✓"
				tick.position = Vector2(38 + j2 * 64, 30)
				tick.add_theme_font_size_override("font_size", 30)
				tick.add_theme_color_override("font_color", Color("1b7f2e"))
				ob.add_child(tick)


func _refresh_plate() -> void:
	for c in plate.get_children():
		c.queue_free()
	var ai := _active_idx()
	if ai < 0:
		return
	var added: Array = orders[ai].added
	for j in added.size():
		var ing: Dictionary = ING.filter(func(g): return g.id == added[j])[0]
		var icon := _mk_icon(ing.cell, 72)
		icon.position = Vector2(20 + j * 62, 30)
		plate.add_child(icon)


func _update_status() -> void:
	if state == "menu":
		status_label.text = "绿幕小摊：选一关开张吧（已通关 %d 关）" % unlocked
		return
	var L: Dictionary = LEVELS[level_idx]
	status_label.text = "%s · 剩 %d 秒 · 出餐 %d/%d · 连对 %d" % [
		L.name, int(time_left), score, L.target, combo]


func _on_ingredient(i: int) -> void:
	if state != "play":
		return
	var id: String = ING[i].id
	clicks_total += 1
	# v3 共享食材批处理：一次点击推进所有需要该食材的订单（各按剩余需求量）
	var advanced := 0
	var done := []
	for k in orders.size():
		var o: Dictionary = orders[k]
		var items: Array = o.items
		var added: Array = o.added
		if items.has(id) and added.count(id) < items.count(id):
			added.append(id)
			advanced += 1
			if added.size() == items.size():
				done.append(k)
	if advanced >= 2:
		merge_hits += 1
	if advanced == 0:
		combo = 0
		time_left = maxf(1.0, time_left - LEVELS[level_idx].penalty)
		wrong_flash = 0.4
	else:
		combo += 1
		if done.size() > 0:
			score += done.size()
			served_total += done.size()
			var L: Dictionary = LEVELS[level_idx]
			if score >= int(L.target):
				_win()
				return
			for k in done:
				orders[k] = _make_order()
	_refresh_boxes()
	_refresh_plate()
	_update_status()


func _rush_tick(delta: float) -> void:
	var L: Dictionary = LEVELS[level_idx]
	for k in orders.size():
		var o: Dictionary = orders[k]
		var added: Array = o.added
		if added.size() >= (o.items as Array).size():
			continue
		o.patience = maxf(0.0, o.patience - delta)
		if o.patience <= 0.0:
			orders[k] = _make_order()
			rush_outs += 1
			combo = 0
			time_left = maxf(1.0, time_left - RUSH_LOSS)
			wrong_flash = 0.3
			_refresh_boxes()
			_refresh_plate()


func _win() -> void:
	state = "clear"
	unlocked = maxi(unlocked, mini(level_idx + 1, LEVELS.size() - 1))
	var used: float = LEVELS[level_idx].time - time_left
	end_title.text = "过关！"
	end_body.text = "%s 出餐 %d 单达标，用时 %d 分 %d 秒。\n剩余 %d 秒。\n—— 本局遥测：总点击 %d · 合单利用 %d · 跑单 %d ——\n绿幕版：背景与素材底都是 #00ff00，后续直接抠像换真实场景。" % [
		LEVELS[level_idx].name, score, int(used) / 60, int(used) % 60, int(time_left), clicks_total, merge_hits, rush_outs]
	btn_next.visible = level_idx < LEVELS.size() - 1
	end_panel.visible = true
	_update_status()


func _lose() -> void:
	state = "end"
	var L: Dictionary = LEVELS[level_idx]
	end_title.text = "打烊！"
	end_body.text = "差 %d 单达标（%d/%d）。\n最高连对 %d 次。\n—— 本局遥测：总点击 %d · 合单利用 %d · 跑单 %d ——\n小提示：%s" % [
		int(L.target) - score, score, L.target, combo, clicks_total, merge_hits, rush_outs, L.tip]
	btn_next.visible = false
	end_panel.visible = true
	_update_status()


func _process(delta: float) -> void:
	wrong_flash = maxf(0.0, wrong_flash - delta)
	if state == "play":
		time_left -= delta
		if LEVELS[level_idx].rush:
			_rush_tick(delta)
		_update_status()
		if time_left <= 0.0:
			time_left = 0.0
			_lose()
	queue_redraw()


func _draw() -> void:
	if state == "play" or state == "clear" or state == "end":
		# 每块订单框的进度描边 + 催单耐心环
		for k in orders.size():
			var ob: Panel = order_boxes[k]
			if not ob.visible:
				continue
			var o: Dictionary = orders[k]
			var items: Array = o.items
			var ratio: float = float((o.added as Array).size()) / items.size() if items.size() > 0 else 0.0
			draw_rect(Rect2(ob.position.x, ob.position.y, 280 * ratio, 4), Color("111111"))
			if LEVELS[level_idx].rush and o.patience > 0.0:
				var r: float = o.patience / LEVELS[level_idx].patience
				var col := Color("1b7f2e").lerp(Color("d84315"), 1.0 - r)
				var c := ob.position + Vector2(262, 22)
				draw_arc(c, 12, -PI / 2, -PI / 2 + TAU * r, 24, col, 4.0)
				draw_string(FONT, c + Vector2(-8, 7), "%d" % int(ceil(o.patience)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("111111"))
	if wrong_flash > 0.0:
		draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(1, 0, 0, wrong_flash * 0.25))
	draw_string(FONT, Vector2(16, 78), "欢迎光临", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("111111"))
