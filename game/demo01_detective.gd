extends Control
## 灵感菇侦探 · 三案件版（demo-01）
## 点击犯罪现场物品听证词，集齐后指认真相；每案独立数据，难度递进。
## 纯代码实现、无外部资源；对应 Miro 玩法块 demo-01（叙事涌现 & 线索涌现）。

const VIEW := Vector2(960, 540)
const SCENE_RECT := Rect2(0, 40, 620, 500)

## 三案件数据：物品(位置/绘制种类/证词/线索) + 指认(问题/选项/正确项) + 结局
const CASES := [
	{
		name = "案件一 · 雨夜的失窃",
		items = [
			{ id = "clock", name = "停摆的挂钟", kind = "clock", rect = Rect2(455, 90, 90, 90),
				words = "我停在 11 点 47 分……有人动过我的指针，之后就再没人给我上发条。",
				clue = "挂钟停在 11:47，指针被人动过" },
			{ id = "vase", name = "打翻的花瓶", kind = "vase", rect = Rect2(120, 380, 80, 110),
				words = "主人出门前我可是好好站在柜子边的……有人从窗户翻进来，慌乱里撞了我一下。",
				clue = "有人从窗户进入室内，碰倒了花瓶" },
			{ id = "papers", name = "翻乱的文件抽屉", kind = "tea", rect = Rect2(120, 210, 40, 50),
				words = "文件被翻得乱七八糟，少了一页房产证复印件……小偷是有备而来的。",
				clue = "文件抽屉被翻动，房产证复印件失踪——窃贼目标明确" },
			{ id = "window", name = "窗台的泥印", kind = "window", rect = Rect2(430, 210, 110, 100),
				words = "半夜有人从外面翻进来，手在我身上撑了一下……你摸摸，泥还没干透。",
				clue = "窗台有新鲜的泥手印" },
			{ id = "tea", name = "半杯冷茶", kind = "tea", rect = Rect2(300, 320, 40, 50),
				words = "他把我泡好就上楼了，一口都没喝……我凉透的时候，窗外正好打过一声闷雷。",
				clue = "主人 11 点多还在家，之后才离开客厅" },
			{ id = "foot", name = "湿脚印", kind = "foot", rect = Rect2(220, 460, 90, 45),
				words = "我从阳台一路走到柜子边，鞋底还带着雨水的味道……对了，我不是主人的形状。",
				clue = "室内有不属于主人的湿脚印，通向阳台" },
		],
		question = "小偷是从哪里进来的？",
		choices = ["从大门大摇大摆进来", "从阳台窗户翻进来", "顺着烟囱爬进来"],
		correct = 1,
		ending = "雨夜 11 点 47 分，小偷从阳台翻入。他碰倒了花瓶，在窗台留下泥手印，\n却没注意到湿脚印一路出卖了他——而停摆的挂钟，记住了这一切。\n真相只有一个。本案告破！",
	},
	{
		name = "案件二 · 办公室的毒咖啡",
		items = [
			{ id = "cup", name = "主人的咖啡杯", kind = "tea", rect = Rect2(300, 320, 40, 50),
				words = "毒在我身体里……但从吧台到桌面，我一直在主人手里，谁也没靠近过。",
				clue = "毒不是在路上下的——杯子从未离开主人" },
			{ id = "cooler", name = "饮水机", kind = "vase", rect = Rect2(430, 210, 110, 100),
				words = "今天的水有股苦味……一个小时前，有人换过我的滤芯。我看得清清楚楚，是那孩子。",
				clue = "饮水机滤芯一小时前被人换过" },
			{ id = "bin", name = "垃圾桶", kind = "vase", rect = Rect2(120, 380, 80, 110),
				words = "主人的杯子摔碎前，有人从我这里拿走了那只备用杯……我见过那只杯子，是新的。",
				clue = "有人从垃圾桶拿走了备用杯" },
			{ id = "printer", name = "打印机便签", kind = "window", rect = Rect2(455, 90, 90, 90),
				words = "19:00 的会议改到 21:00……这张通知是有人后来才放进我的托盘的，纸还带着打印机的余温。",
				clue = "会议改期的通知是伪造的，为了让主管独自留下" },
			{ id = "badge", name = "门禁记录", kind = "foot", rect = Rect2(220, 460, 90, 45),
				words = "19:05 之后，整层楼只有一张门禁卡刷过我……那张卡的主人是助理。",
				clue = "19:05 后只有助理刷门禁进入过本层" },
		],
		question = "毒是谁下的？",
		choices = ["保洁阿姨（换滤芯时下的）", "实习生（倒咖啡时下的）", "助理（换滤芯+伪造会议，预谋投毒）"],
		correct = 2,
		ending = "真相是助理的预谋：提前在饮水机滤芯下毒，再用伪造的会议通知让主管独自留下。\n主管用自己的备用杯喝了那杯咖啡——从始至终，凶手都没碰过那只杯子。\n铁证如山。本案告破！",
	},
	{
		name = "案件三 · 阁楼上的遗嘱",
		items = [
			{ id = "watch", name = "管家的怀表", kind = "clock", rect = Rect2(455, 90, 90, 90),
				words = "我停在老爷被发现的那一刻……从那晚起，就再没人给我上过发条。",
				clue = "怀表停在老爷被发现的时间" },
			{ id = "urn", name = "灰烬盆", kind = "vase", rect = Rect2(120, 380, 80, 110),
				words = "盆底有一角没烧尽的信纸……上面的日期，正是老爷立新遗嘱的日子。",
				clue = "灰烬里有烧毁的新遗嘱残片" },
			{ id = "glasses", name = "老花镜", kind = "window", rect = Rect2(430, 210, 110, 100),
				words = "老爷看东西从来不离身……我就掉在保险箱前面，说明他最后在这里读过什么。",
				clue = "老花镜遗落在保险箱前" },
			{ id = "drawer", name = "上锁的抽屉", kind = "tea", rect = Rect2(300, 320, 40, 50),
				words = "我是锁着的，钥匙在老爷身上……我的锁完好无损，谁也没能打开我。",
				clue = "抽屉锁完好——遗嘱不在抽屉里" },
			{ id = "note", name = "老爷的留言条", kind = "tea", rect = Rect2(300, 240, 40, 50),
				words = "老爷最后一晚的留言：明早九点和律师通电话。字迹慌乱，力透纸背。",
				clue = "老爷临终前约了律师通话——管家无从抵赖" },
			{ id = "safe", name = "老式保险箱", kind = "foot", rect = Rect2(220, 460, 90, 45),
				words = "我的密码是老爷的结婚纪念日……可那天，全宅只有管家知道这个日子。",
				clue = "保险箱密码只有管家知道" },
		],
		question = "新遗嘱是怎么消失的？",
		choices = ["律师卷走了遗嘱", "管家烧毁并伪造了遗嘱", "侄子偷走藏了起来"],
		correct = 1,
		ending = "真相：管家知道老主人改了遗嘱，便在阁楼上烧毁原件，灰烬里的残片暴露了日期。\n他以为抽屉的锁和保险箱能掩盖一切——却忘了自己的怀表，停在老爷被发现的那一刻。\n天网恢恢。本案告破！",
	},
	{
		name = "案件四 · 雪夜的失踪",
		items = [
			{ id = "door", name = "反锁的书房门", kind = "window", rect = Rect2(430, 210, 110, 100),
				words = "我从里面反锁，钥匙还插在锁孔上……整晚没有人从我这里进来或出去。",
				clue = "书房门从内反锁——外人无法进出" },
			{ id = "locker", name = "玄关鞋柜", kind = "vase", rect = Rect2(120, 380, 80, 110),
				words = "她的那双雪靴昨夜还在我这里……今早，我不见了那双靴子。",
				clue = "妻子的雪靴失踪了" },
			{ id = "tracks", name = "窗外的雪地脚印", kind = "foot", rect = Rect2(220, 460, 90, 45),
				words = "一行脚印从窗台下笔直走向林子……步幅平稳，不慌不忙，是个清醒的人。",
				clue = "雪地脚印步幅平稳——出走者是清醒的" },
			{ id = "fireplace", name = "熄灭的壁炉", kind = "clock", rect = Rect2(455, 90, 90, 90),
				words = "我的余烬里有一角烧焦的睡袍……粉色的，绣着主人的名字。",
				clue = "壁炉里有烧毁的睡袍纤维" },
			{ id = "pills", name = "半瓶安眠药", kind = "tea", rect = Rect2(300, 320, 40, 50),
				words = "主人睡前常拿我里的药……昨晚，我少了几颗。",
				clue = "安眠药少了几颗" },
			{ id = "milk", name = "床头的牛奶杯", kind = "tea", rect = Rect2(300, 240, 40, 50),
				words = "昨夜她喝下了我……然后睡得很沉很沉，沉到听不见开门声。",
				clue = "妻子昨夜服药后沉睡" },
		],
		question = "妻子是怎么失踪的？",
		choices = ["被陌生人破门绑走", "自己服药假睡，换装后从窗户离开", "被野兽袭击拖进了林子"],
		correct = 1,
		ending = "真相：没有绑匪，也没有野兽。妻子服下安眠药假睡，深夜换上雪靴、烧掉睡袍制造错觉，\n从窗户走进了暴雪——反锁的门是她留给世界的谜题。\n一场自导自演的失踪。本案告破！",
	},
]

