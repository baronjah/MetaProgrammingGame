class_name LayerControls
extends Node3D

var active_layer: int = 0
var layer_spacing: float = 0.0
var isolate_mode: bool = false

# DNA: TREE_STRUCTURE | rebuilds layer buttons from weave layer config
func rebuild_buttons() -> void:
	if not has_node("LayerButtons"):
		return
	for c in $LayerButtons.get_children():
		c.queue_free()
	var idx := 0
	for layer_id in TheWeave.layer_config.keys():
		var card := MeshInstance3D.new()
		card.mesh = PlaneMesh.new()
		card.position = Vector3(float(idx) * 0.4, 0, 0)
		card.set_meta("interactive", true)
		card.set_meta("layer_id", int(layer_id))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color((TheWeave.layer_config[layer_id] as Dictionary).get("color", "#FFFFFF"))
		card.material_override = mat
		$LayerButtons.add_child(card)
		idx += 1

# DNA: MUTATE_GLOBAL | toggles layer visibility or isolation
func toggle_layer(layer_id: int) -> void:
	active_layer = layer_id
	if isolate_mode:
		TheWeave.isolate_layer(layer_id)
		return
	var visible := not TheWeave.layer_visibility.get(layer_id, true)
	TheWeave.set_layer_visible(layer_id, visible)

# DNA: MUTATE_GLOBAL | toggles isolate mode
func set_isolate_mode(enabled: bool) -> void:
	isolate_mode = enabled
	if not isolate_mode:
		TheWeave.restore_all_layers()

# DNA: MUTATE_NODE | pulls active layer forward
func pull_forward(amount: float) -> void:
	TheWeave.pull_layer_forward(active_layer, amount)

# DNA: MUTATE_NODE | updates spacing and recomputes all layer z offsets
func set_spacing(spacing: float) -> void:
	layer_spacing = max(spacing, 0.0)
	TheWeave.set_layer_spacing(layer_spacing)
