extends Node3D
## Bounded live terrain; stable gameplay IDs are journaled separately per chunk.
const Generator := preload("res://open_world/world_generator.gd")
const SIZE := 48.0
const RADIUS := 2
signal chunk_loaded(coord: Vector2i, node: Node3D, description: Dictionary)
signal chunk_unloading(coord: Vector2i)
signal origin_shifted(delta: Vector3)
var generator = Generator.new()
var origin_chunk := Vector2i.ZERO
var chunks: Dictionary = {}
var pending: Array[Vector2i] = []
var journals: Dictionary = {}
var dirty: Dictionary = {}
var center_chunk := Vector2i.ZERO
var generation_count := 0
var visited: Dictionary = {}
var save_root := ""
var configured := false
var save_error := ""
var tree_mesh: Mesh
var trunk_mesh: Mesh
var rock_mesh: Mesh
func configure(seed: int, profile: String, densities: Dictionary = {}) -> bool:
	if configured:
		flush_save()
		# Preserve the current world until its pending changes can be stored.
		if not dirty.is_empty(): return false
		if not _remove_all():
			# Unload hooks can create fresh dirty state after the initial flush.
			prime(to_local_position(center_chunk,Vector3.ZERO))
			return false
		if origin_chunk != Vector2i.ZERO: _rebase(Vector2i.ZERO)
	generator.configure(seed,profile,densities)
	save_root = "user://open_world_v7/%s_%d/chunks" % [generator.profile,seed]
	DirAccess.make_dir_recursive_absolute(save_root)
	configured = true
	center_chunk = Vector2i.ZERO
	generation_count = 0
	visited.clear()
	_prepare_decor_meshes()
	return true
func reset_world(seed: int, densities: Dictionary = {}) -> bool:
	return configure(seed,generator.profile,densities)
func clear_world_state() -> void:
	# Only numeric chunk files in this world's own journal namespace are removed.
	# Unload clients before deletion; otherwise callbacks resurrect cleared progress.
	_remove_all(true)
	var directory := DirAccess.open(save_root)
	if directory:
		for file in directory.get_files():
			var pieces := file.trim_suffix(".json").split("_")
			if file.ends_with(".json") and pieces.size() == 2 and pieces[0].is_valid_int() and pieces[1].is_valid_int():
				directory.remove(file)
	journals.clear(); dirty.clear()
func _exit_tree() -> void: flush_save()
func _remove_all(discard_changes := false) -> bool:
	for coord in chunks.keys(): _unload(coord)
	pending.clear()
	if not discard_changes and not dirty.is_empty(): return false
	journals.clear(); dirty.clear()
	return true
func absolute_chunk(point: Vector3) -> Vector2i:
	return origin_chunk+Vector2i(int(floor((point.x+24)/SIZE)),int(floor((point.z+24)/SIZE)))
func to_local_position(coord: Vector2i, point: Vector3) -> Vector3:
	var delta := coord-origin_chunk
	return Vector3(delta.x*SIZE,0,delta.y*SIZE)+point
func home_vector(point: Vector3) -> Vector3:
	return Vector3(-origin_chunk.x*SIZE-point.x,0,-origin_chunk.y*SIZE-point.z)
func ready_at(point: Vector3) -> bool: return chunks.has(absolute_chunk(point))
func loaded_count() -> int: return chunks.size()
func cached_state_count() -> int: return journals.size()
func prime(point: Vector3) -> void:
	_sync(point)
	# Only center/cardinal neighbors are synchronous; other chunks use the frame queue.
	for i in mini(5,pending.size()): _load(pending.pop_front())
func step(point: Vector3) -> void:
	_sync(point)
	if not pending.is_empty(): _load(pending.pop_front())
func _sync(point: Vector3) -> void:
	if not configured: return
	var center := absolute_chunk(point)
	center_chunk = center
	if absf(point.x) > 144 or absf(point.z) > 144 or (center == Vector2i.ZERO and origin_chunk != Vector2i.ZERO): _rebase(center)
	for coord: Vector2i in chunks.keys():
		if absi(coord.x-center.x) > RADIUS or absi(coord.y-center.y) > RADIUS: _unload(coord)
	pending.clear()
	for x in range(-RADIUS,RADIUS+1):
		for z in range(-RADIUS,RADIUS+1):
			var coord := center+Vector2i(x,z)
			if not chunks.has(coord): pending.append(coord)
	pending.sort_custom(func(a: Vector2i,b: Vector2i): return (a-center).length_squared() < (b-center).length_squared())
