extends Node3D
## DEMO8 3D 灰模（阶段 A 受限轨迹桥梁）：旧规则核心 flight_core.gd + 三维表现 + 2D HUD。
## 坐标契约：60px=1m；世界 X 侧向（阶段 A 恒 0）、Y 向上、前进沿 -Z；
## world = (0, (GROUND_Y-old_y)/60, -(old_x-START_X)/60)。核心按旧 px 单位积分，本文件只做表现转换。
## 相机：CameraRig→SpringArm3D→Camera3D 跟随机位，不继承滚转、不反写模拟（R 复位）。
## 网格均为 Godot 基础几何体（灰模诚实原则：折线仍是设计参数，非真实折纸网格）。

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const ComicObjectScript := preload("res://comic_style/comic_object.gd")
const ModelLibrary := preload("res://comic_style/model_library.gd")
const StyleDef := preload("res://comic_style/comic_style.gd")
const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")
const PX_PER_M := 60.0
const GROUND_Y := 460.0
const START_X := 60.0
const CHARGE_TIME := 1.2
const PAPER_POS := Vector2(90.0, 160.0)
const PAPER_H := 300.0

var style_def: Resource = StyleDef.new()   # 3d-shared 基座统一样式（toon+描边）

var core: RefCounted = CoreScript.new()
var last_throw := {angle = 30.0, power = 1.0}   # 测试/复盘用：最近一次实际投掷入参

## 表现节点
var world_root: Node3D
var plane_visual: Node3D
var cam_rig: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var trail_mesh: MeshInstance3D
var trail_imm: ImmediateMesh
var level_props: Node3D
var high_gate: Node3D = null       # C10：摆动门节点引用（每帧随 gate_side_at 更新）
var sun: DirectionalLight3D

## HUD
var hud: CanvasLayer
var paint: Control
var status_label: Label
var hint_label: Label
var fold_btn: Button
var menu_panel: Panel
var level_buttons: Array = []
var menu_tip: Label
var settle_panel: Panel
var settle_title: Label
var settle_body: Label
var settle_btn: Button
var chart: Control                 # 阶段 C：结算轨迹复盘小图（高度-距离 + 门/终点标记）
var chart_cache := PackedVector2Array()
var chart_marks_cache: Array = []
var shop_panel: Panel
var shop_coins: Label
var shop_box: Control
var shop_skip: Button
var final_panel: Panel
var final_body: Label

## 输入状态
var charging := false
var charge := 0.0
var fold_p1 := Vector2.ZERO
var fold_has_p1 := false
var prev_state := ""
var auto_shots_dir := ""      # 非空时自动演示并截图（离线渲染证据）
var _shot_stage := 0


func _ready() -> void:
	_build_world()
	_build_hud()
	_apply_level_props()
	auto_shots_dir = String(OS.get_environment("DEMO08_SHOTS_DIR"))
	if auto_shots_dir != "":
		_auto_shots_run.call_deferred()


# ---------------- 世界搭建 ----------------

func _build_world() -> void:
	world_root = Node3D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("9fd8f5")
	sky_mat.sky_horizon_color = Color("e8f4fa")
	sky_mat.ground_bottom_color = Color("7a9a6d")
	sky_mat.ground_horizon_color = Color("cfe0c5")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	we.environment = env
	world_root.add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world_root.add_child(sun)

	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(80.0, 220.0)
	ground.mesh = gm
	ground.position = Vector3(0.0, 0.0, -100.0)
	# 统一材质：大平面用基座 toon body 材质，不加描边壳（巨型面描边出怪边）
	ground.material_override = style_def.body_material(Color("8bbf6a"))
	world_root.add_child(ground)

	var strip := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(5.0, 0.06, 220.0)
	strip.mesh = sm
	strip.position = Vector3(0.0, 0.03, -100.0)
	strip.material_override = style_def.body_material(Color("d9cfa8"))
	world_root.add_child(strip)

	# 场景应用：起点台用基座 crate 模型（ComicObject，统一 toon+描边）
	var pad: Node3D = ModelLibrary.create_model("crate")
	pad.scale = Vector3(2.2, 1.6, 2.2)
	pad.position = Vector3(0.0, 0.0, 0.2)
	world_root.add_child(pad)

	# 跑道两侧装饰（确定性摆位，ComicObject 统一样式，增强速度可读性）
	var deco_ids := ["tree", "bush", "barrel", "rock"]
	var k := 0
	for zz in [-12.0, -26.0, -40.0, -54.0, -68.0, -82.0, -96.0, -110.0, -124.0, -138.0]:
		var deco: Node3D = ModelLibrary.create_model(deco_ids[k % deco_ids.size()])
		var side: float = -1.0 if k % 2 == 0 else 1.0
		deco.position = Vector3(side * (13.0 + 3.0 * float(k % 3)), 0.0, zz)
		deco.scale = Vector3.ONE * (1.6 + 0.4 * float(k % 2))
		world_root.add_child(deco)
		k += 1

	level_props = Node3D.new()
	level_props.name = "LevelProps"
	world_root.add_child(level_props)

	trail_imm = ImmediateMesh.new()
	trail_mesh = MeshInstance3D.new()
	trail_mesh.mesh = trail_imm
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = Color(0.2, 0.35, 0.7, 0.6)
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mesh.material_override = tm
	world_root.add_child(trail_mesh)

	# 场景应用：纸飞机 = 自建 ComicObject parts（统一 toon+描边；本地机头 -Z）
	plane_visual = ComicObjectScript.new()
	plane_visual.name = "PlaneVisual"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.05, 0.9)
	plane_visual.add_part(bm, Color("fafafa"), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.1)))
	var wm := BoxMesh.new()
	wm.size = Vector3(0.55, 0.02, 0.4)
	var wl_basis := Basis.IDENTITY.rotated(Vector3(0.0, 0.0, 1.0), deg_to_rad(7.0))
	plane_visual.add_part(wm, Color("ffffff"), Transform3D(wl_basis, Vector3(-0.26, 0.02, 0.12)))
	var wr_basis := Basis.IDENTITY.rotated(Vector3(0.0, 0.0, 1.0), deg_to_rad(-7.0))
	plane_visual.add_part(wm, Color("ffffff"), Transform3D(wr_basis, Vector3(0.26, 0.02, 0.12)))
	world_root.add_child(plane_visual)

	cam_rig = Node3D.new()
	cam_rig.name = "CameraRig"
	spring_arm = SpringArm3D.new()
	spring_arm.spring_length = 8.0
	spring_arm.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	# 遮挡：SpringArm 球形探测 + 地面碰撞体（低飞镜头收近不穿地；物理行为 headless 可验证）
	var arm_shape := SphereShape3D.new()
	arm_shape.radius = 0.3
	spring_arm.shape = arm_shape
	cam_rig.add_child(spring_arm)
	camera = Camera3D.new()
	camera.fov = 70.0
	spring_arm.add_child(camera)
	world_root.add_child(cam_rig)
	camera.current = true

	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundCollider"
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(80.0, 0.5, 220.0)
	gcol.shape = gshape
	ground_body.add_child(gcol)
	ground_body.position = Vector3(0.0, -0.25, -100.0)
	world_root.add_child(ground_body)


