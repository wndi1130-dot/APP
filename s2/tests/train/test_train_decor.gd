extends "res://addons/gut/test.gd"

const Decor = preload("res://game/train/train_decor.gd")
const Mods = preload("res://game/train/train_mods.gd")
const Dom = preload("res://game/train/train_dom.gd")
const LawTech = preload("res://game/train/train_lawtech.gd")
const Save = preload("res://game/politics/save_slot.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const TV = preload("res://tests/train/train_vectors.gd")
const FV = preload("res://tests/politics/field_vectors.gd")
const PATH := "res://tests/fixtures/train/mods_vectors.json"
var _data: Dictionary = {}


func before_all() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))["decor"]


func _same(want: Variant, got: Variant, label: String = "") -> void:
	assert_eq(TV.diff(want, got, label), "")
	assert_eq(TV.diff(got, want, label + " unexpected"), "")


func _fresh() -> Dictionary:
	var g: Dictionary = TV.points()[0]["state"].duplicate(true)
	g["dom"] = Dom.start()
	g["food"] = 100.0
	g["lux"] = 100.0
	g["med"] = 10.0
	g["sup"] = 20.0
	g["ledger"] = []
	g["journal"] = []
	# The table points carry no draw state or card list; a save read and the draw check need both.
	g["rng"] = {"state": 1}
	if not g.has("cards"): g["cards"] = []
	return g


func _tier(g: Dictionary, car: String, n: int) -> void:
	g["dom"]["furnish"][car] = {"work": n, "jobs": range(1, n + 1), "furnPts": 0, "tier": n, "best": n, "items": []}


func _put(g: Dictionary, car: String, kind: String, on: Variant = null) -> void:
	Decor.receive_decor(g, [kind])
	assert_eq(Mods.place(g, car, kind, Decor.DECOR[kind]["spot"], [2, 0], 0, on), {"ok": true})


func test_residential_wall_overflow_keeps_even_unreconciled_stock_and_all_state() -> void:
	var g: Dictionary = _fresh()
	_put(g, "front", "piano")
	_put(g, "front", "painting")
	Decor.receive_decor(g, ["rare_violin"])
	g["lux"] = 0.0
	var before: Dictionary = g.duplicate(true)
	assert_eq(Mods.take_back(g, "front", 0), {"ok": false, "why": "살림이 내려가면 자리가 모자란다. 다른 것부터 거둬라"})
	assert_eq(g, before)
	assert_true(Mods.take_back(g, "front", 1)["ok"])
	assert_true(Mods.take_back(g, "front", 0)["ok"])
	assert_eq(Mods.furnish_of(g, "front")["tier"], 0)
	assert_eq(Mods.furnish_of(g, "front")["best"], 1)
	assert_eq(Mods.slots_open(g, "front"), {"floor": 8, "wall": 0, "surface": 0})


func test_surface_overflow_is_per_parent_and_failed_cascade_keeps_everything() -> void:
	var g: Dictionary = _fresh()
	_put(g, "front", "cupboard")
	_put(g, "front", "side_table")
	_put(g, "front", "side_table")
	for _i: int in 4: _put(g, "front", "can_beans", 0)
	for _i: int in 3: _put(g, "front", "record", 1)
	var before: Dictionary = g.duplicate(true)
	assert_eq(Mods.take_back(g, "front", 0), {"ok": false, "why": "살림이 내려가면 자리가 모자란다. 다른 것부터 거둬라"})
	assert_eq(g, before)


func test_cascade_is_excluded_before_capacity_check_and_remaining_indices_are_remapped() -> void:
	var g: Dictionary = _fresh()
	_put(g, "front", "cupboard")
	_put(g, "front", "side_table")
	for _i: int in 4: _put(g, "front", "can_beans", 0)
	for _i: int in 2: _put(g, "front", "record", 1)
	var food: float = g["food"]
	assert_true(Mods.take_back(g, "front", 0)["ok"])
	assert_eq(Mods.furnish_of(g, "front")["tier"], 0)
	assert_eq(Mods.furnish_of(g, "front")["best"], 1)
	assert_eq(Decor.items_of(g, "front").map(func(item: Dictionary) -> String: return item["kind"]), ["side_table", "record", "record"])
	assert_eq(Decor.items_of(g, "front").slice(1).map(func(item: Dictionary) -> int: return item["on"]), [0, 0])
	assert_eq(float(g["food"]), food + 4 * float(Decor.DECOR["can_beans"]["v"]))
	assert_eq(Decor.read_store(g)["can_beans"]["n"], 4)
	assert_eq(Mods.slots_open(g, "front")["surface"], 0)


