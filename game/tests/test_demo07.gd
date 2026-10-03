extends SceneTree
## demo-07 v2 四关卡验证（headless，真实时间）：
## 用例1 选关菜单：4 关配置齐全，仅第 1 关解锁（其余 🔒 disabled）
## 用例2 L1 出餐闭环：点满订单→得分+自动开新单
## 用例3 点错惩罚：扣时=penalty、连击清零
## 用例4 L3 双订单：完成一单另一单仍在，在制单数维持 2
## 用例5 L4 催单耐心环：耗尽→跑单（换新单+断连+扣时）
## 用例6 通关流转：达标→clear+解锁下一关；超时→end 打烊
## 运行：godot --headless --path game -s res://tests/test_demo07.gd

var fails := 0


func _init() -> void:
	_run()


func _check(cond: bool, tag: String) -> void:
	if cond:
		print("PASS: " + tag)
	else:
		fails += 1
		print("FAIL: " + tag)


func _ing_index(s, id: String) -> int:
	for i in s.ING.size():
		if s.ING[i].id == id:
			return i
	return -1


func _serve_active(s) -> void:
	# 服务当前单（第一个未点满的），逐个点它的食材
	var ai: int = s._active_idx()
	if ai < 0:
		return
	var o: Dictionary = s.orders[ai]
	for id in o.items:
		s._on_ingredient(_ing_index(s, id))


func _run() -> void:
	print("=== demo-07 v2 四关卡测试 ===")
	var s: Control = load("res://demo07_cooking.tscn").instantiate()
	root.add_child(s)
	await physics_frame
	await physics_frame

	# 用例1 菜单
	_check(s.state == "menu", "1.1 初始为选关菜单")
	_check(s.LEVELS.size() == 4, "1.2 四关配置齐全")
	var b0: Button = s.menu_panel.get_node("LevelBtn0")
	var b3: Button = s.menu_panel.get_node("LevelBtn3")
	_check(b0 != null and not b0.disabled, "1.3 第 1 关可选")
	_check(b3 != null and b3.disabled, "1.4 第 4 关初始锁定")

	# 用例2 L1 出餐闭环
	s.start_level(0)
	await physics_frame
	_check(s.state == "play", "2.1 L1 进入对局")
	_check(s.orders.size() == 1, "2.2 L1 单订单")
	_check((s.orders[0].items as Array).size() == 3, "2.3 L1 订单为 3 料")
	_serve_active(s)
	_check(s.score == 1, "2.4 点满一单得 1 分")
	_check((s.orders[0].added as Array).is_empty(), "2.5 出餐后自动开新单")

	# 用例3 点错惩罚
	s.combo = 5
	var t0: float = s.time_left
	var items: Array = s.orders[0].items
	var wrong_i := -1
	for i in s.ING.size():
		if not items.has(s.ING[i].id):
			wrong_i = i
			break
	s._on_ingredient(wrong_i)
	_check(absf((t0 - s.time_left) - 3.0) < 0.6, "3.1 点错扣 3 秒")
	_check(s.combo == 0, "3.2 点错断连击")

	# 用例4 L3 双订单
	s.unlocked = 3
	s.start_level(2)
	await physics_frame
	_check(s.orders.size() == 2, "4.1 L3 双订单并发")
	_check(not s.order_boxes[1].visible == false, "4.2 双框齐开")
	var before_score: int = s.score
	_serve_active(s)
	_check(s.score == before_score + 1, "4.3 完成当前单得分")
	_check(s.orders.size() == 2, "4.4 在制订单维持 2 单")

	# 用例5 L4 催单耐心环
	s.start_level(3)
	await physics_frame
	_check(absf(s.orders[0].patience - 30.0) < 0.5, "5.1 L4 订单带 30 秒耐心")
	s.orders[0].patience = 0.4
	s.combo = 4
	var t1: float = s.time_left
	await create_timer(1.0).timeout
	# 新单 0.4s 时换上，又衰减 ~0.6s → 应在 28.5~30 之间（换过单）
	_check(s.orders[0].patience > 28.5 and s.orders[0].patience <= 30.0, "5.2 耐心耗尽→换新单")
	_check(s.combo == 0, "5.3 跑单断连击")
	_check(s.time_left < t1 - 4.0, "5.4 跑单扣 5 秒")

	# 用例6 通关流转
	s.start_level(0)
	await physics_frame
	var guard := 0
	while s.state == "play" and guard < 40:
		_serve_active(s)
		guard += 1
	_check(s.state == "clear", "6.1 达标→过关结算")
	_check(s.unlocked >= 1, "6.2 解锁第 2 关")
	s._go_menu()
	var b1: Button = s.menu_panel.get_node("LevelBtn1")
	_check(b1 != null and not b1.disabled, "6.3 菜单里第 2 关已解锁")
	s.start_level(0)
	s.time_left = 0.05
	await create_timer(0.6).timeout
	_check(s.state == "end", "6.4 超时→打烊结算")
	_check(s.end_panel.visible, "6.5 结算面板可见")

	print("=== 结果：%s（fails=%d）===" % ["ALL PASS" if fails == 0 else "HAS FAIL", fails])
	quit(1 if fails > 0 else 0)
