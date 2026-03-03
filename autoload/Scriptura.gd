extends Node

const SCRIPTURA_PATH := "res://data/scriptura.json"
const FUNCTION_DB_PATH := "res://data/function_db.json"
const MAX_LOG_ENTRIES := 10

var current_laws: Dictionary = {}
var law_catalog: Dictionary = {}
var function_db: Dictionary = {}
var message_log: Array[Dictionary] = []
var timeline_index: int = -1

signal law_changed(law_name: String, new_state: String)
signal law_value_changed(law_name: String, value: float)
signal function_snapped(func_id: String, direction: String)

# DNA: QUERY_NODE | auto-tag v1.8
func _ready() -> void:
	load_scriptura()
	load_function_db()

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func _process(delta: float) -> void:
	var any_changed := false
	for law_name in current_laws.keys():
		var law := current_laws[law_name] as Dictionary
		var value := float(law.get("value", _state_to_value(str(law.get("state", "A")))))
		var target := float(law.get("target_value", value))
		if is_equal_approx(value, target):
			continue
		var speed := max(float(law.get("value_speed", 0.0)), 0.0)
		if speed <= 0.0:
			value = target
		else:
			value = move_toward(value, target, speed * delta)
		law["value"] = value
		var new_state := "A" if value >= 0.0 else "B"
		if str(law.get("state", "A")) != new_state:
			law["state"] = new_state
			law_changed.emit(law_name, new_state)
		law_catalog[law_name] = law
		current_laws[law_name] = law
		law_value_changed.emit(law_name, value)
		any_changed = true
	if any_changed:
		save_scriptura()

