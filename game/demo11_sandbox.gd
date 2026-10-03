extends Control
## 塞尔达式箱庭谜题（demo-11 v1）
## 12x7 紧凑箱庭：推箱 / 冻冰 / 焚烧 / 磁石的工具组合解谜，5 个房间每房至少两条解法路线。
## 开关 = 压力板：玩家踩住或箱子/铁块压住时导通，离开即断开；全部开关导通时终点门开启。
## 格子状态机 + 手写移动插值（80ms 滑动），无刚体、无 PhysicsServer、无外部素材。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")

const ROOM_W := 12
const ROOM_H := 7
const CELL := 50.0
const BOARD_POS := Vector2(48, 84)
const SLIDE_TIME := 0.08        # 玩家/被推物滑动插值时长（秒）
const TORCH_MELT_TIME := 3.0    # 火把旁冰面的融化秒数

const DIR_VECS := {up = Vector2i(0, -1), down = Vector2i(0, 1), left = Vector2i(-1, 0), right = Vector2i(1, 0)}

## 房间表：map 用 ASCII 定义（#墙 .地板 ~水 O深坑 S开关 G终点门 P起点 B木箱 I铁块 T火把）
## tools = 本关可用能力（ice 冰霜杖 / fire 火把 / magnet 磁石），随关卡解锁；每房至少两条解法。
const ROOMS := [
	{name = "房间1 · 推动入门", tools = [], tip = "把木箱推上圆盘开关压住，终点门才会开。两只木箱方向随便挑：上面的箱往下推、下面的箱往右推，至少两条走法。",
		map = [
			"############",
			"#P.........#",
			"#....B.....#",
			"#..B.S.....#",
			"#..........#",
			"#G.........#",
			"############",
		]},
	{name = "房间2 · 水面", tools = ["ice"], tip = "水挡住了去路。解法A：把木箱推进水里沉成桥面走过去；解法B：冰霜杖（F）把面前一格的水冻成冰面。小心别把唯一的木箱推进坑里。",
		map = [
			"############",
			"#P...~.....#",
			"#....~.....#",
			"#..B.~....G#",
			"#....~.....#",
			"#..O.~.....#",
			"############",
		]},
	{name = "房间3 · 焚烧", tools = ["ice", "fire"], tip = "木箱堆堵住了开关。解法A：火把（G）烧掉开关旁的木箱，再把散箱推进去压住；解法B：不烧，把散箱从下路绕推过去，一样能压住开关。",
		map = [
			"############",
			"#P....T...~#",
			"#..B..B....#",
			"#....BS....#",
			"#..........#",
			"#........G.#",
			"############",
		]},
	{name = "房间4 · 磁石", tools = ["magnet"], tip = "铁块锁在围栏里。解法A：磁石（H）隔空把同排、中间无墙的最近铁块一格格拉到开关上；解法B：绕进围栏推着铁块走长路从缺口出来。",
		map = [
			"############",
			"#P....#....#",
			"#.....#....#",
			"#.S......I.#",
			"#.....#....#",
			"#.....#..G.#",
			"############",
		]},
	{name = "房间5 · 组合考验", tools = ["ice", "fire", "magnet"], tip = "两个开关要同时压住门才开：木箱压上面、铁块用磁石拉到下面。人踩住也行但一走开就断——所以重物得都用上，还要先想办法过水。",
		map = [
			"############",
			"#P..~..S..G#",
			"#...~......#",
			"#...~..B...#",
			"#...~..S..I#",
			"#.B.~......#",
			"############",
		]},
]

var state := "play"           # play / final
var room_idx := 0
var grid: Array = []          # 长度 ROOM_W*ROOM_H：floor/wall/water/bridge/pit/fill/ice/gate
var player := {x = 1, y = 1}  # 格子坐标
var facing := "right"         # 最后移动方向，F/G/H 沿此方向使用
var objects: Array = []       # {type=box/iron/switch/torch, x, y}
var tools: Array = []         # 本关可用能力
var steps := 0                # 成功移动步数（工具不计数）
var gate_pos := {x = -1, y = -1}
var melt_queue: Array = []    # 火把旁冰面 {x, y, left} 融化倒计时
var rooms_cleared := 0
var pulse := 0.0
var slide_t := 1.0            # 0..1 手写插值进度
var slide_from := Vector2.ZERO
var pushed_idx := -1
var pushed_from := Vector2.ZERO
var toast := ""
var toast_age := 99.0

