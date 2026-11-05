extends RefCounted
## Project S1 people to experts and omit only the unported log/counter columns.
## Missing log/stats keys stay missing, so comparisons still catch absent defaults.


static func project(g: Dictionary) -> Dictionary:
	var out: Dictionary = g.duplicate(true)
	if not out.get("dom") is Dictionary:
		return out
	var d: Dictionary = out["dom"]
	# Supplies sequences retain S1 people; only their living expert columns exist in S2.
	if d.get("people") is Array and not d.has("experts"):
		d["experts"] = []
		for person: Dictionary in d["people"]:
			if bool(person.get("alive", false)) and not bool(person.get("gone", false)):
				(d["experts"] as Array).append({"name": person["name"], "comm": person["comm"], "field": person["field"], "skill": person["skill"]})
	if d.get("log") is Dictionary:
		for key: String in d["log"].keys():
			if key != "restores":
				d["log"].erase(key)
	if d.get("stats") is Dictionary:
		for key: String in d["stats"].keys():
			if key not in ["restored", "tier3", "defective"]:
				d["stats"].erase(key)
	return out
