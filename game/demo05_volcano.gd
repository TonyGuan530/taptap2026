extends Control
## 重生之我是恐龙·火山生存（demo-05）
## 现代人意识穿越成恐龙：火山爆发前探索规划、分散储备资源；
## 灾后风向/降雨决定火山灰、泥流、燃烧、污染的连锁变化；最后选择撤离路线。
## 对应 Miro 玩法块 demo-05。纯代码实现、无外部资源；3 分钟一局。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")

const PHASE1_TIME := 45.0
const STORE_COST := 1

## 地块：名称/位置/风险/特产
const TILES := [
	{id = "highland", name = "高地", x = 90, y = 130, risk = "火山灰·低", has = "视野最好，灰层薄"},
	{id = "valley", name = "河谷", x = 390, y = 130, risk = "泥流·高", has = "水源充足，雨后泥流"},
	{id = "forest", name = "森林", x = 690, y = 130, risk = "燃烧·中", has = "食物丰富，怕火"},
	{id = "cave", name = "洞穴", x = 240, y = 300, risk = "安全·极低", has = "坚固避难，没特产"},
	{id = "wetland", name = "湿地", x = 540, y = 300, risk = "污染·中", has = "水+小动物，怕污染"},
]
## 撤离路线
const ROUTES := [
	{name = "北线·翻山", risk = "耗体力大，但远离灰区", need = 6},
	{name = "东线·沿河", risk = "快，但可能遇泥流改道", need = 4},
	{name = "南线·密林", risk = "食物多，慢，易迷路", need = 5},
]

var phase := "prepare"        # prepare / disaster / decide / end
var timer := PHASE1_TIME
var gather := 0
var stored := {}              # tileId -> {food, water}
var supply := {food = 3, water = 3}
var wind := ""
var rain := false
var events := []              # 末日故事事件链
var route_chosen := -1
var result := ""
var pulse := 0.0
var hovered := -1
var toast := ""
var toast_age := 99.0

var status_label: Label
var hint_label: Label
var end_panel: Panel
var end_body: Label


func _ready() -> void:
	for t in TILES:
		stored[t.id] = {food = 0, water = 0}
	_build_ui()
	# 采集计时：每 4 秒 +1 采集点
	var timer_node := Timer.new()
	timer_node.wait_time = 4.0
	timer_node.timeout.connect(_gather_tick)
	add_child(timer_node)
	timer_node.start()
	queue_redraw()


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "重生之我是恐龙 · 火山生存（demo-05）"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ffd54f"))
	ui.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(16, 38)
	status_label.size = Vector2(760, 26)
	status_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(status_label)
	hint_label = Label.new()
	hint_label.position = Vector2(16, VIEW.y - 30)
	hint_label.size = Vector2(600, 26)
	hint_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(hint_label)
	# 结算面板
	end_panel = Panel.new()
	end_panel.name = "EndPanel"
	end_panel.position = Vector2(130, 80)
	end_panel.size = Vector2(700, 380)
	end_panel.visible = false
	ui.add_child(end_panel)
	var et := Label.new()
	et.text = "🌋 末日故事"
	et.position = Vector2(20, 12)
	et.add_theme_font_size_override("font_size", 20)
	et.add_theme_color_override("font_color", Color("ffd54f"))
	end_panel.add_child(et)
	end_body = Label.new()
	end_body.name = "Body"
	end_body.position = Vector2(20, 50)
	end_body.size = Vector2(660, 270)
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_body.add_theme_font_size_override("font_size", 13)
	end_panel.add_child(end_body)
	var again := Button.new()
	again.text = "再来一次"
	again.position = Vector2(20, 330)
	again.size = Vector2(150, 36)
	again.pressed.connect(_restart)
	end_panel.add_child(again)


func _set_status(t: String) -> void:
	if status_label:
		status_label.text = t


func _set_hint(t: String) -> void:
	if hint_label:
		hint_label.text = t


func _toast(t: String) -> void:
	toast = t
	toast_age = 0.0


func _log_ev(t: String) -> void:
	events.append(t)


func _restart() -> void:
	phase = "prepare"
	timer = PHASE1_TIME
	gather = 0
	supply = {food = 3, water = 3}
	events = []
	route_chosen = -1
	for t in TILES:
		stored[t.id] = {food = 0, water = 0}
	end_panel.visible = false
	queue_redraw()


