extends Node3D
## DEMO5 HD-2D 恐龙生存 · 阶段 B（营地与生存）
## 指南：taptap2026-demo05-hd2d-zcode-guide-2026-10-04.md §6 阶段B
## 新增：三种设施（储备堆/集水器/枝叶窝）、建造模式（B 选型 / 幽灵跟随 / E 放置 / Esc 取消）、
## 饥饿口渴需求（Q 吃 / R 喝）、最小昼夜（昼 60s / 夜 30s）。
## 验收（阶段 B）：无效放置不扣款；采集建成功能设施；营地确实影响生存。

const MOVE_SPEED := 6.0
const INTERACT_RANGE := 2.2
const GRAVITY := 18.0

## 昼夜（最小循环：昼 60s / 夜 30s）
const DAY_LEN := 60.0
const NIGHT_LEN := 30.0

## 资源点
const BERRY_POS := Vector3(-6.0, 0.0, -4.0)
const WATER_POS := Vector3(6.0, 0.0, -5.0)
const TREE_POS := Vector3(8.5, 0.0, 3.0)
const BERRY_START_STOCK := 3
const TREE_START_STOCK := 3
const BERRY_REGEN := 20.0
const TREE_REGEN := 25.0

## 需求
const HUNGER_MAX := 100.0
const THIRST_MAX := 100.0
const HP_MAX := 100.0
const HUNGER_DRAIN := 1.0 / 1.2
const THIRST_DRAIN := 1.0 / 1.0
const HP_DRAIN_STARVE := 1.5
const EAT_HUNGER := 35.0
const DRINK_THIRST := 40.0

## 建造配方（wood 消耗）
const RECIPES := [
	{id = "storage", name = "储备堆", cost = 4, desc = "存取食物与饮水"},
	{id = "collector", name = "集水器", cost = 3, desc = "缓慢集水（上限 3）"},
	{id = "shelter", name = "枝叶窝", cost = 6, desc = "夜晚入睡跳到黎明"},
]
const BUILD_COLORS := {
	"storage": Color(0.75, 0.6, 0.35), "collector": Color(0.35, 0.55, 0.75),
	"shelter": Color(0.45, 0.6, 0.4),
}

## 泥流低谷（阶段 C2：路径拓扑改变——夜漫显著减速，不复制灰区伤害）
const MUD_X_MIN := -2.0
const MUD_X_MAX := 9.0
const MUD_Z_MIN := -9.0
const MUD_Z_MAX := -1.0            # 南缘留 z∈[-1,1.5] 绕行道（岩石群在 z≥1.5）
const MUD_SPEED_SCALE := 0.22
const MUD_START_DAY := 2          # 首夜暴雨叙事后，第 2 夜起泥流漫谷（确定性）

## 岩石障碍
const ROCKS := [
	{pos = Vector3(0, 0.75, -2), size = Vector3(3, 1.5, 2)},
	{pos = Vector3(-3, 0.75, 3), size = Vector3(2, 1.5, 3)},
	{pos = Vector3(4, 0.75, 3.5), size = Vector3(2.5, 1.5, 2)},
]

## 火山灰夜潮（阶段 C 首个灾害：确定性正弦推进-退去，无 RNG）
const VOLCANO_POS := Vector3(19.0, 0.0, -10.0)   # 火山锥在东墙外
const ASH_FRONT_FAR := 18.0    # 黄昏/黎明灰界（墙内侧）
const ASH_NEAR_STRONG := 8.0   # 强潮夜灰界最西（单数日）
const ASH_NEAR_WEAK := 12.0    # 弱潮夜灰界（双数日）——营地区位随预报摆动

## 萨满预报（C3）：今夜灰潮强度。真值按日奇偶确定；预报每第 4 日错一次（75% 正确，脚本化不完全信息）
func _tonight_ash_near() -> float:
	return ASH_NEAR_STRONG if day_num % 2 == 1 else ASH_NEAR_WEAK

func _forecast_correct() -> bool:
	return day_num % 4 != 3

