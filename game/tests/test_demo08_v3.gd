extends SceneTree
## demo-08 v3 验收（监督者窄授权：同关 ≥3 种合理策略且无严格支配）：
## 用例1 三策略各自成立：俯冲吃低门、抬头吃高空门、稳定直通——三者都能通关
## 用例2 无严格支配：三种策略收益接近（极差 < 8 金币），没有一档碾压
## 用例3 门互斥性：高门/低门各有归属（俯冲只吃低门、抬头只吃高门）
## 用例4 稳定型容错：稳定区+贴近 40° → 阻力减免满额；角偏差大或配平出区 → 无减免
## 运行：godot --headless --path game -s res://tests/test_demo08_v3.gd

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
	print("=== demo-08 v3 同关三策略验收 ===")
	var s: Control = load("res://demo08_paperplane.tscn").instantiate()
	root.add_child(s)
	await physics_frame
	s.unlocked = 2

	# 用例1-3：L2 三种折法各掷一次
	var res: Dictionary = {}
	for cfg in [[0.85, "俯冲"], [0.5, "稳定"], [0.15, "抬头"]]:
		s.start_level(1)
		_fold_trim(s, 4, cfg[0])
		s._on_fold_done()
		var c0: int = s.coins
		await _fly(s)
		res[cfg[1]] = {
			cleared = s.last_pass, high = s.gate_hit, low = s.low_gate_hit,
			earn = s.coins - c0, dist = s.flight_distance,
		}
		print("  %s: pass=%s 高门=%s 低门=%s 收益=%d 距离=%.1f m" % [
			cfg[1], s.last_pass, s.gate_hit, s.low_gate_hit, s.coins - c0, s.flight_distance])

	# 用例1 三策略各自成立（都能通关 = 无被淘汰的策略）
	_check(res["俯冲"].cleared and res["稳定"].cleared and res["抬头"].cleared,
		"1.1 俯冲/稳定/抬头三种策略都能通关（无支配的第一条：没有策略被淘汰）")
	# 用例2 收益无碾压
	var earns: Array = [res["俯冲"].earn, res["稳定"].earn, res["抬头"].earn]
	var spread: int = earns.max() - earns.min()
	_check(spread < 8, "2.1 三策略收益极差 %d < 8 金币（无一档碾压）" % spread)
	# 用例3 门各有归属
	_check(res["俯冲"].low and not res["俯冲"].high, "3.1 俯冲型吃低空门（不越高门）")
	_check(res["抬头"].high and not res["抬头"].low, "3.2 抬头型吃高空门（不低于门）")

	# 用例4 稳定型容错
	s.start_level(1)
	_fold_trim(s, 4, 0.5)  # 稳定区配平
	s._on_fold_done()
	s.do_throw(40.0, 1.0)  # 贴近最优角
	_check(absf(s.angle_forgive - 0.2) < 0.01, "4.1 稳定区+40°：阻力减免满额 0.2")
	s.start_level(1)
	_fold_trim(s, 4, 0.5)  # 稳定区配平
	s._on_fold_done()
	s.do_throw(30.0, 1.0)  # 偏 10°
	_check(absf(s.angle_forgive) < 0.001, "4.2 稳定区+偏离 10°：无减免（±5° 容差带）")
	s.start_level(1)
	_fold_trim(s, 4, 0.15)  # 抬头区配平
	s._on_fold_done()
	s.do_throw(40.0, 1.0)
	_check(absf(s.angle_forgive) < 0.001, "4.3 配平出稳定区（抬头）：无减免")

	print("=== 结果：%s（fails=%d）===" % ["ALL PASS" if fails == 0 else "HAS FAIL", fails])
	quit(1 if fails > 0 else 0)