func test_common_tier_drop_checks_both_cars_floor_wall_and_each_surface() -> void:
	for car: String in ["captain", "dining"]:
		for spot: String in ["floor", "wall", "surface"]:
			var g: Dictionary = _fresh()
			_put(g, "front", "piano")
			match spot:
				"floor":
					for _i: int in 9: _put(g, car, "chair")
				"wall": _put(g, car, "painting")
				"surface":
					_put(g, car, "side_table")
					for _i: int in 3: _put(g, car, "record", 0)
			var before: Dictionary = g.duplicate(true)
			assert_eq(Mods.take_back(g, "front", 0), {"ok": false, "why": "살림이 내려가면 자리가 모자란다. 다른 것부터 거둬라"}, car + " " + spot)
			assert_eq(g, before)
			assert_eq(Decor.common_tier(g), 1)


func test_another_current_tier_keeps_common_capacity_until_the_last_car_drops() -> void:
	var g: Dictionary = _fresh()
	_put(g, "front", "piano")
	_put(g, "tail1", "piano")
	_put(g, "captain", "painting")
	_put(g, "dining", "painting")
	assert_true(Mods.take_back(g, "front", 0)["ok"])
	assert_eq(Decor.common_tier(g), 1)
	assert_false(Mods.take_back(g, "tail1", 0)["ok"])
	assert_true(Mods.take_back(g, "captain", 0)["ok"])
	assert_false(Mods.take_back(g, "tail1", 0)["ok"])
	assert_true(Mods.take_back(g, "dining", 0)["ok"])
	assert_true(Mods.take_back(g, "tail1", 0)["ok"])
	assert_eq(Decor.common_tier(g), 0)
	assert_eq(Mods.slots_open(g, "captain")["wall"], 0)
	assert_eq(Mods.slots_open(g, "dining")["floor"], 8)


func test_legacy_best_is_filled_without_recalculating_tier_on_load() -> void:
	for best: Variant in [null, 0, 1]:
		var g: Dictionary = _fresh()
		g["version"] = Save.SAVE_VERSION
		g["dom"]["furnish"]["front"] = {"work": 0, "jobs": [], "furnPts": 0, "tier": 1, "items": []}
		if best != null: g["dom"]["furnish"]["front"]["best"] = best
		var loaded: Dictionary = Save.read_save(g, TV.tables())
		assert_true(loaded["ok"])
		if not loaded["ok"]: continue
		var restored: Dictionary = loaded["g"]
		assert_eq(restored["version"], Save.SAVE_VERSION)
		assert_eq(restored["rng"], g["rng"])
		assert_eq(Mods.furnish_of(restored, "front")["tier"], 1)
		assert_eq(Mods.furnish_of(restored, "front")["best"], 1)
		assert_true(Dom.is_store(restored["dom"]))
		var journal: Array = restored["journal"].duplicate(true)
		var rel: float = restored["comms"]["front"]["rel"]
		Mods._update_furnish(restored, "front")
		assert_eq(Mods.furnish_of(restored, "front")["tier"], 0)
		assert_eq(Mods.furnish_of(restored, "front")["best"], 1)
		_put(restored, "front", "piano")
		assert_eq(restored["comms"]["front"]["rel"], rel)
		assert_eq(restored["journal"], journal)


