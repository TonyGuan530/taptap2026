extends Node3D
## DEMO9 3D 场景根（阶段 A 灰模 + 流程闭环，契约 game/demo09_3d/RULES_CONTRACT.md）
## 逻辑：GarageModel（统一校验）+ LaneCore（旧 px 纵向物理，已与旧场景位级对照）。
## 本脚本兼任 RunController（契约 §6）：状态机 menu→build→drive→settle→final、解锁、
## total_time（含翻车局）、按关布局快照与 restore 预填；全部变更走 GarageModel 公开入口。
## 输入：阶段 A 走 InputMap action 层（demo09_thr_pos/neg，注册 Right/Left），不写死 keycode；
## 测试用 Input.action_press 注入即等于真实按键语义。
## 视觉：场景应用套件（comic_style 统一材质 + models 现成模型）；相机 Rig→SpringArm→Camera（A4）。

signal state_changed(new_state: String)

const GarageModel := preload("res://demo09_3d/garage_model.gd")
const LaneCore := preload("res://demo09_3d/lane_core.gd")
const RoadBuilder := preload("res://demo09_3d/road_builder.gd")
const CarViewScript := preload("res://demo09_3d/car_view.gd")
const RigidCar := preload("res://demo09_3d/rigid_car.gd")
const GhostRecorder := preload("res://demo09_3d/ghost_recorder.gd")
const GhostViewScript := preload("res://demo09_3d/ghost_view.gd")
const StyleDef := preload("res://comic_style/comic_style.gd")
const UI_FONT := preload("res://fonts/NotoSansSC.ttf")

@export var auto_start := true   # true: 直接 L1 标准布局发车（截图/演示捷径）；false: 完整菜单流程
@export var use_rigid := false  # B1：true=B1 刚体车（W/S/A/D，D9 物理路线）；false=阶段 A 桥梁（lane_core）

# ── RunController 状态（契约 §6） ──
var state := "menu"              # menu / build / drive / settle / final
var level_idx := 0
var unlocked := 0
var total_time := 0.0
var launch_layout: Array = []
var last_layout_by_level := {}
var last_body_by_level := {}
var last_time_by_level := {}

# ── 运行实体 ──
var model: RefCounted
var core: RefCounted
var car_view: Node3D
var cam: Camera3D
var cam_rig: Node3D
var cam_spring: SpringArm3D
var _cam_init := false
var _thr_t := 0.0   # 注入油门倒计时（与旧 auto_throttle 同语义）

# ── UI 节点 ──
var status_label: Label
var hint_label: Label
var menu_panel: PanelContainer
var level_buttons: Array = []
var garage_panel: PanelContainer
var body_buttons: Array = []
var lateral_buttons: Array = []   # 左/中/右（D1 三档 -1.2/0/+1.2）
var xr_slider: HSlider
var r_slider: HSlider
var wheel_list: ItemList
var gate_label: Label
var launch_btn: Button
var garage_lateral := 0.0
var rigid: RigidBody3D            # B1 刚体车（use_rigid=true 时非空）
var _rigid_time := 0.0            # 刚体模式本局计时
var ghost_rec                     # B4 当前局录制器（GhostRecorder）
var ghost_last: Dictionary = {}   # B4 上一局记录 {key, samples}（键=关卡+seed+版本）
var ghost_view: Node3D            # B4 上一局幽灵回放视图（无碰撞只读）
var _rigid_passed := true         # 刚体本局结果（冲线=true / 翻车=false）
var _rigid_fail_reason := "flip"  # 刚体判负原因：flip=翻车 / fall=坠沟（L10）/ speed=限速（L12）
var _rigid_prev_z := 0.0          # 刚体上一帧 z（限速线跨线检测）
var _rigid_last_vmin := 0.0       # 最近一次限速不达标的线速要求（米/秒，文案用）
var settle_panel: PanelContainer
var settle_title: Label
var settle_info: Label
var settle_btn: Button
var final_panel: PanelContainer
var final_info: Label


func _ready() -> void:
	_register_actions()
	_build_env()
	_build_hud()
	_build_menu()
	_build_garage()
	_build_settle()
	_build_final()
	_go_menu()
	if auto_start:
		start_level(0, [[0.15, 26.0], [0.85, 26.0]])


