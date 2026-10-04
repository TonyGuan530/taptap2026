extends Node3D
## DEMO3 3D 迁移 阶段 A 灰模：斜俯视 3D 经营。
## 表现层只读 KingdomSimulation 状态与事件；经济/规则全部在模拟核心。
## 拾取：Camera3D 射线 → Area3D（槽位/村民，稳定 ID）；左键建设/升级/晋升。

const Sim := preload("res://demo03_3d/kingdom_simulation.gd")
const FONT := preload("res://fonts/NotoSansSC.ttf")

const SLOT_POS: Array[Vector3] = [Vector3(-14, 0, -6), Vector3(0, 0, -6), Vector3(14, 0, -6)]
const HOUSE_POS: Array[Vector3] = [Vector3(-22, 0, 6), Vector3(-8, 0, 8), Vector3(8, 0, 7), Vector3(24, 0, 6)]
const PROF_TINT: Array[String] = ["#c9a227", "#7cbf6b", "#5a8fd0", "#d8d8d8"]
const CAM_POS := Vector3(0, 30, 24)
const CAM_PITCH := -50.0
const CAM_SIZE := 26.0

var sim: KingdomSimulation
var cam: Camera3D
var rig: Node3D
var lava_mat: StandardMaterial3D
var rain: CPUParticles3D
var tower_meshes: Array[MeshInstance3D] = []
var villager_nodes := {}   # id -> Node3D
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
var toasts: Array[Dictionary] = []


func _ready() -> void:
	sim = Sim.new()
	sim.sim_event.connect(_on_sim_event)
	_build_world()
	_build_hud()
	_show_menu()


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
	# 四座小屋（物件；墙+顶+暖窗）
	for i in HOUSE_POS.size():
		var hp: Vector3 = HOUSE_POS[i]
		var body := _box(self, hp + Vector3(0, 2, 0), Vector3(7, 4, 6), Color("5d4037"), "HouseBody%d" % i)
		body.name = "House%d" % i
		var roof := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(7.6, 3, 6.6)
		roof.mesh = pm
		roof.position = hp + Vector3(0, 5.5, 0)
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color("8d6e63")
		roof.material_override = rm
		add_child(roof)
		var win := _box(self, hp + Vector3(2.2, 2.4, 3.1), Vector3(1.6, 1.2, 0.1), Color("ffd54f"), "HouseWin%d" % i)
		win.material_override.emission_enabled = true
		win.material_override.emission = Color("ffd54f")
		win.material_override.emission_energy_multiplier = 1.5
	# 三个建设槽（底座 + 拾取体 + 等级塔体 + Label3D）
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
		var tower := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(2.4, 6, 2.4)
		tower.mesh = tm
		tower.position = sp + Vector3(0, 3, 0)
		var twm := StandardMaterial3D.new()
		twm.albedo_color = Color("4fc3f7")
		tower.material_override = twm
		tower.visible = false
		tower.name = "Tower%d" % i
		add_child(tower)
		tower_meshes.append(tower)
		var tag := Label3D.new()
		tag.text = "槽位 %d\n建造 20💧" % (i + 1)
		tag.font = FONT
		tag.font_size = 64
		tag.pixel_size = 0.005
		tag.position = sp + Vector3(0, 5.2, 3.4)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(tag)
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
	e.background_color = Color("2b1738")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a7a95")
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	# 雨（CPU 粒子，Compatibility 友好）
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


func _villager_visual(id: int, prof: String, x: float) -> void:
	var holder := Node3D.new()
	holder.name = "Villager%d" % id
	holder.position = Vector3(x * 0.055 - 21.0 + 21.0, 0, 9.0 + (id % 3) * 2.0)
	holder.set_meta("vx", holder.position.x)
	var ci := 0
	for p: Dictionary in sim.PROFS:
		if p.name == prof:
			break
		ci += 1
	var col := Color(PROF_TINT[ci % PROF_TINT.size()])
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.55
	cap.height = 2.2
	body.mesh = cap
	body.position = Vector3(0, 1.2, 0)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = col
	body.material_override = bm
	holder.add_child(body)
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


