extends RefCounted
## Stop receipt builder. Legacy schema plus S1 stop v3 and field v4 contracts.

const STOCK_KEYS := ["coal", "food", "medicine", "luxury", "symbol", "info", "scrap", "wood", "cloth", "parts", "ammo_pistol", "ammo_shell", "ammo_craft"]
const PEOPLE_LISTS := ["sent", "injured", "bitten", "dead", "missing", "leftBehind", "rescued"]
## The six towns, and the five stops on the way (mine, lodge, sawmill, lake,
## summit: each its own kind, decision 423).
const PLACE_TYPES := ["freight", "houses", "hospital", "factory", "church", "office", "mine", "lodge", "sawmill", "lake", "summit"]
const SOURCES := ["direct", "auto"]
const END_REASONS := ["departed", "limit", "wiped"]
const REQUIRED := ["place", "time", "stock", "items", "people", "witnessed", "placeState", "promises"]
const OPTIONAL := ["source", "endReason", "decisions", "content_type", "version"]
const V3_REQUIRED := ["receiptId", "stopId", "goal", "extras"]
const V4_REQUIRED := ["departureId", "symbol", "fieldPromises"]
## v5 (s3_departure_receipt_contract.md 3): v4 + how each came back + the train's defence.
const V5_REQUIRED := ["crew", "defense"]
## v5 may also carry (s3 contract 3): the outer things put aboard at the platform, the lures
## that came back, the food put aboard by name before it melted into stock.food (J07: the pot
## reads its state by id). Left out when there are none.
const V5_OPTIONAL := ["wardrobeIn", "luresBack", "foodIn"]
## The v5 keys that are counts by id.
const V5_COUNTS := ["luresBack", "foodIn"]
## gearBack.wear's places: the wardrobe's (wear.gd OUTER_PLACES), the coat only when one is on.
const GEAR_WEAR_KEYS := ["jacket", "coat", "hands"]
const WARDROBE_ENTRY_KEYS := ["id", "condition", "holes"]
## What was done for a wound (s3 contract 3; quick: by a medic within two real minutes, body_injury 4).
const WOUND_TREATS := ["bandaged", "disinfected", "sutured", "splinted", "tourniquet", "pulled", "quick"]
const CREW_KEYS := ["person", "exhaustion", "hunger", "bodyUse", "gearBack"]
const DEFENSE_KEYS := ["held", "people", "hurt", "dead", "wounds"]
const GOAL_KINDS := ["coal", "food", "medicine", "materials", null]
const GROUPS := ["tail", "medtech", "guard", "front", "engine"]
const FIELD_PROMISE_KINDS := ["prologue", "skip_dispatch"]
const FRAGMENT_KINDS := ["engine", "med", "craft", "radio", "expedition"]
const MAX_SAFE_INTEGER := 9007199254740991
const WITNESS_KEYS := ["who", "what", "where", "when", "why", "witnesses"]
const WITNESS_OPTIONAL := ["id", "weight", "template"]
const WOUND_PARTS := ["head_neck", "torso", "arm_left", "arm_right", "leg_left", "leg_right"]
const WOUND_KINDS := ["scratch", "laceration", "deep", "embedded", "bite", "fracture", "amputation"]
const SERIOUS_KINDS := ["deep", "embedded", "fracture", "amputation"]   # these fold into people.injured (S1)
const CUT_PARTS := ["arm_left", "arm_right", "leg_left", "leg_right"]   # an amputation is of an arm or a leg
const ID_PATTERN := "^[a-z][a-z0-9_]*$"
const CLOCK_PATTERN := "^D[1-9][0-9]* ([01][0-9]|2[0-3]):[0-5][0-9]$"

var _place_id: String
var _place_type: String
var _variant: String
var _arrive: String = ""
var _depart: String = ""
var _stay_min: int = 0
var _stock: Dictionary = {}
var _gained: Array[String] = []
var _lost: Array[String] = []
var _people: Dictionary = {}
var _wounds: Array[Dictionary] = []
var _witnessed: Array[Dictionary] = []
var _looted: float = 0.0
var _risk: int = 0
var _place_extra: Dictionary = {}
var _promises: Array[Dictionary] = []
var _source: String = "direct"
var _end_reason: String = ""
var _decisions: Array[Dictionary] = []
var _has_v3: bool = false
var _has_v4: bool = false
var _receipt_id: String = ""
var _stop_id: String = ""
var _departure_id: String = ""
var _goal: Dictionary = {"kind": null, "required": 0, "earned": 0}
var _extras: Dictionary = {"documents": [], "symbolCount": 0, "fragments": [], "coreCount": 0}
var _symbol: Variant = null
var _field_promises: Array[Dictionary] = []
var _has_v5: bool = false
var _crew: Array[Dictionary] = []
var _defense: Dictionary = {}
var _wardrobe_in: Array = []
var _lures_back: Dictionary = {}
var _food_in: Dictionary = {}


func _init(place_id: String, place_type: String = "freight", variant: String = "s2_graybox") -> void:
	_place_id = place_id
	_place_type = place_type
	_variant = variant
	for list_name: String in PEOPLE_LISTS:
		_people[list_name] = [] as Array[String]


## Clocks must read like "D1 10:30"; a bad one is refused (returns false)
## and the stay never goes below zero.
func set_time(arrive: String, depart: String, stay_min: int) -> bool:
	var clock_re := RegEx.create_from_string(CLOCK_PATTERN)
	if clock_re.search(arrive) == null or clock_re.search(depart) == null:
		push_warning("receipt: bad clock %s / %s" % [arrive, depart])
		return false
	_arrive = arrive
	_depart = depart
	_stay_min = maxi(stay_min, 0)
	return true


