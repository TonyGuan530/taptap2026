extends Node3D
## B4 幽灵回放视图：半透明轮廓按采样插值重放上一局轨迹。
## 无碰撞、只读、不影响悬挂/胜负/拾取（契约 §7）；材质为幽灵叠加层专用半透明（非车辆外观）。

const GarageModel := preload("res://demo09_3d/garage_model.gd")

var _samples: Array = []   # {t, pos, bx, by, bz}
var _t := 0.0
var _duration := 0.0


func load_samples(samples: Array) -> void:
	_samples = samples
	_t = 0.0
	_duration = float(samples[-1].t) if samples.size() > 0 else 0.0
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "GhostMesh"
	var box := BoxMesh.new()
	box.size = Vector3(3.4, 3.4, 7.6)   # 标准车身占位（幽灵不随车型变化，B4 简化）
	mesh_node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.55, 1.0, 0.28)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_node.material_override = mat
	add_child(mesh_node)


func _process(dt: float) -> void:
	if _samples.size() < 2:
		return
	_t = fmod(_t + dt, _duration + 0.001)
	# 找 t 所在区间并插值（pos lerp + basis 分量 lerp）
	for i in range(_samples.size() - 1):
		var t0: float = float(_samples[i].t)
		var t1: float = float(_samples[i + 1].t)
		if _t >= t0 and _t <= t1:
			var k: float = (_t - t0) / maxf(t1 - t0, 1e-6)
			var p0: Vector3 = _samples[i].pos
			var p1: Vector3 = _samples[i + 1].pos
			position = p0.lerp(p1, k)
			var b0 := Basis(_samples[i].bx, _samples[i].by, _samples[i].bz)
			var b1 := Basis(_samples[i + 1].bx, _samples[i + 1].by, _samples[i + 1].bz)
			var b: Basis = b0.slerp(b1, k)
			basis = b.orthonormalized()
			break
