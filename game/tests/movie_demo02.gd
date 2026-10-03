extends Node2D
## demo-02 v3 上板素材驱动：跑一局第三关「组合测试房」的完整组合链
## （弹簧起飞 → 羽毛横漂+扑翼 → 石头砸穿脆舱顶入舱），通关瞬间定格截图。
## 运行：godot --path game --write-movie <绝对路径>/f.png --fixed-fps 30 --quit-after 430 res://tests/movie_demo02.tscn

var game: Node2D
var shot_saved := false
var launched := false
var switched := false


func _ready() -> void:
	game = load("res://demo02_physics.tscn").instantiate()
	add_child(game)


func _physics_process(_delta: float) -> void:
	if game == null:
		return
	if game.level_idx != 2:
		game._load_level(2)
		game._on_tag(0)   # 羽毛开局
		return
	if game.goal_reached:
		if not shot_saved:
			shot_saved = true
			_take_shot()
		return
	if game.ball == null:
		return
	var v: Vector2 = game.ball.linear_velocity
	if not launched and v.y <= -400.0:
		launched = true
		Input.action_press("ui_right")   # 弹簧点火后按住→横漂
	if launched and not switched:
		if v.y > 80.0 and game.ball.position.x < 720.0:
			game._try_jump()             # 掉高度就扑翼续航
		if game.ball.position.x >= 720.0 and game.ball.position.y < 230.0:
			switched = true
			Input.action_release("ui_right")
			game._on_tag(1)              # 舱顶上方切石头，砸穿舱门


func _take_shot() -> void:
	var img := get_viewport().get_texture().get_image()
	var out: String = ProjectSettings.globalize_path("res://") + "../reviews/shots/demo-02.png"
	img.save_png(out)
	print("SHOT_SAVED: ", out)
