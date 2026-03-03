class_name RouterNode
extends Node3D

var router_id: String = ""
var output_pins: Array[Node3D] = []

# DNA: TREE_STRUCTURE | builds pin visuals for router outputs
func build_from_router(router: Router) -> void:
	router_id = router.router_id
	for c in get_children():
		c.queue_free()
	output_pins.clear()
	var input_pin := MeshInstance3D.new()
	input_pin.mesh = SphereMesh.new()
	input_pin.position = Vector3(-0.5, 0, 0)
	input_pin.set_meta("interactive", true)
	add_child(input_pin)
	var selector := Label3D.new()
	selector.text = "%s [%s/%s]" % [router_id, router.selector_mode, router.relay_mode]
	selector.position = Vector3(0, 0.4, 0)
	add_child(selector)
	for i in range(router.outputs.size()):
		var pin := Node3D.new()
		pin.position = Vector3(0.5, -0.2 * i, 0)
		var mesh := MeshInstance3D.new()
		mesh.mesh = SphereMesh.new()
		mesh.modulate = Color(1, 0.55, 0.2)
		pin.add_child(mesh)
		var label := Label3D.new()
		label.text = str((router.outputs[i] as Dictionary).get("label", "out"))
		label.position = Vector3(0.2, 0, 0)
		pin.add_child(label)
		pin.set_meta("interactive", true)
		pin.set_meta("router_output_index", i)
		add_child(pin)
		output_pins.append(pin)

# DNA: MUTATE_NODE | highlights active output
func set_active_output(index: int) -> void:
	for i in range(output_pins.size()):
		var pin := output_pins[i]
		var mesh := pin.get_child(0) as MeshInstance3D
		mesh.modulate = Color(1, 1, 0.2) if i == index else Color(0.4, 0.4, 0.4)
