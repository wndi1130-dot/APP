extends RefCounted
## How a living body goes on its feet: which walk and run it is drawn in by what
## is in its hand (decision 422 M11/M14, 423 card 3), how it holds a long weapon
## with a broken arm (422 M2, 423 card 5), and each person's own beat, stride and
## lean. The clips are picture only; the beat and the stride are also where the
## footsteps fall (field_game.gd steps_in), so the feet and the sound stay one.
##
## As the reference game picks them: a long gun and a two-handed weapon walk and
## run their own way, a handgun its own, a heavy tool its own; one-handed weapons,
## knives and empty hands the plain walk. It has nothing by person and nothing
## for a hurt arm: those are ours. Our hatchet and crowbar are one-handed but
## heavy, so they hang in the hand as they are carried (the axe walk); there is
## no axe run, so they run the plain run.

const W = preload("res://game/sim/weapons.gd")

## The walk and run for each kind of hand (the people folder's clip names); a
## kind with none of its own, or a folder without it, walks and runs the plain way.
const WALK: Dictionary = {"long": "p_walk_long", "axe": "p_walk_axe", "pistol": "p_walk_pistol"}
const RUN: Dictionary = {"long": "p_run_long", "pistol": "p_run_pistol"}
## A long weapon held low in the one good hand, the hurt arm at the belly (standing).
const HOLD_WEAK: String = "p_hold_weak"
## A one-handed melee weapon this heavy (kg) hangs in the hand as it is carried.
const HEAVY_TOOL: float = 2.0
## Each person's stride, of the walk's round: as far apart as the bodies' own
## baked rounds are (about 2% either way), so a foot never slides more than the
## 5% the clips were taken at.
const STRIDE: Vector2 = Vector2(0.98, 1.02)
## Each person's lean forward as they go (radians), from upright to a stoop;
## running leans further. It comes and goes over about a quarter of a second.
const POSTURE: Vector2 = Vector2(0.0, 0.06)
const RUN_POSTURE: float = 1.3
const POSTURE_EASE: float = 4.0


## "long" (a two-handed gun or a bow), "pistol" (a one-handed gun), "axe" (a
## heavy one-handed tool) or "" (a light weapon or nothing).
static func kind_of(weapon_id: String) -> String:
	var d: Dictionary = W.get_data(weapon_id)
	match String(d.get("kind", "")):
		"gun":
			return "pistol" if int(d.get("hands", 1)) == 1 else "long"
		"bow":
			return "long"
		"melee":
			return "axe" if float(d.get("weight", 0.0)) >= HEAVY_TOOL else ""
	return ""


## A long weapon in the hand with an arm broken: held low in one hand standing,
## and carried in one hand on the move (the long walk and run hold it in both).
static func weak_hold(p) -> bool:
	return p.body.arm_fracture and kind_of(p.weapon_id()) == "long"


## Running as the feet go now: the run is on and the body can run. Out of
## breath, spent, crouched or overloaded it walks, as field_game.gd moves it.
static func runs(p) -> bool:
	return p.running and not p.crouched and p.carry_state() < 3 and p.body.can_run()


## The walk (or the run) for what is in the hand, "" for the plain one.
static func gait_name(p, running: bool) -> String:
	if weak_hold(p):
		return ""
	return String((RUN if running else WALK).get(kind_of(p.weapon_id()), ""))


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