func _rebase(new_origin: Vector2i) -> void:
	if new_origin == origin_chunk: return
	var difference := new_origin-origin_chunk
	var delta := Vector3(difference.x*SIZE,0,difference.y*SIZE)
	origin_chunk = new_origin
	for coord: Vector2i in chunks: chunks[coord].position = to_local_position(coord,Vector3.ZERO)
	origin_shifted.emit(delta)
func _load(coord: Vector2i) -> void:
	if chunks.has(coord): return
	var description: Dictionary = generator.describe(coord)
	var node := Node3D.new()
	node.name = "Chunk_%d_%d" % [coord.x,coord.y]
	node.position = to_local_position(coord,Vector3.ZERO)
	add_child(node)
	_build_terrain(node,coord)
	_build_decor(node,description.features)
	node.set_meta("description",description)
	chunks[coord] = node
	generation_count += 1
	visited[_key(coord)] = true
	# Discovery keeps a count, not an unbounded set of never-used geometry.
	if visited.size() > 512: visited.erase(visited.keys()[0])
	chunk_loaded.emit(coord,node,description)
func _unload(coord: Vector2i) -> void:
	chunk_unloading.emit(coord)
	_save_chunk(coord)
	var key := _key(coord)
	# Keep unsaved changes available for a later retry even after terrain is gone.
	if not dirty.has(key): journals.erase(key)
	var node: Node3D = chunks[coord]
	chunks.erase(coord)
	remove_child(node)
	node.queue_free()
func _key(coord: Vector2i) -> String: return "%d_%d" % [coord.x,coord.y]
func _id_coord(id: String) -> Vector2i:
	var pieces := id.split(":")
	return Vector2i(int(pieces[0]),int(pieces[1])) if pieces.size() >= 2 else Vector2i.ZERO
func _journal(coord: Vector2i) -> Dictionary:
	var key := _key(coord)
	if not journals.has(key):
		var result := {}
		var filename := save_root+"/"+key+".json"
		if FileAccess.file_exists(filename):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(filename))
			if parsed is Dictionary and parsed.get("version",0) == 1 and parsed.get("seed",0) == generator.seed_value and parsed.get("features",null) is Dictionary: result = parsed.features
		journals[key] = result
	return journals[key]
func get_feature_state(id: String) -> Dictionary:
	var result: Dictionary = _journal(_id_coord(id)).get(id,{})
	return result.duplicate(true)
func set_feature_state(id: String, state: Dictionary) -> void:
	var coord := _id_coord(id)
	_journal(coord)[id] = state.duplicate(true)
	dirty[_key(coord)] = true
