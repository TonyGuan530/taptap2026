extends SceneTree
## L36 时机走廊配方搜索（临时工具，不提交）：无风 × 时机门 40m/12m/开窗 2.0-3.2s
## 快线窗前穿越漏门 / 慢线窗后漏门或落地 / 窗内命中三态
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(35)
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23), pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, 1.0)
	var g := 0
	var t40 := -1.0
	while String(c.state) == "fly" and g < 1800:
		var rel: float = (c.plane_pos.x - 60.0) / 60.0
		if t40 < 0.0 and rel >= 40.0: t40 = c.flight_time
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, gate = c.gate_hit, d = c.flight_distance, t40 = t40, coins = c.coins}

func _init() -> void:
	var good := []
	for n in [3, 4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 26.0
			while ang <= 48.0:
				var r: Dictionary = _mk(n, v, ang)
				if r.ok and r.gate and good.size() < 10:
					good.append({n = n, v = v, ang = ang, d = r.d, t40 = r.t40, coins = r.coins})
				ang += 1.0
	print("GOOD=")
	for r in good: print("  g ", r)
	quit(0)
