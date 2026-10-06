extends Control
## Additive ink strokes. Mouse release ends one stroke, never creates a connector.
signal stroke_changed
const MAX_STROKES := 24
const MAX_POINTS := 256
var strokes: Array = []
var drawing := false
var touch_finger := -1
var ink_color := Color("263844")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	queue_redraw()

func get_strokes() -> Array:
	return strokes.duplicate(true)

func set_strokes(value: Array) -> void:
	strokes = value.duplicate(true)
	drawing = false
	touch_finger = -1
	stroke_changed.emit(); queue_redraw()

func begin_stroke(point: Vector2) -> void:
	if strokes.size() >= MAX_STROKES: return
	strokes.append(PackedVector2Array([point.clamp(Vector2.ZERO,size)]))
	drawing = true
	stroke_changed.emit(); queue_redraw()

func append_point(point: Vector2) -> void:
	if not drawing or strokes.is_empty(): return
	var last: PackedVector2Array = strokes[-1]
	point = point.clamp(Vector2.ZERO,size)
	if last.size() >= MAX_POINTS or last[-1].distance_to(point) < 2.0: return
	last.append(point); strokes[-1] = last
	stroke_changed.emit(); queue_redraw()

func end_stroke() -> void:
	drawing = false
	touch_finger = -1
	stroke_changed.emit(); queue_redraw()

func undo_stroke() -> void:
	drawing = false
	touch_finger = -1
	if not strokes.is_empty(): strokes.pop_back()
	stroke_changed.emit(); queue_redraw()

func clear_drawing() -> void:
	drawing = false; touch_finger = -1; strokes.clear()
	stroke_changed.emit(); queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if touch_finger >= 0:
		accept_event(); return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: begin_stroke(event.position)
		else: end_stroke()
		accept_event()
	elif event is InputEventMouseMotion and drawing:
		append_point(event.position); accept_event()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
		if event.pressed and Rect2(Vector2.ZERO,size).has_point(point):
			if touch_finger < 0 and not drawing:
				touch_finger = event.index; begin_stroke(point)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == touch_finger:
			end_stroke(); get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_finger:
		append_point(get_global_transform_with_canvas().affine_inverse()*event.position)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT] and drawing: end_stroke()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("f9eed8"))
	for x in range(0,int(size.x),40): draw_line(Vector2(x,0),Vector2(x,size.y),Color("dacdb5",0.35))
	for y in range(0,int(size.y),40): draw_line(Vector2(0,y),Vector2(size.x,y),Color("dacdb5",0.35))
	for stroke in strokes:
		if stroke.size() > 1: draw_polyline(stroke,ink_color,4.0,true)
		if not stroke.is_empty():
			draw_circle(stroke[0],4,Color("d69d53"))
			draw_circle(stroke[-1],3,ink_color)
