class_name Router
extends Node

var router_id: String = ""
var from_script: String = ""
var from_function: String = ""
var outputs: Array[Dictionary] = []

var selector_mode: String = "law"
var active_output_index: int = 0
var manual_lock_index: int = -1
var relay_mode: String = "NC"

signal output_switched(router_id: String, old_index: int, new_index: int)
signal input_received(router_id: String, args: Array)
signal all_outputs_dead(router_id: String)

# DNA: TREE_STRUCTURE | appends output route and syncs metadata
func add_output(to_script: String, to_function: String, label: String, law_binding: String, law_state: String) -> int:
	var out := {
		"id": "out_%d" % outputs.size(),
		"to_script": to_script,
		"to_function": to_function,
		"label": label,
		"law_binding": law_binding,
		"law_state": law_state,
		"active": false,
		"thread_id": "thread_%s_%s_%d" % [from_script.to_lower(), to_script.to_lower(), outputs.size()],
	}
	outputs.append(out)
	return outputs.size() - 1

# DNA: MUTATE_NODE | routes invocation through active output
func route(args: Array) -> Variant:
	LogCatcher.catch_input("router_" + router_id, args)
	input_received.emit(router_id, args)
	if relay_mode == "NO" and active_output_index == -1:
		LogCatcher.log("ROUTER", router_id, "NO relay — no active output, signal dropped")
		return null
	var target := _resolve_active_output()
	if target.is_empty():
		LogCatcher.warn("ROUTER", router_id + " — no valid output, signal lost")
		all_outputs_dead.emit(router_id)
		if Engine.has_singleton("SelfDoctor"):
			SelfDoctor._handle_issue({"type": "router_dead", "router_id": router_id})
		return null
	var target_script_id := str(target.get("to_script", ""))
	var target_func := str(target.get("to_function", ""))
	var target_instance: Object = null
	if ScriptRegistry.registry.has(target_script_id):
		var target_entry: Dictionary = ScriptRegistry.registry[target_script_id]
		target_instance = target_entry.get("instance", null)
	if target_instance == null and get_tree().current_scene:
		target_instance = get_tree().current_scene.get_node_or_null(target_script_id)
	if target_instance == null:
		return null
	var call := Callable(target_instance, target_func)
	var valve := ValveRegistry.get_valve(str(target.get("thread_id", "")))
	if valve != null:
		return valve.pass_through(args, call)
	return call.callv(args)

# DNA: QUERY_GLOBAL | resolves current route output selection
func _resolve_active_output() -> Dictionary:
	if outputs.is_empty():
		return {}
	if manual_lock_index >= 0 and manual_lock_index < outputs.size():
		return outputs[manual_lock_index]
	match selector_mode:
		"law":
			for i in range(outputs.size()):
				var o: Dictionary = outputs[i]
				if str(o.get("law_binding", "")) != "" and Scriptura.get_law(str(o.get("law_binding", ""))) == str(o.get("law_state", "")):
					if active_output_index != i:
						output_switched.emit(router_id, active_output_index, i)
						active_output_index = i
					return o
			if relay_mode == "NC":
				return outputs[0]
			return {}
		"round_robin":
			active_output_index = (active_output_index + 1) % outputs.size()
			return outputs[active_output_index]
		"first_ready":
			for o in outputs:
				var sid := str((o as Dictionary).get("to_script", ""))
				if ScriptRegistry.registry.has(sid):
					var e: Dictionary = ScriptRegistry.registry[sid]
					if e.get("instance", null) != null:
						return o
			return {}
	return {}

# DNA: MUTATE_GLOBAL | locks router to explicit output index
func lock_output(index: int) -> void:
	if index < 0 or index >= outputs.size():
		return
	manual_lock_index = index
	selector_mode = "manual"
	active_output_index = index
	LogCatcher.log("ROUTER", router_id, "locked to output " + str(index))

# DNA: MUTATE_GLOBAL | unlocks manual lock and returns to law mode
func unlock() -> void:
	manual_lock_index = -1
	selector_mode = "law"
	LogCatcher.log("ROUTER", router_id, "unlock")

# DNA: MUTATE_GLOBAL | sets relay behavior mode
func set_relay_mode(mode: String) -> void:
	if mode != "NO" and mode != "NC":
		return
	relay_mode = mode
	if relay_mode == "NO" and outputs.is_empty():
		active_output_index = -1
	LogCatcher.log("ROUTER", router_id, "relay_mode = " + mode)
