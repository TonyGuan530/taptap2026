extends Control
## Modeling-style UI: explicit face/crease selection, screen dial, atomic edits.
signal geometry_changed
signal fly_requested
signal menu_requested
const Model = preload("res://demo08_3d/paper_model.gd")
const Geometry = preload("res://demo08_3d/paper_geometry.gd")
const FONT = preload("res://fonts/NotoSansSC.ttf")
var model = Model.new()
var view: TextureRect
var viewport: SubViewport
var camera: Camera3D
var paper_mesh: MeshInstance3D
var edge_mesh: MeshInstance3D
var history_list: ItemList
var angle_slider: HSlider
var angle_number: SpinBox
var apply_btn: Button
var cancel_btn: Button
var undo_btn: Button
var redo_btn: Button
var starter_btn: Button
var fly_btn: Button
var side_btn: Button
var info: Label
var step_label: Label
var new_btn: Button
var overlay: Control
var selected_face := -1
var hover_face := -1
var mode := "select"
var first_point := Vector3(INF,INF,INF)
var hover_point := Vector3(INF,INF,INF)
var snap_name := ""
var dial_dragging := false
var orbiting := false
var panning := false
var dial_previous := 0.0
var dial_angle := 0.0
var yaw := 0.65
var elevation := 0.75
var zoom := 0.46
var target := Vector3.ZERO
var syncing := false
var context := "自由折纸"
var button_theme: Theme

func _ready() -> void:
	position=Vector2.ZERO; size=Vector2(960,540); mouse_filter=MOUSE_FILTER_STOP
	_build_ui(); _build_view(); _refresh()
	visibility_changed.connect(func():
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
		if not visible: _stop_drag())

func _box(color: String,border: String="") -> StyleBoxFlat:
	var box := StyleBoxFlat.new(); box.bg_color=Color(color)
	box.set_corner_radius_all(5)
	if border!="": box.border_color=Color(border); box.set_border_width_all(1)
	return box

func _label(text: String,pos: Vector2,font_size: int=14,color: String="d4dbe6") -> Label:
	var label := Label.new(); label.text=text; label.position=pos
	label.add_theme_font_override("font",FONT); label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color(color)); label.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(label); return label

func _button(text: String,pos: Vector2,dimensions: Vector2,action: Callable) -> Button:
	var button := Button.new(); button.text=text; button.position=pos; button.size=dimensions
	button.theme=button_theme; button.focus_mode=Control.FOCUS_NONE
	button.pressed.connect(action); add_child(button); return button

