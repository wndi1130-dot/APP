extends RefCounted
## The feel of a blow (decision 444, 전투 손맛 C): what is seen, heard and
## felt in the hand when a melee blow goes out and lands. The rules call in
## (field_combat.gd) and nothing here is read back by them, so a field run on
## the rules alone (_step, the bot runs) comes out the same with or without it.
##   hitstop  the field holds still a few hundredths of a second as the
##            player's own blow lands, longer for a heavier weapon and for a
##            body that goes down; never again within STOP_REST of the last
##   shake    the camera kicks a little the way the blow went and settles
##            (the player's own blows and shots; harder when bitten)
##   haptic   a short buzz on a phone with it (Input.vibrate_handheld)
##   sound    a whoosh as the weapon comes round, then a blunt, an edged or a
##            stamping blow where it lands (field_audio groups swing_*, hit_*)
## The reference game has no hitstop or shake: its blows are felt through
## their sound and a long stagger. These are ours, for a phone.

const W = preload("res://game/sim/weapons.gd")

## Seconds the field holds for a blow: by the weapon's weight (knife 0.045,
## crowbar 0.06, hatchet 0.075), more if the body goes down.
const STOP_BASE: float = 0.03
const STOP_PER_KG: float = 0.015
const STOP_FELLED: float = 0.025
const STOP_STOMP: float = 0.05
const STOP_DOOR: float = 0.03
const STOP_BITTEN: float = 0.09
const STOP_MAX: float = 0.12
## No second hold this soon after one ends: a quick run of blows stays fluid.
const STOP_REST: float = 0.12

## The camera's kick as a share of the view's height, so it reads the same
## zoomed in or out (crowbar about 6 px of a 1080 px screen, a bite 13 px),
## settling over SHAKE_TAU. In metres it is these times the camera's size.
const SHAKE_BASE: float = 0.0035
const SHAKE_PER_KG: float = 0.0012
const SHAKE_FELLED: float = 0.002
const SHAKE_DOOR: float = 0.004
const SHAKE_BITTEN: float = 0.012
const SHAKE_SHOT: Dictionary = {"pistol": 0.004, "shotgun": 0.008, "pipe_shotgun": 0.008, "bow": 0.002}
const SHAKE_TAU: float = 0.09
const SHAKE_HZ: float = 18.0
const SHAKE_MAX: float = 0.016
## Kicks kept at once. A field stepped with no frames (the bot runs) never
## settles them, so the oldest go.
const KICKS_MAX: int = 6

## The buzz: [milliseconds, strength 0..1].
const BUZZ_BASE_MS: float = 18.0
const BUZZ_PER_KG_MS: float = 8.0
const BUZZ_FELLED_MS: float = 15.0
const BUZZ_BITTEN: Array = [120, 1.0]
const BUZZ_SHOT: Array = [30, 0.6]

## How loud and how far the sounds carry for the ear (not for the dead: their
## hearing is make_sound's, unchanged).
const SWING_LOUD: float = 0.5
const SWING_REACH: float = 18.0
const BLOW_LOUD: float = 0.85
const BLOW_REACH: float = 40.0
## From this weight a weapon swings with the heavy whoosh.
const HEAVY_KG: float = 2.0

var game
var hold_t: float = 0.0          # seconds the field still holds
var rest_t: float = 0.0          # seconds until another hold may come
var kicks: Array = []            # {"dir": Vector3, "amp": float, "t": float}
var last_buzz: Array = []        # [ms, strength] of the last buzz (tests)


func _init(field_game) -> void:
	game = field_game


## The field holds still this frame (field_game skips the rules' step).
func holding() -> bool:
	return hold_t > 0.0


## step: the field is running (not paused, not over); the hold only counts
## down then. The shake settles either way.
func tick(delta: float, step: bool) -> void:
	if step:
		if hold_t > 0.0:
			var over: float = delta - hold_t
			hold_t = maxf(0.0, hold_t - delta)
			if hold_t <= 0.0:
				rest_t = maxf(0.0, STOP_REST - over)
		elif rest_t > 0.0:
			rest_t = maxf(0.0, rest_t - delta)
	var keep: Array = []
	for k in kicks:
		k["t"] = float(k["t"]) + delta
		if float(k["t"]) < SHAKE_TAU * 5.0:
			keep.append(k)
	kicks = keep


