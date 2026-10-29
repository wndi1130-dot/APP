extends RefCounted
# Weapon data and pure rules for S2 (weapons.md 'S2에 넣을 범위', crafted-gun axis split 2026-10-07).
# feet_from (melee, motion only): how far into the swing the feet are held,
# to its end (motion.gd swing_row). A knife is thrust with the feet free for
# its first half; a crowbar or an axe plants them almost at once (as the
# reference game holds the feet from 10% of a swing, from 50% of a stab).

const DATA: Dictionary = {
	"knife": {
		"name": "칼", "kind": "melee", "hands": 1, "weight": 1.0, "sound": 0,
		"reach": 1.0, "swing": 0.45, "windup": 0.10, "head_base": 0.30, "head_kill": 0.85, "knockdown": 0.1,
		"blade": true, "fatigue": 0.004, "wear": 0.01, "pry": false, "feet_from": 0.5, "gap": 0.15,
	},
	"crowbar": {
		"name": "쇠지렛대", "kind": "melee", "hands": 1, "weight": 2.0, "sound": 0,
		"reach": 1.15, "swing": 0.6, "windup": 0.18, "head_base": 0.28, "head_kill": 0.6, "knockdown": 0.5,
		"blade": false, "fatigue": 0.006, "wear": 0.0014, "pry": true, "feet_from": 0.1, "gap": 0.25,
	},
	# reach: as far as the drawn blade where the rules land the blow from
	# overhead (1.31 m, J2 ③); it was 1.6.
	"axe": {
		"name": "손도끼", "kind": "melee", "hands": 1, "weight": 3.0, "sound": 0,
		"reach": 1.3, "swing": 0.9, "windup": 0.30, "head_base": 0.32, "head_kill": 0.9, "knockdown": 0.6,
		"blade": true, "fatigue": 0.012, "wear": 0.006, "pry": false, "feet_from": 0.1, "gap": 0.3,
	},
	"pistol": {
		"name": "권총", "kind": "gun", "hands": 1, "weight": 2.0, "sound": 2,
		"ammo": "pistol", "mag": 8, "reload": 1.8, "reload_each": false, "pellets": 1, "spread_deg": 0.0,
		"start_deg": 9.0, "min_deg": 1.2, "shrink_time": 1.0, "bloom_deg": 6.0, "min_dist": 1.2,
		"range": 26.0, "head_kill": 1.0, "body_knockdown": 0.35, "action": "semi", "wear": 0.006,
		"min_skill": 0, "crafted": false,
	},
	"shotgun": {
		"name": "펌프식 산탄총", "kind": "gun", "hands": 2, "weight": 3.0, "sound": 3,
		"ammo": "shell", "mag": 4, "reload": 0.7, "reload_each": true, "pellets": 8, "spread_deg": 5.0,
		"start_deg": 7.0, "min_deg": 2.5, "shrink_time": 0.9, "bloom_deg": 9.0, "min_dist": 1.0,
		"range": 14.0, "head_kill": 1.0, "body_knockdown": 0.25, "action": "pump", "wear": 0.008,
		"min_skill": 0, "crafted": false,
	},
	"bow": {
		"name": "사냥 활", "kind": "bow", "hands": 2, "weight": 2.0, "sound": 0,
		"ammo": "craft", "mag": 1, "reload": 1.4, "reload_each": false, "pellets": 1, "spread_deg": 0.0,
		"start_deg": 10.0, "min_deg": 1.0, "shrink_time": 1.6, "bloom_deg": 2.0, "min_dist": 1.5,
		"range": 26.0, "head_kill": 1.0, "body_knockdown": 0.3, "action": "bow", "wear": 0.002,
		"min_skill": 4, "crafted": false,
	},
	"pipe_shotgun": {
		"name": "파이프 산탄총", "kind": "gun", "hands": 2, "weight": 3.0, "sound": 3,
		"ammo": "shell", "mag": 1, "reload": 3.0, "reload_each": false, "pellets": 7, "spread_deg": 7.0,
		"start_deg": 9.0, "min_deg": 2.0, "shrink_time": 1.2, "bloom_deg": 11.0, "min_dist": 1.0,
		"range": 12.0, "head_kill": 1.0, "body_knockdown": 0.25, "action": "single", "wear": 0.02,
		"min_skill": 0, "crafted": true,
	},
}

