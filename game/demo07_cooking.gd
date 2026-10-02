extends Control
## 简单美食小摊（demo-07）：绿幕 00ff00 背景 + ChatGPT 生成美术。
## 按订单点击食材出餐；点错扣时间；90 秒看你能出几单。
## 美术：requirements 流水线由 ChatGPT 生成（纯 00ff00 底，与游戏背景天然融合）。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")
const GAME_TIME := 90.0

## 食材：图集格子（1024x1536，3 行 2 列，每格 512x512）
const ING := [
	{id = "tomato", name = "番茄", cell = Rect2(0, 0, 512, 512)},
	{id = "lettuce", name = "生菜", cell = Rect2(512, 0, 512, 512)},
	{id = "patty", name = "肉饼", cell = Rect2(0, 512, 512, 512)},
	{id = "bun", name = "面包", cell = Rect2(512, 512, 512, 512)},
	{id = "cheese", name = "奶酪", cell = Rect2(0, 1024, 512, 512)},
	{id = "sauce", name = "酱料", cell = Rect2(512, 1024, 512, 512)},
]

var sheet: Texture2D = preload("res://assets/food_sheet.png")
var order := []                # 当前订单的食材 id 序列
var added := []                # 已加到餐盘的
var score := 0
var combo := 0
var time_left := GAME_TIME
var state := "play"
var wrong_flash := 0.0
var pulse := 0.0

var order_box: Control
var plate: Control
var status_label: Label
var end_panel: Panel
var end_body: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#00ff00")
	bg.size = VIEW
	add_child(bg)
	_build_ui()
	_new_order()
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
	title.text = "简单美食小摊（demo-07 · 绿幕版）"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("111111"))
	ui.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(16, 40)
	status_label.size = Vector2(760, 26)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("111111"))
	ui.add_child(status_label)

	# 订单框
	order_box = Panel.new()
	order_box.position = Vector2(340, 80)
	order_box.size = Vector2(280, 120)
	var ob_style := StyleBoxFlat.new()
	ob_style.bg_color = Color(1, 1, 1, 0.92)
	ob_style.set_corner_radius_all(12)
	order_box.add_theme_stylebox_override("panel", ob_style)
	ui.add_child(order_box)
	var ot := Label.new()
	ot.text = "今日订单"
	ot.position = Vector2(12, 6)
	ot.add_theme_font_size_override("font_size", 13)
	ot.add_theme_color_override("font_color", Color("555555"))
	order_box.add_child(ot)

	# 餐盘区
	plate = Control.new()
	plate.position = Vector2(340, 230)
	plate.size = Vector2(280, 130)
	ui.add_child(plate)

	# 食材按钮（单行 6 个，确保 540 高度内完整可见）
	for i in ING.size():
		var cell: Rect2 = ING[i].cell
		var bx := 20 + i * 155
		var by := 395
		var holder := Button.new()
		holder.position = Vector2(bx, by)
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

	# 结算面板
	end_panel = Panel.new()
	end_panel.name = "EndPanel"
	end_panel.position = Vector2(230, 160)
	end_panel.size = Vector2(500, 220)
	var ep_style := StyleBoxFlat.new()
	ep_style.bg_color = Color(1, 1, 1, 0.95)
	ep_style.set_corner_radius_all(14)
	end_panel.add_theme_stylebox_override("panel", ep_style)
	end_panel.visible = false
	ui.add_child(end_panel)
	var et := Label.new()
	et.text = "⏰ 打烊！"
	et.position = Vector2(24, 18)
	et.add_theme_font_size_override("font_size", 24)
	et.add_theme_color_override("font_color", Color("111111"))
	end_panel.add_child(et)
	end_body = Label.new()
	end_body.name = "Body"
	end_body.position = Vector2(24, 64)
	end_body.size = Vector2(452, 90)
	end_body.add_theme_font_size_override("font_size", 16)
	end_body.add_theme_color_override("font_color", Color("333333"))
	end_panel.add_child(end_body)
	var again := Button.new()
	again.text = "再开一摊"
	again.position = Vector2(24, 160)
	again.size = Vector2(150, 38)
	again.pressed.connect(_restart)
	end_panel.add_child(again)


func _new_order() -> void:
	added = []
	# 随机 3~4 种食材组成订单
	var ids := ING.map(func(i): return i.id)
	ids.shuffle()
	order = ids.slice(0, 3 + (randi() % 2))
	for c in order_box.get_children():
		if c is TextureRect:
			c.queue_free()
	# 订单图标
	for k in order.size():
		var ing: Dictionary = ING.filter(func(i): return i.id == order[k])[0]
		var icon := _mk_icon(ing.cell, 62)
		icon.position = Vector2(20 + k * 66, 34)
		order_box.add_child(icon)
	for c in plate.get_children():
		c.queue_free()
	_update_status()


func _update_status() -> void:
	status_label.text = "⏱ %d 秒 · 已出 %d 单 · 连对 %d · 订单 %d/%d" % [
		int(time_left), score, combo, added.size(), order.size()]


func _on_ingredient(i: int) -> void:
	if state != "play":
		return
	var id: String = ING[i].id
	if order.has(id) and added.count(id) < order.count(id):
		added.append(id)
		# 食材落到餐盘
		var icon := _mk_icon(ING[i].cell, 72)
		icon.position = Vector2(20 + (added.size() - 1) * 62, 30)
		plate.add_child(icon)
		combo += 1
		if added.size() == order.size():
			score += 1
			_new_order()
	else:
		combo = 0
		time_left = maxf(1.0, time_left - 4.0)
		wrong_flash = 0.4
	_update_status()


func _restart() -> void:
	score = 0
	combo = 0
	time_left = GAME_TIME
	state = "play"
	end_panel.visible = false
	_new_order()


func _process(delta: float) -> void:
	pulse += delta * 3.0
	wrong_flash = maxf(0.0, wrong_flash - delta)
	if state == "play":
		time_left -= delta
		_update_status()
		if time_left <= 0.0:
			state = "end"
			end_panel.visible = true
			end_body.text = "共出餐 %d 单。\n最高连对 %d 次。\n\n绿幕版：背景与素材底都是 #00ff00，\n后续可以直接抠像换真实场景和真人实拍。" % [score, combo]
	queue_redraw()


func _draw() -> void:
	# 订单框进度描边
	var done_ratio: float = float(added.size()) / order.size() if order.size() > 0 else 0.0
	draw_rect(Rect2(340, 80, 280 * done_ratio, 4), Color("111111"))
	# 错误闪红
	if wrong_flash > 0.0:
		draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(1, 0, 0, wrong_flash * 0.25))
	# 装饰：摊位招牌
	draw_string(FONT, Vector2(16, 78), "🍜 欢迎光临", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("111111"))
