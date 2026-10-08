extends SceneTree
## B1-5 刚体车接入场景流程验证（headless，零窗口，真实时间）
## 用例1 use_rigid=true 车库发车：state=drive、rigid 非空、无 car_view（桥梁与刚体二选一）
## 用例2 action 层：W（demo09_fwd）= 油门，速度增长（米/秒直读）
## 用例3 HUD：刚体模式键位明示（W/S 与 A/D），桥梁/刚体文案不同
## 用例4 冲线结算：teleport 到终点前 → settle、解锁 L2、total_time 累加、面板"过关！"
## 用例5 settle_continue → L2 车库（restore 语义共用）
## 运行：Godot --headless --path game -s res://tests/test_demo09_3d_rigidflow.gd

var passes := 0
var fails := 0


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)


func _check(cond: bool, tag: String) -> void:
	if cond:
		passes += 1
		_log("PASS " + tag)
	else:
		fails += 1
		_log("FAIL " + tag)


func _run() -> void:
	var s = load("res://demo09_3d.tscn").instantiate()
	s.auto_start = false
	s.use_rigid = true
	root.add_child(s)
	await process_frame
	await physics_frame

	s.open_level(0)
	for w in [[0.15, 18.0, -1.2], [0.15, 18.0, 1.2], [0.85, 18.0, -1.2], [0.85, 18.0, 1.2]]:
		s.garage_add_wheel_at(float(w[0]), float(w[1]), float(w[2]))
	_check(s.garage_launch(), "用例1a 刚体模式发车成功")
	_check(s.state == "drive" and s.rigid != null and s.car_view == null,
		"用例1b drive 态：rigid 非空、无 car_view（双路径互斥）")
	_check(s.wheel_list.get_item_count() == 4 and "右" in s.wheel_list.get_item_text(1),
		"用例1c 车库列表含侧位标注")

	for i in range(90):
		await physics_frame   # 落地稳定
	Input.action_press("demo09_fwd")
	for i in range(120):
		await physics_frame
	var v: float = float(s.rigid.linear_velocity.length())
	_check(v > 20.0, "用例2 W 油门（action 层）生效：%.1f m/s" % v)
	_check("W/S" in s.hint_label.text and "A/D" in s.hint_label.text,
		"用例3 HUD 键位明示：%s" % s.hint_label.text)

	# 冲线：teleport 到终点前 1m，给 −Z 速度
	s.rigid.position.z = -799.0
	s.rigid.linear_velocity = Vector3(0, 0, -20)
	var guard := 0
	while s.state == "drive" and guard < 120:
		await physics_frame
		guard += 1
	_check(s.state == "settle" and s.settle_title.text == "过关！", "用例4a 刚体冲线结算（%d 帧）" % guard)
	_check(s.unlocked == 1 and s.total_time > 0.0, "用例4b 解锁 L2 且 total_time 累加")
	Input.action_release("demo09_fwd")
	s.settle_continue()
	_check(s.state == "build" and s.level_idx == 1 and s.rigid == null, "用例5 进入 L2 车库（rigid 已清）")

	# 用例6 翻车结算（D10）：L1 重新发车 → 注入已碰撞状态（倒置+车顶贴地+roof_time=1.40）→
	# 场景消费 rolled_over → 翻车结算（优先于冲线）、不解锁；重试回 L1 车库
	s.open_level(0)
	for w in [[0.15, 18.0, -1.2], [0.15, 18.0, 1.2], [0.85, 18.0, -1.2], [0.85, 18.0, 1.2]]:
		s.garage_add_wheel_at(float(w[0]), float(w[1]), float(w[2]))
	_check(s.garage_launch(), "用例6a 重新发车")
	for i in range(90):
		await physics_frame   # 落地稳定
	var unlocked_before: int = s.unlocked
	s.rigid.position.y = 1.8           # 车顶角压到地面
	s.rigid.rotation = Vector3(PI, 0, 0)
	s.rigid.linear_velocity = Vector3.ZERO
	s.rigid.angular_velocity = Vector3.ZERO
	s.rigid.roof_time = 1.40           # 等价真实翻滚后已累计触地
	var guard6 := 0
	while s.state == "drive" and guard6 < 120:
		await physics_frame
		guard6 += 1
	_check(s.state == "settle" and s.settle_title.text == "翻车" and s._rigid_passed == false,
		"用例6b 翻车结算（%d 帧）" % guard6)
	_check(s.unlocked == unlocked_before, "用例6c 翻车不解锁")
	s.settle_continue()
	_check(s.state == "build" and s.level_idx == 0, "用例6d 翻车重试回 L1 车库（restore 预填）")

	s.queue_free()
	_log("==== 汇总：%d PASS / %d FAIL ====" % [passes, fails])
	quit(1 if fails > 0 else 0)
