extends SceneTree
func _init() -> void:
	var tex: Texture2D = load("res://art/dino.png")
	print("tex=", tex, " size=", tex.get_size() if tex else "null")
	quit()
