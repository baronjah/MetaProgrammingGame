extends Node

var nodes: Dictionary = {}
var threads: Array[WeaveThread] = []
var vias: Array[WeaveVia] = []
var layer_config: Dictionary = {}
var layer_visibility: Dictionary = {}
var layer_spacing: float = 0.0

signal thread_activated(thread_id: String)
signal thread_deactivated(thread_id: String)
signal node_selected(script_id: String)

# DNA: READ_FILE | loads layer definitions for weave layout
func _ready() -> void:
	_load_layers()

# DNA: TREE_STRUCTURE | rebuilds graph from function db topology
func build_from_function_db() -> void:
	for t in threads:
		t.queue_free()
	threads.clear()
	for v in vias:
		v.queue_free()
	vias.clear()
	for func_id in Scriptura.function_db.keys():
		var entry: Dictionary = Scriptura.function_db[func_id]
		var from_id := str(entry.get("script_id", entry.get("class_name", "")))
		var con: Dictionary = entry.get("connections", {})
		for to_id in con.keys():
			add_thread(from_id, to_id, str(entry.get("logic_A", "")), "", str(entry.get("law_binding", "")))

# DNA: TREE_STRUCTURE | registers node with resolved layer z offset
func add_node(script_id: String, world_pos: Vector3, vessel_id: String) -> void:
	var layer_id := _resolve_layer(script_id)
	var z_offset := _get_layer_z(layer_id)
	var pos := world_pos
	pos.z += z_offset
	nodes[script_id] = {
		"world_pos": pos,
		"vessel_id": vessel_id,
		"active": true,
		"layer": layer_id,
	}
	layer_visibility[layer_id] = true

# DNA: TREE_STRUCTURE | creates weave thread and optional cross-layer via
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
		thread.set_meta("dna_type", str((entry["dna"] as Dictionary).get("type", "UNKNOWN")))
	thread.set_law_color()
	threads.append(thread)
	if int(nodes[from]["layer"]) != int(nodes[to]["layer"]):
		var via := WeaveVia.new()
		via.from_layer = int(nodes[from]["layer"])
		via.to_layer = int(nodes[to]["layer"])
		via.from_node_id = from
		via.to_node_id = to
		add_child(via)
		via.draw_via(a, b)
		vias.append(via)

# DNA: MUTATE_NODE | toggles thread active state
func toggle_thread(thread_id: String) -> void:
	for t in threads:
		if t.thread_id == thread_id:
			t.set_active(not t.active)
			if t.active:
				thread_activated.emit(thread_id)
			else:
				thread_deactivated.emit(thread_id)

# DNA: MUTATE_NODE | visibility control for law or layer labels
func set_layer_visible(layer_name_or_id: Variant, visible: bool) -> void:
	if layer_name_or_id is String and str(layer_name_or_id).begins_with("manual_override_"):
		for t in threads:
			if t.thread_id.find(str(layer_name_or_id).trim_prefix("manual_override_")) != -1:
				t.visible = visible
		return
	var layer_id := int(layer_name_or_id)
	layer_visibility[layer_id] = visible
	for script_id in nodes.keys():
		if int((nodes[script_id] as Dictionary).get("layer", -1)) == layer_id:
			(nodes[script_id] as Dictionary)["active"] = visible
	for t in threads:
		var from_layer := int((nodes.get(t.from_script, {}) as Dictionary).get("layer", -1))
		var to_layer := int((nodes.get(t.to_script, {}) as Dictionary).get("layer", -1))
		if from_layer == layer_id and to_layer == layer_id:
			t.visible = visible
		elif from_layer == layer_id or to_layer == layer_id:
			t.modulate.a = 0.3
	for via in vias:
		if via.from_layer == layer_id or via.to_layer == layer_id:
			via.modulate.a = 0.3

# DNA: MUTATE_NODE | isolate one layer and hide others
func isolate_layer(layer_id: int) -> void:
	for lid in layer_config.keys():
		set_layer_visible(int(lid), int(lid) == layer_id)
	for script_id in nodes.keys():
		if int((nodes[script_id] as Dictionary).get("layer", -1)) == layer_id:
			var pos := (nodes[script_id] as Dictionary).get("world_pos", Vector3.ZERO) as Vector3
			pos.z = 0.0
			(nodes[script_id] as Dictionary)["world_pos"] = pos

