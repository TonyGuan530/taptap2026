extends SceneTree
## L28 谷风低门配方搜索（临时工具，不提交）：逆风+右推60 × 下沉谷 36-46m/-2000 × 高门28m/14m + 右侧低门52m/8m/+240
## 三轴：高度（谷）+ 横移（侧风，按 D 乘漂）+ 距离。低线=平抛顶谷按 D；高线=抬头
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float, rudder: int, t_hold: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(27)
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23), pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < 1800:
		c.lateral_input = float(rudder) if c.flight_time < t_hold else 0.0
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, gate = c.gate_hit, low = c.low_gate_hit, d = c.flight_distance, lat = c.lateral, coins = c.coins}

func _init() -> void:
	var lo := []
	var hi := []
	for n in [4, 5, 6]:
		for v in [0.2, 0.35]:
			var ang := 24.0
			while ang <= 40.0:
				for strat in [[1, 9.0], [1, 3.0], [0, 0.0]]:
					var r: Dictionary = _mk(n, v, ang, strat[0], strat[1])
					if r.ok and r.low and lo.size() < 6:
						lo.append({n = n, v = v, ang = ang, hold = strat[1], d = r.d, lat = r.lat, coins = r.coins})
					elif r.ok and r.gate and hi.size() < 4:
						hi.append({n = n, v = v, ang = ang, hold = strat[1], d = r.d, coins = r.coins})
				ang += 1.0
	print("LOW_LINE=", lo.size())
	for r in lo: print("  lo ", r)
	print("HI_LINE=")
	for r in hi: print("  hi ", r)
	quit(0)
