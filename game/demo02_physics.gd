extends Node2D
## 物性变换谜题：给小球换"词条"，物理行为随之改变，借此解谜。
## 羽毛=超轻慢飘 / 石头=重物高速坠落 / 皮球=高弹性。对应 Miro 玩法块 demo-02。
## v3：新增跳跃输入系统（空格跳 / 羽毛空中扑翼 / ←→ 空中横移，力度按词条区分），
##   并加第三关「组合测试房」：弹簧起飞 → 空中切羽毛横漂 → 切石头砸穿舱门，一条链用满三词条。
## 纯代码实现、无外部资源；真·物理引擎（RigidBody2D）驱动，词条切换实时生效。

const VIEW := Vector2(960, 540)
const BALL_R := 16.0
const FRAGILE_SPEED := 450.0   # 脆墙被砸碎所需的最低撞击速度（纯物理判定，与词条无关）
const FLAP_CD := 0.5           # 羽毛空中扑翼冷却（秒）

const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")

## 词条定义（jump=起跳速度 / flap=空中扑翼速度(0=不能扑) / air_a=横移加速度 / air_vmax=横移限速）
const TAGS := [
	{id = "feather", name = "羽毛", col = Color("e8e4d8"), g = 0.18, damp = 1.2, bounce = 0.2,
		jump = 300.0, flap = -280.0, air_a = 420.0, air_vmax = 300.0,
		tip = "轻飘飘，慢飘+空中可扑翼横移"},
	{id = "stone", name = "石头", col = Color("8d8d94"), g = 2.4, damp = 0.0, bounce = 0.08,
		jump = 240.0, flap = 0.0, air_a = 90.0, air_vmax = 160.0,
		tip = "又重又快，砸什么都碎，几乎横移不动"},
	{id = "ball", name = "皮球", col = Color("ef5350"), g = 1.0, damp = 0.0, bounce = 0.86,
		jump = 520.0, flap = 0.0, air_a = 240.0, air_vmax = 380.0,
		tip = "弹！跳得最高，横移灵活"},
]

## 关卡：walls 静态块 / spring 弹簧区 / fragile 脆墙 / goal 目标区 / spawn 出生点
const LEVELS := [
	{
		name = "第一关 · 过高墙",
		walls = [
			Rect2(-40, -300, 1040, 260),        # 天花板
			Rect2(-40, 0, 40, 540),             # 左墙
			Rect2(960, 0, 40, 540),             # 右墙
			Rect2(0, 470, 430, 70),             # 左地面
			Rect2(470, 470, 490, 70),           # 右地面
			Rect2(430, 240, 40, 230),           # 高墙（要飞过去）
		],
		spring = Rect2(260, 440, 100, 30),
		spring_impulse = Vector2(300, -850),
		fragile = Rect2(),
		goal = Rect2(660, 380, 240, 90),
		spawn = Vector2(310, 60),
		solution = "皮球",
	},
	{
		name = "第二关 · 破障落台",
		walls = [
			Rect2(-40, -300, 1040, 260),
			Rect2(-40, 0, 40, 540),
			Rect2(960, 0, 40, 540),
			Rect2(0, 300, 200, 240),            # 左侧小高台（装饰性地形）
			Rect2(0, 470, 960, 70),             # 底部地面
		],
		spring = Rect2(),
		spring_impulse = Vector2(),
		fragile = Rect2(390, 260, 40, 210),     # 脆墙立柱（高速砸碎）
		goal = Rect2(350, 400, 160, 70),        # 脆墙正下方 = 目标区
		spawn = Vector2(410, 40),               # 出生点正对脆墙顶
		solution = "石头",
	},
	{
		name = "第三关 · 组合测试房",
		walls = [
			Rect2(-40, -300, 1040, 260),        # 天花板
			Rect2(-40, 0, 40, 540),             # 左墙
			Rect2(960, 0, 40, 540),             # 右墙
			Rect2(0, 470, 350, 70),             # 左发射台（右侧是深坑）
			Rect2(620, 240, 40, 230),           # 舱室左壁
			Rect2(470, 340, 40, 130),           # 坑中石柱（垫脚/障碍）
		],
		spring = Rect2(150, 440, 100, 30),      # 弹簧：原地高高起飞（冲量需抵消羽毛的空气阻尼）
		spring_impulse = Vector2(260, -660),
		fragile = Rect2(660, 240, 300, 30),     # 舱室脆天花板：只能从正上方砸穿进入
		goal = Rect2(680, 430, 270, 40),        # 舱底整条 = 目标区（砸穿即落在上面）
		spawn = Vector2(200, 60),
		solution = "弹簧 → 羽毛横漂 → 石头砸舱门",
	},

]

