extends "res://v8/ink_draw_pad.gd"
## Immediate sampling feedback. Does not alter or classify the user's geometry.
var cursor := Vector2.ZERO
var hovering := false

func _ready() -> void:
	super._ready()
	mouse_entered.connect(func(): hovering = true; queue_redraw())
	mouse_exited.connect(func(): hovering = false; queue_redraw())
	pen_color = Color("247f91")

func _gui_input(event: InputEvent) -> void:
	super._gui_input(event)
	if event is InputEventMouseMotion:
		cursor = event.position
		queue_redraw()
		if drawing: stroke_changed.emit()

func _draw() -> void:
	draw_style_box(_paper_style(),Rect2(Vector2.ZERO,size))
	for x in range(24,int(size.x),24):
		for y in range(24,int(size.y),24): draw_circle(Vector2(x,y),0.7,Color("c3bdad"))
	if closed_mode and points.size() >= 3:
		var triangles := Geometry2D.triangulate_polygon(points)
		if not triangles.is_empty(): draw_colored_polygon(points,Color(pen_color,0.18))
	if points.size() >= 2:
		draw_polyline(points,Color("253b48"),7.0,true)
		draw_polyline(points,pen_color,4.0,true)
		if closed_mode and not drawing and points.size() >= 3:
			draw_dashed_line(points[-1],points[0],pen_color,2.0,8.0,true)
	if not points.is_empty():
		draw_circle(points[0],7,Color("ef826c"))
		draw_circle(points[0],3,Color("fff5dd"))
		if not closed_mode:
			draw_circle(points[-1],7,pen_color)
			draw_circle(points[-1],3,Color("fff5dd"))
	if hovering:
		draw_arc(cursor,9,0,TAU,24,Color("37545c"),1.0,true)
		draw_circle(cursor,2,pen_color)
