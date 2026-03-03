extends Node

func resolve(from_script_id: String, to_script_id: String) -> Dictionary:
	if not ScriptRegistry.registry.has(from_script_id) or not ScriptRegistry.registry.has(to_script_id):
		return _result("unknown", "", true, null)
	var from_entry: Dictionary = ScriptRegistry.registry[from_script_id]
	var to_entry: Dictionary = ScriptRegistry.registry[to_script_id]
	var from_type := str(from_entry.get("type", ""))
	var to_type := str(to_entry.get("type", ""))
	if to_type == "autoload":
		return _result("autoload_direct", to_script_id, false, null)
	if from_type == "autoload" and to_type == "scene_script":
		var scene := to_entry.get("scene_attachment", null)
		var node_path := str(to_entry.get("node_path_in_scene", "."))
		return _result("cross_scene", "/root%s" % _scene_node_anchor(scene, node_path), true, scene)
	if from_type == "scene_script" and to_type == "scene_script":
		var same_scene := str(from_entry.get("scene_attachment", "")) == str(to_entry.get("scene_attachment", ""))
		if same_scene:
			var rel := build_node_path(str(from_entry.get("node_path_in_scene", ".")), str(to_entry.get("node_path_in_scene", ".")), ".")
			return _result("same_scene", rel, false, null)
		var target_scene := to_entry.get("scene_attachment", null)
		return _result("cross_scene", "/root%s" % _scene_node_anchor(target_scene, str(to_entry.get("node_path_in_scene", "."))), true, target_scene)
	if from_type == "class_named":
		return {
			"strategy": "inject_dependency",
			"path_string": "",
			"needs_scene_load": false,
			"target_scene": null,
			"code_snippet": "# inject %s as parameter" % to_script_id,
		}
	return _result("root_climb", "/root", true, null)

func build_node_path(from_node_path: String, to_node_path: String, _scene_root: String) -> String:
	if from_node_path == to_node_path:
		return "."
	var from_parts := _split_path(from_node_path)
	var to_parts := _split_path(to_node_path)
	var common := 0
	while common < from_parts.size() and common < to_parts.size() and from_parts[common] == to_parts[common]:
		common += 1
	var up := []
	for _i in range(common, from_parts.size()):
		up.append("..")
	var down := []
	for i in range(common, to_parts.size()):
		down.append(to_parts[i])
	var joined := up + down
	return "." if joined.is_empty() else "/".join(joined)

func generate_access_snippet(from_id: String, to_id: String) -> String:
	var resolved := resolve(from_id, to_id)
	var strategy := str(resolved.get("strategy", ""))
	if strategy == "autoload_direct":
		return "var target = %s" % to_id
	if strategy == "inject_dependency":
		return str(resolved.get("code_snippet", ""))
	return "var target = get_node('%s')" % str(resolved.get("path_string", ""))

func _scene_node_anchor(scene_path: Variant, node_path: String) -> String:
	var scene_name := "UnknownScene"
	if scene_path != null:
		scene_name = str(scene_path).get_file().trim_suffix(".tscn")
	if node_path == "." or node_path == "":
		return "/%s" % scene_name
	return "/%s/%s" % [scene_name, node_path]

func _split_path(path: String) -> Array[String]:
	if path == "." or path == "":
		return []
	var out: Array[String] = []
	for piece in path.split("/"):
		if piece != "" and piece != ".":
			out.append(piece)
	return out

func _result(strategy: String, path_string: String, needs_scene_load: bool, target_scene: Variant) -> Dictionary:
	return {
		"strategy": strategy,
		"path_string": path_string,
		"needs_scene_load": needs_scene_load,
		"target_scene": target_scene,
		"code_snippet": "get_node('%s')" % path_string,
	}
