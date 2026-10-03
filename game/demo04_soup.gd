extends Node2D
## SOUP 2.0：和外星生物 DNA 融合改造自身，逃离危险的异星。
## v2：3 个关卡（裂谷长跑/夜翼峡谷/融合之巅）+ DNA 组合效果 + 基因碎片收集与评级。
## 横版跑到右侧逃生舱；3 种 DNA 能力，地形按顺序强制用能力：
## 高台墙(高跳) → 长沟(二段跳) → 黑暗裂谷(荧光，摸黑移速大减) → 组合高墙(高跳+二段跳)。
## 【玩家物理是手写的】AABB 简化解析，不是 move_and_slide——改地形前先读 LEVELS 和碰撞段。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")
const GROUND_Y := 470.0
const GRAV := 1500.0
const WALK := 260.0
const JUMP_V := 560.0

## 每关数据：地形块(x,y,w,h)/融合源/坑/黑暗区/终点/基因碎片。地形设计顺序强制融合：
## L1 高墙→长沟→黑暗裂谷；L2 高墙→组合高墙→黑暗长沟；L3 组合高墙→黑暗双沟→组合高墙。
const LEVELS := [
	{
		name = "裂谷长跑",
		blocks = [
			[0, 470, 1000, 70],
			[1000, 290, 60, 250],      # ① 高台墙：顶 y290，普通跳不够，必须高跳
			[1060, 470, 640, 70],
			[1900, 470, 700, 70],      # ② 长沟 1700→1900：普通跳差一点
			[2900, 470, 150, 70],
			[3050, 470, 300, 70],      # ③ 黑暗裂谷 2600→2900：无荧光摸黑跳不过
		],
		aliens = [
			{id = "highjump", name = "蹦蹦兽", col = Color("ab47bc"), x = 620.0,
				dna = "弹簧腿 DNA", tip = "普通跳变高跳（按住跳跃键跳得更高）"},
			{id = "double", name = "双翼虫", col = Color("4fc3f7"), x = 1500.0,
				dna = "振翅 DNA", tip = "空中可再跳一次（二段跳）"},
			{id = "glow", name = "灯灯菌", col = Color("ffd54f"), x = 2380.0,
				dna = "荧光 DNA", tip = "身体发光，照亮黑暗裂谷"},
		],
		pits = [Rect2(1700, 540, 200, 200), Rect2(2600, 540, 300, 200)],
		dark = Vector2(2340.0, 3600.0),
		goal_x = 3050.0,
		shards = [Vector2(1030, 240), Vector2(1800, 400), Vector2(2750, 280)],
	},
	{
		name = "夜翼峡谷",
		blocks = [
			[0, 470, 700, 70],
			[700, 340, 50, 200],       # 墙1：高跳可翻
			[750, 470, 150, 70],
			[900, 190, 50, 350],       # 组合高墙：顶 y190，高跳不够，需高跳+二段跳
			[950, 470, 500, 70],
			[1750, 470, 600, 70],      # 黑暗长沟 1450→1750：需二段跳+荧光
			[2350, 470, 300, 70],
		],
		aliens = [
			{id = "highjump", name = "蹦蹦兽", col = Color("ab47bc"), x = 400.0,
				dna = "弹簧腿 DNA", tip = "普通跳变高跳"},
			{id = "double", name = "双翼虫", col = Color("4fc3f7"), x = 800.0,
				dna = "振翅 DNA", tip = "空中可再跳一次"},
			{id = "glow", name = "灯灯菌", col = Color("ffd54f"), x = 1350.0,
				dna = "荧光 DNA", tip = "身体发光，照亮黑暗"},
		],
		pits = [Rect2(1450, 540, 300, 200)],
		dark = Vector2(1300.0, 2400.0),
		goal_x = 2350.0,
		shards = [Vector2(925, 140), Vector2(1600, 280), Vector2(2150, 330)],
	},
	{
		name = "融合之巅",
		blocks = [
			[0, 470, 400, 70],
			[400, 200, 50, 340],       # 组合高墙1：顶 y200，需高跳+二段跳
			[450, 470, 450, 70],
			# 组合可选捷径（P0）：上层平台只有超级弹跳能从地面跃上——
			# 普通路线走黑暗双沟（慢、险），上层路线跳过双沟（快）+ 专属碎片
			[700, 170, 120, 20],       # 发射台：普通跳顶277够不到顶170，超级弹跳顶104可落
			[880, 170, 140, 20],       # 上层碎片 (1000,130)
			[1080, 170, 140, 20],      # 末端 1220：走落回主路，连沟2一起省掉
			[1150, 470, 300, 70],      # 黑暗沟1 900→1150：需荧光（高跳可过）
			[1700, 470, 450, 70],      # 黑暗沟2 1450→1700：需荧光+二段跳
			[1850, 230, 50, 240],      # 组合高墙2：顶 y230，需高跳+二段跳
			[2150, 470, 300, 70],
		],
		aliens = [
			{id = "highjump", name = "蹦蹦兽", col = Color("ab47bc"), x = 200.0,
				dna = "弹簧腿 DNA", tip = "普通跳变高跳"},
			{id = "double", name = "双翼虫", col = Color("4fc3f7"), x = 300.0,
				dna = "振翅 DNA", tip = "空中可再跳一次"},
			{id = "glow", name = "灯灯菌", col = Color("ffd54f"), x = 650.0,
				dna = "荧光 DNA", tip = "身体发光，照亮黑暗"},
		],
		pits = [Rect2(900, 540, 250, 200), Rect2(1450, 540, 250, 200)],
		dark = Vector2(700.0, 1800.0),
		goal_x = 2150.0,
		shards = [Vector2(425, 150), Vector2(1025, 280), Vector2(1875, 180), Vector2(1000, 130)],
	},
]

