extends Node

const REGISTRY_PATH := "res://data/script_registry.json"

var registry: Dictionary = {}

# DNA: QUERY_NODE | auto-tag v1.6
func _ready() -> void:
	load_registry()

# DNA: TREE_STRUCTURE | auto-tag v1.6
func load_registry() -> void:
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		registry = {}
		return
	var parsed := JSON.parse_string(file.get_as_text())
	registry = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func register_script(id: String, script_type: String, path: String, scene_path: Variant, node_path: Variant) -> void:
	registry[id] = {
		"type": script_type,
		"path": path,
		"class_name": id,
		"scene_attachment": scene_path,
		"node_path_in_scene": node_path,
		"loaded": false,
	}
	save_registry()

# DNA: TREE_STRUCTURE | auto-tag v1.6
func hotload_script(script_id: String, target_node: Node) -> bool:
	if not registry.has(script_id):
		return false
	var entry: Dictionary = registry[script_id]
	if entry.get("type", "") == "autoload":
		return false
	if entry.get("type", "") != "class_named" and entry.get("type", "") != "scene_script":
		return false
	var script_resource := load(str(entry.get("path", ""))) as Script
	if script_resource == null:
		return false
	target_node.set_script(script_resource)
	entry["loaded"] = true
	registry[script_id] = entry
	save_registry()
	return true

# DNA: RETURN_VALUE | auto-tag v1.6
func eject_script(script_id: String, target_node: Node) -> void:
	if not registry.has(script_id):
		return
	target_node.set_script(null)
	var entry: Dictionary = registry[script_id]
	entry["loaded"] = false
	registry[script_id] = entry
	save_registry()

# DNA: QUERY_NODE | auto-tag v1.6
func get_scripts_by_type(script_type: String) -> Array:
	var result: Array = []
	for id in registry.keys():
		var entry: Dictionary = registry[id]
		if str(entry.get("type", "")) == script_type:
			result.append(entry)
	return result

# DNA: QUERY_NODE | auto-tag v1.6
func find_script_on_scene(scene_path: String) -> Array:
	var result: Array = []
	for id in registry.keys():
		var entry: Dictionary = registry[id]
		if str(entry.get("scene_attachment", "")) == scene_path:
			result.append(entry)
	return result

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func save_registry() -> void:
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(registry, "\t"))