func test_catalog_and_all_slot_tables_match_s1() -> void:
	var tables: Dictionary = _data["tables"]
	var actual: Dictionary = {"DECOR": Decor.DECOR, "DECOR_CARS": Decor.DECOR_CARS, "DECOR_SLOT_TABLE": Decor.DECOR_SLOT_TABLE,
		"DECOR_SLOTS": Decor.DECOR_SLOTS, "FURNISH_WALL_MAX": Decor.FURNISH_WALL_MAX, "FURNISH_FLOOR_MAX": Decor.FURNISH_FLOOR_MAX}
	for key: String in ["DECOR", "DECOR_CARS", "DECOR_SLOT_TABLE", "DECOR_SLOTS", "FURNISH_WALL_MAX", "FURNISH_FLOOR_MAX"]:
		_same(tables[key], actual[key], key)
	assert_eq(Decor.DECOR.size(), 25)
	var furniture: int = 0
	var surfaces: int = 0
	for kind: String in Decor.DECOR:
		var def: Dictionary = Decor.DECOR[kind]
		furniture += int(def["furniture"])
		surfaces += int(def["surface"])
		assert_eq(def["model"], "")
		if def.has("res"):
			# bottle_spirit is an existing legacy STOCK_OF entry in field_game.gd. The tag is exactly what the
			# field credits — rounding it up would melt the piece on arrival.
			var raw: float = 0.5 if kind == "bottle_spirit" else float(FieldItems.stock_of(kind)[1])
			assert_almost_eq(float(def["v"]), raw, 0.0001, kind)
	assert_eq(furniture, 16)
	assert_eq(surfaces, 6)
	assert_eq(Decor.DECOR["frame"]["spot"], "wall")
	assert_eq(Decor.DECOR_CARS.size(), 8)
	assert_eq(Mods.FURNISH_CARS.size(), 6)


func test_residential_slots_each_tier_and_wall_clamps() -> void:
	var walls: Dictionary = {"tail1": [0, 4, 6, 6], "tail2": [0, 4, 7, 7], "tail3": [0, 4, 5, 5], "medtech": [0, 4, 7, 10], "guard": [0, 4, 7, 10], "front": [0, 4, 7, 10]}
	for car: String in Mods.FURNISH_CARS:
		for n: int in 4:
			var g: Dictionary = _fresh()
			_tier(g, car, n)
			assert_eq(Mods.slots_open(g, car), {"floor": [8, 14, 21, 29][n], "wall": walls[car][n], "surface": 0})
			_put(g, car, "side_table")
			assert_eq(Mods.slots_open(g, car), {"floor": [7, 13, 20, 28][n], "wall": walls[car][n], "surface": [2, 4, 6, 8][n]})
	for row: Dictionary in _data["slots"]:
		_same(row["open"], Mods.slots_open(row["state"], row["car"]), "%s tier %d surface %s" % [row["car"], row["tier"], row["surface"]])
	assert_eq(_data["slots"].size(), 64)


func test_common_cars_follow_highest_tier_without_jobs_points_or_effects() -> void:
	for car: String in ["captain", "dining"]:
		var g: Dictionary = _fresh()
		assert_eq(Decor.common_tier(g), 0)
		assert_eq(Mods.slots_open(g, car), {"floor": 8, "wall": 0, "surface": 0})
		_tier(g, "front", 1)
		_tier(g, "tail3", 2)
		assert_eq(Decor.common_tier(g), 2)
		assert_eq(Mods.slots_open(g, car), {"floor": 13 if car == "dining" else 21, "wall": 7, "surface": 0})
		_tier(g, "guard", 3)
		assert_eq(Decor.common_tier(g), 3)
		assert_eq(Mods.slots_open(g, car), {"floor": 13 if car == "dining" else 29, "wall": 10, "surface": 0})
		var before: Dictionary = {"comms": g["comms"].duplicate(true), "ledger": g["ledger"].duplicate(true), "journal": g["journal"].duplicate(true)}
		_put(g, car, "piano")
		assert_eq(g["dom"]["furnish"][car], {"items": [{"kind": "piano", "size": "large", "spot": "floor", "at": [2, 0], "rot": 0}]})
		assert_false(Mods.job_check(g, "furnish", car)["ok"])
		assert_eq({"comms": g["comms"], "ledger": g["ledger"], "journal": g["journal"]}, before)
		assert_true(Dom.is_store(g["dom"]))
		assert_true(Mods.take_back(g, car, 0)["ok"])


