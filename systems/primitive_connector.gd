class_name PrimitiveConnector
extends Node3D

var from_primitive: MeshInstance3D = null
var to_primitive: MeshInstance3D = null
var connection_type: String = "rigid"
var visual_rod: MeshInstance3D = null

signal connected(a: MeshInstance3D, b: MeshInstance3D, connection_type: String)
signal disconnected()

# DNA: TREE_STRUCTURE | creates connector rod through PrimitiveFactory
func connect_primitives(a: MeshInstance3D, b: MeshInstance3D, type: String) -> void:
	from_primitive = a
	to_primitive = b
	connection_type = type
	if from_primitive == null or to_primitive == null:
		return
	var factory := _find_factory()
	if factory == null:
		return
	visual_rod = factory.create("rod", self, (a.global_position + b.global_position) * 0.5)
	_update_rod_transform()
	connected.emit(a, b, type)

# DNA: QUERY_NODE | checks primitive movement each frame
func _process(_delta: float) -> void:
	if from_primitive == null or to_primitive == null or visual_rod == null:
		return
	_update_rod_transform()

# DNA: TREE_STRUCTURE | removes rod and clears refs
func disconnect() -> void:
	if visual_rod:
		var factory := _find_factory()
		if factory:
			factory.destroy(visual_rod)
	visual_rod = null
	from_primitive = null
	to_primitive = null
	disconnected.emit()

# DNA: MUTATE_NODE | updates rod pose between endpoints
func _update_rod_transform() -> void:
	var a := from_primitive.global_position
	var b := to_primitive.global_position
	var mid := (a + b) * 0.5
	visual_rod.global_position = mid
	visual_rod.look_at(b, Vector3.UP)
	var distance := a.distance_to(b)
	visual_rod.scale = Vector3(1, max(distance, 0.01), 1)

# DNA: QUERY_NODE | finds local primitive factory instance
func _find_factory() -> PrimitiveFactory:
	for child in get_tree().current_scene.get_children():
		if child is PrimitiveFactory:
			return child
	return null
