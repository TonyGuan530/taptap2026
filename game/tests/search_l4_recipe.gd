extends SceneTree
## L4 配方搜索（临时工具，不提交）：双门横侧位（高门 -8m / 低门 +8m）下找
## 直通过关 / 转向吃高门过关 / 转向吃低门过关 的折法+角度+转向保持时长

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0


## 折一条竖线：v=上下度（mid_y=0.5-0.5v），半长 0.23（线长 0.46）
func _mk(folds_v: Array, angle: float, dir: float, hold_t: float) -> Dictionary:
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
		c.lateral_input = dir if c.flight_time < hold_t else 0.0
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, d = c.flight_distance, high = c.gate_hit, low = c.low_gate_hit,
		lat = float(c.lateral), trim = float(c.plane_params.trim)}


func _init() -> void:
	var vset := [0.2, 0.5, 0.8, 1.0]
	var found := {straight = [], high = [], low = []}
	for n in [4, 5]:
		for v in vset:
			var fs := []
			for k in n:
				fs.append(v)
			for ang in [35.0, 40.0, 45.0, 50.0, 55.0]:
				var rs: Dictionary = _mk(fs, ang, 0.0, 0.0)
				if rs.ok and found.straight.size() < 3:
					found.straight.append({fs = fs.duplicate(), ang = ang, d = rs.d, trim = rs.trim})
				for hold in [1.0, 1.2, 1.4, 1.6]:
					var rh: Dictionary = _mk(fs, ang, -1.0, hold)
					if rh.ok and rh.high and found.high.size() < 3:
						found.high.append({fs = fs.duplicate(), ang = ang, hold = hold, d = rh.d, lat = rh.lat})
					var rl: Dictionary = _mk(fs, ang, 1.0, hold)
					if rl.ok and rl.low and found.low.size() < 3:
						found.low.append({fs = fs.duplicate(), ang = ang, hold = hold, d = rl.d, lat = rl.lat})
	print("STRAIGHT_PASS:")
	for r in found.straight:
		print("  ", r)
	print("HIGH_GATE_PASS:")
	for r in found.high:
		print("  ", r)
	print("LOW_GATE_PASS:")
	for r in found.low:
		print("  ", r)
	quit(0)