# ---------------- 交互 ----------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if phase == "prepare":
			for i in TILES.size():
				var t: Dictionary = TILES[i]
				if Rect2(t.x, t.y, 160, 96).has_point(pos):
					_on_tile_click(i)
					return
		elif phase == "decide" and route_chosen == -1:
			for i in ROUTES.size():
				if Rect2(60 + i * 290, 300, 270, 120).has_point(pos):
					_choose_route(i)
					return


func _on_tile_click(i: int) -> void:
	var t: Dictionary = TILES[i]
	if gather <= 0:
		_toast("没有可存放的采集点（每 4 秒 +1）")
		return
	gather -= 1
	stored[t.id].food += 1
	stored[t.id].water += 1
	_toast("把 1 食物 + 1 水存到了「%s」" % t.name)


# ---------------- 主循环 ----------------

func _process(delta: float) -> void:
	pulse += delta * 4.0
	toast_age += delta
	if phase == "prepare":
		timer -= delta
		_set_status("【准备期】剩余 %d 秒 · 采集点 %d（点击地块存放）· 已存 %d 份" % [int(timer), gather, _total_stored()])
		_set_hint("河谷水多但雨后泥流；高地灰层薄；洞穴最安全——别把储备全放一个地方！")
		if timer <= 0.0:
			_start_disaster()
	elif phase == "disaster":
		_set_status("【灾变】火山爆发！风向：%s%s" % [("东风，灰向西" if wind == "east" else "西风，灰向东"), ("，暴雨如注" if rain else "")])
		_set_hint("灾害正在连锁发生……")
	queue_redraw()


func _gather_tick() -> void:
	if phase == "prepare":
		gather += 1


func _total_stored() -> int:
	var n := 0
	for k in stored:
		n += int(stored[k].food)
	return n


# ---------------- 灾变 ----------------

func _start_disaster() -> void:
	phase = "disaster"
	wind = "east" if randf() < 0.5 else "west"
	rain = randf() < 0.6
	_log_ev("火山在午后爆发，蘑菇云遮住了太阳。当晚刮起了%s。" % ("东风" if wind == "east" else "西风"))
	if rain:
		_log_ev("深夜开始下暴雨，河水浑浊上涨。")
	else:
		_log_ev("空气干燥得可怕，火星随风飘散。")
	# 下风侧地块灰覆盖，储备减半
	var downwind_ids := ["forest", "wetland"] if wind == "west" else ["highland", "valley"]
	_log_ev("火山灰顺风覆盖了%s和%s，那里的储备损失了一半。" % [_tile_name(downwind_ids[0]), _tile_name(downwind_ids[1])])
	for id in downwind_ids:
		stored[id].food = int(stored[id].food / 2.0)
		stored[id].water = int(stored[id].water / 2.0)
	if rain:
		_log_ev("河谷暴发泥流，河谷里的储备全部被吞没。")
		stored.valley = {food = 0, water = 0}
		_log_ev("湿地的水被灰烬污染，短期无法饮用。")
		stored.wetland.water = int(stored.wetland.water / 2.0)
		_log_ev("森林被雷火点燃，烧了整整三天。")
	else:
		_log_ev("森林侥幸未燃，但食物被灰盖了一层土腥味。")
	var t := get_tree().create_timer(3.0)
	t.timeout.connect(_enter_decide)


func _tile_name(id: String) -> String:
	for t in TILES:
		if t.id == id:
			return t.name
	return id


func _enter_decide() -> void:
	phase = "decide"
	var f := 0
	var w := 0
	for k in stored:
		f += int(stored[k].food)
		w += int(stored[k].water)
	supply.food = mini(3 + f, 12)
	supply.water = mini(3 + w, 12)
	_log_ev("族群收拾行囊：带上 %d 份食物、%d 份水，准备撤离。" % [supply.food, supply.water])


