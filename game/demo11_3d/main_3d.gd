extends Node3D
## DEMO11 3D 灰模主场景（阶段 A）：斜俯视格子箱庭。
## 规则核心 sandbox_rules.gd 是整数状态权威；本场景只做三件事：
## 1) 真实输入（方向键/F/G/H，忽略 echo，工具沿 facing）→ 核心命令，同步结算；
## 2) 核心事件 → 视图（80ms 插值 / 下沉 / 烧毁 / 地形刷新），按稳定 object_id 绑定节点；
## 3) HUD（房间/面向/工具/门/步数 + 两个语义不同的重开按钮）。
## 连续输入按旧版语义处理：核心即时结算，新插值从当前视觉位置出发，不丢命令、不偷批非法占格。

const Rules := preload("res://demo11_3d/sandbox_rules.gd")
const BoardViewScript := preload("res://demo11_3d/board_view.gd")
const ModelLibrary := preload("res://comic_style/model_library.gd")
const ComicStyle := preload("res://comic_style/comic_style.gd")
const FONT := preload("res://fonts/NotoSansSC.ttf")

const SLIDE_TIME := 0.08    # 表现参照（与核心 SLIDE_TIME 一致）
const DROP_TIME := 0.25     # 沉水/融化下沉表现
const BURN_TIME := 0.2      # 烧毁表现
const CAM_HOME_POS := Vector3(6.0, 7.2, 9.6)
const CAM_HOME_LOOK := Vector3(6.0, 0.0, 3.5)
const CAM_HOME_SIZE := 9.0

var rules
var board: Node3D
var cam: Camera3D
var comic_style: Resource          # 3d-shared 统一材质（玩家/火把等无模型物件共用）
var _obj_views := {}       # object_id -> Node3D
var _player_view: Node3D
var _phase_open_last: bool = true  # EXT-13 相位门轮询缓存（room rebuild 后由 _sync_phase 复位）
var _tide_open_last: bool = true   # EXT-31 潮汐格轮询缓存（露出/淹没沿驱动桥板调色）
var _tide_late_open_last: bool = false  # EXT-33 反相潮汐格轮询缓存（开窗 [2,6) 初值默认闭）
var _tgate_open_last: bool = false  # EXT-43 潮闸轮询缓存（开窗 [4,8) 初值默认闭）
var _facing_arrow: MeshInstance3D
var _anims: Array = []     # {node, from, to, t, dur, mode: slide/drop/burn, free_after}

# 演示回放驱动：仅当 user args 含 --demo-script=<文件> 时激活（截图证据基础设施）。
# 脚本每行 "帧号,动作"（up/down/left/right/f/g/h/home，# 开头为注释）；到帧经真实输入管线注入按键。
var _demo_actions := {}
var _demo_frame := 0

# HUD
var hud: CanvasLayer
var status_label: Label
var tools_label: Label
var hint_label: Label
var final_label: Label
var _btn_cont: Button
var _btn_new: Button
var _final_panel: Panel


func _ready() -> void:
	_setup_offscreen()
	rules = Rules.new()
	comic_style = ComicStyle.new()
	board = BoardViewScript.new()
	board.name = "BoardView"
	add_child(board)
	_setup_camera()
	_setup_light()
	_setup_hud()
	_setup_demo_driver()
	_rebuild_room()


## 用户指令（2026-10-04）：不在用户桌面弹出可见游戏窗口做 QA。
## 仅当 user args 含 --offscreen（CLI 截图管线）时：窗口移到屏幕外 (-8000,-8000) 并禁焦点，渲染照常供
## --write-movie 取证；配合命令行 --position -8000,-8000 使窗口从创建起就不可见。
## 注意：不能 window_set_mode(MODE_MINIMIZED)——最小化会挂起渲染交换链，帧全黑（实测）；屏幕外坐标已不可见。
## 普通游玩不带参数不受影响。
func _setup_offscreen() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--offscreen":
			var wid := DisplayServer.MAIN_WINDOW_ID
			DisplayServer.window_set_position(Vector2i(-8000, -8000), wid)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, wid)
			return


