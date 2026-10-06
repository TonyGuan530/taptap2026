extends Node3D
## A single wilderness, physical strokes, stable material rules, randomized loot.
const Rules := preload("res://v8/ink_rules.gd")
const Low := preload("res://lowpoly/library.gd")
const Pad := preload("res://v8/ink_draw_pad.gd")
const Audio := preload("res://tonight_audio.gd")
const Stream := preload("res://open_world/world_stream_v8.gd")
const KEY := Vector3(8,0.45,3)
const PLATE := Vector3(8,0.04,9)
const ANCHOR := Vector3(15.6,0.5,7.65)
const VINES := Vector3(20,0,3)
const LEVER := Vector3(21,0.5,10.7)
const GOAL := Vector3(25,0,7)
const FOUNTAINS := [Vector3(3,0,10.4),Vector3(16.5,0,7)]

var seed_value := 20261006
var words: Array[String] = []
var loot: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var solids: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var blueprint := {}
var selected_word := "Sticky"
var tool_word := ""
var closed_mode := false
var draw_rotation := 0.0
var ink := 100
var hp := 100
var key_retrieved := false
var river_crossed := false
var vines_open := false
var turret_disabled := false
var hazard_passed := false
var won := false
var dead := false
var notebook_open := false
var story_stage := 0
var key_route := ""
var river_route := ""
var hazard_route := ""
var clock := 0.0
var attack_ready := 0.0
var hit_ready := 0.0
var next_shot := 0.0
var last_message := ""
var auto_direction := Vector3.ZERO
var rope_target := Vector3.ZERO
var rope_active := false
var rope_elapsed := 0.0
var last_path := PackedVector2Array()
var path_until := 0.0
var attack_until := 0.0
var world: Node3D
var player: CharacterBody3D
var actor: Node3D
var cam: Camera3D
var hud: CanvasLayer
var stats: Label
var objectives: Label
var narrative: Label
var word_list: Label
var toast_label: Label
var notebook: PanelContainer
var draw_pad: Control
var preview: Label
var word_hint: Label
var mode_hint: Label
var result_panel: PanelContainer
var result_title: Label
var result_text: Label
var word_buttons := {}
var qa_buttons := {}
var key_node: Node3D
var key_gate: StaticBody3D
var vine_gate: StaticBody3D
var lane_gate: StaticBody3D
var turret_node: Node3D
var stroke_node: Node3D
var browser_window: JavaScriptObject
var browser_json: JavaScriptObject
var qa_enabled := false
var stream: Node3D
var densities := {"resources":1.0,"enemies":1.0,"events":1.0,"decoration":1.0}
var generated_puzzles: Array[Dictionary] = []
var generated_fountains: Array[Dictionary] = []
var chunk_nodes := {}
var discovered_chunks := {}
var solved_ids := {}
var last_safe_position := Vector3(2.4,0.6,7)
var loading_wait := false
var settings_open := false
var map_open := false
var settings_panel: PanelContainer
var map_panel: PanelContainer
var exploration_label: Label
var map_text: Label
var seed_edit: LineEdit
var density_sliders := {}
var setting_buttons := {}
var loading_progression := false
var discovered_total := 0
var solved_total := 0
var discovery_coord := Vector2i(2147483647,2147483647)
var discovery_description := {}
var qa_next_ms := 0
var clear_selected_on_build := false
var last_contact := {}
var hints_next_ms := 0

func _ready() -> void:
	_build_ui()
	_build_environment()
	_init_browser()
	_build_run()
	_build_stream()
	_build_settings()
	Low.readable_ui(self)
	_boost_world_labels(self)
	_update_hud()

func _boost_world_labels(node: Node) -> void:
	if node is Label3D:
		node.outline_modulate = Color("102a2d")
		node.outline_size = 8
	for child in node.get_children(): _boost_world_labels(child)

func _init_browser() -> void:
	if not OS.has_feature("web"): return
	browser_window = JavaScriptBridge.get_interface("window")
	browser_json = JavaScriptBridge.get_interface("JSON")
	qa_enabled = browser_window != null and str(browser_window.location.search).contains("qa=1")

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("274a55")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("d1dfd0")
	sky.ambient_light_energy = 0.72
	environment.environment = sky
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-28,0)
	sun.light_color = Color("ffe6c6")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 18.7
	cam.position = Vector3(14,25,23)
	add_child(cam)
	cam.look_at(Vector3(14,0,7))
	cam.current = true

func _build_run() -> void:
	world = Node3D.new()
	world.name = "Wilderness"
	add_child(world)
	var west_ground := _box(Vector3(6,-0.5,7),Vector3(12,1,14),Color("90b49c"))
	west_ground.set_meta("ink_aim_ground",true)
	var east_ground := _box(Vector3(21.5,-0.5,7),Vector3(13,1,14),Color("c6bc8e"))
	east_ground.set_meta("ink_aim_ground",true)
	Low.box(world,Vector3(3,0.09,14),Vector3(13.5,-0.48,7),Color("438d9c"))
	for z in [0.0,14.0]: _box(Vector3(14,1.1,z),Vector3(28,2.2,0.25),Color("607b65"))
	_box(Vector3(28,1.1,7),Vector3(0.25,2.2,14),Color("607b65"))
	for z in [2.5,11.5]: _box(Vector3(0,1.1,z),Vector3(0.25,2.2,5),Color("607b65"))
	_marker("西行旷野 · WASD 探索 / M 地图",Vector3(-1,1.1,7),Color("c2fff2"))
	# The iron key is visible in a fenced wet hollow; jumping cannot bypass it.
	Low.box(world,Vector3(2.6,0.04,3.4),Vector3(8,0.02,3),Color("537b7b"))
	for x in [6.7,9.3]: _box(Vector3(x,0.95,3),Vector3(0.22,1.9,3.6),Color("72919b"))
	for z in [1.2,4.8]: _box(Vector3(8,0.95,z),Vector3(2.6,1.9,0.22),Color("72919b"))
	key_node = Low.scroll()
	key_node.position = KEY
	world.add_child(key_node)
	Low.cylinder(key_node,0.12,0.12,0.12,Vector3(0,0.36,0),Color("ffd76c"),true)
	_marker("铁钥匙 · 抓取／吸铁",Vector3(8,2.3,3),Color("fff0c2"))
	var plate_visual := Low.model("plate",0.07)
	plate_visual.fit(1.1,0.07,1.1)
	plate_visual.position = PLATE
	world.add_child(plate_visual)
	_marker("配重盘 · 重物",Vector3(8,1.05,9),Color("fff0c2"))
	# Only the unlocked 2.3m bank opening reaches the crossing; no wall shortcut.
	_box(Vector3(11.15,1.25,2.9),Vector3(0.32,2.5,5.8),Color("789285"))
	_box(Vector3(11.15,1.25,11.1),Vector3(0.32,2.5,5.8),Color("789285"))
	key_gate = _box(Vector3(11.15,1.1,7),Vector3(0.3,2.2,2.4),Color("b08d64"))
	var gate_visual := Low.model("gate",2.1)
	gate_visual.fit(2.4,2.1,0.34)
	gate_visual.rotation.y = PI/2
	gate_visual.position.y = -1.1
	key_gate.add_child(gate_visual)
	_marker("3 米河 · 托住／拉住",Vector3(13.5,0.35,5.9),Color("e0fcf8"))
	var anchor := _box(Vector3(15.6,0.42,7.65),Vector3(0.24,0.84,0.24),Color("9c754f"))
	Low.cylinder(anchor,0.15,0.15,0.09,Vector3(0,0.43,0),Color("e6c579"),true)
	_marker("系绳木桩",Vector3(15.6,1.2,7.65),Color("ffe3a1"))
	# Two actual paths through the far wall: vines or projectile lane.
	for segment in [[0.0,1.8],[4.2,9.3],[11.7,14.0]]:
		_box(Vector3(20,1.25,(segment[0]+segment[1])*0.5),Vector3(0.4,2.5,segment[1]-segment[0]),Color("749083"))
	vine_gate = _box(Vector3(20,1.05,3),Vector3(0.35,2.1,2.4),Color("4e8055"))
	for offset in [-0.8,-0.4,0.0,0.4,0.8]:
		var branch := Low.model("branch",1.9)
		branch.fit(0.16,1.9,0.15)
		branch.position = Vector3(0,-1.0,offset)
		vine_gate.add_child(branch)
	_marker("藤根 · 切／撬",Vector3(19.3,2.2,3),Color("eef3c0"))
	turret_node = Low.model("pot",1.1)
	turret_node.position = Vector3(22.2,0,10.5)
	world.add_child(turret_node)
	Low.cylinder(world,0.12,0.12,0.85,LEVER,Color("97c2d2"),true)
	lane_gate = _box(Vector3(20,1.0,10.5),Vector3(0.3,2.0,2.4),Color("7498a1"))
	# Grille gaps admit tiny ink pellets while stopping the apprentice body.
	for child in lane_gate.get_children():
		if child is MeshInstance3D: child.hide()
	for offset in [-0.9,-0.3,0.3,0.9]:
		Low.box(lane_gate,Vector3(0.18,2.0,0.2),Vector3(0,0,offset),Color("7498a1"))
	for height in [-0.85,0.85]:
		Low.box(lane_gate,Vector3(0.18,0.13,2.4),Vector3(0,height,0),Color("7498a1"))
	Low.cylinder(lane_gate,0.12,0.12,0.05,Vector3(-0.22,0.7,0),Color("ff9473"),true)
	_marker("安全闸 · 停炮／挡弹",Vector3(20.7,2.0,10.6),Color("cdeafa"))
	var chest := Low.model("chest",0.8)
	chest.position = GOAL
	world.add_child(chest)
	_marker("失落画页 · E",GOAL+Vector3(0,1.5,0),Color("ffe9a2"))
	for fountain_pos in FOUNTAINS:
		var fountain := Low.model("pot",0.6)
		fountain.position = fountain_pos
		world.add_child(fountain)
		Low.cylinder(fountain,0.35,0.35,0.025,Vector3(0,0.49,0),Color("54ddd0"),true)
		_marker("墨泉 · E 补满",fountain_pos+Vector3(0,1.15,0),Color("c2fff2"))
	for entry in [[1.1,1.0,"tree"],[3.8,1.0,"tree_small"],[5.2,12.6,"tree"],[9.6,12.3,"tree_small"],[17.1,1.0,"tree"],[24.5,1.5,"tree_small"],[26.5,12.4,"tree"],[17.3,12.7,"rock"],[24.0,12.4,"berry"]]:
		var decor := Low.model(str(entry[2]),2.0 if "tree" in str(entry[2]) else 0.7)
		decor.position = Vector3(entry[0],0,entry[1])
		world.add_child(decor)
	player = CharacterBody3D.new()
	player.name = "Apprentice"
	player.position = Vector3(2.4,0.6,7)
	player.floor_snap_length = 0.28
	player.collision_layer = 2
	player.collision_mask = 1
	world.add_child(player)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.15
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = capsule
	player.add_child(collision)
	actor = Low.model("apprentice",1.35)
	actor.position.y = -0.575
	player.add_child(actor)
	Low.brush(actor)
	var manifest: Array = Rules.seed_manifest(seed_value)
	var positions := [Vector3(2.2,0,8.2),Vector3(3.4,0,8.2),Vector3(4.6,0,8.2),Vector3(6.2,0,6.3),Vector3(8.5,0,7),Vector3(4.8,0,10.6)]
	for index in manifest.size(): _spawn_word(str(manifest[index]),positions[index])
	_spawn_enemy(Vector3(8.7,0.6,10.8),0)
	_spawn_enemy(Vector3(23.3,0.6,6.5),1)
	stroke_node = Node3D.new()
	stroke_node.name = "VisibleToolStroke"
	world.add_child(stroke_node)
	_toast("先去草地拾词。Tab 画真正的线条／轮廓，字让工具有了性质。")

