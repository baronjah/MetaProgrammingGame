extends Node

var node_registry: Dictionary = {}

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

func _on_node_added(node: Node) -> void:
	if node.has_meta("script_id"):
		var key := str(node.get_path())
		node_registry[key] = {
			"node": node,
			"script_id": str(node.get_meta("script_id", "")),
			"parent": node.get_parent() if node.get_parent() else NodePath(""),
		}
	if Engine.has_singleton("PathResolver"):
		PathResolver.notify_path_valid(str(node.get_path())) if PathResolver.has_method("notify_path_valid") else null
	if Engine.has_singleton("LogCatcher"):
		LogCatcher.log("TREE", "added", str(node.get_path()), LogCatcher.Level.TREE)

func _on_node_removed(node: Node) -> void:
	var key := str(node.get_path())
	if node_registry.has(key):
		node_registry.erase(key)
	if Engine.has_singleton("PathResolver"):
		PathResolver.notify_path_invalid(key) if PathResolver.has_method("notify_path_invalid") else null
	if Engine.has_singleton("TheWeave"):
		for thread in TheWeave.get_threads_for_node(str(node.get_meta("script_id", ""))):
			thread.modulate = Color(0.5, 0.1, 0.1)
	if Engine.has_singleton("LogCatcher"):
		LogCatcher.log("TREE", "removed", key, LogCatcher.Level.TREE)

func track_reparent(node: Node, old_path: NodePath, new_path: NodePath) -> void:
	var old_key := str(old_path)
	if node_registry.has(old_key):
		var entry: Dictionary = node_registry[old_key]
		node_registry.erase(old_key)
		node_registry[str(new_path)] = entry
	if Engine.has_singleton("LogCatcher"):
		LogCatcher.log("TREE", "reparented", "%s -> %s" % [str(old_path), str(new_path)], LogCatcher.Level.TREE)

func get_all_live_paths() -> Array[NodePath]:
	var out: Array[NodePath] = []
	for key in node_registry.keys():
		out.append(NodePath(key))
	return out
