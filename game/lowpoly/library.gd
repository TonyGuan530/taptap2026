extends RefCounted
## Reuse CC0 author models. Primitives are reserved for game-specific markers.
const Visual := preload("res://lowpoly/model_visual.gd")
static var readable_type: FontFile
const MODELS := {
	"apprentice":preload("res://assets/lowpoly/kenney-dungeon/character-human.glb"),
	"enemy":preload("res://assets/lowpoly/kenney-dungeon/character-orc.glb"),
	"bottle":preload("res://assets/lowpoly/kenney-dungeon/potion.glb"),
	"pot":preload("res://assets/lowpoly/kenney-dungeon/pot.glb"),
	"wall":preload("res://assets/lowpoly/kenney-dungeon/wall.glb"),
	"arch":preload("res://assets/lowpoly/kenney-dungeon/wall-opening.glb"),
	"gate":preload("res://assets/lowpoly/kenney-dungeon/gate.glb"),
	"chest":preload("res://assets/lowpoly/kenney-dungeon/chest.glb"),
	"barrel":preload("res://assets/lowpoly/kenney-dungeon/barrel.glb"),
	"banner":preload("res://assets/lowpoly/kenney-dungeon/banner.glb"),
	"tent":preload("res://assets/lowpoly/kenney-forest/tent.glb"),
	"plate":preload("res://assets/lowpoly/kenney-forest/platform.glb"),
	"tree":preload("res://assets/lowpoly/kenney-nature/tree_pineTallA.glb"),
	"tree_small":preload("res://assets/lowpoly/kenney-nature/tree_pineSmallB.glb"),
	"berry":preload("res://assets/lowpoly/kenney-nature/plant_bush.glb"),
	"rock":preload("res://assets/lowpoly/kenney-nature/rock_largeA.glb"),
	"rock_small":preload("res://assets/lowpoly/kenney-nature/rock_smallA.glb"),
	"wood":preload("res://assets/lowpoly/kenney-nature/log_stack.glb"),
	"branch":preload("res://assets/lowpoly/kenney-nature/log.glb"),
	"campfire":preload("res://assets/lowpoly/kenney-nature/campfire_logs.glb"),
	"dinosaur":preload("res://assets/lowpoly/quaternius-dinosaur/Trex.fbx")
}

static func model(key: String, height: float) -> Node3D:
	var result := Visual.new()
	result.name = "LowPoly"+key.to_pascal_case()
	result.setup(MODELS[key].instantiate(),height,MODELS[key].resource_path)
	if key in ["tree","tree_small","rock","rock_small","berry"]:
		for index in result.materials.size():
			var color: Color = result.base_colors[index]
			var green := color.g > color.r
			var palette := Color("53795c") if green else Color("987052")
			if key.begins_with("rock"): palette = Color("737b70") if green else Color("928c7b")
			result.materials[index].albedo_color = palette
			result.base_colors[index] = palette
	if key == "dinosaur":
		result.base_colors[0] = Color("c47a54")
		result.materials[0].albedo_color = result.base_colors[0]
	return result

static func readable_ui(node: Node) -> void:
	if readable_type == null:
		readable_type = load("res://fonts/NotoSansSC-Medium.ttf")
	if node is Control:
		node.add_theme_font_override("font",readable_type)
	if node is Label3D:
		node.font = readable_type
		node.outline_size = 2
		node.font_size = 44
		node.pixel_size = 0.011
	for child in node.get_children(): readable_ui(child)

static func hide_old_visuals(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D or child is Sprite3D: child.hide()
		hide_old_visuals(child)

static func material(color: Color, glowing := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	if glowing:
		result.emission_enabled = true
		result.emission = color*0.4
	return result

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: Color, glowing := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.position = pos
	node.material_override = material(color,glowing)
	parent.add_child(node)
	return node

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent,shape,pos,color)

static func cylinder(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, color: Color, glowing := false) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = 8
	shape.rings = 1
	return mesh(parent,shape,pos,color,glowing)

static func scroll() -> Node3D:
	var result := Node3D.new()
	result.name = "LowPolyWordScroll"
	box(result,Vector3(0.46,0.07,0.48),Vector3(0,0.22,0),Color("f7e7b1"))
	for x in [-0.24,0.24]:
		var roll := cylinder(result,0.055,0.055,0.54,Vector3(x,0.24,0),Color("f8eccc"))
		roll.rotation.x = PI/2
	box(result,Vector3(0.06,0.09,0.50),Vector3(0,0.25,0),Color("c28ad7"))
	return result

static func paper_door() -> Node3D:
	var result := Visual.new()
	result.name = "LowPolyPaperDoor"
	for z in [-0.88,0.88]:
		box(result,Vector3(0.20,2.30,0.15),Vector3(0,1.15,z),Color("bd8061"))
	for row in 4:
		box(result,Vector3(0.09,0.47,1.62),Vector3(0,0.30+row*0.50,0),Color("f2d09d") if row%2 else Color("e9b183"))
	# A small orange flame marker distinguishes paper from permanent stone.
	cylinder(result,0,0.17,0.43,Vector3(-0.1,1.35,0),Color("ff9866"),true)
	return result

static func brush(parent: Node3D) -> void:
	var skeleton: Skeleton3D = _find_skeleton(parent)
	if not skeleton: return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "arm-right"
	skeleton.add_child(attachment)
	var tool := Node3D.new()
	tool.name = "PaintingBrush"
	tool.position = Vector3(0,-0.20,0.05)
	attachment.add_child(tool)
	cylinder(tool,0.025,0.025,0.27,Vector3(0,0.10,0),Color("d8aa79"))
	cylinder(tool,0.05,0.05,0.06,Vector3(0,0.26,0),Color("dfbd65"))
	cylinder(tool,0.015,0.045,0.09,Vector3(0,0.32,0),Color("4de2cf"),true)

static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found: return found
	return null
