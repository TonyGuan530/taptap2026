extends Node2D
## SOUP 2.0：和外星生物 DNA 融合改造自身，逃离危险的异星。
## 横版跑到右侧逃生舱；3 个外星生物各给一种 DNA 能力，
## 地形按顺序强制用能力：高台(跳高) → 长沟(二段跳) → 黑暗裂谷(发光照明)。
## 对应 Miro 玩法块 demo-04。纯代码实现、无外部资源。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")
const GROUND_Y := 470.0
const GOAL_X := 3050.0
const GRAV := 1500.0
const WALK := 260.0
const JUMP_V := 560.0

## DNA 融合源（世界坐标固定）
const ALIENS := [
	{id = "highjump", name = "蹦蹦兽", col = Color("ab47bc"), x = 620.0,
		dna = "弹簧腿 DNA", tip = "普通跳变高跳（按住跳跃键跳得更高）"},
	{id = "double", name = "双翼虫", col = Color("4fc3f7"), x = 1500.0,
		dna = "振翅 DNA", tip = "空中可再跳一次（二段跳）"},
	{id = "glow", name = "灯灯菌", col = Color("ffd54f"), x = 2380.0,
		dna = "荧光 DNA", tip = "身体发光，照亮黑暗裂谷"},
]

## 地形：墙/平台块（x, y, w, h）
const BLOCKS := [
	# 起点地面
	[0, 470, 1000, 70],
	# ① 高台墙（必须高跳翻过，顶 y=290）
	[1000, 290, 60, 250],
	# 中段地面
	[1060, 470, 640, 70],
	# ② 长沟（二段跳才能过去：1180→1560 是沟）
	[1700, 470, 900, 70],
	# ③ 黑暗裂谷区（2340 起天黑，沟 2600→2900 必须有光才敢跳）
	[2600, 470, 900, 70],
	# 逃生舱平台
	[3050, 470, 300, 70],
]
## 裂谷（黑暗段中的坑）
const PIT := Rect2(2600, 540, 300, 200)
const DARK_ZONE := Vector2(2340.0, 3600.0)

var px := 120.0
var py := GROUND_Y - 30.0
var vy := 0.0
var on_floor := false
var jumps_used := 0
var dna := {}                    # id -> true
var face := 1.0
var born_dark := false           # 融合荧光后 permanently 亮
var state := "play"              # play / win
var elapsed := 0.0
var toast := ""
var toast_age := 99.0
var pulse := 0.0
var cam_x := 0.0
var keys := {}


func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "SOUP 2.0 · 融合外星 DNA，逃出异星"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ffd54f"))
	ui.add_child(title)
	var hint := Label.new()
	hint.text = "←/→ 或 A/D 移动 · 空格/W/↑ 跳 · 走近外星生物按 E 融合"
	hint.position = Vector2(16, 38)
	hint.add_theme_font_size_override("font_size", 14)
	ui.add_child(hint)
	var dna_label := Label.new()
	dna_label.name = "DnaLabel"
	dna_label.position = Vector2(16, 62)
	dna_label.add_theme_font_size_override("font_size", 14)
	dna_label.add_theme_color_override("font_color", Color("4fc3f7"))
	ui.add_child(dna_label)
	var esc := Label.new()
	esc.position = Vector2(VIEW.x - 130, 62)
	esc.text = "→ 逃生舱在远方"
	esc.add_theme_font_size_override("font_size", 13)
	ui.add_child(esc)


func _dna_label_text() -> String:
	if dna.is_empty():
		return "DNA：无（找到外星生物，按 E 融合）"
	var parts := []
	for a in ALIENS:
		if dna.has(a.id):
			parts.append(a.dna)
	return "DNA：已融合 " + " + ".join(parts)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		keys[event.keycode] = true
		if event.keycode == KEY_E:
			_try_fuse()
	elif event is InputEventKey and not event.pressed:
		keys[event.keycode] = false


func _try_fuse() -> void:
	for a in ALIENS:
		if not dna.has(a.id) and absf(px - a.x) < 60.0:
			dna[a.id] = true
			toast = "🧬 融合了 %s 的「%s」：%s" % [a.name, a.dna, a.tip]
			toast_age = 0.0
			if a.id == "glow":
				born_dark = true
			var lb := get_tree().root.find_child("DnaLabel", true, false) as Label
			if lb:
				lb.text = _dna_label_text()


