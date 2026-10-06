extends "res://tonight06/draw_pad.gd"
## Explicit mode: a mouse stroke is never silently closed into a triangle.
var closed_mode := false:
	set(value):
		closed_mode = value
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(540,244)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _draw() -> void:
	draw_style_box(_paper_style(),Rect2(Vector2.ZERO,size))
	for x in range(20,int(size.x),20): draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.23,0.50,0.47,0.10))
	for y in range(20,int(size.y),20): draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.23,0.50,0.47,0.10))
	if closed_mode and points.size() >= 3:
		var triangles := Geometry2D.triangulate_polygon(points)
		if not triangles.is_empty(): draw_colored_polygon(points,Color(pen_color,0.22))
	if points.size() >= 2:
		draw_polyline(points,pen_color.darkened(0.25),5.0,true)
		if closed_mode and not drawing and points.size() >= 3: draw_line(points[-1],points[0],pen_color.darkened(0.25),3.0,true)
	if not points.is_empty():
		draw_circle(points[0],6.0,Color("e58364"))
		if not closed_mode: draw_circle(points[-1],5.0,Color("3e6773"))
