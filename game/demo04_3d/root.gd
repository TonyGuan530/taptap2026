extends Node3D
## DEMO4 3D Phase B：五关数据驱动（裂谷长跑/夜翼峡谷/融合之巅/碎岩回廊/终焉长廊）+ 实验房。
## 换算规则：x_3d = x_2d/100；平台顶高 = (470 - y_2d)/100；地面顶面 y=0。
## 语义逐项对应 2D v12（冻结基线）：DNA 增益、暗区 ×0.45、组合、碎岩撞裂墙。
## 3D 物理加固：裂纹墙顶统一 2.9m（2D 为 2.2m——3D 胶囊圆底可沿 0.5m 薄墙顶
## 「骑角」翻越 2.2~2.35m 的边缘墙；2.9m 距高跳上限 2.27m 有 0.63m 富余，
## 物理上不可跳越。碎岩仍是唯一解：L5 二段跳在墙后拿不到、组合不可达；
## L4 与 2D 一致允许组合越墙（碎岩是教学正解而非硬门）。
## 全程序化构建；测试入口 load_level(idx)。

const PLAYER_SCRIPT := preload("res://demo04_3d/player.gd")
const CAMERA_SCRIPT := preload("res://demo04_3d/camera_rig.gd")
const ABILITY_SCRIPT := preload("res://demo04_3d/ability_state.gd")
const ComicObjectScript := preload("res://comic_style/comic_object.gd")
const ML_COL := preload("res://comic_style/model_library.gd").COLORS

