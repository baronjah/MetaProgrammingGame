class_name CataloguePanel
extends Node3D

# DNA: RETURN_VALUE | auto-tag v1.6
func refresh_catalogue() -> void:
	for c in get_children():
		c.queue_free()
	var index := 0
	for pid in ProjectCatalogue.projects.keys():
		var entry: Dictionary = ProjectCatalogue.projects[pid]
		var card := MeshInstance3D.new()
		card.mesh = PlaneMesh.new()
		card.position = Vector3(0, -0.25 * index, 0)
		card.set_meta("interactive", true)
		card.set_meta("project_id", pid)
		var label := Label3D.new()
		label.text = "%s [%s]\nS:%d O:%d M:%d" % [
			str(entry.get("display_name", pid)),
			str(entry.get("version_tag", "")),
			int((entry.get("health", {}) as Dictionary).get("total_scripts", 0)),
			int((entry.get("health", {}) as Dictionary).get("orphans", 0)),
			int((entry.get("health", {}) as Dictionary).get("missing_pairs", 0))
		]
		label.modulate = _status_color(str(entry.get("resurrection_status", "pending")))
		card.add_child(label)
		add_child(card)
		index += 1

# DNA: TREE_STRUCTURE | auto-tag v1.6
func load_into_window(project_id: String, window: int) -> void:
	if not ProjectCatalogue.projects.has(project_id):
		return
	var p: Dictionary = ProjectCatalogue.projects[project_id]
	get_parent().navigate_to(window, str(p.get("disk_path", "res://")))

# DNA: RETURN_VALUE | auto-tag v1.6
func _status_color(status: String) -> Color:
	match status:
		"in-progress":
			return Color(1.0, 0.65, 0.2)
		"complete":
			return Color(0.3, 1.0, 0.3)
		"abandoned":
			return Color(0.35, 0.1, 0.1)
		_:
			return Color(0.6, 0.6, 0.6)
