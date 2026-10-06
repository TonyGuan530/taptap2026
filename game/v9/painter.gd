extends Node3D
## Original papercraft apprentice. Visual-only, movement stays on the parent body.
const Art := preload("res://lowpoly/library.gd")
var phase := 0.0
var active_pose := "idle"
var left_foot: Node3D
var right_foot: Node3D
var scarf: Node3D
var brush: Node3D
var modulate := Color.WHITE:
	set(value): modulate = value

func _ready() -> void:
	Art.cylinder(self,0.26,0.36,0.54,Vector3(0,0.55,0),Color("f2e6cc"))
	Art.cylinder(self,0.23,0.22,0.33,Vector3(0,0.98,0),Color("fff1d6"))
	for x in [-0.085,0.085]:
		Art.box(self,Vector3(0.04,0.06,0.025),Vector3(x,1.00,0.22),Color("263747"))
	Art.cylinder(self,0.48,0.48,0.055,Vector3(0,1.17,0),Color("243847"))
	Art.cylinder(self,0.48,0.48,0.06,Vector3(0,1.21,0),Color("f7ecd4"))
	var hat := Art.cylinder(self,0.025,0.30,0.46,Vector3(-0.035,1.43,0),Color("f2dfba"))
	hat.mesh.radial_segments = 4
	hat.rotation.y = PI/4
	hat.rotation.z = -0.17
	Art.cylinder(self,0.29,0.29,0.07,Vector3(0,1.24,0),Color("d4bea0"))
	Art.cylinder(self,0.26,0.26,0.10,Vector3(0,0.82,0),Color("ec765f"))
	scarf = Art.box(self,Vector3(0.17,0.035,0.50),Vector3(-0.19,0.81,-0.29),Color("ec765f"))
	left_foot = Art.box(self,Vector3(0.21,0.15,0.30),Vector3(-0.15,0.11,0.055),Color("283946"))
	right_foot = Art.box(self,Vector3(0.21,0.15,0.30),Vector3(0.15,0.11,0.055),Color("283946"))
	Art.box(self,Vector3(0.30,0.32,0.20),Vector3(0,0.57,-0.31),Color("244b5d"))
	Art.box(self,Vector3(0.23,0.21,0.025),Vector3(0,0.57,-0.42),Color("4daeb0"))
	Art.cylinder(self,0.075,0.075,0.10,Vector3(0,0.78,-0.31),Color("253845"))
	Art.box(self,Vector3(0.08,0.56,0.025),Vector3(-0.15,0.56,-0.23),Color("785f4b"))
	Art.box(self,Vector3(0.08,0.56,0.025),Vector3(0.15,0.56,-0.23),Color("785f4b"))
	for x in [-0.30,0.30]:
		Art.cylinder(self,0.10,0.11,0.28,Vector3(x,0.58,0.04),Color("efe0be"))
	brush = Node3D.new()
	brush.position = Vector3(0.34,0.42,0.13)
	brush.rotation.z = -0.33
	add_child(brush)
	Art.cylinder(brush,0.035,0.035,0.77,Vector3(0,0.27,0),Color("967455"))
	Art.cylinder(brush,0.065,0.065,0.12,Vector3(0,0.70,0),Color("e6b760"))
	Art.cylinder(brush,0.008,0.07,0.20,Vector3(0,0.86,0),Color("3cacaf"),true)

func pose(state: String) -> void:
	active_pose = state

func face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x,direction.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(1.0,delta*14.0))

func _process(delta: float) -> void:
	phase += delta*10.0
	if not left_foot: return
	var moving := active_pose == "walk"
	left_foot.position.y = 0.11+maxf(0,sin(phase))*0.12 if moving else 0.11
	right_foot.position.y = 0.11+maxf(0,-sin(phase))*0.12 if moving else 0.11
	scarf.rotation.y = sin(phase*0.45)*0.16
	brush.rotation.x = sin(phase)*0.12 if moving else (-0.9 if active_pose == "attack" else 0.0)
