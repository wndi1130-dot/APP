extends RefCounted
## Decision 486: the train watches a work site, sends its escort first, and
## takes the same people back when the guard can no longer hold the place.

const FieldGrid = preload("res://game/world/field_grid.gd")
const SimNoise = preload("res://game/sim/noise.gd")

const TICK_S: float = 1.0
const RING_R: float = 40.0
const NEAR_R: float = 25.0
const PATH_R: float = 10.0
const PATH_EVERY: float = 10.0
const CLEAR_SHARE: float = 0.7
const CLEARED: Array[String] = ["dead", "downed"]
const DECORATION: Array[String] = ["corpse"]
const SEE_R: float = 30.0
const SEEN_BESIDE_R: float = 3.0
const RADIO_EVERY: float = 60.0
## Who speaks the crew's radio lines: the engineer for now, changed here alone.
const SPEAKER: String = "기관사"
const ESCORT_LEAD: float = 3.0
const HOLD_N: int = 4
const HOLD_CLEAR_S: float = 5.0
const OVERFLOW_S: float = 20.0
const OVERFLOW_MULT: int = 2
## Every carrier out dead or down this long, none still to come down: the crew comes back.
const NO_HANDS_S: float = 10.0
const HOLD_SHARE: float = 0.4
const WORKER_BACK_R: float = 8.0
const WORKER_RUN_R: float = 3.0
const BEHIND_M: float = 2.0
const START_SPREAD: float = 6.0
const BOARD_R: float = 1.5
const WORK_R: float = 2.2
const DROP_R: float = 1.0
const BOARD_BELOW: float = 50.0
const DIG_TIME: float = 45.0
const TRIP_COAL: float = 0.25
const EMPTY: float = 0.001
const SHARE_CELLS: int = 8
const COAL_DROP_MIN_X: int = 17
const COAL_DROP_MAX_X: int = 96
const COAL_DROP_ROW: int = 6
const BUDGET_SLACK: float = 0.1
const WOOD_TABLE: Dictionary = {"freight": 2, "houses": 5, "hospital": 1,
	"factory": 1, "church": 3, "office": 3}
const NUMBER_WORDS: Array[String] = ["없음", "하나", "둘", "셋", "넷", "다섯",
	"여섯", "일곱", "여덟", "아홉", "열"]
const JOBS: Dictionary = {
	"coal_heap": {"name": "석탄 더미", "yield": "coal", "carriers": 4, "escorts": 1,
		"verb": "삽질", "work_s": 20.0, "trip": TRIP_COAL, "noise": SimNoise.Level.NORMAL, "noise_every": 60.0},
	"coal_wagon": {"name": "석탄 화차", "yield": "coal", "carriers": 4, "escorts": 2,
		"verb": "곡괭이질", "work_s": DIG_TIME, "trip": TRIP_COAL, "noise": SimNoise.Level.NORMAL, "noise_every": 60.0},
	"wood_stack": {"name": "쌓인 목재", "yield": "wood", "carriers": 4, "escorts": 1,
		"verb": "묶기", "work_s": 15.0, "trip": 1.0, "noise": SimNoise.Level.QUIET, "noise_every": 0.0},
	"furniture": {"name": "가구 해체", "yield": "wood", "carriers": 2, "escorts": 1,
		"verb": "뜯기", "work_s": 75.0, "trip": 1.0, "noise": SimNoise.Level.NORMAL, "noise_every": 60.0},
	"house": {"name": "집 해체", "yield": "wood", "carriers": 4, "escorts": 2,
		"verb": "뜯기", "work_s": 40.0, "trip": 1.0, "noise": SimNoise.Level.LOUD, "noise_every": 45.0,
		"buildings": ["log_cabin", "wood_shed", "barn"]},
	"tree": {"name": "나무 베기", "yield": "wood", "carriers": 4, "escorts": 2,
		"verb": "도끼질", "work_s": 150.0, "trip": 1.0, "noise": SimNoise.Level.NORMAL, "noise_every": 60.0},
}
const DEFAULT_ROWS: Array = [
	{"id": "s2_crew_01", "name": "운송조 1", "role": "worker", "skills": {"strength": 6, "melee": 1, "shooting": 0, "stealth": 1, "search": 1}, "hands": []},
	{"id": "s2_crew_02", "name": "운송조 2", "role": "worker", "skills": {"strength": 6, "melee": 1, "shooting": 0, "stealth": 1, "search": 1}, "hands": []},
	{"id": "s2_crew_03", "name": "운송조 3", "role": "worker", "skills": {"strength": 5, "melee": 1, "shooting": 0, "stealth": 1, "search": 1}, "hands": []},
	{"id": "s2_crew_04", "name": "운송조 4", "role": "worker", "skills": {"strength": 7, "melee": 2, "shooting": 0, "stealth": 1, "search": 1}, "hands": []},
	{"id": "s2_escort_01", "name": "호위조 1", "role": "escort", "skills": {"strength": 6, "melee": 3, "shooting": 3, "stealth": 1, "search": 1}, "hands": [["shotgun", "factory", 0.8], ["crowbar", "factory", 0.9]]},
	{"id": "s2_escort_02", "name": "호위조 2", "role": "escort", "skills": {"strength": 6, "melee": 4, "shooting": 1, "stealth": 1, "search": 1}, "hands": [["axe", "factory", 0.9]]},
]

