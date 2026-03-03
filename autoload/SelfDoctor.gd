extends Node

enum Mode { OBSERVE, ASSIST, AUTONOMOUS }

var mode: Mode = Mode.ASSIST
var diagnosis_log: Array[Dictionary] = []
var known_issues: Dictionary = {}
var repair_queue: Array[Dictionary] = []

signal issue_detected(issue: Dictionary)
signal repair_applied(issue_id: String, action: String)
signal repair_pending(issue: Dictionary)
signal system_healthy()
signal entering_safe_mode()

func _ready() -> void:
	if Engine.has_singleton("ValveRegistry"):
		ValveRegistry.any_valve_closed.connect(_on_any_valve_closed)
		ValveRegistry.any_deviation.connect(_on_any_deviation)
	if Engine.has_singleton("ThreadSupervisor") and ThreadSupervisor.has_signal("deadlock_detected"):
		ThreadSupervisor.deadlock_detected.connect(_on_deadlock)
	if Engine.has_singleton("TreeWatcher"):
		get_tree().node_removed.connect(_on_node_removed)
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(_run_diagnostics)
	add_child(timer)

func _run_diagnostics() -> void:
	for script_id in ScriptRegistry.registry.keys():
		var entry: Dictionary = ScriptRegistry.registry[script_id]
		if bool(entry.get("loaded", false)) and not _is_live(script_id):
			_handle_issue({"type":"script_missing","script_id":script_id})
	for thread_id in ThreadSupervisor.active_threads.keys():
		var t: Dictionary = ThreadSupervisor.active_threads[thread_id]
		if (Time.get_ticks_msec()/1000.0 - float(t.get("started_at", 0.0))) > 10.0:
			_handle_issue({"type":"thread_deadlock","thread_id":thread_id})
	for valve in ValveRegistry.get_failing_valves():
		if valve.consecutive_fails > 2:
			_handle_issue({"type":"valve_closed_by_fails","valve_id":valve.valve_id})
	if OS.get_static_memory_usage() > 256 * 1024 * 1024:
		_handle_issue({"type":"memory_high","bytes":OS.get_static_memory_usage()})
	if diagnosis_log.is_empty():
		system_healthy.emit()

func _handle_issue(issue: Dictionary) -> void:
	_log_issue(issue)
	match mode:
		Mode.OBSERVE:
			pass
		Mode.ASSIST:
			repair_queue.append(issue)
			repair_pending.emit(issue)
		Mode.AUTONOMOUS:
			_apply_repair(issue)

func _apply_repair(issue: Dictionary) -> void:
	var issue_type := str(issue.get("type", ""))
	match issue_type:
		"valve_closed_by_fails":
			var valve := ValveRegistry.valves.get(str(issue.get("valve_id", "")), null)
			if valve:
				valve.select_version("B" if valve.active_version == "A" else "A")
				LiveForge.queue_change({"type":"law_flip","law":"time","to":"B"})
				repair_applied.emit(str(issue.get("id", "")), "switch_version")
		"null_ref_in_ready":
			LiveForge.queue_change({"type":"node_defer_ready","node_path":issue.get("node_path","")})
			repair_applied.emit(str(issue.get("id", "")), "defer_ready")
		"thread_deadlock":
			if ThreadSupervisor.has_method("force_release_all"):
				ThreadSupervisor.force_release_all(str(issue.get("thread_id", "")))
			repair_applied.emit(str(issue.get("id", "")), "force_release")
		"node_path_broken":
			LiveForge.queue_change({"type":"connection_rewire","script_id":issue.get("script_id","")})
			repair_applied.emit(str(issue.get("id", "")), "rewire")
		"fps_critical":
			ValveRegistry.set_all_capture(false)
			if Engine.has_singleton("FrameGovernor"):
				FrameGovernor.set_target_fps(15)
			repair_applied.emit(str(issue.get("id", "")), "fps_reduction")
		_:
			pass

func confirm_repair(issue_id: String) -> void:
	for issue in repair_queue:
		if str(issue.get("id", "")) == issue_id:
			_apply_repair(issue)
			repair_queue.erase(issue)
			return

func reject_repair(issue_id: String) -> void:
	for issue in repair_queue:
		if str(issue.get("id", "")) == issue_id:
			known_issues[issue_id] = {"status":"player_rejected","issue":issue}
			repair_queue.erase(issue)
			return

func soft_restart() -> void:
	LogCatcher.log("DOCTOR", "soft_restart", "initiated")
	entering_safe_mode.emit()
	ValveRegistry.close_all()
	Scriptura.save_scriptura() if Scriptura.has_method("save_scriptura") else null
	_disable_all_scene_nodes()
	_free_dynamic_nodes()
	if ThreadSupervisor.has_method("kill_all_threads"):
		ThreadSupervisor.kill_all_threads()
	if LogCatcher.has_method("clear_buffer"):
		LogCatcher.clear_buffer()
	await get_tree().process_frame
	await get_tree().process_frame
	_unfold_from_scriptura()

func _disable_all_scene_nodes() -> void:
	var count := 0
	for node in get_tree().root.get_children():
		if node == self:
			continue
		if node is Window:
			continue
		_disable_recursive(node)
		count += 1
	LogCatcher.log("DOCTOR", "scene_disabled", str(count))

func _disable_recursive(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_disable_recursive(child)

func _free_dynamic_nodes() -> void:
	for script_id in ScriptRegistry.registry.keys():
		var entry: Dictionary = ScriptRegistry.registry[script_id]
		if str(entry.get("type", "")) == "autoload":
			continue
		if bool(entry.get("loaded", false)):
			entry["loaded"] = false
			ScriptRegistry.registry[script_id] = entry
	ScriptRegistry.save_registry()

func _unfold_from_scriptura() -> void:
	Scriptura.load_scriptura()
	ScriptRegistry.load_registry()
	mode = Mode.ASSIST
	LogCatcher.log("DOCTOR", "soft_restart", "complete")
	system_healthy.emit()

func _log_issue(issue: Dictionary) -> void:
	var issue_id := "issue_%d" % Time.get_ticks_msec()
	issue["id"] = issue_id
	issue["since"] = Time.get_ticks_msec()
	diagnosis_log.append(issue)
	if diagnosis_log.size() > 200:
		diagnosis_log.pop_front()
	known_issues[issue_id] = issue
	issue_detected.emit(issue)
	LogCatcher.warn("DOCTOR", JSON.stringify(issue))

func _is_live(script_id: String) -> bool:
	for key in TreeWatcher.node_registry.keys():
		if str((TreeWatcher.node_registry[key] as Dictionary).get("script_id", "")) == script_id:
			return true
	return false

func _on_any_valve_closed(valve_id: String, reason: String) -> void:
	_handle_issue({"type":"valve_closed_by_fails","valve_id":valve_id,"reason":reason})

func _on_any_deviation(valve_id: String, expected: Variant, actual: Variant) -> void:
	_handle_issue({"type":"valve_deviation","valve_id":valve_id,"expected":str(expected),"actual":str(actual)})

func _on_deadlock(thread_id: String) -> void:
	_handle_issue({"type":"thread_deadlock","thread_id":thread_id})

func _on_node_removed(node: Node) -> void:
	_handle_issue({"type":"weave_thread_broken","path":str(node.get_path())})

func _on_valve_fail_threshold(valve_id: String) -> void:
	_handle_issue({"type":"valve_closed_by_fails","valve_id":valve_id})

func _on_valve_deviation(valve_id: String, expected: Variant, actual: Variant) -> void:
	_handle_issue({"type":"valve_deviation","valve_id":valve_id,"expected":str(expected),"actual":str(actual)})
