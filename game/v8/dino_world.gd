extends Node3D
const Low := preload("res://lowpoly/library.gd")
const Actor := preload("res://v8/dino_actor.gd")
const Rules := preload("res://v8/dino_rules.gd")
const UI := preload("res://v8/dino_ui.gd")
const Machines := preload("res://v5/machines.gd")
const Stream := preload("res://open_world/world_stream_v8.gd")
const Colony := preload("res://v8/colony_state.gd")
const Audio := preload("res://tonight_audio.gd")
const SITES := {"camp":Vector3(-1,0,3),"wheel":Vector3(7,0,2),"highland":Vector3(19,6,-14),"underground":Vector3(-1,-6,27)}
const SHIP_BOARD := Vector3(17,6,-12)
const BED := Vector3(-1,-6,25)
const DEPOSITS := [
	{"key":"wood","name":"树林","pos":Vector3(-4,0,1),"left":40,"model":"wood","color":Color("b8aa70")},
	{"key":"food","name":"浆果","pos":Vector3(-4,0,-3),"left":36,"model":"berry","color":Color("76a45e")},
	{"key":"copper","name":"铜矿","pos":Vector3(3,0,-3),"left":24,"model":"rock_small","color":Color("d99155")},
	{"key":"magnet","name":"磁石","pos":Vector3(2,0,-8),"left":8,"model":"rock_small","color":Color("80a7b6")},
	{"key":"quartz","name":"高地石英","pos":Vector3(15,6,-10),"left":12,"model":"rock_small","color":Color("d3f7db")},
	{"key":"coal","name":"地下煤层","pos":Vector3(4,-6,26),"left":24,"model":"rock_small","color":Color("455561")},
	{"key":"water","name":"水潭","pos":Vector3(5,0,3),"left":60,"model":"pot","color":Color("70d0d8")}
]
var rules = Rules.new()
var player: CharacterBody3D
var buddy: CharacterBody3D
var predator: CharacterBody3D
var ui: CanvasLayer
var camera: Camera3D
var held: Dictionary = {}
var resources: Array[Dictionary] = []
var machines: Dictionary = {}
var dynamic_root: Node3D
var lava: Node3D
var ash: Node3D
var volcano: Node3D
var ship: Node3D
var ship_fan: Node3D
var shelter_fan: Node3D
var started := false
var ending := ""
var hp := 100.0
var hunger := 100.0
var notice := "先到西北浆果丛采集，再回营地喂阿角。"
var notice_seconds := 0.0
var interact_cooldown := 0.0
var tail_cooldown := 0.0
var predator_fright := 0.0
var launch_seconds := -1.0
var story_history: Array[String] = []
var last_phase := "calm"
var valley_safe_seconds := 0.0
var qa_window: JavaScriptObject
var qa_json: JavaScriptObject
var qa_enabled := false
var qa_delay := 0.0
var stream: Node3D
var world_seed := 20261006
var world_densities := {"resources":1.0,"enemies":1.0,"events":1.0,"decoration":1.0}
var wildlife: Dictionary = {}
var discovered_chunks: Dictionary = {}
var generation_steps := 0
var colony = Colony.new()
var building_nodes: Dictionary = {}
var preview: Node3D
var preview_kind := ""
var preview_yaw := 0.0
var preview_absolute := Vector3.ZERO
var preview_reason := ""
var last_direction := Vector3(0,0,-1)
var social_selected := ""
var core_ground: Array[MeshInstance3D] = []
var hud_coord := Vector2i(2147483647,2147483647)
var hud_biome := ""
const SAVE_FIELDS := ["stage","elapsed","phase","charge","fuel_seconds","steam_seconds","sheltered_seconds","underground_power","volcano_armed","exploration_elapsed"]
func _start_stream() -> void:
	stream = Stream.new()
	stream.name = "SeededWorldStream"
	stream.configure(world_seed,"dino",world_densities)
	stream.chunk_loaded.connect(_on_chunk_loaded)
	stream.chunk_unloading.connect(_on_chunk_unloading)
	stream.origin_shifted.connect(_on_origin_shifted)
	add_child(stream)
	for visual in core_ground: stream.apply_core_ground(visual)
	stream.prime(player.position)
func _absolute(point: Vector3) -> Vector3:
	if not stream: return point
	return point+Vector3(stream.origin_chunk.x*48.0,0,stream.origin_chunk.y*48.0)
func _core_local(point: Vector3) -> Vector3:
	if not stream: return point
	return point-Vector3(stream.origin_chunk.x*48.0,0,stream.origin_chunk.y*48.0)
func _site(key: String) -> Vector3: return _core_local(SITES[key])
func terrain_ready(point: Vector3) -> bool:
	var absolute := _absolute(point)
	# Authored camp collision stays alive while terrain chunks are unloaded.
	return stream.generator.near_core(absolute.x,absolute.z) or stream.ready_at(point)
func _on_origin_shifted(delta: Vector3) -> void:
	for child in get_children():
		if child is Node3D and child != stream: child.position -= delta
	for deposit in resources: deposit.pos -= delta
	for index in buddy.route.size(): buddy.route[index] -= delta
	for beast in wildlife.values():
		if beast.node.get_parent() == self:
			for index in beast.node.route.size(): beast.node.route[index] -= delta
func _safe_floor() -> float:
	var point := _absolute(player.position)
	if point.x > -9 and point.x < 9 and point.z > 8 and point.z < 34: return -6.0
	return stream.generator.height_at(point.x,point.z)
func _on_chunk_loaded(coord: Vector2i, node: Node3D, description: Dictionary) -> void:
	generation_steps += 1
	for feature in description.features:
		var kind := str(feature.kind)
		if kind in ["wood","food","copper","magnet","quartz","coal","water"]:
			var state: Dictionary = stream.get_feature_state(feature.id)
			var left := int(state.get("left",feature.get("amount",12)))
			var marker := Node3D.new()
			marker.position = feature.pos
			node.add_child(marker)
			var model_key: String = {"wood":"wood","food":"berry","water":"pot"}.get(kind,"rock_small")
			var visual := Low.model(model_key,1.1 if kind == "wood" or kind == "food" else 0.75)
			visual.modulate = Color("80b065") if kind == "food" else Color("d1be91")
			marker.add_child(visual)
			var label := Label3D.new()
			label.position.y = 1.25
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.add_child(label)
			var deposit := {"key":kind,"name":"野外"+UI.NAMES[kind],"pos":marker.global_position,"left":left,"node":marker,"label":label,"feature_id":str(feature.id),"chunk":coord}
			resources.append(deposit)
			label.text = "%s ×%d" % [deposit.name,left]
			marker.visible = left > 0
		elif kind in ["predator","grazer"]:
			var id := str(feature.id)
			if wildlife.has(id): continue
			var absolute_home := Vector3(coord.x*48.0+feature.pos.x,feature.pos.y,coord.y*48.0+feature.pos.z)
			var record: Dictionary = colony.meet(id,kind,xyz(absolute_home),stream.get_feature_state(id).get("social",{}))
			if record.get("detached",false) and not record.hired:
				# Relocated former employees spawn in their current host chunk only.
				continue
			var creature := Actor.new()
			creature.world = self
			creature.name = "Generated"+kind+str(absi(id.hash()))
			creature.set_meta("dino_id",id)
			creature.position = feature.pos+Vector3(0,0.08,0)
			creature.speed = 3.7 if kind == "predator" else 2.0
			var model: String = {"velociraptor":"Velociraptor","triceratops":"Triceratops","stegosaurus":"Stegosaurus"}[record.species]
			creature.setup("res://assets/lowpoly/quaternius-dinosaur/"+model+".fbx",1.5 if kind == "predator" else 1.8,Color("ddaa95") if kind == "predator" else Color("b9cca5"))
			node.add_child(creature)
			if record.hired or record.get("detached",false):
				creature.reparent(self,true)
				creature.position = _core_local(_vector(record.xyz))
			wildlife[id] = {"kind":kind,"node":creature,"home":feature.pos,"fright":0.0,"chunk":coord,"phase":float(absi(id.hash())%628)/100.0}
			_social_label(creature,record)
	for id in colony.relationships:
		var record: Dictionary = colony.relationships[id]
		if not id.begins_with("core:") and record.get("detached",false) and not record.hired and not wildlife.has(id) and stream.absolute_chunk(_core_local(_vector(record.xyz))) == coord:
			_spawn_released_friend(id,coord,node)
	Low.readable_ui(node)
	_style_world_labels(node)
func _on_chunk_unloading(coord: Vector2i) -> void:
	for index in range(resources.size()-1,-1,-1):
		if resources[index].get("chunk",Vector2i(2147483647,2147483647)) == coord: resources.remove_at(index)
	for id in wildlife.keys():
		if wildlife[id].chunk == coord and wildlife[id].node.get_parent() != self:
			_journal_relationship(id)
			wildlife.erase(id)
func _step_wildlife(delta: float) -> void:
	for id in wildlife:
		var beast: Dictionary = wildlife[id]
		var actor: CharacterBody3D = beast.node
		var record: Dictionary = colony.relationships[id]
		if record.hired or actor.get_parent() == self:
			_step_colony_actor(id,actor,delta)
			continue
		beast.fright = maxf(0.0,beast.fright-delta)
		var local_player: Vector3 = actor.get_parent().to_local(player.position)
		var distance := actor.global_position.distance_to(player.position)
		var target: Vector3 = beast.home+Vector3(sin(rules.exploration_elapsed*0.25+beast.phase)*3,0,cos(rules.exploration_elapsed*0.19+beast.phase)*3)
		if beast.kind == "predator" and distance < 9.0 and record.trust < 20:
			var guarded: bool = _guarded(actor.global_position)
			if guarded: beast.fright = maxf(beast.fright,1.0)
			if beast.fright > 0: target = actor.position+(actor.position-local_player).normalized()*5.0
			else:
				target = local_player
				if distance < 1.55:
					hp -= delta*9.0
					notify("野外迅猛龙追来了！空格甩尾，或交给阿角守卫。")
		actor.drive = (Vector3(target.x,actor.position.y,target.z)-actor.position).normalized() if actor.position.distance_to(target) > 0.7 else Vector3.ZERO
		# Keep streamed actors in their owning chunk to unload them coherently.
		var next: Vector3 = actor.position+actor.drive*1.2
		if absf(next.x) > 22.5 or absf(next.z) > 22.5: actor.drive = (beast.home-actor.position).normalized()
		actor.step(delta)
		record.xyz = xyz(_absolute(actor.global_position))
