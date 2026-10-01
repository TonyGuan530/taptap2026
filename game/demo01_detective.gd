extends Control
## 灵感菇侦探 · 第一案「雨夜的失窃」
## 点击犯罪现场里的物品，听它们说话收集证词；集齐后指认真相。
## 纯代码实现、无外部资源；对应 Miro 玩法块 demo-01（叙事涌现 & 线索涌现）。

const VIEW := Vector2(960, 540)
const SCENE_RECT := Rect2(0, 40, 620, 500)

## 现场物品：位置/绘制种类/证词（物品自己说话）
const ITEMS := [
	{
		"id": "clock", "name": "停摆的挂钟", "kind": "clock", "rect": Rect2(455, 90, 90, 90),
		"words": "我停在 11 点 47 分……有人动过我的指针，之后就再没人给我上发条。",
		"clue": "挂钟停在 11:47，指针被人动过",
	},
	{
		"id": "vase", "name": "打翻的花瓶", "kind": "vase", "rect": Rect2(120, 380, 80, 110),
		"words": "主人出门前我可是好好站在柜子边的……有人从窗户翻进来，慌乱里撞了我一下。",
		"clue": "有人从窗户进入室内，碰倒了花瓶",
	},
	{
		"id": "window", "name": "窗台的泥印", "kind": "window", "rect": Rect2(430, 210, 110, 100),
		"words": "半夜有人从外面翻进来，手在我身上撑了一下……你摸摸，泥还没干透。",
		"clue": "窗台有新鲜的泥手印",
	},
	{
		"id": "tea", "name": "半杯冷茶", "kind": "tea", "rect": Rect2(300, 320, 40, 50),
		"words": "他把我泡好就上楼了，一口都没喝……我凉透的时候，窗外正好打过一声闷雷。",
		"clue": "主人 11 点多还在家，之后才离开客厅",
	},
	{
		"id": "foot", "name": "湿脚印", "kind": "foot", "rect": Rect2(220, 460, 90, 45),
		"words": "我从阳台一路走到柜子边，鞋底还带着雨水的味道……对了，我不是主人的形状。",
		"clue": "室内有不属于主人的湿脚印，通向阳台",
	},
]

## 指认环节：真相 = 小偷雨夜从阳台翻入
const QUESTION := "小偷是从哪里进来的？"
const CHOICES := ["从大门大摇大摆进来", "从阳台窗户翻进来", "顺着烟囱爬进来"]
const CORRECT := 1
const ENDING := "雨夜 11 点 47 分，小偷从阳台翻入。他碰倒了花瓶，在窗台留下泥手印，\n却没注意到湿脚印一路出卖了他——而停摆的挂钟，记住了这一切。\n真相只有一个。本案告破！"

var collected := {}          # id -> true
var bubble_text := "（点击现场里发光的物品，听它们说话……）"
var elapsed := 0.0
var accusing := false
var accuse_msg := ""
var solved := false
var blink := 0.0

var clue_labels := {}        # id -> Label
var bubble_label: Label
var accuse_button: Button
var accuse_panel: Control
var end_panel: Control
var end_label: Label


func _ready() -> void:
	custom_minimum_size = VIEW
	size = VIEW
	# 根节点不拦截鼠标，让点击落入 _unhandled_input 做物品命中判定
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	queue_redraw()


func _process(delta: float) -> void:
	blink += delta * 3.0
	if not solved:
		elapsed += delta
	queue_redraw()


# ---------------- UI ----------------