var level_idx := 0
var blocks: Array = []
var aliens: Array = []
var pits: Array = []
var dark := Vector2(2340.0, 3600.0)
var goal_x := 3050.0
var shards: Array = []
var shard_got: Array = []

var px := 120.0
var py := GROUND_Y - 30.0
var vy := 0.0
var on_floor := false
var jumps_used := 0
var dna := {}                    # id -> true
var combos_found := {}           # 组合发现记录（跨关保留，发现式揭晓）
var face := 1.0
var born_dark := false           # 融合荧光后 permanently 亮
var state := "play"              # play / win
var elapsed := 0.0               # 本关用时
var level_shards := 0
var total_shards := 0
var total_time := 0.0
var ratings: Array = []          # 每关评级 S/A/B
var toast := ""
var toast_age := 99.0
var pulse := 0.0
var cam_x := 0.0
var keys := {}
var jump_held := false             # 跳跃边沿检测：长按不会吞掉二段跳

var level_label: Label
var dna_label: Label
var shard_label: Label
var win_btn: Button
var lab_btn: Button
var mode := "campaign"           # campaign / lab（实验房：自由融合测试）
var lab_events := []             # 遥测：融合顺序/组合发现/跳跃足迹
var lab_fuse_n := 0


func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "SOUP 2.0 · 融合外星 DNA，逃出异星"
	title.position = Vector2(16, 8)
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ffd54f"))
	ui.add_child(title)
	var hint := Label.new()
	hint.text = "←/→ 或 A/D 移动 · 空格/W/↑ 跳 · 走近外星生物按 E 融合 · 同时融合多种 DNA……也许会有意外收获"
	hint.position = Vector2(16, 38)
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", 14)
	ui.add_child(hint)
	dna_label = Label.new()
	dna_label.name = "DnaLabel"
	dna_label.position = Vector2(16, 62)
	dna_label.add_theme_font_override("font", FONT)
	dna_label.add_theme_font_size_override("font_size", 14)
	dna_label.add_theme_color_override("font_color", Color("4fc3f7"))
	ui.add_child(dna_label)
	level_label = Label.new()
	level_label.position = Vector2(16, 86)
	level_label.add_theme_font_override("font", FONT)
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", Color("c6cddc"))
	ui.add_child(level_label)
	shard_label = Label.new()
	shard_label.position = Vector2(VIEW.x - 190, 8)
	shard_label.add_theme_font_override("font", FONT)
	shard_label.add_theme_font_size_override("font_size", 13)
	shard_label.add_theme_color_override("font_color", Color("7ee787"))
	ui.add_child(shard_label)
	var esc := Label.new()
	esc.position = Vector2(VIEW.x - 130, 62)
	esc.text = "→ 逃生舱在远方"
	esc.add_theme_font_override("font", FONT)
	esc.add_theme_font_size_override("font_size", 13)
	ui.add_child(esc)
	win_btn = Button.new()
	win_btn.text = "下一关 →"
	win_btn.position = Vector2(VIEW.x / 2 - 90, 330)
	win_btn.size = Vector2(180, 46)
	win_btn.visible = false
	win_btn.add_theme_font_override("font", FONT)
	win_btn.add_theme_font_size_override("font_size", 16)
	win_btn.pressed.connect(_advance)
	ui.add_child(win_btn)
	lab_btn = Button.new()
	lab_btn.text = "实验房：自由融合测试"
	lab_btn.position = Vector2(VIEW.x / 2 - 90, 386)
	lab_btn.size = Vector2(180, 40)
	lab_btn.visible = false
	lab_btn.add_theme_font_override("font", FONT)
	lab_btn.add_theme_font_size_override("font_size", 14)
	lab_btn.pressed.connect(_enter_lab)
	ui.add_child(lab_btn)
	_load_level(0)


