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
const LootRules = preload("res://game/sim/loot_rules.gd")
const LootTables = preload("res://game/sim/loot_tables.gd")
const W = preload("res://game/sim/weapons.gd")
const AimModel = preload("res://game/sim/aim_model.gd")


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


## Every step of a change of clothes.
func _finish_all(game, p) -> void:
	for i in range(20):
		if p.action == "":
			return
		_finish(game, p)


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
	game.actions.pick_up(p, _lay(game, p, "jacket_plain"), true)
	assert_almost_eq(Wear.plan_time(Wear.dress_plan(p, "jacket_plain")), 2.4 + 2.0 * 2.4, 0.0001, "the coat off and back on")
	assert_almost_eq(p.action_total, 2.4, 0.0001, "a step at a time")
	_finish_all(game, p)
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


# ---------------------------------------------------------------- PR C

func _clips() -> Array:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PersonVisual.OWN_FOLDER.path_join("clips.json")))
	return info["clips"]


func _garments_down(game) -> Array:
	var out: Array = []
	for g: Dictionary in game.ground_items:
		if g.has("garment"):
			out.append(String(g["id"]))
	out.sort()
	return out


func test_the_new_values_are_the_listed_ones() -> void:
	assert_eq(Wear.KINDS["vest_armor"]["bullet"], 1.0, "the vest alone")
	for id: String in Wear.KINDS:
		if id != "vest_armor":
			assert_false(Wear.KINDS[id].has("bullet"), "no other garment stops a round: " + id)
	assert_eq(Wear.WALKABLE, ["head", "neck", "face", "hands"] as Array[String])
	assert_eq([Wear.BROKEN_AT, Wear.STRIP_PER_WEIGHT, Wear.STRIP_WEIGHT_LEAST, Wear.STRIP_WEIGHT_MOST, Wear.SHOT_HOLE_LEAST, Wear.SHOT_HOLE_BITE], [1.0, 2.4, 0.5, 3.0, 0.3, 1.5])
	assert_eq(LootTables.WEAR_WORN, {"dead": [0.25, 0.75], "frozen": [0.25, 0.75], "clothed": [0.2, 0.6], "fresh": [0.05, 0.35]})
	assert_eq(LootTables.WEAR_HOLES, {"dead": 0.2, "frozen": 0.2, "clothed": 0.15, "fresh": 0.1})
	assert_eq(LootTables.WEAR_PLACE["police"]["coat"], [["vest_armor", 2], ["", 1]])
	assert_eq(LootTables.WEAR_PLACE["fire"]["coat"], [["fire_suit", 2], ["coat_long", 1]])


func test_the_vest_alone_stops_a_pistol_round() -> void:
	var p := Person.new()
	assert_eq(Wear.bullet_block_in(p.worn, "torso"), 0.0, "what everyone wears stops none")
	p.coat = Wear.make("coat_long")
	assert_eq(Wear.bullet_block_in(p.worn, "torso"), 0.0, "a thick coat stops blades and teeth, never a round")
	p.coat = Wear.make("vest_armor")
	assert_eq(Wear.bullet_block_in(p.worn, "torso"), 1.0)
	assert_eq(Wear.bullet_block_in(p.worn, "arm_left"), 0.0, "it leaves the arms bare")
	assert_eq(Wear.bullet_block_in(p.worn, "leg_left"), 0.0)
	p.worn["coat"]["wear"] = 0.4
	assert_almost_eq(Wear.bullet_block_in(p.worn, "torso"), 0.6, 0.0001, "less as it wears")
	p.worn["coat"]["wear"] = 0.0
	# Stopped: the vest holds, a little worn; holed there as often as its teeth say.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var copy := RandomNumberGenerator.new()
	copy.seed = 7
	assert_eq(Wear.shot_in(p.worn, "torso", true, rng), "방탄조끼")
	assert_almost_eq(float(p.worn["coat"]["wear"]), GrabRules.COAT_BLOCK_WEAR, 0.0001)
	var holed: bool = copy.randf() < maxf(Wear.SHOT_HOLE_LEAST, 1.0 - 0.5 / Wear.SHOT_HOLE_BITE)
	assert_eq((p.worn["coat"].get("holes", {}) as Dictionary).has("torso"), holed)
	assert_false(p.worn["jacket"].has("holes"), "what is under it is untouched")
	# Holed there, the next round goes through, holing every layer.
	p.worn["coat"]["holes"] = {"torso": true}
	assert_eq(Wear.bullet_block_in(p.worn, "torso"), 0.0)
	assert_eq(Wear.shot_in(p.worn, "torso", false, rng), "")
	for s: String in ["coat", "jacket", "shirt", "under_top"]:
		assert_true((p.worn[s]["holes"] as Dictionary).has("torso"), s)
	assert_almost_eq(float(p.worn["jacket"]["wear"]), GrabRules.COAT_HIT_WEAR, 0.0001)
	p.free()


