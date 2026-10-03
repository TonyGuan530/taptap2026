extends Node2D
## demo-02 v7 上板素材驱动：第五关（自由实验场）路线A——弹簧→羽毛横漂+一次扑翼→漂上高台入 GOAL
## 运行：godot --path game --write-movie <绝对路径>/f.png --fixed-fps 30 --quit-after 400 res://tests/movie_demo02.tscn

var game: Node2D
var shot_saved := false
var launched := false


func _ready() -> void:
	game = load("res://demo02_physics.tscn").instantiate()
	add_child(game)


func _physics_process(_delta: float) -> void:
	if game == null:
		return
	if game.level_idx != 4:
		game._load_level(4)
		game._on_tag(0)   # 羽毛开局
		return
	if game.goal_reached and not shot_saved:
		shot_saved = true
		_take_shot()
		return
	if game.ball == null:
		return
	var v: Vector2 = game.ball.linear_velocity
	if not launched and v.y <= -400.0:
		launched = true
		Input.action_press("ui_right")   # 弹簧点火后按住→横漂
	if launched:
		if v.y > 60.0 and game.ball.position.x < 560.0 and not game.flap_used:
			game._try_jump()             # 掉高度就扑翼（滞空限一次）


func _take_shot() -> void:
	var img := get_viewport().get_texture().get_image()
	var out: String = ProjectSettings.globalize_path("res://") + "../reviews/shots/demo-02.png"
	img.save_png(out)
	print("SHOT_SAVED: ", out)
