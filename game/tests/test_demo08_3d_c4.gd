extends SceneTree
## demo-08 3D 阶段 C4（阶梯②新商店物品·纸面加固）核心不变量（headless，固定 delta=1/60）：
## 规则变化 C4：SHOP_POOL 追加 stiff（4 币可叠加，每级折线阻力 -15%，下限 0.25），
## do_throw 冻结 eff_drag_f = drag_f × stiff_mult()（镜像 eff_lift/wing_mult 先例；无强化路径逐位不变）。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c4.gd（失败退出码非零）

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0
const MAX_STEPS := 1500

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


func _mk_l2(stiff_lvl: int, angle: float = 42.0, power: float = 1.0, folds: int = 4, level: int = 1) -> Object:
	var c: Object = CoreScript.new()
	if stiff_lvl > 0:
		c.upgrades.stiff = stiff_lvl
	c.start_level(level)
	var pr: Rect2 = c.paper_rect
	for k in folds:
		c.add_fold(pr.position + pr.size * Vector2(0.92, 0.08 + 0.06 * float(k)),
			pr.position + pr.size * Vector2(0.92, 0.54 + 0.06 * float(k)))
	c.finish_folds()
	c.do_throw(angle, power)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C4 纸面加固测试开始")

	# C4-1 池集成：拥有全部唯一物后，池=power/wing/stiff 三件，stiff 可复现、价格升序
	var c1: Object = CoreScript.new()
	c1.owned = ["prop", "trimtool", "tough"]
	var stiff_seen := 0
	var pool_ok := true
	for k in 25:
		c1.rng.seed = k
		c1.enter_shop()
		if c1.shop_items.size() != 3:
			pool_ok = false
			break
		var ids := []
		for it in c1.shop_items:
			ids.append(String(it.id))
		if ids.has("stiff"):
			stiff_seen += 1
		if int(c1.shop_items[0].price) > int(c1.shop_items[1].price) or int(c1.shop_items[1].price) > int(c1.shop_items[2].price):
			pool_ok = false
	_check(pool_ok and stiff_seen > 0, "C4-1 六物池抽 3：唯一不重现、价格升序、stiff 可复现（25 种子中 %d 次）" % stiff_seen)

	# C4-2 线性叠加与下限
	var c2: Object = CoreScript.new()
	c2.upgrades.stiff = 2
	_check(absf(float(c2.stiff_mult()) - 0.7) < 1e-9, "C4-2a 2 级阻力乘算 1-0.15×2=0.7")
	var c3: Object = CoreScript.new()
	c3.upgrades.stiff = 7
	_check(absf(float(c3.stiff_mult()) - 0.25) < 1e-9, "C4-2b 7 级触发下限 0.25（防负阻力）")

	# C4-3 轨迹可感：L1（30m 终点）2 折弱掷落地结算，加固 2 级滑得更远
	var base := _mk_l2(0, 25.0, 0.7, 2, 0)
	var stiff := _mk_l2(2, 25.0, 0.7, 2, 0)
	var diff: float = float(stiff.flight_distance) - float(base.flight_distance)
	_check(diff > 0.03,
		"C4-3 加固 2 级 L1 弱掷距离 %.2f→%.2f m（+%.2f；终点截断下为过线点位移，确定可复现）" % [
			float(base.flight_distance), float(stiff.flight_distance), diff])

	# C4-4 购买路径：扣币一次、移出、可重复入池（可叠加非唯一）
	var c4: Object = CoreScript.new()
	c4.coins = 20
	var stiff_seed := -1
	for k in 40:
		c4.rng.seed = k
		c4.enter_shop()
		for it in c4.shop_items:
			if String(it.id) == "stiff":
				stiff_seed = k
		if stiff_seed >= 0:
			break
	_check(stiff_seed >= 0, "C4-4a 找到含纸面加固的抽池种子（seed=%d）" % stiff_seed)
	c4.rng.seed = stiff_seed
	c4.enter_shop()
	var stiff_idx := -1
	for i in c4.shop_items.size():
		if String(c4.shop_items[i].id) == "stiff":
			stiff_idx = i
	var coins0: int = c4.coins
	var bought: bool = c4.buy(stiff_idx)
	_log("  [诊断] bought=%s stiff_idx=%d state=%s coins=%d→%d lvl=%d" % [str(bought), stiff_idx, str(c4.state), coins0, int(c4.coins), int(c4.upgrades.get("stiff", -1))])
	_check(bought and c4.coins == coins0 - 4 and int(c4.upgrades.stiff) == 1,
		"C4-4b 购买扣 4 币、级数 +1")
	var reappear := false
	for k in 30:
		c4.rng.seed = 100 + k
		c4.enter_shop()
		for it in c4.shop_items:
			if String(it.id) == "stiff":
				reappear = true
	_check(reappear, "C4-4c 可叠加物再次入池（非唯一）")

	# C4-5 无强化路径逐位不变（回归锚）：stiff=0 的 L2 与基线值一致
	var c5 := _mk_l2(0)
	_check(c5.gate_hit and c5.coins == 13 and absf(float(c5.flight_distance) - 45.23) < 0.01,
		"C4-5 无强化结果同阶段 A（高门 +3、币 13、%.2fm）" % float(c5.flight_distance))

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c4_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
