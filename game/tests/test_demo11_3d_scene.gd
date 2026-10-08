extends SceneTree
## DEMO11 3D 灰模场景 headless 测试：通过 Input.parse_input_event 注入 InputEventKey，
## 走真实 Input→Viewport→_unhandled_input 分发管线（不直接调用核心方法），
## 验证输入忽略 echo、撞墙不转向、连续输入不丢、工具门禁、推箱压板门反馈、
## 过房视图重建、沉水成桥与环境融化经 _process 推进、镜头观察输入。
## 运行：godot --headless --path game -s res://tests/test_demo11_3d_scene.gd

const MainScene := preload("res://demo11_3d.tscn")

var passes := 0
var fails := 0
var main


func _init() -> void:
	# 看门狗：协程若中途出错会静默停止导致永不 quit，45s 后强制退出码 2
	var watchdog := create_timer(240.0)
	watchdog.timeout.connect(func() -> void:
		print("TIMEOUT 看门狗触发：测试未在时限内完成")
		quit(2))
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("PASS  " + msg)
	else:
		fails += 1
		print("FAIL  " + msg)


func _key(keycode: int, echo := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	ev.echo = echo
	Input.parse_input_event(ev)
	var ev2 := InputEventKey.new()
	ev2.keycode = keycode
	ev2.physical_keycode = keycode
	ev2.pressed = false
	Input.parse_input_event(ev2)
	Input.flush_buffered_events()


func _keys(seq: Array) -> void:
	for k in seq:
		_key(int(k))
		await _frames(2)  # 每键隔 2 帧（与探针一致）：同帧连发键事件顺序不可靠，2 帧间隔已验证逐键正常


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _view_at(x: float, z: float) -> bool:
	for k in main._obj_views:
		var v: Node3D = main._obj_views[k]
		if absf(v.position.x - x) < 0.3 and absf(v.position.z - z) < 0.3:
			return true
	return false


func _obj_at(s, type: String, x: int, y: int) -> bool:
	for o in s.objects:
		if String(o.type) == type and int(o.x) == x and int(o.y) == y:
			return true
	return false


func _run() -> void:
	main = MainScene.instantiate()
	root.add_child(main)
	await _frames(3)

	# ---- 场景1 实例化与初始状态 ----
	_check(main.rules != null and main.rules.room_idx == 0 and int(main.rules.player.x) == 1 and int(main.rules.player.y) == 1,
		"场景1a 灰模实例化：规则核心房1 起点 P(1,1)")
	_check(main._obj_views.size() == 2, "场景1b 房1 物件视图=2（两木箱；压力板由地形层画）")
	_check(main.cam != null and main.cam.projection == Camera3D.PROJECTION_ORTHOGONAL,
		"场景1c 相机为正交投影（斜俯视固定镜头）")
	_check(String(main.status_label.text).contains("房间 1"), "场景1d HUD 显示房间 1")

	# ---- 场景2 右移一格 ----
	_key(KEY_RIGHT)
	await _frames(3)
	_check(int(main.rules.player.x) == 2 and int(main.rules.steps) == 1 and main.rules.facing == "right",
		"场景2 KEY_RIGHT 真实分发：右移一格 (2,1)，facing=right")

	# ---- 场景3 撞墙拒绝 ----
	_key(KEY_UP)
	await _frames(3)
	_check(int(main.rules.player.x) == 2 and int(main.rules.steps) == 1 and main.rules.facing == "right",
		"场景3 KEY_UP 撞墙：不转向不记步（仍沿右面向）")

	# ---- 场景4 echo 忽略 ----
	_key(KEY_LEFT, true)
	await _frames(3)
	_check(int(main.rules.player.x) == 2 and int(main.rules.steps) == 1,
		"场景4 echo 事件被忽略，位置步数不变")

	# ---- 场景5 连续快速输入不丢 ----
	_key(KEY_RIGHT)
	_key(KEY_RIGHT)
	await _frames(4)
	_check(int(main.rules.player.x) == 4 and int(main.rules.steps) == 3,
		"场景5 连按两次右都结算：(4,1) steps=3（动画未完不丢合法命令）")

	# ---- 场景6 工具门禁 ----
	_key(KEY_F)
	await _frames(3)
	_check(int(main.rules.tele.tool_use) == 0,
		"场景6 房1 无冰霜杖：F 拒绝且不崩溃（tool_use 仍 0）")

	# ---- 场景7 推箱压开关门开（先右移到 (5,1)，再下推箱 (5,2)→(5,3)） ----
	_key(KEY_RIGHT)
	await _frames(3)
	_key(KEY_DOWN)
	await _frames(10)
	var box_view_near := false
	for k7 in main._obj_views:
		var v7: Node3D = main._obj_views[k7]
		if absf(v7.position.x - 5.5) < 0.3 and v7.position.z > 2.9:
			box_view_near = true
	_check(main.rules.gate_open() and box_view_near,
		"场景7 箱推上开关 (5,3)：门开，箱视图到位/到位中")
	_check(String(main.status_label.text).contains("开启"), "场景7b HUD 门状态反馈：开启")

	# ---- 场景8 走完房1 路径A 进房2，视图重建 ----
	await _keys([KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_LEFT])
	await _frames(3)
	await _keys([KEY_DOWN, KEY_DOWN, KEY_DOWN])
	await _frames(4)
	_check(main.rules.room_idx == 1 and int(main.rules.rooms_cleared) == 1,
		"场景8a 踏上开启的门过房：房2（rooms_cleared=1）")
	_check(main._obj_views.size() == 1, "场景8b 过房后物件视图重建=1（房2 单箱）")
	_check(int(main.rules.player.x) == 1 and int(main.rules.player.y) == 1,
		"场景8c 玩家视图重定位到房2 起点 P(1,1)")

	# ---- 场景9 房2 推箱入水 → bridge，物件视图移除 ----
	await _keys([KEY_DOWN, KEY_DOWN])
	await _frames(3)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(35)  # 等沉水动画（0.25s）结束并 free
	_check(main.rules.objects.is_empty() and main._obj_views.is_empty(),
		"场景9a 箱沉入水：核心移除+视图节点移除")
	_check(String(main.rules.grid[main.rules._idx(5, 3)]) == "bridge",
		"场景9b 沉水格变 bridge 地形（事件后单格刷新）")
	_key(KEY_RIGHT)
	await _frames(4)
	_check(int(main.rules.player.x) == 5,
		"场景9c 玩家真实按键走上 bridge（可走地形验证）")
	_check(int(main.rules.tele.object_move) == 2,
		"场景9d 兼容口径：累计 2（房1 箱压板推 + 房2 桥前普通推），sink 不增 object_move")

	# ---- 场景10 冻冰 + 环境融化经 _process 推进 ----
	# 走位到 (4,4) 面朝右，面前 (5,4) 是水列（面向只能由成功移动更新，不能原地转向）
	await _keys([KEY_LEFT, KEY_LEFT, KEY_DOWN, KEY_RIGHT])
	await _frames(4)
	_key(KEY_F)
	await _frames(3)
	_check(int(main.rules.player.x) == 4 and int(main.rules.player.y) == 4 and main.rules.facing == "right",
		"场景10a-0 玩家走到 (4,4)，facing=right")
	_check(String(main.rules.grid[main.rules._idx(5, 4)]) == "ice" and int(main.rules.tele.freeze) == 1,
		"场景10a F 冻结面前水格 (5,4) → ice（facing=%s tile=%s tools=%s state=%s）" % [
			str(main.rules.facing), String(main.rules.grid[main.rules._idx(5, 4)]),
			str(main.rules.tools), str(main.rules.state)])
	main.rules.melt_queue.append({x = 5, y = 4, left = 0.05})
	await _frames(30)  # ~0.5s：_process → advance_time 倒计时
	_check(String(main.rules.grid[main.rules._idx(5, 4)]) == "water",
		"场景10b 环境倒计时融化：空冰回水（经 _process 真实推进）")

	# ---- 场景11 镜头观察输入 ----
	_key(KEY_HOME)
	await _frames(2)
	_check(absf(main.cam.size - main.CAM_HOME_SIZE) < 0.01, "场景11a Home 复位镜头尺寸")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	await _frames(2)
	_check(absf(main.cam.size - (main.CAM_HOME_SIZE + 0.5)) < 0.01,
		"场景11b 滚轮缩放镜头（观察输入，不影响规则）")

	# ================= 场景12 房2 收尾：走箱桥到门 → 房3（阶段 B 工具链路开始） =================
	await _keys([KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	_check(main.rules.room_idx == 2 and int(main.rules.rooms_cleared) == 2,
		"场景12 房2 收尾（箱桥过河到门）：进入房3（rooms_cleared=2）")
	_check(String(main.rules.family_by_room[1]) == "box_bridge",
		"场景12b 房2 family=box_bridge（箱沉水成桥）")

	# ================= 场景13 房3：G 沿 facing 烧箱（真实按键解法） =================
	# down×3 right×5 up → 玩家 (6,3) 面朝上，G 烧面前 (6,2) 箱；再绕推 (3,2) 箱到开关 (6,3)
	await _keys([KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_UP])
	await _frames(5)
	_key(KEY_G)
	await _frames(5)
	_check(int(main.rules.tele.burn) == 1 and not _obj_at(main.rules, "box", 6, 2) and _obj_at(main.rules, "box", 5, 3),
		"场景13a G 沿 facing 烧掉面前 (6,2) 木箱，(5,3) 箱不受影响（工具只作用于面前格）")
	# 烧 (6,2) 后：(3,2) 箱右推两次到 (5,2)，(4,3) 右推 A 箱上开关 (6,3)，绕 row4 到门 (9,5)
	await _keys([KEY_DOWN, KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_UP, KEY_UP, KEY_RIGHT, KEY_RIGHT,
		KEY_DOWN, KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN])
	await _frames(8)
	_check(main.rules.room_idx == 3 and String(main.rules.family_by_room[2]) == "plain",
		"场景13b 房3 通关（G 烧挡路箱+右推 A 箱上开关）：family=plain（burn 不入 family，兼容口径）[dbg 玩家=%s,%s %s 门=%s A@5,3=%s A@6,3=%s C@5,2=%s]" % [
			str(int(main.rules.player.x)), str(int(main.rules.player.y)), str(main.rules.facing),
			str(main.rules.gate_open()), str(_obj_at(main.rules, "box", 5, 3)),
			str(_obj_at(main.rules, "box", 6, 3)), str(_obj_at(main.rules, "box", 5, 2))])

	# ================= 场景14 房4：H 沿 facing 拉铁 + 推铁上开关（真实按键解法） =================
	# 磁拉落点不能是玩家格：先 H×5 把铁拉到 (4,3)；玩家绕右侧通道 (10,3) 转朝左，连推两格把铁顶上开关 (2,3)
	await _keys([KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	for i in 5:
		_key(KEY_H)
		await _frames(2)
	await _frames(6)
	_check(_obj_at(main.rules, "iron", 4, 3),
		"场景14a H×5 沿 facing 视线拉铁 (9,3)→(4,3)（落点不越玩家格）")
	await _keys([KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_RIGHT,
		KEY_UP, KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_DOWN,
		KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_LEFT])
	await _frames(8)
	_check(_obj_at(main.rules, "iron", 2, 3) and main.rules.gate_open() and main.rules.room_idx == 3,
		"场景14b 绕行推铁上开关 (2,3)，门开（铁压开关，仍在房4）")
	_check(int(main.rules.tele.tool_use) == 7 and int(main.rules.tele.object_move) == 12,
		"场景14c 遥测累计：tool_use=7（冻1+烧1+磁5）、object_move=12（普通推7：房1/房2/房3×3/房4绕行×2 + 磁拉5，sink 不计）")
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_DOWN])
	await _frames(6)
	_check(main.rules.room_idx == 4 and String(main.rules.family_by_room[3]) == "magnet_iron",
		"场景14d 房4 通关（磁拉+推铁流）：family=magnet_iron，进入房5（索引 [4]）")

	# ================= 场景15 房5 双开关 → final（五房真实按键全流程） =================
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	_check(main.rules.room_idx == 4 and not main.rules.gate_open() and _obj_at(main.rules, "iron", 9, 4),
		"场景15a 房5：B2 沉水成桥+铁推上开关A，单开关不足门仍关")
	await _keys([KEY_LEFT, KEY_DOWN, KEY_RIGHT])
	await _frames(5)
	_check(main.rules.gate_open() and _obj_at(main.rules, "box", 9, 5),
		"场景15b 房5：木箱推上开关B，双开关同时压住门开")
	await _keys([KEY_UP, KEY_UP])
	await _frames(8)
	_check(main.rules.room_idx == 5 and main.rules.state == "play" and int(main.rules.tele.room5_complete) == 1,
		"场景15c 五房全流程（真实按键连续通关）：进入 EXT-1（六房制 final 移至扩展房）、room5_complete=1")
	_check(String(main.rules.family_by_room[4]) == "box_bridge" and main.rules.family_by_room.size() == 5,
		"场景15d 五房 family 齐全（房5=box_bridge）")
	_check(int(main.rules.steps) == 101,
		"场景15e 五房步数=101（房1=12 房2=17 房3=26 房4=32 房5=14，工具不计步）")
	# ---- 场景15g EXT-1 解法A（真实按键 15 步：箱桥+铁上开关，不动移动火把） → 进入 EXT-2（七房制） ----
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_UP,
		KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_DOWN, KEY_LEFT])
	await _frames(10)
	_check(main.rules.room_idx == 6 and main.rules.state == "play" and int(main.rules.steps) == 116,
		"场景15g EXT-1 解法A（真实按键 15 步）：进入 EXT-2（七房制：final 移至 EXT-2 通关），全程 116 步（101+15）")
	_check(String(main.rules.family_by_room[5]) == "box_bridge" and main.rules.family_by_room.size() == 6,
		"场景15h 六段 family 齐全（EXT-1=box_bridge）")
	# ---- 场景15j EXT-2 解法（真实按键 13 步：推铁上 S + 保持 N 空置） → 进入 EXT-3（八房制） ----
	await _keys([KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 7 and main.rules.state == "play" and int(main.rules.steps) == 129,
		"场景15j EXT-2 解法（真实按键 13 步）：进入 EXT-3（八房制：final 移至 EXT-3 通关），全程 129 步（116+13）")
	# ---- 场景15k EXT-3 解法A（真实按键 18 步：薄冰单次通行 + 铁上开关） → 进入 EXT-4（九房制） ----
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_UP, KEY_RIGHT,
		KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_LEFT, KEY_UP])
	await _frames(10)
	_check(main.rules.room_idx == 8 and main.rules.state == "play" and int(main.rules.steps) == 147,
		"场景15k EXT-3 解法A（真实按键 18 步）：进入 EXT-4（九房制：final 移至 EXT-4 通关），全程 147 步（129+18）")
	# ---- 场景15m EXT-4 解法A（真实按键 13 步：四机制协同薄冰道） → final（九房制） ----
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_RIGHT,
		KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_UP])
	await _frames(10)
	_check(main.rules.room_idx == 9 and main.rules.state == "play" and int(main.rules.steps) == 161,
		"场景15m EXT-4 解法A（真实按键 13 步）：进入 EXT-5（十房制：final 移至 EXT-5 通关），全程 161 步（147+14）")
	_check(String(main.rules.family_by_room[8]) == "plain" and main.rules.family_by_room.size() == 9,
		"场景15n 九段 family 齐全（EXT-4=plain）")
	# ---- 场景15o EXT-5 解法（真实按键 12 步：淬冰 + 铁上开关）→ room_clear 进入 EXT-6（十一房制） ----
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_F, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_DOWN, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 10 and main.rules.state == "play" and int(main.rules.steps) == 173,
		"场景15o EXT-5 解法（真实按键 12 步）：room_clear 进入 EXT-6，全程 173 步（161+12）")
	_check(String(main.rules.family_by_room[9]) == "freeze_route" and main.rules.family_by_room.size() == 10,
		"场景15p 十段 family 齐全（EXT-5=freeze_route，F 淬冰所致）")
	# ---- 场景15q EXT-6 解法（真实按键 10 步：推铁上开关 → G） → room_clear 进入 EXT-7（十二房制） ----
	await _keys([KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN,
		KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 11 and main.rules.state == "play" and int(main.rules.steps) == 183,
		"场景15q EXT-6 解法（真实按键 10 步）：room_clear 进入 EXT-7，全程 183 步（173+10）")
	_check(String(main.rules.family_by_room[10]) == "plain" and main.rules.family_by_room.size() == 11,
		"场景15r 十一段 family 齐全（EXT-6=plain，纯走位）")
	# ---- 场景15s EXT-7 解法A（真实按键 23 步：挪灶化冰）→ room_clear 进入 EXT-8（十三房制） ----
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_UP,
		KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_UP])
	await _frames(5)
	main.rules.advance_time(5.0)  # 强制到期：M 邻冰融化倒计时（真实帧路径由 3 秒自然到期，此处锁定确定性）
	await _keys([KEY_UP, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 12 and main.rules.state == "play" and int(main.rules.steps) == 206,
		"场景15s EXT-7 解法A（真实按键 23 步 + 挪灶融化）：room_clear 进入 EXT-8，全程 206 步（183+23）")
	_check(String(main.rules.family_by_room[11]) == "plain" and main.rules.family_by_room.size() == 12,
		"场景15t 十二段 family 齐全（EXT-7=plain，纯挪灶无工具）")
	# ---- 场景15u EXT-8 解法（真实按键 12 步：单行阀）→ room_clear 进入 EXT-9（十四房制） ----
	await _keys([KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 13 and main.rules.state == "play" and int(main.rules.steps) == 218,
		"场景15u EXT-8 解法（真实按键 12 步：单行阀）：room_clear 进入 EXT-9，全程 218 步（206+12）")
	_check(String(main.rules.family_by_room[12]) == "plain" and main.rules.family_by_room.size() == 13,
		"场景15v 十三段 family 齐全（EXT-8=plain，无工具）")
	# ---- 场景15w EXT-9 解法（真实按键 16 步：对影门）→ room_clear 进入 EXT-10（十五房制） ----
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_DOWN,
		KEY_UP, KEY_LEFT, KEY_UP, KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_DOWN, KEY_DOWN, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 14 and main.rules.state == "play" and int(main.rules.steps) == 234,
		"场景15w EXT-9 解法（真实按键 16 步：对影门）：room_clear 进入 EXT-10，全程 234 步（218+16）")
	_check(String(main.rules.family_by_room[13]) == "plain" and main.rules.family_by_room.size() == 14,
		"场景15x 十四段 family 齐全（EXT-9=plain，无工具）")
	# ---- 场景15y EXT-10 解法（真实按键 13 步：铁敬）→ room_clear 进入 EXT-11（十六房制） ----
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_UP, KEY_RIGHT, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 15 and main.rules.state == "play" and int(main.rules.steps) == 247,
		"场景15y EXT-10 解法（真实按键 13 步：铁敬）：room_clear 进入 EXT-11，全程 247 步（234+13）")
	_check(String(main.rules.family_by_room[14]) == "plain" and main.rules.family_by_room.size() == 15,
		"场景15z 十五段 family 齐全（EXT-10=plain，无工具）")
	# ---- 场景15aa EXT-11 解法（真实按键 14 键：G 烧墙 + 13 步）→ room_clear 进入 EXT-12（十七房制） ----
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_G, KEY_RIGHT, KEY_RIGHT,
		KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_DOWN, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 16 and main.rules.state == "play" and int(main.rules.steps) == 260,
		"场景15aa EXT-11 解法（真实按键：G 烧墙 + 13 步）：room_clear 进入 EXT-12，全程 260 步（247+13）")
	_check(String(main.rules.family_by_room[15]) == "plain" and main.rules.family_by_room.size() == 16,
		"场景15ab 十六段 family 齐全（EXT-11=plain，烧墙不入 family 关键词）")
	# ---- 场景15ac EXT-12 解法（真实按键 11 步：冰厅）→ room_clear 进入 EXT-13（十八房制） ----
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_DOWN, KEY_DOWN,
		KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 17 and main.rules.state == "play" and int(main.rules.steps) == 271,
		"场景15ac EXT-12 解法（真实按键 11 步：冰厅）：room_clear 进入 EXT-13，全程 271 步（260+11）")
	_check(String(main.rules.family_by_room[16]) == "plain" and main.rules.family_by_room.size() == 17,
		"场景15ad 十七段 family 齐全（EXT-12=plain，无工具）")
	# ---- 场景15ae EXT-13 解法（真实按键 13 步：闸时）→ room_clear 进入 EXT-14（十九房制） ----
	# 真实按键在开窗（装载后 2 秒）内完成过门——入房后连打不等待
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_DOWN, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 18 and main.rules.state == "play" and int(main.rules.steps) == 284,
		"场景15ae EXT-13 解法（真实按键 13 步：闸时）：room_clear 进入 EXT-14，全程 284 步（271+13）")
	_check(String(main.rules.family_by_room[17]) == "plain" and main.rules.family_by_room.size() == 18,
		"场景15af 十八段 family 齐全（EXT-13=plain，无工具）")
	# ---- 场景15ag EXT-14 解法（真实按键 13 步：跃泉）→ room_clear 进入 EXT-15（二十房制） ----
	await _keys([KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_UP, KEY_RIGHT, KEY_UP,
		KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 19 and main.rules.state == "play" and int(main.rules.steps) == 297,
		"场景15ag EXT-14 解法（真实按键 13 步：跃泉）：room_clear 进入 EXT-15，全程 297 步（284+13）")
	_check(String(main.rules.family_by_room[18]) == "plain" and main.rules.family_by_room.size() == 19,
		"场景15ah 十九段 family 齐全（EXT-14=plain，无工具）")
	# ---- 场景15ai EXT-15 解法（真实按键 16 键：错拍，advance_time(2.0) 确定性切反拍） → final（二十房制） ----
	# 前四键在开窗内踩 Z；中间等待 170 帧（真实走表过周期点）；后段出袋穿 z + 东岸结算
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	main.rules.advance_time(2.0)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_UP, KEY_RIGHT, KEY_RIGHT,
		KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_DOWN, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 20 and main.rules.state == "play" and int(main.rules.steps) == 312,
		"场景15ai EXT-15 解法（真实按键：踩 Z 等反拍穿 z + 铁两推下上开关 + 进 G）：room_clear 进入 EXT-16，全程 312 步（297+15）")
	# ---- 场景15ak EXT-16 解法（真实按键 11 键：合鸣） → final（二十一房制） ----
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 21 and main.rules.state == "play" and int(main.rules.steps) == 323,
		"场景15ak EXT-16 解法（真实按键 11 键：铁滑一推定音 + 相位门过门 + 进 G）：room_clear 进入 EXT-17，全程 323 步（312+11）")
	_check(String(main.rules.family_by_room[20]) == "plain" and main.rules.family_by_room.size() == 21,
		"场景15al 二十一段 family 齐全（EXT-16=plain，无工具）")
	# ---- 场景15am EXT-17 解法（真实按键 15 键：间歇泉，冻冰工具不计步） → room_clear 进入 EXT-18（二十三房制） ----
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_F, KEY_RIGHT, KEY_RIGHT,
		KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 22 and main.rules.state == "play" and int(main.rules.steps) == 337,
		"场景15am EXT-17 解法（真实按键：冻冰抢窗过涧 + 铁下推上开关 + 进 G）：room_clear 进入 EXT-18，全程 337 步（323+14）")
	_check(String(main.rules.family_by_room[21]) == "freeze_route" and main.rules.family_by_room.size() == 22,
		"场景15an 二十二段 family 齐全（EXT-17=freeze_route，F 冻冰）")
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 23 and main.rules.state == "play" and int(main.rules.steps) == 342,
		"场景15ao EXT-18 解法（真实按键 5 键：弹簧跳越水踩自锁 + 过相位门 + 进 G）：room_clear 进入 EXT-19，全程 342 步（337+5）")
	_check(String(main.rules.family_by_room[22]) == "plain" and main.rules.family_by_room.size() == 23,
		"场景15ap 二十三段 family 齐全（EXT-18=plain，无工具）")
	# ---- 场景15aq EXT-19 解法（真实按键 15 键：呼吸桥，冻冰工具不计步） → room_clear 进入 EXT-20（二十六房制） ----
	# 前四键到涧边；advance_time(2.0) 确定性切寒泉结冰；后段过涧 + 东岸结算（分批注入防丢键）
	await _keys([KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_RIGHT])
	main.rules.advance_time(2.0)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_UP, KEY_RIGHT, KEY_DOWN])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_DOWN, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 24 and main.rules.state == "play" and int(main.rules.steps) == 356,
		"场景15aq EXT-19 解法（真实按键：等寒泉结冰过涧 + 铁下推上开关 + 进 G）：room_clear 进入 EXT-20，全程 356 步（342+14）")
	_check(String(main.rules.family_by_room[23]) == "plain" and main.rules.family_by_room.size() == 24,
		"场景15ar 二十四段 family 齐全（EXT-19=plain，无工具，冻冰来自寒泉周期）")
	# ---- 场景15as EXT-20 解法（真实按键 12 键：脆壁，铁推穿裂墙缺口） → room_clear 进入 EXT-21（二十七房制） ----
	# D 到行 2；R×6 推铁穿缺口（第三推砸穿 D(5,2)）压上 S(8,2)；D,R,R,R 绕行；U 进 G(10,2)
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_UP])
	await _frames(10)
	_check(main.rules.room_idx == 25 and main.rules.state == "play" and int(main.rules.steps) == 368,
		"场景15as EXT-20 解法（真实按键 12 键：铁推穿脆壁缺口上开关 + 绕行进 G）：room_clear 进入 EXT-21，全程 368 步（356+12）")
	_check(String(main.rules.family_by_room[24]) == "plain" and main.rules.family_by_room.size() == 25,
		"场景15at 二十五段 family 齐全（EXT-20=plain，无工具，缺口靠推碰砸穿）")
	# ---- 场景15au EXT-21 解法（真实按键 8 键：三拍，错相三连窗） → room_clear 进入 EXT-22（三十房制） ----
	# 一拍 R 过西门（开局即开）；advance_time(2.0) 确定性切寒泉冻桥；二拍 R×5 抢冰过涧到东岸；
	# advance_time(2.2) 越过整周期（桥身后融化）+ 东门同相重开；三拍 R×2 过东门进 G
	await _keys([KEY_RIGHT])
	await _frames(5)
	main.rules.advance_time(2.0)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	main.rules.advance_time(2.2)
	await _keys([KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 26 and main.rules.state == "play" and int(main.rules.steps) == 376,
		"场景15au EXT-21 解法（真实按键 8 键：过门-抢冰-候门三连窗）：room_clear 进入 EXT-22，全程 376 步（368+8）")
	_check(String(main.rules.family_by_room[25]) == "plain" and main.rules.family_by_room.size() == 26,
		"场景15av 二十六段 family 齐全（EXT-21=plain，无工具，节奏即门槛）")
	# ---- 场景15ax EXT-22 解法（真实按键 12 键：暗缝，缝前绕行下推 + 钻缝） → room_clear 进入 EXT-23（三十房制） ----
	# R 推铁右；U,R 绕铁上；D,D 铁下推上开关 S(3,4)；R,R,U,R 到缝前；R 钻缝；R,R,R 进 G(9,2)
	await _keys([KEY_RIGHT, KEY_UP, KEY_RIGHT, KEY_DOWN])
	await _frames(5)
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_UP])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 27 and main.rules.state == "play" and int(main.rules.steps) == 388,
		"场景15ax EXT-22 解法（真实按键 12 键：铁上开关 + 玩家钻缝进 G）：room_clear 进入 EXT-23，全程 388 步（376+12）")
	_check(String(main.rules.family_by_room[26]) == "plain" and main.rules.family_by_room.size() == 27,
		"场景15ay 二十七段 family 齐全（EXT-22=plain，无工具，缝只放行玩家）")
	# ---- 场景15ba EXT-23 解法（真实按键 23 键：疑路，暗坑献祭填坑） → room_clear 进入 EXT-24（三十房制） ----
	# U,L,L 铁上开关 S(3,4)；R×5 绕行推箱到 (10,4)；D,R 到 (10,5)；U×4 献祭填坑 + 踏填土；L×9 进 G(1,1)
	await _keys([KEY_UP, KEY_LEFT, KEY_LEFT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_UP, KEY_UP])
	await _frames(5)
	await _keys([KEY_UP, KEY_UP, KEY_LEFT, KEY_LEFT])
	await _frames(5)
	await _keys([KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_LEFT])
	await _frames(5)
	await _keys([KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_LEFT])
	await _frames(5)
	await _keys([KEY_LEFT, KEY_LEFT, KEY_LEFT])
	await _frames(10)
	_check(main.rules.room_idx == 28 and main.rules.state == "play" and int(main.rules.steps) == 411,
		"场景15ba EXT-23 解法（真实按键 23 键：铁上开关 + 箱献祭填坑 + 踏填土进 G）：room_clear 进入 EXT-24，全程 411 步（388+23）")
	_check(String(main.rules.family_by_room[27]) == "box_bridge" and main.rules.family_by_room.size() == 28,
		"场景15bb 二十八段 family 齐全（EXT-23=box_bridge，献祭填坑归箱桥族）")
	# ---- 场景15bc EXT-24 解法（真实按键 9 键：相位桥，两窗连过） → room_clear 进入 EXT-25（三十房制） ----
	# 开窗 R×5 过相位桥到 (6,3)；advance_time(2.0) 确定性切反拍（桥合、z 开）；R×4 过 z 进 G(10,3)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	main.rules.advance_time(2.0)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 29 and main.rules.state == "play" and int(main.rules.steps) == 420,
		"场景15bc EXT-24 解法（真实按键 9 键：过桥-等反拍-过门）：room_clear 进入 EXT-25，全程 420 步（411+9）")
	_check(String(main.rules.family_by_room[28]) == "plain" and main.rules.family_by_room.size() == 29,
		"场景15bd 二十九段 family 齐全（EXT-24=plain，无工具，纯节奏）")
	# ---- 场景15be EXT-25 解法（真实按键 9 键：终演三重奏） → final（三十房制） ----
	# 开窗 R×3 过相位桥到中廊 (4,3)；advance_time(2.0) 确定性切冰窗+反相窗；R×6 连过呼吸桥与 z 进 G(10,3)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	main.rules.advance_time(2.0)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 30 and main.rules.state == "play" and int(main.rules.steps) == 429,
		"场景15be EXT-25 解法（真实按键 9 键：相桥-等拍-呼吸桥+反相门连过）：room_clear 进入 EXT-26，全程 429 步（420+9）")
	_check(String(main.rules.family_by_room[29]) == "plain" and main.rules.family_by_room.size() == 30,
		"场景15bf 三十段 family 齐全（EXT-25=plain，无工具，纯节奏终演）")
	# ---- 场景15bg EXT-26 解法（真实按键 12 键：弹射垫，箱弹过河 + F 冻水跟渡） → final（三十一房制） ----
	# R,R 推箱上垫弹到 (6,3)；R 踏垫；F 冻面前水；R,R 过河；R×3 绕推箱上开关；U,R,R,D 绕行进 G
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_F])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 31 and main.rules.state == "play" and int(main.rules.steps) == 440,
		"场景15bg EXT-26 解法（真实按键 12 键：弹射过河-冻水跟渡-绕行上开关）：room_clear 进入 EXT-27，全程 440 步（429+11）")
	_check(String(main.rules.family_by_room[30]) == "freeze_route" and main.rules.family_by_room.size() == 31,
		"场景15bh 三十一段 family 齐全（EXT-26=freeze_route，F 冻水跟渡）")
	# ---- 场景15bi EXT-27 解法（真实按键 15 键：联桥，开关压桥不压门） → room_clear 进入 EXT-28（三十四房制） ----
	# U,U,R,R,D 箱下推压住联动开关 b(3,3)；R,D,R 踏联桥 e(5,3) 过河；R×3 推铁上开关；
	# U,R,R,D 绕行进 G(10,3)
	await _keys([KEY_UP, KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_DOWN])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_UP, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 32 and main.rules.state == "play" and int(main.rules.steps) == 455,
		"场景15bi EXT-27 解法（真实按键 15 键：箱压联桥开关 + 过桥 + 推铁上开关）：room_clear 进入 EXT-28，全程 455 步（440+15）")
	_check(String(main.rules.family_by_room[31]) == "plain" and main.rules.family_by_room.size() == 32,
		"场景15bj 三十二段 family 齐全（EXT-27=plain，无工具，开关压桥不压门）")
	# ---- 场景15bk EXT-28 解法（真实按键 20 键：双联，两箱各压一座开关） → final（三十三房制） ----
	# R,R,R,U,L 箱1 左推上 b1(2,2)；D,R,D,D,L 箱2 左推上 b2(2,4)；R,U,R,R,R 过双桥；
	# U,R 推铁上开关 S(9,2)；D,R,R,R,D 下行进 G(10,4)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_UP, KEY_LEFT])
	await _frames(5)
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_DOWN, KEY_LEFT])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_UP, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_UP, KEY_RIGHT, KEY_DOWN])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 33 and main.rules.state == "play" and int(main.rules.steps) == 475,
		"场景15bk EXT-28 解法（真实按键 20 键：两箱各压一座开关 + 双桥连成一线）：room_clear 进入 EXT-29，全程 475 步（455+20）")
	_check(String(main.rules.family_by_room[32]) == "plain" and main.rules.family_by_room.size() == 33,
		"场景15bl 三十三段 family 齐全（EXT-28=plain，无工具，缺一不可）")
	# ---- 场景15bm EXT-29 解法（真实按键 6 键：油道，箱滑压开关） → room_clear 进入 EXT-30（三十六房制） ----
	# up 接近；right 推箱到油道口；right 箱滑 5 格压开关 S(9,2)、玩家 (3,2)；
	# right 玩家滑油停箱后 (8,2)；down,right 进 G(9,3)
	await _keys([KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_DOWN, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 34 and main.rules.state == "play" and int(main.rules.steps) == 481,
		"场景15bm EXT-29 解法（真实按键 6 键：箱滑压开关 + 玩家跟滑 + 进 G）：room_clear 进入 EXT-30，全程 481 步（475+6）")
	_check(String(main.rules.family_by_room[33]) == "plain" and main.rules.family_by_room.size() == 34,
		"场景15bn 三十四段 family 齐全（EXT-29=plain，无工具，油道只伺候木箱）")
	# ---- 场景15bo EXT-30 解法（真实按键 10 键：联运，油道滑行接力弹射） → final（三十五房制） ----
	# R,R 推箱油道接力弹射落对岸 (8,3)；R 玩家滑油到垫 (6,3)；F 冻河；R 过河；
	# R 推箱上开关 S(9,3)；U,R,R,D 绕行进 G(10,3)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_F])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_UP, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 35 and main.rules.state == "play" and int(main.rules.steps) == 490,
		"场景15bo EXT-30 解法（真实按键 10 键：滑+弹联运投递 + 冻河跟渡 + 推箱上开关）：room_clear 进入 EXT-31，全程 490 步（481+9）")
	_check(String(main.rules.family_by_room[34]) == "freeze_route" and main.rules.family_by_room.size() == 35,
		"场景15bp 三十五段 family 齐全（EXT-30=freeze_route，F 冻河跟渡）")
	# ---- 场景15bq EXT-31 解法（真实按键 8 键：潮汐，2:1 复拍子） → room_clear 进入 EXT-32（三十七房制） ----
	# 露潮 R×4 过滩到 (5,3)；advance_time(2.0) 切反拍（z 开、潮仍露至 4.0）；R×4 过门进 G(9,3)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	main.rules.advance_time(2.0)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 36 and main.rules.state == "play" and int(main.rules.steps) == 498,
		"场景15bq EXT-31 解法（真实按键 8 键：露潮过滩 + 反拍过门）：room_clear 进入 EXT-32，全程 498 步（490+8）")
	_check(String(main.rules.family_by_room[35]) == "plain" and main.rules.family_by_room.size() == 36,
		"场景15br 三十六段 family 齐全（EXT-31=plain，无工具，2:1 复拍子）")
	# ---- 场景15bs EXT-32 解法（真实按键 8 键：联运潮滩，潮滩+滑弹联运） → final（三十七房制） ----
	# R 露潮过滩 (2,2)；R,R 推箱油道接力弹射落 (8,2)=S；R 玩家滑油到垫 (6,2)；F 冻河；
	# R 踏冰；D,R 下行进 G(9,3)（绕开箱占的开关）
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_F])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 37 and main.rules.state == "play" and int(main.rules.steps) == 505,
		"场景15bs EXT-32 解法（真实按键 8 键：潮滩 + 接力投递 + 冻河跟渡 + 下行进 G）：room_clear 进入 EXT-33，全程 505 步（498+7）")
	_check(String(main.rules.family_by_room[36]) == "freeze_route" and main.rules.family_by_room.size() == 37,
		"场景15bt 三十七段 family 齐全（EXT-32=freeze_route，F 冻河跟渡）")
	# ---- 场景15bu EXT-33 解法（真实按键 11 键：换乘，错相双滩换乘窗） → final（六十四房制） ----
	# advance_time(2.2) 切换乘窗 [2,4)（u 露 + j 露）；R×7 跨双滩 + 推铁上开关 S(9,2)；
	# U,R,R,D 北上绕行进 G(10,2)
	# 主循环每帧 advance_time(delta)：先按既有相位精确落换乘窗 [2,4)（u+j 双露），再发全部 11 键
	# （与逻辑套件同序：R×7 跨双滩推铁上开关 S(9,2)；U,R,R,D 北上绕行进 G(10,2)）
	main.rules.advance_time(2.2 - float(main.rules.phase_clock))
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_UP])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 38 and main.rules.state == "play" and int(main.rules.steps) == 516,
		"场景15bu EXT-33 解法（真实按键 11 键：换乘窗跨双滩 + 推铁上开关 + 北上绕行进 G）：room_clear 进入 EXT-34（六十四房制：final 移至 EXT-34 通关），全程 516 步（505+11）")
	_check(String(main.rules.family_by_room[37]) == "plain" and main.rules.family_by_room.size() == 38,
		"场景15bv 三十八段 family 齐全（EXT-33=plain，无工具，错相双滩换乘窗）")
	# ---- 场景15bw EXT-34 解法（真实按键 11 键：推凿，推箱凿塌假墙 + 箱压开关） → final（六十四房制） ----
	# R×7 推箱凿塌桩 (7,2) 并续推上开关 S(9,2)；U,R,R,D 北上绕行进 G(10,2)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 39 and main.rules.state == "play" and int(main.rules.steps) == 527,
		"场景15bw EXT-34 解法（真实按键 11 键：推箱凿桩 + 箱压开关 + 北上绕行进 G）：room_clear 进入 EXT-35（六十四房制：final 移至 EXT-35 通关），全程 527 步（516+11）")
	_check(String(main.rules.family_by_room[38]) == "plain" and main.rules.family_by_room.size() == 39,
		"场景15bx 三十九段 family 齐全（EXT-34=plain，无工具，推塌桩只认推力）")
	# ---- 场景15by EXT-35 解法（真实按键 12 键：暖轨，下行压开关 + 避轨东行） → final（六十四房制） ----
	# U,R,R 绕箱北；D,D 下行压 S(3,4)（门导通）；R×6 沿第 3 行避轨；D 进 G(9,4)
	# （G 不在轨上——车永不挡终局入格，真时漂移只动轨上车、不扰步数确定性）
	await _keys([KEY_UP, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_DOWN, KEY_DOWN])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 40 and main.rules.state == "play" and int(main.rules.steps) == 539,
		"场景15by EXT-35 解法（真实按键 12 键：下行压开关 + 避轨东行 + 进 G）：room_clear 进入 EXT-36（六十四房制：final 移至 EXT-36 通关），全程 539 步（527+12）")
	_check(String(main.rules.family_by_room[39]) == "plain" and main.rules.family_by_room.size() == 40,
		"场景15bz 四十段 family 齐全（EXT-35=plain，无工具，暖轨车压板导通（EXT-55））")
	# ---- 场景15ca EXT-36 解法（真实按键 10 键：钥匣，沉箱造桥 + 冻河 + 拾钥 + 开锁门） → final（六十四房制） ----
	# R×4 推箱沉 (6,2) 造桥；R 上桥；F 冻 (7,2)；R,R,R,R 踏冰踩钥 (9,2) 并进锁门 E(10,2)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_F])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 41 and main.rules.state == "play" and int(main.rules.steps) == 548,
		"场景15ca EXT-36 解法（真实按键 10 键：沉箱造桥 + 冻河 + 拾钥 + 开锁门）：room_clear 进入 EXT-37（六十四房制：final 移至 EXT-37 通关），全程 548 步（539+9）")
	_check(String(main.rules.family_by_room[40]) == "box_bridge" and main.rules.family_by_room.size() == 41,
		"场景15cb 四十一段 family 齐全（EXT-36=box_bridge，F 冻河+沉箱桥）")
	# ---- 场景15cc EXT-37 解法（真实按键 15 键：藤垣，推箱压开关 + 攀越 + 踏自锁板进 G） → final（六十四房制） ----
	# U,U 绕箱北；R,R 推箱上 S(4,1)；D,R,R,R,R 攀越藤垣 (6,2)；U,R,R 踩 L(9,1)；D,D,R 进 G(10,3)
	await _keys([KEY_UP, KEY_UP, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_UP, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_DOWN, KEY_DOWN, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 42 and main.rules.state == "play" and int(main.rules.steps) == 563,
		"场景15cc EXT-37 解法（真实按键 15 键：推箱压开关 + 攀越藤垣 + 踏自锁板 + 进 G）：room_clear 进入 EXT-38（六十四房制：final 移至 EXT-38 通关），全程 563 步（548+15）")
	_check(String(main.rules.family_by_room[41]) == "plain" and main.rules.family_by_room.size() == 42,
		"场景15cd 四十二段 family 齐全（EXT-37=plain，无工具，藤垣人货分流）")
	# ---- 场景15ce EXT-38 解法（真实按键 10 键：晶屑，推晶入坑碎水 + 冻冰过壕） → final（六十四房制） ----
	# R,R,R,R 走到晶西邻；第 4 推晶入坑 (6,2) 碎水；F 冻冰；R,R,R,R,R 踏冰进 G(10,2)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_F])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 43 and main.rules.state == "play" and int(main.rules.steps) == 572,
		"场景15ce EXT-38 解法（真实按键 10 键：推晶入坑碎水 + 冻冰过壕 + 进 G）：room_clear 进入 EXT-39（六十四房制：final 移至 EXT-39 通关），全程 572 步（563+9）")
	_check(String(main.rules.family_by_room[42]) == "freeze_route" and main.rules.family_by_room.size() == 43,
		"场景15cf 四十三段 family 齐全（EXT-38=freeze_route，F 冻晶水成桥）")
	# ---- 场景15cg EXT-39 解法（真实按键 9 键：换相井，双井零等待过双滩） → final（六十四房制） ----
	# R 井(2,2) t0→4 j 开；R,R 踏 j(4,2)；R 井(6,2) t4→8 u 开 j 闭沿结算；R 踏 u(8,2)；R,R,R 进 G
	# （真时时钟下井锚定相位：漂移只微移窗内位置，不扰步数确定性）
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 44 and main.rules.state == "play" and int(main.rules.steps) == 581,
		"场景15cg EXT-39 解法（真实按键 9 键：双井零等待过双滩 + 进 G）：room_clear 进入 EXT-40（六十四房制：final 移至 EXT-40 通关），全程 581 步（572+9）")
	_check(String(main.rules.family_by_room[43]) == "plain" and main.rules.family_by_room.size() == 44,
		"场景15ch 四十四段 family 齐全（EXT-39=plain，无工具，换相井零等待）")
	# ---- 场景15ci EXT-40 解法（真实按键 8 键：输送，推箱上带 + 搭车 + 南绕进 G） → final（六十四房制） ----
	# R×4 上货上带并踏上带首；advance(4.5) 等带（箱三拍上 S 门导通、人三拍跟车落后一格）；
	# D,R,R,U 南绕进 G(10,2)（真时时钟漂移不扰：箱上 S 即停、人被箱挡在 (8,2)）
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	main.rules.advance_time(4.5)
	await _frames(5)
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_UP])
	await _frames(10)
	_check(main.rules.room_idx == 45 and main.rules.state == "play" and int(main.rules.steps) == 589,
		"场景15ci EXT-40 解法（真实按键 8 键：推箱上带 + 搭车 + 南绕进 G）：room_clear 进入 EXT-41（六十四房制：final 移至 EXT-41 通关），全程 589 步（581+8）")
	_check(String(main.rules.family_by_room[44]) == "plain" and main.rules.family_by_room.size() == 45,
		"场景15cj 四十五段 family 齐全（EXT-40=plain，无工具，带运不计序列）")
	# ---- 场景15ck EXT-41 解法（真实按键 9 键：经纬，上货上带 + 拐向 + 东行进 G） → final（六十四房制） ----
	# R×3 上货上带并踩带首；advance(4.5) 等带（箱三拍拐向抵 S(5,5) 门导通、人两拍跟车被挡停）；
	# U,R×5 沿第 3 行东行进 G(10,3)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	main.rules.advance_time(4.5)
	await _frames(5)
	await _keys([KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 46 and main.rules.state == "play" and int(main.rules.steps) == 598,
		"场景15ck EXT-41 解法（真实按键 9 键：上货上带 + 拐向 + 东行进 G）：room_clear 进入 EXT-42（六十四房制：final 移至 EXT-42 通关），全程 598 步（589+9）")
	_check(String(main.rules.family_by_room[45]) == "plain" and main.rules.family_by_room.size() == 46,
		"场景15cl 四十六段 family 齐全（EXT-41=plain，无工具，带运不计序列）")
	# ---- 场景15cm EXT-42 解法（真实按键 13 键：双钥，拾银钥穿银门拾金钥进金锁） → final（六十四房制） ----
	# U,R,R 踩银钥 (3,1)；R×5 穿银门 (7,1) 东行；D 下 (8,2)；R,R 踩金钥 (10,2)；D,D 进金锁 E(10,4)
	await _keys([KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	await _keys([KEY_DOWN, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 47 and main.rules.state == "play" and int(main.rules.steps) == 611,
		"场景15cm EXT-42 解法（真实按键 13 键：拾银钥穿银门拾金钥进金锁）：room_clear 进入 EXT-43（六十四房制：final 移至 EXT-43 通关），全程 611 步（598+13）")
	_check(String(main.rules.family_by_room[46]) == "plain" and main.rules.family_by_room.size() == 47,
		"场景15cn 四十七段 family 齐全（EXT-42=plain，无工具，双钥嵌套）")
	# ---- 场景15co EXT-43 解法（真实按键 10 键：候潮，推箱上带 + 候潮过闸 + 南绕进 G） → final（六十四房制） ----
	# R×4 上货上带并踩带尾（箱闸前排队）；advance(4.5) 开闸箱过闸人跟至 (6,2)；R 推箱上东带、
	# 人踏闸格；advance(1.5) 箱一拍上 S；D,R,R,R,U 南绕进 G(10,2)（真时时钟漂移不扰：开窗 4 秒宽）
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	main.rules.advance_time(4.5)
	await _frames(5)
	await _keys([KEY_RIGHT])
	await _frames(5)
	main.rules.advance_time(1.5)
	await _frames(5)
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_UP])
	await _frames(10)
	_check(main.rules.room_idx == 48 and main.rules.state == "play" and int(main.rules.steps) == 621,
		"场景15co EXT-43 解法（真实按键 10 键：推箱上带 + 候潮过闸 + 南绕进 G）：room_clear 进入 EXT-44（六十四房制：final 移至 EXT-44 通关），全程 621 步（611+10）")
	_check(String(main.rules.family_by_room[47]) == "plain" and main.rules.family_by_room.size() == 48,
		"场景15cp 四十八段 family 齐全（EXT-43=plain，无工具，带运不计序列）")
	# ---- 场景15cq EXT-44 解法（真实按键 7 键：晶运，推晶上带 + 随带运 + 冻冰过壕） → room_clear 进入 EXT-45（六十四房制：final 移至 EXT-45 通关） ----
	# R×3 推晶上带并踩带首；晶随真时节拍行驶，advance(2.5) 让晶出带碎水 (7,2)、人随带至 (6,2)；
	# F 冻 (7,2)；R×4 踏冰进 G(10,2)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	main.rules.advance_time(2.5)
	await _frames(5)
	await _keys([KEY_F, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 49 and main.rules.state == "play" and int(main.rules.steps) == 628,
		"场景15cq EXT-44 解法（真实按键 7 键：推晶上带 + 随带运 + 冻冰过壕）：state=final，全程 628 步（621+7）")
	_check(String(main.rules.family_by_room[48]) == "freeze_route" and main.rules.family_by_room.size() == 49,
		"场景15cr 四十九段 family 齐全（EXT-44=freeze_route，F 冻晶水成桥）")
	# ---- 场景15cs EXT-45 解法（真实按键 11 键：潮渡，推箱上带 + 候潮联运 + 南绕进 G） → room_clear 进入 EXT-46（六十四房制） ----
	# R×2 推箱上带 (4,2)（人站带外不随行）；advance(5.5) 箱候潮渡滩上 S(9,2) 门导通；
	# D,R×7,U 人走第 3 行南绕进 G(10,2)
	await _keys([KEY_RIGHT, KEY_RIGHT])
	await _frames(5)
	main.rules.advance_time(5.5)
	await _frames(5)
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_UP])
	await _frames(10)
	_check(main.rules.room_idx == 50 and main.rules.state == "play" and int(main.rules.steps) == 639,
		"场景15cs EXT-45 解法（真实按键 11 键：推箱上带 + 候潮联运 + 南绕进 G）：room_clear 自动进入 EXT-46（六十四房制：final 移至 EXT-46 通关），全程 639 步（628+11）")
	_check(String(main.rules.family_by_room[49]) == "plain" and main.rules.family_by_room.size() == 50,
		"场景15ct 五十段 family 齐全（EXT-45=plain，无工具，带运不计序列）")
	# ---- 场景15cu EXT-46 解法（真实按键 43 键：焚藤，攀藤借朝向烧两洞 + 双货双压开门） → room_clear 进入 EXT-47（六十四房制） ----
	# D,R,R,D,R,R,U,G烧(5,2),U,U,D,G烧(5,3)；绕回推箱过洞上 S(8,2)；绕回推铁过洞上 W(8,3)；进 G(10,2)
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_UP, KEY_G,
		KEY_UP, KEY_UP, KEY_DOWN, KEY_G,
		KEY_UP, KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_LEFT, KEY_DOWN, KEY_RIGHT,
		KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_DOWN, KEY_LEFT, KEY_LEFT, KEY_DOWN, KEY_LEFT, KEY_LEFT, KEY_UP, KEY_LEFT, KEY_RIGHT,
		KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_UP, KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_DOWN, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 51 and main.rules.state == "play" and int(main.rules.steps) == 680,
		"场景15cu EXT-46 解法（真实按键 43 键：焚藤，攀藤借朝向烧两洞 + 双货双压开门）：room_clear 自动进入 EXT-47（六十四房制：final 移至 EXT-47 通关），全程 680 步（639+41）")
	_check(String(main.rules.family_by_room[50]) == "plain" and main.rules.family_by_room.size() == 51,
		"场景15cv 五十一段 family 齐全（EXT-46=plain，烧藤不进分类器——差异5 基线冻结）")
	# ---- 场景15cw EXT-47 解法（真实按键 32 键：引晶，磁拉晶出龛 + 推坑冻桥） → final（六十四房制） ----
	# D,R×5,H拉晶出龛；[L,L,R,H]×3 链拉至 (4,3)；D,R,UP 推晶入坑化水；F 冻冰；踏冰过坑进 G
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_H,
		KEY_LEFT, KEY_LEFT, KEY_RIGHT, KEY_H,
		KEY_LEFT, KEY_LEFT, KEY_RIGHT, KEY_H,
		KEY_LEFT, KEY_LEFT, KEY_RIGHT, KEY_H,
		KEY_DOWN, KEY_RIGHT, KEY_UP, KEY_F,
		KEY_UP, KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 52 and main.rules.state == "play" and int(main.rules.steps) == 707,
		"场景15cw EXT-47 解法（真实按键 32 键：引晶，磁拉晶出龛 + 推坑冻桥）：room_clear 自动进入 EXT-48（六十四房制：final 移至 EXT-48 通关），全程 707 步（680+27）")
	_check(String(main.rules.family_by_room[51]) == "magnet_iron" and main.rules.family_by_room.size() == 52,
		"场景15cx 五十二段 family 齐全（EXT-47=magnet_iron，拉晶与拉铁同串——差异5 冻结沿用）")
	# ---- 场景15cy EXT-48 解法（真实按键 17 键：潮轨，冻道困车 + 踩井沉车 + 翻回过潮） → final（六十四房制） ----
	# R×3,F冻(5,2),R,F冻(6,2),R,F冻(7,2),R；advance 等车开窗入潮格被困；D,L踩井沉车；
	# U,D,U 翻回开窗；R,R,R,R 踏潮格进 G
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_F, KEY_RIGHT, KEY_F, KEY_RIGHT, KEY_F, KEY_RIGHT])
	await _frames(10)
	main.rules.advance_time(2.0)
	await _frames(10)
	await _keys([KEY_DOWN, KEY_LEFT, KEY_UP, KEY_DOWN, KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 53 and main.rules.state == "play" and int(main.rules.steps) == 722,
		"场景15cy EXT-48 解法（真实按键 17 键：潮轨，冻道困车 + 踩井沉车 + 翻回过潮）：room_clear 自动进入 EXT-49（六十四房制：final 移至 EXT-49 通关），全程 722 步（707+15）")
	_check(String(main.rules.family_by_room[52]) == "freeze_route" and main.rules.family_by_room.size() == 53,
		"场景15cz 五十三段 family 齐全（EXT-48=freeze_route，F 冻桥入分类）")
	# ---- 场景15da EXT-49 解法（真实按键 22 键：送货门，两箱接力投递） → final（六十四房制） ----
	# 绕行推近箱 B2 入 X 传岛；绕回推远箱 B1 入门——对格被占退最近位=开关板压开门；进 G
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_LEFT, KEY_LEFT, KEY_DOWN, KEY_LEFT, KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_UP, KEY_LEFT, KEY_LEFT, KEY_LEFT])
	await _frames(10)
	_check(main.rules.room_idx == 54 and main.rules.state == "play" and int(main.rules.steps) == 744,
		"场景15da EXT-49 解法（真实按键 22 键：送货门，两箱接力投递）：room_clear 自动进入 EXT-50（六十四房制：final 移至 EXT-50 通关），全程 744 步（722+22）")
	_check(String(main.rules.family_by_room[53]) == "plain" and main.rules.family_by_room.size() == 54,
		"场景15db 五十四段 family 齐全（EXT-49=plain，push:box:portal 不进分类器——差异5 冻结）")
	# ---- 场景15dc EXT-50 解法（真实按键 9 键：双踩，箱上板计 1 + 人滑入计 2 锁定） → final（六十四房制） ----
	# R×3 面东推箱上板计 1；R 推箱离板人滑入板面计 2 锁定；D,R,R,U row3 绕到 G
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_UP])
	await _frames(10)
	_check(main.rules.room_idx == 55 and main.rules.state == "play" and int(main.rules.steps) == 753,
		"场景15dc EXT-50 解法（真实按键 9 键：双踩，箱上板计 1 + 人滑入计 2 锁定 + row3 绕行）：room_clear 自动进入 EXT-51（六十四房制：final 移至 EXT-51 通关），全程 753 步（744+9）")
	_check(String(main.rules.family_by_room[54]) == "plain" and main.rules.family_by_room.size() == 55,
		"场景15dd 五十五段 family 齐全（EXT-50=plain，'s' 启用后占用表小写全满）")
	# ---- 场景15de EXT-51 解法（真实按键 21 键：潮磨，引晶上潮格磨水 + 冻桥过河 + 推箱上 S） → final（六十四房制） ----
	# R 推晶上潮格（开窗推入）；advance 越闭合沿潮磨成水；F 冻冰踏河；row3 推箱上 S 压开门；进 G
	await _keys([KEY_RIGHT])
	await _frames(10)
	main.rules.advance_time(5.0)
	await _frames(10)
	await _keys([KEY_F, KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_DOWN,
		KEY_LEFT, KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_DOWN, KEY_RIGHT, KEY_UP, KEY_RIGHT, KEY_UP, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 56 and main.rules.state == "play" and int(main.rules.steps) == 773,
		"场景15de EXT-51 解法（真实按键 21 键：潮磨，引晶上潮格磨水 + 冻桥过河 + 推箱上 S 压开门）：room_clear 自动进入 EXT-52（六十四房制：final 移至 EXT-54 通关），全程 773 步（753+20）")
	_check(String(main.rules.family_by_room[55]) == "freeze_route" and main.rules.family_by_room.size() == 56,
		"场景15df 五十六段 family 齐全（EXT-51=freeze_route，F 冻桥入分类）")
	# ---- 场景15dg EXT-52 解法（真实按键 9 键：连碎，推 A 入坑连锁 B 同碎 + F×2 冻双水） → 进 EXT-53（六十四房制） ----
	# R×3 走位面东；R 推 A 入坑连锁 B 同碎双坑化水；F,R,F,R 踏双冰；R,R,R 进 G
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_F, KEY_RIGHT, KEY_F, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 57 and main.rules.state == "play" and int(main.rules.steps) == 780,
		"场景15dg EXT-52 解法（真实按键 9 键：连碎，推 A 入坑连锁 B 同碎 + F×2 冻双水 + 踏冰进 G）：room_clear 自动进入 EXT-53（六十四房制：final 移至 EXT-54 通关），全程 780 步（773+7）")
	_check(String(main.rules.family_by_room[56]) == "freeze_route" and main.rules.family_by_room.size() == 57,
		"场景15dh 五十七段 family 齐全（EXT-52=freeze_route，F 冻桥入分类）")
	# ---- 场景15di EXT-53 解法（真实按键 9 键：弹晶，推晶上垫沿向弹 2 格落坑化水 + F 冻冰过河进 G） → 进 EXT-54（六十四房制） ----
	# R 走位；R 推晶上垫→弹 2 格落坑化水（人进晶原格）；R 上垫 R 绕行；F 冻弹射水；R×4 踏冰进 G
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_F, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 58 and main.rules.state == "play" and int(main.rules.steps) == 788,
		"场景15di EXT-53 解法（真实按键 9 键：弹晶，推晶上垫弹 2 格落坑化水 + F 冻冰过河进 G）：room_clear 自动进入 EXT-54（六十四房制：final 移至 EXT-54 通关），全程 788 步（780+8）")
	_check(String(main.rules.family_by_room[57]) == "freeze_route" and main.rules.family_by_room.size() == 58,
		"场景15dj 五十八段 family 齐全（EXT-53=freeze_route，F 冻桥入分类）")
	# ---- 场景15dk EXT-54 解法（真实按键 7 键：滑晶，推晶上滑道出道入坑化水 + F 冻冰过河进 G） → 进 EXT-55（六十四房制） ----
	# R 走位；R 推晶上滑道→滑到头出道入坑化水（人进晶原格）；R 玩家踏冰道滑至 (7,2)；F 冻坑水；R×3 踏冰进 G
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_F, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 59 and main.rules.state == "play" and int(main.rules.steps) == 794,
		"场景15dk EXT-54 解法（真实按键 7 键：滑晶，推晶上滑道出道入坑化水 + F 冻冰过河进 G）：room_clear 自动进入 EXT-55（六十四房制：final 移至 EXT-58 通关），全程 794 步（788+6）")
	_check(String(main.rules.family_by_room[58]) == "freeze_route" and main.rules.family_by_room.size() == 59,
		"场景15dl 五十九段 family 齐全（EXT-54=freeze_route，F 冻桥入分类）")
	# ---- 场景15dm EXT-55 解法（真实按键 10 键：车碾板，等 14 拍车碾双踩板咬合 + 挡轨折返 + 走位进 G） → final（六十四房制） ----
	# 玩家站 (1,2) 即车折返点：真实时间等待 15 秒（勘误：headless 帧速≈145fps 不定，
	# 帧等待换算不出游戏秒——create_timer 走真实秒、main._process 以真实 delta 推进车拍：
	# 车东行撞墙折返西行碾 s→撞玩家折返东行再碾 s→第 14 拍咬合 @14.0s）后 D 离轨 R×8 沿第 3 行 D 进 G
	await create_timer(15.0).timeout
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 60 and main.rules.state == "play" and int(main.rules.steps) == 804,
		"场景15dm EXT-55 解法（真实按键 10 键：车碾板，等 14 拍车碾双踩板咬合 + 挡轨折返 + 走位进 G）：room_clear 自动进入 EXT-56（六十四房制：final 移至 EXT-58 通关），全程 804 步（794+10，等拍不计步）")
	_check(String(main.rules.family_by_room[59]) == "plain" and main.rules.family_by_room.size() == 60,
		"场景15dn 六十段 family 齐全（EXT-55=plain，无工具纯走位+环境 Actor）")
	# ---- 场景15do EXT-56 解法（真实按键 10 键：车越堑，等 23 拍巡轨车两越断口碾双踩板咬合 + 走位进 G） → final（六十四房制） ----
	# 玩家站 (1,2) 即车折返点：真实时间等待 24 秒（第 22 拍二次弹落双踩板咬合）后 D 离轨 R×8 沿第 3 行 D 进 G
	await create_timer(24.0).timeout
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_DOWN])
	await _frames(10)
	_check(main.rules.room_idx == 61 and main.rules.state == "play" and int(main.rules.steps) == 814,
		"场景15do EXT-56 解法（真实按键 10 键：车越堑，等 23 拍巡轨车两越断口碾双踩板咬合 + 走位进 G）：room_clear 自动进入 EXT-57（六十四房制：final 移至 EXT-58 通关），全程 814 步（804+10，等拍不计步）")
	_check(String(main.rules.family_by_room[60]) == "plain" and main.rules.family_by_room.size() == 61,
		"场景15dp 六十一段 family 齐全（EXT-56=plain，无工具纯走位+环境 Actor）")
	# ---- 场景15dq EXT-57 解法（真实按键 11 键：晶潮渡，晶上带摆渡入潮磨水 + F 冻桥 + 搭带过河进 G） → 进 EXT-58（六十四房制） ----
	# R,R,R 推晶上带+玩家上带（t≈0）；真实时间 5.5 秒（带拍 1-2 摆渡晶落驻潮格、t=4 闭窗潮磨）；
	# F 冻 (6,2)；再 2.5 秒（带拍运玩家上冰）；R×4 进 G(10,2)
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await create_timer(5.5).timeout
	await _keys([KEY_F])
	await create_timer(2.5).timeout
	await _keys([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _frames(10)
	_check(main.rules.room_idx == 62 and main.rules.state == "play" and int(main.rules.steps) == 821,
		"场景15dq EXT-57 解法（真实按键 11 键：晶潮渡，晶上带摆渡入潮磨水 + F 冻桥 + 搭带过河进 G）：room_clear 自动进入 EXT-58（六十四房制：final 移至 EXT-58 通关），全程 821 步（814+7，等拍不计步）")
	_check(String(main.rules.family_by_room[61]) == "freeze_route" and main.rules.family_by_room.size() == 62,
		"场景15dr 六十二段 family 齐全（EXT-57=freeze_route，F 冻桥入分类）")
	# ---- 场景15ds EXT-58 解法（真实按键 7 键：桥渡，铁上带摆渡过桥压重压板 + 玩家绕东进 G） → final（六十四房制） ----
	# R,R 推铁上带+玩家跟进上带（t≈0，桥 t=0 闭窗）；t=3.5 玩家 D 下带让位（铁独占带线：
	# 候窗→上桥续行→(9,2)=W 门开 @t=8）→ 玩家 R,R,R 绕行 (10,3) → 门开后 U 进 G(10,2)
	await _keys([KEY_RIGHT, KEY_RIGHT])
	await create_timer(3.5).timeout
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await create_timer(4.0).timeout
	await _keys([KEY_UP])
	await _frames(10)
	_check(main.rules.room_idx == 63 and main.rules.state == "play" and int(main.rules.steps) == 828,
		"场景15ds EXT-58 解法（真实按键 7 键：桥渡，铁上带摆渡过桥压重压板 + 玩家绕东进 G）：room_clear 自动进入 EXT-59（六十四房制：final 移至 EXT-59 通关），全程 828 步（821+7，等拍不计步）")
	# ---- 场景15du EXT-59 解法（真实按键 11 键：候闸，车候潮过闸压重压板门开 + 玩家 row3 直走绕行进 G） → final ----
	# D,R×9 沿 row3 直走（不挡车）；等 5 拍：车候闸→过闸→(8,2)=W 门开；U 进 G(10,2)
	await _keys([KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT,
		KEY_RIGHT, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await create_timer(5.5).timeout
	await _keys([KEY_UP])
	await _frames(10)
	_check(main.rules.state == "final" and int(main.rules.steps) == 839,
		"场景15du EXT-59 解法（真实按键 11 键：候闸，车候潮过闸压重压板门开 + 玩家 row3 绕行进 G）：state=final，全程 839 步（828+11，等拍不计步，六十四房制终点）")
	_check(main._btn_cont.visible and main._final_panel.visible and main.final_label.visible,
		"场景15i 结算白底面板与双语义重开按钮出现（EXT-59 通关后）")

	print("==== 汇总：%d PASS / %d FAIL ====" % [passes, fails])
	quit(1 if fails > 0 else 0)