func world_status() -> String:
	var has_camp := false
	for building in colony.buildings.values():
		if building.kind == "shelter": has_camp = true
	if not has_camp: return "山谷目标 1/3 · E 采木6、果2 → B 建休息棚 · 喷发倒计时 %.0f 秒" % maxf(0,(300-rules.elapsed)/3.75)
	if rules.elapsed < 300: return "山谷目标 2/3 · 安营完成！沿南侧青色坡道进入地下避难"
	return "山谷目标 3/3 · 火山喷发！进入地下，坚持5秒 · 已避难 %.0f/5" % valley_safe_seconds
func _legacy_world_status() -> String:
	if not stream: return "正在生成营地…"
	var coord: Vector2i = stream.absolute_chunk(player.position)
	discovered_chunks[str(coord)] = true
	if discovered_chunks.size() > 512: discovered_chunks.erase(discovered_chunks.keys()[0])
	if coord != hud_coord:
		hud_coord = coord
		hud_biome = str(stream.generator.describe(coord).biome_name)
	return "%s · 营地 %s · 已探索 %d 片区域 · 伙伴 %d / 8 · B 建设营地" % [hud_biome,home_bearing(),discovered_chunks.size(),hired_ids().size()]
func home_bearing() -> String:
	var direction: Vector3 = _site("camp")-player.position
	if Vector2(direction.x,direction.z).length() < 5.0: return "就在附近"
	var letters := ""
	if absf(direction.z) > 0.3*absf(direction.x): letters += "南" if direction.z > 0 else "北"
	if absf(direction.x) > 0.3*absf(direction.z): letters += "东" if direction.x > 0 else "西"
	return "%s %.0fm" % [letters,Vector2(direction.x,direction.z).length()]
func start_volcano() -> void:
	if rules.arm_volcano():
		last_phase = "calm"
		ui.close_overlay()
		say("六分钟火山挑战已开始。\n第 5 分钟喷发，第 6 分钟结束。\n带阿角飞上天空，或在地下守住第一盏灯。")
func start_new_world(seed_value: int, densities: Dictionary) -> void:
	stream.flush_save()
	if stream.save_error != "":
		notify(stream.save_error+"。当前世界保留，请稍后重试。")
		return
	if not stream.reset_world(seed_value,densities):
		notify(stream.save_error+"。当前世界保留，请稍后重试。")
		return
	world_seed = seed_value
	world_densities = densities.duplicate()
	stream.clear_world_state()
	if FileAccess.file_exists(_save_path()): DirAccess.remove_absolute(_save_path())
	_restart_core()
	discovered_chunks.clear()
	hud_coord = Vector2i(2147483647,2147483647)
	# clear_world_state clears the delta journal; rebuild terrain instances too.
	stream.reset_world(world_seed,world_densities)
	stream.prime(player.position)
	ui.close_overlay()
	notice = "新种子 %d · 自由探索。物资和科技从零开始，火山休眠。" % world_seed
func restart() -> void: start_new_world(world_seed,world_densities)
func _save_path() -> String: return "user://dino_v8_progress_%d.json" % world_seed
func save_exploration() -> bool:
	stream.flush_save()
	if stream.save_error != "": notify(stream.save_error); return false
	_sync_relationship_positions()
	var data := {"version":8,"seed":world_seed,"densities":world_densities,"stock":rules.stock,"built":rules.built,"player":xyz(_absolute(player.position)),"hp":hp,"hunger":hunger,"rules":{},"core_left":[],"buddy":{"xyz":xyz(_absolute(buddy.position)),"recruited":buddy.recruited,"job":buddy.job,"pending_job":buddy.pending_job,"work_phase":buddy.work_phase,"carrying":buddy.carrying,"carried_key":buddy.carried_key,"total_delivered":buddy.total_delivered,"work_timer":buddy.work_timer,"route":[]},"discovered":discovered_chunks.keys(),"colony":colony.snapshot()}
	for field in SAVE_FIELDS: data.rules[field] = rules.get(field)
	for deposit in resources:
		if not deposit.has("feature_id"): data.core_left.append(deposit.left)
	for point in buddy.route: data.buddy.route.append(xyz(_absolute(point)))
	var file := FileAccess.open(_save_path(),FileAccess.WRITE)
	if not file: notify("保存失败，请检查浏览器存储空间。"); return false
	file.store_string(JSON.stringify(data))
	notify("已保存：当前种子的物资、伙伴、科技、位置与野外采集变化。")
	return true
func _vector(values: Array) -> Vector3: return Vector3(float(values[0]),float(values[1]),float(values[2]))
func load_exploration(seed_value: int) -> bool:
	var path := "user://dino_v8_progress_%d.json" % seed_value
	if not FileAccess.file_exists(path): notify("这个种子还没有保存。开始新世界后，设置页可以保存。"); return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version",0) != 8 or int(data.get("seed",0)) != seed_value: notify("存档版本或种子不匹配，当前世界保持原样。"); return false
	for key in ["densities","stock","built","player","rules","core_left","buddy"]:
		if not data.has(key): notify("存档不完整，当前世界保持原样。"); return false
	stream.flush_save()
	if stream.save_error != "": notify(stream.save_error+"。当前世界保留，请稍后重试。"); return false
	if not stream.reset_world(seed_value,data.densities): notify(stream.save_error+"。当前世界保留，请稍后重试。"); return false
	world_seed = seed_value
	world_densities = data.densities.duplicate()
	_restart_core()
	colony.restore(data.get("colony",{}))
	_restore_colony_nodes()
	for material in rules.stock: rules.stock[material] = int(data.stock.get(material,0))
	rules.built = data.built.duplicate()
	for field in SAVE_FIELDS:
		if data.rules.has(field): rules.set(field,data.rules[field])
	for key in rules.built: _build_invention(key)
	for index in mini(DEPOSITS.size(),data.core_left.size()):
		resources[index].left = int(data.core_left[index])
		_refresh_deposit(resources[index])
	player.position = _vector(data.player)
	player.velocity = Vector3.ZERO
	hp = float(data.get("hp",100.0))
	hunger = float(data.get("hunger",100.0))
	buddy.position = _vector(data.buddy.xyz)
	for field in ["recruited","job","pending_job","work_phase","carrying","carried_key","total_delivered","work_timer"]:
		if data.buddy.has(field): buddy.set(field,data.buddy[field])
	buddy.route.clear()
	for point in data.buddy.get("route",[]): buddy.route.append(_vector(point))
	buddy.get_child(buddy.get_child_count()-1).text = "阿角 · 已招募" if buddy.recruited else "阿角 · E 喂 3 果招募"
	discovered_chunks.clear()
	for key in data.get("discovered",[]): discovered_chunks[key] = true
	while discovered_chunks.size() > 512: discovered_chunks.erase(discovered_chunks.keys()[0])
	hud_coord = Vector2i(2147483647,2147483647)
	stream.prime(player.position)
	last_phase = rules.phase
	ui.close_overlay()
	notice = "已读取种子 %d。野外耗尽资源不会重新生长。" % world_seed
	_update_camera(1.0)
	return true
func snapshot() -> Dictionary:
	var data := _legacy_snapshot()
	data.world = stream.snapshot()
	data.seed = world_seed
	data.densities = world_densities.duplicate()
	data.player_absolute = xyz(_absolute(player.position))
	data.volcano_armed = rules.volcano_armed
	data.exploration_elapsed = rules.exploration_elapsed
	data.home_bearing = home_bearing()
	data.discovered = discovered_chunks.size()
	data.active_resources = resources.size()
	data.wildlife = []
	for id in wildlife:
		var beast: Dictionary = wildlife[id]
		data.wildlife.append({"id":id,"kind":beast.kind,"xyz":xyz(beast.node.global_position),"absolute":xyz(_absolute(beast.node.global_position)),"screen":project(beast.node.global_position),"fright":beast.fright,"relationship":colony.relationships[id].duplicate(true)})
	data.colony = colony.snapshot()
	data.colony.recruits = hired_ids()
	data.colony.nearby_dinosaur = nearby_dinosaur()
	data.colony.nearby_building = nearby_building()
	data.colony.preview = {"active":preview_kind != "","kind":preview_kind,"yaw":preview_yaw,"absolute":xyz(preview_absolute),"valid":preview_reason == "","reason":preview_reason,"screen":project(_core_local(preview_absolute))}
	data.version = 8
	for index in resources.size():
		data.resources[index].id = resources[index].get("feature_id","core:"+resources[index].key)
		data.resources[index].generated = resources[index].has("feature_id")
	return data
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_world()
	_build_actors()
	_seed_deposits()
	_start_stream()
	ui = UI.new()
	ui.world = self
	add_child(ui)
	Low.readable_ui(self)
	_style_world_labels(self)
	if OS.has_feature("web"):
		qa_window = JavaScriptBridge.get_interface("window")
		qa_json = JavaScriptBridge.get_interface("JSON")
		qa_enabled = qa_window != null and str(qa_window.location.search).contains("qa=1")
	_update_camera(1.0)