## 按关卡重建终点/门（场景应用：终点与低门为自建 ComicObject，高门用基座 gate_frame 模型；
## 规则横向有效半宽见核心 GATE_HALF_PX=5m，视觉宽度与之一致）
func _apply_level_props() -> void:
	for c in level_props.get_children():
		c.queue_free()
	var L: Dictionary = core.LEVELS[core.level_idx]
	var finish_z := -float(L.target_m)
	# 终点旗门：自建 ComicObject（柱 frame 色 + 横幅/地线红）
	var finish: Node3D = ComicObjectScript.new()
	finish.name = "FinishGate"
	var pole_m := CylinderMesh.new()
	pole_m.top_radius = 0.08
	pole_m.bottom_radius = 0.08
	pole_m.height = 6.0
	for sx in [-3.0, 3.0]:
		finish.add_part(pole_m, ModelLibrary.COLORS.frame,
			Transform3D(Basis.IDENTITY, Vector3(sx, 3.0, 0.0)))
	var banner_m := BoxMesh.new()
	banner_m.size = Vector3(6.4, 1.1, 0.06)
	finish.add_part(banner_m, Color("e53935"), Transform3D(Basis.IDENTITY, Vector3(0.0, 5.6, 0.0)))
	var line_m := BoxMesh.new()
	line_m.size = Vector3(10.0, 0.04, 0.4)
	finish.add_part(line_m, Color("d32f2f"), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 0.0)))
	finish.position = Vector3(0.0, 0.0, finish_z)
	level_props.add_child(finish)
	var gate_x_m: float = float(L.get("gate_x", 0.0))
	if gate_x_m > 0.0:
		# 高门：基座 gate_frame 模型（原尺寸 2.2×2.4），缩放到门宽 6m × 门高；横位随 gate_side（摆动关卡每帧更新）
		var hg: Node3D = ModelLibrary.create_model("gate_frame")
		hg.scale = Vector3(6.0 / 2.2, float(L.gate_h) / 2.4, 1.6)
		hg.position = Vector3(float(L.get("gate_side", 0.0)) / PX_PER_M, 0.0, -gate_x_m)
		level_props.add_child(hg)
		high_gate = hg
	var lg_x_m: float = float(L.get("low_gate_x", 0.0))
	if lg_x_m > 0.0:
		# 低门：自建 ComicObject（双柱 + 横杆，杆顶=low_gate_top）；横位随 low_gate_side
		var low: Node3D = ComicObjectScript.new()
		low.name = "LowGate"
		var post_m := CylinderMesh.new()
		post_m.top_radius = 0.1
		post_m.bottom_radius = 0.1
		post_m.height = float(L.low_gate_top)
		for sx in [-4.0, 4.0]:
			low.add_part(post_m, ModelLibrary.COLORS.frame,
				Transform3D(Basis.IDENTITY, Vector3(sx, float(L.low_gate_top) / 2.0, 0.0)))
		var bar_m := BoxMesh.new()
		bar_m.size = Vector3(8.0, 0.25, 0.25)
		low.add_part(bar_m, ModelLibrary.COLORS.plate,
			Transform3D(Basis.IDENTITY, Vector3(0.0, float(L.low_gate_top), 0.0)))
		low.position = Vector3(float(L.get("low_gate_side", 0.0)) / PX_PER_M, 0.0, -lg_x_m)
		level_props.add_child(low)


