extends "res://open_world/world_stream.gd"
## V8 visual extension; the base stream owns collision, coordinates and journal lifecycle.
const ArtGenerator := preload("res://open_world/world_generator_v8.gd")
const GroundShader := preload("res://open_world/ground_v8.gdshader")
const ART_ASSETS := {
	"pine_tall":"res://assets/lowpoly/kenney-nature/tree_pineTallA.glb",
	"pine_small":"res://assets/lowpoly/kenney-nature/tree_pineSmallB.glb",
	"tree":"res://assets/lowpoly/kenney-nature/tree_simple.glb",
	"oak":"res://assets/lowpoly/kenney-nature-v8/tree_oak.glb",
	"bush":"res://assets/lowpoly/kenney-nature/plant_bush.glb",
	"rock":"res://assets/lowpoly/kenney-nature/rock_largeA.glb",
	"stone":"res://assets/lowpoly/kenney-nature/rock_smallA.glb",
	"grass":"res://assets/lowpoly/kenney-nature-v8/grass.glb",
	"leaf_grass":"res://assets/lowpoly/kenney-nature-v8/grass_leafs.glb",
	"flower_yellow":"res://assets/lowpoly/kenney-nature-v8/flower_yellowA.glb",
	"flower_purple":"res://assets/lowpoly/kenney-nature-v8/flower_purpleA.glb"
}
var ground_material: ShaderMaterial
var decor_material: StandardMaterial3D
var art_meshes: Dictionary = {}
var core_grounds: Array[WeakRef] = []
func _init() -> void:
	generator = ArtGenerator.new()
	ground_material = ShaderMaterial.new()
	ground_material.shader = GroundShader
	decor_material = StandardMaterial3D.new()
	decor_material.vertex_color_use_as_albedo = true
	# StandardMaterial performs the appropriate renderer-dependent vertex conversion.
	decor_material.vertex_color_is_srgb = true
	decor_material.roughness = 1.0
	decor_material.metallic = 0.0
func configure(seed: int, profile: String, densities: Dictionary = {}) -> bool:
	# super flushes/unloads in the old namespace, and refuses a transition on dirty write failure.
	if not super.configure(seed,profile,densities): return false
	save_root = "user://open_world_v8/%s_%d/chunks" % [generator.profile,seed]
	DirAccess.make_dir_recursive_absolute(save_root)
	_update_ground_origin()
	for reference in core_grounds:
		var visual = reference.get_ref()
		if is_instance_valid(visual): _bake_core_ground(visual)
	return true
func _rebase(new_origin: Vector2i) -> void:
	super._rebase(new_origin)
	_update_ground_origin()
func _update_ground_origin() -> void:
	ground_material.set_shader_parameter("world_origin",Vector2(origin_chunk.x*SIZE,origin_chunk.y*SIZE))
func _build_terrain(node: Node3D, coord: Vector2i) -> void:
	# Keep the inherited exact core clipping and ConcavePolygonShape3D faces.
	super._build_terrain(node,coord)
	var visual := node.get_node_or_null("LowPolyTerrain") as MeshInstance3D
	if not visual: return
	var source: Array = visual.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var output := _empty_arrays()
	var offset := Vector2(coord.x*SIZE,coord.y*SIZE)
	for index in range(0,vertices.size(),3):
		_subdivide_triangle(vertices[index],vertices[index+1],vertices[index+2],3,Transform3D.IDENTITY,offset,output,true)
	visual.mesh = _mesh_from_arrays(output)
	visual.material_override = ground_material
