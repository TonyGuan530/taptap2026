extends SceneTree
## 调试：复制 dominance 的精确代码路径，all_cave 跑 2 局（西旱+东雨），FileAccess 逐步落盘
var lg: FileAccess


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)
	if lg:
		lg.seek_end()
		lg.store_string("\n" + t)
		lg.flush()


func _idx(scene, id: String) -> int:
	for i in scene.TILES.size():
		if scene.TILES[i].id == id:
			return i
	return 0


func _make_scene(want_east: bool, want_rain: bool) -> Control:
	for attempt in 400:
		var s0 := 70000 + attempt * 17
		seed(s0)
		var w: bool = randf() < 0.5
		var r: bool = randf() < 0.6
		randf()
		randf()
		if w == want_east and r == want_rain:
			seed(s0)
			var s: Control = load("res://demo05_volcano.tscn").instantiate()
			root.add_child(s)
			await physics_frame
			await physics_frame
			if (s.pending_wind == "east") == want_east and s.pending_rain == want_rain:
				return s
			s.queue_free()
			await physics_frame
	return null


func _play(scene) -> void:
	var invested := 0
	var tick := 0
	var t0 := Time.get_ticks_msec()
	while scene.phase == "prepare" and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame
		tick += 1
		if tick % 20 == 0:
			_log("  tick %d gather=%d cave=%s timer=%.1f" % [tick, scene.gather, JSON.stringify(scene.stored.cave), scene.timer])
		while scene.gather > 0:
			scene._on_tile_click(_idx(scene, "cave"))
			invested += 1
	_log(" prepare end: invested=%d cave=%s phase=%s" % [invested, JSON.stringify(scene.stored.cave), scene.phase])
	t0 = Time.get_ticks_msec()
	while scene.phase == "announce" and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame
	_log(" announce end: phase=%s wind=%s rain=%s" % [scene.phase, scene.wind, scene.rain])
	if scene.phase == "adjust":
		scene._use_emergency("skip")
		t0 = Time.get_ticks_msec()
		while scene.phase == "adjust" and Time.get_ticks_msec() - t0 < 30000:
			await physics_frame
	t0 = Time.get_ticks_msec()
	while scene.phase == "resolve" and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame
	_log(" resolve end: stored=%s" % JSON.stringify(scene.stored))
	if scene.phase == "decide":
		var total: int = scene.supply.food + scene.supply.water
		_log(" decide: supply=%s total=%d bonus=%d needs=%d/%d/%d" % [JSON.stringify(scene.supply), total, scene.route_bonus, scene._route_need(0), scene._route_need(1), scene._route_need(2)])
		for i in [1, 2, 0]:
			if total >= scene._route_need(i):
				scene._choose_route(i)
				break


func _run() -> void:
	await process_frame
	Engine.time_scale = 60.0
	Engine.max_physics_steps_per_frame = 240
	lg = FileAccess.open("user://debug05trace.log", FileAccess.WRITE)
	for wd in [[false, false], [true, true]]:
		var scene: Control = await _make_scene(wd[0], wd[1])
		_log("== game want_east=%s want_rain=%s got wind=%s rain=%s ==" % [wd[0], wd[1], scene.pending_wind, scene.pending_rain])
		await _play(scene)
		_log(" result=%s margin=%d score=%d" % [scene.result, scene.margin, scene._score()])
		for e in scene.events:
			_log(" EV: " + e)
		scene.queue_free()
		await physics_frame
	lg.flush()
	_log("done")
	quit()
