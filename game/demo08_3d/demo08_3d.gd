extends Node3D
## Paper panels rotate around actual creases; the same folded geometry drives 3D aerodynamic flight.
## World X is lateral, Y is up, forward is -Z. Legacy HUD distances use 60px = 1m.

const PaperGeometry := preload("res://demo08_3d/paper_geometry.gd")
const PaperFlight := preload("res://demo08_3d/paper_flight.gd")
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

const OrigamiEditor = preload("res://demo08_3d/origami_editor.gd")
var origami_editor: Control
var practice_mode := false
var paper = PaperGeometry.new()
var fold_animation := 1.0
var dart_queue: Array = []
var paper_mesh: MeshInstance3D
var paper_edges: MeshInstance3D
var undo_btn: Button
var dart_btn: Button
var unfold_btn: Button
var crease_btn: Button
var crease_mode := true
var fold_select_face := -1
var fold_select_point := Vector3.ZERO
var fold_dragging := false
var preview_rotating := false
var preview_elevation := 0.65
var preview_distance := 1.45
var drag_screen_mode := false
var drag_start_angle := 0.0
var drag_start_mouse := Vector2.ZERO
var drag_radial := Vector3.ZERO
var drag_plane_origin := Vector3.ZERO
var fold_notice := ""
var fold_notice_time := 0.0
var core: RefCounted = CoreScript.new()
var last_throw := {angle = 30.0, power = 1.0}   # 测试/复盘用：最近一次实际投掷入参

## 表现节点
var world_root: Node3D
var plane_visual: Node3D
# C68 打磨B：折纸态 3D 预览（SubViewport 环绕相机 + HUD 小窗）
var fold_preview_vp: SubViewport
var fold_preview_cam: Camera3D
var fold_preview_rect: TextureRect
var fold_preview_orbit := 0.6
var preview_paper: MeshInstance3D
var preview_edges: MeshInstance3D
var cam_rig: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var trail_mesh: MeshInstance3D
var trail_imm: ImmediateMesh
var level_props: Node3D
var high_gate: Node3D = null       # C10：摆动门节点引用（每帧随 gate_side_at 更新）
var low_gate: Node3D = null        # C19：低空摆门节点引用
var sun: DirectionalLight3D

## HUD
var hud: CanvasLayer
var paint: Control
var status_label: Label
var hint_label: Label
var fold_btn: Button
var menu_panel: Panel
var tip_timer: Timer
var tip_idx := 0
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
var shop_hint_label: Label   # C37 打磨：按当前关机制推荐购物方向
var shop_box: Control
var shop_skip: Button
var final_panel: Panel
var final_body: Label

## 输入状态
var charging := false
var charge := 0.0
var charge_source := ""
var preflight_panel: Panel
var throw_angle_slider: HSlider
var throw_angle_number: SpinBox
var throw_charge_btn: Button
var throw_charge_meter: ProgressBar
var throw_preview_basis := Basis.IDENTITY
var syncing_throw_angle := false
var throw_rotation_degrees := Vector3(12,0,0)
var throw_rotation_sliders: Array[HSlider] = []
var throw_rotation_numbers: Array[SpinBox] = []
var throw_reset_btn: Button
var fold_p1 := Vector2.ZERO
var fold_has_p1 := false
var prev_state := ""
var auto_shots_dir := ""      # 非空时自动演示并截图（离线渲染证据）
var _shot_stage := 0


func _ready() -> void:
	_build_world()
	_build_hud()
	_build_fold_preview()
	_build_preflight_controls()
	origami_editor=OrigamiEditor.new()
	origami_editor.name="OrigamiWorkbench"
	hud.add_child(origami_editor)
	origami_editor.geometry_changed.connect(_sync_workbench)
	origami_editor.fly_requested.connect(_on_fold_done)
	origami_editor.menu_requested.connect(_go_menu)
	_apply_level_props()
	_on_level_pressed.call_deferred(0,true)
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
	pad.position = Vector3(3.5, 0.0, 0.2)
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
	# C68 打磨A：参数驱动形变——折线参数实时映射机体几何（翼面/上反角/折痕线），每次折完重建
	_rebuild_plane_visual()

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


## Build both world and isolated preview from the same folded paper vertices.
func _rebuild_plane_visual() -> void:
	if plane_visual == null:
		plane_visual = Node3D.new()
		plane_visual.name = "FoldedPaper"
		world_root.add_child(plane_visual)
		paper_mesh = MeshInstance3D.new()
		paper_mesh.name = "PaperSurface"
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.9
		paper_mesh.material_override = material
		plane_visual.add_child(paper_mesh)
		paper_edges = MeshInstance3D.new()
		var ink := StandardMaterial3D.new()
		ink.albedo_color = Color("324759")
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paper_edges.material_override = ink
		plane_visual.add_child(paper_edges)
		plane_visual.scale = Vector3.ONE*3.5
	paper_mesh.mesh = paper.make_mesh(fold_animation)
	var edges := ImmediateMesh.new()
	edges.surface_begin(Mesh.PRIMITIVE_LINES)
	for face in paper.posed_faces(fold_animation):
		for i in face.size():
			edges.surface_add_vertex(face[i]+Vector3.UP*0.00015)
			edges.surface_add_vertex(face[(i+1)%face.size()]+Vector3.UP*0.00015)
	edges.surface_end()
	paper_edges.mesh = edges
	var center: Vector3 = paper.mass_center()
	paper_mesh.position = -center
	paper_edges.position = -center
	if preview_paper != null:
		preview_paper.mesh = paper_mesh.mesh
		preview_edges.mesh = paper_edges.mesh
		# A stable pivot makes mouse picking independent of the moving center of mass.
		preview_paper.position = Vector3.ZERO
		preview_edges.position = Vector3.ZERO

func _paper_point(pos: Vector2) -> Vector2:
	var unit: Vector2 = (pos-core.paper_rect.position)/core.paper_rect.size
	return Vector2((unit.x-0.5)*paper.width,(unit.y-0.5)*paper.length_m)

func _on_undo_fold() -> void:
	fold_dragging = false
	dart_queue.clear()
	if paper.undo():
		fold_animation = 1.0
		if not core.folds.is_empty(): core.folds.pop_back()
		core.folds_used = core.folds.size()
		fold_has_p1 = false
		crease_mode = paper.history.is_empty()
		_rebuild_plane_visual()
		print("PAPER|undo|%d" % paper.history.size())

func _on_unfold() -> void:
	fold_dragging = false
	crease_mode = true
	dart_queue.clear()
	core.start_level(core.level_idx)
	core.throw_angle = 12.0
	if practice_mode: core.paper_rect = Rect2(90,160,210,300)
	paper.reset(0.7 if practice_mode else float(core.level_dict().ratio))
	fold_animation = 1.0
	fold_has_p1 = false
	_rebuild_plane_visual()

func _on_dart() -> void:
	_on_unfold()
	dart_queue = paper.dart_recipe()

func _record_fold(a: Vector2,b: Vector2,angle: float = PI) -> bool:
	if paper.history.size() >= 8: return false
	if not paper.fold(a,b,angle): return false
	var pa: Vector2 = core.paper_rect.position+(a/Vector2(paper.width,paper.length_m)+Vector2.ONE*0.5)*core.paper_rect.size
	var pb: Vector2 = core.paper_rect.position+(b/Vector2(paper.width,paper.length_m)+Vector2.ONE*0.5)*core.paper_rect.size
	core.folds.append([pa,pb])
	core.folds_used = core.folds.size()
	fold_animation = 0.0
	crease_mode = false
	_rebuild_plane_visual()
	print("PAPER|fold|%d|area=%.5f" % [paper.history.size(),paper.material_area()])
	return true


