class_name LifeMaster
extends Node

func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)

func execute_life(target: Node3D) -> void:
	match Scriptura.get_law("life"):
		"A": spawn_alive(target)
		"B": spawn_corpse(target)
		_: spawn_alive(target)

func spawn_alive(target: Node3D) -> void:
	target.set_meta("life_state", "alive")
	if target.has_method("play"):
		target.play("idle")

func spawn_corpse(target: Node3D) -> void:
	target.set_meta("life_state", "dead")
	if target.has_method("stop"):
		target.stop()

func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name == "life":
		Scriptura.push_message("life_state live-updated", "LifeMaster")
