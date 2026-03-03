extends Node

var target_fps: float = 60.0
var budget_ms: float = 1000.0 / target_fps
var last_frame_ms: float = 0.0
var frame_overrun_count: int = 0
var frame_underrun_count: int = 0

var queues: Array[Array] = [[], [], [], [], []]
var deferred_carry: Array[Dictionary] = []
var performance_mode: String = "normal"

signal fps_target_changed(new_target: float)
signal frame_overrun(frame_ms: float, budget_ms: float)
signal frame_underrun(spare_ms: float)
signal queue_flooded(priority: int, count: int)
signal task_dropped(task: Dictionary, reason: String)

func set_target_fps(fps: float) -> void:
	target_fps = clamp(fps, 5.0, 240.0)
	budget_ms = 1000.0 / target_fps
	Engine.max_fps = int(target_fps * 1.5)
	LogCatcher.log("GOVERNOR", "fps_target", str(target_fps))
	fps_target_changed.emit(target_fps)

func set_mode(mode: String) -> void:
	performance_mode = mode
	match mode:
		"economy": set_target_fps(15)
		"turbo": set_target_fps(120)
		"simulation": set_target_fps(30)
		_: set_target_fps(60)
	if Engine.has_singleton("SelfDoctor"):
		SelfDoctor._handle_issue({"type":"fps_mode_changed","mode":mode})
	LogCatcher.log("GOVERNOR", "mode_change", mode)

func queue_task(callable: Callable, label: String, priority: int = 2, max_age: int = 10) -> void:
	var p := clamp(priority, 0, 4)
	queues[p].append({"callable": callable, "label": label, "priority": p, "max_age_frames": max_age, "age": 0})
	if queues[p].size() > 50:
		queue_flooded.emit(p, queues[p].size())
		for _i in range(min(10, queues[p].size())):
			var oldest := queues[p].pop_front()
			if p > 0:
				oldest["priority"] = p - 1
				queues[p - 1].append(oldest)

func _process(_delta: float) -> void:
	var frame_start := Time.get_ticks_usec()
	var budget_us := budget_ms * 1000.0
	for task in deferred_carry:
		task.callable.call()
	deferred_carry.clear()
	for p in range(5):
		for task in queues[p].duplicate():
			var elapsed := Time.get_ticks_usec() - frame_start
			if elapsed >= budget_us * 0.85:
				deferred_carry.append(task)
				queues[p].erase(task)
				continue
			task.age += 1
			if task.age > task.max_age_frames:
				task_dropped.emit(task, "expired")
				LogCatcher.log("GOVERNOR", "task_dropped", task.label)
				queues[p].erase(task)
				continue
			task.callable.call()
			queues[p].erase(task)
	var frame_end := Time.get_ticks_usec()
	last_frame_ms = float(frame_end - frame_start) / 1000.0
	if last_frame_ms > budget_ms:
		frame_overrun_count += 1
		frame_overrun.emit(last_frame_ms, budget_ms)
		if frame_overrun_count > 5:
			SelfDoctor._handle_issue({"type":"fps_critical","frame_ms":last_frame_ms})
			frame_overrun_count = 0
	else:
		frame_underrun_count += 1
		frame_underrun.emit(budget_ms - last_frame_ms)

func get_queue_depths() -> Array[int]:
	return [queues[0].size(), queues[1].size(), queues[2].size(), queues[3].size(), queues[4].size()]

func flush_priority(p: int) -> void:
	if p < 0 or p > 4:
		return
	queues[p].clear()
	LogCatcher.warn("GOVERNOR", "priority %d flushed" % p)