func _build_ui() -> void:
	button_theme=Theme.new(); button_theme.default_font=FONT; button_theme.default_font_size=13
	button_theme.set_stylebox("normal","Button",_box("263243","3c4c61"))
	button_theme.set_stylebox("hover","Button",_box("35465c","7b92ad"))
	button_theme.set_stylebox("pressed","Button",_box("426386","92bdea"))
	button_theme.set_stylebox("disabled","Button",_box("202a37"))
	button_theme.set_color("font_color","Button",Color("e5ecf6"))
	button_theme.set_color("font_disabled_color","Button",Color("66788d"))
	var bg := ColorRect.new(); bg.color=Color("141b25"); bg.size=size; bg.mouse_filter=MOUSE_FILTER_IGNORE; add_child(bg)
	var left := ColorRect.new(); left.color=Color("1c2633"); left.size=Vector2(174,540); left.mouse_filter=MOUSE_FILTER_IGNORE; add_child(left)
	_label("折纸工作台",Vector2(16,16),21,"f1f4fa")
	_label("PAPER / 3D",Vector2(17,45),11,"7f99b6")
	_label("折痕历史",Vector2(14,86),14)
	_label("选中后可重新调节",Vector2(14,110),11,"8496ae")
	history_list=ItemList.new(); history_list.position=Vector2(10,137); history_list.size=Vector2(154,254)
	history_list.add_theme_font_override("font",FONT); history_list.add_theme_font_size_override("font_size",12)
	history_list.add_theme_stylebox_override("panel",_box("17202b"))
	history_list.add_theme_stylebox_override("selected",_box("395876"))
	history_list.add_theme_color_override("font_color",Color("d7e0ec")); history_list.fixed_icon_size=Vector2i(24,24)
	history_list.item_selected.connect(_select_feature); add_child(history_list)
	undo_btn=_button("撤销",Vector2(12,405),Vector2(71,32),_undo)
	redo_btn=_button("重做",Vector2(91,405),Vector2(71,32),_redo)
	_button("空白纸",Vector2(12,445),Vector2(150,32),_new_sheet)
	_button("选关 / 返回",Vector2(12,494),Vector2(150,32),func(): model.cancel();_stop_drag();menu_requested.emit())
	_button("选面",Vector2(190,14),Vector2(64,32),_select_mode)
	new_btn=_button("新折痕",Vector2(262,14),Vector2(78,32),start_crease)
	starter_btn=_button("飞机起点",Vector2(349,14),Vector2(96,32),_load_starter)
	_button("俯视",Vector2(455,14),Vector2(60,32),func(): yaw=0.0;elevation=PI/2-0.001;_update_camera())
	_button("侧视",Vector2(523,14),Vector2(60,32),func(): yaw=PI/2;elevation=0.08;_update_camera())
	_button("适配",Vector2(591,14),Vector2(60,32),_fit_view)
	_label("右键环绕 · 中键平移 · 滚轮缩放",Vector2(190,472),12,"8496ae")
	step_label=_label("",Vector2(190,502),13,"d4dfef")
	step_label.size=Vector2(546,32); step_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_label("折角",Vector2(769,80),18,"f0f3f8")
	angle_number=SpinBox.new(); angle_number.position=Vector2(768,111); angle_number.size=Vector2(174,36)
	angle_number.min_value=-180; angle_number.max_value=180; angle_number.step=1; angle_number.suffix="°"
	angle_number.theme=button_theme; angle_number.value_changed.connect(_angle_changed); add_child(angle_number)
	angle_slider=HSlider.new(); angle_slider.position=Vector2(770,158); angle_slider.size=Vector2(170,24)
	angle_slider.min_value=-180; angle_slider.max_value=180; angle_slider.step=1
	angle_slider.value_changed.connect(_angle_changed); add_child(angle_slider)
	_label("-180°",Vector2(768,184),10,"8496ae"); _label("0°",Vector2(849,184),10,"8496ae"); _label("180°",Vector2(910,184),10,"8496ae")
	for i in 4:
		var angle: float = [0,45,90,180][i]
		_button("%d°" % angle,Vector2(768+i*45,211),Vector2(40,30),func(): _angle_changed(angle))
	side_btn=_button("换活动侧",Vector2(768,253),Vector2(174,32),_flip_side)
	apply_btn=_button("确认",Vector2(768,302),Vector2(82,36),_apply)
	apply_btn.add_theme_stylebox_override("normal",_box("26765a","56a486"))
	cancel_btn=_button("取消",Vector2(860,302),Vector2(82,36),_cancel)
	info=_label("",Vector2(769,354),12,"aabbd0"); info.size=Vector2(173,110); info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	fly_btn=_button("完成 · 去试飞",Vector2(768,484),Vector2(174,42),_fly)
	fly_btn.add_theme_stylebox_override("normal",_box("416fba","779dda"))
	view=TextureRect.new(); view.position=Vector2(184,62); view.size=Vector2(560,396)
	view.stretch_mode=TextureRect.STRETCH_SCALE; view.mouse_filter=MOUSE_FILTER_STOP
	view.gui_input.connect(_view_input); add_child(view)
	overlay=Control.new(); overlay.position=view.position; overlay.size=view.size; overlay.mouse_filter=MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay); add_child(overlay)

