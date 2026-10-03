extends Node2D
## 岩浆降温的小人国度 v3：温度不断上升，建造/升级浇水设施降温，撑过 60 秒。
## 随进度涌现随机 NPC 村民帮忙提水。对应 Miro 玩法块 demo-03。
## v2（Miro《最后的溪流》扩展）：难度阶段 / 酸雨事件 / 村民职业与升级
## v3（ChatGPT 监督评审指引，reviews/chatgpt-demo-03-full.md）：
##   酸雨改双向 modifier：酸雨 8 秒内 设施降温 ×0.6、村民降温 ×1.5（不再直接加温度）——
##   让"升级设施 vs 升级村民"的机会成本随天气变化，验证 局势变化→策略迁移。
##   3 秒酸雨预警：prediction → preparation → consequence。
##   消费遥测：spend_log 记录每次建造/升级/招募村民的花费时刻，供三窗口策略迁移分析。
## v4（用户"停滞转向阶梯"裁定：迭代美术）：纯表现层翻新，零规则/平衡改动——
##   渐变星空+闪烁星、火山剪影（火口辉光+火星）、岩浆气泡（辉光随温度增强）、
##   小屋窗灯、村民踱步、酸雨落地震屏+闪电白幕、压制/强化状态徽标（▼设施/▲村民，
##   即 ChatGPT 条件性修改#2 的视觉层）、预警药丸横幅、三阶段时间进度条。
## 纯代码实现、无外部资源。

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
const NPC_UP_COST := 30
const NPC_UP_COOL := 0.7

## 难度阶段：until = 阶段结束时刻，base/slope = 升温速率
const PHASES := [
	{"until": 20.0, "base": 2.0, "slope": 0.04, "name": "早期威胁"},
	{"until": 40.0, "base": 2.5, "slope": 0.06, "name": "中期危局"},
	{"until": 999.0, "base": 3.2, "slope": 0.10, "name": "灭亡倒计时"},
]

## 酸雨事件：起始时刻（±3s 随机抖动）、基础时长；预警提前量；双向 modifier（ChatGPT v3 指引）
const ACID_TIMES := [22.0, 46.0]
const ACID_JITTER := 3.0
const ACID_DUR := 8.0
const ACID_WARN := 3.0
const ACID_TOWER_MULT := 0.6   # 酸雨期间设施降温效率
const ACID_NPC_MULT := 1.5     # 酸雨期间村民降温效率

## 村民职业（Miro 小人系统的 demo 裁剪版）
const PROFS := [
	{"name": "工程师", "color": "ffd54f", "desc": "建造/升级费用 -5💧"},
	{"name": "植物学家", "color": "81c784", "desc": "额外降温 +0.4/s"},
	{"name": "气象学家", "color": "64b5f6", "desc": "酸雨时长减半"},
	{"name": "搬运工", "color": "e0e0e0", "desc": "水滴收入 +1.5/s"},
]

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
var npcs := []                 # {name, x, phase, prof, pcol, level}
var npc_next := 0
var acid_events := []          # {start, announced, warned}
var spend_log := []            # {t, kind: build/upgrade/promote, amount} 消费遥测
var toasts := []               # {text, x, y, age}
var state := "play"            # play / win / lose
var pulse := 0.0
var acid_was_on := false
var shake := 0.0               # 纯装饰：酸雨落地屏幕震动
var flash := 0.0               # 纯装饰：闪电白幕

var overlay: CanvasLayer
var overlay_title: Label
var overlay_body: Label


func _ready() -> void:
	_build_overlay()
	_setup_round()


func _setup_round() -> void:
	heat = 40.0
	water = 0.0
	elapsed = 0.0
	towers = [0, 0, 0]
	npcs = []
	npc_next = 0
	toasts = []
	spend_log = []
	acid_was_on = false
	acid_events = [
		{"start": ACID_TIMES[0] + randf_range(-ACID_JITTER, ACID_JITTER), "announced": false, "warned": false},
		{"start": ACID_TIMES[1] + randf_range(-ACID_JITTER, ACID_JITTER), "announced": false, "warned": false},
	]
	state = "play"
	if overlay_title:
		overlay_title.get_parent().visible = false


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
	again.pressed.connect(_setup_round)
	panel.add_child(again)
	overlay_title.get_parent().visible = false


# ---------------- 查询 ----------------

func _has_prof(p: String) -> bool:
	for n in npcs:
		if n.prof == p:
			return true
	return false