## Where the camera stands off its place this frame, on the ground plane, as
## a share of the view's height (field_game multiplies by the camera's size).
func camera_offset() -> Vector3:
	var out := Vector3.ZERO
	for k in kicks:
		var t: float = k["t"]
		var fade: float = exp(-t / SHAKE_TAU) * float(k["amp"])
		var dir: Vector3 = k["dir"]
		var side := Vector3(-dir.z, 0.0, dir.x)
		out += dir * fade * cos(TAU * SHAKE_HZ * t) + side * fade * 0.35 * sin(TAU * SHAKE_HZ * 1.37 * t)
	return out.limit_length(SHAKE_MAX)


## A melee weapon starts to come round (or a shove goes out: no weapon, or a
## gun in the hand, which shoves).
func swing(p, weapon_id: String) -> void:
	var d: Dictionary = W.get_data(weapon_id)
	var heavy: bool = d.get("kind", "") == "melee" and float(d.get("weight", 0.0)) >= HEAVY_KG
	_sound("swing_heavy" if heavy else "swing_light", p.position, SWING_LOUD, SWING_REACH)


## A melee blow landed on a body at `at`; felled: it went down or died.
func landed(p, at: Vector3, weapon_id: String, felled: bool) -> void:
	var d: Dictionary = W.get_data(weapon_id)
	if d.get("kind", "") != "melee":
		return
	_sound("hit_blade" if bool(d.get("blade", false)) else "hit_blunt", at, BLOW_LOUD, BLOW_REACH)
	if p != game.player:
		return
	var kg: float = float(d.get("weight", 1.0))
	var more: float = 1.0 if felled else 0.0
	_hold(STOP_BASE + STOP_PER_KG * kg + STOP_FELLED * more)
	_kick(at - p.position, SHAKE_BASE + SHAKE_PER_KG * kg + SHAKE_FELLED * more)
	_buzz(BUZZ_BASE_MS + BUZZ_PER_KG_MS * kg + BUZZ_FELLED_MS * more, clampf(0.35 + 0.15 * kg, 0.0, 1.0))


## A boot came down on a body on the ground.
func stomped(p, at: Vector3, ended_it: bool) -> void:
	_sound("hit_stomp", at, BLOW_LOUD, BLOW_REACH)
	if p != game.player:
		return
	_hold(STOP_STOMP + (STOP_FELLED if ended_it else 0.0))
	_kick(at - p.position, SHAKE_BASE + (SHAKE_FELLED if ended_it else 0.0))
	_buzz(BUZZ_BASE_MS + (BUZZ_FELLED_MS if ended_it else 0.0), 0.5)


## A swing met a shut door.
func struck_door(p, at: Vector3, weapon_id: String) -> void:
	_sound("hit_blunt", at, BLOW_LOUD * 0.8, BLOW_REACH)
	if p != game.player:
		return
	_hold(STOP_DOOR)
	_kick(at - p.position, SHAKE_DOOR)
	_buzz(BUZZ_BASE_MS + BUZZ_PER_KG_MS * float(W.get_data(weapon_id).get("weight", 1.0)), 0.4)


## A bite landed on the player (blocked: the coat took it).
func bitten(p, blocked: bool) -> void:
	if p != game.player:
		return
	var k: float = 0.5 if blocked else 1.0
	_hold(STOP_BITTEN * k)
	var toward := Vector3(sin(p.facing), 0.0, cos(p.facing))
	_kick(-toward, SHAKE_BITTEN * k)
	_buzz(float(BUZZ_BITTEN[0]) * k, float(BUZZ_BITTEN[1]) * k)


## The player's own shot: the camera kicks back from where it went.
func shot(p, weapon_id: String, at: Vector3) -> void:
	if p != game.player:
		return
	_kick(p.position - at, float(SHAKE_SHOT.get(weapon_id, 0.004)))
	_buzz(float(BUZZ_SHOT[0]), float(BUZZ_SHOT[1]))


func _hold(seconds: float) -> void:
	if hold_t > 0.0 or rest_t > 0.0:
		return
	hold_t = minf(seconds, STOP_MAX)


func _kick(way: Vector3, amp: float) -> void:
	way.y = 0.0
	var dir := way.normalized() if way.length() > 0.01 else Vector3(0, 0, -1)
	kicks.append({"dir": dir, "amp": amp, "t": 0.0})
	if kicks.size() > KICKS_MAX:
		kicks.pop_front()


func _buzz(ms: float, strength: float) -> void:
	last_buzz = [int(round(ms)), strength]
	Input.vibrate_handheld(int(round(ms)), strength)


func _sound(group: String, at: Vector3, loud: float, reach: float) -> void:
	var audio = game.get("audio")
	if audio != null:
		audio.feel_sound(group, at, loud, reach)
