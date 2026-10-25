extends "res://addons/gut/test.gd"
## The train holds the dead its brakes brought (decision 416): one pure
## function for a played stop and an unplayed one, hurt but never killed.

const TrainGuard = preload("res://game/sim/train_guard.gd")
const ArrivalHorde = preload("res://game/sim/arrival_horde.gd")
const Receipt = preload("res://game/sim/receipt.gd")


func _receipt(id: String, kind: String) -> Receipt:
	var receipt := Receipt.new(id, kind)
	receipt.set_time("D1 10:00", "D1 11:00", 60)
	return receipt


func _bodies(times: Array, post: String = "cab_door") -> Array:
	var out: Array = []
	for i in range(times.size()):
		out.append({"id": i + 1, "t": float(times[i]), "post": post, "taken": INF})
	return out


func test_one_pair_of_hands_puts_them_down_one_after_another() -> void:
	var r: Dictionary = TrainGuard.resolve(_bodies([0.0, 0.0, 0.0]), 1, 3)
	assert_eq(r["came"], 3)
	assert_eq(r["killed"], 3)
	assert_eq(r["by_squad"], 0)
	assert_almost_eq(float(r["kills"][1]), TrainGuard.KILL_S, 0.001)
	assert_almost_eq(float(r["kills"][3]), TrainGuard.KILL_S * 3.0, 0.001)
	assert_almost_eq(float(r["took"]), TrainGuard.KILL_S * 3.0, 0.001)


func test_the_same_seed_gives_the_same_defence() -> void:
	var bodies := _bodies([0.0, 1.0, 1.5, 2.0, 2.0, 9.0, 30.0])
	assert_eq(TrainGuard.resolve(bodies, 2, 41), TrainGuard.resolve(bodies, 2, 41))
	var differs := false
	for s in range(1, 60):
		if TrainGuard.resolve(bodies, 2, s)["hurt"] != TrainGuard.resolve(bodies, 2, 41)["hurt"]:
			differs = true
	assert_true(differs, "the seed is what decides who is hurt")


func test_nobody_dies_of_it_and_no_wound_is_a_bite() -> void:
	for s in range(1, 200):
		var r: Dictionary = TrainGuard.resolve(_bodies([0, 0, 0, 0, 0, 0, 0, 0]), 2, s)
		for h: Dictionary in r["hurt"]:
			assert_true(TrainGuard.KINDS.has(h["kind"]))
			assert_ne(h["kind"], "bite")
		var receipt := _receipt("freight_01", "freight")
		TrainGuard.write(receipt, r, 8, 2)
		var def: Dictionary = TrainGuard.defense(r, ["p_001", "p_002"], s)
		assert_eq(def["dead"], [])
		for w: Dictionary in def["wounds"]:
			assert_true(["p_001", "p_002"].has(w["person"]))
			assert_ne(w["kind"], "bite")
		var d: Dictionary = receipt.to_dict()
		assert_eq((d["people"]["dead"] as Array).size(), 0)
		assert_eq((d["people"]["bitten"] as Array).size(), 0)
		assert_eq(receipt.problems().size(), 0, str(receipt.problems()))


func test_more_at_once_than_the_hands_hurts_more() -> void:
	var crowd := 0
	var spread := 0
	var times: Array = []
	for i in range(8):
		times.append(float(i) * TrainGuard.KILL_S)
	for s in range(1, 400):
		crowd += (TrainGuard.resolve(_bodies([0, 0, 0, 0, 0, 0, 0, 0]), 2, s)["hurt"] as Array).size()
		spread += (TrainGuard.resolve(_bodies(times), 2, s)["hurt"] as Array).size()
	assert_gt(crowd, spread, "%d against %d" % [crowd, spread])


func test_one_the_squad_puts_down_first_is_not_the_guards() -> void:
	var bodies := _bodies([0.0, 0.0, 0.0])
	bodies[2]["taken"] = 1.0
	var r: Dictionary = TrainGuard.resolve(bodies, 1, 5)
	assert_eq(r["killed"], 2)
	assert_eq(r["by_squad"], 1)
	assert_false((r["kills"] as Dictionary).has(3))
	assert_almost_eq(float(r["kills"][2]), TrainGuard.KILL_S * 2.0, 0.001, "the hands are free for the next sooner")