# DNA: TREE_STRUCTURE | auto-tag v1.8
func load_scriptura() -> void:
	var parsed := _load_json_file(SCRIPTURA_PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_message("Invalid scriptura.json", "Scriptura")
		return
	law_catalog = parsed.get("laws", {})
	current_laws.clear()
	for law_name in law_catalog.keys():
		var law_data := (law_catalog[law_name] as Dictionary).duplicate(true)
		var state := str(law_data.get("state", "A"))
		if state != "A" and state != "B":
			state = "A"
		var value := float(law_data.get("value", _state_to_value(state)))
		law_data["state"] = state
		law_data["value"] = clamp(value, -1.0, 1.0)
		law_data["target_value"] = clamp(float(law_data.get("target_value", value)), -1.0, 1.0)
		law_data["value_speed"] = max(float(law_data.get("value_speed", 0.0)), 0.0)
		current_laws[law_name] = law_data
		law_catalog[law_name] = law_data

# DNA: QUERY_NODE | auto-tag v1.8
func get_law(law_name: String) -> String:
	var law := current_laws.get(law_name, {"state": "A"}) as Dictionary
	return str(law.get("state", "A"))

# DNA: QUERY_NODE | auto-tag v1.8
func get_law_value(law_name: String) -> float:
	if current_laws.has(law_name):
		var law := current_laws[law_name] as Dictionary
		return float(law.get("value", _state_to_value(str(law.get("state", "A")))))
	return 1.0 if get_law(law_name) == "A" else -1.0

# DNA: RETURN_VALUE | auto-tag v1.8
func get_law_blend(law_name: String) -> float:
	return clamp((get_law_value(law_name) + 1.0) * 0.5, 0.0, 1.0)

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func set_law(law_name: String, state: String, log_event: bool = true) -> void:
	if state != "A" and state != "B":
		return
	var target_value := 1.0 if state == "A" else -1.0
	set_law_value(law_name, target_value, 0.0, log_event)

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func set_law_value(law_name: String, target: float, speed: float = 0.0, log_event: bool = true) -> void:
	if not current_laws.has(law_name):
		current_laws[law_name] = {"state": "A", "A": "A", "B": "B", "value": 1.0, "target_value": 1.0, "value_speed": 0.0}
	var law := current_laws[law_name] as Dictionary
	var previous_state := str(law.get("state", "A"))
	law["target_value"] = clamp(target, -1.0, 1.0)
	law["value_speed"] = max(speed, 0.0)
	if speed <= 0.0:
		law["value"] = law["target_value"]
	var value := float(law.get("value", law["target_value"]))
	var new_state := "A" if value >= 0.0 else "B"
	law["state"] = new_state
	current_laws[law_name] = law
	law_catalog[law_name] = law
	save_scriptura()
	if log_event:
		push_message("[LAW_VALUE:%s=%.3f]" % [law_name, float(law["target_value"])], "Scriptura")
	if new_state != previous_state:
		law_changed.emit(law_name, new_state)
	law_value_changed.emit(law_name, float(law.get("value", law["target_value"])))
	if has_node("/root/TimelineManager"):
		TimelineManager.record_project_event("law_value:" + law_name, "ai_codex", export_state_snapshot())

# DNA: TREE_STRUCTURE | auto-tag v1.6
func load_function_db() -> void:
	var parsed := _load_json_file(FUNCTION_DB_PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_message("Invalid function_db.json", "Scriptura")
		return
	function_db = parsed

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func register_function(func_id: String, meta: Dictionary) -> void:
	if not meta.has("logic_A"):
		meta["logic_A"] = "noop_A"
	if not meta.has("logic_B"):
		meta["logic_B"] = "noop_B"
	if not meta.has("history"):
		meta["history"] = []
	function_db[func_id] = meta
	save_function_db()

# DNA: RETURN_VALUE | auto-tag v1.6
func snap_function(func_id: String) -> String:
	if not function_db.has(func_id):
		push_message("Unknown function token: %s" % func_id, "Scriptura")
		return ""
	var meta: Dictionary = function_db[func_id]
	var law_name := str(meta.get("law_binding", ""))
	var direction := get_law(law_name)
	meta["active_state"] = direction
	if not meta.has("history"):
		meta["history"] = []
	meta["history"].append({"state": direction, "tick": Time.get_unix_time_from_system()})
	function_db[func_id] = meta
	save_function_db()
	function_snapped.emit(func_id, direction)
	return str(meta.get(direction == "A" ? "logic_A" : "logic_B", ""))

# DNA: RETURN_VALUE | auto-tag v1.6
func push_message(content: String, source: String) -> void:
	message_log.append({
		"content": content,
		"source": source,
		"timestamp": Time.get_unix_time_from_system(),
	})
	if message_log.size() > MAX_LOG_ENTRIES:
		message_log = message_log.slice(message_log.size() - MAX_LOG_ENTRIES, message_log.size())
	for token in parse_for_tokens(content):
		snap_function(token)
	for law_change in _parse_law_changes(content):
		set_law(str(law_change["law"]), str(law_change["state"]), false)
	timeline_index = -1

# DNA: RETURN_VALUE | auto-tag v1.6
func rewind_to(index: int) -> void:
	if index < 0 or index >= message_log.size():
		return
	timeline_index = index
	load_scriptura()
	for i in range(0, index + 1):
		var content := str(message_log[i].get("content", ""))
		for law_change in _parse_law_changes(content):
			set_law(str(law_change["law"]), str(law_change["state"]), false)
		for token in parse_for_tokens(content):
			snap_function(token)

# DNA: RETURN_VALUE | auto-tag v1.6
func parse_for_tokens(message: String) -> Array:
	var tokens: Array = []
	var is_reading := false
	var buffer := ""
	for i in range(message.length()):
		var ch := message[i]
		if ch == "[":
			is_reading = true
			buffer = ""
			continue
		if ch == "]" and is_reading:
			if buffer != "" and not buffer.begins_with("LAW:"):
				tokens.append(buffer)
			is_reading = false
			buffer = ""
			continue
		if is_reading:
			buffer += ch
	return tokens

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func save_scriptura() -> void:
	var payload := {
		"version": "1.1",
		"connection_points": ["Scriptura", "ConsciousnessBridge"],
		"laws": law_catalog,
	}
	var file := FileAccess.open(SCRIPTURA_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func save_function_db() -> void:
	var file := FileAccess.open(FUNCTION_DB_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(function_db, "\t"))

# DNA: TREE_STRUCTURE | auto-tag v1.6
func _load_json_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_message("Missing file: %s" % path, "Scriptura")
		return {}
	return JSON.parse_string(file.get_as_text())

# DNA: RETURN_VALUE | auto-tag v1.8
func export_state_snapshot() -> Dictionary:
	return {
		"version": "1.1",
		"connection_points": ["Scriptura", "ConsciousnessBridge"],
		"laws": law_catalog.duplicate(true),
	}

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func import_state_snapshot(snapshot: Dictionary) -> void:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return
	law_catalog = (snapshot.get("laws", {}) as Dictionary).duplicate(true)
	current_laws.clear()
	for law_name in law_catalog.keys():
		current_laws[law_name] = (law_catalog[law_name] as Dictionary).duplicate(true)
	save_scriptura()

# DNA: RETURN_VALUE | auto-tag v1.8
func _state_to_value(state: String) -> float:
	return 1.0 if state == "A" else -1.0

# DNA: RETURN_VALUE | auto-tag v1.6
func _parse_law_changes(message: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for token in _parse_raw_brackets(message):
		if token.begins_with("LAW:") and token.contains("="):
			var parts := token.trim_prefix("LAW:").split("=", false, 1)
			if parts.size() == 2:
				var law_name := parts[0]
				var state := parts[1]
				if state == "A" or state == "B":
					result.append({"law": law_name, "state": state})
	return result

# DNA: RETURN_VALUE | auto-tag v1.6
func _parse_raw_brackets(message: String) -> Array[String]:
	var result: Array[String] = []
	var is_reading := false
	var buffer := ""
	for i in range(message.length()):
		var ch := message[i]
		if ch == "[":
			is_reading = true
			buffer = ""
			continue
		if ch == "]" and is_reading:
			if buffer != "":
				result.append(buffer)
			is_reading = false
			buffer = ""
			continue
		if is_reading:
			buffer += ch
	return result
