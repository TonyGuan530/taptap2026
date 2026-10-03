extends SceneTree
## demo-08 v4 补关验收（L4 双门峡谷 / L5 远程投递，headless 真实时间）：
## 用例1 五关配置齐全：LEVELS 5 关、选关按钮 5 个且 L2-L5 初始锁定、L4/L5 字段完整
## 用例2 L4 双门互斥：抬头折法吃高空门（34m/≥12m）不得低空门、俯冲折法吃低空门（40m/≤10m）不得高空门（收益各=距离币+过关12+门3，证一掷只吃其一）
## 用例3 L4/L5 三性格均可通关（俯冲/稳定/抬头三档配平，30° 满力，同 L1-L3 校准法）
## 用例4 L5 顺风最远关：熟练折法（外侧偏上折满）距离 ≥ 85 米终点，且 85 为全关最长终点
## 运行：godot --headless --path game -s res://tests/test_demo08_v4.gd

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


## 熟练折法：外侧偏上折满（与 test_demo08 的 _good_folds 同一定标口径）
func _good_folds(s: Control, n: int) -> void:
	var pr: Rect2 = s.paper_rect
	for k in n:
		var x: float = pr.position.x + pr.size.x * 0.92
		var y1: float = pr.position.y + pr.size.y * (0.08 + 0.06 * float(k))
		var y2: float = pr.position.y + pr.size.y * (0.54 + 0.06 * float(k))
		s.add_fold(Vector2(x, y1), Vector2(x, y2))


func _fly(s: Control) -> void:
	s.do_throw(30.0, 1.0)
	var t0 := Time.get_ticks_msec()
	while s.state == "fly" and Time.get_ticks_msec() - t0 < 30000:
		await physics_frame


func _throw_and_earn(s: Control) -> int:
	var c0: int = s.coins
	await _fly(s)
	return s.coins - c0


