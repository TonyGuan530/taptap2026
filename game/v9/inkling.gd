extends Node3D
const Art := preload("res://lowpoly/library.gd")
var phase := 0.0
var body: MeshInstance3D
var active_pose := "idle"
var modulate := Color.WHITE:
	set(value):
		modulate = value
		if body: body.material_override.albedo_color = Color("395b66")*value
func _ready() -> void:
	var shape := SphereMesh.new()
	shape.radius = 0.38
	shape.height = 0.65
	shape.radial_segments = 8
	shape.rings = 4
	body = Art.mesh(self,shape,Vector3(0,0.35,0),Color("395b66"))
	for x in [-0.11,0.11]:
		Art.box(self,Vector3(0.07,0.09,0.025),Vector3(x,0.42,0.34),Color("f7dfae"))
		Art.cylinder(self,0.015,0.06,0.18,Vector3(x,0.70,0),Color("365564"))
func face(direction: Vector3,delta: float) -> void:
	if direction.length() > 0.1: rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(1,delta*12))
func pose(value: String) -> void: active_pose = value
func _process(delta: float) -> void:
	phase += delta*7
	if body: body.scale.y = 0.25 if active_pose == "dead" else 1.0+sin(phase)*0.07