func test_floor_and_wall_limits_do_not_consume_one_more_object() -> void:
	for n: int in [1, 2, 3]:
		var g: Dictionary = _fresh()
		_tier(g, "front", n)
		var count: int = [8, 14, 21, 29][n]
		for _i: int in count + 1: Decor.receive_decor(g, ["chair"])
		for _i: int in count: assert_true(Mods.place(g, "front", "chair", "floor")["ok"])
		assert_eq(Mods.slots_open(g, "front")["floor"], 0)
		assert_false(Mods.place(g, "front", "chair", "floor")["ok"])
		assert_eq(Decor.read_store(g)["chair"]["n"], 1)
	for row: Array in [["tail1", 6], ["tail2", 7], ["tail3", 5]]:
		var g: Dictionary = _fresh()
		_tier(g, row[0], 3)
		for _i: int in int(row[1]) + 1: Decor.receive_decor(g, ["frame"])
		for _i: int in int(row[1]): assert_true(Mods.place(g, row[0], "frame", "wall")["ok"])
		assert_false(Mods.place(g, row[0], "frame", "wall")["ok"])
		assert_eq(Decor.read_store(g)["frame"]["n"], 1)


func test_rejects_other_cars_and_wrong_spots_without_consuming_inventory() -> void:
	var g: Dictionary = _fresh()
	Decor.receive_decor(g, ["chair"])
	for car: String in ["engine", "store", "cold", "workshop", "tail4", "missing"]:
		assert_false(Mods.can_place(g, car, "chair", "floor")["ok"])
		assert_eq(Mods.slots_open(g, car), {"floor": 0, "wall": 0, "surface": 0})
	assert_false(Mods.place(g, "front", "not_a_kind", "floor")["ok"])
	assert_false(Mods.place(g, "front", "chair", "wall")["ok"])
	assert_eq(g["dom"]["store"]["chair"]["n"], 1)


func test_place_move_rotate_take_back_only_carry_coordinates() -> void:
	var g: Dictionary = _fresh()
	_tier(g, "front", 1)
	Decor.receive_decor(g, ["chair", "frame"])
	var at: Array = [0, 0]
	assert_true(Mods.place(g, "front", "chair", "floor", at, 1)["ok"])
	at[0] = 9
	assert_eq(Decor.items_of(g, "front")[0]["at"], [0, 0])
	assert_true(Mods.place(g, "front", "frame", "wall", [-1, 1], 0)["ok"])
	assert_eq(Mods.slots_open(g, "front"), {"floor": 13, "wall": 3, "surface": 0})
	assert_true(Mods.move(g, "front", 0, [300, -7], 2)["ok"])
	assert_true(Mods.rotate(g, "front", 0, 3)["ok"])
	assert_eq(Decor.items_of(g, "front")[0]["at"], [300, -7])
	assert_eq(Decor.items_of(g, "front")[0]["rot"], 3)
	var before: Dictionary = g.duplicate(true)
	assert_false(Mods.move(g, "front", 0.5, [0, 0])["ok"])
	assert_false(Mods.move(g, "front", 0, [0.5, 0])["ok"])
	assert_false(Mods.rotate(g, "front", 0, 4)["ok"])
	assert_eq(g, before)
	assert_true(Mods.take_back(g, "front", 0)["ok"])
	assert_true(Mods.take_back(g, "front", 0)["ok"])
	assert_eq(Mods.slots_open(g, "front"), {"floor": 14, "wall": 4, "surface": 0})
	assert_eq(Decor.read_store(g), {"chair": {"n": 1}, "frame": {"n": 1}})