## Adds a signed delta. Unknown keys are refused (returns false).
func add_stock(key: String, n: int) -> bool:
	if not STOCK_KEYS.has(key):
		return false
	_stock[key] = int(_stock.get(key, 0)) + n
	return true


func gain_item(id: String) -> bool:
	if not _id_ok(id):
		return false
	_gained.append(id)
	return true


func lose_item(id: String) -> bool:
	if not _id_ok(id):
		return false
	_lost.append(id)
	return true


## Adds a person to one list once. Unknown list names are refused.
func person(list_name: String, id: String) -> bool:
	if not _people.has(list_name) or not _id_ok(id):
		return false
	var list: Array[String] = _people[list_name]
	if not list.has(id):
		list.append(id)
	return true


## One wound of one person (body_injury 4.6). Refused for a bad id, part or kind, and
## for an amputation off the arms and legs (the field cuts only those, amputation.gd).
## It folds the way S1 expects: a bite also puts the person in bitten, a deep wound,
## an embedded one, a fracture or an amputation in injured. festering is written only when true.
## `treat` (WOUND_TREATS keys, the true ones kept) goes out on a v5 receipt only.
func add_wound(person_id: String, part: String, kind: String, festering: bool = false, treat: Dictionary = {}) -> bool:
	if not _id_ok(person_id) or not WOUND_PARTS.has(part) or not WOUND_KINDS.has(kind) \
			or (kind == "amputation" and not CUT_PARTS.has(part)):
		push_warning("receipt: wound refused (%s %s %s)" % [person_id, part, kind])
		return false
	var row := {"person": person_id, "part": part, "kind": kind}
	if festering:
		row["festering"] = true
	var done := {}
	for k: String in WOUND_TREATS:
		if bool(treat.get(k, false)):
			done[k] = true
	if not done.is_empty():
		row["treat"] = done
	_wounds.append(row)
	if kind == "bite":
		person("bitten", person_id)
	elif SERIOUS_KINDS.has(kind):
		person("injured", person_id)
	return true


## when_at: "D1 12:10" (field) or an integer segment (S1 chronicle style).
## template: an id the train reads the row by (e.g. "body_search", decision 423
## card 12), "" for none; both optional keys of the schema's witnessed rows.
func witness(who: String, what: String, where: String, when_at: Variant, why: String, witnesses: Array, template: String = "") -> bool:
	var id_re := RegEx.create_from_string(ID_PATTERN)
	var ok := _id_ok(who) and what != "" and where != "" and why != ""
	for x: Variant in witnesses:
		ok = ok and _witness_ok(x, id_re)
	if template != "":
		ok = ok and _id_ok(template)
	if not ok:
		push_warning("receipt: witness refused (%s)" % who)
		return false
	var row := {
		"who": who, "what": what, "where": where, "when": when_at, "why": why,
		"witnesses": witnesses.duplicate(true),
	}
	if template != "":
		row["template"] = template
	_witnessed.append(row)
	return true


## Records a choice; deciding the same id again replaces the earlier choice.
func decision(id: String, choice: String) -> bool:
	if not _id_ok(id) or not _id_ok(choice):
		return false
	for d: Dictionary in _decisions:
		if d["id"] == id:
			d["choice"] = choice
			return true
	_decisions.append({"id": id, "choice": choice})
	return true


func set_place_state(looted: float, risk: int) -> void:
	_looted = clampf(looted, 0.0, 1.0)
	_risk = maxi(risk, 0)


## Extra persistent place keys (e.g. "bridgeOder": "blocked").
func place_note(key: String, value: Variant) -> void:
	if key == "looted" or key == "remainingRisk":
		return
	_place_extra[key] = value


func set_end(reason: String) -> bool:
	if not END_REASONS.has(reason):
		return false
	_end_reason = reason
	return true


func set_source(source: String) -> bool:
	if not SOURCES.has(source):
		return false
	_source = source
	return true


## Receipts v1-v3 only: there the field itself said whether a promise was kept. A v4 receipt
## carries observations only (see_promise) and writes an empty promises list; S1 judges.
func promise(leader: String, condition: String, kept: bool) -> bool:
	if not _id_ok(leader) or not _id_ok(condition):
		return false
	_promises.append({"leader": leader, "condition": condition, "kept": kept})
	return true


## New setters opt into v3; a departure, symbol or seen promise opts into v4.
func set_ids(receipt_id: String, stop_id: String, departure_id: String = "") -> bool:
	if not _id_ok(receipt_id) or not _id_ok(stop_id):
		return false
	if departure_id != "" and not _id_ok(departure_id):
		return false
	_receipt_id = receipt_id
	_stop_id = stop_id
	_departure_id = departure_id
	_has_v3 = true
	_has_v4 = _has_v4 or departure_id != ""
	return true


func set_goal(kind: Variant, required: int, earned: int) -> bool:
	if not GOAL_KINDS.has(kind) or not _is_amount(required) or not _is_amount(earned):
		return false
	if kind == null and (required != 0 or earned != 0):
		return false
	_goal = {"kind": kind, "required": required, "earned": earned}
	_has_v3 = true
	return true


func set_extras(symbol_count: int, fragments: Array, core_count: int) -> bool:
	if not _is_amount(symbol_count) or not _is_amount(core_count):
		return false
	for fragment: Variant in fragments:
		if not FRAGMENT_KINDS.has(fragment):
			return false
	_extras = {"documents": _extras["documents"], "symbolCount": symbol_count, "fragments": fragments.duplicate(), "coreCount": core_count}
	_has_v3 = true
	return true