func test_a_pistol_round_on_a_vest_leaves_no_wound_and_shot_does() -> void:
	var game = _game()
	game.zombies.list.clear()
	var o = game.squad[1]
	var r = game.make_person({"id": "r_test", "name": "약탈자", "role": "raider"}, o.position + Vector3(4, 0, 0))
	var stopped := 0
	var torso_shot := 0
	for gun: String in ["pistol", "shotgun"]:
		r.set_weapon_slots([{"id": gun, "quality": "factory", "condition": 1.0, "loaded": 8}])
		for s in range(1, 81):
			game.rng.seed = s
			o.body.wounds.clear()
			o.body._refresh()
			o.body.downed = false
			o.coat = Wear.make("vest_armor")
			if not game.combat._shoot_person(r, o, AimModel.BODY_R):
				continue
			var torso: bool = o.body.wounds.any(func(w: Dictionary) -> bool: return String(w["part"]) == "torso")
			if gun == "pistol":
				assert_false(torso, "a pistol round on the body does not get through a whole vest (seed %d)" % s)
				if o.body.wounds.is_empty():
					stopped += 1
					assert_almost_eq(float(o.worn["coat"]["wear"]), GrabRules.COAT_BLOCK_WEAR, 0.0001)
			elif torso:
				torso_shot += 1
	assert_gt(stopped, 0, "some rounds land on the vest")
	assert_gt(torso_shot, 0, "the vest is no help against shot")


func test_a_vest_on_one_of_the_dead_stops_a_pistol_round_on_the_body() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	var d: Dictionary = W.get_data("pistol")
	var held := 0
	for s in range(1, 61):
		var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(5, 0, 0))
		z["worn"] = {"coat": Wear.make("vest_armor")}
		game.rng.seed = s
		if not game.combat._shoot_zombie(p, z, d, AimModel.BODY_R, 5.0):
			continue
		var vest: Dictionary = z["worn"]["coat"]
		if float(vest["wear"]) > 0.0:
			held += 1
			assert_almost_eq(float(z["stun"]), 0.3, 0.0001, "it only staggers")
			assert_eq(z["state"], "wander", "not knocked down")
		else:
			assert_ne(float(z.get("stun", 0.0)), 0.5, "a round on the body never goes through a whole vest")
	assert_gt(held, 0)
	var shotgun: Dictionary = W.get_data("shotgun")
	assert_ne(String(shotgun.get("ammo", "")), "pistol", "shot is not stopped: it takes the pellets' way")


