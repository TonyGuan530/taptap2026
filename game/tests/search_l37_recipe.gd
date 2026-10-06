extends SceneTree
## L37 俯冲双门配方搜索：无风 × 高门 36m/18m + 低门 46m/8m，两门间按 S 俯冲衔接
## 找：双吃（高门+低门）配方
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float, dive_at: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(36)
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23), pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < 1800:
		c.dive_input = c.flight_time >= dive_at
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, gate = c.gate_hit, low = c.low_gate_hit, d = c.flight_distance, coins = c.coins}

func _init() -> void:
	var both := []
	for n in [3, 4, 5]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 28.0
			while ang <= 42.0:
				var dive_at := 2.0
				while dive_at <= 3.2:
					var r: Dictionary = _mk(n, v, ang, dive_at)
					if r.ok and r.gate and r.low and both.size() < 10:
						both.append({n = n, v = v, ang = ang, dive = dive_at, d = r.d, coins = r.coins})
					dive_at += 0.2
				ang += 1.0
	print("BOTH=", both.size())
	for r in both: print("  ", r)
	quit(0)
