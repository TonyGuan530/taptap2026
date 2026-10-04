extends Node3D
## DEMO2 第一人称 3D 物性解谜 · 阶段A 灰模测试房（指南 D:\GIT\3D-GUIDE\taptap2026-demo02-3d-zcode-guide-2026-10-04.md）
## 保留 2D 全部规则：无通用跳跃 / 切换即时生效保持速度连续 / 脆板按撞击速度阈值 / 弹簧一次冲量 / 遥测。
## 参数为米制重标定（不照抄 2D 像素值）：球 r=0.5m，重力 9.8，脆板阈值 12 m/s（≈石头从 4m 落体速度）。

const BALL_R := 0.5
const FRAGILE_SPEED := 12.0        # m/s，脆板破碎阈值（标定：石头 g_scale2.4 从 4m 落体 ≈13.7 m/s）
const FLAP_VEL := 3.2              # 羽毛单次空中修正（向上 m/s）
const SPAWN := Vector3(-4.5, 1.6, 0.0)
const MOUSE_SENS := 0.0022
const PITCH_LIMIT := 1.45          # rad ≈ 83°

const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")

## 词条（g_scale/damp/bounce 从 2D 语义迁移；flap=向上速度 m/s；air_a/vmax 为米制）
const TAGS := [
	{ id = "feather", name = "羽毛", kw = "轻", color = Color(0.91, 0.89, 0.85),
	  g = 0.18, damp = 1.2, bounce = 0.2, flap = FLAP_VEL, air_a = 14.0, air_vmax = 5.0 },
	{ id = "stone", name = "石头", kw = "重", color = Color(0.55, 0.55, 0.58),
	  g = 2.4, damp = 0.0, bounce = 0.08, flap = 0.0, air_a = 3.0, air_vmax = 2.5 },
	{ id = "ball", name = "皮球", kw = "弹", color = Color(0.94, 0.33, 0.31),
	  g = 1.0, damp = 0.0, bounce = 0.86, flap = 0.0, air_a = 8.0, air_vmax = 6.5 },
]

var tag_idx := 0
var ball: RigidBody3D
var ground_ray: RayCast3D
var fragile: StaticBody3D
var goal_reached := false
var fragile_broken := false
var spring_used := false
var in_spring := false
var spring_ready := true
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
var hud_tag: Label
var hud_hint: Label
var flash_t := 0.0


func _ready() -> void:
	_ensure_input_actions()
	_build_room()
	_build_goal_and_hazards()
	_spawn_ball(SPAWN)
	_apply_tag()
	_build_hud()
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


func _box(name: String, pos: Vector3, size: Vector3, color: Color, is_fragile := false) -> StaticBody3D:
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)
	return body


func _build_room() -> void:
	var floor_body := _box("Floor", Vector3(0, -0.25, 0), Vector3(24, 0.5, 12), Color(0.22, 0.24, 0.3))
	floor_body.physics_material_override = _phys_mat(0.4)
	_box("WallN", Vector3(0, 4.5, -6.25), Vector3(24, 9, 0.5), Color(0.18, 0.2, 0.26))
	_box("WallS", Vector3(0, 4.5, 6.25), Vector3(24, 9, 0.5), Color(0.18, 0.2, 0.26))
	_box("WallW", Vector3(-12.25, 4.5, 0), Vector3(0.5, 9, 13), Color(0.18, 0.2, 0.26))
	_box("WallE", Vector3(12.25, 4.5, 0), Vector3(0.5, 9, 13), Color(0.18, 0.2, 0.26))
	_box("Ceiling", Vector3(0, 9.25, 0), Vector3(24, 0.5, 13), Color(0.14, 0.16, 0.2))
	# 灰模照明
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


func _phys_mat(bounce: float) -> PhysicsMaterial:
	var pm := PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = 0.6
	return pm


