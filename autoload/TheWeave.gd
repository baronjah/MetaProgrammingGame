extends Node

var nodes: Dictionary = {}
var threads: Array[WeaveThread] = []

signal thread_activated(thread_id: String)
signal thread_deactivated(thread_id: String)
signal node_selected(script_id: String)

# DNA: RETURN_VALUE | auto-tag v1.6
func build_from_function_db() -> void:
	for t in threads:
		t.queue_free()
	threads.clear()
	for func_id in Scriptura.function_db.keys():
		var entry: Dictionary = Scriptura.function_db[func_id]
		var from_id := str(entry.get("script_id", entry.get("class_name", "")))
		var con: Dictionary = entry.get("connections", {})
		for to_id in con.keys():
			add_thread(from_id, to_id, str(entry.get("logic_A", "")), "", str(entry.get("law_binding", "")))

# DNA: TREE_STRUCTURE | auto-tag v1.6
func add_node(script_id: String, world_pos: Vector3, vessel_id: String) -> void:
	nodes[script_id] = {"world_pos": world_pos, "vessel_id": vessel_id, "active": true}

# DNA: TREE_STRUCTURE | auto-tag v1.6
func add_thread(from: String, to: String, from_func: String, to_func: String, law: String) -> void:
	if not nodes.has(from) or not nodes.has(to):
		return
	var thread := WeaveThread.new()
	thread.thread_id = "%s__%s__%d" % [from, to, threads.size()]
	thread.from_script = from
	thread.to_script = to
	thread.from_function = from_func
	thread.to_function = to_func
	thread.law_binding = law
	add_child(thread)
	var a := nodes[from]["world_pos"] as Vector3
	var b := nodes[to]["world_pos"] as Vector3
	thread.draw_bezier(a, b, a + Vector3(0, 2, 0), b + Vector3(0, 2, 0))
	var entry := _entry_for_function(from, from_func)
	if not entry.is_empty() and entry.has("dna"):
		var dna_type := _dna_enum(str((entry["dna"] as Dictionary).get("type", "UNKNOWN")))
		thread.modulate = FunctionDNA.get_color(dna_type)
	thread.set_law_color()
	threads.append(thread)

# DNA: MUTATE_NODE | auto-tag v1.6
func toggle_thread(thread_id: String) -> void:
	for t in threads:
		if t.thread_id == thread_id:
			t.set_active(not t.active)
			if t.active:
				thread_activated.emit(thread_id)
			else:
				thread_deactivated.emit(thread_id)

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func set_layer_visible(law_name: String, visible: bool) -> void:
	for t in threads:
		if t.law_binding == law_name:
			t.visible = visible

# DNA: RETURN_VALUE | auto-tag v1.6
func isolate_node(script_id: String) -> void:
	for t in threads:
		var linked := t.from_script == script_id or t.to_script == script_id
		t.modulate = Color(1, 1, 1) if linked else Color(0.2, 0.2, 0.2, 0.2)
	node_selected.emit(script_id)

# DNA: RETURN_VALUE | auto-tag v1.6
func clear_isolation() -> void:
	for t in threads:
		t.modulate = Color(1, 1, 1)

# DNA: QUERY_NODE | auto-tag v1.6
func get_threads_for_node(script_id: String) -> Array[WeaveThread]:
	return threads.filter(func(t: WeaveThread): return t.from_script == script_id or t.to_script == script_id)


# DNA: RETURN_VALUE | auto-tag v1.6
func _entry_for_function(script_id: String, func_name: String) -> Dictionary:
	for fid in Scriptura.function_db.keys():
		var e: Dictionary = Scriptura.function_db[fid]
		if str(e.get("script_id", e.get("class_name", ""))) == script_id and (str(e.get("logic_A", "")) == func_name or str(e.get("logic_B", "")) == func_name):
			return e
	return {}

# DNA: RETURN_VALUE | auto-tag v1.6
func _dna_enum(name: String) -> FunctionDNA.Type:
	if FunctionDNA.Type.has(name):
		return FunctionDNA.Type[name]
	return FunctionDNA.Type.UNKNOWN
