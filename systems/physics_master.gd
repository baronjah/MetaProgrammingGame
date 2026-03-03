class_name PhysicsMaster
extends Node

var tracked_bodies: Array[RigidBody3D] = []

func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)

func execute_gravity(body: RigidBody3D) -> void:
	if not tracked_bodies.has(body):
		tracked_bodies.append(body)
	match Scriptura.get_law("gravity"):
		"A": apply_downward_gravity(body)
		"B": apply_upward_gravity(body)
		_: apply_downward_gravity(body)

func apply_downward_gravity(body: RigidBody3D) -> void:
	body.gravity_scale = 1.0

func apply_upward_gravity(body: RigidBody3D) -> void:
	body.gravity_scale = -1.0

func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name != "gravity":
		return
	for body in tracked_bodies:
		if is_instance_valid(body):
			execute_gravity(body)
	Scriptura.push_message("[gravity_control] refreshed tracked bodies", "PhysicsMaster")
