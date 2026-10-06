extends Node3D
## DEMO4 3D 五关巡游录像驱动器：真实输入事件驱动（parse_input_event），无内部作弊位移。
## 校验（headless）：godot --headless --path . res://tests/movie_demo04_3d.tscn
## 录片（空闲时段）：godot --path . res://tests/movie_demo04_3d.tscn --write-movie movie.avi --fixed-fps 60
## 机器人引擎：朝路点行走；贴墙即跳（周期重试）、临边缘探测到沟壑立即起跳、
## 滞空近顶点补二段（超级弹跳）；融合提示出现即按 E；掉坑由游戏恢复机制兜底重试。
## 停点全部取地面可达点；goal 停点越过终点感应区（goal_x±0.5）。

var game: Node3D
var player: CharacterBody3D
var ability: Node

const TOUR := [
	{"waypoints": [6.2, 15.0, 19.5, 23.8], "goal": 31.2},
	{"waypoints": [4.0, 8.0, 13.5, 18.0], "goal": 23.7},
	{"waypoints": [3.0, 6.5, 11.6, 17.5, 20.0], "goal": 21.7},
	{"waypoints": [4.0, 8.0, 13.5, 17.5, 21.5, 24.6], "goal": 30.2},
	{"waypoints": [4.0, 6.5, 8.0, 11.5, 16.5, 19.0, 21.0, 23.5, 29.0], "goal": 31.2},
	{"waypoints": [2.0, 3.2, 4.7, 6.7, 8.0, 11.6, 13.0, 16.5, 18.0, 20.6, 22.5, 25.0, 27.5, 29.5], "goal": 31.2},
]

func _ready() -> void:
	game = load("res://demo04_3d.tscn").instantiate()
	add_child(game)
	for i in 5:
		await get_tree().physics_frame
	player = game.get_node("Player")
	ability = game.get_node("AbilityState")
	_tour()

func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)

func _tap_jump() -> void:
	_key(KEY_SPACE, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_key(KEY_SPACE, false)
	await get_tree().physics_frame

func _ray_hit(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var space := player.get_world_3d().direct_space_state
	return not space.intersect_ray(q).is_empty()

func _goto(x_target: float, li_expected: int, timeout := 90.0) -> bool:
	## 走到 x_target：贴墙跳（每 8 帧）、临沟边缘跳（射线探测）、空中近顶点二段；
	## 终点提前触发推进（感应区比停点容差更早命中）→ 立即视为到达
	var t0 := Time.get_ticks_msec()
	var tick := 0
	var dir := 1.0
	var stuck_pos := player.position
	var stuck_frames := 0
	while Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		await get_tree().physics_frame
		tick += 1
		if game.level_idx != li_expected or game.won:
			return true   # 终点已触发、关卡已推进
		var d: float = x_target - player.position.x
		if absf(d) < 0.45:
			return true
		dir = signf(d)
		if player.position.distance_to(stuck_pos) < 0.05:
			stuck_frames += 1
		else:
			stuck_pos = player.position
			stuck_frames = 0
		if stuck_frames == 240:
			_key(KEY_D, false)
			_key(KEY_A, false)
			_key(KEY_SPACE, false)
			for i in 10:
				await get_tree().physics_frame
			stuck_frames = 0
		elif stuck_frames > 480:
			_key(KEY_D, false)
			_key(KEY_A, false)
			return false
		_key(KEY_D if dir > 0.0 else KEY_A, true)
		# 融合提示 → 按 E（先松方向键防止斜向漂移）
		if game._fuse_target and not game._fuse_target.is_empty():
			_key(KEY_D, false)
			_key(KEY_A, false)
			_key(KEY_E, true)
			await get_tree().physics_frame
			await get_tree().physics_frame
			_key(KEY_E, false)
			continue
		if player.is_on_floor() and absf(player.velocity.y) < 0.01:
			var gap_ahead := not _ray_hit(player.position + Vector3(dir * 0.45, 0.3, 0), player.position + Vector3(dir * 0.45, -4.0, 0))
			var wall_ahead := _ray_hit(player.position + Vector3(0, 0.2, 0), player.position + Vector3(dir * 0.85, 0.2, 0))
			if gap_ahead or (wall_ahead and tick % 8 == 0):
				await _tap_jump()
		elif not player.is_on_floor() and player.jumps_used >= 1 \
				and player.jumps_used < player.ability_state.max_jumps() \
				and player.velocity.y <= 2.0 and tick % 4 == 0:
			await _tap_jump()
	_key(KEY_D, false)
	_key(KEY_A, false)
	return false

func _tour() -> void:
	var fails := 0
	for li in TOUR.size():
		var seg: Dictionary = TOUR[li]
		if game.level_idx != li:
			print("TOUR FAIL 关卡错位 li=%d idx=%d" % [li, game.level_idx])
			fails += 1
			break
		var seg_ok := true
		for wp in seg.waypoints:
			if not await _goto(wp, li):
				print("TOUR FAIL li=%d waypoint=%.1f (px=%.1f)" % [li, wp, player.position.x])
				seg_ok = false
				fails += 1
				break
		if seg_ok and await _goto(seg.goal, li):
			var advanced := false
			for i in 120:
				await get_tree().physics_frame
				if game.won or game.level_idx == li + 1:
					advanced = true
					break
			if advanced:
				print("TOUR OK li=%d DNA=%d 累计碎片=%d" % [li, ability.dna.size(), ability.shards_total])
			else:
				print("TOUR FAIL li=%d 终点未触发 (px=%.1f)" % [li, player.position.x])
				fails += 1
		elif seg_ok:
			print("TOUR FAIL li=%d goal (px=%.1f)" % [li, player.position.x])
			fails += 1
	print("TOUR DONE fails=%d won=%s 总碎片=%d" % [fails, str(game.won), ability.shards_total])
	if fails == 0 and game.won:
		print("ALL PASS")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