func test_the_dead_are_dressed_by_where_they_stood() -> void:
	var vests := 0
	var suits := 0
	for s in range(1, 61):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var plain: Dictionary = LootRules.wear_roll("dead", "", rng)
		_check_outfit(plain, LootTables.WEAR_WORN["dead"])
		assert_true(plain.has("under_top") and plain.has("shirt") and plain.has("trousers") and plain.has("socks"), "plain winter clothes on every one")
		assert_false(plain.has("coat") and String(plain["coat"]["id"]) == "vest_armor", "no vest away from the police station")
		var police: Dictionary = LootRules.wear_roll("dead", "police", rng)
		_check_outfit(police, LootTables.WEAR_WORN["dead"])
		if police.has("coat") and String(police["coat"]["id"]) == "vest_armor":
			vests += 1
			assert_true(police.has("jacket") or police.has("sweater") or police.has("shirt"), "over plain winter clothes")
		var fire: Dictionary = LootRules.wear_roll("clothed", "fire", rng)
		_check_outfit(fire, LootTables.WEAR_WORN["clothed"])
		if fire.has("coat") and String(fire["coat"]["id"]) == "fire_suit":
			suits += 1
			assert_false(fire.has("overtrousers"), "the suit takes that place with it")
	assert_between(vests, 30, 50, "about two in three by the police station")
	assert_between(suits, 30, 50, "about two in three at the fire station")
	var buildings: Array = [{"name": "경찰서", "rect": Rect2i(10, 10, 10, 10)}, {"name": "소방 차고", "rect": Rect2i(40, 10, 10, 10)}]
	assert_eq(LootRules.wear_place_at(buildings, Vector2i(12, 12)), "police")
	assert_eq(LootRules.wear_place_at(buildings, Vector2i(42, 12)), "fire")
	assert_eq(LootRules.place_at(buildings, Vector2i(42, 12)), "workshop", "the pockets keep their own place")


func _check_outfit(worn: Dictionary, worn_range: Array) -> void:
	var places: Array = []
	for slot: String in worn:
		var g: Dictionary = worn[slot]
		var id: String = String(g["id"])
		assert_true(Wear.is_garment(id), id)
		assert_eq(Wear.slot_of(id), slot, id)
		assert_between(float(g["wear"]), float(worn_range[0]) - 0.005, float(worn_range[1]) + 0.005, id)
		for part: String in (g.get("holes", {}) as Dictionary):
			assert_true(Wear.covers(id).has(part), "%s holed where it covers" % id)
		for s: String in Wear.slots_of(id):
			assert_false(places.has(s), "one to a place: " + s)
			places.append(s)


func test_what_the_dead_wear_is_rolled_the_same_whenever_it_is_asked() -> void:
	var game = _game()
	var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(6, 0, 0))
	var first: String = str(game.zombies.worn_of(z))
	z.erase("worn")
	game.rng.randf()
	assert_eq(str(game.zombies.worn_of(z)), first, "its own dice")
	z["state"] = "wander"
	assert_false(game.zombies.strippable(z), "standing, nothing comes off it")
	z["state"] = "dead"
	assert_true(game.zombies.strippable(z))


func test_a_coat_comes_off_one_of_the_dead_as_it_is() -> void:
	var game = _game()
	var p = game.player
	game.zombies.list.clear()
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	z["state"] = "dead"
	var coat := Wear.make("coat_long")
	coat["wear"] = 0.5
	coat["holes"] = {"torso": true}
	z["worn"] = {"coat": coat, "hands": Wear.make("mittens")}
	var far: Dictionary = game.zombies.spawn("dead", p.position + Vector3(6, 0, 0))
	far["state"] = "dead"
	far["worn"] = {"coat": Wear.make("coat_long")}
	game.actions.strip_body(p, int(far["id"]), "coat")
	assert_eq(p.action, "", "out of reach nothing starts")
	game.actions.strip_body(p, int(z["id"]), "coat")
	assert_eq(p.action, "loot", "kneeling at it, as for its pockets")
	assert_almost_eq(p.action_total, Wear.STRIP_PER_WEIGHT * 3.0, 0.0001, "as long as it is heavy")
	_finish(game, p)
	assert_eq(_garments_down(game), ["coat_long"])
	var down: Dictionary = game.ground_items.filter(func(g: Dictionary) -> bool: return g.has("garment"))[0]
	assert_almost_eq(float(down["garment"]["wear"]), 0.5, 0.0001, "as worn as it was")
	assert_true((down["garment"]["holes"] as Dictionary).has("torso"), "and holed")
	assert_false(z["worn"].has("coat"))
	assert_true(bool(z.get("stripped", false)))
	assert_almost_eq(Wear.strip_time("mittens"), Wear.STRIP_PER_WEIGHT * Wear.STRIP_WEIGHT_LEAST, 0.0001, "a light one takes the least")
	# Up again meanwhile: the hands come away empty.
	game.actions.strip_body(p, int(z["id"]), "hands")
	z["state"] = "wander"
	_finish(game, p)
	assert_true(z["worn"].has("hands"))
	# Nor from one left behind meanwhile.
	z["state"] = "dead"
	game.actions.strip_body(p, int(z["id"]), "hands")
	assert_eq(p.action, "loot")
	z["pos"] = p.position + Vector3(6, 0, 0)
	_finish(game, p)
	assert_true(z["worn"].has("hands"), "out of reach by the end, nothing comes away")


