extends SceneTree
## demo-05 V3 Gate：dominance simulation（ChatGPT 2026-10-03 续评指定）
## 8 个简单 policy × 每政策 30 局（风×雨四象限均衡分层），统计胜率/评分，检验是否存在
## 「在所有天气组合下同时最高生存率」的 dominant policy——重点是盯防「高地开局」。
## 不改任何游戏数值；只读 pending_wind/pending_rain（情报派在有高地储备时本就能拿到真话）。
## 运行：godot --headless --path game -s res://tests/test_demo05_dominance.gd

const GAMES_PER_POLICY := 30
const TIME_SCALE := 60.0
const TILE_ORDER := ["highland", "valley", "forest", "cave", "wetland"]
const ROUTE_ORDER := [1, 2, 0]  # 东4 南5 北6，优先最便宜的

const POLICIES := [
	{id = "all_cave", desc = "保险派：全洞穴"},
	{id = "all_highland", desc = "全高地（盯防对象）"},
	{id = "all_valley", desc = "投机派：全河谷"},
	{id = "all_forest", desc = "全森林"},
	{id = "even5", desc = "均匀分散五地块"},
	{id = "intel_play", desc = "情报派：2高地解锁真预报→按天气投资"},
	{id = "valley_relocate", desc = "激进+抢运：全河谷→灾后必抢运"},
	{id = "light_load", desc = "速度派：只存4份→轻装奔袭"},
]

var log_lines: Array = []


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)
	var f := FileAccess.open("user://dominance05log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()


func _idx(scene, id: String) -> int:
	for i in scene.TILES.size():
		if scene.TILES[i].id == id:
			return i
	return 0


## 狩猎指定天气（east/rain）的种子：先只消费 4 次 randf 复刻 _roll_forecast，命中再建场景
func _make_scene(east: bool, rain: bool) -> Control:
	for attempt in 400:
		var s0 := 70000 + attempt * 7
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


## policy 决定下一个采集点投给哪块地
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


func _play_game(scene, policy: String, invested: int) -> int:
	# 返回最终投入的点数；跑完一整局（准备→应变→结算→撤离→结算画面）
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
	return invested


func _run() -> void:
	await process_frame
	Engine.time_scale = TIME_SCALE
	Engine.max_physics_steps_per_frame = 240
	var weathers := [[true, true], [true, false], [false, true], [false, false]]
	var stats := {}
	for p in POLICIES:
		stats[p.id] = {games = 0, win = 0, partial = 0, lose = 0, score = 0, rainW = 0, rainN = 0, dryW = 0, dryN = 0, eastW = 0, eastN = 0, westW = 0, westN = 0}
	var game_no := 0
	for p in POLICIES:
		for g in GAMES_PER_POLICY:
			var wpair: Array = weathers[g % 4]
			var scene: Control = await _make_scene(wpair[0], wpair[1])
			if scene == null:
				_log("SKIP: 找不到天气种子 east=%s rain=%s" % [wpair[0], wpair[1]])
				continue
			await _play_game(scene, p.id, 0)
			var st: Dictionary = stats[p.id]
			st.games += 1
			match scene.result:
				"win":
					st.win += 1
				"partial":
					st.partial += 1
				_:
					st.lose += 1
			st.score += scene._score()
			if scene.rain:
				st.rainN += 1
				if scene.result == "win":
					st.rainW += 1
			else:
				st.dryN += 1
				if scene.result == "win":
					st.dryW += 1
			if scene.wind == "east":
				st.eastN += 1
				if scene.result == "win":
					st.eastW += 1
			else:
				st.westN += 1
				if scene.result == "win":
					st.westW += 1
			game_no += 1
			if game_no % 40 == 0:
				_log("进度 %d/240 局…" % game_no)
			scene.queue_free()
			await physics_frame
	# ---- 汇总（V5 Gate：天气×风向拆分）----
	_log("")
	_log("==== demo-05 dominance simulation V5（%d policy × %d 局，time_scale %.0f）====" % [POLICIES.size(), GAMES_PER_POLICY, TIME_SCALE])
	_log("policy             局  胜%%   雨天胜%%   旱天胜%%   东风胜%%   西风胜%%   均分")
	var worst := {}
	for p in POLICIES:
		var st: Dictionary = stats[p.id]
		if st.games == 0:
			continue
		var wr: float = 100.0 * st.win / st.games
		var rn: int = st.rainN + st.dryN
		var rw: float = 100.0 * st.rainW / maxi(1, st.rainN)
		var dw: float = 100.0 * st.dryW / maxi(1, st.dryN)
		var ew: float = 100.0 * st.eastW / maxi(1, st.eastN)
		var ww: float = 100.0 * st.westW / maxi(1, st.westN)
		var asc: float = 1.0 * st.score / st.games
		_log("%-17s %3d %5.1f  %3.0f/%-2d(%3.0f%%)  %3.0f/%-2d(%3.0f%%)  %3.0f/%-2d(%3.0f%%)  %3.0f/%-2d(%3.0f%%)  %6.1f" % [p.id, st.games, wr, st.rainW, st.rainN, rw, st.dryW, st.dryN, dw, st.eastW, st.eastN, ew, st.westW, st.westN, ww, asc])
	# ---- V5 Gate A/B/C ----
	_log("")
	var top_surv := -1.0
	var top_score := -1.0
	for p in POLICIES:
		var st: Dictionary = stats[p.id]
		if st.games == 0:
			continue
		top_surv = maxf(top_surv, 100.0 * st.win / st.games)
		top_score = maxf(top_score, 1.0 * st.score / st.games)
	var mid_rain := []
	var wind_gap := {}
	for p in POLICIES:
		var st: Dictionary = stats[p.id]
		if st.games == 0 or p.id == "all_cave":
			continue
		var rw: float = 100.0 * st.rainW / maxi(1, st.rainN)
		if rw >= 20.0 and rw <= 70.0 and st.rainN >= 10:
			mid_rain.append(p.id)
		var gap: float = absf(100.0 * st.eastW / maxi(1, st.eastN) - 100.0 * st.westW / maxi(1, st.westN))
		if gap >= 15.0:
			wind_gap[p.id] = gap
	_log("Gate A（≥2 非洞穴策略雨天胜率 20-70 区间）：%s → %s" % [", ".join(mid_rain), "PASS" if mid_rain.size() >= 2 else "FAIL"])
	_log("Gate B（≥1 策略东西风胜率差 ≥15pp）：%s → %s" % [str(wind_gap), "PASS" if wind_gap.size() >= 1 else "FAIL"])
	var c_fail := []
	for p in POLICIES:
		var st: Dictionary = stats[p.id]
		if st.games == 0:
			continue
		if 100.0 * st.win / st.games >= top_surv and 1.0 * st.score / st.games >= top_score:
			c_fail.append(p.id)
	_log("Gate C（无「最高生存率+同最高均分」策略）：%s → %s" % [", ".join(c_fail), "PASS" if c_fail.size() == 0 else "FAIL"])
	Engine.time_scale = 1.0
	_log("==== 完成 ====")
	quit()