func _build_view() -> void:
	viewport=SubViewport.new(); viewport.size=Vector2i(view.size); viewport.world_3d=World3D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(viewport); view.texture=viewport.get_texture()
	var environment := WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color("202c3a")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE; environment.environment.ambient_light_energy=0.6
	viewport.add_child(environment)
	var key_light := DirectionalLight3D.new(); key_light.rotation_degrees=Vector3(-50,-35,0)
	key_light.light_energy=0.8; key_light.shadow_enabled=true; viewport.add_child(key_light)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=zoom; camera.current=true
	viewport.add_child(camera)
	paper_mesh=MeshInstance3D.new()
	var shader := Shader.new()
	shader.code="shader_type spatial; render_mode cull_disabled; void fragment(){ NORMAL=FRONT_FACING ? NORMAL : -NORMAL; ALBEDO=FRONT_FACING ? COLOR.rgb : mix(COLOR.rgb,vec3(0.55,0.67,0.79),0.32); ROUGHNESS=0.9; }"
	var material := ShaderMaterial.new(); material.shader=shader; paper_mesh.material_override=material
	viewport.add_child(paper_mesh)
	edge_mesh=MeshInstance3D.new(); var edge_material := StandardMaterial3D.new()
	edge_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; edge_material.albedo_color=Color("8797aa")
	edge_mesh.material_override=edge_material; viewport.add_child(edge_mesh)
	var grid := MeshInstance3D.new(); var lines := ImmediateMesh.new(); lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-10,11):
		var coordinate: float = i*0.025
		lines.surface_add_vertex(Vector3(coordinate,-0.17,-0.25)); lines.surface_add_vertex(Vector3(coordinate,-0.17,0.25))
		lines.surface_add_vertex(Vector3(-0.25,-0.17,coordinate)); lines.surface_add_vertex(Vector3(0.25,-0.17,coordinate))
	lines.surface_end(); grid.mesh=lines
	var grid_material := StandardMaterial3D.new(); grid_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; grid_material.albedo_color=Color("344658")
	grid.material_override=grid_material; viewport.add_child(grid); _update_camera()
	var floor_mesh := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size=Vector2(0.6,0.6)
	floor_mesh.mesh=plane; floor_mesh.position.y=-0.171
	var floor_material := StandardMaterial3D.new(); floor_material.albedo_color=Color("243343"); floor_material.roughness=1.0
	floor_mesh.material_override=floor_material; viewport.add_child(floor_mesh)

func load_sheet(ratio: float,description: String="自由折纸") -> void:
	model.reset(ratio); context=description; selected_face=-1; mode="select"; first_point=Vector3(INF,INF,INF)
	_stop_drag(); _fit_view(); _changed()

func _update_camera() -> void:
	camera.size=zoom; camera.position=target+Vector3(sin(yaw)*cos(elevation),sin(elevation),cos(yaw)*cos(elevation))*0.8
	camera.look_at(target,Vector3.UP); overlay.queue_redraw()

func _fit_view() -> void:
	yaw=0.65; elevation=0.75; zoom=0.46; target=Vector3.ZERO
	if camera!=null: _update_camera()

func project(point: Vector3) -> Vector2:
	return camera.unproject_position(point)

func _ray(pos: Vector2) -> Dictionary:
	return {"origin":camera.project_ray_origin(pos),"direction":camera.project_ray_normal(pos)}

func _hit(pos: Vector2) -> Dictionary:
	var ray := _ray(pos); var distance := INF; var result := {}
	for fi in model.paper.faces.size():
		var face: PackedVector3Array = model.paper.faces[fi]
		for i in range(1,face.size()-1):
			var hit = Geometry3D.ray_intersects_triangle(ray.origin,ray.direction,face[0],face[i],face[i+1])
			if hit!=null and ray.origin.distance_to(hit)<distance:
				distance=ray.origin.distance_to(hit); result={"face":fi,"point":hit}
	return result

func _snap(hit: Dictionary,pos: Vector2) -> Vector3:
	snap_name=""
	var point: Vector3 = hit.point; var threshold := 12.0
	var face: PackedVector3Array = model.paper.faces[int(hit.face)]
	for i in face.size():
		for candidate in [face[i],face[i].lerp(face[(i+1)%face.size()],0.5)]:
			var distance: float = project(candidate).distance_to(pos)
			if distance<threshold:
				threshold=distance; point=candidate; snap_name="角点" if candidate==face[i] else "边中点"
	return point