# Crafted-gun quality. Factory guns always use "factory".
const QUALITY: Dictionary = {
	"crude": {"name": "조잡", "min_mult": 1.8, "wear_mult": 2.0, "burst": 0.03},
	"usable": {"name": "쓸 만함", "min_mult": 1.3, "wear_mult": 1.3, "burst": 0.0},
	"fine": {"name": "정교", "min_mult": 1.05, "wear_mult": 1.05, "burst": 0.0},
	"factory": {"name": "공장제", "min_mult": 1.0, "wear_mult": 1.0, "burst": 0.0},
}

const CONDITION_NAMES: Array[String] = ["좋음", "닳음", "위험"]
const AMMO_NAMES: Dictionary = {"pistol": "권총탄", "shell": "산탄", "craft": "공방탄"}

# Jam rows for semi/pump by condition level; cold uses the next row.
const JAM_ROWS: Array[float] = [0.0, 0.03, 0.10, 0.15]
# Misfire rows for single-shot; cold moves one row worse, capped at the last row.
const MISFIRE_ROWS: Array[float] = [0.03, 0.06, 0.10]


## What is grabbed when there is nothing better (decision 423, P23): found in a
## kitchen or a washroom, or made from a plank, picked up into a free hand at
## once. Weak and short-lived: "breaks" takes it out of the hand when it is
## worn to nothing (a broken bottle after four blows, a stake after five).
const IMPROVISED: Dictionary = {
	"frying_pan": {
		"name": "프라이팬", "kind": "melee", "hands": 1, "weight": 1.5, "sound": 0,
		"reach": 1.0, "swing": 0.6, "windup": 0.18, "head_base": 0.24, "head_kill": 0.45, "knockdown": 0.45,
		"blade": false, "fatigue": 0.007, "wear": 0.05, "pry": false, "feet_from": 0.1, "breaks": true, "gap": 0.2,
	},
	"broken_bottle": {
		"name": "깨진 병", "kind": "melee", "hands": 1, "weight": 0.5, "sound": 0,
		"reach": 0.8, "swing": 0.4, "windup": 0.08, "head_base": 0.25, "head_kill": 0.6, "knockdown": 0.05,
		"blade": true, "fatigue": 0.004, "wear": 0.25, "pry": false, "feet_from": 0.5, "breaks": true, "gap": 0.1,
	},
	"wood_stake": {
		"name": "나무 말뚝", "kind": "melee", "hands": 1, "weight": 1.0, "sound": 0,
		"reach": 1.1, "swing": 0.5, "windup": 0.12, "head_base": 0.28, "head_kill": 0.7, "knockdown": 0.15,
		"blade": true, "fatigue": 0.005, "wear": 0.2, "pry": false, "feet_from": 0.5, "breaks": true, "gap": 0.15,
	},
}


static func is_known(id: String) -> bool:
	return DATA.has(id) or IMPROVISED.has(id)


static func get_data(id: String) -> Dictionary:
	return DATA.get(id, IMPROVISED.get(id, {}))


## A weapon that goes to pieces when worn out (an improvised one).
static func breaks(id: String) -> bool:
	return bool(get_data(id).get("breaks", false))


static func is_ranged(id: String) -> bool:
	var kind: String = get_data(id).get("kind", "")
	return kind == "gun" or kind == "bow"


# Quality row actually in effect: only crafted weapons read the given quality.
static func quality_row(id: String, quality: String) -> Dictionary:
	if bool(get_data(id).get("crafted", false)) and QUALITY.has(quality):
		return QUALITY[quality]
	return QUALITY["factory"]


# 0 좋음 (>0.6), 1 닳음 (>0.3), 2 위험.
static func condition_level(c: float) -> int:
	if c > 0.6:
		return 0
	if c > 0.3:
		return 1
	return 2


static func jam_chance(id: String, condition: float, cold: bool) -> float:
	var action: String = get_data(id).get("action", "")
	if action != "semi" and action != "pump":
		return 0.0
	var row: int = condition_level(condition) + (1 if cold else 0)
	return JAM_ROWS[row]


static func misfire_chance(id: String, condition: float, cold: bool) -> float:
	var action: String = get_data(id).get("action", "")
	if action != "single":
		return 0.0
	var row: int = mini(condition_level(condition) + (1 if cold else 0), MISFIRE_ROWS.size() - 1)
	return MISFIRE_ROWS[row]


static func burst_chance(id: String, quality: String) -> float:
	if get_data(id).get("action", "") != "single":
		return 0.0
	return float(quality_row(id, quality)["burst"])


