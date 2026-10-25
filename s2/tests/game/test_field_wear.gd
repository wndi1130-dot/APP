extends "res://addons/gut/test.gd"
## Clothes in fourteen places, in layers (decision 434, wear.gd): warmth, the
## layers against the dead's nails and teeth outside in, wetness from rain and
## sweat, wear, weight; putting them on and taking them off as jobs of the
## hands, a layer under others taking those off and on. What everyone goes out
## in gives what the one coat and the gloves gave.

const Wear = preload("res://game/sim/wear.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const Person = preload("res://game/actors/person.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const GrabRules = preload("res://game/sim/grab_rules.gd")
const BodyState = preload("res://game/sim/body_state.gd")
const Combat = preload("res://game/field_combat.gd")


func _game(extra: Dictionary = {}) -> Node:
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


func _finish(game, p) -> void:
	p.action_t = 0.001
	game._update_person(p, 0.1)


func _lay(game, p, id: String, state: Dictionary = {}) -> int:
	game.ground_items.append({"pos": p.position, "id": id, "n": 1, "garment": state if not state.is_empty() else Wear.make(id)})
	return game.ground_items.size() - 1


func _ids_with(changes: Dictionary) -> Dictionary:
	var out := {}
	for s: String in Wear.SLOTS:
		out[s] = String(Wear.DEFAULT.get(s, ""))
	out.merge(changes, true)
	return out


func test_the_values_are_the_listed_ones() -> void:
	var rows: Array = []
	for id: String in ["jacket_short", "coat_long", "hat_knit", "hood", "gloves"]:
		var k: Dictionary = Wear.KINDS[id]
		rows.append([k["slot"], k["warmth"], k.get("windproof", -1.0), k.get("block", -1.0), k.get("heavy", false), k["stuff"], k["weight"]])
	assert_eq(rows, [
		["jacket", 0.7, 0.5, 0.25, false, "wool", 2.0],
		["coat", 0.9, 0.7, 0.5, true, "wool", 3.0],
		["head", 0.1, -1.0, -1.0, false, "wool", 0.2],
		["head", 0.05, -1.0, -1.0, false, "cotton", 0.3],
		["hands", 0.1, -1.0, -1.0, false, "wool", 0.2]])
	assert_eq(Wear.WET_KEEP, {"wool": 0.5, "cotton": 0.2, "leather": 0.6, "oilcloth": 0.9, "padded": 0.3})
	assert_eq([Wear.TORN_AT, Wear.RAGS_AT], [0.34, 0.67])
	assert_eq([Wear.WORN_WEIGHT_SHARE, Wear.WORN_WARMTH_LOSS, Wear.SWEAT_AT, Wear.SWEAT_RATE, Wear.SWEAT_MOST, Wear.RAIN_WET], [0.3, 0.5, 1.0, 0.004, 0.4, 0.003])
	assert_eq(BodyState.BAREFOOT_MOVE, 0.9)
	assert_eq(Wear.KINDS.size(), 47, "some forty kinds")
	assert_eq(str(LootDress.WEAR_FINDS.slice(0, 5).map(func(r: Array) -> Array: return [r[0], r[1]])),
		str([["coat_long", 0.30], ["jacket_short", 0.20], ["hat_knit", 0.40], ["hood", 0.30], ["gloves", 0.35]]), "the first five as they were")


func test_every_kind_has_its_places_a_picture_and_a_short_name() -> void:
	var shells := ["coat_long", "jacket_short", "hat_knit", "hood"]
	for id: String in Wear.KINDS:
		var k: Dictionary = Wear.KINDS[id]
		for s: String in Wear.slots_of(id):
			assert_true(Wear.SLOTS.has(s), "%s: %s" % [id, s])
		for part: String in Wear.covers(id):
			assert_true(BodyState.PARTS.has(part), "%s covers %s" % [id, part])
		assert_true(HudIcons.PATHS.has(FieldItems.icon(id)), "a picture: " + id)
		assert_true(FieldItems.item_name(id).length() <= 9, "short: " + id)
		assert_true(Wear.WET_KEEP.has(String(k["stuff"])), "made of something known: " + id)
		if bool(k.get("heavy", false)):
			assert_gte(float(k.get("block", 0.0)), GrabRules.HEAVY_COAT_BLOCK, "heavy holds half: " + id)
		var look: Dictionary = Wear.look(id)
		assert_true(["torso_outer", "head", "hands", ""].has(String(look["look_slot"])), id)
		assert_true(String(look["look_shell"]) == "" or shells.has(String(look["look_shell"])), id)
		assert_true(["plain", "check", "knit", "quilt"].has(String(look["look_pattern"])), id)
		if String(look["look_shell"]) != "":
			assert_eq((look["look_tint"] as Array).size(), 3, "a tint for what is drawn: " + id)
	for s: String in Wear.DEFAULT:
		assert_eq(Wear.slot_of(String(Wear.DEFAULT[s])), s)


func test_the_times_are_the_lengths_of_the_motions() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PersonVisual.OWN_FOLDER.path_join("clips.json")))
	var lengths: Dictionary = {}
	for c: Dictionary in info["clips"]:
		lengths[String(c["name"])] = float(c["length"])
	for slot: String in Wear.SLOTS:
		assert_almost_eq(float(Wear.TIME[slot]), float(lengths[Wear.CLIP[slot]]), 0.001, slot)
	for kind: String in PersonVisual.WEAR_TINTS:
		assert_true(FileAccess.file_exists(PersonVisual.OWN_FOLDER.path_join("wear").path_join(kind).path_join("vat.bin")), "a shell for " + kind)


