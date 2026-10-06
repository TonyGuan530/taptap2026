extends Control
## Per-finger controls. All actions go through the world's existing physics rules.
signal action_requested(action: String)
signal world_tapped(point: Vector2)
signal touch_detected
var axis := Vector2.ZERO
var touch_enabled := false
var gameplay_enabled := false
var attack_available := false
var climbing := false
var aim_screen := Vector2.ZERO
var has_aim := false
var joystick_finger := -1
var held := {}
var reported_touch := false
const RADIUS := 64.0
const TITLES := {"jump":"跳跃","attack":"挥砍","interact":"交互","notebook":"画纸","reclaim":"回收"}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	hide()

func joystick_center() -> Vector2:
	return Vector2(100,size.y-126)

func action_rect(action: String) -> Rect2:
	var positions := {"jump":Vector2(size.x-98,size.y-144),"attack":Vector2(size.x-198,size.y-144),"interact":Vector2(size.x-298,size.y-144),"notebook":Vector2(size.x-110,size.y-246),"reclaim":Vector2(size.x-226,size.y-246)}
	return Rect2(positions.get(action,Vector2.ZERO),Vector2(84,84) if action in ["jump","attack","interact"] else Vector2(98,76))

func set_touch_enabled(value: bool) -> void:
	touch_enabled = value
	set_gameplay_enabled(gameplay_enabled)

func set_gameplay_enabled(value: bool) -> void:
	gameplay_enabled = value
	visible = touch_enabled and gameplay_enabled
	if not visible and not held.is_empty(): release_all()

func release_all() -> void:
	axis = Vector2.ZERO; joystick_finger = -1; held.clear()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT]: release_all()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not reported_touch:
		reported_touch = true; touch_detected.emit()
	if not visible: return
	if event is InputEventScreenTouch:
		if event.pressed and event.position.y < 96 and not held.has(event.index): return
		_handle_touch(event.index,event.position,event.pressed,event.canceled)
	elif event is InputEventScreenDrag:
		_handle_drag(event.index,event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		# A touchscreen laptop may switch back to its mouse.
		if held.has(-2) or _is_control_point(event.position): _handle_touch(-2,event.position,event.pressed,false)
	elif event is InputEventMouseMotion and held.has(-2): _handle_drag(-2,event.position)

func _is_control_point(point: Vector2) -> bool:
	if point.distance_to(joystick_center()) <= 88: return true
	for action in TITLES:
		if action_rect(action).has_point(point): return true
	return false

func _handle_touch(index: int, point: Vector2, pressed: bool, canceled: bool) -> void:
	if pressed:
		if point.distance_to(joystick_center()) <= 88:
			held[index] = {"kind":"joystick","start":point}
			if joystick_finger == -1: joystick_finger = index; _move_joystick(point)
		else:
			var action := ""
			for candidate in TITLES:
				if action_rect(candidate).has_point(point): action = candidate; break
			held[index] = {"kind":action if action != "" else "world","start":point}
			if action != "":
				if action != "attack" or attack_available: action_requested.emit(action)
			else: aim_screen = point; has_aim = true
	elif held.has(index):
		var entry: Dictionary = held[index]
		if index == joystick_finger: axis = Vector2.ZERO; joystick_finger = -1
		if not canceled and entry.kind == "world" and entry.start.distance_to(point) <= 18:
			aim_screen = point; has_aim = true; world_tapped.emit(point)
		held.erase(index)
	queue_redraw(); get_viewport().set_input_as_handled()

func _handle_drag(index: int, point: Vector2) -> void:
	if not held.has(index): return
	if index == joystick_finger: _move_joystick(point)
	elif held[index].kind == "world": aim_screen = point; has_aim = true
	get_viewport().set_input_as_handled()

func _move_joystick(point: Vector2) -> void:
	axis = ((point-joystick_center())/RADIUS).limit_length(1.0)
	if axis.length()<0.10: axis = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	if not touch_enabled: return
	var ink := Color("294c50")
	var paper := Color("f4e8ce",0.88)
	var font := get_theme_default_font()
	var centre := joystick_center()
	draw_circle(centre,88,Color("243f43",0.16))
	draw_circle(centre,RADIUS,paper); draw_arc(centre,RADIUS,0,TAU,48,ink,3,true)
	draw_circle(centre+axis*44,26,Color("789d91")); draw_arc(centre+axis*44,26,0,TAU,32,ink,2,true)
	draw_string(font,centre+Vector2(-47,100),"上下攀爬" if climbing else "移动",HORIZONTAL_ALIGNMENT_CENTER,94,19,ink)
	for action in TITLES:
		var rect := action_rect(action)
		var disabled: bool = action == "attack" and not attack_available
		var pressed := false
		for entry in held.values():
			if entry.kind == action: pressed = true
		var style := StyleBoxFlat.new()
		style.bg_color = Color("a0b9a8",0.96) if pressed else paper
		style.border_color = Color("94a69c") if disabled else ink
		style.set_border_width_all(2); style.set_corner_radius_all(14)
		style.draw(get_canvas_item(),rect)
		var title: String = "离梯" if action == "jump" and climbing else TITLES[action]
		draw_string(font,rect.position+Vector2(0,rect.size.y/2+7),title,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,22,Color("7f918b") if disabled else ink)

func snapshot() -> Dictionary:
	var actions := {}
	for action in TITLES:
		var rect := action_rect(action)
		actions[action] = [rect.get_center().x,rect.get_center().y]
	return {"enabled":touch_enabled,"visible":visible,"axis":[axis.x,axis.y],"fingers":held.size(),"joystick":[joystick_center().x,joystick_center().y],"actions":actions}
