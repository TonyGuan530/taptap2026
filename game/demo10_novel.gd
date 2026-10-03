extends Control
## 修改小说（demo-10 v1）：编辑即玩法的小说修改部。
## 核心循环：每章一段文稿，文中若干高亮「词槽」；点击词槽从 2~3 个候选中替换，
## 候选带隐性标签（基调增减 / 旗标 / 伏笔 / 地点冲突 / 陷阱改稿），替换实时改写隐藏的故事状态；
## 后续章节正文与候选按此前状态动态拼装——前几章的编辑决定后面读到的故事。
## 状态：三条基调（科幻 / 温情 / 悬疑，-3..+3）+ 旗标集合（身份/地点/关键道具/伏笔…）；
## 第 3 章起有「矛盾检测」：与既有旗标冲突的改写会引来读者来信抗议并扣对应基调 1 点；
## 第 4 章出现「越改越偏」陷阱候选（+2 高收益，但强设旗标并记一次抗议）；
## 每章目标达标可交稿过章，未达则「退稿重改」（可一键回滚到本章开始时的快照）；
## 第 5 章结局完全由状态拼装：最高基调选终稿模板 + 旗标插值，达标即「过审出版」。
## 纯代码 UI、CHAPTERS 常量表驱动、无外部素材（RichTextLabel 纯文字排版）。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")

## 旗标显示名（未列出的键原样显示）
const FLAG_NAMES := {role = "身份", place = "地点", prop = "关键道具", case = "伏笔", note = "细节", forced = "强设"}

## 三条基调的绘制定义：键 / 名 / 色
const TONE_DEFS := [
	{key = "sci", label = "科幻", col = Color("7fd4ff")},
	{key = "warm", label = "温情", col = Color("ffb3a7")},
	{key = "susp", label = "悬疑", col = Color("cfa8ff")},
]

## 第 2 章呼应槽：候选列表随第 1 章旗标（身份）变化——状态化候选的演示
const ECHO_OPTIONS := [
	{role = "侦探", options = [
		{text = "井绳上有新的磨痕", effects = {susp = 1}},
		{text = "我要重查三年前的卷宗编号", effects = {susp = 1, flag_case = "旧卷宗"}},
	]},
	{role = "记者", options = [
		{text = "有人在悄悄撤下当年的报道", effects = {susp = 1}},
		{text = "那篇报道当年被紧急撤稿", effects = {susp = 1, flag_case = "被撤的报道"}},
	]},
	{role = "宇航员", options = [
		{text = "舱外的温度读数在说谎", effects = {sci = 1}},
		{text = "导航日志被人改写过", effects = {sci = 1, flag_case = "被改的日志"}},
	]},
	{role = "", options = [
		{text = "有人在暗处盯着我", effects = {susp = 1}},
	]},
]

