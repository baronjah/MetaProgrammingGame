class_name SolidityMaster
extends Node

var tracked_bodies: Array[CollisionObject3D] = []

# DNA: QUERY_NODE | auto-tag v1.6
func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)

# DNA: RETURN_VALUE | auto-tag v1.6
func execute_solidity(body: CollisionObject3D) -> void:
	if not tracked_bodies.has(body):
		tracked_bodies.append(body)
	match Scriptura.get_law("solidity"):
		"A": rigid_collision(body)
		"B": pass_through(body)
		_: rigid_collision(body)

# DNA: RETURN_VALUE | auto-tag v1.6
func rigid_collision(body: CollisionObject3D) -> void:
	body.collision_layer = 1
	body.collision_mask = 1

# DNA: RETURN_VALUE | auto-tag v1.6
func pass_through(body: CollisionObject3D) -> void:
	body.collision_layer = 0
	body.collision_mask = 0

# DNA: RETURN_VALUE | auto-tag v1.6
func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name != "solidity":
		return
	for body in tracked_bodies:
		if is_instance_valid(body):
			execute_solidity(body)
	Scriptura.push_message("[solid_state] refreshed tracked colliders", "SolidityMaster")
