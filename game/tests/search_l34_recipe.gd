extends SceneTree
## L34 配重峡探针（临时工具，不提交）：逆风 × 120 侧风 × 深左门 46m/12m/-600
## 验证配重必要性：0/1/2 级配重 × 全程顶风 A 的 46m 处横位与门判定
const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0

func _mk(n: int, v: float, ang: float, sw: int) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(33)
	c.upgrades.sideWeight = sw
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23), pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < 1800:
		c.lateral_input = -1.0   # 全程顶风 A
		c.step(DELTA)
		g += 1
	return {ok = c.last_pass, gate = c.gate_hit, d = c.flight_distance, lat = c.lateral, coins = c.coins}

func _init() -> void:
	for sw in [0, 1, 2]:
		var r: Dictionary = _mk(4, 0.2, 30.0, sw)
		print("SW=", sw, ": pass=", r.ok, " gate=", r.gate, " d=", r.d, " lat=", r.lat)
	for n in [4, 5, 6]:
		for v in [0.2, 0.35, 0.5]:
			var ang := 28.0
			while ang <= 40.0:
				var r2: Dictionary = _mk(n, v, ang, 2)
				if r2.ok and r2.gate:
					print("GOOD sw2 n=", n, " v=", v, " ang=", ang, ": d=", r2.d, " lat=", r2.lat, " coins=", r2.coins)
				ang += 2.0
	quit(0)
