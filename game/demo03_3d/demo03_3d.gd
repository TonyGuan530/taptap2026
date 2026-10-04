extends Node3D
## DEMO3 3D 迁移 阶段 A 灰模：斜俯视 3D 经营。
## 表现层只读 KingdomSimulation 状态与事件；经济/规则全部在模拟核心。
## 拾取：Camera3D 射线 → Area3D（槽位/村民，稳定 ID）；左键建设/升级/晋升。

const Sim := preload("res://demo03_3d/kingdom_simulation.gd")
const FONT := preload("res://fonts/NotoSansSC.ttf")
# v3（用户指令）：世界物体切换到 3d-shared 的 ComicObject/统一材质（场景应用层）
const ComicObj := preload("res://comic_style/comic_object.gd")
const StyleDef := preload("res://comic_style/comic_style.gd")
const ModelLib := preload("res://comic_style/model_library.gd")

const SLOT_POS: Array[Vector3] = [Vector3(-14, 0, -6), Vector3(0, 0, -6), Vector3(14, 0, -6)]
const RES_POS := Vector3(-20, 0, -4)   # v10 蓄水池场地
const HOUSE_POS: Array[Vector3] = [Vector3(-22, 0, 6), Vector3(-8, 0, 8), Vector3(8, 0, 7), Vector3(24, 0, 6)]
const PROF_TINT: Array[String] = ["#c9a227", "#7cbf6b", "#5a8fd0", "#d8d8d8"]
const PROF_COLORS := {
	"工程师": Color("c9a227"), "植物学家": Color("7cbf6b"),
	"气象学家": Color("5a8fd0"), "搬运工": Color("d8d8d8"),
}
const CAM_POS := Vector3(0, 30, 24)
const CAM_PITCH := -50.0
const CAM_SIZE := 26.0
# v5 风暴之夜视觉辨识（对齐 2D v14）：紫黑夜空常驻 + 环境细雨；
# 酸雨信息优先——酸雨紫主雨永远比细雨更亮更密，紫黑夜空不得吞掉它
const CLASSIC_BG := Color("2b1738")
const CLASSIC_AMB := Color("8a7a95")
const STORM_BG := Color("170b28")
const STORM_AMB := Color("5d5470")

var sim: KingdomSimulation
var cam: Camera3D
var rig: Node3D
var lava_mat: StandardMaterial3D
var rain: CPUParticles3D
var drizzle: CPUParticles3D
var env_node: WorldEnvironment
var tower_meshes: Array[MeshInstance3D] = []
var comic_towers: Array[Node3D] = []
var villager_nodes := {}   # id -> holder Node3D
var comic_villagers := {}  # id -> ComicObject
var comic_reservoir: Node3D
var style_def: Resource
var hud: CanvasLayer
var temp_fill: ColorRect
var water_label: Label
var time_label: Label
var phase_label: Label
var mode_label: Label
var banner_label: Label
var toast_box: VBoxContainer
var menu_layer: Control
var end_layer: Control
var end_title: Label
var end_body: Label
var end_log_label: Label
var toasts: Array[Dictionary] = []
var tooltip_label: Label
var cmd_button: Button


func _ready() -> void:
	sim = Sim.new()
	sim.sim_event.connect(_on_sim_event)
	style_def = StyleDef.new()
	_build_world()
	_build_hud()
	_show_menu()


