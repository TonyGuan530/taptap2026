extends SceneTree
## L33 热流之巅配方搜索（临时工具，不提交）：逆风 × 深谷 34-44/-2200 × 强热流 46-60/+3200 × 超高门 60m/24m
## 精确高度课：出口高度只有骑得正的弧线够得着 24m
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(32)
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23), pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, 1.0)
	var g := 0
	var h60 := -1.0
	while String(c.state) == "fly" and g < 1800:
		var rel: float = (c.plane_pos.x - 60.0) / 60.0
		if h60 < 0.0 and rel >= 60.0: h60 = (460.0 - c.plane_pos.y) / 60.0
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, gate = c.gate_hit, d = c.flight_distance, h60 = h60, coins = c.coins}

func _init() -> void:
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 30.0
			while ang <= 50.0:
				var r: Dictionary = _mk(n, v, ang)
				print("n=", n, " v=", v, " ang=", ang, ": ok=", r.ok, " gate=", r.gate, " d=", r.d, " h60=", r.h60, " coins=", r.coins)
				ang += 2.0
	quit(0)