var game
var sites: Dictionary = {}
var dropped: Array[Dictionary] = []  # coal set down by a worker; wood lies in game.ground_items instead
var active_site: String = "work_site"
var elapsed: float = 0.0
var tick_left: float = 0.0
var sent: Dictionary = {}
var crew_down_said: bool = false


func _init(field_game) -> void:
	game = field_game


func site_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in game.data.get("spots", {}):
		if game.data["spots"][id].get("kind", "") == "work_site":
			out.append(id)
	return out


func _site(id: String) -> Dictionary:
	if not sites.has(id):
		sites[id] = {"phase": "unseen", "seen": false, "warned": false, "warn_share": 0.0, "half": false,
			"last_open": -INF, "retry": false, "retry_said": false, "hold_s": 0.0, "clear_s": 0.0,
			"path": PackedVector3Array(), "path_at": -INF, "door": Vector3.ZERO,
			"pending": [], "roster": [], "depart_at": 0.0, "sent": false, "noise_s": 0.0,
			"cells": -1, "bright": false}
	return sites[id]


func phase(id: String = "work_site") -> String:
	return String(_site(id)["phase"])


func job_id(id: String = "work_site") -> String:
	return String(game.data["spots"][id].get("job", "coal_wagon"))


func job(id: String = "work_site") -> Dictionary:
	return JOBS.get(job_id(id), JOBS["coal_wagon"])


func position_of(id: String) -> Vector3:
	return FieldGrid.center(game.data["spots"][id]["cell"])


func remaining(id: String = "work_site") -> float:
	if job_id(id) == "coal_wagon":
		return wagon_coal(game.data)
	return maxf(float(game.data["spots"][id].get("amount", 0.0)), 0.0)


## Coal the crew can dig: wagons with a work cell, the ones field_ai.gd _wagon_with_coal sends them to.
static func wagon_coal(data: Dictionary) -> float:
	var total: float = 0.0
	for wagon: Dictionary in data.get("wagons", []):
		if wagon.has("work"):
			total += maxf(float(wagon.get("coal", 0.0)), 0.0)
	return total


func awake(z: Dictionary) -> bool:
	return not DECORATION.has(String(z.get("kind", ""))) and game.zombies.active(z) and z["state"] != "downed"


## Check the stretches between smoothed path points too. Bodies stay in the ring.
func safety(id: String = "work_site") -> Dictionary:
	var at: Vector3 = position_of(id)
	var path: PackedVector3Array = route(id)
	var total: int = 0
	var cleared: int = 0
	var near_awake: int = 0
	var path_awake: int = 0
	for z: Dictionary in game.zombies.list:
		if DECORATION.has(String(z.get("kind", ""))) or z["state"] == "frozen":
			continue
		var pos: Vector3 = z["pos"]
		var distance: float = at.distance_to(pos)
		if distance <= RING_R:
			total += 1
			if CLEARED.has(String(z["state"])):
				cleared += 1
		if not awake(z):
			continue
		if distance <= NEAR_R:
			near_awake += 1
		for i in path.size():
			var closest: Vector3 = path[i]
			if i > 0:
				closest = Geometry3D.get_closest_point_to_segment(pos, path[i - 1], path[i])
			if closest.distance_to(pos) <= PATH_R:
				path_awake += 1
				break
	var share: float = float(cleared) / total if total > 0 else 1.0
	return {"total": total, "cleared": cleared, "share": share, "near_awake": near_awake,
		"path_awake": path_awake, "open": share >= CLEAR_SHARE and near_awake == 0 and path_awake == 0}


