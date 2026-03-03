class_name LawInterpolator
extends RefCounted

# DNA: RETURN_VALUE | auto-tag v1.8
static func blend_float(law_name: String, val_a: float, val_b: float) -> float:
	return lerp(val_b, val_a, Scriptura.get_law_blend(law_name))

# DNA: RETURN_VALUE | auto-tag v1.8
static func blend_color(law_name: String, col_a: Color, col_b: Color) -> Color:
	return col_b.lerp(col_a, Scriptura.get_law_blend(law_name))

# DNA: RETURN_VALUE | auto-tag v1.8
static func blend_vector3(law_name: String, v_a: Vector3, v_b: Vector3) -> Vector3:
	return v_b.lerp(v_a, Scriptura.get_law_blend(law_name))

# DNA: RETURN_VALUE | auto-tag v1.8
static func blend_basis(law_name: String, b_a: Basis, b_b: Basis) -> Basis:
	return b_b.slerp(b_a, Scriptura.get_law_blend(law_name))
