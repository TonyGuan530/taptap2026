extends SceneTree
## L2 配方搜索（临时工具，不提交）：找 低门+过关 / 直通过关 的折法与角度

const CoreScript := preload("res://demo08_3d/flight_core.gd")


func _fly(folds_vert: Array, angle: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(1)
	var pr: Rect2 = c.paper_rect
	for v in folds_vert:
		c.add_fold(pr.position + pr.size * Vector2(0.92, 0.5 - float(v) / 2.0),
			pr.position + pr.size * Vector2(0.92, 0.5 + float(v) / 2.0))
	c.finish_folds()
	c.do_throw(angle, 1.0)
	var g := 0
	while c.state == "fly" and g < 900:
		c.step(1.0 / 60.0)
		g += 1
	return {ok = c.last_pass, d = c.flight_distance, high = c.gate_hit, low = c.low_gate_hit,
		trim = float(c.plane_params.trim), apex = c.apex_m}


func _init() -> void:
	# vert ∈ -1..1：正值折线偏上（trim+），负值偏下。折线中点 (0.92, 0.5-v/2)→(0.92, 0.5+v/2)
	var verts := [-0.9, -0.7, -0.5, -0.3, -0.1, 0.1, 0.3, 0.5, 0.7, 0.9]
	var found_low := []
	var found_pass := []
	for n in [2, 3, 4]:
		for v1 in verts:
			for v2 in verts:
				var fs := [v1, v2]
				if n >= 3:
					fs.append(0.5)
				if n >= 4:
					fs.append(0.7)
				for ang in [10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0]:
					var r: Dictionary = _fly(fs, ang)
					if r.ok and r.low and found_low.size() < 3:
						found_low.append({fs = fs.duplicate(), ang = ang, d = r.d, trim = r.trim, apex = r.apex})
					if r.ok and not r.high and not r.low and found_pass.size() < 3:
						found_pass.append({fs = fs.duplicate(), ang = ang, d = r.d, trim = r.trim, apex = r.apex})
			if found_low.size() >= 2 and found_pass.size() >= 2:
				break
	print("LOW_GATE+PASS:")
	for r in found_low:
		print("  ", r)
	print("PASS_NO_GATE:")
	for r in found_pass:
		print("  ", r)
	quit(0)
