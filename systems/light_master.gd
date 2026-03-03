class_name LightMaster
extends Node

func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)

func execute_light(light_node: Light3D) -> void:
	match Scriptura.get_law("light"):
		"A": ambient_lit(light_node)
		"B": void_dark(light_node)
		_: ambient_lit(light_node)

func ambient_lit(light_node: Light3D) -> void:
	light_node.light_energy = 1.0
	light_node.visible = true

func void_dark(light_node: Light3D) -> void:
	light_node.light_energy = 0.0
	light_node.visible = false

func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name == "light":
		Scriptura.push_message("light_mode live-updated", "LightMaster")
