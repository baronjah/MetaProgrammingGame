class_name LogPanel
extends Node3D

var filter_mode: String = "all"

# DNA: QUERY_NODE | auto-tag v1.6
func _process(_delta: float) -> void:
	refresh_lines()

# DNA: RETURN_VALUE | auto-tag v1.6
func refresh_lines() -> void:
	for c in get_children():
		c.queue_free()
	var lines := LogCatcher.get_recent(50)
	var row := 0
	for line in lines:
		if not _match_filter(line):
			continue
		var label := Label3D.new()
		label.text = line
		label.position = Vector3(0, -0.06 * row, 0)
		label.modulate = _line_color(line)
		add_child(label)
		row += 1

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func set_filter(mode: String) -> void:
	filter_mode = mode

# DNA: RETURN_VALUE | auto-tag v1.6
func _match_filter(line: String) -> bool:
	match filter_mode:
		"warn_error": return line.find("[WARN") != -1 or line.find("[ERROR") != -1
		"tree": return line.find("[TREE") != -1
		"func": return line.find("[FUNC") != -1
		_: return true

# DNA: RETURN_VALUE | auto-tag v1.6
func _line_color(line: String) -> Color:
	if line.find("[DEBUG") != -1:
		return Color(0.6, 0.6, 0.6)
	if line.find("[WARN") != -1:
		return Color(1.0, 0.65, 0.2)
	if line.find("[ERROR") != -1:
		return Color(1.0, 0.2, 0.2)
	if line.find("[TREE") != -1:
		return Color(0.4, 0.9, 1.0)
	if line.find("[THREAD") != -1:
		return Color(0.7, 0.4, 1.0)
	if line.find("[WEAVE") != -1:
		return Color(0.3, 0.5, 1.0)
	return Color(1, 1, 1)
