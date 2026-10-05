extends SceneTree
## 诊断：各配方在 48m 门位处的横位（逆风三段）
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
	var lat_at_gate := 99999.0
	var gd := 0.0
	while String(c.state) == "fly" and g < 1800:
		var in_pos_window: bool = c.plane_pos.x >= 60.0 + 30.2 * 60.0 and c.plane_pos.x < 60.0 + 61.8 * 60.0
		c.lateral_input = 1.0 if (use_pos_hold and in_pos_window) else 0.0
		var px_before: float = c.plane_pos.x
		c.step(DELTA)
		gd = float(c.flight_distance)
		if lat_at_gate > 9000.0 and px_before < 60.0 + 48.0 * 60.0 and c.plane_pos.x >= 60.0 + 48.0 * 60.0:
			lat_at_gate = float(c.lateral)
		g += 1
	return {d = gd, high = c.gate_hit, ok = c.last_pass, lat_gate = lat_at_gate}

func _init() -> void:
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var fs := []
			for k in n:
				fs.append(v)
			for ang in [35.0, 40.0, 45.0]:
				var r: Dictionary = _mk(fs, ang, true)
				if float(r.d) > 55.0:
					print("n=%d v=%s ang=%.0f d=%.1f lat48=%s high=%s pass=%s" % [n, str(v), ang, float(r.d), str(r.lat_gate), str(r.high), str(r.ok)])
	quit(0)