func test_surface_limits_and_parent_removal_remap_remaining_indices() -> void:
	var g: Dictionary = _fresh()
	_tier(g, "front", 1)
	_put(g, "front", "chair")
	_put(g, "front", "side_table")
	_put(g, "front", "table")
	for _i: int in 4: _put(g, "front", "record", 2)
	Decor.receive_decor(g, ["record"])
	assert_false(Mods.can_place(g, "front", "record", "surface", null, null, 2)["ok"])
	assert_true(Mods.can_place(g, "front", "record", "surface", null, null, 1)["ok"])
	assert_false(Mods.can_place(g, "front", "record", "surface", null, null, 0)["ok"])
	assert_false(Mods.can_place(g, "front", "record", "surface")["ok"])
	_put(g, "front", "can_beans", 1)
	var food: float = float(g["food"])
	assert_eq(Mods.slots_open(g, "front")["surface"], 3)
	Mods.take_back(g, "front", 0)
	for item: Dictionary in Decor.items_of(g, "front"):
		if item["kind"] == "record": assert_eq(item["on"], 1)
	assert_eq(Decor.items_of(g, "front")[-1]["on"], 0)
	Mods.take_back(g, "front", 0)
	assert_eq(Decor.items_of(g, "front").size(), 5)
	for item: Dictionary in Decor.items_of(g, "front").slice(1): assert_eq(item["on"], 0)
	assert_eq(float(g["food"]), food + float(Decor.DECOR["can_beans"]["v"]))
	assert_eq(Decor.read_store(g)["can_beans"]["n"], 1)
	assert_eq(Mods.slots_open(g, "front")["surface"], 0)
	assert_true(Dom.is_store(g["dom"]))


func test_dual_items_spend_and_refund_exact_recorded_values() -> void:
	for kind: String in Decor.DECOR:
		var def: Dictionary = Decor.DECOR[kind]
		if not def.has("res"): continue
		var g: Dictionary = _fresh()
		_tier(g, "front", 1)
		_put(g, "front", "table")
		var res: String = def["res"]
		var before: float = float(g[res])
		Decor.receive_decor(g, [kind])
		assert_eq(float(g[res]), before)
		var on: Variant = 0 if def["spot"] == "surface" else null
		assert_true(Mods.place(g, "front", kind, def["spot"], null, null, on)["ok"])
		assert_eq(float(g[res]), before - float(def["v"]))
		assert_eq(Decor.items_of(g, "front")[1]["v"], def["v"])
		Mods.take_back(g, "front", 1)
		assert_eq(float(g[res]), before)
		g[res] = float(def["v"]) - 0.25
		assert_false(Mods.can_place(g, "front", kind, def["spot"], null, null, on)["ok"])
		assert_eq(float(g[res]), float(def["v"]) - 0.25)
	var historical: Dictionary = _fresh()
	_tier(historical, "front", 1)
	_put(historical, "front", "table")
	historical["dom"]["store"] = {"record": {"n": 1, "tags": [{"v": 3, "at": 7}]}}
	Mods.place(historical, "front", "record", "surface", null, null, 0)
	assert_eq(float(historical["lux"]), 97.0)
	Mods.take_back(historical, "front", 1)
	assert_eq(float(historical["lux"]), 100.0)
	assert_eq(Decor.read_store(historical)["record"]["tags"][0]["v"], 3)


func test_newest_tags_melt_across_kinds_but_placed_items_survive() -> void:
	var g: Dictionary = _fresh()
	_tier(g, "front", 1)
	g["lux"] = 4.0
	Decor.receive_decor(g, ["painting", "record", "rare_violin"])
	assert_true(Mods.place(g, "front", "rare_violin", "wall")["ok"])
	g["lux"] = 1.0
	var placed: Array = Decor.items_of(g, "front").duplicate(true)
	var rng: Dictionary = g["rng"].duplicate(true)
	var store: Dictionary = Decor.read_store(g)
	assert_eq(store["painting"]["tags"], [{"v": 0.75, "at": 0}])
	assert_false(store.has("record"))
	assert_eq(Decor.items_of(g, "front"), placed)
	g["lux"] = 0.0
	Decor.reconcile_store(g)
	assert_eq(g["dom"]["store"], {})
	assert_eq(Decor.items_of(g, "front"), placed)
	assert_eq(g["rng"], rng)
	Mods.take_back(g, "front", 0)
	assert_eq(float(g["lux"]), 1.5)
	assert_eq(Decor.read_store(g)["rare_violin"]["tags"][0]["v"], 1.5)