func _build_cost() -> int:
	return BUILD_COST - (5 if _has_prof("工程师") else 0)


func _upgrade_cost() -> int:
	return UPGRADE_COST - (5 if _has_prof("工程师") else 0)


func _acid_dur() -> float:
	return ACID_DUR * (0.5 if _has_prof("气象学家") else 1.0)


func _acid_active() -> bool:
	for e in acid_events:
		if elapsed >= float(e.start) and elapsed < float(e.start) + _acid_dur():
			return true
	return false


func _phase() -> Dictionary:
	for p in PHASES:
		if elapsed < float(p.until):
			return p
	return PHASES[PHASES.size() - 1]


# ---------------- 交互 ----------------

func _unhandled_input(event: InputEvent) -> void:
	if state != "play":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		# 先看是否点了村民（升级）
		for n in npcs:
			if Rect2(float(n.x) - 22.0, 326.0, 44.0, 60.0).has_point(pos):
				_try_promote(n)
				return
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
	var c := _build_cost()
	if water < c:
		_toast("水滴不够（需要 %d💧）" % c, SLOTS[i].position)
		return
	water -= c
	towers[i] = 1
	spend_log.append({t = elapsed, kind = "build", amount = c})
	_toast("浇水设施建成！降温 %s/s" % COOL_L1, SLOTS[i].position)


func _try_upgrade(i: int) -> void:
	var c := _upgrade_cost()
	if water < c:
		_toast("升级需要 %d💧" % c, SLOTS[i].position)
		return
	water -= c
	towers[i] = 2
	spend_log.append({t = elapsed, kind = "upgrade", amount = c})
	_toast("设施升级！降温 %s/s" % COOL_L2, SLOTS[i].position)


func _try_promote(n: Dictionary) -> void:
	if n.level >= 1:
		_toast("%s 已经是精英村民啦" % n.name, Vector2(float(n.x) - 40.0, 330.0))
		return
	if water < NPC_UP_COST:
		_toast("升级村民需要 %d💧" % NPC_UP_COST, Vector2(float(n.x) - 40.0, 330.0))
		return
	water -= NPC_UP_COST
	n.level = 1
	spend_log.append({t = elapsed, kind = "promote", amount = NPC_UP_COST})
	_toast("%s 升级为精英村民！降温 +%.1f/s" % [n.name, NPC_UP_COOL], Vector2(float(n.x) - 60.0, 330.0))


func _toast(text: String, pos: Vector2) -> void:
	toasts.append({text = text, x = pos.x, y = pos.y - 10, age = 0.0})


# ---------------- 每帧 ----------------

func _process(delta: float) -> void:
	pulse += delta * 4.0
	shake = maxf(0.0, shake - delta * 2.2)
	flash = maxf(0.0, flash - delta * 1.6)
	for t in toasts:
		t.age += delta
	toasts = toasts.filter(func(t): return t.age < 2.0)
	if state != "play":
		queue_redraw()
		return
	elapsed += delta

	# 温度：阶段化上升；酸雨不直接加温，而是压制设施/放大村民（v3 双向 modifier）
	var ph: Dictionary = _phase()
	var rise: float = float(ph.base) + float(ph.slope) * elapsed
	var acid_on := _acid_active()
	for e in acid_events:
		if not e.warned and elapsed >= float(e.start) - ACID_WARN and elapsed < float(e.start):
			e.warned = true
			_toast("☔ 酸雨将在 %d 秒后到达！趁早决定水滴花在哪" % int(ceil(float(e.start) - elapsed)), Vector2(VIEW.x / 2 - 110, 90))
		if not e.announced and elapsed >= float(e.start):
			e.announced = true
			shake = 1.0
			flash = 0.8
			_toast("☔ 酸雨来袭！设施降温 ×%s · 村民降温 ×%s" % [ACID_TOWER_MULT, ACID_NPC_MULT], Vector2(VIEW.x / 2 - 110, 90))
			break
	acid_was_on = acid_on

	# 冷却：设施 + 村民（职业加成 + 精英升级）；酸雨期间双向修正
	var tower_cool := 0.0
	for t in towers:
		tower_cool += COOL_L1 if t == 1 else (COOL_L2 if t == 2 else 0.0)
	var npc_cool := 0.0
	for n in npcs:
		npc_cool += NPC_COOL + (0.4 if n.prof == "植物学家" else 0.0) + float(n.level) * NPC_UP_COOL
	var cool := tower_cool * (ACID_TOWER_MULT if acid_on else 1.0) + npc_cool * (ACID_NPC_MULT if acid_on else 1.0)
	heat = clamp(heat + (rise - cool) * delta, 0.0, 130.0)

	# 水滴收入：基础 + 村民（搬运工加成）
	var income := 5.0
	for n in npcs:
		income += 1.0 + (1.5 if n.prof == "搬运工" else 0.0)
	water += income * delta

	# 村民涌现（随机职业）
	if npc_next < NPC_TIMES.size() and elapsed >= NPC_TIMES[npc_next]:
		var prof: Dictionary = PROFS[randi() % PROFS.size()]
		var n := {
			"name": NPC_NAMES[npc_next % NPC_NAMES.size()],
			"x": randf_range(200, 760),
			"phase": randf() * TAU,
			"prof": prof.name,
			"pcol": prof.color,
			"level": 0,
		}
		npcs.append(n)
		_toast("村民 %s（%s）加入：%s" % [n.name, prof.name, prof.desc], Vector2(n.x - 110, 320))
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
			"村民们的名字会被写进歌谣：" + ", ".join(npcs.map(func(n): return n.name + ("★" if n.level >= 1 else ""))) if npcs.size() > 0 else "这一夜，全靠你一个人扛住了。"]
		overlay_title.add_theme_color_override("font_color", Color("66bb6a"))
	else:
		overlay_title.text = "🔥 岩浆吞没了国度……"
		overlay_body.text = "温度突破了 100 度（坚持了 %d 秒，%s）。\n提示：开局尽快建第一座设施，15 秒前建起第二座；\n听到酸雨预警就想想：该升级设施还是投资村民？酸雨中村民更强！" % [
			int(elapsed), str(_phase().name)]
		overlay_title.add_theme_color_override("font_color", Color("ef5350"))