func _forecast_ash_near() -> float:
	var truth := _tonight_ash_near()
	if _forecast_correct():
		return truth
	return ASH_NEAR_WEAK if truth == ASH_NEAR_STRONG else ASH_NEAR_STRONG
const ASH_DPS := 2.0           # 灰区内持续伤害

# —— 运行状态 ——
var inventory := {"food": 0, "water": 0, "wood": 0}
var pile := {"food": 0, "water": 0}
var berry_stock := BERRY_START_STOCK
var berry_regen := 0.0
var tree_stock := TREE_START_STOCK
var tree_regen := 0.0
var hunger := HUNGER_MAX
var thirst := THIRST_MAX
var hp := HP_MAX
var day_time := 0.0
var day_num := 1
var is_night := false
var collector_stock := 0
var collector_timer := 0.0
var buildings: Array = []          # {kind, pos, node}
var build_mode := false
var build_recipe := 0
var ghost: Node3D
var ghost_mesh: MeshInstance3D
var ghost_mat: StandardMaterial3D
var ghost_pos := Vector3.ZERO
var interact_kind := ""
var interact_prompt := ""
var slept_tonight := false
var facing := Vector3(0, 0, -1)   # 放置方向（跟随移动朝向）
var dead := false
var night_amount := 0.0
var sun_light: DirectionalLight3D
var env_res: Environment
var ash_node: MeshInstance3D
var ash_front := ASH_FRONT_FAR
var mud_node: MeshInstance3D
var in_mud := false
var telemetry := {"shelter_build_x": [], "ash_exposure_after_shelter": 0.0}
var shelter_placed := false
var dino: CharacterBody3D
var dino_sprite: Sprite3D
var dino_frames: Array = []
var anim_t := 0.0
var cam_pivot: Node3D
var berry_fruits: Array = []
var hud_labels: Array = []
var hud_prompt: Label
var hud_forecast: Label
var hud_hint: Label

