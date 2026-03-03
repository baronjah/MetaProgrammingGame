class_name NodeTreePreview
extends Node3D

# DNA: RETURN_VALUE | auto-tag v1.6
func preview_scene(path: String) -> void:
	for c in get_children():
		c.queue_free()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var lines := file.get_as_text().split("\n")
	var row := 0
	for line in lines:
		if line.begins_with("[node name="):
			var node_name := line.get_slice('"', 1)
			var node_type := line.get_slice('"', 3)
			var panel := MeshInstance3D.new()
			panel.mesh = PlaneMesh.new()
			panel.position = Vector3(float(row % 4) * 0.8, -float(row) * 0.15, 0)
			add_child(panel)
			var label := Label3D.new()
			label.text = "%s : %s" % [node_name, node_type]
			label.position = panel.position + Vector3(0, 0, 0.01)
			add_child(label)
			row += 1
