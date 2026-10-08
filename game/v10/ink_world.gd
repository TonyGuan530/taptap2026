extends Node3D
## Hybrid chapter: finite paper world, actual multi-stroke geometry and 2D notebook.
const Art := preload("res://lowpoly/library.gd")
const Painter := preload("res://v9/painter.gd")
const Audio := preload("res://tonight_audio.gd")
const Rules := preload("res://v10/sketch_rules.gd")
const SketchPad := preload("res://v10/sketch_pad.gd")
const Structures := preload("res://v10/structures.gd")
const Blade := preload("res://v10/blade.gd")
const TouchControls := preload("res://v10/touch_controls.gd")
const Inkling := preload("res://v9/inkling.gd")
const ReadableFont := preload("res://fonts/NotoSansSC-Medium.ttf")
const Portrait := preload("res://v9/art/painter.png")
const MAX_BLACK_INK := 320.0
const MAX_YELLOW_INK := 120.0
const MAX_HP := 3
const ENEMY_MAX_HP := 3
const FEET_OFFSET := 0.62
const SPEED := 3.5
const GRAVITY := 18.0
const SAFE_BOUNDS := Rect2(Vector2(-3.75,-5.75),Vector2(19.5,13.5))
const PROPERTY_TEXT := {"None":"无词条 · 尺寸和接触决定结果","Sticky":"黏性 · 板面抓地，支持 62° 陡坡","Elastic":"弹性 · 原笔迹实际放大 1.4 倍","Sharp":"锋利 · 黄刃真实接触可切开软藤"}
var player: CharacterBody3D
var actor: Node3D
var cam: Camera3D
var world: Node3D
var draw_pad: Control
var ui: Control
var touch_controls: Control
var footer_panel: Panel
var keyboard_help: Label
var touch_layout := false
var intro_panel: Panel
var notebook_panel: Panel
var result_panel: Panel
var hud_label: Label
var objective_label: Label
var message_label: Label
var estimate_label: Label
var result_label: Label
var buttons := {}
var intro_open := true
var notebook_open := false
var result_open := false
var selected_kind := "ladder"
var selected_color := "black"
var selected_property := "None"
var active_tool: Dictionary = {}
var saved_tools := {}
var drawing_analysis: Dictionary = {}
var ink := {"black":MAX_BLACK_INK,"yellow":0.0}
var words: Array = ["None"]
var structures: Array = []
var goals: Array = [false,false,false]
var goal_positions: Array[Vector3] = [Vector3(4,1.25,0),Vector3(8,2.05,2),Vector3(12,3.10,-2)]
var goal_nodes: Array[Node3D] = []
var yellow_unlocked := false
var won := false
var final_goal_collected := false
var final_goal_node: Node3D
var vine_body: StaticBody3D
var vines_cut := false
var vine_visual: Node3D
var enemy_body: CharacterBody3D
var enemy_actor: Node3D
var enemy_label: Label3D
var enemy_hp := ENEMY_MAX_HP
var enemy_state := "idle"
var enemy_timer := 0.0
var enemy_flash := 0.0
var player_hp := MAX_HP
var player_invulnerability := 0.0
var weapon: Node3D
var facing := Vector3.RIGHT
var notebook_help: Label
var landmark_positions := {"start":Vector3(0,0,0),"fountain":Vector3(-1.5,0,2),"threshold_goal":Vector3(4,1.25,0),"courtyard_goal":Vector3(8,2.05,2),"tower_goal":Vector3(12,3.1,-2),"threshold_aim":Vector3(2.5,1.25,0),"courtyard_aim":Vector3(6.5,2.05,2),"tower_aim":Vector3(10.5,3.1,-2),"threshold_side":Vector3(4,0.60,4),"courtyard_side":Vector3(8,1.0,5),"tower_side_low":Vector3(10.1,1.0,-4),"tower_side_high":Vector3(12,2.0,-4),"yellow_courtyard":Vector3(25,0,0),"yellow_entry":Vector3(27.5,0,0),"vines":Vector3(30.4,0,0),"enemy":Vector3(33.6,0.35,0),"yellow_goal":Vector3(36.5,0.60,0),"word_Sharp":Vector3(27.5,0,-0.6),"yellow_ledge":Vector3(29.25,2.60,0.70)}
var safe_point := Vector3(0,FEET_OFFSET,0)
var climbing_id := -1
var climb_up_guard := false
var climb_progress := 0.0
var next_id := 1
var preview: Node3D
var preview_data: Dictionary = {}
var preview_age := 0.0
var qa_enabled := false
var qa_age := 0.0
var clock := 0.0
var word_pickups: Array = []
var fountains: Array[Vector3] = [Vector3(-1.5,0,2),Vector3(8.4,0,2.5),Vector3(12,0,2.5)]

func _ready() -> void:
	_build_environment()
	_build_world()
	_build_player()
	_build_ui()
	if OS.has_feature("web"):
		qa_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') === '1'"))
		if bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0 || matchMedia('(pointer: coarse)').matches")): _enable_touch_layout()
	elif DisplayServer.is_touchscreen_available(): _enable_touch_layout()
	_update_camera(1.0)
	_update_hud()
	_message("画页散了。还好，笔还在。")

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("b5c4bd")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("e2e8df")
	settings.ambient_light_energy = 0.28
	settings.ambient_light_sky_contribution = 0.0
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-30,0)
	light.light_color = Color("fff2db")
	light.light_energy = 0.52
	light.shadow_enabled = true
	add_child(light)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 12.5
	cam.far = 90.0
	cam.current = true
	add_child(cam)