var ITEMS := []
var QUESTION := ""
var CHOICES := []
var CORRECT := 0
var ENDING := ""

var case_idx := 0
var state := "select"         # select / play
var collected := {}           # id -> true
var bubble_text := "（点击现场里发光的物品，听它们说话……）"
var elapsed := 0.0
var accusing := false
var solved := false
var blink := 0.0

var clue_labels := {}         # id -> Label
var bubble_label: Label
var accuse_button: Button
var accuse_panel: Control
var end_panel: Control
var end_label: Label
var select_panel: Control


func _ready() -> void:
	custom_minimum_size = VIEW
	size = VIEW
	# 根节点不拦截鼠标，让点击落入 _unhandled_input 做物品命中判定
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_show_select()
	queue_redraw()


func _show_select() -> void:
	state = "select"
	select_panel.visible = true


func _process(delta: float) -> void:
	blink += delta * 3.0
	if state == "play" and not solved:
		elapsed += delta
	queue_redraw()


# ---------------- UI 构建 ----------------

func _build_ui() -> void:
	var title := Label.new()
	title.text = "灵感菇侦探"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("ffd54f"))
	add_child(title)

	# 线索笔记面板
	var panel := Panel.new()
	panel.name = "CluePanel"
	panel.position = Vector2(SCENE_RECT.size.x + 10, 40)
	panel.size = Vector2(VIEW.x - SCENE_RECT.size.x - 20, 400)
	add_child(panel)

	accuse_button = Button.new()
	accuse_button.text = "指认真相"
	accuse_button.position = Vector2(14, panel.size.y - 56)
	accuse_button.size = Vector2(panel.size.x - 28, 42)
	accuse_button.disabled = true
	accuse_button.pressed.connect(_on_accuse)
	panel.add_child(accuse_button)

	# 物品证词气泡（不拦截鼠标，避免挡住下方的湿脚印）
	var bubble := Panel.new()
	bubble.name = "Bubble"
	bubble.position = Vector2(10, VIEW.y - 76)
	bubble.size = Vector2(SCENE_RECT.size.x - 20, 66)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	accuse_panel.name = "AccusePanel"
	accuse_panel.position = Vector2(140, 120)
	accuse_panel.size = Vector2(400, 240)
	accuse_panel.visible = false
	add_child(accuse_panel)

	# 结案面板（默认隐藏）
	end_panel = Panel.new()
	end_panel.name = "EndPanel"
	end_panel.position = Vector2(140, 120)
	end_panel.size = Vector2(400, 240)
	end_panel.visible = false
	add_child(end_panel)
	end_label = Label.new()
	end_label.name = "EndLabel"
	end_label.position = Vector2(16, 16)
	end_label.size = Vector2(368, 160)
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_label.add_theme_font_size_override("font_size", 14)
	end_panel.add_child(end_label)

	# 案件选择屏（默认可见）
	select_panel = Panel.new()
	select_panel.name = "SelectPanel"
	select_panel.position = Vector2(170, 110)
	select_panel.size = Vector2(440, 280)
	add_child(select_panel)
	var st := Label.new()
	st.text = "🍄 选择案件"
	st.position = Vector2(20, 14)
	st.add_theme_font_size_override("font_size", 20)
	st.add_theme_color_override("font_color", Color("ffd54f"))
	select_panel.add_child(st)
	for i in CASES.size():
		var b := Button.new()
		b.text = CASES[i].name
		b.position = Vector2(20, 56 + i * 56)
		b.size = Vector2(400, 44)
		b.pressed.connect(_start_case.bind(i))
		select_panel.add_child(b)


