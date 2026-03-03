class_name SolidityMaster
extends Node

var tracked_bodies: Array[CollisionObject3D] = []

func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)

func execute_solidity(body: CollisionObject3D) -> void:
	if not tracked_bodies.has(body):
		tracked_bodies.append(body)
	match Scriptura.get_law("solidity"):
		"A": rigid_collision(body)
		"B": pass_through(body)
		_: rigid_collision(body)

func rigid_collision(body: CollisionObject3D) -> void:
	body.collision_layer = 1
	body.collision_mask = 1

func pass_through(body: CollisionObject3D) -> void:
	body.collision_layer = 0
	body.collision_mask = 0

func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name != "solidity":
		return
	for body in tracked_bodies:
		if is_instance_valid(body):
			execute_solidity(body)
	Scriptura.push_message("[solid_state] refreshed tracked colliders", "SolidityMaster")