## 五章内容表：goal 判定 + tip 目标文案 + body 正文（{i}=词槽占位）+ slots 词槽定义
## 词槽候选 effects：sci/warm/susp=基调增减（会 clamp 到 -3..+3）；flag_X=设置旗标；
## conflict={flag,value,tone}=与既有旗标冲突则记抗议并扣 tone 1 点；trap=越改越偏陷阱（记抗议）
const CHAPTERS := [
	{
		name = "第 1 章 · 开头", goal = {kind = "any"},
		tip = "教学：任选候选改完全部词槽即可交稿",
		body = "我叫{0}，回来是因为那封信。三年前我离开{1}，从此再没回去过。直到上个月，我的信箱里出现了{2}——背面写着一行字：他还活着。",
		slots = [
			{original = "林晚", options = [
				{text = "林晚，一个侦探", effects = {susp = 1, flag_role = "侦探"}},
				{text = "林晚，一个记者", effects = {flag_role = "记者"}},
				{text = "林晚，一个宇航员", effects = {sci = 1, flag_role = "宇航员"}},
			]},
			{original = "老家", options = [
				{text = "多雨的南方小镇", effects = {flag_place = "小镇"}},
				{text = "外婆家所在的海边小镇", effects = {warm = 1, flag_place = "小镇"}},
				{text = "环月的「烛龙」空间站", effects = {sci = 1, flag_place = "空间站"}},
			]},
			{original = "一张照片", options = [
				{text = "井边的合影", effects = {susp = 1, flag_prop = "古井"}},
				{text = "泛黄的家书", effects = {warm = 1, flag_prop = "信件"}},
				{text = "加密的星图", effects = {sci = 1, flag_prop = "星图"}},
				{text = "一张模糊的旧照片", effects = {flag_prop = "旧照片"}},
			]},
		],
	},
	{
		name = "第 2 章 · 发展", goal = {kind = "any"},
		tip = "改完即可交稿——注意呼应槽的候选随前文旗标变化",
		body = "回到老家后的第一晚，{0}。台灯下，我翻出了一本蒙尘的{1}。窗外人影一闪，我确信——{2}。",
		slots = [
			{original = "我彻夜未眠", options = [
				{text = "我重读了三年前的案件卷宗", effects = {susp = 1}},
				{text = "我去看了儿时的老友", effects = {warm = 1}},
				{text = "我申请调阅空间站的旧日志", effects = {sci = 1}},
			]},
			{original = "旧物", options = [
				{text = "母亲留下的针线盒", effects = {warm = 1}},
				{text = "一把黄铜钥匙", effects = {susp = 1}},
				{text = "一本褪色的航行手册", effects = {sci = 1}},
			]},
			{original = "有人在跟着我", dyn = "echo", options = []},
		],
	},
	{
		name = "第 3 章 · 转折", goal = {kind = "tone_max", min = 2},
		tip = "交稿时最高基调要冲到 +2（平淡化改写会掉基调）",
		body = "档案室最深处，我找到三份互相矛盾的记录。第一份说，{0}。第二份说，{1}。最底下压着一张字条，只有一句：{2}。我合上卷宗，起身——{3}。",
		slots = [
			{original = "记录已经残缺", options = [
				{text = "「他自愿参加了深空计划」", effects = {sci = 1}},
				{text = "「他只是累了，想回家」", effects = {warm = 1}},
				{text = "「纸页受潮，字迹难辨」", effects = {}},
			]},
			{original = "说法各有出入", options = [
				{text = "「星图上的坐标是伪造的」", effects = {sci = 1}},
				{text = "「字条是妹妹代笔的」", effects = {warm = 1, flag_note = "代笔的字条"}},
				{text = "「井栏的刻字早已磨平」", effects = {susp = -1}},
			]},
			{original = "「小心回来的人」", options = [
				{text = "「别相信回来的那个人」", effects = {susp = 1}},
				{text = "「回家吃饭吧，汤要凉了」", effects = {warm = 1}},
				{text = "「只是一场寻常告别，何必声张」", effects = {susp = -1}},
			]},
			{original = "我快步离开", options = [
				{text = "我推开老屋的门，闻到饭菜的香气", effects = {warm = 1}},
				{text = "我在档案架后发现第二串脚印", effects = {susp = 1}},
				{text = "我登上舷梯，穿过气闸舱门", effects = {sci = 1}, conflict = {flag = "place", value = "空间站", tone = "sci"}},
			]},
		],
	},
	{
		name = "第 4 章 · 危机", goal = {kind = "dual", at = 1, count = 2, flag = "prop"},
		tip = "两条基调 ≥ +1 且关键道具旗标仍在；小心「越改越偏」的改稿",
		body = "雨下了一整夜。天亮时，{0}。我把所有纸页摊在桌上，终于看清：{1}。要么现在收手，{2}。深夜，我拨通了那个号码：{3}。",
		slots = [
			{original = "门口多了一样东西", options = [
				{text = "门缝里被塞进一份匿名卷宗", effects = {susp = 1, flag_case = "匿名卷宗"}},
				{text = "老屋桌上留着一碗还温着的粥", effects = {warm = 1}},
				{text = "空间站的应答器突然恢复信号", effects = {sci = 1}},
			]},
			{original = "所有线索都指向同一个方向", options = [
				{text = "所有线索都指向同一个真相", effects = {susp = 1}},
				{text = "他一直在等我回家", effects = {warm = 1}},
				{text = "信号来自比月亮更远的地方", effects = {sci = 1}},
			]},
			{original = "还是继续写下去", options = [
				{text = "（改稿）干脆写成「外星来客」的爆点", effects = {sci = 2, warm = -1, flag_forced = "强行科幻"}, trap = true},
				{text = "（改稿）干脆改成「治愈归乡」的催泪收尾", effects = {warm = 2, sci = -1, flag_forced = "强行温情"}, trap = true},
				{text = "保持克制，只写下我能证实的事", effects = {susp = 1}},
			]},
			{original = "「我知道他还活着」", options = [
				{text = "「我知道他还活着」", effects = {susp = 1}},
				{text = "「我想回家吃一顿热饭」", effects = {warm = 1}},
				{text = "「请求一次深空搜救」", effects = {sci = 1}},
			]},
		],
	},
	{
		name = "第 5 章 · 结局", goal = {kind = "publish", min = 2},
		tip = "主基调 ≥ +2 且无读者抗议 → 过审出版",
		body = "回信来的那天，{0}。我在手稿的最后一页写下：{1}。合上稿纸时，{2}。多年后有人问起那个故事的结局，我说：{3}。只有我自己知道，{4}。",
		slots = [
			{original = "门口多了一个包裹", options = [
				{text = "信箱里躺着一枚陌生的空间站徽章", effects = {sci = 1}},
				{text = "妹妹提着保温桶站在门口", effects = {warm = 1}},
				{text = "井台边系着一条崭新的红布", effects = {susp = 1}},
			]},
			{original = "「故事写完了」", options = [
				{text = "「他随星尘去了更远的地方」", effects = {sci = 1}},
				{text = "「他回家了」", effects = {warm = 1}},
				{text = "「真相仍在井底」", effects = {susp = 1}},
			]},
			{original = "我长长舒了一口气", options = [
				{text = "我把手稿寄往深空通讯中心", effects = {sci = 1}},
				{text = "我在饭桌上把它读给全家听", effects = {warm = 1}},
				{text = "我把它锁进抽屉最底层", effects = {susp = 1}},
			]},
			{original = "「每个故事都有它的归宿」", options = [
				{text = "「故事没有结局，只有下一次发射」", effects = {sci = 1}},
				{text = "「最好的结局，是有人等你吃饭」", effects = {warm = 1}},
				{text = "「每个句号都是新的省略号」", effects = {susp = 1}},
			]},
			{original = "有些等待还没有结束", options = [
				{text = "星图的最后一段坐标仍未点亮", effects = {sci = 1}},
				{text = "那封信的落款只有两个字：勿念", effects = {warm = 1}},
				{text = "古井的第三块砖，昨夜又松动了", effects = {susp = 1}},
			]},
		],
	},
]

