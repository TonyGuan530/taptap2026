extends Node2D
## 岩浆降温的小人国度：温度不断上升，建造/升级浇水设施降温，撑过 60 秒。
## 随进度涌现随机 NPC 村民帮忙提水。对应 Miro 玩法块 demo-03。
## 纯代码实现、无外部资源；点击槽位建造（20💧）/升级（40💧）。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")

const GAME_TIME := 60.0
const BUILD_COST := 20
const UPGRADE_COST := 40
const COOL_L1 := 2.0
const COOL_L2 := 5.0
const NPC_COOL := 0.8
const NPC_TIMES := [20.0, 40.0]
const NPC_NAMES := ["阿岩", "小露", "阿灰", "石头婶", "水生"]

## 设施槽位
const SLOTS := [
	Rect2(120, 380, 120, 75),
	Rect2(420, 380, 120, 75),
	Rect2(720, 380, 120, 75),
]

var heat := 40.0
var water := 0.0
var elapsed := 0.0
var towers := [0, 0, 0]        # 每槽位等级 0/1/2
var npcs := []                 # {name, x, phase}
var npc_next := 0
var toasts := []               # {text, x, y, age}
var state := "play"            # play / win / lose
var pulse := 0.0

var overlay: CanvasLayer
var overlay_title: Label
var overlay_body: Label


func _ready() -> void:
	_build_overlay()


func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	add_child(overlay)
	var panel := Panel.new()
	panel.position = Vector2(230, 170)
	panel.size = Vector2(500, 200)
	panel.visible = false
	overlay.add_child(panel)
	overlay_title = Label.new()
	overlay_title.position = Vector2(24, 20)
	overlay_title.add_theme_font_size_override("font_size", 24)
	panel.add_child(overlay_title)
	overlay_body = Label.new()
	overlay_body.position = Vector2(24, 66)
	overlay_body.size = Vector2(452, 70)
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body.add_theme_font_size_override("font_size", 14)
	panel.add_child(overlay_body)
	var again := Button.new()
	again.text = "再守一次"
	again.position = Vector2(24, 146)
	again.size = Vector2(160, 38)
	again.pressed.connect(_restart)
	panel.add_child(again)
	overlay_title.get_parent().visible = false


# ---------------- 交互 ----------------

func _unhandled_input(event: InputEvent) -> void:
	if state != "play":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		for i in SLOTS.size():
			if (Rect2(SLOTS[i]) as Rect2).has_point(pos):
				if towers[i] == 0:
					_try_build(i)
				elif towers[i] == 1:
					_try_upgrade(i)
				else:
					_toast("这座设施已经满级啦", SLOTS[i].position)
				return


func _try_build(i: int) -> void:
	if water < BUILD_COST:
		_toast("水滴不够（需要 %d💧）" % BUILD_COST, SLOTS[i].position)
		return
	water -= BUILD_COST
	towers[i] = 1
	_toast("浇水设施建成！降温 %s/s" % COOL_L1, SLOTS[i].position)


func _try_upgrade(i: int) -> void:
	if water < UPGRADE_COST:
		_toast("升级需要 %d💧" % UPGRADE_COST, SLOTS[i].position)
		return
	water -= UPGRADE_COST
	towers[i] = 2
	_toast("设施升级！降温 %s/s" % COOL_L2, SLOTS[i].position)


func _toast(text: String, pos: Vector2) -> void:
	toasts.append({text = text, x = pos.x, y = pos.y - 10, age = 0.0})


func _restart() -> void:
	heat = 40.0
	water = 0.0
	elapsed = 0.0
	towers = [0, 0, 0]
	npcs = []
	npc_next = 0
	toasts = []
	state = "play"
	overlay_title.get_parent().visible = false


# ---------------- 每帧 ----------------

func _process(delta: float) -> void:
	pulse += delta * 4.0
	for t in toasts:
		t.age += delta
	toasts = toasts.filter(func(t): return t.age < 2.0)
	if state != "play":
		queue_redraw()
		return
	elapsed += delta

	# 温度：随时间加速上升
	var rise := 2.5 + 0.06 * elapsed
	# 冷却：设施 + 村民
	var cool := 0.0
	for t in towers:
		cool += COOL_L1 if t == 1 else (COOL_L2 if t == 2 else 0.0)
	cool += npcs.size() * NPC_COOL
	heat = clamp(heat + (rise - cool) * delta, 0.0, 130.0)

	# 水滴收入
	var income := 5.0 + npcs.size() * 1.0
	water += income * delta

	# 村民涌现
	if npc_next < NPC_TIMES.size() and elapsed >= NPC_TIMES[npc_next]:
		var n := {"name": NPC_NAMES[npc_next % NPC_NAMES.size()], "x": randf_range(200, 760), "phase": randf() * TAU}
		npcs.append(n)
		_toast("村民 %s 提着水桶加入救火！（全体降温 +%s/s）" % [n.name, NPC_COOL], Vector2(n.x - 60, 320))
		npc_next += 1

	# 胜负
	if heat >= 100.0:
		state = "lose"
		_show_end(false)
	elif elapsed >= GAME_TIME:
		state = "win"
		_show_end(true)
	queue_redraw()


