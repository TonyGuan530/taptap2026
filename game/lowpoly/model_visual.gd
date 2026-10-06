extends Node3D
## Per-instance appearance and source animation, without gameplay collision.
var source_path := ""
var animation_player: AnimationPlayer
var size_m := Vector3.ONE
var materials: Array[StandardMaterial3D] = []
var base_colors: Array[Color] = []
var active_pose := ""
var forward_correction := 0.0
var modulate := Color.WHITE:
	set(value):
		modulate = value
		for index in materials.size():
			materials[index].albedo_color = base_colors[index]*value

func setup(asset: Node3D, height: float, source: String) -> void:
	source_path = source
	set_meta("open_asset_source",source)
	_prepare(asset)
	pose("idle")
	if animation_player: animation_player.advance(0.0)
	var measured := {"bounds":AABB(),"initialized":false}
	_measure(asset,Transform3D.IDENTITY,measured)
	var bounds: AABB = measured.bounds
	var factor := height/maxf(bounds.size.y,0.001)
	var mount := Node3D.new()
	mount.name = "SourceModel"
	mount.scale = Vector3.ONE*factor
	mount.position = Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*factor
	mount.add_child(asset)
	add_child(mount)
	size_m = bounds.size*factor

func _measure(node: Node, parent_transform: Transform3D, measured: Dictionary) -> void:
	var transform_value := parent_transform
	if node is Node3D: transform_value *= node.transform
	if node is MeshInstance3D and node.mesh:
		if node.skin:
			_measure_skin(node,measured)
			return
		var box: AABB = node.mesh.get_aabb()
		for x in [0,1]:
			for y in [0,1]:
				for z in [0,1]:
					var point := transform_value*(box.position+box.size*Vector3(x,y,z))
					measured.bounds = measured.bounds.expand(point) if measured.initialized else AABB(point,Vector3.ZERO)
					measured.initialized = true
	for child in node.get_children(): _measure(child,transform_value,measured)

func _local_transform(node: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent is Node3D:
		result = parent.transform*result
		parent = parent.get_parent()
	return result

func _measure_skin(node: MeshInstance3D, measured: Dictionary) -> void:
	var skeleton: Skeleton3D = node.get_node(node.skeleton)
	var transform_value := _local_transform(skeleton)
	for surface in node.mesh.get_surface_count():
		var arrays: Array = node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var influences: int = bones.size()/vertices.size()
		for vertex in vertices.size():
			var point := Vector3.ZERO
			for influence in influences:
				var index := vertex*influences+influence
				if weights[index] < 0.0001: continue
				var bind := bones[index]
				var bone := skeleton.find_bone(node.skin.get_bind_name(bind))
				if bone < 0: bone = node.skin.get_bind_bone(bind)
				point += (transform_value*skeleton.get_bone_global_pose(bone)*node.skin.get_bind_pose(bind)*vertices[vertex])*weights[index]
			measured.bounds = measured.bounds.expand(point) if measured.initialized else AABB(point,Vector3.ZERO)
			measured.initialized = true

func _prepare(node: Node) -> void:
	if node is AnimationPlayer:
		animation_player = node
		# Gameplay roots process overlays while paused; rig animation must pause.
		animation_player.process_mode = Node.PROCESS_MODE_PAUSABLE
		for name in animation_player.get_animation_list():
			var animation: Animation = animation_player.get_animation(name)
			if "idle" in name.to_lower() or "walk" in name.to_lower() or "run" in name.to_lower():
				animation.loop_mode = Animation.LOOP_LINEAR
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var original: Material = node.get_active_material(index)
			var material: StandardMaterial3D = original.duplicate() if original is StandardMaterial3D else StandardMaterial3D.new()
			material.roughness = 0.88
			material.metallic = 0.0
			material.emission_enabled = false
			node.set_surface_override_material(index,material)
			materials.append(material)
			base_colors.append(material.albedo_color)
	for child in node.get_children(): _prepare(child)

func pose(state: String) -> void:
	if not animation_player or active_pose == state: return
	var tokens: Array = {"idle":["idle"],"walk":["walk","run"],"run":["run","walk"],"attack":["attack-melee-right","attack"],"dead":["die","death"]}.get(state,[state])
	for token in tokens:
		for clip in animation_player.get_animation_list():
			if str(token) in clip.to_lower():
				active_pose = state
				animation_player.speed_scale = 2.5 if state == "attack" else 1.0
				animation_player.play(clip,0.08)
				return

func fit(width: float, height: float, depth: float) -> void:
	scale = Vector3(width/maxf(size_m.x,0.001),height/maxf(size_m.y,0.001),depth/maxf(size_m.z,0.001))

func face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x,direction.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z)+forward_correction,minf(1.0,delta*12.0))
