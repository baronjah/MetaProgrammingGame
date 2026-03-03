class_name MenuWorld
extends Node3D

func _ready() -> void:
	_build_panel_a()
	_build_panel_b()

func _build_panel_a() -> void:
	var panel := $MenuPanel_Main
	if panel.get_child_count() == 0:
		var mesh := MeshInstance3D.new()
		mesh.mesh = PlaneMesh.new()
		mesh.scale = Vector3(2.4, 1.2, 1.0)
		panel.add_child(mesh)
		var label := Label3D.new()
		label.text = "EDEN MENU"
		label.position = Vector3(0, 0, 0.01)
		panel.add_child(label)

func _build_panel_b() -> void:
	var area := Area3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	area.add_child(collision)
	$MenuPanel_Main.add_child(area)
	area.input_event.connect(_on_panel_input)

func _on_panel_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		$ShapeSpawner.request_spawn($ShapeSpawner)
