class_name LifeMaster
extends Node

var tracked_nodes: Array[Node3D] = []

func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)

func execute_life(target: Node3D) -> void:
	if not tracked_nodes.has(target):
		tracked_nodes.append(target)
	match Scriptura.get_law("life"):
		"A": spawn_alive(target)
		"B": spawn_corpse(target)
		_: spawn_alive(target)

func spawn_alive(target: Node3D) -> void:
	target.set_meta("life_state", "alive")
	target.set_meta("is_corpse", false)

func spawn_corpse(target: Node3D) -> void:
	target.set_meta("life_state", "dead")
	target.set_meta("is_corpse", true)

func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name != "life":
		return
	for target in tracked_nodes:
		if is_instance_valid(target):
			execute_life(target)
	Scriptura.push_message("[life_state] refreshed tracked nodes", "LifeMaster")