# ---------------- 场景搭建 ----------------

func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAM_HOME_SIZE
	cam.position = CAM_HOME_POS
	add_child(cam)
	cam.look_at(CAM_HOME_LOOK)  # 入树后再 look_at，保证俯角生效
	cam.current = true


func _setup_light() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1c2029")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.86)
	env.ambient_light_energy = 0.8
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)


func _label(parent: Node, pos: Vector2, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _setup_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	status_label = _label(hud, Vector2(16, 8), 19, Color("ffd54f"))
	tools_label = _label(hud, Vector2(16, 38), 15, Color("cfd8dc"))
	hint_label = _label(hud, Vector2(16, 508), 13, Color("90a4ae"))
	# 结算面板底板（阶段 C 视觉债：文字与按钮分离，白底承载）
	_final_panel = Panel.new()
	_final_panel.name = "FinalPanel"
	_final_panel.position = Vector2(130, 176)
	_final_panel.size = Vector2(460, 244)
	var fp_style := StyleBoxFlat.new()
	fp_style.bg_color = Color(1, 1, 1, 0.93)
	fp_style.set_corner_radius_all(12)
	_final_panel.add_theme_stylebox_override("panel", fp_style)
	_final_panel.visible = false
	hud.add_child(_final_panel)
	final_label = _label(hud, Vector2(150, 192), 14, Color("1b5e20"))
	final_label.visible = false
	# 两个重开按钮语义不同（新便利功能，非旧 load_room 等价物）；只在结算面板出现，不挡棋盘
	_btn_cont = Button.new()
	_btn_cont.text = "再来一次（续样本：保留遥测/family，旧版语义）"
	_btn_cont.position = Vector2(150, 320)
	_btn_cont.size = Vector2(420, 36)
	_btn_cont.visible = false
	_btn_cont.pressed.connect(func() -> void:
		rules.restart()
		_rebuild_room())
	hud.add_child(_btn_cont)
	_btn_new = Button.new()
	_btn_new.text = "新样本重开（全清遥测/步数/family）"
	_btn_new.position = Vector2(150, 366)
	_btn_new.size = Vector2(420, 36)
	_btn_new.visible = false
	_btn_new.pressed.connect(func() -> void:
		rules.reset_sample()
		_rebuild_room())
	hud.add_child(_btn_new)


# ---------------- 房间视图重建 ----------------

func _rebuild_room() -> void:
	for k in _obj_views:
		_obj_views[k].queue_free()
	_obj_views.clear()
	_anims.clear()
	board.build(rules)
	_phase_open_last = rules.phase_gate_open()
	board.set_phase_state(_phase_open_last, not _phase_open_last)
	_tide_open_last = rules.tide_open()
	_tide_late_open_last = rules.tide_late_open()
	board.set_tide_state(_tide_open_last, _tide_late_open_last)
	_tgate_open_last = rules.tide_gate_open()
	board.set_tide_gate_state(_tgate_open_last)
	final_label.visible = false
	_final_panel.visible = false
	_spawn_objects()
	if _player_view == null:
		_make_player_view()
	_place_player()
	_update_facing_arrow(rules.facing)
	_sync_hud()


func _spawn_objects() -> void:
	for o in rules.objects:
		var od: Dictionary = o
		var t := String(od.type)
		if t == "switch":
			continue  # 压力板是贴地状态，由 board 画
		var v: Node3D
		match t:
			"box":
				v = ModelLibrary.create_model("crate")
			"iron":
				v = ModelLibrary.create_model("iron_block")
			"torch", "torch_m":
				v = _make_torch_view()
			"cart":
				v = _make_cart_view()
			"crystal":
				v = _make_crystal_view()
			_:
				v = Node3D.new()
		v.position = board.cell_to_world(int(od.x), int(od.y))
		add_child(v)
		_obj_views[int(od.id)] = v


func _style_mat(color: Color) -> ShaderMaterial:
	return comic_style.body_material(color)


func _make_torch_view() -> Node3D:
	# 火把：套件无对应模型，用统一 comic 材质的简单几何（pole=wood_dark，焰=amber）
	var n := Node3D.new()
	var pole := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.05
	c.bottom_radius = 0.05
	c.height = 0.7
	pole.mesh = c
	pole.material_override = _style_mat(ModelLibrary.COLORS.wood_dark)
	pole.position = Vector3(0, 0.35, 0)
	n.add_child(pole)
	var flame := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.13
	s.height = 0.26
	flame.mesh = s
	flame.material_override = _style_mat(Color("e8b45c"))
	flame.position = Vector3(0, 0.78, 0)
	n.add_child(flame)
	return n


func _make_cart_view() -> Node3D:
	# 暖轨车（EXT-35）：套件无对应模型——暗色车体 + 琥珀火焰（与火把同热源语言）
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.62, 0.3, 0.62)
	body.mesh = b
	body.material_override = _style_mat(Color("5a4a44"))
	body.position = Vector3(0, 0.15, 0)
	n.add_child(body)
	var flame := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	flame.mesh = s
	flame.material_override = _style_mat(Color("e8b45c"))
	flame.position = Vector3(0, 0.42, 0)
	n.add_child(flame)
	return n


