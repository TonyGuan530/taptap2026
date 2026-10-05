extends SceneTree
## L26 谷底摆门配方搜索（临时工具，不提交）：逆风 72m × 下沉谷 40-52m/-2500 × 摆动低门 58m/±420/3s
## 高门 30m/14m（爬升段）。找：低线（俯冲穿谷+数拍）/高线（抬头）双类配方
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(25)
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
	return {ok = c.last_pass, gate = c.gate_hit, low = c.low_gate_hit, d = c.flight_distance, t = c.flight_time, coins = c.coins}

func _init() -> void:
	var lo := []
	var hi := []
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 24.0
			while ang <= 46.0:
				var r: Dictionary = _mk(n, v, ang)
				if r.ok:
					var row := {n = n, v = v, ang = ang, d = r.d, t = r.t, coins = r.coins}
					if r.low and lo.size() < 6: lo.append(row)
					elif r.gate and hi.size() < 6: hi.append(row)
				ang += 1.0
	print("LOW_LINE=", lo.size())
	for r in lo: print("  lo ", r)
	print("HI_LINE=")
	for r in hi: print("  hi ", r)
	quit(0)