# Smallest aim half-angle (deg) for this weapon, build quality and shooting level.
static func min_deg(id: String, quality: String, shooting_skill: int) -> float:
	var d: Dictionary = get_data(id)
	if not d.has("min_deg"):
		return 0.0
	var base: float = d["min_deg"]
	var q_mult: float = quality_row(id, quality)["min_mult"]
	var skill_mult: float = maxf(0.7, 1.3 - 0.06 * float(shooting_skill))
	var short: int = maxi(0, int(d.get("min_skill", 0)) - shooting_skill)
	var short_mult: float = 1.0 + 0.25 * float(short)
	return base * q_mult * skill_mult * short_mult


# Condition lost per swing or shot.
static func wear_per_use(id: String, quality: String) -> float:
	var d: Dictionary = get_data(id)
	return float(d.get("wear", 0.0)) * float(quality_row(id, quality)["wear_mult"])


## How long a melee weapon is drawn back before the blow lands (user 2026-10-11:
## by the weapon's weight; first values knife 0.10, crowbar 0.18, hatchet 0.30 s,
## to be set on the phone). It is the front part of the swing time, not added
## to it. A melee weapon with no value of its own goes by its weight.
static func melee_windup(id: String) -> float:
	var d: Dictionary = get_data(id)
	if d.is_empty() or d.get("kind", "") != "melee":
		return 0.0
	var w: float = float(d.get("windup", 0.1 * float(d.get("weight", 1.0))))
	return minf(w, float(d.get("swing", w)) * 0.5)


## The player's wait after a melee blow lands before the next can start
## (decision 473 W1): the reference game's delay between attacks, here by
## the weapon's weight (knife 0.15, crowbar 0.25, hatchet 0.3 s). The blow's
## timing is untouched (decision 411); companions rest by their own pace instead.
static func melee_gap(id: String) -> float:
	var d: Dictionary = get_data(id)
	if d.get("kind", "") != "melee":
		return 0.0
	return float(d.get("gap", 0.0))


## Strength against the weight in the hand (decisions 2026-10-11 '근접 타수'):
## a weapon asks for strength 2 x weight + 1 (knife 3, crowbar 5, hatchet 7).
## Short of it the blow knocks down less; with strength to spare a little more.
static func melee_weight_mult(id: String, strength: int) -> float:
	var need: float = 2.0 * float(get_data(id).get("weight", 1.0)) + 1.0
	return clampf(1.0 - 0.15 * (need - float(strength)), 0.4, 1.15)


## The head is the smaller target, so the state of the hand cannot take the
## chance to find it below this share (a knife, which rarely knocks down,
## would otherwise need seventeen blows at the worst).
const MELEE_HEAD_FLOOR: float = 0.3


## One blow on a standing or downed body: chance to hit the head, to kill on
## a head hit, and to knock down on a body hit. hit_mult is the state of the
## one who strikes (body_state multipliers "melee_hit", 0.15..1).
static func melee_odds(id: String, melee_skill: int, target_downed: bool, from_behind: bool, hit_mult: float = 1.0, strength: int = 5) -> Dictionary:
	var d: Dictionary = get_data(id)
	var head: float = melee_head_chance(id, melee_skill, target_downed, from_behind)
	if not target_downed:
		head *= clampf(hit_mult, MELEE_HEAD_FLOOR, 1.0)
	var knock: float = float(d.get("knockdown", 0.0)) * clampf(hit_mult, 0.0, 1.0) * melee_weight_mult(id, strength)
	return {"head": head, "kill": float(d.get("head_kill", 0.0)), "knockdown": clampf(knock, 0.0, 0.95)}


## Blows it takes on average to end a standing body that stays down once it
## is knocked down (one more blow ends it there). For tests and tuning.
static func melee_mean_swings(odds: Dictionary) -> float:
	var h: float = odds["head"]
	var k: float = odds["kill"]
	var q: float = odds["knockdown"]
	var stays_up: float = (1.0 - h) * (1.0 - q)
	if stays_up >= 1.0:
		return INF
	return (1.0 + h * (1.0 - k) + (1.0 - h) * q) / (1.0 - stays_up)


static func melee_head_chance(id: String, melee_skill: int, target_downed: bool, from_behind: bool) -> float:
	if target_downed:
		return 1.0
	var p: float = float(get_data(id).get("head_base", 0.0)) + 0.04 * float(melee_skill)
	if from_behind:
		p += 0.15
	return clampf(p, 0.0, 0.9)