func _physics_process(delta: float) -> void:
	pulse += delta * 5.0
	toast_age += delta
	if state != "play":
		return
	elapsed += delta

	var left: bool = keys.get(KEY_LEFT, false) or keys.get(KEY_A, false)
	var right: bool = keys.get(KEY_RIGHT, false) or keys.get(KEY_D, false)
	var jump_pressed: bool = (keys.get(KEY_SPACE, false) or keys.get(KEY_W, false) or keys.get(KEY_UP, false))

	if left:
		face = -1.0
	if right:
		face = 1.0
	px = clamp(px + (float(right) - float(left)) * WALK * delta, 30.0, GOAL_X + 200.0)

	# 跳跃：土狼时间内可跳；有振翅 DNA 空中可再跳一次
	if jump_pressed and on_floor:
		vy = -JUMP_V * (1.45 if dna.has("highjump") else 1.0)
		on_floor = false
		jumps_used = 1
	elif jump_pressed and not on_floor and dna.has("double") and jumps_used < 2:
		vy = -JUMP_V * 0.95
		jumps_used = 2

	# 重力 + 位移
	vy += GRAV * delta
	py += vy * delta

	# 地形碰撞（AABB 简化：先水平后垂直，逐块解析）
	var r := Rect2(px - 14, py - 30, 28, 30)
	on_floor = false
	for b in BLOCKS:
		var br := Rect2(b[0], b[1], b[2], b[3])
		if br.intersects(r):
			# 从上方落到块顶
			var prev_y := py - vy * delta
			if vy >= 0.0 and prev_y - 30 <= br.position.y + 8:
				py = br.position.y
				vy = 0.0
				on_floor = true
				jumps_used = 0
			elif vy < 0.0 and prev_y - 30 >= br.position.y + br.size.y - 8:
				py = br.position.y + br.size.y + 30
				vy = 0.0
			else:
				# 水平推离
				if px < br.position.x + br.size.x / 2:
					px = br.position.x - 14
				else:
					px = br.position.x + br.size.x + 14
	# 沟底死亡 → 重置到沟前
	if py > VIEW.y + 120:
		px = maxf(120.0, (PIT.position.x - 220.0) if px > PIT.position.x else 1100.0)
		py = GROUND_Y - 30.0
		vy = 0.0
		toast = "跌进裂谷……异星的苔藓接住了你（回到沟边）"
		toast_age = 0.0

	# 黑暗区：没有荧光 DNA 时大幅减速（不敢跑）
	born_dark = dna.has("glow")
	if px > DARK_ZONE.x and px < DARK_ZONE.y and not born_dark:
		px -= (float(right) - float(left)) * WALK * 0.55 * delta   # 摸黑只能慢慢挪

	# 到达逃生舱
	if px >= GOAL_X + 40.0 and py <= GROUND_Y + 10.0:
		state = "win"

	# 相机跟随
	cam_x = clamp(px - VIEW.x / 2.0, 0.0, GOAL_X + 300.0 - VIEW.x)
	queue_redraw()


