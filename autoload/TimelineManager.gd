extends Node

const HISTORY_EXPORT_DEFAULT := "user://timeline_history.json"

var timelines: Dictionary = {}
var project_history: Timeline = null

signal project_rewound(time: float)

# DNA: QUERY_NODE | auto-tag v1.8
func _ready() -> void:
	project_history = create_timeline("project_version", "project_state")
	project_history.timeline_id = "project_history"
	project_history.target_type = "project_version"
	project_history.target_id = "project_state"
	if project_history.keyframes.is_empty():
		record_project_event("initial_state", "ai_codex", Scriptura.export_state_snapshot())

# DNA: TREE_STRUCTURE | auto-tag v1.8
func create_timeline(target_type: String, target_id: String) -> Timeline:
	var id := "%s__%s" % [target_type, target_id]
	if timelines.has(id):
		return timelines[id] as Timeline
	var timeline := Timeline.new()
	timeline.timeline_id = id
	timeline.target_type = target_type
	timeline.target_id = target_id
	add_child(timeline)
	timelines[id] = timeline
	return timeline

# DNA: QUERY_NODE | auto-tag v1.8
func get_timeline(timeline_id: String) -> Timeline:
	return timelines.get(timeline_id, null) as Timeline

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func play_all() -> void:
	for id in timelines.keys():
		if id == "project_history":
			continue
		(timelines[id] as Timeline).play()

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func stop_all() -> void:
	for timeline in timelines.values():
		(timeline as Timeline).stop()

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func pause_all() -> void:
	for timeline in timelines.values():
		(timeline as Timeline).pause()

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func record_project_event(label: String, source: String, state_snapshot: Dictionary) -> void:
	if project_history == null:
		return
	var t := project_history.duration
	if project_history.keyframes.size() > 0:
		t = max(project_history.duration, project_history.current_time)
	project_history.add_keyframe(
		t,
		state_snapshot,
		Keyframe.ValueType.DICTIONARY,
		Easing.Curve.STEP,
		Easing.Curve.STEP,
		label,
		source
	)
	project_history.duration = max(project_history.duration, t)

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func rewind_project_to(time: float) -> void:
	if project_history == null:
		return
	project_history.seek(time)
	var snapshot := project_history.sample(time)
	if typeof(snapshot) == TYPE_DICTIONARY:
		Scriptura.import_state_snapshot(snapshot as Dictionary)
	project_rewound.emit(time)

# DNA: CREATE_FILE | auto-tag v1.8
func export_history(path: String = HISTORY_EXPORT_DEFAULT) -> void:
	if project_history == null:
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(project_history.save_to_json(), "\t"))
