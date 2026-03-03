class_name WeaveThread
extends Node3D

var thread_id: String = ""
var from_script: String = ""
var to_script: String = ""
var from_function: String = ""
var to_function: String = ""
var law_binding: String = ""
var active: bool = true
var path_style: String = "bezier"

var line_mesh: MeshInstance3D
var control_point_a: Vector3
var control_point_b: Vector3

func _ready() -> void:
	line_mesh = MeshInstance3D.new()
	add_child(line_mesh)

func draw_straight(from: Vector3, to: Vector3) -> void:
	var im := ImmediateMesh.new()
	var mat := ORMMaterial3D.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	im.surface_add_vertex(from)
	im.surface_add_vertex(to)
	im.surface_end()
	line_mesh.mesh = im

func draw_bezier(from: Vector3, to: Vector3, cp_a: Vector3, cp_b: Vector3) -> void:
	var im := ImmediateMesh.new()
	var mat := ORMMaterial3D.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	for i in range(33):
		var t := float(i) / 32.0
		var p := from.bezier_interpolate(cp_a, cp_b, to, t)
		im.surface_add_vertex(p)
	im.surface_end()
	line_mesh.mesh = im

func draw_routed(from: Vector3, to: Vector3, obstacles: Array[AABB]) -> void:
	for ob in obstacles:
		if ob.has_point((from + to) * 0.5):
			var mid := ((from + to) * 0.5) + Vector3(0, ob.size.y + 2.0, 0)
			draw_bezier(from, to, from + Vector3(0, 2, 0), mid)
			return
	draw_bezier(from, to, from + Vector3(0, 2, 0), to + Vector3(0, 2, 0))

func set_active(state: bool) -> void:
	active = state
	if line_mesh and line_mesh.mesh:
		line_mesh.visible = true
		line_mesh.modulate = Color(1, 1, 1) if state else Color(0.4, 0.4, 0.4, 0.6)

func set_law_color() -> void:
	var color := Color(1, 1, 1)
	if law_binding != "":
		color = Color(1.0, 0.65, 0.2) if Scriptura.get_law(law_binding) == "A" else Color(0.2, 0.5, 1.0)
	line_mesh.modulate = color
