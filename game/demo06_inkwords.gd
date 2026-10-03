extends Node2D
## 词条涂鸦创造（demo-06）：探索获得词条 + 有限墨水放置"形状×词条"物体解谜。
## 统一规则驱动：物体行为 = 形状几何 × 词条物理参数，无硬编码配方。
## 词条：Heavy 重(砸碎脆物) / Float 浮(悬浮平台) / Fire 燃(点燃易燃物) / Sticky 黏(接触即固定)
## 形状：圆球 / 长板 / 方块。对应 Miro 玩法块 demo-06。纯代码实现、无外部资源。
##
## v2 迭代（ChatGPT 评审 ITERATE Gate：L3「无显式克制的开放物理问题」修复完善，2026-10-03）：
## 1) L3 加载冻结根因分析：
##    ① 测试侧假冻结（有实证）：tests/probe06.gd、probeL3c2.gd 访问了 demo06 上不存在的 scene.ball 属性，
##       headless 下脚本报错中断探测循环，进程无输出空转直到超时，表象即"加载冻结"
##       （user://p06log.txt、pL3c2log.txt 均恰好停在 "loaded" 一行；而 L3 关闭 objects 后
##       loadtrace.txt 全程 step0..done 完整走通，物理帧率与 L1 相同，游戏本体并无死循环）。
##    ② 物理侧真风险（代码实证）：旧 L3 预置物体出生位两两包围盒互叠——长板 x225..375 与
##       方块 x190..250 相交 25px、方块与圆球 x190..206 相交 16px，三个 RigidBody2D 同帧深叠，
##       分离冲量易发散出 NaN 速度 → 物理步进卡死（本项目已有同类前科：
##       _physics_process 内"坠落出界自动复位（防 NaN 卡死物理）"注释）。
## 2) 修复改法（本版全部落实）：
##    - 预置物体出生点位重新排布：任意两物体、物体与玩家出生点的包围盒互不重叠（见 LEVELS[2].objects）；
##    - 物体生成改为 call_deferred 帧末执行：等旧关卡体 queue_free 真正删除后再进新刚体，
##      生成前做关卡一致性校验 + 组内去重，杜绝快速切关时的重复/残留生成（_spawn_level_objects）；
##    - 每帧对预置物体做 NaN/坠落自动复位（统一物理规则，不判解法）；
##    - 预置物体补上可见绘制（旧版加入后完全不可见）；R 键与坠落复位改用当前关卡 spawn 点；
##    - 移除排查期 loadtrace 调试落盘。
## 3) L3 规格达成：目标跨越 420px 宽断层；场景预置 3 个普通动态物体（无词条、可推可撞）；
##    无任何针对解法的 trigger，通关只由"玩家进入 GOAL"统一规则驱动（Goal Area2D 只挂玩家层）；
##    三种依赖不同物理关系的解法自然成立：
##    A. Float 长板 ×2 → 悬空桥（浮力平台关系，80 墨）；
##    B. Sticky 方块 → 丢进沟里靠右壁，接触冻结成固定垫脚（黏附固定关系，40 墨）；
##    C. 把预置方块推下沟/用 Heavy 圆球撞进沟贴右壁 → 动量传递成垫脚（质量碰撞关系，0~40 墨）。

## v3 迭代（ChatGPT L3 评审 KEEP：下一道 Gate = 真人数据盲测，2026-10-03）：
##    新增轻量 telemetry（评审指定 8 字段：timestamp/shape/tag/spawn_position/ink_cost/
##    object_contact/death_or_reset/goal），本地记录无后台——web 存 localStorage、
##    本地存 user://telemetry_demo06.json，右下角「📦数据」面板可看 JSON/复制/设受试编号，
##    通关时自动打印到控制台。玩法、L3 几何、解法提示（本就不渲染）零改动，不污染盲测。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")
const GRAV := 1600.0
const WALK := 240.0
const JUMP_V := 520.0

