extends SceneTree
## demo-08 3D 阶段 C1（headless，固定 delta=1/60）：
## A 五关全流程（配方直通/吃门，跳过商店）→ final 汇总一致性
## B 强化可解释性（力气 +1 级改变同配方轨迹）
## C 结算轨迹复盘小图数据管线（chart_points/chart_marks/可见性，绘制效果=窗口会话核）
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c1.gd（失败退出码非零）

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


func _good_folds(c: Object, n: int) -> void:
	var pr: Rect2 = c.paper_rect
	for k in n:
		c.add_fold(pr.position + pr.size * Vector2(0.92, 0.08 + 0.06 * float(k)),
			pr.position + pr.size * Vector2(0.92, 0.54 + 0.06 * float(k)))


## 各关配方：[折数, 角度, 力度, 转向dir, 转向保持秒]（L6 为用户指令扩展关：顶风吃高门）
func _recipe(i: int) -> Array:
	match i:
		0: return [2, 30.0, 1.0, 0.0, 0.0]
		1: return [4, 42.0, 1.0, 0.0, 0.0]
		2: return [5, 35.0, 0.9, 0.0, 0.0]
		3: return [4, 35.0, 1.0, -1.0, 1.2]
		4: return [6, 45.0, 1.0, 0.0, 0.0]
		5: return [4, 30.0, 1.0, 1.0, 0.4]
		6: return [5, 30.0, 1.0, -1.0, 0.8]
		7: return [5, 30.0, 1.0, 0.0, 0.0]
		8: return [5, 30.0, 1.0, 1.0, 0.8]
		9: return [5, 30.0, 1.0, 1.0, 0.6]
		10: return [5, 35.0, 1.0, 0.0, 0.0]
		11: return [5, 35.0, 1.0, 0.0, 0.0, 0.35]
		12: return [5, 30.0, 1.0, 1.0, 0.8]
		13: return [5, 30.0, 1.0, 1.0, 0.0, 0.2, 30.2, 61.8]
		14: return [6, 30.0, 1.0, -1.0, 99.0]
		15: return [5, 30.0, 1.0, 0.0, 0.0]
		16: return [5, 30.0, 1.0, 1.0, 0.8, 0.2]
		17: return [6, 30.0, 1.0, 0.0, 0.0, 0.2]
	return [3, 30.0, 1.0, 0.0, 0.0]


