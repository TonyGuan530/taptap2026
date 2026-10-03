extends Node2D
## demo-02 v6 上板素材驱动：第五关「高台弹跳」路线B——皮球零输入弹跳链
## （弹簧→地面反弹→雨棚弹跳→高台→GOAL，全程无输入的涌现路线），通关瞬间定格截图。
## 运行：godot --path game --write-movie <绝对路径>/f.png --fixed-fps 30 --quit-after 300 res://tests/movie_demo02.tscn

var game: Node2D
var shot_saved := false


func _ready() -> void:
	game = load("res://demo02_physics.tscn").instantiate()
	add_child(game)


func _physics_process(_delta: float) -> void:
	if game == null:
		return
	if game.level_idx != 4:
		game._load_level(4)
		game._on_tag(2)   # 皮球：零输入弹跳链路线
		return
	if game.goal_reached and not shot_saved:
		shot_saved = true
		_take_shot()


func _take_shot() -> void:
	var img := get_viewport().get_texture().get_image()
	var out: String = ProjectSettings.globalize_path("res://") + "../reviews/shots/demo-02.png"
	img.save_png(out)
	print("SHOT_SAVED: ", out)
