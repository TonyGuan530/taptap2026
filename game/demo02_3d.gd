extends Node3D
## DEMO2 第一人称 3D 物性解谜 · 阶段B：数据驱动多关卡（目标 ≥5 关）
## 保留 2D 全部规则：无通用跳跃 / 切换即时生效保持速度连续 / 脆板撞击速度阈值 / 弹簧一次冲量 / 遥测。
## 米制标定：球 r=0.5m，重力 9.8，脆板阈值 12 m/s。视觉走 3d-shared comic 材质+模型库（场景应用，不复制套件）。

const BALL_R := 0.5
const FRAGILE_SPEED := 11.0   # 砸板阈值；顶点转石头冲击 ≈15 m/s，留 35% 余量（羽毛终末速 ≈2 永远不够）
const FLAP_VEL := 3.2
const MOUSE_SENS := 0.0022
const PITCH_LIMIT := 1.45

const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")
const ComicStyle := preload("res://comic_style/comic_style.gd")
const ModelLibrary := preload("res://comic_style/model_library.gd")

const TAGS := [
	{ id = "feather", name = "羽毛", kw = "轻", color = Color(0.91, 0.89, 0.85),
	  g = 0.18, damp = 1.2, bounce = 0.2, flap = FLAP_VEL, air_a = 14.0, air_vmax = 5.0 },
	{ id = "stone", name = "石头", kw = "重", color = Color(0.55, 0.55, 0.58),
	  g = 2.4, damp = 0.0, bounce = 0.08, flap = 0.0, air_a = 3.0, air_vmax = 2.5 },
	{ id = "ball", name = "皮球", kw = "弹", color = Color(0.94, 0.33, 0.31),
	  g = 1.0, damp = 0.0, bounce = 0.86, flap = 0.0, air_a = 8.0, air_vmax = 6.5 },
]

