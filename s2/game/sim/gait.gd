extends RefCounted
## How a living body goes on its feet: which walk and run it is drawn in by what
## is in its hand (decision 422 M11/M14, 423 card 3), how it holds a long weapon
## with a broken arm (422 M2, 423 card 5), when it reels (spent or bleeding hard:
## decision 448, how one moves shows the wounds), how it crouches, carries and
## walks hurt (448), when it stands on guard with a hand weapon (422 M3), and
## each person's own beat, stride and lean. The clips
## are picture only; the beat and the stride are also where the footsteps fall
## (field_game.gd steps_in), so the feet and the sound stay one.
##
## As the reference game picks them: a long gun and a two-handed weapon walk and
## run their own way, a handgun its own, a heavy tool its own; one-handed weapons,
## knives and empty hands the plain walk. It has nothing by person and nothing
## for a hurt arm: those are ours. Our hatchet and crowbar are one-handed but
## heavy, so they hang in the hand as they are carried (the axe walk); there is
## no axe run, so they run the plain run. A bow (the reference game has none) is
## carried in the hand on the plain walk: the long gun's two-handed carry put it
## across the hip with its end on the ground (check shots, 10-25).

const W = preload("res://game/sim/weapons.gd")
const Carry = preload("res://game/sim/carry.gd")

## The walk and run for each kind of hand (the people folder's clip names); a
## kind with none of its own, or a folder without it, walks and runs the plain way.
const WALK: Dictionary = {"long": "p_walk_long", "axe": "p_walk_axe", "pistol": "p_walk_pistol"}
const RUN: Dictionary = {"long": "p_run_long", "pistol": "p_run_pistol"}
## Crouched, the walk and the stand for each kind of hand: a long gun held low in
## both hands, a handgun low in both; the rest crouch the plain way (decision 448:
## the sneak by what is held, as the reference game sneaks each kind its own way).
const CROUCH_WALK: Dictionary = {"long": "p_crouch_walk_long", "pistol": "p_crouch_walk_pistol"}
const CROUCH_STAND: Dictionary = {"long": "p_crouch_idle_long", "pistol": "p_crouch_idle_pistol"}
## Walking with something big held in both arms (decision 448: carried, not run).
const CARRY_BIG: String = "p_carry_big"
## Walking hurt: bent, a hand pressed to the side (decision 448: wounds in how one moves).
const WALK_HURT: String = "p_walk_hurt"
## A long weapon held low in the one good hand, the hurt arm at the belly (standing).
const HOLD_WEAK: String = "p_hold_weak"
## A one-handed melee weapon this heavy (kg) hangs in the hand as it is carried.
const HEAVY_TOOL: float = 2.0
## On guard, standing: a knife low in front with its point out; any other hand
## weapon, or the bare fists, up by the shoulder. (The two-handed guard waits for
## a two-handed hand weapon: every one now is held in one hand.)
const READY_ONE: String = "p_ready_one"
const READY_STAB: String = "p_ready_stab"
## How often a body looks for danger near, and how long its guard stays up after
## the danger was last near (seconds; picture only).
const GUARD_LOOK: float = 0.25
const GUARD_HOLD: float = 2.0
## Each person's stride, of the walk's round: as far apart as the bodies' own
## baked rounds are (about 2% either way), so a foot never slides more than the
## 5% the clips were taken at.
const STRIDE: Vector2 = Vector2(0.98, 1.02)
## Each person's lean forward as they go (radians), from upright to a stoop;
## running leans further. It comes and goes over about a quarter of a second.
const POSTURE: Vector2 = Vector2(0.0, 0.06)
const RUN_POSTURE: float = 1.3
const POSTURE_EASE: float = 4.0


## "long" (a two-handed gun), "pistol" (a one-handed gun), "axe" (a heavy
## one-handed tool) or "" (a light weapon, a bow or nothing).
static func kind_of(weapon_id: String) -> String:
	var d: Dictionary = W.get_data(weapon_id)
	match String(d.get("kind", "")):
		"gun":
			return "pistol" if int(d.get("hands", 1)) == 1 else "long"
		"melee":
			return "axe" if float(d.get("weight", 0.0)) >= HEAVY_TOOL else ""
	return ""


