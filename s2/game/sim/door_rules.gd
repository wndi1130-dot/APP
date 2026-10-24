extends RefCounted
## House-door timings; damage by the dead remains with its existing owner.

const TOGGLE_SECONDS := 0.5
const PRY_SECONDS := 4.0
const SAFE_EXTRA_SECONDS := 1.0
const KICK_SECONDS := 1.0
const KICK_CHANCE := 0.5
const OCCUPANT_RADIUS := 0.6


static func can_toggle(door: Dictionary, target: String, pried: bool = false) -> bool:
	var state := String(door.get("state", ""))
	if target == "open":
		return state == "closed" or (pried and state == "locked")
	return target == "closed" and state == "open"


static func can_force(door: Dictionary) -> bool:
	return String(door.get("state", "")) in ["closed", "locked"]
