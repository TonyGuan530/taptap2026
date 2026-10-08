extends CanvasLayer
const Low := preload("res://lowpoly/library.gd")
const NAMES := {"wood":"木","food":"果","copper":"铜","magnet":"磁","quartz":"晶","coal":"煤","water":"水"}
const JOBS := ["harvest","haul","guard","follow","shelter","board"]
const JOB_LABELS := {"follow":"跟随","harvest":"采木","haul":"搬矿","guard":"守卫","shelter":"地下安置","board":"登船","idle":"休息"}
const JOB_NAMES := ["采木 · 走到树林再送回营地","搬矿 · 搬运地表铜矿","守卫 · 在营地驱赶捕食者","跟随 · 一起探索高地与地下","地下安置 · 沿坡道进入寝室","飞船登船 · 沿坡道走上高地"]
const CRAFTS := ["wheel","lamp","steam","ship","shelter","cable","provisions"]
var world: Node3D
var ui_root: Control
var title: Label
var status: Label
var stock: Label
var objective: Label
var hint: Label
var message: Label
var shade: ColorRect
var panel: Panel
var overlay := "intro"
var buttons: Array[Button] = []
var overlay_status: Label
var story_text := ""
var seed_edit: LineEdit
var density_sliders: Dictionary = {}
var density_labels: Dictionary = {}
var preset_control: OptionButton
var worldsettings_button: Button
var settings_message: Label
func _ready() -> void:
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)
	var top := ColorRect.new()
	top.color = Color(0.05,0.13,0.15,0.91)
	top.position = Vector2.ZERO
	top.size = Vector2(960,141)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(top)
	title = label(ui_root,"小山谷 / V9 · 采集、安营、转移",Vector2(20,12),23,Color("fff0c5"))
	worldsettings_button = Button.new()
	worldsettings_button.text = "世界设置  [F2]"
	worldsettings_button.position = Vector2(785,9)
	worldsettings_button.size = Vector2(160,29)
	worldsettings_button.pressed.connect(show_world_settings)
	ui_root.add_child(worldsettings_button)
	status = label(ui_root,"",Vector2(20,44),16)
	stock = label(ui_root,"",Vector2(20,70),16,Color("f8d796"))
	objective = label(ui_root,"",Vector2(20,104),16)
	var bottom := ColorRect.new()
	bottom.color = Color(0.05,0.13,0.15,0.88)
	bottom.position = Vector2(0,455)
	bottom.size = Vector2(960,85)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(bottom)
	hint = label(ui_root,"",Vector2(20,459),18,Color("ffdc8b"))
	message = label(ui_root,"",Vector2(20,490),15)
	label(ui_root,"WASD 移动　E 使用/采集　F 恐龙　B 建设　R 旋转/喝水　C 科技　J 伙伴　空格 甩尾　F2 保存",Vector2(20,516),13,Color("a9c4bf"))
	shade = ColorRect.new()
	shade.color = Color(0.01,0.07,0.09,0.8)
	shade.size = Vector2(960,540)
	ui_root.add_child(shade)
	panel = Panel.new()
	panel.position = Vector2(145,50)
	panel.size = Vector2(670,440)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("193c3e")
	style.border_color = Color("e8c382")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel",style)
	shade.add_child(panel)
	show_intro()
	Low.readable_ui(ui_root)
func label(parent: Node, text: String, pos: Vector2, font_size := 16, color := Color("e4ede2")) -> Label:
	var node := Label.new()
	node.text = text
	node.position = pos
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	parent.add_child(node)
	return node
