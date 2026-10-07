extends SceneTree
## demo09-3d 场景骨架冒烟测试（headless，不弹窗）
## 用例1 骨架完整：TrackRoot(RoadMesh+RoadBody 同源) / Decor 套件装饰 / CarView / HUD 文本
## 用例2 轮胎视图语义：2 条目 = 2 个轮 pivot（不镜像成 4）
## 用例3 驾驶推进：注入油门 2 秒，车辆沿 -Z 前进、无提前结算、HUD 里程递增
## 用例4 姿态映射：旧 car_angle 正=车头向下 → 3D rotation.x 取负
## 用例5 校验拒绝：L4 超预算布局被拒且场景不被破坏（走 GarageModel 统一入口）
## 用例6 自动发车：auto_start=true（截图路径）进入场景即 L1 drive
## 运行：Godot --headless --path game -s res://tests/test_demo09_3d_scene.gd

var passes := 0
var fails := 0


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)


func _check(cond: bool, tag: String) -> void:
	if cond:
		passes += 1
		_log("PASS " + tag)
	else:
		fails += 1
		_log("FAIL " + tag)


func _run() -> void:
	var s = load("res://demo09_3d.tscn").instantiate()
	s.auto_start = false
	root.add_child(s)
	await process_frame
	_check(s.core == null, "用例0 auto_start=false 时不自动发车")

	_check(s.start_level(0, [[0.15, 26.0], [0.85, 26.0]]), "用例1a L1 标准布局发车成功")
	await process_frame
	var track = s.get_node_or_null("TrackRoot")
	var road_mesh = track.get_node_or_null("RoadMesh") if track != null else null
	var road_body = track.get_node_or_null("RoadBody") if track != null else null
	_check(track != null and road_mesh != null and road_mesh.mesh != null and road_mesh.mesh.get_surface_count() >= 1,
		"用例1b 道路可视 mesh 存在（%d 面）" % (road_mesh.mesh.get_surface_count() if road_mesh != null and road_mesh.mesh != null else 0))
	var col = road_body.get_child(0) if road_body != null and road_body.get_child_count() > 0 else null
	_check(road_body != null and col != null and col.shape is ConcavePolygonShape3D and col.shape.get_faces().size() > 0,
		"用例1c 道路碰撞存在且来自同一网格（%d 顶点）" % (col.shape.get_faces().size() / 3 if col != null and col.shape != null else 0))
	var mesh_faces: int = road_mesh.mesh.get_faces().size() / 3 if road_mesh != null else 0
	var col_faces: int = col.shape.get_faces().size() / 3 if col != null and col.shape != null else 0
	_check(mesh_faces == col_faces and mesh_faces > 0, "用例1d 可视与碰撞三角数一致（%d）" % mesh_faces)
	var decor = track.get_node_or_null("Decor")
	_check(decor != null and decor.get_child_count() >= 3,
		"用例1e 套件装饰已布点（%d 个，含起终点 gate_frame）" % (decor.get_child_count() if decor != null else 0))
	var car_view = s.get_node_or_null("CarView")
	_check(car_view != null and car_view.get_child_count() >= 4, "用例1f CarView 存在（车身+座舱+2 轮）")
	_check(s.status_label != null and s.status_label.text.length() > 10, "用例1g HUD 状态文本非空：%s" % s.status_label.text)

	var pivots := 0
	for c in car_view.get_children():
		if c.name.begins_with("WheelPivot"):
			pivots += 1
	_check(pivots == 2, "用例2 轮条目 2 → 轮视图 2（不镜像成 4）")

	s.throttle_on(2.0)
	var z0: float = car_view.position.z
	var m0: float = float(s.core.car_pos.x)
	for i in range(150):
		await physics_frame
	_check(s.core.state == "drive", "用例3a 150 帧后仍在驾驶（无提前结算）")
	_check(car_view.position.z < z0 - 20.0, "用例3b 车辆沿 -Z 前进（z %.1f → %.1f）" % [z0, car_view.position.z])
	var m1: float = float(s.core.car_pos.x)
	_check(m1 > m0 + 200.0, "用例3c 核心里程推进（%.0f → %.0f px）" % [m0, m1])
	_check("速度" in s.status_label.text and float(s.core.flight_time) > 2.0, "用例3d HUD 持续更新（计时 %.1f 秒）" % float(s.core.flight_time))

	s.set_physics_process(false)   # 停物理步，专测映射本身（否则一步积分先改角度）
	s.core.car_angle = 0.3
	s.car_view.apply_state(s.core)
	_check(absf(float(car_view.rotation.x) + 0.3) < 1e-6,
		"用例4 姿态映射取负（car_angle=+0.3 车头向下 → rotation.x=%.4f）" % float(car_view.rotation.x))
	s.set_physics_process(true)

	var pos_before: Vector3 = car_view.position
	var rejected: bool = not s.start_level(3, [[0.5, 26.0], [0.5, 26.0], [0.5, 12.0]])
	_check(rejected, "用例5a L4 超预算布局被拒（Σ=4700>4300）")
	_check(car_view.position == pos_before and s.core.state == "drive", "用例5b 拒绝后场景未被破坏")
	var restored: bool = s.start_level(3, [[0.08, 26.0], [0.92, 26.0]])
	_check(restored and int(s.model.level_idx) == 3 and s.get_node_or_null("CarView") != null, "用例5c 合规布局可在 L4 重新发车")

	s.queue_free()
	var s2 = load("res://demo09_3d.tscn").instantiate()   # auto_start 默认 true（截图管线同路径）
	root.add_child(s2)
	await process_frame
	await physics_frame
	_check(s2.core != null and s2.core.state == "drive" and s2.get_node_or_null("CarView") != null,
		"用例6 auto_start=true 进场景即 L1 drive（截图路径）")
	# ── 用例7-9：A4 追尾 CameraRig（在 s2 上验证，auto_start 实例已在驾驶态） ──
	_check(s2.cam_rig != null and s2.cam_spring != null and s2.cam != null and s2.cam.current
		and absf(s2.cam_spring.spring_length - 8.0) < 1e-6 and s2.cam_spring.collision_mask == 1,
		"用例7 Rig→SpringArm(臂长8,mask=1)→Camera 装配正确")
	# 平滑跟随：瞬移车 50m，rig 不瞬移，随后收敛
	var target_after: Vector3 = s2.car_view.position + Vector3(0.0, 3.0, 0.0)
	s2.core.car_pos.x += 500.0
	s2.car_view.apply_state(s2.core)
	await physics_frame
	var d_near: float = s2.cam_rig.position.distance_to(s2.car_view.position + Vector3(0.0, 3.0, 0.0))
	_check(d_near > 20.0, "用例8a 瞬移后 rig 不跟跳（距目标 %.1f m）" % d_near)
	for i in range(150):
		await physics_frame
	var d_far: float = s2.cam_rig.position.distance_to(s2.car_view.position + Vector3(0.0, 3.0, 0.0))
	_check(d_far < 3.0, "用例8b 150 帧后 rig 收敛到车（距目标 %.2f m）" % d_far)
	# 地平线解耦：车俯仰改变时 rig 保持水平
	s2.set_physics_process(false)
	s2.core.car_angle = 0.4
	s2.car_view.apply_state(s2.core)
	var car_rx: float = float(s2.car_view.rotation.x)
	var rig_rx: float = float(s2.cam_rig.rotation.x)
	var spring_rx: float = float(s2.cam_spring.rotation.x)
	_check(absf(car_rx + 0.4) < 1e-4 and absf(rig_rx) < 1e-6 and absf(spring_rx - deg_to_rad(-14.0)) < 1e-4,
		"用例9 车俯仰 0.4 时 rig 保持水平（车=%.5f rig=%.5f spring=%.5f 期望≈%.5f）" % [car_rx, rig_rx, spring_rx, deg_to_rad(-14.0)])
	s2.set_physics_process(true)
	s2.queue_free()

	_log("==== 汇总：%d PASS / %d FAIL ====" % [passes, fails])
	quit(1 if fails > 0 else 0)