func route(id: String) -> PackedVector3Array:
	var state: Dictionary = _site(id)
	if elapsed - float(state["path_at"]) >= PATH_EVERY:
		var at: Vector3 = position_of(id)
		var nearest: Vector3 = at
		var distance: float = INF
		for cell: Vector2i in game.data["spawns"]["train_door"]:
			var door: Vector3 = FieldGrid.center(cell)
			if at.distance_to(door) < distance:
				distance = at.distance_to(door)
				nearest = door
		var path: PackedVector3Array = game.find_path(nearest, at)
		path.insert(0, nearest)
		if path[-1].distance_to(at) > EMPTY:
			path.append(at)
		state["path"] = path
		state["door"] = nearest
		state["path_at"] = elapsed
	return state["path"]


func door_of(id: String) -> Vector3:
	route(id)
	return _site(id)["door"]


func hold_position(id: String) -> Vector3:
	var path: PackedVector3Array = route(id)
	var length: float = 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	var left: float = length * HOLD_SHARE
	for i in range(path.size() - 1, 0, -1):
		var step: float = path[i].distance_to(path[i - 1])
		if step > EMPTY and left <= step:
			return path[i].lerp(path[i - 1], left / step)
		left -= step
	return door_of(id)


func update(delta: float) -> void:
	elapsed += delta
	tick_left += delta
	while tick_left >= TICK_S:
		tick_left -= TICK_S
		for id: String in site_ids():
			_tick(id)
		game.actions.work_started = false
		for id: String in sites:
			if phase(id) in ["working", "hold", "retreat"]:
				game.actions.work_started = true
		game.actions._dig_noise(TICK_S)


func _tick(id: String) -> void:
	var state: Dictionary = _site(id)
	var stage: String = phase(id)
	if stage == "done":
		return
	var safe: Dictionary = safety(id)
	if stage in ["working", "hold"]:
		for p in members(id):
			if p.role == "worker" and (not p.is_alive() or p.body.downed):
				drop_load(p)
		state["no_hands_s"] = float(state.get("no_hands_s", 0.0)) + TICK_S if _no_hands(id) else 0.0
		var why: String = _trouble(id, safe)
		if why != "":
			retreat(id, why)
		elif stage == "working" and int(safe["near_awake"]) >= HOLD_N:
			state["phase"] = "hold"
			state["hold_s"] = 0.0
			state["clear_s"] = 0.0
			_cancel_workers(id)
			_event(id, "hold")
			game.set_radio(SPEAKER + ": 작업조 잠깐 멈춰. 호위가 막는다.", "reply")
		elif stage == "hold":
			# Only the seconds the escort is held at four or more count toward the overflow.
			if int(safe["near_awake"]) < HOLD_N:
				state["clear_s"] = float(state["clear_s"]) + TICK_S
			else:
				state["clear_s"] = 0.0
				state["hold_s"] = float(state["hold_s"]) + TICK_S
			if float(state["clear_s"]) >= HOLD_CLEAR_S:
				state["phase"] = "working"
				_event(id, "resume")
			elif float(state["hold_s"]) >= OVERFLOW_S:
				retreat(id, "held")
		if phase(id) == "working":
			_release_workers(id)
			if _finished(id):
				state["phase"] = "done"
				_event(id, "done")
				for p in members(id):
					p.brain["job"] = "home"
		_paint(id, safe)
		return
	if stage == "retreat":
		if _returned(id):
			state["phase"] = "closed"
			state["retry"] = true
			state["retry_said"] = false
			_event(id, "returned")
		_paint(id, safe)
		return
	if _finished(id):
		state["phase"] = "done"
		_event(id, "done")
	elif not state["seen"]:
		var distance: float = game.player.position.distance_to(position_of(id))
		# Right beside it counts as seen even when the site's own cell is behind a wall.
		if distance <= SEE_R and (distance <= SEEN_BESIDE_R or game.sight_clear(game.player.position, position_of(id))):
			state["seen"] = true
			_event(id, "seen")
			if safe["open"]:
				_open(id)
			else:
				state["phase"] = "closed"
				state["warned"] = true
				state["warn_share"] = float(safe["share"])
				if float(safe["share"]) >= CLEAR_SHARE:
					game.set_radio(blocked_reason(safe), "reply")
				else:
					game.set_radio(SPEAKER + ": 저기 %s 일터가 보입니다. 둘레에 망자가 %s 있어 아직 못 내보냅니다." % [job(id)["name"], game.director.size_word(int(safe["total"]) - int(safe["cleared"]))], "reply")
	elif safe["open"]:
		if stage != "open":
			_open(id)
	elif stage != "open" and state["warned"] and not state["half"] and float(safe["share"]) >= CLEAR_SHARE / 2.0 \
			and float(safe["share"]) > float(state.get("warn_share", 0.0)):
		# Half way to the share the train asks for, and more cleared than when it first said no.
		state["half"] = true
		state["phase"] = "half"
		_event(id, "half")
		game.set_radio(SPEAKER + ": 좀 줄었습니다. 조금만 더 치우면 내보내겠습니다.", "reply")
	else:
		state["phase"] = "half" if state["half"] else "closed"
	_paint(id, safe)


