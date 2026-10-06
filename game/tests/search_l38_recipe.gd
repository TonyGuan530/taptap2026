extends SceneTree
## L38 俯冲摆门配方搜索：无风 × 摆动低门 66m/top12/0±360/3s，俯冲时机 × 门相双时序
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float, dive_at: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(37)
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23), pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < 1800:
		c.dive_input = c.flight_time >= dive_at and dive_at > 0.0
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, low = c.low_gate_hit, d = c.flight_distance, coins = c.coins}

func _init() -> void:
	var good := []
	for n in [3, 4, 5]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 26.0
			while ang <= 40.0:
				var dive_at := 1.6
				while dive_at <= 2.8:
					var r: Dictionary = _mk(n, v, ang, dive_at)
					if r.ok and r.low and good.size() < 12:
						good.append({n = n, v = v, ang = ang, dive = dive_at, d = r.d, coins = r.coins})
					dive_at += 0.2
				ang += 1.0
	print("GOOD=", good.size())
	for r in good: print("  ", r)
	quit(0)
