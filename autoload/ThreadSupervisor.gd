extends Node

var active_threads: Dictionary = {}
var resource_locks: Dictionary = {}

# DNA: TREE_STRUCTURE | auto-tag v1.6
func spawn_thread(owner_script: String, callable: Callable) -> String:
	var thread := Thread.new()
	var thread_id := "%s_%d" % [owner_script, Time.get_unix_time_from_system()]
	active_threads[thread_id] = {
		"thread": thread,
		"owner_script": owner_script,
		"locked_resources": [],
		"started_at": Time.get_ticks_msec() / 1000.0,
	}
	thread.start(callable)
	return thread_id

# DNA: RETURN_VALUE | auto-tag v1.6
func claim_resource(thread_id: String, resource_name: String) -> bool:
	var owner := resource_locks.get(resource_name, "")
	if owner == "" or owner == thread_id:
		resource_locks[resource_name] = thread_id
		(active_threads[thread_id]["locked_resources"] as Array).append(resource_name)
		return true
	if Engine.has_singleton("LogCatcher"):
		LogCatcher.log("THREAD", "contention", "%s locked by %s" % [resource_name, owner], LogCatcher.Level.THREAD)
	return false

# DNA: RETURN_VALUE | auto-tag v1.6
func release_resource(thread_id: String, resource_name: String) -> void:
	if resource_locks.get(resource_name, "") == thread_id:
		resource_locks[resource_name] = ""
		(active_threads[thread_id]["locked_resources"] as Array).erase(resource_name)

# DNA: RETURN_VALUE | auto-tag v1.6
func finish_thread(thread_id: String) -> void:
	if not active_threads.has(thread_id):
		return
	var entry: Dictionary = active_threads[thread_id]
	var thread := entry.get("thread") as Thread
	if thread and thread.is_alive():
		thread.wait_to_finish()
	for res in (entry.get("locked_resources", []) as Array):
		release_resource(thread_id, str(res))
	active_threads.erase(thread_id)

# DNA: QUERY_NODE | auto-tag v1.6
func _process(_delta: float) -> void:
	if int(Time.get_ticks_msec()) % 5000 < 17:
		check_deadlock()

# DNA: RETURN_VALUE | auto-tag v1.6
func check_deadlock() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for thread_id in active_threads.keys():
		var entry: Dictionary = active_threads[thread_id]
		if (entry.get("locked_resources", []) as Array).size() > 0 and now - float(entry.get("started_at", now)) > 3.0:
			if Engine.has_singleton("LogCatcher"):
				LogCatcher.log("THREAD", "suspected_deadlock", thread_id, LogCatcher.Level.WARN)