func _build_world() -> void:
	world = Node3D.new()
	world.name = "PaperWorld"
	add_child(world)
	_platform("SafePaper",Vector3(6,-0.25,1.0),Vector3(20,0.5,14),Color("eadcbe"))
	for layer in 3:
		Art.box(world,Vector3(20,0.08,14),Vector3(6,-0.55-layer*0.12,1),Color("cdbb98").lightened(layer*0.05))
	_platform("FoldedThreshold",Vector3(4,0.625,0),Vector3(3,1.25,3),Color("ddc7a2"))
	_platform("ThresholdSide",Vector3(4,0.30,4),Vector3(3,0.60,2),Color("e2cba7"))
	_platform("SplitCourtyard",Vector3(8,1.025,2),Vector3(3,2.05,3),Color("d4b896"))
	_platform("CourtyardSide",Vector3(8,0.50,5),Vector3(2.4,1.0,2),Color("ddc09d"))
	_platform("LeaningBookTower",Vector3(12,1.55,-2),Vector3(3,3.10,3),Color("c9aa84"))
	_platform("TowerSideLow",Vector3(10.1,0.5,-4),Vector3(2,1,2),Color("ddc29e"))
	_platform("TowerSideHigh",Vector3(12,1.0,-4),Vector3(2.2,2,2),Color("d1b794"))
	for i in goal_positions.size():
		var node := Node3D.new()
		node.position = goal_positions[i]
		world.add_child(node)
		Art.box(node,Vector3(0.65,0.08,0.48),Vector3(0,0.20,0),Color("fff2d4"))
		for line in 3: Art.box(node,Vector3(0.42,0.012,0.025),Vector3(0,0.25,-0.12+line*0.1),Color("566f71"))
		var marker := Art.cylinder(node,0,0.16,0.50,Vector3(0,0.75,0),Color("edb456"),true)
		marker.rotation.z = 0.18
		goal_nodes.append(node)
		_label3d(node,["折页门槛","裂缝中庭","倾斜书塔"][i],Vector3(0,1.35,0))
	for position in fountains:
		Art.cylinder(world,0.50,0.58,0.12,position+Vector3(0,0.06,0),Color("baa079"))
		Art.cylinder(world,0.39,0.39,0.015,position+Vector3(0,0.13,0),Color("456d70"))
		_label3d(world,"补墨 · E",position+Vector3(0,0.7,0))
	for entry in [["Sticky",Vector3(7.6,0,1.0)],["Elastic",Vector3(10,0,1.0)],["Sharp",landmark_positions.word_Sharp]]:
		var node := Art.scroll()
		node.position = entry[1]
		world.add_child(node)
		word_pickups.append({"word":entry[0],"pos":entry[1],"node":node,"collected":false})
		_label3d(node,{"Sticky":"黏性","Elastic":"弹性","Sharp":"锋利"}[entry[0]],Vector3(0,0.85,0))
	# Four environmental clues: broken rails, scattered paper, book ribbon and ink bottle.
	for x in [-0.25,0.25]:
		var rail := Art.box(world,Vector3(0.08,0.09,1.3),Vector3(2.9,0.06,x+2.1),Color("677d7b"))
		rail.rotation.y = 0.35
	Art.box(world,Vector3(0.50,0.025,0.36),Vector3(7,0.025,-2),Color("f8ebcb"))
	Art.box(world,Vector3(0.18,0.03,2.4),Vector3(12.4,3.13,-2),Color("b2685d"))
	Art.cylinder(world,0.16,0.20,0.40,Vector3(13.8,0.2,1),Color("d3ad48"))
	for x in [-3,1,7,9,15]:
		for z in [-4.6,6.7]: _fold_tree(Vector3(x,0,z),1.6+fmod(x*0.13+4,0.6))
	for i in 11:
		var x := -2.0+float(i)*1.65
		Art.box(world,Vector3(0.7,0.025,0.1),Vector3(x,0.02,-3.1),Color("a9a68e"))
	_build_yellow_courtyard()

func _build_yellow_courtyard() -> void:
	# Tall paper folds cover the complete immutable floor width: walking around
	# a short fence is impossible. The low bridge requires actual black building.
	_platform("VineNorthFold",Vector3(30.4,2,-3.75),Vector3(0.60,4,4.5),Color("c8b58f"))
	_platform("VineSouthFold",Vector3(30.4,2,4.75),Vector3(0.60,4,6.5),Color("c8b58f"))
	_platform("YellowBypassLedge",Vector3(30,2.47,0.70),Vector3(2.4,0.26,0.95),Color("d5bb8e"))
	_label3d(world,"藤庭 · 锋利接触切藤 / 黑墨搭路越过",Vector3(28.3,3.7,0))
	_label3d(world,"借这里落脚",landmark_positions.yellow_ledge+Vector3(0,0.65,0))
	vine_body = StaticBody3D.new(); vine_body.name = "SoftVineGate"
	vine_body.position = Vector3(30.4,1.10,0); vine_body.collision_layer = 5; vine_body.collision_mask = 2
	vine_body.set_meta("soft_vine",true)
	world.add_child(vine_body)
	var collider := CollisionShape3D.new(); var shape := BoxShape3D.new()
	shape.size = Vector3(0.30,2.20,3.0); collider.shape = shape; vine_body.add_child(collider)
	vine_visual = Node3D.new(); vine_body.add_child(vine_visual)
	for z in [-1.25,-0.80,-0.35,0.10,0.55,1.0,1.35]:
		var stalk := Art.cylinder(vine_visual,0.075,0.10,2.20,Vector3(0,0,z),Color("64816b"))
		stalk.rotation.x = 0.08*sin(z*5)
		for h in [-0.5,0.35]:
			var leaf := Art.box(vine_visual,Vector3(0.08,0.24,0.30),Vector3(-0.12,h,z),Color("819969")); leaf.rotation.x = -0.5
	_label3d(vine_visual,"软藤 · 锋利墨刃",Vector3(0,1.40,0))
	enemy_body = CharacterBody3D.new(); enemy_body.name = "CourtyardInkling"
	enemy_body.position = Vector3(33.6,0.35,0); enemy_body.collision_layer = 4; enemy_body.collision_mask = 1
	enemy_body.set_meta("inkling",true); world.add_child(enemy_body)
	var enemy_collider := CollisionShape3D.new(); var enemy_shape := CapsuleShape3D.new()
	enemy_shape.radius = 0.34; enemy_shape.height = 0.70; enemy_collider.shape = enemy_shape
	enemy_body.add_child(enemy_collider)
	enemy_actor = Inkling.new(); enemy_actor.position.y = -0.35; enemy_body.add_child(enemy_actor)
	enemy_label = Label3D.new(); enemy_label.font = ReadableFont; enemy_label.font_size = 40; enemy_label.pixel_size = 0.008
	enemy_label.position = Vector3(0,1.3,0); enemy_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	enemy_label.modulate = Color("334953"); enemy_label.outline_modulate = Color("f3e4c3"); enemy_label.outline_size = 3
	enemy_body.add_child(enemy_label)
	_platform("FinalPageDais",Vector3(36.5,0.30,0),Vector3(2.4,0.60,2.4),Color("dac19b"))
	final_goal_node = Node3D.new(); final_goal_node.position = landmark_positions.yellow_goal; world.add_child(final_goal_node)
	Art.box(final_goal_node,Vector3(0.85,0.06,0.60),Vector3(0,0.18,0),Color("fff1cd"))
	for line in 4: Art.box(final_goal_node,Vector3(0.55,0.012,0.025),Vector3(0,0.23,-0.17+line*0.11),Color("778c79"))
	_label3d(final_goal_node,"最后的画页",Vector3(0,1.25,0))

