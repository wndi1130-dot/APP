extends RefCounted
## What one person remembers (J13, decision 439 cards 1-2): a port of the parts of
## s1/src/game/memory.ts that the train runs here, gathering at a field return (from_return) and
## what the departure sheet carries (departure_memory). The same state and receipt give the same
## g["memory"] and chronicle rows (tests/politics/test_field_port.gd against field_vectors.json).
## A memory changes only that person's words, departure and look back: never a car's rel, the
## tension or the trust. Nobody knows how a thing happened unless one who saw it came back.

const CAPTAIN_ID := "captain"
const GOOD := 3
const BAD := -3
## Light things (treated, a raider let go, the people at a stop) last this many stretches.
const SHORT := 3
const CUES := 3
const SAVE_TEMPLATES := {
	"rescued_from_grab": {"detail": "grab", "prefix": "freed_"},
	"carried_back": {"detail": "carry", "prefix": "carried_"},
	"treated_by": {"detail": "treat", "prefix": "treated_"},
}
const SAVE_W := {"grab": {"chief": 3, "mate": 2}, "carry": {"chief": 3, "mate": 2}, "treat": {"chief": 1, "mate": 1}}
const LEFT_W := -2
const SHOT_W := -2
const KIN_LEFT_W := -2
const VOICES := ["fear", "rough", "quiet"]
## The same thing weighs differently by voice and healing skill, never by car or birthplace.
const MERCY_W := {"medic": 1, "fear": 0, "rough": -1, "quiet": 0}
const RESIDENT_W := {
	"aid": {"medic": 1, "fear": 0, "rough": 1, "quiet": 1},
	"robbed": {"medic": -2, "fear": 0, "rough": -1, "quiet": -1},
	"ignored": {"medic": -1, "fear": 0, "rough": 0, "quiet": -1},
}
const CHRONICLE_KINDS := ["saved_me", "left_me", "saw_shot_surrendered", "lost_kin", "saw_resident_robbed", "saw_resident_aid"]


## FNV-1a over UTF-16 units, as memory.ts hash (Math.imul then >>> 0).
static func _hash(s: String) -> int:
	var x := 2166136261
	for i: int in s.length():
		x = ((x ^ s.unicode_at(i)) * 16777619) & 0xFFFFFFFF
	return x


static func voice_of(pid: String) -> String:
	return String(VOICES[_hash(pid + ":voice") % VOICES.size()])


static func _departure_people(d: Dictionary) -> Array:
	if int(d["version"]) == 2:
		return (d["roster"] as Array) + (d["workCrew"] as Array)
	return d["roster"]


static func _is_medic(d: Dictionary, pid: String) -> bool:
	if int(d["version"]) != 2:
		return false
	for p: Dictionary in _departure_people(d):
		var know: Variant = p.get("know")
		if String(p["id"]) == pid and know is Dictionary and String(know["field"]) == "med" and float(know["skill"]) >= 1.0:
			return true
	return false


static func _weigh(d: Dictionary, pid: String, table: Dictionary) -> int:
	return int(table["medic"]) if _is_medic(d, pid) else int(table[voice_of(pid)])


static func _witness_ids(row: Dictionary) -> Array:
	var out: Array = []
	for w: Variant in row.get("witnesses", []):
		if w is String:
			out.append(w)
		elif w is Dictionary and (w as Dictionary).get("person") is String:
			out.append(w["person"])
	return out


static func _str(v: Variant) -> String:
	return v if v is String else ""


static func _is_gone(g: Dictionary, name: String) -> bool:
	return (g.get("deaths", []) as Array).has(name) or (g.get("left", []) as Array).has(name)


static func _profile(t: Dictionary, pid: String) -> Dictionary:
	for p: Dictionary in t["PROFILES"]:
		if String(p["id"]) == pid:
			return p
	return {}


## The first of a person's family still on the train (decision 439 card 1), as memory.ts kinOf.
static func kin_of(g: Dictionary, t: Dictionary, pid: String) -> String:
	var p := _profile(t, pid)
	if p.is_empty():
		return ""
	for fam: Dictionary in t.get("FAMILIES", []):
		if not ((fam["parents"] as Array).has(pid) or (fam["children"] as Array).has(pid)):
			continue
		for id: Variant in (fam["parents"] as Array) + (fam["children"] as Array):
			var q := _profile(t, String(id))
			if not q.is_empty() and not _is_gone(g, String(q["name"])) and q["name"] != p["name"]:
				return String(q["id"])
		return ""
	return ""