func _open(id: String) -> void:
	var state: Dictionary = _site(id)
	state["phase"] = "open"
	_event(id, "open")
	if state["retry"] and not state["retry_said"]:
		state["retry_said"] = true
		state["last_open"] = elapsed
		game.set_radio(SPEAKER + ": 다시 내보낼까요?", "reply")
	elif elapsed - float(state["last_open"]) >= RADIO_EVERY:
		state["last_open"] = elapsed
		game.set_radio(SPEAKER + ": 이 정도면 이제 거의 안전한 것 같습니다. 작업조 내보낼까요?", "reply")


## The ring over the site fills toward the share the train asks for: full when the ring is cleared enough.
func _paint(id: String, safe: Dictionary) -> void:
	var state: Dictionary = _site(id)
	var spot: Dictionary = game.data["spots"][id]
	var progress: float = minf(float(safe["share"]) / CLEAR_SHARE, 1.0)
	var cells: int = roundi(progress * SHARE_CELLS)
	var bright: bool = phase(id) == "open"
	spot["work_share"] = progress
	spot["state"] = "ready" if bright else phase(id)
	if cells == int(state["cells"]) and bright == bool(state["bright"]):
		return
	state["cells"] = cells
	state["bright"] = bright
	if game.view.spot_nodes.has(id):
		game.view.update_spot(id)


func _event(id: String, ev: String) -> void:
	game.telemetry.work_event(game.clock.elapsed, id, ev)


func _number(n: int) -> String:
	return NUMBER_WORDS[maxi(n, 0)] if n <= 10 else game.director.size_word(n)


func blocked_reason(safe: Dictionary) -> String:
	if int(safe["path_awake"]) > 0:
		return SPEAKER + ": 열차에서 일터 가는 길에 망자가 %s 있습니다." % _number(int(safe["path_awake"]))
	if int(safe["near_awake"]) > 0:
		return SPEAKER + ": 일터 바로 곁에 깨어 있는 망자가 %s 있습니다." % _number(int(safe["near_awake"]))
	var left: int = maxi(ceili(float(safe["total"]) * CLEAR_SHARE) - int(safe["cleared"]), 0)
	return SPEAKER + ": 둘레에 아직 %s 남았습니다." % _number(left)


## Rows retain their order within each role. Existing people never get copied.
## The rows the train can send: the contract's work crew. A contract's empty crew sends nobody; the
## default crew is only for a stop played off the contract.
func _source() -> Array:
	var source: Array = game.work_rows()
	return DEFAULT_ROWS if source.is_empty() and not game.contract_on() else source


## A stop resumed from a save made while the crew was out (field_save.gd apply): the field makes only the
## squad at start, so each crew member the save carries is made again before it is reconnected.
func remake(saved: Array) -> void:
	var rows: Dictionary = {}
	for row: Dictionary in _source():
		rows[String(row["id"])] = row
	for row: Dictionary in saved:
		var pid: String = String(row.get("pid", ""))
		if rows.has(pid) and _person(pid) == null:
			game.crew.append(game.make_person(rows[pid], Vector3.ZERO))


func _rows(id: String) -> Array:
	var source: Array = _source()
	var out: Array = []
	for role: String in ["worker", "escort"]:
		var left: int = int(job(id)["carriers" if role == "worker" else "escorts"])
		for row: Dictionary in source:
			if row.get("role", "") != role or left <= 0:
				continue
			if _reserved(String(row["id"])):
				continue
			var p: Variant = _person(String(row["id"]))
			if p != null and (not p.is_alive() or p.body.downed or not p.brain.get("boarded", false)):
				continue
			out.append(row)
			left -= 1
	return out