## v3 场景应用：ComicObject 水塔（统一 toon+描边；L1 木桶塔 / L2 石基蓝罐）
func _build_tower_comic(slot: int, level: int) -> Node3D:
	if level <= 0:
		return null
	var sp: Vector3 = SLOT_POS[slot]
	var tower := ComicObj.new()
	tower.name = "ComicTower%d_L%d" % [slot, level]
	tower.interactive = true
	tower.style = style_def
	if level == 1:
		for dx: float in [-0.55, 0.55]:
			for dz: float in [-0.55, 0.55]:
				ModelLib._box(tower, Vector3(0.22, 1.6, 0.22), Vector3(dx, 0.8, dz), Color("5d4037"))
		ModelLib._cylinder(tower, 0.95, 1.05, 1.7, Vector3(0, 2.45, 0), Color("cf8958"))
		ModelLib._cylinder(tower, 1.0, 1.0, 0.22, Vector3(0, 2.45, 0), Color("4e6373"))
		ModelLib._box(tower, Vector3(0.18, 0.5, 0.18), Vector3(0.9, 2.2, 0), Color("4e6373"))
	else:
		ModelLib._box(tower, Vector3(2.4, 0.9, 2.4), Vector3(0, 0.45, 0), Color("b5b4aa"))
		for dx: float in [-0.8, 0.8]:
			for dz: float in [-0.8, 0.8]:
				ModelLib._box(tower, Vector3(0.26, 2.6, 0.26), Vector3(dx, 2.0, dz), Color("4e6373"))
		ModelLib._cylinder(tower, 1.25, 1.35, 2.6, Vector3(0, 4.6, 0), Color("4fc3f7"))
		ModelLib._cylinder(tower, 1.3, 1.3, 0.3, Vector3(0, 4.6, 0), Color("4e6373"))
		ModelLib._cylinder(tower, 0.2, 1.25, 0.5, Vector3(0, 6.1, 0), Color("4fc3f7"))
	add_child(tower)
	tower.position = sp
	return tower


## v10 蓄水池 ComicObject：未建=石圈虚位；建成=石池+水柱+立柱
func _build_reservoir_comic(built: bool) -> Node3D:
	var res := ComicObj.new()
	res.name = "ComicReservoir"
	res.interactive = true
	res.style = style_def
	if built:
		ModelLib._cylinder(res, 1.6, 1.8, 0.9, Vector3(0, 0.45, 0), Color("b5b4aa"))
		ModelLib._cylinder(res, 1.45, 1.45, 0.5, Vector3(0, 0.95, 0), Color("4fc3f7"))
		ModelLib._cylinder(res, 0.22, 1.45, 1.0, Vector3(0, 1.5, 0), Color("4e6373"))
	else:
		ModelLib._cylinder(res, 1.7, 1.9, 0.35, Vector3(0, 0.175, 0), Color("8b94a7"))
	add_child(res)
	res.position = RES_POS
	return res


func _update_reservoir_visual() -> void:
	if is_instance_valid(comic_reservoir):
		comic_reservoir.queue_free()
	comic_reservoir = _build_reservoir_comic(sim.reservoir == 1)


## v3 场景应用：ComicObject 小屋（静物，细描边）
func _build_house_comic(pos: Vector3, i: int) -> void:
	var house := ComicObj.new()
	house.name = "ComicHouse%d" % i
	house.interactive = false
	house.style = style_def
	ModelLib._box(house, Vector3(6, 4, 5.6), Vector3(0, 2, 0), Color("6d4c41"))
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(7.6, 3, 6.6)
	house.add_part(roof_mesh, Color("8d6e63"), Transform3D(Basis.IDENTITY, Vector3(0, 5.5, 0)))
	add_child(house)
	house.position = pos


# ---------------- 世界搭建（灰模几何体） ----------------

