extends Node2D
## 示例小游戏「点点大作战」：30 秒内点击下落的圆点得分，漏掉会扣时间。
## 纯代码实现、无外部资源，方便直接验证 Web 导出流水线。
## 正式开发时替换本场景即可，Review 站点与导出脚本无需改动。

const GAME_TIME := 30.0
const SPAWN_INTERVAL := 0.65
const VIEW_W := 960.0
const BOTTOM_Y := 585.0
const MISS_PENALTY := 1.5
const COLORS: Array[Color] = [
	Color("478cbf"), Color("ff7043"), Color("66bb6a"),
	Color("ab47bc"), Color("ffd54f"), Color("ef5350"),
]

var score := 0
var time_left := GAME_TIME
var playing := false
var spawn_cooldown := 0.0
var rng := RandomNumberGenerator.new()

var score_label: Label
var time_label: Label
var overlay: Control
var overlay_title: Label
var overlay_hint: Label
var start_button: Button


## 圆点：会呼吸缩放的小球，被点到后播放消失动画
class Dot extends Node2D:
	var radius := 26.0
	var speed := 160.0
	var col := Color.WHITE
	var phase := randf() * TAU

	func _process(delta: float) -> void:
		phase += delta * 6.0
		queue_redraw()

	func _draw() -> void:
		var wobble := 1.0 + sin(phase) * 0.05
		draw_circle(Vector2.ZERO, radius * wobble, col)
		draw_circle(Vector2(-radius * 0.3, -radius * 0.32), radius * 0.26, Color(1, 1, 1, 0.4))


func _ready() -> void:
	rng.randomize()
	_build_ui()
	_show_overlay("点点大作战", "30 秒内点掉尽量多的圆点，漏掉会扣时间", "开始游戏")


func _draw() -> void:
	# 底部危险线（圆点越过它就算漏掉）
	draw_line(Vector2(0, 540), Vector2(VIEW_W, 540), Color(1, 1, 1, 0.08), 2.0)


func _process(delta: float) -> void:
	if not playing:
		return
	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		spawn_cooldown = SPAWN_INTERVAL * rng.randf_range(0.7, 1.3)
		_spawn_dot()
	var dots := get_children().filter(func(c): return c is Dot)
	for dot in dots:
		dot.position.y += dot.speed * delta
		if dot.position.y > BOTTOM_Y:
			dot.queue_free()
			time_left = maxf(0.0, time_left - MISS_PENALTY)
	time_left -= delta
	_update_hud()
	if time_left <= 0.0:
		_end_game()


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_pop(get_global_mouse_position())


# ---------- 游戏逻辑 ----------

func _spawn_dot() -> void:
	var dot := Dot.new()
	dot.radius = rng.randf_range(20.0, 34.0)
	# 越到后面下落越快，制造紧张感
	dot.speed = rng.randf_range(120.0, 240.0) + (GAME_TIME - time_left) * 3.0
	dot.col = COLORS[rng.randi() % COLORS.size()]
	dot.position = Vector2(rng.randf_range(50.0, VIEW_W - 50.0), -40.0)
	add_child(dot)


func _try_pop(pos: Vector2) -> void:
	var dots := get_children().filter(func(c): return c is Dot)
	# 从最上层（最后绘制的）开始判定
	for i in range(dots.size() - 1, -1, -1):
		var dot: Dot = dots[i]
		if pos.distance_to(dot.position) <= dot.radius + 6.0:
			score += 1
			_update_hud()
			_pop_animation(dot)
			return


func _pop_animation(dot: Dot) -> void:
	dot.set_process(false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dot, "scale", Vector2(1.5, 1.5), 0.12)
	tw.tween_property(dot, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(dot.queue_free)


func _start_game() -> void:
	score = 0
	time_left = GAME_TIME
	spawn_cooldown = 0.0
	for dot in get_children().filter(func(c): return c is Dot):
		dot.queue_free()
	overlay.visible = false
	playing = true
	_update_hud()


func _end_game() -> void:
	playing = false
	_show_overlay("时间到！", "本局得分：%d" % score, "再来一局")


# ---------- UI ----------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 24)
	top.add_theme_constant_override("margin_right", 24)
	top.add_theme_constant_override("margin_top", 14)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	top.add_child(hbox)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 30)
	hbox.add_child(score_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 30)
	hbox.add_child(time_label)

	ui.add_child(top)

	overlay = _build_overlay(ui)
	ui.add_child(overlay)


func _build_overlay(ui: CanvasLayer) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.name = "Overlay"

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.94)
	style.set_corner_radius_all(18)
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	style.border_color = Color("478cbf")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	overlay_title = Label.new()
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 42)
	vbox.add_child(overlay_title)

	overlay_hint = Label.new()
	overlay_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_hint.add_theme_font_size_override("font_size", 18)
	overlay_hint.modulate = Color(1, 1, 1, 0.65)
	vbox.add_child(overlay_hint)

	start_button = Button.new()
	start_button.text = "开始游戏"
	start_button.custom_minimum_size = Vector2(220, 54)
	start_button.add_theme_font_size_override("font_size", 26)
	start_button.pressed.connect(_start_game)
	vbox.add_child(start_button)

	return center


func _show_overlay(title_text: String, hint_text: String, button_text: String) -> void:
	overlay_title.text = title_text
	overlay_hint.text = hint_text
	start_button.text = button_text
	overlay.visible = true


func _update_hud() -> void:
	score_label.text = "得分 %d" % score
	time_label.text = "%.1f s" % maxf(0.0, time_left)
	if time_left < 10.0:
		time_label.add_theme_color_override("font_color", Color("ef5350"))
	else:
		time_label.remove_theme_color_override("font_color")
