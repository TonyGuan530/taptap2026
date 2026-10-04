extends Node3D
## DEMO5 HD-2D 恐龙生存 · 阶段 A（灰盒）
## 指南：taptap2026-demo05-hd2d-zcode-guide-2026-10-04.md
## 直接操控一只恐龙：WASD 移动（相机相对）、E 采集（浆果/饮水）、岩石碰撞、背包 HUD。
## 世界/碰撞为 3D；恐龙为 2D 精灵（临时贴图，正式像素帧后换）。
## 验收（阶段 A）：绕岩石走到资源点、采集、库存变化、离开再返回；无重复领取、无穿墙。

const MOVE_SPEED := 6.0
const INTERACT_RANGE := 2.2
const GRAVITY := 18.0

## 资源点（手工布点，阶段 C 扩展为五地域）
const BERRY_POS := Vector3(-6.0, 0.0, -4.0)
const WATER_POS := Vector3(6.0, 0.0, -5.0)
const BERRY_START_STOCK := 3

## 岩石障碍（验证碰撞与绕行）
const ROCKS := [
	{pos = Vector3(0, 0.75, -2), size = Vector3(3, 1.5, 2)},
	{pos = Vector3(-3, 0.75, 3), size = Vector3(2, 1.5, 3)},
	{pos = Vector3(4, 0.75, 3.5), size = Vector3(2.5, 1.5, 2)},
]

var inventory := {"food": 0, "water": 0}
var berry_stock := BERRY_START_STOCK
var interact_prompt := ""
var interact_kind := ""
var nearest_resource: Node3D
var dino: CharacterBody3D
var cam_pivot: Node3D
var hud_food: Label
var hud_water: Label
var hud_prompt: Label

func _ready() -> void:
	# 输入动作运行时注册（WASD 移动 + E 交互）
	for pair in [["mv_up", KEY_W], ["mv_left", KEY_A], ["mv_down", KEY_S], ["mv_right", KEY_D], ["interact", KEY_E]]:
		if not InputMap.has_action(pair[0]):
			var ev := InputEventKey.new()
			ev.keycode = pair[1]
			InputMap.add_action(pair[0])
			InputMap.action_add_event(pair[0], ev)
	_build_world()
	_build_dino()
	_build_camera()
	_build_hud()

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.85)
	env.ambient_light_energy = 0.7
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)

	# 地面：40×40 灰盒 + 碰撞
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var gmesh := MeshInstance3D.new()
	var gplane := PlaneMesh.new()
	gplane.size = Vector2(40, 40)
	gmesh.mesh = gplane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.36, 0.42, 0.30)
	gmesh.material_override = gmat
	ground.add_child(gmesh)
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(40, 0.2, 40)
	gcol.shape = gshape
	gcol.position = Vector3(0, -0.1, 0)
	ground.add_child(gcol)
	add_child(ground)

	# 边界墙（防走出地图）
	for wall in [
		{pos = Vector3(0, 1, -20), size = Vector3(40, 2, 0.5)},
		{pos = Vector3(0, 1, 20), size = Vector3(40, 2, 0.5)},
		{pos = Vector3(-20, 1, 0), size = Vector3(0.5, 2, 40)},
		{pos = Vector3(20, 1, 0), size = Vector3(0.5, 2, 40)},
	]:
		var wbody := StaticBody3D.new()
		var wcol := CollisionShape3D.new()
		var wshape := BoxShape3D.new()
		wshape.size = wall.size
		wcol.shape = wshape
		wcol.position = wall.pos
		wbody.add_child(wcol)
		add_child(wbody)

	# 岩石障碍（碰撞 + 网格）
	for r in ROCKS:
		var rock := StaticBody3D.new()
		var rmesh := MeshInstance3D.new()
		var rbox := BoxMesh.new()
		rbox.size = r.size
		rmesh.mesh = rbox
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.45, 0.45, 0.48)
		rmesh.material_override = rmat
		rmesh.position = r.pos
		rock.add_child(rmesh)
		var rcol := CollisionShape3D.new()
		var rshape := BoxShape3D.new()
		rshape.size = r.size
		rcol.shape = rshape
		rcol.position = r.pos
		rock.add_child(rcol)
		add_child(rock)

	# 浆果丛（红球标记）
	var berry := StaticBody3D.new()
	berry.name = "BerryNode"
	berry.position = BERRY_POS
	var bmesh := MeshInstance3D.new()
	var bsphere := SphereMesh.new()
	bsphere.radius = 0.5
	bsphere.height = 1.0
	bmesh.mesh = bsphere
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.55, 0.3, 0.25)
	bmesh.material_override = bmat
	bmesh.position = Vector3(0, 0.5, 0)
	berry.add_child(bmesh)
	for k in 3:
		var fruit := MeshInstance3D.new()
		var fsphere := SphereMesh.new()
		fsphere.radius = 0.12
		fsphere.height = 0.24
		fruit.mesh = fsphere
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(0.9, 0.25, 0.25)
		fruit.material_override = fmat
		var ang := k * TAU / 3.0
		fruit.position = Vector3(cos(ang) * 0.35, 0.7, sin(ang) * 0.35)
		fruit.name = "Fruit%d" % k
		berry.add_child(fruit)
	add_child(berry)

	# 水潭（蓝柱标记）
	var water := StaticBody3D.new()
	water.name = "WaterNode"
	water.position = WATER_POS
	var wmesh := MeshInstance3D.new()
	var wcyl := CylinderMesh.new()
	wcyl.top_radius = 0.9
	wcyl.bottom_radius = 0.9
	wcyl.height = 0.2
	wmesh.mesh = wcyl
	var wmat2 := StandardMaterial3D.new()
	wmat2.albedo_color = Color(0.25, 0.5, 0.75)
	wmesh.material_override = wmat2
	wmesh.position = Vector3(0, 0.1, 0)
	water.add_child(wmesh)
	add_child(water)