func button(text: String, y: float, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = Vector2(25,y)
	node.size = Vector2(620,34)
	node.add_theme_font_size_override("font_size",15)
	node.pressed.connect(callback)
	panel.add_child(node)
	buttons.append(node)
	return node
func clear_panel(kind: String) -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	buttons.clear()
	overlay = kind
	shade.show()
	world.held.clear()
func show_intro() -> void:
	clear_panel("intro")
	label(panel,"我想把灯带进史前世界",Vector2(25,24),27,Color("fff0c5"))
	label(panel,"末班地铁之后，我醒成了恐龙。手机没了，电也没了。\n先找三颗果子，和那只三角龙交朋友。",Vector2(25,85),19)
	label(panel,"E 采集：树林木6、浆果2，B 建伙伴休息棚。\n开局80秒后火山喷发，地表会持续受伤！\n安营后改变计划：沿南侧青色坡道进入地下。\n在地下坚持5秒，守住山谷的第一夜。\n菜单暂停时间；WASD移动，空格甩尾。",Vector2(25,162),18)
	button("进入山谷  [Enter]",365,world.begin)
	Low.readable_ui(panel)
func show_story(text: String) -> void:
	story_text = text
	clear_panel("story")
	label(panel,"现代记忆，史前的选择",Vector2(25,28),25,Color("fff0c5"))
	label(panel,text,Vector2(25,110),21)
	button("继续行动  [Enter / 空格]",360,close_overlay)
	Low.readable_ui(panel)
func show_craft() -> void:
	clear_panel("craft")
	label(panel,"把现代知识重新造出来",Vector2(25,16),24,Color("fff0c5"))
	overlay_status = label(panel,"",Vector2(25,54),14)
	for index in CRAFTS.size():
		var key: String = CRAFTS[index]
		var recipe: Dictionary = world.rules.RECIPES[key]
		var cost_text := ""
		for material in recipe.cost: cost_text += "%s%d " % [NAMES[material],recipe.cost[material]]
		if recipe.charge: cost_text += "电%d " % recipe.charge
		var site_name: String = {"wheel":"水潭","camp":"营地","highland":"高地","underground":"地下"}[recipe.site]
		button("%d  %s · %s / %s" % [index+1,recipe.name,cost_text,site_name],86+index*39,world.craft.bind(key))
	button("返回山谷  [C / Esc]",378,close_overlay)
	refresh_craft()
	Low.readable_ui(panel)
func refresh_craft() -> void:
	if overlay != "craft": return
	overlay_status.text = "顺序：水轮 → 灯泡 → 蒸汽。飞船或地下设施，需要走近对应地点。"
	for index in CRAFTS.size():
		buttons[index].disabled = world.rules.built.has(CRAFTS[index])
func show_jobs() -> void:
	clear_panel("jobs")
	label(panel,"三角龙伙伴 · 阿角",Vector2(25,20),25,Color("fff0c5"))
	if not world.buddy.recruited:
		label(panel,"走近阿角，E 喂它 3 颗果子后，就能安排工作。\n果子在营地西北的灌木丛。",Vector2(25,100),20)
	else:
		label(panel,"背着物资时，新安排会排队；阿角先交货，再自动换工作。",Vector2(25,63),15)
		for index in JOBS.size(): button("%d  %s" % [index+1,JOB_NAMES[index]],104+index*40,world.assign_job.bind(JOBS[index]))
	button("返回山谷  [J / Esc]",378,close_overlay)
	Low.readable_ui(panel)
func show_pause() -> void:
	clear_panel("pause")
	label(panel,"山谷暂停中",Vector2(25,30),27,Color("fff0c5"))
	label(panel,"地形、伙伴和火山都在等你。\n高地飞船：造船、让阿角登船，喷发后 E 发射。\n地下文明：寝室通风、电缆、食水，阿角地下安置。\n你也要在地下等待，真正活过第 6 分钟。",Vector2(25,108),19)
	button("继续  [Esc]",315,close_overlay)
	button("世界设置 / 保存与读取",365,show_world_settings)
	Low.readable_ui(panel)
func show_end(ending: String) -> void:
	clear_panel("end")
	var endings := {"flight":["向天空延续的文明","阿角和我飞过灰云。\n我本来只想找回一部手机，\n现在，我带走了一个世界的第一盏灯。"],"civilization":["地下文明的第一夜","通风口还在转，寝室亮着灯，阿角安稳地睡下。\n我们不是等世界恢复原样。\n我们让这群生命拥有了新的明天。"],"dead":["灰烬吞没了山谷","地表的熔岩是真正的危险。\n准备好科技和伙伴，再去高地或地下避难。"]}
	label(panel,endings[ending][0],Vector2(25,32),27,Color("fff0c5"))
	label(panel,endings[ending][1],Vector2(25,116),21)
	button("重新开始  [Enter]",365,world.restart)
	Low.readable_ui(panel)
func close_overlay() -> void:
	shade.hide()
	overlay = ""
	world.held.clear()
func blocked() -> bool: return shade.visible
func key(code: int) -> void:
	if overlay in ["build_menu","building","dinosaur","colony"] and code >= KEY_1 and code <= KEY_9:
		var index := code-KEY_1
		if index < buttons.size() and not buttons[index].disabled: buttons[index].pressed.emit()
		return
	if overlay == "settings" and code == KEY_ENTER: _start_configured()
	elif overlay == "intro" and code in [KEY_ENTER,KEY_SPACE]: world.begin()
	elif overlay == "story" and code in [KEY_ENTER,KEY_SPACE]: close_overlay()
	elif overlay == "end" and code == KEY_ENTER: world.restart()
	elif overlay == "craft" and code >= KEY_1 and code <= KEY_7: world.craft(CRAFTS[code-KEY_1])
	elif overlay == "jobs" and world.buddy.recruited and code >= KEY_1 and code <= KEY_6: world.assign_job(JOBS[code-KEY_1])
	elif (code == KEY_ESCAPE and overlay in ["craft","jobs","pause","story","map","challenge","build_menu","building","dinosaur","colony"]) or (code == KEY_ESCAPE and overlay == "settings" and world.started) or (overlay == "craft" and code == KEY_C) or (overlay in ["jobs","colony"] and code == KEY_J) or (overlay == "map" and code == KEY_M) or (overlay == "build_menu" and code == KEY_B): close_overlay()
func refresh() -> void:
	var phase_name: String = {"calm":"平静","warning":"预警","ash":"灰烬堵住水轮","eruption":"喷发 · 地表危险","after":"喷发结束"}[world.rules.phase]
	status.text = "%s · %02d:%02d / 06:00　生命 %.0f　饱食 %.0f　高度 %+.1f 米　电 %.0f" % [phase_name,int(world.rules.elapsed)/60,int(world.rules.elapsed)%60,world.hp,world.hunger,world.player.position.y,world.rules.charge]
	if not world.rules.volcano_armed: status.text = "自由探索 · 火山休眠　探索 %02d:%02d　生命 %.0f　饱食 %.0f　电 %.0f" % [int(world.rules.exploration_elapsed)/60,int(world.rules.exploration_elapsed)%60,world.hp,world.hunger,world.rules.charge]
	stock.text = "营地物资   木%d  果%d  铜%d  磁%d  晶%d  煤%d  水%d  |  阿角：%s" % [world.rules.stock.wood,world.rules.stock.food,world.rules.stock.copper,world.rules.stock.magnet,world.rules.stock.quartz,world.rules.stock.coal,world.rules.stock.water,world.buddy_status()]
	objective.text = world.world_status()
	hint.text = world.interaction_prompt()
	message.text = world.notice
func _base_snapshot() -> Dictionary:
	var controls: Array = []
	for node in buttons:
		controls.append({"text":node.text,"rect":[node.global_position.x,node.global_position.y,node.size.x,node.size.y],"disabled":node.disabled})
	return {"overlay":overlay,"blocked":blocked(),"story":story_text,"buttons":controls,"objective":objective.text,"hint":hint.text,"notice":message.text}
func show_world_settings() -> void:
	clear_panel("settings")
	density_sliders.clear()
	density_labels.clear()
	label(panel,"随机开放世界 / 自由探索",Vector2(25,16),25,Color("fff0c5"))
	label(panel,"同一种子形成同一世界。密度分别控制物资、恐龙与生态事件。",Vector2(25,54),15)
	label(panel,"种子",Vector2(25,93),17)
	seed_edit = LineEdit.new()
	seed_edit.position = Vector2(85,87)
	seed_edit.size = Vector2(240,34)
	seed_edit.text = str(world.world_seed)
	seed_edit.placeholder_text = "整数种子"
	panel.add_child(seed_edit)
	preset_control = OptionButton.new()
	preset_control.position = Vector2(370,87)
	preset_control.size = Vector2(270,34)
	for text in ["分层疏密 · 均衡","稀疏 · 远足与建造","浓密 · 丰富而危险"]: preset_control.add_item(text)
	preset_control.item_selected.connect(_select_preset)
	panel.add_child(preset_control)
	var names := {"resources":"资源密度","enemies":"捕食者密度","events":"生态事件密度"}
	var index := 0
	for key in names:
		var y := 140+index*43
		label(panel,names[key],Vector2(25,y),16)
		var slider := HSlider.new()
		slider.position = Vector2(160,y+2)
		slider.size = Vector2(380,26)
		slider.min_value = 0.0
		slider.max_value = 1.8
		slider.step = 0.1
		slider.value = float(world.world_densities.get(key,1.0))
		slider.value_changed.connect(_density_changed.bind(key))
		panel.add_child(slider)
		density_sliders[key] = slider
		density_labels[key] = label(panel,"%.1f×" % slider.value,Vector2(560,y),16,Color("f8d796"))
		index += 1
	settings_message = label(panel,"开始新世界 / 重置会清空该种子的物资、科技与采集记录；保存可稍后继续。",Vector2(25,275),14,Color("f8d796"))
	button("开始新世界 / 重置这个种子  [Enter]",310,_start_configured)
	var save_button := button("保存当前探索",352,_save_current)
	save_button.size.x = 298
	save_button.disabled = not world.started
	var load_button := button("读取输入种子的存档",352,_load_configured)
	load_button.position.x = 347
	load_button.size.x = 298
	if world.started: button("返回当前世界  [Esc]",394,close_overlay)
	else: label(panel,"WASD 移动 · E 采集 · M 查看地图 · N 主动开启六分钟火山挑战",Vector2(25,398),15)
	Low.readable_ui(panel)
func _density_changed(value: float, key: String) -> void:
	if density_labels.has(key): density_labels[key].text = "%.1f×" % value
func _select_preset(index: int) -> void:
	var density: float = [1.0,0.45,1.7][index]
	for slider in density_sliders.values(): slider.value = density
func _read_config() -> Dictionary:
	if not seed_edit.text.strip_edges().is_valid_int():
		settings_message.text = "种子需要填写一个整数，例如 20261006。"
		return {}
	var densities := {"decoration":1.0}
	for key in density_sliders: densities[key] = density_sliders[key].value
	return {"seed":int(seed_edit.text),"densities":densities}
func _start_configured() -> void:
	var config := _read_config()
	if not config.is_empty():
		world.start_new_world(config.seed,config.densities)
		if overlay == "settings": settings_message.text = world.notice
func _save_current() -> void:
	if world.save_exploration(): settings_message.text = "当前种子已保存。可关闭页面，之后输入此种子并读取。"
	else: settings_message.text = world.notice
func _load_configured() -> void:
	var config := _read_config()
	if config.is_empty(): return
	if not world.load_exploration(config.seed): settings_message.text = world.notice
func show_challenge() -> void:
	clear_panel("challenge")
	label(panel,"六分钟火山挑战",Vector2(25,28),27,Color("fff0c5"))
	if world.rules.volcano_armed:
		label(panel,"火山挑战已开启。\n第 5 分钟喷发，第 6 分钟结束。\n高地飞船 / 地下文明需要带上阿角。",Vector2(25,105),20)
	else:
		label(panel,"平时可以慢慢探索和建造，火山不会自行苏醒。\n按下开始后：第 5 分钟喷发，第 6 分钟结束。\n高地飞船 / 地下文明，两种结局都需要伙伴。\n开启前先备齐材料、科技和食水。",Vector2(25,100),20)
		button("现在开始火山挑战",310,world.start_volcano)
	button("继续探索  [Esc]",365,close_overlay)
	Low.readable_ui(panel)
func show_map() -> void:
	clear_panel("map")
	label(panel,"探索地图 / 营地方向",Vector2(25,22),26,Color("fff0c5"))
	label(panel,"营地："+world.home_bearing()+"　种子 "+str(world.world_seed),Vector2(25,73),17)
	label(panel,"北 W ↑　东 D →　南 S ↓　西 A ←\n\n东北沙色坡道：高地 +6m。\n南侧青色坡道：地下 −6m。\n\n东西或北方可以走出原山谷。\n东行请绕过坡道南口（Z ≈ 7）。\n采集野外资源，避开迅猛龙。\n\n新地形逐块生成，可以一直走。\n返回营地按方向与距离找路。\n原山谷的科技和阿角仍在那里。",Vector2(25,112),16)
	var center: Vector2i = world.stream.absolute_chunk(world.player.position)
	var origin := Vector2(428,139)
	for x in range(-2,3):
		for z in range(-2,3):
			var coord := center+Vector2i(x,z)
			var tile := ColorRect.new()
			tile.position = origin+Vector2(x+2,z+2)*34
			tile.size = Vector2(31,31)
			tile.color = world.stream.generator.COLORS[world.stream.generator.biome_at(coord.x*48,coord.y*48)] if world.stream.chunks.has(coord) else Color("294647")
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(tile)
			if coord == Vector2i.ZERO: label(panel,"营",tile.position+Vector2(7,3),17,Color.WHITE)
	var absolute: Vector3 = world._absolute(world.player.position)
	var marker := ColorRect.new()
	marker.position = origin+Vector2(2.5+(absolute.x-center.x*48)/48,2.5+(absolute.z-center.y*48)/48)*34-Vector2(3,3)
	marker.size = Vector2(6,6)
	marker.color = Color("ffe08d")
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(marker)
	label(panel,"↑ 北 / 地形色显示生态",Vector2(414,319),14)
	label(panel,"黄点：你　营：原山谷",Vector2(414,343),14,Color("f8d796"))
	button("返回探索  [M / Esc]",378,close_overlay)
	Low.readable_ui(panel)
func snapshot() -> Dictionary:
	var data := _base_snapshot()
	data.settings_button = [worldsettings_button.global_position.x,worldsettings_button.global_position.y,worldsettings_button.size.x,worldsettings_button.size.y]
	data.settings = {}
	if overlay == "settings":
		data.settings.seed = {"text":seed_edit.text,"rect":[seed_edit.global_position.x,seed_edit.global_position.y,seed_edit.size.x,seed_edit.size.y]}
		data.settings.preset = {"selected":preset_control.selected,"rect":[preset_control.global_position.x,preset_control.global_position.y,preset_control.size.x,preset_control.size.y]}
		data.settings.sliders = {}
		for key in density_sliders:
			var slider: HSlider = density_sliders[key]
			data.settings.sliders[key] = {"value":slider.value,"rect":[slider.global_position.x,slider.global_position.y,slider.size.x,slider.size.y]}
		data.settings.message = settings_message.text
	return data

func _small_button(text: String, index: int, callback: Callable) -> Button:
	var node := button("%d  %s" % [index+1,text],180+(index/2)*42,callback)
	node.position.x = 25+(index%2)*315
	node.size = Vector2(300,36)
	return node
func show_build_menu() -> void:
	clear_panel("build_menu")
	label(panel,"把营地建在你选择的地方",Vector2(25,18),25,Color("fff0c5"))
	label(panel,"选择设施 → WASD 移动预览 → R 旋转 → E / 左键放置。\n绿色可建，红色有冲突；Esc 取消。不会堵住科技坡道。",Vector2(25,58),17)
	var index := 0
	for kind in world.Colony.BUILDINGS:
		var recipe: Dictionary = world.Colony.BUILDINGS[kind]
		var cost := ""
		for key in recipe.cost: cost += NAMES[key]+str(recipe.cost[key])+" "
		button("%d  %s · %s" % [index+1,recipe.name,cost],130+index*43,world.begin_build_preview.bind(kind))
		index += 1
	button("继续探索  [B / Esc]",378,close_overlay)
	Low.readable_ui(panel)
func show_dinosaur(id: String) -> void:
	if not world.colony.relationships.has(id): return
	world.social_selected = id
	var record: Dictionary = world.colony.relationships[id]
	clear_panel("dinosaur")
	label(panel,"%s · %s · %s" % [record.name,world.Colony.SPECIES[record.species],record.temperament],Vector2(25,16),24,Color("fff0c5"))
	label(panel,"信任 %d / 35　%s\n专长：%s\n投喂1果，间隔5秒。工资：每45秒1果，缺粮暂停工作。" % [record.trust,"已雇佣" if record.hired else "野生朋友",world.Colony.SPECIALTIES[record.species]],Vector2(25,54),17)
	label(panel,world.notice,Vector2(25,139),14,Color("f8d796"))
	_small_button("问候 / 认识它",0,world.social_action.bind(id,"greet")).disabled = record.greeted
	_small_button("投喂 1 果",1,world.social_action.bind(id,"feed"))
	if not record.hired:
		_small_button("喂3果邀请阿角" if id == "core:buddy" else "雇佣 · 2果 / 信任35",2,world.social_action.bind(id,"hire")).disabled = record.trust < 35 and id != "core:buddy"
		label(panel,"迅猛龙可在7米外投喂；信任20后停止追击。\n关上对白后仍要小心，甩尾会损失12信任。" if record.kind == "predator" else "交朋友后可跟随、驻守、采集或照料营地设施。\n受雇伙伴不会随着旧地形消失。",Vector2(25,278),17)
	else:
		_small_button("跟随探索",2,world.assign_colony_task.bind(id,"follow"))
		_small_button("在这里驻守",3,world.assign_colony_task.bind(id,"guard"))
		_small_button("采集并送货",4,world.assign_colony_task.bind(id,"harvest"))
		var building_id: String = world.nearby_building()
		_small_button("为附近设施工作",5,world.assign_colony_task.bind(id,"work",building_id)).disabled = building_id == ""
		_small_button("解雇 · 保留友谊",6,world.social_action.bind(id,"dismiss"))
		if id == "core:buddy": _small_button("高地登船 / 地下安置",7,show_jobs)
	button("返回行动  [Esc]",378,close_overlay)
	Low.readable_ui(panel)
func show_colony() -> void:
	clear_panel("colony")
	label(panel,"伙伴名册 · 与所有恐龙成为朋友",Vector2(25,18),24,Color("fff0c5"))
	label(panel,"F 走近任意恐龙互动；迅猛龙可在7米外投喂。\n已雇佣伙伴每45秒需要1果，跟随、采集或照料设施。",Vector2(25,58),17)
	var ids: Array = world.hired_ids()
	if not ids.has("core:buddy") and ids.size() < 8: ids.append("core:buddy")
	for index in mini(ids.size(),8):
		var id: String = ids[index]
		var record: Dictionary = world.colony.relationships[id]
		button("%d  %s · %s · %s%s" % [index+1,record.name,world.Colony.SPECIES[record.species],world.Colony.TASKS.get(record.task,record.task) if record.hired else "尚未邀请", " · 缺粮" if not record.fed else ""],120+index*31,show_dinosaur.bind(id)).size.y = 29
	button("继续探索  [J / Esc]",378,close_overlay)
	Low.readable_ui(panel)
func show_building(id: String) -> void:
	if not world.colony.buildings.has(id): close_overlay(); return
	var building: Dictionary = world.colony.buildings[id]
	var recipe: Dictionary = world.Colony.BUILDINGS[building.kind]
	clear_panel("building")
	label(panel,"%s · 等级 %d / 3" % [recipe.name,building.level],Vector2(25,18),25,Color("fff0c5"))
	label(panel,recipe.detail+"\n产出 %d　存粮 %d　%s" % [building.produced,building.stored_food,"已经成熟" if building.ready else "正常运作"],Vector2(25,60),17)
	label(panel,world.notice,Vector2(25,116),14,Color("f8d796"))
	_small_button({"farm":"收获浆果 · 水1","workshop":"制作燃料 · 木2铜1","depot":"存入工资食物 · 果3","shelter":"吃1果休息治疗","beacon":"查看灯光与警戒"}[building.kind],0,world.use_colony_building.bind(id))
	_small_button("升级 · 木%d 铜%d" % [4*int(building.level),2*int(building.level)],1,world.upgrade_colony_building.bind(id)).disabled = building.level >= 3
	var index := 2
	for friend_id in world.hired_ids():
		if index >= 7: break
		var record: Dictionary = world.colony.relationships[friend_id]
		_small_button("派%s工作" % record.name,index,world.assign_colony_task.bind(friend_id,"work",id))
		index += 1
	_small_button("拆除 · 回收一半材料",index,world.demolish_colony_building.bind(id))
	button("返回行动  [Esc]",378,close_overlay)
	Low.readable_ui(panel)