## 五关布局（每关独立重教 DNA，与 2D 一致）。floors=[x0,x1]；walls={x0,x1,h}；
## cracked={x0,x1,h}；up=[x0,x1,h] 上层捷径（仅超级弹跳可从地面跃上）；
## aliens={id,name,x,col}；shards=Vector3(x,高,0)；dark=[min,max]（空=无暗区）。
const LEVELS := [
	{
		name = "裂谷长跑",
		floors = [[0, 10], [10.6, 17], [19, 26], [29, 33]],
		walls = [{x0 = 10.0, x1 = 10.6, h = 1.8}],
		cracked = [],
		up = [],
		aliens = [
			{id = "highjump", name = "蹦蹦兽", x = 6.2, col = Color("ab47bc")},
			{id = "double", name = "双翼虫", x = 15.0, col = Color("4fc3f7")},
			{id = "glow", name = "灯灯菌", x = 23.8, col = Color("ffd54f")},
		],
		shards = [Vector3(10.3, 1.6, 0), Vector3(18.0, 1.2, 0), Vector3(27.5, 1.2, 0)],
		dark = [23.4, 36.0],
		goal = 31.0,
	},
	{
		name = "夜翼峡谷",
		floors = [[0, 7], [7.5, 9], [9.5, 14.5], [17.5, 26.5]],
		walls = [{x0 = 7.0, x1 = 7.5, h = 1.3}, {x0 = 9.0, x1 = 9.5, h = 2.8}],
		cracked = [],
		up = [],
		aliens = [
			{id = "highjump", name = "蹦蹦兽", x = 4.0, col = Color("ab47bc")},
			{id = "double", name = "双翼虫", x = 8.0, col = Color("4fc3f7")},
			{id = "glow", name = "灯灯菌", x = 13.5, col = Color("ffd54f")},
		],
		shards = [Vector3(9.25, 3.3, 0), Vector3(16.0, 1.9, 0), Vector3(21.5, 1.4, 0)],
		dark = [13.0, 24.0],
		goal = 23.5,
	},
	{
		name = "融合之巅",
		floors = [[0, 4], [4.5, 9], [11.5, 14.5], [17, 24.5]],
		walls = [{x0 = 4.0, x1 = 4.5, h = 2.7}, {x0 = 18.5, x1 = 19.0, h = 2.4}],
		cracked = [],
		up = [[7.0, 8.2, 3.0], [8.8, 10.2, 3.0], [10.8, 12.2, 3.0]],
		aliens = [
			{id = "highjump", name = "蹦蹦兽", x = 2.0, col = Color("ab47bc")},
			{id = "double", name = "双翼虫", x = 3.0, col = Color("4fc3f7")},
			{id = "glow", name = "灯灯菌", x = 6.5, col = Color("ffd54f")},
		],
		shards = [Vector3(4.25, 3.2, 0), Vector3(10.25, 1.9, 0), Vector3(18.75, 2.9, 0), Vector3(10.0, 3.4, -1.35)],
		dark = [7.0, 18.0],
		goal = 21.5,
	},
	{
		name = "碎岩回廊",
		floors = [[0, 12], [12.5, 18], [20.5, 25], [25.5, 33]],
		walls = [{x0 = 25.0, x1 = 25.5, h = 2.9}],
		cracked = [{x0 = 12.0, x1 = 12.5, h = 2.9}],
		up = [],
		aliens = [
			{id = "highjump", name = "蹦蹦兽", x = 2.0, col = Color("ab47bc")},
			{id = "break", name = "恐龙兽", x = 4.0, col = Color("e05a3a")},
			{id = "double", name = "双翼虫", x = 8.0, col = Color("4fc3f7")},
			{id = "glow", name = "灯灯菌", x = 14.0, col = Color("ffd54f")},
		],
		shards = [Vector3(6.25, 2.7, 0), Vector3(19.25, 0.7, 0), Vector3(25.25, 3.4, 0)],
		dark = [],
		goal = 30.0,
	},
	{
		name = "终焉长廊",
		floors = [[0, 7], [7.5, 12.5], [15, 19.5], [20, 24.5], [27, 34]],
		walls = [{x0 = 19.5, x1 = 20.0, h = 2.9}, {x0 = 27.5, x1 = 28.0, h = 2.4}],
		cracked = [{x0 = 7.0, x1 = 7.5, h = 2.9}],
		up = [[8.2, 9.6, 3.3], [10.8, 12.2, 3.3], [15.6, 17.0, 3.3], [18.3, 19.2, 3.3]],
		aliens = [
			{id = "glow", name = "灯灯菌", x = 2.0, col = Color("ffd54f")},
			{id = "highjump", name = "蹦蹦兽", x = 4.0, col = Color("ab47bc")},
			{id = "break", name = "恐龙兽", x = 6.0, col = Color("e05a3a")},
			{id = "double", name = "双翼虫", x = 10.0, col = Color("4fc3f7")},
		],
		shards = [Vector3(7.25, 2.7, 0), Vector3(13.75, 1.7, 0), Vector3(19.75, 3.4, 0), Vector3(16.2, 3.8, -1.35)],
		dark = [5.0, 25.0],
		goal = 31.0,
	},
]

const RATINGS := {"S": 45.0, "A": 90.0}   # ≤45s S / ≤90s A / 其余 B（对齐 2D）
const TESTER_IDS := ["P1", "P2", "P3", "P4", "P5"]

var ability: Node
var player: CharacterBody3D
var cam_rig: Node3D
var level_idx := 0
var mode := "campaign"           # campaign / lab
var saved_campaign_idx := 0
var tester_id := "P1"
var elapsed := 0.0
var won := false
var _advancing := false
var level_times: Array = []
var level_ratings: Array = []
var events: Array = []           # 遥测事件流（实验室 T 导出）

var level_root: Node3D
var alien_nodes: Dictionary = {}
var cracks: Array = []           # {x0,x1,h,body,vis,broken}
var _fuse_target: Dictionary = {}
var last_safe_pos := Vector3(1.0, 0.9, 0)   # 最近安全落点（掉坑恢复，指南 §61）
var _grounded_ticks := 0                     # 连续接地静止帧数（≥3 才更新安全点）
var _prev_player_pos := Vector3.ZERO         # 上一帧玩家位置（传送帧检测）
var stats := {"jumps": 0, "doubles": 0, "falls": 0, "dark_enter": 0, "fuses": 0}  # 会话聚合（遥测 v2）
var _in_dark_prev := false

var lbl_level: Label
var lbl_dna: Label
var lbl_stat: Label
var lbl_fuse: Label
var lbl_dark: Label
var lbl_combo: Label
var lbl_toast: Label
var win_panel: Panel
var lbl_win: Label
var toast_age := 99.0

