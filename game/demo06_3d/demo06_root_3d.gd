extends Node3D
## DEMO6 3D 阶段 A 场景应用版 v2：L3 风格开放断层验证房 + 第三人称 + 墨水放置。
## 指令：分支自 3d-shared 拉出，只做场景应用——世界物体用 ComicObject/统一材质（comic_style 套件）。
## 尺度：100px ≈ 1m；玩家 2.4m/s、跳 5.2m/s、手写重力 16；刚体世界重力读 ProjectSettings（3D 默认 9.8）。
## 词条语义保留 2D：Heavy 重力×2.6 mass8 / Float 重力0+冻结 / Fire 2s 自毁（灰模无易燃物）/
## Sticky 摩擦4 弹性0 + 生成后 0.4s 冻结（2D 源码语义如实保留）。
## v2 新增（指南 §3/§4）：ghost yaw 旋转（Q/E）+ 深度调节（滚轮 3~8m）+ 占位原子校验
##（旋转形状查询带 8% 容差，与玩家/地形/实体深度重叠即拒绝且不扣墨）+ 放置带 yaw 旋转。

const ComicObjectScript := preload("res://comic_style/comic_object.gd")
const StyleDefinition := preload("res://comic_style/comic_style.gd")
const ModelLibrary := preload("res://comic_style/model_library.gd")

const WALK := 2.4
const JUMP_V := 5.2
const GRAV := 16.0

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
# 影片/测试插桩：scripted=true 时由驱动直设方向与跳跃（绕过 Input——Movie Maker 离线渲染不处理输入事件）
var scripted := false
var auto_dir := Vector3.ZERO
var auto_jump := false
var player: CharacterBody3D
var cam_pitch: Node3D
var cam: Camera3D
var ghost: Node3D
var ghost_mesh: MeshInstance3D
var placed_root: Node3D
var placed_count := 0
var hud: CanvasLayer
var ink_label: Label
var mode_label: Label
var style: Resource
var ghost_yaw := 0.0
var place_dist := 6.0
var ghost_pos := Vector3(2.0, 1.8, 0.0)
# 物理时钟：词条计时（Fire 自毁 / Sticky 冻结）随物理 tick 累加——离线渲染（--fixed-fps）与
# headless 测试下与真实时钟解耦，保证确定性（Time.get_ticks_msec 在离线渲染会失真）
var clock := 0.0
var props_root: Node3D


func _ready() -> void:
	style = StyleDefinition.new()
	_build_environment()
	_build_level()
	_build_player()
	_build_props()
	_build_goal()
	_build_hud()
	_update_ghost()
	_place_ghost_at(_ray_endpoint())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	mi.material_override = style.body_material(col)
	body.add_child(mi)
	add_child(body)
	return body


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


func _build_level() -> void:
	# L3 风格开放断层：两台同高 1.2m，沟宽 4.05m，沟底 -1.2m。统一材质（场景细色，无轮廓）。
	_static_box(Vector3(0.7, 0.6, 0.0), Vector3(4.4, 1.2, 6.0), Color("8a93a8"))
	_static_box(Vector3(7.6, 0.6, 0.0), Vector3(4.0, 1.2, 6.0), Color("8a93a8"))
	_static_box(Vector3(4.25, -0.75, 0.0), Vector3(4.9, 0.5, 6.0), Color("6d7590"))


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
	vis.material_override = style.body_material(Color("6fbf73"))
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
	add_child(player)
	cam.make_current()


func _build_props() -> void:
	placed_root = Node3D.new()
	placed_root.name = "EnvironmentObjects"
	add_child(placed_root)
	# 普通环境箱（RigidBody 无词条，入 props_root 与词条放置物分账）——可推/可撞，参与 L3 解法 C
	var crate := ModelLibrary.create_model("crate")
	var bounds := ModelLibrary.geometry_bounds(crate)
	var target_h := 1.05
	var s: float = target_h / maxf(bounds.size.y, 0.2)
	var rb := RigidBody3D.new()
	rb.name = "EnvCrate"
	rb.mass = 1.2
	# 低摩擦：可被玩家推动/Heavy 撞走（默认摩擦会咬死在台面上）
	var cpm := PhysicsMaterial.new()
	cpm.friction = 0.4
	cpm.bounce = 0.0
	rb.physics_material_override = cpm
	rb.position = Vector3(2.3, 1.2 + target_h * 0.5 + 0.02, 1.2)
	var cs := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = bounds.size * s
	cs.shape = bsh
	rb.add_child(cs)
	crate.scale = Vector3.ONE * s
	crate.position = -bounds.get_center() * s
	rb.add_child(crate)
	props_root = Node3D.new()
	props_root.name = "EnvProps"
	add_child(props_root)
	props_root.add_child(rb)


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
		mode_label.text = "GOAL!"
		print("GOAL_REACHED")


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	ink_label = Label.new()
	ink_label.position = Vector2(16, 12)
	hud.add_child(ink_label)
	mode_label = Label.new()
	mode_label.position = Vector2(16, 40)
	mode_label.text = "L3 灰模验证房（场景应用版 v2）"
	hud.add_child(mode_label)
	_refresh_hud()


