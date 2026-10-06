extends SceneTree
## demo-08 3D 阶段 C51（阶梯②新商店物品·侧翼配重）核心不变量（headless，固定 delta=1/60）：
## 规则变化（已记录）：wind_damp_mult = 1 - 0.25×sideWeight 级，仅衰减风推分量（side 型与正交侧风），
## 不作用于玩家横向输入与无风阻尼——"抗吹"不是"抗打舵"。池子扩至 8 物。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c51.gd（失败退出码非零）

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0
const MAX_STEPS := 2000

var passes := 0
var fails := 0
var log_lines: Array = []


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)


func _check(cond: bool, tag: String) -> void:
	if cond:
		passes += 1
		_log("PASS " + tag)
	else:
		fails += 1
		_log("FAIL " + tag)


func _fly_l22(n: int, v: float, ang: float, hold_a: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(21)   # L22 顺风斜风（index 21）
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.lateral_input = -1.0 if c.flight_time < hold_a else 0.0
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C51 侧翼配重测试开始")

	# C51-1 静态锚：池 8 物、侧翼配重 4 币可叠加、零级阻尼系数 1.0
	var c1: Object = CoreScript.new()
	c1.start_level(0)
	var found := false
	for it in c1.SHOP_POOL:
		if String(it.id) == "sideweight":
			found = true
			_check(int(it.price) == 4 and not bool(it.get("unique", false)),
				"C51-1 侧翼配重入池（4 币可叠加）")
	_check(found and int(c1.SHOP_POOL.size()) == 9 and absf(float(c1.wind_damp_mult()) - 1.0) < 1e-6,
		"C51-1b 池 9 物 / 零级阻尼 1.0")

	# C51-2 购买语义：种子搜索抽池 → 买 1 扣 4 币级数 +1 → 阻尼 0.75；再买 → 0.5
	var c: Object = CoreScript.new()
	c.rng.seed = 808
	c.coins = 12
	c.start_level(1)
	c.enter_shop()
	var sw_seed := -1
	for k in 40:
		c.rng.seed = 900 + k
		c.enter_shop()
		for it in c.shop_items:
			if String(it.id) == "sideweight":
				sw_seed = 900 + k
		if sw_seed >= 0:
			break
	_check(sw_seed >= 0, "C51-2 找到含侧翼配重的抽池种子（seed=%d）" % sw_seed)
	c.rng.seed = sw_seed
	c.enter_shop()
	var sw_idx := -1
	for i in c.shop_items.size():
		if String(c.shop_items[i].id) == "sideweight":
			sw_idx = i
	var coins0: int = int(c.coins)
	_check(c.buy(sw_idx) and int(c.coins) == coins0 - 4 and int(c.upgrades.sideWeight) == 1
		and absf(float(c.wind_damp_mult()) - 0.75) < 1e-6,
		"C51-2b 买 1：扣 4 币 / 级数 1 / 阻尼 0.75")
	c.coins = 12
	for k in 40:
		c.enter_shop()
		var idx2 := -1
		for i in c.shop_items.size():
			if String(c.shop_items[i].id) == "sideweight":
				idx2 = i
		if idx2 >= 0 and c.buy(idx2):
			break
	_check(int(c.upgrades.sideWeight) == 2 and absf(float(c.wind_damp_mult()) - 0.5) < 1e-6,
		"C51-2c 可叠加再买：级数 2 / 阻尼 0.5")

	# C51-3 物理实效：L22 同配方同舵，1 级配重版横向漂移更小（风分量被衰减）
	var plain: Object = _fly_l22(4, 0.2, 35.0, 1.0)
	var weighed2: Object = CoreScript.new()
	weighed2.upgrades.sideWeight = 1
	weighed2.start_level(21)
	var pr2: Rect2 = weighed2.paper_rect
	for k in 4:
		var mid_y: float = 0.5 - 0.5 * 0.2
		weighed2.add_fold(pr2.position + pr2.size * Vector2(0.92, mid_y - 0.23),
			pr2.position + pr2.size * Vector2(0.92, mid_y + 0.23))
	weighed2.finish_folds()
	weighed2.do_throw(35.0, 1.0)
	var g2 := 0
	while String(weighed2.state) == "fly" and g2 < MAX_STEPS:
		weighed2.lateral_input = -1.0 if weighed2.flight_time < 1.0 else 0.0
		weighed2.step(DELTA)
		g2 += 1
	_check(plain.last_pass and weighed2.last_pass
		and float(weighed2.lateral) < float(plain.lateral),
		"C51-3 配重削弱右推后左切更进（%.0f < %.0f）且双双过关" % [weighed2.lateral, plain.lateral])

	# C51-4 reset_run 清零回到 1.0
	weighed2.reset_run()
	_check(int(weighed2.upgrades.sideWeight) == 0 and absf(float(weighed2.wind_damp_mult()) - 1.0) < 1e-6,
		"C51-4 reset_run 清零（级数 0 / 阻尼 1.0）")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c51_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
