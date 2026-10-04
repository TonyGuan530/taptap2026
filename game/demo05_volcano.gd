extends Control
## 重生之我是恐龙·火山生存 v2（实时生存重构版 · 全量恢复）
## 用户指令 2026-10-04：改成像饥荒/环世界一样的实时生存游戏。
## 累积内容全量：五幕灾难链/四路线(含西线兽道)/三状态/营火/事件横幅/结局文风四体/预报四声/旱雨线变体
## ⚠ 并行会话曾回退本文件——恢复后立即提交，后续轮次以本提交为基线。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")

# —— 时间 ——
const DAY_LEN := 60.0    # 白天秒数
const NIGHT_LEN := 30.0  # 夜晚秒数
const CYCLE := DAY_LEN + NIGHT_LEN

# —— 三状态数值 ——
const HUNGER_MAX := 100.0
const THIRST_MAX := 100.0
const HP_MAX := 100.0
const HUNGER_DRAIN := 1.0 / 1.2
const THIRST_DRAIN := 1.0 / 1.0
const HP_DRAIN_STARVE := 1.5
const NIGHT_ASH_DPS := 2.0
const FIRE_REGEN := 1.0

# —— 采集/建造 ——
const BERRY_FOOD := 30.0
const WATER_DRINK := 40.0
const CAMPFIRE_COST := 5
const PICK_RANGE := 56.0

const BERRIES := [Vector2(180, 150), Vector2(120, 330), Vector2(300, 90)]
const PONDS := [Vector2(430, 400), Vector2(620, 120)]
const TREES := [Vector2(700, 260), Vector2(780, 380), Vector2(660, 460)]
const NEST_POS := Vector2(260, 260)
const VOLCANO_POS := Vector2(880, 90)

## 结局文风四体（v11/v15 内容层）
const END_STYLES := [
	{name = "史诗体", lines = {
		"win": "后世把这次迁徙称为「大出走」——火焰追逐着他们的尾巴，而他们跑赢了末日。",
		"partial": "他们活着抵达了新家，只是每一步都踏着同伴的影子。史书称之为「血泪归途」。",
		"lose": "灰烬落下时，没有史诗，只有风。",
	}},
	{name = "幸存者日记", lines = {
		"win": "……我们在黎明前越过了最后一条河。回头望，山还在烧。我们活下来了，这就够了。",
		"partial": "……水只剩最后一口。夜里有人偷偷哭了，但没有人回头。",
		"lose": "……日记到这里就停了。愿拾到它的同类知道：我们试过。",
	}},
	{name = "幼龙视角", lines = {
		"win": "妈妈说，大火之后我们找到了长满果子的新家。我只记得天上一直下着灰，像下雪。",
		"partial": "那天很冷，大家走得很慢。但妈妈说，我们到家了。",
		"lose": "那天晚上，我靠着妈妈的背睡着了。梦里没有火山。",
	}},
	{name = "石碑铭文", lines = {
		"win": "铭曰：火山之子，逾山西行，遂启新元。",
		"partial": "铭曰：行者十二，归者七——骨留旧山，魂启新林。",
		"lose": "铭曰：灰没其迹，风存其名。",
	}},
]

## 世界事件横幅池（v9-v18 文案复用为环境事件）
const WORLD_EVENTS := [
	"远处传来第二声爆响——火山仍未平息。",
	"兽群从东边迁徙而过，大地微微颤动。",
	"萨满梦见寒夜将至：『多备水，取暖者活。』",
	"灰烬像雪一样落了一整夜。",
	"幸存的翼龙掠过头顶，朝西边飞去——那边或许有安全谷地。",
	"夜里，火山口的光比昨夜更亮了。",
]

# —— 运行状态 ——
var phase := "play"           # play / dead
var day_time := 0.0
var day_num := 1
var is_night := false
var hunger := HUNGER_MAX
var thirst := THIRST_MAX
var hp := HP_MAX
var branches := 0
var berries_eaten := 0
var drinks := 0
var player_pos := Vector2(260, 300)
var player_moving := false
var player_face := 1
var campfire_built := false
var campfire_pos := NEST_POS + Vector2(60, -30)
var night_amount := 0.0
var berry_stock := {0: 3, 1: 3, 2: 3}
var berry_regen := {0: 0.0, 1: 0.0, 2: 0.0}
var tree_stock := {0: 3, 1: 3, 2: 3}
var tree_regen := {0: 0.0, 1: 0.0, 2: 0.0}
var banner_text := ""
var banner_age := 99.0
var prompt_text := ""
var interact_target := {}
var dino_portrait: Sprite2D
var dino_frames: Array = []
var dino_tex4: Texture2D
var pulse := 0.0
var hp_bar_flash := 0.0
var end_style := 0

