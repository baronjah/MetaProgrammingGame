class_name SolidityMaster
extends Node

var tracked_bodies: Array[CollisionObject3D] = []

# DNA: QUERY_NODE | auto-tag v1.8
func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)
	Scriptura.law_value_changed.connect(_on_law_value_changed)

# DNA: MUTATE_NODE | auto-tag v1.8
func execute_solidity(body: CollisionObject3D) -> void:
	if not tracked_bodies.has(body):
		tracked_bodies.append(body)
	var blend := Scriptura.get_law_blend("solidity")
	if is_equal_approx(blend, 1.0):
		rigid_collision(body)
	elif is_equal_approx(blend, 0.0):
		pass_through(body)
	else:
		_apply_blended_solidity(body, blend)

# DNA: MUTATE_NODE | auto-tag v1.6
func rigid_collision(body: CollisionObject3D) -> void:
	body.collision_layer = 1
	body.collision_mask = 1

# DNA: MUTATE_NODE | auto-tag v1.6
func pass_through(body: CollisionObject3D) -> void:
	body.collision_layer = 0
	body.collision_mask = 0

# DNA: MUTATE_NODE | auto-tag v1.8
func _apply_blended_solidity(body: CollisionObject3D, _blend: float) -> void:
	var solidity := LawInterpolator.blend_float("solidity", 1.0, 0.0)
	var enabled := solidity >= 0.5
	body.collision_layer = 1 if enabled else 0
	body.collision_mask = 1 if enabled else 0
	body.set_meta("solidity_factor", solidity)

# DNA: RETURN_VALUE | auto-tag v1.8
func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name == "solidity":
		_refresh_bodies()

# DNA: RETURN_VALUE | auto-tag v1.8
func _on_law_value_changed(law_name: String, _value: float) -> void:
	if law_name == "solidity":
		_refresh_bodies()

# DNA: MUTATE_NODE | auto-tag v1.8
func _refresh_bodies() -> void:
	for body in tracked_bodies:
		if is_instance_valid(body):
			execute_solidity(body)
	Scriptura.push_message("[solid_state] refreshed tracked colliders", "SolidityMaster")