func _build_ui() -> void:
	var title := Label.new()
	title.text = "灵感菇侦探 · 第一案「雨夜的失窃」"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("ffd54f"))
	add_child(title)

	# 线索笔记面板
	var panel := Panel.new()
	panel.position = Vector2(SCENE_RECT.size.x + 10, 40)
	panel.size = Vector2(VIEW.x - SCENE_RECT.size.x - 20, 400)
	add_child(panel)

	var pt := Label.new()
	pt.text = "🍄 线索笔记 0/%d" % ITEMS.size()
	pt.name = "PanelTitle"
	pt.position = Vector2(14, 10)
	pt.add_theme_font_size_override("font_size", 18)
	panel.add_child(pt)

	for i in ITEMS.size():
		var it: Dictionary = ITEMS[i]
		var lb := Label.new()
		lb.text = "%d. ？？？" % (i + 1)
		lb.position = Vector2(14, 44 + i * 66)
		lb.size = Vector2(panel.size.x - 28, 62)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.add_theme_font_size_override("font_size", 13)
		lb.add_theme_color_override("font_color", Color("566072"))
		panel.add_child(lb)
		clue_labels[it.id] = lb

	accuse_button = Button.new()
	accuse_button.text = "指认真相"
	accuse_button.position = Vector2(14, panel.size.y - 56)
	accuse_button.size = Vector2(panel.size.x - 28, 42)
	accuse_button.disabled = true
	accuse_button.pressed.connect(_on_accuse)
	panel.add_child(accuse_button)

	# 物品证词气泡（不拦截鼠标，避免挡住下方的湿脚印）
	var bubble := Panel.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.position = Vector2(10, VIEW.y - 76)
	bubble.size = Vector2(SCENE_RECT.size.x - 20, 66)
	add_child(bubble)
	bubble_label = Label.new()
	bubble_label.text = bubble_text
	bubble_label.position = Vector2(12, 8)
	bubble_label.size = Vector2(bubble.size.x - 24, 52)
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_label.add_theme_font_size_override("font_size", 14)
	bubble.add_child(bubble_label)

	# 指认面板（默认隐藏）
	accuse_panel = Panel.new()
	accuse_panel.position = Vector2(140, 120)
	accuse_panel.size = Vector2(400, 240)
	accuse_panel.visible = false
	add_child(accuse_panel)
	var q := Label.new()
	q.text = QUESTION
	q.position = Vector2(20, 18)
	q.add_theme_font_size_override("font_size", 17)
	accuse_panel.add_child(q)
	for c in CHOICES.size():
		var b := Button.new()
		b.text = CHOICES[c]
		b.position = Vector2(20, 62 + c * 50)
		b.size = Vector2(360, 40)
		b.pressed.connect(_on_choice.bind(c))
		accuse_panel.add_child(b)

	# 结案面板（默认隐藏）
	end_panel = Panel.new()
	end_panel.position = Vector2(110, 90)
	end_panel.size = Vector2(460, 320)
	end_panel.visible = false
	add_child(end_panel)
	var et := Label.new()
	et.text = "🍄 案件还原"
	et.position = Vector2(20, 14)
	et.add_theme_font_size_override("font_size", 20)
	et.add_theme_color_override("font_color", Color("ffd54f"))
	end_panel.add_child(et)
	end_label = Label.new()
	end_label.text = ENDING
	end_label.position = Vector2(20, 56)
	end_label.size = Vector2(420, 190)
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_label.add_theme_font_size_override("font_size", 14)
	end_panel.add_child(end_label)
	var again := Button.new()
	again.text = "再查一遍"
	again.position = Vector2(20, 260)
	again.size = Vector2(180, 40)
	again.pressed.connect(_on_restart)
	end_panel.add_child(again)


# ---------------- 交互 ----------------

func _unhandled_input(event: InputEvent) -> void:
	if solved or accusing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		for it in ITEMS:
			if collected.has(it.id):
				continue
			if (Rect2(it.rect) as Rect2).has_point(pos):
				_collect(it)
				return


func _collect(it: Dictionary) -> void:
	collected[it.id] = true
	bubble_text = "%s：「%s」" % [it.name, it.words]
	bubble_label.text = bubble_text
	var lb: Label = clue_labels[it.id]
	lb.text = "✔ %s" % it.clue
	lb.add_theme_color_override("font_color", Color("c6cddc"))
	var pt := get_tree().current_scene.find_child("PanelTitle", true, false) as Label
	if pt:
		pt.text = "🍄 线索笔记 %d/%d" % [collected.size(), ITEMS.size()]
	if collected.size() == ITEMS.size():
		accuse_button.disabled = false
		accuse_button.text = "指认真相（线索齐了！）"
	queue_redraw()


func _on_accuse() -> void:
	accusing = true
	accuse_msg = ""
	accuse_panel.visible = true
	queue_redraw()


func _on_choice(idx: int) -> void:
	if idx == CORRECT:
		accuse_panel.visible = false
		solved = true
		end_panel.visible = true
		end_label.text = "%s\n\n用时 %d 分 %d 秒" % [ENDING, int(elapsed) / 60, int(elapsed) % 60]
	else:
		accuse_msg = "线索对不上……再看一眼笔记。（选择已重置）"
		var q := accuse_panel.get_child(1) as Label
		q.text = "%s\n%s" % [QUESTION, accuse_msg]
		q.add_theme_color_override("font_color", Color("ef5350"))


func _on_restart() -> void:
	collected.clear()
	bubble_text = "（新的一夜，物品们又开口了……）"
	bubble_label.text = bubble_text
	for id in clue_labels:
		var lb: Label = clue_labels[id]
		lb.text = "%d. ？？？" % (clue_labels.keys().find(id) + 1)
		lb.add_theme_color_override("font_color", Color("566072"))
	var pt := get_tree().current_scene.find_child("PanelTitle", true, false) as Label
	if pt:
		pt.text = "🍄 线索笔记 0/%d" % ITEMS.size()
	accuse_button.disabled = true
	accuse_button.text = "指认真相"
	end_panel.visible = false
	accusing = false
	solved = false
	elapsed = 0.0
	queue_redraw()


