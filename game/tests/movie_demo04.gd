extends Node2D
## demo-04 v8 上板素材驱动：机器人连通 5 关全程录制（Movie Maker 离线渲染）
## 运行：godot --path game --write-movie <帧目录>/f.png --fixed-fps 30 res://tests/movie_demo04.tscn
## 注：Movie 模式下 parse_input_event 分发不可靠，直接操纵 game.keys 状态（demo-02 驱动同款直调风格）。

var game: Node2D
var jump_cd := 0


func _ready() -> void:
	game = load("res://demo04_soup.tscn").instantiate()
	add_child(game)


func _ground_ahead(x: float) -> bool:
	for b in game.blocks:
		if b[0] <= x and b[0] + b[2] >= x and b[1] >= 440 and b[1] <= 500:
			return true
	return false


func _wall_ahead() -> bool:
	for b in game.blocks:
		if b[0] > game.px + 6 and b[0] < game.px + 84 and b[1] < game.py - 6:
			return true
	return false


func _physics_process(_delta: float) -> void:
	if game == null:
		return
	if game.state == "win":
		if game.level_idx >= game.LEVELS.size() - 1:
			get_tree().quit()   # 5 关全通，录制结束
			return
		game._advance()
		return
	game.keys[KEY_RIGHT] = true
	for a in game.aliens:
		if not game.dna.has(a.id) and absf(game.px - a.x) < 55.0:
			game._try_fuse()
	jump_cd = maxi(0, jump_cd - 1)
	if jump_cd > 0:
		game.keys[KEY_SPACE] = false   # 释放上一拍
		return
	if game.on_floor:
		if (not _ground_ahead(game.px + 50.0)) or (not _ground_ahead(game.px + 110.0)) or _wall_ahead():
			game.keys[KEY_SPACE] = true   # 本拍按下 → 边沿触发起跳；下拍自动释放
			jump_cd = 3
	elif game.dna.has("double") and game.jumps_used == 1 and game.vy > -40.0:
		game.keys[KEY_SPACE] = true
		jump_cd = 6