func test_one_new_is_dressed_as_everyone_was() -> void:
	var p := Person.new()
	assert_eq([p.coat["name"], p.coat["warmth"], p.coat["windproof"], p.coat["block"], p.coat["heavy"], float(p.coat["wear"])], ["철도원 외투", 0.7, 0.5, 0.25, false, 0.0])
	assert_true(p.hat.is_empty(), "nothing on the head")
	assert_true(p.gloves)
	assert_almost_eq(Wear.warmth(p, 0.0), 0.8, 0.00001, "the coat and the gloves, as the heat had them")
	assert_eq(Wear.windproof(p), 0.5)
	for part: String in ["torso", "arm_left", "arm_right"]:
		assert_almost_eq(Wear.block(p, part), 0.25, 0.00001, "the coat holds nails as it did: " + part)
		assert_eq(Wear.block(p, part, true), 0.0, "and no teeth")
	for part: String in ["leg_left", "leg_right", "head_neck"]:
		assert_eq(Wear.block(p, part), 0.0, "nothing on the legs holds: " + part)
	assert_eq(Wear.extra_weight(p), 0.0, "no more load than before")
	assert_false(Wear.heavy(p))
	assert_false(Wear.barefoot(p))
	assert_eq(Wear.worn_ids(p), _ids_with({}))
	p.free()


func test_soaked_wool_keeps_half_its_warmth_and_cotton_little() -> void:
	var p := Person.new()
	p.hat = Wear.make("hood")
	assert_almost_eq(Wear.warmth(p, 0.0), 0.85, 0.00001)
	assert_almost_eq(Wear.warmth(p, 1.0), 0.35 + 0.01 + 0.05, 0.00001)
	assert_almost_eq(Wear.warmth(p, 0.5), 0.525 + 0.03 + 0.075, 0.00001)
	p.free()


func test_worn_through_keeps_half_its_warmth() -> void:
	var p := Person.new()
	p.coat["wear"] = 1.0
	assert_almost_eq(Wear.warmth(p, 0.0), 0.35 + 0.1, 0.00001)
	p.coat["wear"] = 0.4
	assert_almost_eq(Wear.warmth(p, 0.0), 0.7 * 0.8 + 0.1, 0.00001)
	p.free()


