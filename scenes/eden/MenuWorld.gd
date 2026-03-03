class_name MenuWorld
extends Node3D

func _ready() -> void:
	_build_panel_a()
	_build_panel_b()

func _build_panel_a() -> void:
	var panel := $MenuPanel_Main
	if panel.get_node_or_null("PanelMesh") == null:
		var mesh := MeshInstance3D.new()
		mesh.name = "PanelMesh"
		mesh.mesh = PlaneMesh.new()
		mesh.scale = Vector3(2.4, 1.2, 1.0)
		panel.add_child(mesh)
	if panel.get_node_or_null("PanelLabel") == null:
		var label := Label3D.new()
		label.name = "PanelLabel"
		label.text = "EDEN MENU :: CLICK TO SPAWN"
		label.position = Vector3(0, 0, 0.01)
		panel.add_child(label)

func _build_panel_b() -> void:
	if $MenuPanel_Main.get_node_or_null("SpawnButtonArea") != null:
		return
	var area := Area3D.new()
	area.name = "SpawnButtonArea"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.2, 0.2)
	collision.shape = shape
	area.add_child(collision)
	$MenuPanel_Main.add_child(area)
	area.input_event.connect(_on_panel_input)

func _on_panel_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		$ShapeSpawner.request_spawn(self)