## 词条：统一物理参数表（任何形状×任何词条都成立，无配方）
const WORDS := [
	{ id = "heavy", name = "Heavy", col = Color("8d8d94"), cost = 10, g = 2.6, float_up = 0.0, burn = false, sticky = false,
		tip = "又重又快：砸碎脆障碍" },
	{ id = "float", name = "Float", col = Color("4fc3f7"), cost = 15, g = 0.0, float_up = 0.0, burn = false, sticky = false,
		tip = "悬浮原地：当空中平台" },
	{ id = "fire", name = "Fire", col = Color("ef5350"), cost = 15, g = 1.0, float_up = 0.0, burn = true, sticky = false,
		tip = "点燃易燃物：木头烧光" },
	{ id = "sticky", name = "Sticky", col = Color("8d6e63"), cost = 10, g = 1.0, float_up = 0.0, burn = false, sticky = true,
		tip = "接触即粘住：当垫脚台" },
]
## 形状：几何 + 墨水价
const SHAPES := [
	{ id = "ball", name = "圆球", cost = 30, kind = "ball", size = Vector2(56, 56) },
	{ id = "plank", name = "长板", cost = 25, kind = "plank", size = Vector2(130, 22) },
	{ id = "block", name = "方块", cost = 30, kind = "block", size = Vector2(64, 64) },
]

## 关卡（只给目标，不规定解法）
const LEVELS := [
	{
		name = "第一关 · 栅栏与沟",
		walls = [
			Rect2(-40, -200, 1040, 200), Rect2(-40, 0, 40, 540), Rect2(960, 0, 40, 540),
			Rect2(0, 470, 960, 70),
		],
		spawn = Vector2(70, 430),
		fence = Rect2(500, 350, 26, 120),        # 易燃木栅栏（挡路）
		goal = Rect2(830, 400, 100, 70),
		ink = 100,
	},
	{
		name = "第二关 · 登上高台",
		walls = [
			Rect2(-40, -200, 1040, 200), Rect2(-40, 0, 40, 540), Rect2(960, 0, 40, 540),
			Rect2(0, 470, 960, 70),
			Rect2(760, 310, 240, 160),               # 高台
		],
		spawn = Vector2(80, 430),
		fence = Rect2(),
		goal = Rect2(810, 240, 130, 70),          # 高台顶上
		ink = 140,
	},
	{
		name = "第三关 · 断层验证（无属性锁）",
		walls = [
			Rect2(-40, -200, 1040, 200), Rect2(-40, 0, 40, 540), Rect2(960, 0, 40, 540),
			Rect2(0, 400, 340, 140),               # 左台
			Rect2(745, 400, 255, 140),             # 右台（v2: 760→745，缩小板2→台空隙，实测抛物线余量不足曾卡台缘）
			Rect2(340, 520, 405, 40),              # 沟底（掉进来不至于出屏）
		],
		spawn = Vector2(70, 330),
		fence = Rect2(),                            # 无易燃物：禁止"见木就烧"式属性锁
		goal = Rect2(790, 370, 130, 60),          # 右台上
		ink = 130,
		solution = "参考解法（仅提示，不做检测）：A. 两块 Float 长板悬空搭桥(约80墨)；B. Sticky 方块丢进沟靠右壁当固定垫脚(40墨)；C. 把预置方块推/用 Heavy 圆球撞进沟贴壁，垫脚翻上右台(0~40墨)",
		objects = [                               # 场景预置普通物体（无词条，可推可撞）
			# v2：出生位两两包围盒互不重叠、且避开玩家出生点(70,330)——修复同帧深叠导致的物理发散
			{ kind = "ball", size = Vector2(52, 52), pos = Vector2(30, 310) },
			{ kind = "plank", size = Vector2(150, 20), pos = Vector2(140, 270) },
			{ kind = "block", size = Vector2(60, 60), pos = Vector2(255, 330) },
		],
	},
	{
		# L4（转向阶梯·补充关卡 2026-10-03）：翻越高墙。墙顶 380、抬升 90，略高于跳高 84.5，
		# 不可直接跳过；无属性锁、无解法 trigger，通关只判"玩家进 GOAL"。已知通路（不作检测）：
		#   A. 一块 Float 长板（顶 390）走上墙头——40 墨；
		#   B. 推环境方块贴墙垫脚（顶 410）跳上墙头——0 墨，纯推箱；
		#   C. 玩家自创组合（涌现观察点）。
		name = "第四关 · 翻越高墙",
		walls = [
			Rect2(-40, -200, 1040, 200), Rect2(-40, 0, 40, 540), Rect2(960, 0, 40, 540),
			Rect2(0, 470, 960, 70),                  # 地面
			Rect2(500, 380, 44, 90),                 # 高墙（顶 380，抬升 90 > 跳高 84.5，不可直跳）
		],
		spawn = Vector2(70, 430),
		fence = Rect2(),                            # 无易燃物：无"见木就烧"属性锁
		goal = Rect2(790, 400, 110, 70),          # 墙右侧地面
		ink = 150,
		objects = [                               # 预置普通物体（可推可站）：置于起跳点之后、避开跳跃弧线（净空>=10px）
			{ kind = "block", size = Vector2(60, 60), pos = Vector2(400, 430) },
			{ kind = "ball", size = Vector2(52, 52), pos = Vector2(460, 428) },
		],
	},
]

