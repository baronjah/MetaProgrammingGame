class_name ShapeSpawner
extends Node3D

var spawn_thread: Thread
var law_mutex := Mutex.new()

# DNA: QUERY_NODE | auto-tag v1.6
func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)

# DNA: RETURN_VALUE | auto-tag v1.6
func _exit_tree() -> void:
	if spawn_thread and spawn_thread.is_alive():
		spawn_thread.wait_to_finish()

# DNA: TREE_STRUCTURE | auto-tag v1.6
func request_spawn(shape_parent: Node3D) -> void:
	if spawn_thread and spawn_thread.is_alive():
		return
	spawn_thread = Thread.new()
	spawn_thread.start(_spawn_worker.bind(shape_parent))

# DNA: TREE_STRUCTURE | auto-tag v1.6
func spawn_alive_shape(shape_parent: Node3D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.name = "AliveShape"
	mesh.position = Vector3(0, 0.3, 0)
	shape_parent.add_child(mesh)
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(mesh, "rotation:y", TAU, 2.5)

# DNA: TREE_STRUCTURE | auto-tag v1.6
func spawn_dead_shape(shape_parent: Node3D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	mesh.name = "DeadShape"
	mesh.position = Vector3(0, 0.2, 0)
	shape_parent.add_child(mesh)

# DNA: TREE_STRUCTURE | auto-tag v1.6
func _spawn_worker(shape_parent: Node3D) -> void:
	law_mutex.lock()
	var life_state := Scriptura.get_law("life")
	law_mutex.unlock()
	call_deferred("_apply_spawn", life_state, shape_parent)

# DNA: TREE_STRUCTURE | auto-tag v1.6
func _apply_spawn(life_state: String, shape_parent: Node3D) -> void:
	if life_state == "A":
		spawn_alive_shape(shape_parent)
	else:
		spawn_dead_shape(shape_parent)
	if spawn_thread and spawn_thread.is_alive():
		spawn_thread.wait_to_finish()

# DNA: RETURN_VALUE | auto-tag v1.6
func _on_law_changed(law_name: String, new_state: String) -> void:
	if law_name == "life":
		Scriptura.push_message("[LAW:life=%s]" % new_state, "ShapeSpawner")
