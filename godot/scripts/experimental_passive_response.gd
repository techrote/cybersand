extends RefCounted

# Opt-in #400 application experiment. No native material or contact authority.
# Scalar float arithmetic avoids rounding the energy polynomial through Vector2.
static func revalidate(velocity: Vector2, omega: float, mass: float, inertia: float,
		total: Vector2, total_torque: float, passive: Vector2, passive_torque: float,
		enabled: bool) -> Dictionary:
	if not velocity.is_finite() or not total.is_finite() or not passive.is_finite(): return {"valid":false,"error":"nonfinite_vector"}
	for value: float in [omega,mass,inertia,total_torque,passive_torque]:
		if not is_finite(value): return {"valid":false,"error":"nonfinite_scalar"}
	if mass<=0 or inertia<=0: return {"valid":false,"error":"invalid_inertia"}
	var base_x: float = velocity.x+(float(total.x)-passive.x)/mass
	var base_y: float = velocity.y+(float(total.y)-passive.y)/mass
	var base_w: float = omega+(total_torque-passive_torque)/inertia
	var linear: float = base_x*passive.x+base_y*passive.y+base_w*passive_torque
	var quadratic: float = 0.5*((float(passive.x)*passive.x+float(passive.y)*passive.y)/mass+passive_torque*passive_torque/inertia)
	if not is_finite(linear) or not is_finite(quadratic): return {"valid":false,"error":"nonfinite_energy"}
	var retained: float = 1.0
	if enabled and linear+quadratic>0:
		retained=0.0 if linear>=0 or quadratic<=0 else minf(1.0,-linear/quadratic)
	var result_impulse: Vector2 = total+passive*(retained-1.0)
	var result_torque: float = total_torque+passive_torque*(retained-1.0)
	if not result_impulse.is_finite() or not is_finite(result_torque): return {"valid":false,"error":"nonfinite_result"}
	return {"valid":true,"impulse":result_impulse,"torque":result_torque,
		"passive_scale":retained,"passive_energy_linear":linear,"passive_energy_quadratic":quadratic,
		"passive_energy_unscaled":linear+quadratic,"passive_energy_accepted":retained*linear+retained*retained*quadratic,
		"passive_impulse_before":passive,"passive_torque_before":passive_torque}
