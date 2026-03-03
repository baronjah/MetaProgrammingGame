class_name LogicGate
extends Node

enum GateType { AND, OR, NOT, XOR, NAND, NOR }

var gate_type: GateType = GateType.AND
var input_states: Dictionary = {}
var output_callable: Callable
var gate_id: String = ""

# DNA: MUTATE_GLOBAL | records input and triggers output on truthy evaluation
func receive_input(input_id: String, state: bool) -> void:
	input_states[input_id] = state
	if _evaluate() and output_callable.is_valid():
		output_callable.call()

# DNA: RETURN_VALUE | boolean evaluation of current gate state
func _evaluate() -> bool:
	if input_states.size() == 0:
		return false
	var values: Array = input_states.values()
	match gate_type:
		GateType.AND:
			return values.all(func(v: Variant) -> bool: return bool(v))
		GateType.OR:
			return values.any(func(v: Variant) -> bool: return bool(v))
		GateType.NOT:
			return not bool(values[0])
		GateType.XOR:
			var count := values.filter(func(v: Variant) -> bool: return bool(v)).size()
			return count == 1
		GateType.NAND:
			return not values.all(func(v: Variant) -> bool: return bool(v))
		GateType.NOR:
			return not values.any(func(v: Variant) -> bool: return bool(v))
	return false