func test_one_of_ours_gets_up_in_what_it_wore() -> void:
	var game = _game()
	var q = game.squad[1]
	q.hat = Wear.make("hat_earflap")
	game.on_person_died(q)
	var z: Dictionary = game.zombies.list[game.zombies.list.size() - 1]
	assert_eq(String(z["worn"]["head"]["id"]), "hat_earflap")
	assert_true(game.zombies.strippable(z), "lying there it can be stripped")


func test_a_shirt_under_two_layers_goes_on_in_steps_and_a_cut_keeps_what_was_done() -> void:
	var game = _game()
	var p = game.player
	game.zombies.list.clear()
	p.coat = Wear.make("coat_long")
	var plan: Array = Wear.dress_plan(p, "shirt_flannel")
	assert_eq(plan.map(func(s: Dictionary) -> String: return "%s:%s" % [s["op"], s["slot"]]), ["off:coat", "off:jacket", "on:shirt", "back:jacket", "back:coat"])
	assert_almost_eq(Wear.plan_time(plan), Wear.dress_time(p, "shirt_flannel"), 0.0001, "the steps add up as before")
	assert_almost_eq(Wear.plan_time(Wear.undress_plan(p, "shirt")), Wear.undress_time(p, "shirt"), 0.0001)
	assert_eq(Wear.dress_plan(p, "coverall").map(func(s: Dictionary) -> String: return "%s:%s" % [s["op"], s["slot"]]), ["off:coat", "off:jacket", "aside:trousers", "on:shirt", "back:jacket", "back:coat"])
	game.actions.pick_up(p, _lay(game, p, "shirt_flannel"), true)
	assert_eq([p.action_busy["slot"], p.action_busy["off"]], ["coat", true])
	_finish(game, p)
	assert_eq(Wear.worn_ids(p)["coat"], "", "the coat is off")
	assert_eq([p.action_busy["slot"], p.action_busy["off"]], ["jacket", true])
	_finish(game, p)
	assert_eq([p.action_busy["slot"], p.action_busy["off"]], ["shirt", false])
	p.stick = Vector2(1, 0)
	game._update_person(p, 0.1)
	p.stick = Vector2.ZERO
	assert_eq(p.action, "", "the stick cut it")
	game._update_person(p, 0.1)
	assert_true(game.actions.wear_chains.is_empty())
	assert_eq(Wear.worn_ids(p)["shirt"], "shirt_cotton", "not changed yet")
	assert_eq(_garments_down(game), ["coat_long", "jacket_short", "shirt_flannel"], "what was taken off lies at the feet")
	# Done whole, it all goes back on.
	var game2 = _game()
	var p2 = game2.player
	game2.zombies.list.clear()
	p2.coat = Wear.make("coat_long")
	game2.actions.pick_up(p2, _lay(game2, p2, "shirt_flannel"), true)
	_finish_all(game2, p2)
	assert_eq(Wear.worn_ids(p2), _ids_with({"shirt": "shirt_flannel", "coat": "coat_long"}))
	assert_eq(_garments_down(game2), ["shirt_cotton"])


