class_name JsonInspector
extends Node3D

# DNA: RETURN_VALUE | auto-tag v1.6
func inspect_json(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed := JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		$Label3D.text = "Invalid JSON"
		return
	if path.ends_with("scriptura.json"):
		$Label3D.text = "Laws: %s" % ", ".join(parsed.get("laws", {}).keys())
	elif path.ends_with("function_db.json"):
		$Label3D.text = "Functions: %d" % parsed.keys().size()
	elif path.ends_with("script_registry.json"):
		$Label3D.text = "Registered scripts: %d" % parsed.keys().size()
	else:
		$Label3D.text = "Top keys: %s" % ", ".join(parsed.keys())

# DNA: MUTATE_NODE | auto-tag v1.6
func toggle_law(law_name: String, next_state: String) -> void:
	Scriptura.set_law(law_name, next_state)
