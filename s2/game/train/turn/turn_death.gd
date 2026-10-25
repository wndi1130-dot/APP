extends RefCounted
## Shared S1 death.ts + people.ts + wounds.ts death hook.
const C = preload("res://game/train/turn/turn_common.gd")
const St = preload("res://game/train/train_state.gd")
const People = preload("res://game/train/turn/turn_people.gd")

static func log_death(g: Dictionary, names: Array, cause: String, witness: bool = false, comm: String = "") -> void:
	if not g.has("deathLog"): g["deathLog"] = []
	for who: String in names:
		var row: Dictionary = {"seg": g["seg"], "name": who, "cause": cause}
		if witness: row["witness"] = true
		if comm != "": row["comm"] = comm
		g["deathLog"].append(row)

static func take_kin_body(g: Dictionary, t: Dictionary) -> void:
	var kin: Dictionary = g.get("pyreKin", {})
	for comm: String in t["COMMS"]:
		if int(kin.get(comm, 0)) <= 0: continue
		kin[comm] = int(kin[comm]) - 1
		g["comms"][comm]["base"][2] -= float(t["P"]["pyreKinCrowd"])
		return

static func on_death(g: Dictionary, t: Dictionary, comm: String, names: Array, cause: String = "other", witness: bool = false, quiet: bool = false) -> void:
	var n: int = names.size()
	if n <= 0: return
	var s: Dictionary = g["comms"][comm]
	s["pop"] = maxi(1, int(s["pop"]) - n)
	g["deaths"].append_array(names)
	log_death(g, names, cause, witness, comm)
	if not g.has("story"): g["story"] = {"stage": 1, "flags": {}}
	if not g["story"].has("flags"): g["story"]["flags"] = {}
	g["story"]["flags"]["first_death"] = true
	if St.law_active(g, "corpse_throw"): g["thrown"] += n
	elif St.law_active(g, "corpse_store"):
		g["stored"] += n
		g["comms"]["tail"]["base"][2] += n
	elif St.law_active(g, "corpse_burn"):
		var in_car: int = mini(n, maxi(0, int(t["P"]["coldCap"]) - int(g["stored"]) - int(g.get("pyre", 0))))
		g["pyre"] = int(g.get("pyre", 0)) + in_car
		var over: int = n - in_car
		if over > 0:
			if not g.has("pyreKin"): g["pyreKin"] = {}
			g["pyreKin"][comm] = int(g["pyreKin"].get(comm, 0)) + over
			s["base"][2] += float(t["P"]["pyreKinCrowd"]) * over
			C.journal(g, "냉동칸이 찼다. 시신 %d구를 %s에 둔다." % [over, t["COMM_NAME"][comm]], "dark")
	else:
		if not bool(g["corpseIssue"]):
			C.journal(g, "첫 시신을 두고 다툼이 났다. 시신 처리가 안건에 올랐다.", "bad")
			var flags: Dictionary = g["story"]["flags"]
			if not flags.has("first_corpse_agenda") or flags["first_corpse_agenda"] == "none": flags["first_corpse_agenda"] = "own"
		g["corpseIssue"] = true
		C.bump(g, "tension", 3 * n, "corpse")
		g["thrown"] += n
	if not quiet: C.journal(g, "%s의 %s이(가) 죽었다." % [t["COMM_NAME"][comm], ", ".join(names)], "bad")
	People.after_death(g, t, comm, names)
	if not g.has("wounds"): g["wounds"] = []
	var lost: int = 0
	for wound: Dictionary in g["wounds"]:
		if wound["state"] in ["bed", "home", "light"] and names.has(wound["who"]): lost += 1
	if lost > 0: g["injured"] = maxi(0, int(g["injured"]) - lost)
