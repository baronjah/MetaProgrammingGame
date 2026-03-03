class_name WeaveNode
extends Node3D

var script_id: String = ""
var script_type: String = ""
var functions: Array[Dictionary] = []
var input_ports: Array[Node3D] = []
var output_ports: Array[Node3D] = []

func build_ports_from_registry() -> void:
	for c in get_children():
		if c.name.begins_with("InputPort_") or c.name.begins_with("OutputPort_"):
			c.queue_free()
	input_ports.clear()
	output_ports.clear()
	var outputs := max(functions.size(), 1)
	for i in range(outputs):
		var port := MeshInstance3D.new()
		port.name = "OutputPort_%d" % i
		port.mesh = SphereMesh.new()
		port.position = Vector3(0.6, -0.15 * i, 0)
		port.set_meta("port_type", "output")
		port.set_meta("script_id", script_id)
		port.set_meta("interactive", true)
		add_child(port)
		output_ports.append(port)
		var in_port := MeshInstance3D.new()
		in_port.name = "InputPort_%d" % i
		in_port.mesh = SphereMesh.new()
		in_port.position = Vector3(-0.6, -0.15 * i, 0)
		in_port.set_meta("port_type", "input")
		in_port.set_meta("script_id", script_id)
		in_port.set_meta("interactive", true)
		add_child(in_port)
		input_ports.append(in_port)

func highlight_function(_func_name: String) -> void:
	for port in output_ports:
		(port as MeshInstance3D).modulate = Color(1.0, 0.8, 0.2)
