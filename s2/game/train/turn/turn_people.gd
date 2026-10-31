extends RefCounted
## S1 people.ts; optional death-weight hooks are rejected by the action boundary.
const C = preload("res://game/train/turn/turn_common.gd")
const St = preload("res://game/train/train_state.gd")

static func add_card(g: Dictionary, card: Dictionary, t: Dictionary = {}) -> void:
	C.card(g, card, t)
	g["peopleSeg"] = g["seg"]

static func recent(g: Dictionary, t: Dictionary) -> bool:
	if int(g.get("peopleSeg", -99)) >= int(g["seg"]) - 1: return true
	for row: Dictionary in g["cards"]:
		if t["PEOPLE_KINDS"].has(row["kind"]): return true
	return false

static func family(g: Dictionary, t: Dictionary, who: String) -> Dictionary:
	var person: Dictionary = C.profile(t, who)
	if person.is_empty(): return {}
	for fam: Dictionary in t.get("FAMILIES", []):
		if not fam["parents"].has(person["id"]) and not fam["children"].has(person["id"]): continue
		var kids: Array = []
		var others: Array = []
		for id: String in fam["parents"] + fam["children"]:
			var p: Dictionary = C.profile(t, id, "id")
			if p.is_empty() or St.is_gone(g, p["name"]) or p["name"] == who: continue
			others.append(p)
			if fam["children"].has(id) and int(p["age"]) < 16: kids.append(p)
		return {"fam": fam, "isParent": fam["parents"].has(person["id"]), "kids": kids, "others": others}
	return {}

static func after_death(g: Dictionary, t: Dictionary, comm: String, names: Array) -> void:
	var known: Array = []
	for who: String in names:
		if not C.profile(t, who).is_empty() and not C.is_leader(g, t, who): known.append(who)
	for who: String in known:
		var f: Dictionary = family(g, t, who)
		for p: Dictionary in f.get("others", []):
			var kept: Array = []
			for m: Dictionary in g.get("mourning", []):
				if m["name"] != p["name"]: kept.append(m)
			kept.append({"name": p["name"], "comm": p["community"], "until": int(g["seg"]) + 2})
			g["mourning"] = kept
	if known.is_empty() or C.has_card(g, "orphan"): return
	var parent: String = ""
	for who: String in known:
		var f: Dictionary = family(g, t, who)
		if bool(f.get("isParent", false)) and not f["kids"].is_empty():
			parent = who
			break
	for row: Dictionary in g["cards"]:
		if row["kind"] == "keepsake":
			if parent != "":
				row.merge({"kind": "orphan", "comm": comm, "who": parent}, true)
				row.erase("text")
			return
	var card: Dictionary = {"kind": "orphan" if parent != "" else "keepsake", "comm": comm, "who": parent if parent != "" else known[0]}
	if parent == "" and g["phase"] == "stop": card["text"] = "field"
	add_card(g, card, t)

static func victim_weight(g: Dictionary, t: Dictionary, p: Dictionary, cause: String) -> float:
	var age: int = int(p["age"])
	if cause == "wound":
		if age < 16 or age > 65: return 0
		return (1.6 if age >= 50 else 1.0) * (1.5 if St.law_active(g, "triage") and age >= 50 else 1.0)
	var w: float = 3.0 if age >= 65 else (2.5 if age <= 10 else 1.0)
	if St.law_active(g, "contribution_ration") and (age >= 65 or age < 16): w *= 1.5
	if St.law_active(g, "common_kitchen") and (age >= 65 or age <= 10): w *= 0.6
	return w * maxf(0.3, (100.0 - St.situation(g, t, p["community"])[1]) / 50.0)

static func pick_victims(g: Dictionary, t: Dictionary, n: int, cause: String, random: Dictionary) -> Array:
	var pool: Array = []
	for p: Dictionary in t["PROFILES"]:
		if St.is_gone(g, p["name"]) or C.is_leader(g, t, p["name"]): continue
		var w: float = victim_weight(g, t, p, cause)
		if w > 0: pool.append({"p": p, "w": w})
	var out: Array = []
	for _k: int in n:
		if pool.is_empty(): break
		var total: float = 0
		for row: Dictionary in pool: total += float(row["w"])
		var draw: float = C.rnd(random) * total
		var i: int = 0
		while i < pool.size() - 1 and draw >= float(pool[i]["w"]):
			draw -= float(pool[i]["w"])
			i += 1
		out.append(pool[i]["p"])
		pool.remove_at(i)
	return out

