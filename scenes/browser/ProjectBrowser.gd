class_name ProjectBrowser
extends Node3D

var window_a_path: String = "res://"
var window_b_path: String = "res://"
var active_window: int = 0

func _ready() -> void:
	navigate_to(0, window_a_path)
	navigate_to(1, window_b_path)

func navigate_to(window: int, path: String) -> void:
	var current := path
	var dir := DirAccess.open(current)
	if dir == null and path.begins_with("res://"):
		current = ProjectSettings.globalize_path(path)
		dir = DirAccess.open(current)
	if dir == null:
		return
	if window == 0:
		window_a_path = path
	else:
		window_b_path = path
	_update_path_label(window, path)
	_rebuild_file_list(window, dir)

func select_entry(window: int, entry_name: String) -> void:
	var base := window_a_path if window == 0 else window_b_path
	var full := base.path_join(entry_name)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(full)):
		navigate_to(window, full)
		return
	if full.ends_with(".gd"):
		var _script_inspector_access := PathResolver.generate_access_snippet("ProjectBrowser", "ScriptInspector")
		$ScriptInspector.inspect_script(full)
	elif full.ends_with(".json"):
		var _json_inspector_access := PathResolver.generate_access_snippet("ProjectBrowser", "JsonInspector")
		$JsonInspector.inspect_json(full)
	elif full.ends_with(".tscn"):
		var _tree_preview_access := PathResolver.generate_access_snippet("ProjectBrowser", "NodeTreePreview")
		$NodeTreePreview.preview_scene(full)

func trigger_bomb(window: int) -> void:
	var target := window_a_path if window == 0 else window_b_path
	var script := ProjectSettings.globalize_path("res://tools/data_bomb/bomb.py")
	OS.execute("python", [script, "--path", ProjectSettings.globalize_path(target)], [])
	_set_action_status(window, "Bomb complete")

func compare_windows() -> void:
	var a := _list_script_files(window_a_path)
	var b := _list_script_files(window_b_path)
	var overlap := []
	for name in a.keys():
		if b.has(name):
			overlap.append(name)
	$DiffPanel/Label3D.text = "Shared scripts: %s" % ", ".join(overlap)

func open_second_window(path: String) -> void:
	window_b_path = path
	navigate_to(1, path)

func _list_script_files(path: String) -> Dictionary:
	var result := {}
	var dir := DirAccess.open(ProjectSettings.globalize_path(path))
	if dir == null:
		return result
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if not dir.current_is_dir() and n.ends_with(".gd"):
			result[n] = true
		n = dir.get_next()
	dir.list_dir_end()
	return result

func _update_path_label(window: int, path: String) -> void:
	var label_path := "BrowserWindow_A/PathBar/Label3D" if window == 0 else "BrowserWindow_B/PathBar/Label3D"
	var label := get_node_or_null(label_path) as Label3D
	if label:
		label.text = path

func _set_action_status(window: int, text: String) -> void:
	var label_path := "BrowserWindow_A/ActionBar/Label3D" if window == 0 else "BrowserWindow_B/ActionBar/Label3D"
	var label := get_node_or_null(label_path) as Label3D
	if label:
		label.text = text

func _rebuild_file_list(window: int, dir: DirAccess) -> void:
	var parent_path := "BrowserWindow_A/FileList" if window == 0 else "BrowserWindow_B/FileList"
	var parent := get_node_or_null(parent_path) as Node3D
	if parent == null:
		return
	for c in parent.get_children():
		c.queue_free()
	dir.list_dir_begin()
	var index := 0
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var entry := Node3D.new()
			entry.name = "FileEntry_%d" % index
			entry.position = Vector3(0, -0.12 * index, 0)
			var mesh := MeshInstance3D.new()
			mesh.mesh = PlaneMesh.new()
			entry.add_child(mesh)
			var label := Label3D.new()
			label.text = name
			label.modulate = _entry_color(name, dir.current_is_dir())
			entry.add_child(label)
			parent.add_child(entry)
			index += 1
		name = dir.get_next()
	dir.list_dir_end()

func _entry_color(name: String, is_dir: bool) -> Color:
	if is_dir:
		return Color(1.0, 0.65, 0.2)
	if name.ends_with(".gd"):
		return Color(0.3, 0.5, 1.0)
	if name.ends_with(".tscn"):
		return Color(0.35, 1.0, 0.35)
	if name.ends_with(".json"):
		return Color(1.0, 1.0, 1.0)
	return Color(0.6, 0.6, 0.6)


func open_catalogue_mode() -> void:
	var _catalogue_access := PathResolver.generate_access_snippet("ProjectBrowser", "CataloguePanel")
	$CataloguePanel.refresh_catalogue()