# ---------------- 案件流程 ----------------

func _start_case(idx: int) -> void:
	case_idx = idx
	var c: Dictionary = CASES[idx]
	ITEMS = c.items
	QUESTION = c.question
	CHOICES = c.choices
	CORRECT = c.correct
	ENDING = c.ending
	collected = {}
	bubble_text = "（点击现场里发光的物品，听它们说话……）"
	elapsed = 0.0
	accusing = false
	solved = false
	state = "play"

	select_panel.visible = false
	end_panel.visible = false
	accuse_panel.visible = false

	var title = get_tree().root.find_child("Title", true, false)
	if title:
		title.text = "灵感菇侦探 · " + c.name

	# 重建线索笔记（清掉上一案的）
	var panel = get_tree().root.find_child("CluePanel", true, false)
	clue_labels.clear()
	if panel:
		for ch in panel.get_children():
			if ch is Label:
				ch.queue_free()
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
	queue_redraw()


func _on_accuse() -> void:
	accusing = true
	accuse_panel.visible = true
	# 重建指认选项
	for c in accuse_panel.get_children():
		c.queue_free()
	var q := Label.new()
	q.name = "QLabel"
	q.text = QUESTION
	q.position = Vector2(20, 18)
	q.add_theme_font_size_override("font_size", 16)
	accuse_panel.add_child(q)
	for ci in CHOICES.size():
		var b := Button.new()
		b.text = CHOICES[ci]
		b.position = Vector2(20, 62 + ci * 44)
		b.size = Vector2(360, 38)
		b.pressed.connect(_on_choice.bind(ci))
		accuse_panel.add_child(b)
	queue_redraw()


