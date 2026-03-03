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
signal function_snapped(func_id: String, direction: String)

func _ready() -> void:
	load_scriptura()
	load_function_db()

func load_scriptura() -> void:
	var parsed := _load_json_file(SCRIPTURA_PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_message("Invalid scriptura.json", "Scriptura")
		return
	law_catalog = parsed.get("laws", {})
	current_laws.clear()
	for law_name in law_catalog.keys():
		var law_data: Dictionary = law_catalog[law_name]
		current_laws[law_name] = str(law_data.get("state", "A"))

func get_law(law_name: String) -> String:
	return str(current_laws.get(law_name, "A"))

func set_law(law_name: String, state: String, log_event: bool = true) -> void:
	if state != "A" and state != "B":
		return
	current_laws[law_name] = state
	if law_catalog.has(law_name):
		law_catalog[law_name]["state"] = state
	save_scriptura()
	if log_event:
		push_message("[LAW:%s=%s]" % [law_name, state], "Scriptura")
	law_changed.emit(law_name, state)

func load_function_db() -> void:
	var parsed := _load_json_file(FUNCTION_DB_PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_message("Invalid function_db.json", "Scriptura")
		return
	function_db = parsed

func register_function(func_id: String, meta: Dictionary) -> void:
	if not meta.has("logic_A"):
		meta["logic_A"] = "noop_A"
	if not meta.has("logic_B"):
		meta["logic_B"] = "noop_B"
	if not meta.has("history"):
		meta["history"] = []
	function_db[func_id] = meta
	save_function_db()

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

func rewind_to(index: int) -> void:
	if index < 0 or index >= message_log.size():
		return
	timeline_index = index
	load_scriptura()
	for i in range(0, index + 1):
		var content := str(message_log[i].get("content", ""))
		for law_change in _parse_law_changes(content):
			current_laws[str(law_change["law"])] = str(law_change["state"])
		for token in parse_for_tokens(content):
			snap_function(token)

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

func save_scriptura() -> void:
	var payload := {
		"version": "1.0",
		"connection_points": ["Scriptura", "ConsciousnessBridge"],
		"laws": law_catalog,
	}
	var file := FileAccess.open(SCRIPTURA_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))

func save_function_db() -> void:
	var file := FileAccess.open(FUNCTION_DB_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(function_db, "\t"))

func _load_json_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_message("Missing file: %s" % path, "Scriptura")
		return {}
	return JSON.parse_string(file.get_as_text())

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
