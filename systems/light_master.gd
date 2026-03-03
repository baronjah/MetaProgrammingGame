class_name LightMaster
extends Node

var tracked_lights: Array[Light3D] = []

# DNA: QUERY_NODE | auto-tag v1.8
func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)
	Scriptura.law_value_changed.connect(_on_law_value_changed)

# DNA: MUTATE_NODE | auto-tag v1.8
func execute_light(light_node: Light3D) -> void:
	if not tracked_lights.has(light_node):
		tracked_lights.append(light_node)
	var blend := Scriptura.get_law_blend("light")
	if is_equal_approx(blend, 1.0):
		ambient_lit(light_node)
	elif is_equal_approx(blend, 0.0):
		void_dark(light_node)
	else:
		_apply_blended_light(light_node, blend)

# DNA: MUTATE_NODE | auto-tag v1.6
func ambient_lit(light_node: Light3D) -> void:
	light_node.light_energy = 1.0
	light_node.visible = true

# DNA: MUTATE_NODE | auto-tag v1.6
func void_dark(light_node: Light3D) -> void:
	light_node.light_energy = 0.0
	light_node.visible = false

# DNA: MUTATE_NODE | auto-tag v1.8
func _apply_blended_light(light_node: Light3D, _blend: float) -> void:
	var energy := LawInterpolator.blend_float("light", 1.0, 0.0)
	light_node.light_energy = energy
	light_node.visible = energy > 0.01

# DNA: RETURN_VALUE | auto-tag v1.8
func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name == "light":
		_refresh_lights()

# DNA: RETURN_VALUE | auto-tag v1.8
func _on_law_value_changed(law_name: String, _value: float) -> void:
	if law_name == "light":
		_refresh_lights()

# DNA: MUTATE_NODE | auto-tag v1.8
func _refresh_lights() -> void:
	for light_node in tracked_lights:
		if is_instance_valid(light_node):
			execute_light(light_node)
	Scriptura.push_message("[light_mode] refreshed tracked lights", "LightMaster")