static func recover(g: Dictionary, t: Dictionary, comm: String, why: String) -> void:
	var s: Dictionary = g["comms"][comm]
	if not s.get("sick") is Dictionary: return
	if St.is_gone(g, s["sick"]["rep"]["name"]):
		C.journal(g, "%s이(가) %s 대표 자리를 이었다." % [s["leader"]["name"], t["COMM_NAME"][comm]], "dark")
		s.erase("sick")
		s["debt"] = false
		return
	C.journal(g, "%s이(가) %s 다시 대표 자리에 앉았다." % [s["sick"]["rep"]["name"], why], "good")
	s["leader"] = s["sick"]["rep"]
	s.erase("sick")

static func fall_sick(g: Dictionary, t: Dictionary, comm: String) -> void:
	var pool: Array = []
	var fallback: Array = []
	for p: Dictionary in t["PROFILES"]:
		if p["community"] != comm or St.is_gone(g, p["name"]): continue
		fallback.append(p)
		if not g["usedProfiles"].has(p["id"]) and int(p["age"]) >= 25 and int(p["age"]) <= 60: pool.append(p)
	if pool.is_empty(): pool = fallback
	var person: Dictionary = pool[int(floor(C.rnd(g) * pool.size()))]
	if not g["usedProfiles"].has(person["id"]): g["usedProfiles"].append(person["id"])
	var s: Dictionary = g["comms"][comm]
	var rep_trait: String = s["leader"]["trait"]
	var shift: Array = ["ambition", "greed"] if rep_trait in ["fear", "family"] else (t["TRAITS"] as Array).filter(func(x: String) -> bool: return x != rep_trait)
	var proxy_trait: String = "ambition"
	for trait_id: String in shift:
		if trait_id != t["TRAIT_BAN"].get(comm):
			proxy_trait = trait_id
			break
	s["sick"] = {"since": g["seg"], "rep": s["leader"]}
	s["leader"] = {"personId": person["id"], "name": person["name"], "age": person["age"], "trait": proxy_trait, "traitShown": 0}
	g["sickCount"] = int(g.get("sickCount", 0)) + 1
	add_card(g, {"kind": "rep_sick", "comm": comm}, t)
	C.journal(g, "%s 대표 %s이(가) 앓아누웠다. 회기엔 %s이(가) 대신 나온다." % [t["COMM_NAME"][comm], s["sick"]["rep"]["name"], person["name"]], "bad")

static func sick_tick(g: Dictionary, t: Dictionary) -> void:
	for comm: String in t["COMMS"]:
		var s: Dictionary = g["comms"][comm]
		var sit: Array = St.situation(g, t, comm)
		var low: bool = float(sit[0]) < 38 or float(sit[1]) < 38
		s["lowStreak"] = int(s.get("lowStreak", 0)) + 1 if low else 0
		if s.get("sick") is Dictionary:
			if St.is_gone(g, s["sick"]["rep"]["name"]): recover(g, t, comm, "")
			elif not low: recover(g, t, comm, "처지가 나아지자")
			elif int(g["seg"]) - int(s["sick"]["since"]) >= 3:
				C.journal(g, "%s은(는) 끝내 일어나지 못했다. %s이(가) %s 대표 자리를 이었다." % [s["sick"]["rep"]["name"], s["leader"]["name"], t["COMM_NAME"][comm]], "dark")
				s.erase("sick")
				s["debt"] = false
			continue
		if int(g.get("sickCount", 0)) < 2 and int(s["lowStreak"]) >= 2 and not C.has_card(g, "rep_sick") and C.rnd(g) < 0.3: fall_sick(g, t, comm)