func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("90b4ae")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d2dac0")
	settings.ambient_light_energy = 0.75
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_color = Color("fff3d5")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 27
	camera.far = 160
	camera.current = true
	add_child(camera)
	# Ground has a physical southern opening. Nothing teleports between levels.
	platform(Vector3(54,0.5,32),Vector3(0,-0.25,-8),Color("6f8b5e"))
	platform(Vector3(20,0.5,24),Vector3(-17,-0.25,20),Color("748b61"))
	platform(Vector3(20,0.5,24),Vector3(17,-0.25,20),Color("748b61"))
	# Northeast ramp rises six metres over twelve metres; top meets highland.
	platform(Vector3(6,0.45,sqrt(180.0)),Vector3(11,2.76,0),Color("c1ac7a"),atan(0.5))
	platform(Vector3(20,6.5,15),Vector3(17,2.75,-13.5),Color("b1a071"))
	# Underground ramp enters actual geometry at y=-6, with open cutaway view.
	platform(Vector3(8,0.45,sqrt(180.0)),Vector3(0,-3.24,14),Color("9b967b"),atan(0.5))
	platform(Vector3(17,0.6,13),Vector3(0,-6.3,26.5),Color("50656a"))
	for side in [-1,1]:
		platform(Vector3(0.7,4,13),Vector3(side*8.5,-4,26.5),Color("465653"))
		for z in [22,27,32]:
			var stone := Low.model("rock",2.4)
			stone.position = Vector3(side*7.6,-6,z)
			add_child(stone)
	platform(Vector3(17,3,0.5),Vector3(0,-4.5,33),Color("465653"))
	# Visible ramp guide rails use alternating warm stones.
	for step in 7:
		for x in [7.5,14.5]: Low.box(self,Vector3(0.28,0.28,0.55),Vector3(x,float(step)+0.2,6-step*2),Color("e0cf99"))
	for step in 7:
		for x in [-4.3,4.3]: Low.box(self,Vector3(0.3,0.3,0.6),Vector3(x,-float(step)+0.15,8+step*2),Color("87d9cd"))
	world_label("东北高地 +6m\n沿沙色坡道向北",Vector3(11,1.5,6),Color("ffdda3"))
	world_label("地下 −6m\n沿青色坡道向南",Vector3(0,1.1,8),Color("a3f1df"))
	world_label("营地 · 交货与科技",_site("camp")+Vector3(0,2.4,0),Color("ffe7a4"))
	world_label("飞船建造台",_site("highland")+Vector3(0,1.2,0),Color("ffe7a4"))
	world_label("地下文明 · 寝室 / 电缆 / 食水",_site("underground")+Vector3(0,1.1,0),Color("b8f4e6"))
	var camp := Low.model("tent",1.6)
	camp.position = Vector3(-2,0,6)
	add_child(camp)
	var marker := Low.model("campfire",0.55)
	marker.position = _site("camp")+Vector3(-1.5,0,-1)
	add_child(marker)
	Low.box(self,Vector3(3,0.08,2),_site("camp")+Vector3(0,0.05,0),Color("a7a270"))
	Low.box(self,Vector3(5,0.08,5),_site("highland")+Vector3(0,0.05,0),Color("8e9273"))
	Low.box(self,Vector3(5,0.05,5),_site("underground")+Vector3(0,0.04,0),Color("69857c"))
	var pond := CylinderMesh.new()
	pond.top_radius = 2.2
	pond.bottom_radius = 2.2
	pond.height = 0.06
	pond.radial_segments = 12
	Low.mesh(self,pond,Vector3(5,0.03,3),Color("489baf"))
	for point in [Vector3(-21,0,5),Vector3(-19,0,-6),Vector3(-12,0,-16),Vector3(-6,0,-15),Vector3(5,0,-16),Vector3(23,6,-17),Vector3(25,0,3),Vector3(20,0,10),Vector3(-21,0,19)]:
		var tree := Low.model("tree",3.0)
		tree.position = point
		add_child(tree)
	volcano = Node3D.new()
	volcano.position = Vector3(-8,0,-30)
	add_child(volcano)
	Low.cylinder(volcano,2.2,8.0,12,Vector3(0,6,0),Color("71675e"))
	Low.cylinder(volcano,1.8,1.6,0.25,Vector3(0,12.1,0),Color("ed844f"),true)
	world_label("火山 · 05:00 喷发",Vector3(-8,14,-30),Color("ffd594"))
	lava = Node3D.new()
	add_child(lava)
	Low.box(lava,Vector3(53,0.06,31),Vector3(0,0.035,-8),Color("dd7340"))
	Low.box(lava,Vector3(7.8,0.06,10),Vector3(0,-0.08,13),Color("cf6034"))
	lava.hide()
	ash = Node3D.new()
	add_child(ash)
	for index in 28:
		Low.box(ash,Vector3(0.06,0.1,0.06),Vector3((index*17%44)-22,5+(index%5),((index*13)%40)-20),Color("4d5050"))
	ash.hide()
	dynamic_root = Node3D.new()
	add_child(dynamic_root)
