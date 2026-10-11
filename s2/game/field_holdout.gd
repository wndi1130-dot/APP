extends RefCounted
## Holding the train while it gets ready to leave (user decisions 056, 074, 075).
## The first shape, on the stop there is: the doors of the platform side wear
## under the dead that reach them, a wall can be put up in front of each, a
## clock runs down, hordes come faster and walk to the doors. It is a stage to
## measure with: every number here is a first value, none of them settled.
##
## Off unless opts["holdout"] says so: "start" (from the first second) or
## "depart" (it opens when leaving is called, and leaving again goes early).

const FieldGrid = preload("res://game/world/field_grid.gd")
const SimNoise = preload("res://game/sim/noise.gd")

const MODES: Array[String] = ["start", "depart"]
const READY_TIME: float = 300.0   # the train is ready this long after it opens
const DOOR_HP: int = 24           # three of the dead through one in about ten seconds
const WALL_HP: int = 12
const BANG_EVERY: float = 1.3     # one of the dead, one blow: as on a house door
const REACH: float = 1.6
const HEARD_DOORS: int = 2        # blows are heard from this many doors, the nearest
const HURT_REACH: float = 3.0     # a door that gives way reaches whoever stands this near it
const BUILD_TIME: float = 8.0     # as the manhole lid: one heavy thing, a normal sound
const MATERIALS: Array[String] = ["plank", "scrap", "wood"]
## Hordes while it lasts: the director is the same one, with the stage's pace.
# Leaving before the train is ready (user decision 143): a last call of this
# many seconds, and whoever is not at the train when it ends stays.
const LAST_CALL_S: float = 3.0
# What going unready costs at most, at the moment the stage opens; it falls to
# nothing as the train gets ready. PLACEHOLDERS until the play check gives a table.
const EARLY_COAL_MAX: int = 6
const EARLY_PARTS_MAX: int = 2
const FIRST_GAP: float = 45.0
const RATIO: float = 0.9
const MIN_GAP: float = 35.0

var game
var mode: String = ""
var on: bool = false
var opened: bool = false
var early: bool = false
var ready: bool = false
var left: float = READY_TIME
var total: float = READY_TIME
var doors: Array = []             # {cell, hp, max, wall, bang_t, entered: {zombie id: true}, node}
var walls_built: int = 0
var reached: int = 0              # people in front of a door as it gave way
var hurt: int = 0                 # and how many of them it scratched
var first_wave: int = 0
var calling: bool = false         # the last call is being counted
var call_left: float = 0.0
var left_people: int = 0          # who stayed on the platform as it left
var cost_paid: Dictionary = {"coal": 0, "plow_part": 0}   # what going unready cost
var opened_at: float = 0.0


func _init(field_game) -> void:
	game = field_game
	mode = String(game.opts.get("holdout", ""))
	if not MODES.has(mode):
		mode = ""
	total = float(game.opts.get("holdout_time", READY_TIME))
	left = total


func enabled() -> bool:
	return mode != ""


## Leaving is called and the stage has not opened yet: it opens instead.
func opens_on_leaving() -> bool:
	return mode == "depart" and not opened


func begin() -> void:
	if opened or not enabled():
		return
	opened = true
	on = true
	left = total
	opened_at = game.clock.elapsed
	first_wave = game.director.index
	var hp: int = int(game.opts.get("holdout_door_hp", DOOR_HP))
	# Every door the train has is held: the lower side's, then the upper's.
	var sides: Dictionary = game.data["train_doors"]
	for side: String in ["lower", "upper"]:
		for c in sides.get(side, []):
			doors.append({"cell": c, "hp": hp, "max": hp, "wall": 0, "bang_t": BANG_EVERY, "entered": {}, "node": null, "upper": side == "upper"})
	game.director.set_pace(FIRST_GAP, RATIO, MIN_GAP, opened_at)
	game.set_radio("기관사: 불을 올린다. %d분만 문을 지켜라." % int(ceil(total / 60.0)), "must")


## Where the n-th body of a horde walks: the doors in turn, of the side it
## comes in on where the train has doors on both.
func target(n: int, from = null) -> Vector3:
	if doors.is_empty():
		return FieldGrid.center(game.horde_home())
	var mine: Array = doors
	if from != null:
		var up: bool = game.above_train(from)
		mine = doors.filter(func(door: Dictionary) -> bool: return bool(door["upper"]) == up)
		if mine.is_empty():
			mine = doors
	return FieldGrid.center(mine[n % mine.size()]["cell"])


## "We leave now": the count starts. It cannot be called off.
func last_call() -> void:
	if not on or calling:
		return
	calling = true
	call_left = LAST_CALL_S
	game.set_radio("기관사: 셋을 센다. 탈 사람은 타라!", "must")