var status_label: Label
var hint_label: Label
var final_panel: Panel
var final_body: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	load_room(0)
	queue_redraw()


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "塞尔达式箱庭谜题（demo-11）"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ffd54f"))
	ui.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(16, 40)
	status_label.size = Vector2(920, 24)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("cfd8dc"))
	ui.add_child(status_label)
	hint_label = Label.new()
	hint_label.position = Vector2(16, VIEW.y - 28)
	hint_label.size = Vector2(930, 24)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color("90a4ae"))
	ui.add_child(hint_label)
	# 全通关结算面板
	final_panel = Panel.new()
	final_panel.name = "FinalPanel"
	final_panel.position = Vector2(230, 140)
	final_panel.size = Vector2(500, 240)
	var fp_style := StyleBoxFlat.new()
	fp_style.bg_color = Color(1, 1, 1, 0.95)
	fp_style.set_corner_radius_all(14)
	final_panel.add_theme_stylebox_override("panel", fp_style)
	final_panel.visible = false
	ui.add_child(final_panel)
	var ft := Label.new()
	ft.text = "全通关！"
	ft.position = Vector2(24, 14)
	ft.add_theme_font_size_override("font_size", 26)
	ft.add_theme_color_override("font_color", Color("1b5e20"))
	final_panel.add_child(ft)
	final_body = Label.new()
	final_body.name = "FinalBody"
	final_body.position = Vector2(24, 60)
	final_body.size = Vector2(452, 110)
	final_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	final_body.add_theme_font_size_override("font_size", 15)
	final_body.add_theme_color_override("font_color", Color("333333"))
	final_panel.add_child(final_body)
	var btn_again := Button.new()
	btn_again.name = "AgainBtn"
	btn_again.text = "再来一次（回到房间1）"
	btn_again.position = Vector2(24, 180)
	btn_again.size = Vector2(452, 42)
	btn_again.pressed.connect(_restart)
	final_panel.add_child(btn_again)


func _restart() -> void:
	load_room(0)


# ---------------- 房间装载与查询 ----------------

func load_room(i: int) -> void:
	if i < 0 or i >= ROOMS.size():
		return
	room_idx = i
	var R: Dictionary = ROOMS[i]
	grid = []
	objects = []
	melt_queue = []
	gate_pos = {x = -1, y = -1}
	var rows: Array = R.map
	for y in ROOM_H:
		var row: String = rows[y]
		for x in ROOM_W:
			var ch := row[x]
			var tile := "floor"
			match ch:
				"#":
					tile = "wall"
				"~":
					tile = "water"
				"O":
					tile = "pit"
				"G":
					tile = "gate"
					gate_pos = {x = x, y = y}
			grid.append(tile)
			match ch:
				"P":
					player = {x = x, y = y}
				"B":
					objects.append({type = "box", x = x, y = y})
				"I":
					objects.append({type = "iron", x = x, y = y})
				"T":
					objects.append({type = "torch", x = x, y = y})
				"S":
					objects.append({type = "switch", x = x, y = y})
	tools = (R.tools as Array).duplicate()
	facing = "right"
	slide_t = 1.0
	pushed_idx = -1
	state = "play"
	if final_panel:
		final_panel.visible = false
	_update_status()
	queue_redraw()


func _idx(x: int, y: int) -> int:
	return y * ROOM_W + x


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < ROOM_W and y >= 0 and y < ROOM_H


func _tile(x: int, y: int) -> String:
	return String(grid[_idx(x, y)])


func _set_tile(x: int, y: int, t: String) -> void:
	grid[_idx(x, y)] = t


## 该格上的实体物件（box/iron/torch），开关是压力板不算实体
func _solid_at(x: int, y: int) -> Dictionary:
	for o in objects:
		var od: Dictionary = o
		var t := String(od.type)
		if (t == "box" or t == "iron" or t == "torch") and int(od.x) == x and int(od.y) == y:
			return od
	return {}


func _cell_center(x: int, y: int) -> Vector2:
	return Vector2(BOARD_POS.x + (x + 0.5) * CELL, BOARD_POS.y + (y + 0.5) * CELL)


func _switch_pressed(od: Dictionary) -> bool:
	var sx: int = int(od.x)
	var sy: int = int(od.y)
	if int(player.x) == sx and int(player.y) == sy:
		return true
	var s := _solid_at(sx, sy)
	if s.is_empty():
		return false
	return String(s.type) == "box" or String(s.type) == "iron"