# ---------------- 坐标转换 ----------------

func to_world(p: Vector2, lat_px: float = 0.0) -> Vector3:
	return Vector3(lat_px / PX_PER_M, (GROUND_Y - p.y) / PX_PER_M, -(p.x - START_X) / PX_PER_M)


# ---------------- HUD 搭建 ----------------

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	paint = Control.new()
	paint.name = "PaintLayer"
	paint.set_anchors_preset(Control.PRESET_FULL_RECT)
	paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paint.draw.connect(_on_paint)
	hud.add_child(paint)
	status_label = Label.new()
	status_label.position = Vector2(16, 40)
	status_label.size = Vector2(920, 24)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("0d3b4e"))
	hud.add_child(status_label)
	var title := Label.new()
	title.text = "纸飞机 3D（阶段B · 3d-shared 基座）"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("0d3b4e"))
	hud.add_child(title)
	hint_label = Label.new()
	hint_label.position = Vector2(16, VIEW.y - 28)
	hint_label.size = Vector2(930, 24)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color("37474f"))
	hud.add_child(hint_label)
	fold_btn = Button.new()
	fold_btn.name = "FoldDoneBtn"
	fold_btn.text = "完成折叠，去投掷"
	fold_btn.position = Vector2(90, 464)
	fold_btn.size = Vector2(190, 42)
	fold_btn.pressed.connect(_on_fold_done)
	fold_btn.visible = false
	hud.add_child(fold_btn)
	_build_menu_panel()
	_build_settle_panel()
	_build_shop_panel()
	_build_final_panel()
	_go_menu()


func _panel_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.93)
	st.set_corner_radius_all(12)
	return st


func _build_menu_panel() -> void:
	menu_panel = Panel.new()
	menu_panel.name = "MenuPanel"
	menu_panel.position = Vector2(150, 92)
	menu_panel.size = Vector2(660, 330)
	menu_panel.add_theme_stylebox_override("panel", _panel_style())
	hud.add_child(menu_panel)
	var mt := Label.new()
	mt.text = "纸飞机 3D：选关起飞"
	mt.position = Vector2(24, 14)
	mt.add_theme_font_size_override("font_size", 22)
	mt.add_theme_color_override("font_color", Color("111111"))
	menu_panel.add_child(mt)
	for i in core.LEVELS.size():
		var lb := Button.new()
		lb.name = "LevelBtn%d" % i
		# 6 关布局：面板宽 660-48 边距 → 每键 98 宽 + 102 步进（末键右缘 632 不溢出）
		lb.position = Vector2(24 + i * 102, 58)
		lb.size = Vector2(98, 46)
		lb.add_theme_font_size_override("font_size", 12)
		lb.pressed.connect(_on_level_pressed.bind(i))
		lb.mouse_entered.connect(_on_menu_hover.bind(i))
		menu_panel.add_child(lb)
		level_buttons.append(lb)
	menu_tip = Label.new()
	menu_tip.name = "MenuTip"
	menu_tip.position = Vector2(24, 114)
	menu_tip.size = Vector2(612, 60)
	menu_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_tip.add_theme_font_size_override("font_size", 14)
	menu_tip.add_theme_color_override("font_color", Color("0d47a1"))
	menu_panel.add_child(menu_tip)
	var rules := Label.new()
	rules.text = "3D 灰模：跟随视角观察同一套折线规则。折线靠右升力大、靠上抬头、长线多阻力。\n60 像素 = 1 米；R 复位相机；门奖即时入账，失败仍保留。\n阶段 B：飞行中 A/D 横移（加速 240/上限 320/阻尼 160 px/s²，边界 ±20m），门有横向宽度 5m。\n商店七物：力气/翼面/纸面加固/重心铅条/螺旋桨/配平仪/韧性——加固降阻力、铅条驯配平。"
	rules.position = Vector2(24, 186)
	rules.size = Vector2(612, 100)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.add_theme_font_size_override("font_size", 13)
	rules.add_theme_color_override("font_color", Color("555555"))
	menu_panel.add_child(rules)