## C68 打磨B：折纸态 3D 预览——SubViewport 环绕相机 + HUD 小窗（headless 无渲染，节点结构可断言）
func _build_fold_preview() -> void:
	fold_preview_vp = SubViewport.new()
	fold_preview_vp.name = "FoldPreviewVP"
	fold_preview_vp.size = Vector2i(460, 330)
	fold_preview_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	fold_preview_cam = Camera3D.new()
	fold_preview_cam.fov = 55.0
	fold_preview_vp.add_child(fold_preview_cam)
	fold_preview_cam.current = true
	add_child(fold_preview_vp)
	fold_preview_vp.world_3d = World3D.new()
	var preview_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("20495e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.8
	preview_environment.environment = environment
	fold_preview_vp.add_child(preview_environment)
	var preview_light := DirectionalLight3D.new()
	preview_light.rotation_degrees = Vector3(-45,-25,0)
	fold_preview_vp.add_child(preview_light)
	preview_paper = MeshInstance3D.new()
	preview_paper.material_override = paper_mesh.material_override
	preview_paper.scale = Vector3.ONE*3.5
	fold_preview_vp.add_child(preview_paper)
	preview_edges = MeshInstance3D.new()
	preview_edges.material_override = paper_edges.material_override
	preview_edges.scale = Vector3.ONE*3.5
	fold_preview_vp.add_child(preview_edges)
	_rebuild_plane_visual()
	fold_preview_rect = TextureRect.new()
	fold_preview_rect.name = "FoldPreview"
	fold_preview_rect.texture = fold_preview_vp.get_texture()
	fold_preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fold_preview_rect.position = Vector2(480, 88)
	fold_preview_rect.size = Vector2(460, 330)
	fold_preview_rect.stretch_mode = TextureRect.STRETCH_SCALE
	fold_preview_rect.visible = false
	hud.add_child(fold_preview_rect)
	crease_btn = _fold_button("新折痕",Vector2(830,464),Vector2(104,42),_begin_new_crease)

func _begin_new_crease() -> void:
	_end_fold_drag()
	crease_mode = true
	fold_has_p1 = false
	fold_notice = ""

func _preview_ray(pos: Vector2) -> Dictionary:
	var cursor := pos-fold_preview_rect.position
	return {"origin":fold_preview_cam.project_ray_origin(cursor)/3.5,"direction":fold_preview_cam.project_ray_normal(cursor)}

func _paper_hit(ray: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var nearest := INF
	for fi in paper.faces.size():
		var face: PackedVector3Array = paper.faces[fi]
		for j in range(1,face.size()-1):
			var point = Geometry3D.ray_intersects_triangle(ray.origin,ray.direction,face[0],face[j],face[j+1])
			if point is Vector3:
				var distance: float = ray.origin.distance_squared_to(point)
				if distance<nearest:
					nearest=distance; result={"face":fi,"point":point}
	return result

func _hit_paper_at(pos: Vector2) -> Dictionary:
	if fold_preview_rect.get_rect().has_point(pos): return _paper_hit(_preview_ray(pos))
	if _paper_rect().has_point(pos):
		var p := _paper_point(pos)
		return _paper_hit({"origin":Vector3(p.x,1.0,p.y),"direction":Vector3.DOWN})
	return {}

func _select_crease(hit: Dictionary) -> void:
	if not fold_has_p1:
		fold_select_face = int(hit.face)
		fold_select_point = hit.point
		fold_has_p1 = true
		fold_notice = ""
		return
	if int(hit.face)!=fold_select_face:
		fold_notice = "请在同一块纸面上选择第二个点。"
		fold_notice_time = 3.0
		return
	if paper.history.size()<8 and paper.begin_face_fold(fold_select_face,fold_select_point,hit.point):
		var pr := _paper_rect()
		core.folds.append([pr.position+(Vector2(fold_select_point.x/paper.width,fold_select_point.z/paper.length_m)+Vector2.ONE*0.5)*pr.size,pr.position+(Vector2(hit.point.x/paper.width,hit.point.z/paper.length_m)+Vector2.ONE*0.5)*pr.size])
		core.folds_used = paper.history.size()
		fold_animation = 1.0
		crease_mode = false
		fold_notice = ""
		_rebuild_plane_visual()
		print("PAPER|fold|%d|area=%.5f" % [paper.history.size(),paper.material_area()])
	else:
		fold_notice = "这条折痕不能折起，请换同一纸面的两点；也可以先回退。"
		fold_notice_time = 3.0
	fold_has_p1 = false

func _start_fold_drag(hit: Dictionary, pos: Vector2) -> void:
	if paper.history.is_empty(): return
	var action: Dictionary = paper.history.back()
	# Before any bend, grabbing either side chooses which side to lift.
	if not bool(action.moves[int(hit.face)]) and absf(float(action.angle))<0.001:
		for i in action.moves.size(): action.moves[i]=not action.moves[i]
		_rebuild_plane_visual()
	if not bool(action.moves[int(hit.face)]):
		fold_notice = "请拖动黄色的活动纸片；新折痕按钮可添加下一条。"
		fold_notice_time = 3.0
		return
	fold_dragging = true
	drag_start_angle = float(action.angle)
	drag_start_mouse = pos
	drag_plane_origin = action.origin+action.axis*(hit.point-action.origin).dot(action.axis)
	drag_radial = (hit.point-drag_plane_origin).normalized()
	drag_screen_mode=absf(action.axis.dot(_preview_ray(pos).direction))<=0.06
	fold_notice = ""
	print("PAPER|drag-start|angle=%.1f" % rad_to_deg(drag_start_angle))

func _drag_fold_to(pos: Vector2) -> void:
	if not fold_dragging or paper.history.is_empty(): return
	var action: Dictionary = paper.history.back()
	var ray := _preview_ray(pos)
	var denominator: float = action.axis.dot(ray.direction)
	var angle: float = drag_start_angle+(drag_start_mouse.y-pos.y)*PI/220.0
	if not drag_screen_mode:
		if absf(denominator)<=0.06: return
		var t: float = action.axis.dot(drag_plane_origin-ray.origin)/denominator
		if t<=0.0: return
		var radial: Vector3 = ray.origin+ray.direction*t-drag_plane_origin
		if radial.length()>0.003:
			radial=radial.normalized()
			angle=drag_start_angle+atan2(action.axis.dot(drag_radial.cross(radial)),drag_radial.dot(radial))
			drag_radial=radial
	paper.set_last_angle(angle)
	# Accumulate successive short rotations so atan2 cannot wrap a long drag.
	drag_start_angle=float(action.angle)
	drag_start_mouse=pos
	fold_animation = 1.0
	_rebuild_plane_visual()

func _end_fold_drag() -> void:
	if not fold_dragging: return
	fold_dragging = false
	print("PAPER|drag-end|angle=%.1f|area=%.5f" % [rad_to_deg(float(paper.history.back().angle)),paper.material_area()])


## 按关卡重建终点/门（场景应用：终点与低门为自建 ComicObject，高门用基座 gate_frame 模型；
## 规则横向有效半宽见核心 GATE_HALF_PX=5m，视觉宽度与之一致）
func _apply_level_props() -> void:
	for c in level_props.get_children():
		c.queue_free()
	high_gate = null
	low_gate = null
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
	else:
		high_gate = null
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
		low_gate = low
	# C44 打磨：气流区可视化——贴地色带（下沉深蓝/上升暖橙），横跨场地宽，长度=区带宽
	for b in 2:
		var zsuf := "" if b == 0 else "2"
		var zx_m: float = float(L.get("wind_up" + zsuf + "_x", 0.0))
		var za: float = float(L.get("wind_up" + zsuf, 0.0))
		if zx_m <= 0.0 or absf(za) < 1e-6:
			continue
		var zlen_m: float = float(L.get("wind_up" + zsuf + "_len", 10.0))
		var zone: Node3D = ComicObjectScript.new()
		zone.name = "WindZone" + ("1" if b == 0 else "2")
		var strip := BoxMesh.new()
		strip.size = Vector3(24.0, 0.08, zlen_m)
		zone.add_part(strip, Color("01579b") if za < 0.0 else Color("e65100"),
			Transform3D(Basis.IDENTITY, Vector3(0.0, 0.04, 0.0)))
		zone.position = Vector3(0.0, 0.0, -(zx_m + zlen_m / 2.0))
		level_props.add_child(zone)
	_rebuild_plane_visual()   # C68：进场按当前折线参数重建机体（start_level 已重置参数为默认形）


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
	title.text = "纸飞机 · 折叠与试飞"
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
	undo_btn = _fold_button("回退一步",Vector2(320,464),Vector2(130,42),_on_undo_fold)
	dart_btn = _fold_button("示范纸飞机",Vector2(480,464),Vector2(170,42),_on_dart)
	unfold_btn = _fold_button("重新展开",Vector2(670,464),Vector2(140,42),_on_unfold)
	var back_button := Button.new()
	back_button.text = "选关 / 返回"
	back_button.position = Vector2(820,8)
	back_button.size = Vector2(124,30)
	back_button.pressed.connect(_go_menu)
	hud.add_child(back_button)
	_build_menu_panel()
	_build_settle_panel()
	_build_shop_panel()
	_build_final_panel()
	_go_menu()


func _fold_button(text: String,pos: Vector2,size: Vector2,action: Callable) -> Button:
	var button := Button.new()
	button.text=text; button.position=pos; button.size=size
	button.pressed.connect(action)
	button.visible=false
	hud.add_child(button)
	return button

func _panel_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.93)
	st.set_corner_radius_all(12)
	return st


func _build_menu_panel() -> void:
	menu_panel = Panel.new()
	menu_panel.name = "MenuPanel"
	menu_panel.position = Vector2(130,80)
	menu_panel.size = Vector2(700,390)
	menu_panel.add_theme_stylebox_override("panel",_panel_style())
	hud.add_child(menu_panel)
	var title := Label.new()
	title.text = "折一架，再看它怎么飞"
	title.position = Vector2(24,14)
	title.add_theme_color_override("font_color",Color("0d3b4e"))
	menu_panel.add_child(title)
	var trial := Button.new()
	trial.name = "FreeFlightBtn"
	trial.text = "自由折纸与试飞"
	trial.position = Vector2(24,54)
	trial.size = Vector2(250,44)
	trial.pressed.connect(_on_level_pressed.bind(0,true))
	menu_panel.add_child(trial)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24,115)
	scroll.size = Vector2(652,155)
	menu_panel.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	scroll.add_child(grid)
	for i in core.LEVELS.size():
		var button := Button.new()
		button.name = "LevelBtn%d" % i
		button.custom_minimum_size = Vector2(124,42)
		button.add_theme_font_size_override("font_size",12)
		button.pressed.connect(_on_level_pressed.bind(i))
		button.mouse_entered.connect(_on_menu_hover.bind(i))
		grid.add_child(button)
		level_buttons.append(button)
	menu_tip = Label.new()
	menu_tip.position = Vector2(24,280)
	menu_tip.size = Vector2(652,80)
	menu_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_tip.add_theme_font_size_override("font_size",14)
	menu_tip.add_theme_color_override("font_color",Color("0d3b4e"))
	menu_panel.add_child(menu_tip)
	tip_timer = Timer.new()
	tip_timer.wait_time = 2.5
	tip_timer.timeout.connect(_on_menu_tip_rotate)
	add_child(tip_timer)


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
	# C37 打磨：按当前关机制推荐购物方向（动态刷新于 _refresh_shop）
	shop_hint_label = Label.new()
	shop_hint_label.name = "ShopHint"
	shop_hint_label.position = Vector2(24, 42)
	shop_hint_label.add_theme_font_size_override("font_size", 13)
	shop_hint_label.add_theme_color_override("font_color", Color("0d47a1"))
	shop_panel.add_child(shop_hint_label)
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
	return core.paper_rect


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


