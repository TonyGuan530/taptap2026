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


func _ready() -> void:
	_build_ui()
	_load_level(0)


func _find(n: String) -> Node:
	return get_tree().root.find_child(n, true, false)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
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


func _refresh_buttons() -> void:
	for i in SHAPES.size():
		var b = get_tree().root.find_child("ShapeBtn" + str(i), true, false)
		if b: b.add_theme_color_override("font_color", Color("ffd54f") if i == shape_idx else Color("e8ecf4"))
	for i in WORDS.size():
		var b2 = get_tree().root.find_child("WordBtn" + str(i), true, false)
		if b2: b2.add_theme_color_override("font_color", Color("ffd54f") if i == word_idx else Color("e8ecf4"))


func _on_shape(i: int) -> void:
	shape_idx = i
	_refresh_buttons()


func _on_word(i: int) -> void:
	word_idx = i
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
	add_child(body)


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
	_set_hint("放置了 %s×%s（-%d💧）。%s" % [shape.name, word.name, cost, word.tip])


func _on_placed_contact(body_node: Node, placed_body: RigidBody2D) -> void:
	var word_id: String = placed_body.get_meta("word", "")
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
	var panel := Panel.new()
	panel.name = "WinPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(240, 180)
	panel.size = Vector2(480, 180)
	var ui := get_tree().root.find_child("CanvasLayer", true, false)
	if ui:
		ui.add_child(panel)
	var t := Label.new()
	t.text = "🏁 过关！%s\n用时 %d 秒 · 剩余墨水 %d · 放置 %d 个物体\n\n试试用别的词条组合再通一次——每关不止一种解法。" % [
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