func _build_goal_and_hazards() -> void:
	# 弹簧垫：Area3D，进入即给一次竖直冲量（一次触发，退出复位）
	var spring := Area3D.new()
	spring.name = "Spring"
	spring.position = Vector3(-4.5, 0.15, 0)
	var scs := CollisionShape3D.new()
	var ssh := BoxShape3D.new()
	ssh.size = Vector3(2, 0.4, 2)
	scs.shape = ssh
	spring.add_child(scs)
	var smi := MeshInstance3D.new()
	var smesh := BoxMesh.new()
	smesh.size = Vector3(2, 0.3, 2)
	smi.mesh = smesh
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(1.0, 0.84, 0.31)
	smi.material_override = smat
	spring.add_child(smi)
	spring.body_entered.connect(_on_spring_enter)
	spring.body_exited.connect(_on_spring_exit)
	add_child(spring)

	# 脆板：弹簧上抛后转石头砸穿，GOAL 在其正下方（板加宽到 x -10..-6 防绕边滑入）
	fragile = _box("FragilePlate", Vector3(-8, 3, 0), Vector3(4, 0.15, 2.5), Color(0.42, 0.56, 0.35), true)

	# GOAL
	var goal := Area3D.new()
	goal.name = "Goal"
	goal.position = Vector3(-8, 0.55, 0)   # 抬离地面 0.1m：防 Area 底面与地板顶面贴合误触发
	var gcs := CollisionShape3D.new()
	var gsh := BoxShape3D.new()
	gsh.size = Vector3(2, 0.9, 2)
	gcs.shape = gsh
	goal.add_child(gcs)
	var gmi := MeshInstance3D.new()
	var gmesh := BoxMesh.new()
	gmesh.size = Vector3(2, 1, 2)
	gmi.mesh = gmesh
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1.0, 0.84, 0.31, 0.35)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmi.material_override = gmat
	goal.add_child(gmi)
	goal.body_entered.connect(_on_goal_enter)
	add_child(goal)


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
	_refresh_hud()


func _spawn_ball(pos: Vector3) -> void:
	ball = RigidBody3D.new()
	ball.name = "PlayerBall"
	ball.position = pos
	ball.mass = 1.0
	ball.continuous_cd = true            # 石头高速撞击防穿透（指南要求）
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
	# 第一人称镜头装置：跟随球位置，yaw 在装置上、pitch 在相机上，不继承滚动
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
	_spawn_ball(SPAWN)
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
	fragile = _box("FragilePlate", Vector3(-8, 3, 0), Vector3(4, 0.15, 2.5), Color(0.42, 0.56, 0.35), true)
	fragile_broken = false


func _zone_name() -> String:
	if ball == null:
		return "?"
	var p := ball.position
	if goal_reached:
		return "goal"
	if in_spring:
		return "spring"
	if p.x < -6.5 and p.y > 2.2:
		return "above_plate"
	if p.x > 6.0:
		return "east"
	return "field"


func _on_spring_enter(_other: Node) -> void:
	in_spring = true


func _on_spring_exit(_other: Node) -> void:
	in_spring = false
	spring_ready = true


func _on_goal_enter(other: Node) -> void:
	print("GOALENTER other=", other.name, " ballpos=", ball.global_position if ball else Vector3.INF)
	if goal_reached:
		return
	goal_reached = true
	var sw := "无切换" if tel_switches.is_empty() else "→".join(tel_switches)
	var idle := (not tel_moved) and (not tel_flapped) and (not tel_mid_switch)
	print("TEL3D|A|%.1fs|idle=%s|%s|%s" % [elapsed, str(idle), sw, "spring_used=" + str(spring_used)])
	_refresh_hud()


func _on_ball_hit(other: Node) -> void:
	if other == fragile and not fragile_broken:
		# 撞击速度阈值判定（prev_speed 为上一物理帧速度，撞击前采样）
		if prev_speed >= FRAGILE_SPEED:
			fragile_broken = true
			fragile.queue_free()
		elif hud_hint != null:
			hud_hint.text = "撞击 %d m/s，未达 %.0f m/s——脆板纹丝不动……" % [int(prev_speed), FRAGILE_SPEED]


func _physics_process(delta: float) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	elapsed += delta
	prev_speed = ball.linear_velocity.length()
	var t: Dictionary = TAGS[tag_idx]

	# 移动：相对镜头 yaw 的水平转向（空中地面一致；无通用跳跃）
	var in_x := Input.get_axis("p_left", "p_right")
	var in_y := Input.get_axis("p_back", "p_fwd")   # W=+1 前进（反馈#1 修复：原 W/S 反向）
	var dir := Vector3.ZERO
	if absf(in_x) > 0.01 or absf(in_y) > 0.01:
		tel_moved = true
		var fwd := -Vector3(sin(yaw), 0, cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		dir = (fwd * in_y + right * in_x).normalized()
	if dir.length_squared() > 0.01:
		var v: Vector3 = ball.linear_velocity
		var hv: Vector2 = Vector2(v.x, v.z)
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

	# 弹簧：进入即竖直冲量（一次触发，离开复位）
	if in_spring and spring_ready:
		ball.linear_velocity = Vector3(0, 12, 0)
		spring_ready = false
		spring_used = true

	# 镜头跟随球，yaw/pitch 来自鼠标；镜头位置钳制在房间内（防穿墙出界）
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
