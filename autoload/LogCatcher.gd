extends Node

const LOG_PATH := "user://logs/session.log"
const MAX_FILE_SIZE_KB := 512

var _last_message: String = ""
var _last_message_time: float = 0.0
var _repeat_count: int = 0
var _similarity_threshold: float = 0.85
var _min_repeat_interval: float = 0.5

var _file: FileAccess = null
var _session_start: float = 0.0
var _recent: Array[String] = []

enum Level { DEBUG, INFO, WARN, ERROR, TREE, IO, THREAD, WEAVE }

# DNA: QUERY_NODE | auto-tag v1.6
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	_file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if _file:
		_file.seek_end()
	_session_start = Time.get_ticks_msec() / 1000.0
	_write("=== Session start %s | Godot %s ===" % [Time.get_datetime_string_from_system(), Engine.get_version_info().get("string", "unknown")])

# DNA: RETURN_VALUE | auto-tag v1.6
func log(category: String, event: String, detail: String = "", level: Level = Level.INFO) -> void:
	var current_msg := "%s|%s|%s" % [category, event, detail]
	var time_now := Time.get_ticks_msec() / 1000.0 - _session_start
	var similarity := _compute_similarity(current_msg, _last_message)
	if similarity >= _similarity_threshold:
		var time_since_last := time_now - _last_message_time
		if time_since_last < _min_repeat_interval:
			_repeat_count += 1
			return
		if _repeat_count > 0:
			_write("[×%d repeated] %s" % [_repeat_count, _last_message])
			_repeat_count = 0
	_last_message = current_msg
	_last_message_time = time_now
	_write(_format(time_now, category, event, detail, level))

# DNA: RETURN_VALUE | auto-tag v1.6
func _format(t: float, cat: String, ev: String, detail: String, level: Level) -> String:
	return "[T+%07.3f][%s][%s] %s → %s" % [t, _level_name(level).rpad(5), cat.rpad(6), ev, detail]

# DNA: RETURN_VALUE | auto-tag v1.6
func _write(line: String) -> void:
	print(line)
	_recent.append(line)
	if _recent.size() > 100:
		_recent.pop_front()
	if _file:
		_file.store_line(line)
		_file.flush()
		if _file.get_length() > MAX_FILE_SIZE_KB * 1024:
			_rotate_file()

# DNA: RETURN_VALUE | auto-tag v1.6
func _compute_similarity(a: String, b: String) -> float:
	if a == "" or b == "":
		return 0.0
	var counts := {}
	for ch in a:
		counts[ch] = int(counts.get(ch, 0)) + 1
	var shared := 0
	for ch in b:
		if int(counts.get(ch, 0)) > 0:
			shared += 1
			counts[ch] = int(counts[ch]) - 1
	return float(shared) / float(max(a.length(), b.length()))

# DNA: RETURN_VALUE | auto-tag v1.6
func warn(category: String, detail: String) -> void:
	log(category, "WARN", detail, Level.WARN)

# DNA: RETURN_VALUE | auto-tag v1.6
func error(category: String, detail: String) -> void:
	log(category, "ERROR", detail, Level.ERROR)
	push_error(detail)

# DNA: QUERY_NODE | auto-tag v1.6
func catch_input(func_name: String, args: Array) -> void:
	log("FUNC", "%s()" % func_name, _serialize_args(args), Level.DEBUG)

# DNA: RETURN_VALUE | auto-tag v1.6
func catch_output(func_name: String, result: Variant) -> void:
	log("FUNC", "%s() ->" % func_name, str(result), Level.DEBUG)

# DNA: RETURN_VALUE | auto-tag v1.6
func _serialize_args(args: Array) -> String:
	var chunks: Array[String] = []
	for a in args:
		if a is Node:
			chunks.append("%s@%s" % [a.name, a.get_path()])
		elif a is Dictionary:
			chunks.append("dict(%s)" % ",".join((a as Dictionary).keys()))
		else:
			chunks.append(str(a))
	var out := "; ".join(chunks)
	return out.left(120) + ("..." if out.length() > 120 else "")

# DNA: RETURN_VALUE | auto-tag v1.6
func flush() -> void:
	if _file:
		_file.flush()

# DNA: QUERY_NODE | auto-tag v1.6
func get_recent(n: int = 20) -> Array[String]:
	var start := maxi(_recent.size() - n, 0)
	return _recent.slice(start, _recent.size())

# DNA: RETURN_VALUE | auto-tag v1.6
func _rotate_file() -> void:
	if _file:
		_file.close()
	if FileAccess.file_exists("user://logs/session_old.log"):
		DirAccess.remove_absolute("user://logs/session_old.log")
	DirAccess.rename_absolute(LOG_PATH, "user://logs/session_old.log")
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)

# DNA: RETURN_VALUE | auto-tag v1.6
func _level_name(level: Level) -> String:
	match level:
		Level.DEBUG: return "DEBUG"
		Level.INFO: return "INFO"
		Level.WARN: return "WARN"
		Level.ERROR: return "ERROR"
		Level.TREE: return "TREE"
		Level.IO: return "IO"
		Level.THREAD: return "THREAD"
		Level.WEAVE: return "WEAVE"
		_: return "INFO"
