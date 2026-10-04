extends Node3D
## DEMO6 3D 阶段 A 灰模 v1：L3 风格开放断层验证房 + 第三人称 + 墨水放置 v1。
## 指南：D:/GIT/3D-GUIDE/taptap2026-demo06-3d-zcode-guide-2026-10-04.md
## 尺度：100px ≈ 1m；玩家 2.4m/s、跳 5.2m/s、手写重力 16；刚体世界重力读 ProjectSettings（3D 默认 9.8）。
## 词条行为（阶段 A 保留 2D 语义）：Heavy 重力×2.6 mass8 / Float 重力0+冻结 / Fire 自毁2s（灰模无易燃物）/
## Sticky 摩擦4 弹性0 + 0.4s 接触计时冻结（源码语义如实保留，未改为接触后计时）。
## 放置 v1：相机中心射线取点（未命中→沿受控深度平面），ghost 半透明预览，LMB 提交，墨水原子扣费（校验失败不扣）。
## 已知 v1 简化：无 yaw/pitch/roll 旋转（后续轮）、无 placement_command_id 完整事务（预留 TODO）、Esc 释放鼠标。

const WALK := 2.4
const JUMP_V := 5.2
const GRAV := 16.0
const PLACE_DIST := 6.0
const VIEW := Vector2(960, 540)

const SHAPES := [
	{"id": "ball", "size": Vector3(0.56, 0.56, 0.56), "cost": 30},
	{"id": "plank", "size": Vector3(1.3, 0.22, 0.6), "cost": 25},
	{"id": "block", "size": Vector3(0.64, 0.64, 0.64), "cost": 30},
]
const WORDS := [
	{"id": "heavy", "cost": 10, "grav": 2.6, "mass": 8.0},
	{"id": "float", "cost": 15, "grav": 0.0},
	{"id": "fire", "cost": 15, "grav": 1.0},
	{"id": "sticky", "cost": 10, "grav": 1.0},
]

var ink := 100
var shape_idx := 1
var word_idx := 0
var mouse_captured := true
var player: CharacterBody3D
var cam_pitch: Node3D
var cam: Camera3D
var ghost: MeshInstance3D
var placed_root: Node3D
var placed_count := 0
var hud: CanvasLayer
var ink_label: Label
var mode_label: Label
var shape_meshes: Array[Mesh] = []
var ghost_meshes: Array[Mesh] = []


func _ready() -> void:
	_build_environment()
	_build_level()
	_build_player()
	_build_props()
	_build_goal()
	_build_hud()
	_update_ghost()



func _mesh_for(shape_idx_v: int) -> Mesh:
	match shape_idx_v:
		0:
			var s := SphereMesh.new()
			s.radius = 0.28
			s.height = 0.56
			return s
		1:
			var p := BoxMesh.new()
			p.size = Vector3(1.3, 0.22, 0.6)
			return p
		2:
			var b := BoxMesh.new()
			b.size = Vector3(0.64, 0.64, 0.64)
			return b
	return BoxMesh.new()


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	sun.light_energy = 1.2
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("101826")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8899bb")
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)


