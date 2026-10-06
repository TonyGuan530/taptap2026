extends "res://v8/ink_world.gd"
## Presentation slice: V8's genuine geometry and contacts, authored papercraft art.
const Painter := preload("res://v9/painter.gd")
const DrawSheet := preload("res://v9/ink_draw_pad.gd")
const WaterInk := preload("res://v9/ink_water.gdshader")
const Inkling := preload("res://v9/inkling.gd")
const InkOutline := preload("res://v9/ink_outline.gdshader")
const FocusStream := preload("res://v9/world_stream.gd")
const Portrait := preload("res://v9/art/painter.png")
var status_detail: Label
var word_chips := {}
var feedback_flash: ColorRect
var flash_age := 2.0
var trail_age := 0.0
var finish_shown := false
var aim_mesh: MeshInstance3D
var aim_lines: ImmediateMesh
var aim_material: StandardMaterial3D
var aim_age := 0.0
var intro_panel: PanelContainer
var intro_open := true
const PROPERTIES := {"Sticky":"接触时黏住物体；端点和弯折决定够到哪里。","Elastic":"开放线伸长 50%，拉住远处的固定物。","Sharp":"锋利的笔迹能切开柔软阻碍、打散污墨。","Magnetic":"吸引铁物，作用于笔迹附近 0.9 米。","Float":"闭合轮廓在水面承载；画多大，能踩的范围就多大。","Heavy":"面积越大越沉；可以压住、顶开或挡住物体。"}

func _ready() -> void:
	super._ready()
	settings_open = false
	settings_panel.hide()
	exploration_label.hide()
	setting_buttons.settings.hide()
	_style_labels(world)
	_toast("走近地上的词条。Tab 打开画纸，把你的第一条线变成工具。")
	cam.position = player.position+Vector3(2.4,22,15)
	cam.look_at(player.position+Vector3(2.4,0,0))
	_update_hud()

func _build_environment() -> void:
	super._build_environment()
	cam.size = 15.8
	for child in get_children():
		if child is WorldEnvironment:
			child.environment.background_color = Color("b5c4bd")
			child.environment.ambient_light_color = Color("e2e8ef")
			child.environment.ambient_light_energy = 0.28
			child.environment.ambient_light_sky_contribution = 0.0
		if child is DirectionalLight3D:
			child.light_energy = 0.52
			child.light_color = Color("fff5e9")
			child.rotation_degrees = Vector3(-60,-30,0)

