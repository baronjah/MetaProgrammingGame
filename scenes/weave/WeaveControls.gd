class_name WeaveControls
extends Node3D

var style: String = "bezier"

# DNA: MUTATE_NODE | auto-tag v1.6
func toggle_law_layer(law_name: String) -> void:
	TheWeave.set_layer_visible(law_name, not _is_law_visible(law_name))

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func set_style(next_style: String) -> void:
	style = next_style
	for t in TheWeave.threads:
		t.path_style = style

# DNA: RETURN_VALUE | auto-tag v1.6
func isolate(script_id: String) -> void:
	TheWeave.isolate_node(script_id)

# DNA: RETURN_VALUE | auto-tag v1.6
func clear_isolation() -> void:
	TheWeave.clear_isolation()

# DNA: MUTATE_NODE | auto-tag v1.6
func toggle_orphans(visible: bool) -> void:
	for node_id in TheWeave.nodes.keys():
		if node_id.to_lower().contains("orphan"):
			TheWeave.nodes[node_id]["instance"].visible = visible

# DNA: QUERY_NODE | auto-tag v1.6
func _is_law_visible(law_name: String) -> bool:
	for t in TheWeave.threads:
		if t.law_binding == law_name:
			return t.visible
	return true


# DNA: MUTATE_NODE | auto-tag v1.6
func toggle_dna_layer(dna_type: String, visible: bool) -> void:
	for thread in TheWeave.threads:
		if thread.has_meta("dna_type") and str(thread.get_meta("dna_type")) == dna_type:
			thread.visible = visible
