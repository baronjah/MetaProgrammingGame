extends Node

const MAX_DOMES := 4
const DOME_SCENE := "res://scenes/vessel/VesselDome.tscn"

var active_domes: Dictionary = {}

signal dome_created(vessel_id: String)
signal dome_closed(vessel_id: String)
signal dome_focused(vessel_id: String)
signal project_assigned(project_id: String, vessel_id: String)

func create_dome(project_id: String) -> String:
	if active_domes.size() >= MAX_DOMES:
		return ""
	var packed := load(DOME_SCENE) as PackedScene
	if packed == null:
		return ""
	var instance := packed.instantiate() as Node3D
	var vessel_id := "vessel_%d" % Time.get_unix_time_from_system()
	var idx := active_domes.size()
	instance.position = get_layout_position(idx)
	instance.vessel_id = vessel_id
	instance.load_project(project_id, Color(0.7, 0.9, 1.0))
	get_tree().current_scene.add_child(instance)
	active_domes[vessel_id] = {"project_id": project_id, "instance": instance, "position": instance.position}
	ProjectCatalogue.assign_to_vessel(project_id, vessel_id)
	dome_created.emit(vessel_id)
	return vessel_id

func create_shared_dome(project_ids: Array[String]) -> String:
	if active_domes.size() >= MAX_DOMES:
		return ""
	var packed := load(DOME_SCENE) as PackedScene
	if packed == null:
		return ""
	var instance := packed.instantiate() as Node3D
	var vessel_id := "vessel_shared_%d" % Time.get_unix_time_from_system()
	instance.position = get_layout_position(active_domes.size())
	instance.vessel_id = vessel_id
	instance.load_shared(project_ids)
	get_tree().current_scene.add_child(instance)
	active_domes[vessel_id] = {"project_id": ",".join(project_ids), "instance": instance, "position": instance.position}
	for pid in project_ids:
		ProjectCatalogue.assign_to_vessel(pid, vessel_id)
	CursorEntity.set_mode("inspect")
	dome_created.emit(vessel_id)
	return vessel_id

func close_dome(vessel_id: String) -> void:
	if not active_domes.has(vessel_id):
		return
	var entry: Dictionary = active_domes[vessel_id]
	var instance := entry.get("instance") as Node3D
	if instance:
		instance.queue_free()
	active_domes.erase(vessel_id)
	dome_closed.emit(vessel_id)

func focus_dome(vessel_id: String) -> void:
	if not active_domes.has(vessel_id):
		return
	var entry: Dictionary = active_domes[vessel_id]
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var target := (entry.get("instance") as Node3D).global_position + Vector3(0, 1.5, 6.0)
	var tween := create_tween()
	tween.tween_property(cam, "global_position", target, 0.4)
	dome_focused.emit(vessel_id)

func get_layout_position(index: int) -> Vector3:
	var offsets := [Vector3(-8, 0, 0), Vector3(8, 0, 0), Vector3(-16, 0, -2), Vector3(16, 0, -2)]
	return offsets[index] if index < offsets.size() else Vector3(index * 10, 0, 0)