## 空的改动记录（回滚用）：delta=实际生效的基调增量；flag_old=旗标旧值（null=原本没有）；
## contra=本次记下的抗议数；pen_key/pen_delta=冲突惩罚扣掉的基调与实际增量
const EMPTY_APPLIED := {delta = {}, flag_old = {}, contra = 0, pen_key = "", pen_delta = 0}

var stats := {sci = 0, warm = 0, susp = 0}
var flags := {}                # 旗标集合：role / place / prop / case / note / forced…
var contradictions := 0        # 读者来信抗议次数（矛盾检测 + 陷阱改稿）
var chapter_idx := 0
var slots := []                # 当前章词槽 [{original, options, chosen, applied}]
var snap := {}                 # 本章开始时快照 {stats, flags, contradictions}
var chapter_pass := false
var state := "play"            # play / final
var active_slot := -1          # 候选浮层当前指向的词槽
var toast := ""
var toast_t := 0.0
var card_t := 0.0              # 章节标题卡剩余秒数（纯视觉，不阻塞逻辑）

var status_label: Label
var body_rtl: RichTextLabel
var tone_labels := []          # 三条基调的文字标签
var flags_label: Label
var goal_label: Label
var toast_label: Label
var popup_panel: Panel
var popup_box: Control
var card_panel: Panel
var card_label: Label
var end_panel: Panel
var end_title: Label
var end_body: Label
var btn_submit: Button
var btn_reset: Button