func _load_level(i: int) -> void:
	level_idx = i
	var L: Dictionary = LEVELS[i]
	blocks = L.blocks
	aliens = L.aliens
	pits = L.pits
	dark = L.dark
	goal_x = L.goal_x
	shards = L.shards
	shard_got = []
	for s in shards:
		shard_got.append(false)
	px = 120.0
	py = GROUND_Y - 30.0
	vy = 0.0
	jumps_used = 0
	dna = {}
	born_dark = false
	state = "play"
	elapsed = 0.0
	level_shards = 0
	toast = "第 %d/%d 关 · %s" % [i + 1, LEVELS.size(), L.name]
	toast_age = 0.0
	cam_x = 0.0
	dna_label.text = _dna_label_text()
	level_label.text = "第 %d/%d 关 · %s" % [i + 1, LEVELS.size(), L.name]
	_update_shard_label()
	win_btn.visible = false
	lab_btn.visible = false


func _update_shard_label() -> void:
	shard_label.text = "基因碎片 %d/%d · 总计 %d" % [level_shards, shards.size(), total_shards]


func _dna_label_text() -> String:
	if dna.is_empty():
		return "DNA：无（找到外星生物，按 E 融合）"
	var parts := []
	for a in aliens:
		if dna.has(a.id):
			parts.append(a.dna)
	var t := "DNA：已融合 " + " + ".join(parts)
	# 组合效果只在玩家首次融合齐组件后才揭晓（发现式，不开局剧透）
	var combos := []
	if dna.has("highjump") and dna.has("double") and combos_found.has("superjump"):
		combos.append("超级弹跳")
	if dna.has("double") and dna.has("glow") and combos_found.has("nightwing"):
		combos.append("夜翼")
	if not combos.is_empty():
		t += "（组合：" + "、".join(combos) + "）"
	return t


