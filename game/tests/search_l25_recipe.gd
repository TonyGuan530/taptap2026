extends SceneTree
## L25 热气流救援配方搜索（临时工具，不提交）：逆风 80m × 下沉谷 40-52m/-2500 × 热流 54-70m/+3000
## 高门 72m/18m（只有乘好热流才够得着）。找稳健配方 + 摆烂对照
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(24)
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
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 34.0
			while ang <= 50.0:
				var r: Dictionary = _mk(n, v, ang)
				if r.ok and r.gate and good.size() < 10:
					good.append({n = n, v = v, ang = ang, d = r.d, t = r.t, coins = r.coins})
				ang += 2.0
	print("GOOD_GATE=", good.size())
	for r in good: print("  ", r)
	var lazy: Dictionary = _mk(4, 0.2, 45.0)
	print("LAZY_PW03: pass=", lazy.ok, " d=", lazy.d)
	quit(0)