## 轨迹复盘标记：门/终点（米）；C21 补摆动门摆幅/周期数据（0=静止门）；C44 补气流带（kind="band"）
func chart_marks() -> Array:
	var L: Dictionary = core.LEVELS[core.level_idx]
	var marks: Array = []
	var gate_x_m: float = float(L.get("gate_x", 0.0))
	if gate_x_m > 0.0:
		marks.append({x = gate_x_m, kind = "high", side = float(L.get("gate_side", 0.0)) / PX_PER_M,
			swing = float(L.get("gate_swing", 0.0)) / PX_PER_M, period = float(L.get("gate_period", 0.0))})
	var lg_x_m: float = float(L.get("low_gate_x", 0.0))
	if lg_x_m > 0.0:
		marks.append({x = lg_x_m, kind = "low", side = float(L.get("low_gate_side", 0.0)) / PX_PER_M,
			swing = float(L.get("low_gate_swing", 0.0)) / PX_PER_M, period = float(L.get("low_gate_period", 0.0))})
	marks.append({x = float(L.target_m), kind = "finish", side = 0.0, swing = 0.0, period = 0.0})
	for b in 2:
		var suf := "" if b == 0 else "2"
		var bx_m: float = float(L.get("wind_up" + suf + "_x", 0.0))
		var ba: float = float(L.get("wind_up" + suf, 0.0))
		if bx_m > 0.0 and absf(ba) > 1e-6:
			marks.append({x = bx_m, kind = "band", side = 0.0, swing = 0.0, period = 0.0,
				a = ba, len = float(L.get("wind_up" + suf + "_len", 10.0))})
	return marks


## 阶段 C44 打磨：气流带标注文本（无带返回空串；headless 可断言）
func chart_band_label(a: float, x_m: float, len_m: float) -> String:
	if absf(a) < 1e-6 or x_m <= 0.0:
		return ""
	return ("%s%.0f-%.0fm" % [("↓" if a < 0.0 else "↑"), x_m, x_m + len_m])


func _on_chart_draw() -> void:
	if chart_cache.size() < 2:
		return
	var r := Rect2(Vector2.ZERO, chart.size)
	var max_d: float = maxf(float(core.LEVELS[core.level_idx].target_m),core.flight_distance)*1.08
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
		# C44 打磨：气流带画半透明竖直矩形（下沉蓝/上升橙）+ 短标注
		if String(m.kind) == "band":
			var bx1: float = r.position.x + (float(m.x) + float(m.len)) / max_d * r.size.x
			var band_col := Color("01579b") if float(m.a) < 0.0 else Color("e65100")
			chart.draw_rect(Rect2(Vector2(mx, r.position.y), Vector2(bx1 - mx, r.size.y)), Color(band_col, 0.10), true)
			var band_txt: String = chart_band_label(float(m.a), float(m.x), float(m.len))
			chart.draw_string(FONT, Vector2(mx + 3.0, r.position.y + 11.0), band_txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(band_col, 0.9))
			continue
		var col := Color("b71c1c") if String(m.kind) == "finish" else (Color("f9a825") if String(m.kind) == "high" else Color("0277bd"))
		chart.draw_line(Vector2(mx, r.position.y), Vector2(mx, r.position.y + r.size.y), Color(col, 0.7), 2.0)
		# C17/C21 打磨：门线标注横位与摆幅（finish 无横位不标）
		if String(m.kind) != "finish":
			var side_m: float = float(m.side)
			var label_text: String = chart_gate_label(float(m.x), side_m) + chart_gate_swing_label(float(m.swing), float(m.period))
			chart.draw_string(FONT, Vector2(mx + 3.0, r.position.y + 11.0), label_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(col, 0.9))


