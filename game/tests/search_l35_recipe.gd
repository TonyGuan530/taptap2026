extends SceneTree
## L35 终幕双门配方搜索（临时工具，不提交）：逆风+左推60 × 谷 30-38/-2000 × 热流 44-56/+2800
## 双摆门：高门 60m/18m/-240±360/3s（左摆）+ 低门 66m/10m/+300±300/3.5s（右摆）
## 找：高门线 / 低门线 / 双吃（毕业）/ 摆烂
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float, rudder: float, t_hold: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(34)
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
	return {ok = c.last_pass, gate = c.gate_hit, low = c.low_gate_hit, d = c.flight_distance, t = c.flight_time, lat = c.lateral, coins = c.coins}

func _init() -> void:
	var hi := []
	var lo := []
	var both := []
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 28.0
			while ang <= 46.0:
				for strat in [[0.0, 0.0], [1.0, 1.5], [-1.0, 1.0]]:
					var r: Dictionary = _mk(n, v, ang, strat[0], strat[1])
					if r.ok:
						var row := {n = n, v = v, ang = ang, rud = strat[0], hold = strat[1], d = r.d, t = r.t, lat = r.lat, coins = r.coins}
						if r.gate and r.low and both.size() < 4: both.append(row)
						elif r.gate and hi.size() < 6: hi.append(row)
						elif r.low and lo.size() < 6: lo.append(row)
				ang += 2.0
	print("BOTH=", both.size())
	for r in both: print("  b ", r)
	print("HI=")
	for r in hi: print("  h ", r)
	print("LO=")
	for r in lo: print("  l ", r)
	quit(0)
