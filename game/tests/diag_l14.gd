extends SceneTree
## L14 可达性诊断（临时）：各种折法在逆风 70m 关的最大距离
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(folds_v: Array, angle: float, use_pos_hold: bool) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(13)
	var pr: Rect2 = c.paper_rect
	for v in folds_v:
		var mid_y: float = 0.5 - 0.5 * float(v)
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(angle, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < 1800:
		var in_pos_window: bool = c.plane_pos.x >= 60.0 + 35.2 * 60.0 and c.plane_pos.x < 60.0 + 59.8 * 60.0
		c.lateral_input = 1.0 if (use_pos_hold and in_pos_window) else 0.0
		c.step(DELTA)
		g += 1
	return {d = c.flight_distance, high = c.gate_hit, ok = c.last_pass}

func _init() -> void:
	var best := 0.0
	var best_desc := ""
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5, 0.8]:
			var fs := []
			for k in n:
				fs.append(v)
			for ang in [30.0, 35.0, 40.0, 45.0]:
				var r: Dictionary = _mk(fs, ang, true)
				if float(r.d) > best:
					best = float(r.d)
					best_desc = "n=%d v=%s ang=%s d=%.1f high=%s pass=%s" % [n, str(v), ang, float(r.d), str(r.high), str(r.ok)]
	print("BEST_D=", best)
	print("BEST=", best_desc)
	quit(0)
