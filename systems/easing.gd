class_name Easing
extends RefCounted

enum Curve {
	LINEAR,
	EASE_IN,
	EASE_OUT,
	EASE_IN_OUT,
	EASE_OUT_IN,
	SPRING,
	BOUNCE,
	STEP,
	CUSTOM,
}

# DNA: RETURN_VALUE | auto-tag v1.8
static func apply(t: float, curve: Curve, custom_curve: Variant = null) -> float:
	var c := clamp(t, 0.0, 1.0)
	match curve:
		Curve.LINEAR:
			return c
		Curve.EASE_IN:
			return c * c * c
		Curve.EASE_OUT:
			return 1.0 - pow(1.0 - c, 3.0)
		Curve.EASE_IN_OUT:
			if c < 0.5:
				return 4.0 * c * c * c
			return 1.0 - pow(-2.0 * c + 2.0, 3.0) / 2.0
		Curve.EASE_OUT_IN:
			if c < 0.5:
				return 0.5 * apply(c * 2.0, Curve.EASE_OUT)
			return 0.5 + 0.5 * apply((c - 0.5) * 2.0, Curve.EASE_IN)
		Curve.SPRING:
			var s := 1.70158
			return c * c * ((s + 1.0) * c - s)
		Curve.BOUNCE:
			if c < 1.0 / 2.75:
				return 7.5625 * c * c
			elif c < 2.0 / 2.75:
				c -= 1.5 / 2.75
				return 7.5625 * c * c + 0.75
			elif c < 2.5 / 2.75:
				c -= 2.25 / 2.75
				return 7.5625 * c * c + 0.9375
			c -= 2.625 / 2.75
			return 7.5625 * c * c + 0.984375
		Curve.STEP:
			return 0.0 if c < 0.5 else 1.0
		Curve.CUSTOM:
			if custom_curve != null and custom_curve.has_method("sample"):
				return clamp(float(custom_curve.sample(c)), 0.0, 1.0)
			return c
		_:
			return c

# DNA: RETURN_VALUE | auto-tag v1.8
static func apply_with_speed(current: float, target: float, speed: float, delta: float, curve: Curve) -> float:
	var distance := target - current
	if absf(distance) < 0.0001:
		return target
	var raw_t := clamp(speed * delta / absf(distance), 0.0, 1.0)
	var eased_t := apply(raw_t, curve)
	return lerp(current, target, eased_t)