func _throw_and_fly(c: Object) -> void:
	var r := _recipe(c.level_idx)
	if r.size() > 5:
		# 第 6 元素 = 均匀折法 v 值（L12 乘风摆门配方用）
		var v: float = float(r[5])
		var pru: Rect2 = c.paper_rect
		for k in int(r[0]):
			var mid_y: float = 0.5 - 0.5 * v
			c.add_fold(pru.position + pru.size * Vector2(0.92, mid_y - 0.23),
				pru.position + pru.size * Vector2(0.92, mid_y + 0.23))
	else:
		_good_folds(c, int(r[0]))
	c.finish_folds()
	c.do_throw(float(r[1]), float(r[2]))
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		# 第 7/8 元素（可选）= 位置窗顶风（L14 逆风三段配方用）：x ∈ [START+lo, START+hi) 时按住
		var input_on: bool
		if r.size() > 7:
			var lo_px: float = 60.0 + float(r[6]) * 60.0
			var hi_px: float = 60.0 + float(r[7]) * 60.0
			input_on = c.plane_pos.x >= lo_px and c.plane_pos.x < hi_px
		else:
			input_on = c.flight_time < float(r[4])
		c.lateral_input = float(r[3]) if input_on else 0.0
		c.step(DELTA)
		g += 1


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C1 测试开始")

	# A 五关全流程：配方过关 → 跳过商店 → 下一关 → L5 后 final
	var c: Object = CoreScript.new()
	c.rng.seed = 808
	var sum_d := 0.0
	var best_d := 0.0
	var coins_expect := 0
	var all_pass := true
	for i in 19:
		c.start_level(i)
		_throw_and_fly(c)
		var d: float = float(c.flight_distance)
		var ok: bool = c.last_pass and d >= float(c.LEVELS[i].target_m)
		all_pass = all_pass and ok
		_log("  L%d: %.1fm / %.0fm pass=%s high=%s low=%s" % [i + 1, d, float(c.LEVELS[i].target_m), str(c.last_pass), str(c.gate_hit), str(c.low_gate_hit)])
		sum_d += d
		best_d = maxf(best_d, d)
		coins_expect += int(d / 10.0) + int(c.LEVELS[i].reward) + c.gate_coins
		if not ok:
			break
		if i < 18:
			c.settle_continue()
			if String(c.state) == "shop":
				c.shop_skip()
	_check(all_pass and String(c.state) == "settle" and c.level_idx == 18,
		"C1-A 十九关依次过关（L4 转向吃高门含在流程内）")
	var go: String = c.settle_continue()
	_check(go == "final" and String(c.state) == "final", "C1-A2 L19 结算继续 → final")
	_check(absf(float(c.total_distance) - sum_d) < 0.01 and absf(float(c.best_distance) - best_d) < 0.01,
		"C1-A3 总里程/最远一致（%.1fm）" % float(c.total_distance))
	_check(c.coins == coins_expect, "C1-A4 金币累计 %d = 各关门奖+结算之和" % c.coins)
	_check(c.unlocked == 18, "C1-A5 解锁至第 19 关（unlocked=18）")

	# B 强化可解释性：力气 +1 级 → 初速比恰为 1.2，距离有可测变化
	var base: Object = CoreScript.new()
	base.start_level(0)
	_good_folds(base, 2)
	base.finish_folds()
	base.do_throw(30.0, 1.0)
	var base_v0: float = base.velocity.length()
	var gb := 0
	while String(base.state) == "fly" and gb < MAX_STEPS:
		base.step(DELTA)
		gb += 1
	var pow1: Object = CoreScript.new()
	pow1.upgrades = {power = 1, wing = 0}
	pow1.start_level(0)
	_good_folds(pow1, 2)
	pow1.finish_folds()
	pow1.do_throw(30.0, 1.0)
	var pow_v0: float = pow1.velocity.length()
	var gp := 0
	while String(pow1.state) == "fly" and gp < MAX_STEPS:
		pow1.step(DELTA)
		gp += 1
	_check(absf((pow_v0 / base_v0) - 1.2) < 1e-6
		and absf(float(base.flight_distance) - float(pow1.flight_distance)) > 0.005,
		"C1-B 力气+1 级：初速比 %.4f（=1.2），距离 %.2f→%.2f m 变化" % [
			pow_v0 / base_v0, float(base.flight_distance), float(pow1.flight_distance)])

	# C 复盘小图数据管线（场景实例，headless；绘制效果=窗口会话核）
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	var sc: Object = scene.core
	sc.start_level(1)
	_good_folds(sc, 4)
	sc.finish_folds()
	sc.do_throw(42.0, 1.0)
	var g2 := 0
	while String(sc.state) == "fly" and g2 < MAX_STEPS:
		await physics_frame
		g2 += 1
	await process_frame
	await process_frame
	var pts: PackedVector2Array = scene.chart_points()
	var marks: Array = scene.chart_marks()
	var max_h := 0.0
	for p in pts:
		max_h = maxf(max_h, p.y)
	_log("  [诊断] 图内顶点 %.6f vs apex %.6f（点数 %d，trail %d）" % [max_h, float(sc.apex_m), pts.size(), sc.trail.size()])
	_check(scene.chart.visible and String(sc.state) == "settle", "C1-C1 结算面板显示复盘小图")
	_check(pts.size() > 50, "C1-C2 轨迹点数 %d（整掷采样）" % pts.size())
	_check(absf(max_h - float(sc.apex_m)) < 1e-4, "C1-C3 图内顶点 %.4fm ≈ apex_m（±0.1mm，float32 轨迹表示差）" % float(sc.apex_m))
	_check(absf(pts[pts.size() - 1].x - float(sc.flight_distance)) < 1e-6,
		"C1-C4 图末点 %.2fm = 结算距离" % pts[pts.size() - 1].x)
	var has_high := false
	var has_finish := false
	for m in marks:
		if String(m.kind) == "high" and absf(float(m.x) - 34.0) < 1e-6:
			has_high = true
		if String(m.kind) == "finish" and absf(float(m.x) - 45.0) < 1e-6:
			has_finish = true
	_check(has_high and has_finish, "C1-C5 标记含高门 34m 与终点 45m")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c1_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