func _register_actions() -> void:
	for a in [["demo09_thr_pos", KEY_RIGHT], ["demo09_thr_neg", KEY_LEFT],
			["demo09_fwd", KEY_W], ["demo09_fwd", KEY_UP], ["demo09_back", KEY_S], ["demo09_back", KEY_DOWN],
			["demo09_steer_l", KEY_A], ["demo09_steer_r", KEY_D]]:
		if not InputMap.has_action(a[0]):
			InputMap.add_action(a[0])
		var ev := InputEventKey.new()
		ev.physical_keycode = a[1]
		InputMap.action_add_event(a[0], ev)


# ══════════ 状态机 ══════════

func _set_state(s: String) -> void:
	state = s
	state_changed.emit(s)


func _hide_panels() -> void:
	for p in [menu_panel, garage_panel, settle_panel, final_panel]:
		if p != null:
			p.visible = false


func _go_menu() -> void:
	_set_state("menu")
	core = null
	_clear_track()
	_hide_panels()
	if menu_panel != null:
		menu_panel.visible = true
	_refresh_menu()
	_update_hud()


## 关卡按钮 / settle 后继续入口。restore 语义（契约 §6）：只预填目标关自己的上一份布局
func open_level(i: int) -> void:
	if i < 0 or i > unlocked:
		return
	level_idx = i
	model = GarageModel.new()
	model.set_level(i)
	if last_layout_by_level.has(i):
		model.body_kind = int(last_body_by_level.get(i, 1))
		model.restore_layout(last_layout_by_level[i])
	_set_state("build")
	_clear_track()
	_hide_panels()
	garage_panel.visible = true
	_refresh_garage()
	_update_hud()


## 发车（车库出发按钮回调）。布局合法性由 model.add_wheel/can_launch 全路径把关
func garage_launch() -> bool:
	if state != "build" or model == null:
		return false
	if not model.can_launch().ok:
		return false
	launch_layout = []
	for w in model.wheels:
		launch_layout.append({xr = float(w.xr), r = float(w.r), lateral = float(w.lateral), body_kind = model.body_kind})
	return start_level(level_idx, launch_layout)


## 直接发车（auto_start 截图捷径 / garage_launch 底层）：调用方保证布局已校验。
## layout 条目支持 [xr, r] 数组或 {xr, r} 字典两种形态。
func start_level(idx: int, layout: Array) -> bool:
	model = GarageModel.new()
	if not model.set_level(idx):
		return false
	if not layout.is_empty() and layout[0] is Dictionary:
		model.body_kind = clampi(int(layout[0].get("body_kind", 1)), 0, 2)
	for w in layout:
		var xr: float = float(w.xr) if w is Dictionary else float(w[0])
		var rr: float = float(w.r) if w is Dictionary else float(w[1])
		var lat: float = float(w.get("lateral", 0.0)) if w is Dictionary else 0.0
		var res: Dictionary = model.add_wheel(xr, rr, lat)
		if not res.ok:
			return false
	_thr_t = 0.0
	_cam_init = false
	_set_state("drive")
	_clear_track()
	_hide_panels()
	var style: Resource = StyleDef.new()
	core = LaneCore.new()
	core.setup(model, idx, 1)   # 仅作地形相位提供者（rigid 模式不步进）
	var track: Node3D = RoadBuilder.build(Callable(core, "ground_y"), float(model.level().target_m), idx, style,
		model.grid_gaps(model.level()), model.level().get("gates", []), model.level().get("speed_gates", []),
		model.level().get("checkpoints", []), model.level().get("boosts", []))
	track.name = "TrackRoot"
	add_child(track)
	if use_rigid:
		# B1 刚体路径（D9）：车体自带视觉（comic_style）；结算=冲线（翻车检测属 B2）
		rigid = RigidCar.new()
		rigid.setup(model, style)
		rigid.position = Vector3(0, 5.125, 0)
		rigid.name = "RigidCar"
		add_child(rigid)
		cam_spring.add_excluded_object(rigid.get_rid())
		_rigid_time = 0.0
		_rigid_prev_z = 0.0
	else:
		# 阶段 A 桥梁路径：lane_core 解析物理 + car_view 只读映射
		core.launch()
		car_view = CarViewScript.new()
		car_view.setup(model.body(), core.wheels, style)
		car_view.name = "CarView"
		add_child(car_view)
	# B4 幽灵：上一局记录存在则回放；当前局录制器按 关卡+seed+版本 开新缓冲（上一局/当前局隔离）
	var gkey: String = GhostRecorder.record_key(idx, model.geometry_seed(idx), GarageModel.RULE_VERSION)
	if ghost_last.has(gkey) and ghost_last[gkey].samples.size() >= 2:
		ghost_view = GhostViewScript.new()
		ghost_view.name = "GhostView"
		ghost_view.load_samples(ghost_last[gkey].samples)
		add_child(ghost_view)
	ghost_rec = GhostRecorder.new()
	ghost_rec.start(gkey)
	_update_view()
	return true


