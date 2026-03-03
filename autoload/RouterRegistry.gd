extends Node

var routers: Dictionary = {}

signal router_switched(router_id: String, old_output: int, new_output: int)

# DNA: TREE_STRUCTURE | creates router and registers weave node
func create_router(from_script: String, from_function: String, relay_mode: String, selector_mode: String) -> Router:
	var router := Router.new()
	router.router_id = "router_%s_%s_%d" % [from_script.to_lower(), from_function.to_lower(), Time.get_ticks_msec()]
	router.from_script = from_script
	router.from_function = from_function
	router.relay_mode = relay_mode
	router.selector_mode = selector_mode
	add_child(router)
	routers[router.router_id] = router
	router.output_switched.connect(_on_router_switched)
	if Engine.has_singleton("TheWeave"):
		TheWeave.add_node(router.router_id, Vector3.ZERO, "router_layer")
	return router

# DNA: TREE_STRUCTURE | adds output route and weave thread
func add_output_to_router(router_id: String, to_script: String, to_function: String, label: String, law_binding: String, law_state: String) -> void:
	if not routers.has(router_id):
		return
	var router: Router = routers[router_id]
	var index := router.add_output(to_script, to_function, label, law_binding, law_state)
	var thread_id := str(router.outputs[index].get("thread_id", ""))
	if Engine.has_singleton("TheWeave"):
		TheWeave.add_thread(router.router_id, to_script, router.from_function, to_function, law_binding)
	if Engine.has_singleton("ValveRegistry"):
		ValveRegistry.create_valve(thread_id, router.router_id, router.from_function, to_script, to_function)

# DNA: QUERY_GLOBAL | lookup router by id
func get_router(router_id: String) -> Router:
	return routers.get(router_id, null)

# DNA: QUERY_GLOBAL | returns routers sourcing from script id
func get_routers_for_script(script_id: String) -> Array[Router]:
	var out: Array[Router] = []
	for router in routers.values():
		if (router as Router).from_script == script_id:
			out.append(router)
	return out

# DNA: MUTATE_GLOBAL | reevaluates routers bound to changed law
func flip_all_for_law(law_name: String) -> void:
	for router in routers.values():
		for o in (router as Router).outputs:
			if str((o as Dictionary).get("law_binding", "")) == law_name:
				(router as Router)._resolve_active_output()
				break

# DNA: QUERY_NODE | routes switch signal to registry listeners
func _on_router_switched(router_id: String, old_output: int, new_output: int) -> void:
	router_switched.emit(router_id, old_output, new_output)
