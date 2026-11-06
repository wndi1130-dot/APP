extends RefCounted
## The field's one save slot (S3 spec 4, user decision 296): what a stop has
## come to, as one JSON file, written over each time. No loading by hand, no
## going back: the last whole save is the only one, and a broken file falls
## back to the one before it (.bak).
##
## capture() snapshots live picks; to_json/from_json and write/read are plain
## functions over a Dictionary. Only S2 reads this file (its keys are its own);
## the train keeps its own save (user://s1a_game_v2.json). On start the field
## save wins while its phase is "field", unless the train already applied its
## receipt_id (S3 PR #428).

## Field save format number (this file's saves only). Not politics/save_slot.gd SAVE_VERSION,
## which numbers the train's own save. 3 writes byte and int32 runs (the grids, the sight
## memory) as one base64 line each; 1 and 2 wrote them a typed number at a time and still read.
const VERSION := 3
const READ_VERSIONS: Array[int] = [1, 2, 3]
const KIND := "s2_field"
const PATH := "user://field_save.json"
## The train's own save (politics/save_slot.gd DEFAULT_PATH): read here only for what it applied.
const TRAIN_PATH := "user://s1a_game_v2.json"
const DeadPose = preload("res://game/actors/dead_pose.gd")
const EatRules = preload("res://game/sim/eat_rules.gd")
const LungerRules = preload("res://game/sim/lunger_rules.gd")
const Wear = preload("res://game/sim/wear.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const StopForm = preload("res://game/sim/stop_form.gd")
const FieldWork = preload("res://game/field_work.gd")
const Sled = preload("res://game/sim/sled.gd")
const SLED_PERSON_FIELDS: Array[String] = ["sled_id", "sled_stowed_for", "sled_weapon_stowed", "sled_rearm_t", "sled_serial", "sled_job"]
const StopGround = preload("res://game/world/stop_ground.gd")
const SidePath = preload("res://game/world/side_path.gd")
const FURNISH_RULE: int = 0

## Keys that hold a place in the field: [x, y, z] in the file, Vector3 here.
const VEC_KEYS := ["pos", "home"]
## Start options that are not the world: the switch itself and what goes in its own keys.
const NOT_START := ["field_save", "field_save_path", "field_resume", "departure", "receipt_id", "map_data", "vat", "staged", "stop_ground", "stop_end_gap",
	"stop_view_rows", "stop_view_cols", "stop_view_rule", "bounds_rule", "side_path_rule"]
## Version 1 did not store targets or timers; keep its original fallback.
const RESUME_STATES := ["frozen", "wander", "downed", "dead", "rising"]

## Set by _decode when a value is not one the encoder writes; from_json then takes the save as broken.
static var _decode_bad: bool = false
## The whole string (\z: a line end before the end is not one), padding only at the end.
static var _base64_line: RegEx = RegEx.create_from_string("^[A-Za-z0-9+/]*={0,2}\\z")
## The digits of the signed 64-bit edges, compared as text so no value goes through a float.
const INT64_MAX_DIGITS := "9223372036854775807"
const INT64_MIN_DIGITS := "9223372036854775808"
const INT32_MIN := -2147483648
const INT32_MAX := 2147483647
## Tag types and the length of their fixed number list.
const NUMBER_TAGS := {"Vector3": 3, "Vector2": 2, "Color": 4}
const INT_TAGS := {"Vector2i": 2, "Rect2i": 4}
## The packed runs that may be one base64 line (format 3) instead of a typed list (format 2).
const BASE64_TAGS := ["PackedByteArray", "PackedInt32Array"]
## The packed runs that may be a typed list: of vectors, of text, or format 2's bytes and int32s.
const LIST_TAGS := ["PackedVector3Array", "PackedStringArray", "PackedByteArray", "PackedInt32Array"]
## The encoder's text for each byte, "0" to "255", and the byte. A format 2 byte run's elements
## are looked up here (after the same String check _int_of_text makes) instead of read by
## _int_of_text: one format 2 save holds over 230 000 of them, and on the phone (SM-S906N, 11-07)
## _int_of_text, which #1447 put in place of an unchecked int(), cost 0.6 us more a text than
## int(), about 0.14 s more to read one such save. Only these 256 texts are keys, so "+7", "007",
## "-0", "256" or anything else still misses and breaks the file. A const, so read-only and whole
## from the start.
const BYTE_TEXTS := {
	"0": 0, "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10, "11": 11, "12": 12, "13": 13, "14": 14, "15": 15,
	"16": 16, "17": 17, "18": 18, "19": 19, "20": 20, "21": 21, "22": 22, "23": 23, "24": 24, "25": 25, "26": 26, "27": 27, "28": 28, "29": 29, "30": 30, "31": 31,
	"32": 32, "33": 33, "34": 34, "35": 35, "36": 36, "37": 37, "38": 38, "39": 39, "40": 40, "41": 41, "42": 42, "43": 43, "44": 44, "45": 45, "46": 46, "47": 47,
	"48": 48, "49": 49, "50": 50, "51": 51, "52": 52, "53": 53, "54": 54, "55": 55, "56": 56, "57": 57, "58": 58, "59": 59, "60": 60, "61": 61, "62": 62, "63": 63,
	"64": 64, "65": 65, "66": 66, "67": 67, "68": 68, "69": 69, "70": 70, "71": 71, "72": 72, "73": 73, "74": 74, "75": 75, "76": 76, "77": 77, "78": 78, "79": 79,
	"80": 80, "81": 81, "82": 82, "83": 83, "84": 84, "85": 85, "86": 86, "87": 87, "88": 88, "89": 89, "90": 90, "91": 91, "92": 92, "93": 93, "94": 94, "95": 95,
	"96": 96, "97": 97, "98": 98, "99": 99, "100": 100, "101": 101, "102": 102, "103": 103, "104": 104, "105": 105, "106": 106, "107": 107, "108": 108, "109": 109, "110": 110, "111": 111,
	"112": 112, "113": 113, "114": 114, "115": 115, "116": 116, "117": 117, "118": 118, "119": 119, "120": 120, "121": 121, "122": 122, "123": 123, "124": 124, "125": 125, "126": 126, "127": 127,
	"128": 128, "129": 129, "130": 130, "131": 131, "132": 132, "133": 133, "134": 134, "135": 135, "136": 136, "137": 137, "138": 138, "139": 139, "140": 140, "141": 141, "142": 142, "143": 143,
	"144": 144, "145": 145, "146": 146, "147": 147, "148": 148, "149": 149, "150": 150, "151": 151, "152": 152, "153": 153, "154": 154, "155": 155, "156": 156, "157": 157, "158": 158, "159": 159,
	"160": 160, "161": 161, "162": 162, "163": 163, "164": 164, "165": 165, "166": 166, "167": 167, "168": 168, "169": 169, "170": 170, "171": 171, "172": 172, "173": 173, "174": 174, "175": 175,
	"176": 176, "177": 177, "178": 178, "179": 179, "180": 180, "181": 181, "182": 182, "183": 183, "184": 184, "185": 185, "186": 186, "187": 187, "188": 188, "189": 189, "190": 190, "191": 191,
	"192": 192, "193": 193, "194": 194, "195": 195, "196": 196, "197": 197, "198": 198, "199": 199, "200": 200, "201": 201, "202": 202, "203": 203, "204": 204, "205": 205, "206": 206, "207": 207,
	"208": 208, "209": 209, "210": 210, "211": 211, "212": 212, "213": 213, "214": 214, "215": 215, "216": 216, "217": 217, "218": 218, "219": 219, "220": 220, "221": 221, "222": 222, "223": 223,
	"224": 224, "225": 225, "226": 226, "227": 227, "228": 228, "229": 229, "230": 230, "231": 231, "232": 232, "233": 233, "234": 234, "235": 235, "236": 236, "237": 237, "238": 238, "239": 239,
	"240": 240, "241": 241, "242": 242, "243": 243, "244": 244, "245": 245, "246": 246, "247": 247, "248": 248, "249": 249, "250": 250, "251": 251, "252": 252, "253": 253, "254": 254, "255": 255,
}
## Tests only: fail one step of the next write; empty is off, reset on entry.
static var _test_fail_step: String = ""
## Tests only: counts actual parses of the previous slot, not new-file validation.
static var _test_previous_parses: int = 0
## Tests only: actual file parse attempts in read(), including a broken primary.
static var _test_reads: int = 0
## Tests only: texts read by _int_of_text (a format 2 byte run's elements go by BYTE_TEXTS). Kept
## in the shipped path as _test_reads is: one add for each text it reads (lone int tags and int32
## run elements, about 1 000 in a save).
static var _test_int_texts: int = 0
## Process-local hashes of exact disk bytes already accepted by from_json().
static var _known_good: Dictionary = {}

## Only simulation state, never meshes, services or input widgets.
## The whole brain includes work_haul_flee and its cached unloading destination.
const PERSON_FIELDS: Array[String] = [
	"team", "role", "display_name", "skills", "medical", "hunger_level", "sore_level", "smell", "traits", "lamp", "lamp_on",
	"path", "running", "crouched", "facing", "turn_rate", "look", "moving", "stick", "drive_speed", "drive_dir",
	"command", "command_target", "action", "action_label", "action_t", "action_total", "action_done", "action_busy",
	"action_noise_t", "swing_t", "shove_t", "lunge_t", "shove_rest_t", "strike_t", "strike_total", "strike_at", "strike_kind",
	"reload_t", "jam_t", "target_zombie", "target_person", "hold_attack", "grabbers", "grab_left", "grab_front",
	"climbing", "carrying_wounded", "downed_marked", "dead_marked", "brain", "panic", "ice_t", "fallen_t",
	"last_hurt_by", "blood_soaked", "close_kills",
	"sled_id", "sled_stowed_for", "sled_weapon_stowed", "sled_rearm_t", "sled_serial", "sled_job",
]
const GAME_FIELDS: Array[String] = [
	"squad", "crew", "raiders",
	"rng", "eat_rng", "hordes", "pending_spawn", "last_loud", "rattle", "lid_open", "waiting", "cap",
	"ammo_start", "loaded_start", "cloth_start", "shot_times", "blood", "sounds", "alarms", "named_seen",
	"glints", "key_ways", "note_spot", "lures", "lure_marks", "body_searches", "loot_report", "rode_off",
	"forecast_t", "forecast_precision", "deaf_t", "casings", "last_gun_t", "radio", "radio_wait", "radio_wait_t",
	"radio_last", "radio_rings", "radio_t", "zone_now", "auto_paused_once", "dark_noise_t", "safe_warned",
	"glass_warned", "player_downed_t", "spotted_events", "unseen_rattle", "lid_tip_told", "roof_seen",
	"seen_now", "seen_memory", "vis_t", "cam_focus", "cam_push", "cam_size",
	"sleds", "next_sled_id",
]
const COMPONENTS: Array[String] = ["director", "ledger", "mission_play", "holdout", "actions", "ai", "combat", "lines", "weather", "telemetry", "train_guard", "work"]
## "dead_eaten_seconds" is EatRules.EATEN_META (결정 441 (3)).
const PERSON_META: Array[String] = ["dead_regrab_until", "pose_mode", "pose_blow_way", "pose_care", "pose_swing", "pose_recover_wait", "pose_recover_release", "dead_eaten_seconds"]


## What the field is now, as plain data. `game` is a field_game.gd.
static func capture(game) -> Dictionary:
	if game.ended:
		return _capture_ended(game)
	if game.get("work") != null:
		game.work.prepare_digs()
	var people: Array = []
	for p in game.people:
		people.append(_person(game, p))
	var zombies: Array = []
	if game.zombies != null:
		for z in game.zombies.list:
			zombies.append(_record(game, z))
	var containers := {}
	for id in game.data.get("containers", {}):
		var c: Dictionary = game.data["containers"][id]
		containers[String(id)] = _record(game, c)
	var spots := {}
	for id in game.data.get("spots", {}):
		spots[String(id)] = String(game.data["spots"][id].get("state", ""))
	var ground: Array = []
	for g in game.ground_items:
		ground.append(g.duplicate(true))  # {pos, id, n} and a dropped gun's own row
	var said: Dictionary = game.receipt.to_dict() if game.receipt != null else {}
	# The departure order is the train side's contract (S3 spec): kept whole, inside untouched.
	var departure: Dictionary = (game.opts.get("departure", {}) as Dictionary).duplicate(true)
	var stop_id := String(departure.get("stopId", said.get("stopId", game.opts.get("stop_id", ""))))
	var out: Dictionary = {
		"version": VERSION, "kind": KIND,
		"stop_id": stop_id, "place": game.place, "mission": game.mission,
		"stop_form": game.stop_form, "stop_ground": String(game.data.get("stop_form", "")),
		"stop_end_gap": int(game.data.get("stop_end_gap", -1)),
		"bounds_rule": int(game.data.get("bounds_stamp", 0)),
		"side_path_rule": int(game.data.get("side_path_rule", game.opts.get("side_path_rule", SidePath.RULE))),
		"stop_view_rows": int(game.data.get("stop_view_rows", 0)),
		"stop_view_cols": int(game.data.get("stop_view_cols", 0)),
		"stop_view_rule": int(game.data.get("stop_view_rule", 0)),
		"seed": int(game.rng.seed), "phase": "ended" if game.ended else "field", "end_reason": String(said.get("endReason", "")),
		"saved_at": game.clock.label(), "clock": {"elapsed": game.clock.elapsed, "speed": game.clock.speed},
		"player_pid": game.player.pid if game.player != null else "",
		"people": people, "ammo": game.ammo.duplicate(), "containers": containers, "spots": spots,
		"ground_items": ground, "unloaded": game.unloaded.duplicate(), "loaded_wear": game.loaded_wear.duplicate(true),
		"sleds": game.sleds.duplicate(true), "next_sled_id": game.next_sled_id,
		"coal": {"delivered": game.actions.coal_delivered if game.actions != null else 0, "spent": game.actions.coal_spent if game.actions != null else 0},
		"zombies": zombies, "decisions": game.decisions.duplicate(true),
		# The return's id, the same as the receipt's receiptId: the train side applies it once.
		"receipt_id": String(said.get("receiptId", game.opts.get("receipt_id", ""))),
		"departure": departure,
		# The same seed builds the same stop only with the same start options.
		"start_opts": _start_opts(game.opts),
		# What the receipt has gathered so far (deaths, who saw what, notes): its own fields as they are.
		"receipt_state": _receipt_state(game.receipt) if game.receipt != null else {},
	}
	out["runtime"] = _runtime(game)
	return out


## Ended saves stay small.
static func _capture_ended(game) -> Dictionary:
	var said: Dictionary = game.receipt.to_dict() if game.receipt != null else {}
	var departure: Dictionary = (game.opts.get("departure", {}) as Dictionary).duplicate(true)
	var stop_id := String(departure.get("stopId", said.get("stopId", game.opts.get("stop_id", ""))))
	var start_opts: Dictionary = {}
	for key in ["slice", "slice_run", "visit_id"]:
		if game.opts.has(key):
			start_opts[key] = game.opts[key]
	return {
		"version": VERSION, "kind": KIND, "phase": "ended",
		"receipt_id": String(said.get("receiptId", game.opts.get("receipt_id", ""))),
		"receipt_state": _receipt_state(game.receipt) if game.receipt != null else {},
		"place": game.place, "departure": departure,
		"seed": int(game.rng.seed), "stop_id": stop_id,
		"start_opts": start_opts.duplicate(true),
		"clock": {"elapsed": game.clock.elapsed, "speed": game.clock.speed},
		"coal": {"delivered": game.actions.coal_delivered if game.actions != null else 0, "spent": game.actions.coal_spent if game.actions != null else 0},
	}


static func _start_opts(opts: Dictionary) -> Dictionary:
	var out := opts.duplicate(true)
	for key in NOT_START:
		out.erase(key)
	return out


static func _person(game, p) -> Dictionary:
	return {
		"pid": p.pid, "team": p.team, "pos": p.position, "level": game.level_of(p.position), "alive": p.is_alive(),
		"bag": p.bag, "items": p.items.duplicate(), "hands": p.hands.duplicate(true), "wear": Wear.save_of(p),
		"body": p.body.save_of(), "heat": p.heat.save_of(),
		"state": _properties(game, p, PERSON_FIELDS), "aim": _script_state(game, p.aim),
		"meta": _person_meta(game, p),
	}


static func _person_meta(game, p) -> Dictionary:
	var out: Dictionary = {}
	for key: String in PERSON_META:
		if p.has_meta(key):
			out[key] = _freeze(game, p.get_meta(key))
	return out


static func to_json(d: Dictionary) -> String:
	var encoded: Dictionary = _encode(d)
	# Keep the envelope readable by old slot tools; the payload preserves Variant types.
	encoded["version"] = int(d.get("version", VERSION))
	return JSON.stringify(encoded, "", false, true)


## The save in `text`, or {} when it is not a whole save of this kind and version.
static func from_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:  # a cut-off file is expected here, not an engine error
		return {}
	var parsed = json.data
	if not parsed is Dictionary:
		return {}
	var version: Variant = parsed.get("version")
	if not (version is int or version is float):
		return {}
	if not is_finite(float(version)) or float(version) != floorf(float(version)):
		return {}
	if parsed.get("kind") != KIND or not int(version) in READ_VERSIONS:
		return {}
	var decoded: Variant = decode_checked(parsed)
	if not decoded is Dictionary or not _whole(decoded):
		return {}
	var d: Dictionary = decoded
	d["version"] = int(d["version"])
	d["seed"] = int(d.get("seed", 0))
	for z in d.get("zombies", []):
		z["id"] = int(z["id"])
		z["horde"] = int(z["horde"])
	for g in d.get("ground_items", []):
		# A crew carrier's dropped load keeps its part (field_work.gd drop_load); other items count whole.
		g["n"] = float(g["n"]) if g.get("crew_drop", false) else int(g["n"])
		# An arrow saved before it took the stock's name (decision 426).
		if g.get("id") == "arrow":
			g["id"] = "ammo_craft"
	for key in ["ammo", "unloaded"]:
		var counts: Dictionary = d.get(key, {})
		for id in counts:
			counts[id] = int(counts[id])
	for p in d.get("people", []):
		p["level"] = int(p["level"])
		for id in p["items"]:
			p["items"][id] = int(p["items"][id])
		for h in p["hands"]:
			if h.has("loaded"):
				h["loaded"] = int(h["loaded"])
	return d


## Only fields read without a fallback are required. Optional old fields, when
## present, must still have the container/number type their readers consume.
static func _fields(d: Variant, required: Dictionary, optional: Dictionary = {}) -> bool:
	if not d is Dictionary:
		return false
	for key in required:
		if not d.has(key) or not _field_type(d[key], required[key]):
			return false
	for key in optional:
		if d.has(key) and not _field_type(d[key], optional[key]):
			return false
	return true


static func _field_type(value: Variant, type: int) -> bool:
	if type == TYPE_FLOAT:
		return (value is int or value is float) and is_finite(float(value))
	return typeof(value) == type


static func _counts(d: Dictionary) -> bool:
	for value in d.values():
		if not _field_type(value, TYPE_FLOAT):
			return false
	return true


static func _whole(d: Dictionary) -> bool:
	if d.has("bounds_rule") and not _valid_bounds_rule(d["bounds_rule"]):
		return false
	if d.has("side_path_rule") and not _valid_side_path_rule(d["side_path_rule"]):
		return false
	if not _fields(d, {"clock": TYPE_DICTIONARY, "coal": TYPE_DICTIONARY}, {
		"people": TYPE_ARRAY, "zombies": TYPE_ARRAY, "ground_items": TYPE_ARRAY,
		"containers": TYPE_DICTIONARY, "spots": TYPE_DICTIONARY, "ammo": TYPE_DICTIONARY, "unloaded": TYPE_DICTIONARY,
		"loaded_wear": TYPE_ARRAY, "decisions": TYPE_ARRAY, "start_opts": TYPE_DICTIONARY,
		"departure": TYPE_DICTIONARY, "receipt_state": TYPE_DICTIONARY, "runtime": TYPE_DICTIONARY, "seed": TYPE_FLOAT,
		"sleds": TYPE_ARRAY, "next_sled_id": TYPE_FLOAT,
	}):
		return false
	if not _fields(d["clock"], {"elapsed": TYPE_FLOAT, "speed": TYPE_FLOAT}) \
		or not _fields(d["coal"], {"delivered": TYPE_FLOAT, "spent": TYPE_FLOAT}):
		return false
	for key in ["ammo", "unloaded"]:
		if not _counts(d.get(key, {})):
			return false
	for row in d.get("people", []):
		if not _fields(row, {"pid": TYPE_STRING, "pos": TYPE_VECTOR3, "level": TYPE_FLOAT,
			"bag": TYPE_STRING, "items": TYPE_DICTIONARY, "hands": TYPE_ARRAY, "body": TYPE_DICTIONARY}, {
			"wear": TYPE_DICTIONARY, "heat": TYPE_DICTIONARY, "meta": TYPE_DICTIONARY, "state": TYPE_DICTIONARY, "aim": TYPE_DICTIONARY,
		}):
			return false
		if not _counts(row["items"]):
			return false
		for hand in row["hands"]:
			if not _fields(hand, {}, {"loaded": TYPE_FLOAT}):
				return false
	for row in d.get("zombies", []):
		if not _fields(row, {"id": TYPE_FLOAT, "horde": TYPE_FLOAT, "kind": TYPE_STRING, "pos": TYPE_VECTOR3, "state": TYPE_STRING}, {"loot": TYPE_ARRAY}):
			return false
	for row in d.get("ground_items", []):
		if not _fields(row, {"n": TYPE_FLOAT}):
			return false
	if not _whole_sleds(d):
		return false
	for row in d.get("containers", {}).values():
		if not _fields(row, {"searched": TYPE_BOOL, "locked": TYPE_BOOL, "items": TYPE_ARRAY}):
			return false
	var opts: Dictionary = d.get("start_opts", {})
	if not _whole_start(opts):
		return false
	var departure: Dictionary = d.get("departure", {})
	if not _whole_departure(opts.get("departure", {}) if departure.is_empty() else departure):
		return false
	return not exact(d) or _whole_runtime(d)


static func _valid_side_path_rule(value: Variant) -> bool:
	# JSON의 정수 float도 허용하되 아직 없는 배치 판은 다른 지도로 복원하지 않는다.
	return _valid_bounds_rule(value) and value <= SidePath.RULE


static func _valid_bounds_rule(value: Variant) -> bool:
	if value is int:
		return value >= 0
	# JSON의 정수도 float로 온다. int 범위를 벗어난 값은 변환 전에 거부한다.
	return value is float and is_finite(value) and value >= 0.0 and value < 9223372036854775808.0 and floor(value) == value


## Campaign rules require int; old JSON field options may hold integral floats.
## A negative seed-rule limit means the field does not read that campaign-only key.
static func furnish_seed_problem(d: Dictionary, max_rule: int, max_seed_rule: int = -1, allow_float: bool = false) -> String:
	if d.has("world_seed") and _int_of_text(d["world_seed"]) == null:
		return "F-CAMPAIGN-ROUTE: world seed"
	if max_seed_rule >= 0 and d.has("seed_rule"):
		if not d["seed_rule"] is int or d["seed_rule"] < 0 or d["seed_rule"] > max_seed_rule:
			return "F-CAMPAIGN-ROUTE: seed_rule"
	if d.has("furnish_rule"):
		var rule: Variant = d["furnish_rule"]
		if not _valid_bounds_rule(rule) or (not allow_float and not rule is int) or rule > max_rule:
			return "F-CAMPAIGN-ROUTE: furnish_rule"
	if int(d.get("furnish_rule", 0)) >= 1 and not d.has("world_seed"):
		return "F-CAMPAIGN-ROUTE: missing world seed"
	return ""


## Sled rows as the restore reads them: a bad one sends the read to the backup
## before anything of the game changes. Saves from before sleds have none.
static func _whole_sleds(d: Dictionary) -> bool:
	if not _fields(d, {}, {"sleds": TYPE_ARRAY, "next_sled_id": TYPE_FLOAT}):
		return false
	for row in d.get("sleds", []):
		if not _fields(row, {"id": TYPE_FLOAT, "level": TYPE_FLOAT, "pos": TYPE_VECTOR3, "items": TYPE_DICTIONARY}, {"puller": TYPE_STRING}):
			return false
		if not _counts(row["items"]):
			return false
		# The restore walks the cargo by item id: a tagged key of another type is not one.
		for item in row["items"]:
			if not item is String:
				return false
	return true


## The saved start options may supply a squad instead of the default one.
static func _whole_start(opts: Dictionary, max_furnish_rule: int = FURNISH_RULE) -> bool:
	if furnish_seed_problem(opts, max_furnish_rule, -1, true) != "":
		return false
	if not _fields(opts, {}, {"squad": TYPE_ARRAY}):
		return false
	if opts.has("squad") and opts["squad"].is_empty():
		return false
	for row in opts.get("squad", []):
		if not _fields(row, {"id": TYPE_STRING, "name": TYPE_STRING, "role": TYPE_STRING}, {
			"hands": TYPE_ARRAY, "items": TYPE_DICTIONARY, "skills": TYPE_DICTIONARY, "wear": TYPE_DICTIONARY,
		}):
			return false
		if not _whole_start_hands(row.get("hands", [])) or not _counts(row.get("items", {})):
			return false
	return true


static func _whole_start_hands(hands: Array) -> bool:
	for hand in hands:
		if not hand is Array or hand.is_empty() or not hand[0] is String:
			return false
		if hand.size() > 1 and not hand[1] is String:
			return false
		if hand.size() > 2 and not _field_type(hand[2], TYPE_FLOAT):
			return false
	return true


## Only a v2 departure activates field_game.gd's direct contract/roster reads.
static func _whole_departure(departure: Variant) -> bool:
	if not _fields(departure, {}, {"version": TYPE_FLOAT, "train": TYPE_DICTIONARY, "lootDeck": TYPE_DICTIONARY}):
		return false
	if departure.get("pastWeather") is Array:
		for row in departure["pastWeather"]:
			if not _fields(row, {"weather": TYPE_STRING, "seg": TYPE_FLOAT}):
				return false
	if int(departure.get("version", 0)) != 2:
		return true
	if not _fields(departure, {"placeId": TYPE_STRING, "departureId": TYPE_STRING, "stopId": TYPE_STRING, "roster": TYPE_ARRAY}, {"workCrew": TYPE_ARRAY}):
		return false
	if departure["roster"].is_empty():
		return false
	for person in departure["roster"] + departure.get("workCrew", []):
		if not _fields(person, {"id": TYPE_STRING, "name": TYPE_STRING, "role": TYPE_STRING, "comm": TYPE_STRING,
			"rel": TYPE_FLOAT, "body": TYPE_DICTIONARY, "gear": TYPE_DICTIONARY, "hunger": TYPE_FLOAT, "sore": TYPE_FLOAT, "rest": TYPE_FLOAT}):
			return false
		if not _fields(person["gear"], {"hands": TYPE_ARRAY, "items": TYPE_DICTIONARY, "bag": TYPE_STRING, "wear": TYPE_DICTIONARY}):
			return false
		if not _whole_start_hands(person["gear"]["hands"]) or not _counts(person["gear"]["items"]):
			return false
		if person.get("know") is Dictionary and person["know"].get("field", "") == "med":
			if not _fields(person["know"], {"skill": TYPE_FLOAT}):
				return false
	return true


## A v2 slot without runtime uses the legacy path; with runtime every direct
## exact-restore read must be safe, even if its map later needs the fallback.
static func _whole_runtime(d: Dictionary) -> bool:
	if not _fields(d, {"containers": TYPE_DICTIONARY, "people": TYPE_ARRAY, "zombies": TYPE_ARRAY}):
		return false
	var runtime: Dictionary = d["runtime"]
	if not _fields(runtime, {"spots": TYPE_DICTIONARY, "levels": TYPE_DICTIONARY, "mission": TYPE_DICTIONARY,
		"components": TYPE_DICTIONARY, "holdout_doors": TYPE_ARRAY, "game": TYPE_DICTIONARY}, {
		"wagon_coal": TYPE_ARRAY, "hud": TYPE_DICTIONARY, "zombie_system": TYPE_DICTIONARY,
	}):
		return false
	for kind in ["spots", "components"]:
		for row in runtime[kind].values():
			if not row is Dictionary:
				return false
	for row in runtime["levels"].values():
		if not _fields(row, {"solid": TYPE_PACKED_BYTE_ARRAY, "doors": TYPE_DICTIONARY, "windows": TYPE_DICTIONARY, "revision": TYPE_FLOAT}, {
			"width": TYPE_FLOAT, "height": TYPE_FLOAT, "floor_glass": TYPE_DICTIONARY,
		}):
			return false
	for row in runtime["holdout_doors"]:
		if not _fields(row, {"wall": TYPE_FLOAT}):
			return false
	if not _whole_sleds(runtime["game"]):
		return false
	for value in runtime.get("wagon_coal", []):
		if not _field_type(value, TYPE_FLOAT):
			return false
	return _fields(runtime.get("hud", {}), {}, {"grab_total": TYPE_FLOAT})


## Whether the field is where play goes on when the app starts again: a stop still
## being played whose return the train has not taken in yet. `applied` is the train
## save's fieldReturns.applied (receipt ids; a Dictionary there, a list is read too).
static func should_resume(save: Dictionary, applied = {}) -> bool:
	if save.is_empty() or String(save.get("phase", "")) != "field":
		return false
	var id := String(save.get("receipt_id", ""))
	if id == "":
		return true
	if applied is Dictionary:
		return not (applied as Dictionary).has(id)
	return not (applied as Array).has(id)


## Where the app starts (S3 spec 4, user decision 296): the field save and the
## train save are read, and a stop still being played whose return the train has
## not taken in comes back. Returns the start options for it, or {} to start fresh.
static func pick_start(field_path: String = PATH, train_path: String = TRAIN_PATH, read_context: Variant = null) -> Dictionary:
	var save: Dictionary = read_for_start(field_path, read_context) if read_context is Dictionary else read(field_path)
	if not should_resume(save, train_applied(train_path)):
		return {}
	var opts := resume_opts(save)
	opts["field_save_path"] = field_path
	return opts


## The receipt ids the train save has taken in (its fieldReturns.applied), {} when none.
static func train_applied(train_path: String = TRAIN_PATH) -> Dictionary:
	if not FileAccess.file_exists(train_path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(train_path)) != OK or not json.data is Dictionary:
		return {}
	var returns = (json.data as Dictionary).get("fieldReturns")
	if not returns is Dictionary or not returns.get("applied") is Dictionary:
		return {}
	return returns["applied"]


## The options that build the same stop again and then put the save on it.
static func resume_opts(save: Dictionary) -> Dictionary:
	if save.get("phase") == "ended":
		return {}
	var opts: Dictionary = (save.get("start_opts", {}) as Dictionary).duplicate(true)
	opts["seed"] = int(save.get("seed", 0))
	opts["place"] = String(save.get("place", ""))
	opts["mission"] = String(save.get("mission", ""))
	opts["bounds_rule"] = int(save.get("bounds_rule", 0))
	opts["side_path_rule"] = int(save.get("side_path_rule", 0))
	if save.has("stop_form"):
		opts["stop_form"] = save["stop_form"]
	# The ground goes up as the save stood on it (field_game.gd shape_stop). One from before
	# remote ground was built kept a remote stop's map as it was.
	if save.has("stop_ground"):
		opts["stop_ground"] = String(save["stop_ground"])
	elif String(opts.get("stop_form", "")) == "remote":
		opts["stop_ground"] = ""
	# And with the train's end gap it had: one from before the gap was worked out had END_GAP.
	if save.has("stop_end_gap"):
		opts["stop_end_gap"] = int(save["stop_end_gap"])
	elif String(opts.get("stop_ground", opts.get("stop_form", ""))) in ["edge", "remote"]:
		opts["stop_end_gap"] = StopGround.END_GAP
	if save.has("stop_view_rows"):
		for key: String in ["stop_view_rows", "stop_view_cols", "stop_view_rule"]:
			opts[key] = int(save.get(key, 0))
		if (int(opts["stop_view_rows"]) > 0 or int(opts["stop_view_cols"]) > 0) and int(opts["stop_view_rule"]) != StopGround.VIEW_RULE:
			push_warning("field save view rule changed; restoring legacy state on the saved view size")
	elif String(save.get("place", "")) in StopGround.VIEW_PLACES:
		opts["stop_view_rows"] = 0
		opts["stop_view_cols"] = 0
	if not (save.get("departure", {}) as Dictionary).is_empty():
		opts["departure"] = (save["departure"] as Dictionary).duplicate(true)
	if String(save.get("receipt_id", "")) != "":
		opts["receipt_id"] = String(save["receipt_id"])
	opts["field_resume"] = save
	return opts


## A save that holds the whole running state (version 2 with "runtime"), not only the old fallbacks.
static func exact(save: Dictionary) -> bool:
	if (int(save.get("stop_view_rows", 0)) > 0 or int(save.get("stop_view_cols", 0)) > 0) \
			and int(save.get("stop_view_rule", 0)) != StopGround.VIEW_RULE:
		return false
	return int(save.get("version", 1)) >= 2 and save.has("runtime")


## Exact solids must fit every saved floor before any grid is replaced: its cell count,
## and its width and height where the save keeps them.
static func _grid_sizes_match(game, save: Dictionary) -> bool:
	var levels: Dictionary = save["runtime"].get("levels", {})
	for level in levels:
		if not game.levels.has(level):
			return false
		var grid: FieldGrid = game.levels[level]
		var row: Dictionary = levels[level]
		if row.get("solid", PackedByteArray()).size() != grid.width * grid.height:
			return false
		if row.has("width") and (int(row["width"]) != grid.width or int(row.get("height", -1)) != grid.height):
			return false
	return true


## Version 2 reconnects existing identities before restoring their clocks or callbacks.
static func apply(game, save: Dictionary) -> void:
	if save.get("phase") == "ended":
		return
	var form := StopForm.resolve(save if save.has("stop_form") else game.opts, String(game.data["place_kind"]))
	game.skip_arrival()
	game.begin_resume()
	game.clock.elapsed = float(save["clock"]["elapsed"])
	game.clock.speed = float(save["clock"]["speed"])
	# The work crew is made during play (field_work.gd): each member a save carries is made again first.
	if game.get("work") != null:
		game.work.remake(save.get("people", []))
	for row: Dictionary in save.get("people", []):
		for p in game.people:
			if p.pid == String(row["pid"]):
				_put_person(p, row)
	_restore_sled_envelope(game, save)
	if exact(save):
		game.ammo.clear()
	_put_counts(game.ammo, save.get("ammo", {}))
	game.unloaded.clear()
	_put_counts(game.unloaded, save.get("unloaded", {}))
	game.loaded_wear = (save.get("loaded_wear", []) as Array).duplicate(true)
	game.actions.coal_delivered = float(save["coal"]["delivered"])
	game.actions.coal_spent = float(save["coal"]["spent"])
	if exact(save):
		if _grid_sizes_match(game, save):
			_apply_exact(game, save)
			game.set_stop_form(form)
			return
		push_warning("field save grid size changed; restoring legacy state")
	var boxes: Dictionary = game.data.get("containers", {})
	for id in save.get("containers", {}):
		if boxes.has(id):  # a heap pulled together during the stop is not on the map yet
			var row: Dictionary = save["containers"][id]
			boxes[id]["searched"] = bool(row["searched"])
			boxes[id]["locked"] = bool(row["locked"])
			boxes[id]["items"] = (row["items"] as Array).duplicate(true)
	for id in save.get("spots", {}):
		if game.data["spots"].has(id):
			game.data["spots"][id]["state"] = String(save["spots"][id])
	game.ground_items = (save.get("ground_items", []) as Array).duplicate(true)
	game.decisions = (save.get("decisions", []) as Array).duplicate(true)
	# Version 1 and fallback keep the share this start set up, as the old switch did (decisions 383, 387, 134).
	_put_zombies(game, save.get("zombies", []))
	if game.receipt != null:
		_put_receipt(game.receipt, save.get("receipt_state", {}))
	if exact(save):
		_restore_work_fallback(game, save)
	game.cam_focus = game.player.position
	game._update_camera(1.0)
	Sled.reconcile(game)
	_refresh_restored_view(game)
	game.set_stop_form(form)


## Keep the saved coal pool when grid paths cannot be restored.
static func _restore_fallback_coal(game, runtime: Dictionary, saved_people: Array) -> bool:
	var wagons: Array = game.data.get("wagons", [])
	if not runtime.has("wagon_coal"):
		var removed: float = maxf(game.actions.coal_delivered, 0.0)
		for person: Dictionary in saved_people:
			var brain: Dictionary = person.get("state", {}).get("brain", {})
			if brain.get("load_kind", "coal") == "coal":
				removed += maxf(float(brain.get("load", 0.0)), 0.0)
		if game.work != null:
			for pile: Dictionary in game.work.dropped:
				if pile.get("kind", "") == "coal":
					removed += maxf(float(pile.get("n", 0.0)), 0.0)
		for wagon: Dictionary in wagons:
			if wagon.has("work"):
				var taken: float = minf(maxf(float(wagon.get("coal", 0.0)), 0.0), removed)
				wagon["coal"] = maxf(float(wagon.get("coal", 0.0)) - taken, 0.0)
				removed -= taken
		return false
	var coal: Array = runtime.get("wagon_coal", [])
	var ids: Array = runtime.get("wagon_ids", [])
	var matched: bool = wagons.size() == coal.size()
	if runtime.has("wagon_ids"):
		matched = matched and ids.size() == wagons.size()
		if matched:
			for i in wagons.size():
				if String(ids[i]) != String(wagons[i].get("id", "")):
					matched = false
					break
	if matched:
		for i in wagons.size():
			wagons[i]["coal"] = maxf(float(coal[i]), 0.0)
		return true
	var pool: float = 0.0
	for amount: Variant in coal:
		pool += maxf(float(amount), 0.0)
	for wagon: Dictionary in wagons:
		wagon["coal"] = 0.0
	for wagon: Dictionary in wagons:
		if wagon.has("work"):
			wagon["coal"] = pool
			pool = 0.0
			break
	if pool > 0.0 and game.work != null:
		game.work.dropped.append({"pos": game.player.position, "kind": "coal", "n": pool})
	return false


## Rebuild routes on this grid. Interrupted picks keep seconds, never old callbacks.
static func _restore_work_fallback(game, save: Dictionary) -> void:
	var runtime: Dictionary = save["runtime"]
	if game.work != null:
		_restore_properties(game, game.work, runtime.get("components", {}).get("work", {}))
	var matched: bool = _restore_fallback_coal(game, runtime, save.get("people", []))
	for row: Dictionary in save.get("people", []):
		var p = _person_with_id(game, String(row["pid"]))
		if p == null:
			continue
		var brain: Dictionary = row.get("state", {}).get("brain", {})
		for key: String in ["work_site", "job", "side", "load", "load_kind", "boarded", "board_at", "work_wait", "work_run", "work_haul_flee",
				"work_haul_gave_up", "haul_best_at"]:
			if brain.has(key):
				p.brain[key] = brain[key]
		p.brain.erase("coal_drop")
	if game.work == null:
		return
	for id: String in game.work.sites.keys():
		if not game.data["spots"].has(id):
			game.work.sites.erase(id)
			continue
		var state: Dictionary = game.work.sites[id]
		state["path"] = PackedVector3Array()
		state["path_at"] = -INF
		state["door"] = Vector3.ZERO
		state["cells"] = -1
		state["bright"] = false
		if not matched:
			state["dig_wagon"] = -1
			state["dig_parts"] = []
			state["dig_active"] = {}
	game.work.restore_digs()
	game.actions.work_started = false
	for id: String in game.work.sites:
		if not matched:
			game.work.sites[id]["dig_wagon"] = -1
		if game.work.phase(id) in ["working", "hold", "retreat"]:
			game.actions.work_started = true


## The old/fallback path also keeps sled work by pid and id, with no replay.
static func _restore_sled_envelope(game, save: Dictionary) -> void:
	game.sleds = (save.get("sleds", []) as Array).duplicate(true)
	game.next_sled_id = int(save.get("next_sled_id", 1))
	for p in game.people:
		p.sled_id = 0
		p.sled_stowed_for = 0
		p.sled_weapon_stowed = false
		p.sled_rearm_t = 0.0
		p.sled_serial = 0
		p.sled_job = {}
	for row: Dictionary in save.get("people", []):
		var p = _person_with_id(game, String(row["pid"]))
		if p == null:
			continue
		var saved: Dictionary = _sled_person_state(row.get("state", {}))
		var fields: Dictionary = {}
		for key: String in SLED_PERSON_FIELDS:
			if saved.has(key):
				fields[key] = saved[key]
		_restore_properties(game, p, fields)
		if p.sled_id != 0 or p.sled_weapon_stowed or not p.sled_job.is_empty():
			fields.clear()
			for key: String in ["path", "running", "crouched", "facing", "look", "moving", "stick", "drive_speed", "drive_dir"]:
				if saved.has(key):
					fields[key] = saved[key]
			_restore_properties(game, p, fields)
		if not p.sled_job.is_empty():
			fields.clear()
			for key: String in ["action", "action_label", "action_t", "action_total", "action_done"]:
				if saved.has(key):
					fields[key] = saved[key]
			_restore_properties(game, p, fields)


## Migrate before thawing callbacks: the old drawing action no longer exists.
static func _sled_person_state(saved: Dictionary) -> Dictionary:
	var state: Dictionary = saved.duplicate(true)
	if String(state.get("sled_job", {}).get("kind", "")) == "rearm":
		state["sled_job"] = {}
	if String(state.get("action", "")) == "sled_rearm":
		state["sled_rearm_t"] = maxf(0.0, float(state.get("action_t", 0.0)))
		state["action"] = ""
		state["action_label"] = ""
		state["action_t"] = 0.0
		state["action_total"] = 0.0
		state["action_done"] = {"$call": []}
		if float(state["sled_rearm_t"]) <= 0.0:
			state["sled_weapon_stowed"] = false
			state["sled_stowed_for"] = 0
	return state


static func _put_person(p, row: Dictionary) -> void:
	p.cancel_action()
	p.stop()
	p.position = row["pos"]
	p.bag = String(row["bag"])
	p.items = (row["items"] as Dictionary).duplicate(true)
	# A save from before the three places has none: they keep what they put on.
	Wear.restore(p, row.get("wear", {}))
	p.set_weapon_slots((row["hands"] as Array).duplicate(true))
	var b = p.body
	var body: Dictionary = row["body"]
	b.restore(body)
	p.heat.restore(row.get("heat", {}))
	# How long the dead have eaten at this body (결정 441 (3)): one eaten up stays so. Version 2
	# keeps it in "meta" (PERSON_META), a version-1 row as its own "eaten"; none before it.
	var metadata: Dictionary = row.get("meta", {})
	var key := String(EatRules.EATEN_META)
	if metadata.has(key) or row.has("eaten"):
		p.set_meta(EatRules.EATEN_META, float(metadata.get(key, row.get("eaten", 0.0))))
	elif p.has_meta(EatRules.EATEN_META):
		p.remove_meta(EatRules.EATEN_META)


static func _runtime(game) -> Dictionary:
	var out: Dictionary = {"game": _properties(game, game, GAME_FIELDS), "components": {}, "levels": {}, "spots": {}, "mission": _script_state(game, game.mission_play.mission)}
	for name: String in COMPONENTS:
		out["components"][name] = _script_state(game, game.get(name))
	var doors: Array = []
	for door: Dictionary in game.holdout.doors:
		doors.append(_record(game, door))
	out["holdout_doors"] = doors
	out["hud"] = {"grab_total": game.hud.grab_total}
	out["zombie_system"] = _properties(game, game.zombies, ["next_id", "loot_rng", "lunge_rng", "embed_rng", "lunger_share"])
	for level in game.levels:
		var grid = game.levels[level]
		var level_state: Dictionary = {"solid": grid.solid.duplicate(), "width": grid.width, "height": grid.height,
			"revision": grid.revision, "doors": {}, "windows": {}, "floor_glass": grid.floor_glass.duplicate()}
		for kind: String in ["doors", "windows"]:
			for cell in grid.get(kind):
				level_state[kind][cell] = _record(game, grid.get(kind)[cell])
		out["levels"][level] = level_state
	for id in game.data.get("spots", {}):
		out["spots"][id] = _record(game, game.data["spots"][id])
	# Coal dug from a wagon (field_ai.gd _dug, field_work.gd) is in the map's own rows, which a
	# restart builds afresh: each wagon's coal, in the map's order.
	var wagon_coal: Array = []
	var wagon_ids: Array = []
	for wagon: Dictionary in game.data.get("wagons", []):
		wagon_coal.append(float(wagon.get("coal", 0.0)))
		wagon_ids.append(String(wagon.get("id", "")))
	out["wagon_coal"] = wagon_coal
	out["wagon_ids"] = wagon_ids
	return out


## These small state holders contain script data; their owners and drawing objects
## are reconstructed by the field. Explicit exclusions keep those out of the slot.
static func _script_state(game, object) -> Dictionary:
	var fields: Array[String] = []
	for prop: Dictionary in object.get_property_list():
		var name: String = String(prop["name"])
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) or name in ["game", "tracers"]:
			continue
		if (object == game.mission_play and name == "mission") or (object == game.holdout and name == "doors"):
			continue
		# by_id holds the very rows of bodies (field_train_guard.gd): put back from them on restore.
		if object == game.train_guard and name == "by_id":
			continue
		fields.append(name)
	return _properties(game, object, fields)