func _ready() -> void:
	ability = Node.new()
	ability.name = "AbilityState"
	ability.set_script(ABILITY_SCRIPT)
	add_child(ability)

	_build_hud()
	_build_static()
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col.shape = capsule
	player.add_child(col)
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
	player.jump_performed.connect(_on_jump_performed)

	cam_rig = Node3D.new()
	cam_rig.name = "CameraRig"
	cam_rig.set_script(CAMERA_SCRIPT)
	cam_rig.excluded_body = player
	add_child(cam_rig)

	ability.dna_gained.connect(_on_dna_gained)
	ability.combo_discovered.connect(_on_combo_discovered)
	ability.shards_changed.connect(_on_shards_changed)
	load_level(0)
	_log_ev("session_start", {"levels": LEVELS.size()})
	_maybe_start_tour()

func _maybe_start_tour() -> void:
	## 调试巡游：Web ?tour=1 或原生 --tour 显式开启；真实输入驱动五关通关，
	## 供无窗口录证（CDP）与回归演示。正常游玩永不激活。
	var want := false
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("new URLSearchParams(location.search).get('tour')", true)
		want = str(v) == "1"
	elif "--tour" in OS.get_cmdline_user_args() or "--tour" in OS.get_cmdline_args():
		want = true
	if want:
		var drv := preload("res://demo04_3d/tour_driver.gd").new()
		drv.game = self
		add_child(drv)

func _build_static() -> void:
	# 灯光/环境：跨关常驻
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

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var root_c := Control.new()
	root_c.name = "Root"
	root_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root_c)
	lbl_level = _mk_label(root_c, 24, 16, 19, Color(1, 0.9, 0.55))
	lbl_dna = _mk_label(root_c, 24, 42, 18, Color(0.31, 0.76, 0.94))
	lbl_stat = _mk_label(root_c, 24, 68, 15, Color(0.85, 0.9, 0.95))
	lbl_fuse = _mk_label(root_c, 24, 92, 16, Color(1, 0.85, 0.4))
	lbl_fuse.visible = false
	lbl_dark = _mk_label(root_c, 24, 116, 15, Color(1, 0.55, 0.4))
	lbl_dark.text = "黑暗中……没有荧光寸步难行"
	lbl_dark.visible = false
	lbl_combo = _mk_label(root_c, 24, 140, 18, Color(0.5, 1, 0.6))
	lbl_combo.visible = false
	lbl_toast = _mk_label(root_c, 24, 168, 16, Color(1, 0.75, 0.3))
	lbl_toast.visible = false
	win_panel = Panel.new()
	win_panel.name = "WinPanel"
	win_panel.position = Vector2(220, 190)
	win_panel.size = Vector2(540, 200)
	win_panel.visible = false
	root_c.add_child(win_panel)
	lbl_win = _mk_label(win_panel, 20, 30, 18, Color(0.9, 0.95, 1))
	lbl_win.name = "WinText"