func _platform(title: String, pos: Vector3, dimensions: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = title
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("ink_support",true)
	body.set_meta("support_top",pos.y+dimensions.y*0.5)
	body.set_meta("support_bounds",Rect2(Vector2(pos.x-dimensions.x*0.5,pos.z-dimensions.z*0.5),Vector2(dimensions.x,dimensions.z)))
	world.add_child(body)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	Art.box(body,dimensions,Vector3.ZERO,color)
	if dimensions.y > 0.6:
		for y in range(1,int(dimensions.y/0.25)+1):
			Art.box(body,Vector3(dimensions.x+0.025,0.025,dimensions.z+0.025),Vector3(0,-dimensions.y*0.5+y*0.25,0),color.darkened(0.08))
	return body

func _fold_tree(position: Vector3, height: float) -> void:
	Art.cylinder(world,0.035,0.09,height*0.55,position+Vector3(0,height*0.275,0),Color("876f56"))
	for level in 3:
		var crown := Art.cylinder(world,0,0.48-level*0.07,height*0.65,position+Vector3(0,height*0.5+level*0.25,0),Color("62857d").lightened(level*0.03))
		crown.mesh.radial_segments = 4
		crown.rotation.y = PI/4

func _label3d(parent: Node3D, text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text; label.position = pos; label.font = ReadableFont
	label.font_size = 40; label.pixel_size = 0.009
	label.modulate = Color("263e43"); label.outline_size = 2
	label.outline_modulate = Color("f2e4c8")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "PainterBody"
	player.collision_layer = 2
	player.collision_mask = 1
	player.floor_max_angle = deg_to_rad(48)
	player.floor_snap_length = 0.25
	player.position = safe_point
	add_child(player)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25; shape.height = 1.20
	collider.shape = shape
	player.add_child(collider)
	actor = Painter.new()
	actor.position.y = -FEET_OFFSET
	player.add_child(actor)

func _process(delta: float) -> void:
	touch_controls.set_gameplay_enabled(not intro_open and not notebook_open and not result_open)
	touch_controls.attack_available = selected_color == "yellow" and weapon != null
	if touch_controls.climbing != (climbing_id >= 0):
		touch_controls.climbing = climbing_id >= 0; touch_controls.queue_redraw()
	clock += delta
	_update_camera(delta)
	preview_age += delta
	if preview_age >= 0.12:
		preview_age = 0.0; _update_preview()
	# Projection is published only after the current final camera transform.
	qa_age += delta
	if qa_enabled and qa_age > 0.1:
		qa_age = 0.0
		var snapshot := qa_snapshot()
		snapshot.touch = touch_controls.snapshot()
		snapshot.viewport = [get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y]
		JavaScriptBridge.eval("window.__v10_ink_qa = "+JSON.stringify(snapshot)+";")

func _physics_process(delta: float) -> void:
	if intro_open or notebook_open or result_open:
		player.velocity.x = 0; player.velocity.z = 0
		if climbing_id < 0:
			player.velocity.y -= GRAVITY*delta; player.move_and_slide()
		actor.pose("idle"); return
	_step_combat(delta)
	if climbing_id >= 0:
		var climb_input := clampf(float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-touch_controls.axis.y,-1.0,1.0)
		climb_step(delta,climb_input)
	else:
		_update_floor_property()
		# Finishing a climb requires a fresh upward input before walking forward.
		# Otherwise the held climb direction immediately carries a player off a small landing.
		if not Input.is_physical_key_pressed(KEY_W) and not Input.is_physical_key_pressed(KEY_UP): climb_up_guard = false
		var keys := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if climb_up_guard and keys.y<0: keys.y = 0
		var movement: Vector2 = (keys.normalized()+touch_controls.axis).limit_length(1.0)
		var direction := Vector3(movement.x,0,movement.y)
		player.velocity.x = direction.x*SPEED; player.velocity.z = direction.z*SPEED
		player.velocity.y -= GRAVITY*delta
		player.move_and_slide()
		if direction.length() > 0.1: facing = direction
		actor.face(direction,delta)
		actor.pose("attack" if weapon and weapon.swinging else ("walk" if direction.length() > 0.1 else "idle"))
		if player.is_on_floor(): _remember_safe_point()
	if player.position.y < -3.0 or absf(player.position.z-1) > 11 or player.position.x < -8 or player.position.x > 44:
		_recover_player()
		_message("回到了最近的落脚处，画稿和造物都还在。")
	collect_goals()
	collect_words()

func attack() -> bool:
	if intro_open or notebook_open or result_open or climbing_id >= 0: return false
	if selected_color != "yellow" or not weapon:
		_message("选黄墨并保存墨刃，再按左键或 F 挥砍。" ); return false
	if not weapon.begin_swing(): return false
	actor.pose("attack"); Audio.play(self,330); _update_hud()
	return true

func _step_combat(delta: float) -> void:
	player_invulnerability = maxf(0,player_invulnerability-delta)
	if weapon:
		for body in weapon.step(delta):
			if body == vine_body and not vines_cut:
				if weapon.analysis.property == "Sharp":
					vines_cut = true; vine_body.collision_layer = 0; vine_visual.hide()
					_message("锋利墨刃碰到了软藤，藤庭的路打开了。" ); Audio.play(self,1060)
				else: _message("确实碰到了软藤；锋利能切断它，也可以用黑墨搭路越过。")
			elif body == enemy_body and enemy_hp > 0:
				enemy_hp = maxi(0,enemy_hp-(2 if weapon.analysis.property == "Sharp" else 1))
				enemy_flash = 0.22; enemy_state = "hurt" if enemy_hp > 0 else "dead"; enemy_timer = 0.60
				if enemy_hp == 0:
					enemy_body.collision_layer = 0; enemy_actor.pose("dead")
				_message("墨刃命中污墨 · %d/%d。%s" % [enemy_hp,ENEMY_MAX_HP,"污墨散开了。" if enemy_hp == 0 else "它退了一步。"])
				Audio.play(self,480)
	if not yellow_unlocked: return
	enemy_flash = maxf(0,enemy_flash-delta)
	enemy_actor.modulate = Color("ffaf82") if enemy_flash > 0 else Color.WHITE
	var delta_to_player := player.position-enemy_body.position
	var close := Vector2(delta_to_player.x,delta_to_player.z).length() < 1.30 and absf(delta_to_player.y) < 0.9
	if enemy_hp > 0:
		enemy_actor.face(Vector3(delta_to_player.x,0,delta_to_player.z),delta)
		enemy_timer = maxf(0,enemy_timer-delta)
		if enemy_state == "idle" and close:
			enemy_state = "windup"; enemy_timer = 0.65
		elif enemy_state == "windup" and enemy_timer <= 0:
			enemy_state = "attack"; enemy_timer = 0.24
			if close: damage_player(1)
		elif enemy_state == "attack" and enemy_timer <= 0:
			enemy_state = "cooldown"; enemy_timer = 1.35
		elif enemy_state in ["cooldown","hurt"] and enemy_timer <= 0: enemy_state = "idle"
		enemy_actor.pose("attack" if enemy_state == "attack" else "idle")
		enemy_actor.scale = Vector3(1.13,0.78,1.13) if enemy_state == "windup" else Vector3.ONE
	enemy_label.text = "污墨 %d/%d · %s" % [enemy_hp,ENEMY_MAX_HP,{"idle":"可绕开","windup":"蓄势！","attack":"挥击！","cooldown":"回气","hurt":"命中","dead":"散开了"}[enemy_state]]
	enemy_label.modulate = Color("ba5d49") if enemy_state in ["windup","attack"] else Color("334953")
	_update_hud()

func damage_player(amount: int) -> void:
	if player_invulnerability > 0 or won: return
	player_hp = maxi(0,player_hp-amount); player_invulnerability = 1.0
	Audio.play(self,180)
	if player_hp == 0:
		_recover_player(); player_hp = MAX_HP; player_invulnerability = 2.0
		_message("回到最近的落脚处；画稿、墨刃和造物都还在。墨泉旁 E 可补满两色。")
	else: _message("污墨击中了你 · 生命 %d/%d。退开等它回气，或从侧面绕过。" % [player_hp,MAX_HP])
	_update_hud()

func _remember_safe_point() -> void:
	# Any saved X/Z has immutable paper terrain beneath it, even if a board is refunded.
	if SAFE_BOUNDS.has_point(Vector2(player.position.x,player.position.z)) and player.position.y > 0.50:
		safe_point = player.position

func _recover_player() -> void:
	if not SAFE_BOUNDS.has_point(Vector2(safe_point.x,safe_point.z)): safe_point = Vector3(0,FEET_OFFSET,0)
	var support := support_at(safe_point-Vector3(0,FEET_OFFSET-0.2,0),12.0)
	player.position = support.position+Vector3(0,FEET_OFFSET+0.05,0) if not support.is_empty() else Vector3(0,FEET_OFFSET,0)
	player.velocity = Vector3.ZERO
	climbing_id = -1

func _update_floor_property() -> void:
	var sticky := false
	# Sample the real capsule footprint, including its leading edge on a steep ramp.
	# A centre-only ray misses the board before the capsule first touches it.
	var feet := player.position-Vector3(0,FEET_OFFSET,0)
	for offset in [Vector3.ZERO,Vector3(0.24,0,0),Vector3(-0.24,0,0),Vector3(0,0,0.24),Vector3(0,0,-0.24)]:
		var support := support_at(feet+offset+Vector3(0,0.45,0),0.95)
		if not support.is_empty() and support.collider.get_meta("ink_property","None") == "Sticky": sticky = true
	player.floor_max_angle = deg_to_rad(64 if sticky else 48)
	player.floor_stop_on_slope = true

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch: _enable_touch_layout()
	var touch_press: bool = event is InputEventScreenTouch and event.pressed
	var mouse_press: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION
	if touch_layout and (touch_press or mouse_press):
		for button in buttons.values():
			if intro_open and not intro_panel.is_ancestor_of(button): continue
			if notebook_open and not notebook_panel.is_ancestor_of(button): continue
			if result_open and not result_panel.is_ancestor_of(button): continue
			if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position):
				button.pressed.emit(); get_viewport().set_input_as_handled(); return

func jump_or_exit() -> void:
	if intro_open or notebook_open or result_open: return
	if climbing_id >= 0: exit_climb(false)
	elif player.is_on_floor(): player.velocity.y = 5.0

func _touch_action(action: String) -> void:
	match action:
		"jump": jump_or_exit()
		"attack": attack()
		"interact": interact()
		"notebook": toggle_notebook()
		"reclaim": reclaim_nearest()

func _touch_world(point: Vector2) -> void:
	if intro_open or notebook_open or result_open: return
	if selected_color == "yellow": attack(); return
	var hit := mouse_surface(point)
	if not hit.is_empty(): place_active(hit.position)

func _enable_touch_layout() -> void:
	if touch_layout: return
	touch_layout = true; touch_controls.set_touch_enabled(true)
	footer_panel.hide(); keyboard_help.hide()
	message_label.position = Vector2(205,503); message_label.size = Vector2(730,32)
	message_label.add_theme_font_size_override("font_size",16)
	for button in buttons.values(): button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.notebook.text = "画纸"; buttons.restart.text = "重开"
	buttons.close.text = "关闭画纸"; buttons.undo.text = "撤销末笔"
	for id in ["ladder","board","blade","color_black","color_yellow"]:
		buttons[id].position.y = 54; buttons[id].size.y = 56
	for i in 4:
		var id: String = ["property_None","property_Sticky","property_Elastic","property_Sharp"][i]
		buttons[id].position.y = 145+i*57; buttons[id].size.y = 52
	notebook_help.hide(); draw_pad.position.y = 112
	for id in ["undo","clear","confirm"]:
		buttons[id].position.y = 422; buttons[id].size.y = 52

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if intro_open:
			if event.physical_keycode in [KEY_ENTER,KEY_SPACE]: begin_adventure()
			return
		if event.physical_keycode == KEY_TAB:
			toggle_notebook(); get_viewport().set_input_as_handled(); return
		if notebook_open:
			if event.physical_keycode == KEY_Z: draw_pad.undo_stroke()
			if event.physical_keycode == KEY_ESCAPE: toggle_notebook()
			return
		if event.physical_keycode == KEY_R: reset_run(); return
		if result_open: return
		if event.physical_keycode == KEY_E: interact()
		if event.physical_keycode in [KEY_Q,KEY_Z]: reclaim_nearest()
		if event.physical_keycode == KEY_F: attack()
		if event.physical_keycode == KEY_SPACE:
			jump_or_exit()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION: return
		if intro_open or notebook_open or result_open: return
		if selected_color == "yellow": attack(); return
		var hit := mouse_surface(event.position)
		if not hit.is_empty(): place_active(hit.position)

func _update_camera(delta: float) -> void:
	var focus := player.position+Vector3(2.7,0.1,0)
	var desired := focus+Vector3(0,12.5,10.7)
	cam.position = cam.position.lerp(desired,minf(1,delta*9))
	cam.look_at(focus,Vector3.UP)

func mouse_surface(screen: Vector2) -> Dictionary:
	var origin := cam.project_ray_origin(screen)
	var end := origin+cam.project_ray_normal(screen)*90.0
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1))

