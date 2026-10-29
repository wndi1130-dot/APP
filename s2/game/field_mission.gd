extends RefCounted
## The stop's purpose in the field (content_variety_first_build 2부): puts the
## goal places on the Sulechów map, answers taps on them, and writes how the
## goals stood when the train leaves. With no mission kind it does nothing.
##
## Track office survey ("survey"): look at the switch and the signal outside
## (silent), find the track log in the station office or up the signal box
## (a locked box: picked quietly it takes time, broken it is loud), and a
## cellar store that may be left alone. No work crew comes down.
##
## Loading yard ("depot"): the work crew loads coal as on the plain stop, and
## once they are down one card asks whether two of them mend the conveyor
## first (scrap, minutes of two pairs of hands; then the belt loads twice as
## fast, the pickaxes stop and the belt is what is heard). One decision, no
## button to keep pressing. What was mended stays as the place's note; it is
## not a supply for a later visit (user decision, first build).
## All numbers here are first guesses, to be set on the phone.

const FieldGrid = preload("res://game/world/field_grid.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const Mission = preload("res://game/sim/mission.gd")

const INSPECT_TIME: float = 6.0
const DEEP_TIME: float = 30.0
const PICK_TIME: float = 25.0     # the quiet way into a locked record box
const BREAK_TIME: float = 2.0     # the loud way
## Outside things to look at: id, name, cell, goal, part, the fact it shows.
const SURVEY_SPOTS: Array = [
	["sv_switch", "분기기", Vector2i(50, 20), "inspect", "outside", "switch", "switch_east_frozen"],
	["sv_signal", "신호기", Vector2i(114, 5), "inspect", "outside", "signal", "signal_east_dark"],
	["sv_store", "지하 보관실 내림문", Vector2i(35, 23), "deep", "deep", "store", "plough_stored"],
]
## The track log lies in two places; either one will do.
## id, name, cell, building, level.
const SURVEY_LOGS: Array = [
	["sv_log_office", "역무실 선로 기록함", Vector2i(31, 23), 0, 0],
	["sv_log_signal", "신호소 선로 기록함", Vector2i(105, 8), 1, 1],
]
const LOG_FACTS: Array[String] = ["switch_east_frozen", "water_next_alive"]
const CONVEYOR_CELL := Vector2i(67, 21)
const REPAIR_SCRAP: int = 2
const REPAIR_HANDS: int = 2
const REPAIR_WORK: float = 360.0   # person-seconds: two people, three minutes
const REPAIR_STEP: float = 10.0
const BELT_MULT: float = 2.0       # coal per trip once the belt runs
const BELT_NOISE: float = 40.0     # the running belt is heard this often (normal)

var game
var mission: Mission
var opened: Array[String] = []    # record boxes opened this stop
var repair_done: float = 0.0      # person-seconds put into the conveyor
var belt_noise_t: float = 0.0


func _init(field_game) -> void:
	game = field_game
	mission = Mission.new(game.mission)


func active() -> bool:
	return mission.kind != ""


## Called once the map is built and before it is drawn.
func place() -> void:
	if mission.kind == "depot":
		game.data["spots"]["dp_conveyor"] = {"kind": "conveyor", "cell": CONVEYOR_CELL, "name": "적재 컨베이어", "state": "stopped"}
		game.data["labels"].append({"text": "적재 컨베이어", "cell": CONVEYOR_CELL + Vector2i(0, 1)})
	if mission.kind != "survey":
		return
	for row: Array in SURVEY_SPOTS:
		game.data["spots"][row[0]] = {"kind": row[3], "cell": row[2], "name": row[1], "state": "unseen", "goal": row[4], "part": row[5], "fact": row[6]}
		game.data["labels"].append({"text": row[1], "cell": row[2] + Vector2i(0, 1)})
	for row: Array in SURVEY_LOGS:
		game.data["containers"][row[0]] = {"id": row[0], "name": row[1], "cell": row[2], "building": row[3], "search": 5.0, "items": ["document"], "locked": true, "level": row[4], "searched": false, "pick": PICK_TIME}


func opening_line() -> String:
	match mission.kind:
		"survey":
			return "이번 일: 분기기·신호기 살피기 · 역무실이나 신호소에서 선로 기록 찾기 · 작업조 없이"
		"depot":
			return "이번 일: 측선 석탄 %d 싣기 · 작업조를 부르면 적재 컨베이어 고칠지 정하기" % int(mission.goal("load")["amount"])
	return ""


## The goals as one short line for the clock box: each goal that must be done,
## and an extra one only once someone has started on it. "" on a plain stop.
func goal_line() -> String:
	var bits: Array = []
	for g: Dictionary in mission.goals:
		var touched: bool = not (g["got"] as Array).is_empty() or float(g["have"]) > 0.0
		if g["extra"] and not touched:
			continue
		bits.append(mission.progress_line(g["id"]) + (" ✓" if mission.is_done(g["id"]) else ""))
	return " · ".join(bits)


## The work crew is not called on a stop that is not for hauling.
func crew_allowed() -> bool:
	return mission.kind != "survey"


func is_mission_spot(id: String) -> bool:
	return String(game.data["spots"][id].get("kind", "")) in ["inspect", "deep", "conveyor"]


func spot(p, id: String) -> void:
	var s: Dictionary = game.data["spots"][id]
	if s["state"] == "seen":
		if p == game.player:
			game.hud.toast("%s: 이미 살폈다." % s["name"])
		return
	if s["kind"] == "deep":
		p.start_action("inspect", "보관실 살피기", DEEP_TIME, _seen.bind(p, id))
	else:
		p.start_action("inspect", "살피기", INSPECT_TIME, _seen.bind(p, id))


func _seen(_p, id: String) -> void:
	var s: Dictionary = game.data["spots"][id]
	s["state"] = "seen"
	game.view.update_spot(id)
	mission.learn(String(s["fact"]))
	_mark(String(s["goal"]), String(s["part"]))


## A locked record box: the card that asks how to get in.
func lock_card(p, id: String) -> void:
	var c: Dictionary = game.data["containers"][id]
	game.hud.card("record_lock", "%s이 잠겨 있다." % c["name"], [
		{"id": "quiet", "label": "조용히 딴다", "say": "\"서두르지 마. 소리 내지 말고.\"", "cost": "%d초 · 소리 없음" % int(PICK_TIME)},
		{"id": "break", "label": "부순다", "say": "\"시간이 없다. 부숴.\"", "cost": "%d초 · 큰 소리" % int(BREAK_TIME)},
		{"id": "leave", "label": "그냥 둔다", "say": "\"다른 데서 찾는다.\"", "cost": "없음"},
	], Callable(self, "_lock_choice").bind(p, id))


func _lock_choice(choice: String, p, id: String) -> void:
	if choice == "leave":
		return
	game.decisions.append({"id": "record_lock", "choice": choice})
	if choice == "quiet":
		p.start_action("pick", "조용히 따기", PICK_TIME, _unlocked.bind(id))
	else:
		p.start_action("pry", "부수기", BREAK_TIME, _broken.bind(p, id))


func _broken(p, id: String) -> void:
	game.make_sound(FieldGrid.center(game.data["containers"][id]["cell"]), SimNoise.Level.LOUD, "kick", p)
	_unlocked(id)


func _unlocked(id: String) -> void:
	game.actions._unlock(id)
	if not opened.has(id):
		opened.append(id)


## A container was searched: the track log counts wherever it was found.
func searched(id: String) -> void:
	if not game.data["containers"][id].has("pick"):
		return
	for fact in LOG_FACTS:
		mission.learn(fact)
	_mark("records", "log")


func _mark(goal: String, part: String) -> void:
	var was_done := mission.all_done()
	if not mission.mark(goal, part, game.clock.elapsed):
		return
	game.hud.toast(mission.progress_line(goal))
	if mission.all_done() and not was_done:
		# Told, not ended: leaving is still the player's call.
		game.set_radio("기관사: 볼 것은 다 본 것 같습니다. 떠날 때는 말씀만 하십시오.", "reply")


# ---------------------------------------------------------------- loading yard

func conveyor() -> Dictionary:
	return game.data["spots"].get("dp_conveyor", {})


func belt_running() -> bool:
	return String(conveyor().get("state", "")) == "running"


## Coal a carrier takes per trip: more off a running belt.
func load_mult() -> float:
	return BELT_MULT if belt_running() else 1.0


func scrap_at_hand() -> int:
	var n := 0
	for p in game.squad:
		if p.is_alive():
			n += int(p.items.get("scrap", 0))
	return n


## The crew is down: on a loading-yard stop the one card comes up. True if it did.
func crew_down(p) -> bool:
	if mission.kind != "depot":
		return false
	conveyor_card(p)
	return true


func conveyor_card(p) -> void:
	var c := conveyor()
	if c.is_empty():
		return
	if c["state"] != "stopped":
		game.hud.toast("적재 컨베이어: %s" % {"part": "고치는 중", "running": "돌고 있다"}.get(c["state"], c["state"]))
		return
	if not game.actions.work_started:
		game.hud.toast("적재 컨베이어가 서 있다. 작업조가 내려와야 손댈 수 있다.")
		return
	var have := scrap_at_hand()
	game.hud.card("depot_conveyor", "적재 컨베이어가 서 있다. 고치면 빨리 싣지만 손 둘이 한동안 빠진다.", [
		{"id": "load", "label": "바로 싣는다", "say": "\"손은 다 삽으로. 실을 수 있는 만큼 싣는다.\"", "cost": "지금 속도 · 곡괭이 소리"},
		{"id": "repair", "label": "고치고 싣는다", "say": "\"둘은 설비를 봐. 돌기만 하면 금방이다.\"", "cost": "고철 %d (가진 것 %d) · 둘이 %d분 · 고치면 %d배, 설비 도는 소리" % [REPAIR_SCRAP, have, int(REPAIR_WORK / REPAIR_HANDS / 60.0), int(BELT_MULT)]},
	], Callable(self, "_conveyor_choice").bind(p))


func _conveyor_choice(choice: String, _p) -> void:
	if choice != "repair":
		game.decisions.append({"id": "depot_conveyor", "choice": "load"})
		return
	if scrap_at_hand() < REPAIR_SCRAP:
		game.hud.toast("고철이 모자란다. 구해 오면 컨베이어를 눌러 다시 정한다.")
		return
	var left := REPAIR_SCRAP
	for q in game.squad:
		var n: int = mini(left, int(q.items.get("scrap", 0))) if q.is_alive() else 0
		if n > 0:
			q.take_item("scrap", n)
			left -= n
	var hands := 0
	for q in game.crew:
		if hands < REPAIR_HANDS and q.is_alive() and q.role == "worker":
			q.brain["job"] = "repair"
			hands += 1
	game.decisions.append({"id": "depot_conveyor", "choice": "repair"})
	conveyor()["state"] = "part"
	game.view.update_spot("dp_conveyor")
	mission.mark("repair", "begun", game.clock.elapsed)


## A carrier told to mend the conveyor: walk there, then work in short steps.
## Returns the point to walk to, or null when the step was started here.
func repair_step(p):
	var at := FieldGrid.center(CONVEYOR_CELL) + Vector3(0.9 if int(p.brain.get("side", 0)) == 0 else -0.9, 0, 0)
	if p.position.distance_to(at) > 1.6:
		return at
	p.start_action("repair", "설비 고치기", REPAIR_STEP, _repaired.bind(p))
	return null


func _repaired(_p) -> void:
	if belt_running():
		return
	repair_done += REPAIR_STEP
	if repair_done < REPAIR_WORK:
		return
	conveyor()["state"] = "running"
	game.view.update_spot("dp_conveyor")
	for q in game.crew:
		if q.brain.get("job", "") == "repair":
			q.brain["job"] = "dig"
	mission.mark("repair", "running", game.clock.elapsed)
	belt_noise_t = 0.0
	game.set_radio("기관사: 컨베이어가 돕니다. 이제 빨리 실립니다.", "reply")


## The running belt is heard in place of the pickaxes. True while it runs.
func belt_noise(delta: float) -> bool:
	if not belt_running():
		return false
	belt_noise_t -= delta
	if belt_noise_t <= 0.0:
		belt_noise_t = BELT_NOISE
		game.make_sound(FieldGrid.center(CONVEYOR_CELL), SimNoise.Level.NORMAL, "bang")
	return true


## Coal was put down at the train.
func loaded() -> void:
	if mission.kind != "depot":
		return
	if mission.fill("load", game.actions.coal_delivered, game.clock.elapsed):
		game.set_radio("기관사: 실을 만큼 실었습니다. 떠날 때는 말씀만 하십시오.", "reply")


## The train leaves (or the stop is lost): how each goal stood goes on record.
func finish(reason: String) -> void:
	if not active():
		return
	game.receipt.place_note("goals", mission.states(reason))
	game.receipt.place_note("facts", mission.facts.duplicate())
	game.receipt.place_note("opened", opened.duplicate())
	if not conveyor().is_empty():
		game.receipt.place_note("conveyor", String(conveyor()["state"]))
	game.telemetry.goals = mission.log_rows(reason)