func _draw() -> void:
	var off := -cam_x
	# 天空渐变（越靠近裂谷越暗）
	var base := Color("171226")
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), base)
	# 星星
	for k in 26:
		var sx := fposmod(k * 173.0, 3350.0) - cam_x
		if sx > -10 and sx < VIEW.x + 10:
			var sy := 30.0 + (k * 53) % 200
			draw_circle(Vector2(sx, sy), 1.5, Color(1, 1, 1, 0.35))
	# 远山
	for k in 6:
		var mx := k * 620.0 - cam_x * 0.4
		if mx > -260 and mx < VIEW.x + 260:
			draw_polygon(PackedVector2Array([Vector2(mx, 470), Vector2(mx + 240, 470), Vector2(mx + 120, 320)]), PackedColorArray([Color("241d3a")]))
	# 地形
	for b in BLOCKS:
		var br := Rect2(b[0] + off, b[1], b[2], b[3])
		if br.position.x > VIEW.x + 50 or br.end.x < -50:
			continue
		draw_rect(br, Color("3d3552"))
		draw_rect(br, Color("241f36"), false, 2)
	# 裂谷（黑暗中的坑：无光时几乎是黑的）
	var pit_r := Rect2(PIT.position.x + off, 470, PIT.size.x, 200)
	var dark := not born_dark
	draw_rect(pit_r, Color("050308") if dark else Color("120b1a"))
	# 黑暗区遮罩
	if px > DARK_ZONE.x - 300 and px < DARK_ZONE.y:
		var zone_l := DARK_ZONE.x + off
		draw_rect(Rect2(zone_l, 0, DARK_ZONE.y - DARK_ZONE.x, VIEW.y), Color(0.01, 0.005, 0.02, 0.88 if not born_dark else 0.35))
		# 玩家光圈
		var pl := Vector2(px + off, py - 15)
		if born_dark:
			for radius in [130.0, 90.0, 55.0]:
				draw_circle(pl, radius, Color(1.0, 0.95, 0.6, 0.05))
		else:
			draw_circle(pl, 70.0, Color(1, 1, 1, 0.02))
	# 逃生舱
	var gx := GOAL_X + 80.0 + off
	draw_rect(Rect2(gx - 40, 380, 100, 90), Color("2b3b4d"))
	draw_polygon(PackedVector2Array([Vector2(gx - 50, 380), Vector2(gx + 70, 380), Vector2(gx + 10, 330)]), PackedColorArray([Color("4fc3f7")]))
	draw_rect(Rect2(gx + 2, 420, 26, 50), Color("8de3ff"))
	draw_string(FONT, Vector2(gx - 30, 368), "逃生舱", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("4fc3f7"))
	# 外星生物（脉动）
	for a in ALIENS:
		var ax: float = a.x + off
		if ax < -60 or ax > VIEW.x + 60:
			continue
		var bob := 5.0 * sin(pulse + a.x)
		var ay := 445.0 + bob
		var got: bool = dna.has(a.id)
		var body_col: Color = a.col if not got else Color(a.col, 0.25)
		draw_circle(Vector2(ax, ay - 18), 16, body_col)
		draw_circle(Vector2(ax - 6, ay - 22), 3.5, Color(1, 1, 1, 0.9))
		draw_circle(Vector2(ax + 6, ay - 22), 3.5, Color(1, 1, 1, 0.9))
		draw_line(Vector2(ax - 6, ay - 10), Vector2(ax + 6, ay - 10), Color(0, 0, 0, 0.6), 2)
		# 触须
		draw_line(Vector2(ax - 10, ay - 30), Vector2(ax - 16, ay - 42), body_col, 2)
		draw_line(Vector2(ax + 10, ay - 30), Vector2(ax + 16, ay - 42), body_col, 2)
		var label: String = ("%s · %s" % [a.name, ("已融合" if got else "按 E 融合")]) if (absf(px - a.x) < 60.0 and not got) else a.name
		draw_string(FONT, Vector2(ax - 34, ay + 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c6cddc") if not got else Color("566072"))
	# 玩家（SOUP 小人）
	var pl2 := Vector2(px + off, py - 15)
	draw_circle(Vector2(pl2.x, pl2.y - 12), 10, Color("e8e4d8"))
	draw_circle(Vector2(pl2.x + 3 * face, pl2.y - 14), 2, Color("333"))
	draw_rect(Rect2(pl2.x - 8, pl2.y - 4, 16, 19), Color("7986cb"))
	if born_dark:
		draw_circle(Vector2(pl2.x, pl2.y - 12), 5, Color(1.0, 0.95, 0.6, 0.9))
	# 黑暗遮罩最上层再压一次玩家名字提示
	if state == "play" and elapsed < 5.0:
		draw_string(FONT, Vector2(16, 100), "目标：一路向右，抵达逃生舱。每种地形都需要对应的 DNA 能力。", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffcc80"))
	# toast
	if toast_age < 3.0:
		var a2: float = clamp(3.0 - toast_age, 0.0, 1.0)
		draw_rect(Rect2(VIEW.x / 2 - 300, 110, 600, 34), Color(0, 0, 0, 0.55 * a2))
		draw_string(FONT, Vector2(VIEW.x / 2 - 290, 133), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, a2))
	# 计时
	draw_string(FONT, Vector2(VIEW.x - 90, 28), "%d 秒" % int(elapsed), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e8ecf4"))
	# 胜利结算
	if state == "win":
		draw_rect(Rect2(180, 150, 600, 220), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(180, 150, 600, 220), Color("4fc3f7"), false, 3)
		draw_string(FONT, Vector2(210, 195), "🚀 逃脱成功！", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("4fc3f7"))
		draw_string(FONT, Vector2(210, 240), "用时 %d 秒 · 融合 DNA %d/3 种" % [int(elapsed), dna.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e8ecf4"))
		var names := ""
		for a in ALIENS:
			if dna.has(a.id):
				names += a.name + " "
		draw_string(FONT, Vector2(210, 270), "外星伙伴：" + (names if names != "" else "无（你是怎么飞过来的？！）"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8b94a7"))
		draw_string(FONT, Vector2(210, 310), "刷新页面可再跑一次，试试不融合某个 DNA 会怎样。", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8b94a7"))
