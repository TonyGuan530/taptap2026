extends RefCounted
## Deterministic chunk descriptions, independent of visitation and loading order.
const CHUNK_SIZE := 48.0
const GRID_STEP := 4.0
const BIOME_NAMES := {"grassland":"草甸","forest":"密林","wetland":"湿地","mesa":"高原","ashland":"灰岩荒地"}
const COLORS := {"grassland":Color("7ca879"),"forest":Color("50785b"),"wetland":Color("649b9d"),"mesa":Color("bd9d6d"),"ashland":Color("7c8285")}
var seed_value := 20261006
var profile := "dino"
var densities := {"resources":1.0,"enemies":1.0,"events":1.0,"decoration":1.0}
var elevation := FastNoiseLite.new()
var climate := FastNoiseLite.new()
var coverage := FastNoiseLite.new()
func configure(value: int, kind: String, settings: Dictionary = {}) -> void:
	seed_value = value
	profile = "ink" if kind == "ink" else "dino"
	for key in densities: densities[key] = clampf(float(settings.get(key,1.0)),0.0,1.8)
	elevation.seed = int(value % 2147483647)
	elevation.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elevation.frequency = 0.018
	elevation.fractal_octaves = 3
	climate.seed = int((value+39019) % 2147483647)
	climate.frequency = 0.0075
	climate.fractal_octaves = 2
	coverage.seed = int((value+91271) % 2147483647)
	coverage.frequency = 0.035
	coverage.fractal_octaves = 2
func protected_rects() -> Array[Rect2]:
	if profile == "ink": return [Rect2(0,0,28,14)]
	return [Rect2(-27,-24,54,56),Rect2(-9,20,18,13.5)]
func near_core(x: float, z: float, margin := 0.0) -> bool:
	for rect: Rect2 in protected_rects():
		if rect.grow(margin).has_point(Vector2(x,z)): return true
	return false
func _core_distance(x: float, z: float) -> float:
	var distance := INF
	for rect: Rect2 in protected_rects():
		var dx := maxf(maxf(rect.position.x-x,x-rect.end.x),0)
		var dz := maxf(maxf(rect.position.y-z,z-rect.end.y),0)
		distance = minf(distance,Vector2(dx,dz).length())
	return distance
func biome_at(x: float, z: float) -> String:
	var value := climate.get_noise_2d(x,z)
	if value < -0.30: return "wetland"
	if value < -0.07: return "forest"
	if value < 0.16: return "grassland"
	if value < 0.34: return "mesa"
	return "ashland"
func _raw_height(x: float, z: float) -> float:
	# Smooth low slopes, with elevated resource biomes rather than impassable noise spikes.
	var high := smoothstep(0.08,0.42,climate.get_noise_2d(x,z))*5.5
	return 1.5+elevation.get_noise_2d(x,z)*2.8+high
func height_at(x: float, z: float) -> float:
	# A deterministic 24m lattice leaves gentle flat clearings for event fixtures.
	var px := floorf(x/24)*24+12
	var pz := floorf(z/24)*24+12
	var radius := Vector2(x-px,z-pz).length()
	var value := lerpf(_raw_height(px,pz),_raw_height(x,z),smoothstep(6,11,radius))
	return value*smoothstep(2,18,_core_distance(x,z))
func color_at(x: float, z: float) -> Color:
	var color: Color = COLORS[biome_at(x,z)]
	return color.lerp(Color("e0d7ab"),clampf((height_at(x,z)-2)/16,0,.3))
func _rng(coord: Vector2i, salt: int) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = (seed_value*104729+int(coord.x)*73856093+int(coord.y)*19349663+salt*83492791) & 0x7fffffffffffffff
	return result
func _feature(coord: Vector2i, kind: String, index: int, x: float, z: float) -> Dictionary:
	return {"id":"%d:%d:%s:%d" % [coord.x,coord.y,kind,index],"kind":kind,"pos":Vector3(x,height_at(coord.x*48+x,coord.y*48+z),z)}