func test_one_that_walks_off_is_nobody_s() -> void:
	var bodies := _bodies([0.0, 0.0])
	bodies[1]["taken"] = 2.0
	bodies[1]["by"] = "left"
	var r: Dictionary = TrainGuard.resolve(bodies, 1, 5)
	assert_eq(r["killed"], 1)
	assert_eq(r["by_squad"], 0)


func test_no_hands_put_nobody_down() -> void:
	var r: Dictionary = TrainGuard.resolve(_bodies([0.0, 4.0]), 0, 5)
	assert_eq(r["killed"], 0)
	assert_eq((r["hurt"] as Array).size(), 0)


## What it says of a time does not wait for what comes after (the field runs
## it again as each one gets to the train).
func test_it_is_causal() -> void:
	var all := _bodies([0.0, 0.5, 1.0, 1.0, 3.0, 7.0, 7.5, 20.0])
	for s in range(1, 40):
		var full: Dictionary = TrainGuard.resolve(all, 2, s)
		for cut in [1, 3, 5, 7]:
			var part: Dictionary = TrainGuard.resolve(all.slice(0, cut), 2, s)
			var now: float = float(all[cut - 1]["t"])
			for id: int in part["kills"]:
				if float(part["kills"][id]) <= now:
					assert_eq(part["kills"][id], full["kills"][id])
			for h: Dictionary in part["hurt"]:
				if float(h["t"]) <= now:
					assert_true(full["hurt"].has(h) or _post_worse(full["hurt"], h), "seed %d cut %d" % [s, cut])


func _post_worse(rows: Array, h: Dictionary) -> bool:
	for r: Dictionary in rows:
		if r["post"] == h["post"] and TrainGuard.KINDS.find(r["kind"]) >= TrainGuard.KINDS.find(h["kind"]):
			return true
	return false


## A stop nobody goes out on is held the same way and writes the same rows.
func test_an_unplayed_stop_goes_through_the_same_function() -> void:
	var r: Dictionary = TrainGuard.auto("houses", 2, 9)
	assert_eq(r, TrainGuard.resolve(ArrivalHorde.auto_bodies("houses"), 2, 9))
	assert_eq(r["came"], int(ArrivalHorde.band("houses")[0]))
	var receipt := _receipt("houses_01", "houses")
	receipt.set_source("auto")
	TrainGuard.write(receipt, r, 0, 2)
	var d: Dictionary = receipt.to_dict()
	assert_eq(d["source"], "auto")
	assert_eq(d["placeState"]["trainGuard"]["came"], r["came"])
	assert_eq(d["placeState"]["trainGuard"]["killed"], r["killed"])
	assert_eq(receipt.problems().size(), 0, str(receipt.problems()))


## The S3 contract's "defense": the people at the posts, who of them was
## hurt and how, nobody dead; with nobody named there is none.
func test_a_hurt_guard_goes_in_the_contract_s_defense() -> void:
	var r := {"came": 2, "killed": 2, "by_squad": 0, "took": 8.0, "kills": {}, "starts": {},
		"hurt": [{"post": "roof", "kind": "laceration", "t": 4.0, "id": 2}]}
	var def: Dictionary = TrainGuard.defense(r, ["p_010", "p_011"], 3)
	assert_true(def["held"])
	assert_eq(def["people"], ["p_010", "p_011"])
	assert_eq(def["hurt"], ["p_010"], "the roof is the third post: the first of two")
	assert_eq(def["dead"], [])
	assert_eq((def["wounds"] as Array).size(), 1)
	assert_eq(def["wounds"][0]["kind"], "laceration")
	assert_true(["arm_left", "arm_right", "torso"].has(def["wounds"][0]["part"]))
	assert_null(TrainGuard.defense(r, [], 3))
	var receipt := _receipt("freight_01", "freight")
	TrainGuard.write(receipt, r, 2, 2)
	assert_eq(receipt.to_dict()["placeState"]["trainGuard"]["hurt"], ["roof"])
	assert_eq((receipt.to_dict()["witnessed"] as Array).size(), 0, "no row of its own among the witnessed")


func test_the_post_is_where_it_got_to_the_train() -> void:
	var train := Rect2i(10, 5, 40, 3)
	assert_eq(TrainGuard.post_at(52, train), "plow")
	assert_eq(TrainGuard.post_at(45, train), "cab_door")
	assert_eq(TrainGuard.post_at(12, train), "car_door")
	assert_eq(TrainGuard.post_at(20, train), "roof")
