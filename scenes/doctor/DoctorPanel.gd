class_name DoctorPanel
extends Node3D

var hold_time: float = 0.0

func _process(delta: float) -> void:
	_update_status()
	_update_health_bar()

func _update_status() -> void:
	var status := "healthy"
	var color := Color(0.2, 1.0, 0.2)
	if SelfDoctor.repair_queue.size() > 0:
		status = "issues"
		color = Color(1.0, 0.65, 0.2)
	if SelfDoctor.known_issues.size() > 10:
		status = "critical"
		color = Color(1.0, 0.2, 0.2)
	if has_node("StatusRing"):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		$StatusRing.material_override = mat
	if has_node("IssueList/Label3D"):
		$IssueList/Label3D.text = "%s (%d)" % [status, SelfDoctor.repair_queue.size()]

func set_mode_observe() -> void:
	SelfDoctor.mode = SelfDoctor.Mode.OBSERVE

func set_mode_assist() -> void:
	SelfDoctor.mode = SelfDoctor.Mode.ASSIST

func set_mode_autonomous() -> void:
	SelfDoctor.mode = SelfDoctor.Mode.AUTONOMOUS

func hold_soft_restart(delta: float, holding: bool) -> void:
	if not holding:
		hold_time = 0.0
		return
	hold_time += delta
	if has_node("SoftRestartButton/Label3D"):
		$SoftRestartButton/Label3D.text = "Restart %.1f/2.0" % hold_time
	if hold_time >= 2.0:
		SelfDoctor.soft_restart()
		hold_time = 0.0

func apply_issue(issue_id: String) -> void:
	SelfDoctor.confirm_repair(issue_id)

func dismiss_issue(issue_id: String) -> void:
	SelfDoctor.reject_repair(issue_id)

func _update_health_bar() -> void:
	if not has_node("HealthBar"):
		return
	var usage := float(OS.get_static_memory_usage()) / float(256 * 1024 * 1024)
	$HealthBar.scale.x = clamp(usage, 0.1, 1.5)
