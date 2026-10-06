extends Control
## A real mouse-drawn contour; a new stroke replaces the previous contour.
signal stroke_changed
var points := PackedVector2Array()
var drawing := false
var pen_color := Color("66d0bd")

func _ready() -> void:
	custom_minimum_size = Vector2(420, 260)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func clear_drawing() -> void:
	points.clear()
	drawing = false
	queue_redraw()
	stroke_changed.emit()

func set_points(value: PackedVector2Array) -> void:
	points = value.duplicate()
	queue_redraw()
	stroke_changed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drawing = event.pressed
		if drawing:
			points = PackedVector2Array([event.position.clamp(Vector2.ONE * 8, size - Vector2.ONE * 8)])
		else:
			stroke_changed.emit()
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and drawing:
		var point: Vector2 = event.position.clamp(Vector2.ONE * 8, size - Vector2.ONE * 8)
		if points.size() < 256 and (points.is_empty() or points[-1].distance_to(point) > 4.0):
			points.append(point)
			queue_redraw()
		accept_event()

func _draw() -> void:
	draw_style_box(_paper_style(), Rect2(Vector2.ZERO, size))
	for x in range(20, int(size.x), 20):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.23, 0.50, 0.47, 0.10))
	for y in range(20, int(size.y), 20):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.23, 0.50, 0.47, 0.10))
	if points.size() >= 3:
		var triangles := Geometry2D.triangulate_polygon(points)
		if not triangles.is_empty():
			draw_colored_polygon(points, Color(pen_color, 0.25))
	if points.size() >= 2:
		draw_polyline(points, pen_color.darkened(0.25), 4.0, true)
		if not drawing and points.size() >= 3:
			draw_line(points[-1], points[0], pen_color.darkened(0.25), 3.0, true)
	if not points.is_empty():
		draw_circle(points[0], 5.0, Color("ed967e"))

func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f0e8d3")
	style.set_corner_radius_all(10)
	return style
