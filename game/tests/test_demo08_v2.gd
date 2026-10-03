extends SceneTree
## demo-08 v2 飞行性格验收（监督者窄授权，headless 真实时间）：
## 用例1 三种性格：同投掷下俯冲/稳定/抬头配置的轨迹肉眼可辨（apex 两两差 ≥10%，顺序 俯冲<抬头<稳定）
## 用例2 无画圈保证：三种轨迹 x 全程单调前进（模型封顶 0.95g 的设计不变量）
## 用例3 L2 高空门：抬头机（飘）穿过 12 米门得 +3 金币；俯冲机（低平）穿不过
## 用例4 档位仪表：_tier3/_trim_tier 阈值正确
## 运行：godot --headless --path game -s res://tests/test_demo08_v2.gd

var fails := 0


func _init() -> void:
	_run()


func _check(cond: bool, tag: String) -> void:
	if cond:
		print("PASS: " + tag)
	else:
		fails += 1
		print("FAIL: " + tag)


func _fold_trim(s: Control, n: int, y_frac: float) -> void:
	var pr: Rect2 = s.paper_rect
	for k in n:
		var x: float = pr.position.x + pr.size.x * 0.92
		var y1: float = pr.position.y + pr.size.y * clampf(y_frac - 0.2, 0.02, 0.98)
		var y2: float = pr.position.y + pr.size.y * clampf(y_frac + 0.2, 0.02, 0.98)
		s.add_fold(Vector2(x, y1), Vector2(x, y2))


func _fly(s: Control) -> void:
	s.do_throw(30.0, 1.0)
	var t0 := Time.get_ticks_msec()
	while s.state == "fly" and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame


func _run() -> void:
	print("=== demo-08 v2 飞行性格验收 ===")
	var s: Control = load("res://demo08_paperplane.tscn").instantiate()
	root.add_child(s)
	await physics_frame

	# 用例1 三种性格（L1，同 30° 满力，各 2 折：下方/中间/上方）
	var apexes: Dictionary = {}
	var times: Dictionary = {}
	var dists: Dictionary = {}
	for cfg in [[0.85, "俯冲"], [0.5, "稳定"], [0.15, "抬头"]]:
		s.start_level(0)
		_fold_trim(s, 2, cfg[0])
		s._on_fold_done()
		await _fly(s)
		apexes[cfg[1]] = s.apex_m
		times[cfg[1]] = s.flight_time
		dists[cfg[1]] = s.flight_distance
		print("  %s: trim=%+.2f apex=%.1f m time=%.2fs dist=%.1f m" % [
			cfg[1], float(s.plane_params.trim), s.apex_m, s.flight_time, s.flight_distance])
	var a_dive: float = apexes["俯冲"]
	var a_mid: float = apexes["稳定"]
	var a_float: float = apexes["抬头"]
	_check(a_dive < a_mid * 0.9, "1.1 俯冲 apex %.1f 比稳定 %.1f 低 ≥10%%（低平轨迹）" % [a_dive, a_mid])
	_check(a_float < a_mid * 0.95 and a_float > a_dive * 1.05,
		"1.2 抬头 apex %.1f 介于两者且各差 ≥5%%（飘-掉高轨迹）" % a_float)
	_check(a_float > a_dive * 1.15, "1.3 抬头 apex %.1f 比俯冲 %.1f 高 ≥15%%（高度形态性格差）" % [a_float, a_dive])

	# 用例2 无画圈（x 单调前进的模型不变量）：三者都飞出正距离且结算正常
	_check(dists["俯冲"] > 5.0 and dists["稳定"] > 5.0 and dists["抬头"] > 5.0,
		"2.1 三种性格都正常前飞（%.1f / %.1f / %.1f m，无画圈回退）" % [dists["俯冲"], dists["稳定"], dists["抬头"]])

	# 用例3 L2 高空门
	s.unlocked = 2
	s.start_level(1)
	_fold_trim(s, 4, 0.15)
	s._on_fold_done()
	var c0: int = s.coins
	await _fly(s)
	var floaty_hit: bool = s.gate_hit
	var floaty_coins: int = s.coins
	var floaty_dist: float = s.flight_distance
	var floaty_apex: float = s.apex_m
	_check(floaty_hit, "3.1 抬头机（飘）穿过 12 米高空门")
	s.start_level(1)
	_fold_trim(s, 4, 0.85)
	s._on_fold_done()
	await _fly(s)
	var dive_hit: bool = s.gate_hit
	var dive_coins: int = s.coins
	var dive_dist: float = s.flight_distance
	var dive_apex: float = s.apex_m
	_check(not dive_hit, "3.2 俯冲机（低平）穿不过高空门（apex %.1f m < 12 m）" % dive_apex)
	_check(floaty_apex > dive_apex * 1.4, "3.4 两种性格 L2 高度形态差 ≥40%%（%.1f vs %.1f m）" % [floaty_apex, dive_apex])
	# 收益核算（v3 起两门并存：抬头吃高空门、俯冲吃低空门，各 +3）
	var earn_f: int = floaty_coins - c0
	var earn_d: int = dive_coins - floaty_coins
	var exp_f: int = int(floaty_dist / 10.0) + 6 + 3
	var exp_d: int = int(dive_dist / 10.0) + 6 + 3
	_check(earn_f == exp_f and earn_d == exp_d, "3.3 两掷收益各=距离币+过关6+门3（%d/%d 期望 %d/%d）" % [earn_f, earn_d, exp_f, exp_d])

	# 用例4 档位仪表
	_check(s._tier3(0.3, 0.5, 1.0) == "低" and s._tier3(0.7, 0.5, 1.0) == "中" and s._tier3(1.2, 0.5, 1.0) == "高", "4.1 升力/阻力三档阈值正确")
	_check(s._trim_tier(-0.5) == "俯冲" and s._trim_tier(0.2) == "稳定" and s._trim_tier(0.8) == "抬头", "4.2 配平三档阈值正确（俯冲/稳定/抬头）")

	print("=== 结果：%s（fails=%d）===" % ["ALL PASS" if fails == 0 else "HAS FAIL", fails])
	quit(1 if fails > 0 else 0)
