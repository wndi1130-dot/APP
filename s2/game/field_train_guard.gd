extends RefCounted
## The brakes as a sound of the field and the train holding what they bring
## (decision 416; the rules in sim/arrival_horde.gd and sim/train_guard.gd).
##
## The sound is made once, as the stop's clock starts (field_game _ready),
## whether the train is seen rolling in or not: the scene only shows it, so a
## touch that skips it changes nothing. The dead it calls walk to the engine
## end; each one that gets to the train in the first minutes is put down
## there by the guards, by the one function an unplayed stop uses too. One the
## squad puts down first is not theirs, so the squad at the train spares them.

const FieldGrid = preload("res://game/world/field_grid.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const ArrivalHorde = preload("res://game/sim/arrival_horde.gd")
const TrainGuard = preload("res://game/sim/train_guard.gd")

## Cells round the train within which the guards reach one of the dead.
const REACH_CELLS := 2
## Each of them makes for its own place along the engine end, up to this many
## cells either way of where the brakes were, so they come up against the
## plough, the cab door and the first car's door instead of piling on one cell.
const SPREAD_CELLS := 7

var game  # field_game.gd
## Made (or a stop come back to: what was heard is in the save's dead).
var done: bool = false
var spot := Vector3.ZERO
var heard: int = 0
var filled: int = 0
var hands: int = TrainGuard.HANDS
var guard_ids: Array = []
## train_guard.gd's input, as they get to the train; by id.
var bodies: Array = []
var by_id: Dictionary = {}
var result: Dictionary = {}
var fill_due: Array = []
var engaged: Dictionary = {}
var put_down: Dictionary = {}
var told: Dictionary = {}
var radio_said: bool = false


func _init(field_game) -> void:
	game = field_game


## The train has come to a stand: its brakes, heard as any sound (noise.gd
## SOURCES "train_brake"), and those who heard them set off for it.
func brake() -> void:
	if done:
		return
	done = true
	spot = FieldGrid.center(game.data["anchors"]["whistle"])
	# The train's people at the posts (the departure contract's ids, S3), else
	# as many nameless hands as the stop says.
	guard_ids = game.opts.get("train_guard_ids", []) if game.opts.get("train_guard_ids") is Array else []
	hands = guard_ids.size() if not guard_ids.is_empty() else maxi(int(game.opts.get("train_guards", TrainGuard.HANDS)), 0)
	game.make_sound(spot, ArrivalHorde.LEVEL, "train_brake")
	for z in game.zombies.list:
		if z["state"] == "investigate" and (z["target"] as Vector3).distance_to(spot) < 0.01:
			z["arrival"] = true
			z["target"] = place_for(int(z["id"]))
			heard += 1
	filled = ArrivalHorde.fill(heard, String(game.data["place_kind"]))
	for i in range(filled):
		fill_due.append({"t": ArrivalHorde.FILL_GAP_S * float(i), "i": i})


## A stop come back to mid-play: the brakes were heard before it was left.
func resumed() -> void:
	done = true
	radio_said = true


func tick() -> void:
	if not done:
		return
	var now: float = game.clock.elapsed
	_fill(now)
	if not radio_said and now >= ArrivalHorde.RADIO_AT_S:
		radio_said = true
		if heard + filled > 0:
			game.set_radio(ArrivalHorde.RADIO_LINE, "urgent", spot)
	var changed := false
	for z in game.zombies.list:
		if not z.get("arrival", false):
			continue
		var id: int = int(z["id"])
		if by_id.has(id):
			var b: Dictionary = by_id[id]
			if z["state"] == "dead" and not put_down.has(id) and float(b["taken"]) == INF:
				b["taken"] = now
				changed = true
		elif game.zombies.threat(z) and now <= ArrivalHorde.WINDOW_S and at_train(z["pos"]):
			var row := {"id": id, "t": now, "post": TrainGuard.post_at(FieldGrid.cell_of(z["pos"]).x, game.data["train"]), "taken": INF}
			bodies.append(row)
			by_id[id] = row
			changed = true
	if changed:
		result = TrainGuard.resolve(bodies, hands, game.rng.seed)
	if result.is_empty():
		return
	# A guard gets to one: it is held there, or it has walked off.
	for id: int in result["starts"]:
		if engaged.has(id) or float(result["starts"][id]) > now:
			continue
		engaged[id] = true
		var z: Dictionary = game.zombies.find(id)
		if z.is_empty() or not game.zombies.threat(z):
			continue
		if not at_train(z["pos"]):
			by_id[id]["taken"] = now
			by_id[id]["by"] = "left"
			result = TrainGuard.resolve(bodies, hands, game.rng.seed)
			continue
		if not z["state"] in ["grab", "attack", "downed"]:
			z["state"] = "investigate"
			z["target"] = z["pos"]
			z["linger"] = TrainGuard.KILL_S + 1.0
	for id: int in result["kills"]:
		if put_down.has(id) or float(result["kills"][id]) > now:
			continue
		put_down[id] = true
		var z: Dictionary = game.zombies.find(id)
		if z.is_empty() or not game.zombies.threat(z):
			continue
		game.zombies.kill(z)
		game.make_sound(z["pos"], SimNoise.Level.QUIET, "train_guard")
	for h: Dictionary in result["hurt"]:
		if told.has(h["post"]) or float(h["t"]) > now:
			continue
		told[h["post"]] = true
		if game.hud != null:
			game.hud.toast("열차 %s 쪽을 지키던 사람이 다쳤다." % POST_WORDS.get(String(h["post"]), "문"))


const POST_WORDS := {"plow": "쟁기", "cab_door": "기관실 문", "roof": "지붕", "car_door": "객차 문"}


## Where one of them makes for: along the train's side from the brakes'
## place, by its own number (no dice of the game's are drawn).
func place_for(id: int) -> Vector3:
	var u: float = float(("%d:%d:arrival_place" % [game.rng.seed, id]).hash() & 0xFFFF) / 65535.0
	var off: float = roundf(lerpf(-float(SPREAD_CELLS), float(SPREAD_CELLS), u))
	return game.walkable_near(spot + Vector3(off, 0.0, 0.0), true, 2)


## Close enough to the train for the guards at its doors and on its roof.
func at_train(at: Vector3) -> bool:
	if game.level_of(at) != 0:
		return false
	return (game.data["train"] as Rect2i).grow(REACH_CELLS).has_point(FieldGrid.cell_of(at))


## On the receipt as the stop ends (train_guard.gd write).
func write_receipt() -> void:
	if not done or result.is_empty() and heard + filled == 0:
		return
	if result.is_empty():
		result = TrainGuard.resolve(bodies, hands, game.rng.seed)
	TrainGuard.write(game.receipt, result, heard, hands)
	# The S3 contract's own field, once the receipt has it (v5); only with the
	# train's people named, there is nobody to name otherwise.
	var d: Variant = TrainGuard.defense(result, guard_ids, game.rng.seed)
	if d is Dictionary and game.receipt.has_method("set_defense"):
		game.receipt.set_defense(d["held"], d["people"], d["hurt"], d["dead"], d["wounds"])


## The rest of those within reach walk in along the nearest way in that is
## out of sight (the fair spawn rule), one after another.
func _fill(now: float) -> void:
	if fill_due.is_empty():
		return
	var keep: Array = []
	for f: Dictionary in fill_due:
		if now < float(f["t"]):
			keep.append(f)
			continue
		var key := _way_in()
		if key == "":
			continue
		var at: Vector3 = game.entry_pos(key, int(f["i"]))
		var z: Dictionary = game.zombies.spawn("dead", at, {"target": spot})
		z["target"] = place_for(int(z["id"]))
		z["stander"] = false
		z["arrival"] = true
	fill_due = keep


func _way_in() -> String:
	var best := ""
	var best_d := INF
	for key in game.road_entries():
		if game._entry_on_screen(key):
			continue
		var d: float = game.entry_pos(key).distance_to(spot)
		if d < best_d:
			best_d = d
			best = key
	return best