func _on_choice(ci: int) -> void:
	if ci == CORRECT:
		accuse_panel.visible = false
		solved = true
		end_panel.visible = true
		end_label.text = ENDING + "

—— 本局用时 %d 分 %d 秒 ——" % [int(elapsed) / 60, int(elapsed) % 60]
	else:
		var q = get_tree().root.find_child("QLabel", true, false)
		if q:
			q.text = QUESTION + "\n证词对不上……再读一遍线索笔记。（可重新指认）"


# ---------------- 交互 ----------------

func _unhandled_input(event: InputEvent) -> void:
	if state != "play" or accusing or solved:
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
	if clue_labels.has(it.id):
		var lb: Label = clue_labels[it.id]
		lb.text = "✔ " + it.clue
		lb.add_theme_color_override("font_color", Color("c6cddc"))
	var panel = get_tree().root.find_child("CluePanel", true, false)
	if panel:
		var pt = panel.find_child("PanelTitle", true, false)
		if pt:
			pt.text = "🍄 线索笔记 %d/%d" % [collected.size(), ITEMS.size()]
	if collected.size() == ITEMS.size():
		accuse_button.disabled = false
		accuse_button.text = "指认真相"
	queue_redraw()


# ---------------- 绘制 ----------------

func _draw() -> void:
	if state == "select":
		draw_rect(SCENE_RECT, Color("1b2030"))
		return
	draw_rect(SCENE_RECT, Color("232833"))
	draw_rect(Rect2(SCENE_RECT.position, Vector2(SCENE_RECT.size.x, 300)), Color("2a3040"))
	draw_line(Vector2(SCENE_RECT.position.x, 340), Vector2(SCENE_RECT.position.x + SCENE_RECT.size.x, 340), Color("1c1f28"), 3)
	draw_rect(Rect2(430, 210, 110, 100), Color("141a26"))
	draw_rect(Rect2(430, 210, 110, 100), Color("6b7a94"), false, 3)
	for it in ITEMS:
		_draw_item(it)
	if accusing and not solved:
		draw_rect(Rect2(VIEW / 2.0 - Vector2(300, 170), Vector2(600, 340)), Color(0, 0, 0, 0.35))


func _draw_item(it: Dictionary) -> void:
	var r: Rect2 = it.rect
	var got: bool = collected.has(it.id)
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
			draw_polygon(
				PackedVector2Array([r.position + Vector2(10, 20), r.position + Vector2(70, 20), r.position + Vector2(58, r.size.y), r.position + Vector2(22, r.size.y)]),
				PackedColorArray([Color("5c8ec4")]))
			draw_rect(Rect2(r.position + Vector2(28, 60), Vector2(24, r.size.y - 60)), Color("4272a0"))
		"window":
			draw_rect(r, Color("101722"))
			draw_line(r.position + Vector2(r.size.x / 2, 0), r.position + Vector2(r.size.x / 2, r.size.y), Color("6b7a94"), 4)
			draw_line(r.position + Vector2(0, r.size.y / 2), r.position + Vector2(r.size.x, r.size.y / 2), Color("6b7a94"), 4)
		"tea":
			draw_rect(r, Color("bcaaa4"))
			draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 10)), Color("8d6e63"))
		"foot":
			for k in 3:
				_draw_ellipse(r.position + Vector2(18 + k * 26, r.size.y / 2 + 8 - k * 10), 13, 7, Color("5d6b7a"))
	# 名牌
	var fs := 12
	var tw: float = fs * it.name.length()
	draw_rect(Rect2(r.position.x + r.size.x / 2 - tw / 2.0 - 6, r.position.y + r.size.y + 4, tw + 12, 20), Color(0, 0, 0, 0.55))
	draw_string(get_theme_default_font(), Vector2(r.position.x + r.size.x / 2 - tw / 2.0, r.position.y + r.size.y + 19), it.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("c6cddc"))


func _draw_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polygon(pts, PackedColorArray([col]))