## 关卡数据：boxes=[pos,size,color]；spring/fragile/goal 可选；碰撞/物理由装载器生成
const LEVELS := [
	{
		name = "第一关 · 弹簧起步", solution = "弹簧+皮球，空中按住 W 越墙",
		spawn = Vector3(-4.5, 1.6, 0),
		boxes = [
			[Vector3(0, -0.25, 0), Vector3(24, 0.5, 12), "field"],
			[Vector3(3, 2.25, 0), Vector3(1, 4.5, 12), "wall"],
			[Vector3(0, 4.5, -6.25), Vector3(24, 9, 0.5), "wall"],
			[Vector3(0, 4.5, 6.25), Vector3(24, 9, 0.5), "wall"],
			[Vector3(-12.25, 4.5, 0), Vector3(0.5, 9, 13), "wall"],
			[Vector3(12.25, 4.5, 0), Vector3(0.5, 9, 13), "wall"],
			[Vector3(0, 9.25, 0), Vector3(24, 0.5, 13), "wall"],
		],
		spring = { pos = Vector3(-4.5, 0.15, 0), imp = Vector3(0, 12, 0) },
		fragile = null,
		goal = { pos = Vector3(7, 0.65, 0), size = Vector3(2.4, 1.1, 2.4) },   # 底 0.1m 离地防贴合误触发
	},
	{
		name = "第二关 · 砸穿脆板", solution = "原地弹簧上抛，顶点转石头竖直砸穿脆板",
		spawn = Vector3(-8, 1.6, 0),
		boxes = [
			[Vector3(0, -0.25, 0), Vector3(24, 0.5, 12), "field"],
			[Vector3(0, 4.5, -6.25), Vector3(24, 9, 0.5), "wall"],
			[Vector3(0, 4.5, 6.25), Vector3(24, 9, 0.5), "wall"],
			[Vector3(-12.25, 4.5, 0), Vector3(0.5, 9, 13), "wall"],
			[Vector3(12.25, 4.5, 0), Vector3(0.5, 9, 13), "wall"],
			[Vector3(0, 9.25, 0), Vector3(24, 0.5, 13), "wall"],
		],
		spring = { pos = Vector3(-8, 0.15, 0), imp = Vector3(0, 12, 0) },   # 实测基准冲量 12（b 套件全绿所测）；余量来自板压低 2.0 + 阈值 11
		fragile = { pos = Vector3(-9.75, 2.0, 0), size = Vector3(2.5, 0.5, 2.5) },   # 脆板错位弹簧左上方；厚 0.5m 防高速穿板；压低落距增冲击余量
		goal = { pos = Vector3(-9.75, 0.7, 0), size = Vector3(2.4, 0.9, 2.4) },   # 底 0.25m 离地
	},
	{
		name = "第三关 · 组合峡谷", solution = "弹簧→转羽毛(扑翼+W)跨峡谷→松 W 落入远端 GOAL",
		spawn = Vector3(-4.5, 1.6, 0),
		boxes = [
			[Vector3(-6, -0.25, 0), Vector3(12, 0.5, 12), "field"],
			[Vector3(12, -0.25, 0), Vector3(8, 0.5, 12), "field"],
			[Vector3(2, 4.5, -6.25), Vector3(28, 9, 0.5), "wall"],
			[Vector3(2, 4.5, 6.25), Vector3(28, 9, 0.5), "wall"],
			[Vector3(-12.25, 4.5, 0), Vector3(0.5, 9, 13), "wall"],
			[Vector3(16.25, 4.5, 0), Vector3(0.5, 9, 13), "wall"],
			[Vector3(2, 9.25, 0), Vector3(28, 0.5, 13), "wall"],
		],
		spring = { pos = Vector3(-4.5, 0.15, 0), imp = Vector3(0, 12, 0) },
		fragile = null,
		goal = { pos = Vector3(11, 0.55, 0), size = Vector3(3.2, 0.9, 2.8) },
	},
	{
		name = "第四关 · 开放高台", solution = "双路线：羽毛顶点转轻飘上高台 ／ 皮球按住 W 被空中弹板抛射上高台（不换词条）",
		spawn = Vector3(-8, 1.6, 0),
		boxes = [
			[Vector3(0, -0.25, 0), Vector3(24, 0.5, 12), "field"],
			[Vector3(9, 1.5, 0), Vector3(4, 3, 4), "wall"],   # 高台：顶面 y=3
			[Vector3(0, 4.5, -6.25), Vector3(24, 9, 0.5), "wall"],
			[Vector3(0, 4.5, 6.25), Vector3(24, 9, 0.5), "wall"],
			[Vector3(-12.25, 4.5, 0), Vector3(0.5, 9, 13), "wall"],
			[Vector3(12.25, 4.5, 0), Vector3(0.5, 9, 13), "wall"],
			[Vector3(0, 9.25, 0), Vector3(24, 0.5, 13), "wall"],
		],
		springs = [
			{ pos = Vector3(-8, 0.15, 0), imp = Vector3(0, 12, 0) },
			{ pos = Vector3(4.4, 3, 0), imp = Vector3(3.5, 8, 0) },   # 空中弹板：皮球下落弧穿过即被抛向高台（vx 也重设，松 W 时机不敏感）
		],
		fragile = null,
		goal = { pos = Vector3(9, 3.65, 0), size = Vector3(2.4, 1.1, 2.4) },   # 高台顶上，底 3.1 离台面 0.1
	},
	{
		name = "第五关 · 高台弹跳", solution = "皮球踩弹簧后零输入：竖直弹簧链逐级再点火，穿过高空 GOAL 环（石头弹不上去）",
		spawn = Vector3(-3, 1.6, 0),
		boxes = [
			[Vector3(0, -0.25, 0), Vector3(12, 0.5, 12), "field"],
			[Vector3(0, 8, -6.25), Vector3(12, 16, 0.5), "wall"],
			[Vector3(0, 8, 6.25), Vector3(12, 16, 0.5), "wall"],
			[Vector3(-6.25, 8, 0), Vector3(0.5, 16, 13), "wall"],
			[Vector3(6.25, 8, 0), Vector3(0.5, 16, 13), "wall"],
			[Vector3(0, 16.25, 0), Vector3(13, 0.5, 13), "wall"],
		],
		springs = [
			{ pos = Vector3(-3, 0.15, 0), imp = Vector3(0, 12, 0) },
			{ pos = Vector3(-3, 4.5, 0), imp = Vector3(0, 12, 0) },   # 空中弹簧：上升穿过即再点火
		],
		fragile = null,
		goal = { pos = Vector3(-3, 11, 0), size = Vector3(2.4, 1.0, 2.4) },   # 高空环：二级弹簧顶点 ≈12 穿过
	},
	{
		name = "第六关 · 抛接峡谷", solution = "弹簧斜抛切羽毛：W 飘到峡谷中段松键垂降浮空弹板，二次点火抛上基座 GOAL（直线滑翔会被基座挡住）",
		spawn = Vector3(-8, 1.6, 0),
		boxes = [
			[Vector3(-8, -0.25, 0), Vector3(8, 0.5, 12), "field"],      # 左岸 x -12..-4
			[Vector3(13.75, 1.75, 0), Vector3(3.5, 3.5, 6), "wall"],    # 高台 x 12..15.5 顶面 y=3.5
			[Vector3(13.75, 3, 0), Vector3(2.5, 6, 3), "wall"],         # 基座 x 12.5..15 顶面 y=6（挡直线滑翔）
			[Vector3(2.5, 6, -6.25), Vector3(29, 12, 0.5), "wall"],
			[Vector3(2.5, 6, 6.25), Vector3(29, 12, 0.5), "wall"],
			[Vector3(-12.25, 4.5, 0), Vector3(0.5, 9, 13), "wall"],
			[Vector3(16.25, 6, 0), Vector3(0.5, 12, 13), "wall"],
			[Vector3(-2, 9.25, 0), Vector3(20, 0.5, 13), "wall"],       # 左半顶棚 y 9..9.5（发射段）
			[Vector3(12.5, 11.75, 0), Vector3(11, 0.5, 13), "wall"],    # 右半顶棚抬高 y 11.5..12（接力段）
		],
		springs = [
			{ pos = Vector3(-8, 0.15, 0), imp = Vector3(4.5, 13, 0) },  # 斜抛：石头直线弹道落谷（g=23.5 顶点仅 4.3m）
			{ pos = Vector3(5, 5.5, 0), imp = Vector3(5, 9.5, 0), size = Vector3(3.5, 1.2, 3.5) },   # 浮空弹板：二次点火抛上基座
		],
		fragile = null,
		goal = { pos = Vector3(13.75, 6.65, 0), size = Vector3(2.4, 1.1, 2.4) },   # 基座顶，底 6.1 离座面 0.1
	},
	{
		name = "第七关 · 破窗密室", solution = "弹簧冲天，顶点切石头高速坠落砸穿密室天窗（皮球不切只有 12.2 < 窗阈 14）",
		spawn = Vector3(-8, 1.6, 0),
		boxes = [
			[Vector3(-7, -0.25, 0), Vector3(11, 0.5, 10), "field"],     # 发射场 x -12.5..-1.5
			[Vector3(1, -0.25, 0), Vector3(7, 0.5, 10), "field"],       # 密室地板 x -2.5..4.5
			[Vector3(-1.95, 4.75, 0), Vector3(1.1, 0.5, 8), "wall"],    # 顶棚左段（天窗 x -1.4..0.2）
			[Vector3(3.3, 4.75, 0), Vector3(2.4, 0.5, 8), "wall"],      # 顶棚右段 x 2.1..4.5
			[Vector3(-2.75, 2.25, 0), Vector3(0.5, 4.5, 8), "wall"],    # 密室左墙
			[Vector3(4.75, 2.25, 0), Vector3(0.5, 4.5, 8), "wall"],     # 密室右墙
			[Vector3(-4, 6, -5.25), Vector3(18, 12, 0.5), "wall"],
			[Vector3(-4, 6, 5.25), Vector3(18, 12, 0.5), "wall"],
			[Vector3(-12.75, 6, 0), Vector3(0.5, 12, 11), "wall"],
			[Vector3(5.75, 6, 0), Vector3(0.5, 12, 11), "wall"],
			[Vector3(-3.5, 12.25, 0), Vector3(19, 0.5, 11), "wall"],
		],
		springs = [
			{ pos = Vector3(-8, 0.15, 0), imp = Vector3(4.9, 15, 0) },  # 冲天：顶点 y≈12 高于天窗，坠落段攒速度
		],
		fragile = { pos = Vector3(1.55, 4.75, 0), size = Vector3(5.9, 0.3, 3), speed = 14.0 },   # 整条天窗缝=脆板（阈 14）：石头坠落 15+ 破，皮球不切 12 破不了
		goal = { pos = Vector3(2.5, 0.65, 0), size = Vector3(2.4, 1.1, 2.4) },   # 室内，底 0.1 离地
	},
]