## 门开 = 房间内全部开关被压住（无开关的房间门常开）
func gate_open() -> bool:
	var all_on := true
	var found := false
	for o in objects:
		var od: Dictionary = o
		if String(od.type) == "switch":
			found = true
			if not _switch_pressed(od):
				all_on = false
	if not found:
		return true
	return all_on


func is_win() -> bool:
	if state == "final":
		return true
	if int(gate_pos.x) < 0:
		return false
	return int(player.x) == int(gate_pos.x) and int(player.y) == int(gate_pos.y) and gate_open()


# ---------------- 核心动作 ----------------

## 格子移动 + 推箱/推铁：返回是否移动成功
func move(dir: String) -> bool:
	if state != "play" or not DIR_VECS.has(dir):
		return false
	var d: Vector2i = DIR_VECS[dir]
	var px: int = int(player.x)
	var py: int = int(player.y)
	var nx: int = px + d.x
	var ny: int = py + d.y
	if not _in_bounds(nx, ny):
		return false
	var tile := _tile(nx, ny)
	if tile == "wall":
		return false
	var target := _solid_at(nx, ny)
	if not target.is_empty():
		var ttype := String(target.type)
		if ttype == "torch":
			return false
		# 推动判定：目标落点必须空且表面允许
		var bx: int = nx + d.x
		var by: int = ny + d.y
		if not _in_bounds(bx, by):
			return false
		var btile := _tile(bx, by)
		if not _solid_at(bx, by).is_empty() or btile == "wall" or btile == "gate":
			return false
		if btile == "water" or btile == "pit":
			# 木箱沉入水/坑变成桥面/填土，木箱本体消失
			objects.erase(target)
			_set_tile(bx, by, "bridge" if btile == "water" else "fill")
			pushed_idx = -1
			_toast("木箱沉了下去，变成了可以走的路面")
		else:
			if btile != "floor" and btile != "ice":
				return false
			target.x = bx
			target.y = by
			pushed_idx = objects.find(target)
			pushed_from = _cell_center(nx, ny)
		_slide_to(px, py)
		player = {x = nx, y = ny}
		facing = dir
		steps += 1
		_after_step(nx, ny)
		return true
	# 空格：水面/深坑不可走，关闭的门不可进
	if tile == "water" or tile == "pit":
		return false
	if tile == "gate" and not gate_open():
		return false
	_slide_to(px, py)
	player = {x = nx, y = ny}
	facing = dir
	steps += 1
	_after_step(nx, ny)
	return true


## 工具：ice 冻结面前水格 / fire 烧箱或融冰 / magnet 隔空拉铁块近 1 格
func use_tool(tool: String, dir: String) -> bool:
	if state != "play" or not DIR_VECS.has(dir):
		return false
	if not tools.has(tool):
		return false
	var d: Vector2i = DIR_VECS[dir]
	var tx: int = int(player.x) + d.x
	var ty: int = int(player.y) + d.y
	if not _in_bounds(tx, ty):
		return false
	if tool == "ice":
		if _tile(tx, ty) != "water":
			return false
		_set_tile(tx, ty, "ice")
		_arm_torch_melt(tx, ty)
		_toast("冰霜杖：面前的水冻成了冰面")
		_update_status()
		queue_redraw()
		return true
	if tool == "fire":
		var o := _solid_at(tx, ty)
		if not o.is_empty() and String(o.type) == "box":
			objects.erase(o)
			_toast("火把：木箱烧成了灰")
			_update_status()
			queue_redraw()
			return true
		if _tile(tx, ty) == "ice":
			_set_tile(tx, ty, "water")
			_toast("火把：冰面融化还原成水")
			_update_status()
			queue_redraw()
			return true
		return false
	if tool == "magnet":
		# 沿视线找最近铁块：只有墙会挡视线
		var cx: int = tx
		var cy: int = ty
		while _in_bounds(cx, cy):
			if _tile(cx, cy) == "wall":
				break
			var o2 := _solid_at(cx, cy)
			if not o2.is_empty() and String(o2.type) == "iron":
				var fx: int = cx - d.x
				var fy: int = cy - d.y
				if fx == int(player.x) and fy == int(player.y):
					return false
				var ft := _tile(fx, fy)
				if (ft != "floor" and ft != "ice") or not _solid_at(fx, fy).is_empty():
					return false
				o2.x = fx
				o2.y = fy
				pushed_idx = objects.find(o2)
				pushed_from = _cell_center(cx, cy)
				slide_t = 0.0
				_toast("磁石：铁块被拉近了一格")
				_update_status()
				queue_redraw()
				return true
			cx += d.x
			cy += d.y
		return false
	return false


