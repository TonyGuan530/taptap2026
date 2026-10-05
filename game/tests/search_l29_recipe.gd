extends SceneTree
## L29 双谷接力配方搜索（临时工具，不提交）：逆风 70m × 双下沉谷 30-40/-50-60（各-1800）
## 高门 24m/14m + 窗口低门 46m/12m。找：过关线（含吃门数）
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(28)
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23), pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < 1800:
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, gate = c.gate_hit, low = c.low_gate_hit, d = c.flight_distance, t = c.flight_time, coins = c.coins}

func _init() -> void:
	var hi := []
	var lo := []
	var both := []
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 24.0
			while ang <= 46.0:
				var r: Dictionary = _mk(n, v, ang)
				if r.ok:
					var row := {n = n, v = v, ang = ang, d = r.d, t = r.t, coins = r.coins}
					if r.gate and r.low: both.append(row)
					elif r.gate and hi.size() < 5: hi.append(row)
					elif r.low and lo.size() < 5: lo.append(row)
				ang += 1.0
	print("BOTH=", both.size())
	for r in both: print("  both ", r)
	print("HI=")
	for r in hi: print("  hi ", r)
	print("LO=")
	for r in lo: print("  lo ", r)
	quit(0)
