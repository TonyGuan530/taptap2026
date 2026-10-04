extends SceneTree
## L6 侧风走廊配方搜索（临时工具，不提交）：折法×角度×顶风(D)保持时长 → 过关+吃高门

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0


func _mk(folds_v: Array, angle: float, hold_t: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(5)
	var pr: Rect2 = c.paper_rect
	for v in folds_v:
		var mid_y: float = 0.5 - 0.5 * float(v)
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(angle, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < 1200:
		c.lateral_input = 1.0 if c.flight_time < hold_t else 0.0
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, d = c.flight_distance, high = c.gate_hit, lat = float(c.lateral), apex = c.apex_m}


func _init() -> void:
	var found := []
	var best_nogate := 0.0
	for n in [4, 5]:
		for v in [0.2, 0.35, 0.5, 0.8]:
			var fs := []
			for k in n:
				fs.append(v)
			for ang in [30.0, 35.0, 40.0, 45.0, 50.0]:
				for hold in [0.4, 0.7, 1.0, 1.3, 1.6]:
					var r: Dictionary = _mk(fs, ang, hold)
					if r.ok and r.high and found.size() < 4:
						found.append({fs = fs.duplicate(), ang = ang, hold = hold, d = r.d, lat = r.lat, apex = r.apex})
					if r.ok:
						best_nogate = maxf(best_nogate, float(r.d))
	print("BEST_PASS_D=", best_nogate)
	print("HIGH_GATE_PASS:")
	for r in found:
		print("  ", r)
	quit(0)