func _build_dino() -> void:
	dino = CharacterBody3D.new()
	dino.name = "Dino"
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.6
	col.shape = cap
	col.position = Vector3(0, 0.8, 0)
	dino.add_child(col)
	var pivot := Node3D.new()
	pivot.name = "VisualPivot"
	dino.add_child(pivot)
	var sprite := Sprite3D.new()
	sprite.texture = load("res://art/dino.png")
	sprite.pixel_size = 0.0018
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(0, 620)  # 脚底锚点：贴图中心上移半高
	sprite.position = Vector3(0, 0.02, 0)
	pivot.add_child(sprite)
	dino.position = Vector3(0, 0.1, 4)
	add_child(dino)

func _build_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.name = "CameraRig"
	var cam := Camera3D.new()
	cam.position = Vector3(0, 14, 9)
	cam.rotation_degrees = Vector3(-57, 0, 0)
	cam.fov = 55
	cam_pivot.add_child(cam)
	add_child(cam_pivot)
	cam_pivot.position = Vector3(0, 0, 4)
	cam.current = true

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	hud_food = _mk_label(hud, Vector2(16, 10), Color("ffd54f"))
	hud_water = _mk_label(hud, Vector2(120, 10), Color("4fc3f7"))
	hud_prompt = _mk_label(hud, Vector2(16, 44), Color("ffe082"))
	hud_prompt.add_theme_font_size_override("font_size", 18)
	var help := _mk_label(hud, Vector2(16, 500), Color("8b94a7"))
	help.text = "WASD 移动 · E 采集/交互 · 走到资源点旁按 E"
	help.add_theme_font_size_override("font_size", 14)

func _mk_label(ui: CanvasLayer, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 18)
	ui.add_child(l)
	return l

func _process(delta: float) -> void:
	# 相机跟随恐龙（XZ 平面）
	if dino and cam_pivot:
		cam_pivot.position = Vector3(dino.position.x, 0, dino.position.z + 4)
	# 移动（相机相对 = 世界轴，固定方位）
	var mv := Vector2.ZERO
	if Input.is_action_pressed("mv_left"):
		mv.x -= 1
	if Input.is_action_pressed("mv_right"):
		mv.x += 1
	if Input.is_action_pressed("mv_up"):
		mv.y -= 1
	if Input.is_action_pressed("mv_down"):
		mv.y += 1
	if dino and mv != Vector2.ZERO:
		dino.velocity.x = mv.x * MOVE_SPEED
		dino.velocity.z = mv.y * MOVE_SPEED
	else:
		dino.velocity.x = 0
		dino.velocity.z = 0
	if not dino.is_on_floor():
		dino.velocity.y -= GRAVITY * delta
	else:
		dino.velocity.y = 0.0
	if dino:
		dino.move_and_slide()
	# 交互检测
	_update_interact()
	if Input.is_action_just_pressed("interact") and interact_kind != "":
		_do_interact()
	# HUD
	hud_food.text = "食物 %d" % inventory.food
	hud_water.text = "饮水 %d" % inventory.water
	hud_prompt.text = interact_prompt

func _update_interact() -> void:
	interact_kind = ""
	interact_prompt = ""
	if dino == null:
		return
	var dp := dino.position
	if berry_stock > 0 and dp.distance_to(BERRY_POS) < INTERACT_RANGE + 0.5:
		interact_kind = "food"
		interact_prompt = "[E] 采集浆果（剩余 %d）" % berry_stock
		nearest_resource = get_node_or_null("BerryNode")
		return
	if dp.distance_to(WATER_POS) < INTERACT_RANGE + 0.5:
		interact_kind = "water"
		interact_prompt = "[E] 喝水"
		nearest_resource = get_node_or_null("WaterNode")

func _do_interact() -> void:
	match interact_kind:
		"food":
			if berry_stock > 0:
				berry_stock -= 1
				inventory.food += 1
				_refresh_berry_fruits()
				interact_prompt = ""
		"water":
			inventory.water += 1
			interact_prompt = ""

func _refresh_berry_fruits() -> void:
	var node := get_node_or_null("BerryNode")
	if node == null:
		return
	for k in 3:
		var fruit := node.get_node_or_null("Fruit%d" % k)
		if fruit:
			fruit.visible = k < berry_stock
