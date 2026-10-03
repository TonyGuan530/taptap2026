extends SceneTree
## telemetry 面板探针：验证 _on_tel_panel 能在真实节点树中建出 TelPanel，
## 以及 CanvasLayer 查找方式是否可靠（web 端按钮点击无反应的排查）。
## 运行：godot --headless --path game -s res://tests/probe_tel.gd

func _init() -> void:
	_run()

func _run() -> void:
	var f := FileAccess.open("user://telpanel_log.txt", FileAccess.WRITE)
	await process_frame
	var scene = load("res://demo06_inkwords.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var ui_direct = scene.get_children().filter(func(c): return c is CanvasLayer)
	var ui_find = scene.get_tree().root.find_child("CanvasLayer", true, false)
	scene._on_tel_panel()
	await process_frame
	await process_frame
	var panel_exists := false
	for c in scene.get_children().filter(func(c): return c is CanvasLayer):
		if c.has_node("TelPanel"):
			panel_exists = true
	var lines := [
		"canvaslayer_direct=%d" % ui_direct.size(),
		"canvaslayer_names=" + ",".join(ui_direct.map(func(c): return c.name)),
		"find_child_hit=%s" % str(ui_find != null),
		"telpanel_after_open=%s" % str(panel_exists),
		"events=%d json_len=%d" % [scene.tel_events.size(), scene.tel_export_json().length()],
	]
	for l in lines:
		print(l)
		f.store_string(l + "\n")
	f.flush()
	quit()
