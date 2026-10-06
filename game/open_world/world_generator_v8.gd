extends "res://open_world/world_generator.gd"
## Art-only extension. Heights, protected routes, deterministic candidates and IDs are inherited.
const NATURAL_PALETTE := [Color("78958a"),Color("718a61"),Color("9ba873"),Color("baa17a"),Color("959a8d")]
const PIGMENT_PALETTE := [Color("78aaa6"),Color("78a18b"),Color("a1b48b"),Color("c2b28b"),Color("a3abb0")]
func biome_weights_at(x: float, z: float) -> PackedFloat32Array:
	var value := climate.get_noise_2d(x,z)
	# Adjacent overlapping transition bands form a partition of unity, not chunk tints.
	var wet := smoothstep(-.41,-.19,value)
	var forest := smoothstep(-.18,.04,value)
	var meadow := smoothstep(.05,.27,value)
	var highland := smoothstep(.23,.45,value)
	return PackedFloat32Array([1-wet,wet-forest,forest-meadow,meadow-highland,highland])
func color_at(x: float, z: float) -> Color:
	var palette: Array = PIGMENT_PALETTE if profile == "ink" else NATURAL_PALETTE
	var weights := biome_weights_at(x,z)
	var result := Color(0,0,0,1)
	for index in weights.size():
		result.r += palette[index].r*weights[index]
		result.g += palette[index].g*weights[index]
		result.b += palette[index].b*weights[index]
	# Coverage is sampled at the same absolute point, so quiet soil patches cross chunk edges.
	var soil := Color("c1b18d") if profile == "dino" else Color("d0c2a2")
	var dry := smoothstep(-.5,.5,coverage.get_noise_2d(x,z))*.095
	result = result.lerp(soil,dry)
	return result.lerp(soil,clampf((height_at(x,z)-2)/22,0,.12))
func normal_at(x: float, z: float) -> Vector3:
	# The same central stencil on both sides includes the neighboring chunk's height samples.
	const DELTA := .5
	return Vector3(height_at(x-DELTA,z)-height_at(x+DELTA,z),2*DELTA,height_at(x,z-DELTA)-height_at(x,z+DELTA)).normalized()
