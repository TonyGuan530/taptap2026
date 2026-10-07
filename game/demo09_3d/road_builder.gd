extends RefCounted
## DEMO9 3D 道路生成（契约 game/demo09_3d/RULES_CONTRACT.md §1 受限轨迹桥梁）
## 中心线高度来自 LaneCore.ground_y 的米制映射，左右边缘同高（阶段 A 侧向无起伏，宽度待阶段 B 定）。
## 可视 ArrayMesh 与 ConcavePolygonShape3D 碰撞使用同一顶点数组——严格同源，杜绝"看的是一张图、碰的是另一张"。

const PX_PER_M := 10.0
const BASE_GROUND_Y := 430.0
const START_X := 120.0

## 段长（米）：越小越贴合正弦，800m 关约 400 段，顶点量可控
const SEG_M := 2.0
## 阶段 A 占位路宽（米）。2D 无左右概念，正式宽度是阶段 B 决策（契约 §11），只影响视觉不碰物理规则
const ROAD_WIDTH_M := 10.0


## 返回根 Node3D：RoadMesh(MeshInstance3D) + RoadBody(StaticBody3D + CollisionShape3D) + Decor
## ground: Callable(core.ground_y)；length_m: 关卡 target_m；style: comic_style Resource（统一材质入口）
## gaps_m: 已网格对齐的沟壑区间 [{z0,z1}]（米，绝对里程口径，来自 GarageModel.grid_gaps），
##   完全落入区间的路段 quad 从可视网格与碰撞形状中同时剔除（同源开洞）；
##   缺省空 = 无沟（L1-L9 不受影响，三角数与旧版一致）
## gates_m: 限高架 [{gx, clear}]（米，绝对里程口径）——gate_frame 门架 + iron_block 横杆
##   （基座套件模型，场景应用规则）+ 横杆 StaticBody 碰撞盒（刚体路径真实撞杆）
## speed_gates_m: 限速检测线 [{gx, vmin}]（米）——路面标记线（规则层跨线测速）
## checkpoints_m: 分段检查点 [{gx, tmax}]（米）——路面标记线（规则层累计计时）
## boosts_m: 加速带 [{gx, dv}]（米）——路面标记线（规则层跨带提速）
## 前后各加 6m 缓冲：起点前是 ramp 平地（出发台），车尾轮不悬在网格边缘外
static func build(ground: Callable, length_m: float, seed_i: int, style: Resource, gaps_m: Array = [], gates_m: Array = [], speed_gates_m: Array = [], checkpoints_m: Array = [], boosts_m: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = "TrackRoot"

	# 绝对里程(米) → 道路局部里程 s_m（px_x = START_X + s_m*PX_PER_M）
	var gaps_s: Array = []
	for g in gaps_m:
		gaps_s.append(Vector2(float(g.z0) - START_X / PX_PER_M, float(g.z1) - START_X / PX_PER_M))

	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var half_w := ROAD_WIDTH_M * 0.5
	var s_from := -6.0
	var s_to := length_m + 6.0
	var n_seg := int(ceil((s_to - s_from) / SEG_M))
	for k in range(n_seg + 1):
		var s := minf(s_from + k * SEG_M, s_to)
		var y := ground_height(ground, s)
		verts.append(Vector3(-half_w, y, -s))
		verts.append(Vector3(half_w, y, -s))
		uvs.append(Vector2(0.0, k * SEG_M))
		uvs.append(Vector2(1.0, k * SEG_M))
	var indices := PackedInt32Array()
	for k in range(n_seg):
		var s_a := s_from + k * SEG_M
		var s_b := minf(s_a + SEG_M, s_to)
		var in_gap := false
		for gs in gaps_s:
			# quad 完全落入沟壑区间才剔除（GAP_GRID_M=SEG_M 时沟缘与段界严格对齐）
			if s_a >= gs.x - 0.001 and s_b <= gs.y + 0.001:
				in_gap = true
				break
		if in_gap:
			continue
		var a := k * 2
		# 从 -Z 看下去保持逆时针（法线朝上）
		indices.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, style.body_material(Color("8bbf6a")))

	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "RoadMesh"
	mesh_node.mesh = mesh
	root.add_child(mesh_node)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	var body := StaticBody3D.new()
	body.name = "RoadBody"
	var col := CollisionShape3D.new()
	col.name = "RoadCollision"
	col.shape = shape
	body.add_child(col)
	root.add_child(body)

	root.add_child(build_decor(ground, length_m, seed_i, gaps_s))
	root.add_child(build_gates(ground, gates_m))
	root.add_child(build_line_markers(ground, speed_gates_m))
	root.add_child(build_line_markers(ground, checkpoints_m))
	root.add_child(build_line_markers(ground, boosts_m))
	return root