func _mk_label(parent: Control, x: float, y: float, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = Vector2(x, y)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func load_level(idx: int) -> void:
	## 关卡（重）载：清空旧节点组 → 按 LEVELS[idx] 重建 → 玩家归位。
	level_idx = clampi(idx, 0, LEVELS.size() - 1)
	_advancing = false
	won = false
	win_panel.visible = false
	_fuse_target = {}
	if level_root != null:
		level_root.queue_free()
	level_root = Node3D.new()
	level_root.name = "LevelRoot"
	add_child(level_root)
	alien_nodes = {}
	cracks = []
	ability.reset_level_state(true)   # 每关重教 DNA，组合发现跨关保留（对齐 2D）
	var L: Dictionary = LEVELS[level_idx]

	for f in L.floors:
		_solid(Vector3((f[0] + f[1]) / 2.0, -0.5, 0), Vector3(f[1] - f[0], 1.0, 10.0), ML_COL.stone)
	for w in L.walls:
		_solid(Vector3((w.x0 + w.x1) / 2.0, w.h / 2.0, 0), Vector3(w.x1 - w.x0, w.h, 3.0), ML_COL.iron_dark)
	for ci in L.cracked.size():
		_build_crack(L.cracked[ci], ci)
	# 上层捷径 = 西侧空中栈道（z -2.05..-0.65）：2D 悬台在主车道头顶会吃掉 3D 跳弧
	#（胶囊顶高 4.0m > 台底 2.8m， lip 跳必顶头）；改侧栈道后台道与车道零交集，
	# 组合独占可达性不变（顶 3.0/3.3 > 高跳 2.2，仅超级弹跳 4.15 可登）。
	for u in L.up:
		_solid(Vector3((u[0] + u[1]) / 2.0, u[2] - 0.1, -1.35), Vector3(u[1] - u[0], 0.2, 1.4), ML_COL.wood)
	for a in L.aliens:
		_build_alien(a)
	for spos in L.shards:
		_build_shard(spos)
	_build_goal(L.goal)
	# 走廊侧壁（隐形碰撞）：可行动 z 压到 ±1.6，堵死「墙边侧绕」（指南 §198）
	var x_end: float = L.goal + 2.0
	for zs in [-2.25, 2.25]:
		var side := StaticBody3D.new()
		var scs := CollisionShape3D.new()
		var sbox := BoxShape3D.new()
		sbox.size = Vector3(x_end, 8.0, 0.5)
		scs.shape = sbox
		side.position = Vector3(x_end / 2.0, 3.0, zs)
		side.add_child(scs)
		level_root.add_child(side)

	# 荧光灯随重置移除（DNA 每关重教，灯不该残留到无荧光的新关）
	for c in player.get_children():
		if c is OmniLight3D:
			c.queue_free()
	player.position = Vector3(1.0, 1.2, 0)
	player.velocity = Vector3.ZERO
	player.input_enabled = true
	last_safe_pos = Vector3(1.0, 0.9, 0)
	_prev_player_pos = Vector3(1.0, 1.2, 0)
	_grounded_ticks = 0
	cam_rig.position = player.position
	if mode == "lab":
		for id in ["highjump", "double", "glow", "break"]:
			ability.gain_dna(id)
	elapsed = 0.0
	_log_ev("level_start", {"level": level_idx, "mode": mode})
	_refresh_hud()

func _solid(pos: Vector3, size: Vector3, color: Color) -> void:
	## 世界几何 = ComicObject 视觉 + 独立 StaticBody3D 碰撞
	var obj := ComicObjectScript.new()
	obj.position = pos
	level_root.add_child(obj)
	obj.add_part(BoxMesh.new(), color, Transform3D.IDENTITY)
	obj.scale = size
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.position = pos
	body.add_child(cs)
	level_root.add_child(body)

func _build_crack(c: Dictionary, ci: int) -> void:
	## 裂纹岩墙：带碎岩 DNA 撞上即碎（对应 2D「撞击裂纹岩墙可将其击碎」）
	var center := Vector3((c.x0 + c.x1) / 2.0, c.h / 2.0, 0)
	var size := Vector3(c.x1 - c.x0, c.h, 3.0)
	var obj := ComicObjectScript.new()
	obj.position = center
	level_root.add_child(obj)
	obj.add_part(BoxMesh.new(), Color(0.52, 0.34, 0.2), Transform3D.IDENTITY)
	obj.scale = size
	var body := StaticBody3D.new()
	body.name = "Crack%d" % ci
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.position = center
	body.add_child(cs)
	level_root.add_child(body)
	cracks.append({"x0": c.x0, "x1": c.x1, "h": c.h, "body": body, "vis": obj, "broken": false})

func _build_alien(a: Dictionary) -> void:
	var area := Area3D.new()
	area.name = "Alien_" + a.id
	area.position = Vector3(a.x, 0.8, 0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.2
	cs.shape = sph
	area.add_child(cs)
	level_root.add_child(area)
	alien_nodes[a.id] = area
	var vis := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 0.7, 0.7)
	vis.mesh = mesh
	vis.position = area.position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = a.col
	mat.emission_enabled = true
	mat.emission = a.col * 0.4
	vis.material_override = mat
	level_root.add_child(vis)
	var lbl := Label3D.new()
	lbl.text = a.name
	lbl.font_size = 40
	lbl.position = area.position + Vector3(0, 1.0, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	level_root.add_child(lbl)

func _build_shard(spos: Vector3) -> void:
	var area := Area3D.new()
	area.position = spos
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.7
	cs.shape = sph
	area.add_child(cs)
	level_root.add_child(area)
	area.body_entered.connect(_on_shard_entered.bind(area))
	var vis := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.25, 0.35, 0.25)
	vis.mesh = mesh
	vis.position = spos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 1.0, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 0.35)
	vis.material_override = mat
	level_root.add_child(vis)
	area.set_meta("vis", vis)