func _make_crystal_view() -> Node3D:
	# 冰晶（EXT-38）：套件无对应模型——冰蓝斜置棱柱 + 亮芯（一推即碎的自置水源）
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = Vector3(0.4, 0.55, 0.4)
	mi.mesh = p
	mi.material_override = _style_mat(Color("a8d8ef"))
	mi.position = Vector3(0, 0.28, 0)
	mi.rotation_degrees = Vector3(0, 45, 0)
	n.add_child(mi)
	var glint := MeshInstance3D.new()
	var g := BoxMesh.new()
	g.size = Vector3(0.06, 0.3, 0.06)
	glint.mesh = g
	glint.material_override = _style_mat(Color("eef9ff"))
	glint.position = Vector3(0, 0.34, 0)
	glint.rotation_degrees = Vector3(0, 45, 0)
	n.add_child(glint)
	return n


func _make_player_view() -> void:
	_player_view = Node3D.new()
	_player_view.name = "PlayerView"
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.28
	s.height = 0.56
	mi.mesh = s
	mi.material_override = _style_mat(Color("7ee081"))
	mi.position = Vector3(0, 0.28, 0)
	_player_view.add_child(mi)
	_facing_arrow = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.12, 0.08, 0.2)
	_facing_arrow.mesh = b
	_facing_arrow.material_override = _style_mat(Color("242934"))
	_player_view.add_child(_facing_arrow)
	add_child(_player_view)


func _place_player() -> void:
	_player_view.position = board.cell_to_world(int(rules.player.x), int(rules.player.y))


func _update_facing_arrow(dir: String) -> void:
	var d: Vector2i = Rules.DIR_VECS.get(dir, Vector2i(1, 0))
	_facing_arrow.position = Vector3(float(d.x) * 0.32, 0.12, float(d.y) * 0.32)


# ---------------- 输入（真实按键路径；忽略 echo；工具沿 facing） ----------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_UP:
				_do_move("up")
			KEY_DOWN:
				_do_move("down")
			KEY_LEFT:
				_do_move("left")
			KEY_RIGHT:
				_do_move("right")
			KEY_F:
				_do_tool("ice")
			KEY_G:
				_do_tool("fire")
			KEY_H:
				_do_tool("magnet")
			KEY_BACKSPACE:
				rules.restart()
				_rebuild_room()
			KEY_HOME:
				_reset_camera()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(-0.5)


func _do_move(dir: String) -> void:
	rules.try_move(dir)
	_apply_events(rules.drain_events())


func _do_tool(tool_name: String) -> void:
	rules.try_tool(tool_name, rules.facing)
	_apply_events(rules.drain_events())


# ---------------- 表现：事件 → 视图 ----------------