func _run() -> void:
	print("=== demo-08 v4 L4/L5 补关验收 ===")
	var s: Control = load("res://demo08_paperplane.tscn").instantiate()
	root.add_child(s)
	await physics_frame

	# --- 用例1 五关配置齐全 + 选关按钮 5 个 + 初始锁定（全新场景 unlocked=0）---
	_check(s.LEVELS.size() == 5, "1.1 LEVELS 共 5 关")
	_check(s.level_buttons.size() == 5, "1.2 选关面板 5 个按钮")
	var lock_ok: bool = not s.level_buttons[0].disabled
	for i in range(1, 5):
		lock_ok = lock_ok and s.level_buttons[i].disabled
	_check(lock_ok, "1.3 初始仅 L1 解锁（L2-L5 按钮 disabled，L4/L5 初始锁定）")
	var l4: Dictionary = s.LEVELS[3]
	var l5: Dictionary = s.LEVELS[4]
	_check(int(l4.folds) == 5 and String(l4.wind) == "head" and absf(float(l4.target_m) - 55.0) < 0.01 \
		and absf(float(l4.gate_x) - 34.0) < 0.01 and absf(float(l4.gate_h) - 12.0) < 0.01 and int(l4.gate_bonus) == 3 \
		and absf(float(l4.low_gate_x) - 40.0) < 0.01 and absf(float(l4.low_gate_top) - 10.0) < 0.01,
		"1.4 L4 双门峡谷配置齐全（逆风 55m，高门 34m/12m+3，低门 40m/10m 以下+3）")
	_check(int(l5.folds) == 6 and String(l5.wind) == "tail" and absf(float(l5.target_m) - 85.0) < 0.01 \
		and absf(float(l5.gate_x) - 50.0) < 0.01 and absf(float(l5.gate_h) - 14.0) < 0.01 and int(l5.gate_bonus) == 4,
		"1.5 L5 远程投递配置齐全（顺风 85m，高空门 50m/14m+4）")

	# --- 用例2 L4 双门互斥（顺带取 L4 抬头/俯冲通关数据）---
	s.unlocked = 4
	s.start_level(3)
	_fold_trim(s, 5, 0.15)   # 抬头档（配平 > 0.35）
	s._on_fold_done()
	var f_earn: int = await _throw_and_earn(s)
	var f_high: bool = s.gate_hit
	var f_low: bool = s.low_gate_hit
	var f_dist: float = s.flight_distance
	var f_pass: bool = s.last_pass
	_check(f_high and not f_low, "2.1 抬头折法吃 L4 高空门（34m/≥12m）、不得低空门")
	_check(f_earn == int(f_dist / 10.0) + 12 + 3,
		"2.2 抬头折法收益 %d = 距离币 %d + 过关 12 + 高空门 3（只吃一门）" % [f_earn, int(f_dist / 10.0)])
	s.start_level(3)
	_fold_trim(s, 5, 0.85)   # 俯冲档（配平 < -0.15）
	s._on_fold_done()
	var d_earn: int = await _throw_and_earn(s)
	var d_high: bool = s.gate_hit
	var d_low: bool = s.low_gate_hit
	var d_dist: float = s.flight_distance
	var d_pass: bool = s.last_pass
	_check(d_low and not d_high, "2.3 俯冲折法吃 L4 低空门（40m/≤10m）、不得高空门")
	_check(d_earn == int(d_dist / 10.0) + 12 + 3,
		"2.4 俯冲折法收益 %d = 距离币 %d + 过关 12 + 低空门 3（只吃一门）" % [d_earn, int(d_dist / 10.0)])

	# --- 用例3 L4/L5 三性格均可通关（L4 抬头/俯冲复用用例2 数据）---
	_check(f_pass, "3.1 L4 抬头性格通关（%.1f ≥ 55 米）" % f_dist)
	_check(d_pass, "3.2 L4 俯冲性格通关（%.1f ≥ 55 米）" % d_dist)
	s.start_level(3)
	_fold_trim(s, 5, 0.5)    # 稳定档
	s._on_fold_done()
	await _fly(s)
	_check(s.last_pass and s.flight_distance >= 55.0, "3.3 L4 稳定性格通关（%.1f ≥ 55 米）" % s.flight_distance)
	s.start_level(4)
	_fold_trim(s, 3, 0.7)    # 俯冲档轻配平（3 折，配平 -0.42，俯冲档可达 85 米的折法）
	s._on_fold_done()
	var l5_dive_trim: float = float(s.plane_params.trim)
	await _fly(s)
	_check(l5_dive_trim < -0.15 and s.last_pass,
		"3.4 L5 俯冲性格通关（配平 %+.2f 俯冲档，%.1f ≥ 85 米）" % [l5_dive_trim, s.flight_distance])
	s.start_level(4)
	_fold_trim(s, 6, 0.5)    # 稳定档
	s._on_fold_done()
	await _fly(s)
	_check(s.last_pass and s.flight_distance >= 85.0, "3.5 L5 稳定性格通关（%.1f ≥ 85 米）" % s.flight_distance)
	s.start_level(4)
	_fold_trim(s, 6, 0.15)   # 抬头档
	s._on_fold_done()
	await _fly(s)
	_check(s.last_pass and s.flight_distance >= 85.0, "3.6 L5 抬头性格通关（%.1f ≥ 85 米）" % s.flight_distance)

	# --- 用例4 L5 顺风最远关：熟练折法距离 ≥ 终点，且 85 为全关最长 ---
	s.start_level(4)
	_good_folds(s, 6)
	s._on_fold_done()
	await _fly(s)
	_check(s.last_pass and s.flight_distance >= 85.0, "4.1 L5 熟练折法（外侧偏上折满）%.1f 米 ≥ 终点 85 米" % s.flight_distance)
	var max_tgt: float = 0.0
	for L in s.LEVELS:
		max_tgt = maxf(max_tgt, float(L.target_m))
	_check(absf(max_tgt - 85.0) < 0.01, "4.2 L5 终点 85 米为全关最长（最长 %.0f 米）" % max_tgt)

	print("=== 结果：%s（fails=%d）===" % ["ALL PASS" if fails == 0 else "HAS FAIL", fails])
	quit(1 if fails > 0 else 0)