func _build_run() -> void:
	super._build_run()
	# Replace only appearance. Every gate and fence retains the verified collision.
	for child in world.get_children():
		if child is StaticBody3D and not child.get_meta("ink_aim_ground",false):
			var box_shape: BoxShape3D
			for visual in child.get_children():
				if visual is CollisionShape3D and visual.shape is BoxShape3D: box_shape = visual.shape
				if visual is MeshInstance3D:
					visual.hide()
					if child == lane_gate and visual.mesh is BoxMesh and visual.mesh.size.x < 0.25: visual.show()
			if box_shape and child not in [key_gate,vine_gate,lane_gate]:
				if absf(child.position.x-11.15)<0.02 or absf(child.position.x-20.0)<0.02:
					Low.box(child,box_shape.size,Vector3.ZERO,Color("d4c1a0"))
					for i in range(0,int(box_shape.size.z*2.0)):
						var slash := Low.box(child,Vector3(0.013,0.55,0.09),Vector3(-box_shape.size.x*0.51,0.15,-box_shape.size.z*0.45+float(i)*0.5),Color("597477"))
						slash.rotation.x = -0.5 if i%2 else 0.5
				elif child.position.x > 6.6 and child.position.x < 9.4 and child.position.z > 1.0 and child.position.z < 5.0:
					var along_z := box_shape.size.z > box_shape.size.x
					var span := box_shape.size.z if along_z else box_shape.size.x
					for i in range(int(span/0.35)+1):
						var offset := -span*0.5+float(i)*0.35
						Low.box(child,Vector3(0.055,box_shape.size.y,0.055),Vector3(0,0,offset) if along_z else Vector3(offset,0,0),Color("465965"))
		if child is Node3D and child.name in ["LowPolyTree","LowPolyTreeSmall","LowPolyBerry","LowPolyRock"]:
			child.hide()
	# Paper layers, broken wall caps, ink strokes and folded plants.
	Low.box(world,Vector3(11.9,0.10,13.9),Vector3(6,-0.085,7),Color("e9d9b9"))
	Low.box(world,Vector3(12.9,0.10,13.9),Vector3(21.5,-0.085,7),Color("e9d9b9"))
	for layer in 3:
		Low.box(world,Vector3(11.9,0.06,13.9),Vector3(6,-0.38-layer*0.11,7),Color("cdbb98").lightened(layer*0.035))
		Low.box(world,Vector3(12.9,0.06,13.9),Vector3(21.5,-0.38-layer*0.11,7),Color("cdbb98").lightened(layer*0.035))
	for z in [0.0,14.0]:
		for x in range(1,28,2):
			if x > 11 and x < 16: continue
			_paper_rock(Vector3(x,0,z),Vector3(1.8,0.5+fmod(float(x)*0.37,1.1),0.6))
	for z in range(1,14,2): _paper_rock(Vector3(28,0,z),Vector3(0.6,0.8,1.7))
	for x in [6.7,9.3]:
		for z in [1.3,3.0,4.7]:
			_column(Vector3(x,0,z),1.9)
		Low.box(world,Vector3(0.10,0.08,3.55),Vector3(x,1.85,3),Color("334854"))
	for z in [1.2,4.8]: Low.box(world,Vector3(2.65,0.08,0.10),Vector3(8,1.85,z),Color("334854"))
	for z in [1.0,3.4,5.1,9.0,11.0,13.0]:
		_column(Vector3(11.15,0,z),1.6 if z in [5.1,9.0] else 1.1)
		_paper_rock(Vector3(20,0,z),Vector3(0.50,1.5,1.6))
	_arch(Vector3(11.15,0,7),PI/2,2.65,2.4)
	_arch(Vector3(25,0,7.4),0,3.4,2.5)
	Low.box(world,Vector3(3.9,0.12,3.3),Vector3(25,-0.01,7.1),Color("ead3a8"))
	for i in 3: Low.box(world,Vector3(3.2-i*0.30,0.11,0.38),Vector3(25,0.04+i*0.02,5.4+i*0.27),Color("f3e4c3"))
	Low.box(world,Vector3(2.2,0.035,2.1),Vector3(25,0.075,7),Color("d3bf99"))
	Low.box(world,Vector3(1.35,1.40,0.035),Vector3(25,1.1,8.25),Color("fff0ce"))
	for i in 6:
		var mark := Low.box(world,Vector3(0.04,0.48,0.04),Vector3(24.55+i*0.16,1.1+sin(float(i))*0.15,8.21),Color("365761"))
		mark.rotation.z = sin(float(i)*2)*0.6
	for entry in [[1.2,1.3],[4.7,1.1],[5.5,12.7],[10.1,12.8],[17.3,1.1],[23.8,1.0],[26.8,12.6],[17.0,12.4],[27.0,8.7]]:
		_fold_tree(Vector3(entry[0],0,entry[1]),1.5+fmod(float(entry[0]),1.3))
	for i in 38:
		var x := fmod(float(i)*5.73,27.0)+0.4
		var z := 0.7 if i%2==0 else 13.0
		if x > 11 and x < 16: continue
		_fold_plant(Vector3(x,0,z),0.32+fmod(float(i)*0.23,0.35))
	for x in [3.0,5.0,8.5,10.0,16.5,18.0,22.0,24.0]:
		for z in [6.3,7.5]:
			Low.box(world,Vector3(0.75,0.025,0.42),Vector3(x,0.016,z),Color("dbc7a4"))
	# Animated blue ink water, with sparse pale ripple marks.
	for child in world.get_children():
		if child is MeshInstance3D and absf(child.position.x-13.5)<0.1 and child.position.y < -0.4:
			var water_material := ShaderMaterial.new()
			water_material.shader = WaterInk
			child.material_override = water_material
	for z in [1.0,3.0,5.0,9.0,11.5,13.0]:
		Low.box(world,Vector3(0.65,0.018,0.04),Vector3(13.4,-0.38,z),Color("83bbb6"))
	# Golden key silhouette replaces the unrelated scroll visual.
	for child in key_node.get_children(): child.hide()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.13
	ring.outer_radius = 0.21
	var ring_node := Low.mesh(key_node,ring,Vector3(0,0.45,0),Color("dfae57"),true)
	ring_node.rotation.x = PI/2
	Low.box(key_node,Vector3(0.10,0.56,0.10),Vector3(0,0.03,0),Color("dfae57"))
	Low.box(key_node,Vector3(0.20,0.10,0.10),Vector3(0.07,-0.15,0),Color("dfae57"))
	var old_actor := actor
	player.remove_child(old_actor)
	old_actor.queue_free()
	actor = Painter.new()
	actor.position.y = -0.575
	player.add_child(actor)
	# Small ink creatures fit the same world and keep the original combat rules.
	for enemy in enemies:
		var old: Node3D = enemy.art
		old.hide()
		var inkling := Inkling.new()
		inkling.position.y = -0.55
		enemy.node.add_child(inkling)
		enemy.art = inkling
		inkling.modulate = Color("416b75")
		if int(enemy.index) == 0:
			enemy.node.position = Vector3(17.9,0.6,4.8)
			enemy.home = enemy.node.position
	for child in world.get_children():
		if child.name == "LowPolyPlate": child.hide()
	Low.cylinder(world,0.44,0.49,0.08,Vector3(8,0.045,9),Color("b8986e"))
	Low.cylinder(world,0.33,0.33,0.015,Vector3(8,0.092,9),Color("426c71"))
	aim_mesh = MeshInstance3D.new()
	aim_lines = ImmediateMesh.new()
	aim_mesh.mesh = aim_lines
	aim_material = StandardMaterial3D.new()
	aim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aim_mesh.material_override = aim_material
	world.add_child(aim_mesh)
	_grade_art(world)
	_outline_children(world)
	finish_shown = false

