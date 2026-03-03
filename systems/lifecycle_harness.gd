class_name LifecycleHarness
extends Node3D

var _harness_id: String = ""
var _ready_complete: bool = false
var _thread_lock: Mutex = Mutex.new()
var _last_parent_path: NodePath = NodePath("")

signal harness_ready(script_id: String)
signal harness_process_tick(script_id: String, delta: float)
signal harness_tree_exiting(script_id: String)
signal harness_reparented(script_id: String, old_path: NodePath, new_path: NodePath)

# DNA: RETURN_VALUE | auto-tag v1.6
func _init() -> void:
	_harness_id = _resolve_harness_id()
	if Engine.has_singleton("ScriptRegistry") and not ScriptRegistry.registry.has(_harness_id):
		ScriptRegistry.register_script(_harness_id, "scene_script", get_script().resource_path, null, null)
	tree_entered.connect(_on_tree_entered)
	tree_exiting.connect(_on_tree_exiting)

# DNA: QUERY_NODE | auto-tag v1.6
func _ready() -> void:
	_last_parent_path = get_path()
	_harness_ready_check()
	_ready_complete = true
	harness_ready.emit(_harness_id)
	on_ready()

# DNA: QUERY_NODE | auto-tag v1.6
func _process(delta: float) -> void:
	if _last_parent_path != get_path():
		harness_reparented.emit(_harness_id, _last_parent_path, get_path())
		if Engine.has_singleton("TreeWatcher"):
			TreeWatcher.track_reparent(self, _last_parent_path, get_path())
	_last_parent_path = get_path()
	harness_process_tick.emit(_harness_id, delta)
	on_process(delta)

# DNA: QUERY_NODE | auto-tag v1.6
func _physics_process(delta: float) -> void:
	on_physics_process(delta)

# DNA: QUERY_NODE | auto-tag v1.6
func _input(event: InputEvent) -> void:
	if Engine.has_singleton("CursorEntity"):
		CursorEntity._input(event)
	if not event.is_echo():
		on_input(event)

# DNA: RETURN_VALUE | auto-tag v1.6
func _exit_tree() -> void:
	harness_tree_exiting.emit(_harness_id)
	if Engine.has_singleton("ScriptRegistry") and ScriptRegistry.registry.has(_harness_id):
		ScriptRegistry.registry[_harness_id]["loaded"] = false
		ScriptRegistry.save_registry()
	on_exit_tree()

# DNA: RETURN_VALUE | auto-tag v1.6
func safe_read(callable: Callable) -> Variant:
	_thread_lock.lock()
	var result := callable.call()
	_thread_lock.unlock()
	return result

# DNA: RETURN_VALUE | auto-tag v1.6
func safe_write(callable: Callable) -> void:
	_thread_lock.lock()
	callable.call()
	_thread_lock.unlock()

# DNA: QUERY_NODE | auto-tag v1.6
func _harness_ready_check() -> void:
	for property in get_property_list():
		var p: Dictionary = property
		var name := str(p.get("name", ""))
		if name.begins_with("@"):
			continue
		var value := get(name)
		if value == null and name.find("onready") != -1:
			if Engine.has_singleton("LogCatcher"):
				LogCatcher.warn("HARNESS", "%s null onready: %s @ %s" % [_harness_id, name, str(get_path())])

# DNA: QUERY_NODE | auto-tag v1.6
func on_ready() -> void:
	pass

# DNA: QUERY_NODE | auto-tag v1.6
func on_process(_delta: float) -> void:
	pass

# DNA: QUERY_NODE | auto-tag v1.6
func on_physics_process(_delta: float) -> void:
	pass

# DNA: QUERY_NODE | auto-tag v1.6
func on_input(_event: InputEvent) -> void:
	pass

# DNA: RETURN_VALUE | auto-tag v1.6
func on_exit_tree() -> void:
	pass

# DNA: RETURN_VALUE | auto-tag v1.6
func _on_tree_entered() -> void:
	if Engine.has_singleton("LogCatcher"):
		LogCatcher.log("TREE", "entered", str(get_path()), LogCatcher.Level.TREE)

# DNA: RETURN_VALUE | auto-tag v1.6
func _on_tree_exiting() -> void:
	if Engine.has_singleton("LogCatcher"):
		LogCatcher.log("TREE", "exiting", str(get_path()), LogCatcher.Level.TREE)

# DNA: RETURN_VALUE | auto-tag v1.6
func _resolve_harness_id() -> String:
	if get_script() and get_script().resource_path != "":
		return get_script().resource_path.get_file().trim_suffix(".gd")
	return name
