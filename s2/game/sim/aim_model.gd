extends RefCounted
# One shooter's aim circle (field_unified 10 '조준 안정화'). Angles are half-angles in degrees.

const W = preload("res://game/sim/weapons.gd")

const HEAD_R := 0.13
const BODY_R := 0.34
const MOVE_GROW := 1.5     # moving pushes the circle toward start_deg x this
const BLOOM_CAP := 1.6     # firing never opens past start_deg x this
const CLOSE_MULT := 2.0    # enemy within 1.8 m doubles the floor
const MIN_SHRINK_SPAN := 0.25  # shrink speed never drops below start_deg x this / shrink_time

var weapon_id: String = ""
var deg: float = 0.0
var floor_deg: float = 0.0
var active: bool = false


func start(p_weapon_id: String, mods: Dictionary) -> void:
	weapon_id = p_weapon_id
	deg = _start_deg() * float(mods.get("spread", 1.0))
	floor_deg = compute_floor(mods)
	active = true


func stop() -> void:
	active = false


# Floor the circle can shrink to under these mods.
func compute_floor(mods: Dictionary) -> float:
	var q: String = mods.get("quality", "factory")
	var skill: int = int(mods.get("skill", 0))
	var f: float = W.min_deg(weapon_id, q, skill) * float(mods.get("min_mult", 1.0))
	if bool(mods.get("enemy_close", false)):
		f *= CLOSE_MULT
	return minf(f, _start_deg() * BLOOM_CAP)


func tick(delta: float, mods: Dictionary) -> void:
	if not active or delta <= 0.0:
		return
	var s: float = _start_deg()
	floor_deg = compute_floor(mods)
	if bool(mods.get("moving", false)):
		var target: float = maxf(s * MOVE_GROW, floor_deg)
		if deg < target:
			deg = minf(target, deg + s * delta)
		return
	if deg < floor_deg:
		# Floor rose (enemy closed in): open up at the moving rate.
		deg = minf(floor_deg, deg + s * delta)
		return
	var shrink_time: float = maxf(0.01, float(W.get_data(weapon_id).get("shrink_time", 1.0)))
	var span: float = maxf(s - floor_deg, s * MIN_SHRINK_SPAN)
	var rate: float = span / shrink_time * float(mods.get("shrink_mult", 1.0))
	deg = maxf(floor_deg, deg - rate * delta)


func fire() -> void:
	var cap: float = _start_deg() * BLOOM_CAP
	var bloom: float = float(W.get_data(weapon_id).get("bloom_deg", 0.0))
	deg = maxf(deg, minf(deg + bloom, cap))


# Circle radius (m) at this distance.
func radius_at(distance: float) -> float:
	return maxf(0.0, distance) * tan(deg_to_rad(deg))


func _start_deg() -> float:
	return float(W.get_data(weapon_id).get("start_deg", 0.0))


# Uniform point in a disc of radius r.
static func disc_point(rng: RandomNumberGenerator, r: float) -> Vector2:
	var dist: float = maxf(0.0, r) * sqrt(rng.randf())
	var ang: float = rng.randf() * TAU
	return Vector2(cos(ang), sin(ang)) * dist


# One shot: where inside the circle it lands. "head" / "body" / "miss".
static func roll(rng: RandomNumberGenerator, radius_m: float, head_r: float = HEAD_R, body_r: float = BODY_R) -> String:
	var dist: float = maxf(0.0, radius_m) * sqrt(rng.randf())
	return _zone(dist, head_r, body_r)


# Shotgun: aim point rolled in the circle, each pellet scattered spread_m around it.
static func pellet_hits(rng: RandomNumberGenerator, radius_m: float, spread_m: float, pellets: int, head_r: float = HEAD_R, body_r: float = BODY_R) -> Dictionary:
	var out: Dictionary = {"head": 0, "body": 0}
	var aim: Vector2 = disc_point(rng, radius_m)
	for _i in range(maxi(0, pellets)):
		var p: Vector2 = aim + disc_point(rng, spread_m)
		var z: String = _zone(p.length(), head_r, body_r)
		if z != "miss":
			out[z] = int(out[z]) + 1
	return out


static func _zone(dist: float, head_r: float, body_r: float) -> String:
	if dist <= head_r:
		return "head"
	if dist <= body_r:
		return "body"
	return "miss"