func _edge_hit(pos: Vector2,hit: Dictionary) -> Dictionary:
	# A ray at an exact boundary can miss its triangle by floating-point error.
	# Screen snapping makes boundary handles selectable while respecting occlusion.
	if selected_face<0 or selected_face>=model.paper.faces.size(): return hit
	var poly: PackedVector3Array = model.paper.faces[selected_face]
	var ray := _ray(pos)
	var threshold := 12.0
	var result := hit
	for i in poly.size():
		for candidate in [poly[i],poly[i].lerp(poly[(i+1)%poly.size()],0.5)]:
			var distance: float = project(candidate).distance_to(pos)
			if distance>=threshold: continue
			if not hit.is_empty() and int(hit.face)!=selected_face and (candidate-hit.point).dot(ray.direction)>0.002: continue
			threshold=distance; result={"face":selected_face,"point":candidate}
	return result

func _select_mode() -> void:
	model.cancel(); _stop_drag(); mode="select"; first_point=Vector3(INF,INF,INF); _changed()

func start_crease() -> void:
	model.cancel(); _stop_drag(); mode="face"; selected_face=-1; first_point=Vector3(INF,INF,INF)
	model.message="先点选要折的纸面，再在同一面上点折痕两端。"; _changed()

func _view_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseMotion and not dial_dragging and not orbiting and not panning:
		var hit := _hit(event.position)
		hover_face=-1 if hit.is_empty() else int(hit.face)
		hover_point=Vector3(INF,INF,INF) if hit.is_empty() else _snap(hit,event.position)
		_rebuild_mesh(); overlay.queue_redraw()
	if not event is InputEventMouseButton or not event.pressed: return
	if event.button_index==MOUSE_BUTTON_RIGHT: orbiting=true; return
	if event.button_index==MOUSE_BUTTON_MIDDLE: panning=true; return
	if event.button_index==MOUSE_BUTTON_WHEEL_UP or event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
		zoom=clampf(zoom*(0.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),0.18,0.9); _update_camera(); return
	if event.button_index!=MOUSE_BUTTON_LEFT: return
	var pos: Vector2 = event.position
	if mode!="face" and mode!="points" and model.selected>=0 and absf(pos.distance_to(dial_center())-48)<15:
		if model.transaction.is_empty(): model.select_feature(model.selected)
		dial_dragging=true; dial_previous=atan2((pos-dial_center()).x,-(pos-dial_center()).y)
		dial_angle=float(model.features[model.selected].angle)
		_refresh(); return
	var hit := _hit(pos)
	if mode=="points": hit=_edge_hit(pos,hit)
	if hit.is_empty(): return
	if mode=="select" or mode=="face":
		selected_face=int(hit.face)
		if mode=="face": mode="points"; model.message="纸面已选中，点折痕起点（可吸附角点或边中点）。"
		else: model.selected=-1; model.message="纸面已选中；点「新折痕」开始折叠。"
		_changed(); return
	if mode=="points":
		if int(hit.face)!=selected_face: model.message="折痕两点需要在同一个已选纸面上。"; _refresh(); return
		var point := _snap(hit,pos)
		if not first_point.is_finite():
			first_point=point; model.message="再点折痕终点；橙色线是旋转轴。"; _refresh(); overlay.queue_redraw(); return
		if model.begin_crease(selected_face,first_point,point):
			mode="angle"; selected_face=-1; first_point=Vector3(INF,INF,INF)
			print("WORKBENCH|crease|%d" % model.features.size())
		else: model.message="折痕未建立：两点需相隔至少 1 厘米，并能保持纸面连接。"
		_changed()

func _input(event: InputEvent) -> void:
	if not visible: _stop_drag(); return
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT: dial_dragging=false
		if event.button_index==MOUSE_BUTTON_RIGHT: orbiting=false
		if event.button_index==MOUSE_BUTTON_MIDDLE: panning=false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE: _cancel(); get_viewport().set_input_as_handled()
		if event.ctrl_pressed and event.keycode==KEY_Z: _redo() if event.shift_pressed else _undo(); get_viewport().set_input_as_handled()
	if not event is InputEventMouseMotion: return
	if orbiting:
		yaw-=event.relative.x*0.01; elevation=clampf(elevation+event.relative.y*0.008,-1.45,1.55); _update_camera()
		get_viewport().set_input_as_handled()
	elif panning:
		target-=camera.global_basis.x*event.relative.x*zoom/396.0
		target+=camera.global_basis.y*event.relative.y*zoom/396.0; _update_camera(); get_viewport().set_input_as_handled()
	elif dial_dragging:
		var local: Vector2 = event.position-view.position
		var radial: Vector2 = local-dial_center()
		if radial.length()<12: return
		var raw := atan2(radial.x,-radial.y)
		dial_angle=clampf(dial_angle+wrapf(raw-dial_previous,-PI,PI),-PI,PI)
		var degrees: float = rad_to_deg(dial_angle)
		dial_previous=raw; _angle_changed(degrees); get_viewport().set_input_as_handled()

