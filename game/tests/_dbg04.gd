extends SceneTree
## 临时调试：完整复现用例1（ts=4，L1→L2→L3），观察卡点（用完即删）
const RIGHT := KEY_RIGHT
const JUMP := KEY_SPACE
var scene = null

func _init() -> void:
	_run()

func _press(key: Key, frames: int) -> void:
	for i in frames:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.pressed = true
		Input.parse_input_event(ev)
		await physics_frame
	var up := InputEventKey.new()
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await physics_frame

func _tap(key: Key) -> void:
	await _press(key, 2)

func _ground_ahead(x: float) -> bool:
	for b in scene.blocks:
		if b[0] <= x and b[0] + b[2] >= x and b[1] >= 440 and b[1] <= 500:
			return true
	return false

func _wall_ahead() -> bool:
	for b in scene.blocks:
		if b[0] > scene.px + 6 and b[0] < scene.px + 84 and b[1] < scene.py - 6:
			return true
	return false

func _fuse_all() -> void:
	for a in scene.aliens:
		if not scene.dna.has(a.id) and absf(scene.px - a.x) < 55.0:
			await _tap(KEY_E)

func _run() -> void:
	await process_frame
	Engine.time_scale = 4.0
	scene = load("res://demo04_soup.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var jump_cd := 0
	var wins := 0
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 100000:
		await physics_frame
		frames += 1
		jump_cd = maxi(0, jump_cd - 1)
		if scene.state == "win":
			wins += 1
			print("WIN level %d at f=%d elapsed=%.0f shards=%d" % [scene.level_idx + 1, frames, scene.elapsed, scene.level_shards])
			if wins >= 3:
				break
			scene._advance()
			await physics_frame
			continue
		if not scene.keys.get(RIGHT, false):
			var ev := InputEventKey.new()
			ev.keycode = RIGHT
			ev.pressed = true
			Input.parse_input_event(ev)
		await _fuse_all()
		if jump_cd == 0:
			if scene.on_floor:
				if (not _ground_ahead(scene.px + 50.0)) or (not _ground_ahead(scene.px + 110.0)) or _wall_ahead():
					await _tap(JUMP)
					jump_cd = 20
			elif scene.dna.has("double") and scene.jumps_used == 1 and scene.vy > -40.0:
				await _tap(JUMP)
				jump_cd = 8
		if frames % 60 == 0:
			print("f=%d L=%d px=%.0f py=%.0f vy=%.0f floor=%s jumps=%d dna=%d cd=%d" % [frames, scene.level_idx + 1, scene.px, scene.py, scene.vy, scene.on_floor, scene.jumps_used, scene.dna.size(), jump_cd])
	print("END wins=%d level=%d px=%.0f" % [wins, scene.level_idx + 1, scene.px])
	Engine.time_scale = 1.0
	quit()