func _ready() -> void:
	_build_ui()
	start_chapter(0)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "修改小说（demo-10 · 编辑即玩法）"
	title.position = Vector2(16, 4)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("ffd54f"))
	ui.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(16, 26)
	status_label.size = Vector2(920, 22)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("9aa3b5"))
	ui.add_child(status_label)

	# 上 2/3：章节正文（词槽高亮可点击）
	body_rtl = RichTextLabel.new()
	body_rtl.name = "Body"
	body_rtl.position = Vector2(16, 52)
	body_rtl.size = Vector2(928, 292)
	body_rtl.bbcode_enabled = true
	body_rtl.scroll_active = true
	body_rtl.add_theme_font_size_override("normal_font_size", 16)
	body_rtl.add_theme_font_size_override("bold_font_size", 16)
	body_rtl.add_theme_color_override("default_color", Color("e8e4d8"))
	body_rtl.meta_clicked.connect(_on_meta)
	ui.add_child(body_rtl)

	# 下 1/3：基调条（_draw 画）+ 文字 + 旗标 + 目标 + 按钮
	for i in TONE_DEFS.size():
		var tl := Label.new()
		tl.position = Vector2(24 + i * 210, 350)
		tl.add_theme_font_size_override("font_size", 13)
		ui.add_child(tl)
		tone_labels.append(tl)
	flags_label = Label.new()
	flags_label.position = Vector2(24, 396)
	flags_label.size = Vector2(600, 62)
	flags_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flags_label.add_theme_font_size_override("font_size", 13)
	flags_label.add_theme_color_override("font_color", Color("8fd3a7"))
	ui.add_child(flags_label)
	goal_label = Label.new()
	goal_label.position = Vector2(644, 350)
	goal_label.size = Vector2(300, 118)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.add_theme_font_size_override("font_size", 13)
	goal_label.add_theme_color_override("font_color", Color("ffb74d"))
	ui.add_child(goal_label)
	btn_submit = Button.new()
	btn_submit.text = "提交本章"
	btn_submit.position = Vector2(644, 486)
	btn_submit.size = Vector2(140, 40)
	btn_submit.pressed.connect(submit_chapter)
	ui.add_child(btn_submit)
	btn_reset = Button.new()
	btn_reset.text = "重置本章"
	btn_reset.position = Vector2(804, 486)
	btn_reset.size = Vector2(140, 40)
	btn_reset.pressed.connect(reset_chapter)
	ui.add_child(btn_reset)
	toast_label = Label.new()
	toast_label.position = Vector2(24, 502)
	toast_label.size = Vector2(600, 24)
	toast_label.add_theme_font_size_override("font_size", 13)
	toast_label.add_theme_color_override("font_color", Color("ff8a80"))
	ui.add_child(toast_label)

	# 候选浮层
	popup_panel = Panel.new()
	popup_panel.name = "PickPanel"
	popup_panel.position = Vector2(556, 84)
	popup_panel.size = Vector2(380, 244)
	var pp_style := StyleBoxFlat.new()
	pp_style.bg_color = Color(0.13, 0.12, 0.18, 0.98)
	pp_style.set_corner_radius_all(10)
	pp_style.border_color = Color("5a5470")
	pp_style.set_border_width_all(2)
	popup_panel.add_theme_stylebox_override("panel", pp_style)
	popup_panel.visible = false
	ui.add_child(popup_panel)
	popup_box = Control.new()
	popup_box.name = "PickBox"
	popup_box.position = Vector2(12, 10)
	popup_box.size = Vector2(356, 224)
	popup_panel.add_child(popup_box)

	# 章节标题卡（纯视觉，不拦截点击）
	card_panel = Panel.new()
	card_panel.name = "CardPanel"
	card_panel.position = Vector2(230, 150)
	card_panel.size = Vector2(500, 120)
	var cp_style := StyleBoxFlat.new()
	cp_style.bg_color = Color(0.08, 0.07, 0.12, 0.92)
	cp_style.set_corner_radius_all(12)
	card_panel.add_theme_stylebox_override("panel", cp_style)
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.visible = false
	ui.add_child(card_panel)
	card_label = Label.new()
	card_label.name = "CardLabel"
	card_label.position = Vector2(0, 0)
	card_label.size = Vector2(500, 120)
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_label.add_theme_font_size_override("font_size", 30)
	card_label.add_theme_color_override("font_color", Color("ffd54f"))
	card_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(card_label)

	# 终章结算面板
	end_panel = Panel.new()
	end_panel.name = "EndPanel"
	end_panel.position = Vector2(150, 48)
	end_panel.size = Vector2(660, 444)
	var ep_style := StyleBoxFlat.new()
	ep_style.bg_color = Color(0.1, 0.1, 0.14, 0.98)
	ep_style.set_corner_radius_all(14)
	ep_style.border_color = Color("7fd88f")
	ep_style.set_border_width_all(2)
	end_panel.add_theme_stylebox_override("panel", ep_style)
	end_panel.visible = false
	ui.add_child(end_panel)
	end_title = Label.new()
	end_title.name = "EndTitle"
	end_title.position = Vector2(24, 14)
	end_title.add_theme_font_size_override("font_size", 24)
	end_title.add_theme_color_override("font_color", Color("7fd88f"))
	end_panel.add_child(end_title)
	end_body = Label.new()
	end_body.name = "EndBody"
	end_body.position = Vector2(24, 56)
	end_body.size = Vector2(612, 300)
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_body.add_theme_font_size_override("font_size", 14)
	end_body.add_theme_color_override("font_color", Color("e8e4d8"))
	end_panel.add_child(end_body)
	var again := Button.new()
	again.text = "重新改一部"
	again.position = Vector2(24, 380)
	again.size = Vector2(150, 40)
	again.pressed.connect(_restart)
	end_panel.add_child(again)