func _stop_drag() -> void:
	dial_dragging=false; orbiting=false; panning=false

func _angle_changed(degrees: float) -> void:
	if syncing or model.selected<0: return
	degrees=roundf(degrees)
	if model.transaction.is_empty(): model.select_feature(model.selected)
	if model.preview_angle(deg_to_rad(degrees)): print("WORKBENCH|angle|%d|%.1f" % [model.selected+1,degrees])
	mode="angle"; _changed()

func _select_feature(index: int) -> void:
	if model.select_feature(index):
		mode="angle"; selected_face=-1; first_point=Vector3(INF,INF,INF); _stop_drag(); _changed()

func _apply() -> void:
	if model.commit():
		mode="select"; _stop_drag(); print("WORKBENCH|commit|%d" % model.features.size()); _changed()

func _cancel() -> void:
	model.cancel(); mode="select"; first_point=Vector3(INF,INF,INF); selected_face=-1; _stop_drag(); _changed()

func _undo() -> void:
	if model.undo(): mode="select"; selected_face=-1; first_point=Vector3(INF,INF,INF); _stop_drag(); _changed(); print("WORKBENCH|undo|%d" % model.features.size())

func _redo() -> void:
	if model.redo(): mode="select"; selected_face=-1; _stop_drag(); _changed(); print("WORKBENCH|redo|%d" % model.features.size())

func _new_sheet() -> void:
	model.new_sheet(); selected_face=-1; mode="select"; _stop_drag(); first_point=Vector3(INF,INF,INF); _fit_view(); _changed()

func _load_starter() -> void:
	if model.load_dart():
		selected_face=-1; mode="select"; _stop_drag(); first_point=Vector3(INF,INF,INF); _fit_view(); _changed()
		print("WORKBENCH|starter|features=%d" % model.features.size())

func _flip_side() -> void:
	if model.transaction.is_empty() and model.selected>=0: model.select_feature(model.selected)
	if model.flip_side(): _changed()

func _fly() -> void:
	if not model.transaction.is_empty(): model.message="确认或取消当前折角后再试飞。"; _refresh(); return
	_stop_drag(); visible=false; fly_requested.emit()

func _changed() -> void:
	var angles:PackedStringArray=[]
	for feature in model.features: angles.append("%.1f" % rad_to_deg(float(feature.angle)))
	var lo:=INF;var hi:=-INF
	for face in model.paper.faces:
		for point in face: lo=minf(lo,point.y);hi=maxf(hi,point.y)
	print("WORKBENCH|model|angles=%s|pending=%s|height=%.5f" % [",".join(angles),not model.transaction.is_empty(),hi-lo])
	_rebuild_mesh(); _refresh(); overlay.queue_redraw(); geometry_changed.emit()

func _refresh() -> void:
	syncing=true
	var active: bool = model.selected>=0 and model.selected<model.features.size()
	var angle: float = rad_to_deg(float(model.features[model.selected].angle)) if active else 0.0
	angle_slider.value=angle; angle_number.value=angle
	angle_slider.editable=active; angle_number.editable=active
	apply_btn.disabled=model.transaction.is_empty(); cancel_btn.disabled=model.transaction.is_empty() and mode=="select"
	fly_btn.disabled=not model.transaction.is_empty()
	undo_btn.disabled=model.undo_states.is_empty() and model.transaction.is_empty(); redo_btn.disabled=model.redo_states.is_empty() or not model.transaction.is_empty()
	new_btn.disabled=model.features.size()>=8
	side_btn.disabled=not active or model.selected!=model.features.size()-1 or model.features[model.selected].kind!="face"
	history_list.clear()
	for i in model.features.size(): history_list.add_item("%02d  折痕   %+.0f°" % [i+1,rad_to_deg(float(model.features[i].angle))])
	if active: history_list.select(model.selected)
	info.text="%s\n纸面 %.0f cm² · %d 个折痕\n\n%s" % [context,model.paper.material_area()*10000.0,model.features.size(),("拖橙色圆环调角度；松手预览，确认后保留。" if active else "选面 → 新折痕 → 两点 → 调角 → 确认")]
	step_label.text=model.message if model.message!="" else "先选纸面，或载入飞机起点再调整。"
	syncing=false

