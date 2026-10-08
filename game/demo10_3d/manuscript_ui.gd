extends CanvasLayer
## DEMO10 3D 阶段 A：手稿界面（屏幕空间 CanvasLayer）。
## 指南第 4 节：完整正文可读、词槽真鼠标点击、候选浮层只显示小说文字（盲测下）；
## 打开时冻结世界输入（根脚本负责），关闭时恢复；取消只关弹窗不撤销已选词，
## 真正反悔是换选另一个候选，重置是回章首——与旧规则一致。
## 编辑即生效：不新增确认付款步骤。

signal pick_requested(slot_idx: int, opt_idx: int)
signal submit_requested
signal reset_requested
signal close_requested

const FONT_SIZE := 15

var core: RefCounted
var root_panel: Control
var dim: ColorRect
var title_label: Label
var status_label: Label
var body_rtl: RichTextLabel
var tone_labels: Array = []
var amb_label: Label
var flags_label: Label
var goal_label: Label
var btn_submit: Button
var btn_reset: Button
var btn_close: Button
var popup: Panel
var popup_box: VBoxContainer
var active_slot := -1
var is_open := false


func bind(c: RefCounted) -> void:
	core = c


func _ready() -> void:
	layer = 10
	root_panel = Control.new()
	root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_panel.visible = false
	add_child(root_panel)
	dim = ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.09, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_panel.add_child(dim)
	title_label = _label(Vector2(20, 8), Vector2(600, 26), 20, Color("ffd54f"))
	status_label = _label(Vector2(20, 36), Vector2(700, 22), 13, Color("9aa3b5"))
	body_rtl = RichTextLabel.new()
	body_rtl.position = Vector2(20, 64)
	body_rtl.size = Vector2(610, 440)
	body_rtl.bbcode_enabled = true
	body_rtl.scroll_active = true
	body_rtl.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	body_rtl.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	body_rtl.add_theme_color_override("default_color", Color("e8e4d8"))
	body_rtl.meta_clicked.connect(_on_meta)
	root_panel.add_child(body_rtl)
	# 右栏：基调三档 / 氛围 / 旗标 / 目标 / 按钮
	var rx := 650.0
	for i in 3:
		var tl := _label(Vector2(rx, 70 + i * 26), Vector2(290, 22), 14, Color.WHITE)
		tone_labels.append(tl)
	amb_label = _label(Vector2(rx, 150), Vector2(290, 40), 12, Color("8fb8d8"))
	amb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flags_label = _label(Vector2(rx, 196), Vector2(290, 130), 12, Color("8fd3a7"))
	flags_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label = _label(Vector2(rx, 330), Vector2(290, 80), 12, Color("ffb74d"))
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_submit = _button("提交本章", Vector2(rx, 420), Vector2(140, 38))
	btn_submit.pressed.connect(func() -> void: submit_requested.emit())
	btn_reset = _button("重置本章", Vector2(rx + 150, 420), Vector2(140, 38))
	btn_reset.pressed.connect(func() -> void: reset_requested.emit())
	btn_close = _button("合上手稿（Tab/Esc）", Vector2(rx, 468), Vector2(290, 30))
	btn_close.pressed.connect(func() -> void: close_requested.emit())
	# 候选浮层
	popup = Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.12, 0.18, 0.98)
	st.set_corner_radius_all(10)
	st.border_color = Color("5a5470")
	st.set_border_width_all(2)
	popup.add_theme_stylebox_override("panel", st)
	popup.position = Vector2(240, 90)
	popup.size = Vector2(420, 360)
	popup.visible = false
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	root_panel.add_child(popup)
	popup_box = VBoxContainer.new()
	popup_box.position = Vector2(12, 10)
	popup_box.size = Vector2(396, 340)
	popup_box.add_theme_constant_override("separation", 8)
	popup.add_child(popup_box)


