class_name CursorVisual
extends Node3D

@onready var ring: MeshInstance3D = $Ring
@onready var dot: MeshInstance3D = $Dot
@onready var normal_indicator: MeshInstance3D = $NormalIndicator

var mode: String = "navigate"

# DNA: QUERY_NODE | auto-tag v1.6
func _process(_delta: float) -> void:
	global_position = CursorEntity.world_position
	normal_indicator.look_at(global_position + CursorEntity.hit_normal, Vector3.UP)
	var hovered := CursorEntity.hit_object
	var ring_scale := 1.0
	var color := Color(1, 1, 1)
	if hovered:
		ring_scale = 1.2
		if hovered.has_meta("port_type"):
			color = Color(0.2, 1.0, 0.2) if str(hovered.get_meta("port_type")) == "input" else Color(1.0, 0.65, 0.2)
		elif hovered.has_meta("script_id"):
			color = Color(0.2, 0.7, 1.0)
		elif hovered.has_meta("interactive"):
			color = Color(1.0, 1.0, 0.2)
	ring.scale = Vector3.ONE * ring_scale
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	ring.material_override = mat

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func set_mode(next_mode: String) -> void:
	mode = next_mode
	CursorEntity.set_mode(next_mode)