func test_the_change_is_shown_before_it_is_done() -> void:
	var game = _game()
	var p = game.player
	game.zombies.list.clear()
	p.coat = Wear.make("coat_long")
	var i := _lay(game, p, "sweater_wool")
	game.actions.pick_up(p, i)
	assert_eq(p.action, "", "not yet")
	assert_not_null(game.hud.modal, "the steps and the seconds are up")
	game.hud._wear_go({"ground": game.ground_items[i], "id": "sweater_wool"})
	assert_eq(p.action, "wear")
	assert_eq(p.action_busy["slot"], "coat", "the coat comes off first")
	# One with nothing over it goes on at once.
	var game2 = _game()
	game2.zombies.list.clear()
	game2.actions.pick_up(game2.player, _lay(game2, game2.player, "hat_knit"))
	assert_eq(game2.player.action, "wear")


func test_a_hat_goes_on_at_a_walk_and_a_jacket_does_not() -> void:
	var game = _game()
	var p = game.player
	game.zombies.list.clear()
	game.actions.pick_up(p, _lay(game, p, "hat_knit"))
	assert_true(game.actions.walk_work(p))
	p.stick = Vector2(1, 0)
	game._update_person(p, 0.05)
	game._update_person(p, 0.05)
	assert_eq(p.action, "wear", "walking does not cut it")
	assert_gt(p.drive_speed, 0.0, "and the feet go on")
	p.moving = true
	assert_eq(PersonVisual.wear_of(p, {}, _clips()).y, -1.0, "the walk shows")
	p.running = true
	p.stick = Vector2.ZERO
	game._update_person(p, 0.05)
	assert_eq(p.action, "wear", "the run key on, standing still: it goes on")
	p.stick = Vector2(0.2, 0)
	game._update_person(p, 0.05)
	assert_eq(p.action, "", "a run cuts it, however light the push")
	p.running = false
	p.stick = Vector2.ZERO
	p.drive_speed = 0.0
	game._update_person(p, 0.05)
	game.actions.undress(p, "jacket")
	assert_eq(p.action, "wear")
	assert_false(game.actions.walk_work(p))
	p.stick = Vector2(1, 0)
	game._update_person(p, 0.05)
	assert_eq(p.action, "", "a jacket stops at a walk")


func test_rags_are_not_put_on() -> void:
	var game = _game()
	var p = game.player
	game.zombies.list.clear()
	var g := Wear.make("hat_knit")
	g["wear"] = 1.0
	assert_false(Wear.wearable(g))
	game.actions.pick_up(p, _lay(game, p, "hat_knit", g))
	assert_eq(p.action, "")
	assert_true(p.hat.is_empty())


func test_clothes_taken_off_by_the_train_go_aboard() -> void:
	var game = _game()
	var p = game.player
	game.zombies.list.clear()
	var rect: Rect2i = game.data["unloading"][0]
	p.position = game.lift(rect.position, 0)
	game.actions.undress(p, "jacket")
	_finish(game, p)
	game.actions._load_garments()
	assert_eq(_garments_down(game), [], "not left lying by the train")
	assert_eq(game.loaded_wear.size(), 1)
	assert_eq(String(game.loaded_wear[0]["id"]), "jacket_short")
	# A layer off for a while stays until it goes back on.
	p.hat = Wear.make("hat_knit")
	Wear.put_on(p, Wear.make("jacket_plain"))
	p.coat = Wear.make("coat_long")
	game.actions.pick_up(p, _lay(game, p, "shirt_flannel"), true)
	_finish(game, p)
	game.actions._load_garments()
	assert_eq(_garments_down(game), ["coat_long", "shirt_flannel"], "held by the change under way")
	p.cancel_action()
	game._update_person(p, 0.05)
	game.actions._load_garments()
	assert_eq(_garments_down(game), [], "cut short, it goes aboard too")
	assert_eq(game.loaded_wear.size(), 3)