var level_idx := 0
var level_nodes: Array[Node] = []
var tag_idx := 0
var ball: RigidBody3D
var ground_ray: RayCast3D
var fragile: StaticBody3D
var goal_reached := false
var fragile_broken := false
var fragile_need := 11.0
var spring_used := false
var in_spring := false
var spring_ready := true
var spring_areas: Array[Area3D] = []
var flap_used := false
var prev_speed := 0.0
var tel_switches: Array[String] = []
var tel_resets := 0
var tel_moved := false
var tel_flapped := false
var tel_mid_switch := false
var elapsed := 0.0
var yaw := 0.0
var pitch := 0.0
var cam_rig: Node3D
var camera: Camera3D
var comic_style: Resource
var hud_tag: Label
var hud_level: Label
var hud_hint: Label
var flash_t := 0.0


func _ready() -> void:
	comic_style = ComicStyle.new()
	_ensure_input_actions()
	_build_static()
	_build_hud()
	_load_level(0)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _ensure_input_actions() -> void:
	var defs := {
		"p_left": [KEY_A], "p_right": [KEY_D], "p_fwd": [KEY_W], "p_back": [KEY_S],
		"p_flap": [KEY_SPACE], "p_reset": [KEY_R],
		"p_tag1": [KEY_1], "p_tag2": [KEY_2], "p_tag3": [KEY_3],
	}
	for action: String in defs:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in defs[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func _phys_mat(bounce: float) -> PhysicsMaterial:
	var pm := PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = 0.6
	return pm


func _box(name: String, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = comic_style.body_material(color)
	body.add_child(mi)
	add_child(body)
	level_nodes.append(body)
	return body


func _build_static() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.075, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.55, 0.65)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var ui := CanvasLayer.new()
	add_child(ui)
	hud_level = Label.new()
	hud_level.position = Vector2(20, 90)
	hud_level.add_theme_font_size_override("font_size", 16)
	hud_level.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	ui.add_child(hud_level)


func _build_hud() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	hud_tag = Label.new()
	hud_tag.position = Vector2(20, 16)
	hud_tag.add_theme_font_size_override("font_size", 26)
	hud_tag.add_theme_color_override("font_color", Color("ffd54f"))
	ui.add_child(hud_tag)
	hud_hint = Label.new()
	hud_hint.position = Vector2(20, 60)
	hud_hint.add_theme_font_size_override("font_size", 15)
	hud_hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	ui.add_child(hud_hint)


func _load_level(idx: int) -> void:
	for n in level_nodes:
		if is_instance_valid(n):   # 碎板已被 queue_free 但仍挂在 level_nodes，直接 free 会中断协程
			n.queue_free()
	level_nodes.clear()
	spring_areas.clear()
	level_idx = idx
	var lv: Dictionary = LEVELS[idx]
	for b: Array in lv.boxes:
		_box("Geo", b[0], b[1], Color(0.22, 0.24, 0.3))
	# 弹簧（单弹簧 lv.spring 兼容；多弹簧 lv.springs 数组，L4 双路线/L5 弹跳链用）
	# 注意：Dictionary.get 的默认值参数是急切求值，L4/L5 无 spring 键会直接崩，须显式分支
	var spring_list: Array = lv.springs if lv.has("springs") else [lv.spring]
	for s in spring_list:
		var spring := Area3D.new()
		spring.name = "Spring"
		spring.position = s.pos
		var scs := CollisionShape3D.new()
		var ssh := BoxShape3D.new()
		ssh.size = s.get("size", Vector3(2, 1.2, 2))   # 触发带 1.2m 厚：高反弹皮球的微弹跳必须触发（0.4m 薄带会帧运气漏接）
		scs.shape = ssh
		spring.add_child(scs)
		var plate: Node3D = ModelLibrary.create_model("pressure_plate")
		plate.position = Vector3(0, -0.2, 0)
		spring.add_child(plate)
		spring.set_meta("imp", s.imp)
		spring_areas.append(spring)   # 点火走每帧 overlaps_body 查询（body_exited 在斜抛+CCD 下不可靠）
		add_child(spring)
		level_nodes.append(spring)
	# 脆板
	fragile = null
	fragile_broken = false
	if lv.fragile != null:
		fragile = _box("FragilePlate", lv.fragile.pos, lv.fragile.size, Color(0.42, 0.56, 0.35))
		var blk: Node3D = ModelLibrary.create_model("iron_block")
		blk.scale = Vector3(lv.fragile.size.x / 0.92, lv.fragile.size.y / 0.85, lv.fragile.size.z / 0.92)
		fragile.add_child(blk)
		# 每关可覆盖阈值（L7 破窗=14：皮球自然弹道 12.4 不够，逼最后一刻切石头）
		fragile_need = lv.fragile.get("speed", FRAGILE_SPEED)
	# GOAL
	var goal := Area3D.new()
	goal.name = "Goal"
	goal.position = lv.goal.pos
	var gcs := CollisionShape3D.new()
	var gsh := BoxShape3D.new()
	gsh.size = lv.goal.size
	gcs.shape = gsh
	goal.add_child(gcs)
	var frame: Node3D = ModelLibrary.create_model("gate_frame")
	goal.add_child(frame)
	goal.body_entered.connect(_on_goal_enter)
	add_child(goal)
	level_nodes.append(goal)
	# 球与状态
	_spawn_ball(lv.spawn)
	_apply_tag()
	goal_reached = false
	spring_used = false
	spring_ready = true
	in_spring = false
	flap_used = false
	prev_speed = 0.0
	tel_switches = []
	tel_resets = 0
	tel_moved = false
	tel_flapped = false
	tel_mid_switch = false
	elapsed = 0.0
	hud_level.text = "%s ｜ %s" % [lv.name, lv.solution]


func _spawn_ball(pos: Vector3) -> void:
	ball = RigidBody3D.new()
	ball.name = "PlayerBall"
	ball.position = pos
	ball.mass = 1.0
	ball.continuous_cd = true
	ball.contact_monitor = true
	ball.max_contacts_reported = 8
	ball.can_sleep = false
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = BALL_R
	cs.shape = sh
	ball.add_child(cs)
	ball.physics_material_override = _phys_mat(0.2)
	ball.body_entered.connect(_on_ball_hit)
	ground_ray = RayCast3D.new()
	ground_ray.target_position = Vector3(0, -(BALL_R + 0.15), 0)
	ball.add_child(ground_ray)
	add_child(ball)
	level_nodes.append(ball)   # 球入清理清单：否则换关后旧球泄漏成物理幽灵（与真球互撞毁发射）
	if cam_rig == null:
		cam_rig = Node3D.new()
		cam_rig.name = "CameraRig"
		add_child(cam_rig)
		camera = Camera3D.new()
		camera.position = Vector3(0, 0.25, 0)
		camera.fov = 80.0
		cam_rig.add_child(camera)
		camera.current = true
	_apply_tag()


func _apply_tag() -> void:
	if ball == null:
		return
	var t: Dictionary = TAGS[tag_idx]
	ball.gravity_scale = t.g
	ball.linear_damp = t.damp
	var pm := ball.physics_material_override
	if pm == null:
		pm = _phys_mat(t.bounce)
		ball.physics_material_override = pm
	else:
		pm.bounce = t.bounce
	ball.can_sleep = false
	_refresh_hud()


func _refresh_hud() -> void:
	if hud_tag == null or hud_hint == null:
		return
	var t: Dictionary = TAGS[tag_idx]
	hud_tag.text = "词条：%s · %s" % [t.name, t.kw]
	hud_tag.add_theme_color_override("font_color", t.color)
	hud_hint.text = "WASD 移动｜鼠标观察｜1/2/3 切词条｜空格=羽毛扑翼(滞空一次)｜R 重置｜Esc 释放鼠标"


func switch_tag(i: int) -> void:
	var changed := i != tag_idx
	tag_idx = i
	_apply_tag()
	if changed:
		tel_switches.append("%s@%.1fs[%s]" % [TAGS[i].name, elapsed, _zone_name()])
		if elapsed >= 0.5:
			tel_mid_switch = true
		flash_t = 0.9


func try_flap() -> void:
	var t: Dictionary = TAGS[tag_idx]
	if t.flap == 0.0 or flap_used:
		return
	if ground_ray != null and ground_ray.is_colliding():
		return
	ball.linear_velocity.y = maxf(ball.linear_velocity.y, t.flap)
	flap_used = true
	tel_flapped = true


func reset_ball() -> void:
	if ball != null:
		ball.queue_free()
	_spawn_ball(LEVELS[level_idx].spawn)
	_apply_tag()
	if fragile_broken:
		_restore_fragile()
	goal_reached = false
	spring_used = false
	spring_ready = true
	in_spring = false
	flap_used = false
	tel_switches = []
	tel_resets += 1
	tel_moved = false
	tel_flapped = false
	tel_mid_switch = false


func _restore_fragile() -> void:
	if is_instance_valid(fragile):
		return
	var lv: Dictionary = LEVELS[level_idx]
	if lv.fragile == null:
		return
	fragile = _box("FragilePlate", lv.fragile.pos, lv.fragile.size, Color(0.42, 0.56, 0.35))
	var blk: Node3D = ModelLibrary.create_model("iron_block")
	blk.scale = Vector3(lv.fragile.size.x / 0.92, lv.fragile.size.y / 0.85, lv.fragile.size.z / 0.92)
	fragile.add_child(blk)
	fragile_broken = false


func _zone_name() -> String:
	if ball == null:
		return "?"
	if in_spring:
		return "spring"
	if goal_reached:
		return "goal"
	return "field"


func _on_goal_enter(other: Node) -> void:
	if not (other is RigidBody3D):
		return   # 只认玩家球体；StaticBody(地板)贴邻边界会误触发
	if goal_reached:
		return
	if LEVELS[level_idx].fragile != null and not fragile_broken:
		return   # 脆板关卡：砸穿才算过关，滚落绕进洞无效
	goal_reached = true
	var sw := "无切换" if tel_switches.is_empty() else "→".join(tel_switches)
	var idle := (not tel_moved) and (not tel_flapped) and (not tel_mid_switch)
	print("TEL3D|L%d|%.1fs|idle=%s|%s|resets=%d|spring=%s" % [level_idx + 1, elapsed, str(idle), sw, tel_resets, str(spring_used)])


func _on_ball_hit(other: Node) -> void:
	var lv: Dictionary = LEVELS[level_idx]
	if other == fragile and not fragile_broken and prev_speed >= fragile_need:
		fragile_broken = true
		level_nodes.erase(fragile)   # 摘除幽灵引用，防下次 _load_level 对已释放节点 queue_free
		fragile.queue_free()


func _physics_process(delta: float) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	elapsed += delta
	prev_speed = ball.linear_velocity.length()
	var t: Dictionary = TAGS[tag_idx]

	var in_x := Input.get_axis("p_left", "p_right")
	var in_y := Input.get_axis("p_back", "p_fwd")
	var dir := Vector3.ZERO
	if absf(in_x) > 0.01 or absf(in_y) > 0.01:
		tel_moved = true
		var fwd := -Vector3(sin(yaw), 0, cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		dir = (fwd * in_y + right * in_x).normalized()
	if dir.length_squared() > 0.01:
		var hv: Vector2 = Vector2(ball.linear_velocity.x, ball.linear_velocity.z)
		var target: Vector2 = Vector2(dir.x, dir.z) * float(t.air_vmax)
		hv = hv.move_toward(target, float(t.air_a) * delta)
		ball.linear_velocity.x = hv.x
		ball.linear_velocity.z = hv.y

	if Input.is_action_just_pressed("p_flap"):
		try_flap()
	if Input.is_action_just_pressed("p_reset"):
		reset_ball()
	if Input.is_action_just_pressed("p_tag1"):
		switch_tag(0)
	if Input.is_action_just_pressed("p_tag2"):
		switch_tag(1)
	if Input.is_action_just_pressed("p_tag3"):
		switch_tag(2)

	in_spring = false
	for a in spring_areas:
		if is_instance_valid(a) and a.overlaps_body(ball):
			in_spring = true
			if spring_ready:
				ball.linear_velocity = a.get_meta("imp")   # 全矢量抛射：横分量=定向弹板（L4/L6）；纯竖直=重置横向（L1 调好的越墙落点）
				spring_ready = false
				spring_used = true
	if not spring_ready and in_spring == false:
		spring_ready = true   # 离开所有弹簧即再武装（几何事实，不依赖事件）

	if cam_rig != null and is_instance_valid(ball):
		cam_rig.global_position = ball.global_position + Vector3(0, 0.3, 0)
		cam_rig.rotation = Vector3(0, yaw, 0)
		camera.rotation.x = pitch

	if flash_t > 0.0:
		flash_t = maxf(0.0, flash_t - delta)
		if hud_tag != null:
			hud_tag.modulate.a = clampf(flash_t / 0.9 + 0.35, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENS
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -PITCH_LIMIT, PITCH_LIMIT)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
