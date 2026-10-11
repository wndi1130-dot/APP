extends RefCounted
## Where a person's arms and weapon sit for the motion they are in. It only
## reads the rules' clocks (shove_t, lunge_t, strike_t, swing_t) and moves
## boxes; it decides nothing. Forward is +z (person.gd turns the whole body by facing).

const ARM_SIZE: Vector3 = Vector3(0.1, 0.1, 0.5)
const ARM_SIDE: float = 0.33
const WEAPON_REST: Vector3 = Vector3(0.3, 1.0, 0.35)
const SHOULDER: Vector3 = Vector3(0.3, 1.0, 0.0)
const SHOVE_WINDUP: float = 0.15     # field_combat.SHOVE_WINDUP: the arms come back this long
const LUNGE: float = 0.15            # field_combat.SHOVE_LUNGE: the arms stay out this long
const META: String = "pose_arms"
const MODE: String = "pose_mode"      # what the swing being drawn is: "swing", "floor" (down at a body on the ground) or "stomp"
const FOOT_SIZE: Vector3 = Vector3(0.18, 0.16, 0.4)
const FOOT_REST: Vector3 = Vector3(0.12, 0.08, 0.1)
const SWING: String = "pose_swing"    # the way back of the swing being drawn: how long it is in all


static func apply(p, lying: bool) -> void:
	var arms: Array = _arms(p)
	for arm in arms:
		arm.visible = not lying
	arms[2].visible = false          # the foot shows only while it stomps
	p.weapon_mesh.position = WEAPON_REST
	p.weapon_mesh.rotation = Vector3.ZERO
	if lying:
		return
	var push := shove_push(p.shove_t, p.lunge_t, SHOVE_WINDUP / float(p.mults()["swing"]))
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var t: Dictionary = arm_at(push, side)
		arms[i].position = t["pos"]
		arms[i].rotation = t["rot"]
	var sw: Array = swing_state(p)
	if sw.is_empty():
		return
	var mode: String = p.get_meta(MODE, "swing")
	if mode == "stomp":
		var st: Dictionary = stomp_at(sw[0], sw[1], sw[2])
		arms[2].visible = true
		arms[2].position = st["pos"]
		# The arms come out for balance while the knee is up.
		for i in 2:
			var t: Dictionary = arm_at(float(st["arms"]), -1.0 if i == 0 else 1.0)
			arms[i].position = t["pos"]
			arms[i].rotation = t["rot"]
		p.body_mesh.rotation.x += float(st["lean"])
		return
	var w: Dictionary = floor_strike_at(sw[0], sw[1], sw[2]) if mode == "floor" else weapon_at(p.weapon_id(), sw[0], sw[1], sw[2])
	p.weapon_mesh.position = w["pos"]
	p.weapon_mesh.rotation = w["rot"]
	p.body_mesh.rotation.x += float(w["lean"])
	# The weapon hand goes with the weapon.
	arms[1].position = (SHOULDER + w["pos"]) * 0.5
	arms[1].rotation = Vector3(0.2, 0, 0)


## Where a melee swing is: [windup 0..1, way back 0..1, landed], or [] with no
## swing. The rules keep the draw-back (strike_t of strike_total); what is left
## of swing_t after it is the way back, a hit or a miss alike.
static func swing_state(p) -> Array:
	if p.strike_t > 0.0:
		p.set_meta(SWING, -1.0)
		p.set_meta(MODE, strike_mode(p.get("strike_kind"), p.strike_at))
		return [1.0 - clampf(p.strike_t / maxf(0.01, p.strike_total), 0.0, 1.0), 0.0, false]
	if not p.has_meta(SWING) or p.swing_t <= 0.0 or p.shove_t > 0.0:
		p.remove_meta(SWING)
		p.remove_meta(MODE)
		return []
	var rest: float = p.get_meta(SWING)
	if rest < p.swing_t:
		rest = p.swing_t
		p.set_meta(SWING, rest)
	return [1.0, 1.0 - clampf(p.swing_t / rest, 0.0, 1.0), true]


## What kind of blow is being drawn back. The rules say whether it is a stomp
## (strike_kind); a weapon aimed at a body on the ground comes straight down.
static func strike_mode(kind, at) -> String:
	if kind is String and kind == "stomp":
		return "stomp"
	if at is Dictionary and at.get("state", "") == "downed":
		return "floor"
	return "swing"


## -1 arms pulled back to the chest, 0 hanging, 1 thrown straight out.
static func shove_push(shove_t: float, lunge_t: float, windup: float) -> float:
	if shove_t > 0.0:
		return -(1.0 - clampf(shove_t / maxf(0.01, windup), 0.0, 1.0))
	if lunge_t > 0.0:
		return ease(clampf(lunge_t / LUNGE, 0.0, 1.0), 0.5)
	return 0.0


