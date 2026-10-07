extends RefCounted
## Editable crease features in original material coordinates. Preview is atomic.
const Geometry = preload("res://demo08_3d/paper_geometry.gd")
var paper = Geometry.new()
var features: Array = []
var base_recipe: Array = []
var ratio := 0.7
var selected := -1
var transaction: Dictionary = {}
var undo_states: Array = []
var redo_states: Array = []
var message := ""

func _state() -> Dictionary:
	return {"features":features.duplicate(true),"base":base_recipe.duplicate(true),"ratio":ratio,"selected":selected}

func _restore(state: Dictionary) -> void:
	features=state.features.duplicate(true); base_recipe=state.base.duplicate(true)
	ratio=state.ratio; selected=state.selected
	_replay()

func reset(value: float = 0.7) -> void:
	ratio=value; features.clear(); base_recipe.clear(); transaction.clear()
	undo_states.clear(); redo_states.clear(); selected=-1
	paper=Geometry.new(); paper.reset(ratio)

func new_sheet() -> void:
	if not transaction.is_empty(): cancel()
	var before := _state()
	features.clear(); base_recipe.clear(); selected=-1
	_replay(); undo_states.append(before); redo_states.clear()
	message="已换为空白纸；撤销可恢复上一张。"

static func _weights(point: Vector2,a: Vector2,b: Vector2,c: Vector2) -> Vector3:
	var denominator := (b-a).cross(c-a)
	if absf(denominator)<0.00000001: return Vector3(-1,-1,-1)
	var v := (point-a).cross(c-a)/denominator
	var w := (b-a).cross(point-a)/denominator
	return Vector3(1.0-v-w,v,w)

func material_to_world(face: int,point: Vector2) -> Vector3:
	var uv: PackedVector2Array = paper.material_faces[face]
	var poly: PackedVector3Array = paper.faces[face]
	for i in range(1,uv.size()-1):
		var weights := _weights(point,uv[0],uv[i],uv[i+1])
		if weights.x>=-0.00001 and weights.y>=-0.00001 and weights.z>=-0.00001:
			return poly[0]*weights.x+poly[i]*weights.y+poly[i+1]*weights.z
	return Vector3(INF,INF,INF)

func world_to_material(face: int,point: Vector3) -> Vector2:
	var poly: PackedVector3Array = paper.faces[face]
	var uv: PackedVector2Array = paper.material_faces[face]
	for i in range(1,poly.size()-1):
		var u: Vector3 = poly[i]-poly[0]
		var v: Vector3 = poly[i+1]-poly[0]
		var p: Vector3 = point-poly[0]
		var denominator: float = u.dot(u)*v.dot(v)-u.dot(v)*u.dot(v)
		if absf(denominator)<0.0000000001: continue
		var b: float = (p.dot(u)*v.dot(v)-p.dot(v)*u.dot(v))/denominator
		var c: float = (p.dot(v)*u.dot(u)-p.dot(u)*u.dot(v))/denominator
		if b>=-0.00001 and c>=-0.00001 and b+c<=1.00001:
			return uv[0]*(1-b-c)+uv[i]*b+uv[i+1]*c
	return Vector2(INF,INF)

func _replay() -> bool:
	var previous = paper
	paper=Geometry.new(); paper.reset(ratio)
	for base in base_recipe:
		if not paper.fold(base.a,base.b,base.angle): paper=previous; return false
	for feature in features:
		if feature.kind=="stack":
			if not paper.fold(feature.a,feature.b,feature.angle): paper=previous; return false
			continue
		var face := -1
		for i in paper.faces.size():
			if material_to_world(i,feature.seed).is_finite() and material_to_world(i,feature.a).is_finite() and material_to_world(i,feature.b).is_finite():
				face=i; break
		if face<0 or not paper.begin_face_fold(face,material_to_world(face,feature.a),material_to_world(face,feature.b)):
			paper=previous; return false
		if feature.flip:
			for i in paper.history.back().moves.size(): paper.history.back().moves[i]=not paper.history.back().moves[i]
		paper.set_last_angle(feature.angle)
	return true