func _label(pos: Vector2, size_: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size_
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	root_panel.add_child(l)
	return l


func _button(text: String, pos: Vector2, size_: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size_
	root_panel.add_child(b)
	return b


func open() -> void:
	is_open = true
	root_panel.visible = true
	refresh()
	_close_popup()


func close() -> void:
	is_open = false
	root_panel.visible = false
	_close_popup()


func refresh() -> void:
	if core == null or not is_open:
		return
	var ch: Dictionary = core.CHAPTERS[core.chapter_idx]
	title_label.text = "手稿 · %s" % str(ch.name)
	var done := 0
	for sl in core.slots:
		if int(sl.chosen) >= 0:
			done += 1
	var st := "词槽 %d/%d · 读者抗议 ×%d" % [done, core.slots.size(), int(core.contradictions)]
	if not (core.anomalies as Array).is_empty() and not bool(core.blind_mode):
		st += " · 待圆回矛盾 ×%d" % (core.anomalies as Array).size()
	if str(core.state) == "final":
		st += " · 已过审出版"
	status_label.text = st
	body_rtl.text = _body_bbcode()
	var blind := bool(core.blind_mode)
	for i in tone_labels.size():
		var td: Dictionary = core.TONE_DEFS[i]
		var v: int = int(core.stats[td.key])
		var lbl: Label = tone_labels[i]
		if blind:
			lbl.text = "%s · %s" % [str(td.label), str(core.tone_tier(v))]
		else:
			lbl.text = "%s %+d" % [str(td.label), v]
		lbl.add_theme_color_override("font_color", td.col)
	amb_label.visible = blind
	if blind:
		amb_label.text = "基调氛围：" + str(core.ambience_text())
	var ftxt := _flags_text()
	flags_label.text = ftxt
	var tag := "待交稿"
	if str(core.state) == "final":
		tag = "已出版"
	elif bool(core.chapter_pass):
		tag = "已过章"
	elif done > 0:
		tag = "已退稿，可继续调整或重置本章"
	goal_label.text = "本章目标：%s\n[%s]" % [str(ch.tip), tag]


func _flags_text() -> String:
	if (core.flags as Dictionary).is_empty():
		return "旗标：（暂无——改词会在这里种下身份、地点与伏笔）"
	var parts := []
	for k in core.flags:
		var kk := str(k)
		parts.append("%s=%s" % [str(core.FLAG_NAMES.get(kk, kk)), str(core.flags[k])])
	return "旗标：" + " · ".join(parts)


func _body_bbcode() -> String:
	var ch: Dictionary = core.CHAPTERS[core.chapter_idx]
	var out: String = str(ch.body)
	for i in core.slots.size():
		var sl: Dictionary = core.slots[i]
		var word := str(sl.original)
		var col := "ffd54f"
		var ci := int(sl.chosen)
		if ci >= 0:
			word = str((sl.options as Array)[ci].text)
			col = "7fd88f"
		out = out.replace("{%d}" % i, "[url=%d]" % i + "[u][color=#%s]%s[/color][/u]" % [col, word] + "[/url]")
	return out


func _on_meta(meta) -> void:
	_open_popup(int(str(meta)))


func _open_popup(i: int) -> void:
	if core == null or i < 0 or i >= core.slots.size():
		return
	active_slot = i
	for c in popup_box.get_children():
		popup_box.remove_child(c)
		c.free()
	var sl: Dictionary = core.slots[i]
	var head := Label.new()
	head.text = "改写「%s」：" % str(sl.original)
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Color("ffd54f"))
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_box.add_child(head)
	# 盲测安全：选择前只给小说文字（派生义/可圆回/解读方向全部隐藏）；
	# 非盲测时按旧 UI 补标注。已选项给「（已选）」标记。
	var opts: Array = sl.options
	for k in opts.size():
		var opt: Dictionary = opts[k]
		var b := Button.new()
		var mark := "（已选）" if int(sl.chosen) == k else ""
		b.text = "%d. %s%s" % [k + 1, str(opt.text), mark]
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_on_pick.bind(k))
		popup_box.add_child(b)
	var cancel := Button.new()
	cancel.text = "取消（只关弹窗，不撤销已选的词）"
	cancel.add_theme_font_size_override("font_size", 12)
	cancel.pressed.connect(_close_popup)
	popup_box.add_child(cancel)
	popup.visible = true


func _on_pick(k: int) -> void:
	var slot := active_slot
	_close_popup()
	if slot >= 0:
		pick_requested.emit(slot, k)


func _close_popup() -> void:
	active_slot = -1
	popup.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := event as InputEventKey
		if popup.visible and active_slot >= 0:
			# 数字键快速选择候选（键盘路径；1..9）
			var idx := -1
			match k.physical_keycode:
				KEY_1: idx = 0
				KEY_2: idx = 1
				KEY_3: idx = 2
				KEY_4: idx = 3
				KEY_5: idx = 4
				KEY_6: idx = 5
				KEY_7: idx = 6
				KEY_8: idx = 7
				KEY_9: idx = 8
			if idx >= 0:
				var opts: Array = core.slots[active_slot].options
				if idx < opts.size():
					_on_pick(idx)
					get_viewport().set_input_as_handled()
					return
		if k.physical_keycode == KEY_TAB or k.physical_keycode == KEY_ESCAPE:
			_close_popup()
			close_requested.emit()
			get_viewport().set_input_as_handled()
