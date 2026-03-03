class_name LightMaster
extends Node

var tracked_lights: Array[Light3D] = []

# DNA: QUERY_NODE | auto-tag v1.6
func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)

# DNA: RETURN_VALUE | auto-tag v1.6
func execute_light(light_node: Light3D) -> void:
	if not tracked_lights.has(light_node):
		tracked_lights.append(light_node)
	match Scriptura.get_law("light"):
		"A": ambient_lit(light_node)
		"B": void_dark(light_node)
		_: ambient_lit(light_node)

# DNA: RETURN_VALUE | auto-tag v1.6
func ambient_lit(light_node: Light3D) -> void:
	light_node.light_energy = 1.0
	light_node.visible = true

# DNA: RETURN_VALUE | auto-tag v1.6
func void_dark(light_node: Light3D) -> void:
	light_node.light_energy = 0.0
	light_node.visible = false

# DNA: RETURN_VALUE | auto-tag v1.6
func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name != "light":
		return
	for light_node in tracked_lights:
		if is_instance_valid(light_node):
			execute_light(light_node)
	Scriptura.push_message("[light_mode] refreshed tracked lights", "LightMaster")
