extends SceneTree
func _init() -> void:
	_run()
func _run() -> void:
	await process_frame
	# 用户指令：不弹窗——窗口最小化后台渲染
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var scene: Control = load("res://demo05_volcano.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	scene.end_style = 1
	scene.result = "partial"
	scene.margin = 2
	scene.supply = {food = 1, water = 1}
	scene._log_ev("族群选择了东线·沿河：快，但可能遇泥流改道。")
	scene._log_ev("寒夜如萨满所预言地降临，族群又耗掉了 1 份水取暖。")
	scene._log_ev("次日余震震裂了森林的地面，四分之一的储备陷进了裂缝。")
	scene._log_ev("迁徙兽群路过森林，叼走 1 份储备，但族群猎杀了落单的巨兽——多了 2 份兽肉。")
	scene._show_end()
	for k in 30:
		await physics_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("res://../reviews/shots/demo-05-ending.png")
	print("SAVED ", img.get_width(), "x", img.get_height())
	quit()
