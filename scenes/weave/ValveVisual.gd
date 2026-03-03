class_name ValveVisual
extends Node3D

var valve_id: String = ""
var closed_by_doctor: bool = false

@onready var ring: MeshInstance3D = $Ring if has_node("Ring") else MeshInstance3D.new()
@onready var override_dot: MeshInstance3D = $OverrideDot if has_node("OverrideDot") else MeshInstance3D.new()
@onready var halo: MeshInstance3D = $CaptureHalo if has_node("CaptureHalo") else MeshInstance3D.new()

# DNA: QUERY_NODE | auto-tag v1.6
func _ready() -> void:
	if ring.get_parent() == null:
		ring.mesh = TorusMesh.new()
		add_child(ring)
	if override_dot.get_parent() == null:
		override_dot.mesh = SphereMesh.new()
		override_dot.position = Vector3(0.1, 0.1, 0)
		add_child(override_dot)
	if halo.get_parent() == null:
		halo.mesh = TorusMesh.new()
		halo.scale = Vector3.ONE * 1.2
		add_child(halo)
	set_meta("interactive", true)
	set_meta("script_id", valve_id)

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func update_visual(open_state: bool, throttle_ms: float, capture: bool, override_active: bool, active_version: String, doctor_closed: bool) -> void:
	closed_by_doctor = doctor_closed
	var color := Color(0.2, 1.0, 0.2)
	if not open_state:
		color = Color(1.0, 0.2, 0.2)
	elif throttle_ms > 0.0:
		color = Color(1.0, 0.65, 0.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	ring.material_override = mat
	override_dot.visible = override_active
	override_dot.modulate = Color(0.2, 0.5, 1.0) if active_version == "A" else Color(0.3, 0.8, 1.0)
	halo.visible = capture
