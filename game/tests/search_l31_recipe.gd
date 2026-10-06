extends SceneTree
## L31 风暴回廊配方搜索（临时工具，不提交）：逆风+右推60 × 谷 30-40/-2200 × 热流 44-58/+2800 × 摆动高门 62m/16m/+300/±360/3s
## 能量+漂移+门相三重时序。找：过关吃门 / 过关漏门 / 摆烂 对照
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float, rudder: float, t_hold: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(30)
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
	var good := []
	var partial := []
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 28.0
			while ang <= 48.0:
				for strat in [[0.0, 0.0], [1.0, 1.5], [1.0, 3.0]]:
					var r: Dictionary = _mk(n, v, ang, strat[0], strat[1])
					if r.ok and r.gate and good.size() < 8:
						good.append({n = n, v = v, ang = ang, rud = strat[0], hold = strat[1], d = r.d, t = r.t, lat = r.lat, coins = r.coins})
					elif r.ok and not r.gate and partial.size() < 4:
						partial.append({n = n, v = v, ang = ang, hold = strat[1], d = r.d, coins = r.coins})
				ang += 1.0
	print("GOOD=")
	for r in good: print("  g ", r)
	print("PASS_NO_GATE=")
	for r in partial: print("  p ", r)
	quit(0)