static func elder_tick(g: Dictionary, t: Dictionary) -> void:
	var held: Variant = g.get("elderHeld")
	if held is Dictionary:
		if int(g["seg"]) > int(held["until"]) or St.is_gone(g, held["who"]): g["elderHeld"] = null
		elif g["seg"] != held["at"] and float(g["food"]) < 20 and C.rnd(g) < 0.3:
			g["elderHeld"] = null
			g["comms"][held["comm"]]["pop"] = maxi(1, int(g["comms"][held["comm"]]["pop"]) - 1)
			C.bump_rel(g, held["comm"], -5, "elder")
			if not g.has("left"): g["left"] = []
			g["left"].append(held["who"])
			C.journal(g, "%s이(가) 밤에 혼자 내렸다." % held["who"], "dark")
	if bool(g.get("elderAsked", false)) or not (float(g["food"]) < 20 or St.situation(g, t, "tail")[1] < 30): return
	var tail_old: Dictionary = {}
	var other_old: Dictionary = {}
	for p: Dictionary in t["PROFILES"]:
		if St.is_gone(g, p["name"]) or C.is_leader(g, t, p["name"]): continue
		if p["community"] == "tail" and int(p["age"]) >= 65 and (tail_old.is_empty() or int(p["age"]) > int(tail_old["age"])): tail_old = p
		if int(p["age"]) >= 60 and (other_old.is_empty() or int(p["age"]) > int(other_old["age"])): other_old = p
	var elder: Dictionary = tail_old if not tail_old.is_empty() else other_old
	if elder.is_empty(): return
	g["elderAsked"] = true
	add_card(g, {"kind": "elder", "comm": elder["community"], "who": elder["name"]}, t)

static func birth_tick(g: Dictionary, t: Dictionary) -> void:
	var h: int = C.hash_text(str(g["seed"]) + ":birth")
	if g.get("born") != null or float(h % 1000) / 1000 >= 0.4 or int(g["seg"]) != 8 + (int(floor(float(h) / 1000)) % 11): return
	var comm: String = "front" if C.hash_text(str(g["seed"]) + ":birth:comm") % 3 == 0 else "tail"
	var mother: Dictionary = {}
	for fam: Dictionary in t["FAMILIES"]:
		if fam["community"] != comm: continue
		for id: String in fam["parents"]:
			var p: Dictionary = C.profile(t, id, "id")
			if not p.is_empty() and p["gender"] == "female" and not St.is_gone(g, p["name"]) and int(p["age"]) >= 18 and int(p["age"]) <= 42:
				mother = p
				break
		if not mother.is_empty(): break
	if mother.is_empty():
		for p: Dictionary in t["PROFILES"]:
			if p["community"] == comm and p["gender"] == "female" and not St.is_gone(g, p["name"]) and int(p["age"]) >= 18 and int(p["age"]) <= 40:
				mother = p
				break
	if mother.is_empty(): return
	g["born"] = {"comm": comm, "mother": mother["name"], "weak": false, "left": 0}
	add_card(g, {"kind": "birth", "comm": comm, "who": mother["name"]}, t)

static func tick(g: Dictionary, t: Dictionary) -> void:
	var kept: Array = []
	for temp: Dictionary in g.get("tempBase", []):
		if int(g["seg"]) < int(temp["until"]): kept.append(temp)
		else: g["comms"][temp["c"]]["base"][int(temp["i"])] -= float(temp["v"])
	g["tempBase"] = kept
	var baby: Variant = g.get("born")
	if baby is Dictionary and bool(baby["weak"]) and int(baby["left"]) > 0:
		if float(g["med"]) >= 1:
			C.bump(g, "med", -1, "sick")
			baby["left"] -= 1
			if int(baby["left"]) == 0:
				baby["weak"] = false
				add_card(g, {"kind": "naming", "comm": baby["comm"], "who": baby["mother"]}, t)
				C.journal(g, "%s의 아이가 고비를 넘겼다." % baby["mother"], "good")
		else:
			baby["left"] = 0
			baby["lost"] = true
			g["comms"][baby["comm"]]["pop"] = maxi(1, int(g["comms"][baby["comm"]]["pop"]) - 1)
			C.journal(g, "%s의 아이는 그 겨울을 넘기지 못했다." % baby["mother"], "dark")
	sick_tick(g, t)
	elder_tick(g, t)
	birth_tick(g, t)
