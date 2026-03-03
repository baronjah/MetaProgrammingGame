class_name ShapeWorkbench
extends LifecycleHarness

var selected: Array[MeshInstance3D] = []
var connector_mode: bool = false
var pending_connector: MeshInstance3D = null
var shape_router: Router = null

@onready var factory: PrimitiveFactory = $PrimitiveFactory
@onready var connector_root: Node3D = $PrimitiveConnector_Root

# DNA: TREE_STRUCTURE | initializes workbench bindings
func on_ready() -> void:
	factory.load_library()
	_setup_router()
	CursorEntity.clicked.connect(_on_cursor_clicked)
	CursorEntity.drag_ended.connect(_on_drag_ended)
	_build_toolbar()

# DNA: QUERY_NODE | routes click interactions
func _on_cursor_clicked(target: Node3D, _button: int, world_pos: Vector3) -> void:
	if target == null:
		deselect_all()
		return
	if target.has_meta("toolbar_primitive"):
		spawn_at(str(target.get_meta("toolbar_primitive")), world_pos)
		return
	if target.has_meta("primitive_id"):
		var mesh_target := target as MeshInstance3D
		if connector_mode:
			_handle_connector_click(mesh_target)
		else:
			select_primitive(mesh_target)

# DNA: TREE_STRUCTURE | handles drag/drop move
func _on_drag_ended(payload: Dictionary, _drop_target: Node3D) -> void:
	if str(payload.get("type", "")) == "generic" and selected.size() > 0:
		move_selected(CursorEntity.world_position)

# DNA: MUTATE_NODE | highlight/select primitive
func select_primitive(node: MeshInstance3D) -> void:
	if node == null:
		return
	if not selected.has(node):
		selected.append(node)
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	node.material_override = mat
	_show_transform_handles(node)

# DNA: MUTATE_NODE | clears selection visuals
func deselect_all() -> void:
	for node in selected:
		if node:
			node.material_override = null
	selected.clear()
	for c in $Selection.get_children():
		c.queue_free()

# DNA: MUTATE_NODE | updates selected node position
func move_selected(new_pos: Vector3) -> void:
	if selected.is_empty():
		return
	selected[0].global_position = new_pos
	LogCatcher.log("WORKBENCH", "move_selected", str(new_pos))

# DNA: TREE_STRUCTURE | spawn primitive through factory
func spawn_at(primitive_id: String, pos: Vector3) -> void:
	if shape_router != null:
		shape_router.route([primitive_id, pos, Vector3(1,1,1)])
	else:
		factory.create(primitive_id, self, pos)

# DNA: MUTATE_GLOBAL | enters connector mode + cursor mode
func enter_connector_mode() -> void:
	connector_mode = true
	CursorEntity.set_mode("weave")

# DNA: MUTATE_GLOBAL | exits connector mode + cursor mode
func exit_connector_mode() -> void:
	connector_mode = false
	pending_connector = null
	CursorEntity.set_mode("navigate")

# DNA: QUERY_NODE | handles two-click connector workflow
func _handle_connector_click(node: MeshInstance3D) -> void:
	if pending_connector == null:
		pending_connector = node
		return
	if node == pending_connector:
		return
	var conn := PrimitiveConnector.new()
	connector_root.add_child(conn)
	conn.connect_primitives(pending_connector, node, "joint")
	pending_connector = null

# DNA: TREE_STRUCTURE | builds toolbar from primitive library json
func _build_toolbar() -> void:
	for c in $WorkbenchToolbar.get_children():
		c.queue_free()
	var defs: Dictionary = factory.library.get("primitives", {})
	var i := 0
	for primitive_id in defs.keys():
		var button := factory.create("slab", $WorkbenchToolbar, Vector3(float(i) * 0.7, 0, 0))
		if button:
			button.set_meta("toolbar_primitive", primitive_id)
			var label := Label3D.new()
			label.text = primitive_id
			label.position = Vector3(0, 0, 0.02)
			button.add_child(label)
		i += 1

# DNA: TREE_STRUCTURE | adds orb handles around selection
func _show_transform_handles(node: MeshInstance3D) -> void:
	for c in $Selection.get_children():
		c.queue_free()
	var offsets := [Vector3(0.4, 0, 0), Vector3(-0.4, 0, 0), Vector3(0, 0.4, 0), Vector3(0, -0.4, 0)]
	for off in offsets:
		var orb := factory.create("orb", $Selection, node.global_position + off)
		if orb:
			orb.scale = Vector3.ONE * 0.15


# DNA: TREE_STRUCTURE | creates shape generator router and outputs
func _setup_router() -> void:
	if not Engine.has_singleton("RouterRegistry"):
		return
	shape_router = RouterRegistry.create_router("ShapeWorkbench", "spawn_at", "NC", "law")
	RouterRegistry.add_output_to_router(shape_router.router_id, "FlatShapeGen", "generate", "Flat 2D", "shape_mode", "A")
	RouterRegistry.add_output_to_router(shape_router.router_id, "ThickShapeGen", "generate", "3D Thick", "shape_mode", "B")
