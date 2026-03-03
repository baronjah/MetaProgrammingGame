class_name TimeMaster
extends Node

var tracked_nodes: Array[Node] = []

# DNA: QUERY_NODE | auto-tag v1.8
func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)
	Scriptura.law_value_changed.connect(_on_law_value_changed)

# DNA: MUTATE_NODE | auto-tag v1.8
func execute_time(target: Node) -> void:
	if not tracked_nodes.has(target):
		tracked_nodes.append(target)
	var blend := Scriptura.get_law_blend("time")
	if is_equal_approx(blend, 1.0):
		entropy_forward(target)
	elif is_equal_approx(blend, 0.0):
		entropy_reverse(target)
	else:
		_apply_blended_time(target, blend)

# DNA: MUTATE_NODE | auto-tag v1.6
func entropy_forward(target: Node) -> void:
	target.process_mode = Node.PROCESS_MODE_INHERIT
	if target.has_meta("time_scale"):
		target.remove_meta("time_scale")

# DNA: MUTATE_NODE | auto-tag v1.6
func entropy_reverse(target: Node) -> void:
	target.process_mode = Node.PROCESS_MODE_DISABLED
	target.set_meta("time_scale", -1.0)

# DNA: MUTATE_NODE | auto-tag v1.8
func _apply_blended_time(target: Node, _blend: float) -> void:
	var scale := LawInterpolator.blend_float("time", 1.0, -1.0)
	target.process_mode = Node.PROCESS_MODE_INHERIT
	target.set_meta("time_scale", scale)

# DNA: RETURN_VALUE | auto-tag v1.8
func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name == "time":
		_refresh_nodes()

# DNA: RETURN_VALUE | auto-tag v1.8
func _on_law_value_changed(law_name: String, _value: float) -> void:
	if law_name == "time":
		_refresh_nodes()

# DNA: MUTATE_NODE | auto-tag v1.8
func _refresh_nodes() -> void:
	for target in tracked_nodes:
		if is_instance_valid(target):
			execute_time(target)
	Scriptura.push_message("[time_flow] refreshed tracked nodes", "TimeMaster")