func _build_goal(goal_x: float) -> void:
	var pod := ComicObjectScript.new()
	pod.position = Vector3(goal_x, 1.0, 0)
	level_root.add_child(pod)
	pod.add_part(BoxMesh.new(), ML_COL.iron, Transform3D.IDENTITY)
	pod.scale = Vector3(1.6, 2.0, 1.6)
	var goal := Area3D.new()
	goal.name = "Goal"
	var gcs := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(1.0, 3.0, 4.0)
	gcs.shape = gbox
	goal.position = Vector3(goal_x, 1.5, 0)
	goal.add_child(gcs)
	level_root.add_child(goal)
	goal.body_entered.connect(_on_goal_entered)

func _physics_process(delta: float) -> void:
	if player == null:
		return
	if not won:
		elapsed += delta
	var L: Dictionary = LEVELS[level_idx]
	var dark: Array = L.dark
	var in_dark: bool = dark.size() == 2 and float(dark[0]) < player.position.x and player.position.x < float(dark[1])
	player.in_dark_zone = in_dark
	if in_dark != _in_dark_prev:
		_log_ev("zone", {"zone": "dark", "enter": in_dark, "level": level_idx})
		if in_dark:
			stats.dark_enter += 1
		_in_dark_prev = in_dark
	lbl_dark.visible = in_dark and not ability.has_dna("glow")
	# 掉坑恢复（指南 §61/§198）：回到此前安全落点，不重开关卡、不丢 DNA/碎墙/碎片、计时继续
	var moved := player.position.distance_to(_prev_player_pos)
	_prev_player_pos = player.position
	if moved > 0.5:
		_grounded_ticks = 0   # 传送帧：陈旧 on_floor/vy 不可信，安全点计数清零
	elif player.position.y < -3.0:
		player.position = last_safe_pos if last_safe_pos.y > -0.5 else Vector3(1.0, 0.9, 0)
		player.velocity = Vector3.ZERO
		_grounded_ticks = 0
		_toast("掉坑了！回到安全边缘（DNA 与碎片保留）")
		stats.falls += 1
		_log_ev("pit_fall", {"level": level_idx})
	elif player.is_on_floor() and absf(player.velocity.y) < 0.01 and player.position.y > -0.5:
		# 真实落地静止才记安全点：静止帧 vy≈0（move_and_slide 清掉垂直分量）。
		# 传送后的陈旧帧靠 moved>0.5 清零 + 连续 3 帧门槛双重排除。
		_grounded_ticks += 1
		if _grounded_ticks >= 3:
			last_safe_pos = player.position
	else:
		_grounded_ticks = 0
	_update_fuse_candidate()
	_check_crack_smash()
	if toast_age < 3.0:
		toast_age += delta
		if toast_age >= 3.0:
			lbl_toast.visible = false
	if int(elapsed * 10.0) % 5 == 0:
		_refresh_hud()
	cam_rig.position = cam_rig.position.lerp(player.position, minf(1.0, delta * 8.0))
	cam_rig.position.y = maxf(cam_rig.position.y, player.position.y + 0.5)

