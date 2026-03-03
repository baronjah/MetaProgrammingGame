class_name FunctionDNA
extends RefCounted

enum Type {
	RETURN_VALUE,
	QUERY_GLOBAL,
	MUTATE_GLOBAL,
	COPY_GLOBAL,
	MUTATE_NODE,
	QUERY_NODE,
	TREE_STRUCTURE,
	CREATE_FILE,
	READ_FILE,
	WRITE_RESOURCE,
	UNKNOWN
}

static func get_color(type: Type) -> Color:
	match type:
		Type.RETURN_VALUE: return Color("#88CCFF")
		Type.QUERY_GLOBAL: return Color("#AAFFAA")
		Type.MUTATE_GLOBAL: return Color("#FFAA44")
		Type.COPY_GLOBAL: return Color("#CCFFCC")
		Type.MUTATE_NODE: return Color("#FFFF88")
		Type.QUERY_NODE: return Color("#FFFFAA")
		Type.TREE_STRUCTURE: return Color("#FF8844")
		Type.CREATE_FILE: return Color("#FF88FF")
		Type.READ_FILE: return Color("#FFCCFF")
		Type.WRITE_RESOURCE: return Color("#FF44FF")
		_: return Color.WHITE

static func requires_main_thread(type: Type) -> bool:
	return type in [Type.MUTATE_NODE, Type.QUERY_NODE, Type.TREE_STRUCTURE]

static func requires_mutex(type: Type) -> bool:
	return type in [Type.MUTATE_GLOBAL, Type.TREE_STRUCTURE, Type.WRITE_RESOURCE]

static func requires_call_deferred(type: Type) -> bool:
	return type == Type.TREE_STRUCTURE

static func get_valve_default(type: Type) -> String:
	match type:
		Type.TREE_STRUCTURE: return "gate_and_queue"
		Type.MUTATE_GLOBAL, Type.WRITE_RESOURCE, Type.MUTATE_NODE: return "log_and_pass"
		_: return "pass_through"

static func get_doctor_priority(type: Type) -> String:
	match type:
		Type.TREE_STRUCTURE: return "critical"
		Type.MUTATE_GLOBAL, Type.WRITE_RESOURCE: return "high"
		Type.MUTATE_NODE: return "medium"
		_: return "low"

static func classify_from_source(func_source: String) -> Type:
	if "add_child" in func_source or "remove_child" in func_source or "reparent" in func_source or "free()" in func_source:
		return Type.TREE_STRUCTURE
	if "FileAccess.open" in func_source:
		if "WRITE" in func_source or "READ_WRITE" in func_source:
			if "does_file_exist" in func_source or "create" in func_source.to_lower():
				return Type.CREATE_FILE
			return Type.WRITE_RESOURCE
		return Type.READ_FILE
	if "return " in func_source and not ("set_" in func_source or ".position" in func_source):
		return Type.RETURN_VALUE
	if "Scriptura." in func_source or "ScriptRegistry." in func_source:
		if "set_" in func_source or "register_" in func_source or "push_" in func_source or "= " in func_source:
			return Type.MUTATE_GLOBAL
		if ".duplicate()" in func_source:
			return Type.COPY_GLOBAL
		return Type.QUERY_GLOBAL
	if ".position" in func_source or ".visible" in func_source or "set_script" in func_source or ".scale" in func_source:
		return Type.MUTATE_NODE
	if "get_path()" in func_source or "is_inside_tree" in func_source:
		return Type.QUERY_NODE
	return Type.UNKNOWN