func _process(_delta: float) -> void:
	if card_t > 0.0:
		card_t = maxf(0.0, card_t - _delta)
		card_panel.modulate.a = clampf(card_t, 0.0, 1.0)
		if card_t <= 0.0:
			card_panel.visible = false
	if toast_t > 0.0:
		toast_t = maxf(0.0, toast_t - _delta)
		toast_label.modulate.a = clampf(toast_t, 0.0, 1.0)
		if toast_t <= 0.0:
			toast_label.text = ""
	_refresh_ui()
	queue_redraw()


# ---------------- 公开玩法 API（测试入口） ----------------

## 进入第 i 章：重建词槽（解析状态化候选）、拍本章快照、弹标题卡
func start_chapter(i: int) -> void:
	if i < 0 or i >= CHAPTERS.size():
		return
	chapter_idx = i
	var ch: Dictionary = CHAPTERS[i]
	slots = []
	for sd in ch.slots:
		var sdef: Dictionary = sd
		var sl := {
			original = str(sdef.original),
			options = _resolve_options(sdef),
			chosen = -1,
			applied = EMPTY_APPLIED.duplicate(true),
		}
		slots.append(sl)
	snap = {stats = stats.duplicate(), flags = flags.duplicate(), contradictions = contradictions}
	chapter_pass = false
	_close_popup()
	_show_card(str(ch.name))
	_refresh_ui()


## 改写词槽：换选会先回滚该槽上一次的改动（基调/旗标/抗议/惩罚），再施加新候选
func choose(slot_idx: int, opt_idx: int) -> void:
	if state != "play":
		return
	if slot_idx < 0 or slot_idx >= slots.size():
		return
	var opts: Array = slots[slot_idx].options
	if opt_idx < 0 or opt_idx >= opts.size():
		return
	if int(slots[slot_idx].chosen) == opt_idx:
		return
	_unapply_slot(slot_idx)
	var opt: Dictionary = opts[opt_idx]
	slots[slot_idx].chosen = opt_idx
	var applied := EMPTY_APPLIED.duplicate(true)
	var fx: Dictionary = opt.effects
	for k in fx:
		var key: String = str(k)
		if key == "sci" or key == "warm" or key == "susp":
			var amount: int = int(fx[k])
			var old: int = int(stats[key])
			stats[key] = clampi(old + amount, -3, 3)
			applied.delta[key] = stats[key] - old
		elif key.begins_with("flag_"):
			var fname: String = key.substr(5)
			applied.flag_old[fname] = flags.get(fname)   # 没有时为 null，回滚时删除
			flags[fname] = str(fx[k])
	# 矛盾检测：改写与既有旗标冲突（如小镇线写出空间站场景）→ 读者抗议 + 扣对应基调
	var conflict = opt.get("conflict")
	if conflict != null:
		var cf: Dictionary = conflict
		var cflag: String = str(cf.flag)
		if flags.has(cflag) and str(flags[cflag]) != str(cf.value):
			applied.contra = 1
			contradictions += 1
			var pk: String = str(cf.tone)
			var po: int = int(stats[pk])
			stats[pk] = clampi(po - 1, -3, 3)
			applied.pen_key = pk
			applied.pen_delta = int(stats[pk]) - po
			_toast("读者来信抗议：故事写岔了（%s -1）" % _tone_name(pk))
	# 陷阱改稿：越改越偏，高收益但同样引来抗议（终章过审要求抗议为 0）
	if bool(opt.get("trap", false)):
		applied.contra += 1
		contradictions += 1
		_toast("读者来信抗议：越改越偏了（本章抗议 +1）")
	slots[slot_idx].applied = applied
	_refresh_ui()