func test_a_heavy_coat_goes_on_over_the_jacket() -> void:
	var game = _game()
	var p = game.player
	game.zombies.list.clear()
	p.coat["wear"] = 0.4
	var load_before: float = p.weight()
	var i := _lay(game, p, "coat_long")
	game.actions.pick_up(p, i)
	assert_eq(p.action, "wear")
	assert_eq(p.action_busy.get("slot"), "coat")
	assert_almost_eq(p.action_total, 2.4, 0.0001, "nothing over it to take off")
	assert_eq(String(p.coat["id"]), "jacket_short", "not yet")
	_finish(game, p)
	assert_eq(String(p.coat["id"]), "coat_long")
	assert_eq(Wear.worn_ids(p), _ids_with({"coat": "coat_long"}), "the railway coat stays on under it")
	assert_true(Wear.heavy(p))
	assert_true(game.ground_items.filter(func(g: Dictionary) -> bool: return g.has("garment")).is_empty(), "nothing put down")
	assert_almost_eq(Wear.block(p, "arm_left", true), GrabRules.HEAVY_COAT_BLOCK, 0.0001, "it stops bites")
	assert_almost_eq(Wear.block(p, "torso"), 1.0 - 0.5 * (1.0 - 0.25 * 0.6), 0.0001, "both layers in turn")
	assert_almost_eq(Wear.warmth(p, 0.0), 0.9 + 0.7 * 0.8 + 0.1, 0.0001, "warmer, past what the heat takes")
	assert_almost_eq(Wear.windproof(p), 0.7, 0.0001, "the outer one stops the wind")
	assert_almost_eq(Wear.extra_weight(p), 3.0 * Wear.WORN_WEIGHT_SHARE, 0.0001, "and heavier")
	assert_almost_eq(p.weight() - load_before, Wear.extra_weight(p), 0.0001, "on the load")


func test_a_jacket_under_the_coat_takes_the_coat_off_and_on() -> void:
	var game = _game()
	var p = game.player
	game.zombies.list.clear()
	p.coat = Wear.make("coat_long")
	var old: Dictionary = p.worn["jacket"]
	old["wear"] = 0.4
	game.actions.pick_up(p, _lay(game, p, "jacket_plain"))
	assert_almost_eq(p.action_total, 2.4 + 2.0 * 2.4, 0.0001, "the coat off and back on")
	_finish(game, p)
	assert_eq(Wear.worn_ids(p), _ids_with({"jacket": "jacket_plain", "coat": "coat_long"}))
	var down: Array = game.ground_items.filter(func(g: Dictionary) -> bool: return g.has("garment"))
	assert_eq(down.size(), 1)
	assert_eq(String(down[0]["id"]), "jacket_short")
	assert_almost_eq(float(down[0]["garment"]["wear"]), 0.4, 0.0001, "put down as it was")
	assert_almost_eq(Wear.dress_time(p, "shirt_flannel"), 2.4 + 2.0 * 2.4 + 2.0 * 2.4, 0.0001, "a shirt: the jacket and the coat off and on")
	assert_almost_eq(Wear.undress_time(p, "shirt"), 2.4 + 2.0 * 2.4 + 2.0 * 2.4, 0.0001)
	assert_almost_eq(Wear.dress_time(p, "sweater_wool"), 2.4 + 2.0 * 2.4 + 2.0 * 2.4, 0.0001, "an empty place under them too")
	assert_almost_eq(Wear.dress_time(p, "hat_knit"), 1.4, 0.0001, "the head has no stack")


func test_a_whole_suit_takes_two_places() -> void:
	var p := Person.new()
	assert_almost_eq(Wear.dress_time(p, "coverall"), 2.4 + 2.4 + 2.0 * 2.4, 0.0001, "the trousers aside, the jacket off and on")
	var off: Array = Wear.put_on(p, Wear.make("coverall"))
	assert_eq(off.map(func(g: Dictionary) -> String: return String(g["id"])), ["shirt_cotton", "trousers_cotton"])
	assert_eq(String(Wear.occupant(p, "trousers").get("id", "")), "coverall")
	assert_eq(Wear.worn_ids(p)["trousers"], "", "shown in its own place only")
	assert_almost_eq(Wear.block(p, "leg_left"), 0.15, 0.0001, "it covers the legs")
	var back: Array = Wear.put_on(p, Wear.make("trousers_wool"))
	assert_eq(back.map(func(g: Dictionary) -> String: return String(g["id"])), ["coverall"], "trousers put the suit aside")
	assert_true(Wear.occupant(p, "shirt").is_empty(), "the shirt place is bare")
	p.free()


