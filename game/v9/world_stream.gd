extends "res://open_world/world_stream_v8.gd"
## Keep showcase saves separate from the historical V8 wilderness.
func configure(seed: int,profile: String,density: Dictionary = {}) -> bool:
	if not super.configure(seed,profile,density): return false
	save_root = "user://open_world_v9/%s_%d/chunks" % [generator.profile,seed]
	DirAccess.make_dir_recursive_absolute(save_root)
	return true