var level_idx := 0
var tag_idx := 0
var ball: RigidBody2D
var tag_buttons := []
var msg_label: Label
var level_label: Label
var next_b: Button
var hint := ""
var stuck_time := 0.0
var spring_ready := true
var goal_reached := false
var elapsed := 0.0
var flap_cd := 0.0            # 羽毛扑翼冷却
var ground_ray: RayCast2D     # 球脚下的接地检测（跳跃用）


func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "物性变换谜题 · 给球换个词条，物理就变了"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ffd54f"))
	ui.add_child(title)

	for i in TAGS.size():
		var b := Button.new()
		b.text = TAGS[i].name
		b.position = Vector2(540 + i * 108, 6)
		b.size = Vector2(100, 36)
		b.focus_mode = Control.FOCUS_NONE   # 别抢空格键：空格留给跳跃
		b.pressed.connect(_on_tag.bind(i))
		ui.add_child(b)
		tag_buttons.append(b)

	var reset_b := Button.new()
	reset_b.text = "重置"
	reset_b.position = Vector2(866, 6)
	reset_b.size = Vector2(80, 36)
	reset_b.focus_mode = Control.FOCUS_NONE
	reset_b.pressed.connect(func() -> void: _reset_ball(true))
	ui.add_child(reset_b)

	# 关卡切换：通关前禁用，通关后可点（评审反馈：第二关缺入口）
	next_b = Button.new()
	next_b.text = "下一关"
	next_b.position = Vector2(866, 50)
	next_b.size = Vector2(80, 36)
	next_b.disabled = true
	next_b.focus_mode = Control.FOCUS_NONE
	next_b.pressed.connect(_next_level)
	ui.add_child(next_b)

	msg_label = Label.new()
	msg_label.position = Vector2(16, VIEW.y - 32)
	msg_label.size = Vector2(VIEW.x - 32, 28)
	msg_label.add_theme_font_size_override("font_size", 15)
	ui.add_child(msg_label)

	level_label = Label.new()
	level_label.position = Vector2(16, 42)
	level_label.add_theme_font_size_override("font_size", 15)
	ui.add_child(level_label)

	_load_level(0)
	_refresh_tag_buttons()


# ---------------- 词条 ----------------

func _on_tag(i: int) -> void:
	tag_idx = i
	_apply_tag()
	_refresh_tag_buttons()
	hint = "词条 → %s：%s（切换是实时的，球正在飞也能换）" % [TAGS[i].name, TAGS[i].tip]


func _apply_tag() -> void:
	if ball == null:
		return
	var t: Dictionary = TAGS[tag_idx]
	ball.gravity_scale = t.g
	ball.linear_damp = t.damp
	var pm := PhysicsMaterial.new()
	pm.bounce = t.bounce
	pm.friction = 0.6
	ball.physics_material_override = pm
	# 词条切换必须立刻可见：禁止休眠并唤醒当前球
	ball.can_sleep = false
	ball.sleeping = false


func _refresh_tag_buttons() -> void:
	for i in tag_buttons.size():
		tag_buttons[i].add_theme_color_override("font_color", Color("ffd54f") if i == tag_idx else Color("e8ecf4"))