# DNA: MUTATE_NODE | restores all layer visibility and z offsets
func restore_all_layers() -> void:
	for lid in layer_config.keys():
		set_layer_visible(int(lid), true)
	for script_id in nodes.keys():
		var lid := int((nodes[script_id] as Dictionary).get("layer", 0))
		var pos := (nodes[script_id] as Dictionary).get("world_pos", Vector3.ZERO) as Vector3
		pos.z = _get_layer_z(lid)
		(nodes[script_id] as Dictionary)["world_pos"] = pos

# DNA: MUTATE_NODE | pulls specific layer toward camera by amount
func pull_layer_forward(layer_id: int, amount: float) -> void:
	for script_id in nodes.keys():
		if int((nodes[script_id] as Dictionary).get("layer", -1)) != layer_id:
			continue
		var pos := (nodes[script_id] as Dictionary).get("world_pos", Vector3.ZERO) as Vector3
		pos.z = _get_layer_z(layer_id) - amount
		(nodes[script_id] as Dictionary)["world_pos"] = pos

# DNA: MUTATE_GLOBAL | adjusts layer spacing and reapplies z offsets
func set_layer_spacing(spacing: float) -> void:
	layer_spacing = spacing
	for lid in layer_config.keys():
		(layer_config[lid] as Dictionary)["z_offset"] = float((layer_config[lid] as Dictionary).get("id", 0)) * spacing
	restore_all_layers()

# DNA: MUTATE_NODE | dims graph except selected node connections
func isolate_node(script_id: String) -> void:
	for t in threads:
		var linked := t.from_script == script_id or t.to_script == script_id
		t.modulate = Color(1, 1, 1) if linked else Color(0.2, 0.2, 0.2, 0.2)
	node_selected.emit(script_id)

# DNA: MUTATE_NODE | clears node isolation dimming
func clear_isolation() -> void:
	for t in threads:
		t.modulate = Color(1, 1, 1)

# DNA: QUERY_GLOBAL | returns threads connected to node
func get_threads_for_node(script_id: String) -> Array[WeaveThread]:
	return threads.filter(func(t: WeaveThread): return t.from_script == script_id or t.to_script == script_id)

# DNA: READ_FILE | parse weave layer json
func _load_layers() -> void:
	var file := FileAccess.open("res://data/weave_layers.json", FileAccess.READ)
	if file == null:
		return
	var parsed := JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	layer_config = parsed.get("layers", {})
	for lid in layer_config.keys():
		layer_visibility[int(lid)] = bool((layer_config[lid] as Dictionary).get("visible", true))

# DNA: QUERY_GLOBAL | resolve layer assignment from script and dna
func _resolve_layer(script_id: String) -> int:
	if script_id.to_lower().contains("router"):
		return 4
	if ScriptRegistry.registry.has(script_id):
		var entry: Dictionary = ScriptRegistry.registry[script_id]
		if entry.has("weave_layer"):
			return int(entry.get("weave_layer", 0))
		var stype := str(entry.get("type", ""))
		if stype == "autoload":
			return 0
		if stype == "class_named":
			return 1
		if stype == "scene_script":
			return 2
	var dna := _dominant_dna(script_id)
	if dna in ["CREATE_FILE", "READ_FILE", "WRITE_RESOURCE"]:
		return 3
	return 1

# DNA: QUERY_GLOBAL | returns layer z offset from config
func _get_layer_z(layer_id: int) -> float:
	if layer_config.has(str(layer_id)):
		return float((layer_config[str(layer_id)] as Dictionary).get("z_offset", 0.0))
	return float(layer_id) * 4.0

# DNA: QUERY_GLOBAL | infer dominant dna type for script
func _dominant_dna(script_id: String) -> String:
	for fid in Scriptura.function_db.keys():
		var e: Dictionary = Scriptura.function_db[fid]
		if str(e.get("script_id", e.get("class_name", ""))) != script_id:
			continue
		if e.has("dna"):
			return str((e["dna"] as Dictionary).get("type", "UNKNOWN"))
	return "UNKNOWN"

# DNA: QUERY_GLOBAL | lookup function entry for script/function
func _entry_for_function(script_id: String, func_name: String) -> Dictionary:
	for fid in Scriptura.function_db.keys():
		var e: Dictionary = Scriptura.function_db[fid]
		if str(e.get("script_id", e.get("class_name", ""))) == script_id and (str(e.get("logic_A", "")) == func_name or str(e.get("logic_B", "")) == func_name):
			return e
	return {}

# DNA: RETURN_VALUE | convert dna string to enum
func _dna_enum(name: String) -> FunctionDNA.Type:
	if FunctionDNA.Type.has(name):
		return FunctionDNA.Type[name]
	return FunctionDNA.Type.UNKNOWN