var level_idx := 0
var ink := 100
var shape_idx := 0
var word_idx := 0
var placed := []               # 放置的物体节点
var state := "play"            # play / win
var elapsed := 0.0
var pulse := 0.0
var player: CharacterBody2D
var player_vy := 0.0
var on_floor := false
var keys := {}
var jumps_used := 0

var ui_labels := {}
var ui_layer: CanvasLayer = null   # v4：直接持有 UI 层引用——旧 find_child("CanvasLayer")
                                   # 查不到自动名 "@CanvasLayer@2"，致通关面板从未显示（线上实测发现）
var env_oid_n := 0                 # v5：预置物体实例 ID 计数（contact 链还原用）

# ---------------- 盲测 telemetry（本地记录，无后台） ----------------
var tel_pid := "P01"        # 受试编号（数据面板可改，随记录保留）
var tel_sid := ""           # 会话号：区分多次运行/页面刷新
var tel_events := []        # 事件流水（只放 str/int/float/Array，保证 JSON 可序列化）
var tel_t0_ms := 0          # 会话起始，用于 elapsed


func _ready() -> void:
	tel_sid = str(int(Time.get_unix_time_from_system()))
	tel_t0_ms = Time.get_ticks_msec()
	_tel_restore()
	_build_ui()
	_load_level(0)


func _find(n: String) -> Node:
	return get_tree().root.find_child(n, true, false)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui_layer = ui
	add_child(ui)
	var title := Label.new()
	title.text = "词条涂鸦创造 · 形状×词条=万物（demo-06）"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ffd54f"))
	ui.add_child(title)
	var ink_l := Label.new()
	ink_l.name = "Ink"
	ink_l.position = Vector2(16, 40)
	ink_l.add_theme_font_size_override("font_size", 15)
	ink_l.add_theme_color_override("font_color", Color("4fc3f7"))
	ui.add_child(ink_l)
	var st := Label.new()
	st.name = "Status"
	st.position = Vector2(16, 66)
	st.size = Vector2(760, 24)
	st.add_theme_font_size_override("font_size", 14)
	ui.add_child(st)
	var hint := Label.new()
	hint.name = "Hint"
	hint.position = Vector2(16, VIEW.y - 30)
	hint.size = Vector2(940, 26)
	hint.add_theme_font_size_override("font_size", 13)
	ui.add_child(hint)

	# 形状按钮（左）与词条按钮（右）
	for i in SHAPES.size():
		var b := Button.new()
		b.text = "%s %d💧" % [SHAPES[i].name, SHAPES[i].cost]
		b.position = Vector2(560 + i * 100, 6)
		b.size = Vector2(96, 32)
		b.pressed.connect(_on_shape.bind(i))
		b.name = "ShapeBtn" + str(i)
		ui.add_child(b)
	for i in WORDS.size():
		var b2 := Button.new()
		b2.text = WORDS[i].name
		b2.position = Vector2(560 + i * 100, 40)
		b2.size = Vector2(96, 30)
		b2.pressed.connect(_on_word.bind(i))
		b2.name = "WordBtn" + str(i)
		ui.add_child(b2)
	# 盲测数据导出入口（右下角小按钮，不进玩法区）
	var tdb := Button.new()
	tdb.text = "📦数据"
	tdb.position = Vector2(884, 506)
	tdb.size = Vector2(72, 28)
	tdb.pressed.connect(_on_tel_panel)
	ui.add_child(tdb)


