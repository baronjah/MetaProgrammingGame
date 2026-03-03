class_name LifeMaster
extends Node

var tracked_nodes: Array[Node3D] = []

# DNA: QUERY_NODE | auto-tag v1.8
func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)
	Scriptura.law_value_changed.connect(_on_law_value_changed)

# DNA: MUTATE_NODE | auto-tag v1.8
func execute_life(target: Node3D) -> void:
	if not tracked_nodes.has(target):
		tracked_nodes.append(target)
	var blend := Scriptura.get_law_blend("life")
	if is_equal_approx(blend, 1.0):
		spawn_alive(target)
	elif is_equal_approx(blend, 0.0):
		spawn_corpse(target)
	else:
		_apply_blended_life(target, blend)

# DNA: TREE_STRUCTURE | auto-tag v1.6
func spawn_alive(target: Node3D) -> void:
	target.set_meta("life_state", "alive")
	target.set_meta("is_corpse", false)

# DNA: TREE_STRUCTURE | auto-tag v1.6
func spawn_corpse(target: Node3D) -> void:
	target.set_meta("life_state", "dead")
	target.set_meta("is_corpse", true)

# DNA: MUTATE_NODE | auto-tag v1.8
func _apply_blended_life(target: Node3D, _blend: float) -> void:
	var vitality := LawInterpolator.blend_float("life", 1.0, 0.0)
	target.set_meta("vitality", vitality)
	target.set_meta("life_state", "alive" if vitality >= 0.5 else "dying")
	target.set_meta("is_corpse", vitality < 0.05)

# DNA: RETURN_VALUE | auto-tag v1.8
func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name == "life":
		_refresh_nodes()

# DNA: RETURN_VALUE | auto-tag v1.8
func _on_law_value_changed(law_name: String, _value: float) -> void:
	if law_name == "life":
		_refresh_nodes()

# DNA: MUTATE_NODE | auto-tag v1.8
func _refresh_nodes() -> void:
	for target in tracked_nodes:
		if is_instance_valid(target):
			execute_life(target)
	Scriptura.push_message("[life_state] refreshed tracked nodes", "LifeMaster")
