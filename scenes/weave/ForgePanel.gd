class_name ForgePanel
extends Node3D

var history: Array[Dictionary] = []

# DNA: QUERY_NODE | auto-tag v1.6
func _ready() -> void:
	LiveForge.change_applied.connect(_on_change_applied)
	_update_queue_label()

# DNA: QUERY_NODE | auto-tag v1.6
func _process(_delta: float) -> void:
	_update_queue_label()

# DNA: MUTATE_NODE | auto-tag v1.6
func toggle_forge() -> void:
	LiveForge.toggle_forge(not LiveForge.forge_active)

# DNA: MUTATE_NODE | auto-tag v1.6
func apply_all() -> void:
	while LiveForge.change_queue.size() > 0:
		LiveForge._apply(LiveForge.change_queue.pop_front())

# DNA: RETURN_VALUE | auto-tag v1.6
func undo_last() -> void:
	ForgeUndo.pop_and_apply()

# DNA: RETURN_VALUE | auto-tag v1.6
func _on_change_applied(change: Dictionary) -> void:
	history.append(change)
	if history.size() > 10:
		history.pop_front()
	ForgeUndo.push_inverse(change)

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func _update_queue_label() -> void:
	if has_node("QueueLabel"):
		$QueueLabel.text = "Queue: %d" % LiveForge.change_queue.size()