static func _properties(game, object, fields: Array) -> Dictionary:
	var out: Dictionary = {}
	for field: String in fields:
		var value: Variant = object.get(field)
		if field == "sled_rearm_t" and float(value) <= 0.0:
			continue
		if field == "action_done":
			if object.action == "":
				value = Callable()
			elif object.action == "swap":
				# The combat callback is a closure with no serializable capture list.
				value = Callable(object, "swap_weapons")
		out[field] = _freeze(game, value)
	return out


static func _record(game, row: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in row:
		if key != "node":
			out[key] = _freeze(game, row[key])
	return out


## References use stable field identities. Instance ids are process-local, including
## keys in combat/work reservations, so they also travel by the person's pid.
static func _freeze(game, value: Variant) -> Variant:
	if value is RandomNumberGenerator:
		return {"$rng": [str(value.seed), str(value.state)]}
	if value is Callable:
		if not value.is_valid():
			return {"$call": []}
		return {"$call": [_freeze(game, value.get_object()), String(value.get_method()), _freeze(game, value.get_bound_arguments())]}
	if value is Object:
		for p in game.people:
			if value == p:
				return {"$person": p.pid}
			if value == p.body:
				return {"$body": p.pid}
		if value == game:
			return {"$owner": "field"}
		for name: String in COMPONENTS + ["zombies"]:
			if value == game.get(name):
				return {"$owner": name}
		push_error("Unsupported object in field save")
		return null
	if value is Dictionary:
		if value.has("id") and value.has("kind") and value.has("pos"):
			var zombie: Dictionary = game.zombies.find(int(value["id"]))
			if is_same(value, zombie):
				return {"$zombie": int(value["id"])}
		for kind: String in ["containers", "spots"]:
			for id in game.data.get(kind, {}):
				if is_same(value, game.data[kind][id]):
					return {"$map": [kind, id]}
		for level in game.levels:
			for kind: String in ["doors", "windows"]:
				for cell in game.levels[level].get(kind):
					if is_same(value, game.levels[level].get(kind)[cell]):
						return {"$grid": [level, kind, cell]}
		for p in game.people:
			for i in p.body.wounds.size():
				if is_same(value, p.body.wounds[i]):
					return {"$wound": [p.pid, i]}
		for i in game.ground_items.size():
			if is_same(value, game.ground_items[i]):
				return {"$ground": i}
		var dictionary: Dictionary = {}
		for key in value:
			var saved_key: Variant = _freeze(game, key)
			if key is int:
				for p in game.people:
					if key == p.get_instance_id():
						saved_key = {"$instance": p.pid}
			dictionary[saved_key] = _freeze(game, value[key])
		return dictionary
	if value is Array:
		var array: Array = []
		for entry in value:
			array.append(_freeze(game, entry))
		return array
	if value is PackedVector3Array or value is PackedByteArray or value is PackedInt32Array or value is PackedStringArray:
		return value.duplicate()
	return value


static func _person_with_id(game, pid: String):
	for p in game.people:
		if p.pid == pid:
			return p
	return null


static func _thaw(game, value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("$person"):
			return _person_with_id(game, String(value["$person"]))
		if value.has("$body"):
			return _person_with_id(game, String(value["$body"])).body
		if value.has("$instance"):
			return _person_with_id(game, String(value["$instance"])).get_instance_id()
		if value.has("$zombie"):
			return game.zombies.find(int(value["$zombie"]))
		if value.has("$map"):
			var at: Array = value["$map"]
			return game.data[at[0]][at[1]]
		if value.has("$grid"):
			var at: Array = value["$grid"]
			return game.levels[at[0]].get(at[1])[at[2]]
		if value.has("$wound"):
			var at: Array = value["$wound"]
			return _person_with_id(game, String(at[0])).body.wounds[int(at[1])]
		if value.has("$ground"):
			return game.ground_items[int(value["$ground"])]
		if value.has("$owner"):
			return game if value["$owner"] == "field" else game.get(value["$owner"])
		if value.has("$call"):
			var call: Array = value["$call"]
			if call.is_empty():
				return Callable()
			return Callable(_thaw(game, call[0]), StringName(call[1])).bindv(_thaw(game, call[2]))
		var dictionary: Dictionary = {}
		for key in value:
			dictionary[_thaw(game, key)] = _thaw(game, value[key])
		return dictionary
	if value is Array:
		var array: Array = []
		for entry in value:
			array.append(_thaw(game, entry))
		return array
	if value is PackedVector3Array or value is PackedByteArray or value is PackedInt32Array or value is PackedStringArray:
		return value.duplicate()
	return value


static func _restore_properties(game, object, saved: Dictionary) -> void:
	for key in saved:
		var current: Variant = object.get(key)
		var value: Variant = saved[key]
		if current is RandomNumberGenerator:
			var pair: Array = value["$rng"]
			current.seed = int(pair[0])
			current.state = int(pair[1])
		else:
			var restored: Variant = _thaw(game, value)
			if current is Array:
				current.assign(restored)
			else:
				object.set(key, restored)


## Old v2 switches mean the forced share; never restore the removed property. With
## neither, the share this start set up stays (decisions 383, 387, 134).
static func _restore_zombie_system(game, saved: Dictionary) -> void:
	var state: Dictionary = saved.duplicate()
	if not state.has("lunger_share") and state.has("lungers_on"):
		state["lunger_share"] = LungerRules.SHARE if bool(state["lungers_on"]) else 0.0
	state.erase("lungers_on")
	var start_share: float = game.zombies.lunger_share
	_restore_properties(game, game.zombies, state)
	# A saved share that is not a share (NaN comes back as -INF) leaves the start's.
	var share: float = game.zombies.lunger_share
	if not is_finite(share) or share < 0.0 or share > 1.0:
		game.zombies.lunger_share = start_share


## Old prologue saves can still be walking to a loud sound at the chase pace.
static func _restore_noise_pace(game, z: Dictionary) -> void:
	var all = game.zombies
	if all.noise_hurry >= all.SPEED_HURRY:
		return   # Act 1 on keeps the chase pace (the act's pace is set up before a restore).
	if z.get("state", "") == "investigate" and z.get("clue_kind", "") == "sound" and float(z.get("speed", 0.0)) == all.SPEED_HURRY:
		z["speed"] = all.noise_hurry


static func _apply_exact(game, save: Dictionary) -> void:
	_restore_sled_envelope(game, save)
	var runtime: Dictionary = save["runtime"]
	for kind: String in ["containers", "spots"]:
		var rows: Dictionary = save["containers"] if kind == "containers" else runtime["spots"]
		var into: Dictionary = game.data[kind]
		for id in into.keys():
			if not rows.has(id):
				into.erase(id)
		for id in rows:
			into[id] = (rows[id] as Dictionary).duplicate(true)
	var wagons: Array = game.data.get("wagons", [])
	var wagon_coal: Array = runtime.get("wagon_coal", [])
	for i in mini(wagons.size(), wagon_coal.size()):
		wagons[i]["coal"] = float(wagon_coal[i])
	for level in runtime["levels"]:
		var grid = game.levels[level]
		var row: Dictionary = runtime["levels"][level]
		grid.solid = row["solid"].duplicate()
		grid.doors = (row["doors"] as Dictionary).duplicate(true)
		grid.windows = (row["windows"] as Dictionary).duplicate(true)
		# The glass fallen from a window onto the floor (field_actions.gd), there to sweep up.
		grid.floor_glass = (row.get("floor_glass", {}) as Dictionary).duplicate(true)
		grid.refresh_paths()
		grid.revision = int(row["revision"])
	game.ground_items = (save.get("ground_items", []) as Array).duplicate(true)
	game.decisions = (save.get("decisions", []) as Array).duplicate(true)
	# Allocate every identity first, then reconnect references without calling spawn().
	game.zombies.list.clear()
	for row: Dictionary in save["zombies"]:
		game.zombies.list.append({"id": int(row["id"])})
	for i in game.zombies.list.size():
		game.zombies.list[i].merge(_thaw(game, save["zombies"][i]), true)
		_restore_noise_pace(game, game.zombies.list[i])
	game.zombies._sense_cells_ready = false
	for row: Dictionary in save["people"]:
		var p = _person_with_id(game, String(row["pid"]))
		if p != null:
			_restore_properties(game, p, _sled_person_state(row.get("state", {})))
			_restore_properties(game, p.aim, row.get("aim", {}))
			var metadata: Dictionary = row.get("meta", {})
			for key: String in PERSON_META:
				if metadata.has(key):
					p.set_meta(key, _thaw(game, metadata[key]))
				elif p.has_meta(key):
					p.remove_meta(key)
	var player = _person_with_id(game, String(save.get("player_pid", "")))
	if player != null:
		game.player = player
	_restore_properties(game, game.mission_play.mission, runtime["mission"])
	for name: String in COMPONENTS:
		if runtime["components"].has(name):
			_restore_properties(game, game.get(name), runtime["components"][name])
	game.train_guard.by_id.clear()
	for row: Dictionary in game.train_guard.bodies:
		game.train_guard.by_id[int(row["id"])] = row
	for door: Dictionary in game.holdout.doors:
		if is_instance_valid(door.get("node")):
			door["node"].queue_free()
	game.holdout.doors = _thaw(game, runtime["holdout_doors"])
	for door: Dictionary in game.holdout.doors:
		door["node"] = null
		if int(door["wall"]) > 0:
			game.holdout._show_wall(door)
	_restore_zombie_system(game, runtime.get("zombie_system", {}))
	game.hud.grab_total = float(runtime.get("hud", {}).get("grab_total", game.hud.grab_total))
	if game.receipt != null:
		_put_receipt(game.receipt, save.get("receipt_state", {}))
	_restore_properties(game, game, runtime["game"])
	if game.work != null:
		game.work.restore_digs()
	Sled.reconcile(game)
	_refresh_restored_view(game)
	# Sight/view rebuilding must not advance the saved simulation or random streams.
	_restore_properties(game, game, runtime["game"])
	Sled.reconcile(game)
	# Rendering establishes pose caches. Keep their saved clocks too: showing the
	# paused frame is not an extra simulation/render step on the body's timeline.
	for i in game.zombies.list.size():
		var restored: Dictionary = _thaw(game, save["zombies"][i])
		game.zombies.list[i].clear()
		game.zombies.list[i].merge(restored)
		_restore_noise_pace(game, game.zombies.list[i])
	for row: Dictionary in save["people"]:
		var p = _person_with_id(game, String(row["pid"]))
		if p != null:
			var metadata: Dictionary = row.get("meta", {})
			for key: String in PERSON_META:
				if metadata.has(key):
					p.set_meta(key, _thaw(game, metadata[key]))
				elif p.has_meta(key):
					p.remove_meta(key)


static func _refresh_restored_view(game) -> void:
	if game.view == null:
		return
	game.view.update_sleds(game.sleds, game.people)
	# Boxes are drawn in shared chunk meshes (map_view.gd): ask the view, not its nodes.
	for id in game.view.container_ids():
		if not game.data["containers"].has(id):
			game.view.remove_object_container(id)
	for id in game.data["containers"]:
		if game.view.has_container(id):
			game.view.update_container(id)
		else:
			game.view.add_container(id)
	for id in game.data["spots"]:
		if game.view.spot_nodes.has(id):
			game.view.update_spot(id)
	if game.work != null:
		game.work.paint_digs()
	for cell in game.grid.doors:
		if game.view.door_nodes.has(cell) or (game.view.buildings and game.view.buildings.draws_cell(cell)):
			game.view.update_door(cell)
	for cell in game.grid.windows:
		if game.view.window_nodes.has(cell) or (game.view.buildings and game.view.buildings.draws_cell(cell)):
			game.view.update_window(cell)
	for key in game.view.manhole_nodes:
		game.view.update_manhole(key, not game.director.is_open(key), float(game.lid_open.get(key, 0.0)) > 0.0)
	game._update_camera(0.0)
	game._refresh_vision()
	var level: int = game.level_of(game.player.position)
	game.view.show_levels(level)
	game.view.cut_away(game.grid_at(game.player.position).building_at(FieldGrid.cell_of(game.player.position)), level)
	for p in game.people:
		p.visible = game.level_shown(game.level_of(p.position)) and game._person_visible(p) and not game.rode_off.has(p)
		var saved_look: float = p.look
		p.refresh_view(p.visible)
		# refresh_view normally turns by the frame delta; a restored still must not.
		p.look = saved_look
		p.rotation.y = p.facing if p.turn_rate <= 0.0 else saved_look
	game.zombies.render(game.camera, game.seen_now, game.mask_on)


static func _put_counts(into: Dictionary, counts: Dictionary) -> void:
	for id in counts:
		into[id] = int(counts[id])


static func _put_zombies(game, rows: Array) -> void:
	var all = game.zombies
	all.list.clear()
	var top := 0
	for row: Dictionary in rows:
		var z: Dictionary = all.spawn(String(row["kind"]), row["pos"], {"horde": int(row.get("horde", -1)), "name": String(row.get("name", ""))})
		var state := String(row["state"])
		if state in ["downed", "dead"]:
			DeadPose.mark_fall(z, game.people)  # lies as it fell, not standing
		z["id"] = int(row["id"])
		z["state"] = state if state in RESUME_STATES else "wander"
		# A version-2 row is the whole record: pockets not rolled yet stay unrolled (zombies.gd rolls them when asked).
		if row.has("loot"):
			z["loot"] = (row["loot"] as Array).duplicate(true)
		else:
			z.erase("loot")
		z["searched"] = bool(row.get("searched", false))
		# Where it keeps to: its pockets and clothes are rolled by that place when first asked.
		if row.get("home") is Vector3:
			z["home"] = row["home"]
		if row.get("worn") is Dictionary:
			z["worn"] = (row["worn"] as Dictionary).duplicate(true)
			z["stripped"] = bool(row.get("stripped", false))
		top = maxi(top, int(row["id"]))
	all.next_id = top + 1


## The receipt's own fields, read and written back as they are (it has no loader of
## its own). Typed lists keep their type: they are filled, not replaced.
static func _receipt_state(r) -> Dictionary:
	var out := {}
	for prop in r.get_property_list():
		var name := String(prop["name"])
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and name.begins_with("_"):
			var v = r.get(name)
			out[name] = v.duplicate(true) if (v is Array or v is Dictionary) else v
	return out


static func _put_receipt(r, state: Dictionary) -> void:
	for name in state:
		var now = r.get(name)
		var v = state[name]
		if now is Array:
			(now as Array).assign(v)
		elif now is Dictionary:
			var into: Dictionary = now
			for key in into.keys():
				if not (v as Dictionary).has(key):
					into.erase(key)
			for key in v:
				if into.get(key) is Array:
					(into[key] as Array).assign(v[key])  # the people lists are typed
				else:
					into[key] = v[key]
		elif now is int:
			r.set(name, int(v))
		elif now is float:
			r.set(name, float(v))
		elif now is bool:
			r.set(name, bool(v))
		elif now is String:
			r.set(name, String(v))


static func _bytes_hash(bytes: PackedByteArray) -> PackedByteArray:
	var context: HashingContext = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		return PackedByteArray()
	return context.finish()


static func _remember_good(path: String, bytes: PackedByteArray) -> void:
	var digest: PackedByteArray = _bytes_hash(bytes)
	if digest.size() == 32:
		_known_good[path] = digest
	else:
		_known_good.erase(path)


## Writes over the slot: the new file goes down whole first, the last one is kept as .bak.
static func write(d: Dictionary, path: String = PATH) -> bool:
	var fail_step := _test_fail_step
	_test_fail_step = ""
	var text := to_json(d)
	var bytes := text.to_utf8_buffer()
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	var payload := bytes
	if fail_step == "short":
		payload = bytes.slice(0, maxi(0, bytes.size() - 1))
	elif fail_step == "tamper":
		payload = bytes.duplicate()
		var at := payload.find(46)  # A decimal point becomes a digit: same length, still valid sample JSON.
		payload[at if at >= 0 else 0] = 48
	f.store_buffer(payload)
	f.flush()
	var error: Error = f.get_error()
	f.close()
	if fail_step == "write_error":
		error = ERR_FILE_CANT_WRITE
	if error != OK:
		DirAccess.remove_absolute(tmp)
		return false
	var written := FileAccess.get_file_as_bytes(tmp)
	if written != bytes or from_json(text).is_empty():
		DirAccess.remove_absolute(tmp)
		return false
	var backup := path + ".bak"
	if FileAccess.file_exists(path):
		var previous_file := FileAccess.open(path, FileAccess.READ)
		if previous_file == null:
			DirAccess.remove_absolute(tmp)
			return false
		var previous_length := previous_file.get_length()
		var previous_bytes := previous_file.get_buffer(previous_length)
		error = previous_file.get_error()
		previous_file.close()
		if fail_step == "read_previous":
			error = ERR_FILE_CANT_READ
		if error != OK or previous_bytes.size() != previous_length:
			DirAccess.remove_absolute(tmp)
			return false
		var previous_hash: PackedByteArray = _bytes_hash(previous_bytes)
		var known_hash: PackedByteArray = _known_good.get(path, PackedByteArray())
		var previous_good: bool = previous_hash.size() == 32 and previous_hash == known_hash
		if not previous_good:
			_test_previous_parses += 1
			previous_good = not from_json(previous_bytes.get_string_from_utf8()).is_empty()
		var moved: String = backup if previous_good else path + ".broken"
		if FileAccess.file_exists(moved) and DirAccess.remove_absolute(moved) != OK:
			DirAccess.remove_absolute(tmp)
			return false
		if DirAccess.rename_absolute(path, moved) != OK:
			DirAccess.remove_absolute(tmp)
			return false
	if fail_step != "rename_tmp" and DirAccess.rename_absolute(tmp, path) == OK:
		_remember_good(path, written)
		return true
	if not FileAccess.file_exists(path) and FileAccess.file_exists(backup):
		DirAccess.rename_absolute(backup, path)
	DirAccess.remove_absolute(tmp)
	return false


## The last whole save: the slot, or the one before it when the slot is broken; {} when none.
static func read(path: String = PATH) -> Dictionary:
	for at in [path, path + ".bak"]:
		if FileAccess.file_exists(at):
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(at)
			_test_reads += 1
			var d: Dictionary = from_json(bytes.get_string_from_utf8())
			if not d.is_empty():
				if at == path:
					_remember_good(path, bytes)
				return d
	return {}


## A caller-owned, short-lived boot read, including an empty result. Hashes stream
## both candidates: a deferred scene switch can see a write, clear, or backup change.
## This stores no parsed save globally and does not change the write-validation cache.
static func read_for_start(path: String, context: Dictionary) -> Dictionary:
	var files: Array[String] = []
	for at: String in [path, path + ".bak"]:
		files.append(FileAccess.get_sha256(at) if FileAccess.file_exists(at) else "")
	if context.get("path") != path or context.get("files") != files:
		context["path"] = path
		context["files"] = files
		context["saved"] = read(path)
	return context["saved"]


static func clear(path: String = PATH) -> void:
	_known_good.erase(path)
	for at in [path, path + ".tmp", path + ".bak", path + ".broken"]:
		if FileAccess.file_exists(at):
			DirAccess.remove_absolute(at)


static func _encode(v: Variant) -> Variant:
	if v is int:
		return {"$type": "int", "value": str(v)}
	if v is float and not is_finite(v):
		return {"$type": "float", "value": "inf" if v > 0.0 else "-inf"}
	if v is Vector3:
		return {"$type": "Vector3", "value": [v.x, v.y, v.z]}
	if v is Vector2:
		return {"$type": "Vector2", "value": [v.x, v.y]}
	if v is Vector2i:
		return {"$type": "Vector2i", "value": [v.x, v.y]}
	if v is Rect2i:
		return {"$type": "Rect2i", "value": [v.position.x, v.position.y, v.size.x, v.size.y]}
	if v is Color:
		return {"$type": "Color", "value": [v.r, v.g, v.b, v.a]}
	# A grid's cells and the sight memory are runs of bytes or int32s, tens of thousands
	# long: one base64 line, not a typed object a number (about 30 bytes for each byte).
	# (Marshalls reports an empty run as an error: that one is "".)
	if v is PackedByteArray:
		return {"$type": "PackedByteArray", "base64": "" if v.is_empty() else Marshalls.raw_to_base64(v)}
	if v is PackedInt32Array:
		# Little-endian, as on every device the game ships to (arm64, x86-64).
		return {"$type": "PackedInt32Array", "base64": "" if v.is_empty() else Marshalls.raw_to_base64((v as PackedInt32Array).to_byte_array())}
	if v is PackedVector3Array or v is PackedStringArray:
		return {"$type": type_string(typeof(v)), "value": _encode(Array(v))}
	if v is Dictionary:
		var strings_only: bool = true
		for key in v:
			if not (key is String or key is StringName):
				strings_only = false
		if not strings_only:
			var pairs: Array = []
			for key in v:
				pairs.append([_encode(key), _encode(v[key])])
			return {"$type": "Dictionary", "value": pairs}
		var out := {}
		for k in v:
			if k == "dig_parts":
				out[String(k)] = _encode(FieldWork.clean_dig_parts(v[k], int(v.get("dig_wagon", -1))))
			else:
				out[String(k)] = _encode(v[k])
		return out
	if v is Array:
		var out: Array = []
		for e in v:
			out.append(_encode(e))
		return out
	return v


## A parsed value back as the encoder had it (_encode). Only what the encoder writes reads: a
## value that is not (a typed int that is not its text, a vector a number short, an unknown
## tag) sets _decode_bad and gives null, so a broken file is never half read into a guessed
## board. A typed parent (a packed run, a typed map) checks each raw child's form before it
## decodes it and stops at the first that fails, before building anything; a plain map or list
## decodes all its children and then drops itself, before the dig_parts clean-up, if one failed.
## decode_checked is the entrance.
static func _decode(v: Variant) -> Variant:
	if v is Dictionary:
		# No game state has a "$type" key (saves of format 1 to 3, and the game's data): a map
		# with one is a tag, and a tag that is not whole is a broken file.
		if v.has("$type"):
			return _decode_tag(v)
		var out := {}
		for k in v:
			var e = v[k]
			if k in VEC_KEYS and e is Array and e.size() == 3:
				# Format 1 wrote a place as a bare [x, y, z] (it had no tags).
				if not _numbers(e, 3):
					return _bad()
				out[k] = Vector3(float(e[0]), float(e[1]), float(e[2]))
			else:
				out[k] = _decode(e)
		# A broken child left a null here and built nothing from it: stop before the clean-up.
		if _decode_bad:
			return null
		if out.has("dig_parts"):
			out["dig_parts"] = FieldWork.clean_dig_parts(out["dig_parts"], int(out.get("dig_wagon", -1)))
		return out
	if v is Array:
		var out: Array = []
		for e in v:
			out.append(_decode(e))
		return null if _decode_bad else out
	return v


## One typed value: exactly {"$type", "value"}, or {"$type", "base64"} for a packed run.
static func _decode_tag(v: Dictionary) -> Variant:
	var type: Variant = v["$type"]
	if not type is String or v.size() != 2:
		return _bad()
	# A typed value is by far the most common tag (every int in a save): ask for it first.
	if not v.has("value"):
		return _unpack(type, v["base64"]) if v.has("base64") and type in BASE64_TAGS else _bad()
	var value: Variant = v["value"]
	if type == "int":
		var n: Variant = _int_of_text(value)
		return _bad() if n == null else n
	if type == "float":
		if value is String and value == "inf":
			return INF
		if value is String and value == "-inf":
			return -INF
		return _bad()
	if NUMBER_TAGS.has(type):
		if not _numbers(value, NUMBER_TAGS[type]):
			return _bad()
		match type:
			"Vector3": return Vector3(float(value[0]), float(value[1]), float(value[2]))
			"Vector2": return Vector2(float(value[0]), float(value[1]))
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	if INT_TAGS.has(type):
		if not value is Array or (value as Array).size() != INT_TAGS[type]:
			return _bad()
		for e: Variant in value:
			if not _int_component(e, INT32_MIN, INT32_MAX):
				return _bad()
		if type == "Vector2i":
			return Vector2i(int(value[0]), int(value[1]))
		return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))
	if type == "Dictionary":
		return _decode_pairs(value)
	if not type in LIST_TAGS or not value is Array:
		return _bad()
	return _decode_run(type, value)