func _check_crack_smash() -> void:
	## 撞击碎裂：有碎岩 DNA 且身体贴近裂纹墙基座（对应 2D「撞击可击碎」）
	if not ability.has_dna("break"):
		return
	for c in cracks:
		if c.broken:
			continue
		if absf(player.position.z) < 1.6 and player.position.x > c.x0 - 0.95 \
				and player.position.x < c.x1 + 0.95 and player.position.y < c.h + 1.0:
			c.broken = true
			c.body.queue_free()
			c.vis.queue_free()
			_toast("轰！裂纹岩墙被撞碎了！")
			_log_ev("crack_broken", {"level": level_idx})
			return

func _update_fuse_candidate() -> void:
	_fuse_target = {}
	var L: Dictionary = LEVELS[level_idx]
	if ability.dna.size() >= L.aliens.size():
		return
	var best := {}
	var space := player.get_world_3d().direct_space_state
	for a in L.aliens:
		if ability.has_dna(a.id):
			continue
		if not alien_nodes.has(a.id):
			continue
		var d: float = player.position.distance_to(alien_nodes[a.id].position)
		if d >= 1.2 or (not best.is_empty() and d >= best.d):
			continue
		# 隔墙不融合（指南 §198）：玩家→外星生物视线被实体挡住则不作为候选
		var ray := PhysicsRayQueryParameters3D.create(player.position, alien_nodes[a.id].position)
		ray.exclude = [player.get_rid()]
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or (hit.collider is Area3D):
			best = {"id": a.id, "name": a.name, "d": d}
	_fuse_target = best

func _on_jump_performed(jump_type: String) -> void:
	stats.jumps += 1
	if jump_type == "double":
		stats.doubles += 1

func _on_fuse_request() -> void:
	if _fuse_target.is_empty():
		return
	stats.fuses += 1
	_log_ev("dna_fuse", {"id": _fuse_target.id, "level": level_idx})
	ability.gain_dna(_fuse_target.id)

func _on_shard_entered(body: Node3D, area: Area3D) -> void:
	if body != player or area.has_meta("done"):
		return
	area.set_meta("done", true)
	var vis: Node = area.get_meta("vis")
	if vis != null:
		vis.queue_free()
	area.queue_free()
	ability.collect_shard()
	_log_ev("shard", {"level": level_idx})
	_toast("基因碎片 +1")
	_refresh_hud()

func _on_dna_gained(_id: String) -> void:
	if ability.has_dna("glow") and player != null:
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
	var nm := "超级弹跳" if id == "superjump" else "夜翼"
	lbl_combo.text = "组合发现：%s" % nm
	lbl_combo.visible = true
	_log_ev("combo", {"id": id, "level": level_idx})
	_toast("组合发现：%s" % nm)
	_refresh_hud()

func _on_shards_changed(_count: int, _total: int) -> void:
	_refresh_hud()

func _on_goal_entered(body: Node3D) -> void:
	if _advancing or body != player:   # 只认玩家；_advancing 防同帧重复触发
		return
	var rating := _rating(elapsed)
	level_times.append(elapsed)
	level_ratings.append(rating)
	_log_ev("level_done", {"level": level_idx, "time": snappedf(elapsed, 0.1), "rating": rating, "mode": mode})
	if mode == "lab":
		won = true
		player.input_enabled = false
		win_panel.visible = true
		lbl_win.text = "实验室演练完成！用时 %d 秒 · 评级 %s\nR 重来 · B 返回战役" % [int(elapsed), rating]
		return
	if level_idx < LEVELS.size() - 1:
		_advancing = true
		_toast("第 %d 关完成！评级 %s · %d 秒 → 下一关" % [level_idx + 1, rating, int(elapsed)])
		load_level(level_idx + 1)
	else:
		won = true
		player.input_enabled = false
		var total := 0.0
		for t in level_times:
			total += t
		var letters := ""
		for r in level_ratings:
			letters += str(r)
		win_panel.visible = true
		lbl_win.text = "全线逃脱成功！\n总用时 %d 秒 · 碎片 %d/%d · 评级 %s" % [
			int(total), ability.shards_total, _total_shards(), letters]

func _rating(t: float) -> String:
	if t <= RATINGS.S:
		return "S"
	if t <= RATINGS.A:
		return "A"
	return "B"

