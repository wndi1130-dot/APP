extends RefCounted
## Fights in the field: melee swings, aimed shots, shoves, grabs, bites and
## falls (field_unified 10, body_injury 2·3·4.2, weapons.md, zombies.md).
## Everything here reads and writes the field_game node.

const FieldGrid = preload("res://game/world/field_grid.gd")
const W = preload("res://game/sim/weapons.gd")
const WR = preload("res://game/sim/weapon_rules.gd")
const AimModel = preload("res://game/sim/aim_model.gd")
const GrabRules = preload("res://game/sim/grab_rules.gd")
const Wear = preload("res://game/sim/wear.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const Carry = preload("res://game/sim/carry.gd")
const BodyState = preload("res://game/sim/body_state.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const Pose = preload("res://game/actors/person_pose.gd")
const Motion = preload("res://game/sim/motion.gd")

const SHOVE_REACH: float = 1.3
const SHOVE_COS: float = 0.3
const SHOVE_KNOCK: float = 0.35
## Lockout between shoves: a press that comes out about a third of a second
## after the last one (user, build 47: 0.5 felt late). Still one per swing time.
const SHOVE_TIME: float = 0.35
const SHOVE_WINDUP: float = 0.15     # the arms come back first; then the shove lands (build 89: it was instant)
const SHOVE_LUNGE: float = 0.15
## What stops a melee blow while it is drawn back (opts["melee_break"], to be
## shown on the phone): "grab" a grab on the one swinging stops it (as with the
## shove), "none" nothing does. The time is spent either way.
const WINDUP_BREAKS: Array[String] = ["grab", "none"]
const WHIFF_RECOVER: float = 0.2        # the least a missed or stopped blow still costs
## One lying there and no melee weapon in the hand: the boot comes down (user
## 2026-10-11). Slow on purpose, so a weapon stays worth carrying: it lands
## later than the heaviest weapon and takes several to end it, where a weapon
## ends a fallen one in one blow. First values, to be set on the phone.
const STOMP_WINDUP: float = 0.45
const STOMP_TIME: float = 1.0           # one whole stomp, the lift included
const STOMPS_TO_END: int = 3
const STOMP_REACH: float = 0.9
const STOMP_FATIGUE: float = 0.004
const CLOSE: float = 1.8
const JAM_CLEAR: float = 2.5
const FALL_TIME: float = 1.5
const BEHIND_COS: float = -0.3
const MELEE_SLACK: float = 0.15          # a blow lands this far past the weapon's reach
const RAIDER_AMMO: int = 6
## A companion breathes after a blow that landed, and again when it picks the
## next one out of the crowd (user 2026-10-12: they cut everything down in a blink).
const ALLY_REST_MIN: float = 0.35
const ALLY_REST_MAX: float = 0.55
const ALLY_SWITCH_MIN: float = 0.5
const ALLY_SWITCH_MAX: float = 0.8
## How far a companion must have turned toward the target before it swings.
const ALLY_TURN_DEG: float = 35.0
## One body does one thing at a time (decision 420). A blow or a shove breaks
## off these works of the hands (the ones the stick breaks off, and rummaging a
## body); any other (a climb, a crossing, a door or a window, a weapon swap)
## runs to its end and no blow or shove starts meanwhile.
const BLOW_BREAKS: Array = ["search", "salvage", "pry", "kick", "glass", "lid", "snow", "fire", "craft", "rub", "splint", "treat", "eat", "wear", "loot", "take"]

var game
## The player's shove pressed during a blow: it goes once the blow is over
## (decision 420). Short-lived, never saved.
var shove_after: Dictionary = {}
## Melee blows under way, by person: when each began (the game clock) and its
## motion row, for the feet it holds (decision 425: feet_held).
var blows: Dictionary = {}
var tracers: Array = []                 # {"from", "to", "t"} for the view
var kills: int = 0
# Picks where a wound lands. A stream of its own, so the fight rolls in game.rng stay as they were.
var _wound_rng := RandomNumberGenerator.new()
var _wound_seeded: bool = false
# Companion pauses. A stream of its own with a fixed seed, so game.rng rolls stay as they were.
var _pace_rng := RandomNumberGenerator.new()
# Which arrows break. A stream of its own too, seeded from the game on first use.
var _gear_rng := RandomNumberGenerator.new()
var _gear_seeded: bool = false


func _is_ally(p) -> bool:
	return p.team == "squad" and p != game.player


func _pace(lo: float, hi: float) -> float:
	return _pace_rng.randf_range(lo, hi)


func _init(field_game) -> void:
	game = field_game
	_pace_rng.seed = 0x7ace


## Seeds the wound stream on first use, from the game seed.
func wound_rng() -> RandomNumberGenerator:
	if not _wound_seeded:
		_wound_seeded = true
		_wound_rng.seed = int(game.rng.seed) ^ 0x5eed
	return _wound_rng


func gear_rng() -> RandomNumberGenerator:
	if not _gear_seeded:
		_gear_seeded = true
		_gear_rng.seed = int(game.rng.seed) ^ 0x9ea2
	return _gear_rng


## A part of the group ("arm" or "leg") with a random side, for wounds from other scripts.
func wound_side(group: String) -> String:
	return BodyState.pick_side(wound_rng(), group)


func update(delta: float) -> void:
	for p in game.people_alive():
		var m: Dictionary = p.mults()
		p.swing_t = maxf(0.0, p.swing_t - delta)
		p.lunge_t = maxf(0.0, p.lunge_t - delta)
		if p.shove_t > 0.0:
			p.shove_t -= delta
			if p.shove_t <= 0.0:
				p.shove_t = 0.0
				if p.can_act() and p.grabbers.is_empty():
					p.swing_t = 0.0
					p.lunge_t = SHOVE_LUNGE
					shove(p)
		if p.strike_t > 0.0:
			p.strike_t -= delta
			if p.strike_t <= 0.0:
				_land_strike(p)
		if shove_after.has(p.get_instance_id()):
			if not p.can_act():
				shove_after.erase(p.get_instance_id())
			elif not striking(p):
				shove_after.erase(p.get_instance_id())
				start_shove(p)
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
		# A person who gave up, was taken or ran is no longer someone to hit,
		# whoever held the order (player hand, companion, a stale tap).
		if p.target_person != null and not hostile(p.target_person):
			p.target_person = null
			if p.target_zombie.is_empty():
				p.hold_attack = false
		if not p.can_act():
			continue
		if not p.target_zombie.is_empty():
			_pursue_zombie(p, delta)
		elif p.target_person != null:
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


## Orders from the player's hand. The HUD calls these and does not write the
## fight state (targets, hold, goal, path) itself.

## In a one-press fight: still after someone, swinging on.
func fighting(p) -> bool:
	return p.hold_attack and (not p.target_zombie.is_empty() or p.target_person != null)


## Go for an enemy; hold keeps swinging.
func fight(p, target, hold: bool) -> void:
	# A raider who surrendered, ran or was taken is not a target (a tap that
	# lands a moment late, a finger still down on him).
	if target == null or (not (target is Dictionary) and not hostile(target)):
		return
	p.brain.erase("goal")
	if target is Dictionary:
		melee_target(p, target, hold)
	else:
		melee_person(p, target)
		p.hold_attack = hold


## The finger holding the swing is gone: finish this swing, then stop.
func stop_holding(p) -> void:
	p.hold_attack = false


## Call the fight off where you stand (a tap on open ground).
func call_off(p) -> void:
	p.target_zombie = {}
	p.target_person = null
	p.hold_attack = false
	p.brain.erase("goal")


## Call the fight off and stop walking at the enemy too.
func stop_fight(p) -> void:
	call_off(p)
	p.path = PackedVector3Array()


## The stick takes over: whoever you were walking at is dropped.
func drop_melee(p) -> void:
	p.target_zombie = {}
	p.target_person = null


## The gun comes up: no walking at a zombie or to a goal meanwhile.
func drop_target(p) -> void:
	p.target_zombie = {}
	p.brain.erase("goal")


## Someone still worth hitting: a raider who gave up, ran, was taken or left is
## not (a disarmed raider sent off runs south and is let go, build 47).
func hostile(o) -> bool:
	return o.is_alive() and not (o.brain.get("state", "") in ["surrender", "flee", "prisoner", "gone"])


## How far from the body a blow can land (guns and bare hands: arm's length).
func melee_range(p) -> float:
	var wid: String = p.weapon_id()
	var reach: float = float(W.get_data(wid).get("reach", 0.9)) if not W.is_ranged(wid) else 0.9
	return reach + MELEE_SLACK


## A wall, shut door or whole window (or another floor) between p and the spot.
func melee_blocked(p, at: Vector3) -> bool:
	if game.level_of(p.position) != game.level_of(at):
		return true
	return not game.grid_at(p.position).body_line_clear(FieldGrid.cell_of(p.position), FieldGrid.cell_of(at))


func _pursue_zombie(p, delta: float) -> void:
	var z: Dictionary = p.target_zombie
	if z.is_empty() or z["state"] == "dead":
		p.target_zombie = {}
		# One tap fights on: the next dead hand already at you is the next target (user, build 20).
		# An emptied target is an order to stop, not a kill: no chaining then.
		# The player's chaining is a start-screen choice (morning card; on by default).
		var chain: bool = p != game.player or bool(game.opts.get("melee_chain", true))
		if p.hold_attack and not z.is_empty() and chain:
			var next := _next_close_zombie(p)
			if next.is_empty():
				p.hold_attack = false
			else:
				p.target_zombie = next
				if _is_ally(p):
					p.swing_t = maxf(p.swing_t, _pace(ALLY_SWITCH_MIN, ALLY_SWITCH_MAX))
		else:
			p.hold_attack = false
		return
	var wid: String = p.weapon_id()
	var reach: float = float(W.get_data(wid).get("reach", 0.9)) if not W.is_ranged(wid) else 0.9
	var d: float = p.position.distance_to(z["pos"])
	# Shut off by a wall or a whole window: no swing, walk round instead.
	if d > reach + MELEE_SLACK or melee_blocked(p, z["pos"]):
		p.brain["repath_t"] = float(p.brain.get("repath_t", 0.0)) - delta
		if p.brain["repath_t"] <= 0.0 or p.path.is_empty():
			p.brain["repath_t"] = 0.4
			var path: PackedVector3Array = game.find_path(p.position, z["pos"], false)
			if path.size() > 0:
				path[path.size() - 1] = z["pos"] + (p.position - z["pos"]).normalized() * (reach * 0.8)
			p.go_to(path, p.running)
		return
	p.stop()
	p.face_point(z["pos"])
	# A body turns at a pace; swing only once it faces the target.
	if p != game.player and not p.turned_to(deg_to_rad(ALLY_TURN_DEG)):
		return
	if p.swing_t > 0.0:
		return
	if W.is_ranged(wid) and not stomps(p, z):
		shove(p)
	else:
		start_swing(p, z)
	if not p.hold_attack:
		p.target_zombie = {}


const CHAIN_R := 2.0
## User decision 330: with one of the dead this near, a tap on a thing no longer
## walks over to do it (only the stick and the pads). Draft value, to be set by hand play.
const TAP_ASSIST_OFF_R := 4.0


## The tap helper is off: one of the dead on its feet (or getting up), seen,
## on this floor and within TAP_ASSIST_OFF_R (decision 330).
func tap_assist_off(p) -> bool:
	var lv: int = game.level_of(p.position)
	for z in game.zombies.list:
		if String(z["state"]) in ["dead", "frozen", "downed"]:
			continue
		if game.level_of(z["pos"]) != lv or not game.cell_seen(z["pos"]):
			continue
		if p.position.distance_to(z["pos"]) <= TAP_ASSIST_OFF_R:
			return true
	return false


func _next_close_zombie(p) -> Dictionary:
	var best: Dictionary = {}
	var best_d := CHAIN_R
	for z in game.zombies.list:
		if z["state"] in ["dead", "frozen", "wander"] or not game.cell_seen(z["pos"]):
			continue
		var d: float = p.position.distance_to(z["pos"])
		if d < best_d:
			best_d = d
			best = z
	return best


## The attack pad's target (field_unified 10): the nearest enemy within arm's
## reach ahead, or anything already at you; a downed one nearest is finished.
func melee_pick(p):
	var wid: String = p.weapon_id()
	var reach: float = float(W.get_data(wid).get("reach", 0.9)) if not W.is_ranged(wid) else 0.9
	var fwd := Vector3(sin(p.facing), 0, cos(p.facing))
	var best = null
	var best_d := INF
	for z in game.zombies.list:
		if not game.zombies.threat(z) or not game.cell_seen(z["pos"]):
			continue
		var d: float = p.position.distance_to(z["pos"])
		var to: Vector3 = z["pos"] - p.position
		to.y = 0
		var ahead := to.length() < 0.01 or fwd.dot(to.normalized()) >= 0.2
		if (ahead and d <= reach + 0.8) or d <= 1.2:
			if d < best_d:
				best_d = d
				best = z
	for r in game.raiders:
		if hostile(r) and r.visible:
			var d: float = p.position.distance_to(r.position)
			if d <= reach + 0.8 and d < best_d:
				best_d = d
				best = r
	return best


## Seconds before the auto aim settles on a target: shooting skill (0-10)
## shortens it (field_unified 10; numbers are S2 starting values).
func acquire_time(p) -> float:
	return clampf(0.7 - 0.05 * int(p.skills.get("shooting", 0)), 0.15, 0.7)


## Auto aim candidates, best first: seen threats in range, those ahead before
## those behind, nearest first; from shooting 7 the dangerous ones (fresh, or
## already coming at us) jump the queue. Never a friend or a frightened survivor.
## A sharp shooter (shooting 7+) is shown which ones are the danger (runners,
## the ones already coming); the aim still takes the nearest and the player
## slides to another (field_unified 10, A3: the game must not swap it for you).
func marks_danger(p, z: Dictionary) -> bool:
	return int(p.skills.get("shooting", 0)) >= 7 and z["state"] != "dead" and (z["kind"] == "fresh" or z["state"] in ["chase", "attack", "grab"])


func aim_candidates(p) -> Array:
	var wid: String = p.weapon_id()
	var reach: float = float(W.get_data(wid).get("range", 20.0))
	var fwd := Vector3(sin(p.facing), 0, cos(p.facing))
	var rows: Array = []
	for z in game.zombies.list:
		if z["state"] == "dead" or not game.cell_seen(z["pos"]):
			continue
		var d: float = p.position.distance_to(z["pos"])
		if d > reach:
			continue
		var to: Vector3 = z["pos"] - p.position
		to.y = 0
		var score := d
		if to.length() > 0.01 and fwd.dot(to.normalized()) < 0.3:
			score += 8.0
		if z["state"] == "frozen" or z["state"] == "rising":
			score += 6.0
		rows.append([score, z])
	for r in game.raiders:
		if hostile(r) and r.visible:
			var d: float = p.position.distance_to(r.position)
			if d <= reach:
				rows.append([d - 2.0, r])
	rows.sort_custom(func(a, b): return a[0] < b[0])
	return rows.map(func(row): return row[1])


func _pursue_person(p, delta: float) -> void:
	var o = p.target_person
	if o == null or not hostile(o) or o.body.downed:
		p.target_person = null
		if p.target_zombie.is_empty():
			p.hold_attack = false
		return
	var wid: String = p.weapon_id()
	var reach: float = float(W.get_data(wid).get("reach", 0.9)) if not W.is_ranged(wid) else 0.9
	var d: float = p.position.distance_to(o.position)
	var shut: bool = d <= reach + MELEE_SLACK and melee_blocked(p, o.position)
	# A raider's walking is the AI's: out of reach or shut off, it lets the target go.
	if p.team == "raider" and (d > reach + MELEE_SLACK or shut):
		p.target_person = null
		return
	if d > reach + MELEE_SLACK or shut:
		p.brain["repath_t"] = float(p.brain.get("repath_t", 0.0)) - delta
		if p.brain["repath_t"] <= 0.0 or p.path.is_empty():
			p.brain["repath_t"] = 0.4
			p.go_to(game.find_path(p.position, o.position, false), p.running)
		return
	p.stop()
	p.face_point(o.position)
	if p.swing_t <= 0.0:
		start_swing(p, o)


static func behind(z: Dictionary, attacker_pos: Vector3) -> bool:
	var forward := Vector3(sin(z["angle"]), 0, cos(z["angle"]))
	var to_a: Vector3 = attacker_pos - z["pos"]
	to_a.y = 0
	if to_a.length() < 0.01:
		return false
	return forward.dot(to_a.normalized()) < BEHIND_COS


## A melee blow starts: the weapon is drawn back for its weight's time, then
## it lands (swing, swing_person). `at` is a zombie's Dictionary or a person.
## With no melee weapon in the hand it is the old shove, at once.
func start_swing(p, at) -> void:
	if p.swing_t > 0.0 or p.strike_t > 0.0 or not _hands_free_for_blow(p):
		return
	# Running, the blow goes out as a shove (decision 425, as in the reference
	# game: no swing at a run). Stopped, it is a swing again.
	if p.is_running_now():
		_shove_now(p)
		return
	var stomp_it: bool = stomps(p, at)
	p.strike_kind = "stomp" if stomp_it else "swing"
	var windup: float = (STOMP_WINDUP if stomp_it else W.melee_windup(p.weapon_id())) / float(p.mults()["swing"])
	if windup <= 0.0:
		_strike(p, at)
		return
	p.strike_at = at
	p.strike_t = windup
	p.strike_total = windup
	p.swing_t = windup
	if not stomp_it:
		blows[p.get_instance_id()] = {"at": game.clock.elapsed, "row": Motion.swing_row(p.weapon_id()), "mult": float(p.mults()["swing"])}


## True while a melee blow holds the feet (decision 425): from its weapon's
## feet_from of the swing to its end (Motion.swing_row), the body does not walk
## off under the stick. Shoves and stomps do not hold them.
func feet_held(p) -> bool:
	var id: int = p.get_instance_id()
	if not blows.has(id):
		return false
	if p.strike_t <= 0.0 and p.swing_t <= 0.0:
		blows.erase(id)
		return false
	var blow: Dictionary = blows[id]
	var row: Dictionary = blow["row"]
	if row.is_empty():
		return false
	var gone: float = (game.clock.elapsed - float(blow["at"])) * float(blow["mult"])
	var feet: Vector2 = row["feet"]
	return gone >= feet.x and gone < feet.y

## The attack pad with nobody in reach (decision 405, as in the reference game): the
## weapon comes round all the same and lands on whatever is in its arc by then
## (an empty Dictionary as strike_at). No melee weapon in the hand: the shove.
func swing_air(p) -> void:
	if game.paused or not p.can_act():
		return
	if W.get_data(p.weapon_id()).get("kind", "") != "melee":
		start_shove(p)
		return
	start_swing(p, {})


## Who an air swing lands on: the nearest dead (not yet dead) or hostile person
## in reach, in the attack pad's arc ahead (melee_pick), not behind a wall.
func _in_arc(p):
	var reach: float = melee_range(p)
	var fwd := Vector3(sin(p.facing), 0, cos(p.facing))
	var best = null
	var best_d := INF
	var rows: Array = []
	for z in game.zombies.list:
		if String(z["state"]) != "dead":
			rows.append([z, z["pos"]])
	for r in game.raiders:
		if hostile(r):
			rows.append([r, r.position])
	for row in rows:
		var pos: Vector3 = row[1]
		var to: Vector3 = pos - p.position
		to.y = 0
		var d: float = to.length()
		if d > reach or d >= best_d:
			continue
		if d > 0.01 and fwd.dot(to.normalized()) < 0.2:
			continue
		if melee_blocked(p, pos):
			continue
		best_d = d
		best = row[0]
	return best


## An air swing that met no one: the weapon still tires the arm and swishes,
## or meets the shut door or whole window it was swung at.
func _swing_empty(p) -> void:
	var wid: String = p.weapon_id()
	var d: Dictionary = W.get_data(wid)
	var m: Dictionary = p.mults()
	p.swing_t = float(d["swing"]) / float(m["swing"])
	p.body.add_fatigue(float(d["fatigue"]) * BodyState.fatigue_mult({"carry_state": p.carry_state(), "cold_level": p.cold_level()}))
	var lg = game.grid_at(p.position)
	var fwd := Vector3(sin(p.facing), 0, cos(p.facing))
	var reach: float = melee_range(p)
	var step := 0.3
	# Doors and windows are struck on the ground floor only, as _break_window does.
	while step <= reach and lg == game.grid:
		var c: Vector2i = FieldGrid.cell_of(p.position + fwd * step)
		step += 0.3
		if lg.windows.has(c) and not bool(lg.windows[c]["broken"]):
			_wear(p, WR.melee_wear(wid, String(p.weapon()["quality"]), int(p.skills["melee"])))
			game.actions._break_window(p, c)
			return
		if lg.doors.has(c) and String(lg.doors[c]["state"]) in ["closed", "locked"]:
			_wear(p, WR.melee_wear(wid, String(p.weapon()["quality"]), int(p.skills["melee"])))
			game.make_sound(FieldGrid.center(c), SimNoise.Level.NORMAL, "melee", p)
			return
	game.make_sound(p.position, SimNoise.Level.QUIET, "melee", p)


## No melee weapon in the hand (bare, or a gun) and the one aimed at lies there.
func stomps(p, at) -> bool:
	if not (at is Dictionary) or at.is_empty() or String(at["state"]) != "downed":
		return false
	return W.get_data(p.weapon_id()).get("kind", "") != "melee"


## One stomp lands on a fallen one. It takes STOMPS_TO_END of them; what it
## has taken stays with it if it gets up meanwhile.
func stomp(p, z: Dictionary) -> void:
	p.swing_t = STOMP_TIME / float(p.mults()["swing"])
	p.body.add_fatigue(STOMP_FATIGUE)
	game.make_sound(z["pos"], SimNoise.Level.QUIET, "melee", p)
	z["stomped"] = int(z.get("stomped", 0)) + 1
	if int(z["stomped"]) >= STOMPS_TO_END:
		_kill(p, z, "")


func _stomp_reaches(p, z: Dictionary) -> bool:
	if not game.zombies.list.has(z) or String(z["state"]) != "downed":
		return false
	return p.position.distance_to(z["pos"]) <= STOMP_REACH + MELEE_SLACK + 0.3 and not melee_blocked(p, z["pos"])


func _strike(p, at) -> void:
	if at is Dictionary and at.is_empty():
		at = _in_arc(p)
		if at == null:
			_swing_empty(p)
			return
	if at is Dictionary:
		swing(p, at)
	else:
		swing_person(p, at)


## The draw-back is over: the blow lands if the one swinging still can and
## the target is still there to be hit; otherwise it is a miss that cost time.
func _land_strike(p) -> void:
	var at = p.strike_at
	var windup: float = p.strike_total
	p.strike_t = 0.0
	p.strike_total = 0.0
	p.strike_at = null
	p.swing_t = 0.0
	var stopped: bool = p.body.dead or p.body.downed or p.fallen_t > 0.0
	if String(game.opts.get("melee_break", "grab")) == "grab" and not p.grabbers.is_empty():
		stopped = true
	var stomp_it: bool = p.strike_kind == "stomp"
	# An air swing (strike_at {}) finds what it lands on as it lands (_strike).
	var air: bool = at is Dictionary and at.is_empty()
	if stopped or not (air or (_stomp_reaches(p, at) if stomp_it else _strike_reaches(p, at))):
		p.swing_t = WHIFF_RECOVER
		return
	if stomp_it:
		stomp(p, at)
	else:
		_strike(p, at)
	# The draw-back was the front of the swing time, not extra.
	p.swing_t = maxf(p.swing_t - windup, WHIFF_RECOVER)
	if _is_ally(p):
		p.swing_t += _pace(ALLY_REST_MIN, ALLY_REST_MAX)


func _strike_reaches(p, at) -> bool:
	var d: Dictionary = W.get_data(p.weapon_id())
	if d.is_empty() or d.get("kind", "") != "melee":
		return false
	var reach: float = float(d.get("reach", 0.9)) + MELEE_SLACK
	var pos: Vector3
	if at is Dictionary:
		if not game.zombies.list.has(at) or String(at["state"]) == "dead":
			return false
		pos = at["pos"]
	else:
		if at == null or not is_instance_valid(at) or not at.is_alive():
			return false
		pos = at.position
	# It may have stepped back a little while the weapon came round.
	return p.position.distance_to(pos) <= reach + 0.3 and not melee_blocked(p, pos)


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
	_wear(p, WR.melee_wear(wid, String(p.weapon()["quality"]), int(p.skills["melee"])))
	# Read before the blow's own sound: a quiet sound turns the body toward it
	# (zombies.hear), and this one comes from where the body stands.
	var from_back := behind(z, p.position)
	# Seen struck (dead_body.gd picks which way it is thrown by these; nothing reads them here).
	z["hit_at"] = z["age"]
	z["hit_by"] = p.position
	z["hit_way"] = String(p.get_meta(Pose.BLOW_WAY, ""))
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
	# Quiet kill from behind: knife, crouched, the thing has not noticed anyone.
	if wid == "knife" and p.crouched and from_back and state != "chase" and state != "attack" and state != "grab":
		_kill(p, z, "뒤에서 조용히 끝냈다")
		return
	var downed: bool = state == "downed"
	# The state of the hand and its strength against the weapon's weight (decisions '근접 타수').
	var odds: Dictionary = W.melee_odds(wid, int(p.skills["melee"]), downed, from_back, float(m.get("melee_hit", 1.0)), int(p.skills.get("strength", 5)))
	var head: float = odds["head"]
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
	if rng.randf() < float(odds["knockdown"]):
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
		o.body.apply_cut(wid == "axe" or rng.randf() < 0.3, game.clock.elapsed, BodyState.pick_part(wound_rng()))
		o.last_hurt_by = p.pid
		game.telemetry.injury(game.clock.elapsed, o.pid, "cut")
		if o.team == "raider":
			game.ai.raider_hit(o, p)
		elif o == game.player or o.team == "squad":
			game.say(o, "%s 베였다." % o.display_name, true, "hurt")


func _kill(p, z: Dictionary, msg: String) -> void:
	game.zombies.kill(z)
	kills += 1
	if p != null and p.team != "raider":
		if msg != "":
			_toast(p, msg)
		if p.note_close_kill(game.clock.elapsed):
			_toast(p, "%s 옷이 피로 젖었다. 눈으로 문지르면 지워진다." % p.display_name)


## Shove: a short cone in front, breaks a grab, sometimes knocks down.
## The player's shove key: the arms come back for a moment, then it lands.
## Companions shove on reflex (shove itself).
## The shove key ends a one-press fight (decision 420: one press, one thing);
## pressed mid-blow it goes once the blow is over.
func start_shove(p) -> void:
	if game.paused:
		return
	if p == game.player and fighting(p):
		call_off(p)
	if striking(p):
		if p == game.player:
			shove_after[p.get_instance_id()] = true
		return
	_shove_now(p)


## The shove itself, drawn back first (start_shove; a blow at a run).
func _shove_now(p) -> void:
	if striking(p) or not _hands_free_for_blow(p):
		return
	blows.erase(p.get_instance_id())
	p.shove_t = SHOVE_WINDUP / float(p.mults()["swing"])
	p.swing_t = p.shove_t


## In a blow or a shove: drawn back, landing, or coming back from it.
func striking(p) -> bool:
	return p.swing_t > 0.0 or p.strike_t > 0.0 or p.shove_t > 0.0


## Free to start a blow or a shove (decision 420): a work it breaks off is let
## go now; any other work of the hands runs to its end first.
func _hands_free_for_blow(p) -> bool:
	if p.action == "" or p.action == "aim":
		return true
	if BLOW_BREAKS.has(p.action):
		p.cancel_action()
		return true
	return false


func shove(p) -> void:
	# One shove per swing time: mashing the button must not stack stuns.
	if p.swing_t > 0.0 or game.paused or not _hands_free_for_blow(p):
		return
	var rng: RandomNumberGenerator = game.rng
	var m: Dictionary = p.mults()
	p.swing_t = SHOVE_TIME / float(m["swing"])
	p.body.add_fatigue(0.003)
	var forward := Vector3(sin(p.facing), 0, cos(p.facing))
	var hit := 0
	for z in game.zombies.in_radius(p.position, SHOVE_REACH):
		if z["state"] == "frozen" or z["state"] == "rising":
			continue
		# Getting up off the ground it can be shoved again (decision 425); lying it cannot.
		if z["state"] == "downed" and not game.zombies.getting_up(z):
			continue
		var to_z: Vector3 = z["pos"] - p.position
		to_z.y = 0
		var grabbing: bool = p.grabbers.has(z)
		if not grabbing and to_z.length() > 0.2 and forward.dot(to_z.normalized()) < SHOVE_COS:
			continue
		# Walls, shut doors and whole glass stop a shove too (a grabber is on you, so it counts).
		if not grabbing and melee_blocked(p, z["pos"]):
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
	p.lunge_t = SHOVE_LUNGE      # the arms seen thrown out as it breaks free
	# A blow drawn back as it was grabbed is lost when it breaks free, as the
	# grab rule says (decision 420); with "none" it still lands.
	if String(game.opts.get("melee_break", "grab")) == "grab" and p.strike_t > 0.0:
		p.strike_t = 0.0
		p.strike_total = 0.0
		p.strike_at = null
	return true


func _push(z: Dictionary, from: Vector3, dist: float) -> void:
	var away: Vector3 = z["pos"] - from
	away.y = 0
	if away.length() < 0.01:
		return
	var dest: Vector3 = z["pos"] + away.normalized() * dist
	if not game.grid_at(dest).blocks_body(FieldGrid.cell_of(dest)):
		z["pos"] = dest


func _wear(p, amount: float) -> void:
	if p.hands.is_empty():
		return
	var h: Dictionary = p.hands[0]
	var id: String = String(h["id"])
	var before: float = float(h["condition"])
	h["condition"] = WR.worn(id, before, amount)
	var label: String = String(W.get_data(id).get("name", ""))
	# An improvised one goes to pieces in the hand (decision 423, P23); a
	# factory one cracks first and breaks at nothing (weapons.md: never
	# without warning).
	if h["condition"] <= 0.0 and (W.breaks(id) or WR.melee_breaks(id)):
		p.hands.remove_at(0)
		p.set_weapon_slots(p.hands)
		_toast(p, ("%s이(가) 부서졌다." if W.breaks(id) else WR.BROKE_LINE) % label)
	elif WR.cracks(id, before, float(h["condition"])):
		_toast(p, WR.CRACK_LINE % label)


func _toast(p, text: String) -> void:
	if p == game.player:
		game.hud.toast(text)


# ---------------------------------------------------------------- grabs and bites

func _dead_contact_valid(z: Dictionary, p) -> bool:
	if p == null or not p.is_alive() or z.is_empty():
		return false
	if z.get("state", "dead") in ["dead", "downed", "rising", "frozen", "waking", "climb"]:
		return false
	var reach: float = game.zombies.ATTACK_RANGE + GrabRules.CONTACT_MARGIN
	return z["pos"].distance_to(p.position) <= reach and game.zombies.can_reach(z, p)


## A dead hand reaches a person (body_injury 2): grab, scratch or blocked.
func zombie_reaches(z: Dictionary, p) -> String:
	if not _dead_contact_valid(z, p):
		return "miss"
	if p.grabbers.has(z):
		return "grab"
	var rng: RandomNumberGenerator = game.rng
	var now: float = game.clock.elapsed
	var part: String = BodyState.pick_scratch_part(wound_rng())
	var block: float = Wear.block(p, part)
	var outcome: String = GrabRules.attack_outcome(rng, block)
	match outcome:
		"grab":
			if not GrabRules.can_regrab(p, now):
				return "miss"
			var prone: bool = p.fallen_t > 0.0 or p.body.downed
			var front: bool = GrabRules.front_contact(p.facing, z["pos"] - p.position, prone)
			z["victim"] = p
			z["state"] = "grab"
			if not p.grabbers.has(z):
				p.grabbers.append(z)
				game.shout(p, "grabbed")
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
			p.body.apply_scratch(rng, now, part)
			Wear.tear(p, part, false)
			p.panic = minf(1.0, p.panic + 0.3)
			game.telemetry.injury(now, p.pid, "scratch")
			if p.team != "raider":
				game.say(p, "%s 긁혔다." % p.display_name, true, "scratch")
		"blocked":
			_toast(p, _held_line(Wear.tear(p, part, true)))
	return outcome


## A door of the held train gives way with someone in front of it: the hands
## that come through reach them once. The coat may stop it; if not it is a
## scratch (nothing has hold of them yet, so no grab comes of this).
func breach_reaches(p) -> String:
	var now: float = game.clock.elapsed
	var part: String = BodyState.pick_scratch_part(wound_rng())
	var block: float = Wear.block(p, part)
	if game.rng.randf() < block:
		_toast(p, _held_line(Wear.tear(p, part, true)))
		return "blocked"
	p.body.apply_scratch(game.rng, now, part)
	Wear.tear(p, part, false)
	p.panic = minf(1.0, p.panic + 0.3)
	game.telemetry.injury(now, p.pid, "scratch")
	game.say(p, "%s 긁혔다." % p.display_name, true, "scratch")
	return "scratch"


## What a held nail shows: the coat as it always said, else the garment that held.
func _held_line(by: String) -> String:
	if by == "" or by == String(Wear.KINDS["jacket_short"]["name"]):
		return "외투가 손톱을 막았다."
	return "%s 손톱을 막았다." % _subject(by)


## A garment's name as the one doing it: 이 after a closed syllable, else 가.
static func _subject(word: String) -> String:
	var last: int = word.unicode_at(word.length() - 1) - 0xAC00 if word != "" else -1
	var closed: bool = last >= 0 and last < 11172 and last % 28 != 0
	return "%s%s" % [word, "이" if closed else "가"]


## The window ran out: the bite lands (body_injury 2). Witnesses go on the receipt.
func bite(p) -> void:
	var rng: RandomNumberGenerator = game.rng
	var now: float = game.clock.elapsed
	var held: bool = not p.grabbers.is_empty()
	# A departed target or a stale hand cannot bite across a wall or floor.
	for z in p.grabbers.duplicate():
		if z.get("state") != "grab" or z.get("victim") != p or not _dead_contact_valid(z, p):
			p.release_grab(z)
			if z.get("state") == "grab" and z.get("victim") == p:
				game.zombies.release(z, p.position, false)
	if p.grabbers.is_empty():
		if held:
			GrabRules.mark_released(p, now)
		return
	var crawler := false
	for z in p.grabbers:
		crawler = crawler or bool(z.get("crawl", false))
	var part: String = GrabRules.bite_location(rng, crawler)
	var site: String = BodyState.pick_side(wound_rng(), part)
	var block: float = Wear.block(p, site, true)
	var blocked: bool = block > 0.0 and rng.randf() < block
	Wear.tear(p, site, blocked, true)
	if not blocked:
		p.body.apply_bite(rng, site, now)
	# The one at the front bit: it is drawn tearing away through the rest of its bite (DeadBody.bite_after_k).
	p.grabbers[0]["bit_at"] = float(p.grabbers[0]["age"])
	for z in p.grabbers.duplicate():
		game.zombies.release(z, p.position, false)
	p.grabbers.clear()
	p.grab_left = 0.0
	p.panic = 1.0
	if blocked:
		_toast(p, "외투가 물림을 막았다.")
		return
	game.telemetry.injury(now, p.pid, "bite")
	if p.team == "raider":
		return
	var part_word: String = {"arm": "팔", "torso": "몸통", "head_neck": "목", "leg": "다리"}.get(part, part)
	game.say(p, UiFonts.josa("%s %s을(를) 물렸다." % [p.display_name, part_word]), true, "bite_" + part)
	var seen: Array = []
	for o in game.allies_alive():
		if o != p and o.position.distance_to(p.position) < 12.0 and game.sight_clear(o.position, p.position):
			seen.append(o.pid)
	game.receipt.witness(p.pid, "bitten_" + part, _where(p.position), game.clock.label(), "grabbed_by_the_dead", seen)
	game.receipt.person("bitten", p.pid)


func _where(at: Vector3) -> String:
	var z: String = game.grid.zone_at(FieldGrid.cell_of(at))
	var names: Dictionary = game.data["zone_names"]
	return String(names.get(z, names.get("", game.data["place_id"])))


## Falls on ice, under a load or off the ladder (body_injury 3.2).
func fall(p, msg: String, fracture_chance: float = 0.05, leg: bool = false) -> void:
	p.fallen_t = FALL_TIME
	p.cancel_action()
	p.stop()
	p.aim.stop()
	game.make_sound(p.position, SimNoise.Level.NORMAL, "fall", p)
	if game.rng.randf() < fracture_chance:
		p.body.fracture(not leg, wound_side("leg" if leg else "arm"), game.clock.elapsed)
		game.telemetry.injury(game.clock.elapsed, p.pid, "fracture")
		game.say(p, "%s %s, %s가 부러졌다." % [p.display_name, msg, "다리" if leg else "팔"], true, "fracture")
	elif p.team != "raider":
		game.say(p, "%s %s." % [p.display_name, msg], true, "fall")


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
	return p.can_act() and W.is_ranged(wid) and not arm_too_hurt(p) and p.reload_t <= 0.0 and p.jam_t <= 0.0 and not bool(p.weapon().get("broken", false))


## A broken arm leaves one hand: two-handed guns and the bow stay down (body_injury 4.2).
func arm_too_hurt(p) -> bool:
	return bool(p.mults()["one_hand"]) and int(W.get_data(p.weapon_id()).get("hands", 1)) >= 2


## Press and hold: start the aim circle. Standing still shrinks it.
func start_aim(p) -> bool:
	if not can_shoot(p):
		if p == game.player and W.is_ranged(p.weapon_id()):
			if arm_too_hurt(p):
				game.hud.toast("팔 골절 · 두 손 무기 못 씀")
			elif bool(p.weapon().get("broken", false)):
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
	# Paused: a target may be picked, nothing leaves the gun (field_unified 10, tactical pause).
	if game.paused:
		p.aim.stop()
		_toast(p, "멈춘 동안은 쏘지 못한다.")
		return "none"
	if not p.aim.active:
		p.aim.start(wid, aim_mods(p))
	var h: Dictionary = p.weapon()
	if int(h["loaded"]) <= 0:
		p.aim.stop()
		start_reload(p)
		return "empty"
	if target == null or (target is Dictionary and target.is_empty()):
		at.y = game.level_y(game.level_of(p.position))
	else:
		# The shot goes where the target is, not where a dragged finger ended.
		var spot: Vector3 = target["pos"] if target is Dictionary else target.position
		at = Vector3(spot.x, at.y, spot.z)
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
		p.body.apply_cut(false, now, wound_side("arm"))
		game.make_sound(p.position, SimNoise.Level.LOUD, "gun", p)
		p.aim.stop()
		game.say(p, "%s 총열이 터졌다." % p.display_name)
		return "burst"
	# A silencer takes the shot one step down and wears with it (weapons.md 소음기).
	var silencer: String = String(h.get("silencer", ""))
	if silencer != "" and (not WR.silencer_fits(silencer, wid) or float(h.get("silencer_cond", 1.0)) <= 0.0):
		h.erase("silencer")
		h.erase("silencer_cond")
		silencer = ""
	game.make_sound(p.position, WR.shot_level(wid, silencer), "gun" if int(d["sound"]) > 0 else "bow", p)
	if silencer != "":
		h["silencer_cond"] = float(h.get("silencer_cond", 1.0)) - WR.silencer_wear(silencer, wid)
		if float(h["silencer_cond"]) <= 0.0:
			h.erase("silencer")
			h.erase("silencer_cond")
			_toast(p, "%s이(가) 망가졌다." % String(WR.SILENCERS[silencer]["name"]))
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
	var arrow: bool = wid == "bow"
	if blocked_at != null or dist > float(d["range"]):
		_drop_arrow(arrow, end, false)
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
	var lands: Vector3 = end
	if not hit:
		# The miss lands somewhere past the target: a small sound over there, and the arrow with it.
		var past: Vector3 = at + (at - p.position).normalized() * rng.randf_range(1.0, 3.0)
		game.make_sound(past, SimNoise.Level.QUIET, "impact", p)
		lands = past
	_drop_arrow(arrow, lands, hit)
	_after_shot(p)
	return "shot"


## An arrow lies where the shot ended, to be picked up again, unless it broke
## (weapons.md 공방탄: some break).
func _drop_arrow(arrow: bool, at: Vector3, hit: bool) -> void:
	if arrow and not WR.arrow_breaks(gear_rng().randf(), hit):
		game.ground_items.append({"pos": at, "id": "ammo_craft", "n": 1})


func _after_shot(p) -> void:
	if int(p.weapon()["loaded"]) <= 0:
		p.aim.stop()
		start_reload(p)


func _shoot_zombie(p, z: Dictionary, d: Dictionary, radius: float, dist: float) -> bool:
	var rng: RandomNumberGenerator = game.rng
	if z["state"] == "rising":
		var rose: String = AimModel.roll(rng, radius)
		if rose != "miss":
			_shot_through(z, rose)
			_kill(p, z, "")
			return true
		return false
	if int(d.get("pellets", 1)) > 1:
		var spread_m: float = dist * tan(deg_to_rad(float(d["spread_deg"])))
		var hits: Dictionary = AimModel.pellet_hits(rng, radius, spread_m, int(d["pellets"]))
		var body: int = int(hits["body"])
		if body > 0:
			_shot_through(z, "body")
		if int(hits["head"]) > 0:
			_shot_through(z, "head")
			_kill(p, z, "")
			return true
		if body <= 0:
			return false
		var knock := 1.0 - pow(1.0 - float(d["body_knockdown"]) , body)
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
		_shot_through(z, zone)
		_kill(p, z, "")
		return true
	if zone == "body":
		# A thick coat stops blades and bites only; rounds go through (user
		# 17:34, zombies.md 82e27ce). Only the vest stops a pistol round, on the
		# body (decision 434: the dead by the police station wear it): the round
		# stays in it, the body only staggers, and the vest is mostly holed there.
		var worn: Dictionary = game.zombies.worn_of(z)
		var stop: float = Wear.bullet_block_in(worn, "torso") if String(d.get("ammo", "")) == "pistol" else 0.0
		var held: bool = stop > 0.0 and rng.randf() < stop
		var by: String = Wear.shot_in(worn, "torso", held, rng)
		if held:
			z["stun"] = 0.3
			_toast(p, "%s 탄을 막았다." % _subject(by))
			return true
		if rng.randf() < float(d["body_knockdown"]):
			game.zombies.knock_down(z)
		else:
			z["stun"] = 0.5
		return true
	return false


## What hit one of the dead (a round, shot, an arrow) went through its clothes
## there, holing each layer as on the living (clothing.md 3.3). No dice.
func _shot_through(z: Dictionary, zone: String) -> void:
	Wear.shot_in(game.zombies.worn_of(z), "head_neck" if zone == "head" else "torso", false, game.rng)


func _shoot_person(p, o, radius: float) -> bool:
	var rng: RandomNumberGenerator = game.rng
	if not hostile(o):
		return false
	var cover := 0.0
	# Low cover (cars, fences) between shooter and target halves the body.
	if game.grid_at(o.position).solid_at(FieldGrid.cell_of(o.position + (p.position - o.position).normalized() * 1.0)) == FieldGrid.Solid.LOW:
		cover = 0.5
	var zone: String = AimModel.roll(rng, radius, 0.12, 0.34 * (1.0 - cover))
	if zone == "miss":
		return false
	o.last_hurt_by = p.pid
	var fine: String = o.body.gunshot_part(rng, zone)
	# A pistol round where a vest covers (decision 434, body_injury 6장): it is
	# stopped, and the vest more often than not holed there for the next one.
	# Where nothing stops rounds no dice are drawn: it goes in as it always did,
	# holing what it goes through.
	var pistol: bool = String(W.get_data(p.weapon_id()).get("ammo", "")) == "pistol"
	var stop: float = Wear.bullet_block_in(o.worn, fine) if pistol else 0.0
	var held: bool = stop > 0.0 and rng.randf() < stop
	var by: String = Wear.shot_in(o.worn, fine, held, rng)
	if held:
		game.actions.struck(o)
		game.make_sound(o.position, SimNoise.Level.QUIET, "impact", p)
		if o.team == "raider":
			game.ai.raider_hit(o, p)
		else:
			game.say(o, "%s 총에 맞았다 — %s 막았다." % [o.display_name, _subject(by)], true, "hurt")
		return true
	var part: String = o.body.gunshot_at(fine, game.clock.elapsed)
	if zone == "head":
		o.body.downed = true
	game.telemetry.injury(game.clock.elapsed, o.pid, "gunshot")
	if o.team == "raider":
		game.ai.raider_hit(o, p)
	else:
		game.say(o, "%s 총에 맞았다%s." % [o.display_name, " (다리)" if part == "leg" else ""], true, "hurt")
	return true


func _first_wall(from: Vector3, to: Vector3):
	var lg = game.grid_at(from)
	var a := FieldGrid.cell_of(from)
	var b := FieldGrid.cell_of(to)
	var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var c := FieldGrid.cell_of(from.lerp(to, t))
		if c == a:
			continue
		if lg.opaque(c):
			return FieldGrid.center(c) + Vector3(0, from.y, 0)
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
	# Not mid-blow either: one body does one thing at a time (decision 420).
	if p.hands.size() < 2 or not p.can_act() or p.action != "" or striking(p):
		return
	p.aim.stop()
	p.reload_t = 0.0
	var t: float = Carry.swap_time("belt", p.carry_state())
	p.start_action("swap", "무기 바꿈", t, func() -> void: p.swap_weapons())
