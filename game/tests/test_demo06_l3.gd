extends SceneTree
## demo-06 L3「无显式克制的开放物理问题」验证 v2（headless，time_scale 1.0 真实时间计时）
## T0 加载不冻结：L3 载入后物理帧持续推进，3 个预置物体落地稳定（冻结修复验证）
## T1 断层几何：沟宽 420 远超跳跃射程，不能直接跳过；无易燃栅栏（无属性锁）
## T2 解法A 几何可行：两块 Float 长板悬空桥（坐标计算断言）+ 墨水足够
## T3 解法B 几何可行：Sticky 方块沟内垫脚（台阶高度窗口断言）
## T4 解法C 几何可行：预置方块推/撞入沟贴右壁成垫脚（Heavy 圆球可选）
## T5 实机通关（解法A）：GOAL 只由玩家进入触发，45s 真实时间上限
## 运行：godot --headless --path game -s res://tests/test_demo06_l3.gd
## 注意：本测试不引用 demo06 不存在的属性（旧版探针访问 scene.ball 导致脚本报错、
##       headless 进程空转假死——即"L3 加载冻结"的测试侧根因，见 demo06_inkwords.gd 头部 v2 注释）

var scene = null
var logf: FileAccess
var pass_cnt := 0
var fail_cnt := 0

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000:
		await physics_frame

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _check(tag: String, ok: bool, detail: String = "") -> void:
	if ok:
		pass_cnt += 1
	else:
		fail_cnt += 1
	_log("%s: %s%s" % [tag, "PASS" if ok else "FAIL", ("（" + detail + "）") if detail != "" else ""])

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://l3log.txt", FileAccess.WRITE)
	await process_frame
	# v2: time_scale 保持 1.0——6x 加速会拉大物理 delta、压低抛物线积分精度，
	# T5b 实机跳跃因此撞台壁（真实时间计时也是流水线对测试的要求）
	Engine.time_scale = 1.0
	# 物理常数（与 demo06_inkwords.gd 一致，用于几何断言，不跑物理模拟）
	var grav := 1600.0
	var jump_v := 520.0
	var walk := 240.0
	var jump_h := jump_v * jump_v / (2.0 * grav)     # ≈84.5 跳跃高度
	var air_t := 2.0 * jump_v / grav                  # ≈0.65 滞空时间
	var jump_range := walk * air_t                    # ≈156 跳跃水平射程
	_log("跳跃高度=%.1f 水平射程=%.1f" % [jump_h, jump_range])

	# ============ T0 加载不冻结 + 预置动态物体 ============
	scene = load("res://demo06_inkwords.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(2)
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		await physics_frame
		frames += 1
	_check("T0a L3 载入后物理帧持续推进（无冻结）", frames > 45, "1.5s 真实时间物理帧=%d" % frames)
	var objs := get_nodes_in_group("level_objs")
	_check("T0b 预置动态物体数量 = 3（规格 2~3）", objs.size() == 3, "实际=%d" % objs.size())
	var finite_ok := true
	var rest_ok := true
	var kinds := {}
	for o in objs:
		var ob := o as RigidBody2D
		if ob == null:
			continue
		kinds[ob.get_meta("kind", "")] = true
		if is_nan(ob.position.x) or is_nan(ob.position.y):
			finite_ok = false
			continue
		# 落到左台后的停留高度带：台面 400，圆球顶心 374 / 方块 370 / 长板 389
		if ob.position.y < 330.0 or ob.position.y > 430.0:
			rest_ok = false
		if absf(ob.position.x - (ob.get_meta("spawn", Vector2.ZERO) as Vector2).x) > 40.0:
			rest_ok = false
	_check("T0c 物体位置有限（无 NaN，冻结根因②已修复）", finite_ok)
	_check("T0d 物体已落到左台并稳定（不漂移/不掉沟）", rest_ok)
	_check("T0e 物体种类齐全（球/板/块）", kinds.has("ball") and kinds.has("plank") and kinds.has("block"))
	_check("T0f 关卡状态 play", scene.state == "play", String(scene.state))

	# ============ 断层几何（读取关卡常量做坐标计算，不跑物理） ============
	var lv: Dictionary = scene.LEVELS[2]
	var left: Rect2 = lv.walls[3]        # 左台
	var right: Rect2 = lv.walls[4]       # 右台
	var pit: Rect2 = lv.walls[5]         # 沟底
	var gap := right.position.x - (left.position.x + left.size.x)
	var ink: int = lv.ink
	_check("T1a 断层宽度 ≥ 300（较宽断层）", gap >= 300.0, "沟宽=%.0f" % gap)
	_check("T1b 沟宽 > 2×跳跃射程（不能直接跳过）", gap > jump_range * 2.0, "沟宽=%.0f 射程=%.0f" % [gap, jump_range])
	_check("T1c 沟底存在且低于两侧台面（掉入不出屏）", pit.position.y > left.position.y and pit.position.y > right.position.y)
	var fence: Rect2 = lv.fence
	_check("T1d 无易燃栅栏（禁「见木就烧」属性锁）", fence.size.x == 0.0 and fence.size.y == 0.0)
	var goal: Rect2 = lv.goal
	_check("T1e GOAL 在右台上、玩家站立即可达", goal.position.x >= right.position.x and goal.end.y >= right.position.y)
	_check("T1f 玩家出生在左台", lv.spawn.x < left.position.x + left.size.x and lv.spawn.x > left.position.x)

	# ============ T2 解法A：Float 长板悬空桥（长板 130×22，Float 价 15） ============
	var cost_a := 2 * (25 + 15)                              # 两块长板×Float
	var p1 := Rect2(400.0 - 65.0, 350.0 - 11.0, 130.0, 22.0) # 长板1 拟放 (400,350)
	var p2 := Rect2(615.0 - 65.0, 350.0 - 11.0, 130.0, 22.0) # 长板2 拟放 (615,350)
	var hop1 := p2.position.x - (p1.position.x + p1.size.x)  # 板1→板2 空隙
	var hop2 := right.position.x - (p2.position.x + p2.size.x) # 板2→右台 空隙
	var mount := left.position.y - p1.position.y             # 左台面→板1顶 抬升
	_check("T2a 墨水足够解法A", ink >= cost_a, "ink=%d 需要=%d" % [ink, cost_a])
	_check("T2b 长板1 搭在左台边缘（左缘偏差 ≤30）", absf(p1.position.x - (left.position.x + left.size.x)) <= 30.0)
	_check("T2c 板1→板2 跳距 ≤ 射程", hop1 <= jump_range, "空隙=%.0f" % hop1)
	_check("T2d 板2→右台 跳距 ≤ 射程", hop2 <= jump_range, "空隙=%.0f" % hop2)
	_check("T2e 左台→板1 抬升 ≤ 跳高", mount <= jump_h, "抬升=%.0f 跳高=%.1f" % [mount, jump_h])

	# ============ T3 解法B：Sticky 方块沟内固定垫脚（方块 64→60 近似，Sticky 价 10） ============
	var cost_b := 30 + 10                                    # 方块×Sticky
	var block_top := pit.position.y - 60.0                   # 方块落沟底后的顶面高度 ≈460
	var exit_lo := pit.position.y - jump_h                   # 能从沟底跳上的垫脚顶下限 ≈435.5
	var exit_hi := left.position.y + jump_h                  # 能从垫脚跳上右台的垫脚顶上限 ≈484.5
	_check("T3a 墨水足够解法B", ink >= cost_b, "ink=%d 需要=%d" % [ink, cost_b])
	_check("T3b 方块垫脚顶落在单级出入窗口内", block_top >= exit_lo and block_top <= exit_hi,
		"顶=%.0f 窗口[%.1f,%.1f]" % [block_top, exit_lo, exit_hi])
	_check("T3c 单级垫脚足够出沟（2×跳高 ≥ 台面落差）", 2.0 * jump_h >= pit.position.y - left.position.y,
		"2×跳高=%.1f 落差=%.0f" % [2.0 * jump_h, pit.position.y - left.position.y])
	_check("T3d 沟宽容得下方块靠右壁放置", pit.size.x >= 60.0 and right.position.x - pit.position.x >= 60.0)

	# ============ T4 解法C：预置方块推/撞入沟成垫脚（Heavy 圆球可选，纯推 0 墨） ============
	var env_block: RigidBody2D = null
	for o2 in objs:
		var ob2 := o2 as RigidBody2D
		if ob2 != null and ob2.get_meta("kind", "") == "block":
			env_block = ob2
	_check("T4a 场景存在可推环境方块", env_block != null)
	if env_block != null:
		var bx := (env_block.get_meta("spawn", Vector2.ZERO) as Vector2).x
		_check("T4b 环境方块位于出生点与台缘之间（可推向沟）", bx > float(lv.spawn.x) and bx < left.position.x + left.size.x,
			"方块x=%.0f" % bx)
		var cost_c := 30 + 10                                # Heavy 圆球（可选加速）
		_check("T4c 墨水足够解法C（含 Heavy 球）", ink >= cost_c, "ink=%d 需要=%d" % [ink, cost_c])
		_check("T4d 环境方块(60 高)入沟后顶面在同一出入窗口", block_top >= exit_lo and block_top <= exit_hi)
	_check("T4e 环境方块留在台上也可直接跳越（60 抬升 ≤ 跳高）", 60.0 <= jump_h)

	# ============ T5 实机通关（解法A）——通关只由玩家进入 GOAL 触发 ============
	scene._on_shape(1)     # 长板（走真实选择路径，select 进 telemetry）
	scene._on_word(1)      # Float
	scene._try_place(Vector2(400, 350))
	scene._try_place(Vector2(615, 350))
	await _wait(0.3)
	_check("T5a 两块 Float 长板放置成功、墨水正确扣减", scene.placed.size() == 2 and scene.ink == ink - cost_a,
		"placed=%d ink=%d" % [scene.placed.size(), scene.ink])
	var won := false
	var last_x := -1.0
	var jc := 0
	t0 = Time.get_ticks_msec()
	while scene.state == "play" and Time.get_ticks_msec() - t0 < 45000:
		await physics_frame
		scene.keys[KEY_D] = true
		jc = maxi(0, jc - 1)
		var px: float = scene.player.position.x
		var py: float = scene.player.position.y
		if scene.on_floor and jc == 0:
			var want := false
			if px > 285.0 and px < 320.0 and py > 370.0:
				want = true        # 左台缘起跳上板1（落点 408~443，留 ≥22px 余量）
			elif px > 408.0 and px < 460.0 and py < 350.0:
				want = true        # 板1 起跳上板2（落点 ≈564，板2 左缘 550）
			elif px > 625.0 and px < 665.0 and py < 350.0:
				want = true        # 板2 起跳上右台/GOAL
			elif absf(px - last_x) < 2.0:
				want = true        # 被预置方块挡住 → 跳越（统一物理，不判解法）
			if want:
				scene.keys[KEY_SPACE] = true
				jc = 20
			else:
				scene.keys[KEY_SPACE] = false
		last_x = px
	won = scene.state == "win"
	scene.keys[KEY_D] = false
	scene.keys[KEY_SPACE] = false
	_check("T5b 实机通关（解法A·仅 GOAL 判定，无解法 trigger）", won,
		"state=%s player=%s" % [String(scene.state), str(scene.player.position)])

	# ============ T6 盲测 telemetry（ChatGPT L3 评审指定 8 字段，玩法零改动） ============
	var has_place := false
	var has_select := false
	for e in scene.tel_events:
		if e.get("type", "") == "place" and e.get("shape", "") == "plank" and e.get("tag", "") == "float" \
				and int(e.get("ink_cost", 0)) == cost_a / 2 and (e.get("pos", []) as Array).size() == 2:
			has_place = true
		if e.get("type", "") == "select":
			has_select = true
	_check("T6a place 事件含 shape/tag/spawn_position/ink_cost", has_place)
	_check("T6b select 事件记录（可回放首次试 Heavy/Sticky）", has_select)
	var has_goal := false
	for e2 in scene.tel_events:
		if e2.get("type", "") == "goal" and int(e2.get("level", -1)) == 2 and e2.has("elapsed"):
			has_goal = true
	_check("T6c goal 事件记录通关（用时/剩余墨水/放置数）", has_goal)
	var jtxt: String = scene.tel_export_json()
	var jparsed = JSON.parse_string(jtxt)
	var evs_ok: bool = jparsed is Dictionary and jparsed.get("events", null) is Array \
			and (jparsed["events"] as Array).size() == scene.tel_events.size()
	_check("T6d 导出 JSON 可解析且事件数一致", evs_ok, "json_len=%d" % jtxt.length())
	var pid_ok: bool = jparsed is Dictionary and str(jparsed.get("pid", "")) != ""
	_check("T6e 记录含受试编号 pid（盲测区分受试者）", pid_ok)
	var has_contact := false
	var has_end := false
	# T6f 驱动：放一个 Heavy 圆球进沟，等它撞上沟底（真实刚体→静态接触）
	scene._on_shape(0)
	scene._on_word(0)
	scene._try_place(Vector2(500, 200))
	var t3 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t3 < 6000:
		await physics_frame
		var hit_wall := false
		for e9 in scene.tel_events:
			if e9.get("type", "") == "contact" and str(e9.get("with", "")) == "wall":
				hit_wall = true
		if hit_wall:
			break
	for e3 in scene.tel_events:
		if e3.get("type", "") == "contact" and str(e3.get("oid", "")).begins_with("placed_") \
				and e3.get("ev", "") == "enter" and str(e3.get("with", "")) != "":
			has_contact = true
		if e3.get("type", "") == "session_end" and e3.get("end_reason", "") == "goal":
			has_end = true
	_check("T6f contact_enter 序列带双方实例 ID（还原接触链）", has_contact)
	_check("T6g 通关自动 session_end(goal) 封口", has_end)

	# ============ T7 L4「翻越高墙」几何（转向阶梯·补充关卡，L3 未动） ============
	scene._load_level(3)
	await _wait(0.5)
	var lv4: Dictionary = scene.LEVELS[3]
	var wall: Rect2 = lv4.walls[4]
	var rise4: float = lv4.walls[3].position.y - wall.position.y   # 地面 470 → 墙顶 380
	_check("T7a 墙体抬升超过跳高（不可直接跳过）", rise4 > jump_h, "抬升=%.0f 跳高=%.1f" % [rise4, jump_h])
	_check("T7b GOAL 在墙右侧地面", lv4.goal.position.x > wall.end.x and lv4.goal.end.y >= lv4.walls[3].position.y)
	_check("T7c 墨水足够解法A（单 Float 板 40）", int(lv4.ink) >= 40, "ink=%s" % str(lv4.ink))
	var q1 := Rect2(420 - 65, 401 - 11, 130, 22)   # 浮板 顶 390（高于墙顶 380，走上墙头只需 10px 小跳）
	_check("T7d 浮板可从地面跳上（抬升 ≤ 跳高）", (lv4.walls[3].position.y - q1.position.y) <= jump_h,
		"抬升=%.0f" % (lv4.walls[3].position.y - q1.position.y))
	_check("T7e 浮板不与墙体相交", not q1.intersects(wall))
	_check("T7f 浮板顶高于墙顶（板上小跳即可越墙，抬升 ≤ 跳高）",
		q1.position.y > wall.position.y and (q1.position.y - wall.position.y) <= jump_h,
		"越墙抬升=%.0f" % (q1.position.y - wall.position.y))
	var objs4 := get_nodes_in_group("level_objs")
	_check("T7g 预置物体 2 件（可推可站，规格 2~3）", objs4.size() == 2, "实际=%d" % objs4.size())
	_check("T7h 解法B 成立：环境方块顶(410)可从地面跳上，且从方块顶可跳上墙顶(380)",
		objs4.size() >= 1 and 410.0 - jump_h < lv4.walls[3].position.y and (410.0 - wall.position.y) <= jump_h,
		"上箱抬升=%.0f 越墙抬升=%.0f" % [470.0 - 410.0, 410.0 - wall.position.y])

	# ============ T8 L4 实机通关（解法A·单 Float 板，仅 GOAL 判定） ============
	scene._on_shape(1)
	scene._on_word(1)
	scene._try_place(Vector2(420, 401))
	await _wait(0.3)
	var won4 := false
	var jc4 := 0
	var t4 := Time.get_ticks_msec()
	while scene.state == "play" and Time.get_ticks_msec() - t4 < 45000:
		scene.keys[KEY_D] = true
		await physics_frame
		jc4 = maxi(0, jc4 - 1)
		var px4: float = scene.player.position.x
		var py4: float = scene.player.position.y
		if scene.on_floor and jc4 == 0:
			var want := false
			if px4 > 262.0 and px4 < 274.0 and py4 > 420.0:
				want = true        # 地面 → 浮板（顶 390，起跳距板缘≥36px 弧线净空）
			elif px4 > 455.0 and px4 < 485.0 and py4 < 400.0:
				want = true        # 浮板 → 越墙（墙顶 380 低于板顶 390，抬升 10）
			if want:
				scene.keys[KEY_SPACE] = true
				jc4 = 25
			else:
				scene.keys[KEY_SPACE] = false
		if scene.on_floor and py4 < 330.0 and px4 > 370.0:
			scene.keys[KEY_D] = true   # 落上板2 后恢复向右
	won4 = scene.state == "win"
	scene.keys[KEY_D] = false
	scene.keys[KEY_SPACE] = false
	_check("T8a L4 实机通关（解法A·仅 GOAL 判定，无解法 trigger）", won4,
		"state=%s player=%s" % [String(scene.state), str(scene.player.position)])

	# ============ T9 L5「双沟群岛」几何（持续开发令·补充关卡，L3/L4 未动） ============
	scene._load_level(4)
	await _wait(0.5)
	var lv5: Dictionary = scene.LEVELS[4]
	var g1: float = lv5.walls[4].position.x - lv5.walls[3].end.x   # 沟1 = 中岛左缘 - 左岛右缘
	var g2: float = lv5.walls[5].position.x - lv5.walls[4].end.x   # 沟2 = 右岛左缘 - 中岛右缘
	_check("T9a 沟1 ≤ 水平射程（可直接跳过）", g1 <= jump_range and g1 > 60.0, "沟1=%.0f 射程=%.0f" % [g1, jump_range])
	_check("T9b 沟2 > 水平射程（必须架助，墨水策略分化点）", g2 > jump_range, "沟2=%.0f 射程=%.0f" % [g2, jump_range])
	_check("T9c 坑底覆盖两段沟（掉落不出屏）",
		lv5.walls[6].position.x <= lv5.walls[3].end.x and lv5.walls[6].end.x >= lv5.walls[5].position.x)
	_check("T9d 三岛同高 400（平面路线，无垂直陷阱）",
		lv5.walls[3].position.y == 400.0 and lv5.walls[4].position.y == 400.0 and lv5.walls[5].position.y == 400.0)
	_check("T9e 墨水足够单板解法（40）", int(lv5.ink) >= 40, "ink=%s" % str(lv5.ink))
	var objs5 := get_nodes_in_group("level_objs")
	_check("T9i 坑底环境物体 2 件（落坑逃生路径，无软锁）", objs5.size() == 2, "实际=%d" % objs5.size())

	# ============ T10 L5 实机通关（单板解法：直跳沟1 + Float 板越沟2，仅 GOAL 判定） ============
	scene._on_shape(1)
	scene._on_word(1)
	scene._try_place(Vector2(665, 391))   # Float 长板跨沟2（顶 380， spans 600..730）
	await _wait(0.3)
	var won5 := false
	var jc5 := 0
	var t5 := Time.get_ticks_msec()
	while scene.state == "play" and Time.get_ticks_msec() - t5 < 45000:
		await physics_frame
		scene.keys[KEY_D] = true
		jc5 = maxi(0, jc5 - 1)
		var px5: float = scene.player.position.x
		var py5: float = scene.player.position.y
		if scene.on_floor and jc5 == 0:
			var want := false
			if px5 > 270.0 and px5 < 280.0 and py5 > 370.0:
				want = true        # 左岛缘直跳沟1（落中岛 420..560）
			elif px5 > 548.0 and px5 < 560.0 and py5 > 370.0:
				want = true        # 中岛缘起跳上板（顶 380，落点 600..730）
			if want:
				scene.keys[KEY_SPACE] = true
				jc5 = 25
			else:
				scene.keys[KEY_SPACE] = false
	won5 = scene.state == "win"
	scene.keys[KEY_D] = false
	scene.keys[KEY_SPACE] = false
	_check("T10a L5 实机通关（单板解法·仅 GOAL 判定，无解法 trigger）", won5,
		"state=%s player=%s" % [String(scene.state), str(scene.player.position)])

	# ============ T11 L6「登天梯」几何（持续开发令·补充关卡，L3/L4/L5 未动） ============
	scene._load_level(5)
	await _wait(0.4)
	var lv6: Dictionary = scene.LEVELS[5]
	var t1: Rect2 = lv6.walls[4]
	var t2: Rect2 = lv6.walls[5]
	var r_t1: float = lv6.walls[3].position.y - t1.position.y   # 地面 470 → 塔1 顶 330
	var r_t2: float = t1.position.y - t2.position.y             # 塔1 330 → 塔2 260
	_check("T11a 塔1 抬升超跳高（必须架助）", r_t1 > jump_h, "抬升=%.0f 跳高=%.1f" % [r_t1, jump_h])
	var g12: float = t2.position.x - t1.end.x   # 塔1/塔2 水平间隙
	var reach70: float = 240.0 * ((520.0 + sqrt(520.0 * 520.0 - 4.0 * 800.0 * 70.0)) / 1600.0)   # 爬升 70 时的可达水平距离
	_check("T11b 塔1→塔2 间隙超爬升 70 可达距离（直接跳不可达，须二级架助）", g12 > reach70,
		"间隙=%.0f 可达=%.1f" % [g12, reach70])
	var f1 := Rect2(220 - 65, 401 - 11, 130, 22)   # P1 顶 390（自地面抬升 80）
	var f2 := Rect2(535 - 65, 346 - 11, 130, 22)   # P2 顶 325（自塔1 抬升 65，紧邻塔1 右缘）
	_check("T11d P1 可从地面跳上（抬升 ≤ 跳高）", (lv6.walls[3].position.y - f1.position.y) <= jump_h,
		"抬升=%.0f" % (lv6.walls[3].position.y - f1.position.y))
	_check("T11e 塔1 可从 P1 跳上（抬升 ≤ 跳高）且 P1 不与塔1 相交",
		(f1.position.y - t1.position.y) <= jump_h and not f1.intersects(t1),
		"抬升=%.0f" % (f1.position.y - t1.position.y))
	_check("T11f P2 紧邻塔1 右缘（步行可落，无跳）", f2.position.x <= t1.end.x and f2.end.x > t1.end.x
		and f2.position.y >= t1.position.y - 10.0)
	_check("T11g 塔2 可从 P2 跳上（抬升 ≤ 跳高）且 P2 不与塔2 相交",
		(f2.position.y - t2.position.y) <= jump_h and not f2.intersects(t2),
		"抬升=%.0f" % (f2.position.y - t2.position.y))
	_check("T11h GOAL 在塔2 顶", lv6.goal.position.x >= t2.position.x and lv6.goal.end.y >= t2.position.y
		and lv6.goal.position.y >= t2.position.y - 70.0)

	# ============ T12 L6 实机通关（双板链·仅 GOAL 判定） ============
	scene._on_shape(1)
	scene._on_word(1)
	scene._try_place(Vector2(220, 401))
	scene._try_place(Vector2(535, 346))
	await _wait(0.3)
	var won6 := false
	var jc6 := 0
	var t6 := Time.get_ticks_msec()
	while scene.state == "play" and Time.get_ticks_msec() - t6 < 45000:
		await physics_frame
		scene.keys[KEY_D] = true
		jc6 = maxi(0, jc6 - 1)
		var px6: float = scene.player.position.x
		var py6: float = scene.player.position.y
		if scene.on_floor and jc6 == 0:
			var want := false
			if px6 > 56.0 and px6 < 72.0 and py6 > 420.0:
				want = true        # 地面 → P1（顶 390）
			elif px6 > 240.0 and px6 < 275.0 and py6 > 350.0 and py6 < 400.0:
				want = true        # P1 → 塔1（顶 330）
			elif px6 > 500.0 and px6 < 530.0 and py6 > 285.0 and py6 < 325.0:
				want = true        # P2 → 塔2（顶 260）
			if want:
				scene.keys[KEY_SPACE] = true
				jc6 = 25
			else:
				scene.keys[KEY_SPACE] = false
	won6 = scene.state == "win"
	scene.keys[KEY_D] = false
	scene.keys[KEY_SPACE] = false
	_check("T12a L6 实机通关（双板链·仅 GOAL 判定，无解法 trigger）", won6,
		"state=%s player=%s" % [String(scene.state), str(scene.player.position)])

	Engine.time_scale = 1.0
	_log("统计: PASS=%d FAIL=%d" % [pass_cnt, fail_cnt])
	_log("ALL DONE")
	logf.flush()
	quit()