func platform(size: Vector3, pos: Vector3, color: Color, angle := 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.x = angle
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := Low.box(body,size,Vector3.ZERO,color)
	if angle == 0.0 and pos.y > -1.0 and size.y < 1.0: core_ground.append(visual)
func world_label(text: String, pos: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.outline_size = 3
	label.font_size = 36
	label.pixel_size = 0.012
	add_child(label)
	return label
func _style_world_labels(node: Node) -> void:
	# Shared font helper resets outline size; preserve V6 world-label contrast after it.
	if node is Label3D:
		node.outline_modulate = Color("102a2d")
		node.outline_size = 8
	for child in node.get_children(): _style_world_labels(child)
func _build_actors() -> void:
	player = Actor.new()
	player.name = "ModernMindTrex"
	player.position = Vector3(-5,0.05,4)
	player.world = self
	player.setup("res://assets/lowpoly/quaternius-dinosaur/Trex.fbx",1.9)
	add_child(player)
	buddy = Actor.new()
	buddy.name = "TriceratopsCompanion"
	buddy.speed = 5.0
	buddy.position = Vector3(-8,0.05,2)
	buddy.world = self
	buddy.setup("res://assets/lowpoly/quaternius-dinosaur/Triceratops.fbx",1.65,Color("b9deaa"))
	add_child(buddy)
	var buddy_label := Label3D.new()
	buddy_label.text = "阿角 · E 喂 3 果招募"
	buddy_label.position.y = 2.25
	buddy_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	buddy.add_child(buddy_label)
	predator = Actor.new()
	predator.name = "WildVelociraptor"
	predator.speed = 4.1
	predator.position = Vector3(-18,0.05,-10)
	predator.world = self
	predator.setup("res://assets/lowpoly/quaternius-dinosaur/Velociraptor.fbx",1.5,Color("deafa3"))
	add_child(predator)
	_register_core_relationships()
func _seed_deposits() -> void:
	resources.clear()
	for definition in DEPOSITS:
		var deposit: Dictionary = definition.duplicate(true)
		var node := Node3D.new()
		node.position = deposit.pos
		dynamic_root.add_child(node)
		var visual := Low.model(deposit.model,0.65 if deposit.key != "food" else 1.1)
		visual.modulate = deposit.color
		node.add_child(visual)
		var label := Label3D.new()
		label.text = "%s ×%d" % [deposit.name,deposit.left]
		label.position.y = 1.0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		node.add_child(label)
		deposit.node = node
		deposit.label = label
		resources.append(deposit)
func begin() -> void:
	started = true
	story_history.append("末班地铁之后，我醒成了恐龙。先把灯造回来。")
	ui.close_overlay()
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and preview_kind != "" and not ui.blocked():
		confirm_build_preview()
		return
	if not event is InputEventKey: return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if not event.pressed:
		held.erase(code)
		return
	if event.echo: return
	if ui.blocked():
		ui.key(code)
		get_viewport().set_input_as_handled()
		return
	if not started or ending != "": return
	held[code] = true
	match code:
		KEY_E: interact()
		KEY_F:
			var friend_id := nearby_dinosaur()
			if friend_id != "": ui.show_dinosaur(friend_id)
		KEY_B: ui.show_build_menu()
		KEY_N: ui.show_challenge()
		KEY_M: ui.show_map()
		KEY_F2: ui.show_world_settings()
		KEY_C: ui.show_craft()
		KEY_J: ui.show_colony()
		KEY_ESCAPE:
			if preview_kind != "": cancel_build_preview()
			else: ui.show_pause()
		KEY_Q: eat()
		KEY_R:
			if preview_kind != "": preview_yaw += PI/2; _update_build_preview()
			else: drink()
		KEY_SPACE: tail()
func _physics_process(delta: float) -> void:
	if stream: stream.step(player.position)
	if not started or ui.blocked() or ending != "":
		player.drive = Vector3.ZERO
		return
	interact_cooldown = maxf(0,interact_cooldown-delta)
	tail_cooldown = maxf(0,tail_cooldown-delta)
	predator_fright = maxf(0,predator_fright-delta)
	if launch_seconds >= 0:
		launch_seconds += delta
		ship.position.y = _site("highland").y+launch_seconds*1.8
		player.position = ship.position+Vector3(-1,0.2,0)
		buddy.position = ship.position+Vector3(1,0.2,0)
		if launch_seconds >= 8: finish("flight")
	else:
		var input_axis := Vector3(float(held.has(KEY_D) or held.has(KEY_RIGHT))-float(held.has(KEY_A) or held.has(KEY_LEFT)),0,float(held.has(KEY_S) or held.has(KEY_DOWN))-float(held.has(KEY_W) or held.has(KEY_UP)))
		player.drive = input_axis.normalized()
		if player.drive.length() > 0.1: last_direction = player.drive
		player.step(delta)
		_step_buddy(delta)
		_step_predator(delta)
		_step_wildlife(delta)
		_step_colony(delta)
		if not rules.volcano_armed: rules.arm_volcano()
		rules.tick(delta*3.75,player.position.y < -4,buddy_sheltered())
		var has_camp := false
		for building in colony.buildings.values():
			if building.kind == "shelter": has_camp = true
		if has_camp and rules.elapsed >= 300 and player.position.y < -4:
			valley_safe_seconds += delta
			if valley_safe_seconds >= 5: finish("civilization")
		hunger = maxf(0,hunger-delta*0.13)
		hp -= delta*(rules.surface_damage(_absolute(player.position))+(1.2 if hunger <= 0 else 0.0))
		if player.position.y < _safe_floor()-12.0: hp = 0
		if hp <= 0: finish("dead")
		elif rules.can_settle(player.position.y < -4,buddy_sheltered()): finish("civilization")
	_update_machines(delta)
	_update_phase()
	_update_camera(delta)
func _process(delta: float) -> void:
	if not ui: return
	if preview_kind != "": _update_build_preview()
	for deposit in resources:
		deposit.label.visible = deposit.left > 0 and deposit.pos.distance_to(player.position) < 7.5
	for id in wildlife:
		var social_label: Label3D = wildlife[id].node.get_node_or_null("SocialLabel")
		if social_label: social_label.visible = wildlife[id].node.global_position.distance_to(player.position) < 10
	ui.refresh()
	qa_delay += delta
	if qa_enabled and qa_delay >= 0.1:
		qa_delay = 0
		qa_window.__v8_dino_qa = qa_json.parse(JSON.stringify(snapshot()))
func _update_camera(delta: float) -> void:
	var focus := player.position+Vector3(0,0.8,0)
	var desired := focus+Vector3(16,22,25)
	camera.position = camera.position.lerp(desired,minf(1,delta*4.0))
	camera.look_at(focus)
func _update_phase() -> void:
	lava.visible = rules.phase == "eruption"
	ash.visible = rules.elapsed >= 240 and rules.elapsed < 360
	for index in ash.get_child_count():
		ash.get_child(index).position.y = 2+fmod(10-index*0.31-rules.elapsed*1.9,7)
	if rules.phase == last_phase: return
	last_phase = rules.phase
	match rules.phase:
		"warning": say("火山的低鸣越来越近。第 5 分钟喷发。\n准备飞船，或把寝室、电缆、食水带进地下。")
		"ash": say("灰烬堵住了水轮，灯靠存电撑着。\n蒸汽动力能继续发电；营地 E 可以添煤加水。")
		"eruption": say("地表已经烧起来了。\n这次我要带走的，不只是自己的便利。\n让阿角上船，或者一起在地下守住灯。")
		"after": notify("喷发已经结束。地下的灯和同伴，仍在吗？")
func resource_target() -> int:
	var best := 2.3
	var target := -1
	for index in resources.size():
		var distance: float = player.position.distance_to(resources[index].pos)
		if resources[index].left > 0 and distance < best:
			best = distance
			target = index
	return target
func interaction_prompt() -> String:
	if not started: return ""
	if launch_seconds >= 0: return "飞船正在升空 · 灯和伙伴都在船上"
	if preview_kind != "": return "%s · R 旋转 / E 建造 / Esc 取消 · %s" % [Colony.BUILDINGS[preview_kind].name,"可以放置" if preview_reason == "" else preview_reason]
	var context := _interaction_context()
	if context.kind == "resource":
		var deposit: Dictionary = resources[context.index]
		return "E 采集 %s +2 · 剩 %d · F 恐龙互动" % [deposit.name,deposit.left]
	if context.kind == "building": return "E 使用 %s Lv%d · F 恐龙互动" % [Colony.BUILDINGS[colony.buildings[context.id].kind].name,colony.buildings[context.id].level]
	if context.kind == "ship": return "E 发射飞船 · 喷发后 / 电25 / 阿角登船"
	if context.kind == "steam": return "E 蒸汽机添煤加水 · 煤1 + 水1 / 180秒"
	var friend_id := nearby_dinosaur()
	if friend_id != "":
		var record: Dictionary = colony.relationships[friend_id]
		return "E 与%s互动 · %s · 信任%d / 35 · %s" % [record.name,Colony.SPECIES[record.species],record.trust,"已雇佣" if record.hired else "问候 / 喂食 / 雇佣"]
	return "WASD 探索 · B 营地建设 · J 伙伴 · C 科技 · M 地图 · F2 保存"
func interact() -> void:
	if interact_cooldown > 0: return
	interact_cooldown = 0.24
	if preview_kind != "":
		confirm_build_preview()
		return
	var context := _interaction_context()
	if context.kind == "building": ui.show_building(context.id); return
	if context.kind == "resource":
		var target: int = context.index
		var deposit: Dictionary = resources[target]
		var count: int = mini(2,deposit.left)
		deposit.left -= count
		rules.stock[deposit.key] += count
		_refresh_deposit(deposit)
		notify("%s +%d，存入营地物资。" % [deposit.name,count])
		Audio.play(self,760,0.06)
		return
	if context.kind == "ship":
		launch()
	elif context.kind == "steam":
		if rules.refuel(): notify("锅炉已添煤加水：多运行 180 秒。")
		else: notify("添煤加水需要煤1、水1。")
	else:
		var id := nearby_dinosaur()
		if id != "": ui.show_dinosaur(id)
func _interaction_context() -> Dictionary:
	# Physical world actions take precedence over followers; F always talks.
	var result := {"kind":"none","id":"","index":-1}
	var best := INF
	var target := resource_target()
	if target >= 0: best = player.position.distance_to(resources[target].pos); result = {"kind":"resource","index":target,"id":""}
	var id := nearby_building()
	if id != "":
		var distance := player.position.distance_to(_core_local(_vector(colony.buildings[id].xyz)))
		if distance < best: best = distance; result = {"kind":"building","id":id,"index":-1}
	var ship_distance := player.position.distance_to(_site("highland"))
	if rules.built.has("ship") and ship_distance < 3.5 and ship_distance < best:
		best = ship_distance; result = {"kind":"ship","id":"","index":-1}
	var steam_distance := player.position.distance_to(_site("camp"))
	if rules.built.has("steam") and steam_distance < 2.6 and steam_distance < best: result = {"kind":"steam","id":"","index":-1}
	return result
func _refresh_deposit(deposit: Dictionary) -> void:
	if deposit.has("feature_id"):
		stream.set_feature_state(deposit.feature_id,{"left":deposit.left})
	deposit.label.text = "%s ×%d" % [deposit.name,deposit.left]
	deposit.node.visible = deposit.left > 0
func recruit() -> bool:
	if buddy.recruited or player.position.distance_to(buddy.position) > 2.6: return false
	if hired_ids().size() >= 8: notify("营地最多8位伙伴，请先解雇一位。"); return false
	if rules.stock.food < 3:
		notify("阿角需要 3 颗果子。去西北浆果丛按 E 采集。")
		return false
	rules.stock.food -= 3
	buddy.recruited = true
	buddy.job = "follow"
	var record: Dictionary = colony.relationships["core:buddy"]
	record.hired = true; record.trust = maxi(35,int(record.trust)); record.task = "follow"
	buddy.get_child(buddy.get_child_count()-1).text = "阿角 · 已招募"
	say("它把第三颗果子推回给我。\n阿角，你想要的不是工作，是一同活下去。\n按 J 安排采木、搬矿或守卫。")
	return true
func assign_job(job: String) -> void:
	if not buddy.recruited: return
	if job not in UI.JOBS: return
	var record: Dictionary = colony.relationships["core:buddy"]
	if buddy.job == "colony" and record.carry > 0:
		buddy.carrying = int(record.carry); buddy.carried_key = str(record.carry_key)
		record.carry = 0; record.carry_key = ""
		buddy.job = "harvest"; buddy.work_phase = "returning"
		buddy.route = route_to(_site("camp")+Vector3(0,0,-0.6))
	# Already-carried materials remain physically with the worker until delivered.
	if buddy.carrying > 0:
		buddy.pending_job = job
		ui.close_overlay()
		notify("已排队：%s。阿角先交货，随后自动换工作。" % UI.JOB_LABELS[job])
		return
	buddy.pending_job = ""
	buddy.job = job
	colony.relationships["core:buddy"].task = job
	buddy.work_phase = "walking"
	buddy.work_timer = 0
	match job:
		"harvest": buddy.route = route_to(resources[0].pos)
		"haul": buddy.route = route_to(resources[2].pos)
		"shelter": buddy.route = route_to(_core_local(BED))
		"board": buddy.route = route_to(_core_local(SHIP_BOARD))
		"guard": buddy.route = route_to(_site("camp")+Vector3(-2,0,-2))
		"follow": buddy.route.clear()
	ui.close_overlay()
	notify("阿角收到安排，会沿实体坡道亲自走到目的地。")
func route_to(target: Vector3, actor: CharacterBody3D = null) -> Array[Vector3]:
	var target_core := _absolute(target)
	var buddy_core := _absolute(buddy.position if actor == null else actor.position)
	var source_highland: bool = buddy_core.y > 4.5 and Rect2(7,-22,21,18).has_point(Vector2(buddy_core.x,buddy_core.z))
	var target_highland: bool = target_core.y > 4.5 and Rect2(7,-22,21,18).has_point(Vector2(target_core.x,target_core.z))
	var source_below: bool = buddy_core.y < -3 and Rect2(-9,8,18,26).has_point(Vector2(buddy_core.x,buddy_core.z))
	var target_below: bool = target_core.y < -3 and Rect2(-9,8,18,26).has_point(Vector2(target_core.x,target_core.z))
	var route: Array[Vector3] = []
	if source_highland and not target_highland:
		route.append(Vector3(11,6,-8)); route.append(Vector3(11,0,6))
	if source_below and not target_below:
		route.append(Vector3(0,-6,21)); route.append(Vector3(0,0,7))
	if target_highland and not source_highland:
		# Enter from the ramp's southern ground face. A diagonal from camp
		# reaches the raised side wall before its walkable incline, and web
		# physics can hold the companion there. Bypass the camp machines west.
		if buddy_core.y >= -3:
			if buddy_core.x < 3 and buddy_core.z < 6.7:
				route.append(Vector3(-5.5,0,buddy_core.z))
				route.append(Vector3(-5.5,0,7.2))
			else:
				route.append(Vector3(buddy_core.x,0,7.2))
		route.append(Vector3(7,0,7.2))
		route.append(Vector3(11,0,7.2))
		route.append(Vector3(11,6,-8))
	if target_below and not source_below:
		route.append(Vector3(0,0,7)); route.append(Vector3(0,-6,22))
	route.append(target_core)
	for index in route.size(): route[index] = _core_local(route[index])
	return route
func _step_buddy(delta: float) -> void:
	if buddy.job == "colony": return
	if colony.relationships.has("core:buddy") and not colony.relationships["core:buddy"].fed:
		buddy.drive = Vector3.ZERO; buddy.step(delta); return
	if not buddy.recruited:
		buddy.drive = Vector3.ZERO
		buddy.step(delta)
		return
	if buddy.job == "follow":
		if buddy.route.is_empty() and player.position.distance_to(buddy.position) > 3: buddy.route = route_to(player.position-Vector3(1,0,1))
		buddy.follow_route(delta)
		return
	var arrived: bool = buddy.follow_route(delta)
	if not arrived: return
	if buddy.job not in ["harvest","haul"]: return
	var index := 0 if buddy.job == "harvest" else 2
	if buddy.work_phase == "returning":
		rules.stock[buddy.carried_key] += buddy.carrying
		buddy.total_delivered += buddy.carrying
		notify("阿角把 %s%d 送回营地。" % [UI.NAMES[buddy.carried_key],buddy.carrying])
		buddy.carrying = 0
		buddy.carried_key = ""
		buddy.work_phase = "walking"
		buddy.route = route_to(resources[index].pos)
		buddy.get_child(0).modulate = Color("b9deaa")
		if buddy.pending_job != "":
			var next_job: String = buddy.pending_job
			buddy.pending_job = ""
			assign_job(next_job)
			notify("阿角已把物资交回营地，现在开始%s。" % UI.JOB_LABELS[next_job])
		return
	buddy.work_timer += delta
	if buddy.work_timer >= 1.2 and resources[index].left > 0:
		buddy.work_timer = 0
		buddy.carrying = mini(2,resources[index].left)
		buddy.carried_key = resources[index].key
		resources[index].left -= buddy.carrying
		_refresh_deposit(resources[index])
		buddy.work_phase = "returning"
		buddy.route = route_to(_site("camp")+Vector3(0,0,-0.6))
		buddy.get_child(0).modulate = Color("ffe19b")
	elif resources[index].left <= 0:
		buddy.job = "guard"
		buddy.route = route_to(_site("camp")+Vector3(-2,0,-2))
		notify("采集点已空，阿角回营地守卫。")
func buddy_boarded() -> bool:
	return buddy.recruited and buddy.job == "board" and buddy.position.distance_to(_core_local(SHIP_BOARD)) < 1.4
func buddy_sheltered() -> bool:
	return buddy.recruited and buddy.job == "shelter" and buddy.position.y < -4 and buddy.position.distance_to(_core_local(BED)) < 2
func buddy_status() -> String:
	if buddy.job == "colony": return Colony.TASKS.get(colony.relationships["core:buddy"].task,"休息")
	if not buddy.recruited: return "未招募"
	if buddy.carrying > 0:
		var status := "背%s%d回营" % [UI.NAMES[buddy.carried_key],buddy.carrying]
		if buddy.pending_job != "": status += "→%s(排队)" % UI.JOB_LABELS[buddy.pending_job]
		return status
	return UI.JOB_LABELS.get(buddy.job,"休息")
func _step_predator(delta: float) -> void:
	var record: Dictionary = colony.relationships["core:predator"]
	if record.hired:
		_step_colony_actor("core:predator",predator,delta)
		return
	var target := _core_local(Vector3(-18,0,-10))
	var chasing: bool = record.trust < 20 and player.position.y > -1 and player.position.y < 2 and player.position.distance_to(predator.position) < 8
	var guarded: bool = _guarded(predator.position)
	if guarded: predator_fright = maxf(1,predator_fright)
	if chasing and predator_fright <= 0:
		target = player.position
		if player.position.distance_to(predator.position) < 1.55:
			hp -= delta*12
			notify("野生迅猛龙在攻击！空格甩尾，或回阿角守卫的营地。")
	elif predator_fright > 0: target = predator.position+(predator.position-player.position).normalized()*4
	predator.drive = (Vector3(target.x,predator.position.y,target.z)-predator.position).normalized() if predator.position.distance_to(target) > 0.8 else Vector3.ZERO
	predator.step(delta)
func tail() -> void:
	if tail_cooldown > 0: return
	for id in wildlife:
		var beast: Dictionary = wildlife[id]
		if beast.kind == "predator" and not colony.relationships[id].hired and beast.node.global_position.distance_to(player.position) < 4.0:
			beast.fright = 4.0
			colony.relationships[id].trust = maxi(0,int(colony.relationships[id].trust)-12)
	tail_cooldown = 1.2
	Audio.play(self,180,0.12)
	if player.position.distance_to(predator.position) < 4:
		predator_fright = 4
		if not colony.relationships["core:predator"].hired: colony.relationships["core:predator"].trust = maxi(0,int(colony.relationships["core:predator"].trust)-12)
		notify("尾巴赶跑了迅猛龙。趁现在离开它的领地。")
	else: notify("甩尾！靠近捕食者时能把它赶开。")
func eat() -> void:
	if rules.stock.food < 1: notify("营地没果子了。西北浆果丛 E 采集。"); return
	rules.stock.food -= 1
	hunger = minf(100,hunger+35)
	hp = minf(100,hp+12)
	notify("吃掉 1 果，恢复饱食与生命。地下储备另需 6 果。")
func drink() -> void:
	if rules.stock.water < 1: notify("营地没水了。水潭 E 装水。"); return
	rules.stock.water -= 1
	hp = minf(100,hp+16)
	notify("喝掉 1 水，生命 +16。锅炉与地下储备也需要水。")
func craft(key: String) -> bool:
	if not Rules.RECIPES.has(key): return false
	var recipe: Dictionary = Rules.RECIPES[key]
	if player.position.distance_to(_site(recipe.site)) > 3.5:
		ui.overlay_status.text = "请先走近%s。菜单暂停时间，关闭后沿坡道前往。" % {"wheel":"水潭旁的水轮台","camp":"营地","highland":"东北高地的飞船台","underground":"南边地下营地"}[recipe.site]
		return false
	if not rules.craft(key):
		ui.overlay_status.text = "材料、蓄电或前置科技不足。水轮 → 灯泡 → 蒸汽；费用见按钮。"
		return false
	_build_invention(key)
	ui.close_overlay()
	match key:
		"wheel": say("我用尾巴转动了水轮。\n还记得电磁感应，真好。营地终于有电了。\n沿东北坡道找石英，再回营地点灯。")
		"lamp": say("第一盏灯亮了。阿角也凑过来。\n原来，把光分给别人，并不会让我少一点。\n南边地下有煤，下一步是蒸汽动力。")
		"steam": say("灰会停住水轮，但停不住蒸汽。\n现在可以准备飞船，或者地下寝室、电缆与食水。\n按 J 让阿角登船，或在地下安置。")
		_: notify("%s已建成。准备好伙伴，等待真正的喷发。" % recipe.name)
	return true
func _build_invention(key: String) -> void:
	if key in ["wheel","lamp","steam"]:
		var index: int = ["wheel","lamp","steam"].find(key)
		var machine: Dictionary = Machines.make(index)
		machine.node.position = _site("wheel") if index == 0 else _site("camp")+Vector3(0 if index == 1 else 2,0,0)
		dynamic_root.add_child(machine.node)
		machines[key] = machine
	elif key == "ship":
		ship = Node3D.new()
		ship.position = _site("highland")
		dynamic_root.add_child(ship)
		Low.cylinder(ship,1.05,1.1,3.7,Vector3(0,2.65,0),Color("eddbb0"))
		Low.cylinder(ship,0,1.05,1.8,Vector3(0,5.4,0),Color("c87b52"))
		Low.cylinder(ship,1.07,1.07,0.5,Vector3(0,3.6,0),Color("73b8bd"))
		Low.cylinder(ship,0.55,0.7,0.7,Vector3(0,0.6,0),Color("51676d"))
		for angle in 4:
			var fin := Node3D.new()
			fin.rotation.y = angle*PI/2
			ship.add_child(fin)
			var wing := Low.box(fin,Vector3(0.18,1.65,1.8),Vector3(0,1.1,1.3),Color("c87b52"))
			wing.rotation.x = -0.25
		var ship_body := StaticBody3D.new()
		var ship_collision := CollisionShape3D.new()
		var ship_shape := CylinderShape3D.new()
		ship_shape.radius = 1.12
		ship_shape.height = 4.4
		ship_collision.shape = ship_shape
		ship_collision.position.y = 2.6
		ship_body.add_child(ship_collision)
		ship.add_child(ship_body)
		ship_fan = Node3D.new()
		ship_fan.position = Vector3(0,-0.7,0)
		ship.add_child(ship_fan)
		Low.cylinder(ship_fan,0.38,0,2.4,Vector3.ZERO,Color("ffab51"),true)
		ship_fan.hide()
		var light := OmniLight3D.new()
		light.position = Vector3(0,1.5,0)
		light.light_color = Color("ffe2a6")
		light.omni_range = 6
		ship.add_child(light)
	elif key == "shelter":
		for x in [-4,2]:
			var tent := Low.model("tent",1.6)
			tent.position = _core_local(Vector3(x,-6,29))
			dynamic_root.add_child(tent)
		shelter_fan = Node3D.new()
		shelter_fan.position = _core_local(Vector3(-5,-3.8,26))
		dynamic_root.add_child(shelter_fan)
		for index in 4:
			var blade := Low.box(shelter_fan,Vector3(0.12,1.3,0.15),Vector3.ZERO,Color("b6cdc0"))
			blade.rotation.z = index*PI/4
	elif key == "cable":
		for step in 11:
			var point := _core_local(Vector3(-4.8,-float(maxi(0,step-3))*0.8+0.5,7+step*2))
			Low.box(dynamic_root,Vector3(0.08,0.08,2.1),point,Color("e9c66d"))
		var light := OmniLight3D.new()
		light.position = _core_local(Vector3(0,-3,27))
		light.light_color = Color("83f0cd")
		light.omni_range = 9
		light.light_energy = 1.8
		dynamic_root.add_child(light)
	elif key == "provisions":
		for x in [-2,0]:
			var barrel := Low.model("barrel",0.9)
			barrel.position = _core_local(Vector3(x,-6,31))
			dynamic_root.add_child(barrel)
	Low.readable_ui(dynamic_root)
	_style_world_labels(dynamic_root)
func _update_machines(delta: float) -> void:
	if machines.has("wheel") and rules.wheel_running: machines.wheel.rotor.rotation.z -= delta*2
	if machines.has("lamp"):
		machines.lamp.light.visible = rules.lamp_on
		machines.lamp.bulb.material_override.emission_enabled = rules.lamp_on
	if machines.has("steam") and rules.steam_running:
		machines.steam.rotor.rotation.z += delta*5
		machines.steam.piston.position.x = 0.9+sin(rules.elapsed*8)*0.18
	if shelter_fan and rules.underground_power > 0: shelter_fan.rotation.z += delta*3
	if ship_fan and launch_seconds >= 0:
		ship_fan.show()
		ship_fan.scale = Vector3.ONE*(0.9+sin(launch_seconds*25)*0.12)
func launch() -> bool:
	if not rules.can_launch(buddy_boarded()):
		notify("发射需要：已喷发、飞船建成、蒸汽运行5秒、电25、阿角真正登船。")
		return false
	rules.charge -= 25
	launch_seconds = 0
	say("阿角踏上了甲板。我最后看了一眼山谷。\n我们的第一盏灯，会在天空继续亮着。")
	return true
func say(text: String) -> void:
	story_history.append(text)
	ui.show_story(text)
func notify(text: String) -> void:
	notice = text
func objective() -> String:
	if not buddy.recruited: return "目标 1 / 西北采 3 果，走近阿角 E 招募；J 派它采木或搬矿。"
	if rules.stage == 0: return "目标 2 / 木3 铜2 磁1 → 水潭 C 造水轮；东北坡道上有石英。"
	if rules.stage == 1: return "目标 3 / 东北高地采石英 → 营地 C 造灯泡；蓄电至少 8。"
	if rules.stage == 2: return "目标 4 / 南边地下采煤、水潭装水 → 营地 C 造蒸汽动力。"
	if rules.built.has("ship"): return "逃离路线 / J 让阿角登船；喷发后走近飞船 E 发射，真正升空。"
	if rules.underground_ready(): return "文明路线 / J 让阿角地下安置；你也下去，灯亮着活过 06:00。"
	return "选择未来 / 高地飞船，或地下寝室+电缆+食水。J 安置伙伴，等待喷发。"
func finish(result: String) -> void:
	ending = result
	held.clear()
	ui.show_end(result)
func _restart_core() -> void:
	cancel_build_preview()
	for node in building_nodes.values(): node.queue_free()
	building_nodes.clear()
	for id in wildlife.keys():
		if wildlife[id].node.get_parent() == self: wildlife[id].node.queue_free()
	wildlife.clear()
	colony = Colony.new()
	for child in dynamic_root.get_children():
		dynamic_root.remove_child(child)
		child.queue_free()
	rules = Rules.new()
	machines.clear()
	ship = null
	ship_fan = null
	shelter_fan = null
	hp = 100
	hunger = 100
	ending = ""
	launch_seconds = -1
	last_phase = "calm"
	story_history.clear()
	held.clear()
	player.position = Vector3(-5,0.05,4)
	player.velocity = Vector3.ZERO
	buddy.position = Vector3(-8,0.05,2)
	buddy.velocity = Vector3.ZERO
	buddy.recruited = false
	buddy.job = "idle"
	buddy.pending_job = ""
	buddy.route.clear()
	buddy.carrying = 0
	buddy.total_delivered = 0
	buddy.work_timer = 0
	buddy.visual.modulate = Color("b9deaa")
	buddy.get_child(buddy.get_child_count()-1).text = "阿角 · E 喂 3 果招募"
	predator.position = Vector3(-18,0.05,-10)
	predator.velocity = Vector3.ZERO
	predator_fright = 0
	_register_core_relationships()
	interact_cooldown = 0
	lava.hide()
	ash.hide()
	_seed_deposits()
	Low.readable_ui(dynamic_root)
	_style_world_labels(dynamic_root)
	started = true
	ui.close_overlay()
	say("末班地铁之后，我又醒在这片山谷。\n这一次，先交一个朋友，再把灯造回来。")
func _legacy_snapshot() -> Dictionary:
	var landmarks: Array = []
	for deposit in resources:
		landmarks.append({"key":deposit.key,"name":deposit.name,"xyz":xyz(deposit.pos),"left":deposit.left,"screen":project(deposit.pos+Vector3(0,0.5,0))})
	var stations: Dictionary = {}
	for key in SITES: stations[key] = {"xyz":xyz(_site(key)),"screen":project(_site(key))}
	return {"version":7,"kind":"dino","player":xyz(player.position),"player_screen":project(player.position),"hp":hp,"hunger":hunger,"started":started,"ending":ending,"timer":rules.elapsed,"phase":rules.phase,"stage":rules.stage,"charge":rules.charge,"stock":rules.stock.duplicate(),"built":rules.built.duplicate(),"fuel_seconds":rules.fuel_seconds,"steam_seconds":rules.steam_seconds,"underground_power":rules.underground_power,"sheltered_seconds":rules.sheltered_seconds,"launch_seconds":launch_seconds,"resources":landmarks,"stations":stations,"buddy":{"xyz":xyz(buddy.position),"screen":project(buddy.position),"recruited":buddy.recruited,"job":buddy.job,"pending_job":buddy.pending_job,"work_phase":buddy.work_phase,"carrying":buddy.carrying,"carried_key":buddy.carried_key,"total_delivered":buddy.total_delivered,"boarded":buddy_boarded(),"sheltered":buddy_sheltered()},"predator":{"xyz":xyz(predator.position),"fright":predator_fright},"ui":ui.snapshot(),"story_history":story_history.duplicate(),"routes":{"highland":[xyz(Vector3(7,0,7.2)),xyz(Vector3(11,0,7.2)),xyz(Vector3(11,6,-8)),xyz(_site("highland"))],"underground":[xyz(Vector3(0,0,7)),xyz(Vector3(0,-6,22)),xyz(_site("underground"))]}}
func xyz(value: Vector3) -> Array: return [snappedf(value.x,0.01),snappedf(value.y,0.01),snappedf(value.z,0.01)]
func project(value: Vector3) -> Array:
	var point := camera.unproject_position(value)
	return [snappedf(point.x,0.1),snappedf(point.y,0.1)]

func _register_core_relationships() -> void:
	colony.meet("core:buddy","grazer",xyz(Vector3(-8,0.05,2)))
	colony.meet("core:predator","predator",xyz(Vector3(-18,0.05,-10)))
	buddy.set_meta("dino_id","core:buddy")
	predator.set_meta("dino_id","core:predator")
	_social_label(predator,colony.relationships["core:predator"])
func _social_label(actor: CharacterBody3D, record: Dictionary) -> void:
	var label: Label3D = actor.get_node_or_null("SocialLabel")
	if not label:
		label = Label3D.new(); label.name = "SocialLabel"; label.position.y = 2.3
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.font_size = 26; label.pixel_size = 0.013
		label.outline_size = 6; label.outline_modulate = Color("102a2d"); actor.add_child(label)
	label.text = "%s · %s\n%s · 信任 %d" % [record.name,Colony.SPECIES[record.species],Colony.TASKS.get(record.task,"野生") if record.hired else record.temperament,record.trust]
func _actor_for(id: String) -> CharacterBody3D:
	if id == "core:buddy": return buddy
	if id == "core:predator": return predator
	if wildlife.has(id): return wildlife[id].node
	return null
func hired_ids() -> Array[String]:
	var result: Array[String] = []
	for id in colony.relationships:
		if colony.relationships[id].hired: result.append(id)
	return result
func nearby_dinosaur() -> String:
	var result := ""
	var best := INF
	var ids: Array = wildlife.keys()+["core:buddy","core:predator"]
	for id in ids:
		var actor := _actor_for(id)
		if not is_instance_valid(actor): continue
		var record: Dictionary = colony.relationships[id]
		var distance := actor.global_position.distance_to(player.position)
		var range_limit := 7.0 if record.kind == "predator" and not record.hired else 3.4
		if distance < range_limit and distance < best: best = distance; result = id
	return result
func _journal_relationship(id: String) -> void:
	var record: Dictionary = colony.relationships[id]
	var actor := _actor_for(id)
	if is_instance_valid(actor): record.xyz = xyz(_absolute(actor.global_position))
	if not id.begins_with("core:"):
		var state: Dictionary = stream.get_feature_state(id)
		state.social = record.duplicate(true)
		stream.set_feature_state(id,state)
func _sync_relationship_positions() -> void:
	for id in colony.relationships:
		var actor := _actor_for(id)
		if is_instance_valid(actor): colony.relationships[id].xyz = xyz(_absolute(actor.global_position))
func social_action(id: String, action: String) -> bool:
	var actor := _actor_for(id)
	if not is_instance_valid(actor): notify("这位朋友在远方，走近后才能互动。"); return false
	var limit := 7.2 if colony.relationships[id].kind == "predator" else 3.7
	if actor.global_position.distance_to(player.position) > limit: notify("请先走近这只恐龙。"); return false
	var record: Dictionary = colony.relationships[id]
	# The original three-fruit 阿角 route remains a quick first-friend tutorial.
	if id == "core:buddy" and action == "hire" and not buddy.recruited:
		if rules.stock.food < 3: notify("阿角需要3果。去西北浆果丛采集。"); return false
		ui.close_overlay()
		return recruit()
	var response: Dictionary = colony.social(id,action,rules.stock,rules.exploration_elapsed)
	notify(response.message)
	if not response.ok:
		if ui.overlay == "dinosaur": ui.show_dinosaur(id)
		return false
	if action == "hire":
		record.detached = true
		actor.route.clear(); actor.speed = 8.0
		if actor.get_parent() != self: actor.reparent(self,true)
	elif action == "dismiss":
		if record.carry > 0:
			rules.stock[record.carry_key] += int(record.carry); record.carry = 0
		if id == "core:buddy": buddy.recruited = false; buddy.job = "idle"; buddy.route.clear()
		actor.route.clear()
	_journal_relationship(id)
	if action == "dismiss" and not id.begins_with("core:"):
		var coord: Vector2i = stream.absolute_chunk(actor.global_position)
		if stream.chunks.has(coord):
			actor.reparent(stream.chunks[coord],true)
			wildlife[id].chunk = coord; wildlife[id].home = actor.position
		else:
			wildlife.erase(id); actor.queue_free()
	if id != "core:buddy" and is_instance_valid(actor): _social_label(actor,record)
	if ui.overlay == "dinosaur": ui.show_dinosaur(id)
	return true
func assign_colony_task(id: String, task: String, building_id := "") -> bool:
	if not colony.assign(id,task,xyz(_absolute(player.position)),building_id): return false
	var actor := _actor_for(id)
	if is_instance_valid(actor): actor.route.clear()
	if id == "core:buddy":
		var record: Dictionary = colony.relationships[id]
		if buddy.carrying > 0:
			record.carry = buddy.carrying; record.carry_key = buddy.carried_key
			buddy.carrying = 0; buddy.carried_key = ""
		buddy.pending_job = ""; buddy.work_phase = "walking"; buddy.work_timer = 0.0
		buddy.job = "colony"
	ui.close_overlay()
	notify("%s：%s。每45秒1果工资；缺粮时休息，投喂可恢复。" % [colony.relationships[id].name,Colony.TASKS[task]])
	_journal_relationship(id)
	return true
func _guarded(point: Vector3) -> bool:
	if buddy.recruited and buddy.job == "guard" and colony.relationships["core:buddy"].fed and buddy.position.distance_to(point) < 5: return true
	for id in hired_ids():
		var record: Dictionary = colony.relationships[id]
		var actor := _actor_for(id)
		if is_instance_valid(actor) and record.fed and record.task == "guard":
			var radius := 9.0 if record.species == "velociraptor" else 6.0
			if _near_powered_beacon(actor.position): radius += 3
			if actor.global_position.distance_to(point) < radius: return true
	return false
func _near_powered_beacon(point: Vector3) -> bool:
	for building in colony.buildings.values():
		if building.kind == "beacon" and building.powered and _core_local(_vector(building.xyz)).distance_to(point) < 9: return true
	return false
func _walk_actor(actor: CharacterBody3D, target: Vector3, delta: float, radius := 1.0) -> bool:
	if Vector2(actor.position.x-target.x,actor.position.z-target.z).length() < radius and absf(actor.position.y-target.y) < 1.4:
		actor.drive = Vector3.ZERO; actor.step(delta); return true
	if actor.route.is_empty() or actor.route[-1].distance_to(target) > 2: actor.route = route_to(target,actor)
	actor.follow_route(delta)
	return false
func _deposit_for_worker(record: Dictionary, actor: CharacterBody3D) -> Dictionary:
	var best := 55.0
	var result := {}
	for deposit in resources:
		if deposit.left <= 0 or deposit.key not in ["wood","food","copper"]: continue
		var distance: float = deposit.pos.distance_to(actor.position)
		# Grazers are gatherers; raptors can still help but prefer food.
		if record.species == "velociraptor" and deposit.key != "food": distance *= 1.3
		if distance < best: best = distance; result = deposit
	return result
func _delivery_point(actor: CharacterBody3D) -> Vector3:
	var point := _site("camp")+Vector3(0,0,-0.6)
	var best := actor.position.distance_to(point)
	for building in colony.buildings.values():
		if building.kind != "depot": continue
		var target := _core_local(_vector(building.xyz))+Vector3(0,0,2)
		var distance := actor.position.distance_to(target)
		if distance < best: point = target; best = distance
	return point
func _step_colony_actor(id: String, actor: CharacterBody3D, delta: float) -> void:
	var record: Dictionary = colony.relationships[id]
	# A remote stationary employee is parked, never allowed to fall through unloaded terrain.
	if not terrain_ready(actor.global_position): actor.velocity = Vector3.ZERO; actor.drive = Vector3.ZERO; return
	if not record.hired or not record.fed:
		actor.drive = Vector3.ZERO; actor.step(delta); return
	actor.speed = 8.0 if record.task == "follow" else 4.8
	# Reassignment never abandons a real load: deliver before the new task.
	if record.carry > 0:
		if _walk_actor(actor,_delivery_point(actor),delta,1.0):
			rules.stock[record.carry_key] += int(record.carry); record.delivered += int(record.carry)
			if id == "core:buddy": buddy.total_delivered += int(record.carry)
			notify("%s已交回%s%d，继续%s。" % [record.name,UI.NAMES[record.carry_key],record.carry,Colony.TASKS.get(record.task,"工作")])
			record.carry = 0; record.carry_key = ""; actor.route.clear()
		record.xyz = xyz(_absolute(actor.global_position))
		return
	if record.task == "follow":
		_walk_actor(actor,player.position-last_direction*2.4,delta,2.1)
	elif record.task == "guard":
		var guard_point := _core_local(_vector(record.guard_xyz))
		if record.species == "velociraptor": guard_point += Vector3(sin(rules.exploration_elapsed*0.4)*2,0,cos(rules.exploration_elapsed*0.4)*2)
		_walk_actor(actor,guard_point,delta,1.0)
	elif record.task == "harvest":
		if record.carry > 0:
			if _walk_actor(actor,_delivery_point(actor),delta,1.0):
				rules.stock[record.carry_key] += int(record.carry); record.delivered += int(record.carry)
				notify("%s送来%s%d。" % [record.name,UI.NAMES[record.carry_key],record.carry])
				record.carry = 0; actor.route.clear()
		else:
			var deposit := _deposit_for_worker(record,actor)
			if deposit.is_empty(): actor.drive = Vector3.ZERO; actor.step(delta)
			elif _walk_actor(actor,deposit.pos,delta,1.8):
				record.work_timer += delta
				if record.work_timer >= 1.4:
					record.work_timer = 0.0
					record.carry = mini(3 if record.species == "triceratops" else 2,int(deposit.left))
					record.carry_key = deposit.key; deposit.left -= int(record.carry)
					_refresh_deposit(deposit); actor.route.clear()
	elif record.task == "work" and colony.buildings.has(record.building):
		var building: Dictionary = colony.buildings[record.building]
		if _walk_actor(actor,_core_local(_vector(building.xyz))+Vector3(0,0,2.2),delta,0.9):
			record.work_timer += delta*(1.4 if record.species == "stegosaurus" else 1.0)
			if building.kind == "workshop" and record.work_timer >= 12:
				record.work_timer = 0.0; _process_workshop(building)
	else: actor.drive = Vector3.ZERO; actor.step(delta)
	record.xyz = xyz(_absolute(actor.global_position))
func _step_colony(delta: float) -> void:
	colony.relationships["core:buddy"].xyz = xyz(_absolute(buddy.position))
	colony.relationships["core:predator"].xyz = xyz(_absolute(predator.position))
	for id in hired_ids():
		var record: Dictionary = colony.relationships[id]
		record.wage_timer += delta
		while record.wage_timer >= 45:
			record.wage_timer -= 45.0
			var paid := false
			for building in colony.buildings.values():
				if building.kind == "depot" and building.stored_food > 0 and _vector(building.xyz).distance_to(_vector(record.xyz)) < 18+int(building.level)*5:
					building.stored_food -= 1; paid = true; break
			if not paid and rules.stock.food > 0: rules.stock.food -= 1; paid = true
			record.fed = paid
			if not paid: notify("%s缺少工资食物，暂停工作。喂1果可恢复。" % record.name)
	if buddy.job == "colony" and buddy.recruited: _step_colony_actor("core:buddy",buddy,delta)
	for building in colony.buildings.values():
		var point := _core_local(_vector(building.xyz))
		if building.kind == "farm" and not building.ready:
			var rate := 1.0
			for id in hired_ids():
				var record: Dictionary = colony.relationships[id]
				var actor := _actor_for(id)
				if record.task == "work" and record.building == building.id and record.fed and is_instance_valid(actor) and actor.position.distance_to(point) < 4:
					rate += 1.4 if record.species == "stegosaurus" else 1.0
			if _near_powered_beacon(point): rate += 0.25
			building.progress += delta*rate
			if building.progress >= 20.0/float(building.level): building.ready = true
		if building.kind == "beacon":
			building.powered = rules.built.has("lamp") and rules.charge > 0.2
			if building.powered: rules.charge = maxf(0,rules.charge-delta*0.15)
			if building_nodes.has(building.id): building_nodes[building.id].get_node("ColonyLight").visible = building.powered
		if building.kind == "shelter" and point.distance_to(player.position) < 5.5:
			hp = minf(100,hp+delta*0.8*int(building.level)); hunger = minf(100,hunger+delta*0.08)
		if building_nodes.has(building.id):
			var label: Label3D = building_nodes[building.id].get_node("BuildingLabel")
			label.visible = point.distance_to(player.position) < 12
			label.text = "%s Lv%d%s" % [Colony.BUILDINGS[building.kind].name,building.level," · 可以收获" if building.kind == "farm" and building.ready else ""]
func nearby_building() -> String:
	var best := 4.3
	var result := ""
	for id in colony.buildings:
		var distance := _core_local(_vector(colony.buildings[id].xyz)).distance_to(player.position)
		if distance < best: best = distance; result = id
	return result
func _placement_reason(kind: String, point: Vector3, yaw: float) -> String:
	if not Colony.BUILDINGS.has(kind): return "未知建筑"
	var local := _core_local(point)
	if not terrain_ready(local): return "等待地形生成"
	var rect: Rect2 = colony.footprint(kind,point,yaw,0.6)
	for reserved in [Rect2(-6,7,12,27),Rect2(7,-22,21,31),Rect2(-4,-1,10,8)]:
		if rect.intersects(reserved): return "保留坡道、营地科技与避难通路"
	for deposit in resources:
		var absolute := _absolute(deposit.pos)
		if rect.grow(1.2).has_point(Vector2(absolute.x,absolute.z)): return "请给采集点留出空间"
	for id in colony.buildings:
		var building: Dictionary = colony.buildings[id]
		if rect.intersects(colony.footprint(building.kind,_vector(building.xyz),building.yaw,0.5)): return "与已有建筑重叠"
	var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	var low := INF; var high := -INF
	for corner: Vector2 in corners:
		var height: float = stream.generator.height_at(corner.x,corner.y)
		low = minf(low,height); high = maxf(high,height)
	if high-low > 0.9: return "坡度太大，请找平地"
	if absf(point.y-stream.generator.height_at(point.x,point.z)) > 1.1: return "需要放在地面"
	if kind in ["workshop","beacon"] and not rules.built.has("lamp"): return "需要先用 C 造出科技灯泡"
	if not colony.afford(rules.stock,Colony.BUILDINGS[kind].cost): return "材料不足，费用见 B 菜单"
	return ""
func begin_build_preview(kind: String) -> void:
	cancel_build_preview(); preview_kind = kind; preview_yaw = 0.0
	preview = Node3D.new(); preview.name = "ConstructionPreview"; add_child(preview)
	var dims: Array = Colony.BUILDINGS[kind].size
	Low.box(preview,Vector3(dims[0],0.10,dims[1]),Vector3(0,0.12,0),Color("86dfb0"))
	Low.box(preview,Vector3(0.25,0.3,0.8),Vector3(0,0.3,-float(dims[1])/2),Color("ffecaa"))
	ui.close_overlay(); _update_build_preview()
func cancel_build_preview() -> void:
	preview_kind = ""
	if is_instance_valid(preview): preview.queue_free()
	preview = null
func _update_build_preview() -> void:
	if preview_kind == "" or not is_instance_valid(preview): return
	var point := _absolute(player.position+last_direction*4.8)
	point.x = snappedf(point.x,0.5); point.z = snappedf(point.z,0.5)
	point.y = stream.generator.height_at(point.x,point.z)
	preview_absolute = point; preview_reason = _placement_reason(preview_kind,point,preview_yaw)
	preview.position = _core_local(point)+Vector3(0,0.06,0); preview.rotation.y = preview_yaw
	for visual in preview.get_children():
		if visual is MeshInstance3D: visual.material_override.albedo_color = Color("8bdfb4") if preview_reason == "" else Color("e87d71")
func confirm_build_preview() -> bool:
	_update_build_preview()
	if preview_kind == "": return false
	if not place_colony_building(preview_kind,preview_absolute,preview_yaw): return false
	cancel_build_preview(); return true
func place_colony_building(kind: String, point: Vector3, yaw: float) -> bool:
	var reason := _placement_reason(kind,point,yaw)
	if reason != "": notify(reason+"。未扣材料。"); return false
	var id: String = colony.construct(kind,point,yaw,rules.stock)
	if id == "": return false
	_build_colony_visual(colony.buildings[id]); notify(Colony.BUILDINGS[kind].name+"建成，靠近 E 使用、派工和升级。")
	return true
func _build_colony_visual(building: Dictionary) -> void:
	var root := Node3D.new(); root.name = "Colony"+str(building.id).replace(":","_")
	root.position = _core_local(_vector(building.xyz)); root.rotation.y = float(building.yaw); add_child(root)
	building_nodes[building.id] = root
	var dims: Array = Colony.BUILDINGS[building.kind].size
	Low.box(root,Vector3(dims[0],0.12,dims[1]),Vector3(0,0.06,0),Color("a8936b"))
	if building.kind == "farm":
		for x in [-0.8,0.8]:
			for z in [-0.7,0.7]:
				var plant := Low.model("berry",0.65); plant.position = Vector3(x,0.15,z); root.add_child(plant)
		for z in [-1.5,1.5]: Low.box(root,Vector3(3,0.26,0.12),Vector3(0,0.15,z),Color("6d5b47"))
	elif building.kind == "depot":
		for x in [-0.8,0.8]:
			var crate := Low.model("barrel",0.9); crate.position = Vector3(x,0.12,0); root.add_child(crate)
	elif building.kind == "workshop":
		Low.box(root,Vector3(2.7,0.25,1.5),Vector3(0,1.0,0),Color("bc9668"))
		for x in [-1.0,1.0]: Low.box(root,Vector3(0.20,0.9,1.0),Vector3(x,0.5,0),Color("755d49"))
		Low.box(root,Vector3(0.9,0.4,0.7),Vector3(-0.5,1.35,0),Color("5f787d"))
	elif building.kind == "shelter":
		var tent := Low.model("tent",2.0); tent.position.y = 0.1; root.add_child(tent)
	elif building.kind == "beacon":
		Low.box(root,Vector3(0.2,2.7,0.2),Vector3(0,1.4,0),Color("876d52"))
		Low.box(root,Vector3(0.75,0.5,0.75),Vector3(0,2.75,0),Color("ffe6a0"))
		var light := OmniLight3D.new(); light.name = "ColonyLight"; light.position.y = 2.7
		light.light_color = Color("ffe8ba"); light.light_energy = 2.0+int(building.level)*0.5; light.omni_range = 9.0+int(building.level)*2.0; root.add_child(light)
	var body := StaticBody3D.new(); body.name = "BuildingCollision"; root.add_child(body)
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new()
	shape.size = Vector3(dims[0],0.9,dims[1]); collision.shape = shape; collision.position.y = 0.5; body.add_child(collision)
	var label := Label3D.new(); label.name = "BuildingLabel"; label.position.y = 3.25 if building.kind == "beacon" else 2.4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.font_size = 28; label.pixel_size = 0.012; root.add_child(label)
	Low.readable_ui(root); _style_world_labels(root)
func _process_workshop(building: Dictionary) -> bool:
	if not rules.built.has("lamp") or not colony.afford(rules.stock,{"wood":2,"copper":1}): return false
	colony.spend(rules.stock,{"wood":2,"copper":1}); var count := 1+int(building.level)
	rules.stock.coal += count; building.produced += count
	notify("燃料工坊：木2铜1 → 煤%d，可给蒸汽机添燃料。" % count)
	return true
func use_colony_building(id: String) -> bool:
	if not colony.buildings.has(id): return false
	var building: Dictionary = colony.buildings[id]
	if player.position.distance_to(_core_local(_vector(building.xyz))) > 4.5: notify("请先走近设施。"); return false
	var ok := false
	match building.kind:
		"depot":
			if rules.stock.food >= 3 and int(building.stored_food)+3 <= 6+int(building.level)*6:
				rules.stock.food -= 3; building.stored_food += 3; ok = true
				notify("存入3果，附近伙伴优先从仓库领取工资。容量%d，范围%d米。" % [6+int(building.level)*6,18+int(building.level)*5])
			else: notify("補给仓需要3果与空位；升级增加容量和发粮范围。")
		"farm":
			if not building.ready: notify("浆果还在生长，派伙伴照料可加快成熟。")
			elif rules.stock.water < 1: notify("收获需1水灌溉，去水潭采集。")
			else:
				rules.stock.water -= 1; var count := 1+int(building.level)*2
				rules.stock.food += count; building.produced += count; building.ready = false; building.progress = 0.0
				ok = true; notify("农圃收获%d果，用水1。" % count)
		"workshop": ok = _process_workshop(building)
		"shelter":
			if rules.stock.food > 0:
				rules.stock.food -= 1; hp = minf(100,hp+25*int(building.level)); hunger = minf(100,hunger+20)
				ok = true; notify("在休息棚吃1果，恢复生命和饱食。")
		"beacon": notify("灯塔%s；每秒耗电0.15，扩大附近守卫警戒。" % ("亮着" if building.powered else "需要科技灯泡与蓄电")); ok = building.powered
	if ui.overlay == "building": ui.show_building(id)
	return ok
func upgrade_colony_building(id: String) -> bool:
	if not colony.buildings.has(id) or player.position.distance_to(_core_local(_vector(colony.buildings[id].xyz))) > 4.5: return false
	if not colony.upgrade(id,rules.stock): notify("升级需要木%d铜%d，最高3级。" % [4*int(colony.buildings[id].level),2*int(colony.buildings[id].level)]); return false
	building_nodes[id].queue_free(); building_nodes.erase(id); _build_colony_visual(colony.buildings[id])
	notify("升级完成：农圃更快、收获更多；工坊煤产量、休息治疗和灯塔照明提高。")
	if ui.overlay == "building": ui.show_building(id)
	return true
func demolish_colony_building(id: String) -> bool:
	if not colony.buildings.has(id) or player.position.distance_to(_core_local(_vector(colony.buildings[id].xyz))) > 4.5: return false
	if not colony.demolish(id,rules.stock): return false
	building_nodes[id].queue_free(); building_nodes.erase(id); ui.close_overlay()
	notify("已拆除，返还已花材料的一半与仓库存粮。伙伴转为驻守。")
	return true
func _restore_colony_nodes() -> void:
	for building in colony.buildings.values(): _build_colony_visual(building)
	for id in colony.relationships:
		var record: Dictionary = colony.relationships[id]
		if id.begins_with("core:"): continue
		if not record.hired: continue
		if wildlife.has(id): wildlife[id].node.queue_free(); wildlife.erase(id)
		var actor := Actor.new(); actor.world = self; actor.name = "Restored"+str(absi(id.hash())); actor.set_meta("dino_id",id)
		var model: String = {"velociraptor":"Velociraptor","triceratops":"Triceratops","stegosaurus":"Stegosaurus"}[record.species]
		actor.setup("res://assets/lowpoly/quaternius-dinosaur/"+model+".fbx",1.7,Color("b9cca5")); add_child(actor)
		actor.position = _core_local(_vector(record.xyz)); actor.speed = 8.0
		var parts: PackedStringArray = str(id).split(":"); var coord := Vector2i(int(parts[0]),int(parts[1]))
		wildlife[id] = {"kind":record.kind,"node":actor,"home":_vector(record.home)-Vector3(coord.x*48.0,0,coord.y*48.0),"fright":0.0,"chunk":coord,"phase":0.0}
		_social_label(actor,record)
	predator.position = _core_local(_vector(colony.relationships["core:predator"].xyz))
	_social_label(predator,colony.relationships["core:predator"])
func _spawn_released_friend(id: String, coord: Vector2i, parent: Node3D) -> void:
	var record: Dictionary = colony.relationships[id]
	var actor := Actor.new(); actor.world = self; actor.set_meta("dino_id",id); actor.name = "Released"+str(absi(id.hash()))
	var model: String = {"velociraptor":"Velociraptor","triceratops":"Triceratops","stegosaurus":"Stegosaurus"}[record.species]
	actor.setup("res://assets/lowpoly/quaternius-dinosaur/"+model+".fbx",1.7,Color("b9cca5"))
	parent.add_child(actor); actor.global_position = _core_local(_vector(record.xyz))
	wildlife[id] = {"kind":record.kind,"node":actor,"home":actor.position,"fright":0.0,"chunk":coord,"phase":0.0}
	_social_label(actor,record)