func test_the_save_keeps_the_dead_clothes_and_what_went_aboard() -> void:
	var game = _game()
	var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(3, 0, 0))
	var worn: Dictionary = game.zombies.worn_of(z)
	worn["shirt"]["wear"] = 0.9
	z["stripped"] = true
	game.loaded_wear.append(Wear.make("hood"))
	var d: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	var row: Dictionary = (d["zombies"] as Array).filter(func(r: Dictionary) -> bool: return int(r["id"]) == int(z["id"]))[0]
	assert_almost_eq(float(row["worn"]["shirt"]["wear"]), 0.9, 0.0001)
	assert_eq(String(d["loaded_wear"][0]["id"]), "hood")
	FieldSave._put_zombies(game, d["zombies"])
	var back: Dictionary = game.zombies.find(int(z["id"]))
	assert_almost_eq(float(back["worn"]["shirt"]["wear"]), 0.9, 0.0001)
	assert_true(bool(back["stripped"]))


func test_one_of_the_dead_not_yet_looked_at_keeps_where_it_kept_to_through_a_save() -> void:
	var game = _game()
	game.zombies.list.clear()
	var at: Vector3 = game.player.position + Vector3(3, 0, 0)
	var cell: Vector2i = FieldGame.FieldGrid.cell_of(at)
	game.data["buildings"] = (game.data.get("buildings", []) as Array) + [{"name": "경찰서", "rect": Rect2i(cell - Vector2i(1, 1), Vector2i(3, 3))}]
	var z: Dictionary = game.zombies.spawn("dead", at)
	var there: String = str(game.zombies.worn_of(z.duplicate()))
	var away: Dictionary = z.duplicate()
	away["home"] = at + Vector3(40, 0, 0)
	assert_ne(str(game.zombies.worn_of(away)), there, "the place tells (else this proves nothing)")
	z["pos"] = at + Vector3(40, 0, 0)
	var d: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	FieldSave._put_zombies(game, d["zombies"])
	var back: Dictionary = game.zombies.find(int(z["id"]))
	assert_false(back.has("worn"), "not rolled before")
	assert_eq(str(game.zombies.worn_of(back)), there, "dressed by where it kept to, not where it lay")


func test_a_wound_or_a_round_on_the_vest_cuts_a_change_short() -> void:
	var game = _game()
	game.zombies.list.clear()
	var o = game.squad[1]
	var r = game.make_person({"id": "r_test", "name": "약탈자", "role": "raider"}, o.position + Vector3(4, 0, 0))
	r.set_weapon_slots([{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 8}])
	var held := 0
	var hurt := 0
	for s in range(1, 81):
		o.body.wounds.clear()
		o.body._refresh()
		o.body.downed = false
		o.body.injured_at = -INF
		o.coat = Wear.make("vest_armor")
		game.actions.pick_up(o, _lay(game, o, "trousers_wool"), true)
		assert_eq(o.action, "wear")
		game.rng.seed = s
		if not game.combat._shoot_person(r, o, AimModel.BODY_R):
			o.cancel_action()
			game._update_person(o, 0.0)
			continue
		game._update_person(o, 0.0)
		assert_eq(o.action, "", "cut short (seed %d)" % s)
		assert_false(game.actions.wear_chains.has(o.get_instance_id()))
		if o.body.wounds.is_empty():
			held += 1
		else:
			hurt += 1
	assert_gt(held, 0, "a round the vest stopped")
	assert_gt(hurt, 0, "a round that went in")


