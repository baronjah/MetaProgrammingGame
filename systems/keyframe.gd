class_name Keyframe
extends RefCounted

enum ValueType { FLOAT, VECTOR3, COLOR, BASIS, STRING, BOOL, DICTIONARY }

var time: float = 0.0
var value: Variant = 0.0
var value_type: ValueType = ValueType.FLOAT
var easing_in: Easing.Curve = Easing.Curve.EASE_IN_OUT
var easing_out: Easing.Curve = Easing.Curve.EASE_IN_OUT
var label: String = ""
var source: String = ""
var tags: Array[String] = []

# DNA: RETURN_VALUE | auto-tag v1.8
func interpolate_to(next: Keyframe, t: float) -> Variant:
	var eased := Easing.apply(t, easing_out)
	match value_type:
		ValueType.FLOAT:
			return lerp(float(value), float(next.value), eased)
		ValueType.VECTOR3:
			return (value as Vector3).lerp(next.value as Vector3, eased)
		ValueType.COLOR:
			return (value as Color).lerp(next.value as Color, eased)
		ValueType.BASIS:
			return (value as Basis).slerp(next.value as Basis, eased)
		ValueType.BOOL:
			return next.value if t >= 0.5 else value
		ValueType.STRING:
			return next.value if t >= 0.5 else value
		ValueType.DICTIONARY:
			return value
		_:
			return value