func _show_end(win: bool) -> void:
	overlay_title.get_parent().visible = true
	if win:
		overlay_title.text = "🏡 国度守住了！"
		overlay_body.text = "60 秒过去，岩浆在大家的努力下退了回去。\n剩余温度 %d 度 · 村民 %d 人 · 水滴 %d\n%s" % [
			int(heat), npcs.size(), int(water),
			"村民们的名字会被写进歌谣：" + ", ".join(npcs.map(func(n): return n.name)) if npcs.size() > 0 else "这一夜，全靠你一个人扛住了。"]
		overlay_title.add_theme_color_override("font_color", Color("66bb6a"))
	else:
		overlay_title.text = "🔥 岩浆吞没了国度……"
		overlay_body.text = "温度突破了 100 度（坚持了 %d 秒）。\n提示：开局尽快建第一座设施，15 秒前建起第二座，\n然后攒水滴把设施升到 2 级。村民会出现帮你！" % int(elapsed)
		overlay_title.add_theme_color_override("font_color", Color("ef5350"))


# ---------------- 绘制 ----------------

func _draw() -> void:
	# 天空与地面
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color("1d1420"))
	draw_rect(Rect2(0, 250, VIEW.x, 210), Color("241a1c"))
	draw_rect(Rect2(0, 250, VIEW.x, 4), Color("3a2a2c"))
	# 远处的小屋
	for k in 4:
		var hx := 60 + k * 210.0
		draw_rect(Rect2(hx, 330, 46, 30), Color("4a3b45"))
		draw_polygon(PackedVector2Array([Vector2(hx - 6, 330), Vector2(hx + 52, 330), Vector2(hx + 23, 306)]), PackedColorArray([Color("5d4550")]))
	# 岩浆河（脉动）
	var glow := 0.5 + 0.2 * sin(pulse)
	draw_rect(Rect2(0, 462, VIEW.x, 78), Color("d84315"))
	draw_rect(Rect2(0, 462, VIEW.x, 78), Color(1.0, 0.45, 0.1, glow * 0.35))
	for k in 10:
		var lx := fposmod(k * 107 + pulse * 22, VIEW.x)
		draw_circle(Vector2(lx, 486 + (k % 3) * 16), 5, Color("ffab91", 0.7))
	# 设施槽位
	for i in SLOTS.size():
		var r: Rect2 = SLOTS[i]
		var t: int = towers[i]
		if t == 0:
			draw_rect(r, Color(1, 1, 1, 0.04))
			draw_rect(r, Color("8b94a7"), false, 2)
			draw_string(FONT, r.position + Vector2(14, 34), "空槽位", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("8b94a7"))
			draw_string(FONT, r.position + Vector2(14, 56), "建造 %d💧" % BUILD_COST, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("4fc3f7"))
		else:
			var h := 34.0 if t == 1 else 52.0
			var bw := 26.0 if t == 1 else 34.0
			var bx := r.position.x + r.size.x / 2 - bw / 2
			# 水塔：底座 + 塔身 + 水箱
			draw_rect(Rect2(bx - 6, r.position.y + r.size.y - 14, bw + 12, 12), Color("56789a"))
			draw_rect(Rect2(bx + bw / 2 - 3, r.position.y + r.size.y - 14 - (h - 22), 6, h - 22), Color("56789a"))
			draw_rect(Rect2(bx, r.position.y + r.size.y - 14 - h, bw, 24), Color("4fc3f7") if t == 2 else Color("7fb7d9"))
			draw_rect(Rect2(bx + 4, r.position.y + r.size.y - 14 - h + 4, bw - 8, 8), Color("e1f5fe"))
			if t == 2:
				draw_string(FONT, r.position + Vector2(8, 20), "II 级", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffd54f"))
			# 洒水动画
			if state == "play":
				for k in 4:
					var dx := r.position.x + 18 + k * 28.0
					var dy := r.position.y + 10 + fposmod(pulse * 40 + k * 17, 26)
					draw_circle(Vector2(dx, dy), 2.5, Color(0.4, 0.8, 1.0, 0.8))
	# 村民小人
	for n in npcs:
		var bob := 3.0 * sin(pulse * 2.0 + n.phase)
		var px: float = n.x
		var py := 356.0 + bob
		draw_circle(Vector2(px, py - 18), 7, Color("ffcc80"))          # 头
		draw_rect(Rect2(px - 6, py - 10, 12, 22), Color("90a4ae"))      # 身体
		draw_rect(Rect2(px - 10, py - 6, 4, 12), Color("90a4ae"))       # 水桶
		draw_string(FONT, Vector2(px - 24, py + 26), n.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c6cddc"))
	# 温度条
	var bw2 := 360.0
	var bx2 := (VIEW.x - bw2) / 2
	draw_rect(Rect2(bx2 - 2, 12, bw2 + 4, 22), Color(0, 0, 0, 0.5))
	var frac: float = clamp(heat / 100.0, 0.0, 1.0)
	var bar_col := Color("66bb6a").lerp(Color("ef5350"), frac)
	draw_rect(Rect2(bx2, 14, bw2 * frac, 18), bar_col)
	draw_rect(Rect2(bx2 - 2, 12, bw2 + 4, 22), Color("e8ecf4"), false, 2)
	draw_string(FONT, Vector2(bx2 + 6, 27), "温度 %d°" % int(heat), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("111") if frac < 0.6 else Color("fff"))
	# 水滴与时间
	draw_string(FONT, Vector2(16, 28), "💧 %d" % int(water), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("4fc3f7"))
	draw_string(FONT, Vector2(VIEW.x - 110, 28), "⏱ %d/%d 秒" % [int(elapsed), int(GAME_TIME)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e8ecf4"))
	# 提示
	if state == "play" and elapsed < 6.0:
		draw_string(FONT, Vector2(230, 70), "温度会越升越快！点击空槽位建造浇水设施，撑过 60 秒！", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffcc80"))
	# 浮动提示
	for t in toasts:
		var a: float = clamp(2.0 - t.age, 0.0, 1.0)
		draw_string(FONT, Vector2(t.x, t.y), t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a))
