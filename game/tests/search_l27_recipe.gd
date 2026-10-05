extends SceneTree
## L27 热流摆门配方搜索（临时工具，不提交）：逆风 80m × 沉后托波形 × 摆动高门 74m/18m/±420/3.5s
## 能量（出口高度）+ 门位（摆相）双时序。找过关吃门配方 + 吃门高度不足档 + 摆烂对照
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(26)
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23), pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < 1800:
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, gate = c.gate_hit, d = c.flight_distance, t = c.flight_time, coins = c.coins}

func _init() -> void:
	var good := []
	var partial := []
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 30.0
			while ang <= 50.0:
				var r: Dictionary = _mk(n, v, ang)
				if r.gate and good.size() < 8:
					good.append({n = n, v = v, ang = ang, ok = r.ok, d = r.d, t = r.t, coins = r.coins})
				elif r.ok and not r.gate and partial.size() < 4:
					partial.append({n = n, v = v, ang = ang, d = r.d, t = r.t, coins = r.coins})
				ang += 1.0
	print("GATE_HITS=")
	for r in good: print("  g ", r)
	print("PASS_NO_GATE=")
	for r in partial: print("  p ", r)
	quit(0)