func _on_settle() -> void:
	_set_state("settle")
	total_time += float(core.flight_time)   # 契约 §6：累计含翻车局
	_finish_bookkeeping(core.last_pass, float(core.flight_time))
	if ghost_rec != null:
		var gkey: String = GhostRecorder.record_key(level_idx, model.geometry_seed(level_idx), GarageModel.RULE_VERSION)
		ghost_last[gkey] = ghost_rec.finish()   # B4：按 关卡+seed+版本 键控存储（契约 §7 隔离）
	_refresh_settle()
	settle_panel.visible = true
	_update_hud()


## 刚体结算：passed=冲线；false=翻车（D10）或坠沟（L10 reason="fall"），判负优先于冲线
func _rigid_settle(passed: bool, reason: String = "flip") -> void:
	_set_state("settle")
	_rigid_passed = passed
	_rigid_fail_reason = reason
	total_time += _rigid_time
	_finish_bookkeeping(passed, _rigid_time)
	if ghost_rec != null:
		var gkey2: String = GhostRecorder.record_key(level_idx, model.geometry_seed(level_idx), GarageModel.RULE_VERSION)
		ghost_last[gkey2] = ghost_rec.finish()   # B4：按 键控存储
	if passed:
		settle_title.text = "过关！"
		settle_info.text = "用时 %.1f 秒 · 最高速度 %.0f 米/秒" % [_rigid_time, rigid.linear_velocity.length()]
		settle_btn.text = "下一关" if level_idx < GarageModel.LEVELS.size() - 1 else "查看全通关结算"
	elif reason == "fall":
		settle_title.text = "坠沟"
		settle_info.text = "速度不足飞越沟壑（坚持了 %.1f 秒）" % _rigid_time
		settle_btn.text = "重试（预填上一版布局）"
	elif reason == "speed":
		settle_title.text = "限速检测未通过"
		settle_info.text = "过线车速 %.0f 米/秒，要求 %.0f（坚持了 %.1f 秒）" % [rigid.linear_velocity.length(), float(_rigid_last_vmin), _rigid_time]
		settle_btn.text = "重试（预填上一版布局）"
	elif reason == "late":
		settle_title.text = "分段计时超时"
		settle_info.text = "用时 %.1f 秒超过检查点时限（坚持了 %.1f 秒）" % [_rigid_time, _rigid_time]
		settle_btn.text = "重试（预填上一版布局）"
	else:
		settle_title.text = "翻车"
		settle_info.text = "坚持了 %.1f 秒（车顶触地累计 1.5 秒判负）" % _rigid_time
		settle_btn.text = "重试（预填上一版布局）"
	settle_panel.visible = true
	_update_hud()


## 结算共有记账：解锁 + 布局/用时存档（契约 §6）
func _finish_bookkeeping(passed: bool, time_s: float) -> void:
	last_layout_by_level[level_idx] = launch_layout.duplicate(true)
	last_body_by_level[level_idx] = model.body_kind
	last_time_by_level[level_idx] = time_s
	if passed:
		unlocked = maxi(unlocked, mini(level_idx + 1, GarageModel.LEVELS.size() - 1))


## 结算按钮：过关→下一关/全通关；翻车→就地重试（restore 预填自己关的上一版）
func settle_continue() -> void:
	if state != "settle":
		return
	var passed: bool = _rigid_passed if (use_rigid and rigid != null) else (core != null and bool(core.last_pass))
	if passed:
		if level_idx < GarageModel.LEVELS.size() - 1:
			open_level(level_idx + 1)
		else:
			_go_final()
	else:
		open_level(level_idx)


