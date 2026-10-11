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
const BUILD_TIME: float = 8.0     # as the manhole lid: one heavy thing, a normal sound
const MATERIALS: Array[String] = ["plank", "scrap", "wood"]
## Hordes while it lasts: the director is the same one, with the stage's pace.
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
var first_wave: int = 0
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
	# The doors held are one side's: the lower, or the upper where that is all there is.
	var sides: Dictionary = game.data["train_doors"]
	var cells: Array = sides.get("lower", [])
	if cells.is_empty():
		cells = sides.get("upper", [])
	for c in cells:
		doors.append({"cell": c, "hp": hp, "max": hp, "wall": 0, "bang_t": BANG_EVERY, "entered": {}, "node": null})
	game.director.set_pace(FIRST_GAP, RATIO, MIN_GAP, opened_at)
	game.set_radio("기관사: 불을 올린다. %d분만 문을 지켜라." % int(ceil(total / 60.0)), "must")


## Where the n-th body of a horde walks: the doors in turn.
func target(n: int) -> Vector3:
	if doors.is_empty():
		return FieldGrid.center(game.horde_home())
	return FieldGrid.center(doors[n % doors.size()]["cell"])


func tick(delta: float) -> void:
	if not on:
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
	game.make_sound(FieldGrid.center(door["cell"]), SimNoise.Level.NORMAL, "bang")
	if int(door["wall"]) > 0:
		door["wall"] = int(door["wall"]) - 1
		if int(door["wall"]) == 0:
			_show_wall(door)
			game.hud.toast("방벽이 무너졌다.")
		return
	if int(door["hp"]) <= 0:
		return
	var before := state_of(door)
	door["hp"] = int(door["hp"]) - 1
	var now := state_of(door)
	if now != before:
		game.set_radio("기관사: 문이 뚫렸다!" if now == "breached" else "기관사: 문이 상했다. 오래 못 버틴다.", "must", FieldGrid.center(door["cell"]))


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
		node.position = Vector3(at.x, 0.45, at.z + 0.6)
		game.add_child(node)
		door["node"] = node
	door["node"].visible = int(door["wall"]) > 0


func leaving_early() -> void:
	if on:
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
		"walls": walls_built, "waves": waves(),
	}


func end_lines() -> Array:
	if not opened:
		return []
	var r := result()
	var how := "채비를 다 채우고 떠났다" if ready else ("채비 %d초를 남기고 떠났다" % int(r["leftSec"]) if early else "채비 중에 끝났다")
	return [
		"버티기 판: %s · 물결 %d번" % [how, int(r["waves"])],
		"상한 문 %d · 뚫린 문 %d · 뚫린 문으로 든 것 %d · 세운 방벽 %d" % [int(r["damaged"]), int(r["breached"]), int(r["entered"]), int(r["walls"])],
	]
