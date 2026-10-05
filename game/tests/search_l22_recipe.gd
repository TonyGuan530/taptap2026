extends SceneTree
## L22 顺风斜风配方搜索（临时工具，不提交）：顺风恒推 + 侧风右推60，高门 42m/-240 横位/12m 以上
## 策略：按住 A 顶风左切到 -4m 横位；顺风提速 → 修正窗口短，需早按住 + 高角度保 12m 高度

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0


func _mk(folds_v: Array, angle: float, mode: int, t0: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(21)
	var pr: Rect2 = c.paper_rect
	for v in folds_v:
		var mid_y: float = 0.5 - 0.5 * float(v)
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(angle, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < 1800:
		var on := false
		match mode:
			0: on = true                                  # 全程按住 A
			1: on = c.flight_time >= t0                   # t0 秒后按住 A
			2: on = c.flight_time < t0                    # t0 秒前按住 A（后松手回正）
		c.lateral_input = -1.0 if on else 0.0
		c.step(DELTA)
		g += 1
	var lat_at_gate := 0.0
	return {ok = c.last_pass, d = c.flight_distance, gate = c.gate_hit,
		lat = float(c.lateral), apex = c.apex_m, t = c.flight_time}


func _init() -> void:
	var found := []
	var best_noGate := 0.0
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var fs := []
			for k in n:
				fs.append(v)
			for ang in [35.0, 40.0, 45.0, 50.0, 55.0]:
				for mode in [0, 1, 2]:
					for t0 in [0.5, 1.0]:
						var r: Dictionary = _mk(fs, ang, mode, t0)
						if r.gate:
							best_noGate = maxf(best_noGate, float(r.d))
						if r.ok and r.gate and found.size() < 8:
							found.append({n = n, v = v, ang = ang, mode = mode, t0 = t0,
								d = r.d, lat = r.lat, apex = r.apex, t = r.t})
	print("BEST_D_WITH_GATE=", best_noGate)
	print("GATE_PASS:")
	for r in found:
		print("  ", r)
	quit(0)
