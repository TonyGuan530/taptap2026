extends SceneTree
## L24 下沉峡谷配方搜索（临时工具，不提交）：逆风 1.25 + 下沉区 50-70m/-1600
## 高门 30m/14m（爬升段）+ 低门 72m/top12（被气流压低后）——找：都吃 / 单高 / 单低 三类线
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(23)
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
	return {ok = c.last_pass, gate = c.gate_hit, low = c.low_gate_hit, d = c.flight_distance, coins = c.coins}

func _init() -> void:
	var both := []
	var hi := []
	var lo := []
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 26.0
			while ang <= 46.0:
				var r: Dictionary = _mk(n, v, ang)
				if r.ok:
					var row := {n = n, v = v, ang = ang, d = r.d, coins = r.coins}
					if r.gate and r.low: both.append(row)
					elif r.gate and hi.size() < 3: hi.append(row)
					elif r.low and lo.size() < 3: lo.append(row)
				ang += 2.0
	print("BOTH=", both.size())
	for r in both: print("  both ", r)
	print("HI_ONLY=")
	for r in hi: print("  hi   ", r)
	print("LO_ONLY=")
	for r in lo: print("  lo   ", r)
	quit(0)