func _refresh_buttons() -> void:
	for i in SHAPES.size():
		var b = get_tree().root.find_child("ShapeBtn" + str(i), true, false)
		if b: b.add_theme_color_override("font_color", Color("ffd54f") if i == shape_idx else Color("e8ecf4"))
	for i in WORDS.size():
		var b2 = get_tree().root.find_child("WordBtn" + str(i), true, false)
		if b2: b2.add_theme_color_override("font_color", Color("ffd54f") if i == word_idx else Color("e8ecf4"))


func _on_shape(i: int) -> void:
	shape_idx = i
	_tel("select", {"shape": SHAPES[i].id})
	_refresh_buttons()


func _on_word(i: int) -> void:
	word_idx = i
	_tel("select", {"tag": WORDS[i].id})
	_refresh_buttons()
	_set_hint("%s：%s" % [WORDS[i].name, WORDS[i].tip])


func _set_status(t: String) -> void:
	var l = get_tree().root.find_child("Status", true, false)
	if l: l.text = t
	var i2 = get_tree().root.find_child("Ink", true, false)
	if i2: i2.text = "墨水 %d" % ink


func _set_hint(t: String) -> void:
	var l = get_tree().root.find_child("Hint", true, false)
	if l: l.text = t


# ---------------- 关卡 ----------------

func _load_level(idx: int) -> void:
	level_idx = idx
	var lv: Dictionary = LEVELS[idx]
	ink = lv.ink
	state = "play"
	elapsed = 0.0
	_tel("start", {"ink": ink})
	for c in get_children():
		if c is RigidBody2D or c is StaticBody2D or c is CharacterBody2D:
			c.queue_free()
	for wi in lv.walls.size():
		_add_static(lv.walls[wi], Color("39415a"))
	if lv.fence.size.x > 0:
		_add_fence(lv.fence)
	# v2 修复：预置物体延迟到帧末生成——旧关卡体 queue_free 真正删除、本帧物理状态
	# 稳定之后，新刚体才进场；避免新旧物理体同帧混存加剧求解器发散（L3 加载冻结修复点）
	if lv.has("objects"):
		call_deferred("_spawn_level_objects", lv)
	_spawn_player(lv.spawn)
	_add_goal(lv.goal)
	_refresh_buttons()


## v2：帧末生成预置物体（带关卡一致性校验与组内去重，防快速切关残留/重复）
func _spawn_level_objects(lv: Dictionary) -> void:
	if lv != LEVELS[level_idx] or state != "play":
		return
	for n in get_tree().get_nodes_in_group("level_objs"):
		var old := n as RigidBody2D
		if old:
			old.queue_free()
	if not lv.has("objects"):
		return
	for od in lv.objects:
		_add_dynamic(od)


func _add_static(r: Rect2, col: Color) -> void:
	var body := StaticBody2D.new()
	body.position = r.position + r.size / 2.0
	body.set_meta("rect", r)
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	body.add_child(cs)
	add_child(body)