## A stop receipt (v3 or v4: it has its ids), the shape that carries documents.
func is_stop_receipt() -> bool:
	return _has_v3 or _has_v4


## A document found in the field (S1 info_documents.ts, extras.documents of a
## stop receipt): the note of a box hidden at the next stop (decision 423 card
## 10). Refused (false) when it is not one the contract knows, or twice.
func add_document(document: Dictionary) -> bool:
	var out: Array[String] = []
	_check_document(out, "document", document, RegEx.create_from_string(ID_PATTERN))
	for d: Dictionary in _extras["documents"]:
		if d.get("id") == document.get("id"):
			out.append("document: 같은 문서가 두 번 있음")
	if not out.is_empty():
		push_warning("receipt: document refused (%s)" % ", ".join(out))
		return false
	(_extras["documents"] as Array).append(document.duplicate(true))
	_has_v3 = true
	return true


func set_symbol(id: String, group_id: String, carried_by: String) -> bool:
	if not _id_ok(id) or not GROUPS.has(group_id) or not _id_ok(carried_by):
		return false
	_symbol = {"id": id, "groupId": group_id, "carriedBy": carried_by}
	_has_v4 = true
	return true


## Observations only. S1 decides whether the promise was kept or broken.
func see_promise(id: String, kind: String, witnesses: Array, heard_by: Array) -> bool:
	var id_re := RegEx.create_from_string(ID_PATTERN)
	if not _id_ok(id) or not FIELD_PROMISE_KINDS.has(kind):
		return false
	if not _is_id_list(witnesses, id_re, true) or not _is_group_list(heard_by):
		return false
	for seen: Dictionary in _field_promises:
		if seen["id"] == id:
			return false
	_field_promises.append({"id": id, "kind": kind, "witnesses": witnesses.duplicate(), "heardBy": heard_by.duplicate()})
	_has_v4 = true
	return true


## Problems with what has been built so far (check() on to_dict()).
## How one who boarded came back (v5): exhaustion and hunger 0..2, what the body was used for,
## the guns and things they brought back, and what they wear at the wardrobe's places (`wear`,
## wear.gd back_of; left out when not given: the train reads them as gone out). Opts the
## receipt into v5.
func set_crew_row(person_id: String, exhaustion: int, hunger: int, body_use: Dictionary = {}, hands: Array = [], items: Dictionary = {}, wear: Dictionary = {}) -> bool:
	if not _id_ok(person_id):
		return false
	for row: Dictionary in _crew:
		if row["person"] == person_id:
			_crew.erase(row)
			break
	var back := {"hands": hands.duplicate(true), "items": items.duplicate()}
	if not wear.is_empty():
		back["wear"] = wear.duplicate(true)
	_crew.append({"person": person_id, "exhaustion": clampi(exhaustion, 0, 2), "hunger": clampi(hunger, 0, 2),
			"bodyUse": body_use.duplicate(), "gearBack": back})
	_has_v5 = true
	return true


## The outer things put aboard at the platform ({id, condition, holes?} each, wear.gd
## to_wardrobe), for the train's wardrobe. On a v5 receipt only.
func set_wardrobe_in(rows: Array) -> void:
	_wardrobe_in = rows.duplicate(true)


## The lures that came back unspent, by kind. On a v5 receipt only.
func set_lures_back(by_kind: Dictionary) -> void:
	_lures_back = by_kind.duplicate()


## The food put aboard, by the field's id (fresh, wilted, spoiled, frozen, dented … in the id,
## food_cooking.md 2), as many as melted into stock.food: what it was, not more of it. On a v5
## receipt only.
func set_food_in(by_id: Dictionary) -> void:
	_food_in = by_id.duplicate()


## The train's defence at the stop (decision 416; the stop-sound stream fills it): those who
## stood at the train, who of them got hurt or died, their wounds. Opts the receipt into v5.
func set_defense(held: bool, people: Array, hurt: Array, dead: Array, wounds: Array = []) -> void:
	_defense = {"held": held, "people": people.duplicate(), "hurt": hurt.duplicate(), "dead": dead.duplicate(), "wounds": wounds.duplicate(true)}
	_has_v5 = true


func problems() -> Array[String]:
	return check(to_dict())


static func _id_ok(v: String) -> bool:
	if RegEx.create_from_string(ID_PATTERN).search(v) == null:
		push_warning("receipt: bad id '%s'" % v)
		return false
	return true


