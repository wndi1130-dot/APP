extends RefCounted
# Weapon data and pure rules for S2 (weapons.md 'S2에 넣을 범위', crafted-gun axis split 2026-10-07).

const DATA: Dictionary = {
	"knife": {
		"name": "칼", "kind": "melee", "hands": 1, "weight": 1.0, "sound": 0,
		"reach": 1.0, "swing": 0.45, "head_base": 0.30, "head_kill": 0.85, "knockdown": 0.1,
		"blade": true, "fatigue": 0.004, "wear": 0.01, "pry": false,
	},
	"crowbar": {
		"name": "쇠지렛대", "kind": "melee", "hands": 1, "weight": 2.0, "sound": 0,
		"reach": 1.15, "swing": 0.6, "head_base": 0.28, "head_kill": 0.6, "knockdown": 0.5,
		"blade": false, "fatigue": 0.006, "wear": 0.004, "pry": true,
	},
	"axe": {
		"name": "손도끼", "kind": "melee", "hands": 1, "weight": 3.0, "sound": 0,
		"reach": 1.6, "swing": 0.9, "head_base": 0.32, "head_kill": 0.9, "knockdown": 0.6,
		"blade": true, "fatigue": 0.012, "wear": 0.006, "pry": false,
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


static func is_known(id: String) -> bool:
	return DATA.has(id)


static func get_data(id: String) -> Dictionary:
	return DATA.get(id, {})


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


static func melee_head_chance(id: String, melee_skill: int, target_downed: bool, from_behind: bool) -> float:
	if target_downed:
		return 1.0
	var p: float = float(get_data(id).get("head_base", 0.0)) + 0.04 * float(melee_skill)
	if from_behind:
		p += 0.15
	return clampf(p, 0.0, 0.9)