func _apply_events(evs: Array) -> void:
	var need_rebuild := false
	for e in evs:
		match String(e.type):
			"move":
				_start_slide(_player_view, board.cell_to_world(int(e.to.x), int(e.to.y)), SLIDE_TIME, "slide", false)
				_update_facing_arrow(String(e.dir))
			"teleport":
				# EXT-9：传送无连续位移语义——玩家节点直接落位到对格
				_player_view.position = board.cell_to_world(int(e.to.x), int(e.to.y))
				_update_facing_arrow(rules.facing)
			"push", "magnet":
				var v = _obj_views.get(int(e.id))
				if v != null:
					_start_slide(v, board.cell_to_world(int(e.to.x), int(e.to.y)), SLIDE_TIME, "slide", false)
			"sink":
				var v2 = _obj_views.get(int(e.id))
				if v2 != null:
					_start_drop(v2, Vector3(float(e.at.x) + 0.5, -0.9, float(e.at.y) + 0.5), DROP_TIME)
					_obj_views.erase(int(e.id))
				board.refresh_tile(int(e.at.x), int(e.at.y), rules)
			"freeze":
				board.refresh_tile(int(e.at.x), int(e.at.y), rules)
			"crack":
				# EXT-3：玩家踏上薄冰 → 碎裂回水（核心已结算，此处仅刷新地形）
				board.refresh_tile(int(e.at.x), int(e.at.y), rules)
			"melt":
				if String(e.occupant) == "box" or String(e.occupant) == "iron":
					var v3 = _obj_views.get(int(e.id))
					if v3 != null:
						_start_drop(v3, Vector3(float(e.at.x) + 0.5, -0.9, float(e.at.y) + 0.5), DROP_TIME)
						_obj_views.erase(int(e.id))
					board.refresh_tile(int(e.at.x), int(e.at.y), rules)
				elif String(e.occupant) == "player":
					# 兼容旧版：玩家退回无插值（slide_t=1.0），权威状态先行
					if e.has("player_to"):
						_player_view.position = board.cell_to_world(int(e.player_to.x), int(e.player_to.y))
					board.refresh_tile(int(e.at.x), int(e.at.y), rules)
				else:
					board.refresh_tile(int(e.at.x), int(e.at.y), rules)
			"burn":
				var v4 = _obj_views.get(int(e.id))
				if v4 != null:
					_start_anim(v4, v4.position, v4.position + Vector3(0, 0.2, 0), BURN_TIME, "burn", true)
					_obj_views.erase(int(e.id))
			"cart_move":
				# EXT-35 暖轨车：自主巡轨滑移（80ms 插值，与推物同款表现）
				var vc = _obj_views.get(int(e.id))
				if vc != null:
					_start_slide(vc, board.cell_to_world(int(e.to.x), int(e.to.y)), SLIDE_TIME, "slide", false)
			"warp":
				# EXT-49 送货门：物传瞬移重定位（无插值——门是即达的）
				var vw = _obj_views.get(int(e.id))
				if vw != null:
					vw.position = board.cell_to_world(int(e.to.x), int(e.to.y))
			"gate_open":
				pass  # refresh_state 统一处理
			"room_clear":
				need_rebuild = true
			"room_reset":
				need_rebuild = true
			"burn_wall":
				board.refresh_tile(int(e.at.x), int(e.at.y), rules)
			"pickup":
				# EXT-36 钥匙拾取：核心已把 tile 变 floor，此处刷地（金环消失）
				board.refresh_tile(int(e.at.x), int(e.at.y), rules)
			"shatter":
				# EXT-38 冰晶碎裂：视图下坠消散 + 落点刷水
				var vsh = _obj_views.get(int(e.id))
				if vsh != null:
					_start_drop(vsh, Vector3(float(e.at.x) + 0.5, -0.4, float(e.at.y) + 0.5), DROP_TIME)
					_obj_views.erase(int(e.id))
				board.refresh_tile(int(e.at.x), int(e.at.y), rules)
			"tide_break":
				# 落潮淹没：占位物（箱/铁/晶/车）视图下坠消散 + 潮格刷水
				var vtb = _obj_views.get(int(e.id))
				if vtb != null:
					_start_drop(vtb, Vector3(float(e.at.x) + 0.5, -0.4, float(e.at.y) + 0.5), DROP_TIME)
					_obj_views.erase(int(e.id))
				board.refresh_tile(int(e.at.x), int(e.at.y), rules)
			"belt_move":
				# EXT-40 输送带：带上物/人 80ms 滑移（人走 _player_view）
				if String(e.otype) == "player":
					_start_slide(_player_view, board.cell_to_world(int(e.to.x), int(e.to.y)), SLIDE_TIME, "slide", false)
				else:
					var vbm = _obj_views.get(int(e.id))
					if vbm != null:
						_start_slide(vbm, board.cell_to_world(int(e.to.x), int(e.to.y)), SLIDE_TIME, "slide", false)
			"final":
				pass  # HUD 统一处理
	if need_rebuild:
		_rebuild_room()
		return
	board.refresh_state(rules)
	_sync_hud()