func _ready() -> void:
	for pair in [["mv_up", KEY_W], ["mv_left", KEY_A], ["mv_down", KEY_S], ["mv_right", KEY_D],
			["interact", KEY_E], ["eat", KEY_Q], ["drink", KEY_R], ["build", KEY_B],
			["recipe1", KEY_1], ["recipe2", KEY_2], ["recipe3", KEY_3], ["restart", KEY_ENTER]]:
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
	env_res = env
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)
	sun_light = sun
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
	var berry := Node3D.new()
	berry.name = "BerryNode"
	berry.position = BERRY_POS
	var bmesh := MeshInstance3D.new()
	var bsphere := SphereMesh.new()
	bsphere.radius = 0.5
	bsphere.height = 1.0
	bmesh.mesh = bsphere
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.35, 0.5, 0.28)
	bmesh.material_override = bmat
	bmesh.position = Vector3(0, 0.5, 0)
	berry.add_child(bmesh)
	for k in BERRY_START_STOCK:
		var fruit := MeshInstance3D.new()
		var fsphere := SphereMesh.new()
		fsphere.radius = 0.12
		fsphere.height = 0.24
		fruit.mesh = fsphere
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(0.9, 0.25, 0.25)
		fruit.material_override = fmat
		var ang := k * TAU / 3.0
		fruit.position = Vector3(cos(ang) * 0.35, 0.75, sin(ang) * 0.35)
		fruit.name = "Fruit%d" % k
		berry_fruits.append(fruit)
		berry.add_child(fruit)
	add_child(berry)
	var water := Node3D.new()
	water.name = "WaterNode"
	water.position = WATER_POS
	var wmesh := MeshInstance3D.new()
	var wcyl := CylinderMesh.new()
	wcyl.top_radius = 0.9
	wcyl.bottom_radius = 0.9
	wcyl.height = 0.2
	wmesh.mesh = wcyl
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.25, 0.5, 0.75)
	wmesh.material_override = wmat
	wmesh.position = Vector3(0, 0.1, 0)
	water.add_child(wmesh)
	add_child(water)
	var tree := Node3D.new()
	tree.name = "TreeNode"
	tree.position = TREE_POS
	var tmesh := MeshInstance3D.new()
	var tcyl := CylinderMesh.new()
	tcyl.top_radius = 0.14
	tcyl.bottom_radius = 0.2
	tcyl.height = 2.4
	tmesh.mesh = tcyl
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.45, 0.33, 0.22)
	tmesh.material_override = tmat
	tmesh.position = Vector3(0, 1.2, 0)
	tree.add_child(tmesh)
	var crown := MeshInstance3D.new()
	var csphere := SphereMesh.new()
	csphere.radius = 0.9
	crown.mesh = csphere
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.3, 0.5, 0.25)
	crown.material_override = cmat
	crown.position = Vector3(0, 2.6, 0)
	tree.add_child(crown)
	add_child(tree)
	# 火山锥（东墙外，灰潮方向锚点）
	var volcano := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.3
	cone.bottom_radius = 3.5
	cone.height = 5.0
	volcano.mesh = cone
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(0.32, 0.26, 0.24)
	volcano.material_override = vmat
	volcano.position = VOLCANO_POS + Vector3(0, 2.5, 0)
	add_child(volcano)
	# 灰潮体（半透明灰墙，逐帧按 ash_front 缩放）
	ash_node = MeshInstance3D.new()
	var abox := BoxMesh.new()
	abox.size = Vector3(1, 1, 1)
	ash_node.mesh = abox
	var amat := StandardMaterial3D.new()
	amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amat.albedo_color = Color(0.35, 0.32, 0.28, 0.45)
	ash_node.material_override = amat
	ash_node.visible = false
	add_child(ash_node)
	# 泥流带（固定低谷地形，夜漫昼干，只减速不扣血）
	mud_node = MeshInstance3D.new()
	var mbox := BoxMesh.new()
	mbox.size = Vector3(MUD_X_MAX - MUD_X_MIN, 0.4, MUD_Z_MAX - MUD_Z_MIN)
	mud_node.mesh = mbox
	var mudmat := StandardMaterial3D.new()
	mudmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mudmat.albedo_color = Color(0.4, 0.3, 0.18, 0.5)
	mud_node.material_override = mudmat
	mud_node.position = Vector3((MUD_X_MIN + MUD_X_MAX) * 0.5, 0.2, (MUD_Z_MIN + MUD_Z_MAX) * 0.5)
	mud_node.visible = false
	add_child(mud_node)

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
	dino_frames = [load("res://art/dino.png"), load("res://art/dino3.png"), load("res://art/dino2.png")]
	sprite.texture = dino_frames[0]
	sprite.pixel_size = 0.0018
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(0, 620)
	sprite.position = Vector3(0, 0.02, 0)
	pivot.add_child(sprite)
	dino_sprite = sprite
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

func _mk_label(ui: CanvasLayer, pos: Vector2, col: Color, size := 18) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	ui.add_child(l)
	return l

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	hud_labels = [
		_mk_label(hud, Vector2(16, 10), Color("ffd54f")),
		_mk_label(hud, Vector2(136, 10), Color("4fc3f7")),
		_mk_label(hud, Vector2(256, 10), Color("a1887f")),
		_mk_label(hud, Vector2(376, 10), Color("ef5350")),
		_mk_label(hud, Vector2(496, 10), Color("ffa726")),
		_mk_label(hud, Vector2(616, 10), Color("4fc3f7")),
		_mk_label(hud, Vector2(736, 10), Color("9ccc65")),
	]
	hud_prompt = _mk_label(hud, Vector2(16, 44), Color("ffe082"), 18)
	hud_forecast = _mk_label(hud, Vector2(16, 70), Color("81d4fa"), 15)
	hud_hint = _mk_label(hud, Vector2(16, 500), Color("8b94a7"), 14)
	hud_hint.text = "WASD 移动 · E 交互 · Q 吃 · R 喝 · B 建造（1/2/3 选型，E 放置，Esc 取消）· 夜晚火山灰自东坡推进（灰区受伤且不可交互）· 第 2 夜起低谷夜间泥流（大幅减速，绕行南侧）"

