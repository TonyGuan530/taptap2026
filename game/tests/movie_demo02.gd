extends Node2D
## demo-02 v4 上板素材驱动：第四关「开放解法房」路线B 完整演绎
## （弹簧起飞 → 羽毛横漂+一次扑翼 → 高窗口切石头弹道砸穿脆板入舱），通关瞬间定格截图。
## 运行：godot --path game --write-movie <绝对路径>/f.png --fixed-fps 30 --quit-after 500 res://tests/movie_demo02.tscn

var game: Node2D
var shot_saved := false
var launched := false
var switched := false
var flapped := false


func _ready() -> void:
	game = load("res://demo02_physics.tscn").instantiate()
	add_child(game)


func _physics_process(_delta: float) -> void:
	if game == null:
		return
	if game.level_idx != 3:
		game._load_level(3)
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
		if v.y > 60.0 and game.ball.position.x < 560.0 and not game.flap_used:
			game._try_jump()             # 掉高度就扑翼（滞空限一次）
			flapped = true
		if game.ball.position.x >= 590.0 and game.ball.position.x <= 630.0 and game.ball.position.y < 200.0:
			switched = true
			Input.action_release("ui_right")
			game._on_tag(1)              # 高窗口切石头，弹道砸穿脆板


func _take_shot() -> void:
	var img := get_viewport().get_texture().get_image()
	var out: String = ProjectSettings.globalize_path("res://") + "../reviews/shots/demo-02.png"
	img.save_png(out)
	print("SHOT_SAVED: ", out)
