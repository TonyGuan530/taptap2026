extends SceneTree
## L32 狂风精准配方搜索（临时工具，不提交）：逆风 × 120 双倍侧风 × 高门 44m/12m/+700
## 全帆乘风课：被动入门带 / 配重 1 级版应漏门（设计的"物品场合性"）
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float, sw: int) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(31)
	c.upgrades.sideWeight = sw
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
	return {ok = c.last_pass, gate = c.gate_hit, d = c.flight_distance, lat = c.lateral, coins = c.coins}

func _init() -> void:
	var good := []
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 26.0
			while ang <= 44.0:
				var r: Dictionary = _mk(n, v, ang, 0)
				if r.ok and r.gate and good.size() < 8:
					good.append({n = n, v = v, ang = ang, d = r.d, lat = r.lat, coins = r.coins})
				ang += 1.0
	print("GOOD=")
	for r in good: print("  g ", r)
	var sw1: Dictionary = _mk(4, 0.2, 30.0, 1)
	print("SIDEWEIGHT1 ang30: ok=", sw1.ok, " gate=", sw1.gate, " lat=", sw1.lat)
	quit(0)
