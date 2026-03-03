extends Node

const SCRIPTURA_PATH := "res://data/scriptura.json"
const FUNCTION_DB_PATH := "res://data/function_db.json"

var current_laws: Dictionary = {}
var function_db: Dictionary = {}
var message_log: Array[Dictionary] = []
var timeline_index: int = -1

signal law_changed(law_name: String, new_state: String)
signal function_snapped(func_id: String, direction: String)

func _ready() -> void:
	load_scriptura()
	load_function_db()

func load_scriptura() -> void:
	var file := FileAccess.open(SCRIPTURA_PATH, FileAccess.READ)
	if file == null:
		push_message("Missing scriptura.json", "Scriptura")
		return
	var parsed := JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_message("Invalid scriptura.json", "Scriptura")
		return
	current_laws.clear()
	for law_name in parsed.get("laws", {}).keys():
		var law_data: Dictionary = parsed["laws"][law_name]
		current_laws[law_name] = str(law_data.get("state", "A"))

func load_function_db() -> void:
	var file := FileAccess.open(FUNCTION_DB_PATH, FileAccess.READ)
	if file == null:
		push_message("Missing function_db.json", "Scriptura")
		return
	var parsed := JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		function_db = parsed

func get_law(law_name: String) -> String:
	return str(current_laws.get(law_name, "A"))

func set_law(law_name: String, state: String) -> void:
	if state != "A" and state != "B":
		return
	current_laws[law_name] = state
	push_message("Law %s snapped to %s" % [law_name, state], "Scriptura")
	law_changed.emit(law_name, state)

func register_function(func_id: String, meta: Dictionary) -> void:
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
	meta["history"] = meta.get("history", [])
	meta["history"].append({"state": direction, "tick": Time.get_unix_time_from_system()})
	function_db[func_id] = meta
	save_function_db()
	function_snapped.emit(func_id, direction)
	return str(meta.get(direction == "A" ? "logic_A" : "logic_B", ""))

func push_message(content: String, source: String) -> void:
	message_log.append({"content": content, "source": source, "timestamp": Time.get_unix_time_from_system()})
	if message_log.size() > 10:
		message_log = message_log.slice(message_log.size() - 10)
	var tokens := parse_for_tokens(content)
	for token in tokens:
		snap_function(token)
	timeline_index = -1

func rewind_to(index: int) -> void:
	if index < 0 or index >= message_log.size():
		return
	timeline_index = index
	load_scriptura()
	for i in range(0, index + 1):
		var msg := str(message_log[i].get("content", ""))
		var tokens := parse_for_tokens(msg)
		for token in tokens:
			snap_function(token)

func parse_for_tokens(message: String) -> Array:
	var tokens: Array = []
	var reading := false
	var buffer := ""
	for i in range(message.length()):
		var ch := message[i]
		if ch == "[":
			reading = true
			buffer = ""
			continue
		if ch == "]" and reading:
			if buffer != "":
				tokens.append(buffer)
			reading = false
			buffer = ""
			continue
		if reading:
			buffer += ch
	return tokens

func save_function_db() -> void:
	var file := FileAccess.open(FUNCTION_DB_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(function_db, "\t"))
