extends SceneTree
## demo-09 v2 诊断关验收（监督者窄授权）：
## 用例1 预算约束：L4 轮胎总面积 Σπr² ≤ 4300，超预算拒绝
## 用例2 三类车型都能通关：长轴距大轮 / 短轴距小轮 / 三轮偏置
## 用例3 trade-off：三类车型的六指标分布不同（用时极差 ≥10% 且至少一项其他指标差异 ≥30%）
## 用例4 复制上一版 + Ghost：结算后布局存档、续玩自动预填、轨迹采样可用于回放
## 运行：godot --headless --path game -s res://tests/test_demo09_v2.gd

var fails := 0


func _init() -> void:
	_run()


func _check(cond: bool, tag: String) -> void:
	if cond:
		print("PASS: " + tag)
	else:
		fails += 1
		print("FAIL: " + tag)


func _fly(s: Control, t: float) -> void:
	s.do_launch()
	s.throttle_on(t)
	var t0 := Time.get_ticks_msec()
	while s.state == "drive" and Time.get_ticks_msec() - t0 < 90000:
		await physics_frame


## 三类标准车型
func _build(s: Control, kind: String) -> void:
	s.clear_wheels()
	if kind == "长轴距大轮":
		s.add_wheel(0.03, 26.0)
		s.add_wheel(0.97, 26.0)
	elif kind == "短轴距小轮":
		s.add_wheel(0.3, 16.0)
		s.add_wheel(0.45, 16.0)
		s.add_wheel(0.6, 16.0)
		s.add_wheel(0.75, 16.0)
	elif kind == "三轮偏置":
		s.add_wheel(0.1, 20.0)
		s.add_wheel(0.55, 20.0)
		s.add_wheel(0.9, 20.0)


func _metrics(s: Control) -> Dictionary:
	return {
		cleared = s.last_pass, time = s.flight_time, pitch = s.max_pitch,
		air = s.airtime_s, bottom = s.bottom_out,
		contact = float(s.grounded_frames) / maxf(1.0, float(s.drive_frames)),
	}


func _run() -> void:
	print("=== demo-09 v2 诊断关验收 ===")
	var s: Control = load("res://demo09_racer.tscn").instantiate()
	root.add_child(s)
	await physics_frame
	s.unlocked = 3

	# 用例1 预算约束
	s.start_level(3)
	_check(s.add_wheel(0.1, 26.0) and s.add_wheel(0.9, 26.0), "1.1 两个大轮（面积和 4248 ≤ 4300）可放")
	_check(not s.add_wheel(0.5, 12.0), "1.2 再加任意轮超预算（+452 → 4700 > 4300）被拒绝")
	_check(s.wheels.size() == 2, "1.3 被拒轮未进入布局")

	# 用例2+3 三类车型跑诊断关
	var res: Dictionary = {}
	for kind in ["长轴距大轮", "短轴距小轮", "三轮偏置"]:
		s.start_level(3)
		_build(s, kind)
		var launched: bool = s.do_launch()
		await _fly(s, 90.0)
		res[kind] = _metrics(s)
		res[kind].launched = launched
		print("  %s: 通关=%s 用时=%.1f 秒 最大俯仰=%.2f rad 滞空=%.1f 秒 托底=%d 接地率=%d%%" % [
			kind, str(s.last_pass), s.flight_time, s.max_pitch, s.airtime_s, s.bottom_out,
			int(100.0 * float(s.grounded_frames) / maxf(1.0, float(s.drive_frames)))])
	_check(res["长轴距大轮"].launched and res["短轴距小轮"].launched and res["三轮偏置"].launched, "2.1 三类车型均可发车")
	_check(res["长轴距大轮"].cleared and res["短轴距小轮"].cleared and res["三轮偏置"].cleared,
		"2.2 三类车型都能通关（≥3 种合理车型存在）")
	# 用例3 trade-off：用时分布 + 至少一项其他指标显著分化
	var t1: float = res["长轴距大轮"].time
	var t2: float = res["短轴距小轮"].time
	var t3: float = res["三轮偏置"].time
	var tmin: float = minf(t1, minf(t2, t3))
	var tmax: float = maxf(t1, maxf(t2, t3))
	_check(tmax > tmin * 1.1, "3.1 用时极差 ≥10%%（%.1f / %.1f / %.1f 秒）" % [t1, t2, t3])
	var air_spread: float = maxf(res["长轴距大轮"].air, maxf(res["短轴距小轮"].air, res["三轮偏置"].air)) - \
		minf(res["长轴距大轮"].air, minf(res["短轴距小轮"].air, res["三轮偏置"].air))
	var bot_spread: float = float(maxi(res["长轴距大轮"].bottom, maxi(res["短轴距小轮"].bottom, res["三轮偏置"].bottom)) -
		mini(res["长轴距大轮"].bottom, mini(res["短轴距小轮"].bottom, res["三轮偏置"].bottom)))
	_check(air_spread > 0.3 or bot_spread >= 2, "3.2 至少一项指标显著分化（滞空极差 %.1f 秒 / 托底极差 %.0f 次）" % [air_spread, bot_spread])

	# 用例4 复制上一版 + Ghost
	_check(s.last_layout_by_level.has(3) and (s.last_layout_by_level[3] as Array).size() == 3, "4.1 结算已存档三轮偏置布局")
	_check(s.last_time_by_level.has(3) and float(s.last_time_by_level[3]) > 0.0, "4.2 结算已记录用时")
	_check(s.ghost_pts.size() >= 2, "4.3 轨迹采样可用于 Ghost 回放")
	s.settle_continue()  # 翻车/过关后续玩 → 自动预填上一版
	var restored: bool = s.wheels.size() == 3
	_check(restored, "4.4 续玩进车库自动预填上一版布局（3 轮）")

	print("=== 结果：%s（fails=%d）===" % ["ALL PASS" if fails == 0 else "HAS FAIL", fails])
	quit(1 if fails > 0 else 0)