func _person(pid: String):
	for p in game.people:
		if p.pid == pid:
			return p
	return null


func _reserved(pid: String) -> bool:
	for state: Dictionary in sites.values():
		for row: Dictionary in state["pending"]:
			if row["id"] == pid:
				return true
	return false


func _pending_people(except_site: String = "") -> int:
	var count: int = 0
	for id: String in sites:
		if id == except_site:
			continue
		count += sites[id]["pending"].size()
	return count


func _outside_people() -> int:
	var count: int = 0
	for p in game.allies_alive():
		if not p.brain.get("boarded", false):
			count += 1
	return count


func start(id: String = "work_site") -> bool:
	var state: Dictionary = _site(id)
	if phase(id) in ["working", "hold", "retreat", "done"]:
		return false
	var safe: Dictionary = safety(id)
	if not safe["open"]:
		if phase(id) == "open":
			state["phase"] = "closed"
		_paint(id, safe)
		game.set_radio(blocked_reason(safe), "reply")
		return false
	if phase(id) != "open":
		_tick(id)
		return false
	var rows: Array = _rows(id)
	var workers: Array = []
	var escorts: Array = []
	for row: Dictionary in rows:
		if row["role"] == "worker":
			workers.append(row)
		else:
			escorts.append(row)
	if workers.is_empty():
		game.set_radio(SPEAKER + ": 지금 내보낼 일꾼이 없습니다.", "reply")
		return false
	# Escorts come down first (decision 486): with none to stand guard, nobody goes.
	if escorts.is_empty():
		game.set_radio(SPEAKER + ": 지켜 줄 호위가 없습니다. 지금은 못 내보냅니다.", "reply")
		return false
	if _outside_people() + rows.size() + _pending_people() > game.ALLY_CAP:
		game.hud.toast("사람이 너무 많음")
		return false
	active_site = id
	state["phase"] = "working"
	state["seen"] = true
	state["retry"] = false
	state["sent"] = false
	state["pending"] = workers
	state["roster"] = []
	for row: Dictionary in rows:
		state["roster"].append(String(row["id"]))
	state["depart_at"] = elapsed + ESCORT_LEAD
	state["noise_s"] = 0.0
	state["no_hands_s"] = 0.0
	game.actions.work_started = true
	game.ai.crew_recalled = false
	for i in escorts.size():
		_disembark(id, escorts[i], i)
	_paint(id, safe)
	game.set_radio(SPEAKER + ": 작업조 내려간다. 호위는 %s 일터를 지켜라." % job(id)["name"], "reply")
	return true


func _disembark(id: String, row: Dictionary, side: int) -> void:
	var p: Variant = _person(String(row["id"]))
	var door: Vector3 = door_of(id)
	if p == null:
		p = game.make_person(row, door)
		game.crew.append(p)
	p.cancel_action()
	p.stop()
	p.target_zombie = {}
	p.target_person = null
	p.hold_attack = false
	p.aim.stop()
	p.position = door + _spread(p, 0.5)
	p.visible = true
	# One who was mending the depot's conveyor goes back to it while it is still half mended.
	var belt: Dictionary = game.mission_play.conveyor()
	var mending: bool = p.brain.get("mender", false) and not belt.is_empty() and belt["state"] == "part"
	p.brain.merge({"work_site": id, "job": "repair" if mending else "dig", "side": side % 2, "load": 0.0,
		"load_kind": job(id)["yield"], "boarded": false, "fleeing": false, "work_run": false,
		"work_wait": -1.0}, true)
	p.brain.erase("board_at")
	p.brain.erase("dest")
	if not sent.has(p.pid):
		sent[p.pid] = true
		game.receipt.person("sent", p.pid)
	if not _site(id)["sent"]:
		_site(id)["sent"] = true
		_event(id, "sent")


func _release_workers(id: String) -> void:
	var state: Dictionary = _site(id)
	var pending: Array = state["pending"]
	if pending.is_empty() or elapsed < float(state["depart_at"]):
		return
	if _outside_people() + pending.size() + _pending_people(id) > game.ALLY_CAP:
		retreat(id, "cap")
		return
	for i in pending.size():
		_disembark(id, pending[i], i)
	pending.clear()
	# The depot's one card comes up the first time carriers are down this stop, not on every return.
	if not crew_down_said:
		crew_down_said = true
		game.mission_play.crew_down(game.player)


