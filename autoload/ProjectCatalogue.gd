extends Node

const CATALOGUE_PATH := "res://data/project_catalogue.json"

var projects: Dictionary = {}
var active_comparisons: Array[String] = []

# DNA: QUERY_NODE | auto-tag v1.6
func _ready() -> void:
	load_catalogue()

# DNA: TREE_STRUCTURE | auto-tag v1.6
func load_catalogue() -> void:
	var file := FileAccess.open(CATALOGUE_PATH, FileAccess.READ)
	if file == null:
		projects = {}
		return
	var parsed := JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		projects = parsed.get("projects", {})

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func register_project(disk_path: String) -> String:
	var internal_id := "proj_%s_%d" % [_slugify(disk_path.get_file()), Time.get_unix_time_from_system()]
	var impact_path := disk_path.path_join("first_impact/first_impact.json")
	var plan_path := disk_path.path_join("first_impact/resurrection_plan.json")
	var health := {
		"total_scripts": 0,
		"orphans": 0,
		"missing_pairs": 0,
		"files_over_400": 0,
	}
	if FileAccess.file_exists(impact_path):
		var impact := JSON.parse_string(FileAccess.get_file_as_string(impact_path))
		if typeof(impact) == TYPE_DICTIONARY:
			var scripts: Array = impact.get("scripts", [])
			health["total_scripts"] = scripts.size()
			health["orphans"] = scripts.filter(func(s: Dictionary): return str(s.get("script_type", "")) == "orphan").size()
	if FileAccess.file_exists(plan_path):
		var plan := JSON.parse_string(FileAccess.get_file_as_string(plan_path))
		if typeof(plan) == TYPE_DICTIONARY:
			var hp: Dictionary = plan.get("health", {})
			health["missing_pairs"] = int(hp.get("missing_duality_pairs", 0))
			health["files_over_400"] = int(hp.get("files_over_400_lines", 0))
	projects[internal_id] = {
		"internal_id": internal_id,
		"display_name": disk_path.get_file(),
		"disk_path": disk_path,
		"godot_version": "unknown",
		"engine_type": "mono",
		"first_impact_path": disk_path.path_join("first_impact/"),
		"scanned": FileAccess.file_exists(impact_path),
		"scan_date": Time.get_datetime_string_from_system(),
		"version_tag": "unlabeled",
		"duplicate_of": null,
		"similarity_to": [],
		"similarity_score": 0.0,
		"custom_notes": "",
		"resurrection_status": "pending",
		"health": health,
		"tags": [],
		"vessel_assignment": null,
	}
	save_catalogue()
	return internal_id

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func update_custom(project_id: String, field: String, value: Variant) -> void:
	if not projects.has(project_id):
		return
	projects[project_id][field] = value
	save_catalogue()

# DNA: QUERY_NODE | auto-tag v1.6
func find_duplicates() -> Array[Dictionary]:
	var ids := projects.keys()
	var pairs: Array[Dictionary] = []
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: Dictionary = projects[ids[i]]
			var b: Dictionary = projects[ids[j]]
			var score := _similarity(a, b)
			if score > 0.7:
				pairs.append({"a": ids[i], "b": ids[j], "similarity_score": score})
	return pairs

# DNA: RETURN_VALUE | auto-tag v1.6
func assign_to_vessel(project_id: String, vessel_id: String) -> void:
	if not projects.has(project_id):
		return
	projects[project_id]["vessel_assignment"] = vessel_id
	save_catalogue()
	if Engine.has_singleton("VesselDomeManager"):
		VesselDomeManager.project_assigned.emit(project_id, vessel_id)

# DNA: QUERY_NODE | auto-tag v1.6
func get_projects_by_tag(tag: String) -> Array:
	var out: Array = []
	for project in projects.values():
		if (project.get("tags", []) as Array).has(tag):
			out.append(project)
	return out

# DNA: QUERY_NODE | auto-tag v1.6
func get_unscanned() -> Array:
	return projects.values().filter(func(p: Dictionary): return not bool(p.get("scanned", false)))

# DNA: QUERY_NODE | auto-tag v1.6
func get_by_resurrection_status(status: String) -> Array:
	return projects.values().filter(func(p: Dictionary): return str(p.get("resurrection_status", "")) == status)

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func save_catalogue() -> void:
	var payload := {"projects": projects}
	var file := FileAccess.open(CATALOGUE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))

# DNA: RETURN_VALUE | auto-tag v1.6
func _similarity(a: Dictionary, b: Dictionary) -> float:
	var ah: Dictionary = a.get("health", {})
	var bh: Dictionary = b.get("health", {})
	var sa := float(ah.get("total_scripts", 0))
	var sb := float(bh.get("total_scripts", 0))
	if sa == 0.0 and sb == 0.0:
		return 1.0
	if sa == 0.0 or sb == 0.0:
		return 0.0
	return min(sa, sb) / max(sa, sb)

# DNA: RETURN_VALUE | auto-tag v1.6
func _slugify(value: String) -> String:
	return value.to_lower().replace(" ", "_").replace("-", "_")