func to_dict() -> Dictionary:
	var stock := {}
	for key: String in STOCK_KEYS:
		if _stock.has(key):
			stock[key] = _stock[key]
	var people := {}
	for list_name: String in PEOPLE_LISTS:
		people[list_name] = (_people[list_name] as Array[String]).duplicate()
	var place_state := {"looted": _looted, "remainingRisk": _risk}
	for key: String in _place_extra:
		place_state[key] = _place_extra[key]
	var v5 := _has_v4 and (_has_v5 or _any_treat())
	if not _wounds.is_empty():
		people["wounds"] = _wounds.duplicate(true)
		if not v5:
			for w: Dictionary in people["wounds"]:
				w.erase("treat")
	# New contracts follow case1_symbol_kept.json; legacy insertion order is unchanged.
	var d: Dictionary = {}
	if _has_v3 or _has_v4:
		d["version"] = (5 if v5 else 4) if _has_v4 else 3
		d["receiptId"] = _receipt_id
		if _has_v4:
			d["departureId"] = _departure_id
		d["stopId"] = _stop_id
		d["source"] = _source
		if _end_reason != "":
			d["endReason"] = _end_reason
	d.merge({
		"place": {"id": _place_id, "type": _place_type, "variant": _variant},
		"time": {"arrive": _arrive, "depart": _depart, "stayGameMinutes": _stay_min},
		"stock": stock,
		"items": {"gained": _gained.duplicate(), "lost": _lost.duplicate()},
		"people": people,
		"witnessed": _witnessed.duplicate(true),
		"placeState": place_state,
		"promises": [] if _has_v4 else _promises.duplicate(true),  # v4: no field-side verdicts
	})
	if _has_v3 or _has_v4:
		if not _decisions.is_empty():
			d["decisions"] = _decisions.duplicate(true)
		var goal: Dictionary = _goal.duplicate()
		goal["status"] = _goal_status(goal["kind"], goal["required"], goal["earned"], _end_reason)
		d["goal"] = goal
		d["extras"] = _extras.duplicate(true)
		if _has_v4:
			d["symbol"] = _symbol.duplicate(true) if _symbol is Dictionary else null
			d["fieldPromises"] = _field_promises.duplicate(true)
		if v5:
			d["crew"] = _crew.duplicate(true)
			d["defense"] = _defense.duplicate(true) if not _defense.is_empty() else null
			if not _wardrobe_in.is_empty():
				d["wardrobeIn"] = _wardrobe_in.duplicate(true)
			if not _lures_back.is_empty():
				d["luresBack"] = _lures_back.duplicate()
			if not _food_in.is_empty():
				d["foodIn"] = _food_in.duplicate()
		return d
	if not _wounds.is_empty():
		d["version"] = 2
	d["source"] = _source
	if _end_reason != "":
		d["endReason"] = _end_reason
	if not _decisions.is_empty():
		d["decisions"] = _decisions.duplicate(true)
	return d


func _any_treat() -> bool:
	for w: Dictionary in _wounds:
		if w.has("treat"):
			return true
	return false


## Two-space indent, insertion (fixed) key order.
func to_json() -> String:
	return JSON.stringify(to_dict(), "  ", false)


