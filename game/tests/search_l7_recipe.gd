extends SceneTree
## L7 回风峡谷配方搜索（临时工具，不提交）：右侧风+1 下顶风(A)左拐吃 -6m 高门，放手由风送回中线，70m 过关

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0


func _mk(folds_v: Array, angle: float, hold_t: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(6)
	var pr: Rect2 = c.paper_rect
	for v in folds_v:
		var mid_y: float = 0.5 - 0.5 * float(v)
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(angle, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < 1500:
		c.lateral_input = -1.0 if c.flight_time < hold_t else 0.0
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, d = c.flight_distance, high = c.gate_hit, lat = float(c.lateral), apex = c.apex_m}


func _init() -> void:
	var found := []
	var best_noGate := 0.0
	for n in [5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var fs := []
			for k in n:
				fs.append(v)
			for ang in [30.0, 35.0, 40.0, 45.0]:
				for hold in [0.8, 1.1, 1.4, 1.7, 2.0, 2.3]:
					var r: Dictionary = _mk(fs, ang, hold)
					if r.high:
						best_noGate = maxf(best_noGate, float(r.d))
					if r.ok and r.high and found.size() < 4:
						found.append({fs = fs.duplicate(), ang = ang, hold = hold, d = r.d, lat = r.lat, apex = r.apex})
	print("BEST_D_WITH_GATE=", best_noGate)
	print("HIGH_GATE_PASS:")
	for r in found:
		print("  ", r)
	quit(0)