func test_receipt_gained_accepts_only_catalog_ids_without_crediting_numbers_twice() -> void:
	var g: Dictionary = _fresh()
	var before: float = float(g["lux"])
	Decor.receive_receipt(g, {"items": {"gained": ["chair", "painting", "can_beans", "not_decor"], "lost": []}})
	assert_eq(g["dom"]["store"].size(), 3)
	assert_eq(g["dom"]["store"]["chair"], {"n": 1})
	assert_eq(float(g["lux"]), before)
	assert_false(g["dom"]["store"].has("not_decor"))


func test_old_save_migration_keeps_version_rng_tier_and_unassigned_coordinates() -> void:
	var g: Dictionary = _fresh()
	g["version"] = 1  # an old save carries its slot version; the table point does not
	g["dom"].erase("store")
	g["dom"]["furnish"] = {"front": {"work": 0, "jobs": [], "furnPts": 1, "tier": 0, "best": 0, "items": [{"kind": "frame", "size": "small"}]}}
	assert_true(Dom.is_store(g["dom"]))
	var rng: Dictionary = g["rng"].duplicate(true)
	var loaded: Dictionary = Save.read_save(g, TV.tables())
	assert_true(loaded["ok"])
	if not loaded["ok"]: return
	assert_eq(Save.SAVE_VERSION, 1)
	assert_eq(int(loaded["g"]["version"]), 1)
	assert_eq(loaded["g"]["dom"]["store"], {})
	assert_eq(loaded["g"]["dom"]["decor80"], [])
	assert_eq(Decor.items_of(loaded["g"], "front"), [{"kind": "frame", "size": "small", "spot": "wall"}])
	assert_eq(loaded["g"]["rng"], rng)
	assert_true(Dom.is_store(loaded["g"]["dom"]))
	var once: Dictionary = loaded["g"].duplicate(true)
	Decor.migrate(loaded["g"])
	assert_eq(loaded["g"], once)


func test_save_contract_rejects_malformed_inventory_positions_and_surface_references() -> void:
	for store: Variant in [[], {"missing": {"n": 1}}, {"chair": {"n": -1}}, {"chair": {"n": 0.5}},
		{"chair": {"n": true}}, {"chair": {"n": 1, "tags": []}}, {"record": {"n": 1}},
		{"record": {"n": 1, "tags": []}}, {"record": {"n": 1, "tags": [{"v": 0, "at": 0}]}},
		{"record": {"n": 1, "tags": [{"v": -0.5, "at": 0}]}}, {"record": {"n": 1, "tags": [{"v": 1, "at": -1}]}}]:
		assert_false(Dom.is_store({"store": store}), str(store))
	var g: Dictionary = _fresh()
	_tier(g, "front", 1)
	_put(g, "front", "table")
	_put(g, "front", "record", 0)
	for patch: Dictionary in [{"on": 1}, {"on": 4}, {"on": 0.5}, {"rot": 4}, {"rot": true}, {"at": [1]}, {"at": [1.5, 0]}, {"at": null}, {"v": 0}, {"spot": "floor"}, {"extra": true}]:
		var bad: Dictionary = g["dom"].duplicate(true)
		bad["furnish"]["front"]["items"][1].merge(patch, true)
		assert_false(Dom.is_store(bad), str(patch))


func test_crowding_counts_only_floor_and_collectibles_add_no_furniture_points() -> void:
	var g: Dictionary = _fresh()
	_tier(g, "front", 1)
	_put(g, "front", "table")
	_put(g, "front", "bed_frame")
	var points: int = int(Mods.furnish_of(g, "front")["furnPts"])
	var before: Variant = LawTech.sit(g, "front")
	_put(g, "front", "rare_violin")
	_put(g, "front", "record", 0)
	assert_eq(int(Mods.furnish_of(g, "front")["furnPts"]), points)
	assert_eq(LawTech.sit(g, "front"), before)
	assert_eq(Decor.decor_crowd(Decor.items_of(g, "front")), 0.0)