## A packed run written as a list: each raw element is checked for the one form the encoder
## gives it before anything is decoded or built (never the general map path, whose dig_parts
## clean-up reads other keys), and goes straight into the packed array in one pass.
static func _decode_run(type: String, list: Array) -> Variant:
	var count: int = list.size()
	if type == "PackedStringArray":
		for e: Variant in list:
			if not e is String:
				return _bad()
		return PackedStringArray(list)
	if type == "PackedVector3Array":
		var places := PackedVector3Array()
		places.resize(count)
		for i: int in count:
			var e: Variant = list[i]
			if not e is Dictionary or (e as Dictionary).get("$type") != "Vector3":
				return _bad()
			var place: Variant = _decode_tag(e)
			if _decode_bad:
				return null
			places[i] = place
		return places
	# Format 2 wrote byte and int32 runs as a list of typed ints (one run can hold tens of
	# thousands): each is read where it lands, no list in between.
	if type == "PackedByteArray":
		var bytes := PackedByteArray()
		bytes.resize(count)
		for i: int in count:
			var e: Variant = list[i]
			if not e is Dictionary:
				return _bad()
			var tag: Dictionary = e
			if tag.size() != 2 or tag.get("$type") != "int":
				return _bad()
			# Text only, as _int_of_text: a StringName "7" must not find the key "7".
			var text: Variant = tag.get("value")
			if not text is String:
				return _bad()
			var b: Variant = BYTE_TEXTS.get(text)
			if b == null:
				return _bad()
			bytes[i] = b
		return bytes
	var ints := PackedInt32Array()
	ints.resize(count)
	for i: int in count:
		var n: Variant = _typed_int(list[i])
		if n == null or n < INT32_MIN or n > INT32_MAX:
			return _bad()
		ints[i] = n
	return ints