func _arm_torch_melt(x: int, y: int) -> void:
	var offsets := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for off in offsets:
		var ov: Vector2i = off
		var ox: int = x + ov.x
		var oy: int = y + ov.y
		if _in_bounds(ox, oy):
			var o := _solid_at(ox, oy)
			if not o.is_empty() and String(o.type) == "torch":
				melt_queue.append({x = x, y = y, left = TORCH_MELT_TIME})
				return


func _slide_to(px: int, py: int) -> void:
	slide_from = _cell_center(px, py)
	slide_t = 0.0


func _after_step(nx: int, ny: int) -> void:
	if _tile(nx, ny) == "gate" and gate_open():
		if room_idx >= ROOMS.size() - 1:
			state = "final"
			_show_final()
		else:
			rooms_cleared += 1
			_toast(String(ROOMS[room_idx].name) + " 通过！")
			load_room(room_idx + 1)
	else:
		_update_status()
	queue_redraw()


func _show_final() -> void:
	final_panel.visible = true
	final_body.text = "五个箱庭房间全部通过！总步数 %d。\n冰霜杖冻水、火把烧箱融冰、磁石隔空拉铁——每个房间都不止一条解法，换个工具再走一遍试试。" % steps
	_update_status()
	queue_redraw()


func _toast(t: String) -> void:
	toast = t
	toast_age = 0.0


func _update_status() -> void:
	if status_label == null:
		return
	if state == "final":
		status_label.text = "全通关！五个房间全部通过 · 总步数 %d" % steps
		hint_label.text = "推箱、冻冰、焚烧、磁拉——工具组合的箱庭解谜到此毕业"
		return
	var R: Dictionary = ROOMS[room_idx]
	status_label.text = "%s · 房间 %d/%d · 步数 %d · 终点门 %s" % [
		String(R.name), room_idx + 1, ROOMS.size(), steps, "开启" if gate_open() else "关闭"]
	hint_label.text = "方向键移动（推箱/踩开关） · F 冰霜杖 / G 火把 / H 磁石，朝面向格使用"


# ---------------- 输入 ----------------

func _unhandled_input(event: InputEvent) -> void:
	if state != "play":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.keycode:
			KEY_UP:
				move("up")
			KEY_DOWN:
				move("down")
			KEY_LEFT:
				move("left")
			KEY_RIGHT:
				move("right")
			KEY_F:
				use_tool("ice", facing)
			KEY_G:
				use_tool("fire", facing)
			KEY_H:
				use_tool("magnet", facing)


# ---------------- 主循环 ----------------

func _process(delta: float) -> void:
	pulse += delta * 3.0
	toast_age += delta
	if slide_t < 1.0:
		slide_t = minf(1.0, slide_t + delta / SLIDE_TIME)
	# 火把旁的冰面按倒计时融化还原成水
	var k := melt_queue.size() - 1
	while k >= 0:
		var m: Dictionary = melt_queue[k]
		m.left = float(m.left) - delta
		if float(m.left) <= 0.0:
			if _tile(int(m.x), int(m.y)) == "ice":
				_set_tile(int(m.x), int(m.y), "water")
			melt_queue.remove_at(k)
		k -= 1
	_update_status()
	queue_redraw()


# ---------------- 绘制 ----------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color("1c2029"))
	if grid.size() == ROOM_W * ROOM_H:
		_draw_board()
		_draw_objects()
		_draw_player()
	_draw_side_panel()
	if toast_age < 2.5:
		var a: float = clampf(2.5 - toast_age, 0.0, 1.0)
		draw_string(FONT, Vector2(BOARD_POS.x, BOARD_POS.y + ROOM_H * CELL + 20.0), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a))