func _go_final() -> void:
	_set_state("final")
	_clear_track()
	_hide_panels()
	final_panel.visible = true
	final_info.text = "四关全部通过！\n总用时 %.1f 秒（含翻车局）\n轮胎布局学毕业了。" % total_time
	_update_hud()


## 重置进度：清解锁/总用时/按关实验记录并回菜单。与"回到菜单"（保留进度）是两个语义（契约 §9-5）
func reset_progress() -> void:
	unlocked = 0
	total_time = 0.0
	launch_layout = []
	last_layout_by_level.clear()
	last_body_by_level.clear()
	last_time_by_level.clear()
	level_idx = 0
	_go_menu()


func throttle_on(t: float) -> void:
	_thr_t = maxf(_thr_t, maxf(0.0, t))


# ══════════ 车库操作（UI 回调 + 测试入口，全部走 GarageModel） ══════════

func garage_set_body(kind: int) -> void:
	if model != null and state == "build":
		model.body_kind = clampi(kind, 0, 2)
		_refresh_garage()
		_update_hud()


## 侧位选择（D1 三档）：-1.2 左 / 0 中 / +1.2 右
func garage_set_lateral(lateral: float) -> void:
	garage_lateral = clampf(lateral, -GarageModel.LATERAL_MAX, GarageModel.LATERAL_MAX)
	_refresh_garage()


func garage_add_wheel_at(xr: float, r: float, lateral: float = 0.0) -> bool:
	if state != "build" or model == null:
		return false
	var res: Dictionary = model.add_wheel(xr, r, lateral)
	_refresh_garage()
	_update_hud()
	return bool(res.ok)


func garage_add_wheel_from_sliders() -> bool:
	if xr_slider == null:
		return false
	return garage_add_wheel_at(float(xr_slider.value), float(r_slider.value), garage_lateral)


func garage_remove(idx: int) -> bool:
	if state != "build" or model == null:
		return false
	var ok: bool = bool(model.remove_wheel(idx).ok)
	_refresh_garage()
	_update_hud()
	return ok


func garage_adjust_radius(idx: int, d: float) -> bool:
	if state != "build" or model == null:
		return false
	var cur: float = float(model.wheels[idx].r)
	var ok: bool = bool(model.set_radius(idx, cur + d).ok)   # 超关卡上限自动夹回（旧滚轮语义）；超预算拒绝
	_refresh_garage()
	_update_hud()
	return ok


func _clear_track() -> void:
	for child in get_children():
		if child.name == "TrackRoot" or child.name == "CarView" or child.name == "RigidCar" or child.name == "GhostView":
			child.queue_free()
	car_view = null
	rigid = null
	ghost_view = null


# ══════════ 主循环 ══════════

func _physics_process(dt: float) -> void:
	if state != "drive":
		return
	if use_rigid and rigid != null:
		_physics_process_rigid(dt)
		_update_view()
		return
	if core == null or core.state != "drive":
		return
	var thr := 0.0
	if _thr_t > 0.0:
		_thr_t = maxf(0.0, _thr_t - dt)
		thr = 1.0
	else:
		if Input.is_action_pressed("demo09_fwd") or Input.is_action_pressed("demo09_thr_pos"):
			thr = 1.0
		elif Input.is_action_pressed("demo09_back") or Input.is_action_pressed("demo09_thr_neg"):
			thr = -1.0
	core.step(dt, thr)
	_update_view()
	if core.state == "settle":
		_on_settle()