func _empty_arrays() -> Array:
	var result: Array = []; result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	result[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	result[Mesh.ARRAY_COLOR] = PackedColorArray()
	return result
func _mesh_from_arrays(arrays: Array) -> ArrayMesh:
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
func _subdivide_triangle(a: Vector3, b: Vector3, c: Vector3, count: int, transform_value: Transform3D, offset: Vector2, output: Array, terrain: bool, source_normal := Vector3.ZERO) -> void:
	# Barycentric positions lie on the original collision plane. Heights and routes are unchanged.
	for i in count:
		for j in range(count-i):
			var p := a+(b-a)*float(i)/count+(c-a)*float(j)/count
			var q := a+(b-a)*float(i+1)/count+(c-a)*float(j)/count
			var r := a+(b-a)*float(i)/count+(c-a)*float(j+1)/count
			_append_triangle(p,q,r,transform_value,offset,output,terrain,source_normal)
			if i+j < count-1:
				var s := a+(b-a)*float(i+1)/count+(c-a)*float(j+1)/count
				_append_triangle(q,s,r,transform_value,offset,output,terrain,source_normal)
func _append_triangle(a: Vector3, b: Vector3, c: Vector3, transform_value: Transform3D, offset: Vector2, output: Array, terrain: bool, source_normal: Vector3) -> void:
	var geometric := source_normal if not source_normal.is_zero_approx() else (b-a).cross(c-a).normalized()
	for point in [a,b,c]:
		var absolute: Vector3 = transform_value*point
		var xz := Vector2(absolute.x,absolute.z)+offset
		output[Mesh.ARRAY_VERTEX].append(point)
		var normal: Vector3 = generator.normal_at(xz.x,xz.y) if terrain else geometric
		output[Mesh.ARRAY_NORMAL].append(normal)
		# Shader ALBEDO consumes linear colors; core and exterior use the same conversion.
		output[Mesh.ARRAY_COLOR].append(generator.color_at(xz.x,xz.y).srgb_to_linear())
func apply_core_ground(visual: MeshInstance3D) -> bool:
	if not configured or not visual or not visual.mesh or not visual.is_inside_tree(): return false
	if not visual.has_meta("v8_ground_source"):
		visual.set_meta("v8_ground_source",visual.mesh)
		core_grounds.append(weakref(visual))
	return _bake_core_ground(visual)
func _bake_core_ground(visual: MeshInstance3D) -> bool:
	var source: Mesh = visual.get_meta("v8_ground_source",visual.mesh)
	var output := _empty_arrays()
	var offset := Vector2(origin_chunk.x*SIZE,origin_chunk.y*SIZE)
	if source is BoxMesh and visual.global_basis.is_equal_approx(Basis.IDENTITY):
		# Subdivision coordinates match the exterior's absolute 4m lattice, including clipped edges.
		var bounds := source.get_aabb()
		var xs := _lattice_axis(bounds.position.x,bounds.end.x,visual.global_position.x+offset.x)
		var zs := _lattice_axis(bounds.position.z,bounds.end.z,visual.global_position.z+offset.y)
		for i in range(xs.size()-1):
			for j in range(zs.size()-1):
				var a := Vector3(xs[i],bounds.end.y,zs[j])
				var b := Vector3(xs[i],bounds.end.y,zs[j+1])
				var c := Vector3(xs[i+1],bounds.end.y,zs[j+1])
				var d := Vector3(xs[i+1],bounds.end.y,zs[j])
				_subdivide_triangle(a,b,c,3,visual.global_transform,offset,output,false)
				_subdivide_triangle(a,c,d,3,visual.global_transform,offset,output,false)
		# Keep source sides/bottom exactly where the authored visual placed them.
		for surface in source.get_surface_count():
			var arrays: Array = source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				var a := vertices[indices[i]]; var b := vertices[indices[i+1]]; var c := vertices[indices[i+2]]
				if is_equal_approx(a.y,bounds.end.y) and is_equal_approx(b.y,bounds.end.y) and is_equal_approx(c.y,bounds.end.y): continue
				_subdivide_triangle(a,b,c,1,visual.global_transform,offset,output,false,source_normals[indices[i]])
	else:
		for surface in source.get_surface_count():
			var arrays: Array = source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for i in range(0,count,3):
				var a := vertices[indices[i] if not indices.is_empty() else i]
				var b := vertices[indices[i+1] if not indices.is_empty() else i+1]
				var c := vertices[indices[i+2] if not indices.is_empty() else i+2]
				_subdivide_triangle(a,b,c,3,visual.global_transform,offset,output,false,source_normals[indices[i] if not indices.is_empty() else i])
	if output[Mesh.ARRAY_VERTEX].is_empty(): return false
	visual.mesh = _mesh_from_arrays(output)
	visual.material_override = ground_material
	return true
func _lattice_axis(low: float, high: float, absolute_offset: float) -> PackedFloat32Array:
	var result := PackedFloat32Array([low])
	var point := (floorf((low+absolute_offset)/4)+1)*4-absolute_offset
	while point < high-.0001:
		result.append(point); point += 4
	result.append(high)
	return result
func _prepare_decor_meshes() -> void:
	for key in ART_ASSETS:
		var cache_key := "%s:%s" % [generator.profile,key]
		if art_meshes.has(cache_key): continue
		var packed := load(ART_ASSETS[key]) as PackedScene
		if not packed:
			push_error("V8 missing authored decoration: %s" % ART_ASSETS[key]); continue
		var root := packed.instantiate()
		var arrays := _empty_arrays()
		_flatten_model(root,Transform3D.IDENTITY,arrays,str(key))
		root.free()
		if arrays[Mesh.ARRAY_VERTEX].is_empty(): continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bounds := AABB(vertices[0],Vector3.ZERO)
		for point in vertices: bounds = bounds.expand(point)
		# Preserve author proportions and use a ground-level origin with unit model height.
		var factor := 1.0/maxf(bounds.size.y,.001)
		var center := bounds.get_center()
		for i in vertices.size(): vertices[i] = (vertices[i]-Vector3(center.x,bounds.position.y,center.z))*factor
		arrays[Mesh.ARRAY_VERTEX] = vertices
		art_meshes[cache_key] = _mesh_from_arrays(arrays)
func _flatten_model(node: Node, parent_transform: Transform3D, arrays: Array, key: String) -> void:
	var transform_value := parent_transform
	if node is Node3D: transform_value *= node.transform
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			var source: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
			var color := _model_color(node.get_active_material(surface),key)
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for i in count:
				var index := indices[i] if not indices.is_empty() else i
				arrays[Mesh.ARRAY_VERTEX].append(transform_value*vertices[index])
				arrays[Mesh.ARRAY_NORMAL].append((transform_value.basis.inverse().transposed()*normals[index]).normalized())
				arrays[Mesh.ARRAY_COLOR].append(color)
	for child in node.get_children(): _flatten_model(child,transform_value,arrays,key)
func _model_color(material: Material, key: String) -> Color:
	var name := material.resource_name.to_lower() if material else ""
	var original: Color = material.albedo_color if material is StandardMaterial3D else Color.WHITE
	var ink: bool = generator.profile == "ink"
	if "yellow" in name: return Color("e0ba64")
	if "purple" in name: return Color("a983be")
	if "wood" in name or "bark" in name: return Color("a98161") if ink else Color("967153")
	if "leaf" in name or "grass" in name or original.g > original.r:
		return Color("70aa89") if ink else Color("64835a")
	if key in ["rock","stone"]: return Color("a0a699") if ink else Color("918c79")
	return Color("adb597") if ink else Color("8c9476")
func _build_decor(parent: Node3D, features: Array) -> void:
	var coord := Vector2i.ZERO
	# The chunk name avoids modifying base _load or the gameplay description contract.
	var parts := str(parent.name).split("_")
	if parts.size() == 3: coord = Vector2i(int(parts[1]),int(parts[2]))
	var groups := decor_layout(coord,features)
	for key in groups:
		var mesh: Mesh = art_meshes.get("%s:%s" % [generator.profile,key])
		if not mesh: continue
		var transforms: Array = groups[key]
		var many := MultiMesh.new(); many.transform_format = MultiMesh.TRANSFORM_3D
		many.mesh = mesh; many.instance_count = transforms.size()
		var bounds := AABB(); var initialized := false
		for i in transforms.size():
			many.set_instance_transform(i,transforms[i])
			var instance_bounds: AABB = transforms[i]*mesh.get_aabb()
			bounds = bounds.merge(instance_bounds) if initialized else instance_bounds
			initialized = true
		many.custom_aabb = bounds
		var visual := MultiMeshInstance3D.new(); visual.name = "NatureV8_"+str(key)
		visual.multimesh = many; visual.material_override = decor_material
		visual.set_meta("open_asset_source",ART_ASSETS[key]); parent.add_child(visual)
func decor_layout(coord: Vector2i, features: Array) -> Dictionary:
	# CPU layout is also used to compute each group's precise culling bounds.
	var rng: RandomNumberGenerator = generator._rng(coord,881)
	var groups := {}
	for feature: Dictionary in features:
		var key := ""; var height := 1.0
		if feature.kind == "decor_tree":
			key = ["pine_tall","oak","tree","pine_small","bush"][int(feature.variant)%5]
			height = rng.randf_range(3.8,6.3) if key != "bush" else rng.randf_range(.85,1.5)
			if key == "pine_small": height *= .68
		elif feature.kind == "decor_rock":
			key = "rock" if int(feature.variant)%2 == 0 else "stone"
			height = rng.randf_range(.55,1.15)
		else: continue
		var yaw := rng.randf_range(-PI,PI)
		var scale_value := Vector3(rng.randf_range(.9,1.15),1,rng.randf_range(.9,1.15))*height
		_group_transform(groups,key,Transform3D(Basis(Vector3.UP,yaw).scaled(scale_value),feature.pos))
	# Independent bounded visual accents never alter features, journals or clear puzzle routes.
	rng = generator._rng(coord,889)
	var events: Array[Vector2] = []
	for feature: Dictionary in features:
		if feature.kind in ["pull","weight","vines"]: events.append(Vector2(feature.pos.x,feature.pos.z))
	for index in 32:
		var x := rng.randf_range(-22,22); var z := rng.randf_range(-22,22)
		var absolute := Vector2(coord.x*SIZE+x,coord.y*SIZE+z)
		var coverage_value: float = generator.coverage.get_noise_2d(absolute.x,absolute.y)
		if rng.randf() > generator.densities.decoration*.7 or not generator._clear(coord,x,z,events,7): continue
		if coverage_value < -.3: continue
		var key: String = ["grass","leaf_grass","grass","flower_yellow","flower_purple"][rng.randi_range(0,4)]
		var height := rng.randf_range(.25,.55) if key.begins_with("flower") else rng.randf_range(.28,.65)
		_group_transform(groups,key,Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*height),Vector3(x,generator.height_at(absolute.x,absolute.y),z)))
	return groups
func _group_transform(groups: Dictionary, key: String, value: Transform3D) -> void:
	if not groups.has(key): groups[key] = []
	groups[key].append(value)
