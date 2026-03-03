extends Node

var valves: Dictionary = {}

signal any_valve_closed(valve_id: String, reason: String)
signal any_deviation(valve_id: String, expected: Variant, actual: Variant)

func create_valve(thread_id: String, from_script: String, from_func: String, to_script: String, to_func: String) -> Valve:
	var valve := Valve.new()
	valve.valve_id = "valve_%s" % thread_id
	valve.thread_id = thread_id
	valve.from_script = from_script
	valve.from_function = from_func
	valve.to_script = to_script
	valve.to_function = to_func
	add_child(valve)
	valves[valve.valve_id] = valve
	valve.valve_closed.connect(_on_valve_closed)
	valve.deviation_detected.connect(_on_deviation)
	if Engine.has_singleton("SelfDoctor"):
		valve.fail_threshold_reached.connect(SelfDoctor._on_valve_fail_threshold)
		valve.deviation_detected.connect(SelfDoctor._on_valve_deviation)
	_register_connection_valve(from_script, to_script, valve.valve_id)
	return valve

func get_valve(thread_id: String) -> Valve:
	var key := "valve_%s" % thread_id
	return valves.get(key, null)

func close_all() -> void:
	for valve in valves.values():
		(valve as Valve).close_valve("registry_close_all")

func open_all() -> void:
	for valve in valves.values():
		(valve as Valve).open_valve()

func get_closed_valves() -> Array[Valve]:
	var out: Array[Valve] = []
	for valve in valves.values():
		if not (valve as Valve).open:
			out.append(valve)
	return out

func get_failing_valves() -> Array[Valve]:
	var out: Array[Valve] = []
	for valve in valves.values():
		if (valve as Valve).consecutive_fails > 0:
			out.append(valve)
	return out

func set_all_capture(enabled: bool) -> void:
	for valve in valves.values():
		(valve as Valve).capture_enabled = enabled

func _register_connection_valve(from_script: String, to_script: String, valve_id: String) -> void:
	for func_id in Scriptura.function_db.keys():
		var entry: Dictionary = Scriptura.function_db[func_id]
		if str(entry.get("script_id", entry.get("class_name", ""))) != from_script:
			continue
		var con: Dictionary = entry.get("connections", {})
		if not con.has(to_script):
			continue
		con[to_script]["valve_id"] = valve_id
		con[to_script]["valve_state"] = "open"
		con[to_script]["throttle_ms"] = 0
		con[to_script]["capture_enabled"] = false
		con[to_script]["active_version"] = "A"
		entry["connections"] = con
		Scriptura.function_db[func_id] = entry
	Scriptura.save_function_db()

func _on_valve_closed(valve_id: String, reason: String) -> void:
	any_valve_closed.emit(valve_id, reason)

func _on_deviation(valve_id: String, expected: Variant, actual: Variant) -> void:
	any_deviation.emit(valve_id, expected, actual)