# ---------------- 绘制 ----------------

func _draw() -> void:
	_draw_room()
	for it in ITEMS:
		_draw_item(it)
	if accusing and not solved:
		draw_rect(Rect2(VIEW / 2.0 - Vector2(300, 170), Vector2(600, 340)), Color(0, 0, 0, 0.35))


func _draw_room() -> void:
	# 墙与地板
	draw_rect(Rect2(0, 40, SCENE_RECT.size.x, 300), Color("2a3040"))
	draw_rect(Rect2(0, 340, SCENE_RECT.size.x, SCENE_RECT.size.y + 40 - 340), Color("3a3326"))
	draw_line(Vector2(0, 340), Vector2(SCENE_RECT.size.x, 340), Color("1c1f28"), 3)
	# 雨夜窗外
	if ITEMS[2].rect.position.y > 0:
		var wr := Rect2(ITEMS[2].rect)
		draw_rect(wr, Color("141a26"))
		for k in 7:
			var rx := wr.position.x + 12 + k * 14.0
			var off := fmod(blink * 40.0 + k * 30.0, 60.0)
			draw_line(Vector2(rx, wr.position.y + off), Vector2(rx - 6, wr.position.y + off + 16), Color("4a6fa5"), 1.5)
		draw_rect(wr, Color("6b7a94"), false, 3.0)


func _draw_item(it: Dictionary) -> void:
	var r: Rect2 = it.rect
	var got: bool = collected.has(it.id)
	# 收集齐之前未点过的物品带呼吸光圈
	if not got:
		var glow := 0.25 + 0.15 * sin(blink * 2.0)
		draw_rect(r.grow(6), Color(1.0, 0.84, 0.31, glow), false, 3.0)
	match it.kind:
		"clock":
			draw_rect(r, Color("6d4c2f"))
			draw_circle(r.position + r.size / 2.0, r.size.x / 2.0 - 6, Color("e8e4d8"))
			draw_line(r.position + r.size / 2.0, r.position + r.size / 2.0 + Vector2(0, -22), Color("333"), 3)
			draw_line(r.position + r.size / 2.0, r.position + r.size / 2.0 + Vector2(16, 6), Color("333"), 3)
		"vase":
			draw_rect(Rect2(r.position + Vector2(30, -6), Vector2(20, 10)), Color("8d6e63"))  # 散落的花
			draw_circle(r.position + Vector2(24, -2), 6, Color("ef5350"))
			draw_circle(r.position + Vector2(58, -4), 5, Color("ab47bc"))
			draw_polygon(
				PackedVector2Array([r.position + Vector2(10, 20), r.position + Vector2(70, 20), r.position + Vector2(58, r.size.y), r.position + Vector2(22, r.size.y)]),
				PackedColorArray([Color("5c8ec4")]))
			draw_rect(Rect2(r.position + Vector2(28, 60), Vector2(24, r.size.y - 60)), Color("4272a0"))
		"window":
			draw_rect(r, Color("101722"))
			draw_line(r.position + Vector2(r.size.x / 2, 0), r.position + Vector2(r.size.x / 2, r.size.y), Color("6b7a94"), 4)
			draw_line(r.position + Vector2(0, r.size.y / 2), r.position + Vector2(r.size.x, r.size.y / 2), Color("6b7a94"), 4)
			draw_circle(r.position + Vector2(r.size.x / 2, r.size.y - 14), 9, Color("795548"))
		"tea":
			draw_rect(r, Color("bcaaa4"))
			draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 10)), Color("8d6e63"))
			draw_rect(Rect2(r.position + Vector2(6, r.size.y - 8), Vector2(r.size.x - 12, 8)), Color("8d6e63"))
		"foot":
			for k in 3:
				var p := r.position + Vector2(k * 30.0, -k * 8.0)
				_ellipse(Vector2(p.x + 12, p.y + 12), 13, 7, Color("5d6b7a"))
			draw_line(r.position + Vector2(-4, r.size.y), r.position + Vector2(r.size.x + 30, -14), Color("5d6b7a"), 1.0)
	# 名牌
	var name_l: String = it.name
	var fs := 12
	var tw := fs * name_l.length()
	draw_rect(Rect2(r.position.x + r.size.x / 2 - tw / 2.0 - 6, r.position.y + r.size.y + 4, tw + 12, 20), Color(0, 0, 0, 0.55))
	draw_string(get_theme_default_font(), Vector2(r.position.x + r.size.x / 2 - tw / 2.0, r.position.y + r.size.y + 19), name_l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("c6cddc"))


func _ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polygon(pts, PackedColorArray([col]))