## 交稿：全部词槽改完才受理；目标达标过章（末章过审出版），否则退稿停在本章
func submit_chapter() -> void:
	if state != "play":
		return
	if not _all_chosen():
		chapter_pass = false
		_toast("还有词槽没改完——把每个高亮词都定下来再交稿")
		_refresh_ui()
		return
	if _goal_ok():
		chapter_pass = true
		if chapter_idx >= CHAPTERS.size() - 1:
			state = "final"
			_close_popup()
			_show_end()
			_toast("过审出版！")
		else:
			start_chapter(chapter_idx + 1)
			_toast("交稿通过，进入下一章")
	else:
		chapter_pass = false
		_toast("退稿重改：" + str(CHAPTERS[chapter_idx].tip))
	_refresh_ui()


## 退稿后重置本章：回滚到本章开始时的快照，词槽全部恢复可重改
func reset_chapter() -> void:
	if state != "play":
		return
	var ss: Dictionary = snap.stats
	stats = {sci = int(ss.sci), warm = int(ss.warm), susp = int(ss.susp)}
	flags = (snap.flags as Dictionary).duplicate()
	contradictions = int(snap.contradictions)
	for i in slots.size():
		slots[i].chosen = -1
		slots[i].applied = EMPTY_APPLIED.duplicate(true)
	chapter_pass = false
	_close_popup()
	_toast("已重置本章：旗标与基调回到章首快照")
	_refresh_ui()


## 当前章渲染后的完整正文（终章额外拼上按状态生成的结局段）
func state_text() -> String:
	var ch: Dictionary = CHAPTERS[chapter_idx]
	var t: String = _render_plain(str(ch.body))
	if state == "final":
		t += "\n\n" + _ending_text()
	return t


# ---------------- 状态与规则 ----------------

func _resolve_options(sdef: Dictionary) -> Array:
	if str(sdef.get("dyn", "")) != "echo":
		return sdef.options
	var role: String = str(flags.get("role", ""))
	for e in ECHO_OPTIONS:
		if str(e.role) == role:
			return e.options
	return ECHO_OPTIONS[ECHO_OPTIONS.size() - 1].options


func _unapply_slot(i: int) -> void:
	var sl: Dictionary = slots[i]
	if int(sl.chosen) < 0:
		return
	var ap: Dictionary = sl.applied
	var d: Dictionary = ap.delta
	for k in d:
		var dk: String = str(k)
		stats[dk] = clampi(int(stats[dk]) - int(d[k]), -3, 3)
	var fo: Dictionary = ap.flag_old
	for k in fo:
		if fo[k] == null:
			flags.erase(str(k))
		else:
			flags[str(k)] = fo[k]
	if int(ap.contra) > 0:
		contradictions = maxi(0, contradictions - int(ap.contra))
	var pk: String = str(ap.pen_key)
	if pk != "":
		stats[pk] = clampi(int(stats[pk]) - int(ap.pen_delta), -3, 3)
	sl.chosen = -1
	sl.applied = EMPTY_APPLIED.duplicate(true)


func _all_chosen() -> bool:
	for sl in slots:
		if int(sl.chosen) < 0:
			return false
	return true


