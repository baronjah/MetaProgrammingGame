class_name WeaveControls
extends Node3D

var style: String = "bezier"

func toggle_law_layer(law_name: String) -> void:
	TheWeave.set_layer_visible(law_name, not _is_law_visible(law_name))

func set_style(next_style: String) -> void:
	style = next_style
	for t in TheWeave.threads:
		t.path_style = style

func isolate(script_id: String) -> void:
	TheWeave.isolate_node(script_id)

func clear_isolation() -> void:
	TheWeave.clear_isolation()

func toggle_orphans(visible: bool) -> void:
	for node_id in TheWeave.nodes.keys():
		if node_id.to_lower().contains("orphan"):
			TheWeave.nodes[node_id]["instance"].visible = visible

func _is_law_visible(law_name: String) -> bool:
	for t in TheWeave.threads:
		if t.law_binding == law_name:
			return t.visible
	return true