func _update_tower_visual(slot: int) -> void:
	var lv: int = sim.towers[slot]
	var mi := tower_meshes[slot]
	mi.visible = lv > 0
	var mesh := mi.mesh as BoxMesh
	var mat := mi.material_override as StandardMaterial3D
	if lv == 1:
		mesh.size = Vector3(2.2, 7, 2.2)
		mi.position.y = SLOT_POS[slot].y + 3.5
		mat.albedo_color = Color("4fc3f7")
	elif lv == 2:
		mesh.size = Vector3(3.0, 11, 3.0)
		mi.position.y = SLOT_POS[slot].y + 5.5
		mat.albedo_color = Color("0288d1")


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
	water_label = _label(hud, Vector2(20, 14), "💧 0", 22, Color("4fc3f7"))
	time_label = _label(hud, Vector2(870, 16), "⏱ 0/60", 18, Color("e8ecf4"))
	phase_label = _label(hud, Vector2(700, 44), "阶段：初火", 18, Color("aed581"))
	mode_label = _label(hud, Vector2(20, 44), "经典 60 秒", 15, Color("9fb3c8"))
	banner_label = _label(hud, Vector2(200, 44), "", 18, Color("ce93d8"))
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
	_label(menu_layer, Vector2(240, 380), "左键：点槽位建造/升级，点村民晋升｜滚轮缩放，Q/E 旋转，Home 复位", 14, Color("9fb3c8"))
	# 结算
	end_layer = Control.new()
	end_layer.visible = false
	hud.add_child(end_layer)
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.62)
	panel.position = Vector2(240, 170)
	panel.size = Vector2(480, 200)
	end_layer.add_child(panel)
	end_title = _label(end_layer, Vector2(280, 190), "", 30, Color("66bb6a"))
	end_body = _label(end_layer, Vector2(280, 240), "", 16, Color("e8ecf4"))
	_button(end_layer, Vector2(280, 310), Vector2(150, 42), "再守一次",
			func() -> void:
				_start(sim.mode))
	_button(end_layer, Vector2(450, 310), Vector2(120, 42), "选模式",
			func() -> void: _show_menu())


func _toast(text: String, col: Color) -> void:
	var l := _label(toast_box, Vector2.ZERO, text, 15, col)
	toasts.append({"label": l, "age": 0.0})


# ---------------- 状态机 ----------------

func _start(p_mode: String) -> void:
	sim.setup_round(p_mode)
	for v: Node3D in villager_nodes.values():
		v.queue_free()
	villager_nodes.clear()
	for i in tower_meshes.size():
		tower_meshes[i].visible = false
	rain.emitting = false
	menu_layer.visible = false
	end_layer.visible = false
	mode_label.text = "风暴之夜（实验）" if p_mode == "storm" else "经典 60 秒"
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
			banner_label.text = "☔ 酸雨将至——先想好水滴花在哪！"
			banner_label.add_theme_color_override("font_color", Color("efc3f5"))
		"acid_started":
			rain.emitting = true
			banner_label.text = "☔ 酸雨中：设施降温 ×0.6 · 村民降温 ×1.5"
		"acid_ended":
			rain.emitting = false
			banner_label.text = "☀ 酸雨过了！设施恢复 · 村民回落"
			banner_label.add_theme_color_override("font_color", Color("90caf9"))
		"round_ended":
			rain.emitting = false
			end_layer.visible = true
			if bool(p.win):
				end_title.text = "🏡 国度守住了！"
				end_title.add_theme_color_override("font_color", Color("66bb6a"))
				end_body.text = "60 秒过去，岩浆退了回去。\n剩余温度 %d 度 · 村民 %d 位 · 水滴 %d" % [
					int(sim.heat), sim.villagers.size(), int(sim.water)]
			else:
				end_title.text = "🔥 岩浆吞没了国度……"
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


func _pick(screen_pos: Vector2) -> void:
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var col: Object = hit.collider
	if col.has_meta("slot"):
		var slot := int(col.get_meta("slot"))
		var lv: int = sim.towers[slot]
		var ok := sim.try_upgrade(slot) if lv == 1 else sim.try_build(slot)
		if not ok:
			_toast("水滴不够（需要 %d💧）" % (sim.upgrade_cost() if lv == 1 else sim.build_cost()), Color("ef9a9a"))
	elif col.has_meta("villager"):
		var id := int(col.get_meta("villager"))
		if not sim.try_promote(id):
			_toast("晋升需要 30💧 或已晋升", Color("ef9a9a"))


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
	water_label.text = "💧 %d" % int(sim.water)
	time_label.text = "⏱ %d/60" % int(sim.elapsed)
	var ph := sim.phase()
	phase_label.text = "阶段：%s" % str(ph.name)
	phase_label.add_theme_color_override("font_color", Color(str(ph.col)))
	# 村民表现走动（只读展示）
	for id: int in villager_nodes:
		var holder := villager_nodes[id] as Node3D
		var vx: float = float(holder.get_meta("vx"))
		holder.position.x = vx + sin((sim.elapsed + float(id)) * 1.3) * 2.0
	# toast 淡出
	for i in range(toasts.size() - 1, -1, -1):
		var t: Dictionary = toasts[i]
		t.age += delta
		var l := t.label as Label
		l.modulate.a = clampf(2.0 - float(t.age), 0.0, 1.0)
		if float(t.age) > 2.0:
			l.queue_free()
			toasts.remove_at(i)
