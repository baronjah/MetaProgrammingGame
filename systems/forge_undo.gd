class_name ForgeUndo
extends Node

var stack: Array[Dictionary] = []

func push_inverse(original: Dictionary) -> void:
	var inverse := _inverse_of(original)
	if inverse.is_empty():
		return
	stack.append(inverse)
	if stack.size() > 50:
		stack.pop_front()
		if Engine.has_singleton("LogCatcher"):
			LogCatcher.warn("FORGE", "Undo stack full, dropped oldest entry")

func pop_and_apply() -> void:
	if stack.is_empty():
		return
	LiveForge.queue_change(stack.pop_back())

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
