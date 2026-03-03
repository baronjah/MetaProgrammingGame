extends Node

var change_queue: Array[Dictionary] = []
var forge_active: bool = false

signal change_applied(change: Dictionary)
signal change_failed(change: Dictionary, reason: String)
signal forge_toggled(active: bool)

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func queue_change(change: Dictionary) -> void:
	change_queue.append(change)
	if Engine.has_singleton("LogCatcher"):
		LogCatcher.log("FORGE", "queued", str(change.get("type", "unknown")))

# DNA: QUERY_NODE | auto-tag v1.6
func _process(_delta: float) -> void:
	if forge_active and change_queue.size() > 0:
		var change := change_queue.pop_front()
		_apply(change)

# DNA: RETURN_VALUE | auto-tag v1.6
func _apply(change: Dictionary) -> void:
	var ctype := str(change.get("type", ""))
	match ctype:
		"law_flip":
			_apply_law_flip(change)
		"thread_create":
			_apply_thread_create(change)
		"thread_remove":
			_apply_thread_remove(change)
		"script_hotload":
			_apply_hotload(change)
		"node_reparent":
			_apply_reparent(change)
		"function_inject":
			_apply_function_inject(change)
		_:
			change_failed.emit(change, "unknown type")
			if Engine.has_singleton("LogCatcher"):
				LogCatcher.warn("FORGE", "Unknown change type: %s" % ctype)

# DNA: MUTATE_NODE | auto-tag v1.6
func _apply_law_flip(c: Dictionary) -> void:
	Scriptura.set_law(str(c.get("law", "")), str(c.get("to", "A")))
	Scriptura.save_scriptura() if Scriptura.has_method("save_scriptura") else null
	change_applied.emit(c)

# DNA: TREE_STRUCTURE | auto-tag v1.6
func _apply_thread_create(c: Dictionary) -> void:
	TheWeave.add_thread(str(c.get("from_script", "")), str(c.get("to_script", "")), str(c.get("from_func", "")), str(c.get("to_func", "")), str(c.get("law", "")))
	var source := str(c.get("from_script", ""))
	for key in Scriptura.function_db.keys():
		var entry: Dictionary = Scriptura.function_db[key]
		if str(entry.get("script_id", entry.get("class_name", ""))) == source:
			var con: Dictionary = entry.get("connections", {})
			con[str(c.get("to_script", ""))] = {"strategy": "autoload_direct", "snippet": str(c.get("to_script", ""))}
			entry["connections"] = con
			Scriptura.function_db[key] = entry
	Scriptura.save_function_db()
	change_applied.emit(c)

# DNA: MUTATE_NODE | auto-tag v1.6
func _apply_thread_remove(c: Dictionary) -> void:
	TheWeave.toggle_thread(str(c.get("thread_id", "")))
	change_applied.emit(c)

# DNA: MUTATE_NODE | auto-tag v1.6
func _apply_hotload(c: Dictionary) -> void:
	var node := get_tree().root.get_node_or_null(str(c.get("target_node_path", "")))
	if node == null:
		change_failed.emit(c, "target node not found")
		return
	if ScriptRegistry.hotload_script(str(c.get("script_id", "")), node):
		if Engine.has_singleton("LogCatcher"):
			LogCatcher.log("FORGE", "hotloaded", "%s -> %s" % [str(c.get("script_id", "")), str(c.get("target_node_path", ""))])
		change_applied.emit(c)
	else:
		change_failed.emit(c, "hotload failed")

# DNA: TREE_STRUCTURE | auto-tag v1.6
func _apply_reparent(c: Dictionary) -> void:
	var node := get_tree().root.get_node_or_null(str(c.get("node_path", "")))
	var new_parent := get_tree().root.get_node_or_null(str(c.get("new_parent_path", "")))
	if node == null or new_parent == null:
		change_failed.emit(c, "node/new parent missing")
		return
	node.reparent.call_deferred(new_parent)
	if Engine.has_singleton("LogCatcher"):
		LogCatcher.log("FORGE", "reparent_deferred", "%s -> %s" % [str(c.get("node_path", "")), str(c.get("new_parent_path", ""))])
	change_applied.emit(c)

# DNA: MUTATE_NODE | auto-tag v1.6
func _apply_function_inject(c: Dictionary) -> void:
	var script_id := str(c.get("script_id", ""))
	if not ScriptRegistry.registry.has(script_id):
		change_failed.emit(c, "script not in registry")
		return
	var path := str((ScriptRegistry.registry[script_id] as Dictionary).get("path", ""))
	var global_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_path):
		change_failed.emit(c, "script path missing")
		return
	var f := FileAccess.open(global_path, FileAccess.READ_WRITE)
	if f == null:
		change_failed.emit(c, "cannot open script")
		return
	f.seek_end()
	f.store_string("\n" + _build_function(c.get("function_json", {})))
	f.close()
	ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	change_applied.emit(c)

# DNA: MUTATE_NODE | auto-tag v1.6
func toggle_forge(active: bool) -> void:
	forge_active = active
	if Engine.has_singleton("LogCatcher"):
		LogCatcher.log("FORGE", "toggled", str(active))
	forge_toggled.emit(active)

# DNA: RETURN_VALUE | auto-tag v1.6
func _build_function(fn_json: Dictionary) -> String:
	var name := str(fn_json.get("name", "generated_fn"))
	return "func %s() -> void:\n\tpass\n" % name
