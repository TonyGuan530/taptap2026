extends SceneTree
## demo-08 纸飞机模拟器 + 肉鸽 流程与平衡验证（headless，Engine.time_scale 6x 真实时间驱动）
## 用例1 折线上限：L1 限 3 次，第 4 次 add_fold 返回 false
## 用例2 参数汇总：外侧折线 lift_area 大于内侧折线；上方折线 trim 为正
## 用例3 投掷：do_throw(30, 0.8) 后 state=fly，位置随 physics_frame 推进（x 递增）
## 用例4 飞行结束：几秒后落地 state=settle，flight_distance > 0
## 用例5 过关判定：L1 两段外侧偏上折线 + 30° 满力应过 40 米终点
## 用例6 商店：过关后 state=shop、3 项强化，buy(0) 扣金币且生效
## 用例7 顺风逆风：等价折线+同角度力度，L3（顺风）距离 > L2（逆风）距离
## 用例8 全通关：3 关依次过关 → state=final（全通关结算）
## 运行：godot --headless --path game -s res://tests/test_demo08.gd

const BASE_SEED := 808

var log_lines: Array = []
var passes := 0
var fails := 0


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)
	var f := FileAccess.open("user://test08log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()


func _check(cond: bool, tag: String) -> void:
	if cond:
		passes += 1
		_log("PASS " + tag)
	else:
		fails += 1
		_log("FAIL " + tag)


func _new_scene() -> Control:
	seed(BASE_SEED)
	var s: Control = load("res://demo08_paperplane.tscn").instantiate()
	root.add_child(s)
	await physics_frame
	await physics_frame
	return s


func _wait_state(scene: Control, st: String, timeout_ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(scene) and scene.state != st and Time.get_ticks_msec() - t0 < timeout_ms:
		await physics_frame
	return is_instance_valid(scene) and scene.state == st


## 等 settle；超时打警告（防死循环挂死测试）
func _fly_and_settle(scene: Control) -> void:
	var ok: bool = await _wait_state(scene, "settle", 30000)
	if not ok:
		_log("警告：飞行 30 秒仍未结算，当前 state=%s" % str(scene.state))


## 折 n 条「外侧偏上」的等价折线：按各关纸面比例归一（中点约 0.92 宽 / 0.31 高）
func _good_folds(scene: Control, n: int) -> void:
	var pr: Rect2 = scene.paper_rect
	for k in n:
		var x: float = pr.position.x + pr.size.x * 0.92
		var y1: float = pr.position.y + pr.size.y * (0.08 + 0.06 * float(k))
		var y2: float = pr.position.y + pr.size.y * (0.54 + 0.06 * float(k))
		scene.add_fold(Vector2(x, y1), Vector2(x, y2))


## 商店里贪婪购买：从最便宜的买起，买得起就买（模拟肉鸽成长）
func _greedy_buy(scene: Control) -> void:
	var guard := 0
	while scene.state == "shop" and scene.shop_items.size() > 0 \
			and scene.coins >= int(scene.shop_items[0].price) and guard < 10:
		if not scene.buy(0):
			break
		guard += 1


func _run() -> void:
	await process_frame
	Engine.time_scale = 6.0
	_log("demo-08 纸飞机模拟器 + 肉鸽 headless 测试开始（time_scale 6x）")
	var s: Control = await _new_scene()

	# --- 用例1 折线上限：L1 限 3 次，第 4 次 false ---
	s.start_level(0)
	var pr1: Rect2 = s.paper_rect
	var all_ok := true
	for k in 3:
		var ok1: bool = s.add_fold(
			Vector2(pr1.position.x + pr1.size.x * 0.9, pr1.position.y + 20.0),
			Vector2(pr1.position.x + pr1.size.x * 0.9, pr1.position.y + pr1.size.y - 20.0))
		all_ok = all_ok and ok1
	var over: bool = s.add_fold(
		Vector2(pr1.position.x + 10.0, pr1.position.y + 10.0),
		Vector2(pr1.position.x + 10.0, pr1.position.y + 100.0))
	_check(all_ok and not over, "用例1 折线上限：前 3 次成功、第 4 次 add_fold 返回 false")

	# --- 用例2 参数汇总：外侧升力 > 内侧升力；上方折线 trim > 0 ---
	s.start_level(0)
	var pr2: Rect2 = s.paper_rect
	s.add_fold(Vector2(pr2.position.x + pr2.size.x * 0.92, pr2.position.y + pr2.size.y * 0.2),
		Vector2(pr2.position.x + pr2.size.x * 0.92, pr2.position.y + pr2.size.y * 0.8))
	var lift_outer: float = s.plane_params.lift_area
	s.start_level(0)
	var pr3: Rect2 = s.paper_rect
	s.add_fold(Vector2(pr3.position.x + pr3.size.x * 0.08, pr3.position.y + pr3.size.y * 0.2),
		Vector2(pr3.position.x + pr3.size.x * 0.08, pr3.position.y + pr3.size.y * 0.8))
	var lift_inner: float = s.plane_params.lift_area
	s.start_level(0)
	var pr4: Rect2 = s.paper_rect
	s.add_fold(Vector2(pr4.position.x + pr4.size.x * 0.2, pr4.position.y + pr4.size.y * 0.12),
		Vector2(pr4.position.x + pr4.size.x * 0.8, pr4.position.y + pr4.size.y * 0.12))
	var trim_top: float = s.plane_params.trim
	_check(lift_outer > lift_inner and trim_top > 0.0,
		"用例2 参数汇总：外侧折线 lift_area %.2f > 内侧 %.2f，上方折线 trim %.2f > 0" % [lift_outer, lift_inner, trim_top])

	# --- 用例3 投掷 + 用例4 飞行结算（共用一次飞行） ---
	s.start_level(0)
	_good_folds(s, 1)
	s._on_fold_done()
	var x0: float = s.plane_pos.x
	s.do_throw(30.0, 0.8)
	var is_fly: bool = s.state == "fly"
	for k in 24:
		await physics_frame
	var x1: float = s.plane_pos.x
	_check(is_fly and x1 > x0, "用例3 投掷：do_throw(30,0.8) 后 state=fly，x %.0f → %.0f 递增" % [x0, x1])
	await _fly_and_settle(s)
	_check(s.state == "settle" and s.flight_distance > 0.0,
		"用例4 飞行结算：落地后 state=settle，flight_distance %.1f 米 > 0" % s.flight_distance)

	# --- 用例5 过关判定：L1 两段外侧偏上折线 + 30° 满力过 40 米 ---
	s.start_level(0)
	_good_folds(s, 2)
	s._on_fold_done()
	s.do_throw(30.0, 1.0)
	await _fly_and_settle(s)
	var target1: float = float(s.LEVELS[0].target_m)
	_check(s.last_pass and s.flight_distance >= target1,
		"用例5 过关判定：L1 飞行 %.1f 米 ≥ 终点 %.0f 米（过关）" % [s.flight_distance, target1])

	# --- 用例6 商店：过关后 state=shop、3 项强化，buy(0) 扣金币 ---
	var coins_before: int = s.coins
	s.settle_continue()
	var shop_ok: bool = s.state == "shop" and s.shop_items.size() == 3
	var bought: bool = false
	if shop_ok and s.coins >= int(s.shop_items[0].price):
		bought = s.buy(0)
	var coins_after: int = s.coins
	_check(shop_ok and bought and coins_after < coins_before,
		"用例6 商店：state=shop 且 3 项强化，buy(0) 成功，金币 %d → %d（剩余商品 %d 项）" % [coins_before, coins_after, s.shop_items.size()])
	s.queue_free()
	await physics_frame

	# --- 用例7 顺风逆风：全新场景（无强化干扰），等价折线 + 同角度力度 ---
	var s2: Control = await _new_scene()
	s2.start_level(1)
	_good_folds(s2, 4)
	s2._on_fold_done()
	s2.do_throw(30.0, 1.0)
	await _fly_and_settle(s2)
	var d_head: float = s2.flight_distance
	s2.start_level(2)
	_good_folds(s2, 5)
	s2._on_fold_done()
	s2.do_throw(30.0, 1.0)
	await _fly_and_settle(s2)
	var d_tail: float = s2.flight_distance
	_check(d_tail > d_head, "用例7 风向：同折线同投掷，L3 顺风 %.1f 米 > L2 逆风 %.1f 米" % [d_tail, d_head])
	s2.queue_free()
	await physics_frame

	# --- 用例8 全通关：3 关依次过关 → state=final ---
	var s3: Control = await _new_scene()
	var all_pass := true
	for i in 3:
		s3.start_level(i)
		var folds_n: int = int(s3.LEVELS[i].folds)
		_good_folds(s3, folds_n)
		s3._on_fold_done()
		s3.do_throw(30.0, 1.0)
		await _fly_and_settle(s3)
		var tgt: float = float(s3.LEVELS[i].target_m)
		var lv_pass: bool = s3.last_pass and s3.flight_distance >= tgt
		all_pass = all_pass and lv_pass
		_log("  第%d关：飞行 %.1f 米（目标 %.0f 米）%s，金币 %d" % [i + 1, s3.flight_distance, tgt, "达标" if lv_pass else "未达标", s3.coins])
		if not s3.last_pass:
			break
		s3.settle_continue()   # 前两关 → 商店；第 3 关 → 全通关结算
		if s3.state == "shop":
			_greedy_buy(s3)
	_check(all_pass, "用例8a 全程：三关依次达标（等价折线 + 30° 满力，关间贪婪购买强化）")
	_check(s3.state == "final", "用例8b 全通关：第 3 关过关后 state=final（全通关结算面板）")
	s3.queue_free()
	await physics_frame

	Engine.time_scale = 1.0
	_log("==== 汇总：%d PASS / %d FAIL ====" % [passes, fails])
	quit(1 if fails > 0 else 0)
