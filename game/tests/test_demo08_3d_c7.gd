extends SceneTree
## demo-08 3D 阶段 C7（阶梯②新商店物品·重心铅条）核心不变量（headless，固定 delta=1/60）：
## 规则变化 C7：SHOP_POOL 追加 ballast（5 币可叠加，配平收敛 30%/级 下限 0.1）；
## do_throw 冻结 eff_trim = trim × ballast_mult()（仅影响飞行性格 lift_tilt/俯仰偏置；
## angle_forgive 窗口仍按折线原配平——设计决定）。无铅条路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c7.gd（失败退出码非零）

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0
const MAX_STEPS := 1800

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


## 狂野折法：5 折全在纸面最下（v=-1 → trim=-1.75 俯冲），L5 85m 终点远
func _mk_wild(ballast_lvl: int, level: int = 4) -> Object:
	var c: Object = CoreScript.new()
	if ballast_lvl > 0:
		c.upgrades.ballast = ballast_lvl
	c.start_level(level)
	var pr: Rect2 = c.paper_rect
	for k in 5:
		var mid_y: float = 0.99  # v=-1.0 → mid_y=0.99（贴近纸底，len 0.46 越界容差内）
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.04),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.04))
	c.finish_folds()
	c.do_throw(30.0, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C7 重心铅条测试开始")

	# C7-1 乘算与下限：1 级 0.7、3 级 0.1（恰达下限）、4 级仍 0.1
	var c1: Object = CoreScript.new()
	c1.upgrades.ballast = 1
	var c3: Object = CoreScript.new()
	c3.upgrades.ballast = 3
	var c4: Object = CoreScript.new()
	c4.upgrades.ballast = 4
	_check(absf(float(c1.ballast_mult()) - 0.7) < 1e-9 and absf(float(c3.ballast_mult()) - 0.1) < 1e-9
		and absf(float(c4.ballast_mult()) - 0.1) < 1e-9,
		"C7-1 收敛乘算 0.7/0.1/0.1（30%/级，下限 0.1）")

	# C7-2 无铅条恒等：ballast=0 → mult 1.0，eff_trim == trim（回归锚）
	var c0: Object = CoreScript.new()
	c0.start_level(0)
	c0.plane_params.trim = -1.75
	c0.finish_folds()
	c0.do_throw(30.0, 1.0)
	_check(absf(float(c0.ballast_mult()) - 1.0) < 1e-9 and absf(float(c0.eff_trim) - (-1.75)) < 1e-9,
		"C7-2 无铅条 eff_trim == 原配平 -1.75")

	# C7-3 轨迹性格变化：狂野折法 L5，无铅条 vs 2 级铅条（eff -1.75→-1.05）距离必变
	var wild0 := _mk_wild(0)
	var wild2 := _mk_wild(2)
	var diff: float = float(wild2.flight_distance) - float(wild0.flight_distance)
	_check(absf(diff) > 0.3,
		"C7-3 铅条 2 级改变狂野折法距离 %.2f→%.2f m（±%.2f，性格收敛生效）" % [
			float(wild0.flight_distance), float(wild2.flight_distance), absf(diff)])

	# C7-4 angle_forgive 口径：仍按折线原配平（-1.75 俯冲区 → 无容错，与铅条无关）
	_check(absf(float(wild2.angle_forgive)) < 1e-9 and absf(float(wild2.eff_trim)) < 1.3,
		"C7-4 容错窗口按原配平（俯冲区 forgive=0，eff_trim 已收敛 %.2f）" % float(wild2.eff_trim))

	# C7-5 购买路径：自动寻种子 → 扣 5 币 → 级数 +1 → 可再次入池
	var c5: Object = CoreScript.new()
	c5.coins = 20
	var b_seed := -1
	for k in 60:
		c5.rng.seed = k
		c5.enter_shop()
		for it in c5.shop_items:
			if String(it.id) == "ballast":
				b_seed = k
		if b_seed >= 0:
			break
	_check(b_seed >= 0, "C7-5a 找到含重心铅条的抽池种子（seed=%d）" % b_seed)
	c5.rng.seed = b_seed
	c5.enter_shop()
	var b_idx := -1
	for i in c5.shop_items.size():
		if String(c5.shop_items[i].id) == "ballast":
			b_idx = i
	var coins0: int = c5.coins
	var bought: bool = c5.buy(b_idx)
	_check(bought and c5.coins == coins0 - 5 and int(c5.upgrades.ballast) == 1,
		"C7-5b 购买扣 5 币、级数 +1")
	var reappear := false
	for k in 40:
		c5.rng.seed = 500 + k
		c5.enter_shop()
		for it in c5.shop_items:
			if String(it.id) == "ballast":
				reappear = true
	_check(reappear, "C7-5c 可叠加物再次入池（非唯一）")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c7_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
