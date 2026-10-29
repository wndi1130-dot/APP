extends SceneTree
## The brakes heard and the train holding what they bring (decision 416),
## measured: fixed seeds, the squad left standing where it gets off, before
## (opts "arrival_horde" false: the brakes heard by nobody) and after.
## godot --headless --path s2 -s res://tools/arrival_runs.gd -- --seeds 1:10 --seconds 300 --hz 5 --places freight_01,houses_01,mine_01
## Prints one tab-separated row a run and a summary a place and phase.
## --act act3 --act-progress 1.0: how far along the journey (decision 498's cap); --form remote: the stop's form.
## --census: instead, every map's dead within the brakes' reach of its engine
## against its kind's most (arrival_horde.gd SIZE).

const FieldGame = preload("res://game/field_game.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const ArrivalHorde = preload("res://game/sim/arrival_horde.gd")

var seed_first := 1
var seed_last := 10
var seconds := 300.0
var hz := 5
var places: Array = ["first_leg_01_sulechow", "houses_01", "mine_02"]
var act := "prologue"
var act_progress := 0.0
var form := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--census"):
		_census()
		quit(0)
		return
	for i in range(args.size() - 1):
		match args[i]:
			"--seeds":
				var p := args[i + 1].split(":")
				seed_first = int(p[0])
				seed_last = int(p[1])
			"--seconds":
				seconds = float(args[i + 1])
			"--hz":
				hz = int(args[i + 1])
			"--places":
				places = Array(args[i + 1].split(","))
			"--act":
				act = args[i + 1]
			"--act-progress":
				act_progress = float(args[i + 1])
			"--form":
				form = args[i + 1]
	print("place\tphase\tseed\theard\tfilled\tcame\tfirst_at_train\tby_guards\tby_squad\ttook\thurt\tfirst_horde\tsquad_hurt")
	for place in places:
		for phase in ["before", "after"]:
			var sums := {"heard": 0.0, "came": 0.0, "first": 0.0, "first_n": 0, "guards": 0.0, "squad": 0.0, "took": 0.0, "hurt": 0.0, "horde": 0.0, "horde_n": 0, "squad_hurt": 0.0}
			var n := 0
			for s in range(seed_first, seed_last + 1):
				var row: Dictionary = await _trial(String(place), phase, s)
				n += 1
				for k in ["heard", "came", "guards", "squad", "took", "hurt", "squad_hurt"]:
					sums[k] += float(row[k])
				if float(row["first"]) >= 0.0:
					sums["first"] += float(row["first"])
					sums["first_n"] += 1
				if float(row["horde"]) >= 0.0:
					sums["horde"] += float(row["horde"])
					sums["horde_n"] += 1
			print("SUMMARY\t%s\t%s\truns=%d\theard=%.2f\tcame=%.2f\tfirst_at_train=%.1f\tby_guards=%.2f\tby_squad=%.2f\ttook=%.1f\thurt=%.2f\tfirst_horde=%.1f(%d)\tsquad_hurt=%.2f" % [
				place, phase, n, sums["heard"] / n, sums["came"] / n,
				sums["first"] / maxi(sums["first_n"], 1), sums["guards"] / n, sums["squad"] / n,
				sums["took"] / n, sums["hurt"] / n, sums["horde"] / maxi(sums["horde_n"], 1), sums["horde_n"], sums["squad_hurt"] / n])
	quit(0)


func _trial(place: String, phase: String, s: int) -> Dictionary:
	var game = FieldGame.new()
	game.opts = {"seed": s, "raiders": false, "auto_pause": false, "place": place, "arrive": false, "arrival_horde": phase == "after",
		"act": act, "act_progress": act_progress}
	if form != "":
		game.opts["stop_form"] = form
	root.add_child(game)
	game.set_process(false)
	var step := 1.0 / float(hz)
	var t := 0.0
	var first := -1.0
	while t < seconds and not game.ended:
		game._step(step)
		t += step
		if first < 0.0 and not game.train_guard.bodies.is_empty():
			first = float(game.train_guard.bodies[0]["t"])
	var g = game.train_guard
	var r: Dictionary = g.result
	var horde := -1.0
	if game.hordes.has(0):
		horde = float(game.hordes[0]["t"])
	var squad_hurt := 0
	for p in game.squad:
		squad_hurt += p.body.wounds.size()
	var row := {"heard": g.heard, "filled": g.filled, "came": g.bodies.size(), "first": first,
		"guards": int(r.get("killed", 0)), "squad": int(r.get("by_squad", 0)), "took": float(r.get("took", 0.0)),
		"hurt": (r.get("hurt", []) as Array).size(), "horde": horde, "squad_hurt": squad_hurt}
	print("%s\t%s\t%d\t%d\t%d\t%d\t%.1f\t%d\t%d\t%.1f\t%d\t%.1f\t%d" % [place, phase, s, row["heard"], row["filled"], row["came"], first, row["guards"], row["squad"], row["took"], row["hurt"], horde, squad_hurt])
	game.queue_free()
	await process_frame
	return row


func _census() -> void:
	print("map	kind	by_engine	least	most")
	for id in FieldMaps.ids():
		var d: Dictionary = FieldMaps.build(id)
		if not d["anchors"].has("whistle"):
			continue
		var spot: Vector3 = FieldGrid.center(d["anchors"]["whistle"])
		var n := 0
		for key: String in d["spawns"]:
			if (key.begins_with("dead_") and key != "dead_levels") or key in ["clothed_station", "clothed_shed"]:
				for c in d["spawns"][key]:
					if FieldGrid.center(c).distance_to(spot) <= ArrivalHorde.reach():
						n += 1
		var b: Array = ArrivalHorde.band(String(d["place_kind"]))
		print("%s	%s	%d	%d	%d%s" % [id, d["place_kind"], n, b[0], b[1], "	OVER" if n > int(b[1]) else ""])