func _draw_board() -> void:
	for y in ROOM_H:
		for x in ROOM_W:
			var t := _tile(x, y)
			var rx := BOARD_POS.x + x * CELL
			var ry := BOARD_POS.y + y * CELL
			var r := Rect2(rx + 1.0, ry + 1.0, CELL - 2.0, CELL - 2.0)
			var center := Vector2(rx + CELL * 0.5, ry + CELL * 0.5)
			match t:
				"wall":
					draw_rect(r, Color("11141d"))
					draw_rect(Rect2(r.position + Vector2(5, 5), r.size - Vector2(10, 10)), Color("1d2331"), false, 2.0)
				"water":
					draw_rect(r, Color("174e75"))
					var wave: float = sin(pulse * 2.2 + x * 1.3 + y * 0.9)
					draw_line(center + Vector2(-13.0, wave * 3.0), center + Vector2(13.0, wave * 3.0), Color(0.65, 0.85, 1.0, 0.35), 2.0)
				"bridge":
					draw_rect(r, Color("8a6a42"))
					draw_rect(r, Color("5e4527"), false, 2.0)
					for k in 3:
						draw_line(Vector2(rx + 6.0, ry + 12.0 + k * 13.0), Vector2(rx + CELL - 6.0, ry + 12.0 + k * 13.0), Color(0, 0, 0, 0.25), 2.0)
				"pit":
					draw_rect(r, Color("07080d"))
					draw_rect(r, Color("2a2f3d"), false, 2.0)
				"fill":
					draw_rect(r, Color("665a3d"))
					draw_circle(center + Vector2(-8, -6), 2.5, Color(0, 0, 0, 0.3))
					draw_circle(center + Vector2(7, 4), 2.5, Color(0, 0, 0, 0.3))
					draw_circle(center + Vector2(-2, 9), 2.5, Color(0, 0, 0, 0.3))
				"ice":
					draw_rect(r, Color("a8d8ef"))
					draw_line(r.position + Vector2(8, r.size.y - 8), r.position + Vector2(r.size.x - 8, 8), Color(1, 1, 1, 0.65), 2.0)
					draw_rect(r, Color("d9f1fb"), false, 2.0)
				"gate":
					if gate_open():
						draw_rect(r, Color("3d3320"))
						draw_rect(r, Color("ffd54f"), false, 3.0)
						draw_string(FONT, center + Vector2(-15.0, 5.0), "门开", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffd54f"))
					else:
						draw_rect(r, Color("4a2430"))
						for k in 3:
							draw_line(Vector2(rx + 12.0 + k * 13.0, ry + 5.0), Vector2(rx + 12.0 + k * 13.0, ry + CELL - 5.0), Color("8c3b47"), 4.0)
				_:
					var floor_col := Color("39435a") if (x + y) % 2 == 0 else Color("343d53")
					draw_rect(r, floor_col)


func _draw_objects() -> void:
	# 压力板贴地先画
	for o in objects:
		var od: Dictionary = o
		if String(od.type) == "switch":
			var c := _cell_center(int(od.x), int(od.y))
			var on: bool = _switch_pressed(od)
			draw_circle(c, 15.0, Color("242b3b"))
			draw_circle(c, 11.0, Color("4caf50") if on else Color("a34a3f"))
			draw_arc(c, 15.0, 0.0, TAU, 24, Color("11141d"), 2.0)
	# 立起来的物件（被推时按插值画）
	for i in objects.size():
		var od2: Dictionary = objects[i]
		var otype := String(od2.type)
		if otype == "switch":
			continue
		var target_c := _cell_center(int(od2.x), int(od2.y))
		var c2 := target_c
		if i == pushed_idx and slide_t < 1.0:
			c2 = pushed_from.lerp(target_c, slide_t)
		if otype == "box":
			var br := Rect2(c2 - Vector2(17, 17), Vector2(34, 34))
			draw_rect(br, Color("a5743c"))
			draw_rect(br, Color("6e4a24"), false, 3.0)
			draw_line(br.position + Vector2(4, 4), br.end - Vector2(4, 4), Color(0, 0, 0, 0.25), 2.0)
			draw_line(Vector2(br.position.x + 4, br.end.y - 4), Vector2(br.end.x - 4, br.position.y + 4), Color(0, 0, 0, 0.25), 2.0)
			draw_string(FONT, c2 + Vector2(-14.0, 5.0), "箱", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("5d3f1e"))
		elif otype == "iron":
			var ir := Rect2(c2 - Vector2(17, 17), Vector2(34, 34))
			draw_rect(ir, Color("8b96a5"))
			draw_rect(ir, Color("565f6c"), false, 3.0)
			draw_circle(ir.position + Vector2(8, 8), 2.5, Color("424a55"))
			draw_circle(Vector2(ir.end.x - 8, ir.position.y + 8), 2.5, Color("424a55"))
			draw_circle(Vector2(ir.position.x + 8, ir.end.y - 8), 2.5, Color("424a55"))
			draw_circle(ir.end - Vector2(8, 8), 2.5, Color("424a55"))
			draw_string(FONT, c2 + Vector2(-14.0, 5.0), "铁", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("39404b"))
		elif otype == "torch":
			draw_line(c2 + Vector2(0, 14), c2 + Vector2(0, -4), Color("6e4a24"), 4.0)
			var flick: float = 1.0 + 0.15 * sin(pulse * 6.0)
			draw_circle(c2 + Vector2(0, -10), 7.0 * flick, Color("ff8f3c"))
			draw_circle(c2 + Vector2(0, -12), 3.5 * flick, Color("ffd54f"))


func _draw_player() -> void:
	var target_c := _cell_center(int(player.x), int(player.y))
	var c := target_c
	if slide_t < 1.0:
		c = slide_from.lerp(target_c, slide_t)
	draw_circle(c, 14.0, Color("11141d"))
	draw_circle(c, 12.0, Color("7ee081"))
	var d: Vector2i = DIR_VECS.get(facing, Vector2i(1, 0))
	var dv := Vector2(d.x, d.y)
	draw_circle(c + dv * 8.0, 4.0, Color("1b5e20"))
	draw_circle(c + Vector2(-4, -4), 2.0, Color("1b5e20"))
	draw_circle(c + Vector2(4, -4), 2.0, Color("1b5e20"))


func _draw_side_panel() -> void:
	var px0 := BOARD_POS.x + ROOM_W * CELL + 16.0
	var py0 := BOARD_POS.y
	var pw := VIEW.x - px0 - 12.0
	var ph := ROOM_H * CELL
	draw_rect(Rect2(px0, py0, pw, ph), Color("232837"))
	draw_rect(Rect2(px0, py0, pw, ph), Color("3a4356"), false, 2.0)
	if state == "final":
		return
	var R: Dictionary = ROOMS[room_idx]
	draw_string(FONT, Vector2(px0 + 14.0, py0 + 26.0), String(R.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("ffd54f"))
	draw_string(FONT, Vector2(px0 + 14.0, py0 + 50.0), "目标（不止一条解法）", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8fa3b0"))
	_wrap_text(String(R.tip), Vector2(px0 + 14.0, py0 + 68.0), pw - 28.0, 12, Color("b8c4cc"))
	draw_string(FONT, Vector2(px0 + 14.0, py0 + 150.0), "本关能力", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8fa3b0"))
	var tool_rows := [["ice", "F 冰霜杖：冻结面前一格的水"], ["fire", "G 火把：烧箱 / 融冰"], ["magnet", "H 磁石：隔空拉近铁块 1 格"]]
	for k in tool_rows.size():
		var row: Array = tool_rows[k]
		var avail: bool = tools.has(String(row[0]))
		var col := Color("e8eef2") if avail else Color(1, 1, 1, 0.22)
		draw_string(FONT, Vector2(px0 + 14.0, py0 + 172.0 + k * 22.0), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	var pressed := 0
	var total := 0
	for o in objects:
		var od: Dictionary = o
		if String(od.type) == "switch":
			total += 1
			if _switch_pressed(od):
				pressed += 1
	var gate_col := Color("4caf50") if gate_open() else Color("e57373")
	draw_string(FONT, Vector2(px0 + 14.0, py0 + 254.0), "开关 %d/%d 压住 · 终点门 %s" % [pressed, total, "开启" if gate_open() else "关闭"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, gate_col)
	draw_string(FONT, Vector2(px0 + 14.0, py0 + 280.0), "步数 %d · 已通过 %d/%d" % [steps, rooms_cleared, ROOMS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b8c4cc"))
	draw_string(FONT, Vector2(px0 + 14.0, py0 + 308.0), "方向键移动，踩上或压住开关", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("78848e"))
	draw_string(FONT, Vector2(px0 + 14.0, py0 + 328.0), "F/G/H 沿最后移动方向使用", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("78848e"))


func _wrap_text(text: String, pos: Vector2, width: float, size: int, col: Color) -> void:
	var line := ""
	var y := pos.y
	for ch in text:
		line += ch
		if FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			line = line.substr(0, line.length() - 1)
			draw_string(FONT, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			y += size + 4
			line = ch
	draw_string(FONT, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
