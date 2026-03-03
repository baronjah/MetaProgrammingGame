class_name WeaveVia
extends Node3D

var from_layer: int = 0
var to_layer: int = 1
var from_node_id: String = ""
var to_node_id: String = ""
var via_mesh: MeshInstance3D

# DNA: MUTATE_NODE | draws vertical via between layer positions
func draw_via(from_pos: Vector3, to_pos: Vector3) -> void:
	if via_mesh == null:
		via_mesh = MeshInstance3D.new()
		via_mesh.mesh = CylinderMesh.new()
		add_child(via_mesh)
	var mid := (from_pos + to_pos) * 0.5
	global_position = mid
	look_at(to_pos, Vector3.UP)
	var distance := from_pos.distance_to(to_pos)
	via_mesh.scale = Vector3(0.05, max(distance * 0.5, 0.01), 0.05)
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.9, 1.0)
	mat.albedo_color = Color(0.5, 0.7, 1.0, 0.8)
	via_mesh.material_override = mat