func _start_slide(node: Node3D, to: Vector3, dur: float, mode: String, free_after: bool) -> void:
	_start_anim(node, node.position, to, dur, mode, free_after)


func _start_drop(node: Node3D, to: Vector3, dur: float) -> void:
	_start_anim(node, node.position, to, dur, "drop", true)


func _start_anim(node: Node3D, from: Vector3, to: Vector3, dur: float, mode: String, free_after: bool) -> void:
	# 同一节点的新动画覆盖旧动画：从当前视觉位置出发（连续输入不丢命令）
	var i := _anims.size() - 1
	while i >= 0:
		if _anims[i].node == node:
			_anims.remove_at(i)
		i -= 1
	_anims.append({node = node, from = from, to = to, t = 0.0, dur = dur, mode = mode, free_after = free_after})


func _process(delta: float) -> void:
	rules.advance_time(delta)
	var evs: Array = rules.drain_events()
	if evs.size() > 0:
		_apply_events(evs)
	# EXT-13/15 相位门：轮询正/反两相开合沿，切换栏栅可见性（房间重建后缓存复位为当前相）
	var po: bool = rules.phase_gate_open()
	if po != _phase_open_last:
		_phase_open_last = po
		board.set_phase_state(po, not po)
	# EXT-31/33 潮汐格：轮询大潮/反相露淹沿，切换桥板颜色（湿泥绿-水蓝 / 暖沙-暗琥珀）
	var to: bool = rules.tide_open()
	var tlo: bool = rules.tide_late_open()
	if to != _tide_open_last or tlo != _tide_late_open_last:
		_tide_open_last = to
		_tide_late_open_last = tlo
		board.set_tide_state(to, tlo)
	# EXT-43 潮闸：轮询开/闭沿，切换横杆颜色（开=潮青可通行 / 闭=暗杆）
	var tgo: bool = rules.tide_gate_open()
	if tgo != _tgate_open_last:
		_tgate_open_last = tgo
		board.set_tide_gate_state(tgo)
	var i := _anims.size() - 1
	while i >= 0:
		var a: Dictionary = _anims[i]
		a.t = float(a.t) + delta / float(a.dur)
		var k := clampf(float(a.t), 0.0, 1.0)
		a.node.position = (a.from as Vector3).lerp(a.to as Vector3, k)
		if String(a.mode) == "burn":
			a.node.scale = Vector3.ONE * (1.0 - k)
		if float(a.t) >= 1.0:
			if bool(a.free_after):
				a.node.queue_free()
			_anims.remove_at(i)
		i -= 1
	if _demo_actions.size() > 0:
		_demo_frame += 1
		if _demo_actions.has(_demo_frame):
			_inject_demo_key(String(_demo_actions[_demo_frame]))


func _setup_demo_driver() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo-script="):
			var path := a.substr("--demo-script=".length())
			var f := FileAccess.open(path, FileAccess.READ)
			if f == null:
				push_warning("demo-script 无法打开: " + path)
				return
			while not f.eof_reached():
				var line := f.get_line().strip_edges()
				if line == "" or line.begins_with("#"):
					continue
				var parts := line.split(",", false, 1)  # maxsplit=1 → 恰好 2 段（frame,action），melt:x,y 的坐标含逗号
				if parts.size() >= 2:
					_demo_actions[int(parts[0])] = parts[1].strip_edges()


