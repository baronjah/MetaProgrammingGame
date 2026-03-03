class_name VesselDome
extends Node3D

var project_id: String = ""
var vessel_id: String = ""
var layers: Array[Node3D] = []
var script_nodes: Dictionary = {}

# DNA: TREE_STRUCTURE | auto-tag v1.6
func load_project(pid: String, layer_color: Color) -> void:
	project_id = pid
	var root_path := _project_root(pid)
	var impact_path := root_path.path_join("first_impact/first_impact.json")
	if not FileAccess.file_exists(impact_path):
		return
	var parsed := JSON.parse_string(FileAccess.get_file_as_string(impact_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var layer := Node3D.new()
	layer.name = "ProjectLayer_%s" % pid
	$LayerContainer.add_child(layer)
	layers.append(layer)
	var scenes: Array = parsed.get("scenes", [])
	for i in range(scenes.size()):
		var card := _make_card(str(scenes[i].get("scene_path", "scene")), layer_color)
		card.position = Vector3(float(i) * 0.7, 0.8, 0)
		layer.add_child(card)
	var scripts: Array = parsed.get("scripts", [])
	for j in range(scripts.size()):
		var script_id := str(scripts[j].get("class_name", scripts[j].get("file_path", "script")))
		var node := _make_card(script_id, _script_color(str(scripts[j].get("script_type", "orphan"))))
		node.position = Vector3(float(j % 8) * 0.5, 0.1, -0.6 - float(j / 8) * 0.3)
		node.set_meta("script_id", script_id)
		node.set_meta("interactive", true)
		layer.add_child(node)
		script_nodes[script_id] = node

# DNA: TREE_STRUCTURE | auto-tag v1.6
func load_shared(project_ids: Array[String]) -> void:
	for i in range(project_ids.size()):
		var hue := float(i) / max(1.0, float(project_ids.size()))
		load_project(project_ids[i], Color.from_hsv(hue, 0.7, 1.0))
		layers[-1].position.y = float(i) * 0.2

# DNA: RETURN_VALUE | auto-tag v1.6
func show_law_state(laws: Dictionary) -> void:
	var lines: Array[String] = []
	for law in laws.keys():
		lines.append("%s:%s" % [law, laws[law]])
	$LawPanel/Label3D.text = " ".join(lines)

# DNA: MUTATE_NODE | auto-tag v1.6
func highlight_script(script_id: String) -> void:
	if not script_nodes.has(script_id):
		return
	var node := script_nodes[script_id] as MeshInstance3D
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.2)
	node.material_override = mat

# DNA: QUERY_NODE | auto-tag v1.6
func get_script_world_position(script_id: String) -> Vector3:
	if not script_nodes.has(script_id):
		return global_position
	return (script_nodes[script_id] as Node3D).global_position

# DNA: RETURN_VALUE | auto-tag v1.6
func _project_root(pid: String) -> String:
	if ProjectCatalogue.projects.has(pid):
		return str((ProjectCatalogue.projects[pid] as Dictionary).get("disk_path", ""))
	return ""

# DNA: RETURN_VALUE | auto-tag v1.6
func _make_card(text: String, color: Color) -> MeshInstance3D:
	var card := MeshInstance3D.new()
	card.mesh = PlaneMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	card.material_override = mat
	var label := Label3D.new()
	label.text = text
	label.position = Vector3(0, 0, 0.02)
	card.add_child(label)
	return card

# DNA: RETURN_VALUE | auto-tag v1.6
func _script_color(script_type: String) -> Color:
	match script_type:
		"autoload":
			return Color(1, 1, 1)
		"class_named":
			return Color(0.3, 0.5, 1.0)
		"scene_script":
			return Color(0.35, 1.0, 0.35)
		_:
			return Color(0.6, 0.6, 0.6)
