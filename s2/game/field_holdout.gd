extends RefCounted
## Holding the train while it gets ready to leave (user decisions 056, 074, 075).
## The first shape, on the stop there is: the doors of the platform side wear
## under the dead that reach them, a wall can be put up in front of each, a
## clock runs down, hordes come faster and walk to the doors. It is a stage to
## measure with: every number here is a first value, none of them settled.
##
## Off unless opts["holdout"] says so: "start" (from the first second),
## "depart" (it opens when leaving is called, and leaving again goes early) or
## "roll" (user decision 148: whether this stop can have it is rolled once as
## the train stops and kept hidden; where it can, it opens on leaving unless
## the stop was quiet and the track is clear).

const FieldGrid = preload("res://game/world/field_grid.gd")
const SimNoise = preload("res://game/sim/noise.gd")

const MODES: Array[String] = ["start", "depart", "roll"]
# How likely a stop of each kind is to be one that can have it, in a hundred
# (user decisions 074, 087; the town stops low, decisions 151, 153). A kind
# not here is taken as the lowest of the town stops.
const CHANCE: Dictionary = {
	"mine": 60, "sawmill": 30, "lodge": 25, "lake": 10,
	"freight": 10, "hospital": 10, "factory": 10,
	"houses": 5, "church": 5, "office": 5,
}
const CHANCE_OTHER: int = 5
# The one line shown to anybody before it (user decision 150): the kind's
# chance in words, never the roll. [up to this chance, the word].
const RISK_WORDS: Array = [[15, "낮다"], [40, "있다"], [100, "높다"]]
# "Quiet, and the track beside the train clear": the stop's noise score at
# most this, and at most this many dead on the track. PLACEHOLDERS.
const QUIET_NOISE: int = 12
const CLEAR_TRACK: int = 2
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
# Ready, and a quiet while (user decision 146): the next wave is put off by
# this long whatever is heard, those the cap still held at the ways in turn
# back, and of the waves after it every so-many-th body walks to the track
# ahead of the train or behind it instead of a door, so that staying on makes
# the plough's price climb again (decision 149). PROPOSED values.
const QUIET_GAP_S: float = 40.0
const TRACK_EVERY: int = 3
const TRACK_SPREAD: int = 6       # they stand over this many cells of track
# The train is ready: the words stand big on the screen this long.
const READY_SHOWN_S: float = 4.0
# What going unready costs, on top of the plough's price: [share of the
# getting-ready still left (below this), coal, plough parts]. Starting values
# from the play check, not settled.
const EARLY_STEPS: Array = [[0.25, 2, 0], [0.5, 4, 1], [0.75, 7, 1], [2.0, 10, 2]]
# The plough's price by the dead on the track as it leaves (s1c_domestic 6.6,
# numbers proposed there): [up to this many, parts, the word on screen].
const PLOUGH_STEPS: Array = [[0, 0, "선로 비었다"], [10, 1, "망자 몇"], [30, 2, "무리"], [1 << 30, 3, "큰 무리"]]
# Leaving people behind (user decision 147): this much trust for the first,
# this much for each one more, and no more than the most. Things left cost none.
const TRUST_FIRST: int = 12
const TRUST_EACH_MORE: int = 4
const TRUST_MOST: int = 24
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
var track_at_leave: int = -1      # the dead on the track as it left
var ready_shown: float = 0.0      # the "ready" words are still up this long
var over: float = 0.0             # how long it stayed after it was ready
var rolled: bool = false          # "roll": this stop can have it (hidden)
var slipped: bool = false         # it could, and the train got away quietly
var opened_at: float = 0.0


func _init(field_game) -> void:
	game = field_game
	mode = String(game.opts.get("holdout", ""))
	if not MODES.has(mode):
		mode = ""
	total = float(game.opts.get("holdout_time", READY_TIME))
	left = total
	if mode == "roll":
		# Its own dice, so the stop's are not moved on by it.
		var dice := RandomNumberGenerator.new()
		dice.seed = hash([int(game.opts.get("seed", 0)), game.place, "holdout"])
		rolled = dice.randi_range(1, 100) <= chance()


func enabled() -> bool:
	return mode != ""


## How likely this kind of stop is to be one that can have it, in a hundred.
func chance() -> int:
	if game.opts.has("holdout_chance"):
		return int(game.opts["holdout_chance"])
	return int(CHANCE.get(String(game.data.get("place_kind", "")), CHANCE_OTHER))


## The kind's chance in a word, for the line anybody sees.
func risk_word() -> String:
	var c: int = chance()
	for row: Array in RISK_WORDS:
		if c <= int(row[0]):
			return String(row[1])
	return String(RISK_WORDS[-1][1])


## A quiet stop with the track beside the train clear: the train gets away.
func quiet_and_clear() -> bool:
	return game.ledger.total <= QUIET_NOISE and track_now() <= CLEAR_TRACK


