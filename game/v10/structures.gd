extends RefCounted
## Meshes and collision share the same mapped stroke/polygon coordinates.
const Art := preload("res://lowpoly/library.gd")

static func create(analysis: Dictionary, start: Vector3, direction: Vector3, preview := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Ink"+str(analysis.kind).to_pascal_case()
	var side := Vector3(-direction.z,0,direction.x).normalized()
	if side.length() < 0.01: side = Vector3.RIGHT
	root.transform = Transform3D(Basis(side,direction,side.cross(direction).normalized()),start)
	var ink := Color("273a42")
	if preview: ink = Color("80b6a5",0.55)
	for segment in analysis.segments:
		var a := Vector3(segment[0].x,segment[0].y,0)
		var b := Vector3(segment[1].x,segment[1].y,0)
		var beam := Art.cylinder(root,0.033,0.033,a.distance_to(b),(a+b)*0.5,ink)
		var delta := (b-a).normalized()
		var x_axis := Vector3.FORWARD.cross(delta).normalized()
		beam.basis = Basis(x_axis,delta,x_axis.cross(delta))
		if preview: _transparent(beam.material_override)
	if analysis.kind == "board": _board(root,analysis.polygon,preview,analysis.property)
	if analysis.property != "None":
		var badge := Art.box(root,Vector3(0.12,0.20,0.035),Vector3(0,0.18,0.05),Color("8cb4a3") if analysis.property == "Sticky" else Color("cc96be"))
		if preview: _transparent(badge.material_override)
	return root

static func _transparent(material: StandardMaterial3D) -> void:
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.55
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

static func _board(root: Node3D, polygon: PackedVector2Array, preview: bool, property: String) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for index in indices:
		vertices.append(Vector3(polygon[index].x,polygon[index].y,0.035))
		normals.append(Vector3.BACK)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var surface := Art.mesh(root,mesh,Vector3.ZERO,Color("4d6570",0.55) if preview else Color("394d55"))
	surface.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	if preview:
		_transparent(surface.material_override); return
	var body := StaticBody3D.new()
	body.name = "ActualDrawnBoard"
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("ink_support",true)
	body.set_meta("ink_property",property)
	root.add_child(body)
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(vertices)
	shape.backface_collision = true
	collider.shape = shape
	body.add_child(collider)