func test_nails_meet_the_layers_outside_in() -> void:
	var p := Person.new()
	p.coat = Wear.make("coat_long")
	assert_eq(Wear.tear(p, "torso", true), "두꺼운 겉옷", "the outer one held")
	assert_almost_eq(float(p.worn["coat"]["wear"]), GrabRules.COAT_BLOCK_WEAR, 0.0001)
	assert_true((p.worn["coat"]["holes"] as Dictionary).has("torso"))
	assert_false(p.worn["jacket"].has("holes"), "what is under it is untouched")
	assert_eq(Wear.tear(p, "arm_left", false), "", "got through")
	for s: String in ["coat", "jacket", "hands", "shirt"]:
		assert_almost_eq(float(p.worn[s]["wear"]), GrabRules.COAT_HIT_WEAR + (GrabRules.COAT_BLOCK_WEAR if s == "coat" else 0.0), 0.0001, s)
		assert_true((p.worn[s]["holes"] as Dictionary).has("arm_left"), s)
	assert_false(p.worn["under_top"].has("holes"), "the vest under it has no sleeves")
	assert_eq(Wear.block(p, "arm_left"), 0.0, "holed all through")
	var q := Person.new()
	q.worn.erase("jacket")
	q.worn["hands"] = Wear.make("gloves_leather")
	assert_almost_eq(Wear.block(q, "arm_right", true), 0.2, 0.0001, "leather gloves hold some teeth")
	assert_eq(Wear.tear(q, "arm_right", true, true), "가죽 장갑")
	p.free()
	q.free()


func test_the_legs_are_covered_now() -> void:
	var p := Person.new()
	Wear.put_on(p, Wear.make("trousers_work"))
	Wear.put_on(p, Wear.make("boots_work"))
	assert_almost_eq(Wear.block(p, "leg_left"), 1.0 - 0.9 * 0.8, 0.0001, "work trousers and boots")
	assert_almost_eq(Wear.block(p, "leg_right", true), 0.2, 0.0001, "the boots hold some teeth")
	assert_eq(Wear.block(p, "torso", true), 0.0)
	p.free()


func test_a_nail_on_a_layer_shows_its_name() -> void:
	var game = _game()
	var c = game.combat
	assert_eq(c._held_line(""), "외투가 손톱을 막았다.")
	assert_eq(c._held_line("철도원 외투"), "외투가 손톱을 막았다.", "as it always said")
	assert_eq(c._held_line("두꺼운 겉옷"), "두꺼운 겉옷이 손톱을 막았다.")
	assert_eq(c._held_line("가죽 장갑"), "가죽 장갑이 손톱을 막았다.")
	assert_eq(c._held_line("작업화"), "작업화가 손톱을 막았다.")


func test_dressed_warm_sweats_at_work_and_rain_soaks_less_under_oilcloth() -> void:
	var p := Person.new()
	assert_eq(Wear.wet_gain(p, 1.0, false, true), 0.0, "as everyone goes out, no sweat")
	assert_almost_eq(Wear.wet_gain(p, 1.0, true, false), Wear.RAIN_WET, 0.000001, "the rain")
	p.coat = Wear.make("raincoat")
	assert_almost_eq(Wear.wet_gain(p, 1.0, true, false), Wear.RAIN_WET * 0.1, 0.000001, "the raincoat keeps most of it off")
	p.coat = Wear.make("coat_long")
	assert_gt(Wear.warmth(p, 0.0), Wear.SWEAT_AT)
	assert_almost_eq(Wear.wet_gain(p, 1.0, false, true), Wear.SWEAT_RATE, 0.000001, "warm at work sweats")
	assert_eq(Wear.wet_gain(p, 1.0, false, false), 0.0, "standing still does not")
	p.heat.wet = Wear.SWEAT_MOST - 0.001
	assert_almost_eq(Wear.wet_gain(p, 1.0, false, true), 0.001, 0.000001, "never past its line")
	assert_lt(Wear.SWEAT_MOST, 0.5, "sweat alone adds no load (carry.gd soaked line)")
	p.free()


func test_rain_soaks_out_of_doors_through_the_game() -> void:
	var game = _game()
	var p = game.player
	game.zombies.list.clear()
	game.weather.kinds = ["sleet"] as Array[String]
	var before: float = p.heat.wet
	game._update_person(p, 1.0)
	var lg = game.grid_at(p.position)
	if lg.indoor(FieldGame.FieldGrid.cell_of(p.position)):
		pass_test("starts indoors on this map")
		return
	assert_gt(p.heat.wet, before, "sleet soaks one standing outside")


