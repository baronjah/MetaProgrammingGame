class_name ScriptInspector
extends Node3D

func inspect_script(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	var lines := text.split("\n")
	var class_name := ""
	for line in lines:
		if line.strip_edges().begins_with("class_name"):
			class_name = line.split(" ", false, 2)[1]
			break
	$Label3D.text = "Script: %s\nClass: %s\nLines: %d" % [path, class_name, lines.size()]

func register_to_script_registry(script_id: String, script_type: String, path: String, scene_path: Variant, node_path: Variant) -> void:
	ScriptRegistry.register_script(script_id, script_type, path, scene_path, node_path)

func add_to_function_db(function_id: String, entry: Dictionary) -> void:
	Scriptura.register_function(function_id, entry)