static func _book(g: Dictionary) -> Dictionary:
	if not g.get("memory") is Dictionary:
		g["memory"] = {"rows": [], "applied": [], "spent": []}
	return g["memory"]


## Gathers memories from one return (memory.ts memoryFromReturn). Once a receipt id. `returned`:
## who boarded alive (field_return.gd returned_of; passed in so the two files need not load each other).
static func from_return(g: Dictionary, t: Dictionary, departure: Dictionary, receipt: Dictionary, returned: Array) -> Array:
	var book := _book(g)
	if (book["applied"] as Array).has(receipt["receiptId"]):
		return []
	(book["applied"] as Array).append(receipt["receiptId"])
	var back := {}
	for pid: String in returned:
		back[pid] = true
	var back_list: Array = back.keys()
	var known := {}
	for p: Dictionary in _departure_people(departure):
		known[String(p["id"])] = true
	var rescued: Array = receipt["people"]["rescued"]
	var where: String = receipt["place"]["id"]
	var seg: Variant = g["seg"]
	var out: Array = []
	var gone := {}
	for key: String in ["dead", "missing", "leftBehind"]:
		for pid: String in receipt["people"][key]:
			gone[pid] = true
	var rows: Array = receipt["witnessed"]

	for row: Dictionary in rows:
		var what := _str(row.get("what"))
		var template := _str(row.get("template"))
		if template == "" and what == "shot_surrendered_raider":
			template = "shot_surrendered_raider"
		var doer := _str(row.get("who"))
		var seen := _back_witnesses(row, back, known, rescued)
		if SAVE_TEMPLATES.has(template):
			var save: Dictionary = SAVE_TEMPLATES[template]
			if not what.begins_with(save["prefix"]):
				continue
			var victim := what.substr(String(save["prefix"]).length())
			var by_chief := doer == CAPTAIN_ID
			_add(out, back, seg, where, {
				"who": victim, "kind": "saved_me" if by_chief else "saved_by", "about": doer, "how": "seen", "from": [],
				"detail": save["detail"], "weight": SAVE_W[save["detail"]]["chief" if by_chief else "mate"],
				"until": seg + SHORT if save["detail"] == "treat" else null,
			})
			continue
		if template == "left_behind_survived" and what.begins_with("left_"):
			_add(out, back, seg, where, {"who": what.substr(5), "kind": "left_me", "about": CAPTAIN_ID, "how": "seen", "from": [], "weight": LEFT_W, "until": null})
			continue
		if template == "shot_surrendered_raider" or template == "spared_raider":
			for w: String in seen:
				if template == "shot_surrendered_raider":
					_add(out, back, seg, where, {"who": w, "kind": "saw_shot_surrendered", "about": doer, "how": "seen", "from": [], "weight": SHOT_W, "until": null})
				else:
					_add(out, back, seg, where, {"who": w, "kind": "saw_mercy", "about": doer, "how": "seen", "from": [], "detail": what, "weight": _weigh(departure, w, MERCY_W), "until": seg + SHORT})
			continue
		if template in ["resident_aid", "resident_robbed", "resident_ignored"]:
			var outcome := template.substr("resident_".length())
			for w: String in seen:
				if w == doer:
					continue
				_add(out, back, seg, where, {
					"who": w, "kind": "saw_resident_" + outcome, "about": doer, "how": "seen", "from": [], "detail": what,
					"weight": _weigh(departure, w, RESIDENT_W[outcome]), "until": null if outcome == "robbed" else seg + SHORT,
				})

	# Those who saw one fall, and one of the family of each who did not come back.
	for pid: String in gone.keys():
		var about: Array = []
		for row: Dictionary in rows:
			if _str(row.get("who")) == pid or _str(row.get("what")).ends_with("_" + pid):
				about.append(row)
		var saw: Array = []
		var seen_by_gone := false
		var chief_near := false
		for row: Dictionary in about:
			for w: String in _back_witnesses(row, back, known, rescued):
				if w != pid and w != CAPTAIN_ID and not saw.has(w):
					saw.append(w)
			for w: String in _witness_ids(row):
				if w != pid and w != CAPTAIN_ID and gone.has(w):
					seen_by_gone = true
			if _str(row.get("who")) == CAPTAIN_ID or _witness_ids(row).has(CAPTAIN_ID):
				chief_near = true
		for w: String in saw:
			_add(out, back, seg, where, {"who": w, "kind": "saw_fall", "about": CAPTAIN_ID, "subject": pid, "how": "seen", "from": [], "weight": 0, "until": null})
		var detail := "dead" if (receipt["people"]["dead"] as Array).has(pid) else ("left" if (receipt["people"]["leftBehind"] as Array).has(pid) else "missing")
		var kin := kin_of(g, t, pid)
		if kin == "":
			continue
		var mates: Array = []
		for x: String in back_list:
			if x != CAPTAIN_ID and x != kin and known.has(x):
				mates.append(x)
		var from: Array = []
		if detail == "left":
			from = mates
		else:
			for x: String in saw:
				if x != kin:
					from.append(x)
		var how := "seen" if saw.has(kin) else ("told" if not from.is_empty() else "unknown")
		var row := {
			"who": kin, "kind": "lost_kin", "about": CAPTAIN_ID, "subject": pid, "seg": seg, "where": where, "how": how,
			"from": from if how == "told" else [], "detail": detail,
			"weight": KIN_LEFT_W if detail == "left" and how != "unknown" else 0, "until": null,
		}
		if how != "unknown" and chief_near:
			row["chiefNear"] = true
		if how == "unknown" and seen_by_gone:
			row["seenByGone"] = true
		out.append(row)

	(book["rows"] as Array).append_array(out)
	for m: Dictionary in out:
		_chronicle(g, m)
	return out


