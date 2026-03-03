class_name TimelinePanel
extends Node3D

@export var timeline_id: String = "project_history"
@export var source_colors := {
	"player": Color.WHITE,
	"ai_claude": Color(0.3, 0.5, 1.0),
	"ai_codex": Color(1.0, 0.55, 0.2),
	"ai_gemini": Color(0.4, 1.0, 0.4),
	"data_bomb": Color(0.7, 0.4, 1.0),
}

var _timeline: Timeline = null

# DNA: QUERY_NODE | auto-tag v1.8
func _ready() -> void:
	_refresh_timeline_ref()
	rebuild_keyframe_dots()

# DNA: TREE_STRUCTURE | auto-tag v1.8
func rebuild_keyframe_dots() -> void:
	if _timeline == null or not has_node("KeyframeDots"):
		return
	for child in $KeyframeDots.get_children():
		child.queue_free()
	for i in range(_timeline.keyframes.size()):
		var kf := _timeline.keyframes[i]
		var dot := MeshInstance3D.new()
		dot.name = "KeyframeDot_%d" % i
		dot.mesh = SphereMesh.new()
		dot.scale = Vector3.ONE * 0.05
		dot.position = Vector3(_to_bar_x(kf.time), 0.0, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = source_colors.get(kf.source, Color.WHITE)
		dot.material_override = mat
		dot.set_meta("keyframe_index", i)
		$KeyframeDots.add_child(dot)

# DNA: MUTATE_NODE | auto-tag v1.8
func scrub_to(normalized: float) -> void:
	if _timeline == null:
		return
	var t := clamp(normalized, 0.0, 1.0) * max(_timeline.duration, 0.001)
	_timeline.scrub(t)
	_update_labels()

# DNA: RETURN_VALUE | auto-tag v1.8
func _to_bar_x(time_value: float) -> float:
	if _timeline == null or _timeline.duration <= 0.0:
		return 0.0
	return (time_value / _timeline.duration) * 2.0 - 1.0

# DNA: QUERY_NODE | auto-tag v1.8
func _refresh_timeline_ref() -> void:
	if not has_node("/root/TimelineManager"):
		return
	_timeline = TimelineManager.get_timeline(timeline_id)
	if _timeline == null and timeline_id == "project_history":
		_timeline = TimelineManager.project_history
	if _timeline != null:
		_timeline.value_changed.connect(_on_timeline_value_changed)

# DNA: MUTATE_NODE | auto-tag v1.8
func _on_timeline_value_changed(_id: String, _value: Variant) -> void:
	_update_labels()

# DNA: MUTATE_NODE | auto-tag v1.8
func _update_labels() -> void:
	if _timeline == null:
		return
	if has_node("TimeLabel"):
		$TimeLabel.text = "t=%.2f" % _timeline.current_time
	if has_node("DurationLabel"):
		$DurationLabel.text = "dur=%.2f" % _timeline.duration