func test_barefoot_walks_slower() -> void:
	var p := Person.new()
	var shod: float = float(p.mults()["move"])
	Wear.take_off(p, "shoes")
	assert_true(Wear.barefoot(p))
	assert_almost_eq(float(p.mults()["move"]), shod * BodyState.BAREFOOT_MOVE, 0.0001)
	p.free()


func test_the_head_and_the_hands_have_their_own_motions() -> void:
	var game = _game()
	var p = game.player
	game.zombies.list.clear()
	game.actions.pick_up(p, _lay(game, p, "hat_knit"))
	assert_almost_eq(p.action_total, 1.4, 0.0001)
	_finish(game, p)
	assert_eq(String(p.hat["id"]), "hat_knit")
	assert_almost_eq(Wear.warmth(p, 0.0), 0.9, 0.00001)
	game.actions.undress(p, "hands")
	assert_almost_eq(p.action_total, 1.8, 0.0001)
	_finish(game, p)
	assert_false(p.gloves)
	assert_eq(Wear.worn_ids(p)["hands"], "")


func test_taking_one_off_leaves_it_as_it_is_and_putting_it_back_mends_nothing() -> void:
	var game = _game()
	var p = game.player
	game.zombies.list.clear()
	Wear.tear(p, "arm_left", false)
	var before := Wear.warmth(p, 0.0)
	game.actions.undress(p, "jacket")
	assert_eq(p.action, "wear")
	assert_true(bool(p.action_busy.get("off", false)))
	_finish(game, p)
	assert_eq(String(p.coat["id"]), "", "nothing over the arms")
	assert_eq(Wear.block(p, "torso"), 0.0)
	assert_lt(Wear.warmth(p, 0.0), before)
	var i: int = game.ground_items.size() - 1
	assert_eq(String(game.ground_items[i]["id"]), "jacket_short")
	game.actions.pick_up(p, i)
	_finish(game, p)
	assert_almost_eq(float(p.coat["wear"]), GrabRules.COAT_HIT_WEAR, 0.0001)
	assert_true((p.coat["holes"] as Dictionary).has("arm_left"), "the hole is still there")


func test_a_box_gives_a_garment_to_put_on_and_take_all_leaves_it() -> void:
	var game = _game()
	var p = game.player
	game.zombies.list.clear()
	var box := ""
	for id: String in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if int(c.get("level", 0)) == 0 and not c.get("locked", false) and not c.has("pick"):
			box = id
			break
	assert_ne(box, "")
	var c: Dictionary = game.data["containers"][box]
	c["items"] = ["coat_long", "food_pack"]
	c["searched"] = true
	p.position = game.lift(c["cell"], 0)
	game.actions.take_all(p, box)
	assert_eq(c["items"], ["coat_long"], "the coat stays in the box")
	game.actions.take(p, box, 0)
	assert_eq(c["items"], [])
	assert_eq(p.action, "wear")
	_finish(game, p)
	assert_eq(String(p.coat["id"]), "coat_long")
	assert_false(p.items.has("coat_long"), "never in the bag")


func test_a_companion_leaves_clothes_in_the_box() -> void:
	var game = _game()
	var q = game.squad[1]
	var c := {"items": ["hat_knit", "food_pack"], "searched": true}
	game.actions._companion_take(q, c)
	assert_eq(c["items"], ["hat_knit"])


func test_a_blow_or_the_stick_cuts_dressing_short() -> void:
	assert_true(FieldGame.STICK_BREAKS.has("wear"))
	assert_true(Combat.BLOW_BREAKS.has("wear"))


func test_the_save_keeps_what_is_worn() -> void:
	var game = _game()
	var p = game.player
	p.hat = Wear.make("hood")
	p.gloves = false
	Wear.put_on(p, Wear.make("coverall"))
	Wear.tear(p, "torso", true)
	var d: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	assert_false(d.is_empty())
	var row: Dictionary = (d["people"] as Array).filter(func(r: Dictionary) -> bool: return String(r["pid"]) == String(p.pid))[0]
	var q := Person.new()
	Wear.restore(q, row["wear"])
	assert_eq(Wear.worn_ids(q), _ids_with({"head": "hood", "hands": "", "shirt": "coverall", "trousers": ""}))
	assert_almost_eq(float(q.coat["wear"]), GrabRules.COAT_BLOCK_WEAR, 0.0001)
	assert_eq(String(Wear.occupant(q, "trousers").get("id", "")), "coverall")
	# A save of the three places (#594): the coat it had, over the plain cotton.
	var r := Person.new()
	var long_one := Wear.make("coat_long")
	long_one["wear"] = 0.2
	Wear.restore(r, {"outer": long_one, "head": {}, "hands": true})
	assert_eq(Wear.worn_ids(r), _ids_with({"jacket": "", "coat": "coat_long"}))
	assert_almost_eq(float(r.coat["wear"]), 0.2, 0.0001)
	# One from before: they keep what everyone wears.
	var s := Person.new()
	Wear.restore(s, {})
	assert_eq(Wear.worn_ids(s), _ids_with({}))
	q.free()
	r.free()
	s.free()