## B1 刚体路径：action 层（W/S/A/D 与兼容层并集）→ 车体输入；结算 = 冲线（翻车检测属 B2）
func _physics_process_rigid(dt: float) -> void:
	if _thr_t > 0.0:
		_thr_t = maxf(0.0, _thr_t - dt)
		rigid.drive_input = 1.0
	else:
		var fwd_key: bool = Input.is_action_pressed("demo09_fwd") or Input.is_action_pressed("demo09_thr_pos")
		var back_key: bool = Input.is_action_pressed("demo09_back") or Input.is_action_pressed("demo09_thr_neg")
		rigid.drive_input = (1.0 if fwd_key else 0.0) - (1.0 if back_key else 0.0)
		rigid.drive_input = clampf(rigid.drive_input, -1.0, 1.0)
	rigid.steer_input = (1.0 if Input.is_action_pressed("demo09_steer_l") else 0.0) \
			- (1.0 if Input.is_action_pressed("demo09_steer_r") else 0.0)
	_rigid_time += dt
	# 加速带（L14）：前向跨带瞬间沿当前方向提速（刚体米制，封顶 90 m/s）
	for b in model.level().get("boosts", []):
		var bgz: float = -float(b.gx)
		if _rigid_prev_z > bgz and rigid.position.z <= bgz:
			var bvel: Vector3 = rigid.linear_velocity
			if bvel.length() > 1.0:
				rigid.linear_velocity = bvel.normalized() * minf(bvel.length() + float(b.dv), 90.0)
	# 分段检查点（L13）：前向跨线时比赛用时超过累计时限 → 超时判负（先于冲线检查）
	var rigid_pos_m: float = -rigid.position.z
	for cp in model.level().get("checkpoints", []):
		var cpg: float = float(cp.gx)
		if -_rigid_prev_z < cpg and rigid_pos_m >= cpg:
			if _rigid_time > float(cp.tmax):
				_rigid_settle(false, "late")
				return
	_rigid_prev_z = rigid.position.z
	# 限速检测线（L12）：前向跨线且车速不足 → 检测不通过（先于冲线检查）
	for sg in model.level().get("speed_gates", []):
		var sgz: float = -float(sg.gx)
		if _rigid_prev_z > sgz and rigid.position.z <= sgz and rigid.linear_velocity.length() < float(sg.vmin):
			_rigid_last_vmin = float(sg.vmin)
			_rigid_settle(false, "speed")
			return
	_rigid_prev_z = rigid.position.z
	if rigid.rolled_over:
		_rigid_settle(false)   # 翻车优先于冲线（D10）
	elif rigid.position.y < _road_height_m(rigid.position.z) - 20.0:
		_rigid_settle(false, "fall")   # 坠沟（L10）：跌出路面 20m 以上
	elif rigid.position.z <= -float(model.level().target_m):
		_rigid_settle(true)


## 刚体所在 z 处的路面高度（米，y 向上；z 轴负向前进与道路 s_m 对齐）
func _road_height_m(z: float) -> float:
	var px_x: float = LaneCore.START_X + (-z) * LaneCore.PX_PER_M
	return (RoadBuilder.BASE_GROUND_Y - float(core.ground_y(px_x))) / LaneCore.PX_PER_M


func _update_view() -> void:
	if car_view != null:
		car_view.apply_state(core)
	if state == "drive" and ghost_rec != null:
		var focus: Node3D = car_view if car_view != null else rigid
		if focus != null:
			ghost_rec.sample(get_physics_process_delta_time(), focus.global_position, focus.global_transform.basis)
	_update_camera()
	_update_hud()


## 追尾 CameraRig（A4）：Rig(位置阻尼平滑、地平线不随车姿) → SpringArm3D(避障) → Camera3D
func _update_camera() -> void:
	var focus: Node3D = car_view if car_view != null else rigid
	if cam_rig == null or focus == null:
		return
	var target: Vector3 = focus.position + Vector3(0.0, 3.0, 0.0)
	if not _cam_init:
		cam_rig.position = target
		_cam_init = true
	else:
		var k := 1.0 - exp(-7.0 * get_physics_process_delta_time())
		cam_rig.position = cam_rig.position.lerp(target, k)
	# 阶段 A 航向恒为 -Z（无侧向运动）；阶段 B 在此接入真实航向平滑


# ══════════ UI 构建（代码装配，避免手写 tscn） ══════════

func _mk_label(parent: Node, txt: String, size: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("242934"))
	parent.add_child(l)
	return l


func _mk_button(parent: Node, txt: String, size: int) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_override("font", UI_FONT)
	b.add_theme_font_size_override("font_size", size)
	parent.add_child(b)
	return b


