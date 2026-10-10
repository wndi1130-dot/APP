extends RefCounted
## What can be done to one wound, in order (body_injury 4.6).
## 'first_aid' stops the blood and nothing more; 'full' runs every step the
## tools allow. A step whose tool is missing stops the run there: it and the
## steps behind it are shown grey with the name of what is missing.
## Stage 1 has three tools (bandage, a bottle of spirit, a plank). The stage 2
## steps (tourniquet, pulling, stitching) are listed, but nothing in the game
## gives their tools yet, so they always read as missing.

const BodyState = preload("res://game/sim/body_state.gd")

const FIRST_AID := "first_aid"
const FULL := "full"

## Step states.
const DO := "do"            # will be done
const DONE := "done"        # already done on this wound
const MISSING := "missing"  # the tool is not there: the run stops here
const BLOCKED := "blocked"  # behind a missing step

## seconds: body_injury 4.6 start values. tools: any one of them does (one is
## used up). An empty list: no such tool in the game yet (stage 2).
const STEPS: Dictionary = {
	"tourniquet": {"label": "지혈대", "seconds": 3.0, "tools": [], "need": "지혈대"},
	"pull": {"label": "빼기", "seconds": 6.0, "tools": [], "need": "핀셋"},
	"disinfect": {"label": "소독", "seconds": 2.0, "tools": ["bottle_spirit"], "need": "소독할 술"},
	"suture": {"label": "봉합", "seconds": 12.0, "tools": [], "need": "바늘과 실"},
	"bandage": {"label": "붕대", "seconds": 4.0, "tools": ["bandage"], "need": "붕대"},
	"splint": {"label": "부목", "seconds": 10.0, "tools": ["plank", "wood"], "need": "판자"},
}

## The order of care for each kind of wound (the table in 4.6).
const ORDER: Dictionary = {
	"scratch": ["disinfect", "bandage"],
	"laceration": ["disinfect", "bandage"],
	"deep": ["tourniquet", "suture", "bandage"],
	"embedded": ["pull", "disinfect", "bandage"],
	"bite": ["bandage"],
	"fracture": ["splint"],
}

const KIND_NAMES: Dictionary = {
	"scratch": "긁힘", "laceration": "찢김", "deep": "깊은 상처",
	"embedded": "박힌 것", "bite": "물림", "fracture": "골절",
}
const PART_NAMES: Dictionary = {
	"head_neck": "머리·목", "torso": "몸통", "arm_left": "왼팔",
	"arm_right": "오른팔", "leg_left": "왼다리", "leg_right": "오른다리",
}

## A medic's hands are quicker (body_injury 4 '능력과 지식'; the old treat()
## took 4 s against 6 s).
const MEDIC_TIME := 0.67


## The steps of care for a wound: [{id, label, seconds, state, need, tool, count}].
## have: item id -> count (the hands that treat and the one treated, pooled).
static func plan(wound: Dictionary, have: Dictionary, mode: String = FULL) -> Array:
	var out: Array = []
	var stopped := false
	for id: String in _order(wound, mode):
		var row: Dictionary = STEPS[id]
		var step := {"id": id, "label": row["label"], "seconds": float(row["seconds"]), "need": "", "tool": "", "count": 0, "state": DO}
		if _is_done(wound, id):
			step["state"] = DONE
		elif stopped:
			step["state"] = BLOCKED
		else:
			var count: int = _count(wound, id)
			var tool_id: String = _tool(row["tools"], have, count)
			if tool_id == "":
				step["state"] = MISSING
				step["need"] = "%s 없음" % row["need"] if count <= 1 or _total(row["tools"], have) == 0 else "%s %d개 필요" % [row["need"], count]
				stopped = true
			else:
				step["tool"] = tool_id
				step["count"] = count
		out.append(step)
	return out


## The steps that will really be done, in order.
static func runnable(steps: Array) -> Array:
	var out: Array = []
	for s: Dictionary in steps:
		if s["state"] == DO:
			out.append(s)
	return out


## Does one step on the wound of that index. Returns how many of the tool it
## used (0: nothing was done).
static func apply(body: BodyState, index: int, step_id: String) -> int:
	if index < 0 or index >= body.wounds.size():
		return 0
	match step_id:
		"disinfect":
			return 1 if body.disinfect(index) else 0
		"bandage":
			return body.bandage_wound(index)
		"splint":
			return 1 if body.splint_wound(index) else 0
	return 0


## One line for a wound row: "왼팔 찢김 · 피 보통".
static func wound_text(wound: Dictionary) -> String:
	var words: Array = ["%s %s" % [PART_NAMES.get(wound["part"], wound["part"]), KIND_NAMES.get(wound["kind"], wound["kind"])]]
	if wound["kind"] == "fracture":
		words.append("부목 댐" if wound["splinted"] else "부목 없음")
	else:
		words.append(blood_word(float(wound["blood"])))
		if wound["bandaged"]:
			words.append("붕대 감음")
		if wound["disinfected"]:
			words.append("소독함")
	if wound["festering"]:
		words.append("곪음")
	return " · ".join(words)


static func blood_word(blood: float) -> String:
	if blood <= 0.0:
		return "피 멎음"
	if blood >= BodyState.HEAVY_BLOOD:
		return "피 많음"
	if blood >= BodyState.SEEP_BLOOD:
		return "피 보통"
	return "피 조금"


## The steps as one line for the screen: done ones marked, missing ones named.
static func steps_text(steps: Array) -> String:
	var parts: Array = []
	for s: Dictionary in steps:
		match s["state"]:
			DONE:
				parts.append("%s 함" % s["label"])
			MISSING:
				parts.append("%s (%s)" % [s["label"], s["need"]])
			_:
				parts.append(String(s["label"]))
	return " → ".join(parts)


static func seconds(step: Dictionary, medical: String) -> float:
	return float(step["seconds"]) * (1.0 if medical == "none" else MEDIC_TIME)


static func _order(wound: Dictionary, mode: String) -> Array:
	var kind: String = String(wound.get("kind", ""))
	if not ORDER.has(kind):
		return []
	if mode == FIRST_AID:
		# Blood only: the bandage, when there is blood to stop.
		return ["bandage"] if float(wound["blood"]) > 0.0 and ORDER[kind].has("bandage") else []
	var out: Array = []
	for id: String in ORDER[kind]:
		# A tourniquet goes on a limb.
		if id == "tourniquet" and not (String(wound["part"]).begins_with("arm_") or String(wound["part"]).begins_with("leg_")):
			continue
		out.append(id)
	return out


static func _is_done(wound: Dictionary, id: String) -> bool:
	match id:
		"disinfect":
			return bool(wound["disinfected"])
		"bandage":
			return bool(wound["bandaged"])
		"splint":
			return bool(wound["splinted"])
	return false


## How many of the tool the step takes (a wound bleeding hard takes two bandages).
static func _count(wound: Dictionary, id: String) -> int:
	if id == "bandage" and float(wound["blood"]) >= BodyState.HEAVY_BLOOD:
		return 2
	return 1


static func _tool(tools: Array, have: Dictionary, count: int) -> String:
	for id: String in tools:
		if int(have.get(id, 0)) >= count:
			return id
	return ""


static func _total(tools: Array, have: Dictionary) -> int:
	var n := 0
	for id: String in tools:
		n += int(have.get(id, 0))
	return n