static func _back_witnesses(row: Dictionary, back: Dictionary, known: Dictionary, rescued: Array) -> Array:
	var out: Array = []
	for w: String in _witness_ids(row):
		if back.has(w) and (known.has(w) or rescued.has(w)):
			out.append(w)
	return out


## One who holds a memory came back alive; the chief holds none. A family memory is kept on the train.
static func _add(out: Array, back: Dictionary, seg: Variant, where: String, m: Dictionary) -> void:
	if m["who"] == CAPTAIN_ID or not back.has(m["who"]) and m["kind"] != "lost_kin":
		return
	m["seg"] = seg
	m["where"] = where
	out.append(m)


static func _chronicle(g: Dictionary, m: Dictionary) -> void:
	if not CHRONICLE_KINDS.has(m["kind"]):
		return
	if not g.get("chronicle") is Array:
		g["chronicle"] = []
	(g["chronicle"] as Array).append({
		"template": "s3." + String(m["kind"]), "who": m["who"], "where": m["where"], "when": m["seg"],
		"witnesses": [m["who"]] if m["how"] == "seen" else (m["from"] as Array).duplicate(), "from": "s3",
	})


static func _live(g: Dictionary, m: Dictionary) -> bool:
	return m["until"] == null or float(m["until"]) >= float(g["seg"])


static func _memories_of(g: Dictionary, pid: String) -> Array:
	var out: Array = []
	var book: Variant = g.get("memory")
	if not book is Dictionary:
		return out
	for m: Dictionary in book["rows"]:
		if m["who"] == pid and _live(g, m):
			out.append(m)
	return out


## What the departure sheet carries for one person (memory.ts departureMemory): an own standing
## with the chief past the thresholds, and the newest memory keys. Empty for no memory.
static func departure_memory(g: Dictionary, pid: String) -> Dictionary:
	var rows := _memories_of(g, pid)
	var score := 0
	for m: Dictionary in rows:
		if m["about"] == CAPTAIN_ID:
			score += int(m["weight"])
	# Newest first; ties keep the order they were kept in (Array.sort is stable in the TS port).
	var order: Array = []
	for i: int in rows.size():
		order.append([i, rows[i]])
	order.sort_custom(func(a: Array, b: Array) -> bool:
		var sa := float(a[1]["seg"])
		var sb := float(b[1]["seg"])
		return sa > sb if sa != sb else int(a[0]) < int(b[0]))
	var cues: Array = []
	for pair: Array in order:
		var m: Dictionary = pair[1]
		var key: String = "saved_by:" + String(m["about"]) if m["kind"] == "saved_by" else String(m["kind"])
		if not cues.has(key):
			cues.append(key)
	var out := {}
	if score >= GOOD:
		out["stance"] = "good"
	elif score <= BAD:
		out["stance"] = "bad"
	if not cues.is_empty():
		out["cues"] = cues.slice(0, CUES)
	return out