func _total_shards() -> int:
	var n := 0
	for L in LEVELS:
		n += L.shards.size()
	return n

func _toast(msg: String) -> void:
	lbl_toast.text = msg
	lbl_toast.visible = true
	toast_age = 0.0

func _log_ev(type: String, data: Dictionary = {}) -> void:
	events.append({"t": snappedf(Time.get_ticks_msec() / 1000.0, 0.1), "type": type}.merged(data))
	if events.size() > 800:
		events = events.slice(events.size() - 800)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and event.keycode):
		return
	match event.keycode:
		KEY_R:
			if event.shift_pressed:
				# 完整再跑（指南 §61）：清总碎片/总用时/评级/组合发现，回第 1 关
				level_times = []
				level_ratings = []
				stats = {"jumps": 0, "doubles": 0, "falls": 0, "dark_enter": 0, "fuses": 0}
				ability.reset_level_state(false)
				ability.shards_total = 0
				mode = "campaign"
				load_level(0)
				_toast("完整再跑：全部进度清零")
			else:
				load_level(level_idx)
				_toast("已重置本关")
		KEY_K:
			if mode == "campaign":
				mode = "lab"
				load_level(level_idx)
				_toast("实验室模式：全 DNA · R重置 B返回 T导出 G测试员")
		KEY_B:
			if mode == "lab":
				mode = "campaign"
				load_level(saved_campaign_idx)
				_toast("返回战役")
		KEY_G:
			tester_id = TESTER_IDS[(TESTER_IDS.find(tester_id) + 1) % TESTER_IDS.size()]
			_toast("测试员编号：%s" % tester_id)
		KEY_T:
			_export_telemetry()

func _export_telemetry() -> void:
	var stats := []
	for i in level_times.size():
		stats.append({"level": i + 1, "time": snappedf(level_times[i], 0.1), "rating": level_ratings[i]})
	var envelope := {
		"game": "demo-04-3d",
		"tester": tester_id,
		"mode": mode,
		"level_idx": level_idx + 1,
		"exported_at": Time.get_datetime_string_from_system(true),
		"stats": stats,
		"events": events,
	}
	DirAccess.make_dir_recursive_absolute("user://demo04_3d_lab_log")
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "_")
	var paths := ["user://demo04_3d_lab_log.json", "user://demo04_3d_lab_log/%s_%s.json" % [tester_id, stamp]]
	var ok_n := 0
	for pp in paths:
		var f := FileAccess.open(pp, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(envelope, "  "))
			f.close()
			ok_n += 1
	if ok_n == paths.size():
		_toast("遥测已导出（%s · %d 事件）" % [tester_id, events.size()])
	else:
		_toast("遥测导出失败")

func _refresh_hud() -> void:
	var L: Dictionary = LEVELS[level_idx]
	var mode_txt := "（实验室·全DNA）" if mode == "lab" else ""
	lbl_level.text = "第 %d/%d 关：%s %s" % [level_idx + 1, LEVELS.size(), L.name, mode_txt]
	var dna_names: Array = ability.dna_names()
	# 组合只显示本关已持有组件对应的组合（指南 §61）
	var combo_names := []
	if ability.combos_found.has("superjump") and ability.has_dna("highjump") and ability.has_dna("double"):
		combo_names.append("超级弹跳")
	if ability.combos_found.has("nightwing") and ability.has_dna("double") and ability.has_dna("glow"):
		combo_names.append("夜翼")
	var combo_txt: String = ("（组合：" + "、".join(combo_names) + "）") if combo_names.size() > 0 else ""
	lbl_dna.text = "DNA：" + (("已融合 " + " + ".join(dna_names) + " " + combo_txt) if dna_names.size() > 0 else "无（找到外星生物，按 E 融合）")
	lbl_stat.text = "碎片 %d · 累计 %d/%d · 用时 %d 秒" % [ability.shards_level, ability.shards_total, _total_shards(), int(elapsed)]
	if not _fuse_target.is_empty():
		lbl_fuse.text = "按 E 与 %s 融合" % _fuse_target.name
		lbl_fuse.visible = true
	else:
		lbl_fuse.visible = false
