extends SceneTree
## demo-08 3D 阶段 C33（难度曲线全量分析）：二十关顺序通关，逐关采集
## 飞行时长/距离/金币/门命中 → 数据表 + 总量汇总（供评审难度曲线）。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c33.gd（失败退出码非零）

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


func _good_folds(c: Object, n: int) -> void:
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.08 + 0.06 * float(k)
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.46))


## 各关配方：[折数, 角度, 力度, 转向dir, 转向hold, 均匀v(可选), 位置窗lo(可选), 位置窗hi(可选)]
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
		18: return [5, 30.0, 1.0, 1.0, 0.0, 0.2, 30.2, 54.8]
		19: return [5, 30.0, 1.0, -1.0, 0.0, -0.5, 30.2, 50.4]
		21: return [4, 35.0, 1.0, -1.0, 1.0, 0.2]
		22: return [4, 30.0, 1.0, 1.0, 1.0, 0.2]
		23: return [4, 27.0, 1.0, 0.0, 0.0, 0.2]
	return [3, 30.0, 1.0, 0.0, 0.0]


func _run() -> void:
	await process_frame
	_log("demo-08 3D 难度曲线分析开始（二十四关顺序通关，无商店购买）")
	_log("关 | 时长s | 距离m | 金币 | 高门 | 低门 | 过关")
	var c: Object = CoreScript.new()
	var total_t := 0.0
	var total_d := 0.0
	var all_pass := true
	for i in 24:
		c.start_level(i)
		var r := _recipe(i)
		if r.size() > 5:
			var v: float = float(r[5])
			var pr: Rect2 = c.paper_rect
			for k in int(r[0]):
				var mid_y: float = 0.5 - 0.5 * v
				c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
					pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
		else:
			_good_folds(c, int(r[0]))
		c.finish_folds()
		c.do_throw(float(r[1]), float(r[2]))
		var g := 0
		while String(c.state) == "fly" and g < MAX_STEPS:
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
		var ft: float = float(c.flight_time)
		var d: float = float(c.flight_distance)
		total_t += ft
		total_d += d
		all_pass = all_pass and c.last_pass
		_log("%2d | %5.1f | %5.1f | %3d | %s | %s | %s" % [i + 1, ft, d, int(c.coins), str(c.gate_hit), str(c.low_gate_hit), str(c.last_pass)])
	_check(all_pass, "C33-A 二十四关全部过关（无商店购买强化）")
	_check(absf(float(c.total_distance) - total_d) < 0.5, "C33-B 总里程 %.1fm 一致" % total_d)
	_log("--------------------------------------")
	_log("汇总：总飞行 %.1f 秒 / 总里程 %.1f 米 / 总金币 %d" % [total_t, total_d, int(c.coins)])
	_log("--------------------------------------")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c33_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