func _add_fence(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = "Fence"
	body.position = r.position + r.size / 2.0
	body.set_meta("rect", r)
	body.set_meta("flammable", true)
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	body.add_child(cs)
	add_child(body)


func _add_goal(r: Rect2) -> void:
	var g := Area2D.new()
	g.name = "Goal"
	g.position = r.position + r.size / 2.0
	g.collision_mask = 2   # 只检测玩家层
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	g.add_child(cs)
	g.body_entered.connect(func(body): if body == player: _win())
	add_child(g)
	set_meta("goal_rect", r)


func _add_dynamic(od: Dictionary) -> void:
	var body := RigidBody2D.new()
	body.position = od.pos
	body.add_to_group("level_objs")   # v2：统一标记，供清理/复位/绘制/测试使用
	env_oid_n += 1
	body.set_meta("oid", "env_%s_%02d" % [od.kind, env_oid_n])   # v5：实例 ID，盲测还原接触链
	var cs := CollisionShape2D.new()
	if od.kind == "ball":
		var sh := CircleShape2D.new()
		sh.radius = od.size.x / 2.0
		cs.shape = sh
	else:
		var sh2 := RectangleShape2D.new()
		sh2.size = od.size
		cs.shape = sh2
	body.add_child(cs)
	body.set_meta("size", od.size)
	body.set_meta("kind", od.kind)
	body.set_meta("spawn", od.pos)    # v2：记录出生点，供 NaN/坠落复位
	# v5（评审）：预置物体也上报 contact_enter——接触链必须包含环境物体
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.body_entered.connect(_on_env_contact.bind(body))
	add_child(body)


func _on_env_contact(body_node: Node, env_body: RigidBody2D) -> void:
	_tel("contact", {"oid": str(env_body.get_meta("oid", "")),
		"with": _tel_oid(body_node), "ev": "enter"})


func _spawn_player(pos: Vector2) -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.position = pos
	player.collision_layer = 2
	player.collision_mask = 1 | 4
	var cs := CollisionShape2D.new()
	var sh := CapsuleShape2D.new()
	sh.radius = 12
	sh.height = 40
	cs.shape = sh
	player.add_child(cs)
	add_child(player)


# ---------------- 放置 ----------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		# UI 区域不放置
		if pos.x > 540 and pos.y < 80:
			return
		if state == "play":
			_try_place(pos)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_tel("reset", {"why": "R", "pos": [snappedf(player.position.x, 0.5), snappedf(player.position.y, 0.5)]})
		player.position = LEVELS[level_idx].spawn   # v2：改用当前关卡出生点（原为写死坐标）
		player.velocity = Vector2.ZERO
	elif event is InputEventKey:
		keys[event.keycode] = event.pressed


func _try_place(pos: Vector2) -> void:
	var shape: Dictionary = SHAPES[shape_idx]
	var word: Dictionary = WORDS[word_idx]
	var cost: int = shape.cost + word.cost
	if ink < cost:
		_set_hint("墨水不够（需要 %d，剩 %d）" % [cost, ink])
		return
	ink -= cost
	var body := RigidBody2D.new()
	body.position = pos
	body.name = "Placed_" + word.id + "_" + shape.id + "_" + str(placed.size())
	var cs := CollisionShape2D.new()
	if shape.kind == "ball":
		var sh := CircleShape2D.new()
		sh.radius = shape.size.x / 2.0
		cs.shape = sh
	else:
		var sh2 := RectangleShape2D.new()
		sh2.size = shape.size
		cs.shape = sh2
	body.add_child(cs)
	# ---- 统一规则：词条决定物理参数（对任何形状都成立） ----
	body.gravity_scale = word.g
	if word.id == "heavy":
		body.mass = 8.0
	if word.id == "float":
		body.gravity_scale = 0.0
		body.can_sleep = false
	if word.sticky:
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.0
		pm.friction = 4.0
		body.physics_material_override = pm
	if word.burn:
		body.set_meta("burning", true)
		var burn_out := get_tree().create_timer(2.0)
		burn_out.timeout.connect(func():
			if is_instance_valid(body):
				body.queue_free())
	body.set_meta("word", word.id)
	body.set_meta("oid", "placed_%02d" % placed.size())   # v5：实例 ID
	if word.id == "float":
		body.collision_layer = 4
		body.collision_mask = 1 | 2
	else:
		body.collision_layer = 8
		body.collision_mask = 1 | 8
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.body_entered.connect(_on_placed_contact.bind(body))
	add_child(body)
	placed.append(body)
	# Float：悬浮原地（freeze 在放置点，成为可站平台）
	if word.id == "float":
		body.freeze = true
	# Sticky：接触后 0.4 秒冻结固定（当垫脚台）
	if word.sticky:
		var t := get_tree().create_timer(0.4)
		t.timeout.connect(func():
			if is_instance_valid(body):
				body.freeze = true)
	_tel("place", {"shape": shape.id, "tag": word.id,
		"pos": [snappedf(pos.x, 0.5), snappedf(pos.y, 0.5)],
		"ink_cost": cost, "ink_left": ink})
	_set_hint("放置了 %s×%s（-%d💧）。%s" % [shape.name, word.name, cost, word.tip])


## v5：接触对象实例 ID（env/placed 带 oid，墙/栅栏/玩家用稳定名）
func _tel_oid(n: Node) -> String:
	if n == player:
		return "player"
	if n.has_meta("oid"):
		return str(n.get_meta("oid"))
	if n.name == "Fence":
		return "fence"
	if n is StaticBody2D:
		return "wall"
	if n is RigidBody2D and n.is_in_group("level_objs"):
		return "env"
	if n is RigidBody2D:
		return "placed"
	return "other"


func _on_placed_contact(body_node: Node, placed_body: RigidBody2D) -> void:
	var word_id: String = placed_body.get_meta("word", "")
	# v5 盲测：contact_enter 序列——body_entered 天然只在“接触开始/分离后再接触”触发，
	# 无逐帧重复；带双方实例 ID，可还原玩家构造的接触链
	_tel("contact", {"oid": str(placed_body.get_meta("oid", "")),
		"with": _tel_oid(body_node), "ev": "enter"})
	# 统一规则：Fire 遇易燃物 → 烧毁；Heavy 重物遇脆物/栅栏 → 砸毁
	if word_id == "fire" and (body_node.get_meta("flammable", false) or body_node.name == "Fence"):
		body_node.queue_free()
		_set_hint("🔥 栅栏被烧毁了！")
	if word_id == "heavy" and body_node.name == "Fence":
		body_node.queue_free()
		_set_hint("栅栏被重物砸碎了！")


# ---------------- 玩家 ----------------

func _physics_process(delta: float) -> void:
	if state != "play" or player == null or not is_instance_valid(player):
		return
	elapsed += delta
	pulse += delta * 4.0
	var left: bool = keys.get(KEY_LEFT, false) or keys.get(KEY_A, false)
	var right: bool = keys.get(KEY_RIGHT, false) or keys.get(KEY_D, false)
	player.velocity.x = (float(right) - float(left)) * WALK
	if (keys.get(KEY_SPACE, false) or keys.get(KEY_W, false) or keys.get(KEY_UP, false)) and on_floor:
		player.velocity.y = -JUMP_V
	player.velocity.y += GRAV * delta if not player.is_on_floor() else 0.0
	player.move_and_slide()
	on_floor = player.is_on_floor()
	# 坠落出界自动复位（防 NaN 卡死物理）
	if player.position.y > 700:
		_tel("reset", {"why": "fall", "pos": [snappedf(player.position.x, 0.5), snappedf(player.position.y, 0.5)]})
		player.position = LEVELS[level_idx].spawn   # v2：改用当前关卡出生点（原为写死坐标）
		player.velocity = Vector2.ZERO
	# 玩家推动普通物体（统一物理：推力来自行走）
	for i in player.get_slide_collision_count():
		var col := player.get_slide_collision(i)
		var rb = col.get_collider()
		if rb is RigidBody2D:
			rb.apply_central_impulse(-col.get_normal() * 6.0)
	# v2：预置物体 NaN/坠落防护（统一物理规则，不判解法）
	for o in get_tree().get_nodes_in_group("level_objs"):
		var ob := o as RigidBody2D
		if ob == null:
			continue
		if is_nan(ob.position.x) or is_nan(ob.position.y) or ob.position.y > 700:
			ob.position = ob.get_meta("spawn", Vector2(100, 300)) as Vector2
			ob.linear_velocity = Vector2.ZERO
			ob.angular_velocity = 0.0
	# Float 物体悬浮微动
	for p in placed:
		if is_instance_valid(p) and p.get_meta("word", "") == "float" and p.freeze:
			p.position.y += sin(pulse + p.position.x) * 0.3
	queue_redraw()


# ---------------- 胜利 ----------------

func _win() -> void:
	if state != "play":
		return
	state = "win"
	_tel("goal", {"elapsed": snappedf(elapsed, 0.1), "ink_left": ink, "placements": placed.size()})
	_tel("session_end", {"end_reason": "goal"})   # v5：通关自动封口（评审：未通关局由组织者在📦面板手动封口）
	print("[demo-06 telemetry] " + tel_export_json())   # 盲测可只靠录屏+控制台取数
	var panel := Panel.new()
	panel.name = "WinPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(240, 180)
	panel.size = Vector2(480, 180)
	var ui := get_tree().root.find_child("UI", true, false)
	if ui:
		ui.add_child(panel)
	var t := Label.new()
	# v5：文案中性化（评审）——不暗示“多解/换组合”，避免污染受试者后续行为
	t.text = "🏁 测试完成，请通知组织者。\n%s · 用时 %d 秒 · 剩余墨水 %d · 放置 %d 个物体" % [
		LEVELS[level_idx].name, int(elapsed), ink, placed.size()]
	t.position = Vector2(24, 20)
	t.size = Vector2(430, 110)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", Color("111111"))
	panel.add_child(t)
	var next := Button.new()
	next.text = ("下一关" if level_idx + 1 < LEVELS.size() else "重玩本关")
	next.position = Vector2(24, 130)
	next.size = Vector2(140, 36)
	next.pressed.connect(func():
		panel.visible = false
		if level_idx + 1 < LEVELS.size():
			_load_level(level_idx + 1)
		else:
			_load_level(0))
	panel.add_child(next)


# ---------------- 盲测 telemetry 实现 ----------------

func _tel(type: String, extra: Dictionary = {}) -> void:
	var ev := {
		"type": type,
		"ts": Time.get_datetime_string_from_system(),
		"el": snappedf((Time.get_ticks_msec() - tel_t0_ms) / 1000.0, 0.1),
		"sid": tel_sid,
		"level": level_idx,
	}
	for k in extra:
		ev[k] = extra[k]
	tel_events.append(ev)
	_tel_persist()


func tel_export_json() -> String:
	return JSON.stringify({"pid": tel_pid, "events": tel_events})


## web→localStorage（base64 防转义），本地→user:// 文件；失败静默，不影响玩法
func _tel_persist() -> void:
	if OS.has_feature("web"):
		var payload := Marshalls.utf8_to_base64(tel_export_json())
		var js = Engine.get_singleton("JavaScriptBridge")
		js.eval("try{localStorage.setItem('demo06_tel','%s')}catch(e){}" % payload)
	else:
		var f := FileAccess.open("user://telemetry_demo06.json", FileAccess.WRITE)
		if f:
			f.store_string(tel_export_json())


## 启动恢复历史事件（多次运行累积在同一份记录，按 sid 区分会话）
func _tel_restore() -> void:
	var raw := ""
	if OS.has_feature("web"):
		var js = Engine.get_singleton("JavaScriptBridge")
		var r = js.eval("(function(){try{return localStorage.getItem('demo06_tel')||''}catch(e){return ''}})()", true)
		raw = str(r)
	elif FileAccess.file_exists("user://telemetry_demo06.json"):
		raw = FileAccess.get_file_as_string("user://telemetry_demo06.json")
	if raw == "":
		return
	var json_text := raw
	if OS.has_feature("web"):
		json_text = Marshalls.base64_to_utf8(raw)
	var parsed = JSON.parse_string(json_text)
	if parsed is Dictionary and parsed.get("events", null) is Array:
		tel_events = parsed["events"]
		if parsed.get("pid", "") is String and str(parsed["pid"]) != "":
			tel_pid = str(parsed["pid"])


## 📦数据面板：受试编号 + JSON 查看/复制（盲测后取数用）
func _on_tel_panel() -> void:
	if ui_layer == null or not is_instance_valid(ui_layer) or ui_layer.has_node("TelPanel"):
		return
	var ui := ui_layer
	var panel := Panel.new()
	panel.name = "TelPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.97)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(150, 60)
	panel.size = Vector2(660, 420)
	ui.add_child(panel)
	var pid_l := LineEdit.new()
	pid_l.name = "TelPid"
	pid_l.text = tel_pid
	pid_l.position = Vector2(16, 14)
	pid_l.size = Vector2(120, 30)
	pid_l.placeholder_text = "受试编号"
	pid_l.text_changed.connect(func(s: String): tel_pid = s)
	panel.add_child(pid_l)
	var box := TextEdit.new()
	box.text = tel_export_json()
	box.position = Vector2(16, 54)
	box.size = Vector2(628, 316)
	box.editable = false
	panel.add_child(box)
	var copy := Button.new()
	copy.text = "复制 JSON"
	copy.position = Vector2(160, 380)
	copy.size = Vector2(120, 30)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(tel_export_json())
		_set_hint("telemetry 已复制到剪贴板"))
	panel.add_child(copy)
	# v5（评审）：组织者操作的“结束本次测试”封口——照顾未通关/放弃局，点后自动复制
	var endb := Button.new()
	endb.text = "结束本次测试(未通关)"
	endb.position = Vector2(400, 380)
	endb.size = Vector2(170, 30)
	endb.pressed.connect(func():
		_tel("session_end", {"end_reason": "give_up"})
		DisplayServer.clipboard_set(tel_export_json())
		box.text = tel_export_json()
		_set_hint("已封口（give_up）并复制 JSON——请交给组织者"))
	panel.add_child(endb)
	var clr := Button.new()
	clr.text = "清空记录"
	clr.position = Vector2(290, 380)
	clr.size = Vector2(110, 30)
	clr.pressed.connect(func():
		tel_events = []
		_tel_persist()
		box.text = tel_export_json())
	panel.add_child(clr)
	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(580, 380)
	close.size = Vector2(64, 30)
	close.pressed.connect(func(): panel.queue_free())
	panel.add_child(close)
	print("[demo-06 telemetry] " + tel_export_json())


