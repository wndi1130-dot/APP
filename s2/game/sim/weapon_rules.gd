extends RefCounted
## Weapon rules beside the weapon rows (weapons.md 규칙): silencers, how use
## and skill wear a melee weapon, and arrows that break. Values that came from
## the reference game say so; the rest are ours (new values, held by tests).

const W = preload("res://game/sim/weapons.gd")
const SimNoise = preload("res://game/sim/noise.gd")

## Silencers (weapons.md 소음기, decision 432 line): one step quieter only,
## never quiet; pistols and rifles only (S2 has no rifle). The improvised one
## (a bottle) is worn through in a few shots; the made one wears per shot, a
## rifle's faster than a pistol's.
const SILENCERS: Dictionary = {
	"silencer_bottle": {"name": "즉석 소음기", "wear": {"pistol": 0.25, "rifle": 0.25}},
	"silencer": {"name": "소음기", "wear": {"pistol": 0.01, "rifle": 0.02}},
}
## Which guns take one, and as what kind of gun.
const SILENCER_FITS: Dictionary = {"pistol": "pistol"}
## A silenced shot is at least this loud.
const SILENCED_FLOOR: int = SimNoise.Level.NORMAL

## Melee wear and skill (the reference game: a hit wears the weapon one time
## in n, n growing by half the weapon skill). Ours wears a little every blow;
## the same skill share is put on it as n / (n + floor(skill / 2)). n by the
## reference's knife, crowbar and hand axe; improvised ones have none (they
## are meant to go to pieces, decision 423).
const MELEE_WEAR_ONE_IN: Dictionary = {"knife": 15, "crowbar": 70, "axe": 15}

## A factory melee weapon worn to "위험" shows a crack first, then breaks at
## nothing (weapons.md: a knife breaks; never without warning).
const CRACK_LINE: String = "%s에 금이 갔다."
const BROKE_LINE: String = "%s이(가) 부러졌다."

## Arrows (weapons.md 공방탄): some break and are not found again.
const ARROW_BREAK_HIT: float = 0.3
const ARROW_BREAK_MISS: float = 0.1


static func silencer_fits(silencer_id: String, gun_id: String) -> bool:
	return SILENCERS.has(silencer_id) and SILENCER_FITS.has(gun_id)


## The sound level of a shot from this gun with this silencer on ("" none).
static func shot_level(gun_id: String, silencer_id: String = "") -> int:
	var level: int = int(W.get_data(gun_id).get("sound", 0))
	if silencer_id == "" or not silencer_fits(silencer_id, gun_id) or level <= SILENCED_FLOOR:
		return level
	return maxi(level - 1, SILENCED_FLOOR)


static func silencer_wear(silencer_id: String, gun_id: String) -> float:
	if not silencer_fits(silencer_id, gun_id):
		return 0.0
	return float(SILENCERS[silencer_id]["wear"].get(SILENCER_FITS[gun_id], 0.0))


static func melee_wear_mult(id: String, melee_skill: int) -> float:
	if not MELEE_WEAR_ONE_IN.has(id):
		return 1.0
	var n: float = float(MELEE_WEAR_ONE_IN[id])
	return n / (n + floorf(float(maxi(melee_skill, 0)) * 0.5))


## What one blow takes off a melee weapon.
static func melee_wear(id: String, quality: String, melee_skill: int) -> float:
	return W.wear_per_use(id, quality) * melee_wear_mult(id, melee_skill)


## A factory melee weapon breaks too (improvised ones already do: W.breaks).
static func melee_breaks(id: String) -> bool:
	return W.get_data(id).get("kind", "") == "melee"


## The blow that took it from "닳음" into "위험".
static func cracks(id: String, before: float, after: float) -> bool:
	return melee_breaks(id) and not W.breaks(id) and W.condition_level(before) < 2 and W.condition_level(after) == 2 and after > 0.0


static func arrow_breaks(roll: float, hit: bool) -> bool:
	return roll < (ARROW_BREAK_HIT if hit else ARROW_BREAK_MISS)
