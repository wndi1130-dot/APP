extends RefCounted
## What the return receipt says (UI 3단계 시안 2차, B1 「성에 낀 계기」): the
## place, the end of the stop, the hours, the head lines, the four columns and
## what was seen, and the field's one line of promises. receipt_sheet.gd puts
## it on the stop's own sheet, in the slice and at the field's end alike. It
## reads the stop's own record (result["receipt"]) and sets nothing. People are
## numbers here, never names (user decision 183), so the dead are only ever
## counted.
##
## The promises the stop made are observations only (receipt.gd see_promise):
## who saw them and which carriage heard. Whether one was kept is the train's
## call, on its return.

const LeaveScene = preload("res://game/ui/leave_scene.gd")
const TrainRules = preload("res://game/train/train_rules.gd")

const PLACE_NAME := "술레후프"
const REASONS: Dictionary = {"departed": "출발", "limit": "시간 끝", "wiped": "모두 쓰러짐"}
## The promise kinds the first trial has (s3_first_trial_scope 1절), by the
## short name the field shows.
const PROMISE_NAMES: Dictionary = {"prologue": "서막", "skip_dispatch": "교대", "research_pick": "연구"}


static var _comms: Dictionary = {}


## A carriage's name from the train's rules ("tail" → 꼬리칸).
static func comm_name(id: String) -> String:
	if _comms.is_empty():
		_comms = TrainRules.load_default().get("comms", {})
	var comms: Dictionary = _comms
	return String((comms.get(id, {}) as Dictionary).get("name", id))


## A promise in a few words: the state the train sent ("state"), or else what
## the departure says, cut to a word or two (decision 293 ③: no 「~한다」).
static func promise_state(p: Dictionary) -> String:
	if p.has("state"):
		return String(p["state"])
	var made_to: String = String(p.get("madeTo", ""))
	match String(p.get("kind", "")):
		"prologue":
			var n: int = (p.get("subjects", []) as Array).size()
			return "%d명 데려오기" % n if n > 0 else "데려오기"
		"skip_dispatch":
			return "%s 파견 제외" % comm_name(made_to)
		"research_pick":
			return "%s 연구 우선" % comm_name(made_to)
	return String(p.get("label", ""))


## The field's one line of promises (「약속: 서막 ○○ / 교대 ○○」), "" for none.
static func promise_line(promises: Array) -> String:
	var parts: Array = []
	for p in promises:
		if not p is Dictionary:
			continue
		var kind: String = String(p.get("kind", ""))
		var said: String = promise_state(p)
		parts.append((String(PROMISE_NAMES.get(kind, kind)) + " " + said).strip_edges())
	return "" if parts.is_empty() else "약속: " + " / ".join(parts)


## "D1 10:30" → "1일째 10:30".
static func _day_time(t: String) -> String:
	var bits: PackedStringArray = t.split(" ", false, 1)
	if bits.size() == 2 and bits[0].begins_with("D") and bits[0].substr(1).is_valid_int():
		return "%s일째 %s" % [bits[0].substr(1), bits[1]]
	return t


## The lines under the columns: each promise seen, and the symbol carried.
static func seen_lines(r: Dictionary) -> Array:
	var out: Array = []
	for fp in r.get("fieldPromises", []):
		if not fp is Dictionary:
			continue
		var kind: String = String(fp.get("kind", ""))
		var heard: Array = []
		for g in fp.get("heardBy", []):
			heard.append(comm_name(String(g)))
		var line: String = "약속 %s · 본 사람 %d" % [PROMISE_NAMES.get(kind, kind), (fp.get("witnesses", []) as Array).size()]
		if not heard.is_empty():
			line += " · %s 들음" % ", ".join(heard)
		out.append(line)
	# The old promise shape (receipt.gd promise): a leader's word and whether it held.
	for p in r.get("promises", []):
		if p is Dictionary:
			out.append("약속 %s · %s" % [p.get("condition", "?"), "지킴" if p.get("kept", false) else "어김"])
	var sym = r.get("symbol", null)
	if sym is Dictionary and not (sym as Dictionary).is_empty():
		var line: String = "상징물 · %s의 것" % comm_name(String(sym.get("groupId", "")))
		if String(sym.get("carriedBy", "")) != "":
			line += " · 든 사람 있음"
		out.append(line)
	return out


## What the slip says, for the card and the tests alike.
static func rows(result: Dictionary) -> Dictionary:
	var r: Dictionary = result.get("receipt", {})
	var time: Dictionary = r.get("time", {})
	var when: String = ""
	if time.has("arrive") and time.has("depart"):
		var depart: String = _day_time(String(time["depart"]))
		var arrive: String = _day_time(String(time["arrive"]))
		# The same day once: 「1일째 10:30 → 13:10」.
		var day: String = arrive.get_slice(" ", 0)
		if depart.begins_with(day + " "):
			depart = depart.trim_prefix(day + " ")
		when = "%s → %s" % [arrive, depart]
	var reason: String = String(result.get("reason", ""))
	return {
		"place": PLACE_NAME,
		"stamp": String(REASONS.get(reason, reason)),
		"when": when,
		"head": LeaveScene.head(result),
		"columns": LeaveScene.columns(result),
		"seen": seen_lines(r),
	}