func _process(delta: float) -> void:
	# —— 昼夜 ——
	if not dead:
		day_time += delta
	var cycle := DAY_LEN + NIGHT_LEN
	if day_time >= cycle:
		day_time -= cycle
		day_num += 1
		slept_tonight = false
		_flush_telemetry()
	is_night = day_time >= DAY_LEN
	# —— 昼夜视觉（光照渐变）——
	night_amount = move_toward(night_amount, 1.0 if is_night else 0.0, delta * 4.0)
	if sun_light:
		sun_light.light_energy = 1.1 * (1.0 - 0.85 * night_amount)
	if env_res:
		env_res.ambient_light_energy = lerpf(0.7, 0.18, night_amount)
		env_res.ambient_light_color = Color(0.75, 0.75, 0.85).lerp(Color(0.25, 0.28, 0.45), night_amount)
		env_res.background_color = Color(0.12, 0.14, 0.18).lerp(Color(0.03, 0.04, 0.08), night_amount)
	# —— 火山灰夜潮（确定性：正弦推进-退去）——
	if is_night:
		var ap: float = (day_time - DAY_LEN) / NIGHT_LEN
		ash_front = lerpf(ASH_FRONT_FAR, _tonight_ash_near(), sin(ap * PI))
	else:
		ash_front = ASH_FRONT_FAR
	if ash_node:
		ash_node.visible = is_night
		if is_night:
			var aw := 20.0 - ash_front
			ash_node.scale = Vector3(aw, 4.0, 40.0)
			ash_node.position = Vector3(ash_front + aw * 0.5, 2.0, 0)
	# —— 泥流低谷（C2：路径拓扑，减速不扣血）——
	var mud_night := is_night and day_num >= MUD_START_DAY
	if mud_node:
		mud_node.visible = mud_night
	in_mud = mud_night and dino != null \
			and dino.position.x > MUD_X_MIN and dino.position.x < MUD_X_MAX \
			and dino.position.z > MUD_Z_MIN and dino.position.z < MUD_Z_MAX
	# —— 死亡 / 重开 ——
	if dead:
		hud_prompt.text = "你死了（第 %d 天）· 按 Enter 重来" % day_num
		if Input.is_action_just_pressed("restart"):
			_reset_run()
		return
	if hp <= 0.0:
		dead = true
		return
	# —— 移动 ——
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
		var spd: float = MOVE_SPEED * (MUD_SPEED_SCALE if in_mud else 1.0)
		dino.velocity.x = mv.x * spd
		dino.velocity.z = mv.y * spd
	elif dino:
		dino.velocity.x = 0
		dino.velocity.z = 0
	if dino and not dino.is_on_floor():
		dino.velocity.y -= GRAVITY * delta
	if dino:
		dino.move_and_slide()
	# —— 行走动画（移动时 5fps 交替行走/嗅探帧，静止回站立）——
	if dino_sprite and dino_frames.size() == 3:
		if mv != Vector2.ZERO:
			anim_t += delta
			dino_sprite.texture = dino_frames[1 + (int(anim_t * 5.0) % 2)]
		else:
			anim_t = 0.0
			dino_sprite.texture = dino_frames[0]
	# —— 朝向（由移动速度决定，静止时保持）——
	if dino:
		var vel := Vector3(dino.velocity.x, 0, dino.velocity.z)
		if vel.length_squared() > 0.5:
			facing = vel.normalized()
	# —— 建造幽灵跟随 ——
	if build_mode and dino and ghost:
		ghost_pos = Vector3(dino.position.x, 0, dino.position.z) + facing * 2.2
		ghost_pos.y = 0.0
		ghost.position = ghost_pos
		var placeable := _can_place_at(ghost_pos)
		if ghost_mat:
			ghost_mat.albedo_color = Color(0.4, 0.9, 0.4, 0.5) if placeable else Color(0.95, 0.35, 0.3, 0.55)
	# —— 需求 ——
	hunger = maxf(0.0, hunger - HUNGER_DRAIN * delta)
	thirst = maxf(0.0, thirst - THIRST_DRAIN * delta)
	var drain := 0.0
	if hunger <= 0.0:
		drain += HP_DRAIN_STARVE
	if thirst <= 0.0:
		drain += HP_DRAIN_STARVE
	if drain > 0.0:
		hp = maxf(0.0, hp - drain * delta)
	# —— 灰区持续伤害 ——
	if dino and is_night and dino.position.x > ash_front:
		hp = maxf(0.0, hp - ASH_DPS * delta)
		if shelter_placed:
			telemetry.ash_exposure_after_shelter += delta
	# —— 资源再生 ——
	if berry_stock < BERRY_START_STOCK:
		berry_regen += delta
		if berry_regen >= BERRY_REGEN:
			berry_regen = 0.0
			berry_stock += 1
	for i in berry_fruits.size():
		berry_fruits[i].visible = i < berry_stock
	if tree_stock < TREE_START_STOCK:
		tree_regen += delta
		if tree_regen >= TREE_REGEN:
			tree_regen = 0.0
			tree_stock += 1
	# —— 集水器（建成才工作）——
	var has_collector := false
	for b in buildings:
		if b.kind == "collector":
			has_collector = true
	if has_collector and collector_stock < 3:
		collector_timer += delta
		if collector_timer >= 15.0:
			collector_timer = 0.0
			collector_stock += 1
	# —— 输入：建造选型 ——
	if build_mode:
		for i in RECIPES.size():
			if Input.is_action_just_pressed("recipe%d" % (i + 1)):
				build_recipe = i
	# —— 交互 ——
	_update_interact()
	if Input.is_action_just_pressed("interact"):
		if build_mode:
			_try_place()
		elif interact_kind != "":
			_do_interact()
	if Input.is_action_just_pressed("eat"):
		_eat()
	if Input.is_action_just_pressed("drink"):
		_drink_from_inventory()
	if Input.is_action_just_pressed("build"):
		_toggle_build()
	if build_mode and Input.is_action_just_pressed("ui_cancel"):
		_toggle_build()
	# —— 相机跟随 ——
	if dino and cam_pivot:
		cam_pivot.position = Vector3(dino.position.x, 0, dino.position.z + 4)
	# —— HUD ——
	hud_labels[0].text = "食物 %d" % inventory.food
	hud_labels[1].text = "饮水 %d" % inventory.water
	hud_labels[2].text = "木材 %d" % inventory.wood
	hud_labels[3].text = "生命 %d" % int(hp)
	hud_labels[4].text = "饥饿 %d" % int(hunger)
	hud_labels[5].text = "口渴 %d" % int(thirst)
	hud_labels[6].text = "第 %d 天 · %s" % [day_num, "夜" if is_night else "昼"]
	hud_prompt.text = interact_prompt + ("　[B 建造中：%s — E 放置 / Esc 取消]" % RECIPES[build_recipe].name if build_mode else "")
	if hud_forecast:
		hud_forecast.text = "萨满预报：今夜灰潮%s（萨满十中七五）" % ("强·东推至 8m" if _forecast_ash_near() == ASH_NEAR_STRONG else "弱·仅近坡 12m")
	if is_night and dino:
		if dino.position.x > ash_front:
			hud_prompt.text = "⚠ 火山灰侵入——向西撤！ " + hud_prompt.text
		elif ash_front < 14.0:
			hud_prompt.text = "灰雾自火山坡推进（西界 %.0fm） " % ash_front + hud_prompt.text
	if in_mud:
		hud_prompt.text = "泥流漫谷——通行大幅减缓 " + hud_prompt.text

