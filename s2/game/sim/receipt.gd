extends RefCounted
## Stop receipt builder (field_unified 8). Shape matches s1/schema/receipt.schema.json.

const STOCK_KEYS := ["coal", "food", "medicine", "luxury", "symbol", "info", "scrap", "wood", "ammo_pistol", "ammo_shell", "ammo_craft"]
const PEOPLE_LISTS := ["sent", "injured", "bitten", "dead", "missing", "leftBehind", "rescued"]
const PLACE_TYPES := ["freight", "houses", "hospital", "factory", "church", "office"]
const SOURCES := ["direct", "auto"]
const END_REASONS := ["departed", "limit", "wiped"]
const REQUIRED := ["place", "time", "stock", "items", "people", "witnessed", "placeState", "promises"]
const OPTIONAL := ["source", "endReason", "decisions", "content_type"]
const WITNESS_KEYS := ["who", "what", "where", "when", "why", "witnesses"]
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
var _witnessed: Array[Dictionary] = []
var _looted: float = 0.0
var _risk: int = 0
var _place_extra: Dictionary = {}
var _promises: Array[Dictionary] = []
var _source: String = "direct"
var _end_reason: String = ""
var _decisions: Array[Dictionary] = []


func _init(place_id: String, place_type: String = "freight", variant: String = "s2_graybox") -> void:
	_place_id = place_id
	_place_type = place_type
	_variant = variant
	for list_name: String in PEOPLE_LISTS:
		_people[list_name] = [] as Array[String]


func set_time(arrive: String, depart: String, stay_min: int) -> void:
	_arrive = arrive
	_depart = depart
	_stay_min = stay_min


## Adds a signed delta. Unknown keys are refused (returns false).
func add_stock(key: String, n: int) -> bool:
	if not STOCK_KEYS.has(key):
		return false
	_stock[key] = int(_stock.get(key, 0)) + n
	return true


func gain_item(id: String) -> void:
	_gained.append(id)


func lose_item(id: String) -> void:
	_lost.append(id)


## Adds a person to one list once. Unknown list names are refused.
func person(list_name: String, id: String) -> bool:
	if not _people.has(list_name):
		return false
	var list: Array[String] = _people[list_name]
	if not list.has(id):
		list.append(id)
	return true


## when_at: "D1 12:10" (field) or an integer segment (S1 chronicle style).
func witness(who: String, what: String, where: String, when_at: Variant, why: String, witnesses: Array) -> void:
	_witnessed.append({
		"who": who, "what": what, "where": where, "when": when_at, "why": why,
		"witnesses": witnesses.duplicate(true),
	})


## Records a choice; deciding the same id again replaces the earlier choice.
func decision(id: String, choice: String) -> void:
	for d: Dictionary in _decisions:
		if d["id"] == id:
			d["choice"] = choice
			return
	_decisions.append({"id": id, "choice": choice})


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


func promise(leader: String, condition: String, kept: bool) -> void:
	_promises.append({"leader": leader, "condition": condition, "kept": kept})


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
	var d := {
		"place": {"id": _place_id, "type": _place_type, "variant": _variant},
		"time": {"arrive": _arrive, "depart": _depart, "stayGameMinutes": _stay_min},
		"stock": stock,
		"items": {"gained": _gained.duplicate(), "lost": _lost.duplicate()},
		"people": people,
		"witnessed": _witnessed.duplicate(true),
		"placeState": place_state,
		"promises": _promises.duplicate(true),
		"source": _source,
	}
	if _end_reason != "":
		d["endReason"] = _end_reason
	if not _decisions.is_empty():
		d["decisions"] = _decisions.duplicate(true)
	return d


## Two-space indent, insertion (fixed) key order.
func to_json() -> String:
	return JSON.stringify(to_dict(), "  ", false)


## Thin shape check (no JSON Schema in GDScript). Returns problems; empty means OK.
## Accepts JSON-parsed input too (integers arrive as whole floats).
static func check(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var id_re := RegEx.create_from_string(ID_PATTERN)
	var clock_re := RegEx.create_from_string(CLOCK_PATTERN)
	for key: String in REQUIRED:
		if not d.has(key):
			out.append("%s: 없음" % key)
	for key: Variant in d:
		if not (REQUIRED.has(key) or OPTIONAL.has(key)):
			out.append("%s: 모르는 칸" % str(key))

	var place: Variant = d.get("place")
	if place is Dictionary:
		for key: String in ["id", "variant"]:
			if not _is_id(place.get(key), id_re):
				out.append("place.%s: id 형식이 아님" % key)
		if not PLACE_TYPES.has(place.get("type")):
			out.append("place.type: 모르는 유형")
	elif d.has("place"):
		out.append("place: 사전이 아님")

	var time: Variant = d.get("time")
	if time is Dictionary:
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
			if not PEOPLE_LISTS.has(key):
				out.append("people.%s: 모르는 목록" % str(key))
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
			if w.has("witnesses") and not (w["witnesses"] is Array):
				out.append("witnessed.%d.witnesses: 목록이 아님" % i)
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
		else:
			out.append("decisions: 목록이 아님")
	if d.has("content_type") and d["content_type"] != "receipt":
		out.append("content_type: receipt가 아님")
	return out


static func _is_num(v: Variant) -> bool:
	return v is int or v is float


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