func _build_settle_panel() -> void:
	settle_panel = Panel.new()
	settle_panel.name = "SettlePanel"
	settle_panel.position = Vector2(240, 110)
	settle_panel.size = Vector2(480, 310)
	settle_panel.add_theme_stylebox_override("panel", _panel_style())
	settle_panel.visible = false
	hud.add_child(settle_panel)
	settle_title = Label.new()
	settle_title.name = "SettleTitle"
	settle_title.position = Vector2(24, 14)
	settle_title.add_theme_font_size_override("font_size", 24)
	settle_title.add_theme_color_override("font_color", Color("111111"))
	settle_panel.add_child(settle_title)
	settle_body = Label.new()
	settle_body.name = "SettleBody"
	settle_body.position = Vector2(24, 56)
	settle_body.size = Vector2(432, 84)
	settle_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settle_body.add_theme_font_size_override("font_size", 14)
	settle_body.add_theme_color_override("font_color", Color("333333"))
	settle_panel.add_child(settle_body)
	# 阶段 C：轨迹复盘小图（高度-距离折线 + 门/终点标记；绘制数据 headless 可断言）
	chart = Control.new()
	chart.name = "TrailChart"
	chart.position = Vector2(24, 146)
	chart.size = Vector2(432, 90)
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.draw.connect(_on_chart_draw)
	settle_panel.add_child(chart)
	settle_btn = Button.new()
	settle_btn.name = "SettleBtn"
	settle_btn.position = Vector2(24, 250)
	settle_btn.size = Vector2(200, 42)
	settle_btn.pressed.connect(_on_settle_continue)
	settle_panel.add_child(settle_btn)
	var back := Button.new()
	back.name = "SettleBackBtn"
	back.text = "返回选关"
	back.position = Vector2(256, 250)
	back.size = Vector2(200, 42)
	back.pressed.connect(_go_menu)
	settle_panel.add_child(back)


func _build_shop_panel() -> void:
	shop_panel = Panel.new()
	shop_panel.name = "ShopPanel"
	shop_panel.position = Vector2(170, 88)
	shop_panel.size = Vector2(620, 384)
	shop_panel.add_theme_stylebox_override("panel", _panel_style())
	shop_panel.visible = false
	hud.add_child(shop_panel)
	var st := Label.new()
	st.text = "肉鸽商店（强化立即生效，带入下一关）"
	st.position = Vector2(24, 12)
	st.add_theme_font_size_override("font_size", 20)
	st.add_theme_color_override("font_color", Color("111111"))
	shop_panel.add_child(st)
	shop_coins = Label.new()
	shop_coins.name = "ShopCoins"
	shop_coins.position = Vector2(24, 48)
	shop_coins.add_theme_font_size_override("font_size", 15)
	shop_coins.add_theme_color_override("font_color", Color("e65100"))
	shop_panel.add_child(shop_coins)
	shop_box = Control.new()
	shop_box.name = "ShopBox"
	shop_box.position = Vector2(24, 82)
	shop_box.size = Vector2(572, 224)
	shop_panel.add_child(shop_box)
	shop_skip = Button.new()
	shop_skip.name = "ShopSkip"
	shop_skip.text = "跳过，进入下一关"
	shop_skip.position = Vector2(24, 322)
	shop_skip.size = Vector2(572, 44)
	shop_skip.pressed.connect(_on_shop_skip)
	shop_panel.add_child(shop_skip)


func _build_final_panel() -> void:
	final_panel = Panel.new()
	final_panel.name = "FinalPanel"
	final_panel.position = Vector2(210, 110)
	final_panel.size = Vector2(540, 300)
	final_panel.add_theme_stylebox_override("panel", _panel_style())
	final_panel.visible = false
	hud.add_child(final_panel)
	var ft := Label.new()
	ft.text = "全通关！"
	ft.position = Vector2(24, 14)
	ft.add_theme_font_size_override("font_size", 26)
	ft.add_theme_color_override("font_color", Color("1b5e20"))
	final_panel.add_child(ft)
	final_body = Label.new()
	final_body.name = "FinalBody"
	final_body.position = Vector2(24, 60)
	final_body.size = Vector2(492, 150)
	final_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	final_body.add_theme_font_size_override("font_size", 15)
	final_body.add_theme_color_override("font_color", Color("333333"))
	final_panel.add_child(final_body)
	var again := Button.new()
	again.name = "AgainBtn"
	again.text = "再来一次（清空进度）"
	again.position = Vector2(24, 230)
	again.size = Vector2(230, 44)
	again.pressed.connect(_on_reset_run)
	final_panel.add_child(again)
	var back := Button.new()
	back.text = "返回选关"
	back.position = Vector2(286, 230)
	back.size = Vector2(230, 44)
	back.pressed.connect(_go_menu)
	final_panel.add_child(back)


# ---------------- 流程 ----------------

func _paper_rect() -> Rect2:
	return Rect2(PAPER_POS, Vector2(PAPER_H * float(core.LEVELS[core.level_idx].ratio), PAPER_H))


func _hide_all_panels() -> void:
	menu_panel.visible = false
	settle_panel.visible = false
	shop_panel.visible = false
	final_panel.visible = false
	fold_btn.visible = false
	if chart != null:
		chart.visible = false


## 轨迹复盘数据：折线点（米）(前进 x, 高度 y)
func chart_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in core.trail:
		var pp: Vector2 = p
		pts.append(Vector2((pp.x - START_X) / PX_PER_M, (GROUND_Y - pp.y) / PX_PER_M))
	return pts


## 轨迹复盘标记：门/终点（米）
func chart_marks() -> Array:
	var L: Dictionary = core.LEVELS[core.level_idx]
	var marks: Array = []
	var gate_x_m: float = float(L.get("gate_x", 0.0))
	if gate_x_m > 0.0:
		marks.append({x = gate_x_m, kind = "high", side = float(L.get("gate_side", 0.0)) / PX_PER_M})
	var lg_x_m: float = float(L.get("low_gate_x", 0.0))
	if lg_x_m > 0.0:
		marks.append({x = lg_x_m, kind = "low", side = float(L.get("low_gate_side", 0.0)) / PX_PER_M})
	marks.append({x = float(L.target_m), kind = "finish", side = 0.0})
	return marks


