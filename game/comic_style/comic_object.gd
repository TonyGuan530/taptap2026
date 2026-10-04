@tool
extends Node3D

const StyleDefinition = preload("res://comic_style/comic_style.gd")

@export var interactive: bool = false:
	set(value):
		interactive = value
		if is_inside_tree():
			refresh_style()
@export var interaction_enabled: bool = true:
	set(value):
		interaction_enabled = value
		if is_inside_tree():
			refresh_style()
@export var style: Resource = StyleDefinition.new()

var hovered: bool = false
var selected: bool = false
var _parts: Array[MeshInstance3D] = []
var _colors: Dictionary = {}

func _ready() -> void:
	# Rebuild registration after a PackedScene is instantiated.
	if _parts.is_empty():
		_collect_parts(self)
	refresh_style()

func _collect_parts(parent: Node) -> void:
	for child in parent.get_children():
		if child is MeshInstance3D and child.name != "ComicOutline" and child.has_meta("comic_color"):
			_parts.append(child)
			_colors[child.get_instance_id()] = child.get_meta("comic_color")
		if child.name != "ComicOutline":
			_collect_parts(child)

func add_part(mesh: Mesh, color: Color, part_transform: Transform3D = Transform3D.IDENTITY) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = "Part%d" % _parts.size()
	part.mesh = mesh
	part.transform = part_transform
	part.set_meta("comic_color", color)
	add_child(part)
	part.owner = self
	_parts.append(part)
	_colors[part.get_instance_id()] = color
	var shell := MeshInstance3D.new()
	shell.name = "ComicOutline"
	shell.mesh = StyleDefinition.smooth_shell(mesh)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.extra_cull_margin = 0.5
	part.add_child(shell)
	shell.owner = self
	_apply_part(part)
	return part

func refresh_style() -> void:
	for part in _parts:
		if is_instance_valid(part):
			_apply_part(part)

func add_imported_model(source: Node3D, fallback_color: Color = Color("b5b4aa")) -> bool:
	# Static, one-material-per-mesh GLB. Preserve nested local transforms.
	var imported: Array[Dictionary] = []
	_collect_imported(source, Transform3D.IDENTITY, imported)
	if imported.is_empty():
		push_error("ComicObject: imported model has no meshes")
		return false
	for entry in imported:
		var mesh_node: MeshInstance3D = entry.node
		if mesh_node.mesh.get_surface_count() != 1 or mesh_node.skin != null or (mesh_node.mesh is ArrayMesh and mesh_node.mesh.get_blend_shape_count() > 0):
			push_error("ComicObject: use static closed parts, one material per mesh; skinned/morph assets need a dedicated outline rig")
			return false
	for entry in imported:
		var mesh_node: MeshInstance3D = entry.node
		var color := fallback_color
		var material: Material = mesh_node.get_active_material(0)
		if mesh_node.has_meta("comic_color"):
			color = mesh_node.get_meta("comic_color")
		elif material is StandardMaterial3D:
			color = material.albedo_color
		add_part(mesh_node.mesh, color, entry.transform)
	return true

func _collect_imported(node: Node, parent_transform: Transform3D, collected: Array[Dictionary]) -> void:
	if node.name == "ComicOutline":
		return
	var combined: Transform3D = parent_transform * node.transform if node is Node3D else parent_transform
	if node is MeshInstance3D and node.mesh:
		collected.append({"node": node, "transform": combined})
	for child in node.get_children():
		_collect_imported(child, combined, collected)

func _apply_part(part: MeshInstance3D) -> void:
	var color: Color = _colors.get(part.get_instance_id(), Color.WHITE)
	part.material_override = style.body_material(color, interaction_enabled)
	var shell: MeshInstance3D = part.get_node_or_null("ComicOutline")
	if shell:
		shell.material_override = style.outline_material(interactive, hovered, selected, interaction_enabled)

func set_interactive(value: bool) -> void:
	interactive = value
	if not is_inside_tree():
		refresh_style()

func set_enabled(value: bool) -> void:
	interaction_enabled = value
	if not is_inside_tree():
		refresh_style()

func set_hovered(value: bool) -> void:
	if hovered != value:
		hovered = value
		refresh_style()

func set_selected(value: bool) -> void:
	if selected != value:
		selected = value
		refresh_style()

func get_line_width() -> float:
	return style.width(interactive, selected)
