class_name FlatShapeGen
extends Node

# DNA: MUTATE_NODE | generates flat shape primitive
func generate(primitive_id: String, position: Vector3, size: Vector3) -> MeshInstance3D:
	var node := PrimitiveFactory.new().create("slab", get_tree().current_scene, position)
	if node:
		node.scale = size
	return node
