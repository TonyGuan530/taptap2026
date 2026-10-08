extends "res://demo09_3d.gd"
## Review entry: keep migration rules intact, expose garage and rigid driving.
func _ready() -> void:
	auto_start=false
	use_rigid=true
	state_changed.connect(func(next: String):print("REVIEW09|state|"+next))
	super._ready()
	_fit_panel(menu_panel,Vector2(160,86),Vector2(640,430),true)
	_fit_panel(garage_panel,Vector2(560,16),Vector2(380,500),true)
	_fit_panel(settle_panel,Vector2(210,140),Vector2(540,260),false)
	_fit_panel(final_panel,Vector2(210,140),Vector2(540,280),false)

func _fit_panel(panel: PanelContainer, at: Vector2, dimensions: Vector2, scrollable: bool) -> void:
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position=at
	panel.custom_minimum_size=dimensions
	var content=panel.get_node("VB")
	for child in content.get_children():
		if child is Label: child.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if scrollable:
		panel.remove_child(content)
		var scroll:=ScrollContainer.new()
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size=dimensions
		panel.add_child(scroll)
		content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		scroll.add_child(content)
	# Reparenting changes minimum size on the next layout pass.
	panel.set_deferred("size",dimensions)

var _review_ticks:=0
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_review_ticks+=1
	if state=="drive" and rigid!=null and _review_ticks%60==0:
		print("REVIEW09|drive|pos=%s|speed=%.1f|grounded=%d"%[rigid.position,rigid.linear_velocity.length(),rigid.grounded_wheels])
