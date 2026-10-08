@tool
extends Resource

const BODY_SHADER = preload("res://comic_style/shaders/plain_toon.gdshader")
const OUTLINE_SHADER = preload("res://comic_style/shaders/pixel_outline.gdshader")

@export var interactive_width: float = 4.0
@export var thin_width: float = 1.5
@export var selected_extra: float = 1.0
@export var line_color: Color = Color("242934")
@export var hover_color: Color = Color("e8b45c")
@export var selected_color: Color = Color("f5ce7a")
@export var disabled_color: Color = Color("657078")

func body_material(color: Color, enabled: bool = true) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BODY_SHADER
	material.set_shader_parameter("base_color", color if enabled else color.lerp(Color("8a9191"), 0.45))
	return material

func width(interactive: bool, selected: bool = false) -> float:
	return (interactive_width + (selected_extra if selected else 0.0)) if interactive else thin_width

func outline_material(interactive: bool, hovered: bool, selected: bool, enabled: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("outline_width", width(interactive, selected))
	var ink: Color = line_color
	if interactive:
		if not enabled:
			ink = disabled_color
		elif selected:
			ink = selected_color
		elif hovered:
			ink = hover_color
	material.set_shader_parameter("line_color", ink)
	return material

static func smooth_shell(source: Mesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	var surfaces: Array[Array] = []
	var normal_sums: Dictionary = {}
	for surface_index in source.get_surface_count():
		var data: Array = source.surface_get_arrays(surface_index).duplicate(true)
		var verts: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			var key: Vector3 = verts[i].snapped(Vector3.ONE * 0.0001)
			var normal: Vector3 = normals[i] if i < normals.size() else verts[i].normalized()
			normal_sums[key] = (normal_sums.get(key, Vector3.ZERO) as Vector3) + normal
		surfaces.append(data)
	for surface_index in surfaces.size():
		var data: Array = surfaces[surface_index]
		var verts: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var normals := PackedVector3Array()
		normals.resize(verts.size())
		for i in verts.size():
			var key: Vector3 = verts[i].snapped(Vector3.ONE * 0.0001)
			normals[i] = (normal_sums[key] as Vector3).normalized()
		data[Mesh.ARRAY_NORMAL] = normals
		var primitive := Mesh.PRIMITIVE_TRIANGLES
		if source is ArrayMesh:
			primitive = source.surface_get_primitive_type(surface_index)
		result.add_surface_from_arrays(primitive, data)
	return result