func _on_chart_draw() -> void:
	if chart_cache.size() < 2:
		return
	var r := Rect2(Vector2.ZERO, chart.size)
	var max_d: float = float(core.LEVELS[core.level_idx].target_m) * 1.08
	var max_h: float = 1.0
	for p in chart_cache:
		var pp: Vector2 = p
		max_h = maxf(max_h, pp.y)
	paint_chart_axes(r, max_d, max_h)
	var pts := PackedVector2Array()
	for p in chart_cache:
		var pp: Vector2 = p
		pts.append(Vector2(r.position.x + pp.x / max_d * r.size.x,
			r.position.y + r.size.y - pp.y / max_h * r.size.y))
	chart.draw_polyline(pts, Color("1e5a8a"), 2.0)
	chart.draw_circle(pts[pts.size() - 1], 3.0, Color("e53935"))
	for m in chart_marks_cache:
		var mx: float = r.position.x + float(m.x) / max_d * r.size.x
		var col := Color("b71c1c") if String(m.kind) == "finish" else (Color("f9a825") if String(m.kind) == "high" else Color("0277bd"))
		chart.draw_line(Vector2(mx, r.position.y), Vector2(mx, r.position.y + r.size.y), Color(col, 0.7), 2.0)


func paint_chart_axes(r: Rect2, max_d: float, max_h: float) -> void:
	chart.draw_rect(r, Color(1, 1, 1, 0.55))
	chart.draw_line(r.position + Vector2(0, r.size.y), r.position + Vector2(r.size.x, r.size.y), Color("607d8b"), 1.5)
	chart.draw_string(FONT, r.position + Vector2(2.0, 12.0), "%.0fm" % max_d, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("607d8b"))
	chart.draw_string(FONT, r.position + Vector2(2.0, r.size.y - 3.0), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("607d8b"))


func _go_menu() -> void:
	# 与 2D 旧版一致：返回选关保留进度（金币/强化/解锁），仅"再来一次"清空
	core.state = "menu"
	prev_state = "menu"
	_hide_all_panels()
	menu_panel.visible = true
	for i in level_buttons.size():
		var lb: Button = level_buttons[i]
		var locked: bool = i > core.unlocked
		lb.disabled = locked
		lb.text = ("第%d关 · %s" % [i + 1, String(core.LEVELS[i].short)]) if not locked else ("第%d关（未解锁）" % [i + 1])
	menu_tip.text = "折纸三参数：升力面积（折线越靠外越大）· 配平（越靠上越正/抬头）· 阻力（线越长越大）"
	_update_status()


func _on_reset_run() -> void:
	_go_menu()


func _on_level_pressed(i: int) -> void:
	if i < 0 or i >= core.LEVELS.size() or i > core.unlocked:
		return
	core.start_level(i)
	prev_state = "fold"
	_hide_all_panels()
	fold_btn.visible = true
	fold_has_p1 = false
	_apply_level_props()
	_update_status()


func _on_fold_done() -> void:
	if core.state != "fold":
		return
	core.finish_folds()
	fold_btn.visible = false
	charging = false
	charge = 0.0
	_update_status()


func _release_throw() -> void:
	if core.state == "throw" and charging:
		charging = false
		last_throw = {angle = core.throw_angle, power = charge}
		core.do_throw(core.throw_angle, charge)
		charge = 0.0
		_update_status()


func _on_settle_continue() -> void:
	var go: String = core.settle_continue()
	prev_state = core.state
	_hide_all_panels()
	if go == "shop":
		_show_shop()
	elif go == "final":
		_show_final()
	elif go == "retry":
		fold_btn.visible = true
		fold_has_p1 = false
		_apply_level_props()
	_update_status()


func _on_shop_skip() -> void:
	core.shop_skip()
	prev_state = "fold"
	_hide_all_panels()
	fold_btn.visible = true
	_apply_level_props()
	_update_status()


func _show_shop() -> void:
	shop_panel.visible = true
	_refresh_shop()


func _show_final() -> void:
	var owned_txt: String = ", ".join(core.owned) if core.owned.size() > 0 else "无特殊部件"
	final_body.text = "%d 关全部飞过终点旗！\n总飞行 %d 米 · 最远一掷 %.1f 米 · 金币余额 %d\n强化：力气 x%d · 翼面 x%d · 加固 x%d · 铅条 x%d · %s" % [
		core.LEVELS.size(), int(core.total_distance), core.best_distance, core.coins,
		int(core.upgrades.power), int(core.upgrades.wing),
		int(core.upgrades.get("stiff", 0)), int(core.upgrades.get("ballast", 0)), owned_txt]
	final_panel.visible = true


