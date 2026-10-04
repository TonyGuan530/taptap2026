extends Node3D
## DEMO4 3D 阶段 A：灰模 L1「裂谷长跑」+ 能力基线。
## 布局按 100px≈1m 从 2D LEVELS[0] 换算；X 向东为前进方向，Y 向上。
## 全程序化构建（灰盒几何 + 程序 HUD），不依赖场景内手摆节点。

const PLAYER_SCRIPT := preload("res://demo04_3d/player.gd")
const CAMERA_SCRIPT := preload("res://demo04_3d/camera_rig.gd")
const ABILITY_SCRIPT := preload("res://demo04_3d/ability_state.gd")
const ComicObjectScript := preload("res://comic_style/comic_object.gd")
const ModelLibrary := preload("res://comic_style/model_library.gd")

const ALIENS := [
	{"id": "highjump", "name": "蹦蹦兽", "pos": Vector3(6.2, 0.8, 0)},
	{"id": "double", "name": "双翼虫", "pos": Vector3(15.0, 0.8, 0)},
	{"id": "glow", "name": "灯灯菌", "pos": Vector3(23.8, 0.8, 0)},
]
const SHARDS := [Vector3(10.3, 1.6, 0), Vector3(18.0, 1.2, 0), Vector3(27.5, 1.2, 0)]
const DARK_MIN_X := 23.4
const DARK_MAX_X := 36.0
const GOAL_X := 31.0
const ML_COL := preload("res://comic_style/model_library.gd").COLORS

var ability: Node
var player: CharacterBody3D
var cam_rig: Node3D
var elapsed := 0.0
var won := false

var lbl_dna: Label
var lbl_stat: Label
var lbl_fuse: Label
var lbl_dark: Label
var lbl_combo: Label
var win_panel: Panel
var lbl_win: Label

var alien_nodes: Dictionary = {}
var shard_nodes: Array = []
var _fuse_target: Dictionary = {}

func _ready() -> void:
	ability = Node.new()
	ability.name = "AbilityState"
	ability.set_script(ABILITY_SCRIPT)
	add_child(ability)

	_build_hud()
	_build_level()

	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col.shape = capsule
	player.add_child(col)
	player.position = Vector3(1.0, 1.2, 0)
	var vis := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.35
	capsule_mesh.height = 1.5
	vis.mesh = capsule_mesh
	vis.position = Vector3(0, 0.1, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.88, 1.0)
	vis.material_override = mat
	player.add_child(vis)
	add_child(player)
	player.ability_state = ability
	player.fused.connect(_on_fuse_request)

	cam_rig = Node3D.new()
	cam_rig.name = "CameraRig"
	cam_rig.set_script(CAMERA_SCRIPT)
	cam_rig.excluded_body = player
	add_child(cam_rig)
	cam_rig.position = player.position

	ability.dna_gained.connect(_on_dna_gained)
	ability.combo_discovered.connect(_on_combo_discovered)
	ability.shards_changed.connect(_on_shards_changed)
	_refresh_hud()

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var root_c := Control.new()
	root_c.name = "Root"
	root_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root_c)
	lbl_dna = _mk_label(root_c, 24, 16, 18, Color(0.31, 0.76, 0.94))
	lbl_stat = _mk_label(root_c, 24, 44, 15, Color(0.85, 0.9, 0.95))
	lbl_fuse = _mk_label(root_c, 24, 70, 16, Color(1, 0.85, 0.4))
	lbl_fuse.visible = false
	lbl_dark = _mk_label(root_c, 24, 96, 15, Color(1, 0.55, 0.4))
	lbl_dark.text = "黑暗中……没有荧光寸步难行"
	lbl_dark.visible = false
	lbl_combo = _mk_label(root_c, 24, 122, 18, Color(0.5, 1, 0.6))
	lbl_combo.visible = false
	win_panel = Panel.new()
	win_panel.name = "WinPanel"
	win_panel.position = Vector2(240, 200)
	win_panel.size = Vector2(500, 170)
	win_panel.visible = false
	root_c.add_child(win_panel)
	lbl_win = _mk_label(win_panel, 20, 30, 19, Color(0.9, 0.95, 1))
	lbl_win.name = "WinText"