func _mk_panel(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = title
	p.visible = false
	var vb := VBoxContainer.new()
	vb.name = "VB"
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	add_child(p)
	return p


func _build_menu() -> void:
	menu_panel = _mk_panel("MenuPanel")
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	var vb: VBoxContainer = menu_panel.get_node("VB")
	_mk_label(vb, "DEMO9 · 追尾赛车 3D", 30)
	_mk_label(vb, "自己设计一辆车：选车身、摆轮胎，通过测试场。", 18).modulate = Color(1, 1, 1, 0.85)
	level_buttons.clear()
	for i in range(GarageModel.LEVELS.size()):
		var b := _mk_button(vb, "", 20)
		b.pressed.connect(open_level.bind(i))
		level_buttons.append(b)
	var reset_btn := _mk_button(vb, "重置进度（清解锁与实验记录）", 14)
	reset_btn.pressed.connect(reset_progress)
	_mk_label(vb, "方向键右 = 油门，左 = 刹车/倒车（阶段 A 键位）", 14).modulate = Color(1, 1, 1, 0.7)


func _refresh_menu() -> void:
	for i in range(level_buttons.size()):
		var b: Button = level_buttons[i]
		var locked: bool = i > unlocked
		b.disabled = locked
		b.text = ("第%d关 · %s" % [i + 1, String(GarageModel.LEVELS[i].short)]) if not locked else ("第%d关（未解锁）" % [i + 1])


func _build_garage() -> void:
	garage_panel = _mk_panel("GaragePanel")
	garage_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	garage_panel.position = Vector2(560, 16)
	garage_panel.custom_minimum_size = Vector2(380, 0)
	var vb: VBoxContainer = garage_panel.get_node("VB")
	_mk_label(vb, "车库（最多 4 只轮胎，一只条目 = 一只轮胎）", 18)
	var body_row := HBoxContainer.new()
	vb.add_child(body_row)
	for i in range(3):
		var b := _mk_button(body_row, String(GarageModel.BODIES[i].name), 15)
		b.pressed.connect(garage_set_body.bind(i))
		body_buttons.append(b)
	var lat_row := HBoxContainer.new()
	vb.add_child(lat_row)
	_mk_label(lat_row, "侧位", 14)
	for lat in [[-1.2, "左轮"], [0.0, "居中"], [1.2, "右轮"]]:
		var lb := _mk_button(lat_row, String(lat[1]), 15)
		lb.set_meta("lat", float(lat[0]))
		lb.pressed.connect(garage_set_lateral.bind(float(lat[0])))
		lateral_buttons.append(lb)
	_mk_label(vb, "位置 xr（0=车头，1=车尾）", 14)
	xr_slider = HSlider.new()
	xr_slider.min_value = 0.03
	xr_slider.max_value = 0.97
	xr_slider.step = 0.01
	xr_slider.value = 0.5
	vb.add_child(xr_slider)
	_mk_label(vb, "半径 r（12–30）", 14)
	r_slider = HSlider.new()
	r_slider.min_value = 12.0
	r_slider.max_value = 30.0
	r_slider.step = 1.0
	r_slider.value = 18.0
	vb.add_child(r_slider)
	var add_btn := _mk_button(vb, "放轮胎", 17)
	add_btn.pressed.connect(garage_add_wheel_from_sliders)
	wheel_list = ItemList.new()
	wheel_list.custom_minimum_size = Vector2(0, 90)
	wheel_list.add_theme_font_override("font", UI_FONT)
	wheel_list.add_theme_font_size_override("font_size", 14)
	vb.add_child(wheel_list)
	var ops := HBoxContainer.new()
	vb.add_child(ops)
	var del_btn := _mk_button(ops, "删除选中", 15)
	del_btn.pressed.connect(func() -> void: garage_remove(wheel_list.get_selected_items()[0] if wheel_list.get_selected_items().size() > 0 else -1))
	var plus_btn := _mk_button(ops, "半径+2", 15)
	plus_btn.pressed.connect(func() -> void:
		var sel := wheel_list.get_selected_items()
		if sel.size() > 0:
			garage_adjust_radius(sel[0], 2.0))
	var minus_btn := _mk_button(ops, "半径-2", 15)
	minus_btn.pressed.connect(func() -> void:
		var sel := wheel_list.get_selected_items()
		if sel.size() > 0:
			garage_adjust_radius(sel[0], -2.0))
	gate_label = _mk_label(vb, "", 15)
	launch_btn = _mk_button(vb, "出发", 20)
	launch_btn.pressed.connect(garage_launch)


func _refresh_garage() -> void:
	if model == null:
		return
	wheel_list.clear()
	var drivers: Array = model.driver_indices()
	for i in range(model.wheels.size()):
		var w: Dictionary = model.wheels[i]
		var lat_m: float = float(w.get("lateral", 0.0))
		var lat_tag: String = "右" if lat_m > 0.01 else ("左" if lat_m < -0.01 else "中")
		var tag: String = " [驱动轮]" if i in drivers else ""
		wheel_list.add_item("轮胎%d  xr=%.2f  r=%d  %s侧%s" % [i + 1, float(w.xr), int(round(float(w.r))), lat_tag, tag])
	for i in range(body_buttons.size()):
		body_buttons[i].disabled = i == model.body_kind
	for i in range(lateral_buttons.size()):
		lateral_buttons[i].disabled = is_equal_approx(float(lateral_buttons[i].get_meta("lat", 0.0)), garage_lateral)
	var ok: bool = bool(model.can_launch().ok)
	launch_btn.disabled = not ok
	gate_label.text = String(model.can_launch().reason) if not ok else "约束满足，可以出发"


func _build_settle() -> void:
	settle_panel = _mk_panel("SettlePanel")
	settle_panel.set_anchors_preset(Control.PRESET_CENTER)
	var vb: VBoxContainer = settle_panel.get_node("VB")
	settle_title = _mk_label(vb, "", 28)
	settle_info = _mk_label(vb, "", 18)
	settle_btn = _mk_button(vb, "继续", 20)
	settle_btn.pressed.connect(settle_continue)


func _refresh_settle() -> void:
	if core.last_pass:
		settle_title.text = "过关！"
		settle_info.text = "用时 %.1f 秒 · 最高速度 %.0f 米/秒" % [float(core.flight_time), float(core.max_speed)]
		settle_btn.text = "下一关" if level_idx < GarageModel.LEVELS.size() - 1 else "查看全通关结算"
	elif core.settle_reason == "fall":
		settle_title.text = "坠沟"
		settle_info.text = "速度不足飞越沟壑 · 跑了 %.0f 米" % [(float(core.car_pos.x) - LaneCore.START_X) / LaneCore.PX_PER_M]
		settle_btn.text = "重试（预填上一版布局）"
	elif core.settle_reason == "gate":
		settle_title.text = "撞限高杆"
		settle_info.text = "整车高度超过净空 %.1f 米 · 跑了 %.0f 米" % [float(core.last_gate_clear), (float(core.car_pos.x) - LaneCore.START_X) / LaneCore.PX_PER_M]
		settle_btn.text = "重试（预填上一版布局）"
	elif core.settle_reason == "speed":
		settle_title.text = "限速检测未通过"
		settle_info.text = "过线车速 %.0f 米/秒，要求 %.0f · 跑了 %.0f 米" % [float(core.last_speed_val) / LaneCore.PX_PER_M, float(core.last_speed_vmin) / LaneCore.PX_PER_M, (float(core.car_pos.x) - LaneCore.START_X) / LaneCore.PX_PER_M]
		settle_btn.text = "重试（预填上一版布局）"
	elif core.settle_reason == "late":
		settle_title.text = "分段计时超时"
		settle_info.text = "用时 %.1f 秒超过检查点时限 %.1f 秒 · 跑了 %.0f 米" % [float(core.last_late.t), float(core.last_late.tmax), (float(core.car_pos.x) - LaneCore.START_X) / LaneCore.PX_PER_M]
		settle_btn.text = "重试（预填上一版布局）"
	else:
		settle_title.text = "翻车"
		settle_info.text = "坚持了 %.1f 秒 · 跑了 %.0f 米（车顶触地累计 1.5 秒判负）" % [float(core.flight_time), (float(core.car_pos.x) - LaneCore.START_X) / LaneCore.PX_PER_M]
		settle_btn.text = "重试（预填上一版布局）"


func _build_final() -> void:
	final_panel = _mk_panel("FinalPanel")
	final_panel.set_anchors_preset(Control.PRESET_CENTER)
	var vb: VBoxContainer = final_panel.get_node("VB")
	_mk_label(vb, "全通关！", 30)
	final_info = _mk_label(vb, "", 20)
	var back := _mk_button(vb, "回到菜单", 18)
	back.pressed.connect(_go_menu)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.position = Vector2(16, 12)
	status_label.add_theme_font_override("font", UI_FONT)
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color("242934"))
	layer.add_child(status_label)
	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.position = Vector2(16, 46)
	hint_label.add_theme_font_override("font", UI_FONT)
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_color_override("font_color", Color("4a5568"))
	layer.add_child(hint_label)