## 融合后检查是否有新组合被发现；返回发现信息（无则空串）
func _check_combo_discovery() -> String:
	var found := ""
	if dna.has("highjump") and dna.has("double") and not combos_found.has("superjump"):
		combos_found["superjump"] = true
		found = "🔍 组合发现：超级弹跳（弹簧腿+振翅）——二段跳也变高跳，能翻组合高墙！"
	if dna.has("double") and dna.has("glow") and not combos_found.has("nightwing"):
		combos_found["nightwing"] = true
		var sep := "" if found == "" else "\n"
		found += sep + "🔍 组合发现：夜翼（振翅+荧光）——黑暗中也能展翅疾行！"
	return found


func _rating() -> String:
	if level_shards >= shards.size() and elapsed <= 50.0:
		return "S"
	if elapsed <= 90.0:
		return "A"
	return "B"


func _advance() -> void:
	if state != "win":
		return
	if level_idx >= LEVELS.size() - 1:
		total_shards = 0
		total_time = 0.0
		ratings = []
		combos_found = {}   # 完整重开：组合重新进入「未发现」状态
		_load_level(0)
	else:
		_load_level(level_idx + 1)


## —— 实验房（GPT P2）：无目标沙盒，自由融合顺序 + 遥测，供真人盲测 ——
func _enter_lab() -> void:
	mode = "lab"
	blocks = [[-200, 470, 1600, 70]]
	aliens = [
		{id = "highjump", name = "蹦蹦兽", col = Color("ab47bc"), x = 300.0, dna = "弹簧腿 DNA", tip = "普通跳变高跳"},
		{id = "double", name = "双翼虫", col = Color("4fc3f7"), x = 480.0, dna = "振翅 DNA", tip = "空中可再跳一次"},
		{id = "glow", name = "灯灯菌", col = Color("ffd54f"), x = 660.0, dna = "荧光 DNA", tip = "身体发光，照亮黑暗"},
	]
	pits = []
	dark = Vector2.ZERO
	goal_x = 99999.0
	shards = []
	shard_got = []
	px = 120.0
	py = GROUND_Y - 30.0
	vy = 0.0
	jumps_used = 0
	dna = {}
	combos_found = {}
	born_dark = false
	state = "play"
	elapsed = 0.0
	level_shards = 0
	lab_events = [{"t": 0.0, "ev": "enter"}]
	lab_fuse_n = 0
	toast = "实验房：自由融合，随便试（R 重置 · B 返回战役）"
	toast_age = 0.0
	dna_label.text = _dna_label_text()
	level_label.text = "实验房 · 自由融合测试"
	_update_shard_label()
	win_btn.visible = false
	lab_btn.visible = false

func _reset_lab() -> void:
	_save_lab_log()
	_enter_lab()

func _exit_lab() -> void:
	_save_lab_log()
	mode = "campaign"
	total_shards = 0
	total_time = 0.0
	ratings = []
	combos_found = {}
	_load_level(0)

func _save_lab_log() -> void:
	if mode != "lab" or lab_events.is_empty():
		return
	lab_events.append({"t": snappedf(elapsed, 0.1), "ev": "exit"})
	var arr := []
	var f := FileAccess.open("user://demo04_lab_log.json", FileAccess.READ)
	if f:
		var j := JSON.new()
		if j.parse(f.get_as_text()) == OK and j.data is Array:
			arr = j.data
		f.close()
	arr.append(lab_events)
	var w := FileAccess.open("user://demo04_lab_log.json", FileAccess.WRITE)
	if w:
		w.store_string(JSON.stringify(arr))
		w.close()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		keys[event.keycode] = true
		if event.keycode == KEY_E:
			_try_fuse()
		elif mode == "lab" and event.keycode == KEY_R:
			_reset_lab()
		elif mode == "lab" and event.keycode == KEY_B:
			_exit_lab()
	elif event is InputEventKey and not event.pressed:
		keys[event.keycode] = false