func _box(position_value: Vector3, size_value: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 2
	world.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size_value
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	Low.box(body,size_value,Vector3.ZERO,color)
	return body

func _marker(text_value: String, position_value: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.no_depth_test = true
	label.font_size = 28
	label.pixel_size = 0.009
	world.add_child(label)
	return label

func _spawn_word(word: String, position_value: Vector3) -> void:
	var node := Low.scroll()
	node.position = position_value
	world.add_child(node)
	loot.append({"word":word,"node":node,"collected":false})
	loot[-1].marker = _marker(Rules.NAMES[word],position_value+Vector3(0,0.95,0),Rules.COLORS[word])

func _spawn_enemy(position_value: Vector3, index: int) -> void:
	var body := CharacterBody3D.new()
	body.position = position_value
	body.collision_layer = 4
	body.collision_mask = 1
	world.add_child(body)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.1
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var visual := Low.model("enemy",1.2)
	visual.position.y = -0.55
	body.add_child(visual)
	enemies.append({"node":body,"art":visual,"hp":70,"index":index,"attack_at":0.0,"home":position_value,"windup":0.0})

func _physics_process(delta: float) -> void:
	if notebook_open or settings_open or dead: return
	stream.step(player.position)
	_update_discovery()
	clock += delta
	var direction := auto_direction
	if direction.length_squared() < 0.01:
		direction = Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).normalized()
	if rope_active:
		rope_elapsed += delta
		var difference := rope_target-player.position
		player.velocity = Vector3(difference.x,0,difference.z).normalized()*6.5
		player.velocity.y = (1.75-player.position.y)*8.0
		if Vector2(difference.x,difference.z).length() < 0.38 or rope_elapsed > 2.0:
			rope_active = false
			player.velocity.y = 0
	else:
		player.velocity.x = direction.x*3.5
		player.velocity.z = direction.z*3.5
		if not player.is_on_floor(): player.velocity.y -= 20*delta
		elif player.velocity.y < 0: player.velocity.y = 0
		if Input.is_physical_key_pressed(KEY_SPACE) and player.is_on_floor(): player.velocity.y = 5.3
	var next_position := player.position+Vector3(player.velocity.x,0,player.velocity.z)*delta
	loading_wait = not stream.ready_at(next_position)
	if loading_wait:
		player.velocity.x = 0
		player.velocity.z = 0
	player.move_and_slide()
	if player.position.y < _ground_y(player.position)-5.0 or (_in_core() and player.position.y < -1.8):
		_damage(10,"掉进河里了：回岸补墨，桥需要覆盖脚下，绳子需要够到木桩。")
		player.position = Vector3(15.8 if river_crossed else 11.5,0.8,7) if _in_core() else last_safe_position
		player.velocity = Vector3.ZERO
	collect_pickups()
	if _in_core() and player.position.x > 15.25 and not river_crossed:
		river_crossed = true
		story_stage = maxi(story_stage,2)
		if river_route.is_empty(): river_route = "drawn_support"
		_toast("河并不在乎你画得像不像。它只问：能托住你，还是能拉住你？")
	if _in_core() and player.position.x > 20.45 and (vines_open or turret_disabled or lane_gate.collision_layer == 0):
		hazard_passed = true
		if hazard_route.is_empty(): hazard_route = "shield_lane" if not turret_disabled else "magnetic_lever"
	if player.is_on_floor(): last_safe_position = player.position
	_update_enemies(delta)
	_update_projectiles(delta)
	if direction.length() > 0.1: actor.face(direction,delta)
	actor.pose("attack" if clock < attack_until else ("walk" if direction.length() > 0.1 or rope_active else "idle"))
	_update_hud()

func _process(_delta: float) -> void:
	if not is_instance_valid(player): return
	var focus := player.position+Vector3(2.8,0,0)
	cam.position = cam.position.lerp(focus+Vector3(0,25,16),minf(_delta*7,1))
	cam.look_at(focus)
	_update_nearby_hints()
	if clock > path_until and stroke_node and stroke_node.get_child_count() > 0:
		for child in stroke_node.get_children(): child.queue_free()
	_publish_qa()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_M: map_open = not map_open; map_panel.visible = map_open
			KEY_F4: settings_open = not settings_open; settings_panel.visible = settings_open
			KEY_TAB:
				if not dead and not settings_open: toggle_notebook()
			KEY_ESCAPE:
				if notebook_open: toggle_notebook()
				elif settings_open: settings_open = false; settings_panel.hide()
				else: result_panel.hide()
			KEY_ENTER:
				if notebook_open: apply_drawing()
			KEY_C:
				if notebook_open: set_mode(not closed_mode)
			KEY_R:
				draw_rotation += PI/2
				_toast("封闭造物旋转了 90°。开放线条朝点击方向挥出。")
			KEY_Z:
				if not notebook_open: recover_tool()
			KEY_E:
				if not notebook_open: interact()
			KEY_F2: reset_run(false)
			KEY_F3: reset_run(true)
			KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6:
				select_word(Rules.WORDS[event.physical_keycode-KEY_1])
	elif event is InputEventMouseButton and event.pressed and not notebook_open and not settings_open and not dead:
		var target := _mouse_world(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT: use_tool(target)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if blueprint.get("kind","") == "open": use_tool(target)
			else: brush_attack(target)

func _mouse_world(point: Vector2) -> Vector3:
	var ray := cam.project_ray_origin(point)
	var direction := cam.project_ray_normal(point)
	var query := PhysicsRayQueryParameters3D.create(ray,ray+direction*180.0,1)
	var excluded: Array[RID] = []
	# A ground-screen click defines XZ. Fence tops and existing drawings must not bend that aim.
	# Keep their gameplay collision intact, excluding only this temporary pointer ray.
	for fixture in 64:
		query.exclude = excluded
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): break
		var surface: CollisionObject3D = hit.collider
		var is_terrain := surface.name == "TerrainCollision" and stream.is_ancestor_of(surface)
		if is_terrain or surface.get_meta("ink_aim_ground",false): return hit.position
		excluded.append(surface.get_rid())
	var estimate := ray+direction*maxf((player.position.y-ray.y)/direction.y,0)
	for iteration in 8:
		var y := _ground_y(estimate)
		estimate = ray+direction*maxf((y-ray.y)/direction.y,0)
	return estimate

func collect_pickups() -> void:
	for entry in loot:
		if entry.collected or not is_instance_valid(entry.node): continue
		if _xz(player.position).distance_to(_xz(entry.node.position)) < 0.85:
			entry.collected = true
			if entry.has("id"): stream.set_feature_state(entry.id,{"picked":true})
			entry.node.hide()
			if entry.has("marker"):
				entry.marker.hide()
				entry.marker.set_meta("hint_disabled",true)
			if not words.has(entry.word):
				words.append(entry.word)
				if words.size() == 1: selected_word = entry.word
				_toast("拾到「%s」：%s" % [Rules.NAMES[entry.word],Rules.HINTS[entry.word]])
			else:
				ink = mini(100,ink+20)
				_toast("重复的字化成 20 墨，已有词语仍可反复使用。")
			Audio.play(self,720,0.12)
	_update_hud()

func select_word(word: String) -> void:
	if words.has(word):
		selected_word = word
		if word_hint: word_hint.text = "「%s」 %s" % [Rules.NAMES[word],Rules.HINTS[word]]
		_preview_drawing()
	else: _toest_missing(word)
	_update_hud()

func _toest_missing(word: String) -> void:
	_toast("还没拾到「%s」。地上的卷轴和污墨掉落都可能带来新字。" % Rules.NAMES[word])

func toggle_notebook() -> void:
	notebook_open = not notebook_open
	notebook.visible = notebook_open
	if notebook_open:
		player.velocity = Vector3.ZERO
		_preview_drawing()
	_update_hud()

func set_mode(closed: bool) -> void:
	closed_mode = closed
	draw_pad.closed_mode = closed
	mode_hint.text = "封闭轮廓：拖出外边缘，系统连接首尾。" if closed else "开放线条：从红点开始画鞭／绳，长度和弯折决定实际接触。"
	_preview_drawing()

func _preview_drawing() -> void:
	if not draw_pad: return
	var tool: Dictionary = Rules.stroke(draw_pad.points,closed_mode)
	if tool.is_empty():
		preview.text = "画一条足够长的线；封闭模式要有面积，且不要自交。"
	elif tool.kind == "open":
		preview.text = "开放笔画 · %d 顶点 · 长 %.2f 米 · 直达 %.2f 米 · %d 墨" % [tool.points.size(),tool.length,tool.reach*(1.5 if selected_word == "Elastic" else 1.0),tool.cost]
	else:
		preview.text = "封闭轮廓 · %d 顶点 · %.2f × %.2f 米 · 面积 %.2f · %d 墨／次" % [tool.polygon.size(),tool.size.x,tool.size.z,tool.area,tool.cost]
	word_hint.text = "「%s」 %s" % [Rules.NAMES[selected_word],Rules.HINTS[selected_word]]

func apply_drawing() -> bool:
	if not words.has(selected_word):
		_toest_missing(selected_word)
		return false
	var tool: Dictionary = Rules.stroke(draw_pad.points,closed_mode)
	if tool.is_empty():
		_toast("笔画还不能成形：开放线至少两个点；封闭轮廓需要面积，不能自交。")
		return false
	var refund := int(blueprint.get("cost",0)) if blueprint.get("kind","") == "open" else 0
	var available := mini(100,ink+refund)
	if available < int(tool.cost):
		_toast("墨不足。E 在墨泉补满，Z 收回造物也能回墨。")
		return false
	ink = available
	blueprint = tool
	tool_word = selected_word
	if tool.kind == "open": ink -= int(tool.cost)
	notebook_open = false
	notebook.hide()
	_toast("%s＋%s：点击／右键朝目标挥出。" % ["开放线条" if tool.kind == "open" else "封闭轮廓",Rules.NAMES[tool_word]] if tool.kind == "open" else "封闭轮廓＋%s：右键放置；R 旋转；Z 收回最后一件。" % Rules.NAMES[tool_word])
	_update_hud()
	return true

func use_tool(target: Vector3) -> bool:
	if blueprint.is_empty() or dead:
		_toast("Tab 先画工具并附上一个已拾到的字。左键也能用画笔近战。")
		return false
	if blueprint.kind == "closed": return _place_solid(target)
	if clock < attack_ready: return false
	attack_ready = clock+0.35
	attack_until = clock+0.28
	var origin := _xz(player.position)
	var aim := _xz(target)-origin
	last_path = Rules.world_path(blueprint,origin,aim,tool_word)
	_draw_stroke(last_path)
	actor.face(Vector3(aim.x,0,aim.y),1)
	var effect := false
	if _in_core() and not key_retrieved and Rules.remote_contact(blueprint,origin,aim,tool_word,_xz(KEY)):
		_retrieve_key("%s_stroke" % tool_word.to_lower())
		effect = true
	if _in_core() and player.position.x < 15 and key_retrieved and Rules.rope_contact(blueprint,origin,aim,tool_word,_xz(ANCHOR)):
		rope_active = true
		rope_elapsed = 0
		rope_target = Vector3(16.1,1.75,7.65)
		river_route = "%s_rope" % tool_word.to_lower()
		_toast("绳子够到木桩了：线条绷紧，把你拉向对岸。")
		effect = true
	if _in_core() and not vines_open and Rules.vine_contact(blueprint,origin,aim,tool_word,_xz(VINES)):
		_open_vines("sharp_stroke")
		effect = true
	if _in_core() and not turret_disabled and Rules.remote_contact(blueprint,origin,aim,tool_word,_xz(LEVER)) and tool_word == "Magnetic":
		turret_disabled = true
		hazard_route = "magnetic_lever"
		lane_gate.collision_layer = 0
		lane_gate.hide()
		turret_node.modulate = Color("8c9990")
		_toast("铁拉杆真的被拉下了。炮口熄灭，南侧可以通过。")
		effect = true
	effect = _generated_open_contact(origin,aim) or effect
	for enemy in enemies:
		if enemy.hp > 0 and Rules.path_distance(last_path,_xz(enemy.node.position)) < 0.5:
			_hit_enemy(enemy,48 if tool_word == "Sharp" else 36,aim.normalized())
			effect = true
	Audio.play(self,470 if effect else 310,0.1)
	if not effect: _toest_miss()
	return effect

func _toest_miss() -> void:
	_toast("笔画扫过了这片地方。看端点和弯折：字合适，还要真的够到／碰到物体。")

func _draw_stroke(path: PackedVector2Array) -> void:
	for child in stroke_node.get_children(): child.queue_free()
	path_until = clock+0.6
	for i in range(1,path.size()):
		var from := Vector3(path[i-1].x,_ground_y(Vector3(path[i-1].x,0,path[i-1].y))+0.65,path[i-1].y)
		var to := Vector3(path[i].x,_ground_y(Vector3(path[i].x,0,path[i].y))+0.65,path[i].y)
		var length := from.distance_to(to)
		var line := Low.box(stroke_node,Vector3(0.07,0.07,length),from.lerp(to,0.5),Rules.COLORS[tool_word])
		if length > 0.01: line.look_at(to,Vector3.UP)
		line.scale.z = 0.04
		create_tween().tween_property(line,"scale:z",1.0,0.12)
	if not path.is_empty():
		Low.cylinder(stroke_node,0.11,0.11,0.08,Vector3(path[-1].x,_ground_y(Vector3(path[-1].x,0,path[-1].y))+0.7,path[-1].y),Rules.COLORS[tool_word],true)

func _place_solid(target: Vector3) -> bool:
	if solids.size() >= 24:
		_toast("已有 24 件实体造物。先用 Z 回收，再继续画；墨会全部退回。")
		return false
	if _xz(player.position).distance_to(_xz(target)) > 4.3:
		_toast("放得太远：走近到 4.3 米以内。")
		return false
	if not stream.ready_at(target): return false
	if _in_core() and (target.x < 0.5 or target.x > 27.5 or target.z < 0.5 or target.z > 13.5): return false
	if ink < int(blueprint.cost):
		_toast("墨不足，E 在墨泉补满或 Z 收回造物。")
		return false
	if _in_core() and target.x > 12 and target.x < 15 and tool_word != "Float":
		_toast("这个字不能浮在水上。重物会沉底；漂浮轮廓才能承重。")
		return false
	ink -= int(blueprint.cost)
	_create_solid(blueprint,tool_word,Vector3(target.x,_ground_y(target)+(-0.07 if tool_word == "Float" else 0.48),target.z),draw_rotation)
	if _in_core() and not key_retrieved and Rules.weight_contact(blueprint,_xz(target),draw_rotation,tool_word,_xz(PLATE)): _retrieve_key("heavy_counterweight")
	if _in_core() and not vines_open and Rules.weight_contact(blueprint,_xz(target),draw_rotation,tool_word,_xz(VINES)): _open_vines("heavy_wedge")
	_generated_closed_contact(target)
	if _in_core() and tool_word == "Float" and target.x > 11.8 and target.x < 15.2: river_route = "float_contour"
	Audio.play(self,550,0.11)
	_toast("造物落下了：真正能碰撞的是你画出的轮廓。Z 收回最后一件，退还全部墨。")
	_update_hud()
	return true

func _create_solid(tool: Dictionary, word: String, position_value: Vector3, angle: float) -> void:
	var body := StaticBody3D.new()
	body.position = position_value
	body.rotation.y = angle
	body.collision_layer = 1
	body.collision_mask = 2
	world.add_child(body)
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.mesh
	mesh.material_override = Low.material(Rules.COLORS[word],word == "Float")
	if word != "Float": mesh.scale.y = 6.0
	body.add_child(mesh)
	for shape: ConvexPolygonShape3D in tool.shapes:
		var collision := CollisionShape3D.new()
		collision.shape = shape
		if word != "Float": collision.scale.y = 6.0
		body.add_child(collision)
	solids.append({"node":body,"tool":tool.duplicate(),"word":word,"cost":tool.cost,"rotation":angle})

func recover_tool() -> void:
	if not solids.is_empty():
		var last: Dictionary = solids.pop_back()
		ink = mini(100,ink+int(last.cost))
		last.node.queue_free()
		_toast("最后一件造物已回收，墨全部退回。已经打开的机关保持打开。")
	elif not blueprint.is_empty():
		if blueprint.kind == "open": ink = mini(100,ink+int(blueprint.cost))
		blueprint.clear()
		tool_word = ""
		last_path.clear()
		_toast("工具回到纸上，墨全部退回。随时重新画。")
	_update_hud()

func _retrieve_key(route: String) -> void:
	key_retrieved = true
	key_route = route
	story_stage = maxi(story_stage,1)
	key_gate.collision_layer = 0
	key_gate.hide()
	var tween := create_tween()
	tween.tween_property(key_node,"position",player.position+Vector3(0,0.5,0),0.48)
	tween.tween_callback(key_node.hide)
	_toast("钥匙被带回来了。原来歪歪的线也能救回东西。河岸门已打开。")

func _open_vines(route: String) -> void:
	vines_open = true
	hazard_route = route
	vine_gate.collision_layer = 0
	vine_gate.hide()
	_toast("藤根松开了。观察接触和重量，比背一个标准形状更有用。")

func brush_attack(target: Vector3) -> bool:
	if clock < attack_ready or dead: return false
	attack_ready = clock+0.32
	attack_until = clock+0.25
	var aim := (_xz(target)-_xz(player.position)).normalized()
	actor.face(Vector3(aim.x,0,aim.y),1)
	var hit := false
	for enemy in enemies:
		if enemy.hp <= 0: continue
		var offset: Vector2 = _xz(enemy.node.position)-_xz(player.position)
		if offset.length() <= 1.6 and (offset.length() < 0.3 or offset.normalized().dot(aim) > 0.2):
			_hit_enemy(enemy,26,aim)
			hit = true
	Audio.play(self,400,0.08)
	return hit

func _hit_enemy(enemy: Dictionary, damage: int, direction: Vector2) -> void:
	enemy.hp = maxi(0,int(enemy.hp)-damage)
	enemy.node.position += Vector3(direction.x,0,direction.y)*0.28
	if enemy.has("id"):
		stream.set_feature_state(enemy.id,{"hp":enemy.hp})
	if enemy.hp <= 0:
		enemy.art.pose("dead")
		enemy.node.collision_layer = 0
		var missing: Array[String] = []
		for word in Rules.seed_manifest(seed_value+int(enemy.index)+99):
			if not words.has(word): missing.append(word)
		var drop: String = missing[0] if not missing.is_empty() else Rules.seed_manifest(seed_value+int(enemy.index))[0]
		if enemy.has("id"): drop = str(enemy.get("drop_word",drop))
		if enemy.has("id"):
			_spawn_generated_word(drop,enemy.node.position-Vector3(0,0.55,0),enemy.id+":drop",enemy.coord)
		else:
			_spawn_word(drop,Vector3(enemy.node.position.x,0,enemy.node.position.z))
		ink = mini(100,ink+24)
		_toast("污墨散了，掉下「%s」和 24 墨。重复词也会化成补给。" % Rules.NAMES[drop])
		Low.readable_ui(world)
		_boost_world_labels(world)
	else:
		enemy.art.modulate = Color("ffd1b1")
		enemy.windup = clock+0.35

func _update_enemies(delta: float) -> void:
	for enemy in enemies:
		if enemy.hp <= 0: continue
		var body: CharacterBody3D = enemy.node
		var offset := player.position-body.position
		var distance := Vector2(offset.x,offset.z).length()
		body.velocity.y -= 20*delta
		var active := distance < 4.2 and absf(player.position.x-body.position.x) < 4.0
		if active and distance > 1.0:
			var direction := Vector3(offset.x,0,offset.z).normalized()
			body.velocity.x = direction.x*1.2
			body.velocity.z = direction.z*1.2
			enemy.art.face(direction,delta)
			enemy.art.pose("walk")
		else:
			body.velocity.x = 0
			body.velocity.z = 0
			enemy.art.pose("attack" if active else "idle")
		body.move_and_slide()
		if body.position.y < _ground_y(body.position)-4: body.position = enemy.home
		if enemy.has("id") and not stream.ready_at(body.position+body.velocity*delta):
			body.position = enemy.home
			body.velocity = Vector3.ZERO
		if active and distance < 1.1 and clock > enemy.attack_at:
			enemy.attack_at = clock+1.25
			_damage(8,"污墨正贴近你：左键画笔近战，或者用开放鞭子从远处抽击。")
		if clock > enemy.windup: enemy.art.modulate = Color.WHITE

func _update_projectiles(delta: float) -> void:
	if _in_core() and not turret_disabled and player.position.x > 16.8 and player.position.z > 9.2 and clock > next_shot:
		next_shot = clock+1.15
		var node := Node3D.new()
		node.position = Vector3(22.1,0.72,10.5)
		world.add_child(node)
		Low.cylinder(node,0.10,0.10,0.13,Vector3.ZERO,Color("fb9469"),true)
		shots.append({"node":node,"velocity":(Vector3(player.position.x,0.72,player.position.z)-node.position).normalized()*5.0,"life":3.0})
	for shot in shots.duplicate():
		var previous: Vector3 = shot.node.position
		var next: Vector3 = previous+shot.velocity*delta
		var blocked := false
		for solid in solids:
			if solid.word != "Float" and Rules.shield_intercepts(solid.tool,_xz(solid.node.position),solid.rotation,_xz(previous),_xz(next)):
				blocked = true
				hazard_route = "drawn_shield"
				if lane_gate.collision_layer != 0:
					lane_gate.collision_layer = 0
					lane_gate.hide()
					_toast("炮弹被你画的挡板真正截住了。安全闸亮起，南路放行。")
				break
		if not blocked:
			var query := PhysicsRayQueryParameters3D.create(previous,next,1,[lane_gate.get_rid()])
			# The safety grille passes pellets; stone walls and real solids do not.
			blocked = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		shot.life -= delta
		shot.node.position = next
		if not blocked and _xz(next).distance_to(_xz(player.position)) < 0.32 and absf(next.y-player.position.y) < 0.8:
			_damage(12,"炮弹碰到你了。磁性拉杆能停炮，封闭挡板能在接触处挡弹，也能绕北侧藤根。")
			blocked = true
		if blocked or shot.life <= 0:
			shots.erase(shot)
			shot.node.queue_free()

func _damage(amount: int, hint: String) -> void:
	if clock < hit_ready or dead: return
	hit_ready = clock+0.55
	hp = maxi(0,hp-amount)
	_toast(hint)
	if hp == 0:
		dead = true
		result_title.text = "纸被污墨浸湿了"
		result_text.text = "词语和工具还能重新组合。保留种子重试，或换一个拾取顺序。"
		result_panel.show()
	_update_hud()

func interact() -> void:
	if dead: return
	collect_pickups()
	for refill in generated_fountains:
		if is_instance_valid(refill.node) and _xz(player.position).distance_to(_xz(refill.node.position)) < 1.5:
			ink = 100
			_toast("野外墨泉补满；附近卷轴可重组工具，Z 回收造物。")
			_update_hud()
			return
	for pos in FOUNTAINS:
		if _in_core() and _xz(player.position).distance_to(_xz(pos)) < 1.35:
			ink = 100
			_toast("墨泉补满了。试错不会锁死：回收、补墨，再画一次。")
			Audio.play(self,610,0.13)
			_update_hud()
			return
	if _in_core() and not won and _xz(player.position).distance_to(_xz(GOAL)) < 1.65:
		if key_retrieved and river_crossed and hazard_passed:
			won = true
			story_stage = 3
			result_title.text = "把失落画页带回来了"
			result_text.text = "我曾想证明自己画得像。今天，弯曲的线抓住了东西，字改变了材质，我把路画出来了。\n\n钥匙：%s · 过河：%s · 险路：%s\n同一道难题还能用另一组字和笔画去试。" % [_route_text(key_route),_route_text(river_route),_route_text(hazard_route)]
			result_text.text += "\n旷野仍在西侧：按 Esc 继续探索，主线记录会保留。"
			result_panel.show()
			Audio.play(self,880,0.35)
		else: _toest_miss()
	else: _toest_miss()
	_update_hud()

func reset_run(reseed: bool) -> void:
	if is_instance_valid(stream) and not reseed and not loading_progression:
		stream.clear_world_state()
		if FileAccess.file_exists(_profile_path()): DirAccess.remove_absolute(_profile_path())
	if reseed: seed_value = int(posmod(seed_value*1664525+1013904223,2147483647))
	if reseed: clear_selected_on_build = true
	discovered_chunks.clear()
	solved_ids.clear()
	discovered_total = 0
	solved_total = 0
	discovery_coord = Vector2i(2147483647,2147483647)
	words.clear()
	loot.clear()
	enemies.clear()
	solids.clear()
	shots.clear()
	blueprint.clear()
	last_path.clear()
	selected_word = "Sticky"
	tool_word = ""
	ink = 100
	hp = 100
	key_retrieved = false
	river_crossed = false
	vines_open = false
	turret_disabled = false
	hazard_passed = false
	won = false
	dead = false
	story_stage = 0
	key_route = ""
	river_route = ""
	hazard_route = ""
	clock = 0
	attack_ready = 0
	hit_ready = 0
	next_shot = 0
	rope_active = false
	auto_direction = Vector3.ZERO
	draw_rotation = 0
	notebook_open = false
	notebook.hide()
	result_panel.hide()
	draw_pad.clear_drawing()
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	_build_run()
	if is_instance_valid(stream):
		remove_child(stream)
		stream.queue_free()
	generated_fountains.clear()
	generated_puzzles.clear()
	chunk_nodes.clear()
	_build_stream()
	Low.readable_ui(world)
	_boost_world_labels(world)
	_update_hud()

func _xz(value: Vector3) -> Vector2:
	return Vector2(value.x,value.z)

func _toast(message: String) -> void:
	last_message = message
	if toast_label: toast_label.text = message

func _build_ui() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var backdrop := ColorRect.new()
	backdrop.position = Vector2(10,8)
	backdrop.size = Vector2(940,126)
	backdrop.color = Color("173c42ed")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(backdrop)
	stats = _label(hud,"",Vector2(24,14),Vector2(690,26),17)
	objectives = _label(hud,"",Vector2(24,40),Vector2(900,24),16)
	narrative = _label(hud,"",Vector2(24,65),Vector2(920,26),14)
	word_list = _label(hud,"",Vector2(24,91),Vector2(890,28),14)
	var controls := _label(hud,"WASD 移动 · 空格跳 · 左键画笔／鞭子 · 右键用工具 · Tab 绘画 · E 拾取／补墨／带回画页 · Z 回收 · R 转向",Vector2(20,487),Vector2(920,22),13)
	controls.add_theme_color_override("font_color",Color("edf3d7"))
	toast_label = _label(hud,"",Vector2(20,510),Vector2(920,26),14)
	toast_label.add_theme_color_override("font_color",Color("ffe0a0"))
	var draw_button := _button(hud,"Tab 画工具",Vector2(791,12),Vector2(148,31),toggle_notebook)
	qa_buttons.draw = draw_button
	notebook = PanelContainer.new()
	notebook.position = Vector2(103,73)
	notebook.size = Vector2(754,404)
	notebook.add_theme_stylebox_override("panel",_style(Color("163e46")))
	hud.add_child(notebook)
	var sheet := Control.new()
	sheet.custom_minimum_size = Vector2(730,402)
	notebook.add_child(sheet)
	_label(sheet,"画线条或轮廓，再让字落上去",Vector2(19,8),Vector2(590,29),21)
	qa_buttons.open = _button(sheet,"开放：鞭／绳",Vector2(19,42),Vector2(168,29),set_mode.bind(false))
	qa_buttons.closed = _button(sheet,"封闭：桥／挡板／重物",Vector2(194,42),Vector2(254,29),set_mode.bind(true))
	qa_buttons.clear = _button(sheet,"清空重画",Vector2(455,42),Vector2(124,29),func(): draw_pad.clear_drawing())
	mode_hint = _label(sheet,"",Vector2(19,73),Vector2(694,25),13)
	draw_pad = Pad.new()
	draw_pad.position = Vector2(19,101)
	draw_pad.size = Vector2(540,244)
	sheet.add_child(draw_pad)
	draw_pad.stroke_changed.connect(_preview_drawing)
	for index in Rules.WORDS.size():
		var word: String = Rules.WORDS[index]
		var button := _button(sheet,"%d %s" % [index+1,Rules.NAMES[word]],Vector2(571,102+index*38),Vector2(138,33),select_word.bind(word))
		word_buttons[word] = button
		qa_buttons["word_"+word] = button
	preview = _label(sheet,"",Vector2(19,348),Vector2(693,24),13)
	word_hint = _label(sheet,"",Vector2(19,371),Vector2(510,25),12)
	qa_buttons.confirm = _button(sheet,"确认工具 · Enter",Vector2(537,368),Vector2(173,29),apply_drawing)
	notebook.hide()
	set_mode(false)
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(190,165)
	result_panel.size = Vector2(580,257)
	result_panel.add_theme_stylebox_override("panel",_style(Color("163e46")))
	hud.add_child(result_panel)
	var card := Control.new()
	card.custom_minimum_size = Vector2(570,245)
	result_panel.add_child(card)
	result_title = _label(card,"",Vector2(22,17),Vector2(530,40),26)
	result_text = _label(card,"",Vector2(22,66),Vector2(530,126),16)
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qa_buttons.restart = _button(card,"同种子重试 · F2",Vector2(22,202),Vector2(243,34),reset_run.bind(false))
	qa_buttons.reseed = _button(card,"换随机种子 · F3",Vector2(281,202),Vector2(266,34),reset_run.bind(true))
	result_panel.hide()

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("94b4a3")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _label(parent: Node, value: String, position_value: Vector2, size_value: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = position_value
	label.size = size_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("eaf1df"))
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, position_value: Vector2, size_value: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = position_value
	button.size = size_value
	button.add_theme_font_size_override("font_size",14)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _update_hud() -> void:
	if not stats: return
	stats.text = "野外画家 V8 · 生命 %d · 墨 %d/100 · F4 设置 / M 地图" % [hp,ink]
	objectives.text = "%s 带回铁钥匙    %s 跨过真实河流    %s 穿过藤根／炮弹险路    %s E 带回失落画页" % [_tick(key_retrieved),_tick(river_crossed),_tick(hazard_passed),_tick(won)]
	narrative.text = ["学徒：老师说，要画得像。我想带回失落画页，证明自己。","学徒：歪线也能把东西拉回来……我该看用途，还是看模样？","学徒：河托住了我。接下来，用刚拾到的字应付藤根和炮口。","学徒：我没背出标准答案，我观察、试错，把路画了出来。"][clampi(story_stage,0,3)]
	var inventory := PackedStringArray()
	for word in Rules.WORDS:
		inventory.append("%s%s" % [Rules.NAMES[word],"✓" if words.has(word) else "？"])
	word_list.text = "拾取词语：%s   当前：%s%s" % [" · ".join(inventory),Rules.NAMES[tool_word] if not tool_word.is_empty() else "未造工具","＋开放线" if blueprint.get("kind","") == "open" else ("＋封闭轮廓" if blueprint.get("kind","") == "closed" else "")]
	for word in word_buttons:
		word_buttons[word].disabled = not words.has(word)
		word_buttons[word].modulate = Rules.COLORS[word] if word == selected_word else Color.WHITE

func _tick(value: bool) -> String:
	return "✓" if value else "○"

func _route_text(route: String) -> String:
	return {"sticky_stroke":"黏性线条抓取","magnetic_stroke":"磁吸铁钥匙","heavy_counterweight":"重物压配重","elastic_rope":"弹性长绳","sticky_rope":"黏性长绳","float_contour":"漂浮轮廓承重","drawn_support":"画出的落脚点","sharp_stroke":"锋利线条切藤","heavy_wedge":"重物撬开藤根","magnetic_lever":"磁吸停炮","drawn_shield":"画挡板挡弹","shield_lane":"穿过炮口险路"}.get(route,"临场观察")

func _point(value: Vector3) -> Dictionary:
	var projected := cam.unproject_position(value)
	var ground := cam.unproject_position(Vector3(value.x,_ground_y(value),value.z))
	return {"pos":[value.x,value.y,value.z],"screen":[projected.x,projected.y],"ground_screen":[ground.x,ground.y]}

func _core_point(value: Vector3) -> Dictionary:
	return _point(value-Vector3(stream.origin_chunk.x*48.0,0,stream.origin_chunk.y*48.0))

func _publish_qa() -> void:
	if not qa_enabled: return
	if Time.get_ticks_msec() < qa_next_ms: return
	qa_next_ms = Time.get_ticks_msec()+120
	var live_loot := []
	for entry in loot:
		if not is_instance_valid(entry.node): continue
		var item := _point(entry.node.position)
		item.word = entry.word
		item.tag = Rules.NAMES[entry.word]
		item.collected = entry.collected
		item.id = entry.get("id","")
		live_loot.append(item)
	var enemy_list := []
	for enemy in enemies:
		if not is_instance_valid(enemy.node): continue
		var item := _point(enemy.node.position)
		item.hp = enemy.hp
		item.index = enemy.index
		enemy_list.append(item)
	var preview_points := []
	for point in draw_pad.points: preview_points.append([point.x,point.y])
	var polygon := []
	for point in blueprint.get("polygon",blueprint.get("points",PackedVector2Array())): polygon.append([point.x,point.y])
	var path := []
	for point in last_path: path.append([point.x,point.y])
	var button_points := {}
	for key in qa_buttons:
		var button: Button = qa_buttons[key]
		var rect := button.get_global_rect()
		button_points[key] = [rect.get_center().x,rect.get_center().y]
	var rect := draw_pad.get_global_rect()
	var objects := {"key":_core_point(KEY),"plate":_core_point(PLATE),"bank_west":_core_point(Vector3(11.5,0,7)),"river_center":_core_point(Vector3(13.5,0,7)),"anchor":_core_point(ANCHOR),"vines":_core_point(VINES),"lever":_core_point(LEVER),"goal":_core_point(GOAL),"fountain_west":_core_point(FOUNTAINS[0]),"fountain_east":_core_point(FOUNTAINS[1])}
	var state := {"version":8,"player":[player.position.x,player.position.y,player.position.z],"player_screen":_point(player.position).screen,"seed":seed_value,"loot":live_loot,"words":words,"ink":ink,"hp":hp,"landmarks":objects,"enemies":enemy_list,"puzzles":{"key":key_retrieved,"river":river_crossed,"vines":vines_open,"turret_disabled":turret_disabled,"hazard":hazard_passed,"key_route":key_route,"river_route":river_route,"hazard_route":hazard_route},"drawing":{"preview_points":preview_points,"vertices":draw_pad.points.size(),"closed_mode":closed_mode,"preview":preview.text},"active_tool":{"kind":blueprint.get("kind",""),"word":tool_word,"vertices":polygon,"path":path,"length":blueprint.get("length",0),"reach":blueprint.get("reach",0)*(1.5 if tool_word == "Elastic" else 1.0),"area":blueprint.get("area",0),"solids":solids.size(),"rope_active":rope_active},"ui":{"notebook":notebook_open,"selected_tag":selected_word,"draw_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"buttons":button_points,"message":last_message,"objectives":objectives.text,"story":narrative.text,"result":result_text.text if won or dead else ""},"won":won,"dead":dead,"ending":won,"story_stage":story_stage}
	state.stream = stream.snapshot()
	state.stream.loading_wait = loading_wait
	state.stream.discovered = discovered_total
	state.stream.solved = solved_total
	state.features = _feature_snapshot()
	state.generated_puzzles = _puzzle_snapshot()
	state.settings = _settings_snapshot()
	state.map = map_open
	state.contact = last_contact
	browser_window.__v8_ink_qa = browser_json.parse(JSON.stringify(state))

func _build_stream() -> void:
	stream = Stream.new()
	stream.name = "SeededTerrain"
	add_child(stream)
	stream.chunk_loaded.connect(_on_chunk_loaded)
	stream.chunk_unloading.connect(_on_chunk_unloading)
	stream.origin_shifted.connect(_on_origin_shifted)
	stream.configure(seed_value,"ink",densities)
	if clear_selected_on_build:
		stream.clear_world_state()
		if FileAccess.file_exists(_profile_path()): DirAccess.remove_absolute(_profile_path())
		clear_selected_on_build = false
	stream.prime(player.position)
	# Match authored banks to the wilderness while retaining their physical river gap.
	for floor_body in world.get_children():
		if floor_body is StaticBody3D and floor_body.get_meta("ink_aim_ground",false):
			for visual in floor_body.get_children():
				if visual is MeshInstance3D: stream.apply_core_ground(visual)
	last_safe_position = player.position

func _in_core() -> bool:
	return is_instance_valid(stream) and stream.origin_chunk == Vector2i.ZERO and Rect2(0,0,28,14).has_point(_xz(player.position))

func _ground_y(point: Vector3) -> float:
	if not is_instance_valid(stream): return 0.0
	var absolute := point+Vector3(stream.origin_chunk.x*48.0,0,stream.origin_chunk.y*48.0)
	return stream.generator.height_at(absolute.x,absolute.z)

func _on_origin_shifted(delta: Vector3) -> void:
	# world remains identity: all gameplay positions use the same local coordinate system.
	for child in world.get_children():
		if child is Node3D: child.position -= delta
	cam.position -= delta
	last_safe_position -= delta
	rope_target -= delta
	for enemy in enemies: enemy.home -= delta
	for puzzle in generated_puzzles:
		for key in ["center","target","plate","lever"]:
			if puzzle.has(key): puzzle[key] -= delta
	var path := PackedVector2Array()
	for point in last_path: path.append(point-Vector2(delta.x,delta.z))
	last_path = path
	# Stroke children are already in world coordinates; shifting its parent would double-shift new strokes.
	stroke_node.position = Vector3.ZERO
	for child in stroke_node.get_children():
		if child is Node3D: child.position -= delta

func _track_new_nodes(coord: Vector2i, before: int) -> void:
	if not chunk_nodes.has(coord): chunk_nodes[coord] = []
	for index in range(before,world.get_child_count()): chunk_nodes[coord].append(world.get_child(index))

func _spawn_generated_word(word: String, position_value: Vector3, id: String, coord: Vector2i) -> void:
	if stream.get_feature_state(id).get("picked",false): return
	var before := world.get_child_count()
	_spawn_word(word,position_value)
	loot[-1].id = id
	loot[-1].coord = coord
	var marker: Label3D = loot[-1].marker
	_hint(marker,"word",7.0,4)
	if id.ends_with(":prerequisite0"): marker.position += Vector3(-0.8,0.1,-0.55)
	if id.ends_with(":prerequisite1"): marker.position += Vector3(-0.8,0.2,0.95)
	_track_new_nodes(coord,before)

func _spawn_fountain(position_value: Vector3, id: String, coord: Vector2i) -> void:
	var before := world.get_child_count()
	var node := Low.model("pot",0.6)
	node.position = position_value
	world.add_child(node)
	Low.cylinder(node,0.35,0.35,0.025,Vector3(0,0.49,0),Color("54ddd0"),true)
	var marker := _marker("E · 墨泉",position_value+Vector3(-2.0,1.15,0.9),Color("c2fff2"))
	_hint(marker,"fountain",9.0,8)
	generated_fountains.append({"id":id,"node":node,"coord":coord})
	_track_new_nodes(coord,before)

func _on_chunk_loaded(coord: Vector2i, _node: Node3D, description: Dictionary) -> void:
	chunk_nodes[coord] = []
	for feature: Dictionary in description.features:
		var position_value: Vector3 = stream.to_local_position(coord,feature.pos)
		var id: String = feature.id
		match str(feature.kind):
			"scroll": _spawn_generated_word(str(feature.word),position_value,id,coord)
			"fountain": _spawn_fountain(position_value,id,coord)
			"enemy":
				var state: Dictionary = stream.get_feature_state(id)
				if int(state.get("hp",70)) <= 0:
					_spawn_generated_word(str(Rules.seed_manifest(seed_value+id.hash())[0]),position_value,id+":drop",coord)
					continue
				var before := world.get_child_count()
				_spawn_enemy(position_value+Vector3(0,0.6,0),int(feature.get("variant",0))+100)
				enemies[-1].id = id
				enemies[-1].coord = coord
				enemies[-1].hp = int(state.get("hp",70))
				enemies[-1].drop_word = str(Rules.seed_manifest(seed_value+id.hash())[0])
				_track_new_nodes(coord,before)
			"pull","weight","vines": _spawn_puzzle(feature,coord,position_value)
	Low.readable_ui(world)
	_boost_world_labels(world)

func _on_chunk_unloading(coord: Vector2i) -> void:
	for entry in enemies:
		if entry.get("coord",Vector2i(2147483647,2147483647)) == coord:
			stream.set_feature_state(entry.id,{"hp":entry.hp})
	loot = loot.filter(func(entry): return entry.get("coord",Vector2i(2147483647,2147483647)) != coord)
	enemies = enemies.filter(func(entry): return entry.get("coord",Vector2i(2147483647,2147483647)) != coord)
	generated_fountains = generated_fountains.filter(func(entry): return entry.coord != coord)
	generated_puzzles = generated_puzzles.filter(func(entry): return entry.coord != coord)
	for node in chunk_nodes.get(coord,[]):
		if is_instance_valid(node): node.queue_free()
	chunk_nodes.erase(coord)

func _spawn_puzzle(feature: Dictionary, coord: Vector2i, center: Vector3) -> void:
	var before := world.get_child_count()
	var kind: String = feature.kind
	var id: String = feature.id
	var target := center+Vector3(1.0,0,0)
	var plate := center+Vector3(-2,0,-2)
	var lever := center+Vector3(0,0,1.9)
	var state: Dictionary = stream.get_feature_state(id)
	var puzzle := {"id":id,"coord":coord,"kind":kind,"center":center,"target":target,"plate":plate,"lever":lever,"solved":bool(state.get("solved",false)),"route":str(state.get("route","")),"reward_word":str(Rules.seed_manifest(seed_value+id.hash())[0])}
	# A real closed pocket makes the reward inaccessible until geometry touches its mechanism.
	for z in [-1.65,1.65]: _box(center+Vector3(1,1.1,z),Vector3(3.2,2.2,0.20),Color("6b8171"))
	_box(center+Vector3(2.6,1.1,0),Vector3(0.20,2.2,3.3),Color("6b8171"))
	var gate := _box(center+Vector3(-0.6,1.1,0),Vector3(0.22,2.2,3.3),Color("5c855d") if kind == "vines" else Color("a98a65"))
	puzzle.gate = gate
	var treasure := Low.scroll()
	treasure.position = target+Vector3(0,0.15,0)
	world.add_child(treasure)
	puzzle.treasure = treasure
	var plate_visual := Low.model("plate",0.07)
	plate_visual.fit(1.1,0.07,1.1)
	plate_visual.position = plate+Vector3(0,0.04,0)
	world.add_child(plate_visual)
	Low.cylinder(world,0.10,0.10,0.75,lever+Vector3(0,0.4,0),Color("8ac0d3"),true)
	var title := {"pull":"围栏画页 · 抓取或配重","weight":"配重闸 · 压盘或吸杆","vines":"藤根 · 切断或撬开"}
	puzzle.title = _marker(str(title[kind]),center+Vector3(0.8,3.8,-1.5),Color("ffe9ad"))
	_hint(puzzle.title,"puzzle",16.0,10,id)
	puzzle.plate_label = _marker("配重盘",plate+Vector3(-0.35,1.05,-0.8),Color("eee0a8"))
	_hint(puzzle.plate_label,"detail",8.0,6,id)
	if kind == "weight":
		puzzle.lever_label = _marker("铁拉杆",lever+Vector3(0.8,1.05,0.8),Color("c2e9ff"))
		_hint(puzzle.lever_label,"detail",8.0,6,id)
	generated_puzzles.append(puzzle)
	_track_new_nodes(coord,before)
	# Every local event brings accessible prerequisites and a refill outside the gate.
	var prerequisites: Array = {"pull":["Sticky","Heavy"],"weight":["Heavy","Magnetic"],"vines":["Sharp","Heavy"]}[kind]
	for index in prerequisites.size():
		_spawn_generated_word(str(prerequisites[index]),center+Vector3(-3,0,index*1.2-0.6),id+":prerequisite%d"%index,coord)
	_spawn_fountain(center+Vector3(-3,0,-2.6),id+":refill",coord)
	if puzzle.solved:
		_set_solved_hints(puzzle)
		solved_ids[id] = true
		if solved_ids.size() > 512: solved_ids.erase(solved_ids.keys()[0])
		gate.collision_layer = 0
		gate.hide()
		treasure.hide()
		_spawn_puzzle_reward(puzzle)

func _generated_open_contact(origin: Vector2, aim: Vector2) -> bool:
	var effect := false
	for puzzle in generated_puzzles:
		if puzzle.solved: continue
		var accepted := false
		var route := ""
		match puzzle.kind:
			"pull":
				accepted = Rules.remote_contact(blueprint,origin,aim,tool_word,_xz(puzzle.target))
				route = tool_word.to_lower()+"_retrieval"
			"weight":
				accepted = tool_word == "Magnetic" and Rules.remote_contact(blueprint,origin,aim,tool_word,_xz(puzzle.lever))
				route = "magnetic_lever"
			"vines":
				accepted = Rules.vine_contact(blueprint,origin,aim,tool_word,_xz(puzzle.center+Vector3(-0.6,0,0)))
				route = "sharp_contact"
		if accepted:
			_solve_puzzle(puzzle,route)
			effect = true
	return effect

func _generated_closed_contact(target: Vector3) -> void:
	for puzzle in generated_puzzles:
		if puzzle.solved: continue
		var point: Vector3 = puzzle.center+Vector3(-0.6,0,0) if puzzle.kind == "vines" else puzzle.plate
		if Rules.weight_contact(blueprint,_xz(target),draw_rotation,tool_word,_xz(point)):
			_solve_puzzle(puzzle,"heavy_wedge" if puzzle.kind == "vines" else "heavy_counterweight")

func _solve_puzzle(puzzle: Dictionary, route: String) -> void:
	if puzzle.solved: return
	puzzle.solved = true
	puzzle.route = route
	_set_solved_hints(puzzle)
	last_contact = {"id":puzzle.id,"family":puzzle.kind,"route":route,"word":tool_word,"kind":blueprint.get("kind",""),"area":blueprint.get("area",0.0),"reach":blueprint.get("reach",0.0),"clock":clock}
	solved_ids[puzzle.id] = true
	solved_total += 1
	if solved_ids.size() > 512: solved_ids.erase(solved_ids.keys()[0])
	stream.set_feature_state(puzzle.id,{"solved":true,"route":route})
	puzzle.gate.collision_layer = 0
	puzzle.gate.hide()
	puzzle.treasure.hide()
	_spawn_puzzle_reward(puzzle)
	_toast("%s 解开了；%s真的碰到了机关。画页奖励只领取一次。"%[{"pull":"围栏","weight":"配重闸","vines":"藤根"}[puzzle.kind],Rules.NAMES[tool_word]])

func _spawn_puzzle_reward(puzzle: Dictionary) -> void:
	var position_value: Vector3 = puzzle.center+Vector3(-1.5,0,0) if puzzle.kind == "pull" else puzzle.target
	_spawn_generated_word(puzzle.reward_word,position_value,puzzle.id+":reward",puzzle.coord)

func _update_discovery() -> void:
	var coord: Vector2i = stream.absolute_chunk(player.position)
	if coord != discovery_coord:
		discovery_coord = coord
		discovery_description = stream.generator.describe(coord)
		var discovery_id := "%d:%d:visited"%[coord.x,coord.y]
		if not stream.get_feature_state(discovery_id).get("visited",false):
			discovered_total += 1
			stream.set_feature_state(discovery_id,{"visited":true})
		discovered_chunks["%d,%d"%[coord.x,coord.y]] = true
		if discovered_chunks.size() > 512: discovered_chunks.erase(discovered_chunks.keys()[0])
	if not exploration_label: return
	var description: Dictionary = discovery_description
	var home: Vector3 = stream.home_vector(player.position)
	var bearing := "东" if home.x > 0 else "西"
	bearing += "南" if home.z > 0 else "北"
	exploration_label.text = "%s · 探索 %d / 解谜 %d · 家 %s %.0fm%s"%[description.biome_name,discovered_total,solved_total,bearing,home.length()," · 前方地形正在展开" if loading_wait else ""]
	if map_open:
		var rows := PackedStringArray()
		for z in range(coord.y-2,coord.y+3):
			var row := ""
			for x in range(coord.x-2,coord.x+3):
				var key := "%d,%d"%[x,z]
				row += "  你  " if Vector2i(x,z) == coord else ("  家  " if x == 0 and z == 0 else ("  ●  " if discovered_chunks.has(key) else "  ·  "))
			rows.append(row)
		map_text.text = "北 ↑      48 米 / 格\n"+"\n".join(rows)+"\n\n从西侧入口返回画室。\n已探索 %d 片区域，已解 %d 道谜题。\n每个新机关附近有词语和墨泉；你可以绕行继续探索。"%[discovered_total,solved_total]

func _feature_snapshot() -> Array:
	var result := []
	for refill in generated_fountains:
		var entry := _point(refill.node.position)
		entry.id = refill.id
		entry.kind = "fountain"
		result.append(entry)
	for enemy in enemies:
		if enemy.has("id"):
			var entry := _point(enemy.node.position)
			entry.id = enemy.id
			entry.kind = "enemy"
			entry.hp = enemy.hp
			result.append(entry)
	return result

func _puzzle_snapshot() -> Array:
	var result := []
	for puzzle in generated_puzzles:
		result.append({"id":puzzle.id,"kind":puzzle.kind,"center":_point(puzzle.center),"target":_point(puzzle.target),"plate":_point(puzzle.plate),"lever":_point(puzzle.lever),"gate":_point(puzzle.gate.position),"solved":puzzle.solved,"route":puzzle.route,"reward_word":puzzle.reward_word})
	return result

func _build_settings() -> void:
	exploration_label = _label(hud,"",Vector2(24,136),Vector2(900,24),14)
	exploration_label.add_theme_color_override("font_color",Color("c3f2df"))
	setting_buttons.settings = _button(hud,"世界设置",Vector2(791,48),Vector2(148,29),func(): settings_open = not settings_open; settings_panel.visible = settings_open)
	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(173,155)
	settings_panel.size = Vector2(614,309)
	settings_panel.add_theme_stylebox_override("panel",_style(Color("173d45")))
	hud.add_child(settings_panel)
	var sheet := Control.new()
	sheet.custom_minimum_size = Vector2(600,298)
	settings_panel.add_child(sheet)
	_label(sheet,"画家 V8 · 把自己的路画出来",Vector2(18,9),Vector2(560,29),21)
	_label(sheet,"种子",Vector2(18,45),Vector2(64,25),15)
	seed_edit = LineEdit.new()
	seed_edit.position = Vector2(77,42)
	seed_edit.size = Vector2(170,31)
	seed_edit.text = str(seed_value)
	seed_edit.placeholder_text = "整数种子"
	sheet.add_child(seed_edit)
	for index in 3:
		var names := ["稀疏","均衡","密集"]
		var values := [0.45,1.0,1.7]
		setting_buttons["preset%d"%index] = _button(sheet,names[index],Vector2(267+index*104,42),Vector2(96,31),_preset.bind(values[index]))
	var kinds := ["resources","enemies","events"]
	var titles := ["词语 / 墨泉","污墨敌人","物理解谜"]
	for index in 3:
		var key: String = kinds[index]
		_label(sheet,titles[index],Vector2(18,82+index*35),Vector2(130,27),15)
		var slider := HSlider.new()
		slider.position = Vector2(148,85+index*35)
		slider.size = Vector2(394,24)
		slider.min_value = 0
		slider.max_value = 1.8
		slider.step = 0.05
		slider.value = densities[key]
		sheet.add_child(slider)
		density_sliders[key] = slider
		var value_label := _label(sheet,"%.2f"%slider.value,Vector2(548,82+index*35),Vector2(45,27),13)
		slider.value_changed.connect(func(value: float): value_label.text = "%.2f"%value)
	_label(sheet,"开始新世界清除所选种子的进度；保存 / 读取含库存和机关记录。\n主线营地保留；墨泉无限补墨，单个卷轴 / 画页只领取一次。",Vector2(18,190),Vector2(566,42),13)
	setting_buttons.start = _button(sheet,"开始新世界",Vector2(18,246),Vector2(153,34),_start_settings)
	setting_buttons.save = _button(sheet,"保存探索",Vector2(179,246),Vector2(128,34),save_exploration)
	setting_buttons.load = _button(sheet,"读取探索",Vector2(315,246),Vector2(128,34),load_exploration)
	setting_buttons.close = _button(sheet,"返回游戏",Vector2(451,246),Vector2(128,34),func(): settings_open = false; settings_panel.hide())
	map_panel = PanelContainer.new()
	map_panel.position = Vector2(229,171)
	map_panel.size = Vector2(502,303)
	map_panel.add_theme_stylebox_override("panel",_style(Color("173d45")))
	hud.add_child(map_panel)
	var map_sheet := Control.new()
	map_sheet.custom_minimum_size = Vector2(480,285)
	map_panel.add_child(map_sheet)
	map_text = _label(map_sheet,"",Vector2(18,14),Vector2(446,263),16)
	map_panel.hide()
	settings_panel.show()
	settings_open = true
	_update_discovery()

func _preset(value: float) -> void:
	for slider in density_sliders.values(): slider.value = value

func _start_settings() -> void:
	if not _journal_ready(): return
	if not seed_edit.text.is_valid_int():
		_toast("请输入整数种子。")
		return
	# Reset only the requested seed; another seed's journal and profile remain intact.
	loading_progression = true
	seed_value = int(seed_edit.text)
	for key in density_sliders: densities[key] = float(density_sliders[key].value)
	clear_selected_on_build = true
	reset_run(false)
	loading_progression = false
	settings_open = false
	settings_panel.hide()
	_toast("新旷野已生成。西侧出口通向连续地形；M 看地图，F4 保存设置。")

func _settings_snapshot() -> Dictionary:
	var rects := {}
	var pending_densities := {}
	for key in setting_buttons:
		var rect: Rect2 = setting_buttons[key].get_global_rect()
		rects[key] = [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	for key in density_sliders:
		var rect: Rect2 = density_sliders[key].get_global_rect()
		rects[key] = [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
		pending_densities[key] = density_sliders[key].value
	var seed_rect := seed_edit.get_global_rect()
	rects.seed = [seed_rect.position.x,seed_rect.position.y,seed_rect.size.x,seed_rect.size.y]
	return {"open":settings_open,"seed_text":seed_edit.text,"densities":densities,"pending_densities":pending_densities,"rects":rects}

func _profile_path() -> String:
	return "user://v8_ink_profile_%d.json"%seed_value

func save_exploration() -> void:
	if not _journal_ready(): return
	var absolute := player.position+Vector3(stream.origin_chunk.x*48.0,0,stream.origin_chunk.y*48.0)
	var core_loot := []
	for entry in loot:
		if not entry.has("id"): core_loot.append({"word":entry.word,"position":[entry.node.position.x+stream.origin_chunk.x*48.0,entry.node.position.y,entry.node.position.z+stream.origin_chunk.y*48.0],"collected":entry.collected})
	var saved_solids := []
	for solid in solids:
		var polygon := []
		for point in solid.tool.polygon: polygon.append([point.x/0.00625,point.y/0.00625])
		var point: Vector3 = solid.node.position+Vector3(stream.origin_chunk.x*48.0,0,stream.origin_chunk.y*48.0)
		saved_solids.append({"position":[point.x,point.y,point.z],"polygon":polygon,"word":solid.word,"rotation":solid.rotation})
	var drawing := []
	for point in draw_pad.points: drawing.append([point.x,point.y])
	var core_enemy_states := []
	for enemy in enemies:
		if not enemy.has("id"):
			var position_value: Vector3 = enemy.node.position+Vector3(stream.origin_chunk.x*48.0,0,stream.origin_chunk.y*48.0)
			core_enemy_states.append({"index":enemy.index,"hp":enemy.hp,"position":[position_value.x,position_value.y,position_value.z]})
	var data := {"version":8,"seed":seed_value,"densities":densities,"position":[absolute.x,absolute.y,absolute.z],"words":words,"ink":ink,"hp":hp,"core_loot":core_loot,"solids":saved_solids,"drawing":drawing,"closed":closed_mode,"tool_word":tool_word,"selected_word":selected_word,"key":key_retrieved,"river":river_crossed,"vines":vines_open,"turret":turret_disabled,"hazard":hazard_passed,"won":won,"key_route":key_route,"river_route":river_route,"hazard_route":hazard_route,"stage":story_stage,"discovered":discovered_chunks,"solved_ids":solved_ids,"discovered_total":discovered_total,"solved_total":solved_total}
	data.core_enemies = core_enemy_states
	data.lane_open = lane_gate.collision_layer == 0
	var file := FileAccess.open(_profile_path(),FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		_toast("已保存这个种子的探索、库存、造物和机关记录。")
	else: _toast("保存失败，请检查浏览器本地存储是否可写。")

func load_exploration() -> void:
	if not _journal_ready(): return
	if not seed_edit.text.is_valid_int(): return
	var requested_seed := int(seed_edit.text)
	var path := "user://v8_ink_profile_%d.json"%requested_seed
	if not FileAccess.file_exists(path):
		_toast("这个种子还没有保存的探索。")
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version",0) != 8 or int(data.get("seed",-1)) != requested_seed:
		_toast("存档版本不匹配；保留文件，未读取。")
		return
	loading_progression = true
	seed_value = requested_seed
	densities = data.densities.duplicate()
	reset_run(false)
	words.assign(data.words)
	ink = int(data.ink)
	hp = int(data.hp)
	key_retrieved = bool(data.key)
	river_crossed = bool(data.river)
	vines_open = bool(data.vines)
	turret_disabled = bool(data.turret)
	hazard_passed = bool(data.hazard)
	won = bool(data.won)
	key_route = str(data.key_route)
	river_route = str(data.river_route)
	hazard_route = str(data.hazard_route)
	story_stage = int(data.stage)
	discovered_chunks = data.discovered.duplicate()
	solved_ids = data.solved_ids.duplicate()
	discovered_total = int(data.get("discovered_total",discovered_chunks.size()))
	solved_total = int(data.get("solved_total",solved_ids.size()))
	for node in [key_gate if key_retrieved else null,vine_gate if vines_open else null,lane_gate if turret_disabled or bool(data.get("lane_open",false)) else null]:
		if node != null: node.collision_layer = 0; node.hide()
	if key_retrieved: key_node.hide()
	for stored in data.core_loot:
		var found := false
		for entry in loot:
			if entry.has("id"): continue
			if str(stored.word) == str(entry.word) and _xz(entry.node.position).distance_to(Vector2(stored.position[0],stored.position[2])) < 0.1:
				entry.collected = stored.collected
				entry.node.visible = not entry.collected
				if entry.has("marker"):
					entry.marker.visible = not entry.collected
					entry.marker.set_meta("hint_disabled",entry.collected)
				found = true
				break
		if not found:
			_spawn_word(str(stored.word),Vector3(stored.position[0],stored.position[1],stored.position[2]))
			loot[-1].collected = stored.collected
			loot[-1].node.visible = not bool(stored.collected)
			loot[-1].marker.visible = not bool(stored.collected)
			loot[-1].marker.set_meta("hint_disabled",bool(stored.collected))
	for stored in data.get("core_enemies",[]):
		for enemy in enemies:
			if enemy.has("id") or enemy.index != int(stored.index): continue
			enemy.hp = int(stored.hp)
			enemy.node.position = Vector3(stored.position[0],stored.position[1],stored.position[2])
			if enemy.hp <= 0:
				enemy.node.collision_layer = 0
				enemy.art.pose("dead")
	var stored_position: Array = data.position
	player.position = Vector3(stored_position[0],stored_position[1],stored_position[2])
	# Rebase first, then create saved geometry in the near-origin physics frame.
	stream.prime(player.position)
	stream.step(player.position)
	var offset := Vector3(stream.origin_chunk.x*48.0,0,stream.origin_chunk.y*48.0)
	for stored in data.solids:
		var points := PackedVector2Array()
		for point in stored.polygon: points.append(Vector2(point[0],point[1]))
		var tool := Rules.stroke(points,true)
		if tool.is_empty(): continue
		_create_solid(tool,str(stored.word),Vector3(stored.position[0],stored.position[1],stored.position[2])-offset,float(stored.rotation))
	var drawing := PackedVector2Array()
	for point in data.drawing: drawing.append(Vector2(point[0],point[1]))
	draw_pad.set_points(drawing)
	closed_mode = bool(data.closed)
	draw_pad.closed_mode = closed_mode
	tool_word = str(data.tool_word)
	selected_word = str(data.selected_word)
	blueprint = Rules.stroke(drawing,closed_mode) if not tool_word.is_empty() else {}
	loading_progression = false
	settings_open = false
	settings_panel.hide()
	player.velocity = Vector3.ZERO
	last_safe_position = player.position
	_update_hud()
	_toast("已读取探索；卷轴和已解机关不会重新送奖励。")

func _journal_ready() -> bool:
	stream.flush_save()
	if not stream.save_error.is_empty():
		_toast("区块保存失败；保留当前探索。请恢复本地存储后再试。")
		return false
	return true

func _hint(label: Label3D, kind: String, distance: float, priority: int, puzzle_id := "") -> void:
	label.set_meta("hint_kind",kind)
	label.set_meta("hint_distance",distance)
	label.set_meta("hint_priority",priority)
	label.set_meta("hint_puzzle",puzzle_id)

func _set_solved_hints(puzzle: Dictionary) -> void:
	puzzle.title.text = "已解 · "+str({"pull":"围栏画页","weight":"配重闸","vines":"藤根"}[puzzle.kind])
	puzzle.title.modulate = Color("b7ddbd")
	for key in ["plate_label","lever_label"]:
		if puzzle.has(key):
			puzzle[key].set_meta("hint_disabled",true)
			puzzle[key].hide()

func _update_nearby_hints() -> void:
	if Time.get_ticks_msec() < hints_next_ms: return
	hints_next_ms = Time.get_ticks_msec()+100
	var nearest_id := ""
	var nearest := 16.0
	for puzzle in generated_puzzles:
		var distance := _xz(puzzle.center).distance_to(_xz(player.position))
		if distance < nearest:
			nearest = distance
			nearest_id = puzzle.id
	var candidates: Array[Label3D] = []
	for child in world.get_children():
		if not child is Label3D or not child.has_meta("hint_kind"): continue
		var label: Label3D = child
		label.hide()
		if label.get_meta("hint_disabled",false): continue
		if _xz(label.position).distance_to(_xz(player.position)) > float(label.get_meta("hint_distance")): continue
		var puzzle_id: String = label.get_meta("hint_puzzle","")
		if not puzzle_id.is_empty() and puzzle_id != nearest_id: continue
		candidates.append(label)
	candidates.sort_custom(func(a: Label3D,b: Label3D):
		var a_priority: int = a.get_meta("hint_priority")
		var b_priority: int = b.get_meta("hint_priority")
		if a_priority != b_priority: return a_priority > b_priority
		return a.position.distance_squared_to(player.position) < b.position.distance_squared_to(player.position))
	var occupied: Array[Rect2] = []
	var visible_world := Rect2(10,165,940,309)
	for label in candidates:
		var screen := cam.unproject_position(label.global_position)
		if not visible_world.has_point(screen): continue
		var pixels_per_meter := screen.distance_to(cam.unproject_position(label.global_position+cam.global_basis.x))
		var metrics := Vector2(label.text.length()*44,52)
		if label.font != null:
			metrics = label.font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size)
		var size_value := metrics*label.pixel_size*pixels_per_meter
		var rect := Rect2(screen-size_value*0.5,size_value).grow(7)
		if occupied.any(func(other: Rect2): return rect.intersects(other)): continue
		label.show()
		occupied.append(rect)