func _refresh_shop() -> void:
	shop_coins.text = "金币：%d" % core.coins
	for c in shop_box.get_children():
		c.queue_free()
	for i in core.shop_items.size():
		var item: Dictionary = core.shop_items[i]
		var b := Button.new()
		b.name = "ShopItem%d" % i
		b.text = "%s · %d 金币 —— %s" % [String(item.name), int(item.price), String(item.desc)]
		b.position = Vector2(0, i * 62)
		b.size = Vector2(572, 52)
		b.disabled = core.coins < int(item.price)
		b.pressed.connect(_on_shop_buy.bind(i))
		shop_box.add_child(b)


func _on_shop_buy(idx: int) -> void:
	if core.buy(idx):
		_refresh_shop()


func _on_menu_hover(i: int) -> void:
	if core.state == "menu":
		menu_tip.text = String(core.LEVELS[i].tip)


# ---------------- 输入（真实事件路径） ----------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if core.state == "fold" and event.pressed:
			if _paper_rect().grow(10.0).has_point(pos):
				if not fold_has_p1:
					fold_p1 = pos
					fold_has_p1 = true
				else:
					core.add_fold(fold_p1, pos)
					fold_has_p1 = false
		elif core.state == "throw":
			if event.pressed:
				charging = true
				charge = 0.0
			else:
				_release_throw()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if core.state == "throw":
			if k.pressed and not k.echo:
				if k.keycode == KEY_UP:
					core.throw_angle = minf(60.0, core.throw_angle + 3.0)
				elif k.keycode == KEY_DOWN:
					core.throw_angle = maxf(0.0, core.throw_angle - 3.0)
				elif k.keycode == KEY_SPACE:
					charging = true
					charge = 0.0
			elif not k.pressed and k.keycode == KEY_SPACE:
				_release_throw()
		elif core.state == "fly":
			# 阶段 B1：A/D 有限侧向转向（真实按键事件；松开侧清零）
			if k.pressed and not k.echo:
				if k.keycode == KEY_A:
					core.lateral_input = -1.0
				elif k.keycode == KEY_D:
					core.lateral_input = 1.0
			elif not k.pressed:
				if k.keycode == KEY_A and float(core.lateral_input) < 0.0:
					core.lateral_input = 0.0
				elif k.keycode == KEY_D and float(core.lateral_input) > 0.0:
					core.lateral_input = 0.0
		if k.pressed and not k.echo and k.keycode == KEY_R and core.state == "fly":
			_snap_camera()
	elif event is InputEventMouseMotion and core.state == "throw" and not charging:
		core.throw_angle = clampf((VIEW.y - event.position.y) * 60.0 / VIEW.y, 0.0, 60.0)


# ---------------- 主循环 ----------------

func _process(delta: float) -> void:
	if core.state == "throw" and charging:
		charge = minf(1.0, charge + delta / CHARGE_TIME)
	if core.state != prev_state:
		if core.state == "settle":
			_show_settle_panel()
		# C15 修复：离开 fly 态清零横向输入（防止按住 A/D 跨掷残留带偏下一掷）
		if prev_state == "fly" and core.state != "fly":
			core.lateral_input = 0.0
		prev_state = core.state
	_update_status()
	_update_visuals()
	paint.queue_redraw()


func _physics_process(delta: float) -> void:
	if core.state == "fly":
		core.step(delta)


func _update_visuals() -> void:
	var wp := to_world(core.plane_pos, float(core.lateral))
	plane_visual.position = wp
	# 偏航=航向角（表现），小滚转倾斜=横移视觉（相机不继承）
	var bank: float = clampf(-float(core.lateral_vel) / float(core.LAT_VMAX), -1.0, 1.0) * 0.3
	plane_visual.rotation = Vector3(-core.pitch, float(core.yaw_rad()), bank)
	# C10 摆动门：高门横位每帧随 gate_side_at(flight_time)（与规则判定同一公式）
	if high_gate != null and core.state == "fly":
		high_gate.position.x = float(core.gate_side_at(float(core.flight_time))) / PX_PER_M
	if core.state != "fly" and core.state != "settle":
		cam_rig.position = Vector3(0.0, 1.2, 0.0)
		cam_rig.rotation = Vector3(0.0, 0.0, 0.0)
	else:
		# 相机半跟随航向（无滚转），横向只跟一半保持门/跑道可读
		cam_rig.position = Vector3(wp.x * 0.6, wp.y, wp.z)
		cam_rig.rotation = Vector3(0.0, float(core.yaw_rad()) * 0.5, 0.0)
	_redraw_trail()


func _snap_camera() -> void:
	var wp := to_world(core.plane_pos, float(core.lateral))
	cam_rig.position = Vector3(wp.x * 0.6, wp.y, wp.z)
	cam_rig.rotation = Vector3(0.0, 0.0, 0.0)


func _redraw_trail() -> void:
	trail_imm.clear_surfaces()
	var pts: Array = core.trail
	if pts.size() < 2:
		return
	var lat: float = float(core.lateral)
	trail_imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in pts:
		var pp: Vector2 = p
		trail_imm.surface_add_vertex(to_world(pp, lat))
	trail_imm.surface_end()


