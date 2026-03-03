extends Node

var camera: Camera3D = null
var world_position: Vector3 = Vector3.ZERO
var hit_normal: Vector3 = Vector3.ZERO
var hit_object: Node3D = null
var hit_script_id: String = ""
var hit_port: Node3D = null

var dragging: bool = false
var drag_origin: Vector3 = Vector3.ZERO
var drag_payload: Dictionary = {}
var mode: String = "navigate"

signal cursor_moved(world_pos: Vector3)
signal hovered(target: Node3D, script_id: String)
signal unhovered(target: Node3D)
signal clicked(target: Node3D, button: int, world_pos: Vector3)
signal right_clicked(target: Node3D, world_pos: Vector3)
signal drag_started(payload: Dictionary, origin: Vector3)
signal drag_ended(payload: Dictionary, drop_target: Node3D)
signal port_hovered(port: Node3D, script_id: String, port_type: String)
signal port_clicked(port: Node3D, script_id: String, port_type: String)

# DNA: QUERY_NODE | auto-tag v1.6
func _process(_delta: float) -> void:
	if camera == null:
		camera = get_viewport().get_camera_3d()
		if camera == null:
			return
	var ray := get_world_ray()
	var query := PhysicsRayQueryParameters3D.create(ray["origin"], ray["origin"] + ray["direction"] * 1000.0)
	var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
	var previous := hit_object
	hit_object = hit.get("collider", null)
	if hit_object:
		world_position = hit.get("position", world_position)
		hit_normal = hit.get("normal", Vector3.UP)
		hit_script_id = str(hit_object.get_meta("script_id", ""))
		hit_port = hit_object if hit_object.has_meta("port_type") else null
		emit_signal("hovered", hit_object, hit_script_id)
		if hit_port:
			emit_signal("port_hovered", hit_port, hit_script_id, str(hit_port.get_meta("port_type", "")))
	else:
		hit_normal = Vector3.UP
		hit_script_id = ""
		hit_port = null
	if previous and previous != hit_object:
		emit_signal("unhovered", previous)
	emit_signal("cursor_moved", world_position)

# DNA: QUERY_NODE | auto-tag v1.6
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("clicked", hit_object, event.button_index, world_position)
			if hit_port and mode == "weave":
				var payload := {
					"type": "thread_start",
					"from_script": hit_script_id,
					"port": hit_port,
				}
				begin_drag(payload)
				emit_signal("port_clicked", hit_port, hit_script_id, str(hit_port.get_meta("port_type", "")))
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			emit_signal("right_clicked", hit_object, world_position)
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
			dragging = false
			emit_signal("drag_ended", drag_payload, hit_object)
			drag_payload = {}
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if not dragging:
			begin_drag({"type": "generic", "script_id": hit_script_id})

# DNA: RETURN_VALUE | auto-tag v1.6
func begin_drag(payload: Dictionary) -> void:
	dragging = true
	drag_payload = payload
	drag_origin = world_position
	emit_signal("drag_started", payload, drag_origin)

# DNA: QUERY_NODE | auto-tag v1.6
func get_world_ray() -> Dictionary:
	var mouse_pos := get_viewport().get_mouse_position()
	return {
		"origin": camera.project_ray_origin(mouse_pos),
		"direction": camera.project_ray_normal(mouse_pos),
	}

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func set_camera(cam: Camera3D) -> void:
	camera = cam

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func set_mode(next_mode: String) -> void:
	mode = next_mode
