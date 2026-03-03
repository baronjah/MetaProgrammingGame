class_name Valve
extends Node

var valve_id: String = ""
var from_script: String = ""
var from_function: String = ""
var to_script: String = ""
var to_function: String = ""
var thread_id: String = ""

var open: bool = true
var throttle_ms: float = 0.0
var last_pass_time: float = 0.0
var pass_count: int = 0
var fail_count: int = 0
var consecutive_fails: int = 0
var auto_close_on_fails: int = 5

var capture_enabled: bool = false
var capture_log: Array[Dictionary] = []
var capture_baseline: Dictionary = {}

var active_version: String = "A"
var version_override: bool = false
var relay_mode: String = "NC"

signal valve_opened(valve_id: String)
signal valve_closed(valve_id: String, reason: String)
signal data_passed(valve_id: String, args: Array, result: Variant)
signal data_blocked(valve_id: String, args: Array, reason: String)
signal fail_threshold_reached(valve_id: String)
signal deviation_detected(valve_id: String, expected: Variant, actual: Variant)

# DNA: RETURN_VALUE | auto-tag v1.6
func pass_through(args: Array, destination_callable: Callable) -> Variant:
	LogCatcher.catch_input(from_function + "→" + to_function, args)
	if relay_mode == "NO" and not open:
		data_blocked.emit(valve_id, args, "relay_no")
		LogCatcher.log("VALVE", valve_id, "blocked — relay is NO and closed", LogCatcher.Level.WARN)
		return null
	if not open:
		data_blocked.emit(valve_id, args, "valve_closed")
		LogCatcher.log("VALVE", valve_id, "blocked — valve is closed", LogCatcher.Level.WARN)
		return null
	var now := float(Time.get_ticks_msec())
	if throttle_ms > 0.0 and (now - last_pass_time) < throttle_ms:
		data_blocked.emit(valve_id, args, "throttled")
		if Engine.has_singleton("FrameGovernor"):
			FrameGovernor.queue_task(func() -> void: destination_callable.callv(args), "valve_throttle_%s" % valve_id, 2, 10)
		return null
	last_pass_time = now
	pass_count += 1
	var result := destination_callable.callv(args)
	LogCatcher.catch_output(from_function + "→" + to_function, result)
	if capture_enabled:
		_capture_entry(args, result)
	if not capture_baseline.is_empty():
		_compare_to_baseline(args, result)
	data_passed.emit(valve_id, args, result)
	consecutive_fails = 0
	return result

# DNA: RETURN_VALUE | auto-tag v1.6
func report_fail(reason: String) -> void:
	fail_count += 1
	consecutive_fails += 1
	LogCatcher.warn("VALVE", "%s fail #%d: %s" % [valve_id, consecutive_fails, reason])
	if consecutive_fails >= auto_close_on_fails:
		open = false
		fail_threshold_reached.emit(valve_id)

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func set_throttle(ms: float) -> void:
	throttle_ms = max(ms, 0.0)
	LogCatcher.log("VALVE", valve_id, "throttle set to %sms" % throttle_ms)

# DNA: TREE_STRUCTURE | auto-tag v1.6
func open_valve() -> void:
	open = true
	consecutive_fails = 0
	valve_opened.emit(valve_id)

# DNA: RETURN_VALUE | auto-tag v1.6
func close_valve(reason: String) -> void:
	open = false
	valve_closed.emit(valve_id, reason)

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func save_baseline() -> void:
	if capture_log.is_empty():
		return
	capture_baseline = capture_log[-1].duplicate(true)
	LogCatcher.log("VALVE", valve_id, "baseline saved")

# DNA: RETURN_VALUE | auto-tag v1.6
func _capture_entry(args: Array, result: Variant) -> void:
	capture_log.append({
		"time": Time.get_ticks_msec(),
		"args": JSON.stringify(args),
		"result": str(result),
	})
	if capture_log.size() > 100:
		capture_log.pop_front()

# DNA: RETURN_VALUE | auto-tag v1.6
func _compare_to_baseline(args: Array, result: Variant) -> void:
	var baseline_args := str(capture_baseline.get("args", ""))
	var baseline_result := str(capture_baseline.get("result", ""))
	var args_serialized := JSON.stringify(args)
	if baseline_args == args_serialized and baseline_result != str(result):
		deviation_detected.emit(valve_id, baseline_result, result)
		LogCatcher.warn("VALVE", "%s deviation: expected=%s actual=%s" % [valve_id, baseline_result, str(result)])

# DNA: RETURN_VALUE | auto-tag v1.6
func select_version(ver: String) -> void:
	if ver != "A" and ver != "B":
		return
	active_version = ver
	version_override = true
	if Engine.has_singleton("TheWeave"):
		TheWeave.set_layer_visible("manual_override_%s" % valve_id, true)