func _owned(g: Dictionary) -> Dictionary:
	var rel: Dictionary = {}
	var slots: Dictionary = {}
	var crowd: Dictionary = {}
	for c: String in Mods.COMM_CARS: rel[c] = g["comms"][c]["rel"]
	for car: String in Decor.DECOR_CARS:
		slots[car] = Mods.slots_open(g, car)
		crowd[car] = Decor.decor_crowd(Decor.items_of(g, car))
	return {"furnish": g["dom"].get("furnish", {}), "store": g["dom"].get("store", {}),
		"food": g["food"], "med": g["med"], "lux": g["lux"], "sup": g["sup"], "rel": rel,
		"ledger": g.get("ledger", []), "slots": slots, "crowd": crowd}


func test_operations_replay_s1_results_and_complete_owned_state() -> void:
	var actions: int = 0
	for row: Dictionary in _data["cases"]:
		var g: Dictionary = row["state"].duplicate(true)
		for step: Dictionary in row["steps"]:
			var result: Variant = null
			var car: String = step.get("car", "")
			match step["op"]:
				"receive": Decor.receive_decor(g, step["gained"])
				"canPlace": result = Mods.can_place(g, car, step["kind"], step["spot"], step.get("at"), step.get("rot"), step.get("on"))
				"place": result = Mods.place(g, car, step["kind"], step["spot"], step.get("at"), step.get("rot"), step.get("on"))
				"move": result = Mods.move(g, car, step["i"], step["at"], step.get("rot"))
				"rotate": result = Mods.rotate(g, car, step["i"], step["rot"])
				"takeBack": result = Mods.take_back(g, car, step["i"])
				"spend": g[step["res"]] = float(g.get(step["res"], 0)) - float(step["amount"])
				"read": result = Decor.read_store(g)
				"reconcile": Decor.reconcile_store(g)
				"migrate": Decor.migrate(g)
			var label: String = "%s/%d %s" % [row["name"], actions, step["op"]]
			_same(step["result"], result, label + " result")
			_same(step["after"], _owned(g), label + " after")
			assert_true(Dom.is_store(g["dom"]), label + " saved shape")
			actions += 1
	assert_gt(actions, 40)


func _effect_owned(g: Dictionary) -> Dictionary:
	var out: Dictionary = {"percent": {}, "parts": {}, "gain": {}, "rel": {},
		"decor80": g["dom"].get("decor80", []).duplicate(true),
		"journal": g["journal"].duplicate(true), "ledger": g["ledger"].duplicate(true), "rng": g["rng"].duplicate(true)}
	for car: String in Decor.DECOR_CARS:
		out["percent"][car] = Decor.decor_percent(g, car)
		out["parts"][car] = Decor.decor_parts(g, car)
		out["gain"][car] = LawTech.decor_rel_gain(g, car)
	for c: String in g["comms"]: out["rel"][c] = g["comms"][c]["rel"]
	return out


func _effect_item(kind: String, on: int = -1) -> Dictionary:
	var item: Dictionary = {"kind": kind, "size": Decor.DECOR[kind]["size"], "spot": Decor.DECOR[kind]["spot"]}
	if on >= 0: item["on"] = on
	return item


func test_effects_replay_s1_percent_rewards_first80_and_reentry() -> void:
	var effects: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))["decorEffects"]
	_same(effects["voices"], Decor.FURNISH80, "exact story table")
	assert_eq(effects["cases"].size(), 133)
	for row: Dictionary in effects["cases"]:
		var g: Dictionary = row["state"].duplicate(true)
		var original: Dictionary = g["dom"]["furnish"].duplicate(true)
		_same(row["before"], _effect_owned(g), row["name"] + "/before")
		LawTech.furnish_tick(g)
		_same(row["first"], _effect_owned(g), row["name"] + "/first")
		for car: String in g["dom"]["furnish"]: g["dom"]["furnish"][car]["items"] = []
		LawTech.furnish_tick(g)
		_same(row["below"], _effect_owned(g), row["name"] + "/below")
		g["dom"]["furnish"] = original
		LawTech.furnish_tick(g)
		_same(row["again"], _effect_owned(g), row["name"] + "/again")
		for entry: Dictionary in g["ledger"]: assert_eq(entry["why"], "furnish")