func begin_crease(face: int,a: Vector3,b: Vector3) -> bool:
	if not transaction.is_empty() or features.size()>=8 or face<0 or face>=paper.faces.size() or not a.is_finite() or not b.is_finite(): return false
	var ua := world_to_material(face,a)
	var ub := world_to_material(face,b)
	if not ua.is_finite() or not ub.is_finite() or ua.distance_to(ub)<0.01: return false
	var seed := Vector2.ZERO
	for p in paper.material_faces[face]: seed+=p
	seed/=paper.material_faces[face].size()
	var before := _state()
	if not paper.begin_face_fold(face,a,b):
		message="这条折痕会锁住相邻纸片，请换一条或先撤销。"
		return false
	transaction=before
	features.append({"kind":"face","a":ua,"b":ub,"seed":seed,"flip":false,"angle":0.0})
	selected=features.size()-1
	message="拖动旋转手柄或角度滑条，确认后保留。"
	return true

func select_feature(index: int) -> bool:
	if index<0 or index>=features.size(): return false
	if not transaction.is_empty() and selected==index: return true
	if not transaction.is_empty(): cancel()
	if index<0 or index>=features.size(): return false
	transaction=_state(); selected=index
	message="正在调整折痕 %d；后面的折叠会一起跟随。" % (index+1)
	return true

func preview_angle(angle: float) -> bool:
	if transaction.is_empty() or selected<0 or selected>=features.size() or not is_finite(angle): return false
	var old: float = features[selected].angle
	features[selected].angle=clampf(angle,-PI,PI)
	if not _replay(): features[selected].angle=old; message="此角度无法保持纸面连接。"; return false
	return true

func flip_side() -> bool:
	if transaction.is_empty() or selected!=features.size()-1 or features[selected].kind!="face": return false
	features[selected].flip=not features[selected].flip
	features[selected].angle=-float(features[selected].angle)
	if _replay(): return true
	features[selected].flip=not features[selected].flip; features[selected].angle=-float(features[selected].angle)
	return false

func commit() -> bool:
	if transaction.is_empty(): return false
	undo_states.append(transaction.duplicate(true)); redo_states.clear(); transaction.clear()
	message="已确认折痕 %d；可从列表再次调整。" % (selected+1)
	return true

func cancel() -> void:
	if transaction.is_empty(): return
	var before := transaction.duplicate(true); transaction.clear(); _restore(before)
	message="已取消，纸张恢复到操作前。"

func undo() -> bool:
	if not transaction.is_empty(): cancel(); return true
	if undo_states.is_empty(): return false
	redo_states.append(_state()); _restore(undo_states.pop_back())
	return true

func redo() -> bool:
	if not transaction.is_empty() or redo_states.is_empty(): return false
	undo_states.append(_state()); _restore(redo_states.pop_back())
	return true

func load_dart() -> bool:
	if not transaction.is_empty(): cancel()
	var before := _state()
	var recipe: Array = paper.dart_recipe()
	base_recipe=recipe.slice(0,4)
	features=[{"kind":"stack","a":recipe[4].a,"b":recipe[4].b,"angle":recipe[4].angle}]
	selected=0
	if not _replay(): _restore(before); return false
	undo_states.append(before); redo_states.clear()
	message="已载入飞机起点，选中翼折痕可改变翼角。"
	return true

func selected_axis() -> Dictionary:
	if selected<0 or selected>=features.size(): return {}
	var current = paper
	# Find this feature's hinge in the state immediately before it, so descendants
	# cannot hide or move its control frame. Earlier hinges remain world-anchored.
	var feature: Dictionary = features[selected]
	if feature.kind=="stack":
		return {"origin":Vector3(feature.a.x,0,feature.a.y),"axis":Vector3(feature.b.x-feature.a.x,0,feature.b.y-feature.a.y).normalized(),"normal":Vector3.UP}
	var stored_features := features
	features=features.slice(0,selected)
	if not _replay(): features=stored_features; paper=current; return {}
	var frame: Dictionary = {}
	for i in paper.faces.size():
		var a := material_to_world(i,feature.a)
		var b := material_to_world(i,feature.b)
		if a.is_finite() and b.is_finite() and material_to_world(i,feature.seed).is_finite():
			frame={"origin":(a+b)*0.5,"axis":(b-a).normalized(),"normal":Geometry.polygon_normal(paper.faces[i])}; break
	features=stored_features; paper=current
	return frame