## Coal and plough parts that going now would cost: {"coal", "plow_part"}.
func early_cost() -> Dictionary:
	if ready or total <= 0.0:
		return {"coal": 0, "plow_part": 0}
	var short: float = clampf(left / total, 0.0, 1.0)
	return {"coal": int(ceil(EARLY_COAL_MAX * short)), "plow_part": int(ceil(EARLY_PARTS_MAX * short))}


func tick(delta: float) -> void:
	if not on:
		return
	if calling:
		call_left -= delta
		if call_left <= 0.0:
			calling = false
			# The train does not go without its chief: the call is lost.
			if not game.aboard(game.player):
				game.set_radio("기관사: 열차장이 안 탔다. 못 떠난다.", "must")
			else:
				leaving_early()
				game.audio.depart()
				game.finish("departed")
				return
	left -= delta
	for door: Dictionary in doors:
		var at: Vector3 = FieldGrid.center(door["cell"])
		var hands := 0
		for z in game.zombies.in_radius(at, REACH):
			if not game.zombies.active(z) or z["state"] == "downed" or game.level_of(z["pos"]) != 0:
				continue
			hands += 1
			# Through a breached door each of them goes in once.
			if int(door["hp"]) <= 0 and int(door["wall"]) == 0:
				door["entered"][z["id"]] = true
			# What has come to a door stays at it.
			if z["state"] == "investigate":
				z["linger"] = 40.0
		door["bang_t"] = float(door["bang_t"]) - delta * hands
		while float(door["bang_t"]) <= 0.0:
			door["bang_t"] = float(door["bang_t"]) + BANG_EVERY
			_bang(door)
	if left <= 0.0:
		ready = true
		on = false
		game.audio.depart()
		game.finish("departed")


func _bang(door: Dictionary) -> void:
	# The dead hear it as they did; the ear gets the door's own sound below.
	game.audio.quiet = true
	game.make_sound(FieldGrid.center(door["cell"]), SimNoise.Level.NORMAL, "bang")
	game.audio.quiet = false
	if int(door["wall"]) > 0:
		door["wall"] = int(door["wall"]) - 1
		if int(door["wall"]) == 0:
			_show_wall(door)
			game.hud.toast("방벽이 무너졌다.")
		_voice(door, "wall_down" if int(door["wall"]) == 0 else "wall")
		return
	if int(door["hp"]) <= 0:
		return
	var before := state_of(door)
	door["hp"] = int(door["hp"]) - 1
	var now := state_of(door)
	_voice(door, "break" if now == "breached" else ("low" if now == "damaged" else "door"))
	if now == "breached":
		_reach_through(door)
	if now != before:
		game.set_radio("기관사: 문이 뚫렸다!" if now == "breached" else "기관사: 문이 상했다. 오래 못 버틴다.", "must", FieldGrid.center(door["cell"]))


## What the player hears of a door. A wall going down and a door giving way
## are always heard; blows only from the doors nearest the player.
func _voice(door: Dictionary, kind: String) -> void:
	var at: Vector3 = FieldGrid.center(door["cell"])
	if game.audio.DOOR_BLOWS.has(kind):
		var mine: float = at.distance_to(game.player.position)
		var nearer := 0
		for other: Dictionary in doors:
			if FieldGrid.center(other["cell"]).distance_to(game.player.position) < mine:
				nearer += 1
		if nearer >= HEARD_DOORS:
			return
	game.audio.door(kind, at, SimNoise.Level.NORMAL)


## A door gives way: everyone of the train's in front of it gets the one roll
## a dead hand gets (decision 075: those who fought at a breached door).
func _reach_through(door: Dictionary) -> void:
	var at: Vector3 = FieldGrid.center(door["cell"])
	for p in game.squad + game.crew:
		if not p.is_alive() or game.level_of(p.position) != 0 or p.position.distance_to(at) > HURT_REACH:
			continue
		reached += 1
		if game.combat.breach_reaches(p) == "scratch":
			hurt += 1


## whole, damaged (under half) or breached (decision 075's three words).
func state_of(door: Dictionary) -> String:
	if int(door["hp"]) <= 0:
		return "breached"
	return "damaged" if int(door["hp"]) * 2 < int(door["max"]) else "whole"


func count(state: String) -> int:
	var n := 0
	for door: Dictionary in doors:
		if state_of(door) == state:
			n += 1
	return n


func waves() -> int:
	return game.director.index - first_wave


func goal_line() -> String:
	if not opened:
		return "버티기 판: 「떠난다」를 부르면 채비가 시작된다" if mode == "depart" else ""
	var s: int = int(ceil(maxf(left, 0.0)))
	return "채비 %d:%02d · 문 멀쩡 %d · 상함 %d · 뚫림 %d · 물결 %d" % [s / 60, s % 60, count("whole"), count("damaged"), count("breached"), waves()]


