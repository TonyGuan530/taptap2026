extends Node
## DEMO4 3D 巡游驱动器（调试组件）：真实输入事件驱动五关通关，
## 仅在显式开启时挂载——Web ?tour=1（URL 参数）或原生 --tour 启动参数。
## 用于无窗口录证（CDP 截屏/录像）与回归演示；不影响正常游玩路径。

var game: Node3D
var player: CharacterBody3D
var ability: Node
var done := false

const TOUR := [
	{"waypoints": [6.2, 15.0, 19.5, 23.8], "goal": 31.2},
	{"waypoints": [4.0, 8.0, 13.5, 18.0], "goal": 23.7},
	{"waypoints": [3.0, 6.5, 11.6, 17.5, 20.0], "goal": 21.7},
	{"waypoints": [4.0, 8.0, 13.5, 17.5, 21.5, 24.6], "goal": 30.2},
	{"waypoints": [4.0, 6.5, 8.0, 11.5, 16.5, 19.0, 21.0, 23.5, 29.0], "goal": 31.2},
]

func _ready() -> void:
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
	## 走到 x_target：贴墙跳（每 8 帧）、临沟边缘跳（+0.45m 射线探测）、空中近顶点二段；
	## 终点提前触发推进（感应区比停点容差更早命中）→ 立即视为到达
	var t0 := Time.get_ticks_msec()
	var tick := 0
	var dir := 1.0
	var stuck_pos: Vector3 = player.position
	var stuck_frames := 0
	var last_wall_jump := -999.0
	var last_gap_jump := -999.0
	var last_air := -999.0
	while Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		await get_tree().physics_frame
		tick += 1
		if game.level_idx != li_expected or game.won:
			return true
		var d: float = x_target - player.position.x
		if absf(d) < 0.45:
			return true
		dir = signf(d)
		_key(KEY_D if dir > 0.0 else KEY_A, true)
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
			if gap_ahead or (wall_ahead and (Time.get_ticks_msec() - last_wall_jump) >= 130):
				last_wall_jump = Time.get_ticks_msec()
				last_air = Time.get_ticks_msec()
				await _tap_jump()
		elif not player.is_on_floor() and player.jumps_used >= 1 \
				and player.jumps_used < player.ability_state.max_jumps() \
				and player.velocity.y <= 2.0 and (Time.get_ticks_msec() - last_air) >= 70:
			await _tap_jump()
	_key(KEY_D, false)
	_key(KEY_A, false)
	return false

func _tour() -> void:
	var fails := 0
	for li in TOUR.size():
		var seg: Dictionary = TOUR[li]
		if game.level_idx != li:
			fails += 1
			break
		var seg_ok := true
		for wp in seg.waypoints:
			if not await _goto(wp, li):
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
			if not advanced:
				fails += 1
		elif seg_ok:
			fails += 1
	done = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.tourDone='%d'" % fails, true)
	print("TOUR DONE fails=%d won=%s" % [fails, str(game.won)])
