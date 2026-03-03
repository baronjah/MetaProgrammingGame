class_name GovernorPanel
extends Node3D

var frame_history: Array[float] = []

# DNA: QUERY_NODE | auto-tag v1.6
func _process(_delta: float) -> void:
	_update_fps()
	_update_budget()
	_update_queues()
	_update_history()

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func set_mode(mode: String) -> void:
	FrameGovernor.set_mode(mode)

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func _update_fps() -> void:
	if has_node("FPSDisplay"):
		$FPSDisplay.text = "FPS %.1f / %.1f" % [Engine.get_frames_per_second(), FrameGovernor.target_fps]
	if has_node("OverrunCounter"):
		$OverrunCounter.text = "Overruns: %d" % FrameGovernor.frame_overrun_count

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func _update_budget() -> void:
	if not has_node("BudgetBar"):
		return
	var usage := FrameGovernor.last_frame_ms / max(FrameGovernor.budget_ms, 0.001)
	$BudgetBar.scale.x = clamp(usage, 0.1, 1.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2,1,0.2) if usage < 0.6 else (Color(1,0.65,0.2) if usage < 0.85 else Color(1,0.2,0.2))
	$BudgetBar.material_override = mat

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func _update_queues() -> void:
	if not has_node("QueueVisualizer"):
		return
	for c in $QueueVisualizer.get_children():
		c.queue_free()
	var depths := FrameGovernor.get_queue_depths()
	for i in range(depths.size()):
		var bar := MeshInstance3D.new()
		bar.mesh = PlaneMesh.new()
		bar.position = Vector3(i * 0.3, 0, 0)
		bar.scale = Vector3(0.2, 0.1 + float(depths[i]) * 0.03, 1)
		$QueueVisualizer.add_child(bar)

# DNA: MUTATE_GLOBAL | auto-tag v1.6
func _update_history() -> void:
	frame_history.append(FrameGovernor.last_frame_ms)
	if frame_history.size() > 30:
		frame_history.pop_front()
	if not has_node("FrameHistory"):
		return
	for c in $FrameHistory.get_children():
		c.queue_free()
	for i in range(frame_history.size()):
		var bar := MeshInstance3D.new()
		bar.mesh = PlaneMesh.new()
		bar.position = Vector3(-2.0 + i * 0.12, -0.6, 0)
		bar.scale = Vector3(0.05, frame_history[i] / 10.0, 1)
		$FrameHistory.add_child(bar)
