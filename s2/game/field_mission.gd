extends RefCounted
## The stop's purpose in the field (content_variety_first_build 2부): puts the
## goal places on the Sulechów map, answers taps on them, and writes how the
## goals stood when the train leaves. With no mission kind it does nothing.
##
## Track office survey ("survey"): look at the switch and the signal outside
## (silent), find the track log in the station office or up the signal box
## (a locked box: picked quietly it takes time, broken it is loud), and a
## cellar store that may be left alone. No work crew comes down.
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

var game
var mission: Mission
var opened: Array[String] = []    # record boxes opened this stop


func _init(field_game) -> void:
	game = field_game
	mission = Mission.new(game.mission)


func active() -> bool:
	return mission.kind != ""


## Called once the map is built and before it is drawn.
func place() -> void:
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
			return "이번 일: 분기기와 신호기를 살피고, 역무실이나 신호소에서 선로 기록을 찾는다. 작업조는 부르지 않는다."
	return ""


## The work crew is not called on a stop that is not for hauling.
func crew_allowed() -> bool:
	return mission.kind != "survey"


func is_mission_spot(id: String) -> bool:
	return String(game.data["spots"][id].get("kind", "")) in ["inspect", "deep"]


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
		game.set_radio("기관사: 볼 것은 다 본 모양이군. 떠날 때는 자네가 정하게.", "reply")


## The train leaves (or the stop is lost): how each goal stood goes on record.
func finish(reason: String) -> void:
	if not active():
		return
	game.receipt.place_note("goals", mission.states(reason))
	game.receipt.place_note("facts", mission.facts.duplicate())
	game.receipt.place_note("opened", opened.duplicate())
	game.telemetry.goals = mission.log_rows(reason)
