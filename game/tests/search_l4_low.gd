extends SceneTree
## L4 低门可达性聚焦搜索（临时）：俯冲/混合 trim 组合 × 角度 × 右舵保持
## 结论用于判断"L4 低门 + 过关 55m"在现有机制下是否可达（内容发现）

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0


func _mk(folds_v: Array, angle: float, hold_t: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(3)
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
	return {ok = c.last_pass, d = c.flight_distance, low = c.low_gate_hit, apex = c.apex_m}


func _init() -> void:
	var base_sets := [
		[-0.9, -0.9, -0.9, -0.9], [-0.9, -0.9], [-0.5, -0.5, -0.5, -0.5],
		[0.0, 0.0, 0.0, 0.0], [0.3, 0.3, 0.3, 0.3],
		[0.2, 0.2, 0.2, 0.2, -0.9], [0.2, 0.2, 0.2, 0.2, 0.0],
		[-0.5, -0.5, 0.2, 0.2], [-0.9, 0.2, 0.2, 0.2], [0.0, 0.0, 0.0, 0.0, 0.0],
	]
	var best_d := 0.0
	var best_low_d := 0.0
	var found := []
	for fs in base_sets:
		for ang in [12.0, 15.0, 18.0, 22.0, 26.0, 30.0, 35.0, 40.0]:
			for hold in [0.8, 1.1, 1.4, 1.7, 2.0]:
				var r: Dictionary = _mk(fs, ang, hold)
				best_d = maxf(best_d, float(r.d))
				if r.low:
					best_low_d = maxf(best_low_d, float(r.d))
					if r.ok and found.size() < 3:
						found.append({fs = fs.duplicate(), ang = ang, hold = hold, d = r.d})
	print("BEST_D_ALL=", best_d)
	print("BEST_D_WITH_LOWGATE=", best_low_d)
	print("LOW_PASS_FOUND:")
	for r in found:
		print("  ", r)
	quit(0)