func _build_env() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("7ec0ee")
	sky_mat.sky_horizon_color = Color("cfe8f7")
	sky_mat.ground_bottom_color = Color("5d8f42")
	sky_mat.ground_horizon_color = Color("cfe8f7")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.name = "Env"
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	cam_rig = Node3D.new()
	cam_rig.name = "CameraRig"
	add_child(cam_rig)
	cam_spring = SpringArm3D.new()
	cam_spring.name = "Spring"
	cam_spring.spring_length = 8.0
	cam_spring.margin = 0.4
	cam_spring.collision_mask = 1   # 只与道路/装饰(层1)避让；阶段 A 车辆无刚体，天然排除本车
	cam_spring.rotation.x = deg_to_rad(-14.0)   # 固定俯角：前路始终在画面内
	cam_rig.add_child(cam_spring)
	cam = Camera3D.new()
	cam.name = "Cam"
	cam.fov = 70.0
	cam.position = Vector3(0.0, 0.0, cam_spring.spring_length)   # 臂 +Z = 车尾方向，相机朝车看
	cam_spring.add_child(cam)
	cam.current = true


## 检查点 HUD 提示（L13）：下一检查点剩余时限；全部通过或无检查点返回空串
func _checkpoint_hint(drive_clock: float, next_cp: Dictionary) -> String:
	if next_cp.is_empty():
		return ""
	return " · 检查点剩 %.1f 秒（时限 %.1f）" % [float(next_cp.tmax) - drive_clock, float(next_cp.tmax)]


