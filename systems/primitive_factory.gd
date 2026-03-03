class_name PrimitiveFactory
extends Node

const LIBRARY_PATH := "res://data/primitive_library.json"
var library: Dictionary = {}

signal primitive_created(id: String, node: MeshInstance3D)
signal primitive_destroyed(id: String)

# DNA: READ_FILE | loads primitive definitions
func load_library() -> void:
	var file := FileAccess.open(LIBRARY_PATH, FileAccess.READ)
	if file == null:
		LogCatcher.error("FACTORY", "missing primitive library")
		return
	var parsed := JSON.parse_string(file.get_as_text())
	library = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

# DNA: TREE_STRUCTURE | queues node creation through FrameGovernor
func create(primitive_id: String, parent: Node3D, position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var def := (library.get("primitives", {}) as Dictionary).get(primitive_id, null)
	if def == null:
		LogCatcher.error("FACTORY", "unknown primitive: " + primitive_id)
		return null
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "%s_%d" % [primitive_id, randi()]
	mesh_instance.mesh = _build_mesh(def)
	mesh_instance.position = position
	mesh_instance.set_meta("primitive_id", primitive_id)
	mesh_instance.set_meta("interactive", true)
	mesh_instance.set_meta("script_id", "")
	FrameGovernor.queue_task(
		func() -> void: parent.add_child.call_deferred(mesh_instance),
		"primitive_create_" + primitive_id,
		1,
		10
	)
	primitive_created.emit(primitive_id, mesh_instance)
	LogCatcher.log("FACTORY", "queued_create", "%s at %s" % [primitive_id, str(position)])
	return mesh_instance

# DNA: TREE_STRUCTURE | queues deletion through FrameGovernor
func destroy(node: MeshInstance3D) -> void:
	if node == null:
		return
	var pid := str(node.get_meta("primitive_id", node.name))
	FrameGovernor.queue_task(func() -> void: node.queue_free(), "primitive_destroy_" + pid, 1, 10)
	primitive_destroyed.emit(pid)
	LogCatcher.log("FACTORY", "queued_destroy", pid)

# DNA: RETURN_VALUE | builds and returns mesh resource
func _build_mesh(def: Dictionary) -> Mesh:
	var mesh_class := str(def.get("mesh_class", "BoxMesh"))
	var size: Array = def.get("default_size", [1.0, 1.0, 1.0])
	match mesh_class:
		"CylinderMesh":
			var m := CylinderMesh.new()
			m.top_radius = float(size[0])
			m.height = float(size[1])
			m.bottom_radius = float(size[2])
			return m
		"SphereMesh":
			var s := SphereMesh.new()
			s.radius = float(size[0])
			return s
		"PrismMesh":
			var p := PrismMesh.new()
			p.size = Vector3(float(size[0]), float(size[1]), float(size[2]))
			return p
		"TorusMesh":
			var t := TorusMesh.new()
			t.inner_radius = float(size[0])
			t.outer_radius = float(size[0]) + float(size[1])
			return t
		_:
			var b := BoxMesh.new()
			b.size = Vector3(float(size[0]), float(size[1]), float(size[2]))
			return b

# DNA: TREE_STRUCTURE | clones source and queues add child
func clone(source: MeshInstance3D) -> MeshInstance3D:
	if source == null or source.get_parent() == null:
		return null
	var clone_node := source.duplicate() as MeshInstance3D
	clone_node.name = "%s_clone_%d" % [source.name, randi()]
	FrameGovernor.queue_task(
		func() -> void: (source.get_parent() as Node).add_child.call_deferred(clone_node),
		"primitive_clone_" + clone_node.name,
		1,
		10
	)
	return clone_node