func describe(coord: Vector2i) -> Dictionary:
	var biome := biome_at(coord.x*48,coord.y*48)
	var features: Array[Dictionary] = []
	var event_centers: Array[Vector2] = []
	var rng := _rng(coord,11)
	for index in 4:
		var x := -12.0 if index%2 == 0 else 12.0
		var z := -12.0 if index/2 == 0 else 12.0
		var chance := rng.randf()
		var variant := rng.randi_range(0,2)
		if profile != "ink" or chance > .34*densities.events or near_core(coord.x*48+x,coord.y*48+z,9): continue
		var feature := _feature(coord,["pull","weight","vines"][variant],index,x,z)
		feature.variant = variant
		features.append(feature)
		event_centers.append(Vector2(x,z))
	var lush := clampf((coverage.get_noise_2d(coord.x*48,coord.y*48)+.8)/1.3,.15,1.0)
	var multiplier := {"forest":1.4,"grassland":1.0,"wetland":.85,"mesa":.6,"ashland":.35}[biome] as float
	rng = _rng(coord,24)
	for index in 36:
		var x := -20+(index%6)*8+rng.randf_range(-1.1,1.1)
		var z := -20+(index/6)*8+rng.randf_range(-1.1,1.1)
		var roll := rng.randf()
		var kind := "decor_rock" if rng.randf() > .76*multiplier else "decor_tree"
		var variant := rng.randi_range(0,4)
		if roll > .52*lush*multiplier*densities.decoration or not _clear(coord,x,z,event_centers,7): continue
		var feature := _feature(coord,kind,index,x,z)
		feature.variant = variant
		features.append(feature)
	rng = _rng(coord,37)
	for index in 12:
		var x := -20+(index%4)*12+rng.randf_range(-1.5,1.5)
		var z := -18+(index/4)*16+rng.randf_range(-1.5,1.5)
		var chance := rng.randf()
		var item := rng.randi_range(0,6)
		var amount := rng.randi_range(6,18)
		var word: String = ["Sticky","Magnetic","Elastic","Float","Sharp","Heavy"][rng.randi_range(0,5)]
		if chance > .56*(.55+lush)*densities.resources or not _clear(coord,x,z,event_centers,7): continue
		var kind: String = "scroll" if profile == "ink" else _resource(biome,item)
		var feature := _feature(coord,kind,index,x,z)
		feature.amount = amount
		feature.word = word
		features.append(feature)
	rng = _rng(coord,49)
	for index in 2:
		var x := rng.randf_range(-18,18)
		var z := rng.randf_range(-18,18)
		var chance := rng.randf()
		if chance > .32*densities.enemies or near_core(coord.x*48+x,coord.y*48+z,20) or not _clear(coord,x,z,event_centers,8): continue
		var kind := "enemy" if profile == "ink" else "predator"
		features.append(_feature(coord,kind,index,x,z))
	# Recovery/friendly landmarks remain available at zero enemy density.
	rng = _rng(coord,63)
	var x := rng.randf_range(-18,18); var z := rng.randf_range(-18,18)
	if rng.randf() < .58*(densities.events if profile == "dino" else 1.0) and _clear(coord,x,z,event_centers,7):
		features.append(_feature(coord,"fountain" if profile == "ink" else "grazer",0,x,z))
	return {"coord":coord,"biome":biome,"biome_name":BIOME_NAMES[biome],"features":features}
func _clear(coord: Vector2i, x: float, z: float, events: Array[Vector2], margin: float) -> bool:
	if near_core(coord.x*48+x,coord.y*48+z,4): return false
	for point: Vector2 in events:
		if point.distance_to(Vector2(x,z)) < margin: return false
	return true
func _resource(biome: String, index: int) -> String:
	var pool: Array = {"forest":["wood","food","wood","water","copper","magnet","food"],"grassland":["food","wood","copper","water","magnet","quartz","coal"],"wetland":["water","food","wood","copper","water","magnet","coal"],"mesa":["quartz","copper","magnet","coal","wood","food","water"],"ashland":["coal","magnet","copper","quartz","food","water","wood"]}[biome]
	return pool[index]
