extends RefCounted
## People who are not the player: three companions, the work crew and the
## raiders in the pharmacy (field_unified 9·11, s2_station 2.4·2.5).
## Raiders only know what they saw or heard: last position, never the truth.

const FieldGrid = preload("res://game/world/field_grid.gd")
const W = preload("res://game/sim/weapons.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const FieldCombat = preload("res://game/field_combat.gd")

const FOLLOW_OFFSETS: Array = [Vector2(-1.3, -1.2), Vector2(1.3, -1.2), Vector2(0.0, -2.4)]
const THINK: float = 0.25
const REACT_MIN: float = 0.4
const REACT_MAX: float = 0.8
const THREAT_R: float = 3.0
const COVER_R: float = 11.0
const RAIDER_SIGHT: float = 22.0
const NOTICE_TIME: float = 1.5
const DIG_TIME: float = 45.0
const TRIP_COAL: float = 0.25
## Something behind a person (outside +-BEHIND_DEG of facing) and farther than
## BEHIND_NEAR is noticed only after it has stayed there BEHIND_NOTICE (0.5..1.0 s per person).
const BEHIND_DEG: float = 100.0
const BEHIND_NEAR: float = 1.2
const BEHIND_NOTICE_MIN: float = 0.5
const BEHIND_NOTICE_MAX: float = 1.0
## A companion waits this long after a shot before the next one.
const ALLY_REFIRE: float = 0.9
## Companions act without an order (decision 406): they go for the dead that
## are after one of us within ENGAGE_R, or that stand within GUARD_R of the
## chief, but never chase farther than LEASH_R from him.
const ENGAGE_R: float = 8.0
const GUARD_R: float = 3.5
const LEASH_R: float = 10.0
## Closer than this the gun is put away for the blade.
const SHOOT_MIN: float = 3.0
## A loud gun only when one of the dead is this near someone and the blade is
## farther than SAVE_FAR from it (the bow, silent, may shoot whenever in range).
const SAVE_NEAR: float = 2.0
const SAVE_FAR: float = 4.0
## This many on a companion at once and it steps back toward the chief.
const CROWD_R: float = 2.5
const CROWD_N: int = 3
## Walking, the one in front keeps this far ahead of the chief.
const LEAD_AHEAD: float = 3.0
## Slow work is dropped when one of the dead gets this near.
const BREAK_R: float = 1.8
const BREAKS: Array = ["search", "treat", "loot", "salvage", "rub"]
## On the move and not getting anywhere for this long: find the way again.
const STUCK_T: float = 1.5
## The door the chief went in by is held while he is this near it.
const DOOR_HOLD_R: float = 16.0
## The chief stops by things to search: the companions not on watch search the
## others within HELP_R of him (decision 406, bundle 2).
const HELP_R: float = 6.0
## Arrows and dropped things this near (and this near the chief) are picked up.
const PICK_R: float = 6.0
## A bleeding one of us with no bandage this near gets one handed over.
const GIVE_R: float = 12.0
## A thing it cannot get to in this long is given up.
const HELP_GIVE_UP: float = 12.0
## What is worth stooping for: light, and of use to everyone.
const PICK_IDS: Array = ["arrow", "ammo_pistol", "ammo_shell", "bandage", "cloth"]
## One of us held by the dead this near: the nearest free companion runs over
## and shoves it off (decision 406, bundle 3). Only one goes.
const RESCUE_R: float = 9.0
## One of us down this near: the nearest free companion stands over them.
const GUARD_DOWN_R: float = 15.0
## What they say of what they see (bundle 4; the lines and how often:
## AllyLines). This many of the dead coming at us, near, is a horde.
const HORDE_N: int = 5
## One of us falls: the nearest companion this near that sees it calls out.
const SEE_DOWN_R: float = 12.0
## The chief stands still this long: the companions look round, each its own
## way, sweeping this far either side.
const LOOK_STILL_S: float = 1.5
const LOOK_SWEEP_DEG: float = 40.0

var game
var think_t: float = 0.0
var fled: int = 0
var surrendered = null
var crew_attitude: String = "defensive"     # aggressive | defensive | neutral
var crew_fire: String = "threat"            # free | threat | melee
var crew_recalled: bool = false
## The door the chief last went into a building by: {"cell", "out", "building"}.
var held_door: Dictionary = {}
var _chief_was_out: bool = true
var _chief_out_at := Vector3.ZERO
## The dead still up, gathered once per think while the companions think, so
## three of them do not each walk the whole list (empty outside update()).
var _live: Array = []
var _live_on: bool = false
var _roles: Dictionary = {}
## Containers by the chief worth a hand, nearest first ([id, d]), gathered
## once per think for all three (_help_search); and where each one stands.
var _help_list: Array = []
var _help_ok: bool = false
var _spots: Dictionary = {}
## The dead within ENGAGE_R of the companion thinking now (_companion fills it).
var _near: Array = []
var _near_of = null
## How long the chief has stood still.
var _chief_still: float = 0.0
## Those of us lying down already called out.
var _down_seen: Dictionary = {}


func _init(field_game) -> void:
	game = field_game


func update(delta: float) -> void:
	for p in game.people_alive():
		if p == game.player:
			continue
		_grab_reflex(p, delta)
	think_t -= delta
	var think := think_t <= 0.0
	_chief_still = 0.0 if game.player.moving else _chief_still + delta
	if think:
		think_t = THINK
		_track_door()
		_call_down()
	# Each companion thinks every THINK, but not all on the same frame: the
	# three are spread over the THINK so no one frame carries all of them.
	var k := 0
	for p in game.squad:
		if p == game.player:
			continue
		k += 1
		if not p.brain.has("think_t"):
			p.brain["think_t"] = THINK * float(k - 1) / 3.0
		p.brain["think_t"] = float(p.brain["think_t"]) - delta
		if p.brain["think_t"] > 0.0:
			continue
		p.brain["think_t"] = float(p.brain["think_t"]) + THINK
		if float(p.brain["think_t"]) <= 0.0:
			p.brain["think_t"] = THINK
		if p.is_alive():
			_notice(p)
		if p.is_alive() and p.can_act():
			if not _live_on:
				_gather_live()
			_companion(p)
	_live_on = false
	_live = []
	_roles = {}
	_help_ok = false
	_near = []
	_near_of = null
	for p in game.crew:
		if p.is_alive() and p.can_act() and not p.brain.get("boarded", false):
			_crew(p, delta, think)
	for r in game.raiders:
		if r.is_alive() and not r.body.downed:
			_raider(r, delta, think)


# ---------------------------------------------------------------- shared

func _gather_live() -> void:
	_live = []
	for z in game.zombies.list:
		var st: String = z["state"]
		if st != "dead" and st != "rising":
			_live.append(z)
	_live_on = true


## Like zombies.in_radius, from the list gathered this think when there is one
## (and from the companion's own near list when it is about that companion).
func _dead_near(at: Vector3, r: float) -> Array:
	if not _live_on:
		return game.zombies.in_radius(at, r)
	var from: Array = _live
	if _near_of != null and r <= ENGAGE_R and at == _near_of.position:
		from = _near
	var out: Array = []
	var rr := r * r
	for z in from:
		if at.distance_squared_to(z["pos"]) <= rr:
			out.append(z)
	return out

## A grabbed companion shoves back after a human reaction time; if that is
## longer than the window, the bite lands first (body_injury 2).
func _grab_reflex(p, delta: float) -> void:
	if p.grabbers.is_empty():
		p.brain.erase("react_t")
		return
	if not p.brain.has("react_t"):
		p.brain["react_t"] = game.rng.randf_range(REACT_MIN, REACT_MAX) * (0.8 if p.team == "squad" else 1.0)
	p.brain["react_t"] = float(p.brain["react_t"]) - delta
	if p.brain["react_t"] <= 0.0:
		p.brain.erase("react_t")
		game.combat.break_grab(p)


## Called once per think (THINK) for a person, so brain["behind_t"] counts real time.
func _threat_near(p, r: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := r
	var back: Dictionary = {}
	var back_d := r
	var fwd := Vector3(sin(p.facing), 0, cos(p.facing))
	var cos_front := cos(deg_to_rad(BEHIND_DEG))
	for z in _dead_near(p.position, r):
		if not game.zombies.active(z) or z["state"] == "downed":
			continue
		var d: float = p.position.distance_to(z["pos"])
		if not (d < best_d or d < back_d) or not game.sight_clear(p.position, z["pos"]):
			continue
		var to_z: Vector3 = z["pos"] - p.position
		to_z.y = 0
		var behind: bool = d > BEHIND_NEAR and to_z.length() > 0.01 and fwd.dot(to_z.normalized()) < cos_front
		if not behind and d < best_d:
			best_d = d
			best = z
		elif behind and d < back_d:
			back_d = d
			back = z
	if not best.is_empty() or back.is_empty():
		p.brain["behind_t"] = 0.0
		return best
	p.brain["behind_t"] = float(p.brain.get("behind_t", 0.0)) + THINK
	var notice: float = lerpf(BEHIND_NOTICE_MIN, BEHIND_NOTICE_MAX, p.name_unit("b"))
	return back if float(p.brain["behind_t"]) >= notice else {}


func _hostile_raider_near(p, r: float):
	for o in game.raiders:
		if not o.is_alive() or o.body.downed or o.brain.get("state", "") in ["surrender", "flee", "prisoner", "gone"]:
			continue
		if not o.brain.get("aware_of_us", false):
			continue
		if p.position.distance_to(o.position) <= r and game.sight_clear(p.position, o.position):
			return o
	return null


func _walk(p, to: Vector3, run: bool = false) -> void:
	if p.brain.get("dest", Vector3.INF).distance_to(to) < 0.6 and not p.path.is_empty():
		return
	p.brain["dest"] = to
	p.go_to(game.find_path(p.position, to, false), run)


## On the way and not getting anywhere (a wall corner, someone in the way):
## drop the path so the next walk finds a new one (zomboid mod lesson: a
## watchdog, not a companion running on the spot).
func _watch_stuck(p) -> void:
	if p.path.is_empty() or p.action != "":
		p.brain.erase("stuck_t")
		p.brain["last_at"] = p.position
		return
	var moved: float = p.position.distance_to(p.brain.get("last_at", p.position))
	p.brain["last_at"] = p.position
	if moved > 0.15:
		p.brain["stuck_t"] = 0.0
		return
	p.brain["stuck_t"] = float(p.brain.get("stuck_t", 0.0)) + THINK
	if p.brain["stuck_t"] >= STUCK_T:
		p.brain["stuck_t"] = 0.0
		p.brain.erase("dest")
		p.stop()


## Use the melee slot for close work; keep the gun for when shooting is allowed.
func _prefer(p, ranged: bool) -> void:
	if p.hands.size() < 2 or p.action != "":
		return
	if W.is_ranged(p.weapon_id()) == ranged:
		return
	if W.is_ranged(p.hands[1]["id"]) == ranged:
		game.combat.swap(p)


func _shoot_or_aim(p, at: Vector3, target) -> void:
	if not game.combat.can_shoot(p):
		if W.is_ranged(p.weapon_id()) and int(p.weapon()["loaded"]) <= 0:
			game.combat.start_reload(p)
		return
	if not p.aim.active:
		game.combat.start_aim(p)
		p.brain["aim_wait"] = 0.6 + 0.04 * p.position.distance_to(at)
		return
	p.face_point(at)
	p.brain["aim_wait"] = float(p.brain.get("aim_wait", 0.0)) - THINK
	if p.brain["aim_wait"] <= 0.0 or p.aim.deg <= p.aim.floor_deg * 1.05:
		game.combat.fire(p, at, target)
		if p.team == "squad":
			p.brain["aim_wait"] = ALLY_REFIRE


func _treat_self(p) -> bool:
	if p.body.bleed <= 0 or p.action != "":
		return false
	if p.items.has("medkit") and p.body.bleed >= 2:
		p.start_action("treat", "치료", 8.0, _use_kit.bind(p, p))
		return true
	var need := 2 if p.body.bleed >= 2 else 1
	if int(p.items.get("bandage", 0)) >= need:
		p.start_action("treat", "붕대", 6.0, _use_bandage.bind(p, p, need))
		return true
	return false


func _use_kit(giver, who) -> void:
	if giver.take_item("medkit"):
		who.body.use_kit()


func _use_bandage(giver, who, n: int) -> void:
	if int(giver.items.get("bandage", 0)) >= n:
		who.body.bandage(n)
		if who.body.last_bandages_used > 0:
			giver.take_item("bandage", who.body.last_bandages_used)


# ---------------------------------------------------------------- companions

## A companion thinks for itself (decision 406): what is after us comes first,
## then the order, then keeping beside the chief. Threat always outranks a job
## (zomboid mod lesson: workers that let themselves be eaten mid-task).
func _companion(p) -> void:
	var player = game.player
	if _live_on:
		_near_of = null
		_near = _dead_near(p.position, ENGAGE_R)
		_near_of = p
	var threat := _threat_near(p, THREAT_R)
	if not threat.is_empty():
		_horde_call(p)
	var raider = _hostile_raider_near(p, 20.0)
	_watch_stuck(p)
	# Slow work is dropped when one of the dead gets close.
	if BREAKS.has(p.action) and not threat.is_empty() and threat["pos"].distance_to(p.position) <= BREAK_R:
		p.cancel_action()
	# A search it chose itself is left when the chief walks on without it.
	if p.action == "search" and p.brain.has("help_c") and p.position.distance_to(player.position) > LEASH_R:
		p.cancel_action()
		p.brain.erase("help_c")
	# Self-care first when nothing is close.
	if threat.is_empty() and raider == null and p.action == "" and _treat_self(p):
		return
	# The medic patches up a bleeding ally nearby; anyone with a bandage does
	# for one bleeding hard (a light bleed gets a bandage handed over instead).
	var carer: bool = p.medical != "none" or int(p.items.get("bandage", 0)) > 0 or p.items.has("medkit")
	if carer and threat.is_empty() and raider == null and p.action == "":
		for o in game.allies_alive():
			if o != p and o.body.bleed > 0 and o.position.distance_to(p.position) < 15.0 and o.grabbers.is_empty() and (p.medical != "none" or o.body.bleed >= 2) and not _cared_by_other(p, o):
				p.brain["care"] = o
				if o.position.distance_to(p.position) > 1.4:
					_walk(p, o.position, o.body.bleed >= 2)
				else:
					game.actions.treat(p, o)
				return
	p.brain.erase("care")
	if p.action != "":
		return
	# Coming over the train after the chief (field_actions.cross_train).
	if p.brain.has("cross"):
		if p.command != "follow" or not threat.is_empty() or raider != null:
			p.brain.erase("cross")
		else:
			var way: Dictionary = p.brain["cross"]
			var foot := FieldGrid.center(way["from"])
			if p.position.distance_to(foot) > 1.0:
				_walk(p, foot)
			elif game.actions.cross_refused(p, way) == "":
				game.actions.cross_train(p, way)
			elif game.actions.too_hurt_to_cross(p) or p.carrying_wounded != null:
				p.brain.erase("cross")   # goes round the train's end as before
			else:
				p.stop()                 # waits for the one ahead
			return
	match p.command:
		"retreat":
			var door := FieldGrid.center(game.data["spawns"]["train_door"][0])
			if p.position.distance_to(door) > 1.5:
				_walk(p, door, true)
			else:
				p.brain["boarded"] = true
				p.stop()
			if not threat.is_empty() and threat["pos"].distance_to(p.position) < 1.3:
				game.combat.shove(p)
			return
		"search":
			if threat.is_empty() and raider == null:
				if _search_near(p, p.command_target):
					return
				p.command = "wait"
	# Raiders aware of us: shoot back while there is something to load; with
	# none, a raider at arm's length gets the blade, else stay by the chief.
	if raider != null and p.command != "retreat":
		if _gun_slot(p) >= 0:
			_prefer(p, true)
			if W.is_ranged(p.weapon_id()):
				_shoot_or_aim(p, raider.position, raider)
				return
		elif p.position.distance_to(raider.position) < 3.0 and game.combat.hostile(raider):
			_prefer(p, false)
			game.combat.melee_person(p, raider)
			return
	# One of us held: pull the dead off them, unless one is already at my throat.
	if p.command != "retreat" and (threat.is_empty() or threat["pos"].distance_to(p.position) > 1.5):
		var held = _held_mate(p)
		if held != null:
			_rescue(p, held)
			return
	# Not on me: the dead after one of us, or right by the chief.
	if threat.is_empty() and (p.command == "follow" or p.command == "cover"):
		threat = _squad_threat(p)
	if not threat.is_empty():
		_engage(p, threat)
		return
	if p.command == "cover" and _gun_slot(p) >= 0:
		# Shoot the dead going for the player within cover range.
		for z in _dead_near(player.position, COVER_R):
			if game.zombies.active(z) and (z["state"] == "chase" or z["state"] == "attack") and z["victim"] == player:
				_prefer(p, true)
				if W.is_ranged(p.weapon_id()):
					_shoot_or_aim(p, z["pos"], z)
				return
	if p.aim.active:
		p.aim.stop()
	p.target_zombie = {}
	# Nothing to load for the gun in hand: the blade comes out and stays out.
	if W.is_ranged(p.weapon_id()) and _gun_slot(p) < 0:
		_prefer(p, false)
		if p.action != "":
			return
	match p.command:
		"follow", "cover":
			if _guard_downed(p) or _hand_over(p) or _pick_ground(p) or _help_search(p):
				return
			_keep_formation(p)
		"wait":
			if p.position.distance_to(p.command_target) > 1.0:
				_walk(p, p.command_target, false)


## The dead p should go for without being told: after one of us (or within
## GUARD_R of the chief), seen, not past the leash. Ahead is seen at once; what
## is behind p only after it has been there a moment (decision 119). Two
## companions do not pile on the same one while another is free.
func _squad_threat(p) -> Dictionary:
	var player = game.player
	var fwd := Vector3(sin(p.facing), 0, cos(p.facing))
	var cos_front := cos(deg_to_rad(BEHIND_DEG))
	var notice: float = lerpf(BEHIND_NOTICE_MIN, BEHIND_NOTICE_MAX, p.name_unit("b"))
	var seen_before: Dictionary = p.brain.get("seen_t", {})
	var seen_now := {}
	var rows: Array = []
	for z in _dead_near(p.position, ENGAGE_R):
		if not game.zombies.active(z) or z["state"] == "downed" or z["state"] == "grab":
			continue
		var v = z.get("victim")
		var after_us: bool = z["state"] in ["chase", "attack", "tell"] and v != null and game.squad.has(v)
		var to_chief: float = z["pos"].distance_to(player.position)
		# Sneaking, nobody starts a fight the dead have not started.
		if not after_us and (to_chief > GUARD_R or player.crouched):
			continue
		# Saving one who is down goes past the leash.
		if to_chief > LEASH_R and not (after_us and v.body.downed):
			continue
		var d: float = p.position.distance_to(z["pos"])
		var to_z: Vector3 = z["pos"] - p.position
		to_z.y = 0
		var behind: bool = d > BEHIND_NEAR and to_z.length() > 0.01 and fwd.dot(to_z.normalized()) < cos_front
		var t: float = float(seen_before.get(z["id"], 0.0)) + THINK
		seen_now[z["id"]] = t
		if behind and t < notice:
			continue
		var s: float = d - (2.0 if v == player else 0.0)
		for o in game.squad:
			if o != p and o.target_zombie == z:
				s += 4.0
		rows.append([s, z])
	p.brain["seen_t"] = seen_now
	# The sight line is the dear part: test the best first and stop at the first seen.
	rows.sort_custom(func(a, b): return a[0] < b[0])
	for row in rows:
		if game.sight_clear(p.position, row[1]["pos"]):
			return row[1]
	return {}


## Fight z as a person would with what they carry: the bow whenever it has a
## clear shot in range (it makes no sound), a loud gun only to save someone the
## blade cannot reach in time, the blade otherwise. Swarmed, step back toward
## the chief and shove the nearest off. The pace of the blows is the combat's
## (decision 119); this only says whom.
func _engage(p, z: Dictionary) -> void:
	var d: float = p.position.distance_to(z["pos"])
	if _crowd(p) >= CROWD_N:
		p.target_zombie = {}
		if p.aim.active:
			p.aim.stop()
		var away: Vector3 = (p.position - z["pos"])
		away.y = 0
		var back: Vector3 = (away.normalized() + (game.player.position - p.position).normalized() * 0.5).normalized()
		_walk(p, game.walkable_near(p.position + back * 2.5, false, 2), true)
		if d < 1.3:
			p.face_point(z["pos"])
			game.combat.shove(p)
		return
	if _should_shoot(p, z, d):
		_prefer(p, true)
		if p.action != "":
			p.target_zombie = {}
			return
		if W.is_ranged(p.weapon_id()):
			p.target_zombie = {}
			p.stop()
			_shoot_or_aim(p, z["pos"], z)
			return
	if p.aim.active:
		p.aim.stop()
	_prefer(p, false)
	if p.action != "":
		# The blade is coming out: no walking at it meanwhile (a walk would cut the swap).
		p.target_zombie = {}
		return
	if d > 3.0 and p.target_zombie != z:
		p.running = true
	game.combat.melee_target(p, z, true)


func _should_shoot(p, z: Dictionary, d: float) -> bool:
	var gun := _gun_slot(p)
	if gun < 0:
		return false
	if p.command == "cover":
		return d > 2.0
	if d < SHOOT_MIN:
		return false
	var data: Dictionary = W.get_data(String(p.hands[gun]["id"]))
	if d > float(data.get("range", 12.0)) * 0.8:
		return false
	if int(data.get("sound", 0)) == 0:
		return true
	var v = z.get("victim")
	return v != null and v != p and game.squad.has(v) and z["pos"].distance_to(v.position) < SAVE_NEAR and d > SAVE_FAR


## The hand slot of a gun that can still fire (loaded, or rounds in the pool
## to load), or -1.
func _gun_slot(p) -> int:
	for i in range(p.hands.size()):
		var h: Dictionary = p.hands[i]
		var id: String = String(h["id"])
		if not W.is_ranged(id) or bool(h.get("broken", false)):
			continue
		if int(h.get("loaded", 0)) > 0 or int(game.ammo.get(String(W.get_data(id).get("ammo", "")), 0)) > 0:
			return i
	return -1


func _crowd(p) -> int:
	var n := 0
	for z in _dead_near(p.position, CROWD_R):
		if game.zombies.active(z) and z["state"] != "downed":
			n += 1
	return n


## Who walks where (decision 406): the bow keeps to the back, the strongest
## blade goes in front, the third at the chief's side. With fewer left the
## ones there are take the front first.
func _role(p) -> String:
	if _live_on and _roles.has(p):
		return _roles[p]
	var r := _pick_role(p)
	if _live_on:
		_roles[p] = r
	return r


func _pick_role(p) -> String:
	var mates: Array = []
	for o in game.squad:
		if o != game.player and o.is_alive() and not o.body.downed and o.command in ["follow", "cover"] and not o.brain.get("boarded", false):
			mates.append(o)
	if mates.size() <= 1:
		return "side"
	var rear = null
	var rear_s := -INF
	for o in mates:
		var s: float = float(o.skills.get("shooting", 0)) + (5.0 if _quiet_bow(o) else 0.0)
		if s > rear_s:
			rear_s = s
			rear = o
	if p == rear:
		return "rear"
	var point = null
	var point_s := -INF
	for o in mates:
		if o == rear:
			continue
		var s: float = float(o.skills.get("strength", 0)) + float(o.skills.get("melee", 0))
		if s > point_s:
			point_s = s
			point = o
	return "point" if p == point else "side"


func _quiet_bow(p) -> bool:
	for h in p.hands:
		var data: Dictionary = W.get_data(String(h["id"]))
		if W.is_ranged(String(h["id"])) and int(data.get("sound", 0)) == 0:
			return true
	return false


## The chief walking: the point goes ahead so doors are opened before him, the
## side one beside, the rear behind. Inside a building the rear one holds the
## door he came in by. Standing, they keep close round him.
func _keep_formation(p) -> void:
	var player = game.player
	var role := _role(p)
	var fwd := Vector3(sin(player.facing), 0, cos(player.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var walking: bool = player.moving
	p.crouched = player.crouched
	var spot: Vector3
	var look: Vector3 = fwd
	var hold := false
	# The chief's gun up: nobody stands in front of it.
	if role == "point" and player.aim.active:
		role = "aside"
	match role:
		"aside":
			spot = player.position - right * 1.4 - fwd * 0.6
		"point":
			spot = player.position + fwd * (LEAD_AHEAD if walking else 1.4) + right * 0.5
			if not game.sight_clear(player.position, spot):
				spot = player.position + fwd * 1.2
				if not game.sight_clear(player.position, spot):
					spot = player.position - fwd * 1.2 + right * 1.3
		"rear":
			if _holds_door(p):
				var door := FieldGrid.center(held_door["cell"])
				spot = door - held_door["out"] * 1.0
				look = held_door["out"]
				hold = true
			else:
				spot = player.position - fwd * 2.4
		_:
			spot = player.position + right * 1.4 - fwd * 1.0
	spot = game.walkable_near(spot, false, 3)
	# Never on the chief's own spot (a tight room pulls every spot onto him):
	# then the old place behind him.
	if spot.distance_to(player.position) < 0.9:
		var off: Vector2 = FOLLOW_OFFSETS[clampi(game.squad.find(p) - 1, 0, 2)]
		spot = game.walkable_near(player.position + right * off.x + fwd * off.y, false, 3)
	var d: float = p.position.distance_to(spot)
	var run: bool = player.running or d > 7.0 or (role == "point" and walking and d > 2.0)
	# The chief has stopped: each looks its own way round, slowly.
	if not hold and _chief_still >= LOOK_STILL_S:
		look = _look_out(p, role, fwd, right)
	if d > (0.8 if hold else 1.2):
		_walk(p, spot, run)
	elif p.path.is_empty():
		p.face_point(p.position + look)


## Where p keeps watch while the chief stands: the front one ahead, the side
## one to its side, the back one behind, each sweeping slowly either way.
func _look_out(p, role: String, fwd: Vector3, right: Vector3) -> Vector3:
	var base: Vector3
	match role:
		"point":
			base = fwd
		"aside":
			base = -right
		"rear":
			base = -fwd
		_:
			base = right
	var k: int = maxi(game.squad.find(p), 0)
	var sweep: float = sin(game.clock.elapsed * 0.5 + float(k) * 2.1) * deg_to_rad(LOOK_SWEEP_DEG)
	return base.rotated(Vector3.UP, sweep)


# ---------------------------------------------------------------- words

## Said over p's head; how often and which line: AllyLines.
func _say(p, event: String, name: String = "") -> void:
	if game.hud == null or p == game.player or p.body.dead:
		return
	var line: String = game.lines.pick(String(p.pid), event, game.clock.elapsed, false, name)
	if line != "":
		game.hud.shout(p, line)


## What happened to p since it last thought: told to go back, let go by the
## dead, put one down, the gun gone dry.
func _notice(p) -> void:
	var b: Dictionary = p.brain
	if p.command == "retreat" and String(b.get("cmd_was", "")) != "retreat":
		_say(p, "retreat")
	b["cmd_was"] = p.command
	var held: bool = not p.grabbers.is_empty()
	if bool(b.get("held", false)) and not held and not p.body.downed:
		_say(p, "freed")
	b["held"] = held
	var last_kill: float = float(p.close_kills[-1]) if not p.close_kills.is_empty() else -1.0
	if b.has("kill_seen") and last_kill > float(b["kill_seen"]):
		_say(p, "kill")
	b["kill_seen"] = last_kill
	var armed := _gun_slot(p) >= 0
	if bool(b.get("armed", false)) and not armed and _has_gun(p):
		_say(p, "ammo_out")
	b["armed"] = armed


func _has_gun(p) -> bool:
	for h in p.hands:
		if W.is_ranged(String(h["id"])) and not bool(h.get("broken", false)):
			return true
	return false


## Many of the dead coming at us near p: it calls it (one of the squad does).
func _horde_call(p) -> void:
	var near: Array = _near if _near_of == p else _dead_near(p.position, ENGAGE_R)
	var n := 0
	for z in near:
		if game.zombies.active(z) and (z["state"] == "chase" or z["state"] == "attack" or z["state"] == "grab"):
			n += 1
	if n >= HORDE_N:
		_say(p, "horde_near")


## One of us has just gone down: the nearest companion that sees it calls out
## their name.
func _call_down() -> void:
	for o in _down_seen.keys():
		if not is_instance_valid(o) or not o.is_alive() or not o.body.downed:
			_down_seen.erase(o)
	for o in game.squad:
		if not o.is_alive() or not o.body.downed or _down_seen.has(o):
			continue
		_down_seen[o] = true
		var best = null
		var best_d := SEE_DOWN_R
		for q in game.squad:
			if q == o or q == game.player or not q.is_alive() or q.body.downed:
				continue
			var d: float = q.position.distance_to(o.position)
			if d < best_d and game.sight_clear(q.position, o.position):
				best_d = d
				best = q
		if best != null:
			_say(best, "ally_down", o.display_name)


## The rear one holds the door while the chief is inside that building, on
## the ground floor, and not too far in.
func _holds_door(p) -> bool:
	if held_door.is_empty():
		return false
	var player = game.player
	var door := FieldGrid.center(held_door["cell"])
	if player.position.distance_to(door) > DOOR_HOLD_R:
		return false
	return p.position.distance_to(door) < DOOR_HOLD_R + 4.0


## Notes the door the chief goes into a building by (ground floor), and
## forgets it when he is out again.
func _track_door() -> void:
	var player = game.player
	if player == null or not player.is_alive():
		return
	var c := FieldGrid.cell_of(player.position)
	var outside: bool = game.level_of(player.position) == 0 and game.grid.building_at(c) < 0
	if outside:
		_chief_was_out = true
		_chief_out_at = player.position
		held_door = {}
		return
	if not _chief_was_out:
		return
	_chief_was_out = false
	var best := Vector2i(-1, -1)
	var best_d := 3.5
	for dc in game.grid.doors:
		var d: float = FieldGrid.center(dc).distance_to(player.position)
		if d < best_d:
			best_d = d
			best = dc
	if best.x < 0:
		return
	var out: Vector3 = _chief_out_at - FieldGrid.center(best)
	out.y = 0
	if out.length() < 0.1:
		return
	held_door = {"cell": best, "out": out.normalized(), "building": game.grid.building_at(c)}


## Someone else is already seeing to o's bleeding.
func _cared_by_other(p, o) -> bool:
	for q in game.squad:
		if q != p and q.is_alive() and q.brain.get("care") == o:
			return true
	return false


## The nearest of us held by the dead within RESCUE_R, seen, that no nearer
## companion is already going to.
func _held_mate(p):
	var best = null
	var best_d := RESCUE_R
	for o in game.squad:
		if o == p or not o.is_alive() or o.grabbers.is_empty():
			continue
		var d: float = p.position.distance_to(o.position)
		if d >= best_d or not game.sight_clear(p.position, o.position):
			continue
		var taken := false
		for q in game.squad:
			if q != p and q != o and q.brain.get("rescue") == o and q.position.distance_to(o.position) < d:
				taken = true
		if not taken:
			best_d = d
			best = o
	if best == null:
		p.brain.erase("rescue")
	return best


## Run to the one held and shove the dead off them; then it is a fight like
## any other. The shove is the combat's own (its reach and knock-down chance).
func _rescue(p, o) -> void:
	p.brain["rescue"] = o
	var z: Dictionary = o.grabbers[0]
	var d: float = p.position.distance_to(z["pos"])
	if p.aim.active:
		p.aim.stop()
	if d > 1.2:
		p.target_zombie = {}
		_walk(p, z["pos"], true)
		return
	p.stop()
	p.face_point(z["pos"])
	if p.turned_to(deg_to_rad(FieldCombat.ALLY_TURN_DEG)) and p.swing_t <= 0.0:
		game.combat.shove(p)
		if o.grabbers.is_empty():
			game.combat.melee_target(p, z, true)


## One of us down: the nearest companion that is free stands over them until
## they are up or carried (the dead after them are its fight, past the leash).
func _guard_downed(p) -> bool:
	var best = null
	var best_d := GUARD_DOWN_R
	for o in game.squad:
		if o == p or o == game.player or not o.is_alive() or not o.body.downed or o.carrying_wounded != null:
			continue
		var d: float = p.position.distance_to(o.position)
		if d < best_d:
			var nearer := false
			for q in game.squad:
				if q != p and q != o and q != game.player and q.is_alive() and not q.body.downed and q.brain.get("guard") == o and q.position.distance_to(o.position) < d:
					nearer = true
			if not nearer:
				best_d = d
				best = o
	if best == null:
		p.brain.erase("guard")
		return false
	p.brain["guard"] = best
	if best_d > 1.4:
		_walk(p, best.position, best_d > 4.0)
	elif p.path.is_empty():
		p.face_point(p.position + (p.position - best.position))
	return true


## The chief stands by to search: the companions not on watch take the
## other things near him, one each (the rear one keeps watch). Not while
## he walks, not while sneaking past anything, never a locked box.
func _help_search(p) -> bool:
	var player = game.player
	var claim: String = String(p.brain.get("help_c", ""))
	if claim != "":
		var mine: Dictionary = game.data["containers"].get(claim, {})
		p.brain["help_t"] = float(p.brain.get("help_t", 0.0)) + THINK
		if float(p.brain["help_t"]) > HELP_GIVE_UP:
			var skip: Dictionary = p.brain.get("help_skip", {})
			skip[claim] = true
			p.brain["help_skip"] = skip
		if mine.is_empty() or mine["searched"] or mine["locked"] or player.position.distance_to(_spot_of(mine)) > HELP_R + 2.0 or float(p.brain["help_t"]) > HELP_GIVE_UP:
			p.brain.erase("help_c")
			claim = ""
	if claim == "":
		var busy_chief: bool = player.action == "search" or player.action == "loot"
		if player.moving and not busy_chief:
			return false
		if _role(p) == "rear" and _mates_up() > 1:
			return false
		var taken := {}
		for o in game.squad:
			if o != p and o.brain.has("help_c"):
				taken[o.brain["help_c"]] = true
		var skip2: Dictionary = p.brain.get("help_skip", {})
		for e in _help_near():
			if not taken.has(e[0]) and not skip2.has(e[0]):
				claim = e[0]
				break
		if claim == "":
			return false
		p.brain["help_c"] = claim
		p.brain["help_t"] = 0.0
	var c2: Dictionary = game.data["containers"][claim]
	var at := _spot_of(c2)
	if p.position.distance_to(at) > 1.3:
		_walk(p, game.walkable_near(at, false, 2), false)
	else:
		p.face_point(at)
		game.actions.search(p, claim)
	return true


## Containers within HELP_R of the chief on his floor, not searched, locked
## or in hand, nearest first: once per think, whoever asks first (outside update(), every time).
func _help_near() -> Array:
	if _help_ok and _live_on:
		return _help_list
	_help_ok = _live_on
	_help_list = []
	var player = game.player
	var lv: int = game.level_of(player.position)
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if c["searched"] or c["locked"] or c.get("busy", false) or c.has("pick") or int(c.get("level", 0)) != lv:
			continue
		var d: float = _spot_of(c).distance_to(player.position)
		if d < HELP_R:
			_help_list.append([id, d])
	_help_list.sort_custom(func(a, b): return a[1] < b[1])
	return _help_list


func _spot_of(c: Dictionary) -> Vector3:
	var key := Vector3i(c["cell"].x, c["cell"].y, int(c.get("level", 0)))
	if not _spots.has(key):
		_spots[key] = game.lift(c["cell"], int(c.get("level", 0)))
	return _spots[key]


func _mates_up() -> int:
	var n := 0
	for o in game.squad:
		if o != game.player and o.is_alive() and not o.body.downed:
			n += 1
	return n


## Arrows that flew and things dropped near us are picked up on the way
## (an archer gets her arrows back), when nothing is after us.
func _pick_ground(p) -> bool:
	var player = game.player
	var best := -1
	var best_d := PICK_R
	for i in range(game.ground_items.size()):
		var g: Dictionary = game.ground_items[i]
		if g.has("weapon") or not PICK_IDS.has(String(g["id"])):
			continue
		var d: float = p.position.distance_to(g["pos"])
		if d < best_d and g["pos"].distance_to(player.position) < PICK_R + 2.0:
			best_d = d
			best = i
	if best < 0:
		return false
	if best_d > 0.9:
		_walk(p, game.ground_items[best]["pos"], false)
	else:
		var g2: Dictionary = game.ground_items[best]
		game.actions.pick_up(p, best)
		if g2["id"] == "arrow":
			game.say(p, "%s: 화살을 주웠다." % p.display_name)
	return true


## One of us bleeding with no bandage of their own: a companion with one to
## spare brings it over (the medic treats instead, above).
func _hand_over(p) -> bool:
	if p.medical != "none" or int(p.items.get("bandage", 0)) <= 0:
		return false
	for o in game.squad:
		if o == p or not o.is_alive() or o.body.bleed <= 0 or not o.grabbers.is_empty():
			continue
		if int(o.items.get("bandage", 0)) > 0 or o.items.has("medkit"):
			continue
		var d: float = o.position.distance_to(p.position)
		if d > GIVE_R:
			continue
		if d > 1.6:
			_walk(p, o.position, o.body.bleed >= 2)
		else:
			p.face_point(o.position)
			p.take_item("bandage")
			o.add_item("bandage")
			game.say(p, "%s: %s에게 붕대를 건넸다." % [p.display_name, o.display_name])
		return true
	return false


## Walk to and search the nearest unsearched container near `around`.
func _search_near(p, around: Vector3) -> bool:
	var best = null
	var best_d := 9.0
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if c["searched"] or c["locked"] or c.get("busy", false):
			continue
		var d: float = FieldGrid.center(c["cell"]).distance_to(around)
		if d < best_d:
			best_d = d
			best = c
	if best == null:
		return false
	var at := FieldGrid.center(best["cell"])
	if p.position.distance_to(at) > 1.3:
		_walk(p, at, false)
	else:
		game.actions.search(p, best["id"])
	return true


# ---------------------------------------------------------------- work crew

func _crew(p, delta: float, think: bool) -> void:
	if crew_recalled or p.brain.get("job", "") == "home":
		var doors: Array = game.data["spawns"]["train_door"]
		var door := FieldGrid.center(doors[mini(1, doors.size() - 1)])
		if p.position.distance_to(door) > 1.5:
			if think:
				_walk(p, door, true)
		else:
			p.brain["boarded"] = true
			p.visible = false
			p.position = door + Vector3(0, -50, 0)
		return
	if p.role == "escort":
		if think:
			_escort(p)
		return
	if not think:
		return
	var threat := _threat_near(p, 6.0)
	if not threat.is_empty():
		# Carriers run for the platform and wait there until it is clear.
		p.cancel_action()
		p.brain["fleeing"] = true
		if threat["pos"].distance_to(p.position) < 1.2:
			game.combat.shove(p)
		_walk(p, FieldGrid.center(Vector2i(int(p.position.x), 8)), true)
		return
	p.brain["fleeing"] = false
	if p.action != "":
		return
	var job: String = p.brain.get("job", "dig")
	if job == "repair":
		var to = game.mission_play.repair_step(p)
		if to != null:
			_walk(p, to, false)
		return
	if job == "dig":
		var wagon: Dictionary = _wagon_with_coal()
		if wagon.is_empty():
			p.brain["job"] = "home"
			return
		var at := FieldGrid.center(wagon["work"]) + Vector3(game.rng.randf_range(-1.5, 1.5), 0, 0.2)
		if p.position.distance_to(FieldGrid.center(wagon["work"])) > 2.2:
			_walk(p, at, false)
			return
		p.start_action("dig", "곡괭이질", DIG_TIME, _dug.bind(p))
		return
	if job == "carry":
		var drop := FieldGrid.center(Vector2i(clampi(int(p.position.x), 17, 96), 6))
		if p.position.distance_to(drop) > 1.0:
			_walk(p, drop, false)
			return
		game.actions.coal_delivered += float(p.brain.get("load", 0.0))
		game.telemetry.trip()
		game.mission_play.loaded()
		p.brain["load"] = 0.0
		p.brain["job"] = "dig"


func _dug(p) -> void:
	var w: Dictionary = _wagon_with_coal()
	if w.is_empty():
		return
	var take := minf(TRIP_COAL * game.mission_play.load_mult(), float(w["coal"]))
	w["coal"] = float(w["coal"]) - take
	p.brain["load"] = take
	p.brain["job"] = "carry"


func _wagon_with_coal() -> Dictionary:
	for w in game.data["wagons"]:
		if w.has("work") and float(w["coal"]) > 0.001:
			return w
	return {}


## Escorts guard the carriers. Attitude says how far they go out; fire
## permission says whether they may shoot (s2_station 2.4).
func _escort(p) -> void:
	var site: Vector3 = FieldGrid.center(game.data["spots"]["work_site"]["cell"])
	var reach: float = {"aggressive": 12.0, "defensive": 6.0, "neutral": 2.0}.get(crew_attitude, 6.0)
	var threat: Dictionary = {}
	var best := 999.0
	for z in game.zombies.in_radius(site, reach + 6.0):
		if not game.zombies.active(z) or z["state"] == "downed":
			continue
		var near_worker := 999.0
		for w in game.crew:
			if w.is_alive() and w.role == "worker":
				near_worker = minf(near_worker, w.position.distance_to(z["pos"]))
		var d: float = minf(p.position.distance_to(z["pos"]), near_worker)
		var attacking: bool = z["state"] == "attack" or z["state"] == "grab"
		if crew_attitude == "neutral" and not attacking and p.position.distance_to(z["pos"]) > 2.0:
			continue
		if d < reach and d < best:
			best = d
			threat = z
	if threat.is_empty():
		if p.aim.active:
			p.aim.stop()
		p.target_zombie = {}
		var post: Vector3 = site + Vector3(-4.0 if p.brain.get("side", 0) == 0 else 4.0, 0, 1.5)
		if p.position.distance_to(post) > 1.5:
			_walk(p, post, false)
		return
	var dist: float = p.position.distance_to(threat["pos"])
	var may_shoot: bool = crew_fire == "free" or (crew_fire == "threat" and best < 5.0)
	if may_shoot and dist > 2.0:
		_prefer(p, true)
		if W.is_ranged(p.weapon_id()):
			_shoot_or_aim(p, threat["pos"], threat)
			return
	_prefer(p, false)
	game.combat.melee_target(p, threat, true)


# ---------------------------------------------------------------- raiders

func _raider(r, delta: float, think: bool) -> void:
	var b: Dictionary = r.brain
	var state: String = b.get("state", "idle")
	if state in ["surrender", "prisoner", "gone"]:
		if state == "prisoner" and think:
			_follow_as_prisoner(r)
		return
	if state == "flee":
		if think:
			var exit := FieldGrid.center(game.data["anchors"]["flee_exit"])
			if r.position.distance_to(exit) < 2.0:
				b["state"] = "gone"
				fled += 1
				r.visible = false
				r.position.y = -50.0
				r.body.dead = true
				game.receipt.place_note("raidersFled", fled)
			else:
				_walk(r, exit, true)
		return
	if not think:
		return
	_raider_perceive(r)
	_raider_morale(r)
	if b["state"] in ["flee", "surrender"]:
		return
	var target = b.get("target")
	var sees: bool = target != null and target.is_alive() and _raider_sees(r, target)
	if sees:
		b["last_seen"] = target.position
		b["lost_t"] = 0.0
	match b["state"]:
		"idle":
			if r.position.distance_to(b["home"]) > 1.0:
				_walk(r, b["home"], false)
		"alert":
			# Heard something: the shooter holds, the others go and look.
			if b["role"] == "shooter":
				r.face_point(b["last_seen"])
			elif r.position.distance_to(b["last_seen"]) > 2.0:
				_walk(r, b["last_seen"], false)
			else:
				b["state"] = "search"
				b["search_t"] = 20.0
		"search":
			b["search_t"] = float(b.get("search_t", 20.0)) - THINK
			if b["search_t"] <= 0.0:
				b["state"] = "idle"
			elif r.path.is_empty():
				var off := Vector3(game.rng.randf_range(-5, 5), 0, game.rng.randf_range(-5, 5))
				_walk(r, b["last_seen"] + off, false)
		"fight":
			b["fight_t"] = float(b.get("fight_t", 0.0)) + THINK
			if not sees:
				b["lost_t"] = float(b.get("lost_t", 0.0)) + THINK
				if r.aim.active:
					r.aim.stop()
				b["aiming"] = false
				if b["lost_t"] > 6.0:
					b["state"] = "search"
					b["search_t"] = 20.0
					return
			_raider_fight(r, target, sees)


func _raider_sees(r, p) -> bool:
	var d: float = r.position.distance_to(p.position)
	var sight: float = RAIDER_SIGHT * float(game.weather.sight_mult(game.clock.is_dark()))
	if p.crouched:
		sight *= 0.6
	if d > sight:
		return false
	return game.sight_clear(r.position, p.position)


## A person has to stay in view 1-2 s before a raider notices (field_unified 11).
func _raider_perceive(r) -> void:
	var b: Dictionary = r.brain
	var best = null
	var best_d := 999.0
	for p in game.allies_alive():
		if p.brain.get("boarded", false):
			continue
		if _raider_sees(r, p):
			var d: float = r.position.distance_to(p.position)
			if d < best_d:
				best_d = d
				best = p
	if best == null:
		b["aware"] = maxf(0.0, float(b.get("aware", 0.0)) - THINK * 0.3)
		return
	var rate: float = THINK / NOTICE_TIME * (2.0 if best_d < 6.0 else 1.0)
	b["aware"] = minf(1.0, float(b.get("aware", 0.0)) + rate)
	if b["aware"] >= 1.0:
		if b["state"] != "fight":
			_alert_all(best, r)
		b["target"] = best


## One raider seeing us tells the others: they share the last position.
func _alert_all(target, spotter) -> void:
	for o in game.raiders:
		if not o.is_alive() or o.brain.get("state", "") in ["flee", "surrender", "prisoner", "gone"]:
			continue
		o.brain["state"] = "fight"
		o.brain["aware_of_us"] = true
		o.brain["target"] = target
		o.brain["last_seen"] = target.position
	if not game.auto_paused_once and game.opts.get("auto_pause", true):
		game.auto_paused_once = true
		game.paused = true
		game.hud.toast("약탈자가 겨눈다. 멈췄다. 명령을 고르고 계속을 누른다.")
	game.receipt.place_note("raiders", "fought")


func _raider_fight(r, target, sees: bool) -> void:
	var b: Dictionary = r.brain
	if target == null or not target.is_alive():
		b["state"] = "search"
		b["search_t"] = 10.0
		return
	var at: Vector3 = target.position if sees else b["last_seen"]
	var d: float = r.position.distance_to(at)
	match b["role"]:
		"shooter":
			# Holds inside the pharmacy, shoots through the door and windows.
			if sees and d < float(W.get_data(r.weapon_id()).get("range", 12.0)) + 4.0:
				b["aiming"] = true
				_shoot_or_aim(r, at, target)
			else:
				b["aiming"] = false
				if r.position.distance_to(b["home"]) > 1.0:
					_walk(r, b["home"], false)
		"advancer":
			# Moves up from cover to cover, shoots when it has a line.
			if sees and d < 14.0:
				r.stop()
				b["aiming"] = true
				_shoot_or_aim(r, at, target)
			else:
				b["aiming"] = false
				_walk(r, _cover_near(at, r.position), false)
		"flanker":
			# Goes round the side and closes in with the axe: it names a target only
			# within the blow's reach and with nothing in the way, else it walks on.
			if sees and d <= game.combat.melee_range(r) and not game.combat.melee_blocked(r, target.position):
				game.combat.melee_person(r, target)
			else:
				var side := Vector3(-(at - r.position).z, 0, (at - r.position).x).normalized() * 5.0
				var goal: Vector3 = at + side if d > 8.0 else at
				_walk(r, goal, d < 10.0)


## A walkable cell next to low cover between me and them, or just closer.
func _cover_near(at: Vector3, from: Vector3) -> Vector3:
	var best := from.lerp(at, 0.35)
	var best_score := 999.0
	for rect in game.data["low_blocks"]:
		var center := Vector3(rect.position.x + rect.size.x * 0.5, 0, rect.position.y + rect.size.y * 0.5)
		var dist_t: float = center.distance_to(at)
		if dist_t < 5.0 or dist_t > 16.0:
			continue
		var score: float = center.distance_to(from) + dist_t * 0.5
		if score < best_score:
			best_score = score
			var side: Vector3 = (center - at).normalized() * (maxf(rect.size.x, rect.size.y) * 0.5 + 1.0)
			best = center + side
	var c: Vector2i = game.grid.nearest_walkable(FieldGrid.cell_of(best), false, 3)
	return FieldGrid.center(c)


## Morale (field_unified 11): fear from both sides, hurt friends, ammo, pain,
## the way out. It breaks into running away, or into giving up.
func _raider_morale(r) -> void:
	var b: Dictionary = r.brain
	if b["state"] != "fight":
		return
	var m: float = float(b.get("morale", 1.0))
	var dead_near: int = game.zombies.in_radius(r.position, 6.0).size()
	if dead_near >= 3:
		m -= 0.02
	if float(b.get("fight_t", 0.0)) > 90.0 and not b.get("long_fight", false):
		b["long_fight"] = true
		m -= 0.15
	if W.is_ranged(r.weapon_id()) and int(r.weapon()["loaded"]) <= 0 and int(b.get("ammo", 6)) <= 0:
		m -= 0.01
	b["morale"] = m
	var friends := 0
	for o in game.raiders:
		if o != r and o.is_alive() and not o.body.downed and o.brain.get("state", "") == "fight":
			friends += 1
	if m < 0.45 and r.body.bleed > 0 or m < 0.3 and friends == 0:
		_surrender(r)
	elif m < 0.3:
		b["state"] = "flee"
		b["aiming"] = false
		r.aim.stop()
		game.say(r, "약탈자 하나가 남쪽 길로 달아난다.")


func _surrender(r) -> void:
	var b: Dictionary = r.brain
	b["state"] = "surrender"
	b["aiming"] = false
	r.aim.stop()
	r.stop()
	r.target_person = null
	# Whoever was hitting this raider stops: the card decides what happens next.
	for q in game.people_alive():
		if q.target_person == r:
			q.target_person = null
			q.hold_attack = false
	if not r.hands.is_empty():
		var h: Dictionary = r.hands[0]
		game.ground_items.append({"pos": r.position + Vector3(0.6, 0, 0), "id": h["id"], "n": 1, "weapon": h.duplicate()})
	r.set_weapon_slots([])
	surrendered = r
	game.hud.card("surrender", "약탈자가 무기를 내려놓고 손을 든다.", [
		{"id": "take", "label": "묶어서 데려간다", "say": "\"손 뒤로. 열차까지 걷는다.\""},
		{"id": "disarm", "label": "무기만 뺏고 보낸다", "say": "\"가라. 다시 보이면 그땐 없다.\""},
		{"id": "shoot", "label": "쏜다", "say": "\"약을 훔친 값이다.\""},
	], Callable(self, "_on_surrender_choice").bind(r))


func _on_surrender_choice(choice: String, r) -> void:
	game.decisions.append({"id": "raider_surrender", "choice": choice})
	match choice:
		"take":
			r.brain["state"] = "prisoner"
			r.team = "survivor"
			game.receipt.place_note("prisoners", 1)
		"disarm":
			r.brain["state"] = "flee"
		"shoot":
			game.make_sound(r.position, SimNoise.Level.LOUD, "gun", game.player)
			var seen: Array = []
			for o in game.allies_alive():
				if o.position.distance_to(r.position) < 15.0:
					seen.append(o.pid)
			game.receipt.witness(game.player.pid, "shot_surrendered_raider", "station_street", game.clock.label(), "raider_surrendered", seen)
			game.on_person_died(r)


func _follow_as_prisoner(r) -> void:
	var p = game.player
	if r.position.distance_to(p.position) > 2.5:
		_walk(r, p.position - Vector3(sin(p.facing), 0, cos(p.facing)) * 1.8, false)
	if game.FieldMaps.by_train(game.data, FieldGrid.cell_of(r.position)):
		r.brain["boarded"] = true


## Raiders hear loud sounds like the dead do (8.2): they turn to the spot.
func raiders_hear(at: Vector3, radius: float, from) -> void:
	for r in game.raiders:
		if r == from or not r.is_alive() or r.body.downed:
			continue
		var b: Dictionary = r.brain
		if b.get("state", "") in ["flee", "surrender", "prisoner", "gone"]:
			continue
		if r.position.distance_to(at) > radius:
			continue
		if from != null and from.team == "raider":
			continue
		# They know gunfire calls the dead too.
		b["morale"] = float(b.get("morale", 1.0)) - 0.03
		if b.get("state", "idle") != "fight":
			b["state"] = "alert"
			b["last_seen"] = at


func raider_hit(r, by) -> void:
	var b: Dictionary = r.brain
	b["morale"] = float(b.get("morale", 1.0)) - 0.25
	b["hit_by"] = by.pid if by != null else ""
	if b.get("state", "") in ["idle", "alert", "search"] and by != null:
		b["state"] = "fight"
		b["aware_of_us"] = true
		b["target"] = by
		b["last_seen"] = by.position
		_alert_all(by, r)


func raider_downed(r) -> void:
	r.brain["aiming"] = false
	for o in game.raiders:
		if o != r and o.is_alive():
			o.brain["morale"] = float(o.brain.get("morale", 1.0)) - 0.35
