class_name ThickShapeGen
extends Node

# DNA: MUTATE_NODE | generates thick shape primitive
func generate(primitive_id: String, position: Vector3, size: Vector3) -> MeshInstance3D:
	var node := PrimitiveFactory.new().create("wedge", get_tree().current_scene, position)
	if node:
		node.scale = Vector3(size.x, max(size.y, 0.2), size.z)
	return node