func _show_settle_panel() -> void:
	settle_panel.visible = true
	var L: Dictionary = core.LEVELS[core.level_idx]
	var is_last: bool = core.level_idx >= core.LEVELS.size() - 1
	if core.last_pass:
		settle_title.text = "过关！"
		settle_btn.text = "查看总成绩" if is_last else "进入商店"
	else:
		settle_title.text = "挑战失败"
		settle_btn.text = "重试本关"
	var earn_txt: String
	if core.last_pass:
		earn_txt = "金币 +%d（门奖 %d + 结算 %d）· 现有 %d" % [
			core.gate_coins + core.coins_earned, core.gate_coins, core.coins_earned, core.coins]
	else:
		earn_txt = "金币 +%d（门奖 %d 失败仍保留）· 现有 %d" % [core.gate_coins, core.gate_coins, core.coins]
	# C16 打磨：有横向风的关卡结算补横移信息（帮助玩家把侧风与轨迹关联）
	var lat_info: String = ""
	if core.wind_mode() == "side" or absf(core.side_wind_accel()) > 0.0:
		lat_info = " · 横移 %+.1f 米" % (float(core.lateral) / 60.0)
	settle_body.text = "%s\n飞行距离 %.1f 米 · 目标 %.0f 米 · 顶点 %.1f 米%s\n%s\n小贴士：%s" % [
		String(L.name), core.flight_distance, float(L.target_m), core.apex_m, lat_info, earn_txt, String(L.tip)]
	# 轨迹复盘小图（阶段 C）：高度-距离 + 门/终点标记
	chart_cache = chart_points()
	chart_marks_cache = chart_marks()
	chart.visible = true
	chart.queue_redraw()


func _update_status() -> void:
	var L: Dictionary = core.LEVELS[core.level_idx]
	match core.state:
		"menu":
			status_label.text = "纸飞机 3D · 已通关 %d/%d 关 · 金币 %d" % [core.unlocked, core.LEVELS.size(), core.coins]
			hint_label.text = "选一关起飞：折纸定参数，蓄力投掷，跟在飞机后面看它飞"
		"fold":
			status_label.text = "%s · 折纸：已折 %d/%d 条 · 目标 %.0f 米" % [
				String(L.name), core.folds_used, int(L.folds), float(L.target_m)]
			hint_label.text = "在左侧纸上点两下折一条线；完成后点按钮进入投掷"
		"throw":
			status_label.text = "%s · 投掷：角度 %d° · 力度上限 x%.1f · 目标 %.0f 米" % [
				String(L.name), int(round(core.throw_angle)), core.power_mult(), float(L.target_m)]
			hint_label.text = "鼠标上下或方向键调角度，按住空格/左键蓄力，松开发射；R 复位相机"
		"fly":
			var live_m: float = (core.plane_pos.x - START_X) / PX_PER_M
			var h_m: float = (GROUND_Y - core.plane_pos.y) / PX_PER_M
			status_label.text = "%s · 飞行中 %.1f 米 / 目标 %.0f 米 · 高度 %.1f 米 · 横移 %.1f 米" % [
				String(L.name), live_m, float(L.target_m), h_m, float(core.lateral) / PX_PER_M]
			hint_label.text = "A/D 横移（门有横向宽度），R 复位相机"
		"settle":
			status_label.text = ("过关！" if core.last_pass else "挑战失败") + " · 飞行 %.1f 米 · 金币 %d" % [core.flight_distance, core.coins]
			hint_label.text = ""
		"shop":
			status_label.text = "肉鸽商店 · 金币 %d · 买强化带入第 %d 关" % [core.coins, core.level_idx + 2]
			hint_label.text = "买不起就点跳过；金币 = 门奖（即时）+ 距离/10 + 过关奖励"
		"final":
			status_label.text = "全通关！金币 %d" % core.coins
			hint_label.text = ""


# ---------------- 2D 覆盖绘制（纸面/折线/投掷辅助） ----------------

func _on_paint() -> void:
	var st: String = String(core.state)
	if st == "menu" or st == "final":
		return
	_draw_wind_tag()
	if st == "fold":
		_draw_paper()
	if st == "fold" or st == "throw":
		_draw_params()
	if st == "throw":
		_draw_throw_ui()


func _draw_paper() -> void:
	var pr := _paper_rect()
	paint.draw_rect(pr, Color(1, 1, 1, 0.85))
	paint.draw_rect(pr, Color("b0bec5"), false, 2.0)
	paint.draw_string(FONT, pr.position + Vector2(0.0, -10.0),
		"纸张：剩余可折 %d 次" % (int(core.LEVELS[core.level_idx].folds) - core.folds_used),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("455a64"))
	for f in core.folds:
		var a: Vector2 = f[0]
		var b: Vector2 = f[1]
		paint.draw_line(a, b, Color("78909c"), 2.0)
		paint.draw_circle(a, 3.0, Color("78909c"))
		paint.draw_circle(b, 3.0, Color("78909c"))
	if fold_has_p1:
		paint.draw_circle(fold_p1, 4.0, Color("e53935"))