func test_a_squad_row_may_say_what_they_wear() -> void:
	var p := Person.new()
	Wear.dress_from(p, {"coat": "raincoat", "head": "hat_earflap", "socks": ""})
	assert_eq(Wear.worn_ids(p), _ids_with({"coat": "raincoat", "head": "hat_earflap", "socks": ""}))
	Wear.dress_from(p, {"outer": "", "hands": false})
	assert_eq(String(p.coat["id"]), "", "the old way still clears the body")
	assert_false(p.gloves)
	p.free()


func test_clothes_lie_in_lived_in_rooms_on_their_own_dice() -> void:
	var base: Dictionary = FieldMaps.build("houses_02")
	var found := 0
	var kinds := {}
	var allowed: Dictionary = {}
	for row: Array in LootDress.WEAR_FINDS:
		allowed[row[0]] = row
		assert_true(Wear.is_garment(String(row[0])), String(row[0]))
		assert_false(Wear.DEFAULT.values().has(row[0]) and row[0] != "jacket_short" and row[0] != "gloves", "what everyone wears is not left lying: %s" % row[0])
	for seed in range(1, 7):
		var data: Dictionary = base.duplicate(true)
		var report: Dictionary = LootDress.dress(data, seed)
		for f: Array in report["finds"]:
			if not Wear.is_garment(String(f[0])):
				continue
			found += 1
			kinds[f[0]] = true
			var c: Dictionary = data["containers"][f[1]]
			var rule: Array = allowed[f[0]]
			var rooms: Array = rule[2]
			assert_true(rooms.is_empty() or rooms.has(LootDress.room_of(c)), "%s in %s" % [f[0], f[1]])
			assert_true((rule[3] as Array).has(LootDress._building_kind_of(data.get("buildings", []), c)), "%s in %s" % [f[0], f[1]])
	assert_gt(found, 0)
	assert_gt(kinds.size(), 5, "more than the five of before turn up")


func test_the_looks_drawn_are_what_is_worn_and_off_plays_backwards() -> void:
	var p := Person.new()
	assert_eq(PersonVisual.looks_of(p), ["jacket_short"] as Array[String])
	p.hat = Wear.make("hat_knit")
	p.coat = Wear.make("coat_long")
	assert_eq(PersonVisual.looks_of(p), ["coat_long", "hat_knit"] as Array[String])
	p.coat = Wear.make("vest_armor")
	assert_eq(PersonVisual.looks_of(p), ["jacket_short", "hat_knit"] as Array[String], "a vest with no shell shows the jacket under it")
	p.hat = Wear.make("cap_brim")
	assert_eq(Wear.look("cap_brim")["look_slot"], "head")
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PersonVisual.OWN_FOLDER.path_join("clips.json")))
	var clips: Array = info["clips"]
	p.action = "wear"
	p.action_total = 1.4
	p.action_t = 1.05
	p.action_busy = {"slot": "head", "off": false}
	var on: Vector2 = PersonVisual.wear_of(p, {}, clips)
	assert_eq(String(clips[int(on.y)]["name"]), "p_wear_head")
	assert_almost_eq(on.x, 0.25, 0.0001)
	p.action_busy = {"slot": "head", "off": true}
	assert_almost_eq(PersonVisual.wear_of(p, {}, clips).x, 0.75, 0.0001, "taking it off is putting it on backwards")
	p.action_busy = {"slot": "shoes", "off": false}
	assert_eq(String(clips[int(PersonVisual.wear_of(p, {}, clips).y)]["name"]), "p_wear_outer", "a place with no motion of its own borrows one")
	p.free()