## 阶段 C21 打磨：摆动门摆幅标注文本（静止门返回空串；headless 可断言）
func chart_gate_swing_label(swing_m: float, period_s: float) -> String:
	if swing_m < 0.01 or period_s < 0.01:
		return ""
	return " ±%.0fm/%.1fs" % [swing_m, period_s]


## 阶段 C17 打磨：复盘小图门线标注文本（headless 可断言）
func chart_gate_label(x_m: float, side_m: float) -> String:
	if absf(side_m) < 0.01:
		return "%.0fm 门" % x_m
	return "%.0fm 门%+.0fm" % [x_m, side_m]


## 阶段 C29 打磨：摆动门关结算门摆信息文本（无摆动门返回空串；headless 可断言）
func settle_gate_swing_text() -> String:
	var L: Dictionary = core.LEVELS[core.level_idx]
	var parts: Array = []
	var hs_m: float = float(L.get("gate_swing", 0.0)) / core.PX_PER_M
	if hs_m > 0.01:
		parts.append("高门±%.0fm/%.1fs" % [hs_m, float(L.get("gate_period", 0.0))])
	var ls_m: float = float(L.get("low_gate_swing", 0.0)) / core.PX_PER_M
	if ls_m > 0.01:
		parts.append("低门±%.0fm/%.1fs" % [ls_m, float(L.get("low_gate_period", 0.0))])
	if parts.is_empty():
		return ""
	return "门摆：" + " / ".join(parts)


## 阶段 C45 打磨：气流区关结算出口高度文本（无带返回空串；headless 可断言）。
## 双带（沉后托）以第二带出口为复盘点——波形关心的是热流出口高度；未飞到出口（落地/超时）返回空串
func settle_zone_text() -> String:
	var L: Dictionary = core.LEVELS[core.level_idx]
	var x_m: float = float(L.get("wind_up_x", 0.0))
	var a: float = float(L.get("wind_up", 0.0))
	if x_m <= 0.0 or absf(a) < 1e-6:
		return ""
	var exit_m: float = x_m + float(L.get("wind_up_len", 10.0))
	var tag := "谷出口" if a < 0.0 else "上升带出口"
	var x2_m: float = float(L.get("wind_up2_x", 0.0))
	var a2: float = float(L.get("wind_up2", 0.0))
	if x2_m > 0.0 and absf(a2) > 1e-6:
		exit_m = x2_m + float(L.get("wind_up2_len", 10.0))
		tag = "热流出口" if a2 > 0.0 else tag
	for p in core.trail:
		var pp: Vector2 = p
		if (pp.x - core.START_X) / core.PX_PER_M >= exit_m:
			return "%s %.1f 米" % [tag, (core.GROUND_Y - pp.y) / core.PX_PER_M]
	return ""


## 阶段 C55 打磨：商店状态栏函数化并补当前强化明细（headless 可断言）
func shop_status_text() -> String:
	return "肉鸽商店 · 金币 %d · 店内 %d 件 · 买强化带入第 %d 关 · 强化：力气 x%d · 翼面 x%d · 加固 x%d · 铅条 x%d · 侧配 x%d" % [
		core.coins, core.shop_items.size(), core.level_idx + 2,
		int(core.upgrades.power), int(core.upgrades.wing),
		int(core.upgrades.get("stiff", 0)), int(core.upgrades.get("ballast", 0)),
		int(core.upgrades.get("sideWeight", 0))]


## 阶段 C53 打磨：飞行中当前气流区实时指示（不在带内返回空串；headless 可断言）
func fly_zone_text() -> String:
	var a: float = core.updraft_accel()
	if absf(a) < 1e-6:
		return ""
	return " · 谷中↓" if a < 0.0 else " · 热流中↑"


## 阶段 C37 起商店策略提示函数化（C45 补气流区行；headless 可断言）
func shop_strategy_hints() -> Array:
	var L: Dictionary = core.LEVELS[core.level_idx]
	var hint_parts: Array = []
	if core.wind_mode() == "head":
		hint_parts.append("逆风关：纸面加固降阻力")
	elif core.wind_mode() == "side":
		hint_parts.append("侧风关：重心铅条驯配平")
	if float(L.get("gate_swing", 0.0)) > 0.0 or float(L.get("low_gate_swing", 0.0)) > 0.0:
		hint_parts.append("摆门关：配平仪精确切门")
	if absf(float(L.get("wind_up", 0.0))) > 0.0:
		hint_parts.append("气流区关：翼面升力扛谷，螺旋桨保速乘流")
	return hint_parts


func paint_chart_axes(r: Rect2, max_d: float, max_h: float) -> void:
	chart.draw_rect(r, Color(1, 1, 1, 0.55))
	chart.draw_line(r.position + Vector2(0, r.size.y), r.position + Vector2(r.size.x, r.size.y), Color("607d8b"), 1.5)
	chart.draw_string(FONT, r.position + Vector2(2.0, 12.0), "%.0fm" % max_d, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("607d8b"))
	chart.draw_string(FONT, r.position + Vector2(2.0, r.size.y - 3.0), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("607d8b"))


func _go_menu() -> void:
	charging=false;charge=0.0;charge_source=""
	_end_fold_drag()
	preview_rotating = false
	core.lateral_input = 0.0
	core.dive_input = false
	practice_mode = false
	core.physical_trial = false
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
		# C75 打磨：大师篇（L31+）金色字体 + 悬停提示，与主线关区分
		if i >= 30:
			lb.add_theme_color_override("font_color", Color("9c6f19"))
			lb.tooltip_text = "大师篇：" + String(core.LEVELS[i].tip)
		else:
			lb.tooltip_text = String(core.LEVELS[i].tip)
	menu_tip.text = "先在自由试飞中比较折法。折痕会改变翼面、重心和稳定性；蓄力与角度决定出手方式。"
	print("PAPER|menu|levels=%d" % core.LEVELS.size())
	_update_status()


func _on_reset_run() -> void:
	core = CoreScript.new()
	_go_menu()


func _on_level_pressed(i: int, practice: bool = false) -> void:
	charging=false;charge=0.0;charge_source=""
	throw_rotation_degrees=Vector3(12,0,0)
	fold_dragging = false
	preview_rotating = false
	crease_mode = true
	fold_notice = ""
	fold_preview_orbit = 0.6
	preview_elevation = 0.65
	preview_distance = 1.45
	practice_mode = practice
	core.physical_trial = practice
	if i < 0 or i >= core.LEVELS.size() or i > core.unlocked:
		return
	core.start_level(i)
	print("PAPER|level|%d|practice=%s" % [i+1,practice])
	core.throw_angle = 12.0
	if practice_mode: core.paper_rect = Rect2(90,160,210,300)
	paper.reset(0.7 if practice_mode else float(core.level_dict().ratio))
	dart_queue.clear()
	fold_animation = 1.0
	_rebuild_plane_visual()
	prev_state = "fold"
	_hide_all_panels()
	fold_btn.visible = true
	fold_has_p1 = false
	_apply_level_props()
	_update_status()
	if origami_editor!=null:
		origami_editor.load_sheet(0.7 if practice_mode else float(core.level_dict().ratio),"自由折纸" if practice_mode else "第%d关 · %s" % [i+1,String(core.LEVELS[i].short)])
		origami_editor.visible=true