## The row of the action list by a door with no wall: put one up.
func wall_row(p) -> Dictionary:
	if not on:
		return {}
	for i in range(doors.size()):
		var door: Dictionary = doors[i]
		if int(door["wall"]) == 0 and p.position.distance_to(FieldGrid.center(door["cell"])) < 2.5:
			return {"label": "방벽 세우기", "call": build.bind(p, i)}
	return {}


func build(p, i: int) -> void:
	var mat := ""
	for m in MATERIALS:
		if int(p.items.get(m, 0)) > 0:
			mat = m
			break
	if mat == "":
		if p == game.player:
			game.hud.toast("방벽을 세울 것(판자나 고철)이 있어야 한다.")
		return
	game.make_sound(p.position, SimNoise.Level.NORMAL, "lid", p)
	p.start_action("wall", "방벽 세우기", BUILD_TIME, _built.bind(p, i, mat))


func _built(p, i: int, mat: String) -> void:
	var door: Dictionary = doors[i]
	if not on or int(door["wall"]) > 0 or not p.take_item(mat):
		return
	door["wall"] = WALL_HP
	walls_built += 1
	_show_wall(door)
	if p == game.player:
		game.hud.toast("방벽을 세웠다.")


## The wall is on the ground in front of the door, never on the car.
func _show_wall(door: Dictionary) -> void:
	if door["node"] == null:
		var node := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.6, 0.9, 0.5)
		node.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.42, 0.36, 0.29)
		node.material_override = mat
		var at: Vector3 = FieldGrid.center(door["cell"])
		node.position = Vector3(at.x, 0.45, at.z + (-0.6 if door["upper"] else 0.6))
		game.add_child(node)
		door["node"] = node
	door["node"].visible = int(door["wall"]) > 0


func leaving_early() -> void:
	if on:
		cost_paid = early_cost()
		early = true
		on = false


## What the stage came to, for the receipt's note, the telemetry and the end screen.
func result() -> Dictionary:
	var entered := 0
	var states: Array = []
	for door: Dictionary in doors:
		entered += door["entered"].size()
		states.append(state_of(door))
	return {
		"ready": ready, "early": early, "leftSec": int(ceil(maxf(left, 0.0))), "doors": states,
		"damaged": count("damaged"), "breached": count("breached"), "entered": entered,
		"walls": walls_built, "waves": waves(), "reached": reached, "hurt": hurt,
		"leftPeople": left_people, "earlyCost": cost_paid,
	}


const ORDINALS: Array[String] = ["첫째", "둘째", "셋째", "넷째", "다섯째", "여섯째", "일곱째", "여덟째", "아홉째", "열째"]


## The two lines shown as the train leaves (user decision 142: no wave is the
## last, so leaving is the full stop): which wave it left in, then how ready
## it was and how the doors stood.
func leave_lines() -> Array:
	var n: int = waves()
	var head: String = "물결이 닿기 전에 떠났다"
	if n > 0:
		head = "%s 물결에서 떠났다" % (ORDINALS[n - 1] if n <= ORDINALS.size() else "%d번째" % n)
	var how: String = "채비를 다 채웠다" if ready else "채비 %d초를 남겼다" % int(ceil(maxf(left, 0.0)))
	var out: Array = [head, "%s · 문 멀쩡 %d · 상함 %d · 뚫림 %d" % [how, count("whole"), count("damaged"), count("breached")]]
	if left_people > 0:
		out.append("남기고 온 사람 %d" % left_people)
	return out


func end_lines() -> Array:
	if not opened:
		return []
	var r := result()
	var how := "채비를 다 채우고 떠났다" if ready else ("채비 %d초를 남기고 떠났다" % int(r["leftSec"]) if early else "채비 중에 끝났다")
	var out: Array = [
		"버티기 판: %s · 물결 %d번" % [how, int(r["waves"])],
		"상한 문 %d · 뚫린 문 %d · 뚫린 문으로 든 것 %d · 세운 방벽 %d" % [int(r["damaged"]), int(r["breached"]), int(r["entered"]), int(r["walls"])],
		"문이 뚫릴 때 그 앞에 있던 사람 %d · 그 가운데 긁힌 사람 %d" % [reached, hurt],
	]
	if int(cost_paid["coal"]) > 0 or int(cost_paid["plow_part"]) > 0:
		out.append("덜 된 채비로 떠난 값: 석탄 %d · 쟁기 부품 %d" % [int(cost_paid["coal"]), int(cost_paid["plow_part"])])
	if left_people > 0:
		out.append("남기고 온 사람 %d · 열차장 신임 크게 하락" % left_people)
	return out