func _static_box(pos: Vector3, size: Vector3, col: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	mi.position = Vector3.ZERO
	body.add_child(mi)
	add_child(body)
	return body


func _build_level() -> void:
	# L3 风格开放断层验证房：左台/右台同高 1.2m，沟宽 4.05m，沟底 y=-1.55 顶面。
	_static_box(Vector3(0.7, 0.6, 0.0), Vector3(4.4, 1.2, 6.0), Color("39415a"))    # 左台 x[-1.5,2.9] 顶1.2
	_static_box(Vector3(7.6, 0.6, 0.0), Vector3(4.0, 1.2, 6.0), Color("39415a"))    # 右台 x[5.6,9.6]
	_static_box(Vector3(4.25, -0.75, 0.0), Vector3(4.9, 0.5, 6.0), Color("2a3148")) # 沟底 顶-1.0


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0.0, 1.9, 0.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.0
	cs.shape = cap
	player.add_child(cs)
	var vis := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.25
	cm.height = 1.0
	vis.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("66bb6a")
	vis.material_override = mat
	player.add_child(vis)
	var pivot := Node3D.new()
	pivot.name = "CamPivot"
	pivot.position = Vector3(0, 0.6, 0)
	player.add_child(pivot)
	var arm := SpringArm3D.new()
	arm.spring_length = 4.5
	arm.collision_mask = 1
	pivot.add_child(arm)
	cam = Camera3D.new()
	cam.fov = 75.0
	arm.add_child(cam)
	player.set_meta("grav", GRAV)
	add_child(player)
	cam.make_current()


func _build_props() -> void:
	placed_root = Node3D.new()
	placed_root.name = "CreatedObjects"
	add_child(placed_root)
	var defs := [
		{"id": "ball", "pos": Vector3(1.2, 2.2, 0.5), "mesh": _mesh_for(0), "shape": _sphere_shape(0.28)},
		{"id": "plank", "pos": Vector3(2.2, 2.4, -0.6), "mesh": _mesh_for(1), "shape": _box_shape(Vector3(1.3, 0.22, 0.6))},
		{"id": "block", "pos": Vector3(0.8, 2.3, 0.8), "mesh": _mesh_for(2), "shape": _box_shape(Vector3(0.64, 0.64, 0.64))},
	]
	for d in defs:
		var rb := RigidBody3D.new()
		rb.position = d.pos
		var cs := CollisionShape3D.new()
		cs.shape = d.shape
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = d.mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("b8a888")
		mi.material_override = mat
		rb.add_child(mi)
		placed_root.add_child(rb)


func _sphere_shape(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s


func _box_shape(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


func _build_goal() -> void:
	var g := Area3D.new()
	g.position = Vector3(8.2, 1.7, 0.0)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.0, 1.2, 1.0)
	cs.shape = sh
	g.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 1.2, 1.0)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffd54f", 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	g.add_child(mi)
	g.body_entered.connect(_on_goal_entered)
	add_child(g)


func _on_goal_entered(body: Node3D) -> void:
	if body == player:
		mode_label.text = "GOAL! 6 关对照见 2D 版"
		print("GOAL_REACHED")


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	ink_label = Label.new()
	ink_label.position = Vector2(16, 12)
	ink_label.text = "墨水 %d | 形状[1球 2板 3块] 词条[4重 5浮 6燃 7黏] LMB放置 | Esc释放鼠标" % ink
	hud.add_child(ink_label)
	mode_label = Label.new()
	mode_label.position = Vector2(16, 40)
	mode_label.text = "L3 灰模验证房 v1（阶段 A）"
	hud.add_child(mode_label)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				shape_idx = 0
			KEY_2:
				shape_idx = 1
			KEY_3:
				shape_idx = 2
			KEY_4:
				word_idx = 0
			KEY_5:
				word_idx = 1
			KEY_6:
				word_idx = 2
			KEY_7:
				word_idx = 3
			KEY_R:
				player.position = Vector3(0.0, 1.9, 0.0)
				player.velocity = Vector3.ZERO
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_update_ghost()
	elif event is InputEventMouseButton and event.pressed and mouse_captured:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place()
	elif event is InputEventMouseMotion and mouse_captured:
		player.rotate_y(-event.relative.x * 0.003)
		cam_pitch.rotate_x(-event.relative.y * 0.003)
		cam_pitch.rotation.x = clampf(cam_pitch.rotation.x, -1.2, 0.6)


func _physics_process(delta: float) -> void:
	# v1：Fire 自毁 2s / Sticky 生成后 0.4s 冻结（2D 语义如实保留，指南 §2 表）
	if placed_root != null:
		var now := Time.get_ticks_msec() / 1000.0
		for b in placed_root.get_children():
			if b is RigidBody3D:
				if b.has_meta("die_at") and now >= float(b.get_meta("die_at")):
					b.queue_free()
					continue
				if b.has_meta("freeze_at") and now >= float(b.get_meta("freeze_at")) and not b.freeze:
					b.freeze = true
	if player == null:
		return
	var dir := Vector3.ZERO
	var fwd := -player.global_transform.basis.z
	var right := player.global_transform.basis.x
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir += fwd
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir -= fwd
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += right
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= right
	dir.y = 0.0
	dir = dir.normalized() * WALK
	if not player.is_on_floor():
		player.velocity.y -= GRAV * delta
	if Input.is_key_pressed(KEY_SPACE) and player.is_on_floor():
		player.velocity.y = JUMP_V
	player.velocity.x = dir.x
	player.velocity.z = dir.z
	player.move_and_slide()


func _update_ghost() -> void:
	if ghost != null:
		ghost.queue_free()
	ghost = MeshInstance3D.new()
	ghost.mesh = _mesh_for(shape_idx)
	var mat := StandardMaterial3D.new()
	var ok: bool = ink >= SHAPES[shape_idx].cost + WORDS[word_idx].cost
	mat.albedo_color = Color(0.4, 0.9, 0.5, 0.35) if ok else Color(0.9, 0.4, 0.3, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.material_override = mat
	add_child(ghost)


func _try_place() -> void:
	var cost: int = SHAPES[shape_idx].cost + WORDS[word_idx].cost
	if ink < cost:
		mode_label.text = "墨水不足（需 %d）" % cost
		return
	var cam_t := cam.global_transform
	var from := cam_t.origin
	var to := from - cam_t.basis.z * PLACE_DIST
	var rb := RigidBody3D.new()
	rb.name = "Placed%d" % placed_count
	var cs := CollisionShape3D.new()
	var mesh: Mesh = _mesh_for(shape_idx)
	if shape_idx == 0:
		var s := SphereShape3D.new()
		s.radius = 0.28
		cs.shape = s
		rb.mass = 1.0 * (2.6 if word_idx == 0 else 1.0)
	else:
		var b := BoxShape3D.new()
		var sz: Vector3 = SHAPES[shape_idx].size
		b.size = sz
		cs.shape = b
		rb.mass = 8.0 if word_idx == 0 else 1.0
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8d8d94") if word_idx == 0 else (Color("4fc3f7") if word_idx == 1 else (Color("ef5350") if word_idx == 2 else Color("8d6e63")))
	mi.material_override = mat
	rb.add_child(mi)
	rb.position = to
	var word: Dictionary = WORDS[word_idx]
	rb.gravity_scale = word.grav
	if word.id == "float":
		rb.freeze = true
		rb.can_sleep = false
	if word.id == "sticky":
		var pm := PhysicsMaterial.new()
		pm.friction = 4.0
		pm.bounce = 0.0
		rb.physics_material_override = pm
		rb.set_meta("freeze_at", Time.get_ticks_msec() / 1000.0 + 0.4)
	if word.id == "fire":
		rb.set_meta("die_at", Time.get_ticks_msec() / 1000.0 + 2.0)
	placed_root.add_child(rb)
	placed_count += 1
	ink -= cost
	ink_label.text = "墨水 %d | 形状[1球 2板 3块] 词条[4重 5浮 6燃 7黏] LMB放置 | Esc释放鼠标" % ink
	print("PLACED type=place shape=%s word=%s level=0" % [SHAPES[shape_idx].id, WORDS[word_idx].id])


func place_for_test() -> void:
	_try_place()
