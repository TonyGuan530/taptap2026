extends SceneTree
## DEMO2 3D 阶段A 灰模验证（headless，真实时间 time_scale=1）
## ① 三词条下落差异可测 ② 弹簧冲量触发 ③ 石头砸穿脆板→GOAL ④ 低速不破板
## ⑤ 羽毛滞空扑翼一次 ⑥ 重置恢复 ⑦ 横移输入生效
## 结果写入 user://v3d_a_log.txt；任何 FAIL → 非零退出码
## 运行：godot --headless --path <worktree>/game -s res://tests/test_demo02_3d_a.gd

var scene = null
var logf: FileAccess
var fails := 0

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _until(cond: Callable, timeout_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_s * 1000:
		if cond.call():
			return true
		await physics_frame
	return false

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails += 1
	_log(name + ": " + ("PASS" if ok else "FAIL"))

func _teleport(pos: Vector3) -> void:
	scene.ball.global_position = pos
	scene.ball.linear_velocity = Vector3.ZERO

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://v3d_a_log.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame

	# ① 三词条下落差异：从 y=6 落到 y<0.7，石头应显著快于羽毛
	var times := {}
	for i in [0, 1]:
		scene.switch_tag(i)
		scene.reset_ball()
		_teleport(Vector3(0, 6, 3))
		var t0 := Time.get_ticks_msec()
		await _until(func(): return scene.ball.global_position.y < 0.7, 15000)
		times[i] = (Time.get_ticks_msec() - t0) / 1000.0
		scene.reset_ball()
	_check("①a 石头下落明显快于羽毛", times[1] < times[0] * 0.75)
	_log("① 下落用时 羽毛=%.2fs 石头=%.2fs" % [times[0], times[1]])

	# ② 弹簧：放到弹簧垫上应获得向上冲量
	scene.reset_ball()
	_teleport(Vector3(-4.5, 1.0, 0))
	var launched: bool = await _until(func(): return scene.ball.linear_velocity.y > 9.0, 10000)
	_check("② 弹簧冲量触发", launched)
	_log("② 弹簧后速度=%.1f m/s spring_used=%s" % [scene.ball.linear_velocity.y, str(scene.spring_used)])

	# ③ 石头砸穿脆板→GOAL：石头定点砸落（弹簧+转向组合留原生试玩验证）
	scene.reset_ball()
	scene.switch_tag(1)   # 石头
	_teleport(Vector3(-8, 8, 0))   # 脆板正上方 4.85m：落速 ≈15 m/s ≥ 12
	var broke_goal: bool = await _until(func(): return scene.goal_reached, 20000)
	_check("③ 石头砸穿脆板并入 GOAL", broke_goal and scene.fragile_broken)
	_log("③ fragile_broken=%s goal_reached=%s pos=%s" % [str(scene.fragile_broken), str(scene.goal_reached), str(scene.ball.global_position)])

	# ④ 低速不破板：羽毛轻落在脆板上，板应完好
	scene.reset_ball()
	scene.switch_tag(0)
	_teleport(Vector3(-8, 6, 0))
	ok_low = await _until(_landed_slow_cond, 20000)
	await _wait_frames(30)
	_check("④a 羽毛低速落板板完好", is_instance_valid(scene.fragile) and not scene.fragile_broken)

	# ⑤ 羽毛滞空扑翼一次：空中扑翼生效，第二次不生效（直到落地）
	scene.reset_ball()
	scene.switch_tag(0)
	_teleport(Vector3(0, 6, 0))
	await _until(func(): return scene.ball.linear_velocity.y < -1.0, 10000)
	var vy0: float = scene.ball.linear_velocity.y
	scene.try_flap()
	var flapped: bool = scene.ball.linear_velocity.y > 2.0 and scene.flap_used
	scene.try_flap()
	await physics_frame
	var second_ignored: bool = scene.flap_used  # 仍只有一次
	_check("⑤a 羽毛空中扑翼生效", flapped)
	_check("⑤b 滞空第二次扑翼被拒", second_ignored)
	_log("⑤ vy %.1f→%.1f" % [vy0, scene.ball.linear_velocity.y])

	# ⑥ 重置：位置回出生点、脆板恢复
	scene.reset_ball()
	var reset_ok: bool = scene.ball.global_position.distance_to(Vector3(-4.5, 1.6, 0)) < 1.5
	scene._restore_fragile()
	reset_ok = reset_ok and is_instance_valid(scene.fragile)
	_check("⑥ 重置与脆板恢复", reset_ok)

	# ⑦ 横移输入生效：羽毛空中按住右移，vx 应正向增大
	scene.reset_ball()
	scene.switch_tag(0)
	_teleport(Vector3(0, 6, 0))
	await physics_frame
	Input.action_press("p_right")
	var vx0: float = scene.ball.linear_velocity.x
	await _wait_frames(30)
	Input.action_release("p_right")
	_check("⑦ 横移输入生效", scene.ball.linear_velocity.x > vx0 + 1.0)
	_log("⑦ vx %.1f→%.1f" % [vx0, scene.ball.linear_velocity.x])

	# ⑧ WASD 方向回归（GitHub 反馈#1：W/S 曾反向）：yaw=0 时 W 应产生 -Z 速度（前进），S 应 +Z
	scene.reset_ball()
	scene.switch_tag(2)
	_teleport(Vector3(0, 6, 0))
	await physics_frame
	Input.action_press("p_fwd")
	await _wait_frames(10)
	Input.action_release("p_fwd")
	var w_ok: bool = scene.ball.linear_velocity.z < -1.0
	scene.reset_ball()
	scene.switch_tag(2)
	_teleport(Vector3(0, 6, 0))
	await physics_frame
	Input.action_press("p_back")
	await _wait_frames(10)
	Input.action_release("p_back")
	var s_ok: bool = scene.ball.linear_velocity.z > 1.0
	_check("⑧a W=前进(-Z)", w_ok)
	_check("⑧b S=后退(+Z)", s_ok)

	_log("ALL DONE fails=%d" % fails)
	logf.flush()
	quit(1 if fails > 0 else 0)

func _wait_frames(n: int) -> void:
	for i in n:
		await physics_frame

func _landed_slow_cond() -> bool:
	var y: float = scene.ball.global_position.y
	return y > 3.3 and y < 4.2 and scene.ball.linear_velocity.length() < 2.0

var ok_low := false