func _choose_route(i: int) -> void:
	route_chosen = i
	var r: Dictionary = ROUTES[i]
	var total: int = supply.food + supply.water
	_log_ev("族群选择了%s：%s" % [r.name, r.risk])
	if i == 1 and randf() < 0.5:
		supply.water = maxi(0, supply.water - 1)
		_log_ev("东线果然遇到泥流改道，多耗了 1 份水。")
	if i == 2 and randf() < 0.5:
		supply.food += 1
		_log_ev("南线一路觅食顺利，多出 1 份食物。")
	if total >= r.need and supply.food >= 1 and supply.water >= 1:
		result = "win"
		_log_ev("第 %d 天，族群抵达一片没有被灰烬覆盖的新生态区。火山的故事结束了，生存的故事才刚刚开始。" % (5 + i))
	elif total >= r.need:
		result = "partial"
		_log_ev("族群踉踉跄跄抵达新生态区，但食物见底——活下来了，代价惨重。")
	else:
		result = "lose"
		_log_ev("物资在半途耗尽……族群的足迹消失在灰烬里。")
	_show_end()


func _show_end() -> void:
	phase = "end"
	end_panel.visible = true
	var verdict := "完美撤离" if result == "win" else ("惨胜" if result == "partial" else "灭亡")
	end_body.text = ""
	for e in events:
		end_body.text += "· " + e + "\n"
	end_body.text += "\n—— 结算：%s · 剩余食物 %d 水 %d · 评分 %d ——" % [verdict, supply.food, supply.water, _score()]


func _score() -> int:
	var base: int = {"win": 70, "partial": 45, "lose": 10}[result]
	return base + supply.food * 2 + supply.water * 2


# ---------------- 绘制 ----------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color("1a1520"))
	# 火山
	var vx := 780.0
	var vcol := Color("4a3b45") if phase == "prepare" else Color("d84315")
	draw_polygon(PackedVector2Array([Vector2(vx - 90, 120), Vector2(vx + 90, 120), Vector2(vx, 30)]), PackedColorArray([vcol]))
	if phase != "prepare":
		var glow := 0.5 + 0.3 * sin(pulse)
		draw_circle(Vector2(vx, 40), 16, Color(1.0, 0.6, 0.2, glow))
		draw_string(FONT, Vector2(vx - 40, 22), "火山爆发！", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffab91"))
	# 地块
	for i in TILES.size():
		var t: Dictionary = TILES[i]
		var r := Rect2(t.x, t.y, 160, 96)
		var burnt: bool = phase != "prepare" and rain and t.id == "forest"
		var ashy: bool = phase != "prepare" and ((wind == "west" and (t.id == "forest" or t.id == "wetland")) or (wind == "east" and (t.id == "highland" or t.id == "valley")))
		draw_rect(r, Color("5d4037") if burnt else (Color("6b6b70") if ashy else Color("39415a")))
		draw_rect(r, Color("ffd54f") if hovered == i else Color("1c2030"), false, 3 if hovered == i else 2)
		draw_string(FONT, r.position + Vector2(10, 22), t.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e8ecf4"))
		draw_string(FONT, r.position + Vector2(10, 44), "风险:%s" % t.risk, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffb74d") if phase == "prepare" else Color("8b94a7"))
		var s: Dictionary = stored[t.id]
		draw_string(FONT, r.position + Vector2(10, 66), "储备 食%d 水%d" % [s.food, s.water], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("4fc3f7"))
		draw_string(FONT, r.position + Vector2(10, 86), t.has, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8b94a7"))
	# 撤离路线卡片
	if phase == "decide":
		draw_string(FONT, Vector2(60, 285), "选择撤离路线（点击卡片）：", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffd54f"))
		for i in ROUTES.size():
			var rt: Dictionary = ROUTES[i]
			var rr := Rect2(60 + i * 290, 300, 270, 120)
			draw_rect(rr, Color("2b3b4d"))
			draw_rect(rr, Color("4fc3f7"), false, 2)
			draw_string(FONT, rr.position + Vector2(14, 30), rt.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("4fc3f7"))
			draw_string(FONT, rr.position + Vector2(14, 58), rt.risk, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c6cddc"))
			draw_string(FONT, rr.position + Vector2(14, 84), "至少需要 %d 份物资" % rt.need, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffb74d"))
	# 随身物资
	draw_string(FONT, Vector2(640, VIEW.y - 30), "随身: 食%d 水%d" % [supply.food, supply.water], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("4fc3f7"))
	# toast
	if toast_age < 2.5:
		var a: float = clamp(2.5 - toast_age, 0.0, 1.0)
		draw_string(FONT, Vector2(16, VIEW.y - 60), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a))