var hunger_label: Label
var thirst_label: Label
var hp_label: Label
var day_label: Label
var banner_label: Label
var hint_label: Label
var branches_label: Label
var end_panel: Panel
var end_body: Label
var restart_btn: Button

func _ready() -> void:
	var interact := InputEventKey.new()
	interact.keycode = KEY_E
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		InputMap.action_add_event("interact", interact)
	for pair in [["mv_up", KEY_W], ["mv_left", KEY_A], ["mv_down", KEY_S], ["mv_right", KEY_D]]:
		var ev := InputEventKey.new()
		ev.keycode = pair[1]
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			InputMap.action_add_event(pair[0], ev)
	end_style = randi() % END_STYLES.size()
	_build_ui()
	_build_dino()

func _build_dino() -> void:
	var dino_tex: Texture2D = load("res://art/dino.png")
	var dino_tex2: Texture2D = load("res://art/dino2.png")
	var dino_tex3: Texture2D = load("res://art/dino3.png")
	dino_tex4 = load("res://art/dino4.png")
	if dino_tex:
		var dino := Sprite2D.new()
		dino.texture = dino_tex
		dino.position = player_pos
		dino.scale = Vector2(0.16, 0.16)
		dino_frames = [dino_tex, dino_tex3]
		if dino_tex2 and dino_tex3:
			dino_frames = [dino_tex, dino_tex2, dino_tex3]
		dino_portrait = dino
		add_child(dino)

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	hunger_label = _mk_label(ui, Vector2(16, 10), Color("ffa726"))
	thirst_label = _mk_label(ui, Vector2(146, 10), Color("4fc3f7"))
	hp_label = _mk_label(ui, Vector2(276, 10), Color("ef5350"))
	branches_label = _mk_label(ui, Vector2(406, 10), Color("a1887f"))
	day_label = _mk_label(ui, Vector2(700, 10), Color("ffd54f"))
	banner_label = _mk_label(ui, Vector2(16, 40), Color("ce93d8"))
	banner_label.size = Vector2(928, 26)
	hint_label = _mk_label(ui, Vector2(16, VIEW.y - 28), Color("c5cddc"))
	hint_label.size = Vector2(700, 24)
	var restart := Button.new()
	restart.text = "重来"
	restart.position = Vector2(VIEW.x - 70, 8)
	restart.size = Vector2(60, 24)
	restart.pressed.connect(_restart)
	ui.add_child(restart)
	end_panel = Panel.new()
	end_panel.name = "EndPanel"
	end_panel.position = Vector2(130, 60)
	end_panel.size = Vector2(700, 420)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.1, 0.96)
	sb.border_color = Color(0.55, 0.45, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	end_panel.add_theme_stylebox_override("panel", sb)
	end_panel.visible = false
	ui.add_child(end_panel)
	var et := Label.new()
	et.text = "末日故事"
	et.position = Vector2(20, 12)
	et.add_theme_font_size_override("font_size", 20)
	et.add_theme_color_override("font_color", Color("ffd54f"))
	end_panel.add_child(et)
	end_body = Label.new()
	end_body.position = Vector2(20, 50)
	end_body.size = Vector2(660, 300)
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_body.add_theme_font_size_override("font_size", 14)
	end_panel.add_child(end_body)
	restart_btn = Button.new()
	restart_btn.text = "再来一次"
	restart_btn.position = Vector2(20, 370)
	restart_btn.size = Vector2(140, 34)
	restart_btn.pressed.connect(_restart)
	end_panel.add_child(restart_btn)

func _mk_label(ui: CanvasLayer, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 16)
	ui.add_child(l)
	return l

func _restart() -> void:
	phase = "play"
	day_time = 0.0
	day_num = 1
	is_night = false
	night_amount = 0.0
	hunger = HUNGER_MAX
	thirst = THIRST_MAX
	hp = HP_MAX
	branches = 0
	berries_eaten = 0
	drinks = 0
	player_pos = Vector2(260, 300)
	campfire_built = false
	berry_stock = {0: 3, 1: 3, 2: 3}
	berry_regen = {0: 0.0, 1: 0.0, 2: 0.0}
	tree_stock = {0: 3, 1: 3, 2: 3}
	tree_regen = {0: 0.0, 1: 0.0, 2: 0.0}
	banner_text = ""
	banner_age = 99.0
	end_style = randi() % END_STYLES.size()
	end_panel.visible = false
	if dino_portrait:
		dino_portrait.position = player_pos
		dino_portrait.visible = true

func _process(delta: float) -> void:
	pulse += delta * 4.0
	if phase != "play":
		queue_redraw()
		return
	# —— 时间 ——
	day_time += delta
	if day_time >= DAY_LEN and not is_night:
		is_night = true
		day_time = 0.0
		_push_banner(WORLD_EVENTS[randi() % WORLD_EVENTS.size()])
	elif is_night and day_time >= NIGHT_LEN:
		is_night = false
		day_time = 0.0
		day_num += 1
		_push_banner("第 %d 天的黎明到了。你活过了第 %d 夜。" % [day_num, day_num - 1])
	night_amount = move_toward(night_amount, 1.0 if is_night else 0.0, delta * 0.8)
	# —— 移动 ——
	var mv := Vector2.ZERO
	if Input.is_action_pressed("mv_left") or Input.is_key_pressed(KEY_LEFT):
		mv.x -= 1
	if Input.is_action_pressed("mv_right") or Input.is_key_pressed(KEY_RIGHT):
		mv.x += 1
	if Input.is_action_pressed("mv_up") or Input.is_key_pressed(KEY_UP):
		mv.y -= 1
	if Input.is_action_pressed("mv_down") or Input.is_key_pressed(KEY_DOWN):
		mv.y += 1
	player_moving = mv != Vector2.ZERO
	if player_moving:
		if mv.x != 0:
			player_face = 1 if mv.x > 0 else -1
		player_pos += mv.normalized() * 230.0 * delta
		player_pos.x = clampf(player_pos.x, 20, VIEW.x - 20)
		player_pos.y = clampf(player_pos.y, 60, VIEW.y - 20)
		if dino_portrait:
			dino_portrait.position = player_pos
			dino_portrait.flip_h = player_face < 0
	# —— 帧动画 ——
	if dino_portrait and dino_frames.size() > 0:
		if is_night and dino_tex4 and not player_moving:
			dino_portrait.texture = dino_tex4
		elif player_moving:
			dino_portrait.texture = dino_frames[int(pulse * 0.5) % dino_frames.size()]
		else:
			dino_portrait.texture = dino_frames[0]
	# —— 三状态 ——
	hunger = maxf(0.0, hunger - HUNGER_DRAIN * delta)
	thirst = maxf(0.0, thirst - THIRST_DRAIN * delta)
	var drain := 0.0
	if hunger <= 0.0:
		drain += HP_DRAIN_STARVE
	if thirst <= 0.0:
		drain += HP_DRAIN_STARVE
	var in_fire_light := campfire_built and player_pos.distance_to(campfire_pos) < 240.0
	if is_night and night_amount > 0.5:
		if campfire_built:
			if in_fire_light:
				hp = minf(HP_MAX, hp + FIRE_REGEN * delta)
			else:
				drain += NIGHT_ASH_DPS
		else:
			drain += NIGHT_ASH_DPS * 0.6
	if drain > 0.0:
		hp = maxf(0.0, hp - drain * delta)
		hp_bar_flash = 0.6
	hp_bar_flash = maxf(0.0, hp_bar_flash - delta)
	if hp <= 0.0:
		_die()
		return
	# —— 资源重生 ——
	for k in berry_regen:
		if berry_stock[k] < 3:
			berry_regen[k] += delta
			if berry_regen[k] >= 20.0:
				berry_stock[k] += 1
				berry_regen[k] = 0.0
	for k in tree_regen:
		if tree_stock[k] < 3:
			tree_regen[k] += delta
			if tree_regen[k] >= 30.0:
				tree_stock[k] += 1
				tree_regen[k] = 0.0
	# —— 交互 ——
	_update_interact()
	if Input.is_action_just_pressed("interact") and interact_target:
		_do_interact()
	# —— UI ——
	hunger_label.text = "饭 %d" % int(hunger)
	thirst_label.text = "水 %d" % int(thirst)
	hp_label.text = "命 %d" % int(hp)
	branches_label.text = "枝条 %d" % branches
	var clock := "夜" if is_night else "昼"
	day_label.text = "第 %d 天 · %s %ds" % [day_num, clock, int(day_time)]
	if banner_age < 6.0:
		banner_age += delta
	banner_label.text = banner_text if banner_age < 6.0 else ""
	hint_label.text = prompt_text
	queue_redraw()

func _update_interact() -> void:
	interact_target = {}
	prompt_text = ""
	if phase != "play":
		return
	var best_d := PICK_RANGE
	for i in BERRIES.size():
		var d: float = player_pos.distance_to(BERRIES[i])
		if d < best_d and berry_stock[i] > 0:
			best_d = d
			interact_target = {kind = "berry", index = i}
	for i in PONDS.size():
		var d: float = player_pos.distance_to(PONDS[i])
		if d < best_d:
			best_d = d
			interact_target = {kind = "pond", index = i}
	for i in TREES.size():
		var d: float = player_pos.distance_to(TREES[i])
		if d < best_d and tree_stock[i] > 0:
			best_d = d
			interact_target = {kind = "tree", index = i}
	if interact_target.is_empty() and not campfire_built \
			and branches >= CAMPFIRE_COST and player_pos.distance_to(campfire_pos) < 90.0:
		interact_target = {kind = "build"}
	if interact_target.is_empty():
		return
	match interact_target.kind:
		"berry":
			prompt_text = "[E] 吃浆果（饭 +%d）" % int(BERRY_FOOD)
		"pond":
			prompt_text = "[E] 喝水（水 +%d）" % int(WATER_DRINK)
		"tree":
			prompt_text = "[E] 拾枯枝"
		"build":
			prompt_text = "[E] 建营火（枝条 ×%d）" % CAMPFIRE_COST

func _do_interact() -> void:
	if interact_target.is_empty():
		return
	match interact_target.kind:
		"berry":
			var i: int = interact_target.index
			if berry_stock[i] > 0:
				berry_stock[i] -= 1
				berries_eaten += 1
				hunger = minf(HUNGER_MAX, hunger + BERRY_FOOD)
				prompt_text = ""
		"pond":
			drinks += 1
			thirst = minf(THIRST_MAX, thirst + WATER_DRINK)
			prompt_text = ""
		"tree":
			var i: int = interact_target.index
			if tree_stock[i] > 0:
				tree_stock[i] -= 1
				branches += 1
				prompt_text = ""
		"build":
			if branches >= CAMPFIRE_COST and not campfire_built:
				branches -= CAMPFIRE_COST
				campfire_built = true
				_push_banner("营火燃起来了——夜晚的火光能护你周全。")

func _push_banner(t: String) -> void:
	banner_text = t
	banner_age = 0.0

func _die() -> void:
	phase = "dead"
	if dino_portrait:
		dino_portrait.visible = false
	var style: Dictionary = END_STYLES[end_style]
	var coda: String = style.lines.get("lose", style.lines.get("win", ""))
	end_body.text = ""
	for e in events_flow():
		end_body.text += "· " + e + "\n"
	end_body.text += "\n—— 本局叙事：%s ——" % style.name
	if coda != "":
		end_body.text += "\n「%s」" % coda
	end_body.text += "\n—— 你存活了 %d 天 %d 秒 · 吃了 %d 颗浆果 · 喝水 %d 次 · 建起营火 %s ——" % [day_num, int(day_time), berries_eaten, drinks, "是" if campfire_built else "否"]
	end_panel.visible = true

func events_flow() -> Array:
	var out: Array = []
	out.append("第 1 天，火山在黄昏中爆发，你从灰烬里醒来。")
	if campfire_built:
		out.append("你燃起了营火——夜里的火光护住了你。")
	else:
		out.append("没有火。火山灰在夜里无声落下。")
	out.append("你一共存活了 %d 天。" % day_num)
	return out

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color("2b2a33"))
	draw_rect(Rect2(0, 0, 560, 540), Color("31323b"))
	draw_rect(Rect2(560, 0, 400, 540), Color("3a3236"))
	draw_rect(Rect2(760, 40, 200, 160), Color("453338"))
	var vx := VOLCANO_POS.x
	var vy := VOLCANO_POS.y
	draw_polygon(PackedVector2Array([Vector2(vx - 70, vy + 60), Vector2(vx + 70, vy + 60), Vector2(vx, vy - 40)]),
		PackedColorArray([Color("5a4448") if not is_night else Color("7a3b32")]))
	if is_night:
		draw_circle(Vector2(vx, vy - 30), 12.0 + 2.0 * sin(pulse), Color(1.0, 0.5, 0.2, 0.8))
	for p in PONDS:
		draw_circle(p, 34.0, Color("2f5d8a"))
		draw_circle(p, 26.0, Color("3f7fb5"))
	for i in BERRIES.size():
		var pos: Vector2 = BERRIES[i]
		draw_circle(pos + Vector2(0, 6), 16.0, Color("2e4d2e"))
		if berry_stock[i] > 0:
			for b in berry_stock[i]:
				var ang: float = b * TAU / 3.0
				draw_circle(pos + Vector2(cos(ang) * 10, sin(ang) * 10 - 4), 4.0, Color("e05555"))
	for i in TREES.size():
		var pos: Vector2 = TREES[i]
		draw_line(pos + Vector2(0, 14), pos + Vector2(0, -26), Color("6b5a4a"), 6.0)
		draw_line(pos + Vector2(0, -10), pos + Vector2(14, -30), Color("6b5a4a"), 4.0)
		for b in tree_stock[i]:
			draw_circle(pos + Vector2(-12 + b * 10, -28), 3.0, Color("a1887f"))
	if campfire_built:
		draw_line(campfire_pos + Vector2(-10, 8), campfire_pos + Vector2(10, -2), Color("6b5a4a"), 5.0)
		draw_line(campfire_pos + Vector2(-10, -2), campfire_pos + Vector2(10, 8), Color("6b5a4a"), 5.0)
		var flame := 0.7 + 0.3 * sin(pulse * 2.0)
		draw_circle(campfire_pos, 8.0, Color(1.0, 0.6, 0.2, flame))
		draw_circle(campfire_pos, 4.0, Color(1.0, 0.9, 0.4, flame))
	draw_circle(NEST_POS, 20.0, Color("4a4438"))
	draw_arc(NEST_POS, 24.0, 0, TAU, 24, Color("5a5446"), 2.0)
	if night_amount > 0.0:
		draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(0.05, 0.03, 0.1, 0.72 * night_amount))
		if campfire_built:
			for r in [240.0, 180.0, 120.0]:
				draw_circle(campfire_pos, r, Color(1.0, 0.85, 0.5, 0.05 * night_amount))
			draw_circle(campfire_pos, 60.0, Color(1.0, 0.85, 0.5, 0.08 * night_amount))
	if not interact_target.is_empty() and phase == "play":
		var pos := Vector2.ZERO
		match interact_target.kind:
			"berry":
				pos = BERRIES[interact_target.index]
			"pond":
				pos = PONDS[interact_target.index]
			"tree":
				pos = TREES[interact_target.index]
			"build":
				pos = campfire_pos
		draw_arc(pos, 40.0 + 3.0 * sin(pulse), 0, TAU, 24, Color("ffd54f", 0.7), 2.0)
	if hp_bar_flash > 0.0:
		draw_rect(Rect2(0, 0, VIEW.x, 4), Color(0.9, 0.2, 0.2, 0.6 * hp_bar_flash))
	if prompt_text != "" and phase == "play":
		var pw := FONT.get_string_size(prompt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var px: float = clampf(player_pos.x - pw / 2, 8, VIEW.x - pw - 8)
		draw_rect(Rect2(px - 6, player_pos.y - 52, pw + 12, 22), Color(0, 0, 0, 0.55))
		draw_string(FONT, Vector2(px, player_pos.y - 36), prompt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffe082"))
	draw_string(FONT, Vector2(860, 20), "E=交互", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8b94a7"))
