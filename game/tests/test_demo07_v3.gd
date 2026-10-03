extends SceneTree
## demo-07 v3 合单实验验证（headless，真实时间）：
## 用例1 实验房配置：第 5 关双订单、8 组固定对、目标 16、无催单
## 用例2 批处理：点一次共享食材同时推进两单（merge_hits=1）
## 用例3 自由顺序：订单 requirements 任意顺序完成
## 用例4 完成替换：完成一单按固定序列补下一单
## 用例5 无效点击：没有任何订单需要的食材 → 扣时断连（不计合单）
## 用例6 L1 回归：单订单批处理退化正确
## 用例7 跑单遥测：耐心耗尽 rush_outs=1
## 用例8 全程通关：16 单全清 → clear，合单自然发生、点击数 < 单食材总数
## 运行：godot --headless --path game -s res://tests/test_demo07_v3.gd

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


func _click(s, id: String) -> void:
	s._on_ingredient(_ing_index(s, id))


func _run() -> void:
	print("=== demo-07 v3 合单实验测试 ===")
	var s: Control = load("res://demo07_cooking.tscn").instantiate()
	root.add_child(s)
	await physics_frame
	await physics_frame

	# 用例1 实验房配置
	s.unlocked = 4
	s.start_level(4)
	await physics_frame
	_check(s.state == "play", "1.1 实验房进入对局")
	_check(s.orders.size() == 2, "1.2 双订单")
	_check(s.LEVELS[4].target == 16, "1.3 目标 16 单")
	_check(not s.LEVELS[4].rush, "1.4 无催单（隔离合单变量）")
	_check(s.order_queue.size() == 16, "1.5 固定序列 16 单")
	_check(s.orders[0].items == ["bun", "patty", "sauce"], "1.6 对 0 单 A=面包/肉饼/酱料")
	_check(s.orders[1].items == ["bun", "lettuce", "cheese"], "1.7 对 0 单 B=面包/生菜/奶酪")

	# 用例2 批处理：面包两单都要 → 一击齐进
	_click(s, "bun")
	_check((s.orders[0].added as Array).has("bun") and (s.orders[1].added as Array).has("bun"), "2.1 一击同时推进两单")
	_check(s.merge_hits == 1, "2.2 合单利用计 1 次")
	_check(s.clicks_total == 1, "2.3 总点击计 1")
	_check(s.combo == 1, "2.4 生产性点击连击 +1")

	# 用例3+4 自由顺序 + 完成替换
	_click(s, "patty")   # 单 A 完成（bun+patty；酱料还没点也行？A=[bun,patty,sauce] 未完成）
	# A 需要 sauce 才满：A added=[bun,patty] → 点 sauce 完成 A
	_click(s, "sauce")
	_check(s.score == 1, "3.1 单 A 完成（自由顺序 bun→patty→sauce）")
	_check(s.orders[0].items == ["bun", "patty"], "3.2 按序列补进对 1 单 A=面包/肉饼")
	_click(s, "lettuce")
	_click(s, "cheese")
	_check(s.score == 2, "3.3 单 B 完成（自由顺序 lettuce→cheese）")

	# 用例5 无效点击：当前两单（对1 A=面包/肉饼，对1 B=面包/肉饼/奶酪）都不需要 sauce
	_click(s, "sauce")
	_check(s.clicks_total == 6, "5.1 无效点击也计入总点击")
	_check(s.time_left < 120.0, "5.2 无效点击扣时")
	_check(s.combo == 0, "5.3 无效点击断连")
	_check(s.merge_hits == 1, "5.4 无效点击不计合单")

	# 用例6 L1 回归：单订单批处理退化正确
	s.start_level(0)
	await physics_frame
	var items: Array = s.orders[0].items
	_check(s.orders.size() == 1, "6.1 L1 单订单")
	var need := 0
	while s.state == "play" and s.score < 1 and need < 8:
		var o: Dictionary = s.orders[0]
		var it: Array = o.items
		var ad: Array = o.added
		if ad.size() < it.size():
			_click(s, it[ad.size()])
		need += 1
	_check(s.score == 1, "6.2 L1 顺序点满出一单")

	# 用例7 跑单遥测
	s.start_level(3)
	await physics_frame
	s.orders[0].patience = 0.4
	await create_timer(1.0).timeout
	_check(s.rush_outs == 1, "7.1 耐心耗尽 rush_outs=1")

	# 用例8 实验房全通关：贪心点当前任一未满足需求 → 批处理自然发生
	s.start_level(4)
	await physics_frame
	var guard := 0
	while s.state == "play" and guard < 120:
		var clicked := false
		for k in s.orders.size():
			var o: Dictionary = s.orders[k]
			var it: Array = o.items
			var ad: Array = o.added
			if ad.size() < it.size():
				_click(s, it[ad.size()])
				clicked = true
				break
		if not clicked:
			break
		guard += 1
	_check(s.state == "clear", "8.1 16 单全清过关")
	_check(s.score == 16, "8.2 得分 16")
	_check(s.merge_hits >= 2, "8.3 固定序列自然产生合单（%d 次）" % s.merge_hits)
	var total_items := 0
	for pair in s.EXPERIMENT_PAIRS:
		total_items += (pair[0] as Array).size() + (pair[1] as Array).size()
	_check(s.clicks_total < total_items, "8.4 批处理省点击：%d < 食材总数 %d" % [s.clicks_total, total_items])

	print("=== 结果：%s（fails=%d）===" % ["ALL PASS" if fails == 0 else "HAS FAIL", fails])
	quit(1 if fails > 0 else 0)
