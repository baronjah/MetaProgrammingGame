class_name TimeMaster
extends Node

var tracked_nodes: Array[Node] = []

# DNA: QUERY_NODE | auto-tag v1.6
func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)

# DNA: RETURN_VALUE | auto-tag v1.6
func execute_time(target: Node) -> void:
	if not tracked_nodes.has(target):
		tracked_nodes.append(target)
	match Scriptura.get_law("time"):
		"A": entropy_forward(target)
		"B": entropy_reverse(target)
		_: entropy_forward(target)

# DNA: RETURN_VALUE | auto-tag v1.6
func entropy_forward(target: Node) -> void:
	target.process_mode = Node.PROCESS_MODE_INHERIT

# DNA: RETURN_VALUE | auto-tag v1.6
func entropy_reverse(target: Node) -> void:
	target.process_mode = Node.PROCESS_MODE_DISABLED

# DNA: RETURN_VALUE | auto-tag v1.6
func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name != "time":
		return
	for target in tracked_nodes:
		if is_instance_valid(target):
			execute_time(target)
	Scriptura.push_message("[time_flow] refreshed tracked nodes", "TimeMaster")
