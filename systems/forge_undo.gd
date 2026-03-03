class_name ForgeUndo
extends Node

var hot_stack: Array[Dictionary] = []
var cold_stack: Array[Dictionary] = []
const COLD_PATH := "user://forge_undo_cold.json"

# DNA: QUERY_NODE | auto-tag v1.6
func _ready() -> void:
	_load_cold()

# DNA: RETURN_VALUE | auto-tag v1.6
func push_inverse(original: Dictionary) -> void:
	var inverse := _inverse_of(original)
	if inverse.is_empty():
		return
	hot_stack.append(inverse)
	if hot_stack.size() > 50:
		var oldest := hot_stack.pop_front()
		cold_stack.append(oldest)
		if Engine.has_singleton("FrameGovernor"):
			FrameGovernor.queue_task(_save_cold, "save_cold_undo", 4, 60)
		else:
			_save_cold()
		if Engine.has_singleton("LogCatcher"):
			LogCatcher.warn("FORGE", "Undo hot stack full, moved oldest to cold storage")

# DNA: RETURN_VALUE | auto-tag v1.6
func pop_and_apply() -> void:
	if not hot_stack.is_empty():
		LiveForge.queue_change(hot_stack.pop_back())
		return
	if not cold_stack.is_empty():
		var task := cold_stack.pop_back()
		LiveForge.queue_change(task)
		_save_cold()
		if Engine.has_singleton("LogCatcher"):
			LogCatcher.log("FORGE", "undo_from_cold", "applied from disk-backed stack")

# DNA: RETURN_VALUE | auto-tag v1.6
func _inverse_of(change: Dictionary) -> Dictionary:
	var ctype := str(change.get("type", ""))
	match ctype:
		"law_flip":
			return {"type": "law_flip", "law": change.get("law", ""), "to": "A" if str(change.get("to", "A")) == "B" else "B"}
		"thread_create":
			return {"type": "thread_remove", "thread_id": change.get("thread_id", "")}
		"thread_remove":
			return {
				"type": "thread_create",
				"from_script": change.get("from_script", ""),
				"from_func": change.get("from_func", ""),
				"to_script": change.get("to_script", ""),
				"to_func": change.get("to_func", ""),
			}
		"node_reparent":
			return {"type": "node_reparent", "node_path": change.get("node_path", ""), "new_parent_path": change.get("old_parent_path", "")}
		_:
			return {}

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func _save_cold() -> void:
	var f := FileAccess.open(COLD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cold_stack))

# DNA: TREE_STRUCTURE | auto-tag v1.6
func _load_cold() -> void:
	if not FileAccess.file_exists(COLD_PATH):
		return
	var parsed := JSON.parse_string(FileAccess.get_file_as_string(COLD_PATH))
	if typeof(parsed) == TYPE_ARRAY:
		cold_stack = parsed