func members(id: String) -> Array:
	var out: Array = []
	for p in game.crew:
		if p.brain.get("work_site", "work_site") == id and _site(id)["roster"].has(p.pid):
			out.append(p)
	return out


## Why the crew must come back at once, or "": called back, eight awake by the site, someone
## grabbed, an escort dead or downed (not one who slipped and gets straight up again), or every
## carrier out dead or down for NO_HANDS_S.
func _trouble(id: String, safe: Dictionary) -> String:
	if game.ai.crew_recalled:
		return "recalled"
	if int(safe["near_awake"]) >= HOLD_N * OVERFLOW_MULT:
		return "eight"
	for p in members(id):
		if p.brain.get("boarded", false):
			continue
		if not p.grabbers.is_empty():
			return "grabbed"
		if p.role == "escort" and (not p.is_alive() or p.body.downed):
			return "escort_down"
	if float(_site(id).get("no_hands_s", 0.0)) >= NO_HANDS_S:
		return "no_hands"
	return ""


## Carriers are out (not back aboard) and none of them is up: dead or down. False while some are still to come down.
func _no_hands(id: String) -> bool:
	if not _site(id)["pending"].is_empty():
		return false
	var out: int = 0
	for p in members(id):
		if p.role != "worker" or p.brain.get("boarded", false):
			continue
		out += 1
		if p.is_alive() and not p.body.downed:
			return false
	return out > 0


func _cancel_workers(id: String) -> void:
	for p in members(id):
		if p.role == "worker" and not p.brain.get("boarded", false):
			p.cancel_action()
			p.stop()


func retreat(id: String, why: String = "") -> void:
	var state: Dictionary = _site(id)
	if phase(id) == "retreat":
		return
	state["phase"] = "retreat"
	state["why"] = why
	state["pending"].clear()
	_cancel_workers(id)
	for p in members(id):
		if not p.brain.get("boarded", false):
			if p.role == "worker":
				drop_load(p)
			if p.brain.get("job", "") == "repair":
				p.brain["mender"] = true
			p.brain["job"] = "home"
	_event(id, "retreat")
	game.set_radio(SPEAKER + ": 작업조 물러나!", "reply")


## Everyone who can still walk is aboard (one who only slipped is still on the way).
func _returned(id: String) -> bool:
	for p in members(id):
		if p.is_alive() and not p.body.downed and not p.brain.get("boarded", false):
			return false
	return true


func _finished(id: String) -> bool:
	if remaining(id) > EMPTY or not _site(id)["pending"].is_empty():
		return false
	for p in members(id):
		if float(p.brain.get("load", 0.0)) > EMPTY:
			return false
	return _dropped_near(id).is_empty()


## Wood goes down as a ground item (the player can take it too, and the field save keeps
## it with the ground); coal goes down as a pile only the crew picks up again.
func drop_load(p) -> void:
	var n: float = float(p.brain.get("load", 0.0))
	if n <= EMPTY:
		return
	var kind: String = String(p.brain.get("load_kind", "coal"))
	if kind == "wood":
		game.ground_items.append({"pos": p.position, "id": "wood", "n": n, "crew_drop": true})
		game.view.update_ground(game.ground_items)
	else:
		dropped.append({"pos": p.position, "kind": kind, "n": n})
	p.brain["load"] = 0.0
	p.brain["job"] = "dig"


func _erase_same(rows: Array, row: Dictionary) -> void:
	for i in range(rows.size() - 1, -1, -1):
		if is_same(rows[i], row):
			rows.remove_at(i)
			return


