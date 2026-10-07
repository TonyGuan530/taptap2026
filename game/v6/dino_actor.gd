extends CharacterBody3D
const Visual := preload("res://lowpoly/model_visual.gd")
var visual: Node3D
var drive := Vector3.ZERO
var speed := 7.5
var recruited := false
var job := "idle"
var pending_job := ""
var work_phase := "walking"
var carrying := 0
var carried_key := ""
var total_delivered := 0
var work_timer := 0.0
var route: Array[Vector3] = []
func setup(source: String, height: float, color := Color.WHITE) -> void:
	visual = Visual.new()
	visual.setup(load(source).instantiate(),height,source)
	visual.modulate = color
	add_child(visual)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 1.25
	collision.shape = capsule
	collision.position.y = 0.66
	add_child(collision)
	floor_snap_length = 0.7
	floor_max_angle = deg_to_rad(48)
	floor_stop_on_slope = true
	collision_layer = 2
	collision_mask = 1
func step(delta: float) -> void:
	velocity.x = drive.x*speed
	velocity.z = drive.z*speed
	if is_on_floor(): velocity.y = -0.1
	else: velocity.y -= 22.0*delta
	move_and_slide()
	if visual:
		visual.face(drive,delta)
		visual.pose("walk" if drive.length() > 0.1 else "idle")
func follow_route(delta: float) -> bool:
	if route.is_empty():
		drive = Vector3.ZERO
		step(delta)
		return true
	var distance := Vector2(position.x-route[0].x,position.z-route[0].z).length()
	if distance < 0.65 and absf(position.y-route[0].y) < 1.4:
		route.pop_front()
		return follow_route(delta)
	drive = (Vector3(route[0].x,position.y,route[0].z)-position).normalized()
	step(delta)
	return false