func _sync_workbench() -> void:
	paper=origami_editor.model.paper
	core.folds.clear()
	for action in paper.history:
		var a:Vector2=Vector2(action.origin.x,action.origin.z)
		var b:Vector2=a+Vector2(action.axis.x,action.axis.z)*0.1
		core.folds.append([a,b])
	core.folds_used=core.folds.size()
	fold_animation=1.0
	_rebuild_plane_visual()

func _on_fold_done() -> void:
	if core.state != "fold":
		return
	if fold_animation < 1.0 or not dart_queue.is_empty(): return
	_end_fold_drag()
	if origami_editor!=null and not origami_editor.model.transaction.is_empty(): return
	core.finish_folds()
	if origami_editor!=null: origami_editor.visible=false
	_rebuild_plane_visual()   # C68 打磨A：折完即形变
	fold_btn.visible = false
	charging = false
	charge_source=""
	charge = 0.0
	_set_throw_angle(core.throw_angle)
	_update_status()


func _begin_throw_charge(source: String) -> void:
	if core.state!="throw" or charging: return
	for number in throw_rotation_numbers:
		if number.get_line_edit().has_focus(): number.apply()
		number.get_line_edit().release_focus()
	charging=true; charge=0.0; charge_source=source
	_sync_preflight_controls()

func _input(event: InputEvent) -> void:
	# Release is global so dragging off the button cannot leave charging stuck.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and charge_source=="button":
		_release_throw()
	if event is InputEventKey and event.keycode==KEY_SPACE and not event.pressed and charge_source=="keyboard":
		_release_throw()

func _set_throw_angle(value: float) -> void:
	_set_throw_rotation(0,value)

func _set_throw_rotation(axis: int, value: float) -> void:
	if syncing_throw_angle or core.state!="throw" or charging or not is_finite(value): return
	if axis<0 or axis>2: return
	throw_rotation_degrees[axis]=clampf(roundf(value),-180.0,180.0)
	core.throw_angle=throw_rotation_degrees.x
	var preview = PaperFlight.new()
	preview.launch(paper,core.throw_angle,0.0,throw_rotation_degrees.y,throw_rotation_degrees.z)
	throw_preview_basis=preview.orientation
	_sync_preflight_controls()
	print("PAPER|aim|angle=%.0f" % core.throw_angle)
	print("PAPER|pose|xyz=%.0f,%.0f,%.0f" % [throw_rotation_degrees.x,throw_rotation_degrees.y,throw_rotation_degrees.z])

func _reset_throw_rotation() -> void:
	if core.state!="throw" or charging: return
	throw_rotation_degrees=Vector3(12,0,0)
	for axis in 3:
		# Discard pending text before deferred focus-exit submission can restore it.
		var entry=throw_rotation_numbers[axis].get_line_edit()
		entry.text=str(throw_rotation_degrees[axis]);entry.release_focus()
	_set_throw_angle(12)

func _sync_preflight_controls() -> void:
	if preflight_panel==null: return
	preflight_panel.visible=core.state=="throw"
	syncing_throw_angle=true
	for axis in 3:
		var slider=throw_rotation_sliders[axis];var number=throw_rotation_numbers[axis]
		if not is_equal_approx(slider.value,throw_rotation_degrees[axis]): slider.value=throw_rotation_degrees[axis]
		# Preserve pending numerical text while the player is typing.
		if not is_equal_approx(number.value,throw_rotation_degrees[axis]): number.value=throw_rotation_degrees[axis]
		if slider.editable==charging: slider.editable=not charging
		if number.editable==charging: number.editable=not charging
	throw_reset_btn.disabled=charging
	throw_charge_meter.value=charge
	throw_charge_btn.text="姿态已锁定 · 蓄力 %.0f%%" % (charge*100.0) if charging else "按住蓄力，松开发射"
	syncing_throw_angle=false

func _build_preflight_controls() -> void:
	preflight_panel=Panel.new(); preflight_panel.name="PreflightControls"
	preflight_panel.position=Vector2(548,96); preflight_panel.size=Vector2(392,430)
	var box:=StyleBoxFlat.new();box.bg_color=Color("1c293b");box.set_corner_radius_all(10)
	preflight_panel.add_theme_stylebox_override("panel",box);preflight_panel.visible=false;hud.add_child(preflight_panel)
	var title:=Label.new();title.text="飞前姿态 · XYZ旋转";title.position=Vector2(22,14);title.add_theme_font_size_override("font_size",22)
	title.add_theme_color_override("font_color",Color("e5ecf7"));preflight_panel.add_child(title)
	var caption:=Label.new();caption.text="三轴独立旋转 · −180°～180°";caption.position=Vector2(22,50)
	caption.add_theme_font_size_override("font_size",15);caption.add_theme_color_override("font_color",Color("a9bfd9"));preflight_panel.add_child(caption)
	for axis in 3:
		var label:=Label.new();label.text=["X 抬头","Y 朝向","Z 侧倾"][axis];label.position=Vector2(22,84+axis*68);label.add_theme_font_size_override("font_size",15);preflight_panel.add_child(label)
		var slider:=HSlider.new();slider.name="LaunchRotationSlider%d"%axis;slider.position=Vector2(82,86+axis*68);slider.size=Vector2(166,26)
		slider.min_value=-180;slider.max_value=180;slider.step=1;slider.focus_mode=Control.FOCUS_NONE
		slider.value_changed.connect(func(value: float): _set_throw_rotation(axis,value));preflight_panel.add_child(slider);throw_rotation_sliders.append(slider)
		var number:=SpinBox.new();number.name="LaunchRotationNumber%d"%axis;number.position=Vector2(279,80+axis*68);number.size=Vector2(92,36)
		number.min_value=-180;number.max_value=180;number.step=1;number.suffix="°"
		number.value_changed.connect(func(value: float): _set_throw_rotation(axis,value));preflight_panel.add_child(number);throw_rotation_numbers.append(number)
		number.get_line_edit().text_submitted.connect(func(_text: String): number.get_line_edit().release_focus())
	throw_angle_slider=throw_rotation_sliders[0];throw_angle_number=throw_rotation_numbers[0]
	throw_reset_btn=Button.new();throw_reset_btn.text="复位姿态 · X 12° / Y 0° / Z 0°";throw_reset_btn.position=Vector2(22,292);throw_reset_btn.size=Vector2(348,34);throw_reset_btn.focus_mode=Control.FOCUS_NONE
	throw_reset_btn.pressed.connect(_reset_throw_rotation);preflight_panel.add_child(throw_reset_btn)
	throw_charge_btn=Button.new();throw_charge_btn.name="ChargeLaunchButton";throw_charge_btn.position=Vector2(22,338);throw_charge_btn.size=Vector2(348,44);throw_charge_btn.focus_mode=Control.FOCUS_NONE
	throw_charge_btn.button_down.connect(func(): _begin_throw_charge("button"));preflight_panel.add_child(throw_charge_btn)
	throw_charge_meter=ProgressBar.new();throw_charge_meter.position=Vector2(22,386);throw_charge_meter.size=Vector2(348,12);throw_charge_meter.max_value=1.0;throw_charge_meter.show_percentage=false
	preflight_panel.add_child(throw_charge_meter)
	var hint:=Label.new();hint.text="↑↓ 调整X · 空格或按钮蓄力";hint.position=Vector2(22,406);hint.add_theme_font_size_override("font_size",13)
	hint.add_theme_color_override("font_color",Color("a9bfd9"));preflight_panel.add_child(hint)