func _box(parent: Node3D, pos: Vector3, size: Vector3, col: Color, name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	mi.name = name
	parent.add_child(mi)
	return mi


func _build_world() -> void:
	# 地面
	_box(self, Vector3(0, -0.5, 4), Vector3(120, 1, 70), Color("3a2f28"), "Ground")
	# 岩浆（远景发光面）
	var lava := _box(self, Vector3(0, 0.2, -46), Vector3(150, 0.6, 26), Color("d84315"), "Lava")
	lava_mat = lava.material_override
	lava_mat.emission_enabled = true
	lava_mat.emission = Color("ff5722")
	lava_mat.emission_energy_multiplier = 1.2
	# 火山（锥体 + 火口辉光）
	var volcano := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 4.0
	cone.bottom_radius = 22.0
	cone.height = 26.0
	volcano.mesh = cone
	volcano.position = Vector3(-38, 13, -52)
	var vm := StandardMaterial3D.new()
	vm.albedo_color = Color("4a3038")
	volcano.material_override = vm
	add_child(volcano)
	var crater := _box(self, Vector3(-38, 26.5, -52), Vector3(5, 1.5, 5), Color("ff7043"), "Crater")
	crater.material_override.emission_enabled = true
	crater.material_override.emission = Color("ff5722")
	crater.material_override.emission_energy_multiplier = 2.0
	# 四座小屋（v3 场景应用：ComicObject 静物 + 暖窗发光特效）
	for i in HOUSE_POS.size():
		var hp: Vector3 = HOUSE_POS[i]
		_build_house_comic(hp, i)
		var win := _box(self, hp + Vector3(2.2, 2.4, 3.1), Vector3(1.6, 1.2, 0.1), Color("ffd54f"), "HouseWin%d" % i)
		win.material_override.emission_enabled = true
		win.material_override.emission = Color("ffd54f")
		win.material_override.emission_energy_multiplier = 1.5
	# 三个建设槽（底座 + 拾取体 + ComicObject 水塔 + Label3D）
	for i in SLOT_POS.size():
		var sp: Vector3 = SLOT_POS[i]
		var base := _box(self, sp + Vector3(0, 0.15, 0), Vector3(6, 0.3, 6), Color("8b94a7"), "SlotBase%d" % i)
		base.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		base.material_override.albedo_color = Color(1, 1, 1, 0.12)
		var body := StaticBody3D.new()
		body.position = sp + Vector3(0, 1.5, 0)
		body.collision_layer = 2
		body.set_meta("slot", i)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(6, 4, 6)
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		var tag := Label3D.new()
		tag.text = "槽位 %d\n建造 20水" % (i + 1)
		tag.font = FONT
		tag.font_size = 64
		tag.pixel_size = 0.005
		tag.position = sp + Vector3(0, 5.2, 3.4)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(tag)
		comic_towers.append(_build_tower_comic(i, 0))
	# v10 蓄水池场地（底座 + 拾取体 + 标签 + ComicObject）
	var rbase := _box(self, RES_POS + Vector3(0, 0.15, 0), Vector3(6, 0.3, 6), Color("8b94a7"), "ResBase")
	rbase.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rbase.material_override.albedo_color = Color(1, 1, 1, 0.12)
	var rbody := StaticBody3D.new()
	rbody.position = RES_POS + Vector3(0, 1.5, 0)
	rbody.collision_layer = 2
	rbody.set_meta("reservoir", true)
	var rshape := CollisionShape3D.new()
	var rbox := BoxShape3D.new()
	rbox.size = Vector3(6, 4, 6)
	rshape.shape = rbox
	rbody.add_child(rshape)
	add_child(rbody)
	var rtag := Label3D.new()
	rtag.text = "蓄水池\n建造 60水\n（酸雨时失效）"
	rtag.font = FONT
	rtag.font_size = 64
	rtag.pixel_size = 0.005
	rtag.position = RES_POS + Vector3(0, 5.0, 3.4)
	rtag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(rtag)
	_update_reservoir_visual()
	# 相机（正交斜俯视 + 操纵杆）
	rig = Node3D.new()
	rig.name = "CameraRig"
	add_child(rig)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAM_SIZE
	cam.position = CAM_POS
	cam.rotation_degrees = Vector3(CAM_PITCH, 0, 0)
	cam.current = true
	rig.add_child(cam)
	# 光照与环境
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = CLASSIC_BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = CLASSIC_AMB
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	env_node = env
	# 酸雨（紫色主雨，酸雨窗内；Compatibility 友好 CPU 粒子）
	rain = CPUParticles3D.new()
	rain.amount = 400
	rain.lifetime = 1.1
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(50, 1, 40)
	rain.position = Vector3(0, 22, 0)
	rain.direction = Vector3(-0.15, -1, 0)
	rain.spread = 2.0
	rain.gravity = Vector3(-2, -34, 0)
	rain.initial_velocity_min = 4.0
	rain.initial_velocity_max = 7.0
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.75, 0.55, 0.9, 0.55)
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain.mesh = QuadMesh.new()
	(rain.mesh as QuadMesh).size = Vector2(0.06, 1.1)
	rain.mesh.material = rmat
	rain.emitting = false
	add_child(rain)
	# v5 风暴环境细雨（灰蓝细线，更慢更淡；仅风暴模式常驻，酸雨时与主雨叠加显更密）
	drizzle = CPUParticles3D.new()
	drizzle.amount = 160
	drizzle.lifetime = 1.6
	drizzle.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drizzle.emission_box_extents = Vector3(50, 1, 40)
	drizzle.position = Vector3(0, 22, 0)
	drizzle.direction = Vector3(0.1, -1, 0)
	drizzle.spread = 2.0
	drizzle.gravity = Vector3(1, -16, 0)
	drizzle.initial_velocity_min = 2.0
	drizzle.initial_velocity_max = 3.5
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.72, 0.8, 0.95, 0.3)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drizzle.mesh = QuadMesh.new()
	(drizzle.mesh as QuadMesh).size = Vector2(0.04, 0.7)
	drizzle.mesh.material = dmat
	drizzle.emitting = false
	add_child(drizzle)