## 限高架（L11）：gate_frame 门架（横跨路面）+ iron_block 横杆（净空 clear）+ 杆碰撞盒。
## 基座套件模型，场景应用规则；桥梁路径的撞杆判定在 lane_core（几何规则），此处碰撞盒供刚体路径。
static func build_gates(ground: Callable, gates_m: Array) -> Node3D:
	var gates_root := Node3D.new()
	gates_root.name = "HeightGates"
	var bar_len := ROAD_WIDTH_M + 2.0
	for gt in gates_m:
		var s_m: float = float(gt.gx) - START_X / PX_PER_M
		var gy: float = ground_height(ground, s_m)
		var clear: float = float(gt.clear)
		# 门架（复用 gate_frame：起终点门的横向跨度语义）
		var frame: Node3D = preload("res://models/native/gate_frame.tscn").instantiate()
		frame.position = Vector3(0.0, gy, -s_m)
		frame.scale = Vector3(ROAD_WIDTH_M + 2.0, clear + 1.0, 2.0)
		gates_root.add_child(frame)
		# 横杆（iron_block 拉长；杆底 = 净空线，杆高 0.6m）
		var bar_y: float = gy + clear + 0.3
		var bar: Node3D = preload("res://models/native/iron_block.tscn").instantiate()
		bar.position = Vector3(0.0, bar_y, -s_m)
		bar.scale = Vector3(bar_len / 0.92, 0.65, 0.7)
		gates_root.add_child(bar)
		# 碰撞盒（刚体路径真实撞杆；桥梁路径判定在 lane_core）
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(bar_len, 0.6, 0.64)
		col.shape = box
		body.add_child(col)
		body.position = Vector3(0.0, bar_y, -s_m)
		gates_root.add_child(body)
	return gates_root


## 路面标记线（限速检测线 L12 / 分段检查点 L13 共用）：gate_frame 门架 + pressure_plate
## 路面检测板（基座套件）。纯视觉标记：判定在 lane_core/根脚本（规则层），本函数不加碰撞。
static func build_line_markers(ground: Callable, lines_m: Array) -> Node3D:
	var sg_root := Node3D.new()
	sg_root.name = "LineMarkers"
	for sg in lines_m:
		var s_m: float = float(sg.gx) - START_X / PX_PER_M
		var gy: float = ground_height(ground, s_m)
		var frame: Node3D = preload("res://models/native/gate_frame.tscn").instantiate()
		frame.position = Vector3(0.0, gy, -s_m)
		frame.scale = Vector3(ROAD_WIDTH_M + 2.0, 4.0, 2.0)
		sg_root.add_child(frame)
		# 路面检测板：压平的 pressure_plate 横贯路宽（1.3m 原生 → 拉宽到路宽）
		var plate: Node3D = preload("res://models/native/pressure_plate.tscn").instantiate()
		plate.position = Vector3(0.0, gy + 0.09, -s_m)
		plate.scale = Vector3(ROAD_WIDTH_M / 1.3, 1.0, 2.2)
		sg_root.add_child(plate)
	return sg_root


static func ground_height(ground: Callable, s_m: float) -> float:
	return (BASE_GROUND_Y - float(ground.call(START_X + s_m * PX_PER_M))) / PX_PER_M


## 场景应用（用户指令）：装饰一律用基座 game/models 现成模型，起终点用 gate_frame；不造 per-demo 资产
## 沟壑区间内的路旁装饰跳过（悬在洞口上方）；rng 取数顺序与无沟时一致（非沟关卡装饰布点逐位不变）
static func build_decor(ground: Callable, length_m: float, seed_i: int, gaps_s: Array = []) -> Node3D:
	var decor := Node3D.new()
	decor.name = "Decor"
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + seed_i * 77
	var props: Array[PackedScene] = [
		preload("res://models/native/tree.tscn"),
		preload("res://models/native/rock.tscn"),
		preload("res://models/native/bush.tscn"),
	]
	var z := 15.0
	var flip := false
	while z < length_m:
		var side := -1.0 if flip else 1.0
		flip = not flip
		var prop_i := rng.randi_range(0, props.size() - 1)
		var x_m := side * (7.0 + rng.randf() * 4.0)
		var rot_y := rng.randf() * TAU
		var z_here := z
		z += 22.0 + rng.randf() * 16.0
		var in_gap := false
		for gs in gaps_s:
			if z_here >= gs.x and z_here <= gs.y:
				in_gap = true
				break
		if in_gap:
			continue
		var prop: Node3D = props[prop_i].instantiate()
		prop.position = Vector3(x_m, ground_height(ground, z_here) + 0.05, -z_here)
		prop.rotation.y = rot_y
		decor.add_child(prop)
	# 起点/终点门（kit gate_frame；路宽 10m，门放大到横跨路面——仅标记，无碰撞语义）
	for gate in [[0.0, 0.0], [length_m, PI]]:
		var gate_node: Node3D = preload("res://models/native/gate_frame.tscn").instantiate()
		gate_node.position = Vector3(0.0, ground_height(ground, gate[0]), -gate[0])
		gate_node.rotation.y = gate[1]
		gate_node.scale = Vector3(12.0, 6.0, 8.0)
		decor.add_child(gate_node)
	return decor