# ---------------- 关卡 ----------------

func _load_level(idx: int) -> void:
	level_idx = idx
	var lv: Dictionary = LEVELS[idx]
	goal_reached = false
	spring_ready = true
	stuck_time = 0.0
	elapsed = 0.0
	for c in get_children():
		if c is RigidBody2D or c is StaticBody2D or c is Area2D:
			c.queue_free()
	for w in lv.walls:
		_add_static(w)
	if lv.fragile.size.x > 0:
		_add_fragile(lv.fragile)
	_spawn_ball(lv.spawn)
	_apply_tag()
	level_label.text = "%s　　参考解法：%s" % [lv.name, lv.solution]
	hint = "空格=跳（羽毛可空中扑翼） ←→=横移｜点词条实时改变物理，把球送进金色 GOAL 区！"
	_refresh_next_button()
	queue_redraw()


func _add_static(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = r.position + r.size / 2.0
	body.set_meta("rect", r)
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	body.add_child(cs)
	add_child(body)


func _add_fragile(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = r.position + r.size / 2.0
	body.name = "FragileWall"
	body.set_meta("rect", r)
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	body.add_child(cs)
	add_child(body)


func _spawn_ball(pos: Vector2) -> void:
	ball = RigidBody2D.new()
	ball.position = pos
	ball.contact_monitor = true
	ball.max_contacts_reported = 6
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = BALL_R
	cs.shape = sh
	ball.add_child(cs)
	ground_ray = RayCast2D.new()
	ground_ray.target_position = Vector2(0, BALL_R + 6.0)   # 稍长于半径：留出接地容差
	ball.add_child(ground_ray)
	ball.body_entered.connect(_on_ball_hit)
	add_child(ball)


var prev_speed := 0.0   # 上一物理帧球速（撞击判定用，body_entered 里读到的已是求解后速度）


func _on_ball_hit(other: Node) -> void:
	var lv: Dictionary = LEVELS[level_idx]
	if lv.fragile.size.x > 0 and other.name == "FragileWall" and ball != null:
		# 纯物理判定：撞击速度够快就碎（石头自然砸得碎；皮球/羽毛物理上做不到）
		if prev_speed >= FRAGILE_SPEED:
			other.queue_free()
			hint = "轰！高速撞击——脆墙碎了！"
		else:
			hint = "这次撞得太轻，脆墙纹丝不动……"


func _reset_ball(keep_time := false) -> void:
	if ball != null:
		ball.queue_free()
	var lv: Dictionary = LEVELS[level_idx]
	_spawn_ball(lv.spawn)
	_apply_tag()
	goal_reached = false
	spring_ready = true
	stuck_time = 0.0
	flap_cd = 0.0


## v3 输入系统：空格=跳（羽毛空中还能扑翼） / ←→=横移（力度按词条区分）。
## 跳跃只在校地时允许；横移全程可用（空中漂移是第三关的核心操作）。
func _apply_input(delta: float, _lv: Dictionary) -> void:
	var t: Dictionary = TAGS[tag_idx]

	if Input.is_action_just_pressed("ui_accept"):
		_try_jump()

	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		var vx: float = ball.linear_velocity.x + dir * t.air_a * delta
		if dir > 0.0:
			vx = minf(vx, t.air_vmax)
		else:
			vx = maxf(vx, -t.air_vmax)
		ball.linear_velocity.x = vx


## 跳跃：校地起跳；羽毛在空中可扑翼（冷却限制），其余词条空中无跳。
func _try_jump() -> void:
	var t: Dictionary = TAGS[tag_idx]
	var grounded: bool = ground_ray != null and ground_ray.is_colliding()
	if grounded:
		ball.linear_velocity.y = -t.jump
	elif t.flap != 0.0 and flap_cd <= 0.0:
		ball.linear_velocity.y = minf(ball.linear_velocity.y, t.flap)
		flap_cd = FLAP_CD


func _next_level() -> void:
	if level_idx + 1 < LEVELS.size():
		_load_level(level_idx + 1)
	else:
		_load_level(0)   # 已到最后一关：从头再来


func _refresh_next_button() -> void:
	## 通关前禁用「下一关」，通关后启用；最后一关通关后变为「从头再来」
	var has_next := level_idx + 1 < LEVELS.size()
	if goal_reached:
		next_b.disabled = false
		next_b.text = "下一关" if has_next else "从头再来"
	else:
		next_b.disabled = true
		next_b.text = "下一关"


# ---------------- 每帧 ----------------

func _physics_process(delta: float) -> void:
	if ball == null or goal_reached:
		return
	var lv: Dictionary = LEVELS[level_idx]
	elapsed += delta
	prev_speed = ball.linear_velocity.length()
	flap_cd = maxf(0.0, flap_cd - delta)

	_apply_input(delta, lv)

	# 弹簧区：进入给一次固定冲量
	if lv.spring.size.x > 0 and spring_ready and (Rect2(lv.spring) as Rect2).has_point(ball.position):
		ball.linear_velocity = lv.spring_impulse
		spring_ready = false

	# 目标区
	if (Rect2(lv.goal) as Rect2).has_point(ball.position):
		goal_reached = true
		if level_idx + 1 < LEVELS.size():
			msg_label.text = "✔ 通关！用时 %d 秒 —— 点右上「下一关」继续挑战。" % int(elapsed)
		else:
			msg_label.text = "✔ 全部通关！用时 %d 秒 —— 点「从头再来」重温全部 %d 关。" % [int(elapsed), LEVELS.size()]
		_refresh_next_button()
		return

	# 失败：球几乎停住且不在目标区 / 飞出屏幕
	if ball.linear_velocity.length() < 20.0:
		stuck_time += delta
	else:
		stuck_time = 0.0
	if stuck_time > 2.0 or ball.position.y > VIEW.y + 80 or ball.position.y < -300:
		msg_label.text = "❌ %s 干不成这件事……换个词条试试（已自动重置）" % TAGS[tag_idx].name
		stuck_time = -2.0
		_reset_ball(true)


# ---------------- 绘制 ----------------

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var lv: Dictionary = LEVELS[level_idx]
	for c in get_children():
		if c is StaticBody2D and c.has_meta("rect"):
			var r: Rect2 = c.get_meta("rect")
			draw_rect(r, Color("39415a"))
			draw_rect(r, Color("1c2030"), false, 2)
	# 弹簧区（黄黑条纹）
	if lv.spring.size.x > 0:
		var sp: Rect2 = lv.spring
		for k in int(sp.size.x / 16):
			draw_rect(Rect2(sp.position.x + k * 16, sp.position.y, 8, sp.size.y), Color("ffd54f") if k % 2 == 0 else Color("333333"))
	# 脆墙（带裂纹的绿，碎了只剩描边）
	if lv.fragile.size.x > 0:
		var fr: Rect2 = lv.fragile
		var alive := is_instance_valid(get_node_or_null("FragileWall"))
		if alive:
			draw_rect(fr, Color("6a8f5a"))
			draw_line(fr.position, fr.position + fr.size, Color("43633a"), 2)
		else:
			draw_rect(fr, Color("6a8f5a"), false, 2)
	# 目标区
	var g: Rect2 = lv.goal
	draw_rect(g, Color(1.0, 0.84, 0.31, 0.15))
	draw_rect(g, Color("ffd54f"), false, 3)
	draw_string(FONT, g.position + Vector2(8, 24), "GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffd54f"))
	# 球
	if ball != null and is_instance_valid(ball):
		var t: Dictionary = TAGS[tag_idx]
		draw_circle(ball.position, BALL_R, t.col)
		draw_circle(ball.position + Vector2(-5, -5), 4, Color(1, 1, 1, 0.5))
	# 提示行
	if hint != "":
		draw_string(FONT, Vector2(16, VIEW.y - 44), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8b94a7"))