# ---------------- 绘制 ----------------

func _draw() -> void:
	# v4 美术层（纯表现，零规则改动）：屏幕震动 / 渐变星空 / 火山 / 岩浆气泡 / 状态标记 / 闪电
	var so := Vector2(randf_range(-1.0, 1.0) * 5.0 * shake, randf_range(-1.0, 1.0) * 4.0 * shake)
	draw_set_transform(so, 0.0, Vector2.ONE)
	var acid_on := _acid_active()

	# 夜空：垂直渐变 + 闪烁星
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(VIEW.x, 0), Vector2(VIEW.x, 250), Vector2(0, 250)]),
		PackedColorArray([Color("2b1738"), Color("2b1738"), Color("55293b"), Color("55293b")])
	)
	for k in 26:
		var sx := fposmod(k * 173.7, VIEW.x)
		var sy := fposmod(k * 97.3, 170.0) + 8.0
		var tw: float = 0.22 + 0.3 * (0.5 + 0.5 * sin(pulse * 1.7 + k * 1.3))
		draw_circle(Vector2(sx, sy), 1.1 + (k % 3) * 0.4, Color(1, 1, 1, tw))
	# 远山火山（右侧剪影 + 火口辉光 + 上升火星）
	draw_polygon(
		PackedVector2Array([Vector2(600, 252), Vector2(828, 104), Vector2(1056, 252)]),
		PackedColorArray([Color("1c1118"), Color("241522"), Color("1c1118")])
	)
	var crater_glow: float = 0.5 + 0.3 * sin(pulse * 1.3)
	draw_circle(Vector2(828, 110), 24.0, Color(1.0, 0.4, 0.12, crater_glow * 0.25))
	draw_circle(Vector2(828, 110), 10.0, Color(1.0, 0.45, 0.15, crater_glow * 0.85))
	for k in 5:
		var ey := fposmod(pulse * 26.0 + k * 23.0, 118.0)
		draw_circle(Vector2(828.0 + 7.0 * sin(pulse * 2.0 + k * 2.1), 110.0 - ey), 2.0, Color(1.0, 0.55, 0.2, (1.0 - ey / 118.0) * 0.8))

	# 地面
	draw_rect(Rect2(0, 250, VIEW.x, 210), Color("241a1c"))
	draw_rect(Rect2(0, 250, VIEW.x, 4), Color("3a2a2c"))
	# 远处的小屋（窗户透光）
	for k in 4:
		var hx := 60 + k * 210.0
		var lamp: float = 0.55 + 0.35 * sin(pulse * 1.1 + k * 1.9)
		draw_rect(Rect2(hx, 330, 46, 30), Color("4a3b45"))
		draw_polygon(PackedVector2Array([Vector2(hx - 6, 330), Vector2(hx + 52, 330), Vector2(hx + 23, 306)]), PackedColorArray([Color("5d4550")]))
		draw_rect(Rect2(hx + 18, 340, 9, 8), Color("ffd54f", lamp * 0.8))

	# 岩浆河：辉光随温度增强 + 翻滚上升的气泡
	var heat_frac: float = clamp(heat / 130.0, 0.0, 1.0)
	var glow := 0.5 + 0.2 * sin(pulse)
	draw_rect(Rect2(0, 462, VIEW.x, 78), Color("d84315"))
	draw_rect(Rect2(0, 462, VIEW.x, 78), Color(1.0, 0.45, 0.1, glow * 0.25 + heat_frac * 0.3))
	draw_rect(Rect2(0, 478, VIEW.x, 42), Color("ff7043", 0.4 + heat_frac * 0.25))
	for k in 12:
		var cyc := fposmod(pulse * 26.0 + k * 37.0, 46.0)
		var lx := fposmod(k * 89.0 + pulse * 14.0, VIEW.x)
		draw_circle(Vector2(lx, 506.0 - cyc), 2.0 + 2.6 * (cyc / 46.0), Color("ffab91", (1.0 - cyc / 46.0) * 0.85))

	# 设施槽位（酸雨中被压制 → 蒙暗 + ▼ 紫色徽标）
	for i in SLOTS.size():
		var r: Rect2 = SLOTS[i]
		var t: int = towers[i]
		if t == 0:
			draw_rect(r, Color(1, 1, 1, 0.04))
			draw_rect(r, Color("8b94a7"), false, 2)
			draw_string(FONT, r.position + Vector2(14, 34), "空槽位", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("8b94a7"))
			draw_string(FONT, r.position + Vector2(14, 56), "建造 %d💧" % _build_cost(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("4fc3f7"))
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
			if acid_on and state == "play":
				# 压制标记：整体蒙暗 + ▼
				draw_rect(Rect2(bx - 8, r.position.y + r.size.y - 20 - h, bw + 16, h + 18), Color(0.08, 0.04, 0.16, 0.4))
				var tcx := r.position.x + r.size.x - 14.0
				draw_circle(Vector2(tcx, r.position.y + 15), 9.0, Color("4a148c", 0.92))
				draw_colored_polygon(PackedVector2Array([Vector2(tcx - 4, r.position.y + 11), Vector2(tcx + 4, r.position.y + 11), Vector2(tcx, r.position.y + 19)]), Color("b39ddb"))
			# 洒水动画
			if state == "play":
				for k in 4:
					var dx := r.position.x + 18 + k * 28.0
					var dy := r.position.y + 10 + fposmod(pulse * 40 + k * 17, 26)
					draw_circle(Vector2(dx, dy), 2.5, Color(0.4, 0.8, 1.0, 0.8))

	# 村民小人（职业配色水桶 + 左右踱步 + 精英星 + 酸雨强化 ▲）
	for n in npcs:
		var bob := 3.0 * sin(pulse * 2.0 + n.phase)
		var px: float = n.x + 2.5 * sin(pulse * 2.4 + n.phase)
		var py := 356.0 + bob
		draw_circle(Vector2(px, py - 18), 7, Color("ffcc80"))          # 头
		draw_rect(Rect2(px - 6, py - 10, 12, 22), Color("90a4ae"))      # 身体
		draw_rect(Rect2(px - 10, py - 6, 4, 12), Color(n.pcol))         # 职业色水桶
		if n.level >= 1:
			draw_circle(Vector2(px, py - 28), 3.0, Color("ffd54f"))     # 精英星
		if acid_on and state == "play":
			# 强化标记：▲ 绿色徽标
			draw_circle(Vector2(px, py - 36), 8.0, Color("1b5e20", 0.9))
			draw_colored_polygon(PackedVector2Array([Vector2(px - 4, py - 32), Vector2(px + 4, py - 32), Vector2(px, py - 40)]), Color("a5d6a7"))
		var label := "%s·%s%s" % [n.name, n.prof, "★" if n.level >= 1 else ""]
		draw_string(FONT, Vector2(px - 38, py + 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c6cddc"))

	# 酸雨预警（药丸底横幅 + 倒计时）
	if state == "play":
		for e in acid_events:
			var s := float(e.start)
			if elapsed >= s - ACID_WARN and elapsed < s:
				var blink := 0.75 + 0.25 * sin(pulse * 6.0)
				draw_rect(Rect2(VIEW.x / 2 - 172, 48, 344, 26), Color(0.12, 0.06, 0.18, 0.82))
				draw_rect(Rect2(VIEW.x / 2 - 172, 48, 344, 26), Color("ce93d8", blink), false, 1.5)
				draw_string(FONT, Vector2(VIEW.x / 2 - 130, 66), "☔ 酸雨将在 %d 秒后到达——先想好水滴花在哪！" % int(ceil(s - elapsed)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("efc3f5"))
	# 酸雨（紫雨 + 双向修正提示）
	if acid_on and state == "play":
		draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(0.55, 0.25, 0.75, 0.08))
		for k in 26:
			var rx := fposmod(k * 41.0 + pulse * 60.0, VIEW.x + 40.0) - 20.0
			var ry := fposmod(k * 97.0 + pulse * 100.0, VIEW.y)
			draw_line(Vector2(rx, ry), Vector2(rx - 5.0, ry + 15.0), Color(0.78, 0.45, 0.95, 0.5), 2.0)
		draw_rect(Rect2(VIEW.x / 2 - 175, 48, 350, 26), Color(0.12, 0.06, 0.18, 0.82))
		draw_rect(Rect2(VIEW.x / 2 - 175, 48, 350, 26), Color("ce93d8"), false, 1.5)
		draw_string(FONT, Vector2(VIEW.x / 2 - 165, 66), "☔ 酸雨中：设施降温 ×%s · 村民降温 ×%s" % [ACID_TOWER_MULT, ACID_NPC_MULT], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ce93d8"))
	# 闪电白幕（酸雨落地瞬间）
	if flash > 0.0:
		draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(0.85, 0.75, 1.0, flash * 0.28))

	# 温度条
	var bw2 := 360.0
	var bx2 := (VIEW.x - bw2) / 2
	draw_rect(Rect2(bx2 - 2, 12, bw2 + 4, 22), Color(0, 0, 0, 0.5))
	var frac: float = clamp(heat / 100.0, 0.0, 1.0)
	var bar_col := Color("66bb6a").lerp(Color("ef5350"), frac)
	draw_rect(Rect2(bx2, 14, bw2 * frac, 18), bar_col)
	draw_rect(Rect2(bx2 - 2, 12, bw2 + 4, 22), Color("e8ecf4"), false, 2)
	draw_string(FONT, Vector2(bx2 + 6, 27), "温度 %d°" % int(heat), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("111") if frac < 0.6 else Color("fff"))
	# 时间进度条（三阶段配色 + 当前时刻游标）
	var tp: float = clamp(elapsed / GAME_TIME, 0.0, 1.0)
	var seg_cols: Array = [Color("66bb6a"), Color("ffd54f"), Color("ef5350")]
	for sgi in 3:
		var seg_w := bw2 / 3.0
		draw_rect(Rect2(bx2 + seg_w * sgi, 38, seg_w - 2.0, 4), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(bx2 + seg_w * sgi, 38, minf(seg_w * tp - seg_w * sgi, seg_w - 2.0), 4), (seg_cols[sgi] as Color))
	draw_rect(Rect2(bx2 + bw2 * tp - 1.0, 35, 2.0, 10), Color("ffffff"))
	# 水滴与时间
	draw_string(FONT, Vector2(16, 28), "💧 %d" % int(water), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("4fc3f7"))
	draw_string(FONT, Vector2(VIEW.x - 110, 28), "⏱ %d/%d 秒" % [int(elapsed), int(GAME_TIME)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e8ecf4"))
	# 阶段横幅
	var ph: Dictionary = _phase()
	var pcol := Color("aed581")
	if elapsed >= 40.0:
		pcol = Color("ef5350")
	elif elapsed >= 20.0:
		pcol = Color("ffd54f")
	draw_string(FONT, Vector2(VIEW.x - 250, 50), "阶段：%s" % ph.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, pcol)
	# 提示
	if state == "play" and elapsed < 6.0:
		draw_string(FONT, Vector2(230, 84), "温度会越升越快！点击空槽位建造浇水设施，撑过 60 秒！", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffcc80"))
	# 浮动提示
	for t in toasts:
		var a: float = clamp(2.0 - t.age, 0.0, 1.0)
		draw_string(FONT, Vector2(t.x, t.y), t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a))