func _max_tone() -> int:
	return maxi(maxi(int(stats.sci), int(stats.warm)), int(stats.susp))


func _goal_ok() -> bool:
	var g: Dictionary = CHAPTERS[chapter_idx].goal
	match str(g.kind):
		"any":
			return _all_chosen()
		"tone_max":
			return _max_tone() >= int(g.min)
		"dual":
			var need: int = int(g.at)
			var n := 0
			if int(stats.sci) >= need:
				n += 1
			if int(stats.warm) >= need:
				n += 1
			if int(stats.susp) >= need:
				n += 1
			return n >= int(g.count) and flags.has(str(g.flag))
		"publish":
			return _max_tone() >= int(g.min) and contradictions == 0
	return false


func _render_plain(body: String) -> String:
	var out := body
	for i in slots.size():
		var sl: Dictionary = slots[i]
		var word: String = str(sl.original)
		var ci: int = int(sl.chosen)
		if ci >= 0:
			var opt: Dictionary = sl.options[ci]
			word = str(opt.text)
		out = out.replace("{%d}" % i, word)
	return out


func _ending_text() -> String:
	var role: String = str(flags.get("role", "旅人"))
	var place: String = str(flags.get("place", "小镇"))
	var prop: String = str(flags.get("prop", "旧物"))
	var dom := "sci"
	if int(stats.warm) > int(stats.sci) and int(stats.warm) >= int(stats.susp):
		dom = "warm"
	elif int(stats.susp) > int(stats.sci) and int(stats.susp) > int(stats.warm):
		dom = "susp"
	match dom:
		"sci":
			return "《回声》终稿：%s带着%s登上离开%s的飞船。舷窗外，星图亮起了最后一段坐标——那是来自过去的问候，也是写给未来的信。" % [role, prop, place]
		"warm":
			return "《归途》终稿：%s回到%s，把%s放进老屋的抽屉。灶上的汤还温着，灯为晚归的人亮着——原来最好的结局，是回来吃饭。" % [role, place, prop]
		_:
			return "《井底的字条》终稿：多年以后，有人在%s的%s旁发现了新的字条，字迹似曾相识，落款只有一行小字：故事才刚刚开始。" % [place, prop]


func _tone_name(key: String) -> String:
	for t in TONE_DEFS:
		if str(t.key) == key:
			return str(t.label)
	return key


# ---------------- UI 刷新 ----------------

func _body_bbcode() -> String:
	var ch: Dictionary = CHAPTERS[chapter_idx]
	var out: String = str(ch.body)
	for i in slots.size():
		var sl: Dictionary = slots[i]
		var word: String = str(sl.original)
		var col := "ffd54f"   # 未改：琥珀
		var ci: int = int(sl.chosen)
		if ci >= 0:
			var opt: Dictionary = sl.options[ci]
			word = str(opt.text)
			col = "7fd88f"    # 已改：绿
		var mark := "[u][color=#%s]%s[/color][/u]" % [col, word]
		out = out.replace("{%d}" % i, "[url=%d]" % i + mark + "[/url]")
	return out


func _flags_text() -> String:
	if flags.is_empty():
		return "旗标：（暂无——改词会在这里种下身份、地点与伏笔）"
	var parts := []
	for k in flags:
		var kk: String = str(k)
		var disp: String = str(FLAG_NAMES.get(kk, kk))
		parts.append("%s=%s" % [disp, str(flags[k])])
	return "旗标：" + " · ".join(parts)