# ---------------- 绘制 ----------------

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var lv: Dictionary = LEVELS[level_idx]
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color("141a26"))
	# 目标区
	var gr: Rect2 = get_meta("goal_rect", Rect2(830, 400, 100, 70))
	draw_rect(gr, Color(1.0, 0.84, 0.31, 0.15))
	draw_rect(gr, Color("ffd54f"), false, 3)
	draw_string(FONT, gr.position + Vector2(8, 24), "GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffd54f"))
	# 地形
	for c in get_children():
		if c is StaticBody2D and c.has_meta("rect"):
			var r: Rect2 = c.get_meta("rect")
			draw_rect(r, Color("39415a"))
			draw_rect(r, Color("1c2030"), false, 2)
		# 木栅栏
		if c is StaticBody2D and c.name == "Fence" and is_instance_valid(c):
			var fr: Rect2 = c.get_meta("rect")
			draw_rect(fr, Color("8d6e63"))
			draw_line(fr.position, fr.position + fr.size, Color("5d4037"), 2)
	# 预置普通物体（v2：无词条、可推可撞；旧版加入后不可见，这里补上绘制）
	for o in get_tree().get_nodes_in_group("level_objs"):
		var ob := o as RigidBody2D
		if ob == null:
			continue
		var osz := ob.get_meta("size", Vector2(40, 40)) as Vector2
		if ob.get_meta("kind", "") == "ball":
			draw_circle(ob.position, osz.x / 2.0, Color("b8a888"))
			draw_arc(ob.position, osz.x / 2.0, 0.0, TAU, 24, Color("111111"), 2.0)
		else:
			draw_rect(Rect2(ob.position - osz / 2.0, osz), Color("b8a888"))
			draw_rect(Rect2(ob.position - osz / 2.0, osz), Color("111111"), false, 2.0)
	# 玩家（小恐龙涂鸦）
	if player and is_instance_valid(player):
		var p := player.position
		draw_circle(Vector2(p.x, p.y - 14), 10, Color("66bb6a"))
		draw_circle(Vector2(p.x + 4, p.y - 17), 2.5, Color("1b1b1b"))
		draw_rect(Rect2(p.x - 9, p.y - 4, 18, 22), Color("43a047"))
		draw_line(Vector2(p.x - 6, p.y + 18), Vector2(p.x - 6, p.y + 26), Color("2e7d32"), 3)
		draw_line(Vector2(p.x + 6, p.y + 18), Vector2(p.x + 6, p.y + 26), Color("2e7d32"), 3)
	# 放置物
	for b in placed:
		if not is_instance_valid(b):
			continue
		var w_id: String = b.get_meta("word", "")
		var w_col: Color = Color("e8e4d8")
		for wd in WORDS:
			if wd.id == w_id:
				w_col = wd.col
		var sh_idx := -1
		for k in SHAPES.size():
			if b.name.contains(SHAPES[k].id):
				sh_idx = k
		var sz: Vector2 = SHAPES[maxi(sh_idx, 0)].size
		if w_id == "float":
			draw_rect(Rect2(b.position - sz / 2.0, sz), Color(w_col, 0.85))
			draw_rect(Rect2(b.position - sz / 2.0, sz), Color("111111"), false, 2)
		elif SHAPES[maxi(sh_idx, 0)].kind == "ball":
			draw_circle(b.position, sz.x / 2.0, w_col)
		else:
			draw_rect(Rect2(b.position - sz / 2.0, sz), w_col)
			draw_rect(Rect2(b.position - sz / 2.0, sz), Color("111111"), false, 2)
		# 火焰标记
		if w_id == "fire":
			var fl := 6.0 + 2.0 * sin(pulse * 2.0)
			draw_circle(b.position + Vector2(0, -sz.y / 2.0 - 10), fl, Color("ff9800"))