## Where the wound rows and the person lists disagree (S1 folding, receipt.schema people.wounds).
## Dead, missing and left-behind people are skipped. Empty means they agree.
static func fold_gaps(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var p: Variant = d.get("people")
	if not (p is Dictionary and p.get("wounds") is Array):
		return out
	var gone: Array = []
	for key: String in ["dead", "missing", "leftBehind"]:
		gone.append_array(p.get(key, []))
	for w: Variant in p["wounds"]:
		if not (w is Dictionary) or gone.has(w.get("person")):
			continue
		var who: String = str(w.get("person"))
		var kind: String = str(w.get("kind"))
		if kind == "bite" and not (p.get("bitten", []) as Array).has(w.get("person")):
			out.append("%s bite not in bitten" % who)
		elif SERIOUS_KINDS.has(kind) and not (p.get("injured", []) as Array).has(w.get("person")):
			out.append("%s %s not in injured" % [who, kind])
	return out


## Thin shape check (no JSON Schema in GDScript). Returns problems; empty means OK.
## Accepts JSON-parsed input too (integers arrive as whole floats).
static func check(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var id_re := RegEx.create_from_string(ID_PATTERN)
	var clock_re := RegEx.create_from_string(CLOCK_PATTERN)
	var version: int = int(d.get("version", 1)) if _is_int(d.get("version", 1)) else 0
	var required: Array = REQUIRED.duplicate()
	if version == 3 or version == 4:
		required.append_array(V3_REQUIRED)
	if version == 5:
		required.append_array(V3_REQUIRED)
	if version >= 4:
		required.append_array(V4_REQUIRED)
	if version == 5:
		required.append_array(V5_REQUIRED)
	for key: String in required:
		if not d.has(key):
			out.append("%s: 없음" % key)
	for key: Variant in d:
		if not (required.has(key) or OPTIONAL.has(key) or (version == 5 and V5_OPTIONAL.has(key))):
			out.append("%s: 모르는 칸" % str(key))

	var place: Variant = d.get("place")
	if place is Dictionary:
		_no_extra(out, "place", place, ["id", "type", "variant"])
		for key: String in ["id", "variant"]:
			if not _is_id(place.get(key), id_re):
				out.append("place.%s: id 형식이 아님" % key)
		if not PLACE_TYPES.has(place.get("type")):
			out.append("place.type: 모르는 유형")
	elif d.has("place"):
		out.append("place: 사전이 아님")

	var time: Variant = d.get("time")
	if time is Dictionary:
		_no_extra(out, "time", time, ["arrive", "depart", "stayGameMinutes"])
		for key: String in ["arrive", "depart"]:
			var v: Variant = time.get(key)
			if not (v is String and clock_re.search(v) != null):
				out.append("time.%s: 'D1 10:30' 꼴이 아님" % key)
		var stay: Variant = time.get("stayGameMinutes")
		if not (_is_int(stay) and float(stay) >= 0.0):
			out.append("time.stayGameMinutes: 0 이상 정수가 아님")
	elif d.has("time"):
		out.append("time: 사전이 아님")

	var stock: Variant = d.get("stock")
	if stock is Dictionary:
		for key: Variant in stock:
			if not STOCK_KEYS.has(key):
				out.append("stock.%s: 모르는 키" % str(key))
			elif not _is_int(stock[key]):
				out.append("stock.%s: 정수가 아님" % str(key))
	elif d.has("stock"):
		out.append("stock: 사전이 아님")

	var items: Variant = d.get("items")
	if items is Dictionary:
		_no_extra(out, "items", items, ["gained", "lost"])
		for key: String in ["gained", "lost"]:
			if not _is_id_list(items.get(key), id_re, false):
				out.append("items.%s: id 목록이 아님" % key)
	elif d.has("items"):
		out.append("items: 사전이 아님")

	var people: Variant = d.get("people")
	if people is Dictionary:
		for key: String in PEOPLE_LISTS:
			if not _is_id_list(people.get(key), id_re, true):
				out.append("people.%s: 겹치지 않는 id 목록이 아님" % key)
		for key: Variant in people:
			if not (PEOPLE_LISTS.has(key) or key == "wounds"):
				out.append("people.%s: 모르는 목록" % str(key))
		if people.has("wounds"):
			_check_wounds(out, people["wounds"], id_re, version == 5)
			if not (_is_int(d.get("version")) and float(d.get("version")) >= 2.0):
				out.append("version: people.wounds가 있으면 2여야 함")
	elif d.has("people"):
		out.append("people: 사전이 아님")

	var witnessed: Variant = d.get("witnessed")
	if witnessed is Array:
		for i: int in (witnessed as Array).size():
			var w: Variant = witnessed[i]
			if not (w is Dictionary):
				out.append("witnessed.%d: 사전이 아님" % i)
				continue
			for key: String in WITNESS_KEYS:
				if not w.has(key):
					out.append("witnessed.%d.%s: 없음" % [i, key])
			_no_extra(out, "witnessed.%d" % i, w, WITNESS_KEYS + WITNESS_OPTIONAL)
			if w.has("id") and not _is_id(w["id"], id_re):
				out.append("witnessed.%d.id: id 형식이 아님" % i)
			if w.has("template") and not _is_id(w["template"], id_re):
				out.append("witnessed.%d.template: id 형식이 아님" % i)
			if w.has("weight") and not (_is_num(w["weight"]) and float(w["weight"]) >= 0.0):
				out.append("witnessed.%d.weight: 0 이상 수가 아님" % i)
			for key: String in ["what", "where", "why"]:
				if w.has(key) and not (w[key] is String and (w[key] as String) != ""):
					out.append("witnessed.%d.%s: 빈 글이 아니어야 함" % [i, key])
			if w.has("who") and not _is_id(w["who"], id_re):
				out.append("witnessed.%d.who: id 형식이 아님" % i)
			if w.has("when"):
				var at: Variant = w["when"]
				var ok_clock: bool = at is String and clock_re.search(at) != null
				if not (ok_clock or (_is_int(at) and float(at) >= 0.0)):
					out.append("witnessed.%d.when: 시각이나 구간 번호가 아님" % i)
			if w.has("witnesses"):
				if not (w["witnesses"] is Array):
					out.append("witnessed.%d.witnesses: 목록이 아님" % i)
				else:
					for j: int in (w["witnesses"] as Array).size():
						if not _witness_ok(w["witnesses"][j], id_re):
							out.append("witnessed.%d.witnesses.%d: id나 {person, text}가 아님" % [i, j])
	elif d.has("witnessed"):
		out.append("witnessed: 목록이 아님")

	var ps: Variant = d.get("placeState")
	if ps is Dictionary:
		var looted: Variant = ps.get("looted")
		if not (_is_num(looted) and float(looted) >= 0.0 and float(looted) <= 1.0):
			out.append("placeState.looted: 0~1 수가 아님")
		var risk: Variant = ps.get("remainingRisk")
		if not (_is_int(risk) and float(risk) >= 0.0):
			out.append("placeState.remainingRisk: 0 이상 정수가 아님")
	elif d.has("placeState"):
		out.append("placeState: 사전이 아님")

	var promises: Variant = d.get("promises")
	if promises is Array:
		for i: int in (promises as Array).size():
			var p: Variant = promises[i]
			if not (p is Dictionary and _is_id(p.get("leader"), id_re) and _is_id(p.get("condition"), id_re) and p.get("kept") is bool):
				out.append("promises.%d: leader·condition·kept가 맞지 않음" % i)
			elif p is Dictionary:
				_no_extra(out, "promises.%d" % i, p, ["leader", "condition", "kept"])
	elif d.has("promises"):
		out.append("promises: 목록이 아님")

	if d.has("source") and not SOURCES.has(d["source"]):
		out.append("source: direct 또는 auto가 아님")
	if d.has("endReason") and not END_REASONS.has(d["endReason"]):
		out.append("endReason: 모르는 끝")
	if d.has("decisions"):
		var decisions: Variant = d["decisions"]
		if decisions is Array:
			for i: int in (decisions as Array).size():
				var c: Variant = decisions[i]
				if not (c is Dictionary and _is_id(c.get("id"), id_re) and _is_id(c.get("choice"), id_re)):
					out.append("decisions.%d: id·choice가 맞지 않음" % i)
				elif c is Dictionary:
					_no_extra(out, "decisions.%d" % i, c, ["id", "choice"])
		else:
			out.append("decisions: 목록이 아님")
	if d.has("content_type") and d["content_type"] != "receipt":
		out.append("content_type: receipt가 아님")
	if d.has("version") and (version < 1 or version > 5):
		out.append("version: 1~5가 아님")
	if version >= 3:
		_check_stop_fields(out, d, id_re)
	if version >= 4:
		_check_field_fields(out, d, id_re)
	if version == 5:
		_check_v5_fields(out, d, id_re)
	return out


static func _check_v5_fields(out: Array[String], d: Dictionary, id_re: RegEx) -> void:
	var crew: Variant = d.get("crew")
	if not crew is Array:
		out.append("crew: 목록이 아님")
	else:
		for i: int in (crew as Array).size():
			var row: Variant = crew[i]
			if not row is Dictionary:
				out.append("crew.%d: 사전이 아님" % i)
				continue
			_no_extra(out, "crew.%d" % i, row, CREW_KEYS)
			if not _is_id(row.get("person"), id_re):
				out.append("crew.%d.person: id 형식이 아님" % i)
			for key: String in ["exhaustion", "hunger"]:
				if not (_is_int(row.get(key)) and float(row[key]) >= 0.0 and float(row[key]) <= 2.0):
					out.append("crew.%d.%s: 0~2가 아님" % [i, key])
			if not row.get("bodyUse") is Dictionary:
				out.append("crew.%d.bodyUse: 사전이 아님" % i)
			var back: Variant = row.get("gearBack")
			if not (back is Dictionary and back.get("hands") is Array and back.get("items") is Dictionary):
				out.append("crew.%d.gearBack: 꼴이 아님" % i)
			elif (back as Dictionary).has("wear"):
				_no_extra(out, "crew.%d.gearBack" % i, back, ["hands", "items", "wear"])
				var wear: Variant = back["wear"]
				if not (wear is Dictionary and wear.has("jacket") and wear.has("hands")):
					out.append("crew.%d.gearBack.wear: 꼴이 아님" % i)
				else:
					_no_extra(out, "crew.%d.gearBack.wear" % i, wear, GEAR_WEAR_KEYS)
					for place: Variant in wear:
						if not (wear[place] is String and wear[place] == "") and not _wardrobe_entry_ok(wear[place], id_re):
							out.append("crew.%d.gearBack.wear.%s: 옷장 꼴이 아님" % [i, str(place)])
	if d.has("wardrobeIn"):
		var rows: Variant = d["wardrobeIn"]
		if not rows is Array:
			out.append("wardrobeIn: 목록이 아님")
		else:
			for i: int in (rows as Array).size():
				if not _wardrobe_entry_ok(rows[i], id_re):
					out.append("wardrobeIn.%d: 옷장 꼴이 아님" % i)
	for key: String in V5_COUNTS:
		if not d.has(key):
			continue
		var counts: Variant = d[key]
		if not counts is Dictionary:
			out.append("%s: 사전이 아님" % key)
			continue
		for kind: Variant in counts:
			if not (_is_id(kind, id_re) and _is_int(counts[kind]) and float(counts[kind]) >= 0.0):
				out.append("%s.%s: 0 이상 정수가 아님" % [key, str(kind)])
	var defense: Variant = d.get("defense")
	if defense is Dictionary:
		_no_extra(out, "defense", defense, DEFENSE_KEYS)
		if not defense.get("held") is bool:
			out.append("defense.held: 참·거짓이 아님")
		for key: String in ["people", "hurt", "dead"]:
			if not _is_id_list(defense.get(key), id_re, true):
				out.append("defense.%s: 겹치지 않는 id 목록이 아님" % key)
		if defense.has("wounds"):
			_check_wounds(out, defense["wounds"], id_re, true)
	elif defense != null:
		out.append("defense: null이나 사전이 아님")


## Same precedence as S1 goalStatus, using this stop's earned amount (not stock).
static func _goal_status(kind: Variant, required: int, earned: int, end_reason: String) -> String:
	if end_reason == "wiped":
		return "failed"
	if kind == null:
		return "retreat"
	if earned >= required:
		return "done"
	return "part" if earned > 0 else "retreat"


static func _check_stop_fields(out: Array[String], d: Dictionary, id_re: RegEx) -> void:
	for key: String in ["receiptId", "stopId"]:
		if d.has(key) and not _is_id(d[key], id_re):
			out.append("%s: id 형식이 아님" % key)
	var goal: Variant = d.get("goal")
	if goal is Dictionary:
		for key: String in ["kind", "required", "earned", "status"]:
			if not goal.has(key):
				out.append("goal.%s: 없음" % key)
		_no_extra(out, "goal", goal, ["kind", "required", "earned", "status"])
		if goal.has("kind") and not GOAL_KINDS.has(goal["kind"]):
			out.append("goal.kind: 모르는 목표")
		for key: String in ["required", "earned"]:
			if goal.has(key) and not _is_amount(goal[key]):
				out.append("goal.%s: 0 이상 안전한 정수가 아님" % key)
		if goal.has("kind") and GOAL_KINDS.has(goal["kind"]) and _is_amount(goal.get("required")) and _is_amount(goal.get("earned")):
			if goal["kind"] == null and (goal["required"] != 0 or goal["earned"] != 0):
				out.append("goal: 목표가 없으면 required·earned는 0이어야 함")
			if goal.has("status") and goal["status"] != _goal_status(goal["kind"], int(goal["required"]), int(goal["earned"]), str(d.get("endReason", "departed"))):
				out.append("goal.status: 목표·획득량·끝과 맞지 않음")
	elif d.has("goal"):
		out.append("goal: 사전이 아님")
	var stock: Variant = d.get("stock")
	if stock is Dictionary:
		if stock.has("info"):
			out.append("stock.info: 판 3·4 문서는 extras.documents에 써야 함")
		for key: Variant in stock:
			if _is_int(stock[key]) and absf(float(stock[key])) > MAX_SAFE_INTEGER:
				out.append("stock.%s: 안전한 정수가 아님" % str(key))
	if d.has("extras"):
		_check_extras(out, d["extras"], id_re)


static func _check_extras(out: Array[String], extras: Variant, id_re: RegEx) -> void:
	if not (extras is Dictionary):
		out.append("extras: 사전이 아님")
		return
	var keys := ["documents", "symbolCount", "fragments", "coreCount"]
	for key: String in keys:
		if not extras.has(key):
			out.append("extras.%s: 없음" % key)
	_no_extra(out, "extras", extras, keys)
	for key: String in ["symbolCount", "coreCount"]:
		if extras.has(key) and not _is_amount(extras[key]):
			out.append("extras.%s: 0 이상 안전한 정수가 아님" % key)
	if extras.has("fragments"):
		if not (extras["fragments"] is Array):
			out.append("extras.fragments: 목록이 아님")
		else:
			for fragment: Variant in extras["fragments"]:
				if not FRAGMENT_KINDS.has(fragment):
					out.append("extras.fragments: 모르는 연구 분야")
	if extras.has("documents"):
		if not (extras["documents"] is Array):
			out.append("extras.documents: 목록이 아님")
		else:
			var seen: Dictionary = {}
			for i: int in extras["documents"].size():
				var document: Variant = extras["documents"][i]
				_check_document(out, "extras.documents.%d" % i, document, id_re)
				if document is Dictionary and _is_id(document.get("id"), id_re):
					if seen.has(document["id"]):
						out.append("extras.documents.%d.id: 같은 문서가 두 번 있음" % i)
					seen[document["id"]] = true


## Read-side v3 document schema; this builder only emits an empty documents list.
static func _check_document(out: Array[String], at: String, document: Variant, id_re: RegEx) -> void:
	if not (document is Dictionary):
		out.append("%s: 사전이 아님" % at)
		return
	var keys := ["id", "sourcePlaceId", "segment", "bodyKey", "choices", "targetId", "state", "kind"]
	var kind: Variant = document.get("kind")
	var detail_key: String = {"next_stop": "nextStop", "history": "history", "technology": "technology"}.get(str(kind), "")
	if detail_key != "":
		keys.append(detail_key)
	else:
		out.append("%s.kind: 모르는 문서" % at)
	for key: String in keys:
		if not document.has(key):
			out.append("%s.%s: 없음" % [at, key])
	_no_extra(out, at, document, keys)
	for key: String in ["id", "sourcePlaceId"]:
		if not _is_id(document.get(key), id_re):
			out.append("%s.%s: id 형식이 아님" % [at, key])
	if not _is_amount(document.get("segment")) or not (document.get("bodyKey") is String) or document.get("state") != "pending":
		out.append("%s: segment·bodyKey·state가 맞지 않음" % at)
	if not _is_id_list(document.get("choices"), id_re, true):
		out.append("%s.choices: 겹치지 않는 id 목록이 아님" % at)
	if (kind == "history" or document.get("targetId") != null) and not _is_id(document.get("targetId"), id_re):
		out.append("%s.targetId: id 형식이 아님" % at)
	if detail_key == "":
		return
	var detail: Variant = document.get(detail_key)
	if not (detail is Dictionary):
		out.append("%s.%s: 사전이 아님" % [at, detail_key])
		return
	var detail_keys: Array = {
		"next_stop": ["stopId", "observedSegment", "blankKey", "confirmed"],
		"history": ["conditionKey", "workKey", "objectKey", "allowedActionIds"],
		"technology": ["branchCandidates", "consumeAt"],
	}[kind]
	for key: String in detail_keys:
		if not detail.has(key):
			out.append("%s.%s.%s: 없음" % [at, detail_key, key])
	_no_extra(out, "%s.%s" % [at, detail_key], detail, detail_keys)
	var valid: bool = false
	if kind == "next_stop":
		valid = _is_id(detail.get("stopId"), id_re) and _is_amount(detail.get("observedSegment")) and _is_id(detail.get("blankKey"), id_re) and detail.get("confirmed") is bool
	elif kind == "history":
		valid = detail.get("conditionKey") is String and detail.get("workKey") is String and detail.get("objectKey") is String and _is_id_list(detail.get("allowedActionIds"), id_re, true)
	elif kind == "technology":
		valid = _is_id_list(detail.get("branchCandidates"), id_re, true) and (detail.get("consumeAt") == null or _is_id(detail.get("consumeAt"), id_re))
	if not valid:
		out.append("%s.%s: 문서 칸이 맞지 않음" % [at, detail_key])


static func _check_field_fields(out: Array[String], d: Dictionary, id_re: RegEx) -> void:
	if d.has("departureId") and not _is_id(d["departureId"], id_re):
		out.append("departureId: id 형식이 아님")
	var symbol: Variant = d.get("symbol")
	if symbol is Dictionary:
		_no_extra(out, "symbol", symbol, ["id", "groupId", "carriedBy"])
		for key: String in ["id", "carriedBy"]:
			if not _is_id(symbol.get(key), id_re):
				out.append("symbol.%s: id 형식이 아님" % key)
		if not GROUPS.has(symbol.get("groupId")):
			out.append("symbol.groupId: 모르는 집단")
		var stock: Variant = d.get("stock")
		if not (stock is Dictionary and _is_int(stock.get("symbol")) and float(stock["symbol"]) >= 1.0):
			out.append("stock.symbol: 상징물이 있으면 1 이상이어야 함")
	elif symbol != null:
		out.append("symbol: null이나 사전이 아님")
	if not d.has("fieldPromises"):
		return
	var promises: Variant = d["fieldPromises"]
	if not (promises is Array):
		out.append("fieldPromises: 목록이 아님")
		return
	var seen: Dictionary = {}
	for i: int in promises.size():
		var at: String = "fieldPromises.%d" % i
		var promise_seen: Variant = promises[i]
		if not (promise_seen is Dictionary):
			out.append("%s: 사전이 아님" % at)
			continue
		for key: String in ["id", "kind", "witnesses", "heardBy"]:
			if not promise_seen.has(key):
				out.append("%s.%s: 없음" % [at, key])
		_no_extra(out, at, promise_seen, ["id", "kind", "witnesses", "heardBy"])
		if not _is_id(promise_seen.get("id"), id_re):
			out.append("%s.id: id 형식이 아님" % at)
		else:
			if seen.has(promise_seen["id"]):
				out.append("%s.id: 같은 약속이 두 번 있음" % at)
			seen[promise_seen["id"]] = true
		if not FIELD_PROMISE_KINDS.has(promise_seen.get("kind")):
			out.append("%s.kind: 모르는 약속" % at)
		if not _is_id_list(promise_seen.get("witnesses"), id_re, true):
			out.append("%s.witnesses: 겹치지 않는 id 목록이 아님" % at)
		if not _is_group_list(promise_seen.get("heardBy")):
			out.append("%s.heardBy: 겹치지 않는 집단 목록이 아님" % at)


static func _is_amount(v: Variant) -> bool:
	return _is_int(v) and float(v) >= 0.0 and float(v) <= MAX_SAFE_INTEGER


static func _is_group_list(v: Variant) -> bool:
	if not (v is Array):
		return false
	var seen: Dictionary = {}
	for group: Variant in v:
		if not GROUPS.has(group) or seen.has(group):
			return false
		seen[group] = true
	return true


## Keys the schema does not list (additionalProperties: false).
static func _no_extra(out: Array[String], at: String, obj: Dictionary, allowed: Array) -> void:
	for key: Variant in obj:
		if not allowed.has(key):
			out.append("%s.%s: 모르는 칸" % [at, str(key)])


## A witness is an id, or {person: id, text: not empty}.
static func _witness_ok(v: Variant, id_re: RegEx) -> bool:
	if v is String:
		return _is_id(v, id_re)
	if not (v is Dictionary) or v.size() != 2:
		return false
	return _is_id(v.get("person"), id_re) and v.get("text") is String and (v.get("text") as String) != ""


## Receipt v2 per-part wounds (body_injury 4.6): {person, part, kind, festering?}, and on v5 treat?.
static func _check_wounds(out: Array[String], wounds: Variant, id_re: RegEx, treat_ok: bool = false) -> void:
	if not (wounds is Array):
		out.append("people.wounds: 목록이 아님")
		return
	for i: int in (wounds as Array).size():
		var w: Variant = wounds[i]
		if not (w is Dictionary):
			out.append("people.wounds.%d: 사전이 아님" % i)
			continue
		_no_extra(out, "people.wounds.%d" % i, w, ["person", "part", "kind", "festering", "treat"] if treat_ok else ["person", "part", "kind", "festering"])
		if w.has("treat"):
			if not w["treat"] is Dictionary:
				out.append("people.wounds.%d.treat: 사전이 아님" % i)
			else:
				for k: Variant in w["treat"]:
					if not WOUND_TREATS.has(k) or w["treat"][k] != true:
						out.append("people.wounds.%d.treat.%s: 모르는 처치" % [i, str(k)])
		if not _is_id(w.get("person"), id_re):
			out.append("people.wounds.%d.person: id 형식이 아님" % i)
		if not WOUND_PARTS.has(w.get("part")):
			out.append("people.wounds.%d.part: 모르는 부위" % i)
		if not WOUND_KINDS.has(w.get("kind")):
			out.append("people.wounds.%d.kind: 모르는 상처" % i)
		elif w.get("kind") == "amputation" and WOUND_PARTS.has(w.get("part")) and not CUT_PARTS.has(w.get("part")):
			out.append("people.wounds.%d.part: 팔·다리가 아닌 절단" % i)
		if w.has("festering") and not (w["festering"] is bool):
			out.append("people.wounds.%d.festering: 참·거짓이 아님" % i)


static func _is_num(v: Variant) -> bool:
	return v is int or v is float


## One wardrobe entry: {id, condition 0..1, holes?: {part: true}} (train_dom.gd).
static func _wardrobe_entry_ok(v: Variant, id_re: RegEx) -> bool:
	if not (v is Dictionary and _is_id(v.get("id"), id_re)):
		return false
	for key: Variant in v:
		if not WARDROBE_ENTRY_KEYS.has(key):
			return false
	var c: Variant = v.get("condition")
	if not ((c is float or c is int) and float(c) >= 0.0 and float(c) <= 1.0):
		return false
	if v.has("holes"):
		if not v["holes"] is Dictionary:
			return false
		for part: Variant in v["holes"]:
			if not (part is String and v["holes"][part] is bool and v["holes"][part]):
				return false
	return true


static func _is_int(v: Variant) -> bool:
	if v is int:
		return true
	return v is float and is_finite(v) and float(v) == floorf(v)


static func _is_id(v: Variant, id_re: RegEx) -> bool:
	return v is String and id_re.search(v) != null


static func _is_id_list(v: Variant, id_re: RegEx, unique: bool) -> bool:
	if not (v is Array):
		return false
	var seen := {}
	for item: Variant in v:
		if not _is_id(item, id_re):
			return false
		if unique and seen.has(item):
			return false
		seen[item] = true
	return true