## 刚体路径的下一未通过检查点（米；bridge 用 core.next_checkpoint()）
func _next_checkpoint_dict(pos_m: float) -> Dictionary:
	for cp in model.level().get("checkpoints", []):
		if pos_m < float(cp.gx):
			return cp
	return {}


func _update_hud() -> void:
	if status_label == null:
		return
	match state:
		"menu":
			status_label.text = "DEMO9 3D · 已解锁 %d/%d 关" % [unlocked + 1, GarageModel.LEVELS.size()]
			hint_label.text = "选一关进入车库：摆轮胎定重心，开到终点旗"
		"build":
			var L: Dictionary = model.level()
			status_label.text = "%s · 车库：轮胎 %d/4（后半段 %d）· 最大半径 %d" % [
				String(L.name), model.wheels.size(), model.rear_count(), int(round(float(L.max_r)))]
			hint_label.text = String(model.can_launch().reason) if not model.can_launch().ok else "约束满足，点出发"
		"drive":
			var L: Dictionary = model.level()
			if use_rigid and rigid != null:
				status_label.text = "%s · 速度 %.0f 米/秒 · 里程 %.0f / %.0f 米 · 计时 %.1f 秒" % [
					String(L.name), rigid.linear_velocity.length(),
					-rigid.position.z, float(L.target_m), _rigid_time]
				hint_label.text = "W/S = 油门/刹车倒车，A/D = 转向（B1 刚体 · 规则 %s · 追尾视角）" % GarageModel.RULE_VERSION
				hint_label.text += _checkpoint_hint(_rigid_time, _next_checkpoint_dict(-rigid.position.z))
			else:
				status_label.text = "%s · 速度 %.0f 米/秒 · 里程 %.0f / %.0f 米 · 姿态 %d° · 计时 %.1f 秒" % [
					String(L.name), float(core.vel.length()) / LaneCore.PX_PER_M,
					(float(core.car_pos.x) - LaneCore.START_X) / LaneCore.PX_PER_M,
					float(L.target_m), int(round(rad_to_deg(float(core.car_angle)))), float(core.flight_time)]
				hint_label.text = "方向键右 = 油门，左 = 刹车/倒车（阶段 A 桥梁 · 规则 r3d-1 · 追尾视角）"
				hint_label.text += _checkpoint_hint(float(core.flight_time), core.next_checkpoint())
		"settle":
			if use_rigid and rigid != null:
				status_label.text = "%s · %s · 用时 %.1f 秒" % [String(model.level().name), "过关" if _rigid_passed else "翻车", _rigid_time]
			else:
				status_label.text = "%s · %s · 用时 %.1f 秒" % [String(model.level().name), "过关" if core.last_pass else "翻车", float(core.flight_time)]
			hint_label.text = ""
		"final":
			status_label.text = "全通关 · 总用时 %.1f 秒" % total_time
			hint_label.text = ""