func support_at(position: Vector3, depth := 1.0) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(position+Vector3(0,0.15,0),position-Vector3(0,depth,0),1)
	return get_world_3d().direct_space_state.intersect_ray(query)

func apply_drawing() -> bool:
	drawing_analysis = Rules.analyze(draw_pad.get_strokes(),selected_kind,selected_property)
	if not drawing_analysis.ok:
		_message(drawing_analysis.reason); _update_estimate(); return false
	if selected_property not in words or (selected_color == "yellow" and not yellow_unlocked):
		_message("先到地图上拾到这个墨色或词条；你的作品仍保留。" ); return false
	if (selected_kind == "blade") != (selected_color == "yellow"):
		_message("黄墨制作墨刃；黑墨搭梯架和板面。画稿仍保留。" ); return false
	if selected_kind == "blade":
		var available: float = ink.yellow+(weapon.analysis.cost if weapon else 0.0)
		if available < drawing_analysis.cost:
			_message("黄墨还差 %.1f；到墨泉 E 补满，或 Q 回收手中墨刃。" % (drawing_analysis.cost-available)); return false
		if weapon: weapon.queue_free()
		weapon = Blade.new(); weapon.configure(drawing_analysis); actor.add_child(weapon)
		ink.yellow = minf(MAX_YELLOW_INK,available-drawing_analysis.cost)
		actor.brush.hide()
	active_tool = drawing_analysis.duplicate(true)
	active_tool.color = selected_color
	saved_tools[selected_color] = active_tool.duplicate(true)
	_message("墨刃已握在手中：%.2f 米 × %.2f 米。左键 / F 挥砍；接触才命中。" % [active_tool.length,active_tool.width] if selected_kind == "blade" else "画稿已保存：%.2f 米 × %.2f 米。关上画纸，点真实台沿摆放。" % [active_tool.length,active_tool.width])
	Audio.play(self,720)
	if notebook_open: toggle_notebook()
	_update_hud(); return true

