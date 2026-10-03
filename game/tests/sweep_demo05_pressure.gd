extends SceneTree
## demo-05 V4 压力参数 sweep（ChatGPT 2026-10-03 裁决：解除数值冻结，只碰两个旋钮）
## grid：采集次数 7/8/9 × 路线需求增量 +1/+2；8 policy × 12 局/组合（天气四象限各 3）
## 运行：godot --headless --path game -s res://tests/sweep_demo05_pressure.gd -- 0,1,2
## combo 编号：0=(7,+1) 1=(7,+2) 2=(8,+1) 3=(8,+2) 4=(9,+1) 5=(9,+2)
## 采样时同时记录「封顶新评分」（min(食,4)*2+min(水,4)*2）供评分改版参考

const GAMES_PER_POLICY := 12
const TIME_SCALE := 60.0
const TILE_ORDER := ["highland", "valley", "forest", "cave", "wetland"]
const ROUTE_ORDER := [1, 2, 0]
const BASE_NEEDS := [6, 4, 5]
const COMBOS := [[7, 1], [7, 2], [8, 1], [8, 2], [9, 1], [9, 2]]

const POLICIES := [
	{id = "all_cave", desc = "保险派"},
	{id = "all_highland", desc = "全高地"},
	{id = "all_valley", desc = "全河谷"},
	{id = "all_forest", desc = "全森林"},
	{id = "even5", desc = "均匀分散"},
	{id = "intel_play", desc = "情报派"},
	{id = "valley_relocate", desc = "激进+抢运"},
	{id = "light_load", desc = "速度派"},
]

var log_lines: Array = []


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)
	var f := FileAccess.open("user://sweep05log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()


func _idx(scene, id: String) -> int:
	for i in scene.TILES.size():
		if scene.TILES[i].id == id:
			return i
	return 0


func _make_scene(east: bool, rain: bool) -> Control:
	for attempt in 400:
		var s0 := 90000 + attempt * 7
		seed(s0)
		var w: bool = randf() < 0.5
		var r: bool = randf() < 0.6
		randf()
		randf()
		if w == east and r == rain:
			seed(s0)
			var s: Control = load("res://demo05_volcano.tscn").instantiate()
			root.add_child(s)
			await physics_frame
			await physics_frame
			if (s.pending_wind == "east") == east and s.pending_rain == rain:
				return s
			s.queue_free()
			await physics_frame
	return null


func _invest(scene, policy: String, invested: int) -> String:
	match policy:
		"all_cave":
			return "cave"
		"all_highland":
			return "highland"
		"all_valley":
			return "valley"
		"all_forest":
			return "forest"
		"even5":
			return TILE_ORDER[invested % 5]
		"intel_play":
			if invested < 2:
				return "highland"
			return "cave" if scene.pending_rain else "valley"
		"valley_relocate":
			return "valley"
		"light_load":
			return "highland" if invested < 2 else "cave"
	return "cave"


func _play_game(scene, policy: String) -> void:
	var invested := 0
	var t0 := Time.get_ticks_msec()
	while scene.phase == "prepare" and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame
		var cap := 4 if policy == "light_load" else 999
		while scene.gather > 0 and invested < cap:
			scene._on_tile_click(_idx(scene, _invest(scene, policy, invested)))
			invested += 1
	t0 = Time.get_ticks_msec()
	while scene.phase == "announce" and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame
	if scene.phase == "adjust":
		match policy:
			"valley_relocate":
				scene._use_emergency("relocate")
				scene._do_relocate(_idx(scene, "valley"))
			"light_load":
				scene._use_emergency("abandon")
			_:
				scene._use_emergency("skip")
		t0 = Time.get_ticks_msec()
		while scene.phase == "adjust" and Time.get_ticks_msec() - t0 < 30000:
			await physics_frame
	t0 = Time.get_ticks_msec()
	while scene.phase == "resolve" and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame
	if scene.phase == "decide":
		var total: int = scene.supply.food + scene.supply.water
		for i in ROUTE_ORDER:
			if total >= scene._route_need(i):
				scene._choose_route(i)
				break


func _run() -> void:
	await process_frame
	Engine.time_scale = TIME_SCALE
	var combo_args := "0,1,2,3,4,5"
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() > 0:
		combo_args = user_args[0]
	_log("")
	_log("==== demo-05 压力 sweep：combos=%s（8 policy × %d 局）====" % [combo_args, GAMES_PER_POLICY])
	for cs in combo_args.split(","):
		var ci := int(cs)
		var points: int = COMBOS[ci][0]
		var need_add: int = COMBOS[ci][1]
		var stats := {}
		for p in POLICIES:
			stats[p.id] = {games = 0, win = 0, partial = 0, lose = 0, food = 0, water = 0}
		var weathers := [[true, true], [true, false], [false, true], [false, false]]
		for p in POLICIES:
			for g in GAMES_PER_POLICY:
				var wpair: Array = weathers[g % 4]
				var scene: Control = await _make_scene(wpair[0], wpair[1])
				if scene == null:
					continue
				scene.timer = float(points * 4)
				for i in scene.ROUTES.size():
					scene.ROUTES[i].need = BASE_NEEDS[i] + need_add
				await _play_game(scene, p.id)
				var st: Dictionary = stats[p.id]
				st.games += 1
				match scene.result:
					"win":
						st.win += 1
					"partial":
						st.partial += 1
					_:
						st.lose += 1
				st.food += scene.supply.food
				st.water += scene.supply.water
				scene.queue_free()
				await physics_frame
		_log("")
		_log("-- combo %d：采集 %d 点 · 路线需求 %d/%d/%d --" % [ci, points, BASE_NEEDS[0] + need_add, BASE_NEEDS[1] + need_add, BASE_NEEDS[2] + need_add])
		_log("policy             局  胜%%  惨胜%%  败%%  均食  均水  封顶分")
		for p in POLICIES:
			var st: Dictionary = stats[p.id]
			if st.games == 0:
				continue
			var wr: float = 100.0 * st.win / st.games
			var pr: float = 100.0 * st.partial / st.games
			var lr: float = 100.0 * st.lose / st.games
			var af: float = 1.0 * st.food / st.games
			var aw: float = 1.0 * st.water / st.games
			var live: float = 100.0 * (st.win + st.partial) / st.games
			var capped: float = (70.0 if live > 0 else 10.0) * live / 100.0 + mini(int(af), 4) * 2.0 + mini(int(aw), 4) * 2.0
			_log("%-17s %3d %5.1f %5.1f %5.1f %5.1f %5.1f %6.1f" % [p.id, st.games, wr, pr, lr, af, aw, capped])
	Engine.time_scale = 1.0
	_log("")
	_log("==== sweep 完成 ====")
	quit()