## Leaving is called and the stage has not opened yet: it opens instead.
func opens_on_leaving() -> bool:
	if opened:
		return false
	if mode == "roll":
		return rolled and not quiet_and_clear()
	return mode == "depart"


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
	if ready and n % TRACK_EVERY == TRACK_EVERY - 1:
		return track_spot(n / TRACK_EVERY, from)
	if doors.is_empty():
		return FieldGrid.center(game.horde_home())
	var mine: Array = doors
	if from != null:
		var up: bool = game.above_train(from)
		mine = doors.filter(func(door: Dictionary) -> bool: return bool(door["upper"]) == up)
		if mine.is_empty():
			mine = doors
	return FieldGrid.center(mine[n % mine.size()]["cell"])


## A place on the track beside the train, on the end nearer to `from`.
func track_spot(k: int, from = null) -> Vector3:
	var train: Rect2i = game.data["train"]
	var row: int = train.position.y + (k % maxi(train.size.y, 1))
	var step: int = 2 + k % TRACK_SPREAD
	var east: bool = from == null or from.x >= FieldGrid.center(train.get_center()).x
	return FieldGrid.center(Vector2i(train.end.x + step if east else train.position.x - 1 - step, row))


## "We leave now": the count starts. It cannot be called off.
func last_call() -> void:
	if not on or calling:
		return
	calling = true
	call_left = LAST_CALL_S
	game.set_radio("기관사: 셋을 센다. 탈 사람은 타라!", "must")


## Coal and plough parts that going now would cost for being unready, on top
## of the plough's price: {"coal", "plow_part"}.
func early_cost() -> Dictionary:
	if ready or total <= 0.0:
		return {"coal": 0, "plow_part": 0}
	var short: float = clampf(left / total, 0.0, 1.0)
	for step: Array in EARLY_STEPS:
		if short < float(step[0]):
			return {"coal": int(step[1]), "plow_part": int(step[2])}
	return {"coal": 0, "plow_part": 0}


## The dead the plough would push through, going now. Which way the train
## leaves is not S2's to say: the fuller side of the track.
func track_now() -> int:
	var t: Dictionary = game.track_dead()
	return maxi(int(t["west"]), int(t["east"]))


## The plough's price for that many dead on the track: {"parts", "word"}.
static func plough(dead: int) -> Dictionary:
	for step: Array in PLOUGH_STEPS:
		if dead <= int(step[0]):
			return {"parts": int(step[1]), "word": String(step[2])}
	return {"parts": 0, "word": ""}


## The trust that leaving this many people behind costs.
static func trust_drop(people: int) -> int:
	if people <= 0:
		return 0
	return mini(TRUST_FIRST + TRUST_EACH_MORE * (people - 1), TRUST_MOST)


## The train is going: what stood on the track is kept for the end lines.
func note_leaving() -> void:
	if track_at_leave < 0:
		track_at_leave = track_now()


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
	left = maxf(left - delta, 0.0)
	ready_shown = maxf(ready_shown - delta, 0.0)
	if ready:
		over += delta
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
	# Ready, and it waits: the chief says when (user decision 149). The doors
	# are still to be held and the waves keep coming.
	if left <= 0.0 and not ready:
		ready = true
		ready_shown = READY_SHOWN_S
		# The quiet while: what was coming comes that much later.
		var now: float = game.clock.elapsed
		game.director.quiet_until = now + QUIET_GAP_S
		# Those still held at the ways in by the cap turn back with it.
		game.pending_spawn.clear()
		game.director.next_arrival = maxf(game.director.next_arrival, game.director.quiet_until)
		game.set_radio("기관사: 채비 끝났다! 말만 하면 떠난다.", "must")


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
		if mode == "roll":
			return "버티기 위험: " + risk_word()
		return "버티기 판: 「떠난다」를 부르면 채비가 시작된다" if mode == "depart" else ""
	if ready:
		return "채비 끝 · 「떠난다」를 부르면 떠난다 · 문 멀쩡 %d · 상함 %d · 뚫림 %d · 물결 %d" % [count("whole"), count("damaged"), count("breached"), waves()]
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
		early = not ready
		on = false


## A rolled stop that never opened: what the roll was and why it did not, for
## the telemetry (the player is not told).
func roll_note() -> Dictionary:
	return {"rolled": rolled, "opened": false, "slipped": slipped, "chance": chance(), "noise": game.ledger.total, "trackDead": maxi(track_at_leave, 0)}


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
		"overSec": int(over),
		"leftShare": snappedf(clampf(left / total, 0.0, 1.0), 0.01) if total > 0.0 else 0.0,
		"trustDrop": trust_drop(left_people),
		"trackDead": maxi(track_at_leave, 0), "ploughParts": int(plough(maxi(track_at_leave, 0))["parts"]),
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
	if ready or early:
		var push: Dictionary = plough(int(r["trackDead"]))
		var cost: String = "%s · 떠나는 값: 쟁기 부품 %d" % [push["word"], int(push["parts"])]
		if ready:
			cost = "끝까지 버텼다 · " + cost
		if int(cost_paid["coal"]) > 0 or int(cost_paid["plow_part"]) > 0:
			cost += " · 덜 된 채비로 석탄 +%d, 부품 +%d" % [int(cost_paid["coal"]), int(cost_paid["plow_part"])]
		out.append(cost)
	# A number, never a name (user decision 147).
	if left_people > 0:
		out.append("남기고 온 사람 %d · 신임 −%d" % [left_people, trust_drop(left_people)])
	return out
