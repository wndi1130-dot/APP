extends RefCounted
## Fights in the field: melee swings, aimed shots, shoves, grabs, bites and
## falls (field_unified 10, body_injury 2·3·4.2, weapons.md, zombies.md).
## Everything here reads and writes the field_game node.

const FieldGrid = preload("res://game/world/field_grid.gd")
const W = preload("res://game/sim/weapons.gd")
const AimModel = preload("res://game/sim/aim_model.gd")
const GrabRules = preload("res://game/sim/grab_rules.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const Carry = preload("res://game/sim/carry.gd")
const BodyState = preload("res://game/sim/body_state.gd")

const SHOVE_REACH: float = 1.3
const SHOVE_COS: float = 0.3
const SHOVE_KNOCK: float = 0.35
const SHOVE_TIME: float = 0.5
const CLOSE: float = 1.8
const JAM_CLEAR: float = 2.5
const FALL_TIME: float = 1.5
const BEHIND_COS: float = -0.3
const RAIDER_AMMO: int = 6

var game
var tracers: Array = []                 # {"from", "to", "t"} for the view
var kills: int = 0


func _init(field_game) -> void:
	game = field_game


func update(delta: float) -> void:
	for p in game.people_alive():
		var m: Dictionary = p.mults()
		p.swing_t = maxf(0.0, p.swing_t - delta)
		if p.jam_t > 0.0:
			p.jam_t -= delta * float(m["hands"])
			if p.jam_t <= 0.0 and p == game.player:
				game.hud.toast("걸림을 풀었다.")
		if p.reload_t > 0.0:
			p.reload_t -= delta * float(m["reload"])
			if p.reload_t <= 0.0:
				_finish_reload(p)
		if p.aim.active:
			if not p.can_act() or not W.is_ranged(p.weapon_id()):
				p.aim.stop()
			else:
				p.aim.tick(delta, aim_mods(p))
		if not p.can_act():
			continue
		if not p.target_zombie.is_empty():
			_pursue_zombie(p, delta)
		elif p.target_person != null and p.team != "raider":
			_pursue_person(p, delta)
	var keep: Array = []
	for t in tracers:
		t["t"] -= delta
		if t["t"] > 0.0:
			keep.append(t)
	tracers = keep


# ---------------------------------------------------------------- melee

## Tap on a zombie: walk up and swing once; hold keeps swinging.
func melee_target(p, z: Dictionary, hold: bool = false) -> void:
	p.target_zombie = z
	p.target_person = null
	p.hold_attack = hold
	p.brain["repath_t"] = 0.0


func melee_person(p, other) -> void:
	p.target_person = other
	p.target_zombie = {}
	p.hold_attack = true
	p.brain["repath_t"] = 0.0


func _pursue_zombie(p, delta: float) -> void:
	var z: Dictionary = p.target_zombie
	if z.is_empty() or z["state"] == "dead":
		p.target_zombie = {}
		return
	var wid: String = p.weapon_id()
	var reach: float = float(W.get_data(wid).get("reach", 0.9)) if not W.is_ranged(wid) else 0.9
	var d: float = p.position.distance_to(z["pos"])
	if d > reach + 0.15:
		p.brain["repath_t"] = float(p.brain.get("repath_t", 0.0)) - delta
		if p.brain["repath_t"] <= 0.0 or p.path.is_empty():
			p.brain["repath_t"] = 0.4
			var path: PackedVector3Array = game.grid.find_path(p.position, z["pos"], false)
			if path.size() > 0:
				path[path.size() - 1] = z["pos"] + (p.position - z["pos"]).normalized() * (reach * 0.8)
			p.go_to(path, p.running)
		return
	p.stop()
	p.face_point(z["pos"])
	if p.swing_t > 0.0:
		return
	if W.is_ranged(wid):
		shove(p)
	else:
		swing(p, z)
	if not p.hold_attack:
		p.target_zombie = {}


func _pursue_person(p, delta: float) -> void:
	var o = p.target_person
	if o == null or not o.is_alive() or o.body.downed:
		p.target_person = null
		return
	var wid: String = p.weapon_id()
	var reach: float = float(W.get_data(wid).get("reach", 0.9)) if not W.is_ranged(wid) else 0.9
	var d: float = p.position.distance_to(o.position)
	if d > reach + 0.15:
		p.brain["repath_t"] = float(p.brain.get("repath_t", 0.0)) - delta
		if p.brain["repath_t"] <= 0.0 or p.path.is_empty():
			p.brain["repath_t"] = 0.4
			p.go_to(game.grid.find_path(p.position, o.position, false), p.running)
		return
	p.stop()
	p.face_point(o.position)
	if p.swing_t <= 0.0:
		swing_person(p, o)


static func behind(z: Dictionary, attacker_pos: Vector3) -> bool:
	var forward := Vector3(sin(z["angle"]), 0, cos(z["angle"]))
	var to_a: Vector3 = attacker_pos - z["pos"]
	to_a.y = 0
	if to_a.length() < 0.01:
		return false
	return forward.dot(to_a.normalized()) < BEHIND_COS


## One melee swing at a zombie (weapons.md S2 rows, zombies.md kinds).
func swing(p, z: Dictionary) -> void:
	var rng: RandomNumberGenerator = game.rng
	var now: float = game.clock.elapsed
	var wid: String = p.weapon_id()
	var d: Dictionary = W.get_data(wid)
	if d.is_empty() or d.get("kind", "") != "melee":
		shove(p)
		return
	var m: Dictionary = p.mults()
	p.swing_t = float(d["swing"]) / float(m["swing"])
	p.body.add_fatigue(float(d["fatigue"]) * BodyState.fatigue_mult({"carry_state": p.carry_state(), "cold_level": p.cold_level()}))
	_wear(p, W.wear_per_use(wid, String(p.weapon()["quality"])))
	game.make_sound(z["pos"], SimNoise.Level.QUIET, "melee", p)
	var state: String = z["state"]
	var blade: bool = bool(d["blade"])
	# Rising corpse: crush the head before it stands (zombies.md 갓 일어난 자).
	if state == "rising":
		_kill(p, z, "머리를 부쉈다")
		return
	# Frozen: blunt or heavy blows shatter the frozen body; a knife wakes it.
	if state == "frozen" or state == "waking":
		if wid == "knife":
			game.zombies.wake(z)
			_toast(p, "칼날이 언 몸에 박혔다.")
		else:
			_kill(p, z, "언 몸이 부서졌다")
		return
	var from_back := behind(z, p.position)
	# Quiet kill from behind: knife, crouched, the thing has not noticed anyone.
	if wid == "knife" and p.crouched and from_back and state != "chase" and state != "attack" and state != "grab":
		_kill(p, z, "뒤에서 조용히 끝냈다")
		return
	var downed: bool = state == "downed"
	var head: float = W.melee_head_chance(wid, int(p.skills["melee"]), downed, from_back)
	if z["kind"] == "clothed" and blade and not downed:
		head *= 0.5
	if rng.randf() < head:
		if rng.randf() < float(d["head_kill"]) or downed:
			_kill(p, z, "")
		else:
			game.zombies.knock_down(z)
		return
	# Body hit: the thick coat of a 껴입은 자 stops blades (zombies.md).
	if z["kind"] == "clothed" and blade:
		z["stun"] = 0.3
		_toast(p, "두꺼운 옷에 날이 막혔다.")
		return
	if rng.randf() < float(d["knockdown"]):
		game.zombies.knock_down(z)
	else:
		z["stun"] = 0.6
		_push(z, p.position, 0.3)


## Raider or squad melee on a person. Hit chance from melee skill.
func swing_person(p, o) -> void:
	var rng: RandomNumberGenerator = game.rng
	var wid: String = p.weapon_id()
	var d: Dictionary = W.get_data(wid)
	var m: Dictionary = p.mults()
	if d.is_empty() or d.get("kind", "") != "melee":
		p.swing_t = SHOVE_TIME
		o.fallen_t = maxf(o.fallen_t, 0.6)
		return
	p.swing_t = float(d["swing"]) / float(m["swing"])
	p.body.add_fatigue(float(d["fatigue"]))
	game.make_sound(o.position, SimNoise.Level.NORMAL, "fight", p)
	var hit: float = clampf(0.45 + 0.05 * int(p.skills["melee"]) - 0.03 * int(o.skills["melee"]), 0.2, 0.85)
	if rng.randf() < hit:
		o.body.apply_cut(wid == "axe" or rng.randf() < 0.3, game.clock.elapsed)
		o.last_hurt_by = p.pid
		game.telemetry.injury(game.clock.elapsed, o.pid, "cut")
		if o.team == "raider":
			game.ai.raider_hit(o, p)
		elif o == game.player or o.team == "squad":
			game.say(o, "%s 베였다." % o.display_name)


func _kill(p, z: Dictionary, msg: String) -> void:
	game.zombies.kill(z)
	kills += 1
	if p != null and p.team != "raider":
		if msg != "":
			_toast(p, msg)
		if p.note_close_kill(game.clock.elapsed):
			_toast(p, "%s 옷이 피로 젖었다. 눈으로 문지르면 지워진다." % p.display_name)


## Shove: a short cone in front, breaks a grab, sometimes knocks down.
func shove(p) -> void:
	var rng: RandomNumberGenerator = game.rng
	var m: Dictionary = p.mults()
	p.swing_t = SHOVE_TIME / float(m["swing"])
	p.body.add_fatigue(0.003)
	var forward := Vector3(sin(p.facing), 0, cos(p.facing))
	var hit := 0
	for z in game.zombies.in_radius(p.position, SHOVE_REACH):
		if z["state"] == "frozen" or z["state"] == "downed" or z["state"] == "rising":
			continue
		var to_z: Vector3 = z["pos"] - p.position
		to_z.y = 0
		var grabbing: bool = p.grabbers.has(z)
		if not grabbing and to_z.length() > 0.2 and forward.dot(to_z.normalized()) < SHOVE_COS:
			continue
		if grabbing:
			p.release_grab(z)
		game.zombies.release(z, p.position, rng.randf() < SHOVE_KNOCK)
		hit += 1
	if hit > 0 and p.grabbers.is_empty():
		p.grab_left = 0.0
	return


## A grabbed person shoves free (player button or companion reflex).
func break_grab(p) -> bool:
	if p.grabbers.is_empty() or p.grab_left <= 0.0:
		return false
	for z in p.grabbers.duplicate():
		game.zombies.release(z, p.position, game.rng.randf() < SHOVE_KNOCK)
	p.grabbers.clear()
	p.grab_left = 0.0
	p.swing_t = SHOVE_TIME
	return true


func _push(z: Dictionary, from: Vector3, dist: float) -> void:
	var away: Vector3 = z["pos"] - from
	away.y = 0
	if away.length() < 0.01:
		return
	var dest: Vector3 = z["pos"] + away.normalized() * dist
	if not game.grid.blocks_body(FieldGrid.cell_of(dest)):
		z["pos"] = dest


func _wear(p, amount: float) -> void:
	if p.hands.is_empty():
		return
	var h: Dictionary = p.hands[0]
	h["condition"] = maxf(0.0, float(h["condition"]) - amount)


func _toast(p, text: String) -> void:
	if p == game.player:
		game.hud.toast(text)


# ---------------------------------------------------------------- grabs and bites

## A dead hand reaches a person (body_injury 2): grab, scratch or blocked.
func zombie_reaches(z: Dictionary, p) -> String:
	var rng: RandomNumberGenerator = game.rng
	var now: float = game.clock.elapsed
	var block: float = float(p.coat.get("block", 0.0)) * (1.0 - float(p.coat.get("wear", 0.0)))
	var outcome: String = GrabRules.attack_outcome(rng, block)
	match outcome:
		"grab":
			var forward := Vector3(sin(p.facing), 0, cos(p.facing))
			var to_z: Vector3 = z["pos"] - p.position
			to_z.y = 0
			var front: bool = to_z.length() < 0.01 or forward.dot(to_z.normalized()) > 0.0
			if not p.grabbers.has(z):
				p.grabbers.append(z)
			var window: float = GrabRules.window(front, p.grabbers.size(), int(p.skills["melee"]), int(p.skills["strength"]), float(p.mults()["shove_window"]))
			if p.grabbers.size() == 1:
				p.grab_left = window
				p.grab_front = front
			else:
				p.grab_left = minf(p.grab_left, window)
			p.cancel_action()
			p.stop()
			p.aim.stop()
			p.target_zombie = {}
			p.panic = minf(1.0, p.panic + 0.5)
			game.telemetry.injury(now, p.pid, "grab")
			if p == game.player:
				game.hud.grab_alert(front)
		"scratch":
			p.body.apply_scratch(rng, now)
			p.coat["wear"] = minf(1.0, float(p.coat.get("wear", 0.0)) + 0.1)
			p.panic = minf(1.0, p.panic + 0.3)
			game.telemetry.injury(now, p.pid, "scratch")
			if p.team != "raider":
				game.say(p, "%s 긁혔다." % p.display_name)
		"blocked":
			p.coat["wear"] = minf(1.0, float(p.coat.get("wear", 0.0)) + 0.05)
			_toast(p, "외투가 손톱을 막았다.")
	return outcome


## The window ran out: the bite lands (body_injury 2). Witnesses go on the receipt.
func bite(p) -> void:
	var rng: RandomNumberGenerator = game.rng
	var now: float = game.clock.elapsed
	var crawler := false
	for z in p.grabbers:
		crawler = crawler or bool(z.get("crawl", false))
	var part: String = GrabRules.bite_location(rng, crawler)
	p.body.apply_bite(rng, part, now)
	for z in p.grabbers.duplicate():
		game.zombies.release(z, p.position, false)
	p.grabbers.clear()
	p.grab_left = 0.0
	p.panic = 1.0
	game.telemetry.injury(now, p.pid, "bite")
	if p.team == "raider":
		return
	var part_word: String = {"arm": "팔", "torso": "몸통", "leg": "다리"}.get(part, part)
	game.say(p, "%s %s를 물렸다." % [p.display_name, part_word])
	var seen: Array = []
	for o in game.allies_alive():
		if o != p and o.position.distance_to(p.position) < 12.0 and game.grid.line_clear(FieldGrid.cell_of(o.position), FieldGrid.cell_of(p.position)):
			seen.append(o.pid)
	game.receipt.witness(p.pid, "bitten_" + part, _where(p.position), game.clock.label(), "grabbed_by_the_dead", seen)
	game.receipt.person("bitten", p.pid)


func _where(at: Vector3) -> String:
	var z: String = game.grid.zone_at(FieldGrid.cell_of(at))
	return {"A": "station_building", "B": "freight_siding", "C": "water_tower", "D": "station_street", "E": "signal_box", "platform": "platform"}.get(z, "sulechow")


## Falls on ice, under a load or off the ladder (body_injury 3.2).
func fall(p, msg: String, fracture_chance: float = 0.05, leg: bool = false) -> void:
	p.fallen_t = FALL_TIME
	p.cancel_action()
	p.stop()
	p.aim.stop()
	game.make_sound(p.position, SimNoise.Level.NORMAL, "fall", p)
	if game.rng.randf() < fracture_chance:
		p.body.fracture(not leg)
		game.telemetry.injury(game.clock.elapsed, p.pid, "fracture")
		game.say(p, "%s %s, %s가 부러졌다." % [p.display_name, msg, "다리" if leg else "팔"])
	elif p.team != "raider":
		game.say(p, "%s %s." % [p.display_name, msg])


# ---------------------------------------------------------------- guns and bows

func aim_mods(p) -> Dictionary:
	var m: Dictionary = p.mults()
	var close := false
	for z in game.zombies.in_radius(p.position, CLOSE):
		if game.zombies.active(z) and z["state"] != "downed":
			close = true
			break
	return {"min_mult": float(m["aim_min"]), "shrink_mult": float(m["aim_shrink"]), "quality": String(p.weapon()["quality"]), "skill": int(p.skills["shooting"]), "enemy_close": close, "moving": p.moving}


func can_shoot(p) -> bool:
	var wid: String = p.weapon_id()
	return p.can_act() and W.is_ranged(wid) and p.reload_t <= 0.0 and p.jam_t <= 0.0 and not bool(p.weapon().get("broken", false))


## Press and hold: start the aim circle. Standing still shrinks it.
func start_aim(p) -> bool:
	if not can_shoot(p):
		if p == game.player and W.is_ranged(p.weapon_id()):
			if bool(p.weapon().get("broken", false)):
				game.hud.toast("총이 망가졌다.")
			elif p.jam_t > 0.0:
				game.hud.toast("걸림을 푸는 중이다.")
			elif p.reload_t > 0.0:
				game.hud.toast("장전 중이다.")
		return false
	if int(p.weapon()["loaded"]) <= 0:
		start_reload(p)
		return false
	p.stop()
	p.aim.start(p.weapon_id(), aim_mods(p))
	return true


## Fire at a point (and an optional target: zombie dict or person). Returns
## "shot", "shove", "jam", "misfire", "burst", "empty" or "none".
func fire(p, at: Vector3, target = null) -> String:
	var rng: RandomNumberGenerator = game.rng
	var now: float = game.clock.elapsed
	var wid: String = p.weapon_id()
	var d: Dictionary = W.get_data(wid)
	if not can_shoot(p):
		p.aim.stop()
		return "none"
	if not p.aim.active:
		p.aim.start(wid, aim_mods(p))
	var h: Dictionary = p.weapon()
	if int(h["loaded"]) <= 0:
		p.aim.stop()
		start_reload(p)
		return "empty"
	at.y = 0.0
	p.face_point(at)
	var dist: float = p.position.distance_to(at)
	# Too close to aim: the gun becomes a shove (field_unified 10).
	# Measured to the enemy, not to the finger: a press on its head lands on the ground short of it.
	if target is Dictionary and not target.is_empty() and p.position.distance_to(target["pos"]) < float(d["min_dist"]):
		p.aim.stop()
		shove(p)
		return "shove"
	# The machine axis of the cold follows the air, not the body (s2_station 2.4).
	var cold: bool = game.weather.ambient_c <= -10.0
	var quality: String = String(h["quality"])
	var cond: float = float(h["condition"])
	if rng.randf() < W.jam_chance(wid, cond, cold):
		p.jam_t = JAM_CLEAR
		p.aim.stop()
		_toast(p, "걸렸다! 푸는 중.")
		return "jam"
	if rng.randf() < W.misfire_chance(wid, cond, cold):
		h["loaded"] = int(h["loaded"]) - 1
		p.aim.stop()
		_toast(p, "불발.")
		start_reload(p)
		return "misfire"
	h["loaded"] = int(h["loaded"]) - 1
	_wear(p, W.wear_per_use(wid, quality))
	if rng.randf() < W.burst_chance(wid, quality):
		h["broken"] = true
		h["condition"] = 0.0
		p.body.apply_cut(false, now)
		game.make_sound(p.position, SimNoise.Level.LOUD, "gun", p)
		p.aim.stop()
		game.say(p, "%s 총열이 터졌다." % p.display_name)
		return "burst"
	game.make_sound(p.position, int(d["sound"]), "gun" if int(d["sound"]) > 0 else "bow", p)
	var radius: float = p.aim.radius_at(dist)
	p.aim.fire()
	var end := at
	if dist > float(d["range"]):
		end = p.position + (at - p.position).normalized() * float(d["range"])
	# A wall in the way takes the shot.
	var blocked_at = _first_wall(p.position, end)
	if blocked_at != null:
		end = blocked_at
	tracers.append({"from": p.position + Vector3(0, 1.2, 0), "to": end + Vector3(0, 1.0, 0), "t": 0.12})
	if wid == "bow":
		game.ground_items.append({"pos": end, "id": "arrow", "n": 1})
	if blocked_at != null or dist > float(d["range"]):
		game.make_sound(end, SimNoise.Level.QUIET, "impact", p)
		_after_shot(p)
		return "shot"
	var hit := false
	if target is Dictionary and not target.is_empty():
		hit = _shoot_zombie(p, target, d, radius, dist)
	elif target != null and not (target is Dictionary):
		hit = _shoot_person(p, target, radius)
	else:
		var z: Dictionary = game.zombies.nearest(at, 0.8, true, true)
		if not z.is_empty():
			hit = _shoot_zombie(p, z, d, radius, dist)
	if not hit:
		# The miss lands somewhere past the target: a small sound over there.
		var past: Vector3 = at + (at - p.position).normalized() * rng.randf_range(1.0, 3.0)
		game.make_sound(past, SimNoise.Level.QUIET, "impact", p)
	_after_shot(p)
	return "shot"


func _after_shot(p) -> void:
	if int(p.weapon()["loaded"]) <= 0:
		p.aim.stop()
		start_reload(p)


func _shoot_zombie(p, z: Dictionary, d: Dictionary, radius: float, dist: float) -> bool:
	var rng: RandomNumberGenerator = game.rng
	var clothed: bool = z["kind"] == "clothed"
	if z["state"] == "rising":
		if AimModel.roll(rng, radius) != "miss":
			_kill(p, z, "")
			return true
		return false
	if int(d.get("pellets", 1)) > 1:
		var spread_m: float = dist * tan(deg_to_rad(float(d["spread_deg"])))
		var hits: Dictionary = AimModel.pellet_hits(rng, radius, spread_m, int(d["pellets"]))
		if int(hits["head"]) > 0:
			_kill(p, z, "")
			return true
		var body: int = int(hits["body"])
		if body <= 0:
			return false
		var knock := 1.0 - pow(1.0 - float(d["body_knockdown"]) * (0.5 if clothed else 1.0), body)
		if rng.randf() < knock or z["state"] == "frozen":
			if z["state"] == "frozen":
				_kill(p, z, "")
			else:
				game.zombies.knock_down(z)
		else:
			z["stun"] = 0.5
		return true
	var zone: String = AimModel.roll(rng, radius)
	if zone == "head":
		if clothed and p.weapon_id() == "pistol" and rng.randf() < 0.25:
			game.zombies.knock_down(z)
		else:
			_kill(p, z, "")
		return true
	if zone == "body":
		# Pistol rounds stop in a 껴입은 자's coat (zombies.md).
		if clothed and p.weapon_id() == "pistol":
			z["stun"] = 0.3
			return true
		if rng.randf() < float(d["body_knockdown"]):
			game.zombies.knock_down(z)
		else:
			z["stun"] = 0.5
		return true
	return false


func _shoot_person(p, o, radius: float) -> bool:
	var rng: RandomNumberGenerator = game.rng
	if not o.is_alive():
		return false
	var cover := 0.0
	# Low cover (cars, fences) between shooter and target halves the body.
	if game.grid.solid_at(FieldGrid.cell_of(o.position + (p.position - o.position).normalized() * 1.0)) == FieldGrid.Solid.LOW:
		cover = 0.5
	var zone: String = AimModel.roll(rng, radius, 0.12, 0.34 * (1.0 - cover))
	if zone == "miss":
		return false
	o.last_hurt_by = p.pid
	var part: String = o.body.apply_gunshot(rng, game.clock.elapsed)
	if zone == "head":
		o.body.downed = true
	game.telemetry.injury(game.clock.elapsed, o.pid, "gunshot")
	if o.team == "raider":
		game.ai.raider_hit(o, p)
	else:
		game.say(o, "%s 총에 맞았다%s." % [o.display_name, " (다리)" if part == "leg" else ""])
	return true


func _first_wall(from: Vector3, to: Vector3):
	var a := FieldGrid.cell_of(from)
	var b := FieldGrid.cell_of(to)
	var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var c := FieldGrid.cell_of(from.lerp(to, t))
		if c == a:
			continue
		if game.grid.opaque(c):
			return FieldGrid.center(c)
	return null


## Reload from the shared squad pool (raiders carry their own few rounds).
func start_reload(p) -> bool:
	var wid: String = p.weapon_id()
	var d: Dictionary = W.get_data(wid)
	if not W.is_ranged(wid) or p.reload_t > 0.0 or p.jam_t > 0.0:
		return false
	var h: Dictionary = p.weapon()
	if int(h["loaded"]) >= int(d["mag"]):
		return false
	if _pool(p, String(d["ammo"])) <= 0:
		_toast(p, "%s이 없다." % W.AMMO_NAMES.get(d["ammo"], "탄"))
		return false
	p.aim.stop()
	p.reload_t = float(d["reload"])
	return true


func _finish_reload(p) -> void:
	p.reload_t = 0.0
	var wid: String = p.weapon_id()
	var d: Dictionary = W.get_data(wid)
	if d.is_empty() or not W.is_ranged(wid):
		return
	var h: Dictionary = p.weapon()
	var kind: String = String(d["ammo"])
	var need: int = int(d["mag"]) - int(h["loaded"])
	if bool(d.get("reload_each", false)):
		need = mini(need, 1)
	var got: int = _take(p, kind, need)
	h["loaded"] = int(h["loaded"]) + got
	if bool(d.get("reload_each", false)) and int(h["loaded"]) < int(d["mag"]) and _pool(p, kind) > 0 and p.can_act() and not p.aim.active:
		p.reload_t = float(d["reload"])


func _pool(p, kind: String) -> int:
	if p.team == "raider":
		return int(p.brain.get("ammo", RAIDER_AMMO))
	return int(game.ammo.get(kind, 0))


func _take(p, kind: String, n: int) -> int:
	var have := _pool(p, kind)
	var got := mini(have, n)
	if p.team == "raider":
		p.brain["ammo"] = have - got
	else:
		game.ammo[kind] = have - got
	return got


## Swap hand slots: belt to hand, slower with a heavy bag (body_injury 6).
func swap(p) -> void:
	if p.hands.size() < 2 or not p.can_act() or p.action != "":
		return
	p.aim.stop()
	p.reload_t = 0.0
	var t: float = Carry.swap_time("belt", p.carry_state()) / float(p.mults()["swap"])
	p.start_action("swap", "무기 바꿈", t, func() -> void: p.swap_weapons())
