extends SceneTree
## L30 终局峡谷配方搜索（临时工具，不提交）：逆风+左推60 × 谷 36-44/-1600 × 热流 48-60/+2400 × 左侧高门 66m/16m/-240
## 顺流线（被动左漂）与抗流线（顶风右切）双找
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float, rudder: float, t_hold: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(29)
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23), pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < 1800:
		c.lateral_input = rudder if c.flight_time < t_hold else 0.0
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, gate = c.gate_hit, d = c.flight_distance, t = c.flight_time, lat = c.lateral, coins = c.coins}

func _init() -> void:
	var g_pass := []
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 28.0
			while ang <= 46.0:
				for strat in [[0.0, 0.0], [-1.0, 1.0], [-1.0, 2.0]]:
					var r: Dictionary = _mk(n, v, ang, strat[0], strat[1])
					if r.ok and r.gate and g_pass.size() < 10:
						g_pass.append({n = n, v = v, ang = ang, rud = strat[0], hold = strat[1], d = r.d, t = r.t, lat = r.lat, coins = r.coins})
				ang += 1.0
	print("GATE_PASS=", g_pass.size())
	for r in g_pass: print("  ", r)
	quit(0)
