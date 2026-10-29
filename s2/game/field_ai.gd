extends RefCounted
## People who are not the player: three companions, the work crew and the
## raiders in the pharmacy (field_unified 9·11, s2_station 2.4·2.5).
## Raiders only know what they saw or heard: last position, never the truth.

const FieldGrid = preload("res://game/world/field_grid.gd")
const W = preload("res://game/sim/weapons.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const FieldCombat = preload("res://game/field_combat.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")
const MoveRules = preload("res://game/sim/move_rules.gd")

const FOLLOW_OFFSETS: Array = [Vector2(-1.3, -1.2), Vector2(1.3, -1.2), Vector2(0.0, -2.4)]
const THINK: float = 0.25
const REACT_MIN: float = 0.4
const REACT_MAX: float = 0.8
const THREAT_R: float = 3.0
const COVER_R: float = 11.0
const RAIDER_SIGHT: float = 22.0
const NOTICE_TIME: float = 1.5
const FieldWork = preload("res://game/field_work.gd")
const DIG_TIME: float = FieldWork.DIG_TIME
const TRIP_COAL: float = FieldWork.TRIP_COAL
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
## Stepping back toward the chief, it keeps this far from the chief's body (check
## shots 10-26: it backed into the chief and the two bodies stood as one).
const CHIEF_ROOM: float = 1.0
## Walking, the one in front keeps this far ahead of the chief.
const LEAD_AHEAD: float = 3.0
## Slow work is dropped when one of the dead gets this near.
const BREAK_R: float = 1.8
const BREAKS: Array = ["search", "treat", "loot", "salvage", "rub", "board"]
## Sent to the train (the user's field test 2026-10-25, 14; new values): this near a door it climbs
## in, for this long; the dead within DOOR_CROWD_R of a door make it as far as
## DOOR_CROWD_M more each, and a door taken is kept unless another comes
## DOOR_KEEP_M nearer.
const BOARD_NEAR: float = 1.5
const BOARD_S: float = 1.5
const DOOR_CROWD_R: float = 3.0
const DOOR_CROWD_M: float = 8.0
const DOOR_KEEP_M: float = 5.0
## On the move and not getting anywhere for this long: find the way again.
const STUCK_T: float = 1.5
## The door the chief went in by is held while he is this near it.
const DOOR_HOLD_R: float = 16.0
## The chief stops by things to search: one companion at a time searches the
## others within HELP_R of him, the rest keep by him (decision 406, bundle 2;
## one at a time, decision 409).
const HELP_R: float = 6.0
## Arrows and dropped things this near (and this near the chief) are picked up.
const PICK_R: float = 6.0
## A bleeding one of us with no bandage this near gets one handed over.
const GIVE_R: float = 12.0
## A thing it cannot get to in this long is given up.
const HELP_GIVE_UP: float = 12.0
## What is worth stooping for: light, and of use to everyone.
const PICK_IDS: Array = ["ammo_craft", "ammo_pistol", "ammo_shell", "bandage", "cloth"]
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
## Decision 486: the slot is where to keep, the lead is where to walk toward.
const FOLLOW_POINT_SIDE: float = 2.1
const FOLLOW_SIDE := Vector2(2.4, -0.6)
const FOLLOW_REAR_BACK: float = 2.5
const FOLLOW_IDLE_POINT := Vector2(1.2, 1.6)
const FOLLOW_IDLE_SIDE := Vector2(1.8, -0.8)
const FOLLOW_IDLE_REAR := Vector2(0.0, -2.0)
const FOLLOW_IDLE_ASIDE := Vector2(-2.0, -0.5)
const FOLLOW_LEAD_S: float = 1.0
const FOLLOW_BUFFER_S: float = 0.6
const FOLLOW_PATH_NEAR: float = 0.12
const FOLLOW_RUN_ON: float = 4.5
const FOLLOW_RUN_OFF: float = 2.5
const FOLLOW_ROOM: float = 0.95
const FOLLOW_SLOT_STEP: float = 1.0
const FOLLOW_SETTLE: float = 0.3
const FOLLOW_SHUFFLE: float = 1.2   # Decision 486: watch only during a short idle adjustment.
const FOLLOW_WALK_MIN: float = 2.0
const FOLLOW_WALK_MAX: float = 4.0
const FOLLOW_SIDE_MAX: float = 3.0
const FOLLOW_REAR_MAX: float = 3.5
const FOLLOW_IDLE_MIN: float = 1.5
const FOLLOW_IDLE_MAX: float = 2.5
const FOLLOW_POINT_CLEAR: float = 1.5
const FOLLOW_EPS: float = 0.001
const FOLLOW_TRAIL_STEP: float = 0.6
const FOLLOW_TRAIL_CAP: int = 64
const FOLLOW_QUEUE_GAP: float = 1.25
const FOLLOW_QUEUE_WAIT: float = 0.9
const FOLLOW_GAP_BAND: float = 0.15   # Decision 486: separate gap stop and restart thresholds.
const FOLLOW_QUEUE_RESUME: float = 1.45
const FOLLOW_QUEUE_LEAD_S: float = 0.5   # Decision 486: lead along the trail.
const FOLLOW_QUEUE_GAP_S: float = 0.2
const FOLLOW_LEADER_STILL: float = 0.3
const FOLLOW_DOOR_RECENT: float = 5.0
const FOLLOW_NARROW_SCAN: int = 3
const FOLLOW_NARROW_WIDTH: int = 2
const FOLLOW_NARROW_HOLD: float = 4.0   # Decision 486: keep the line past a corner.
const LOOK_CAMERA_DEG: float = 60.0

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
## Decision 486: one bounded breadcrumb ring for all companions, sampled once per update.
var _follow_trail := PackedVector3Array()
var _follow_head: int = 0
var _follow_count: int = 0
var _follow_last := Vector3.ZERO   # read only once the trail has a point (saved: no INF)
var _follow_rest: float = 0.0
var _follow_distance: float = 0.0
var _follow_door_at: float = -INF
var _follow_door_id: int = 0
var _follow_cell := Vector3(-1, -1, -1)   # cell x, y and level; a Vector3 so the field save keeps it
var _follow_order: Array = []
var _follow_queue_on: bool = false
var _follow_narrow_at: float = -FOLLOW_NARROW_HOLD


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
	_record_follow()
	if think:
		think_t = THINK
		_track_door()
		_refresh_follow_queue()
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
			if float(p.brain.get("follow_t", -INF)) != game.clock.elapsed:
				_clear_follow_latches(p)
				_follow_release_watch(p)
				p.brain.erase("follow_t")
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
## drop the path so the next walk finds a new one (reference game 1 mod lesson: a
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
## (reference game 1 mod lesson: workers that let themselves be eaten mid-task).
func _companion(p) -> void:
	if _hold_swing(p):
		return
	var player = game.player
	# Out of the train again at the door it went in by: an order other than to
	# the train (field_hud.gd _command) took it off the train.
	if p.brain.has("board_at") and not p.brain.get("boarded", false):
		p.position = p.brain["board_at"]
		p.brain.erase("board_at")
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
			# Into the train (the user's field test, 14): to the door the dead crowd least,
			# a moment to climb up, then inside and out of their reach (_boarded).
			# One at arm's length is shoved off on the way: it does not turn its
			# back to climb (a dead one this near breaks the climb, BREAKS).
			if p.brain.get("boarded", false):
				return
			p.brain.erase("boarding")
			var door := _board_door(p)
			var gap: float = INF if threat.is_empty() else float(threat["pos"].distance_to(p.position))
			if p.position.distance_to(door) > BOARD_NEAR:
				_walk(p, door, true)
			elif gap > BREAK_R:
				p.stop()
				p.face_point(door)
				p.brain["boarding"] = true
				p.start_action("board", "타는 중", BOARD_S, _boarded.bind(p, door))
			if gap < 1.3:
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
	if _hold_swing(p):
		return
	if _finish_fallen(p):
		return
	var d: float = p.position.distance_to(z["pos"])
	if _crowd(p) >= CROWD_N:
		p.target_zombie = {}
		if p.aim.active:
			p.aim.stop()
		var away: Vector3 = (p.position - z["pos"])
		away.y = 0
		var back: Vector3 = (away.normalized() + (game.player.position - p.position).normalized() * 0.5).normalized()
		# It steps back with its face to them, at a walk, not turning its back to run off
		# and round again to shove (move_rules.gd; user field test: they "whip round").
		p.running = false
		_walk(p, game.walkable_near(_beside_chief(p.position, p.position + back * 2.5, away), false, 2), false)
		p.brain["face_hold"] = z["pos"]
		p.brain["face_hold_t"] = game.clock.elapsed
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
	# In reach it stops where it is and strikes; out of reach the chase walks the way (결정 441 (1)).
	if d <= game.combat.melee_range(p) and not game.combat.melee_blocked(p, z["pos"]):
		p.stop()
	game.combat.melee_target(p, z, true)


## Where to step back to from `from`, `to` as the crowd and the chief give it, not
## through the chief: a way back that comes within CHIEF_ROOM of the chief ends at
## the chief's side instead, the side it is on (straight on: square to `away`).
func _beside_chief(from: Vector3, to: Vector3, away: Vector3) -> Vector3:
	var chief: Vector3 = game.player.position
	var way := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var rel := Vector3(chief.x - from.x, 0.0, chief.z - from.z)
	var along := clampf(rel.dot(way) / maxf(way.length_squared(), 0.0001), 0.0, 1.0)
	var off := from + way * along - chief
	off.y = 0.0
	if off.length() >= CHIEF_ROOM:
		return to
	if off.length() < 0.05:
		off = Vector3(-away.z, 0.0, away.x)
		if off.length() < 0.05:
			off = Vector3.RIGHT
	return Vector3(chief.x, to.y, chief.z) + off.normalized() * CHIEF_ROOM


## A swing once begun is seen through where it stands (결정 441 (1)): no next target or
## order takes it off. The rest after a blow and a stomp do not hold it, nor a shove:
## that plants the feet over its first half (feet_held) but keeps the order.
func _hold_swing(p) -> bool:
	if p.strike_kind != "swing" or (p.strike_t <= 0.0 and not game.combat.blow_holds_feet(p)):
		return false
	p.stop()
	return true


## Stopping to swing (결정 441 (1)) left the ones it knocked down behind as it went on to the
## next, and they got up again among the squad. So one already down within the blow's reach
## is finished with the weapon in hand before it moves on. It never walks to a body further
## off, and a gun or bare hands (a stomp) keep to the shove they had.
func _finish_fallen(p) -> bool:
	if p.action != "" or not p.grabbers.is_empty():
		return false
	var best: Dictionary = {}
	var nearest: float = game.combat.melee_range(p)
	for z in _dead_near(p.position, nearest):
		if z["state"] != "downed" or game.combat.stomps(p, z):
			continue
		var seen: Vector3 = game.zombies.seen_pos(z)   # where a blow is judged (decision 487)
		var d: float = p.position.distance_to(seen)
		if d <= nearest and not game.combat.melee_blocked(p, seen):
			nearest = d
			best = z
	if best.is_empty():
		return false
	p.stop()
	game.combat.melee_target(p, best, true)
	return true


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
	# Decision 486: stale follow latches must not survive a different task.
	if game.clock.elapsed - float(p.brain.get("follow_t", -INF)) >= THINK * 2.0:
		_clear_follow_latches(p)
	_follow_release_watch(p)
	p.brain.erase("follow_walk_t")
	p.brain["follow_t"] = game.clock.elapsed
	var player = game.player
	var role := _role(p)
	var fwd := _follow_forward()
	var right := Vector3(fwd.z, 0, -fwd.x)
	var walking: bool = player.moving
	p.crouched = player.crouched
	# Decision 486: door duty keeps its old destination, pace and outward watch.
	if role == "rear" and _holds_door(p):
		var door := FieldGrid.center(held_door["cell"])
		var post: Vector3 = game.walkable_near(door - held_door["out"], false, 3)
		if post.distance_to(player.position) < 0.9:
			var off: Vector2 = FOLLOW_OFFSETS[clampi(game.squad.find(p) - 1, 0, 2)]
			var facing := Vector3(sin(player.facing), 0, cos(player.facing))
			post = game.walkable_near(player.position + Vector3(facing.z, 0, -facing.x) * off.x + facing * off.y, false, 3)
		var door_gap: float = p.position.distance_to(post)
		if door_gap > 0.8:
			_walk(p, post, player.running or door_gap > 7.0)
		elif p.path.is_empty():
			p.face_point(p.position + held_door["out"])
		return
	if role == "point" and player.aim.active:
		role = "aside"
	var mates := _follow_mates()
	var spot := _follow_spot(p, mates, fwd, right)
	if spot.is_finite():
		p.brain["follow_slot"] = spot
	else:
		p.brain.erase("follow_slot")   # saved with the brain: never an INF
	var look := fwd
	if not walking:
		look = _look_out(p, role, fwd, right)
	if _follow_queueing(p, spot, fwd):
		var leader = _follow_leader(p)
		if _follow_wait(p, leader):
			p.stop()
			if not walking:
				p.face_point(p.position + look)
			return
		var leader_back: float = float(_follow_projection(leader.position)["back"])
		var going: bool = _follow_going(leader)
		var leader_speed: float = leader.speed(game.grid_at(leader.position).floor_at(FieldGrid.cell_of(leader.position))) if going else 0.0
		var gap: float = leader_back + FOLLOW_QUEUE_GAP + leader_speed * FOLLOW_QUEUE_GAP_S
		var own_back: float = float(_follow_projection(p.position)["back"])
		var waiting: bool = p.brain.get("follow_gap_waiting", false)
		var stop_gap: float = leader_back + FOLLOW_QUEUE_WAIT + FOLLOW_GAP_BAND if going else gap
		# Decision 486: a stopped follower waits for the full gap across thinks.
		if own_back < (gap if waiting else stop_gap):
			p.brain["follow_gap_waiting"] = true
			p.stop()
			return
		p.brain.erase("follow_gap_waiting")
		var route: PackedVector3Array
		if own_back < gap:
			# Decision 486: keep walking forward inside the band, without a running lead.
			route = _follow_queue_path(p, leader_back + FOLLOW_QUEUE_WAIT, fwd)
		else:
			route = _follow_queue_path(p, gap, fwd)
			if going and not route.is_empty():
				var own_speed: float = p.speed(game.grid_at(p.position).floor_at(FieldGrid.cell_of(p.position)))
				var lead: Vector3 = _follow_trail_at(maxf(leader_back + FOLLOW_QUEUE_WAIT, gap - own_speed * FOLLOW_QUEUE_LEAD_S))
				if _follow_clear(route[-1], lead):
					route.append(lead)
		route = _follow_leave_room(p, route, leader)
		_follow_walk(p, route, leader)
		if own_back < gap:
			p.running = false
			p.brain["follow_running"] = false
		if not walking and p.path.is_empty():
			p.face_point(p.position + look)
		return
	if not walking and p.position.distance_to(spot) <= FOLLOW_SETTLE:
		p.stop()
		p.running = false
		p.brain["follow_running"] = false
		p.face_point(p.position + look)
		return
	var route := _follow_path(p.position, spot)
	if walking and not route.is_empty() and route[-1].distance_to(spot) <= FOLLOW_EPS:
		var speed: float = player.speed(game.grid_at(player.position).floor_at(FieldGrid.cell_of(player.position)))
		var own_speed: float = p.speed(game.grid_at(p.position).floor_at(FieldGrid.cell_of(p.position)))
		var lead := maxf(speed * FOLLOW_LEAD_S, own_speed * FOLLOW_BUFFER_S + FOLLOW_PATH_NEAR)
		var goal := spot + fwd * lead
		if _follow_clear(spot, goal):
			# Decision 486: retain the detour to the slot; only its clear tail gets a lead.
			if _follow_clear(p.position, goal):
				route = PackedVector3Array([goal])
			else:
				route.append(goal)
	_follow_walk(p, route, null, fwd if walking else Vector3.ZERO)
	if not walking:
		_follow_watch(p, look)


## Decision 486: read motion rather than aim; a raised gun can face across the walk.
func _follow_forward() -> Vector3:
	var player = game.player
	if player.moving:
		if player.drive_speed > 0.0 and player.drive_dir.length_squared() > 0.0001:
			return Vector3(player.drive_dir.x, 0, player.drive_dir.z).normalized()
		for next: Vector3 in player.path:
			var way: Vector3 = next - player.position
			way.y = 0.0
			if way.length() > 0.12:
				return way.normalized()
	return Vector3(sin(player.facing), 0, cos(player.facing))


## Decision 486: interpolate fixed spacing without consuming the game's random stream.
func _record_follow() -> void:
	var at: Vector3 = game.player.position
	if _follow_count == 0:
		_follow_trail.resize(FOLLOW_TRAIL_CAP)
		_follow_put(at)
	else:
		var distance := _follow_last.distance_to(at)
		_follow_distance += distance
		if game.level_of(_follow_last) != game.level_of(at) or distance > FOLLOW_TRAIL_STEP * FOLLOW_TRAIL_CAP:
			_follow_put(at)
			_follow_rest = 0.0
		elif distance > 0.0001:
			var cursor := _follow_last
			var left := distance
			var step := FOLLOW_TRAIL_STEP - _follow_rest
			for _i in range(FOLLOW_TRAIL_CAP):
				if left < step:
					break
				cursor = cursor.move_toward(at, step)
				_follow_put(cursor)
				left -= step
				step = FOLLOW_TRAIL_STEP
			_follow_rest = FOLLOW_TRAIL_STEP - step + left
	_follow_last = at
	var cell := FieldGrid.cell_of(at)
	var key := Vector3(cell.x, cell.y, game.level_of(at))
	if key != _follow_cell and game.grid_at(at).doors.has(cell):
		_follow_door_id += 1
		_follow_door_at = _follow_distance
	_follow_cell = key


func _follow_put(at: Vector3) -> void:
	_follow_trail[_follow_head] = at
	_follow_head = (_follow_head + 1) % FOLLOW_TRAIL_CAP
	_follow_count = mini(_follow_count + 1, FOLLOW_TRAIL_CAP)


## Decision 486: role order also settles competing slots, independent of think order.
func _follow_mates() -> Array:
	var mates: Array = []
	for role in ["point", "side", "rear"]:
		for q in game.squad:
			if _follow_active(q) and _role(q) == role:
				mates.append(q)
	return mates


## Decision 486: busy and stale companions release both their slot and their place in line.
func _follow_active(p) -> bool:
	return p != game.player and p.is_alive() and p.can_act() and not p.body.downed \
		and p.command in ["follow", "cover"] and p.action == "" and not p.brain.get("boarded", false) \
		and game.clock.elapsed - float(p.brain.get("follow_t", -INF)) < THINK * 2.0


func _follow_spot(p, mates: Array, fwd: Vector3, right: Vector3) -> Vector3:
	var walking: bool = game.player.moving
	var claimed: Array[Vector3] = []
	for q in mates:
		var role := _role(q)
		if role == "point" and game.player.aim.active:
			role = "aside"
		var near := FOLLOW_WALK_MIN if walking else FOLLOW_IDLE_MIN
		var far := FOLLOW_WALK_MAX if walking else FOLLOW_IDLE_MAX
		if walking and role == "rear":
			near = FOLLOW_REAR_BACK
			far = FOLLOW_REAR_MAX
		elif walking and role in ["side", "aside"]:
			far = FOLLOW_SIDE_MAX
		var off: Vector2
		match role:
			"point": off = Vector2(FOLLOW_POINT_SIDE, LEAD_AHEAD) if walking else FOLLOW_IDLE_POINT
			"aside": off = Vector2(-FOLLOW_SIDE.x, FOLLOW_SIDE.y) if walking else FOLLOW_IDLE_ASIDE
			"rear": off = Vector2(0.0, -FOLLOW_REAR_BACK) if walking else FOLLOW_IDLE_REAR
			_: off = FOLLOW_SIDE if walking else FOLLOW_IDLE_SIDE
		var chosen := Vector3.INF
		# Decision 486: prefer the base slot, then a valid saved slot, then side shifts.
		var base_offset: Vector3 = right * off.x + fwd * off.y
		base_offset = base_offset.normalized() * clampf(base_offset.length(), near, far)
		var base_spot: Vector3 = game.walkable_near(game.player.position + base_offset, false, 1)
		if _follow_slot_free(q, base_spot, claimed, role, near, far, fwd, right):
			chosen = base_spot
		if not chosen.is_finite() and q.brain.get("follow_slot_role", "") == role and q.brain.get("follow_slot_walking", not walking) == walking:
			var saved: Vector2 = q.brain.get("follow_offset", Vector2.ZERO)
			var prior: Vector3 = q.brain.get("follow_slot", Vector3.INF)
			if walking and prior.is_finite():
				prior = game.player.position + right * saved.x + fwd * saved.y
			if _follow_slot_free(q, prior, claimed, role, near, far, fwd, right):
				chosen = prior
		if not chosen.is_finite():
			for shift in [1, -1, 2, -2, 3, -3, 4, -4]:
				var offset: Vector3 = right * (off.x + float(shift) * FOLLOW_SLOT_STEP) + fwd * off.y
				offset = offset.normalized() * clampf(offset.length(), near, far)
				var spot: Vector3 = game.walkable_near(game.player.position + offset, false, 1)
				if _follow_slot_free(q, spot, claimed, role, near, far, fwd, right):
					chosen = spot
					break
		# Decision 486: a fallback behind the chief must not become a reusable role slot.
		var fallback: bool = not chosen.is_finite()
		if fallback:
			chosen = game.walkable_near(game.player.position - fwd * near, false, 1)
			q.brain.erase("follow_slot_role")
			q.brain.erase("follow_offset")
		if chosen.is_finite():
			claimed.append(chosen)
			q.brain["follow_slot"] = chosen
			if not fallback:
				var rel: Vector3 = chosen - game.player.position
				q.brain["follow_offset"] = Vector2(rel.dot(right), rel.dot(fwd))
				q.brain["follow_slot_role"] = role
				q.brain["follow_slot_walking"] = walking
		else:
			q.brain.erase("follow_slot")
		if q == p:
			return chosen
	return Vector3.INF


## Decision 486: saved slots obey the same role, wall and body bounds as new slots.
func _follow_slot_free(p, spot: Vector3, claimed: Array[Vector3], role: String, near: float, far: float, fwd: Vector3, right: Vector3) -> bool:
	if not spot.is_finite() or not game.grid_at(spot).people_can_walk(FieldGrid.cell_of(spot)):
		return false
	var rel: Vector3 = spot - game.player.position
	if rel.length() < near - FOLLOW_EPS or rel.length() > far + FOLLOW_EPS:
		return false
	if game.player.moving:
		if role == "point" and (absf(rel.dot(right)) < FOLLOW_POINT_CLEAR - FOLLOW_EPS or rel.dot(fwd) <= 0.0):
			return false
		if role == "rear" and rel.dot(fwd) > -FOLLOW_REAR_BACK + FOLLOW_EPS:
			return false
	for other in game.squad:
		if other != p and other.is_alive() and spot.distance_to(other.position) <= FOLLOW_ROOM:
			return false
	for prior: Vector3 in claimed:
		if spot.distance_to(prior) <= FOLLOW_ROOM:
			return false
	return true


## Decision 486: inspect only the nearby wall pair across the direction of travel.
func _follow_narrow(fwd: Vector3) -> bool:
	var grid = game.grid_at(game.player.position)
	var cell := FieldGrid.cell_of(game.player.position)
	var side := Vector2i(0, 1) if absf(fwd.x) >= absf(fwd.z) else Vector2i(1, 0)
	var width := 1
	for sign_side in [-1, 1]:
		var wall := false
		for step in range(1, FOLLOW_NARROW_SCAN + 1):
			var c: Vector2i = cell + side * sign_side * step
			if not grid.inside(c):
				return false
			if not grid.people_can_walk(c):
				wall = true
				break
			width += 1
			if width > FOLLOW_NARROW_WIDTH:
				return false
		if not wall:
			return false
	return true


func _follow_clear(from: Vector3, to: Vector3) -> bool:
	if not to.is_finite() or game.level_of(from) != game.level_of(to):
		return false
	var grid = game.grid_at(from)
	var a := FieldGrid.cell_of(from)
	var b := FieldGrid.cell_of(to)
	return grid.people_can_walk(b) and grid.body_line_clear(a, b) and game.sight_clear(from, to) and grid.clear_walk(a, b, false)


## Decision 486: one common think owns the narrow decision and the queue order.
func _refresh_follow_queue() -> void:
	var narrow: bool = _follow_narrow(_follow_forward())
	if narrow:
		_follow_narrow_at = _follow_distance
	var door: bool = _follow_door_id > 0 and _follow_distance - _follow_door_at <= FOLLOW_DOOR_RECENT
	# Decision 486: standing releases a door queue, but not a narrow passage or its hold.
	var queue: bool = (door and _chief_still < LOOK_STILL_S) or narrow or _follow_distance - _follow_narrow_at < FOLLOW_NARROW_HOLD
	if _follow_queue_on and not queue:
		_follow_order.clear()
		for q in game.squad:
			q.brain.erase("follow_waiting")
			q.brain.erase("follow_lead_still")
			q.brain.erase("follow_gap_waiting")
	_follow_queue_on = queue
	if queue:
		_follow_queue_mates(_follow_mates())


func _follow_queueing(p, _spot: Vector3, _fwd: Vector3) -> bool:
	p.brain["follow_queue"] = _follow_queue_on
	return _follow_queue_on


## Decision 486: a predecessor can start work between the common think and this one's turn.
func _follow_leader(p):
	var order: int = _follow_order.find(p)
	if order < 0:
		# Decision 486: a new follower joins behind the nearest active body ahead.
		var own_back: float = float(_follow_projection(p.position)["back"])
		var nearest_back: float = -INF
		var nearest = game.player
		for q in _follow_mates():
			if q == p:
				continue
			var back: float = float(_follow_projection(q.position)["back"])
			if back < own_back and back > nearest_back:
				nearest_back = back
				nearest = q
		return nearest
	for i in range(order - 1, -1, -1):
		var leader = _follow_order[i]
		if _follow_active(leader):
			return leader
	return game.player


## Decision 486: compare distance along the trail, including bends, not a chord across them.
func _follow_projection(at: Vector3) -> Dictionary:
	var newer: Vector3 = game.player.position
	var walked := 0.0
	var best := INF
	var back := 0.0
	for i in range(_follow_count):
		var older := _follow_trail[(_follow_head - 1 - i + FOLLOW_TRAIL_CAP) % FOLLOW_TRAIL_CAP]
		var way := older - newer
		var length := way.length()
		if length > FOLLOW_EPS and game.level_of(at) == game.level_of(newer) and game.level_of(newer) == game.level_of(older):
			var share := clampf((at - newer).dot(way) / way.length_squared(), 0.0, 1.0)
			var distance := at.distance_squared_to(newer + way * share)
			if distance < best:
				best = distance
				back = walked + length * share
		walked += length
		newer = older
	if best == INF:
		var fwd := _follow_forward()
		back = (game.player.position - at).dot(fwd)
		best = at.distance_squared_to(game.player.position - fwd * back)
	return {"back": back, "away": sqrt(best)}


## Decision 486: keep queue order; a returning door guard joins where its body already is.
func _follow_queue_mates(mates: Array) -> Array:
	var eligible: Array = []
	for q in mates:
		if _role(q) != "rear" or not _holds_door(q):
			eligible.append(q)
	for q in _follow_order.duplicate():
		if not eligible.has(q):
			_follow_order.erase(q)
	for q in eligible:
		if _follow_order.has(q):
			continue
		var back: float = _follow_projection(q.position)["back"]
		var index := _follow_order.size()
		for i in range(_follow_order.size()):
			if back < float(_follow_projection(_follow_order[i].position)["back"]):
				index = i
				break
		_follow_order.insert(index, q)
	return _follow_order


## Decision 486: a body turning into a live path is still going.
func _follow_going(leader) -> bool:
	return leader.moving or not leader.path.is_empty() or (leader == game.player and leader.drive_speed > 0.0)


func _follow_wait(p, leader) -> bool:
	var here := _follow_projection(p.position)
	var gap: float = float(here["back"]) - float(_follow_projection(leader.position)["back"])
	var waiting: bool = p.brain.get("follow_waiting", false)
	var still: float = 0.0 if _follow_going(leader) else float(p.brain.get("follow_lead_still", 0.0)) + THINK
	p.brain["follow_lead_still"] = still
	if _follow_going(leader) or float(here["away"]) > FOLLOW_ROOM:
		waiting = false
	elif gap < FOLLOW_QUEUE_WAIT and still >= FOLLOW_LEADER_STILL:
		waiting = true
	elif gap > FOLLOW_QUEUE_RESUME:
		waiting = false
	p.brain["follow_waiting"] = waiting
	return waiting


func _follow_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	# Decision 486: A* drops its start cell; a short move within it still needs a path.
	if not to.is_finite():
		return PackedVector3Array()
	if _follow_clear(from, to):
		return PackedVector3Array([to])
	return game.find_path(from, to, false)


## Decision 486: join the recent trail behind the assigned gap, then follow it forward.
func _follow_queue_path(p, gap: float, fwd: Vector3) -> PackedVector3Array:
	var own_back: float = float(_follow_projection(p.position)["back"])
	if own_back < gap:
		return PackedVector3Array()
	if _follow_count == 0:
		return _follow_path(p.position, game.player.position - fwd * gap)
	var back: Array[Vector3] = [_follow_trail_at(gap)]
	var newer: Vector3 = game.player.position
	var walked: float = 0.0
	for i in range(_follow_count):
		var older: Vector3 = _follow_trail[(_follow_head - 1 - i + FOLLOW_TRAIL_CAP) % FOLLOW_TRAIL_CAP]
		walked += newer.distance_to(older)
		if walked >= own_back:
			var join_at: Vector3 = _follow_trail_at(own_back)
			if back[-1].distance_to(join_at) > 0.05:
				back.append(join_at)
			break
		if walked > gap and back[-1].distance_to(older) > 0.05:
			back.append(older)
		newer = older
	var join := 0
	for i in range(1, back.size()):
		if p.position.distance_squared_to(back[i]) < p.position.distance_squared_to(back[join]):
			join = i
	var route := _follow_path(p.position, back[join])
	if route.is_empty() or route[-1].distance_to(back[join]) > 0.12:
		return _follow_path(p.position, back[0])
	for i in range(join - 1, -1, -1):
		var anchor: Vector3 = p.position if route.size() == 1 else route[-2]
		if _follow_clear(anchor, back[i]):
			route[-1] = back[i]
		elif _follow_clear(route[-1], back[i]):
			route.append(back[i])
		else:
			# Decision 486: a changed door or wall gets one fresh route, not a search per crumb.
			return _follow_path(p.position, back[0])
	return route


## Decision 486: interpolate only along the chief's trail, including floor changes.
func _follow_trail_at(back: float) -> Vector3:
	var newer: Vector3 = game.player.position
	if _follow_count == 0:
		return newer - _follow_forward() * maxf(back, 0.0)
	var left: float = maxf(back, 0.0)
	for i in range(_follow_count):
		var older: Vector3 = _follow_trail[(_follow_head - 1 - i + FOLLOW_TRAIL_CAP) % FOLLOW_TRAIL_CAP]
		var length: float = newer.distance_to(older)
		if length >= left and length > 0.0001:
			return newer.lerp(older, left / length) if game.level_of(newer) == game.level_of(older) else older
		left -= length
		newer = older
	return newer


## Decision 486: clip the queue's path before the predecessor, including between thinks.
func _follow_leave_room(p, route: PackedVector3Array, leader) -> PackedVector3Array:
	if game.level_of(p.position) != game.level_of(leader.position):
		return route
	var out := PackedVector3Array()
	var from: Vector3 = p.position
	for to in route:
		var way := Vector3(to.x - from.x, 0, to.z - from.z)
		var length := way.length()
		if length > 0.0001:
			var rel: Vector3 = leader.position - from
			rel.y = 0.0
			var along := rel.dot(way / length)
			var side_sq := maxf(0.0, rel.length_squared() - along * along)
			if side_sq < FOLLOW_QUEUE_WAIT * FOLLOW_QUEUE_WAIT:
				var entry := along - sqrt(FOLLOW_QUEUE_WAIT * FOLLOW_QUEUE_WAIT - side_sq)
				if entry >= 0.0 and entry < length:
					if entry > 0.12:
						out.append(from.lerp(to, entry / length))
					return out
		out.append(to)
		from = to
	return out


func _follow_walk(p, route: PackedVector3Array, leader = null, fwd: Vector3 = Vector3.ZERO) -> void:
	# Decision 486: refresh before arrival and update pace even when the goal hardly changed.
	while not route.is_empty() and p.position.distance_to(route[0]) < 0.12:
		route.remove_at(0)
	if route.is_empty():
		p.brain.erase("follow_walk_t")
		p.stop()
		return
	var goal := route[-1]
	var gap: float = p.position.distance_to(goal)
	var run: bool = p.brain.get("follow_running", false)
	if gap > FOLLOW_RUN_ON:
		run = true
	elif gap < FOLLOW_RUN_OFF:
		run = false
	p.running = game.player.running or run
	if leader != null and _follow_going(leader) and gap < FOLLOW_RUN_OFF:
		var leader_speed: float = leader.speed(game.grid_at(leader.position).floor_at(FieldGrid.cell_of(leader.position)))
		# Decision 486: only walking pace can veto a nearby follower's run.
		var was_running: bool = p.running
		p.running = false
		var own_speed: float = p.speed(game.grid_at(p.position).floor_at(FieldGrid.cell_of(p.position)))
		p.running = was_running
		if own_speed >= leader_speed - FOLLOW_EPS:
			p.running = false
			run = false
	p.brain["follow_running"] = run
	if leader == null and game.player.moving and fwd != Vector3.ZERO:
		route = _follow_buffer(p, route, fwd)
	p.brain["dest"] = route[-1]
	p.brain["follow_walk_t"] = game.clock.elapsed
	p.go_to(route, p.running)


## Decision 486: two thinks of slack, after choosing the actual pace; formation only.
func _follow_buffer(p, route: PackedVector3Array, fwd: Vector3) -> PackedVector3Array:
	if route.is_empty():
		return route
	var speed: float = p.speed(game.grid_at(p.position).floor_at(FieldGrid.cell_of(p.position)))
	var buffer: float = speed * FOLLOW_BUFFER_S + FOLLOW_PATH_NEAR
	var remaining: float = _follow_remaining(p.position, route)
	if remaining < buffer:
		var extra: Vector3 = route[-1] + fwd * (buffer - remaining)
		if _follow_clear(route[-1], extra):
			route.append(extra)
	return route


func _follow_remaining(at: Vector3, route: PackedVector3Array) -> float:
	var distance: float = 0.0
	for next: Vector3 in route:
		distance += at.distance_to(next)
		at = next
	return distance


func _clear_follow_latches(p) -> void:
	for key: String in ["follow_running", "follow_waiting", "follow_queue", "follow_lead_still", "follow_settled", "follow_walk_t", "follow_gap_waiting"]:
		p.brain.erase(key)


## Decision 486: release only our own watch, preserving a combat hold that replaced it.
func _follow_release_watch(p) -> void:
	if p.brain.has("follow_watch") and p.brain.get("face_hold") == p.brain["follow_watch"] and p.brain.get("face_hold_t") == p.brain.get("follow_watch_t"):
		p.brain.erase("face_hold")
		p.brain.erase("face_hold_t")
	p.brain.erase("follow_watch")
	p.brain.erase("follow_watch_t")


## Decision 486: renew a short shuffle's watch for the full hold, without a think-boundary gap.
func _follow_watch(p, look: Vector3) -> void:
	if p.path.is_empty() or _follow_remaining(p.position, p.path) > FOLLOW_SHUFFLE:
		return
	if p.brain.get("face_hold") is Vector3 and game.clock.elapsed - float(p.brain.get("face_hold_t", -INF)) < MoveRules.FACE_HOLD:
		return
	var watch: Vector3 = p.position + look * 20.0   # Decision 486: keep a shuffle's watch far away.
	p.brain["face_hold"] = watch
	p.brain["face_hold_t"] = game.clock.elapsed
	p.brain["follow_watch"] = watch
	p.brain["follow_watch_t"] = game.clock.elapsed
	p.face_point(watch)


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
	var look := base.rotated(Vector3.UP, sweep)
	# Decision 486: keep the slow sweep, but turn its result to the nearest camera-cone edge.
	if game.camera != null:
		var camera_way: Vector3 = game.camera.global_transform.basis.z
		camera_way.y = 0.0
		if camera_way.length_squared() > 0.0001:
			camera_way = camera_way.normalized()
			var offset := angle_difference(atan2(camera_way.x, camera_way.z), atan2(look.x, look.z))
			var limit: float = deg_to_rad(LOOK_CAMERA_DEG + 5.0)
			if absf(offset) < limit:
				look = camera_way.rotated(Vector3.UP, limit * (-1.0 if offset < 0.0 else 1.0))
	return look


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


## The chief stands by to search: one companion at a time takes the other
## things near him, one after another; the rest keep by him (the rear one
## keeps watch). Not while he walks, never a locked box.
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
		# One of us already at it: the rest stay by the chief.
		for o in game.squad:
			if o != p and o.is_alive() and o.brain.has("help_c"):
				return false
		var skip2: Dictionary = p.brain.get("help_skip", {})
		for e in _help_near():
			if not skip2.has(e[0]):
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
		# A box that shows it is empty is not worth the stop (card P3, decision 472).
		if c["searched"] or c["locked"] or c.get("busy", false) or c.has("pick") or int(c.get("level", 0)) != lv or SearchRules.shows_empty(c):
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
		if g2["id"] == "ammo_craft":
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
		if c["searched"] or c["locked"] or c.get("busy", false) or SearchRules.shows_empty(c):
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


## The door to climb in by: the nearest, each of the dead standing by one
## counting as DOOR_CROWD_M more to go, and the one taken kept unless another
## comes DOOR_KEEP_M nearer (no turning back and forth between two).
func _board_door(p) -> Vector3:
	var kept: Vector3 = p.brain.get("board_door", Vector3.INF)
	var best: Vector3 = kept
	var best_cost: float = INF
	var kept_cost: float = INF
	for c in game.data["spawns"]["train_door"]:
		var at := FieldGrid.center(c)
		var cost: float = p.position.distance_to(at)
		for z in game.zombies.in_radius(at, DOOR_CROWD_R):
			if z["state"] not in ["dead", "rising", "downed", "frozen"]:
				cost += DOOR_CROWD_M
		if at.is_equal_approx(kept):
			kept_cost = cost
		if cost < best_cost:
			best_cost = cost
			best = at
	if kept_cost < INF and kept_cost - best_cost < DOOR_KEEP_M:
		best = kept
	p.brain["board_door"] = best
	return best


## Climbed in: inside, out of sight and out of the reach of the dead, as the
## work crew goes in (_crew); the door is kept to come out by. An order given
## meanwhile to do something else leaves it outside.
func _boarded(p, door: Vector3) -> void:
	p.brain.erase("boarding")
	if p.command != "retreat" or not p.is_alive():
		return
	p.brain["boarded"] = true
	p.brain["board_at"] = door
	p.stop()
	p.position = door + Vector3(0, -50, 0)


# ---------------------------------------------------------------- work crew

func _crew(p, _delta: float, think: bool) -> void:
	if game.work.crew_step(p, think):
		return
	if p.role == "escort" and think:
		_escort(p)


## Existing wagon tasks use the same coal amount and hauling multipliers.
func _dug(p) -> void:
	var wagon: Dictionary = _wagon_with_coal()
	if wagon.is_empty():
		return
	var take: float = minf(TRIP_COAL * game.mission_play.load_mult() * game.haul_mult(), float(wagon["coal"]))
	wagon["coal"] = float(wagon["coal"]) - take
	p.brain["load"] = take
	p.brain["load_kind"] = "coal"
	p.brain["job"] = "carry"


func _wagon_with_coal() -> Dictionary:
	for w in game.data["wagons"]:
		if w.has("work") and float(w["coal"]) > 0.001:
			return w
	return {}


## Escorts guard the carriers. Attitude says how far they go out; fire
## permission says whether they may shoot (s2_station 2.4).
func _escort(p, falling_back: bool = false) -> void:
	if _hold_swing(p):
		return
	var site: Vector3 = p.position if falling_back else game.work.position_of(String(p.brain.get("work_site", "work_site")))
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
		if falling_back:
			post = game.work.door_of(String(p.brain.get("work_site", "work_site")))
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
	if dist <= game.combat.melee_range(p) and not game.combat.melee_blocked(p, threat["pos"]):
		p.stop()
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
	if _hold_swing(r):
		return
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
				r.stop()
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