func _try_fuse() -> void:
	for a in aliens:
		if not dna.has(a.id) and absf(px - a.x) < 60.0:
			dna[a.id] = true
			toast = "🧬 融合了 %s 的「%s」：%s" % [a.name, a.dna, a.tip]
			toast_age = 0.0
			var before := combos_found.keys()
			var discovery := _check_combo_discovery()
			if discovery != "":
				toast = discovery   # 组合发现覆盖融合提示（更值得玩家注意）
			dna_label.text = _dna_label_text()
			if mode == "lab":
				lab_fuse_n += 1
				lab_events.append({"t": snappedf(elapsed, 0.1), "ev": "fuse", "id": a.id, "order": lab_fuse_n})
				for k in combos_found.keys():
					if not before.has(k):
						lab_events.append({"t": snappedf(elapsed, 0.1), "ev": "combo", "id": k})


func _physics_process(delta: float) -> void:
	pulse += delta * 5.0
	toast_age += delta
	if state != "play":
		return
	elapsed += delta

	var left: bool = keys.get(KEY_LEFT, false) or keys.get(KEY_A, false)
	var right: bool = keys.get(KEY_RIGHT, false) or keys.get(KEY_D, false)
	var jump_down: bool = (keys.get(KEY_SPACE, false) or keys.get(KEY_W, false) or keys.get(KEY_UP, false))
	var jump_pressed := jump_down and not jump_held   # 边沿触发：新按下才算跳
	jump_held = jump_down

	if left:
		face = -1.0
	if right:
		face = 1.0
	px = clamp(px + (float(right) - float(left)) * WALK * delta, 30.0, goal_x + 200.0)

	# 跳跃：土狼时间内可跳；有振翅 DNA 空中可再跳一次；
	# 组合·超级弹跳（高跳+振翅）：二段跳也享受高跳力度
	if jump_pressed and on_floor:
		vy = -JUMP_V * (1.45 if dna.has("highjump") else 1.0)
		on_floor = false
		jumps_used = 1
		if mode == "lab" and lab_events.size() < 500:
			lab_events.append({"t": snappedf(elapsed, 0.1), "ev": "jump", "px": snappedf(px, 1.0)})
	elif jump_pressed and not on_floor and dna.has("double") and jumps_used < 2:
		var m := 0.95
		if dna.has("highjump"):
			m = 0.95 * 1.45
		vy = -JUMP_V * m
		jumps_used = 2

	# 重力 + 位移
	vy += GRAV * delta
	py += vy * delta

	# 地形碰撞（AABB 简化：先垂直后水平，逐块解析）
	var r := Rect2(px - 14, py - 30, 28, 30)
	on_floor = false
	for b in blocks:
		var br := Rect2(b[0], b[1], b[2], b[3])
		if br.intersects(r):
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
	# 掉坑 → 回到最近的地面边缘
	if py > VIEW.y + 120:
		var edge := 120.0
		for b in blocks:
			if b[1] >= 450 and b[1] <= 490 and b[0] + b[2] <= px + 20.0 and b[0] + b[2] > edge:
				edge = b[0] + b[2]
		px = maxf(120.0, edge - 40.0)
		py = GROUND_Y - 30.0
		vy = 0.0
		jumps_used = 0
		toast = "跌进裂谷……异星的苔藓接住了你（回到沟边）"
		toast_age = 0.0

	# 黑暗区：没有荧光 DNA 时大幅减速（不敢跑）；
	# 组合·夜翼（振翅+荧光）：黑暗中也能展翅疾行（减速惩罚减半）
	if px > dark.x and px < dark.y and not dna.has("glow"):
		var dark_slow := 0.55
		if dna.has("double") and dna.has("glow"):
			dark_slow = 0.25
		px -= (float(right) - float(left)) * WALK * dark_slow * delta

	# 基因碎片收集
	for i in shards.size():
		if not shard_got[i] and absf(px - shards[i].x) < 48.0 and absf((py - 15.0) - shards[i].y) < 55.0:
			shard_got[i] = true
			level_shards += 1
			toast = "🧬 基因碎片 %d/%d" % [level_shards, shards.size()]
			toast_age = 0.0
			_update_shard_label()

	# 到达逃生舱（仅战役模式；实验房无目标）
	if mode == "campaign" and px >= goal_x + 40.0 and py <= GROUND_Y + 10.0:
		state = "win"
		total_shards += level_shards
		total_time += elapsed
		ratings.append(_rating())
		win_btn.text = "下一关 →" if level_idx < LEVELS.size() - 1 else "再跑一次"
		win_btn.visible = true
		lab_btn.visible = level_idx >= LEVELS.size() - 1

	# 相机跟随
	cam_x = clamp(px - VIEW.x / 2.0, 0.0, goal_x + 300.0 - VIEW.x)
	queue_redraw()