## A raw {"$type": "int", "value": text} element as its int, or null when it is not one.
static func _typed_int(e: Variant) -> Variant:
	if not e is Dictionary or (e as Dictionary).size() != 2 or (e as Dictionary).get("$type") != "int":
		return null
	return _int_of_text((e as Dictionary).get("value"))


## A map with keys that are not all text: [key, value] pairs, each key once.
static func _decode_pairs(value: Variant) -> Variant:
	if not value is Array:
		return _bad()
	var dictionary: Dictionary = {}
	for pair: Variant in value:
		if not pair is Array or (pair as Array).size() != 2:
			return _bad()
		var key: Variant = _decode(pair[0])
		if _decode_bad:
			return null
		# The encoder walks a map's keys once: a repeated key would drop the value before it.
		# Only an infinite float key can repeat in its own output (it writes NaN as "-inf" too):
		# that one keeps the last value, as before.
		if dictionary.has(key) and not (key is float and is_inf(key)):
			return _bad()
		var item: Variant = _decode(pair[1])
		if _decode_bad:
			return null
		dictionary[key] = item
	return dictionary


## The int an int tag's text stands for, or null when it is not the encoder's text (str(v): ASCII
## digits, a minus only, no leading zero, no -0) inside signed 64 bits. Never through a float:
## past 2^53 a float drops the last digits. is_valid_int (ASCII digits after one optional sign,
## nothing else) and two checks instead of a RegEx: a format 2 field save holds over 200 000
## int tags, and RegEx.search cost about ten times as much a tag (11-06, measured on this PC).
static func _int_of_text(value: Variant) -> Variant:
	_test_int_texts += 1
	if not value is String:
		return null
	# Checks by character code, no new string for the common short text: of three ways measured
	# on this PC (11-06, 100 000 texts, least of 7) this was the cheapest, 1.19 us a text against
	# 1.49 us for reading it back through str(); the old unchecked int() was 0.12 us.
	var text: String = value
	var size: int = text.length()
	if size > INT64_MIN_DIGITS.length() + 1 or not text.is_valid_int():
		return null
	var first: int = text.unicode_at(0)
	if first == 43:  # "+": the encoder never writes it
		return null
	var start: int = 1 if first == 45 else 0  # after a "-"
	# A leading zero ("007") or a negative zero ("-0") is not the encoder's text.
	if text.unicode_at(start) == 48 and (size > start + 1 or start == 1):
		return null
	# The 64-bit edge: compare the digits as text before to_int, which would wrap or error.
	var digits: int = size - start
	if digits > INT64_MAX_DIGITS.length():
		return null
	if digits == INT64_MAX_DIGITS.length() and text.substr(start).casecmp_to(INT64_MIN_DIGITS if start == 1 else INT64_MAX_DIGITS) > 0:
		return null
	return text.to_int()