func _mk_label(parent: Control, x: float, y: float, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = Vector2(x, y)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _build_level() -> void:
	# 灯光：主平行光 + 环境光（灰盒可读性）
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.4, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.45, 0.55)
	e.ambient_light_energy = 1.0
	env.environment = e
	add_child(env)

	# 地面/墙/坑（按 2D LEVELS[0] 正确换算：墙顶 1.8m、坑 3m）
	_comic_box(Vector3(5.0, -0.5, 0), Vector3(10.0, 1.0, 10.0), ML_COL.stone)   # x 0..10
	_comic_box(Vector3(10.3, 0.9, 0), Vector3(0.6, 1.8, 3.0), ML_COL.iron_dark)          # 教学墙：顶 1.8（高跳 2.27 可越）
	_comic_box(Vector3(13.5, -0.5, 0), Vector3(7.0, 1.0, 10.0), ML_COL.stone)   # x 10..17
	_comic_box(Vector3(22.5, -0.5, 0), Vector3(7.0, 1.0, 10.0), ML_COL.stone)   # x 19..26（沟 17..19）
	_comic_box(Vector3(30.75, -0.5, 0), Vector3(3.5, 1.0, 10.0), ML_COL.stone)  # x 29..32.5（暗区坑 26..29）
	_comic_box(Vector3(31.0, 1.0, 0), Vector3(1.6, 2.0, 1.6), ML_COL.iron)               # 逃生舱

	# 融合来源
	for a in ALIENS:
		var area := Area3D.new()
		area.name = "Alien_" + a.id
		area.position = a.pos
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.2
		cs.shape = sph
		area.add_child(cs)
		add_child(area)
		alien_nodes[a.id] = area
		var vis := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.7, 0.7, 0.7)
		vis.mesh = mesh
		vis.position = a.pos
		var mat := StandardMaterial3D.new()
		mat.albedo_color = a.col if a.has("col") else Color(0.6, 0.4, 0.8)
		vis.material_override = mat
		add_child(vis)
		var lbl := Label3D.new()
		lbl.text = a.name
		lbl.font_size = 40
		lbl.position = a.pos + Vector3(0, 1.0, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(lbl)

	# 碎片
	for spos in SHARDS:
		var area2 := Area3D.new()
		area2.position = spos
		var cs2 := CollisionShape3D.new()
		var sph2 := SphereShape3D.new()
		sph2.radius = 0.7
		cs2.shape = sph2
		area2.add_child(cs2)
		add_child(area2)
		shard_nodes.append(area2)
		var vis2 := MeshInstance3D.new()
		var mesh2 := BoxMesh.new()
		mesh2.size = Vector3(0.25, 0.35, 0.25)
		vis2.mesh = mesh2
		vis2.position = spos
		var mat2 := StandardMaterial3D.new()
		mat2.albedo_color = Color(0.4, 1.0, 0.55)
		mat2.emission_enabled = true
		mat2.emission = Color(0.2, 0.8, 0.35)
		vis2.material_override = mat2
		add_child(vis2)

	# 暗区 Area（速度惩罚由 in_dark 每帧生效；此 Area 仅为语义标记）
	var dark := Area3D.new()
	dark.name = "DarkZone"
	var dcs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(DARK_MAX_X - DARK_MIN_X, 8.0, 10.0)
	dcs.shape = box
	dark.position = Vector3((DARK_MIN_X + DARK_MAX_X) / 2.0, 4.0, 0)
	dark.add_child(dcs)
	add_child(dark)

	# 终点
	var goal := Area3D.new()
	goal.name = "Goal"
	var gcs := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(1.0, 3.0, 4.0)
	gcs.shape = gbox
	goal.position = Vector3(GOAL_X, 1.5, 0)
	goal.add_child(gcs)
	add_child(goal)
	goal.body_entered.connect(_on_goal_entered)

func _comic_box(pos: Vector3, size: Vector3, color: Color) -> void:
	## 世界物体统一走 ComicObject（粗描边+漫画材质）；碰撞体独立，不随视觉变化
	var obj := ComicObjectScript.new()
	obj.name = "World"
	obj.position = pos
	add_child(obj)
	obj.add_part(BoxMesh.new(), color, Transform3D.IDENTITY)
	obj.scale = size
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.position = pos
	body.add_child(cs)
	add_child(body)

func _physics_process(delta: float) -> void:
	if won or player == null:
		return
	elapsed += delta
	var in_dark := player.position.x > DARK_MIN_X and player.position.x < DARK_MAX_X
	player.in_dark_zone = in_dark
	lbl_dark.visible = in_dark and not ability.has_dna("glow")
	_update_fuse_candidate()
	if int(elapsed * 10.0) % 5 == 0:
		_refresh_hud()
	# 相机跟随
	cam_rig.position = cam_rig.position.lerp(player.position, minf(1.0, delta * 8.0))
	cam_rig.position.y = maxf(cam_rig.position.y, player.position.y + 0.5)

func _update_fuse_candidate() -> void:
	_fuse_target = {}
	if ability.dna.size() >= ALIENS.size():
		return
	var best := {}
	for a in ALIENS:
		if ability.has_dna(a.id):
			continue
		if not alien_nodes.has(a.id):
			continue
		var d: float = player.position.distance_to(alien_nodes[a.id].position)
		if d < 1.2 and (best.is_empty() or d < best.d):
			best = {"id": a.id, "name": a.name, "d": d}
	_fuse_target = best

func _on_fuse_request() -> void:
	if _fuse_target.is_empty():
		return
	ability.gain_dna(_fuse_target.id)

func _on_dna_gained(_id: String) -> void:
	if ability.has_dna("glow"):
		var has_light := false
		for c in player.get_children():
			if c is OmniLight3D:
				has_light = true
		if not has_light:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.95, 0.6)
			light.light_energy = 2.5
			light.omni_range = 7.0
			light.position = Vector3(0, 0.5, 0)
			player.add_child(light)
	_refresh_hud()

