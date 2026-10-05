extends SceneTree
## demo-08 3D 阶段 C32（阶梯②收官组合·L20 切变低门）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：wind="none" + side_wind=+60 双段切变（30m/50m 翻转）
## × 低门 48m 横位 0±240/3.5s 摆动（10m 顶）。L1-L19 无新字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c32.gd（失败退出码非零）

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


## 位置窗顶左风策略：30m 进 -1 段（右送→左拽）按住 A，50m 回 +1 段松手
func _mk_l20(folds_v: Array, angle: float, use_pos_hold: bool) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(19)
	if folds_v.size() > 0:
		var pr: Rect2 = c.paper_rect
		for v in folds_v:
			var mid_y: float = 0.5 - 0.5 * float(v)
			c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
				pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(angle, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		var in_pos_window: bool = c.plane_pos.x >= 60.0 + 30.2 * 60.0 and c.plane_pos.x < 60.0 + 50.4 * 60.0
		c.lateral_input = -1.0 if (use_pos_hold and in_pos_window) else 0.0
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C32 切变低门测试开始")

	# C32-1 三段符号（C13 翻转作用于正交侧风）：20/40/60m 处有效侧风 +60/-60/+60
	var c1: Object = CoreScript.new()
	c1.start_level(19)
	var segs := {}
	for xm in [20.0, 40.0, 60.0]:
		c1.plane_pos.x = 60.0 + xm * 60.0
		segs[xm] = float(c1.side_wind_accel()) * float(c1.shear_sign_flip())
	_check(String(c1.wind_mode()) == "none" and segs[20.0] == 60.0 and segs[40.0] == -60.0 and segs[60.0] == 60.0,
		"C32-1 三段有效侧风：20m=%s 40m=%s 60m=%s（+/-/+）" % [str(segs[20.0]), str(segs[40.0]), str(segs[60.0])])

	# C32-2 低门摆动公式：side 0 ± 240，周期 3.5s——t=0.875 右极 +240，t=2.625 左极 -240
	var c2: Object = CoreScript.new()
	c2.start_level(19)
	_check(absf(float(c2.low_gate_side_at(0.875)) - 240.0) < 1e-6
		and absf(float(c2.low_gate_side_at(2.625)) + 240.0) < 1e-6,
		"C32-2 低门摆动公式：右极 +240 / 左极 -240（窗口 [-240,240]）")

	# C32-3 俯冲配方：过关 + 低门 + 收益 23 = 3 + 6 + 14
	var good := _mk_l20([-0.5, -0.5, -0.5, -0.5, -0.5], 30.0, true)
	_check(good.last_pass and good.low_gate_hit and absf(float(good.flight_distance) - 60.06) < 0.05,
		"C32-3 俯冲配方 %.2fm 过关、低门命中（末位横位 %.0f px）" % [
			float(good.flight_distance), float(good.lateral)])
	_check(good.coins == 23 and int(good.gate_coins) == 3, "C32-3b 收益 23 = 门奖 3 + int(d/10) 6 + 过关奖 14")

	# C32-4 零耦合：顶左风 vs 无舵 前进/高度 300 步逐位一致（侧风不碰纵向积分）
	var folds_v: Array = [-0.5, -0.5, -0.5, -0.5, -0.5]
	var t1: Object = CoreScript.new()
	t1.start_level(19)
	var pr1: Rect2 = t1.paper_rect
	for v in folds_v:
		var mid_y1: float = 0.5 - 0.5 * float(v)
		t1.add_fold(pr1.position + pr1.size * Vector2(0.92, mid_y1 - 0.23),
			pr1.position + pr1.size * Vector2(0.92, mid_y1 + 0.23))
	t1.finish_folds()
	t1.do_throw(30.0, 1.0)
	var pa: Array = []
	var g5 := 0
	while String(t1.state) == "fly" and g5 < 300:
		var in_win: bool = t1.plane_pos.x >= 60.0 + 30.2 * 60.0 and t1.plane_pos.x < 60.0 + 50.4 * 60.0
		t1.lateral_input = -1.0 if in_win else 0.0
		t1.step(DELTA)
		pa.append(t1.plane_pos)
		g5 += 1
	var t2: Object = CoreScript.new()
	t2.start_level(19)
	var pr2: Rect2 = t2.paper_rect
	for v in folds_v:
		var mid_y2: float = 0.5 - 0.5 * float(v)
		t2.add_fold(pr2.position + pr2.size * Vector2(0.92, mid_y2 - 0.23),
			pr2.position + pr2.size * Vector2(0.92, mid_y2 + 0.23))
	t2.finish_folds()
	t2.do_throw(30.0, 1.0)
	var pb: Array = []
	var g6 := 0
	while String(t2.state) == "fly" and g6 < 300:
		t2.step(DELTA)
		pb.append(t2.plane_pos)
		g6 += 1
	var same := pa.size() == pb.size()
	if same:
		for i in pa.size():
			var va: Vector2 = pa[i]
			var vb: Vector2 = pb[i]
			if va.distance_to(vb) > 1e-9:
				same = false
				break
	_check(same, "C32-5 侧风/顶风不改变前进与高度轨迹（%d 步逐位一致）" % pa.size())

	# C32-6 摆烂不可过：无折 < 60
	var lazy := _mk_l20([], 30.0, true)
	_check(not lazy.last_pass and float(lazy.flight_distance) < 60.0,
		"C32-6 摆烂无折 %.1fm < 60 不可过" % float(lazy.flight_distance))

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c32_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