## A list of exactly n JSON numbers. Infinite ones read too: the encoder writes a vector's
## components bare, and Vector3.INF (a stop with no train door, field_ai.gd _board_door) as 1e99999.
static func _numbers(value: Variant, n: int) -> bool:
	if not value is Array or (value as Array).size() != n:
		return false
	for e: Variant in value:
		if not (e is float or e is int):
			return false
	return true


## A whole, finite number from lo to hi (JSON brings every number back as a float).
static func _int_component(e: Variant, lo: int, hi: int) -> bool:
	if e is int:
		return e >= lo and e <= hi
	if not e is float or not is_finite(e) or e != floorf(e):
		return false
	return e >= lo and e <= hi


static func _bad() -> Variant:
	_decode_bad = true
	return null


## A whole parsed save decoded (_decode), or null when any value in it is not one the encoder
## writes: the field slot, the slice and train slots (slice_save.gd) and the test-only train
## loader (save_slot.gd) read through here, and so do the three writers judging the slot they
## are about to set aside as .bak or .broken.
static func decode_checked(v: Variant) -> Variant:
	_decode_bad = false
	var decoded: Variant = _decode(v)
	if _decode_bad:
		_decode_bad = false
		return null
	return decoded


## A base64 run back as the packed array it was (_encode); a line that is not base64, or an
## int32 run cut between numbers, marks the save broken (_decode_bad) rather than guess.
static func _unpack(kind: String, text: Variant) -> Variant:
	if not text is String or (text as String).length() % 4 != 0 or _base64_line.search(text) == null:
		_decode_bad = true
		return null
	var line: String = text
	var raw: PackedByteArray = PackedByteArray() if line.is_empty() else Marshalls.base64_to_raw(line)
	var padding: int = 2 if line.ends_with("==") else (1 if line.ends_with("=") else 0)
	# Three bytes a four-letter group, less the padding: what a real base64 line decodes to.
	if raw.size() != (line.length() >> 2) * 3 - padding:
		_decode_bad = true
		return null
	match kind:
		"PackedByteArray":
			return raw
		"PackedInt32Array":
			if raw.size() % 4 != 0:
				_decode_bad = true
				return null
			return raw.to_int32_array()
	_decode_bad = true
	return null