func _release_throw() -> void:
	if core.state == "throw" and charging:
		charging = false
		charge_source=""
		for number in throw_rotation_numbers: number.get_line_edit().release_focus()
		last_throw = {angle = core.throw_angle, power = charge, rotation_degrees = throw_rotation_degrees}
		core.do_throw(core.throw_angle, charge)
		# The legacy 2D setup clamps pitch to 0–60; the 3D pose keeps its full range.
		core.throw_angle=throw_rotation_degrees.x
		core.physical_flight = PaperFlight.new()
		core.physical_flight.launch(paper,core.throw_angle,charge,throw_rotation_degrees.y,throw_rotation_degrees.z)
		print("PAPER|launch|angle=%.0f|rotation=%.0f,%.0f,%.0f|mass=%.5f|area=%.5f" % [core.throw_angle,throw_rotation_degrees.x,throw_rotation_degrees.y,throw_rotation_degrees.z,core.physical_flight.mass,core.physical_flight.area])
		charge = 0.0
		_sync_preflight_controls()
		_update_status()


func _on_settle_continue() -> void:
	if practice_mode:
		var saved_folds: Array = core.folds.duplicate(true)
		core.start_level(0)
		core.throw_angle = 12.0
		throw_rotation_degrees=Vector3(12,0,0)
		core.folds = saved_folds
		core.folds_used = saved_folds.size()
		prev_state = "fold"
		_hide_all_panels()
		fold_btn.visible = true
		fold_has_p1 = false
		_rebuild_plane_visual()
		_update_status()
		return
	var go: String = core.settle_continue()
	prev_state = core.state
	_hide_all_panels()
	if go == "shop":
		_show_shop()
	elif go == "final":
		_show_final()
	elif go == "retry" or go == "fold":
		_on_level_pressed(core.level_idx)
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
	final_body.text = "5 关全部飞过终点旗！\n折法、投掷角度、逆风、侧风与顺风：完成。\n总飞行 %.1f 米 · 最远一掷 %.1f 米\n也可以返回自由折纸，继续尝试自己的折法。" % [core.total_distance, core.best_distance]
	final_panel.visible = true
	print("PAPER|final|levels=5")


func _refresh_shop() -> void:
	shop_coins.text = "金币：%d" % core.coins
	# C37 打磨/C45 函数化：按当前关机制推荐购物方向（逆风/侧风/摆门/气流区）
	var hint_parts: Array = shop_strategy_hints()
	shop_hint_label.text = " · ".join(hint_parts) if hint_parts.size() > 0 else ""
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


## C30 打磨：选关提示自动轮播（仅在菜单态轮播已解锁关卡的机制说明）
func _on_menu_tip_rotate() -> void:
	if core.state != "menu" or menu_tip == null:
		return
	var tips: Array = []
	for i in core.LEVELS.size():
		if i <= core.unlocked:
			tips.append(String(core.LEVELS[i].tip))
	if tips.is_empty():
		return
	tip_idx = (tip_idx + 1) % tips.size()
	menu_tip.text = tips[tip_idx]


# ---------------- 输入（真实事件路径） ----------------

func _unhandled_input(event: InputEvent) -> void:
	if core.state=="fold" and origami_editor!=null: return
	if core.state=="fold":
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
			preview_rotating=event.pressed
			return
		if event is InputEventMouseButton and event.pressed and fold_preview_rect.get_rect().has_point(event.position):
			if event.button_index==MOUSE_BUTTON_WHEEL_UP:
				preview_distance=maxf(0.85,preview_distance-0.1)
				return
			if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
				preview_distance=minf(2.6,preview_distance+0.1)
				return
		if event is InputEventMouseMotion:
			if fold_dragging: _drag_fold_to(event.position)
			elif preview_rotating:
				fold_preview_orbit-=event.relative.x*0.012
				preview_elevation=clampf(preview_elevation+event.relative.y*0.008,0.15,1.35)
			return
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			_end_fold_drag()
			fold_has_p1=false
			crease_mode=paper.history.is_empty()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if core.state == "fold":
			if not event.pressed:
				_end_fold_drag()
			elif fold_animation>=1.0 and dart_queue.is_empty():
				var hit := _hit_paper_at(pos)
				if not hit.is_empty():
					if crease_mode: _select_crease(hit)
					elif fold_preview_rect.get_rect().has_point(pos): _start_fold_drag(hit,pos)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if core.state == "throw":
			if k.pressed and not k.echo:
				if k.keycode == KEY_UP:
					_set_throw_angle(core.throw_angle+3.0)
				elif k.keycode == KEY_DOWN:
					_set_throw_angle(core.throw_angle-3.0)
				elif k.keycode == KEY_SPACE:
					_begin_throw_charge("keyboard")
			elif not k.pressed and k.keycode == KEY_SPACE and charge_source=="keyboard":
				_release_throw()
		elif core.state == "fly":
			# 阶段 B1：A/D 有限侧向转向（真实按键事件；松开侧清零）
			if k.pressed and not k.echo:
				if k.keycode == KEY_A:
					core.lateral_input = -1.0
				elif k.keycode == KEY_D:
					core.lateral_input = 1.0
				elif k.keycode == KEY_S or k.keycode == KEY_DOWN:
					core.dive_input = true   # C88 俯冲输入
			elif not k.pressed:
				if k.keycode == KEY_A and float(core.lateral_input) < 0.0:
					core.lateral_input = 0.0
				elif k.keycode == KEY_D and float(core.lateral_input) > 0.0:
					core.lateral_input = 0.0
				elif k.keycode == KEY_S or k.keycode == KEY_DOWN:
					core.dive_input = false
		if k.pressed and not k.echo and k.keycode == KEY_R and core.state == "fly":
			_snap_camera()


# ---------------- 主循环 ----------------

func _process(delta: float) -> void:
	if core.state == "fold" and fold_animation < 1.0:
		fold_animation = minf(1.0,fold_animation+delta/0.75)
		_rebuild_plane_visual()
	if core.state == "fold" and fold_animation >= 1.0 and not dart_queue.is_empty():
		var action: Dictionary = dart_queue.pop_front()
		_record_fold(action.a,action.b,float(action.angle))
	for button in [undo_btn,dart_btn,unfold_btn,crease_btn]: button.visible = false
	fold_btn.visible=false
	status_label.visible=core.state!="fold"
	hint_label.visible=core.state!="fold"
	if origami_editor!=null: origami_editor.visible=core.state=="fold"
	undo_btn.disabled = paper.history.is_empty()
	crease_btn.disabled = fold_animation<1.0 or not dart_queue.is_empty() or paper.history.size()>=8
	fold_notice_time=maxf(0.0,fold_notice_time-delta)
	fold_btn.disabled = fold_animation < 1.0 or not dart_queue.is_empty()
	if core.state == "throw" and charging:
		charge = minf(1.0, charge + delta / CHARGE_TIME)
	if core.state != prev_state:
		if core.state == "settle":
			_show_settle_panel()
			if practice_mode:
				settle_title.text = "试飞完成"
				chart_marks_cache = []
				settle_body.text = "距离 %.1f 米 · 时间 %.1f 秒 · 最高 %.1f 米\n\n回退或重新折叠，看看下一架会有什么不同。" % [core.flight_distance,core.flight_time,core.apex_m]
				settle_btn.text = "继续折纸试飞"
				print("PAPER|land|%.2fm|%.2fs" % [core.flight_distance,core.flight_time])
			else:
				print("PAPER|course|%d|pass=%s|%.2fm" % [core.level_idx+1,core.last_pass,core.flight_distance])
		# C15 修复：离开 fly 态清零横向输入（防止按住 A/D 跨掷残留带偏下一掷）
		if prev_state == "fly" and core.state != "fly":
			core.lateral_input = 0.0
			core.dive_input = false   # C88 俯冲态跨掷清零（同 C15 横向教训）
		prev_state = core.state
	_update_status()
	_update_visuals()
	_sync_preflight_controls()
	# C68 打磨B：折纸态预览窗——可见性随状态，相机绕机体慢速环绕
	if fold_preview_rect != null:
		fold_preview_rect.visible = false
		fold_preview_vp.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if core.state == "fold" and fold_preview_cam != null and plane_visual != null:
		fold_preview_cam.position = Vector3(sin(fold_preview_orbit)*preview_distance,tan(preview_elevation)*preview_distance,cos(fold_preview_orbit)*preview_distance)
		fold_preview_cam.look_at(Vector3.ZERO)
	paint.queue_redraw()


