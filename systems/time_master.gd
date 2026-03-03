class_name TimeMaster
extends Node

func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)

func execute_time(target: Node) -> void:
	match Scriptura.get_law("time"):
		"A": entropy_forward(target)
		"B": entropy_reverse(target)
		_: entropy_forward(target)

func entropy_forward(target: Node) -> void:
	target.process_mode = Node.PROCESS_MODE_INHERIT

func entropy_reverse(target: Node) -> void:
	target.process_mode = Node.PROCESS_MODE_DISABLED

func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name == "time":
		Scriptura.push_message("time_flow live-updated", "TimeMaster")