func _active_face(fi: int) -> bool:
	if model.selected<0: return false
	var index: int = model.base_recipe.size()+model.selected
	if index>=model.paper.history.size(): return false
	var action: Dictionary = model.paper.history[index]
	var uv := Vector2.ZERO
	for p in model.paper.material_faces[fi]: uv+=p
	uv/=model.paper.material_faces[fi].size()
	for i in action.patterns.size():
		if action.moves[i] and Geometry2D.is_point_in_polygon(uv,action.patterns[i]): return true
	return false

func _rebuild_mesh() -> void:
	if paper_mesh==null: return
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines := ImmediateMesh.new(); lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for fi in model.paper.faces.size():
		var poly: PackedVector3Array = model.paper.faces[fi]
		var color := Color("f0e9db")
		if _active_face(fi) or fi==selected_face: color=Color("efbd68")
		elif fi==hover_face: color=Color("f6dba9")
		for i in range(1,poly.size()-1):
			for point in [poly[0],poly[i],poly[i+1]]:
				surface.set_color(color); surface.set_normal(Geometry.polygon_normal(poly)); surface.add_vertex(point)
		for i in poly.size(): lines.surface_add_vertex(poly[i]); lines.surface_add_vertex(poly[(i+1)%poly.size()])
	lines.surface_end(); paper_mesh.mesh=surface.commit(); edge_mesh.mesh=lines

func dial_center() -> Vector2:
	var frame: Dictionary = model.selected_axis()
	if frame.is_empty(): return view.size*0.5
	var point := project(frame.origin)
	return Vector2(clampf(point.x,64,view.size.x-64),clampf(point.y,64,view.size.y-64))

func _draw_overlay() -> void:
	var amber := Color("ffbf62")
	if first_point.is_finite():
		overlay.draw_circle(project(first_point),5,amber)
		if hover_point.is_finite() and hover_face==selected_face: overlay.draw_line(project(first_point),project(hover_point),amber,2,true)
	if hover_point.is_finite() and mode=="points":
		var p := project(hover_point)
		overlay.draw_circle(p,4,amber); overlay.draw_string(FONT,p+Vector2(8,-8),snap_name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,amber)
	var frame: Dictionary = model.selected_axis()
	if not frame.is_empty() and mode!="face" and mode!="points":
		var center := dial_center()
		var a := project(frame.origin-frame.axis*0.15); var b := project(frame.origin+frame.axis*0.15)
		overlay.draw_line(a,b,Color("f6a94d"),2,true)
		overlay.draw_arc(center,48,0,TAU,64,Color("f0aa52"),2,true)
		for i in 24:
			var angle: float = i*TAU/24
			var direction := Vector2(sin(angle),-cos(angle))
			overlay.draw_line(center+direction*43,center+direction*49,Color("ba854d"),1,true)
		var angle: float = float(model.features[model.selected].angle)
		var handle := center+Vector2(sin(angle),-cos(angle))*48
		overlay.draw_line(center,handle,amber,2,true); overlay.draw_circle(handle,7,amber)
		overlay.draw_circle(handle,3,Color("fff2d6")); overlay.draw_circle(center,3,amber)
		overlay.draw_string(FONT,center+Vector2(57,4),"%+.0f°" % rad_to_deg(angle),HORIZONTAL_ALIGNMENT_LEFT,-1,14,amber)
	# Orientation triad follows the camera, separate from modeling controls.
	var origin := Vector2(view.size.x-43,view.size.y-34)
	for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
		var direction := Vector2(camera.global_basis.x.dot(axis),-camera.global_basis.y.dot(axis))*22
		var color := Color("df7979") if axis==Vector3.RIGHT else (Color("83c69c") if axis==Vector3.UP else Color("86b1ef"))
		overlay.draw_line(origin,origin+direction,color,2,true)