## 学习链遥测（督导指定：shelter_build_x / 灰暴露时间）——每日滚动与重开时落盘
func _flush_telemetry() -> void:
	var f := FileAccess.open("user://hd2d_telemetry.jsonl", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("user://hd2d_telemetry.jsonl", FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(JSON.stringify({
			"day": day_num,
			"shelter_build_x": telemetry.shelter_build_x,
			"ash_exposure_after_shelter_s": snappedf(telemetry.ash_exposure_after_shelter, 0.1),
		}))
		f.close()
	telemetry.shelter_build_x = []
	telemetry.ash_exposure_after_shelter = 0.0

## 目标点是否被灰潮覆盖（灰区内资源/设施不可交互）
func _in_ash(p: Vector3) -> bool:
	return is_night and p.x > ash_front

func _update_interact() -> void:
	interact_kind = ""
	interact_prompt = ""
	if dino == null:
		return
	var dp := dino.position
	if berry_stock > 0 and not _in_ash(BERRY_POS) and dp.distance_to(BERRY_POS) < INTERACT_RANGE + 0.5:
		interact_kind = "berry"
		interact_prompt = "[E] 采浆果（剩余 %d）" % berry_stock
		return
	if not _in_ash(WATER_POS) and dp.distance_to(WATER_POS) < INTERACT_RANGE + 0.5:
		interact_kind = "pond"
		interact_prompt = "[E] 喝水（口渴 +%d）" % int(DRINK_THIRST)
		return
	if tree_stock > 0 and not _in_ash(TREE_POS) and dp.distance_to(TREE_POS) < INTERACT_RANGE + 0.5:
		interact_kind = "tree"
		interact_prompt = "[E] 拾枯枝（剩余 %d）" % tree_stock
		return
	for b in buildings:
		if not _in_ash(b.pos) and dp.distance_to(b.pos) < INTERACT_RANGE + 0.5:
			match b.kind:
				"storage":
					if pile.food > 0 and hunger < HUNGER_MAX - 1.0:
						interact_kind = "pile_food"
						interact_prompt = "[E] 取食（堆 %d）" % pile.food
					elif pile.water > 0 and thirst < THIRST_MAX - 1.0:
						interact_kind = "pile_water"
						interact_prompt = "[E] 取水（堆 %d）" % pile.water
					elif inventory.food + inventory.water > 0:
						interact_kind = "pile_dep"
						interact_prompt = "[E] 存入食物/饮水"
				"collector":
					if collector_stock > 0:
						interact_kind = "collector"
						interact_prompt = "[E] 取水（器 %d）" % collector_stock
				"shelter":
					interact_kind = "shelter"
					interact_prompt = "[E] 入窝休息" + ("" if is_night else "（夜晚才睡得着）")

func _do_interact() -> void:
	match interact_kind:
		"berry":
			if berry_stock > 0:
				berry_stock -= 1
				inventory.food += 1
				interact_prompt = ""
		"pond":
			thirst = minf(THIRST_MAX, thirst + DRINK_THIRST)
			interact_prompt = ""
		"tree":
			if tree_stock > 0:
				tree_stock -= 1
				inventory.wood += 1
				interact_prompt = ""
		"pile_food":
			if pile.food > 0:
				pile.food -= 1
				hunger = minf(HUNGER_MAX, hunger + EAT_HUNGER)
				interact_prompt = ""
		"pile_water":
			if pile.water > 0:
				pile.water -= 1
				thirst = minf(THIRST_MAX, thirst + DRINK_THIRST)
				interact_prompt = ""
		"pile_dep":
			if inventory.food > 0:
				pile.food += inventory.food
				inventory.food = 0
			if inventory.water > 0:
				pile.water += inventory.water
				inventory.water = 0
			interact_prompt = ""
		"collector":
			if collector_stock > 0:
				collector_stock -= 1
				inventory.water += 1
				interact_prompt = ""
		"shelter":
			if is_night:
				day_time = 0.0
				day_num += 1
				is_night = false
				hp = minf(HP_MAX, hp + 25.0)
				hunger = maxf(0.0, hunger - 8.0)
				thirst = maxf(0.0, thirst - 10.0)
				interact_prompt = "睡到黎明（第 %d 天）" % day_num

func _eat() -> void:
	if inventory.food > 0 and hunger < HUNGER_MAX - 1.0:
		inventory.food -= 1
		hunger = minf(HUNGER_MAX, hunger + EAT_HUNGER)

func _drink_from_inventory() -> void:
	if inventory.water > 0 and thirst < THIRST_MAX - 1.0:
		inventory.water -= 1
		thirst = minf(THIRST_MAX, thirst + DRINK_THIRST)

func _toggle_build() -> void:
	build_mode = not build_mode
	if build_mode and ghost == null:
		ghost = Node3D.new()
		ghost.name = "BuildGhost"
		ghost_mesh = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.5, 1.0, 1.5)
		ghost_mesh.mesh = box
		ghost_mat = StandardMaterial3D.new()
		ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_mat.albedo_color = Color(0.4, 0.9, 0.4, 0.5)
		ghost_mesh.material_override = ghost_mat
		ghost.add_child(ghost_mesh)
		add_child(ghost)
	if ghost:
		ghost.visible = build_mode

## 放置合法性：场内、不压资源点/岩石/已有设施
func _can_place_at(p: Vector3) -> bool:
	if absf(p.x) > 18.0 or absf(p.z) > 18.0:
		return false
	for spot in [BERRY_POS, WATER_POS, TREE_POS]:
		if Vector2(p.x, p.z).distance_to(Vector2(spot.x, spot.z)) < 2.0:
			return false
	for r in ROCKS:
		if absf(p.x - r.pos.x) < r.size.x * 0.5 + 1.0 and absf(p.z - r.pos.z) < r.size.z * 0.5 + 1.0:
			return false
	for b in buildings:
		if Vector2(p.x, p.z).distance_to(Vector2(b.pos.x, b.pos.z)) < 2.2:
			return false
	return true

## E 放置：无效不扣款、木材不足不生成、有效则扣款+生成+退出建造
func _try_place() -> void:
	if not _can_place_at(ghost_pos):
		interact_prompt = "不能放在这里"
		return
	var recipe: Dictionary = RECIPES[build_recipe]
	if inventory.wood < recipe.cost:
		interact_prompt = "木材不足（需 %d）" % recipe.cost
		return
	inventory.wood -= recipe.cost
	var body := StaticBody3D.new()
	body.name = "Building_%s" % recipe.id
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 1.0, 1.5)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BUILD_COLORS[recipe.id]
	mi.material_override = mat
	mi.position = Vector3(0, 0.5, 0)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 1.0, 1.5)
	col.shape = shape
	col.position = Vector3(0, 0.5, 0)
	body.add_child(col)
	body.position = ghost_pos
	add_child(body)
	buildings.append({kind = recipe.id, pos = ghost_pos, node = body})
	if recipe.id == "shelter":
		shelter_placed = true
		telemetry.shelter_build_x.append(snappedf(ghost_pos.x, 0.1))
	interact_prompt = "%s 建成（-木材 %d）" % [recipe.name, recipe.cost]
	build_mode = false
	if ghost:
		ghost.visible = false

func _reset_run() -> void:
	for b in buildings:
		if is_instance_valid(b.node):
			b.node.queue_free()
	buildings.clear()
	inventory = {"food": 0, "water": 0, "wood": 0}
	pile = {"food": 0, "water": 0}
	berry_stock = BERRY_START_STOCK
	berry_regen = 0.0
	tree_stock = TREE_START_STOCK
	tree_regen = 0.0
	hunger = HUNGER_MAX
	thirst = THIRST_MAX
	hp = HP_MAX
	day_time = 0.0
	day_num = 1
	is_night = false
	collector_stock = 0
	collector_timer = 0.0
	slept_tonight = false
	build_mode = false
	if ghost:
		ghost.visible = false
	dead = false
	if dino:
		dino.position = Vector3(0, 0.1, 4)
	_flush_telemetry()
	interact_prompt = "新的开始。"