func test_rags_over_it_come_off_and_stay_down() -> void:
	var game = _game()
	var p = game.player
	game.zombies.list.clear()
	p.coat = Wear.make("coat_long")
	p.worn["coat"]["wear"] = 1.0
	var steps := func(plan: Array) -> Array: return plan.map(func(s: Dictionary) -> String: return "%s:%s" % [s["op"], s["slot"]])
	assert_eq(steps.call(Wear.dress_plan(p, "shirt_flannel")), ["aside:coat", "off:jacket", "on:shirt", "back:jacket"], "not put back on")
	assert_almost_eq(Wear.dress_time(p, "shirt_flannel"), 2.4 + 2.4 + 2.0 * 2.4, 0.0001, "off once, not back")
	assert_eq(steps.call(Wear.undress_plan(p, "shirt")), ["aside:coat", "off:jacket", "drop:shirt", "back:jacket"])
	assert_eq(Wear.displaced(p, "shirt_flannel").map(func(g: Dictionary) -> String: return String(g["id"])), ["shirt_cotton", "coat_long"], "shown as left down")
	game.actions.pick_up(p, _lay(game, p, "shirt_flannel"), true)
	_finish_all(game, p)
	assert_eq(Wear.worn_ids(p), _ids_with({"shirt": "shirt_flannel"}))
	assert_eq(_garments_down(game), ["coat_long", "shirt_cotton"])
	# Worn through while it lay there: it stays down.
	var game2 = _game()
	var p2 = game2.player
	game2.zombies.list.clear()
	p2.coat = Wear.make("coat_long")
	game2.actions.pick_up(p2, _lay(game2, p2, "shirt_flannel"), true)
	_finish(game2, p2)
	var coat: Dictionary = game2.ground_items.filter(func(g: Dictionary) -> bool: return g.has("garment") and String(g["id"]) == "coat_long")[0]
	coat["garment"]["wear"] = 1.0
	_finish_all(game2, p2)
	assert_eq(Wear.worn_ids(p2)["coat"], "", "rags are not put back on")
	assert_eq(_garments_down(game2), ["coat_long", "shirt_cotton"])


func test_what_hits_one_of_the_dead_goes_through_its_clothes() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	for gun: String in ["pistol", "bow", "shotgun"]:
		var d: Dictionary = W.get_data(gun)
		var head := 0
		var body := 0
		for s in range(1, 41):
			var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(5, 0, 0))
			z["worn"] = {"head": Wear.make("hat_knit"), "coat": Wear.make("coat_long")}
			game.rng.seed = s
			if not game.combat._shoot_zombie(p, z, d, AimModel.BODY_R, 5.0):
				continue
			var hat: bool = (z["worn"]["head"].get("holes", {}) as Dictionary).has("head_neck")
			var coat: bool = (z["worn"]["coat"].get("holes", {}) as Dictionary).has("torso")
			assert_true(hat or coat, "%s, seed %d: through something" % [gun, s])
			head += int(hat)
			body += int(coat)
		assert_gt(head, 0, gun + " to the head holes the hat")
		assert_gt(body, 0, gun + " to the body holes the coat")


func test_clothes_draw_no_dice_where_no_vest_stops_a_round() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	var o = game.squad[1]
	var r = game.make_person({"id": "r_test", "name": "약탈자", "role": "raider"}, o.position + Vector3(4, 0, 0))
	for gun: String in ["pistol", "bow", "shotgun"]:
		var d: Dictionary = W.get_data(gun)
		r.set_weapon_slots([{"id": gun, "quality": "factory", "condition": 1.0, "loaded": 8}])
		for s in range(1, 31):
			var dead: Array = []
			var alive: Array = []
			for dressed: bool in [false, true]:
				var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(5, 0, 0))
				z["worn"] = {"head": Wear.make("hat_knit"), "coat": Wear.make("coat_long")} if dressed else {}
				game.rng.seed = s
				game.combat._shoot_zombie(p, z, d, AimModel.BODY_R, 5.0)
				dead.append(game.rng.state)
				o.body.wounds.clear()
				o.body._refresh()
				o.body.downed = false
				o.worn = Wear.outfit(Wear.DEFAULT) if dressed else {}
				game.rng.seed = s
				game.combat._shoot_person(r, o, AimModel.BODY_R)
				alive.append(game.rng.state)
			assert_eq(dead[0], dead[1], "%s on the dead, seed %d" % [gun, s])
			assert_eq(alive[0], alive[1], "%s on the living, seed %d" % [gun, s])
