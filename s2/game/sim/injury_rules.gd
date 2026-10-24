extends RefCounted
## Six body regions, bounded wounds, and normalized pain. Times are seconds.

const MAX_SAME_WOUNDS := 4       # at most 6 regions * 6 kinds * 4 records
const BANDAGE_DEEP_S := 180.0
const BANDAGE_LIGHT_S := 360.0
const BANDAGE_REPLACE_S := 3.0
const PAIN_SCALE := 100.0
const SCRATCH_SIZE := 11.0
const LACERATION_SIZE := 15.0
const DEEP_SIZE := 17.5
const PAIN := {
	"scratch": SCRATCH_SIZE * 1.7 / PAIN_SCALE,
	"laceration": LACERATION_SIZE * 2.5 / PAIN_SCALE,
	"deep": DEEP_SIZE * 3.7 / PAIN_SCALE,
	"embedded": DEEP_SIZE * 3.7 / PAIN_SCALE,
	"bite": 0.5, "fracture": 1.0,
}
const BOUND_BITE_PAIN := 0.3
const BULLET_PAIN := 0.5
const GLASS_PAIN := 0.1
const BANDAGE_PAIN_DIVISOR := 1.5
const SPLINT_PAIN_MULT := 0.5
const SUTURE_PAIN_MULT := 0.5
const FESTER_PAIN := 0.1
const LIGHT_SEVERITY := 0.5
const HEAD_AIM_MULT := 1.4
const ARM_RELOAD_MULT := 0.6
const ARM_SWAP_MULT := 0.7
const ARM_HANDS_MULT := 0.5
const ARM_SHOVE_MULT := 0.7
const LEG_MOVE_MULT := 0.6
const PAIN_ACTION_FLOOR := 0.5


static func bandage_life(wound: Dictionary) -> float:
	return BANDAGE_DEEP_S if wound.get("kind", "") in ["deep", "embedded"] else BANDAGE_LIGHT_S


static func dirty(wound: Dictionary) -> bool:
	return bool(wound.get("bandaged", false)) and bool(wound.get("bandage_dirty", false))


static func needs_closure(wound: Dictionary) -> bool:
	if wound.get("kind", "") == "deep":
		return not bool(wound.get("sutured", false))
	if wound.get("kind", "") == "embedded":
		return not bool(wound.get("pulled", false)) or (wound.get("what", "") == "bullet" and not bool(wound.get("sutured", false)))
	return false


static func severity(wound: Dictionary) -> float:
	return LIGHT_SEVERITY if wound.get("kind", "") in ["scratch", "laceration", "bite"] else 1.0


static func pain(wound: Dictionary) -> float:
	var kind := String(wound.get("kind", ""))
	var value := float(PAIN.get(kind, 0.0))
	if kind == "embedded" and not bool(wound.get("pulled", false)):
		value += BULLET_PAIN if wound.get("what", "") == "bullet" else GLASS_PAIN
	if kind == "bite" and bool(wound.get("bandaged", false)):
		value = BOUND_BITE_PAIN
	if kind == "fracture" and bool(wound.get("splinted", false)):
		value *= SPLINT_PAIN_MULT
	if kind in ["deep", "embedded"] and bool(wound.get("sutured", false)):
		value *= SUTURE_PAIN_MULT
	if bool(wound.get("bandaged", false)):
		value /= BANDAGE_PAIN_DIVISOR
	if bool(wound.get("festering", false)):
		value += FESTER_PAIN
	return clampf(value * maxf(1.0, float(wound.get("hits", 1))), 0.0, 1.0)
