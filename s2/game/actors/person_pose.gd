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
const BLOW_WAY: String = "pose_blow_way"   # which way of its blows the swing is drawn as (person_visual.gd blow_of; field_combat.gd notes it on what it strikes)
const FOOT_SIZE: Vector3 = Vector3(0.18, 0.16, 0.4)
const FOOT_REST: Vector3 = Vector3(0.12, 0.08, 0.1)
const SWING: String = "pose_swing"    # the way back of the swing being drawn: how long it is in all
const Protest = preload("res://game/actors/person_protest.gd")
const W = preload("res://game/sim/weapons.gd")
const LOADED: String = "pose_loaded"  # rounds in the hand's weapon last frame; one fewer is a shot
const KICK_AT: String = "pose_kick_at"
const KICK_MS: float = 180.0          # how long a shot throws the gun back, milliseconds (picture only)


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
		# Left on the platform and shouting after the train (person_protest.gd); a blow or a shove is drawn first.
		if p.shove_t <= 0.0 and p.lunge_t <= 0.0:
			if _hands_busy(p, arms):
				return
			var mark: Dictionary = Protest.mark_of(p, Time.get_ticks_msec())
			if not mark.is_empty():
				_protest(p, arms, mark)
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


static func _protest(p, arms: Array, mark: Dictionary) -> void:
	var d: Dictionary = Protest.at(int(mark.get("kind", 0)), float(mark.get("t", 0.0)))
	var lean: float = d["lean"]
	var lift: float = d["lift"]
	for i in 2:
		arms[i].position = d["arms"][i]["pos"] + Vector3(0, lift, 0)
		arms[i].rotation = d["arms"][i]["rot"]
	p.body_mesh.rotation.x += lean
	p.body_mesh.position.y += lift - lean * 0.25
	p.head_mesh.position += Vector3(0, lift - lean * 0.5, lean * 0.4)


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


# ---------------------------------------------------------------- hands at work
# Held by the dead, a door kicked or prised, a jam cleared, a gun loaded or
# aimed: each only reads the rules' clocks (grabbers, action_t, jam_t,
# reload_t, aim). Nothing here changes a rule. A pose is
# {"weapon": {pos, rot}, "arms": [{pos, rot}, {pos, rot}], "lean", "foot"?}.

## How the hand's weapon is held: "one" (a gun in one hand), "two" (a long
## gun), "bow", or "" (a melee weapon or nothing).
static func hold_of(wid: String) -> String:
	var d: Dictionary = W.get_data(wid)
	match String(d.get("kind", "")):
		"bow":
			return "bow"
		"gun":
			return "one" if int(d.get("hands", 1)) == 1 else "two"
	return ""


static func _pose(wpos: Vector3, wrot: Vector3, left: Dictionary, right: Dictionary, lean: float) -> Dictionary:
	return {"weapon": {"pos": wpos, "rot": wrot}, "arms": [left, right], "lean": lean}


static func _arm(pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"pos": pos, "rot": rot}


## Aimed: a pistol held out at the eye in the right hand, a long gun at the
## shoulder with the left hand under the barrel, a bow out in the left hand and
## the string drawn back to the cheek by `draw` (0..1). `kick` (0..1) is a shot
## just fired: the muzzle comes up and the gun back.
static func aim_at(hold: String, kick: float = 0.0, draw: float = 1.0) -> Dictionary:
	var hang_l := arm_at(0.0, -1.0)
	var k := clampf(kick, 0.0, 1.0)
	match hold:
		"one":
			return _pose(Vector3(0.15, 1.38 + 0.05 * k, 0.72 - 0.08 * k), Vector3(-0.6 * k, 0, 0), hang_l, _arm(Vector3(0.15, 1.35, 0.42 - 0.05 * k), Vector3(-0.3 * k, 0, 0)), -0.04 * k)
		"two":
			return _pose(Vector3(0.12, 1.35 + 0.04 * k, 0.48 - 0.1 * k), Vector3(-0.35 * k, 0, 0), _arm(Vector3(0.05, 1.28, 0.55 - 0.08 * k)), _arm(Vector3(0.2, 1.25, 0.2 - 0.08 * k), Vector3(0.3, 0, 0)), 0.05 - 0.12 * k)
		"bow":
			var d := clampf(draw, 0.0, 1.0)
			return _pose(Vector3(-0.1, 1.35, 0.7), Vector3.ZERO, _arm(Vector3(-0.1, 1.35, 0.45)), _arm(Vector3(0.0, 1.38, 0.55).lerp(Vector3(0.12, 1.42, 0.12), d)), 0.0)
	return {}


## Loading, u (0..1) running through it: the gun comes down to the waist, the
## left hand goes from the belt to the gun and back; for a bow the right hand
## goes over the shoulder for an arrow and down to the string.
static func reload_at(hold: String, u: float) -> Dictionary:
	var reach := 0.5 - 0.5 * cos(TAU * clampf(u, 0.0, 1.0))   # 0 at the belt, 1 at the gun, back again
	if hold == "bow":
		var quiver := Vector3(0.2, 1.55, -0.15)
		return _pose(Vector3(-0.1, 1.2, 0.45), Vector3.ZERO, _arm(Vector3(-0.1, 1.2, 0.3)), _arm(quiver.lerp(Vector3(-0.02, 1.25, 0.4), reach), Vector3(0.3, 0, 0)), 0.05)
	var gun := Vector3(0.1, 1.05, 0.35)
	return _pose(gun, Vector3(0.5, 0, 0), _arm(Vector3(-0.25, 1.0, 0.05).lerp(gun + Vector3(-0.08, 0.05, 0.0), reach), Vector3(PI * 0.5, 0, 0).lerp(Vector3(0.6, 0, 0), reach)), _arm(Vector3(0.15, 1.1, 0.25), Vector3(0.4, 0, 0)), 0.1)