func _draw_params() -> void:
	var bx := 620.0
	var by := 150.0
	paint.draw_string(FONT, Vector2(bx, by), "升力 %s" % _tier3(float(core.plane_params.lift_area), 0.5, 1.0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("1e88e5"))
	paint.draw_string(FONT, Vector2(bx, by + 26.0), "配平 %s" % _trim_tier(float(core.plane_params.trim)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("43a047"))
	paint.draw_string(FONT, Vector2(bx, by + 52.0), "阻力 %s" % _tier3(float(core.plane_params.drag_f), 0.5, 1.0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("fb8c00"))


func _tier3(v: float, mid: float, high: float) -> String:
	return "低" if v < mid else ("中" if v < high else "高")


func _trim_tier(v: float) -> String:
	return "俯冲" if v < -0.15 else ("稳定" if v <= 0.35 else "抬头")


func _draw_throw_ui() -> void:
	var origin := Vector2(160.0, 400.0)
	var dirv := Vector2.from_angle(-deg_to_rad(core.throw_angle))
	var tip := origin + dirv * 110.0
	paint.draw_line(origin, tip, Color("e53935"), 3.0)
	paint.draw_arc(origin, 56.0, -deg_to_rad(core.throw_angle), 0.0, 20, Color(0.9, 0.3, 0.3, 0.6), 2.0)
	paint.draw_string(FONT, tip + Vector2(10.0, 0.0), "%d°" % int(round(core.throw_angle)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e53935"))
	var cb := Rect2(340, 500, 280, 20)
	paint.draw_rect(cb, Color(1, 1, 1, 0.85))
	paint.draw_rect(cb, Color("90a4ae"), false, 1.5)
	paint.draw_rect(Rect2(cb.position.x + 2.0, cb.position.y + 2.0, (cb.size.x - 4.0) * charge, cb.size.y - 4.0), Color("e53935"))
	paint.draw_string(FONT, Vector2(340.0, 494.0), "蓄力 %.0f%%（按住空格/鼠标左键，松开发射）" % (charge * 100.0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("37474f"))


func _draw_wind_tag() -> void:
	var tag: String = wind_tag_text()
	if tag == "":
		return
	paint.draw_string(FONT, Vector2(730.0, 60.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("5c6bc0"))


## 阶段 C16 打磨：风标签文本函数化（headless 可测；覆盖 none/head/tail/侧风/切变/双段切变/正交侧风）
func wind_tag_text() -> String:
	var w: String = core.wind_mode()
	if w == "none":
		return ""
	if w == "side":
		var left: bool = core.wind_side() < 0.0
		var dir1: String = "←" if left else "→"
		var shear_m: float = float(core.LEVELS[core.level_idx].get("shear_x", 0.0))
		var shear2_m: float = float(core.LEVELS[core.level_idx].get("shear_x2", 0.0))
		if shear_m > 0.0 and shear2_m > 0.0:
			var dir2: String = "←" if core.wind_side2() < 0.0 else "→"
			var dir3: String = "←" if core.wind_side3() < 0.0 else "→"
			return "双段切变 %.0f/%.0fm：侧风 %s→%s→%s" % [shear_m, shear2_m, dir1, dir2, dir3]
		if shear_m > 0.0:
			var after: bool = core.wind_side2() < 0.0
			return "风切变 %.0fm：侧风 %s → %s" % [shear_m, dir1, "←" if after else "→"]
		return "侧风 %s（A/D 顶风）" % dir1
	var head: bool = w == "head"
	var label := "逆风 阻力 x1.25" if head else "顺风 恒定推力"
	var sw: float = core.side_wind_accel()
	if absf(sw) > 0.0:
		label += " ＋ 侧风%s" % ("←" if sw < 0.0 else "→")
	return label


# ---------------- 自动演示 + 离线截图（DEMO08_SHOTS_DIR 环境变量触发） ----------------

func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := auto_shots_dir
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png("%s/demo08-3d-%s.png" % [dir, tag])


func _auto_shots_run() -> void:
	await _shot("01-menu")
	_on_level_pressed(0)
	await _shot("02-fold-empty")
	var pr := _paper_rect()
	var e1 := InputEventMouseButton.new()
	e1.button_index = MOUSE_BUTTON_LEFT
	e1.pressed = true
	e1.position = pr.position + pr.size * Vector2(0.92, 0.2)
	Input.parse_input_event(e1)
	await get_tree().process_frame
	var e2 := InputEventMouseButton.new()
	e2.button_index = MOUSE_BUTTON_LEFT
	e2.pressed = true
	e2.position = pr.position + pr.size * Vector2(0.92, 0.8)
	Input.parse_input_event(e2)
	await get_tree().process_frame
	await _shot("03-fold-done")
	_on_fold_done()
	core.throw_angle = 30.0
	charging = true
	charge = 0.85
	_release_throw()
	await get_tree().process_frame
	await _shot("04-launch")
	for k in 75:
		await get_tree().physics_frame
	await _shot("05-flight-mid")
	for k in 25:
		await get_tree().physics_frame
	await _shot("06-flight-late")
	var guard := 0
	while core.state == "fly" and guard < 900:
		await get_tree().physics_frame
		guard += 1
	await _shot("07-settle")
	if core.last_pass:
		_on_settle_continue()
		await _shot("08-shop")
	get_tree().quit()