func _inject_demo_key(action: String) -> void:
	# 截图管线专用非按键动作（规则不变，只操纵核心的既有公开字段，与 v2 测试注入同性质）：
	# "room:N" = load_room 跳房；"melt:x,y" = 注入环境融化倒计时（当前五图无自然热源，冻结融化不可达）
	if action.begins_with("room:"):
		rules.load_room(int(action.substr(5)) - 1)
		_rebuild_room()
		return
	if action.begins_with("melt:"):
		var mp := action.substr(5).split(",")
		if mp.size() == 2:
			rules.melt_queue.append({x = int(mp[0]), y = int(mp[1]), left = 0.05})
		return
	var kc := 0
	match action:
		"up":
			kc = KEY_UP
		"down":
			kc = KEY_DOWN
		"left":
			kc = KEY_LEFT
		"right":
			kc = KEY_RIGHT
		"f":
			kc = KEY_F
		"g":
			kc = KEY_G
		"h":
			kc = KEY_H
		"home":
			kc = KEY_HOME
	if kc != 0:
		var ev := InputEventKey.new()
		ev.keycode = kc
		ev.physical_keycode = kc
		ev.pressed = true
		Input.parse_input_event(ev)


# ---------------- 镜头观察输入（滚轮缩放 / Home 复位；不加自由旋转，避免工具方向误解） ----------------

func _zoom(delta_size: float) -> void:
	cam.size = clampf(cam.size + delta_size, 5.0, 14.0)


func _reset_camera() -> void:
	cam.size = CAM_HOME_SIZE
	cam.position = CAM_HOME_POS
	cam.look_at(CAM_HOME_LOOK)


# ---------------- HUD ----------------

func _sync_hud() -> void:
	if rules.state == "final":
		var fam := ""
		var fam2 := ""
		var fam_n := 0
		for k in rules.family_by_room:
			var item := "房%d=%s" % [int(k) + 1, str(rules.family_by_room[k])]
			if fam_n < 3:
				fam += item + "  "
			else:
				fam2 += item + "  "
			fam_n += 1
		var fam_text := "解法家族：" + fam.strip_edges()
		if fam2 != "":
			fam_text += "\n" + fam2.strip_edges()
		final_label.text = "全通关！总步数 %d\n%s\n\n（遥测：工具 %d · 移物 %d · 冻 %d · 融 %d · 烧 %d · 门导通 %d）" % [
			int(rules.steps), fam_text, int(rules.tele.tool_use), int(rules.tele.object_move),
			int(rules.tele.freeze), int(rules.tele.melt), int(rules.tele.burn), int(rules.tele.switch_on)]
		final_label.visible = true
		_final_panel.visible = true
		_btn_cont.visible = true
		_btn_new.visible = true
	status_label.text = "%s · 房间 %d/%d · 步数 %d · 终点门 %s" % [
		rules.room_name(rules.room_idx), int(rules.room_idx) + 1, rules._total_rooms(), int(rules.steps),
		"开启" if rules.gate_open() else "关闭"]
	var tool_state := func(tname: String) -> String:
		return "✓" if rules.tools.has(tname) else "✗"
	tools_label.text = "面向：%s    F 冰霜杖 %s    G 火把 %s    H 磁石 %s    压住开关 %d/%d" % [
		rules.facing, tool_state.call("ice"), tool_state.call("fire"), tool_state.call("magnet"),
		_pressed_count(), _switch_total()]
	hint_label.text = "方向键移动 · F/G/H 朝面向格使用 · 滚轮缩放 · Home 复位视角 · Backspace 再来一次（续样本）"


## 板满足数/总数（跨普通板与反相板；反相板空置即满足）
func _pressed_count() -> int:
	var n := 0
	for o in rules.objects:
		var od: Dictionary = o
		var t := String(od.type)
		if (t == "switch" or t == "switch_not" or t == "switch_heavy" or t == "switch_latch") and rules._plate_satisfied(od):
			n += 1
	return n


func _switch_total() -> int:
	var n := 0
	for o in rules.objects:
		var t := String(o.type)
		if t == "switch" or t == "switch_not" or t == "switch_heavy" or t == "switch_latch":
			n += 1
	return n