## Clearing a jam: the gun turned on its side close to the chest, the body
## bent over it, the left hand knocking at it three times a second.
static func jam_at(u: float) -> Dictionary:
	var knock := 0.05 * sin(TAU * 3.0 * u)
	return _pose(Vector3(0.05, 1.25, 0.4), Vector3(0.2, 0.7, 0), _arm(Vector3(0.0, 1.3, 0.38 + knock)), _arm(Vector3(0.15, 1.2, 0.25), Vector3(0.3, 0, 0)), 0.15)


## Prising a door: the bar low in the gap, both hands on it, the back bent,
## levering twice a second.
static func pry_at(u: float) -> Dictionary:
	var lever := 0.25 * sin(TAU * 2.0 * u)
	return _pose(Vector3(0.05, 0.85, 0.6), Vector3(1.0 + lever, 0, 0), _arm(Vector3(-0.08, 1.0, 0.45), Vector3(0.5, 0, 0)), _arm(Vector3(0.12, 1.0, 0.42), Vector3(0.5, 0, 0)), 0.35)


## Kicking a door, u (0..1) through the try: the knee comes up, then the sole
## goes straight out at the door. "foot" is the foot.
static func kick_at(u: float) -> Dictionary:
	var back := clampf(u / DRAW, 0.0, 1.0)
	var strike := clampf((u - DRAW) / (1.0 - DRAW), 0.0, 1.0)
	var foot := FOOT_REST + (Vector3(0, 0.45, 0.1) * back).lerp(Vector3(0, 0.45, 0.65), strike)
	var pose := _pose(WEAPON_REST, Vector3.ZERO, arm_at(0.3, -1.0), arm_at(0.3, 1.0), lerpf(-0.1 * back, -0.3, strike))
	pose["foot"] = foot
	return pose


## Held by the dead: both arms out against them, shaking; leaning back from
## one in front, bent forward under one behind.
static func held_at(front: bool, t: float) -> Dictionary:
	var shake := 0.06 * sin(TAU * 7.0 * t)
	var l: Dictionary = arm_at(0.75, -1.0)
	var r: Dictionary = arm_at(0.75, 1.0)
	l["pos"] += Vector3(0, shake, 0)
	r["pos"] -= Vector3(0, shake, 0)
	return _pose(WEAPON_REST, Vector3.ZERO, l, r, -0.15 if front else 0.2)


## The kick of a shot, 0..1: watches the rounds in the hand's gun, and one
## fewer than last frame is a shot (reloading only ever adds).
static func _kick(p, now_ms: int) -> float:
	var h: Dictionary = p.weapon()
	var loaded := int(h.get("loaded", 0)) if not h.is_empty() else 0
	# A weapon swapped into the hand starts its own count.
	var key := "%s:%d" % [p.weapon_id(), loaded]
	var was: String = String(p.get_meta(LOADED, key))
	p.set_meta(LOADED, key)
	if was.get_slice(":", 0) == p.weapon_id() and loaded < int(was.get_slice(":", 1)):
		p.set_meta(KICK_AT, now_ms)
	if not p.has_meta(KICK_AT):
		return 0.0
	return 1.0 - clampf(float(now_ms - int(p.get_meta(KICK_AT))) / KICK_MS, 0.0, 1.0)


## How far a bow is drawn: the aim circle from its widest (0) to its floor (1).
static func _draw(p) -> float:
	var d: Dictionary = W.get_data(p.weapon_id())
	var widest := float(d.get("start_deg", 0.0))
	var span := widest - float(p.aim.floor_deg)
	if span <= 0.0:
		return 1.0
	return clampf((widest - float(p.aim.deg)) / span, 0.0, 1.0)


## Draws the first of the hands-at-work poses that applies; false if none does.
static func _hands_busy(p, arms: Array) -> bool:
	var now_ms := Time.get_ticks_msec()
	var t := float(now_ms) / 1000.0
	var hold := hold_of(p.weapon_id())
	var kick := _kick(p, now_ms)
	var pose: Dictionary = {}
	if not p.grabbers.is_empty():
		pose = held_at(p.grab_front, t)
	elif p.action == "kick" and p.action_total > 0.0:
		pose = kick_at(1.0 - p.action_t / p.action_total)
	elif p.action == "pry" and p.action_total > 0.0:
		pose = pry_at(1.0 - p.action_t / p.action_total)
	elif hold != "" and p.jam_t > 0.0:
		pose = jam_at(t)
	elif hold != "" and p.reload_t > 0.0:
		var total := float(W.get_data(p.weapon_id()).get("reload", 1.0))
		pose = reload_at(hold, 1.0 - clampf(p.reload_t / maxf(0.01, total), 0.0, 1.0))
	elif hold != "" and (p.aim.active or kick > 0.0):
		pose = aim_at(hold, kick, _draw(p) if p.aim.active else 1.0)
	if pose.is_empty():
		return false
	p.weapon_mesh.position = pose["weapon"]["pos"]
	p.weapon_mesh.rotation = pose["weapon"]["rot"]
	for i in 2:
		arms[i].position = pose["arms"][i]["pos"]
		arms[i].rotation = pose["arms"][i]["rot"]
	if pose.has("foot"):
		arms[2].visible = true
		arms[2].position = pose["foot"]
	p.body_mesh.rotation.x += float(pose["lean"])
	return true


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
