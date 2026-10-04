extends SceneTree
## demo-08 3D 阶段 B2 核心不变量（headless，固定 delta=1/60）：
## 规则变化 B2：门横位入配置（gate_side/low_gate_side，默认 0）；L4 高门 -8m/低门 +8m 横侧位。
## 双用例：合理折法+转向 可过关吃门；无输入直线 吃不到侧位门；摆烂（无折）不可过。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_b2.gd（失败退出码非零）

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0
const MAX_STEPS := 1500

var passes := 0
var fails := 0
var log_lines: Array = []


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)


func _check(cond: bool, tag: String) -> void:
	if cond:
		passes += 1
		_log("PASS " + tag)
	else:
		fails += 1
		_log("FAIL " + tag)


## L4 一掷：folds_v 折线（mid_y=0.5-0.5v 半长 0.23）、angle、转向 dir(-1/0/+1)、保持 hold_t 秒
func _mk_l4(folds_v: Array, angle: float, dir: float, hold_t: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(3)
	var pr: Rect2 = c.paper_rect
	for v in folds_v:
		var mid_y: float = 0.5 - 0.5 * float(v)
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(angle, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.lateral_input = dir if c.flight_time < hold_t else 0.0
		c.step(DELTA)
		g += 1
	return c


func _pts(folds_v: Array, angle: float, dir: float, hold_t: float) -> Array:
	var c2: Object = CoreScript.new()
	c2.start_level(3)
	var pr: Rect2 = c2.paper_rect
	for v in folds_v:
		var mid_y: float = 0.5 - 0.5 * float(v)
		c2.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c2.finish_folds()
	c2.do_throw(angle, 1.0)
	var pts: Array = []
	var g := 0
	while String(c2.state) == "fly" and g < MAX_STEPS:
		c2.lateral_input = dir if c2.flight_time < hold_t else 0.0
		c2.step(DELTA)
		pts.append(c2.plane_pos)
		g += 1
	return pts


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 B2 核心不变量测试开始（L4 双门横侧位）")

	# B2-1 无输入直通：过关但两侧门都吃不到（横移 0 vs 门位 ±8m，出 5m 半宽）
	var straight := _mk_l4([0.2, 0.2, 0.2, 0.2], 35.0, 0.0, 0.0)
	_check(straight.last_pass and not straight.gate_hit and not straight.low_gate_hit,
		"B2-1 无输入直通 %.1fm 过关、侧位门全 miss（横移语义生效）" % float(straight.flight_distance))
	_check(absf(float(straight.lateral)) < 1e-9, "B2-1b 无输入横向恒 0")

	# B2-2 转向吃高门（左舵 1.2s）：过关 + 高门 +3，低门封锁
	var high := _mk_l4([0.2, 0.2, 0.2, 0.2], 35.0, -1.0, 1.2)
	_check(high.last_pass and high.gate_hit and not high.low_gate_hit,
		"B2-2 左舵吃高门 %.1fm 过关（横位 %.0f px）" % [float(high.flight_distance), float(high.lateral)])
	_check(high.coins == 20 and high.gate_coins == 3,
		"B2-2b 收益 20 = 门奖 3 + int(d/10) 5 + 过关奖 12")

	# B2-3 转向吃低门（俯冲折法右舵 0.8s）：过关 + 低门 +3，高门封锁
	var low := _mk_l4([-0.5, -0.5, -0.5, -0.5], 26.0, 1.0, 0.8)
	_check(low.last_pass and low.low_gate_hit and not low.gate_hit,
		"B2-3 右舵吃低门 %.1fm 过关（trim=%.2f 横位 %.0f px）" % [float(low.flight_distance), float(low.plane_params.trim), float(low.lateral)])
	_check(low.coins == 20 and low.gate_coins == 3, "B2-3b 收益 20（互斥：高门未触发）")

	# B2-4 转向不刷里程：直通 vs 左舵前进轨迹逐位一致
	var p0 := _pts([0.2, 0.2, 0.2, 0.2], 35.0, 0.0, 0.0)
	var p1 := _pts([0.2, 0.2, 0.2, 0.2], 35.0, -1.0, 1.2)
	var same := p0.size() == p1.size()
	if same:
		for i in p0.size():
			var va: Vector2 = p0[i]
			var vb: Vector2 = p1[i]
			if va.distance_to(vb) > 1e-9:
				same = false
				break
	_check(same, "B2-4 转向不改变前进/高度轨迹（%d 步逐位一致）" % p0.size())

	# B2-5 摆烂不可过：无折直扔 L4 距离远低于 55
	var lazy: Object = CoreScript.new()
	lazy.start_level(3)
	lazy.finish_folds()
	lazy.do_throw(30.0, 1.0)
	var g5 := 0
	while String(lazy.state) == "fly" and g5 < MAX_STEPS:
		lazy.step(DELTA)
		g5 += 1
	_check(not lazy.last_pass and lazy.flight_distance < 55.0,
		"B2-5 摆烂无折 %.1fm < 55 不可过" % float(lazy.flight_distance))

	# B2-6 合成互斥：先吃高门（横位界内+高度达标）→ 40m 处横移到低门位也不再吃低门
	var c6: Object = CoreScript.new()
	c6.start_level(3)
	var pr6: Rect2 = c6.paper_rect
	c6.apply_fold_params(0.92, 0.4, 0.3)
	c6.finish_folds()
	c6.do_throw(30.0, 1.0)
	c6.plane_pos = Vector2(60.0 + 33.5 * 60.0, 460.0 - 13.0 * 60.0)  # 高门 34m 前，13m 高
	c6.velocity = Vector2(600.0, 0.0)
	c6.lateral = -480.0  # 高门横位界内
	c6.flight_time = 0.0
	for k in 6:
		var e6: String = c6.step(DELTA)
		if e6 == "finish" or e6 == "ground" or e6 == "timeout":
			break
		if c6.plane_pos.x >= 60.0 + 34.2 * 60.0:
			break
	_check(c6.gate_hit and not c6.low_gate_hit, "B2-6a 高门（横位 -8m）命中")
	c6.plane_pos = Vector2(60.0 + 39.5 * 60.0, 460.0 - 8.0 * 60.0)  # 低门 40m 前，8m 高（≤10m）
	c6.velocity = Vector2(600.0, 0.0)
	c6.lateral = 480.0  # 已横移到低门位
	for k in 6:
		var e6b: String = c6.step(DELTA)
		if e6b == "finish" or e6b == "ground" or e6b == "timeout":
			break
		if c6.plane_pos.x >= 60.0 + 40.2 * 60.0:
			break
	_check(not c6.low_gate_hit and c6.coins == 3, "B2-6b 已吃高门 → 低门封锁（互斥，币仍 3）")

	# B2-7 遮挡物理基础（headless）：地面碰撞体在位、射线可查询；SpringArm 镜头收近的视觉效果=窗口会话核
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 5:
		await physics_frame
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(0.0, 2.0, -50.0), Vector3(0.0, -1.0, -50.0))
	var hit: Dictionary = space.intersect_ray(q)
	_check(not hit.is_empty() and absf(float(hit.position.y)) < 0.01,
		"B2-7 地面碰撞体在位（射线命中 y=%.2f），遮挡 Ready；镜头收近留窗口会话核" % float(hit.get("position", Vector3.ZERO).y))

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_b2_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
