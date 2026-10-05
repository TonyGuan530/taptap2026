extends SceneTree
## L15 诊断：三种策略下 42m 门位横位与距离（逆风+三段侧风 +60/-60/+60）
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(folds_v: Array, angle: float, policy: String) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(14)
	var pr: Rect2 = c.paper_rect
	for v in folds_v:
		var mid_y: float = 0.5 - 0.5 * float(v)
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(angle, 1.0)
	var g := 0
	var lat42 := 99999.0
	while String(c.state) == "fly" and g < 1800:
		var input := 0.0
		match policy:
			"none":
				input = 0.0
			"poswin":
				input = -1.0 if (c.plane_pos.x >= 60.0 + 30.2 * 60.0 and c.plane_pos.x < 60.0 + 50.4 * 60.0) else 0.0
			"fullA":
				input = -1.0
		c.lateral_input = input
		c.step(DELTA)
		if lat42 > 9000.0 and c.plane_pos.x >= 60.0 + 42.0 * 60.0:
			lat42 = float(c.lateral)
		g += 1
	return {d = float(c.flight_distance), high = c.gate_hit, ok = c.last_pass, lat42 = lat42}

func _init() -> void:
	for policy in ["none", "poswin", "fullA"]:
		var best_d := 0.0
		var best_line := ""
		for n in [5, 6]:
			for v in [0.2, 0.35]:
				var fs := []
				for k in n:
					fs.append(v)
				for ang in [30.0, 35.0, 40.0]:
					var r: Dictionary = _mk(fs, ang, policy)
					if float(r.d) > best_d:
						best_d = float(r.d)
						best_line = "n=%d v=%s ang=%.0f d=%.1f lat42=%s high=%s pass=%s" % [n, str(v), ang, float(r.d), str(r.lat42), str(r.high), str(r.ok)]
		print("%s: best_d=%.1f | %s" % [policy, best_d, best_line])
	quit(0)