func _on_combo_discovered(id: String) -> void:
	lbl_combo.text = "组合发现：%s" % ("超级弹跳" if id == "superjump" else "夜翼")
	lbl_combo.visible = true
	_refresh_hud()

func _on_shards_changed(_count: int, _total: int) -> void:
	_refresh_hud()

func _on_goal_entered(body: Node3D) -> void:
	if won or body != player:   # 只认玩家进入；过滤静态体（逃生舱自身碰撞盒等）
		return
	won = true
	win_panel.visible = true
	lbl_win.text = "逃脱成功！用时 %d 秒 · 碎片 %d · DNA %d 种" % [int(elapsed), ability.shards_level, ability.dna.size()]
	player.input_enabled = false

func _refresh_hud() -> void:
	var dna_names: Array = ability.dna_names()
	var combo_names := []
	if ability.combos_found.has("superjump"):
		combo_names.append("超级弹跳")
	if ability.combos_found.has("nightwing"):
		combo_names.append("夜翼")
	var combo_txt: String = ("（组合：" + "、".join(combo_names) + "）") if combo_names.size() > 0 else ""
	lbl_dna.text = "DNA：" + (("已融合 " + " + ".join(dna_names) + " " + combo_txt) if dna_names.size() > 0 else "无（找到外星生物，按 E 融合）")
	lbl_stat.text = "基因碎片 %d · 用时 %d 秒" % [ability.shards_level, int(elapsed)]
	if not _fuse_target.is_empty():
		lbl_fuse.text = "按 E 与 %s 融合" % _fuse_target.name
		lbl_fuse.visible = true
	else:
		lbl_fuse.visible = false