func build_placement(aim: Vector3) -> Dictionary:
	var result := {"ok":false,"reachable":false,"climbable":false,"reason":"Tab 打开画纸，先保存一件作品。","start":Vector3.ZERO,"end":Vector3.ZERO,"direction":Vector3.UP,"climb_end":Vector3.ZERO,"exit":Vector3.ZERO,"required":0.0}
	if active_tool.is_empty(): return result
	if active_tool.kind == "blade":
		result.reason = "墨刃握在手中，左键 / F 挥砍；黑墨才摆放造物。"; return result
	var feet := player.position-Vector3(0,FEET_OFFSET,0)
	var support := support_at(feet+Vector3(0,0.05,0),0.45)
	if support.is_empty():
		result.reason = "先站在真实地面或板面上，再搭新造物。"; return result
	var target := support_at(aim+Vector3(0,0.20,0),4.0)
	if target.is_empty():
		result.reason = "这里没有真实落脚面，请瞄准墙面或台沿。"; return result
	var top: Vector3 = target.position
	var horizontal := Vector3(top.x-feet.x,0,top.z-feet.z).normalized()
	if horizontal.length() < 0.1:
		result.reason = "把目标点选在身旁以外，留出搭建方向。"; return result
	var start := Vector3(feet.x,support.position.y+0.035,feet.z)+horizontal*0.24
	var end_target := top+Vector3(0,0.04,0)
	var exit_target := top+Vector3(0,FEET_OFFSET+0.04,0)
	var body: Object = target.collider
	if body.has_meta("support_bounds") and top.y > start.y+0.20:
		var bounds: Rect2 = body.get_meta("support_bounds")
		var a := Vector2(start.x,start.z)
		var b := Vector2(top.x,top.z)
		var crossing := b
		var closest := INF
		var corners := [bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]
		for i in 4:
			var contact = Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])
			if contact != null and a.distance_to(contact) < closest:
				crossing = contact; closest = a.distance_to(contact)
		if active_tool.kind == "ladder":
			end_target = Vector3(crossing.x,top.y+0.04,crossing.y)-horizontal*0.32
			exit_target = Vector3(crossing.x,top.y+FEET_OFFSET+0.04,crossing.y)+horizontal*0.43
		else:
			# A ramp must meet the actual outer lip, rather than tunnel into its solid wall.
			end_target = Vector3(crossing.x,top.y+0.12,crossing.y)-horizontal*0.03
	var distance := start.distance_to(end_target)
	result.start = start; result.required = distance; result.climb_end = end_target; result.exit = exit_target
	result.direction = (end_target-start).normalized()
	result.end = start+result.direction*float(active_tool.length)
	result.reachable = active_tool.length+0.035 >= distance
	if not result.reachable:
		result.reason = "还差 %.2f 米。画长一点、走近一点，或借侧台接力。" % (distance-active_tool.length); return result
	var allowed_slope := 62.0 if active_tool.property == "Sticky" else 46.0
	if active_tool.kind == "board" and result.direction.y > sin(deg_to_rad(allowed_slope)):
		result.reason = "坡度太陡，退远一点搭坡，或改用梯架。"; return result
	var exit_support := support_at(exit_target-Vector3(0,FEET_OFFSET-0.08,0),0.40)
	if active_tool.kind == "ladder" and (exit_support.is_empty() or not _clear_capsule(exit_target)):
		result.reason = "顶端缺少落脚面或头顶空间，换个台沿再摆。"; return result
	if active_tool.kind == "ladder" and not _capsule_can_move(start+Vector3(0,FEET_OFFSET,0),end_target+Vector3(0,FEET_OFFSET,0)):
		result.reason = "途中有实体挡住了边梁，绕开侧台再瞄准。"; return result
	if distance < 0.38:
		result.reason = "两端太近，请选择更远的支撑。"; return result
	result.ok = true
	result.climbable = active_tool.kind == "ladder"
	result.reason = "E 进入梯架，W/S 上下，Space 离开。" if active_tool.kind == "ladder" else "沿你画出的板面走；它的轮廓就是真实支撑。"
	return result

