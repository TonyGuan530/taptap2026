extends SceneTree
## L15 三段侧风配方搜索（临时工具，不提交）：逆风 1.25× + 侧风 +60 →(30m)→ -60 →(50m)→ +60
## 高门 42m/-4m 横位在左拽段（30-50m）。策略：位置窗顶左风(A) 30-50m 顺势向左切

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0


func _mk(folds_v: Array, angle: float, use_pos_hold: bool) -> Dictionary:
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
	while String(c.state) == "fly" and g < 1800:
		var in_pos_window: bool = c.plane_pos.x >= 60.0 + 30.2 * 60.0 and c.plane_pos.x < 60.0 + 50.4 * 60.0
		c.lateral_input = -1.0 if (use_pos_hold and in_pos_window) else 0.0
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
			for ang in [30.0, 35.0, 40.0]:
				var r: Dictionary = _mk(fs, ang, true)
				if r.high:
					best_noGate = maxf(best_noGate, float(r.d))
				if r.ok and r.high and found.size() < 4:
					found.append({fs = fs.duplicate(), ang = ang, d = r.d, lat = r.lat, apex = r.apex})
	print("BEST_D_WITH_GATE=", best_noGate)
	print("HIGH_GATE_PASS:")
	for r in found:
		print("  ", r)
	quit(0)
