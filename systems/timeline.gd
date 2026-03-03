class_name Timeline
extends Node

var timeline_id: String = ""
var target_type: String = ""
var target_id: String = ""
var keyframes: Array[Keyframe] = []
var current_time: float = 0.0
var duration: float = 0.0
var playing: bool = false
var loop: bool = false
var playback_speed: float = 1.0
var _last_keyframe_index: int = -1

signal playback_started(timeline_id: String)
signal playback_stopped(timeline_id: String)
signal keyframe_reached(timeline_id: String, keyframe: Keyframe)
signal timeline_completed(timeline_id: String)
signal value_changed(timeline_id: String, new_value: Variant)

# DNA: TREE_STRUCTURE | auto-tag v1.8
func add_keyframe(
	time_sec: float,
	value: Variant,
	value_type: Keyframe.ValueType,
	easing_in: Easing.Curve = Easing.Curve.EASE_IN_OUT,
	easing_out: Easing.Curve = Easing.Curve.EASE_IN_OUT,
	label: String = "",
	source: String = ""
) -> Keyframe:
	var kf := Keyframe.new()
	kf.time = max(time_sec, 0.0)
	kf.value = value
	kf.value_type = value_type
	kf.easing_in = easing_in
	kf.easing_out = easing_out
	kf.label = label
	kf.source = source
	keyframes.append(kf)
	keyframes.sort_custom(func(a: Keyframe, b: Keyframe): return a.time < b.time)
	if keyframes.size() > 0:
		duration = max(duration, keyframes[-1].time)
	if Engine.has_singleton("LogCatcher"):
		LogCatcher.log("TIMELINE", timeline_id, "keyframe added at t=%s [%s]" % [str(kf.time), label])
	return kf

# DNA: RETURN_VALUE | auto-tag v1.8
func sample(at_time: float) -> Variant:
	if keyframes.is_empty():
		return null
	if keyframes.size() == 1:
		return keyframes[0].value
	var t := max(at_time, 0.0)
	if duration > 0.0 and loop:
		t = fmod(t, duration)
	if t <= keyframes[0].time:
		return keyframes[0].value
	if t >= keyframes[-1].time:
		return keyframes[-1].value
	for i in range(keyframes.size() - 1):
		var a := keyframes[i]
		var b := keyframes[i + 1]
		if t >= a.time and t <= b.time:
			var span := max(b.time - a.time, 0.0001)
			var local_t := clamp((t - a.time) / span, 0.0, 1.0)
			return a.interpolate_to(b, local_t)
	return keyframes[-1].value

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func _process(delta: float) -> void:
	if not playing:
		return
	if keyframes.is_empty():
		playing = false
		return
	current_time += delta * playback_speed
	if duration > 0.0 and current_time >= duration:
		if loop:
			current_time = fmod(current_time, duration)
		else:
			current_time = duration
			playing = false
			timeline_completed.emit(timeline_id)
	var new_value := sample(current_time)
	value_changed.emit(timeline_id, new_value)
	_apply_to_target(new_value)
	_check_keyframe_events()

# DNA: MUTATE_NODE | auto-tag v1.8
func _apply_to_target(value: Variant) -> void:
	match target_type:
		"law":
			Scriptura.set_law_value(target_id, float(value), 0.0, false)
		"node_position":
			var node_pos = (TreeWatcher.node_registry.get(target_id, {}) as Dictionary).get("node", null)
			if node_pos != null:
				node_pos.position = value as Vector3
		"node_scale":
			var node_scale = (TreeWatcher.node_registry.get(target_id, {}) as Dictionary).get("node", null)
			if node_scale != null:
				node_scale.scale = value as Vector3
		"node_color":
			var node_color = (TreeWatcher.node_registry.get(target_id, {}) as Dictionary).get("node", null)
			if node_color is MeshInstance3D and (node_color as MeshInstance3D).material_override != null:
				(node_color as MeshInstance3D).material_override.albedo_color = value as Color
		"node_rotation":
			var node_rot = (TreeWatcher.node_registry.get(target_id, {}) as Dictionary).get("node", null)
			if node_rot != null:
				node_rot.rotation = value as Vector3

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func play(from_time: float = 0.0) -> void:
	current_time = clamp(from_time, 0.0, duration)
	playing = true
	playback_started.emit(timeline_id)

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func stop() -> void:
	playing = false
	current_time = 0.0
	playback_stopped.emit(timeline_id)

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func pause() -> void:
	playing = false
	playback_stopped.emit(timeline_id)

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func seek(to_time: float) -> void:
	current_time = clamp(to_time, 0.0, duration)
	playing = false
	var new_value := sample(current_time)
	_apply_to_target(new_value)
	value_changed.emit(timeline_id, new_value)

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func scrub(to_time: float) -> void:
	current_time = clamp(to_time, 0.0, duration)
	var new_value := sample(current_time)
	_apply_to_target(new_value)
	value_changed.emit(timeline_id, new_value)

# DNA: RETURN_VALUE | auto-tag v1.8
func save_to_json() -> Dictionary:
	var items: Array = []
	for kf in keyframes:
		items.append({
			"time": kf.time,
			"value": kf.value,
			"value_type": int(kf.value_type),
			"easing_in": int(kf.easing_in),
			"easing_out": int(kf.easing_out),
			"label": kf.label,
			"source": kf.source,
			"tags": kf.tags,
		})
	return {
		"timeline_id": timeline_id,
		"target_type": target_type,
		"target_id": target_id,
		"duration": duration,
		"loop": loop,
		"playback_speed": playback_speed,
		"keyframes": items,
	}

# DNA: TREE_STRUCTURE | auto-tag v1.8
func load_from_json(data: Dictionary) -> void:
	timeline_id = str(data.get("timeline_id", timeline_id))
	target_type = str(data.get("target_type", ""))
	target_id = str(data.get("target_id", ""))
	loop = bool(data.get("loop", false))
	playback_speed = float(data.get("playback_speed", 1.0))
	keyframes.clear()
	for item in data.get("keyframes", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		add_keyframe(
			float(item.get("time", 0.0)),
			item.get("value", 0.0),
			int(item.get("value_type", Keyframe.ValueType.FLOAT)),
			int(item.get("easing_in", Easing.Curve.EASE_IN_OUT)),
			int(item.get("easing_out", Easing.Curve.EASE_IN_OUT)),
			str(item.get("label", "")),
			str(item.get("source", ""))
		)
	duration = float(data.get("duration", duration))

# DNA: MUTATE_GLOBAL | auto-tag v1.8
func _check_keyframe_events() -> void:
	if keyframes.is_empty():
		return
	for i in range(keyframes.size()):
		if keyframes[i].time <= current_time and i > _last_keyframe_index:
			_last_keyframe_index = i
			keyframe_reached.emit(timeline_id, keyframes[i])