## What the crew set down and carries on: its wood on the ground, or its coal. Wherever it was set
## down (between the site, the wagons and the door), so nothing a carrier dropped is lost on the way.
func _dropped_near(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if job(id)["yield"] == "wood":
		for item: Dictionary in game.ground_items:
			if item.get("crew_drop", false) and float(item.get("n", 0.0)) > EMPTY:
				out.append(item)
		return out
	for row: Dictionary in dropped:
		if row["kind"] == job(id)["yield"] and float(row["n"]) > EMPTY:
			out.append(row)
	return out


func _take_drop(p, row: Dictionary, id: String) -> void:
	var wood: bool = job(id)["yield"] == "wood"
	var take: float = minf(_trip(id), float(row["n"]))
	p.brain["load"] = take
	p.brain["load_kind"] = job(id)["yield"]
	p.brain["job"] = "carry"
	row["n"] = float(row["n"]) - take
	if float(row["n"]) <= EMPTY:
		_erase_same(game.ground_items if wood else dropped, row)
	if wood:
		game.view.update_ground(game.ground_items)


## The ration law cuts a coal trip (decision 430 ②); the depot belt speeds only the wagons it loads.
func _trip(id: String) -> float:
	var n: float = float(job(id)["trip"])
	if job(id)["yield"] == "coal":
		n *= game.haul_mult()
	if job_id(id) == "coal_wagon":
		n *= game.mission_play.load_mult()
	return n


## True consumes this AI turn. False lets the existing escort fight as before.
func crew_step(p, think: bool) -> bool:
	var id: String = String(p.brain.get("work_site", "work_site"))
	if p.brain.get("boarded", false):
		return true
	if phase(id) in ["retreat", "done"] or p.brain.get("job", "") == "home":
		_go_home(p, id, think)
		return true
	if p.role == "escort":
		return false
	if not think:
		return true
	var threat: Dictionary = nearest_threat(p.position, WORKER_BACK_R)
	if not threat.is_empty():
		p.cancel_action()
		p.brain["fleeing"] = true
		if p.position.distance_to(threat["pos"]) <= WORKER_RUN_R:
			drop_load(p)
			p.brain["work_run"] = true
		if not p.brain.get("work_run", false):
			game.ai._walk(p, _behind_escort(p, threat, id), true)
			return true
	if p.brain.get("work_run", false):
		if p.position.distance_to(door_of(id)) > BOARD_R or not threat.is_empty():
			game.ai._walk(p, door_of(id), true)
			return true
		p.brain["work_run"] = false
	p.brain["fleeing"] = false
	if phase(id) == "hold":
		p.cancel_action()
		game.ai._walk(p, hold_position(id), true)
		return true
	if phase(id) != "working" or p.action != "":
		return true
	if p.brain.get("job", "dig") == "repair":
		var to: Variant = game.mission_play.repair_step(p)
		if to != null:
			game.ai._walk(p, to, false)
		return true
	if float(p.brain.get("load", 0.0)) > EMPTY:
		_deliver(p, id)
		return true
	var piles: Array[Dictionary] = _dropped_near(id)
	if not piles.is_empty():
		var pile: Dictionary = piles[0]
		for other: Dictionary in piles:
			if p.position.distance_to(other["pos"]) < p.position.distance_to(pile["pos"]):
				pile = other
		if p.position.distance_to(pile["pos"]) > DROP_R:
			game.ai._walk(p, pile["pos"], false)
		else:
			_take_drop(p, pile, id)
		return true
	var wagon: Dictionary = game.ai._wagon_with_coal() if job_id(id) == "coal_wagon" else {}
	if remaining(id) <= EMPTY or (job_id(id) == "coal_wagon" and wagon.is_empty()):
		return true
	var at: Vector3 = (FieldGrid.center(wagon["work"]) if not wagon.is_empty() else position_of(id)) + _spread(p, 1.5)
	if p.position.distance_to(at) > WORK_R:
		game.ai._walk(p, at, false)
		return true
	if float(p.brain.get("work_wait", -1.0)) < 0.0:
		p.brain["work_wait"] = elapsed + game.rng.randf_range(0.0, START_SPREAD)
	if elapsed >= float(p.brain["work_wait"]):
		p.start_action("dig", String(job(id)["verb"]), float(job(id)["work_s"]), _worked.bind(p, id))
	return true


## A small fixed offset per person (from the pid, no dice) so a crew does not stand in one spot.
func _spread(p, reach: float) -> Vector3:
	var h: int = absi(hash(String(p.pid)))
	return Vector3(float(h % 7 - 3) / 3.0 * reach, 0.0, float((h >> 3) % 3 - 1) * 0.3)


func nearest_threat(at: Vector3, radius: float) -> Dictionary:
	var best: Dictionary = {}
	var distance: float = radius
	for z: Dictionary in game.zombies.list:
		if awake(z) and at.distance_to(z["pos"]) <= distance:
			best = z
			distance = at.distance_to(z["pos"])
	return best


func _behind_escort(p, threat: Dictionary, id: String) -> Vector3:
	var nearest: Variant = null
	var distance: float = INF
	for escort in members(id):
		if escort.role != "escort" or not escort.can_act() or escort.brain.get("boarded", false):
			continue
		if p.position.distance_to(escort.position) < distance:
			nearest = escort
			distance = p.position.distance_to(escort.position)
	if nearest == null:
		return hold_position(id)
	var away: Vector3 = nearest.position - Vector3(threat["pos"])
	away.y = 0.0
	if away.length_squared() <= EMPTY:
		away = door_of(id) - nearest.position
	return nearest.position + away.normalized() * BEHIND_M


func _go_home(p, id: String, think: bool) -> void:
	var door: Vector3 = door_of(id)
	if p.position.distance_to(door) <= BOARD_R:
		p.cancel_action()
		p.stop()
		p.target_zombie = {}
		p.target_person = null
		p.hold_attack = false
		p.aim.stop()
		p.brain["boarded"] = true
		p.brain["board_at"] = door
		p.visible = false
		p.position = door + Vector3(0, -BOARD_BELOW, 0)
	elif think:
		if p.role == "escort":
			game.ai._escort(p, true)
		game.ai._walk(p, door, true)


## The wagon is looked up when the work is done, as the old dig did (a bound wagon row would
## not come back as the same row from a field save).
func _worked(p, id: String) -> void:
	if phase(id) != "working" or not p.can_act() or p.brain.get("boarded", false):
		return
	var wagon: Dictionary = game.ai._wagon_with_coal() if job_id(id) == "coal_wagon" else {}
	if job_id(id) == "coal_wagon" and wagon.is_empty():
		return
	var source: Dictionary = wagon if job_id(id) == "coal_wagon" else game.data["spots"][id]
	var key: String = "coal" if job_id(id) == "coal_wagon" else "amount"
	var take: float = minf(_trip(id), float(source.get(key, 0.0)))
	source[key] = maxf(float(source.get(key, 0.0)) - take, 0.0)
	p.brain["load"] = take
	p.brain["load_kind"] = job(id)["yield"]
	p.brain["job"] = "carry"


func _deliver(p, id: String) -> void:
	var drop: Vector3 = door_of(id)
	if job_id(id) == "coal_wagon":
		drop = FieldGrid.center(Vector2i(clampi(int(p.position.x), COAL_DROP_MIN_X, COAL_DROP_MAX_X), COAL_DROP_ROW))
	if p.position.distance_to(drop) > DROP_R:
		game.ai._walk(p, drop, false)
		return
	if p.brain.get("load_kind", "coal") == "coal":
		game.actions.coal_delivered += float(p.brain.get("load", 0.0))
		game.mission_play.loaded()
	else:
		game.actions.wood_delivered += float(p.brain.get("load", 0.0))
	game.telemetry.trip()
	p.brain["load"] = 0.0
	p.brain["job"] = "dig"


func noise(delta: float, belt: bool = false) -> void:
	for id: String in site_ids():
		var template: Dictionary = job(id)
		if phase(id) != "working" or float(template["noise_every"]) <= 0.0 or (belt and job_id(id) == "coal_wagon"):
			continue
		var digging: bool = false
		for p in members(id):
			if p.is_alive() and not p.brain.get("boarded", false) and p.action == "dig":
				digging = true
		if not digging:
			continue
		var state: Dictionary = _site(id)
		state["noise_s"] = float(state["noise_s"]) - delta
		if float(state["noise_s"]) <= 0.0:
			state["noise_s"] = float(template["noise_every"])
			game.make_sound(position_of(id), int(template["noise"]), "pickaxe" if template["yield"] == "coal" else "salvage")


## Coal wagons are counted once, even when several spots refer to the yard.
static func budget(data: Dictionary) -> Dictionary:
	var out: Dictionary = {"coal": wagon_coal(data), "wood": 0.0}
	for spot: Dictionary in data.get("spots", {}).values():
		if spot.get("kind", "") == "salvage" and spot.get("material", "") == "wood":
			out["wood"] = float(out["wood"]) + float(spot.get("amount", 0.0))
		elif spot.get("kind", "") == "work_site":
			var kind: String = String(spot.get("job", "coal_wagon"))
			if kind != "coal_wagon" and JOBS.has(kind):
				var resource: String = String(JOBS[kind]["yield"])
				out[resource] = float(out[resource]) + float(spot.get("amount", 0.0))
	return out
