extends SceneTree
## L21 顺风摆门配方搜索（临时工具，不提交）：顺风推力 + 摆动低门 55m/+120±240/3s
## 高门不设。策略：折法×角度——顺风加速后俯冲到低门位置

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
	while String(c.state) == "fly" and g < 1800:
		# 位置窗顶左风(A)——低门在 +120m 偏右，需要向左修正对准
		var in_pos_window: bool = c.plane_pos.x >= 60.0 + 50.2 * 60.0 and c.plane_pos.x < 60.0 + 55.4 * 60.0
		c.lateral_input = -1.0 if (use_pos_hold and in_pos_window) else 0.0
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, d = c.flight_distance, low = c.low_gate_hit, lat = float(c.lateral), apex = c.apex_m}


func _init() -> void:
	var found := []
	var best_noGate := 0.0
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var fs := []
			for k in n:
				fs.append(v)
			for ang in [30.0, 35.0, 40.0, 45.0]:
				var r: Dictionary = _mk(fs, ang, false)
				if r.low:
					best_noGate = maxf(best_noGate, float(r.d))
				if r.ok and r.low and found.size() < 6:
					found.append({fs = fs.duplicate(), ang = ang, d = r.d, lat = r.lat, apex = r.apex})
	print("BEST_D_WITH_GATE=", best_noGate)
	print("LOW_GATE_PASS:")
	for r in found:
		print("  ", r)
	quit(0)
