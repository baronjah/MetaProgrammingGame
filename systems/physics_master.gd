class_name PhysicsMaster
extends Node

var tracked_bodies: Array[RigidBody3D] = []

# DNA: QUERY_NODE | auto-tag v1.8
func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)
	Scriptura.law_value_changed.connect(_on_law_value_changed)

# DNA: MUTATE_NODE | auto-tag v1.8
func execute_gravity(body: RigidBody3D) -> void:
	if not tracked_bodies.has(body):
		tracked_bodies.append(body)
	var blend := Scriptura.get_law_blend("gravity")
	if is_equal_approx(blend, 1.0):
		apply_downward_gravity(body)
	elif is_equal_approx(blend, 0.0):
		apply_upward_gravity(body)
	else:
		_apply_blended_gravity(body, blend)

# DNA: MUTATE_NODE | auto-tag v1.6
func apply_downward_gravity(body: RigidBody3D) -> void:
	body.gravity_scale = 1.0

# DNA: MUTATE_NODE | auto-tag v1.6
func apply_upward_gravity(body: RigidBody3D) -> void:
	body.gravity_scale = -1.0

# DNA: MUTATE_NODE | auto-tag v1.8
func _apply_blended_gravity(body: RigidBody3D, blend: float) -> void:
	var gravity_value := LawInterpolator.blend_float("gravity", -9.8, 9.8)
	body.gravity_scale = gravity_value / 9.8

# DNA: RETURN_VALUE | auto-tag v1.8
func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name == "gravity":
		_refresh_bodies()

# DNA: RETURN_VALUE | auto-tag v1.8
func _on_law_value_changed(law_name: String, _value: float) -> void:
	if law_name == "gravity":
		_refresh_bodies()

# DNA: MUTATE_NODE | auto-tag v1.8
func _refresh_bodies() -> void:
	for body in tracked_bodies:
		if is_instance_valid(body):
			execute_gravity(body)
	Scriptura.push_message("[gravity_control] refreshed tracked bodies", "PhysicsMaster")
