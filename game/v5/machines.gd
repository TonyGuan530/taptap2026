extends RefCounted
const Low := preload("res://lowpoly/library.gd")
const COPPER := Color("d78350")
const IRON := Color("3d5362")
static func make(index: int) -> Dictionary:
	var root := Node3D.new()
	var rotor := Node3D.new()
	var piston := Node3D.new()
	var light: OmniLight3D
	var bulb_visual: MeshInstance3D
	root.add_child(rotor)
	root.add_child(piston)
	Low.box(root,Vector3(2.1,0.16,1.5),Vector3(0,0.08,0),Color("597b65"))
	if index == 0:
		Low.box(root,Vector3(0.18,1.5,0.3),Vector3(-0.7,0.8,0),IRON)
		Low.box(root,Vector3(0.18,1.5,0.3),Vector3(0.7,0.8,0),IRON)
		rotor.position = Vector3(0,0.85,0)
		for blade in 8:
			var spoke := Node3D.new()
			spoke.rotation.z = blade*TAU/8.0
			rotor.add_child(spoke)
			Low.box(spoke,Vector3(0.14,1.5,0.14),Vector3.ZERO,COPPER)
			Low.box(spoke,Vector3(0.42,0.24,0.6),Vector3(0,0.75,0),Color("d5b579"))
		Low.box(root,Vector3(0.7,0.6,0.55),Vector3(0.3,0.45,0.7),COPPER)
	elif index == 1:
		Low.cylinder(root,0.09,0.12,2.4,Vector3(0,1.3,0),IRON)
		Low.box(root,Vector3(1.1,0.09,0.18),Vector3(0.4,2.45,0),COPPER)
		var bulb := SphereMesh.new()
		bulb.radius = 0.24
		bulb.height = 0.48
		bulb_visual = Low.mesh(root,bulb,Vector3(0.9,2.25,0),Color("ffdb89"))
		light = OmniLight3D.new()
		light.position = Vector3(0.9,2.15,0)
		light.light_color = Color("ffcf84")
		light.omni_range = 7.0
		light.light_energy = 1.7
		root.add_child(light)
		Low.box(root,Vector3(0.7,0.4,0.5),Vector3(-0.5,0.35,0),IRON)
	else:
		var boiler := Low.model("barrel",1.25)
		boiler.position = Vector3(-0.4,0.2,0)
		root.add_child(boiler)
		Low.cylinder(root,0.15,0.2,1.2,Vector3(-0.4,1.55,0),IRON)
		Low.box(root,Vector3(0.7,0.5,0.7),Vector3(0.6,0.6,0),COPPER)
		piston.position = Vector3(0.9,0.75,0)
		Low.box(piston,Vector3(0.6,0.13,0.13),Vector3.ZERO,Color("c4d3d6"))
		rotor.position = Vector3(0.9,0.55,0.65)
		for blade in 6:
			var spoke := Node3D.new()
			spoke.rotation.z = blade*TAU/6.0
			rotor.add_child(spoke)
			Low.box(spoke,Vector3(0.08,0.9,0.10),Vector3.ZERO,COPPER)
		Low.cylinder(root,0.27,0.3,0.12,Vector3(-0.4,0.18,0),Color("f39548"),true)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.28,2.0,0.28) if index == 1 else Vector3(1.8,0.75,1.2)
	collision.shape = shape
	collision.position.y = shape.size.y/2.0
	body.add_child(collision)
	root.add_child(body)
	return {"node":root,"rotor":rotor,"piston":piston,"light":light,"bulb":bulb_visual}