## One arm for a push value; side is -1 (left) or 1 (right).
static func arm_at(push: float, side: float) -> Dictionary:
	var hang := {"pos": Vector3(ARM_SIDE * side, 1.0, 0.0), "rot": Vector3(PI * 0.5, 0, 0)}
	var back := {"pos": Vector3(ARM_SIDE * side, 1.15, -0.05), "rot": Vector3(0.3, 0, 0)}
	var out := {"pos": Vector3(0.2 * side, 1.2, 0.5), "rot": Vector3.ZERO}
	var to: Dictionary = back if push < 0.0 else out
	var k := absf(push)
	return {"pos": (hang["pos"] as Vector3).lerp(to["pos"], k), "rot": (hang["rot"] as Vector3).lerp(to["rot"], k)}


## The weapon through a swing. windup runs 0..1 until the blow, recover 0..1
## after it. The weapon is back by DRAW of the windup and comes round in the
## rest of it, so it is there when the rules land the blow; the way back takes
## the rest of the swing time. A knife stabs, a crowbar sweeps across, an axe
## comes down.
const DRAW: float = 0.7

static func weapon_at(wid: String, windup: float, recover: float, landed: bool) -> Dictionary:
	var back := 1.0 if landed else clampf(windup / DRAW, 0.0, 1.0)
	var strike := 1.0 if landed else clampf((windup - DRAW) / (1.0 - DRAW), 0.0, 1.0)
	var keep := 1.0 - (ease(clampf(recover, 0.0, 1.0), -2.0) if landed else 0.0)
	var pos := WEAPON_REST
	var rot := Vector3.ZERO
	var lean := 0.0
	match wid:
		"knife":
			pos.z += lerpf(-0.25 * back, 0.45, strike) * keep
			lean = lerpf(-0.1 * back, 0.25, strike) * keep
		"axe":
			rot.x = lerpf(-1.2 * back, 0.5, strike) * keep
			pos += (Vector3(0, 0.5, -0.15) * back).lerp(Vector3(0, -0.2, 0.25), strike) * keep
			lean = lerpf(-0.2 * back, 0.4, strike) * keep
		_:
			var yaw := lerpf(1.1 * back, -1.0, strike) * keep
			rot.y = yaw
			pos = SHOULDER + Vector3(sin(yaw), 0, cos(yaw)) * WEAPON_REST.z
			lean = lerpf(-0.1 * back, 0.2, strike) * keep
	return {"pos": pos, "rot": rot, "lean": lean}


## Any weapon brought down on a body on the ground: up over the shoulder, then
## straight down in front of the feet, the back bent over it.
static func floor_strike_at(windup: float, recover: float, landed: bool) -> Dictionary:
	var back := 1.0 if landed else clampf(windup / DRAW, 0.0, 1.0)
	var strike := 1.0 if landed else clampf((windup - DRAW) / (1.0 - DRAW), 0.0, 1.0)
	var keep := 1.0 - (ease(clampf(recover, 0.0, 1.0), -2.0) if landed else 0.0)
	var rot := Vector3(lerpf(-1.3 * back, 1.1, strike) * keep, 0, 0)
	var pos := WEAPON_REST + (Vector3(0, 0.45, -0.1) * back).lerp(Vector3(0, -0.55, 0.2), strike) * keep
	return {"pos": pos, "rot": rot, "lean": lerpf(-0.15 * back, 0.6, strike) * keep}


## A stomp: the knee comes up as the body leans back, then the foot goes down
## hard in front. "pos" is the foot.
static func stomp_at(windup: float, recover: float, landed: bool) -> Dictionary:
	var back := 1.0 if landed else clampf(windup / DRAW, 0.0, 1.0)
	var strike := 1.0 if landed else clampf((windup - DRAW) / (1.0 - DRAW), 0.0, 1.0)
	var keep := 1.0 - (ease(clampf(recover, 0.0, 1.0), -2.0) if landed else 0.0)
	var pos := FOOT_REST + (Vector3(0, 0.6, 0.3) * back).lerp(Vector3(0, 0.0, 0.55), strike) * keep
	return {"pos": pos, "lean": lerpf(-0.3 * back, 0.45, strike) * keep, "arms": lerpf(0.5 * back, 0.15, strike) * keep}


## The two arms and, last, the stomping foot.
static func _arms(p) -> Array:
	if p.has_meta(META):
		return p.get_meta(META)
	var arms: Array = []
	var color: Color = (p.body_mesh.mesh.material as StandardMaterial3D).albedo_color.darkened(0.15)
	for i in 2:
		var arm := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = ARM_SIZE
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 1.0
		box.material = mat
		arm.mesh = box
		p.add_child(arm)
		arms.append(arm)
	var foot := MeshInstance3D.new()
	var shoe := BoxMesh.new()
	shoe.size = FOOT_SIZE
	shoe.material = (arms[0].mesh as BoxMesh).material
	foot.mesh = shoe
	foot.visible = false
	p.add_child(foot)
	arms.append(foot)
	p.set_meta(META, arms)
	return arms