func _clear_capsule(position: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.24; shape.height = 1.15
	query.shape = shape; query.transform = Transform3D(Basis.IDENTITY,position+Vector3(0,0.02,0))
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _capsule_can_move(from: Vector3, to: Vector3) -> bool:
	# Godot cast_motion ignores shapes already overlapping its start position.
	if not _clear_capsule(from): return false
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.24; shape.height = 1.15
	query.shape = shape; query.transform = Transform3D(Basis.IDENTITY,from)
	query.motion = to-from; query.collision_mask = 1; query.margin = 0.015
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	return fractions.is_empty() or fractions[0] >= 0.999

func place_active(aim: Vector3) -> bool:
	var placement := build_placement(aim)
	if not placement.ok:
		_message(placement.reason); return false
	var price: float = active_tool.cost
	if ink.black < price:
		_message("黑墨还差 %.1f。走近墨泉按 E，或远离造物后按 Q 回收。" % (price-ink.black)); return false
	var node := Structures.create(active_tool,placement.start,placement.direction)
	world.add_child(node)
	var entry := placement.duplicate(true)
	entry.id = next_id; next_id += 1
	entry.node = node; entry.kind = active_tool.kind; entry.length = active_tool.length
	entry.width = active_tool.width; entry.cost = price; entry.property = active_tool.property
	entry.analysis = active_tool.duplicate(true)
	structures.append(entry)
	ink.black -= price
	_message(placement.reason); Audio.play(self,540); _update_hud()
	return true

func _update_preview() -> void:
	preview_data = {}
	if preview:
		preview.queue_free(); preview = null
	if intro_open or notebook_open or result_open or active_tool.is_empty() or active_tool.kind == "blade": return
	var screen: Vector2 = touch_controls.aim_screen if touch_controls.touch_enabled and touch_controls.has_aim else get_viewport().get_mouse_position()
	var hit := mouse_surface(screen)
	if hit.is_empty(): return
	var placement := build_placement(hit.position)
	preview_data = placement
	if placement.required < 0.1: return
	preview = Structures.create(active_tool,placement.start,placement.direction,true)
	world.add_child(preview)
	var end_marker := Art.cylinder(preview,0.08,0.08,0.15,Vector3(0,active_tool.length,0),Color("dca558") if placement.ok else Color("cb6b5c"),true)
	end_marker.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func try_climb() -> bool:
	var feet := player.position-Vector3(0,FEET_OFFSET,0)
	var nearest: Dictionary = {}
	var distance := 1.1
	for entry in structures:
		if not entry.climbable: continue
		var contact: float = feet.distance_to(entry.start)
		if contact < distance: nearest = entry; distance = contact
	if nearest.is_empty(): return false
	climbing_id = nearest.id; climb_progress = 0.0
	player.velocity = Vector3.ZERO
	player.position = nearest.start+Vector3(0,FEET_OFFSET,0)
	_message("沿实际边梁攀爬：W/S 上下，Space 离开。")
	return true

func climb_step(delta: float, input: float) -> void:
	var entry := _find_structure(climbing_id)
	if entry.is_empty(): exit_climb(false); return
	var next_progress: float = clampf(climb_progress+input*2.2*delta,0.0,entry.required)
	var next_position: Vector3 = entry.start+entry.direction*next_progress+Vector3(0,FEET_OFFSET,0)
	if not _capsule_can_move(player.position,next_position):
		_message("边梁前有新的支撑挡住了路；按 S 退回或 Space 离开。" ); return
	climb_progress = next_progress
	player.position = next_position
	player.velocity = Vector3.ZERO
	actor.face(Vector3(entry.direction.x,0,entry.direction.z),delta)
	actor.pose("walk" if absf(input) > 0.1 else "idle")
	if climb_progress >= entry.required-0.01 and input > 0:
		var supported := support_at(entry.exit-Vector3(0,FEET_OFFSET-0.08,0),0.4)
		if not supported.is_empty() and _clear_capsule(entry.exit):
			player.position = entry.exit; _remember_safe_point()
			climbing_id = -1; player.velocity = Vector3.ZERO
			climb_up_guard = true; touch_controls.release_all()
			_message("脚已落在真实台面上，走近画页把它拾起。")
		else: _message("顶端现在无法落脚，按 S 下来或 Space 退出。")

func exit_climb(at_top: bool) -> void:
	if climbing_id < 0: return
	var entry := _find_structure(climbing_id)
	if at_top and not entry.is_empty() and _clear_capsule(entry.exit): player.position = entry.exit
	climbing_id = -1
	player.velocity = Vector3.ZERO
	_message("已离开梯架；重力仍会把你带回落脚面。")

func _find_structure(id: int) -> Dictionary:
	for entry in structures:
		if entry.id == id: return entry
	return {}

func reclaim_structure(id: int) -> bool:
	var entry := _find_structure(id)
	if entry.is_empty(): return false
	if climbing_id == id:
		_message("先离开正在攀爬的梯架，再回收。" ); return false
	var feet := player.position-Vector3(0,FEET_OFFSET,0)
	var contact := Geometry3D.get_closest_point_to_segment(feet,entry.start,entry.end)
	if contact.distance_to(feet) < maxf(0.75,entry.width*0.6):
		_message("先走到另一块支撑上，再回收脚下造物。" ); return false
	ink.black = minf(MAX_BLACK_INK,ink.black+entry.cost)
	entry.node.queue_free(); structures.erase(entry)
	_message("画稿仍在手中！回收 %.1f 黑墨，直接点下一座台沿再摆放。" % entry.cost)
	_update_hud(); return true

func reclaim_nearest() -> void:
	if selected_color == "yellow" and weapon:
		reclaim_weapon(); return
	var nearest: Dictionary = {}
	var distance := 8.0
	for entry in structures:
		var d: float = player.position.distance_to(entry.start)
		if d < distance: distance = d; nearest = entry
	if nearest.is_empty(): _message("附近没有可回收的造物。")
	else: reclaim_structure(nearest.id)

func reclaim_weapon() -> bool:
	if not weapon: return false
	if weapon.swinging:
		_message("等这次挥砍结束，再回收墨刃。" ); return false
	ink.yellow = minf(MAX_YELLOW_INK,ink.yellow+weapon.analysis.cost)
	weapon.queue_free(); weapon = null; saved_tools.erase("yellow")
	if selected_color == "yellow": active_tool = {}
	actor.brush.show(); _message("墨刃回到黄墨瓶；画稿仍在画纸上。" ); _update_hud()
	return true

func interact() -> void:
	var feet := player.position-Vector3(0,FEET_OFFSET,0)
	var fountain_distance := 1.4
	for fountain in fountains:
		var distance: float = feet.distance_to(fountain)
		fountain_distance = minf(fountain_distance,distance)
	var ladder_distance := INF
	for entry in structures:
		if entry.climbable: ladder_distance = minf(ladder_distance,feet.distance_to(entry.start))
	# E chooses the nearest actual interaction, so a fountain cannot swallow
	# input beside a ladder foot; standing at the fountain still replenishes ink.
	if ladder_distance < fountain_distance and try_climb(): return
	if fountain_distance < 1.4:
		ink.black = MAX_BLACK_INK
		if yellow_unlocked: ink.yellow = MAX_YELLOW_INK
		_message("墨泉补满了黑墨和黄墨；你随时可以再试。" if yellow_unlocked else "墨泉补满了黑墨；你随时可以再试。")
		Audio.play(self,850); _update_hud(); return
	if not try_climb(): _message("靠近梯架底端按 E；墨泉旁按 E 补墨。")

func collect_goals() -> void:
	var feet := player.position-Vector3(0,FEET_OFFSET,0)
	for i in goals.size():
		if not goals[i] and feet.distance_to(goal_positions[i]) < 0.75:
			goals[i] = true; goal_nodes[i].hide()
			Audio.play(self,880+i*120)
			_message(["第一张到手！站稳台面后 Z 回收，再用同一画稿去中庭。","第二张到手！Z 回收返还黑墨，同一作品再登书塔。","三张齐了，小庭院完成！"][i])
	if not won and goals.all(func(value): return value):
		won = true
		result_open = true; result_panel.show()
		result_label.text = "小庭院的三张画页，都回来了。\n\n同一份画稿可以回收、再摆放。\n笔迹留在手中，黑墨回到瓶里。\n\n继续探索，或重新画一条路。"
		buttons["continue"].text = "继续逛小庭院"
	if yellow_unlocked and not final_goal_collected and feet.distance_to(landmark_positions.yellow_goal) < 0.75:
		final_goal_collected = true; won = true; final_goal_node.hide()
		result_open = true; result_panel.show(); buttons["continue"].text = "继续在画页里走"
		result_label.text = "最后的画页，回来了。\n\n%s\n\n路是你画出来的。" % ("墨刃切开了藤蔓，笔迹留在手中。" if vines_cut else "黑墨搭过了藤庭，笔迹成为道路。")
		Audio.play(self,1320)
	_update_hud()

func collect_words() -> void:
	var feet := player.position-Vector3(0,FEET_OFFSET,0)
	for entry in word_pickups:
		if entry.word == "Sharp" and not yellow_unlocked: continue
		if not entry.collected and feet.distance_to(entry.pos) < 0.9:
			entry.collected = true; entry.node.hide(); words.append(entry.word)
			_message("拾到了%s：%s" % [{"Sticky":"黏性","Elastic":"弹性","Sharp":"锋利"}[entry.word],PROPERTY_TEXT[entry.word]])
			Audio.play(self,740); _update_hud()

func reset_run() -> void:
	for entry in structures: entry.node.queue_free()
	structures.clear(); active_tool.clear(); saved_tools.clear(); draw_pad.clear_drawing()
	if weapon: weapon.queue_free(); weapon = null
	actor.brush.show()
	goals = [false,false,false]
	for node in goal_nodes: node.show()
	for entry in word_pickups: entry.collected = false; entry.node.show()
	words = ["None"]; ink = {"black":MAX_BLACK_INK,"yellow":0.0}
	selected_property = "None"; selected_color = "black"; selected_kind = "ladder"
	yellow_unlocked = false; won = false; result_open = false; result_panel.hide()
	final_goal_collected = false; final_goal_node.show()
	vines_cut = false; vine_body.collision_layer = 5; vine_visual.show()
	enemy_hp = ENEMY_MAX_HP; enemy_body.collision_layer = 4; enemy_body.position = Vector3(33.6,0.35,0)
	enemy_state = "idle"; enemy_timer = 0; enemy_flash = 0; enemy_actor.pose("idle"); enemy_actor.scale = Vector3.ONE
	player_hp = MAX_HP; player_invulnerability = 0
	climbing_id = -1; climb_up_guard = false; notebook_open = false; notebook_panel.hide()
	player.position = Vector3(0,FEET_OFFSET,0); player.velocity = Vector3.ZERO; safe_point = player.position
	draw_pad.ink_color = Color("263844"); draw_pad.queue_redraw()
	_message("画纸和墨瓶准备好了。拿到高台上的碎页。")
	_update_hud()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme := Theme.new()
	theme.default_font = ReadableFont; theme.default_font_size = 16
	ui.theme = theme
	var hud := _panel(ui,Vector2(16,12),Vector2(635,78))
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_label = _label(hud,"",Vector2(14,10),Vector2(610,24),18)
	objective_label = _label(hud,"拿到高台上的碎页。",Vector2(14,41),Vector2(610,24),17)
	_button(ui,"画纸 · Tab",Vector2(766,14),Vector2(178,38),toggle_notebook,"notebook")
	_button(ui,"重开 · R",Vector2(828,58),Vector2(116,30),reset_run,"restart")
	footer_panel = _panel(ui,Vector2(12,438),Vector2(936,92))
	footer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label = _label(ui,"",Vector2(24,476),Vector2(910,48),17)
	message_label.add_theme_color_override("font_color",Color("263e43"))
	keyboard_help = _label(ui,"WASD 移动 · Space 跳/离梯 · E 攀爬/补墨 · Z/Q 回收 · 同一画稿反复摆放",Vector2(22,447),Vector2(860,26),14)
	notebook_panel = _panel(ui,Vector2(90,15),Vector2(780,510))
	notebook_panel.hide()
	_label(notebook_panel,"绘本 / 保留每一笔",Vector2(24,14),Vector2(350,30),23)
	_button(notebook_panel,"关闭 · Tab",Vector2(626,14),Vector2(130,32),toggle_notebook,"close")
	_button(notebook_panel,"梯架",Vector2(24,62),Vector2(112,38),func(): select_kind("ladder"),"ladder")
	_button(notebook_panel,"板面 / 坡道",Vector2(144,62),Vector2(142,38),func(): select_kind("board"),"board")
	_button(notebook_panel,"墨刃",Vector2(294,62),Vector2(86,38),func(): select_kind("blade"),"blade")
	_button(notebook_panel,"● 黑墨",Vector2(402,62),Vector2(106,38),func(): select_color("black"),"color_black")
	_button(notebook_panel,"● 黄墨 · 锁",Vector2(516,62),Vector2(130,38),func(): select_color("yellow"),"color_yellow")
	buttons.blade.disabled = true
	buttons.color_yellow.disabled = true
	draw_pad = SketchPad.new()
	draw_pad.position = Vector2(24,118); draw_pad.size = Vector2(540,300)
	notebook_panel.add_child(draw_pad)
	draw_pad.stroke_changed.connect(_update_estimate)
	_label(notebook_panel,"一个词条",Vector2(586,118),Vector2(170,26),18)
	var property_titles := {"None":"无词条","Sticky":"黏性","Elastic":"弹性 × 1.4","Sharp":"锋利 · 黄墨"}
	var row := 0
	for property in ["None","Sticky","Elastic","Sharp"]:
		_button(notebook_panel,property_titles[property],Vector2(586,151+row*44),Vector2(170,36),func(): select_property(property),"property_"+property)
		row += 1
	notebook_help = _label(notebook_panel,"",Vector2(586,334),Vector2(175,145),14)
	_button(notebook_panel,"撤销末笔 · Z",Vector2(24,435),Vector2(150,36),draw_pad.undo_stroke,"undo")
	_button(notebook_panel,"清空画纸",Vector2(184,435),Vector2(126,36),draw_pad.clear_drawing,"clear")
	_button(notebook_panel,"保存画稿",Vector2(330,435),Vector2(234,36),apply_drawing,"confirm")
	estimate_label = _label(notebook_panel,"",Vector2(24,478),Vector2(730,26),14)
	intro_panel = _panel(ui,Vector2(170,70),Vector2(620,400))
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture = Portrait; portrait.position = Vector2(26,42); portrait.size = Vector2(232,290)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_panel.add_child(portrait)
	_label(intro_panel,"墨迹漂流",Vector2(280,30),Vector2(315,46),30)
	_label(intro_panel,"画页散了。\n还好，笔还在。",Vector2(280,100),Vector2(310,90),24)
	_label(intro_panel,"在小庭院找回三张画页。\n\n画一件作品，保存一次。\n站稳台面后 Z 回收，直接再摆放。\n同一作品可以反复用！",Vector2(280,208),Vector2(314,110),16)
	_button(intro_panel,"带上画纸",Vector2(280,332),Vector2(310,44),begin_adventure,"begin")
	result_panel = _panel(ui,Vector2(230,92),Vector2(500,350))
	result_panel.hide()
	result_label = _label(result_panel,"",Vector2(30,24),Vector2(440,230),21)
	_button(result_panel,"继续在画页里走",Vector2(30,280),Vector2(240,44),close_result,"continue")
	_button(result_panel,"重新画一条路",Vector2(286,280),Vector2(185,44),reset_run,"result_restart")
	touch_controls = TouchControls.new()
	ui.add_child(touch_controls)
	touch_controls.action_requested.connect(_touch_action)
	touch_controls.world_tapped.connect(_touch_world)
	touch_controls.touch_detected.connect(_enable_touch_layout)
	_update_estimate()

func _panel(parent: Node, pos: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos; panel.size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4e8ce")
	style.border_color = Color("3d5357")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel",style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	return panel

func _label(parent: Node, value: String, pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value; label.position = pos; label.size = dimensions
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("263e43"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, pos: Vector2, dimensions: Vector2, action: Callable, id: String) -> Button:
	var button := Button.new()
	button.text = text; button.position = pos; button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size",15)
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e5d3b2") if state == "normal" else (Color("d0b98f") if state in ["hover","pressed"] else Color("dbd3c4"))
		style.border_color = Color("526464"); style.set_border_width_all(1); style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state,style)
		button.add_theme_color_override("font_color" if state == "normal" else "font_"+state+"_color",Color("263e43") if state != "disabled" else Color("8d9187"))
	parent.add_child(button)
	button.pressed.connect(action)
	buttons[id] = button
	return button

func begin_adventure() -> void:
	intro_open = false; intro_panel.hide()
	_message("Tab 画一件作品并保存；登台取页，站稳后 Z 回收，同一画稿继续搭下一台。")
	_update_hud()

func toggle_notebook() -> void:
	if intro_open or result_open: return
	notebook_open = not notebook_open
	notebook_panel.visible = notebook_open
	if not notebook_open: draw_pad.end_stroke()
	_update_estimate(); _update_hud()

func close_result() -> void:
	result_open = false; result_panel.hide()
	if yellow_unlocked and not won: _message("向右下书塔，到藤根旁拾锋利。Tab 选黄墨画刃，或继续用黑墨搭路。")

func select_kind(kind: String) -> void:
	if kind not in ["ladder","board","blade"]: return
	if kind == "blade" and (not yellow_unlocked or selected_color != "yellow"): return
	if kind != "blade" and selected_color != "black": return
	selected_kind = kind
	_update_estimate(); _update_hud()

func select_color(color: String) -> void:
	if color not in ["black","yellow"]: return
	if color == "yellow" and not yellow_unlocked: return
	selected_color = color
	selected_kind = "blade" if color == "yellow" else saved_tools.get("black",{}).get("kind","ladder")
	active_tool = saved_tools.get(color,{}).duplicate(true)
	if selected_property == "Sticky" and color == "yellow" or selected_property == "Sharp" and color == "black": selected_property = "None"
	if weapon:
		weapon.visible = color == "yellow"
		if color == "black": weapon.cancel_swing()
	actor.brush.visible = color == "black" or not weapon
	draw_pad.ink_color = Color("263844") if color == "black" else Color("bd913d")
	draw_pad.queue_redraw(); _update_estimate(); _update_hud()

func select_property(property: String) -> void:
	if property not in words: return
	if property == "Sticky" and selected_color == "yellow" or property == "Sharp" and selected_color == "black": return
	selected_property = property
	_update_estimate(); _update_hud()

func _update_estimate() -> void:
	if not draw_pad or not estimate_label: return
	drawing_analysis = Rules.analyze(draw_pad.get_strokes(),selected_kind,selected_property)
	if drawing_analysis.ok:
		estimate_label.text = "实测 %.2f × %.2f 米 · %s墨 %.1f · %s" % [drawing_analysis.length,drawing_analysis.width,"黄" if selected_color == "yellow" else "黑",drawing_analysis.cost,PROPERTY_TEXT[selected_property]]
	else: estimate_label.text = drawing_analysis.reason

func _message(value: String) -> void:
	if message_label: message_label.text = value

func _update_hud() -> void:
	if not hud_label: return
	if touch_controls: touch_controls.set_gameplay_enabled(not intro_open and not notebook_open and not result_open)
	var count := 0
	for goal in goals:
		if goal: count += 1
	hud_label.text = "墨迹漂流   黑墨 %.0f / %.0f   画页 %d / 3" % [ink.black,MAX_BLACK_INK,count]
	if yellow_unlocked: hud_label.text += "   黄墨 %.0f   生命 %d/%d" % [ink.yellow,player_hp,MAX_HP]
	objective_label.text = "拿到高台上的碎页。" if not goals[0] else ("到对岸去。" if not goals[1] else ("登上书塔，找回画页。" if not goals[2] else ("路是你画出来的。" if won else "穿过藤庭，拾起最后的画页。")))
	for property in ["None","Sticky","Elastic","Sharp"]:
		if buttons.has("property_"+property):
			buttons["property_"+property].disabled = property not in words or (property == "Sticky" and selected_color == "yellow") or (property == "Sharp" and selected_color == "black")
			buttons["property_"+property].modulate = Color("c5e0cd") if selected_property == property else Color.WHITE
	if buttons.has("color_yellow"):
		buttons.color_yellow.disabled = not yellow_unlocked
		buttons.color_yellow.text = "● 黄墨" if yellow_unlocked else "● 黄墨 · 锁"
	for kind in ["ladder","board","blade"]:
		if buttons.has(kind):
			buttons[kind].disabled = (kind == "blade" and (not yellow_unlocked or selected_color != "yellow")) or (kind != "blade" and selected_color != "black")
			buttons[kind].modulate = Color("c5e0cd") if selected_kind == kind else Color.WHITE
	for color in ["black","yellow"]: buttons["color_"+color].modulate = Color("f1d483") if selected_color == color else Color.WHITE
	if notebook_help:
		notebook_help.text = "墨刃：画剑、斧或你的笔迹。\n每一段都是实际刃身。\n\n保存后握在手中。\n左键 / F 挥砍，Q 回收。\n每 100 px = 1.4 米。" if selected_color == "yellow" else "梯架：两条长梁，\n两根横档接上两侧。\n\n板面：画出闭合轮廓。\n每 100 px = 1.4 米。"

func _point_array(value: Vector3) -> Array:
	return [snappedf(value.x,0.001),snappedf(value.y,0.001),snappedf(value.z,0.001)]

func _screen_array(value: Vector3) -> Array:
	var point := cam.unproject_position(value)
	return [snappedf(point.x,0.1),snappedf(point.y,0.1)]

func qa_snapshot() -> Dictionary:
	# JSON aliases: kind strings ladder/board/blade; property names exactly match UI.
	# All button values are viewport pixel centres; draw_rect is [x,y,width,height].
	var button_snapshot := {}
	for id in buttons:
		var rect: Rect2 = buttons[id].get_global_rect()
		button_snapshot[id] = [rect.get_center().x,rect.get_center().y]
	var drawn: Array = []
	var vertices := 0
	for stroke in draw_pad.get_strokes():
		var points: Array = []
		for point in stroke: points.append([point.x,point.y])
		drawn.append(points); vertices += points.size()
	var landmarks := {}
	for title in landmark_positions:
		landmarks[title] = {"pos":_point_array(landmark_positions[title]),"ground_screen":_screen_array(landmark_positions[title])}
	for i in fountains.size():
		landmarks["fountain_"+str(i)] = {"pos":_point_array(fountains[i]),"ground_screen":_screen_array(fountains[i])}
	for entry in word_pickups:
		landmarks["word_"+entry.word] = {"pos":_point_array(entry.pos),"ground_screen":_screen_array(entry.pos)}
	var structure_snapshot := []
	for entry in structures:
		structure_snapshot.append({"id":entry.id,"kind":entry.kind,"length":entry.length,"start":_point_array(entry.start),"end":_point_array(entry.end),"cost":entry.cost,"reachable":entry.reachable,"climbable":entry.climbable,"property":entry.property,"required":entry.required,"exit":_point_array(entry.exit),"ground_screen":_screen_array(entry.start)})
	var rect: Rect2 = draw_pad.get_global_rect()
	var analysis_snapshot := {"ok":drawing_analysis.get("ok",false),"reason":drawing_analysis.get("reason",""),"length":drawing_analysis.get("length",0.0),"width":drawing_analysis.get("width",0.0),"cost":drawing_analysis.get("cost",0.0)}
	var tool := {"kind":active_tool.get("kind",""),"color":active_tool.get("color","black"),"property":active_tool.get("property","None"),"length":active_tool.get("length",0.0),"width":active_tool.get("width",0.0),"segments":[]}
	for segment in active_tool.get("segments",[]): tool.segments.append([[segment[0].x,segment[0].y],[segment[1].x,segment[1].y]])
	var preview_snapshot := {"ok":preview_data.get("ok",false),"reachable":preview_data.get("reachable",false),"reason":preview_data.get("reason",""),"required":preview_data.get("required",0.0),"start":_point_array(preview_data.get("start",Vector3.ZERO)),"end":_point_array(preview_data.get("end",Vector3.ZERO))}
	var blade_snapshot := {"equipped":weapon != null,"visible":weapon.visible if weapon else false,"length":weapon.analysis.length if weapon else 0,"width":weapon.analysis.width if weapon else 0,"property":weapon.analysis.property if weapon else "None","segments":[],"swinging":weapon.swinging if weapon else false,"swing":weapon.swing_number if weapon else 0,"cooldown":weapon.cooldown if weapon else 0}
	if weapon:
		for segment in weapon.world_segments(): blade_snapshot.segments.append([_point_array(segment[0]),_point_array(segment[1])])
	return {"version":10,"player":_point_array(player.position),"facing":_point_array(facing),"climbing_id":climbing_id,"climb_progress":climb_progress,"preview":preview_snapshot,"ui":{"intro":intro_open,"notebook":notebook_open,"message":message_label.text,"result":result_open,"result_text":result_label.text,"selected_kind":selected_kind,"selected_color":selected_color,"selected_property":selected_property,"buttons":button_snapshot,"draw_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]},"drawing":{"strokes":drawn,"vertices":vertices,"analysis":analysis_snapshot},"active_tool":tool,"ink":ink.duplicate(),"words":words.duplicate(),"structures":structure_snapshot,"landmarks":landmarks,"goals":goals.duplicate(),"won":won,"yellow_unlocked":yellow_unlocked,"weapon":blade_snapshot,"combat":{"hp":player_hp,"max_hp":MAX_HP,"invulnerability":player_invulnerability},"vines":{"cut":vines_cut,"pos":_point_array(landmark_positions.vines),"collision":vine_body.collision_layer},"enemy":{"pos":_point_array(enemy_body.position),"hp":enemy_hp,"max_hp":ENEMY_MAX_HP,"alive":enemy_hp > 0,"state":enemy_state,"timer":enemy_timer,"ground_screen":_screen_array(enemy_body.position)},"final_goal":{"collected":final_goal_collected,"pos":_point_array(landmark_positions.yellow_goal)}}