func _physics_process(delta: float) -> void:
	if core.state == "fly":
		core.step(delta)


func _update_visuals() -> void:
	var wp := to_world(core.plane_pos, float(core.lateral))
	plane_visual.position = wp
	# 偏航=航向角（表现），小滚转倾斜=横移视觉（相机不继承）
	var bank: float = clampf(-float(core.lateral_vel) / float(core.LAT_VMAX), -1.0, 1.0) * 0.3
	if core.physical_flight != null:
		plane_visual.basis = core.physical_flight.orientation.scaled(Vector3.ONE*3.5)
	else:
		if core.state=="throw": plane_visual.basis=throw_preview_basis.scaled(Vector3.ONE*3.5)
		else: plane_visual.rotation = Vector3.ZERO
	# C10 摆动门：高门横位每帧随 gate_side_at(flight_time)（与规则判定同一公式）
	if high_gate != null and core.state == "fly":
		high_gate.position.x = float(core.gate_side_at(float(core.flight_time))) / PX_PER_M
		# C84 时机门：飞行中门体随开启窗显隐（非飞行态常显供观察路线）
		high_gate.visible = core.gate_open()
	if low_gate != null and core.state == "fly":
		low_gate.position.x = float(core.low_gate_side_at(float(core.flight_time))) / PX_PER_M
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
	if core.world_trail.size() >= 2:
		trail_imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for point in core.world_trail: trail_imm.surface_add_vertex(point)
		trail_imm.surface_end()
		return
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
		settle_btn.text = "查看总成绩" if is_last else "下一关"
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
	# C29 打磨：摆动门关卡结算补门摆信息（摆幅/周期，帮助玩家数拍）
	var swing_info: String = settle_gate_swing_text()
	if swing_info != "":
		lat_info += " · " + swing_info
	# C45 打磨：气流区关结算补出口高度（帮助玩家把乘流与门高关联）
	var zone_info: String = settle_zone_text()
	if zone_info != "":
		lat_info += " · " + zone_info
	settle_body.text = "%s\n飞行距离 %.1f 米 · 目标 %.0f 米 · 顶点 %.1f 米%s\n%s\n小贴士：%s" % [
		String(L.name), core.flight_distance, float(L.target_m), core.apex_m, lat_info, earn_txt, String(L.tip)]
	# 轨迹复盘小图（阶段 C）：高度-距离 + 门/终点标记
	chart_cache = chart_points()
	chart_marks_cache = chart_marks()
	chart.visible = true
	chart.queue_redraw()


func _update_status() -> void:
	if practice_mode:
		match core.state:
			"fold":
				var angle: float = 0.0 if paper.history.is_empty() else rad_to_deg(float(paper.history.back().angle))
				status_label.text = "自由折纸 · 已折 %d 步 · 当前折角 %+.0f°" % [paper.history.size(),angle]
				hint_label.text = _fold_help()
			"throw":
				status_label.text = "投掷角度 %d° · 按住空格蓄力，松开发射" % core.throw_angle
				hint_label.text = "上下键调整角度。飞行中 A/D 倾斜转向、S 俯冲。"
			"fly":
				status_label.text = "飞行 %.1f 米 · 高度 %.1f 米 · 速度 %.1f 米/秒" % [core.flight_distance,(GROUND_Y-core.plane_pos.y)/PX_PER_M,core.physical_flight.velocity.length()]
				hint_label.text = "A/D 倾斜转向 · S 俯冲 · R 复位相机"
			"settle":
				status_label.text = "试飞完成 · 距离 %.1f 米" % core.flight_distance
				hint_label.text = ""
		return
	var L: Dictionary = core.LEVELS[core.level_idx]
	match core.state:
		"menu":
			status_label.text = "纸飞机 3D · 五关挑战与自由折纸"
			hint_label.text = "折出形状，再蓄力投掷；观察折法、角度与风如何改变飞行。"
		"fold":
			status_label.text = "%s · 折纸：已折 %d/%d 条 · 目标 %.0f 米" % [
				String(L.name), core.folds_used, maxi(6,int(L.folds)), float(L.target_m)]
			hint_label.text = _fold_help()+" · "+String(L.tip)
		"throw":
			status_label.text = "%s · 投掷角度 %d° · 目标 %.0f 米" % [String(L.name), int(round(core.throw_angle)), float(L.target_m)]
			hint_label.text = "鼠标上下或方向键调角度，按住空格/左键蓄力，松开发射；R 复位相机"
		"fly":
			var live_m: float = (core.plane_pos.x - START_X) / PX_PER_M
			var h_m: float = (GROUND_Y - core.plane_pos.y) / PX_PER_M
			# C36 打磨：摆动门关状态栏补实时门位（与判定共用 gate_side_at/low_gate_side_at）
			var gate_pos_txt: String = ""
			if float(L.get("gate_swing", 0.0)) > 0.0:
				gate_pos_txt = " · 高门位 %+.1f m" % (float(core.gate_side_at(core.flight_time)) / PX_PER_M)
			if float(L.get("gate_open_t1", 0.0)) > 0.0:
				gate_pos_txt += " · 门开 %.1f-%.1fs" % [float(L.get("gate_open_t0", 0.0)), float(L.get("gate_open_t1", 0.0))]
			if float(L.get("low_gate_swing", 0.0)) > 0.0:
				gate_pos_txt += " · 低门位 %+.1f m" % (float(core.low_gate_side_at(core.flight_time)) / PX_PER_M)
			# C53 打磨：气流区关状态栏补实时区带指示（与判定共用 updraft_accel）
			var zone_txt: String = fly_zone_text()
			status_label.text = "%s · 飞行中 %.1f 米 / 目标 %.0f 米 · 高度 %.1f 米 · 横移 %.1f 米%s%s" % [
				String(L.name), live_m, float(L.target_m), h_m, float(core.lateral) / PX_PER_M, gate_pos_txt, zone_txt]
			# C30 打磨：飞行提示按关卡机制定制（摆门/侧风/气流区关提醒）
			var fly_hint := "A/D 倾斜转向 · S 俯冲 · R 复位相机"
			if float(L.get("gate_swing", 0.0)) > 0.0 or float(L.get("low_gate_swing", 0.0)) > 0.0:
				fly_hint = "门在摆动，注意穿越时机 · " + fly_hint
			if core.wind_mode() == "side" or absf(core.side_wind_accel()) > 0.0:
				fly_hint = "侧风会带偏航向 · " + fly_hint
			if float(L.get("wind_up_x", 0.0)) > 0.0:
				fly_hint = "气流区会改变高度 · " + fly_hint
			hint_label.text = fly_hint
		"settle":
			status_label.text = ("过关！" if core.last_pass else "挑战失败") + " · 飞行 %.1f 米" % core.flight_distance
			hint_label.text = ""

		"shop":
			status_label.text = shop_status_text()
			hint_label.text = "买不起就点跳过；金币 = 门奖（即时）+ 距离/10 + 过关奖励"
		"final":
			status_label.text = "五关全部完成！"
			hint_label.text = ""