func test_effect_thresholds_share_epsilon() -> void:
	var effects: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))["decorEffects"]
	for row: Dictionary in effects["thresholds"]:
		assert_eq(Decor.decor_band(row["percent"]), int(row["band"]))
	for i: int in 3:
		var line: float = float(Mods.D["decorThresholds"][i])
		assert_eq(Decor.decor_band(line - 2e-9), i - 1)
		assert_eq(Decor.decor_band(line - 0.5e-9), i)


func test_effect_kind_floor_wall_caps_for_eight_cars() -> void:
	var g: Dictionary = _fresh()
	var before: Dictionary = g.duplicate(true)
	for car: String in Decor.DECOR_CARS: assert_eq(Decor.decor_percent(g, car), 0.0)
	assert_eq(Decor.decor_percent(g, "engine"), 0.0)
	assert_eq(g, before)
	var kinds: Array = Decor.DECOR.keys()
	for n: int in [19, 20, 25]:
		g["dom"]["furnish"]["front"] = {"items": []}
		for i: int in n: g["dom"]["furnish"]["front"]["items"].append(_effect_item(kinds[i]))
		assert_almost_eq(Decor.decor_parts(g, "front")[0], minf(1.0, float(n) / 20.0), 1e-12)
	for car: String in Decor.DECOR_CARS:
		for spot: String in ["floor", "wall"]:
			var target: int = mini(25, Decor.FURNISH_FLOOR_MAX[car]) if spot == "floor" else mini(8, Decor.FURNISH_WALL_MAX[car])
			var index: int = 1 if spot == "floor" else 2
			for n: int in [target - 1, target, target + 1]:
				var items: Array = []
				for _i: int in n: items.append(_effect_item("chair" if spot == "floor" else "frame"))
				g["dom"]["furnish"][car] = {"items": items}
				assert_almost_eq(Decor.decor_parts(g, car)[index], minf(1.0, float(n) / target), 1e-12)


func test_effect_occupied_surface_small_objects_and_light_caps() -> void:
	var g: Dictionary = _fresh()
	for n: int in [0, 1, 3, 4, 5]:
		var items: Array = []
		for _i: int in 5: items.append(_effect_item("table"))
		for i: int in n: items.append(_effect_item("record", i))
		if n > 0: items.append(_effect_item("record", 0))
		g["dom"]["furnish"]["front"] = {"items": items}
		assert_almost_eq(Decor.decor_parts(g, "front")[3], minf(1.0, float(n) / 5.0 / 0.8), 1e-12)
	for n: int in [65, 66, 67]:
		var items: Array = [_effect_item("table")]
		for _i: int in n: items.append(_effect_item("record", 0))
		g["dom"]["furnish"]["front"] = {"items": items}
		assert_almost_eq(Decor.decor_parts(g, "front")[4], minf(1.0, float(n) / 66.0), 1e-12)
	for row: Array in [[[], 0.0], [["small_stove", "iron_stove"], 0.5],
			[["oil_lamp", "oil_lamp"], 0.5], [["oil_lamp", "small_stove", "iron_stove"], 1.0]]:
		var items: Array = []
		for kind: String in row[0]: items.append(_effect_item(kind))
		g["dom"]["furnish"]["front"] = {"items": items}
		assert_eq(Decor.decor_parts(g, "front")[5], row[1])


func test_decor80_save_contract() -> void:
	var d: Dictionary = Dom.start()
	assert_true(Dom.is_store(d), "legacy absent")
	d["decor80"] = Decor.DECOR_CARS.duplicate()
	assert_true(Dom.is_store(d))
	for invalid: Variant in [null, {}, "front", 1, ["front", "front"], ["engine"], ["unknown"], [1], ["Front"]]:
		d["decor80"] = invalid
		assert_false(Dom.is_store(d), str(invalid))
	d["decor80"] = []
	d["decor80_extra"] = []
	assert_false(Dom.is_store(d))
	var g: Dictionary = _fresh()
	g["version"] = Save.SAVE_VERSION
	g["dom"]["decor80"] = ["captain", "dining", "tail1"]
	var loaded: Dictionary = Save.read_save(g, TV.tables())
	assert_true(loaded["ok"])
	if loaded["ok"]: assert_eq(loaded["g"]["dom"]["decor80"], ["captain", "dining", "tail1"])
