extends RefCounted

const ComicObject = preload("res://comic_style/comic_object.gd")
const IDS := ["crate", "iron_block", "rock", "tree", "bush", "barrel", "pressure_plate", "gate_frame"]
const COLORS := {
	"wood": Color("cf8958"), "wood_dark": Color("956444"), "iron": Color("8197a7"),
	"iron_dark": Color("4e6373"), "stone": Color("b5b4aa"), "leaf": Color("7f9e67"),
	"leaf_light": Color("a7bd7d"), "plate": Color("d8b265"), "frame": Color("b1a08e")
}
const SIZES := {
	"crate": Vector3(1, 1, 1), "iron_block": Vector3(0.92, 0.85, 0.92),
	"rock": Vector3(1.3, 0.85, 1.05), "tree": Vector3(1.8, 2.8, 1.8),
	"bush": Vector3(1.45, 0.8, 1.0), "barrel": Vector3(0.84, 1.15, 0.84),
	"pressure_plate": Vector3(1.3, 0.18, 1.3), "gate_frame": Vector3(2.2, 2.4, 0.35)
}

static func create_model(id: String) -> Node3D:
	var obj = ComicObject.new()
	obj.name = id.to_pascal_case()
	obj.set_meta("model_id", id)
	obj.set_meta("size_m", SIZES.get(id, Vector3.ONE))
	obj.interactive = id in ["crate", "iron_block", "barrel", "pressure_plate"]
	match id:
		"crate":
			_box(obj, Vector3(0.9, 0.9, 0.9), Vector3(0, 0.5, 0), COLORS.wood)
			for y in [0.12, 0.88]:
				_box(obj, Vector3(1, 0.15, 1), Vector3(0, y, 0), COLORS.wood_dark)
			for x in [-0.42, 0.42]:
				_box(obj, Vector3(0.14, 0.72, 1), Vector3(x, 0.5, 0), COLORS.wood_dark)
		"iron_block":
			_box(obj, Vector3(0.92, 0.85, 0.92), Vector3(0, 0.425, 0), COLORS.iron)
			_box(obj, Vector3(0.96, 0.12, 0.96), Vector3(0, 0.16, 0), COLORS.iron_dark)
		"rock":
			_ellipsoid(obj, Vector3(1.3, 0.85, 1.05), Vector3(0, 0.425, 0), COLORS.stone, true)
		"tree":
			_cylinder(obj, 0.14, 0.19, 1.8, Vector3(0, 0.9, 0), COLORS.wood_dark)
			_cylinder(obj, 0.05, 0.9, 1.3, Vector3(0, 1.65, 0), COLORS.leaf)
			_cylinder(obj, 0, 0.65, 1.15, Vector3(0, 2.225, 0), COLORS.leaf_light)
		"bush":
			_ellipsoid(obj, Vector3(1, 0.8, 1), Vector3(-0.2, 0.4, 0), COLORS.leaf)
			_ellipsoid(obj, Vector3(0.9, 0.65, 0.8), Vector3(0.3, 0.325, 0.04), COLORS.leaf_light)
		"barrel":
			_cylinder(obj, 0.37, 0.42, 1.15, Vector3(0, 0.575, 0), COLORS.wood)
			for y in [0.2, 0.95]:
				_cylinder(obj, 0.43, 0.43, 0.12, Vector3(0, y, 0), COLORS.iron_dark)
		"pressure_plate":
			_box(obj, Vector3(1.3, 0.1, 1.3), Vector3(0, 0.05, 0), COLORS.iron_dark)
			_box(obj, Vector3(1.08, 0.1, 1.08), Vector3(0, 0.13, 0), COLORS.plate)
		"gate_frame":
			for x in [-0.925, 0.925]:
				_box(obj, Vector3(0.35, 2.4, 0.35), Vector3(x, 1.2, 0), COLORS.frame)
			_box(obj, Vector3(2.2, 0.35, 0.35), Vector3(0, 2.225, 0), COLORS.frame)
	var bounds := geometry_bounds(obj)
	for part in obj.get_children():
		if part is MeshInstance3D:
			part.position.y -= bounds.position.y
	bounds = geometry_bounds(obj)
	obj.set_meta("size_m", bounds.size)
	obj.set_meta("bounds_min", bounds.position)
	return obj

static func geometry_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var initialized := false
	for part in model.get_children():
		if part is MeshInstance3D:
			var aabb: AABB = part.mesh.get_aabb()
			for x in [0, 1]:
				for y in [0, 1]:
					for z in [0, 1]:
						var p: Vector3 = part.transform * (aabb.position + aabb.size * Vector3(x, y, z))
						bounds = bounds.expand(p) if initialized else AABB(p, Vector3.ZERO)
						initialized = true
	return bounds

static func _box(obj: Node3D, size: Vector3, offset: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	obj.add_part(mesh, color, Transform3D(Basis.IDENTITY, offset))

static func _cylinder(obj: Node3D, top: float, bottom: float, height: float, offset: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	obj.add_part(_flat_mesh(mesh), color, Transform3D(Basis.IDENTITY, offset))

static func _ellipsoid(obj: Node3D, size: Vector3, offset: Vector3, color: Color, irregular: bool = false) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 3
	var data := sphere.surface_get_arrays(0)
	var verts: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var p := verts[i]
		if irregular:
			p.x *= 1.0 + 0.15 * sin(p.y * 7.0 + p.z * 3.0)
			p.z *= 1.0 + 0.1 * cos(p.x * 9.0)
		verts[i] = p * size
	data[Mesh.ARRAY_VERTEX] = verts
	var shaped := ArrayMesh.new()
	shaped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	obj.add_part(_flat_mesh(shaped), color, Transform3D(Basis.IDENTITY, offset))

static func _flat_mesh(source: Mesh) -> ArrayMesh:
	var original := source.surface_get_arrays(0)
	var points: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
	var source_normals: PackedVector3Array = original[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for t in range(0, indices.size(), 3):
		var a := points[indices[t]]
		var b := points[indices[t + 1]]
		var c := points[indices[t + 2]]
		if (b - a).cross(c - a).length_squared() < 0.00000001:
			continue
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(source_normals[indices[t]]) < 0:
			normal = -normal
		verts.append_array(PackedVector3Array([a, b, c]))
		normals.append_array(PackedVector3Array([normal, normal, normal]))
	var data: Array = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = verts
	data[Mesh.ARRAY_NORMAL] = normals
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	return result

static func triangle_count(model: Node3D) -> int:
	var total := 0
	for part in model.get_children():
		if part is MeshInstance3D:
			for surface in part.mesh.get_surface_count():
				var data: Array = part.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX] if data[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var count: int = indices.size() if not indices.is_empty() else (data[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				total += int(count / 3.0)
	return total

static func plain_export_copy(model: Node3D) -> Node3D:
	# GLB is geometry + plain materials. Native .tscn retains the Godot shaders.
	var result := Node3D.new()
	result.name = model.name
	for part in model.get_children():
		if part is MeshInstance3D:
			var copy := MeshInstance3D.new()
			copy.name = part.name
			copy.mesh = part.mesh
			copy.transform = part.transform
			var material := StandardMaterial3D.new()
			material.albedo_color = part.get_meta("comic_color")
			material.roughness = 1.0
			material.metallic = 0.0
			copy.material_override = material
			result.add_child(copy)
			copy.owner = result
	return result