func _save_chunk(coord: Vector2i) -> void:
	var key := _key(coord)
	if not dirty.has(key): return
	var filename := save_root+"/"+key+".json"
	var file := FileAccess.open(filename,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version":1,"seed":generator.seed_value,"features":journals.get(key,{})}))
		file.close()
		dirty.erase(key)
	else: save_error = "无法写入区块存档：%s" % key
func flush_save() -> void:
	for key: String in dirty.keys():
		var pieces := key.split("_")
		var coord := Vector2i(int(pieces[0]),int(pieces[1]))
		_save_chunk(coord)
		if not dirty.has(key) and not chunks.has(coord): journals.erase(key)
	if dirty.is_empty(): save_error = ""
func snapshot() -> Dictionary:
	var descriptions := []
	for coord: Vector2i in chunks:
		var description: Dictionary = chunks[coord].get_meta("description")
		descriptions.append({"coord":[coord.x,coord.y],"biome":description.biome,"features":description.features.size()})
	var biome := generator.biome_at(center_chunk.x*SIZE,center_chunk.y*SIZE)
	return {"seed":generator.seed_value,"profile":generator.profile,"densities":generator.densities,"origin_chunk":[origin_chunk.x,origin_chunk.y],"chunk":[center_chunk.x,center_chunk.y],"loaded":chunks.size(),"pending":pending.size(),"budget":25,"generated":generation_count,"biome":biome,"biome_name":Generator.BIOME_NAMES[biome],"cached_states":journals.size(),"save_error":save_error,"chunks":descriptions}
func _build_terrain(node: Node3D, coord: Vector2i) -> void:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var colors := PackedColorArray()
	var offset := Vector2(coord.x*SIZE,coord.y*SIZE)
	for x in 12:
		for z in 12:
			var p := Vector2(-24+x*4,-24+z*4)
			# Clip precisely along the authored floor boundary, preserving its river/cave holes.
			var polygons: Array[PackedVector2Array] = [PackedVector2Array([p,p+Vector2(0,4),p+Vector2(4,4),p+Vector2(4,0)])]
			for rect: Rect2 in generator.protected_rects():
				var cut := PackedVector2Array([rect.position-offset,Vector2(rect.position.x,rect.end.y)-offset,rect.end-offset,Vector2(rect.end.x,rect.position.y)-offset])
				var next: Array[PackedVector2Array] = []
				for polygon in polygons: next.append_array(Geometry2D.clip_polygons(polygon,cut))
				polygons = next
			for polygon in polygons:
				if polygon.size() < 3: continue
				var indices := Geometry2D.triangulate_polygon(polygon)
				for i in range(0,indices.size(),3):
					var triangle: Array[Vector3] = []
					for j in 3:
						var point := polygon[indices[i+j]]
						triangle.append(Vector3(point.x,generator.height_at(offset.x+point.x,offset.y+point.y),point.y))
					# Front faces point upward for terrain and concave collision.
					var normal := (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
					if normal.y < 0:
						var swap := triangle[1]; triangle[1] = triangle[2]; triangle[2] = swap; normal = -normal
					for point: Vector3 in triangle:
						vertices.append(point); normals.append(normal); colors.append(generator.color_at(offset.x+point.x,offset.y+point.z))
	if vertices.is_empty(): return
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var visual := MeshInstance3D.new(); visual.name = "LowPolyTerrain"; visual.mesh = mesh
	var material := StandardMaterial3D.new(); material.vertex_color_use_as_albedo = true; material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material; node.add_child(visual)
	var body := StaticBody3D.new(); body.name = "TerrainCollision"; var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new(); shape.backface_collision = true; shape.set_faces(vertices)
	collision.shape = shape; body.add_child(collision); node.add_child(body)
func _prepare_decor_meshes() -> void:
	var cone := CylinderMesh.new(); cone.top_radius = 0; cone.bottom_radius = 1.25; cone.height = 3.2; cone.radial_segments = 5; cone.rings = 1
	tree_mesh = cone
	var trunk := CylinderMesh.new(); trunk.top_radius = .16; trunk.bottom_radius = .23; trunk.height = 1.6; trunk.radial_segments = 5
	trunk_mesh = trunk
	var stone := SphereMesh.new(); stone.radius = .8; stone.height = 1.0; stone.radial_segments = 5; stone.rings = 2
	rock_mesh = stone
func _instances(parent: Node3D, mesh: Mesh, positions: Array[Vector3], color: Color) -> void:
	if positions.is_empty(): return
	var many := MultiMesh.new(); many.transform_format = MultiMesh.TRANSFORM_3D; many.mesh = mesh; many.instance_count = positions.size()
	for i in positions.size(): many.set_instance_transform(i,Transform3D(Basis(),positions[i]))
	var node := MultiMeshInstance3D.new(); node.multimesh = many
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 1; node.material_override = material
	parent.add_child(node)
func _build_decor(parent: Node3D, features: Array) -> void:
	var trees: Array[Vector3] = []; var trunks: Array[Vector3] = []; var rocks: Array[Vector3] = []
	for feature: Dictionary in features:
		if feature.kind == "decor_tree": trees.append(feature.pos+Vector3(0,2.35,0)); trunks.append(feature.pos+Vector3(0,.8,0))
		elif feature.kind == "decor_rock": rocks.append(feature.pos+Vector3(0,.42,0))
	_instances(parent,tree_mesh,trees,Color("4c8168")); _instances(parent,trunk_mesh,trunks,Color("8b6d55")); _instances(parent,rock_mesh,rocks,Color("8e9792"))