func _refresh_hud() -> void:
	var cost: int = SHAPES[shape_idx].cost + WORDS[word_idx].cost
	ink_label.text = "墨水 %d | %s+%s %d墨 | Q/E旋转 %.0f° | 滚轮深度 %.1fm | LMB放置 | Esc释放鼠标" % [
		ink, SHAPES[shape_idx].id, WORDS[word_idx].id, cost, rad_to_deg(ghost_yaw), place_dist]


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
			KEY_Q:
				ghost_yaw += PI * 0.5
			KEY_E:
				ghost_yaw -= PI * 0.5
			KEY_R:
				player.position = Vector3(0.0, 1.9, 0.0)
				player.velocity = Vector3.ZERO
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_hud()
		_update_ghost()
	elif event is InputEventMouseButton and event.pressed and mouse_captured:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			place_dist = clampf(place_dist + 0.5, 3.0, 8.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			place_dist = clampf(place_dist - 0.5, 3.0, 8.0)
	elif event is InputEventMouseMotion and mouse_captured:
		player.rotate_y(-event.relative.x * 0.003)
		cam_pitch.rotate_x(-event.relative.y * 0.003)
		cam_pitch.rotation.x = clampf(cam_pitch.rotation.x, -1.2, 0.6)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	clock += delta
	# 词条计时（v1 语义）：Fire die_at 自毁 / Sticky freeze_at 冻结
	var now := clock
	for b in placed_root.get_children():
		if b is RigidBody3D:
			if b.has_meta("die_at") and now >= float(b.get_meta("die_at")):
				b.queue_free()
			elif b.has_meta("freeze_at") and now >= float(b.get_meta("freeze_at")) and not b.freeze:
				b.freeze = true
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
	if scripted:
		dir = auto_dir
	if dir.length() > 1.0:
		dir = dir.normalized()
	dir = dir * WALK
	if not player.is_on_floor():
		player.velocity.y -= GRAV * delta
	var want_jump: bool = (Input.is_key_pressed(KEY_SPACE) or auto_jump) and player.is_on_floor()
	if want_jump:
		player.velocity.y = JUMP_V
	auto_jump = false
	player.velocity.x = dir.x
	player.velocity.z = dir.z
	player.move_and_slide()
	# 推箱：滑碰动态刚体施加持续小冲量（普通环境物可被推动/被 Heavy 撞——L3 解法 C 通道）
	for i in player.get_slide_collision_count():
		var col := player.get_slide_collision(i)
		var rb_hit := col.get_collider() as RigidBody3D
		if rb_hit != null and not rb_hit.freeze:
			rb_hit.apply_central_impulse(-col.get_normal() * 25.0 * delta)
	# ghost 跟随射线终点
	_place_ghost_at(_ray_endpoint())


func _ray_endpoint() -> Vector3:
	var cam_t := cam.global_transform
	var end := cam_t.origin - cam_t.basis.z * place_dist
	end.y = maxf(end.y, -0.6)
	return end


func _place_ghost_at(pos: Vector3) -> void:
	ghost_pos = pos
	if ghost != null:
		ghost.position = pos
		ghost.rotation.y = ghost_yaw


func _update_ghost() -> void:
	if ghost != null:
		ghost.queue_free()
	var cost: int = SHAPES[shape_idx].cost + WORDS[word_idx].cost
	ghost = Node3D.new()
	ghost_mesh = MeshInstance3D.new()
	ghost_mesh.mesh = _mesh_for_idx(shape_idx)
	var mat := StandardMaterial3D.new()
	var ok: bool = ink >= cost
	mat.albedo_color = Color(0.4, 0.9, 0.5, 0.35) if ok else Color(0.9, 0.4, 0.3, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mesh.material_override = mat
	ghost.add_child(ghost_mesh)
	add_child(ghost)
	ghost.position = ghost_pos
	ghost.rotation.y = ghost_yaw


func _word_color(word_id: String) -> Color:
	if word_id == "heavy":
		return Color("8d8d94")
	if word_id == "float":
		return Color("4fc3f7")
	if word_id == "fire":
		return Color("ef5350")
	return Color("8d6e63")


func _try_place() -> void:
	try_place_validated(_ray_endpoint(), ghost_yaw)


func _placement_shape(size: Vector3, yaw: float, margin: float) -> BoxShape3D:
	# 旋转盒的凸包近似：yaw 旋转后取水平外接盒（避免旋转形状查询的引擎差异）
	var c := absf(cos(yaw))
	var sn := absf(sin(yaw))
	var ex: float = (size.x * c + size.z * sn) * 0.5 * margin
	var ez: float = (size.x * sn + size.z * c) * 0.5 * margin
	var b := BoxShape3D.new()
	b.size = Vector3(ex * 2.0, size.y * margin, ez * 2.0)
	return b


## 原子放置校验 v2：资金 + 旋转占位查询（8% 收缩容差，允许表面接触）
## 拒绝（资金不足/与玩家/地形/实体深度重叠）→ 不扣墨返回 false；成功 → 扣墨一次
func try_place_validated(pos: Vector3, yaw: float) -> bool:
	var shape: Dictionary = SHAPES[shape_idx]
	var word: Dictionary = WORDS[word_idx]
	var cost: int = shape.cost + word.cost
	if ink < cost:
		mode_label.text = "墨水不足（需 %d，剩 %d）" % [cost, ink]
		return false
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _placement_shape(shape.size, yaw, 0.92)
	params.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [player.get_rid()]
	var hits := get_world_3d().direct_space_state.intersect_shape(params, 8)
	if hits.size() > 0:
		mode_label.text = "放置位置被阻挡"
		return false
	_place_at_validated(pos, yaw, shape, word, cost)
	return true


func _place_at_validated(pos: Vector3, yaw: float, shape: Dictionary, word: Dictionary, cost: int) -> void:
	ink -= cost
	var rb := RigidBody3D.new()
	rb.name = "Placed%d" % placed_count
	rb.rotation.y = yaw
	var cs := CollisionShape3D.new()
	if shape.id == "ball":
		var s := SphereShape3D.new()
		s.radius = shape.size.x * 0.5
		cs.shape = s
	else:
		var b := BoxShape3D.new()
		b.size = shape.size
		cs.shape = b
	rb.add_child(cs)
	# ComicObject 视觉（interactive 粗线：玩家创造物；词条色）
	var comic: Node3D = ComicObjectScript.new()
	comic.interactive = true
	comic.add_part(_mesh_for_idx(shape_idx), _word_color(word.id))
	rb.add_child(comic)
	rb.mass = word.mass if word.id == "heavy" else 1.0
	rb.gravity_scale = word.grav
	if word.id == "float":
		rb.freeze = true
		rb.can_sleep = false
	if word.id == "sticky":
		var pm := PhysicsMaterial.new()
		pm.friction = 4.0
		pm.bounce = 0.0
		rb.physics_material_override = pm
		rb.set_meta("freeze_at", clock + 0.4)
	if word.id == "fire":
		rb.set_meta("die_at", clock + 2.0)
	placed_root.add_child(rb)
	rb.position = pos
	placed_count += 1
	_refresh_hud()
	print("PLACED shape=%s word=%s yaw=%.2f level=0" % [shape.id, word.id, rad_to_deg(yaw)])


func place_for_test() -> void:
	try_place_validated(_ray_endpoint(), 0.0)


## 测试/影片用蓝图放置：指定 形状/词条/位置（走同一校验）
func place_blueprint(shape_i: int, word_i: int, pos: Vector3) -> bool:
	var keep_shape := shape_idx
	var keep_word := word_idx
	shape_idx = shape_i
	word_idx = word_i
	var ok := try_place_validated(pos, 0.0)
	shape_idx = keep_shape
	word_idx = keep_word
	return ok


func _mesh_for_idx(idx: int) -> Mesh:
	match idx:
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
