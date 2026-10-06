extends SceneTree
## L40 三轴终考配方搜索：逆风+左推-60 × 摆动低门 64m/top12/0±360/3s × 俯冲
## 三轴：俯冲定高度、侧风推横位（顶风 D 窗修正）、摆相定时
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float, dive_at: float, d0: float, d1: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(39)
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23), pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < 1800:
		c.dive_input = c.flight_time >= dive_at and dive_at > 0.0
		c.lateral_input = 1.0 if (c.flight_time >= d0 and c.flight_time < d1) else 0.0
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, low = c.low_gate_hit, d = c.flight_distance, coins = c.coins}

func _init() -> void:
	var good := []
	for n in [3, 4, 5]:
		for v in [0.35, 0.5]:
			var ang := 26.0
			while ang <= 36.0:
				for dive in [1.6, 1.8, 2.0, 2.2]:
					for dwin in [[0.4, 1.2], [0.6, 1.4], [0.8, 1.6]]:
						var r: Dictionary = _mk(n, v, ang, dive, dwin[0], dwin[1])
						if r.ok and r.low and good.size() < 12:
							good.append({n = n, v = v, ang = ang, dive = dive, D = dwin[0], d = r.d, coins = r.coins})
				ang += 1.0
	print("GOOD=", good.size())
	for r in good: print("  ", r)
	quit(0)