## A long weapon in the hand with an arm too hurt for it (body_state.gd
## "one_hand": broken, or as bad as broken; field_combat.gd will not let it be
## aimed): held low in one hand standing, and carried in one hand on the move
## (the long walk and run hold it in both).
static func weak_hold(p) -> bool:
	return kind_of(p.weapon_id()) == "long" and bool(p.mults()["one_hand"])


## Running as the feet go now: the run is on and the body can run. Out of
## breath, spent, crouched, over the load or with something big in its arms it
## walks, as field_game.gd moves it (person.gd speed, load_lets_run).
static func runs(p) -> bool:
	return p.running and not p.crouched and p.load_lets_run() and p.body.can_run()


## Reeling on its feet: spent, or bleeding hard (body_state.gd bleed_level 2,
## where the rules slow the walk and the body goes down in two minutes), and not
## running or crouched. Walking, a leg that limps shows its limp instead
## (person_visual.gd limp_of); standing still it reels either way.
static func reels(p) -> bool:
	return not runs(p) and not p.crouched and (p.body.exhaustion_level() >= 2 or p.body.bleed_level() >= 2)


## The guard for what is in the hand, as the blow that follows it is picked
## (person_visual.gd blow_of: a knife stabs). "" with a gun or a bow (they are
## aimed their own way), an arm too hurt to hold a weapon up, or the arms full
## (something big, or someone carried).
static func ready_name(p) -> String:
	var wid: String = p.weapon_id()
	if W.is_ranged(wid) or bool(p.mults()["one_hand"]) or p.carrying_wounded != null or Carry.has_big(p.items):
		return ""
	return READY_STAB if wid == "knife" else READY_ONE


## Danger near enough to stand on guard: one of the dead the tap helper stops for
## (field_combat.gd tap_assist_off: on its feet, seen, on this floor, within
## TAP_ASSIST_OFF_R), or a fight with someone living. The reference game raises a
## hand weapon only while it is aimed; a phone has no aim for one, so the body
## raises it by itself.
static func threatened(field, p) -> bool:
	var combat = field.get("combat")
	return p.target_person != null or (combat != null and combat.tap_assist_off(p))


## The walk (or the run) for what is in the hand, "" for the plain one.
static func gait_name(p, running: bool) -> String:
	if weak_hold(p):
		return ""
	return String((RUN if running else WALK).get(kind_of(p.weapon_id()), ""))


## Crouched, the walk (or the stand) for what is in the hand, "" for the plain
## one; a long weapon held in one hand (weak_hold) crouches the plain way too.
static func crouch_name(p, walking: bool) -> String:
	if weak_hold(p):
		return ""
	return String((CROUCH_WALK if walking else CROUCH_STAND).get(kind_of(p.weapon_id()), ""))


## The walk under a burden, on its feet and not running, crouched, limping or
## reeling (person_visual.gd picks those first): something big in both arms is
## carried so (the load rule's own test, person.gd load_lets_run); a body wound as
## sore as it shows standing (`shown`) goes bent with a hand to its side. Bleeding
## hard keeps the reel: the field camera barely tells the hurt walk from a walk,
## and that body goes down in two minutes. "" with neither.
static func burden_name(p, shown: float) -> String:
	if Carry.has_big(p.items):
		return CARRY_BIG
	if p.body.torso_effort() - 1.0 >= shown:
		return WALK_HURT
	return ""


## This person's stride, of the walk's round (the same for every gait).
static func stride(p) -> float:
	return lerpf(STRIDE.x, STRIDE.y, p.name_unit("stride"))


## Where this person's walk is in its round before their first step: each
## person their own, so two who set off together are not in step.
static func first_step(p) -> float:
	return p.name_unit("step")


## How far forward this person leans as they go now (radians).
static func posture(p, running: bool) -> float:
	return lerpf(POSTURE.x, POSTURE.y, p.name_unit("posture")) * (RUN_POSTURE if running else 1.0)
