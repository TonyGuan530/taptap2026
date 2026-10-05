extends SceneTree
## L21 诊断：各折法/角度在 55m 低门处的横位/高度 + 总距离
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(folds_v: Array, angle: float, use_pos_hold: bool) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(20)
	var pr: Rect2 = c.paper_rect
	for v in folds_v:
		var mid_y: float = 0.5 - 0.5 * float(v)
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(angle, 1.0)
	var g := 0
	var lat55 := 99999.0
	var y55 := 99999.0
	while String(c.state) == "fly" and g < 1800:
		var in_pos_window: bool = c.plane_pos.x >= 60.0 + 50.2 * 60.0 and c.plane_pos.x < 60.0 + 55.4 * 60.0
		c.lateral_input = -1.0 if (use_pos_hold and in_pos_window) else 0.0
		var px_before: float = c.plane_pos.x
		c.step(DELTA)
		if lat55 > 9000.0 and px_before < 60.0 + 55.0 * 60.0 and c.plane_pos.x >= 60.0 + 55.0 * 60.0:
			lat55 = float(c.lateral)
			y55 = (460.0 - float(c.plane_pos.y)) / 60.0
		g += 1
	return {d = float(c.flight_distance), low = c.low_gate_hit, ok = c.last_pass, lat55 = lat55, y55 = y55}

func _init() -> void:
	for fs in [[-0.5, -0.5, -0.5, -0.5, -0.5], [-0.9, -0.9, -0.9, -0.9, -0.9], [-0.5, -0.5, -0.5], [-0.3, -0.3, -0.3, -0.3, -0.3, -0.3], [0.2, 0.2, 0.2, 0.2, 0.2], [-0.5, -0.5, -0.5, -0.5, -0.5, -0.5]]:
		for ang in [20.0, 25.0, 30.0, 35.0, 40.0]:
			var r: Dictionary = _mk(fs, ang, false)
			if float(r.d) > 55.0:
				print("fs=%s ang=%.0f d=%.1f lat55=%s y55=%.1f low=%s pass=%s" % [str(fs), ang, float(r.d), str(r.lat55), float(r.y55), str(r.low), str(r.ok)])
	quit(0)
