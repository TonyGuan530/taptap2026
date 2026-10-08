extends CanvasLayer
## DEMO10 3D 阶段 A：世界 HUD——准星、操作提示、视准目标提示、检查卡、toast、章节卡。
## 只做表现层：toast 文案来自核心信号，检查文本来自 WorldBridge；HUD 不触发任何世界检查，
## 也不显示任何机制信息（盲测安全）。

var crosshair: ColorRect
var hint_label: Label
var target_label: Label
var toast_label: Label
var inspect_panel: Panel
var inspect_title: Label
var inspect_body: Label
var card_panel: Panel
var card_label: Label
var _toast_t := 0.0
var _card_t := 0.0
var _inspect_t := 0.0


func _ready() -> void:
	layer = 5
	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.65)
	crosshair.size = Vector2(4, 4)
	crosshair.position = Vector2(478, 268)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)
	hint_label = _label(Vector2(16, 8), Vector2(700, 20), 12, Color(0.85, 0.87, 0.92, 0.85))
	hint_label.text = "WASD 移动 · 鼠标 环视（点击画面捕获） · E 检查 · Tab 手稿 · Esc 释放鼠标"
	target_label = _label(Vector2(430, 246), Vector2(200, 18), 12, Color("ffd54f"))
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = _label(Vector2(16, 500), Vector2(700, 22), 13, Color("ff8a80"))
	card_panel = Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.07, 0.12, 0.92)
	st.set_corner_radius_all(12)
	card_panel.add_theme_stylebox_override("panel", st)
	card_panel.position = Vector2(280, 190)
	card_panel.size = Vector2(400, 90)
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.visible = false
	add_child(card_panel)
	card_label = Label.new()
	card_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_label.add_theme_font_size_override("font_size", 24)
	card_label.add_theme_color_override("font_color", Color("ffd54f"))
	card_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(card_label)
	inspect_panel = Panel.new()
	var st2 := StyleBoxFlat.new()
	st2.bg_color = Color(0.1, 0.1, 0.15, 0.94)
	st2.set_corner_radius_all(10)
	st2.border_color = Color("5a5470")
	st2.set_border_width_all(1)
	inspect_panel.add_theme_stylebox_override("panel", st2)
	inspect_panel.position = Vector2(230, 380)
	inspect_panel.size = Vector2(500, 110)
	inspect_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect_panel.visible = false
	add_child(inspect_panel)
	inspect_title = Label.new()
	inspect_title.position = Vector2(16, 8)
	inspect_title.add_theme_font_size_override("font_size", 15)
	inspect_title.add_theme_color_override("font_color", Color("ffd54f"))
	inspect_panel.add_child(inspect_title)
	inspect_body = Label.new()
	inspect_body.position = Vector2(16, 34)
	inspect_body.size = Vector2(468, 68)
	inspect_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_body.add_theme_font_size_override("font_size", 13)
	inspect_body.add_theme_color_override("font_color", Color("e8e4d8"))
	inspect_panel.add_child(inspect_body)


func _label(pos: Vector2, size_: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size_
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t = maxf(0.0, _toast_t - delta)
		toast_label.modulate.a = clampf(_toast_t / 1.0, 0.0, 1.0)
		if _toast_t <= 0.0:
			toast_label.text = ""
	if _card_t > 0.0:
		_card_t = maxf(0.0, _card_t - delta)
		card_panel.modulate.a = clampf(_card_t, 0.0, 1.0)
		if _card_t <= 0.0:
			card_panel.visible = false
	if _inspect_t > 0.0:
		_inspect_t = maxf(0.0, _inspect_t - delta)
		inspect_panel.modulate.a = minf(1.0, inspect_panel.modulate.a + delta * 6.0)
		if _inspect_t <= 0.0:
			inspect_panel.visible = false


func show_toast(t: String) -> void:
	toast_label.text = t
	toast_label.modulate.a = 1.0
	_toast_t = 3.0


func show_card(t: String) -> void:
	card_label.text = t
	card_panel.visible = true
	card_panel.modulate.a = 1.0
	_card_t = 1.8


func show_target(title: String) -> void:
	target_label.text = title
	# 准星反馈：有目标=放大+琥珀色，无目标=还原小点（纯表现层，不泄露机制信息）
	var hot := title != ""
	var sz := 7.0 if hot else 4.0
	crosshair.size = Vector2(sz, sz)
	crosshair.position = Vector2(480, 270) - crosshair.size * 0.5
	crosshair.color = Color(1.0, 0.85, 0.4, 0.95) if hot else Color(1, 1, 1, 0.65)


func show_inspect(title: String, text: String) -> void:
	inspect_title.text = title
	inspect_body.text = text
	inspect_panel.visible = true
	inspect_panel.modulate.a = 0.0   # 淡入由 _process 推进
	_inspect_t = 5.0