func _draw() -> void:
	var off := -cam_x
	# 天空渐变底色
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color("171226"))
	# 星星
	for k in 26:
		var sx := fposmod(k * 173.0, goal_x + 400.0) - cam_x
		if sx > -10 and sx < VIEW.x + 10:
			var sy := 30.0 + (k * 53) % 200
			draw_circle(Vector2(sx, sy), 1.5, Color(1, 1, 1, 0.35))
	# 远山
	for k in 6:
		var mx := k * 620.0 - cam_x * 0.4
		if mx > -260 and mx < VIEW.x + 260:
			draw_polygon(PackedVector2Array([Vector2(mx, 470), Vector2(mx + 240, 470), Vector2(mx + 120, 320)]), PackedColorArray([Color("241d3a")]))
	# 地形
	for b in blocks:
		var br := Rect2(b[0] + off, b[1], b[2], b[3])
		if br.position.x > VIEW.x + 50 or br.end.x < -50:
			continue
		draw_rect(br, Color("3d3552"))
		draw_rect(br, Color("241f36"), false, 2)
	# 坑（黑暗中的裂谷）
	for p in pits:
		var pr := Rect2(p.position.x + off, 470, p.size.x, 200)
		draw_rect(pr, Color("050308") if not born_dark else Color("120b1a"))
	# 黑暗区遮罩
	if px > dark.x - 300 and px < dark.y:
		var zone_l := dark.x + off
		draw_rect(Rect2(zone_l, 0, dark.y - dark.x, VIEW.y), Color(0.01, 0.005, 0.02, 0.88 if not born_dark else 0.35))
		# 玩家光圈
		var pl := Vector2(px + off, py - 15)
		if born_dark:
			for radius in [130.0, 90.0, 55.0]:
				draw_circle(pl, radius, Color(1.0, 0.95, 0.6, 0.05))
		else:
			draw_circle(pl, 70.0, Color(1, 1, 1, 0.02))
	# 基因碎片（脉动的绿钻）
	for i in shards.size():
		if shard_got[i]:
			continue
		var s: Vector2 = shards[i]
		var ssx := s.x + off
		if ssx < -30 or ssx > VIEW.x + 30:
			continue
		var bob := 4.0 * sin(pulse * 0.7 + i * 1.7)
		var sc := Vector2(ssx, s.y + bob)
		draw_polygon(PackedVector2Array([sc + Vector2(0, -10), sc + Vector2(8, 0), sc + Vector2(0, 10), sc + Vector2(-8, 0)]), PackedColorArray([Color("7ee787")]))
		draw_polygon(PackedVector2Array([sc + Vector2(0, -4), sc + Vector2(3, 0), sc + Vector2(0, 4), sc + Vector2(-3, 0)]), PackedColorArray([Color("eafff0")]))
	# 逃生舱
	var gx := goal_x + 80.0 + off
	draw_rect(Rect2(gx - 40, 380, 100, 90), Color("2b3b4d"))
	draw_polygon(PackedVector2Array([Vector2(gx - 50, 380), Vector2(gx + 70, 380), Vector2(gx + 10, 330)]), PackedColorArray([Color("4fc3f7")]))
	draw_rect(Rect2(gx + 2, 420, 26, 50), Color("8de3ff"))
	draw_string(FONT, Vector2(gx - 30, 368), "逃生舱", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("4fc3f7"))
	# 外星生物（脉动）
	for a in aliens:
		var ax: float = a.x + off
		if ax < -60 or ax > VIEW.x + 60:
			continue
		var bob2 := 5.0 * sin(pulse + a.x)
		var ay := 445.0 + bob2
		var got: bool = dna.has(a.id)
		var body_col: Color = a.col if not got else Color(a.col, 0.25)
		draw_circle(Vector2(ax, ay - 18), 16, body_col)
		draw_circle(Vector2(ax - 6, ay - 22), 3.5, Color(1, 1, 1, 0.9))
		draw_circle(Vector2(ax + 6, ay - 22), 3.5, Color(1, 1, 1, 0.9))
		draw_line(Vector2(ax - 6, ay - 10), Vector2(ax + 6, ay - 10), Color(0, 0, 0, 0.6), 2)
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
	# 实验房横幅与遥测计数
	if mode == "lab":
		draw_string(FONT, Vector2(16, 132), "实验房：没有通关目标，融合顺序由你决定（R 重置 · B 返回战役）", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7ee787"))
		draw_string(FONT, Vector2(16, 154), "遥测：融合 %d 次 · 组合发现 %d · 事件 %d 条（退出时写入 user://demo04_lab_log.json）" % [lab_fuse_n, combos_found.size(), lab_events.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8b94a7"))
	# 开场目标提示
	if state == "play" and elapsed < 5.0:
		draw_string(FONT, Vector2(16, 110), "目标：一路向右，抵达逃生舱。每种地形都需要对应的 DNA 能力。", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffcc80"))
	# toast
	if toast_age < 3.0:
		var a2: float = clamp(3.0 - toast_age, 0.0, 1.0)
		draw_rect(Rect2(VIEW.x / 2 - 300, 110, 600, 34), Color(0, 0, 0, 0.55 * a2))
		draw_string(FONT, Vector2(VIEW.x / 2 - 290, 133), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, a2))
	# 计时
	draw_string(FONT, Vector2(VIEW.x - 90, 28), "%d 秒" % int(elapsed), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e8ecf4"))
	# 胜利结算
	if state == "win":
		var final := level_idx >= LEVELS.size() - 1
		draw_rect(Rect2(180, 140, 600, 250), Color(0, 0, 0, 0.82))
		draw_rect(Rect2(180, 140, 600, 250), Color("4fc3f7"), false, 3)
		if final:
			draw_string(FONT, Vector2(210, 185), "🌍 全部逃脱成功！", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("4fc3f7"))
			var rt := ""
			for i in ratings.size():
				rt += "第%d关 %s   " % [i + 1, ratings[i]]
			var shards_max := 0
			for L in LEVELS:
				shards_max += L.shards.size()
			draw_string(FONT, Vector2(210, 228), "总碎片 %d/%d · 总用时 %d 秒" % [total_shards, shards_max, int(total_time)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e8ecf4"))
			draw_string(FONT, Vector2(210, 256), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("7ee787"))
			draw_string(FONT, Vector2(210, 296), "异星伙伴送你到最后一程。下方可进实验房自由融合测试。", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8b94a7"))
			draw_string(FONT, Vector2(210, 322), "评级规则：S=3 碎片且 50 秒内 · A=90 秒内 · B=完成", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8b94a7"))
		else:
			draw_string(FONT, Vector2(210, 185), "🚀 本关逃脱！", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("4fc3f7"))
			draw_string(FONT, Vector2(210, 228), "评级 %s · 碎片 %d/%d · 用时 %d 秒" % [_rating(), level_shards, shards.size(), int(elapsed)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e8ecf4"))
			draw_string(FONT, Vector2(210, 262), "前方还有 %d 关，新地形会逼你融合更多 DNA。" % [LEVELS.size() - level_idx - 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8b94a7"))