func _villager_visual(id: int, prof: String, x: float) -> void:
	var holder := Node3D.new()
	holder.name = "Villager%d" % id
	holder.position = Vector3(x * 0.055 - 21.0 + 21.0, 0, 9.0 + (id % 3) * 2.0)
	holder.set_meta("vx", holder.position.x)
	# v3 场景应用：村民 ComicObject 化（职业色身体+斗笠+水桶，统一 toon+描边）
	var prof_col: Color = PROF_COLORS.get(prof, Color("c9a227"))
	var villager := ComicObj.new()
	villager.name = "ComicVillager%d" % id
	villager.interactive = true
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.5
	body_mesh.height = 1.6
	villager.add_part(body_mesh, prof_col.darkened(0.15), Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0)))
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.34
	head_mesh.height = 0.68
	villager.add_part(head_mesh, Color("ffcc80"), Transform3D(Basis.IDENTITY, Vector3(0, 1.95, 0)))
	var hat_mesh := CylinderMesh.new()
	hat_mesh.top_radius = 0.12
	hat_mesh.bottom_radius = 0.52
	hat_mesh.height = 0.22
	villager.add_part(hat_mesh, Color("d9a441"), Transform3D(Basis.IDENTITY, Vector3(0, 2.3, 0)))
	var bucket_mesh := CylinderMesh.new()
	bucket_mesh.top_radius = 0.3
	bucket_mesh.bottom_radius = 0.24
	bucket_mesh.height = 0.55
	villager.add_part(bucket_mesh, Color("8d6e63"), Transform3D(Basis.IDENTITY, Vector3(0.62, 1.0, 0.1)))
	holder.add_child(villager)
	var area := Area3D.new()
	area.collision_layer = 4
	area.set_meta("villager", id)
	var cs := CollisionShape3D.new()
	var sp := CapsuleShape3D.new()
	sp.radius = 0.9
	sp.height = 2.6
	cs.shape = sp
	area.add_child(cs)
	holder.add_child(area)
	var tag := Label3D.new()
	tag.text = "%s·%s" % [sim.NPC_NAMES[id % sim.NPC_NAMES.size()], prof]
	tag.font = FONT
	tag.font_size = 56
	tag.pixel_size = 0.005
	tag.position = Vector3(0, 3.1, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	holder.add_child(tag)
	add_child(holder)
	villager_nodes[id] = holder
	comic_villagers[id] = villager


## v3 场景应用：水塔 ComicObject 化（L1 木桶塔 / L2 石基大罐，统一 toon+描边）
func _update_tower_visual(slot: int) -> void:
	var lv: int = sim.towers[slot]
	var old := comic_towers[slot]
	if is_instance_valid(old):
		old.queue_free()
	comic_towers[slot] = _build_tower_comic(slot, lv)


# ---------------- HUD ----------------

func _label(parent: Node, pos: Vector2, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _button(parent: Node, pos: Vector2, size: Vector2, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	# 对局 HUD
	temp_fill = ColorRect.new()
	temp_fill.color = Color("66bb6a")
	temp_fill.position = Vector2(320, 16)
	temp_fill.size = Vector2(0, 20)
	hud.add_child(temp_fill)
	var temp_bg := ColorRect.new()
	temp_bg.color = Color(0, 0, 0, 0.55)
	temp_bg.position = Vector2(316, 12)
	temp_bg.size = Vector2(328, 28)
	temp_bg.z_index = -1
	hud.add_child(temp_bg)
	water_label = _label(hud, Vector2(20, 14), "水 0", 22, Color("4fc3f7"))
	time_label = _label(hud, Vector2(870, 16), "0/60 秒", 18, Color("e8ecf4"))
	phase_label = _label(hud, Vector2(700, 44), "阶段：初火", 18, Color("aed581"))
	mode_label = _label(hud, Vector2(20, 44), "经典 60 秒", 15, Color("9fb3c8"))
	banner_label = _label(hud, Vector2(200, 44), "", 18, Color("ce93d8"))
	# v2 悬停提示（阶段 B：悬停显示目标名称/价格/当前效果）
	tooltip_label = _label(hud, Vector2(0, 0), "", 15, Color("fff3c4"))
	tooltip_label.visible = false
	# v4 灭火指挥（主动技能按钮，快捷键 F）
	cmd_button = _button(hud, Vector2(20, 470), Vector2(220, 46), "灭火指挥 25水（F）",
			func() -> void: _try_command_ui())
	cmd_button.disabled = true
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(340, 84)
	toast_box.size = Vector2(300, 120)
	hud.add_child(toast_box)
	# 菜单
	menu_layer = Control.new()
	menu_layer.visible = false
	hud.add_child(menu_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = Vector2(960, 540)
	menu_layer.add_child(dim)
	_label(menu_layer, Vector2(300, 150), "岩浆降温的小人国度", 40, Color("ffd54f"))
	_label(menu_layer, Vector2(268, 230), "温度不断攀升，建造浇水设施、带领村民，撑过 60 秒！", 18, Color("e8ecf4"))
	_button(menu_layer, Vector2(300, 300), Vector2(170, 50), "经典 60 秒",
			func() -> void: _start("classic"))
	_button(menu_layer, Vector2(490, 300), Vector2(170, 50), "风暴之夜（实验）",
			func() -> void: _start("storm"))
	_button(menu_layer, Vector2(680, 300), Vector2(170, 50), "寒夜守卫（第 2 章）",
			func() -> void: _start("hard"))
	_label(menu_layer, Vector2(150, 380), "左键：槽位建造/升级 · 村民晋升 · 蓄水池（60水，酸雨时失效）｜F：灭火指挥（25水 全队应急降温）", 14, Color("9fb3c8"))
	_label(menu_layer, Vector2(300, 404), "滚轮缩放，Q/E 旋转，Home 复位", 13, Color("9fb3c8"))
	# 结算（v7：含本局消费遥测时间线 + 一键复制，服务真人盲测采集）
	end_layer = Control.new()
	end_layer.visible = false
	hud.add_child(end_layer)
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.62)
	panel.position = Vector2(240, 150)
	panel.size = Vector2(480, 210)
	end_layer.add_child(panel)
	end_title = _label(end_layer, Vector2(280, 165), "", 30, Color("66bb6a"))
	end_body = _label(end_layer, Vector2(280, 215), "", 15, Color("e8ecf4"))
	_button(end_layer, Vector2(280, 268), Vector2(150, 40), "再守一次",
			func() -> void:
				_start(sim.mode))
	_button(end_layer, Vector2(450, 268), Vector2(120, 40), "选模式",
			func() -> void: _show_menu())
	_button(end_layer, Vector2(590, 268), Vector2(120, 40), "复制记录",
			func() -> void:
				DisplayServer.clipboard_set(end_log_label.text)
				_toast("已复制本局记录", Color("a5d6a7")))
	var log_bg := ColorRect.new()
	log_bg.color = Color(0, 0, 0, 0.5)
	log_bg.position = Vector2(240, 316)
	log_bg.size = Vector2(480, 150)
	end_layer.add_child(log_bg)
	end_log_label = _label(end_layer, Vector2(250, 322), "", 12, Color("cfd8dc"))


func _toast(text: String, col: Color) -> void:
	var l := _label(toast_box, Vector2.ZERO, text, 15, col)
	toasts.append({"label": l, "age": 0.0})


func mode_name(p_mode: String) -> String:
	if p_mode == "storm":
		return "风暴之夜"
	if p_mode == "hard":
		return "寒夜守卫"
	return "经典 60 秒"


## v7 结算遥测：spend_log → 可读时间线（晴/雨 天气上下文 + 总结行），供真人盲测采集
func _format_spend_log() -> String:
	var kind_names := {"build": "建造", "upgrade": "升级", "promote": "晋升", "command": "灭火指挥", "reservoir": "蓄水池"}
	var lines: Array[String] = []
	for rec: Dictionary in sim.spend_log:
		var t: float = float(rec.t)
		var weather := "雨" if sim.acid_at(t) else "晴"
		lines.append("[%5.1fs] %s %s %d水" % [t, weather, str(kind_names.get(str(rec.kind), str(rec.kind))), int(rec.amount)])
	var result := "败" if sim.round_state == "lose" else ("胜" if sim.round_state == "win" else "—")
	lines.append("── %s · %s · 终温 %d · 水滴 %d · 消费 %d 笔" % [
		mode_name(sim.mode), result, int(sim.heat), int(sim.water), sim.spend_log.size()])
	return "\n".join(lines)


## v4 灭火指挥入口（按钮/F 键共用）：成功/冷却中/缺水分支提示
func _try_command_ui() -> void:
	if sim.try_command():
		_toast("灭火指挥！全队降温 +1.5/s（8 秒）", Color("81d4fa"))
	elif not sim.cmd_ready():
		_toast("灭火指挥冷却中…（还差 %.0f 秒）" % maxf(0.0, sim.cmd_ready_at - sim.elapsed), Color("ef9a9a"))
	else:
		_toast("灭火指挥需要 %d水" % sim.CMD_COST, Color("ef9a9a"))


# ---------------- 状态机 ----------------

func _start(p_mode: String) -> void:
	sim.setup_round(p_mode)
	for v: Node3D in villager_nodes.values():
		v.queue_free()
	villager_nodes.clear()
	for i in comic_towers.size():
		_update_tower_visual(i)
	_update_reservoir_visual()
	comic_villagers.clear()
	rain.emitting = false
	menu_layer.visible = false
	end_layer.visible = false
	banner_label.text = ""
	mode_label.text = "经典 60 秒"
	if p_mode == "storm":
		mode_label.text = "风暴之夜（实验）"
	elif p_mode == "hard":
		mode_label.text = "寒夜守卫（第 2 章）"
	toasts.clear()
	for c: Node in toast_box.get_children():
		c.queue_free()


func _show_menu() -> void:
	sim.round_state = "menu"
	menu_layer.visible = true
	end_layer.visible = false


func _on_sim_event(kind: String, p: Dictionary) -> void:
	match kind:
		"built":
			_update_tower_visual(int(p.slot))
		"upgraded":
			_update_tower_visual(int(p.slot))
		"villager_joined":
			_villager_visual(int(p.id), str(p.prof), 480.0)
			_toast("村民 %s 加入！" % str(p.id), Color("a5d6a7"))
		"acid_warn":
			banner_label.text = "【酸雨将至】——先想好水滴花在哪！"
			banner_label.add_theme_color_override("font_color", Color("efc3f5"))
		"acid_started":
			banner_label.text = "【酸雨中】：设施降温 ×0.6 · 村民降温 ×1.5"
		"acid_ended":
			banner_label.text = "【雨停】！设施恢复 · 村民回落"
			banner_label.add_theme_color_override("font_color", Color("90caf9"))
		"reservoir_built":
			_update_reservoir_visual()
			_toast("蓄水池建成！（酸雨时失效，注意时机）", Color("81d4fa"))
		"command_started":
			banner_label.text = "【灭火指挥】！全员应急降温 +1.5/s（不受酸雨影响）"
			banner_label.add_theme_color_override("font_color", Color("81d4fa"))
		"command_ended":
			if String(banner_label.text).begins_with("【灭火指挥】"):
				banner_label.text = ""
		"round_ended":
			end_layer.visible = true
			end_log_label.text = _format_spend_log()
			if bool(p.win):
				end_title.text = "国度守住了！"
				end_title.add_theme_color_override("font_color", Color("66bb6a"))
				end_body.text = "60 秒过去，岩浆退了回去。\n剩余温度 %d 度 · 村民 %d 位 · 水滴 %d" % [
					int(sim.heat), sim.villagers.size(), int(sim.water)]
			else:
				end_title.text = "岩浆吞没了国度……"
				end_title.add_theme_color_override("font_color", Color("ef5350"))
				end_body.text = "坚持了 %d 秒（%s）。\n提示：开局建塔，酸雨时优先投资村民！" % [
					int(sim.elapsed), str(sim.phase().name)]


# ---------------- 输入（真实射线拾取） ----------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.size = clampf(cam.size - 2.0, 14.0, 40.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.size = clampf(cam.size + 2.0, 14.0, 40.0)
		elif event.button_index == MOUSE_BUTTON_LEFT and sim.round_state == "play":
			_pick(event.position)
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F and sim.round_state == "play":
		_try_command_ui()


## v3 悬停代理：射线命中拾取体 → 对应 ComicObject 高亮（统一 toon 描边反馈）
func _update_hover_proxy() -> void:
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var hover_slot := -1
	var hover_villager := -1
	var hover_res := false
	if not hit.is_empty() and hit.collider.has_meta("slot"):
		hover_slot = int(hit.collider.get_meta("slot"))
	elif not hit.is_empty() and hit.collider.has_meta("villager"):
		hover_villager = int(hit.collider.get_meta("villager"))
	elif not hit.is_empty() and hit.collider.has_meta("reservoir"):
		hover_res = true
	for i in comic_towers.size():
		var t: Node3D = comic_towers[i]
		if is_instance_valid(t):
			t.set_hovered(i == hover_slot and sim.towers[i] > 0)
	if is_instance_valid(comic_reservoir):
		comic_reservoir.set_hovered(hover_res and sim.reservoir == 1)
	for id: int in comic_villagers:
		var v: Node3D = comic_villagers[id]
		if is_instance_valid(v):
			v.set_hovered(id == hover_villager)

## v2 悬停提示：指针下目标的名称/价格/当前效果（阶段 B 清单项）
func _update_tooltip(mouse: Vector2) -> void:
	if sim.round_state != "play":
		tooltip_label.visible = false
		return
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var text := ""
	if not hit.is_empty():
		var col: Object = hit.collider
		if col.has_meta("reservoir"):
			if sim.reservoir == 0:
				text = "蓄水池：建造 %d水（降温 4.5/s，酸雨时失效）" % sim.RESERVOIR_COST
			else:
				text = "蓄水池：已建成（酸雨时失效）"
		elif col.has_meta("slot"):
			var slot := int(col.get_meta("slot"))
			var lv: int = sim.towers[slot]
			if lv == 0:
				text = "槽位 %d：建造 %d水（降温 2.0/s）" % [slot + 1, sim.build_cost()]
			elif lv == 1:
				text = "槽位 %d：升级 %d水（降温 2.0→5.0/s）" % [slot + 1, sim.upgrade_cost()]
			else:
				text = "槽位 %d：II 级已满（降温 5.0/s）" % (slot + 1)
		elif col.has_meta("villager"):
			for n: Dictionary in sim.villagers:
				if n.id == int(col.get_meta("villager")):
					var bonus: float = float(sim.prof_info(str(n.prof)).cool_bonus)
					if n.level == 0:
						text = "%s·%s：晋升 %d水（降温 +%.1f/s）" % [str(n.name), str(n.prof), sim.NPC_UP_COST, sim.NPC_UP_COOL]
					else:
						text = "%s·%s：已晋升（降温 +%.1f/s）" % [str(n.name), str(n.prof), sim.NPC_UP_COOL]
					if bonus > 0.0:
						text += " · 额外 +%.1f/s" % bonus
					break
	if text != "":
		tooltip_label.text = text
		tooltip_label.position = mouse + Vector2(14, 10)
		tooltip_label.visible = true
	else:
		tooltip_label.visible = false


func _pick(screen_pos: Vector2) -> void:
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var col: Object = hit.collider
	if col.has_meta("reservoir"):
		if not sim.try_build_reservoir():
			_toast("蓄水池需要 %d水，或已建造" % sim.RESERVOIR_COST, Color("ef9a9a"))
	elif col.has_meta("slot"):
		var slot := int(col.get_meta("slot"))
		var lv: int = sim.towers[slot]
		var ok := sim.try_upgrade(slot) if lv == 1 else sim.try_build(slot)
		if not ok:
			_toast("水滴不够（需要 %d水）" % (sim.upgrade_cost() if lv == 1 else sim.build_cost()), Color("ef9a9a"))
	elif col.has_meta("villager"):
		var id := int(col.get_meta("villager"))
		if not sim.try_promote(id):
			_toast("晋升需要 30水 或已晋升", Color("ef9a9a"))


# ---------------- 每帧 ----------------

func _process(delta: float) -> void:
	sim.tick(delta)
	# 相机操控（Q/E 旋转，Home 复位）
	var rot := 0.0
	if Input.is_key_pressed(KEY_Q):
		rot += 1.2 * delta
	if Input.is_key_pressed(KEY_E):
		rot -= 1.2 * delta
	rig.rotation.y += rot
	if Input.is_key_pressed(KEY_HOME):
		rig.rotation.y = 0.0
		cam.size = CAM_SIZE
	# HUD 更新
	temp_fill.size.x = 320.0 * clampf(sim.heat / 100.0, 0.0, 1.0)
	temp_fill.color = Color("66bb6a").lerp(Color("ef5350"), clampf(sim.heat / 100.0, 0.0, 1.0))
	water_label.text = "水 %d" % int(sim.water)
	time_label.text = "%d/60 秒" % int(sim.elapsed)
	var ph := sim.phase()
	phase_label.text = "阶段：%s" % str(ph.name)
	phase_label.add_theme_color_override("font_color", Color(str(ph.col)))
	# v4 灭火指挥按钮状态（生效中/冷却/可用水滴三态）
	if sim.round_state == "play" and sim.cmd_active():
		cmd_button.text = "灭火中 %.0fs" % maxf(0.0, sim.cmd_until - sim.elapsed)
		cmd_button.disabled = true
	elif sim.round_state == "play" and not sim.cmd_ready():
		cmd_button.text = "灭火指挥 冷却 %.0fs" % maxf(0.0, sim.cmd_ready_at - sim.elapsed)
		cmd_button.disabled = true
	elif sim.round_state == "play":
		cmd_button.text = "灭火指挥 %d水（F）" % sim.CMD_COST
		cmd_button.disabled = sim.water < float(sim.CMD_COST)
	else:
		cmd_button.disabled = true
	# 村民表现走动（只读展示）
	for id: int in villager_nodes:
		var holder := villager_nodes[id] as Node3D
		var vx: float = float(holder.get_meta("vx"))
		holder.position.x = vx + sin((sim.elapsed + float(id)) * 1.3) * 2.0
	# v5 天气表现（只读模拟状态；_process 为唯一驱动）：
	# 风暴模式常驻紫黑夜空+环境细雨；酸雨紫色主雨只在窗内，两模式一致（酸雨信息优先）
	var env := env_node.environment
	var storm_on := sim.round_state == "play" and sim.mode == "storm"
	env.background_color = env.background_color.lerp(STORM_BG if storm_on else CLASSIC_BG, minf(3.0 * delta, 1.0))
	env.ambient_light_color = env.ambient_light_color.lerp(STORM_AMB if storm_on else CLASSIC_AMB, minf(3.0 * delta, 1.0))
	drizzle.emitting = storm_on
	rain.emitting = sim.round_state == "play" and sim.acid_active()
	_update_hover_proxy()
	_update_tooltip(get_viewport().get_mouse_position())
	# toast 淡出
	for i in range(toasts.size() - 1, -1, -1):
		var t: Dictionary = toasts[i]
		t.age += delta
		var l := t.label as Label
		l.modulate.a = clampf(2.0 - float(t.age), 0.0, 1.0)
		if float(t.age) > 2.0:
			l.queue_free()
			toasts.remove_at(i)
