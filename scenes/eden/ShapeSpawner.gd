class_name ShapeSpawner
extends Node3D

var spawn_thread: Thread
var law_mutex := Mutex.new()

func _ready() -> void:
	Scriptura.law_changed.connect(_on_law_changed)

func request_spawn(shape_parent: Node3D) -> void:
	if spawn_thread and spawn_thread.is_alive():
		return
	spawn_thread = Thread.new()
	spawn_thread.start(_spawn_worker.bind(shape_parent))

func spawn_alive_shape(shape_parent: Node3D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.name = "AliveShape"
	shape_parent.add_child(mesh)
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(mesh, "rotation:y", TAU, 2.5)

func spawn_dead_shape(shape_parent: Node3D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	mesh.name = "DeadShape"
	shape_parent.add_child(mesh)

func _spawn_worker(shape_parent: Node3D) -> void:
	law_mutex.lock()
	var life_state := Scriptura.get_law("life")
	law_mutex.unlock()
	call_deferred("_apply_spawn", life_state, shape_parent)

func _apply_spawn(life_state: String, shape_parent: Node3D) -> void:
	if life_state == "A":
		spawn_alive_shape(shape_parent)
	else:
		spawn_dead_shape(shape_parent)

func _on_law_changed(law_name: String, _new_state: String) -> void:
	if law_name == "life":
		Scriptura.push_message("shape_spawner synced to life law", "ShapeSpawner")