func _fold_help() -> String:
	if fold_notice_time>0.0 and fold_notice!="": return fold_notice
	if fold_dragging: return "拖动控制折角，松手保留；右键拖动旋转视角。"
	if fold_has_p1: return "再点同一纸面上的另一点，画出折痕。"
	if crease_mode: return "两点画折痕 → 拖动黄色纸片折起；右键旋转视角，滚轮缩放。"
	return "拖动黄色纸片调整折角；点「新折痕」可在立体纸面继续折。"


# ---------------- 2D 覆盖绘制（纸面/折线/投掷辅助） ----------------

func _on_paint() -> void:
	var st: String = String(core.state)
	if st == "menu" or st == "final":
		return
	_draw_wind_tag()
	if st == "fold": return
	if st == "throw":
		_draw_throw_ui()


func _draw_paper() -> void:
	var pr := _paper_rect()
	paint.draw_rect(pr, Color(1, 1, 1, 0.18))
	for face in paper.posed_faces(fold_animation):
		var projected := PackedVector2Array()
		for p in face:
			projected.append(pr.position+(Vector2(p.x/paper.width,p.z/paper.length_m)+Vector2.ONE*0.5)*pr.size)
		if Geometry2D.triangulate_polygon(projected).size() >= 3:
			paint.draw_colored_polygon(projected,Color("fff6da"))
		projected.append(projected[0])
		paint.draw_polyline(projected,Color("5d7180"),1.5,true)
	paint.draw_rect(pr, Color("b0bec5"), false, 2.0)
	paint.draw_string(FONT, pr.position + Vector2(0.0, -10.0),
		"纸张：剩余可折 %d 次" % (maxi(6,int(core.LEVELS[core.level_idx].folds)) - core.folds_used),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("455a64"))
	if fold_has_p1:
		var p := pr.position+(Vector2(fold_select_point.x/paper.width,fold_select_point.z/paper.length_m)+Vector2.ONE*0.5)*pr.size
		paint.draw_circle(p,4.0,Color("e53935"))
		paint.draw_circle(fold_preview_rect.position+fold_preview_cam.unproject_position(fold_select_point*3.5),5.0,Color("e53935"))


func _draw_params() -> void:
	paint.draw_string(FONT,Vector2(480,440),"纸面 %.0f cm² · 折角 %+.0f° · 松手保留立体形状" % [paper.material_area()*10000.0,0.0 if paper.history.is_empty() else rad_to_deg(float(paper.history.back().angle))],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("0d3b4e"))


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



func _draw_wind_tag() -> void:
	var tag: String = wind_tag_text()
	if tag == "":
		return
	paint.draw_string(FONT, Vector2(730.0, 60.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("5c6bc0"))


## 阶段 C16 打磨：风标签文本函数化（headless 可测；覆盖 none/head/tail/侧风/切变/双段切变/正交侧风）
func wind_tag_text() -> String:
	var w: String = core.wind_mode()
	var speed: float = float(core.LEVELS[core.level_idx].get("wind_mps",0.0))
	if speed > 0.0:
		var wind_name: String = "逆风" if w=="head" else ("顺风" if w=="tail" else "侧风 →")
		return "%s %.1f 米/秒" % [wind_name,speed]
	var anemo: bool = core.owned.has("anemo")   # C80 气流计：持有才显示精确数值
	if w == "side":
		var left: bool = core.wind_side() < 0.0
		var dir1: String = "←" if left else "→"
		var shear_m: float = float(core.LEVELS[core.level_idx].get("shear_x", 0.0))
		var shear2_m: float = float(core.LEVELS[core.level_idx].get("shear_x2", 0.0))
		if shear_m > 0.0 and shear2_m > 0.0:
			var dir2: String = "←" if core.wind_side2() < 0.0 else "→"
			var dir3: String = "←" if core.wind_side3() < 0.0 else "→"
			var base3: String = "双段切变 %.0f/%.0fm：侧风 %s→%s→%s" % [shear_m, shear2_m, dir1, dir2, dir3]
			return base3 + _anemo_note("侧风 %dpx/s²" % int(abs(core.wind_side()) * core.LAT_WIND)) if anemo else base3
		if shear_m > 0.0:
			var after: bool = core.wind_side2() < 0.0
			var base1: String = "风切变 %.0fm：侧风 %s → %s" % [shear_m, dir1, "←" if after else "→"]
			return base1 + _anemo_note("侧风 %dpx/s²" % int(abs(core.wind_side()) * core.LAT_WIND)) if anemo else base1
		var base0: String = "侧风 %s" % dir1
		return base0 + _anemo_note("侧风 %dpx/s²" % int(abs(core.wind_side()) * core.LAT_WIND)) if anemo else base0 + "（A/D 顶风）"
	# head/tail/none：基础风 ＋ 正交侧风段 ＋ 气流区段（C42），none 且全无则空串（L1 路径不变）
	var label := ""
	if w == "head":
		label = "逆风 阻力 x1.25"
	elif w == "tail":
		label = "顺风 恒定推力" + ("（+90px/s²）" if anemo else "")
	if absf(core.side_wind_accel()) > 0.0:
		label = _ortho_wind_text(label + " ＋ ") if label != "" else _ortho_wind_text("")
	var up_txt := updraft_text()
	if up_txt != "":
		label = ("%s ＋ %s" % [label, up_txt]) if label != "" else up_txt
	return label


## C80 气流计精确数值括注（未持有返回空串）
func _anemo_note(txt: String) -> String:
	return "（%s）" % txt if core.owned.has("anemo") else ""


## C42 气流区标签：wind_up_x 未配置或 wind_up=0 返回空串（既有关路径不变）；C43 双区带依次列出
func updraft_text() -> String:
	var parts := PackedStringArray()
	var anemo: bool = core.owned.has("anemo")   # C80 气流计：持有显示精确加速度
	for b in 2:
		var suf := "" if b == 0 else "2"
		var x_m: float = float(core.LEVELS[core.level_idx].get("wind_up" + suf + "_x", 0.0))
		var a: float = float(core.LEVELS[core.level_idx].get("wind_up" + suf, 0.0))
		if x_m <= 0.0 or absf(a) < 1e-6:
			continue
		var len_m: float = float(core.LEVELS[core.level_idx].get("wind_up" + suf + "_len", 10.0))
		var tag := "上升气流" if a > 0.0 else "下沉气流"
		var note := "，%+dpx/s²" % int(a) if anemo else ""
		parts.append("%s %.0f-%.0f 米（%s%s）" % [tag, x_m, x_m + len_m, "乘流爬升" if a > 0.0 else "俯冲穿越", note])
	return " ＋ ".join(parts)


## 正交侧风（C13）标签段：切变面按符号翻转 side_wind（幅值不变），段向 = d1 / -d1 / d1
func _ortho_wind_text(prefix: String) -> String:
	var sw: float = core.side_wind_accel()
	var dir1: String = "←" if sw < 0.0 else "→"
	var dir_flip: String = "→" if sw < 0.0 else "←"
	var anemo_note: String = _anemo_note("%+dpx/s²" % int(sw))   # C80 气流计
	var shear_m: float = float(core.LEVELS[core.level_idx].get("shear_x", 0.0))
	var shear2_m: float = float(core.LEVELS[core.level_idx].get("shear_x2", 0.0))
	if shear_m > 0.0 and shear2_m > 0.0:
		return "%s三段侧风 %.0f/%.0fm：%s%s%s%s" % [prefix, shear_m, shear2_m, dir1, dir_flip, dir1, anemo_note]
	if shear_m > 0.0:
		return "%s切变侧风 %.0fm：%s → %s%s" % [prefix, shear_m, dir1, dir_flip, anemo_note]
	if prefix == "":
		return "%s侧风%s（A/D 顶风）" % [prefix, dir1]
	return "%s侧风%s%s" % [prefix, dir1, anemo_note]


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