func _refresh_ui() -> void:
	if chapter_idx < 0 or chapter_idx >= CHAPTERS.size():
		return
	var ch: Dictionary = CHAPTERS[chapter_idx]
	var done := 0
	for sl in slots:
		if int(sl.chosen) >= 0:
			done += 1
	var st := "%s · 词槽 %d/%d · 读者抗议 ×%d" % [str(ch.name), done, slots.size(), contradictions]
	if state == "final":
		st += " · 已过审出版"
	status_label.text = st
	body_rtl.text = _body_bbcode() if state == "play" else "[color=#7fd88f]" + _ending_text() + "[/color]"
	for i in TONE_DEFS.size():
		var td: Dictionary = TONE_DEFS[i]
		var v: int = int(stats[td.key])
		var sign_c := "+" if v >= 0 else ""
		(tone_labels[i] as Label).text = "%s %s%d" % [str(td.label), sign_c, v]
		(tone_labels[i] as Label).add_theme_color_override("font_color", td.col)
	flags_label.text = _flags_text()
	var tag := "待交稿"
	if state == "final":
		tag = "已出版"
	elif chapter_pass:
		tag = "已过章"
	elif done > 0:
		tag = "已退稿，可继续调整或重置本章"
	goal_label.text = "本章目标：%s\n[%s]" % [str(ch.tip), tag]
	btn_submit.disabled = state != "play"
	btn_reset.disabled = state != "play"


func _show_card(text: String) -> void:
	card_label.text = text
	card_panel.visible = true
	card_t = 1.6


func _toast(t: String) -> void:
	toast = t
	toast_t = 3.0
	toast_label.text = t
	toast_label.modulate.a = 1.0


func _show_end() -> void:
	end_title.text = _ending_text().substr(0, _ending_text().find("：")) + " · 过审出版"
	end_body.text = "%s\n\n基调：科幻 %+d · 温情 %+d · 悬疑 %+d\n读者抗议 %d 次 · 旗标 %d 条\n—— 前四章的每一次改词，共同拼出了这个结局。" % [
		_ending_text(), int(stats.sci), int(stats.warm), int(stats.susp), contradictions, flags.size()]
	end_panel.visible = true


func _restart() -> void:
	stats = {sci = 0, warm = 0, susp = 0}
	flags = {}
	contradictions = 0
	chapter_pass = false
	state = "play"
	end_panel.visible = false
	start_chapter(0)


# ---------------- 交互 ----------------

func _on_meta(meta) -> void:
	if state != "play":
		return
	_open_popup(int(str(meta)))


func _open_popup(i: int) -> void:
	if i < 0 or i >= slots.size():
		return
	active_slot = i
	for c in popup_box.get_children():
		c.queue_free()
	var sl: Dictionary = slots[i]
	var head := Label.new()
	head.text = "改写「%s」：" % str(sl.original)
	head.position = Vector2(0, 0)
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", Color("ffd54f"))
	popup_box.add_child(head)
	var opts: Array = sl.options
	for k in opts.size():
		var opt: Dictionary = opts[k]
		var b := Button.new()
		var mark := "（已选）" if int(sl.chosen) == k else ""
		b.text = str(opt.text) + mark
		b.position = Vector2(0, 30 + k * 44)
		b.size = Vector2(356, 38)
		b.pressed.connect(_on_pick.bind(k))
		popup_box.add_child(b)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.position = Vector2(0, 30 + opts.size() * 44)
	cancel.size = Vector2(120, 32)
	cancel.pressed.connect(_close_popup)
	popup_box.add_child(cancel)
	popup_panel.visible = true


func _on_pick(k: int) -> void:
	if active_slot >= 0:
		choose(active_slot, k)
	_close_popup()


func _close_popup() -> void:
	active_slot = -1
	popup_panel.visible = false


# ---------------- 绘制 ----------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color("201d28"))
	# 稿纸分隔线
	draw_rect(Rect2(16, 46, VIEW.x - 32, 2), Color("39344a"))
	draw_rect(Rect2(16, 344, VIEW.x - 32, 2), Color("39344a"))
	# 三条基调条：中间为零点，向左右延伸
	for i in TONE_DEFS.size():
		var td: Dictionary = TONE_DEFS[i]
		var x := 24.0 + i * 210.0
		var track := Rect2(x, 374, 150, 10)
		draw_rect(track, Color("353148"))
		var v: int = int(stats[td.key])
		var cx := x + 75.0
		if v != 0:
			var w := absf(float(v)) * 25.0
			var fx := cx if v > 0 else cx - w
			draw_rect(Rect2(fx, track.position.y, w, 10), td.col)
		draw_rect(Rect2(cx - 1.0, track.position.y - 2.0, 2, 14), Color("8b94a7"))
		draw_string(FONT, Vector2(x, track.position.y - 6), str(td.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, td.col)
