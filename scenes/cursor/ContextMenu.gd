class_name ContextMenu
extends Node3D

const ACTIONS_PATH := "res://data/context_actions.json"

var action_map: Dictionary = {}

# DNA: QUERY_NODE | auto-tag v1.6
func _ready() -> void:
	load_actions()

# DNA: TREE_STRUCTURE | auto-tag v1.6
func load_actions() -> void:
	var file := FileAccess.open(ACTIONS_PATH, FileAccess.READ)
	if file == null:
		action_map = {}
		return
	var parsed := JSON.parse_string(file.get_as_text())
	action_map = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

# DNA: RETURN_VALUE | auto-tag v1.6
func show_for_target(target_type: String, world_pos: Vector3) -> void:
	global_position = world_pos
	for c in get_children():
		c.queue_free()
	var actions: Array = action_map.get(target_type, [])
	for i in range(actions.size()):
		var option := MeshInstance3D.new()
		option.mesh = PlaneMesh.new()
		option.position = Vector3(cos(float(i)) * 0.6, sin(float(i)) * 0.3, 0)
		option.set_meta("interactive", true)
		option.set_meta("action_id", actions[i])
		var label := Label3D.new()
		label.text = str(actions[i])
		option.add_child(label)
		add_child(option)