func _grade_art(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			if not child.get_meta("v9_graded",false):
				child.material_override.albedo_color = child.material_override.albedo_color.srgb_to_linear()
				child.set_meta("v9_graded",true)
		_grade_art(child)

func _outline_children(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.visible:
			if child.mesh is BoxMesh and child.mesh.size.x > 8: continue
			if child.material_override is ShaderMaterial: continue
			var outline := ShaderMaterial.new()
			outline.shader = InkOutline
			child.material_overlay = outline
		_outline_children(child)

func _paper_rock(pos: Vector3, dimensions: Vector3) -> void:
	var rock := Low.cylinder(world,0.68,0.8,1.0,pos+Vector3(0,dimensions.y*0.5,0),Color("e3d2b0"))
	rock.scale = dimensions
	rock.rotation.y = fmod(pos.x*1.7+pos.z,TAU)
	Low.box(world,Vector3(dimensions.x*0.5,0.018,0.06),pos+Vector3(0,dimensions.y+0.02,0),Color("a18d70"))

func _column(pos: Vector3, height_value: float) -> void:
	Low.box(world,Vector3(0.48,0.18,0.48),pos+Vector3(0,0.09,0),Color("c9b58e"))
	Low.cylinder(world,0.16,0.21,height_value,pos+Vector3(0,height_value*0.5,0),Color("f0dfba"))
	Low.box(world,Vector3(0.38,0.10,0.38),pos+Vector3(0,height_value,0),Color("f5e8c8"))

func _arch(pos: Vector3, angle: float, width_value: float, height_value: float) -> void:
	var arch := Node3D.new()
	arch.position = pos
	arch.rotation.y = angle
	world.add_child(arch)
	for x in [-width_value*0.5,width_value*0.5]:
		Low.box(arch,Vector3(0.42,height_value,0.5),Vector3(x,height_value*0.5,0),Color("f1dfbb"))
		Low.box(arch,Vector3(0.57,0.17,0.65),Vector3(x,0.09,0),Color("cbb891"))
	Low.box(arch,Vector3(width_value+0.5,0.35,0.5),Vector3(0,height_value,0),Color("e4cfaa"))
	Low.box(arch,Vector3(0.60,0.30,0.65),Vector3(0,height_value-0.1,0),Color("f9eacb"))
	var banner := Low.box(arch,Vector3(0.34,1.4,0.04),Vector3(width_value*0.5-0.05,height_value-0.45,0.30),Color("334b5b"))
	banner.rotation.z = -0.05

func _fold_tree(pos: Vector3, height_value: float) -> void:
	Low.cylinder(world,0.06,0.10,height_value*0.7,pos+Vector3(0,height_value*0.35,0),Color("6f6960"))
	for i in 3:
		var leaf := Low.cylinder(world,0.0,0.6-float(i)*0.1,height_value*0.7,pos+Vector3(0,height_value*0.56+float(i)*0.35,0),Color("3c5961") if i%2==0 else Color("527173"))
		leaf.scale.z = 0.43
		leaf.rotation.y = float(i)*1.0+pos.x
	_fold_plant(pos+Vector3(0.45,0,0.2),0.55)

func _fold_plant(pos: Vector3, height_value: float) -> void:
	for i in 3:
		var leaf := Low.cylinder(world,0.0,0.21,height_value,pos+Vector3((float(i)-1)*0.13,height_value*0.43,0),Color("d38a7b") if i%2 else Color("e1aa8b"))
		leaf.scale.z = 0.22
		leaf.rotation.z = (float(i)-1)*0.42
		leaf.rotation.y = pos.x*0.7+float(i)*0.35

func _build_stream() -> void:
	stream = FocusStream.new()
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
	last_safe_position = player.position
	for chunk in stream.get_children():
		var terrain := chunk.get_node_or_null("LowPolyTerrain") as MeshInstance3D
		if terrain: terrain.material_override = Low.material(Color("c7bb9f"))
	# The showcase ground uses one quiet paper color. Terrain physics stays untouched.
	for child in world.get_children():
		if child is StaticBody3D and child.get_meta("ink_aim_ground",false):
			for mesh_node in child.get_children():
				if mesh_node is MeshInstance3D: mesh_node.material_override = Low.material(Color("e9d9b9").srgb_to_linear())

func _build_ui() -> void:
	super._build_ui()
	for child in hud.get_children():
		if child is ColorRect: child.color = Color("f5ecdbeF"); child.size.y = 66
		if child is Label and child not in [stats,objectives,narrative,word_list,toast_label]: child.hide()
	stats.position = Vector2(25,12)
	stats.size = Vector2(330,28)
	stats.add_theme_font_size_override("font_size",23)
	objectives.position = Vector2(25,452)
	objectives.size = Vector2(910,27)
	objectives.add_theme_font_size_override("font_size",18)
	narrative.position = Vector2(25,478)
	narrative.add_theme_font_size_override("font_size",13)
	word_list.position = Vector2(325,17)
	word_list.size = Vector2(460,24)
	word_list.add_theme_font_size_override("font_size",13)
	toast_label.position = Vector2(25,508)
	toast_label.size = Vector2(905,22)
	toast_label.add_theme_font_size_override("font_size",13)
	toast_label.add_theme_color_override("font_color",Color("52716f"))
	var bottom := ColorRect.new()
	bottom.position = Vector2(10,444)
	bottom.size = Vector2(940,92)
	bottom.color = Color("f5ecdbeF")
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)
	hud.move_child(bottom,1)
	for index in Rules.WORDS.size():
		var word: String = Rules.WORDS[index]
		var chip := _label(hud,Rules.NAMES[word],Vector2(26+index*77,44),Vector2(73,18),11)
		word_chips[word] = chip
	status_detail = _label(hud,"",Vector2(505,44),Vector2(430,18),11)
	qa_buttons.draw.text = "画工具  [Tab]"
	qa_buttons.draw.position = Vector2(803,12)
	notebook.position = Vector2(103,68)
	var sheet := draw_pad.get_parent()
	var old_pad := draw_pad
	sheet.remove_child(old_pad)
	old_pad.queue_free()
	draw_pad = DrawSheet.new()
	draw_pad.position = Vector2(19,101)
	draw_pad.size = Vector2(540,244)
	sheet.add_child(draw_pad)
	draw_pad.stroke_changed.connect(_preview_drawing)
	for child in sheet.get_children():
		if child is Label and child.position.y < 15: child.text = "你的形状，捡来的性质。"
	feedback_flash = ColorRect.new()
	feedback_flash.position = Vector2.ZERO
	feedback_flash.size = Vector2(960,540)
	feedback_flash.color = Color(0.4,0.8,0.7,0)
	feedback_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(feedback_flash)
	set_mode(false)
	intro_panel = PanelContainer.new()
	intro_panel.position = Vector2(190,142)
	intro_panel.size = Vector2(580,286)
	intro_panel.add_theme_stylebox_override("panel",_style(Color.WHITE))
	hud.add_child(intro_panel)
	var intro := Control.new()
	intro.custom_minimum_size = Vector2(570,278)
	intro_panel.add_child(intro)
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = Portrait
	portrait.position = Vector2(14,18)
	portrait.size = Vector2(160,240)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro.add_child(portrait)
	_label(intro,"先画歪一点。",Vector2(188,20),Vector2(360,34),26)
	var intro_text := _label(intro,"你醒在一本被冲散的绘本里。\n前方的画页，等一条你画出的路。\n\n拾起地上的字，画出形状。\n它能派上什么用场，由你决定。",Vector2(188,65),Vector2(350,138),16)
	intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qa_buttons.begin = _button(intro,"落笔，出发  [Enter]",Vector2(188,210),Vector2(350,38),_begin_adventure)

func _begin_adventure() -> void:
	intro_open = false
	intro_panel.hide()
	Audio.play(self,660,0.12)
	_toast("WASD 走近地上的词条。拾到后，Tab 打开你的画纸。")

func _physics_process(delta: float) -> void:
	if intro_open or result_panel.visible: return
	super._physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	if intro_open:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ENTER: _begin_adventure()
		return
	super._unhandled_input(event)

func _label(parent: Node,value: String,pos: Vector2,dimensions: Vector2,font_size: int) -> Label:
	var label := super._label(parent,value,pos,dimensions,font_size)
	label.add_theme_color_override("font_color",Color("2c424f"))
	return label

func _style(_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4ead5")
	style.border_color = Color("9b9e8c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0.1,0.2,0.23,0.22)
	style.shadow_size = 10
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _button(parent: Node,value: String,pos: Vector2,dimensions: Vector2,action: Callable) -> Button:
	var button := super._button(parent,value,pos,dimensions,action)
	button.add_theme_color_override("font_color",Color("294853"))
	button.add_theme_color_override("font_hover_color",Color("294853"))
	button.add_theme_color_override("font_pressed_color",Color("ffffff"))
	button.add_theme_color_override("font_disabled_color",Color("a9aaa2"))
	var normal := _style(Color.WHITE)
	normal.bg_color = Color("e3dac2")
	normal.shadow_size = 0
	button.add_theme_stylebox_override("normal",normal)
	var disabled := normal.duplicate()
	disabled.bg_color = Color("e8dfc8")
	button.add_theme_stylebox_override("disabled",disabled)
	button.add_theme_color_override("font_disabled_color",Color("8c9288"))
	var hover := normal.duplicate()
	hover.bg_color = Color("f5dfb9")
	hover.border_color = Color("de876b")
	button.add_theme_stylebox_override("hover",hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color("417c86")
	button.add_theme_stylebox_override("pressed",pressed)
	button.add_theme_stylebox_override("focus",hover)
	return button

func _update_hud() -> void:
	super._update_hud()
	if not stats: return
	stats.text = "墨迹漂流  /  INKBOUND"
	var action := "先拾取地上的词条"
	if not words.is_empty(): action = "取回围栏里的钥匙"
	if key_retrieved: action = "把一条过河的路画出来"
	if river_crossed: action = "进入庭院，找回失落画页"
	if hazard_passed: action = "走近画页，按 E 带回"
	if won: action = "你把路画了出来。试试另一种解法？"
	objectives.text = "%s   %s 钥匙   %s 渡河   %s 庭院" % [action,_tick(key_retrieved),_tick(river_crossed),_tick(hazard_passed)]
	narrative.text = "WASD 移动  ·  Tab 绘画  ·  右键用工具  ·  左键挥笔  ·  E 补墨 / 拾取  ·  Z 回收  ·  R 旋转"
	word_list.text = "当前：%s%s" % [Rules.NAMES[tool_word] if not tool_word.is_empty() else "还未落笔"," / 开放线" if blueprint.get("kind","")=="open" else (" / 闭合面" if blueprint.get("kind","")=="closed" else "")]
	if status_detail: status_detail.text = "墨 %d / 100     纸张 %d%%     %02d:%02d" % [ink,hp,int(clock)/60,int(clock)%60]
	for word in word_chips:
		word_chips[word].text = "%s %s" % ["●" if words.has(word) else "○",Rules.NAMES[word]]
		word_chips[word].add_theme_color_override("font_color",Rules.COLORS[word].darkened(0.40) if words.has(word) else Color("a7a592"))
	for word in word_buttons:
		word_buttons[word].modulate = Color.WHITE
		var selected: bool = word == selected_word
		var background := _style(Color.WHITE)
		background.shadow_size = 0
		background.bg_color = Rules.COLORS[word].lightened(0.38) if selected else Color("e3dac2")
		background.border_color = Color("42616c") if selected else Color("acaf9a")
		background.set_border_width_all(2 if selected else 1)
		word_buttons[word].add_theme_stylebox_override("normal",background)
	if draw_pad: draw_pad.pen_color = Rules.COLORS[selected_word].darkened(0.25); draw_pad.queue_redraw()
	if won and not finish_shown:
		finish_shown = true
		result_title.text = "这一页，是你画出来的。"
		result_text.text = "完成用时 %02d:%02d\n\n取回钥匙：%s\n渡过墨河：%s\n进入庭院：%s\n\n同一处难题，还能换一组形状和词条。" % [int(clock)/60,int(clock)%60,_route_text(key_route),_route_text(river_route),_route_text(hazard_route)]
		result_text.add_theme_font_size_override("font_size",14)
		result_text.size.y = 134
		Audio.play(self,1046,0.16)

func _preview_drawing() -> void:
	super._preview_drawing()
	if draw_pad: draw_pad.pen_color = Rules.COLORS[selected_word].darkened(0.25); draw_pad.queue_redraw()
	if word_hint: word_hint.text = PROPERTIES[selected_word]

func _style_labels(node: Node) -> void:
	for child in node.get_children():
		if child is Label3D:
			child.font_size = 26
			child.pixel_size = 0.007
			child.outline_size = 4
			child.no_depth_test = false
			child.hide()
		else: _style_labels(child)

func _update_nearby_hints() -> void:
	if not is_instance_valid(player): return
	var nearest: Label3D
	var distance := 3.0
	for child in world.get_children():
		if not child is Label3D: continue
		child.hide()
		if child.get_meta("hint_disabled",false): continue
		var current := _xz(child.position).distance_to(_xz(player.position))
		if current < distance:
			distance = current
			nearest = child
	if nearest and not notebook_open: nearest.show()

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	var focus := player.position+Vector3(2.4,0,0)
	cam.position = focus+Vector3(11,19,14)
	cam.look_at(focus)
	_update_nearby_hints()
	if clock > path_until and stroke_node and stroke_node.get_child_count() > 0:
		for child in stroke_node.get_children(): child.queue_free()
	_publish_qa()
	flash_age += delta
	if feedback_flash: feedback_flash.color.a = maxf(0,0.08-flash_age*0.35)
	trail_age += delta
	aim_age += delta
	if aim_age > 0.07:
		aim_age = 0
		_update_aim_preview()
	if not notebook_open and player.velocity.length() > 0.6 and trail_age > 0.22:
		trail_age = 0
		var dot := Low.cylinder(world,0.035,0.055,0.008,Vector3(player.position.x,0.028,player.position.z),Color("78928b"))
		var tween := create_tween()
		tween.tween_interval(2.0)
		tween.tween_property(dot,"scale",Vector3.ZERO,1.0)
		tween.tween_callback(dot.queue_free)

func _update_aim_preview() -> void:
	if not is_instance_valid(aim_mesh): return
	aim_lines.clear_surfaces()
	if blueprint.is_empty() or notebook_open or settings_open or dead or result_panel.visible: return
	var target := _mouse_world(get_viewport().get_mouse_position())
	var points := PackedVector2Array()
	var open: bool = blueprint.get("kind","") == "open"
	if open:
		points = Rules.world_path(blueprint,_xz(player.position),_xz(target)-_xz(player.position),tool_word)
	else:
		for point: Vector2 in blueprint.polygon: points.append(point.rotated(-draw_rotation)+_xz(target))
		if not points.is_empty(): points.append(points[0])
	var color: Color = Rules.COLORS[tool_word]
	if not open and _xz(target).distance_to(_xz(player.position)) > 4.3: color = Color("d27162")
	color.a = 0.75
	aim_material.albedo_color = color
	aim_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(1,points.size()):
		for point: Vector2 in [points[i-1],points[i]]:
			aim_lines.surface_add_vertex(Vector3(point.x,_ground_y(Vector3(point.x,0,point.y))+0.035,point.y))
	aim_lines.surface_end()

func apply_drawing() -> bool:
	var result := super.apply_drawing()
	if result: Audio.play(self,660+Rules.WORDS.find(tool_word)*55,0.12)
	return result

func interact() -> void:
	super.interact()
	if last_message.contains("墨泉补满"):
		hp = mini(100,hp+35)
		_toast("墨泉补满，也修补了纸张。放心换一组形状和词条试试。")
		_update_hud()

func _draw_stroke(path: PackedVector2Array) -> void:
	super._draw_stroke(path)
	path_until = clock+0.95
	if not path.is_empty():
		var tip := Low.cylinder(stroke_node,0.16,0.16,0.045,Vector3(path[-1].x,_ground_y(Vector3(path[-1].x,0,path[-1].y))+0.72,path[-1].y),Rules.COLORS[tool_word],true)
		create_tween().tween_property(tip,"scale",Vector3.ONE*0.35,0.5)

func use_tool(target: Vector3) -> bool:
	var result := super.use_tool(target)
	if result: flash_age = 0
	return result

func _profile_path() -> String:
	return "user://v9_ink_profile_%d.json"%seed_value

func _publish_qa() -> void:
	super._publish_qa()
	if qa_enabled and browser_window != null:
		browser_window.__v8_ink_qa.version = 9
		browser_window.__v8_ink_qa.ui.intro = intro_open
		browser_window.__v9_ink_qa = browser_window.__v8_ink_qa
