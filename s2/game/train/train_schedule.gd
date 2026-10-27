extends RefCounted
## This is called on input/lifecycle events only, never in the drawing tick.

const Catalog = preload("res://game/train/train_catalog.gd")
const Look = preload("res://game/train/train_look.gd")
const STATES := ["work", "eat", "heal", "session", "sleep", "idle", "call", "gather"]


static func main_state(c: Dictionary, person: Dictionary) -> String:
	if c["council"] and c["layout"] == "dining":
		return "session"
	if int(c["stage"]) >= 3 and int(c["stage"]) <= 5 and not bool(person.get("child", false)):
		return "gather"
	if bool(person.get("injured", false)) or bool(person.get("sick", false)):
		return "heal"
	if c["accident"]:
		return "idle"
	if c["memorial"] and c["layout"] == "dining":
		return "gather"
	if c["night"]:
		return "sleep"
	if float(c["ration"]) < Look.LOW_BELOW or int(c["hunger"]) > 0:
		return "eat"
	if c["work"] and String(person.get("role", "")) != "" and not bool(person.get("child", false)):
		return "work"
	return "idle"


static func preferences(c: Dictionary, person: Dictionary) -> Array:
	var out: Array = []
	for layer in Catalog.data()["preferences"]:
		for id in layer["activities"]:
			var allowed: bool = true
			match String(id):
				"session": allowed = c["council"]
				"gather": allowed = c["gather"] and not bool(person.get("child", false)) and not bool(person.get("injured", false))
				"mourn": allowed = c["memorial"]
				"work", "cook", "serve", "carry": allowed = c["work"] and not bool(person.get("child", false)) and not bool(person.get("injured", false))
				"teach": allowed = c["classroom"]
				"care": allowed = c["patients"] and String(person.get("role", "")) == "carer"
				"chat": allowed = c["social"] and not bool(person.get("mourning", false))
				"mend": allowed = c["materials"] and not bool(person.get("child", false))
				"eat": allowed = c["meal"]
				"warm": allowed = c["stove"]
				"heal": allowed = bool(person.get("injured", false)) or bool(person.get("sick", false))
				"sleep": allowed = c["night"]
			if allowed:
				out.append(id)
	return out


static func ranked(preferred: Array, state: String, c: Dictionary) -> Array:
	var first: Array = []
	var rest: Array = []
	for id in preferred:
		if String(Catalog.data()["activities"][id]["state"]) == state:
			first.append(id)
		else:
			rest.append(id)
	if state == "idle" and float(c["warmth"]) < Look.WARM_COLD and first.has("warm"):
		first.erase("warm")
		first.push_front("warm")
	return first + rest


static func gesture(activity: String, c: Dictionary, person: Dictionary, turn: int) -> String:
	if c["voting"]:
		return "freeze_look"
	if activity in ["sleep", "heal"]:
		return "lie_bunk"
	if activity == "mourn":
		return "mourn_stand" if turn % 2 == 0 else "hat_off"
	if float(c["fear"]) >= Look.FEAR_FROZEN:
		return "head_down"
	if bool(person.get("child", false)):
		if int(c["stage"]) >= 3:
			return "sit_floor"
		if activity == "teach":
			return "child_draw_floor"
	if float(c["ration"]) < Look.LOW_BELOW and float(c["ration"]) <= float(c["warmth"]):
		return "eat_bowl" if activity == "eat" else "catch_breath"
	if activity == "warm" and float(c["warmth"]) < Look.WARM_COLD:
		return "rub_stamp"
	# A job short of hands: the ones left at it stop every other turn to get their breath back (carry_people 3.6).
	if activity == "work" and float(c.get("job_short", 0.0)) > 0.0 and turn % 2 == 1:
		return "catch_breath"
	if activity == "gather":
		var row: Dictionary = Catalog.data()["collapse"][int(c["stage"])]
		return String(row["gestures"][posmod(turn, row["gestures"].size())])
	var row: Dictionary = Catalog.data()["activities"].get(activity, Catalog.data()["activities"]["rest"])
	return String(row["gestures"][posmod(turn, row["gestures"].size())])


static func distractions(c: Dictionary, person: Dictionary) -> Array:
	if c["voting"] or int(c["stage"]) >= 3:
		return []
	if bool(person.get("sick", false)):
		return ["cough", "catch_breath"]
	if float(c["warmth"]) < Look.WARM_COLD:
		return ["rub_stamp", "catch_breath"]
	if float(c["ration"]) < Look.LOW_BELOW or float(c["trust"]) < Look.LOW_BELOW:
		return ["catch_breath", "stretch_tired"]
	if c["stopped"] and c["weather"] in ["snow", "sleet", "blizzard"]:
		return ["shake_snow", "look_around"]
	return ["look_around", "stretch_tired"]
