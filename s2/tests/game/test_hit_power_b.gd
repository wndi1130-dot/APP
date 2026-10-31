extends "res://addons/gut/test.gd"
## Optional body push, wall clipping and counter cuts share no rule dice.

const FieldGame = preload("res://game/field_game.gd")
const Combat = preload("res://game/field_combat.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const HitFeel = preload("res://game/hit_feel.gd")
const GrabRules = preload("res://game/sim/grab_rules.gd")
const W = preload("res://game/sim/weapons.gd")
const DT: float = 1.0 / 60.0
const EPS: float = 0.00001
const B_FIELDS: Array[String] = ["b", "pre_state", "d0", "d1", "moved", "cut", "victim_is_striker"]

var game: FieldGame
var p: Variant


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 17, "raiders": false, "auto_pause": false, "hit_power": false, "lungers": false}
	add_child_autofree(game)
	_prepare(game)
	p = game.player


func _hand(who: Variant, id: String) -> void:
	who.hands = [] if id == "" else [{"id": id, "quality": "factory", "condition": 1.0, "loaded": 0}]
	who.set_weapon_slots(who.hands)


func _prepare(field: FieldGame) -> void:
	field.set_process(false)
	field.zombies.list.clear()
	field.pending_spawn.clear()
	var who: Variant = field.player
	who.position = field.lift(Vector2i(60, 7), 0)
	who.facing = PI * 0.5
	who.crouched = false
	who.path.clear()
	who.items.clear()
	who.skills["strength"] = 5
	who.skills["melee"] = 5
	_hand(who, "crowbar")
	# Only the actors placed by a test take part in its fight.
	var slot: int = 0
	for other: Variant in field.people:
		if other != who:
			other.position = field.lift(Vector2i(20 + slot * 3, 7), 0)
			other.path.clear()
			slot += 1
	for x: int in range(58, 66):
		for y: int in range(5, 11):
			field.grid.set_solid(Vector2i(x, y), FieldGrid.Solid.NONE)


func _field(options: Dictionary, seed_value: int = 17) -> FieldGame:
	var field: FieldGame = FieldGame.new()
	field.opts = {"seed": seed_value, "raiders": false, "auto_pause": false, "hit_power": false, "lungers": false}
	field.opts.merge(options, true)
	add_child(field)
	_prepare(field)
	return field


func _options(mask: int) -> Dictionary:
	return {"hit_push": (mask & 1) != 0, "hit_wall": (mask & 2) != 0, "hit_counter": (mask & 4) != 0}


func _dead(field: FieldGame, who: Variant, distance: float = 0.8, state: String = "attack", kind: String = "dead") -> Dictionary:
	var z: Dictionary = field.zombies.spawn(kind, who.position + Vector3(distance, 0, 0))
	z["state"] = state
	z["angle"] = -PI * 0.5
	z["victim"] = who
	z["windup"] = 0.4
	z["cooldown"] = 0.0
	z["age"] = 2.0
	z["seen_at"] = {who.get_instance_id(): 0.0}
	z["last_seen"] = who.position
	z["target"] = who.position
	z["lunger"] = false
	z["dash_t"] = 0.0
	z["spent_t"] = 0.0
	return z


func _trace(field: FieldGame) -> Array:
	var heard: Array = []
	field.combat.struck.connect(func(info: Dictionary) -> void: heard.append(info.duplicate(true)))
	return heard


func _roll_seed(first_low: float, first_high: float, second_low: float = 0.0, second_high: float = 1.0) -> int:
	var dice: RandomNumberGenerator = RandomNumberGenerator.new()
	for value: int in range(4096):
		dice.seed = value
		var first: float = dice.randf()
		var second: float = dice.randf()
		if first >= first_low and first < first_high and second >= second_low and second < second_high:
			return value
	assert_true(false, "a seed for the requested branch exists")
	return 0


func _seed_body(field: FieldGame, who: Variant, z: Dictionary) -> void:
	var wid: String = who.weapon_id()
	var mults: Dictionary = who.mults()
	var odds: Dictionary = W.melee_odds(wid, int(who.skills["melee"]), false, field.combat.behind(z, who.position), float(mults.get("melee_hit", 1.0)), int(who.skills["strength"]))
	var head: float = float(odds["head"])
	if z["kind"] == "clothed" and bool(W.get_data(wid)["blade"]):
		head *= 0.5
	field.rng.seed = _roll_seed(head, 1.0, float(odds["knockdown"]), 1.0)


func _body(field: FieldGame, who: Variant, z: Dictionary, direct: bool = false) -> void:
	var before: int = int(field.combat.melee_tally["body_stun"])
	_seed_body(field, who, z)
	if direct:
		field.combat.swing(who, z)
	else:
		field.combat._strike(who, z)
	assert_eq(int(field.combat.melee_tally["body_stun"]), before + 1, "the intended body branch landed")


func _q(field: FieldGame, who: Variant, z: Dictionary, counter: bool = false) -> float:
	var data: Dictionary = W.get_data(who.weapon_id())
	return float(HitFeel.blow_power(float(data.get("weight", 0.0)), int(who.skills["strength"]), HitFeel.body_melee(who.body, who.mult_ctx()), who.body.breath_locked, field.combat.behind(z, who.position), counter, field.combat._edge_of(who), "swing")["q"])


func _count(tally: Dictionary, key: String, expected: int) -> void:
	assert_eq(int(tally.get(key, 0)), expected, key)
	assert_eq(tally.has(key), expected > 0, "only actual events add " + key)
	if tally.has(key):
		assert_eq(typeof(tally[key]), TYPE_INT, key + " is an integer")


func _no_b(tally: Dictionary, heard: Array) -> void:
	for key: String in tally:
		assert_false(key.begins_with("b_"), key)
	for info: Dictionary in heard:
		assert_false(info.has("wall"), "legacy signals have no wall field")
		for key: String in B_FIELDS:
			assert_false(info.has(key), "legacy signals have no " + key)


func _legacy_b_trace(heard: Array) -> Array:
	var trace: Array = heard.duplicate(true)
	for info: Dictionary in trace:
		for key: String in B_FIELDS:
			info.erase(key)
	return trace


func _snapshot(field: FieldGame, heard: Array) -> Dictionary:
	var dead: Array = []
	for z: Dictionary in field.zombies.list:
		dead.append([z["id"], z["state"], z["pos"], field.zombies.seen_pos(z)])
	var people: Array = []
	for who: Variant in field.people:
		people.append({"id": who.pid, "pos": who.position, "dead": who.body.dead, "downed": who.body.downed,
			"exhaustion": who.body.exhaustion, "breath": who.body.breath, "breath_locked": who.body.breath_locked,
			"hands": who.hands.duplicate(true), "swing_t": who.swing_t})
	var tally_keys: Array = field.combat.melee_tally.keys()
	tally_keys.sort()
	return {"dead": dead, "people": people, "melee_tally": field.combat.melee_tally.duplicate(true),
		"melee_tally_keys": tally_keys,
		"contacts": field.combat.contacts.duplicate(true), "rng": field.rng.state,
		"trace": heard.duplicate(true), "kills": field.combat.kills, "crowd_falls": field.combat.crowd_falls}


func _record(field: FieldGame, z: Dictionary) -> Dictionary:
	var record: Dictionary = {}
	for key: String in ["id", "state", "pos", "stun", "hit_hold", "dash_t", "spent_t", "path_t", "windup", "cooldown"]:
		record[key] = z.get(key, 0.0)
	record["seen_pos"] = field.zombies.seen_pos(z)
	record["holds_player"] = z["victim"] == field.player
	return record


func _mixed_fight(explicit_off: bool, seed_value: int, hit_power: bool) -> Dictionary:
	var options: Dictionary = {"hit_power": hit_power}
	if explicit_off:
		options.merge(_options(0), true)
	var field: FieldGame = _field(options, seed_value)
	var who: Variant = field.player
	var heard: Array = _trace(field)
	var checkpoints: Array = []
	var rushing: Dictionary = _dead(field, who)
	rushing["lunger"] = true
	rushing["dash_t"] = 0.15
	rushing["dash_dir"] = Vector3.LEFT
	var start: Vector3 = rushing["pos"]
	_body(field, who, rushing)
	assert_almost_eq(start.distance_to(rushing["pos"]), 0.3, EPS)
	checkpoints.append(_snapshot(field, heard))
	# The second body hit ends in a wall, so the whole old push is cancelled.
	who.position = Vector3(61.0, 0.0, 9.5)
	field.grid.set_solid(Vector2i(62, 9), FieldGrid.Solid.WALL)
	var blocked: Dictionary = _dead(field, who)
	start = blocked["pos"]
	_body(field, who, blocked)
	assert_eq(blocked["pos"], start)
	checkpoints.append(_snapshot(field, heard))
	who.position = field.lift(Vector2i(60, 7), 0)
	var frozen: Dictionary = field.zombies.spawn("frozen", who.position + Vector3(0.8, 0, 0))
	field.combat._strike(who, frozen)
	assert_eq(frozen["state"], "dead")
	checkpoints.append(_snapshot(field, heard))
	_hand(who, "")
	var fallen: Dictionary = _dead(field, who)
	field.zombies.knock_down(fallen)
	for _i: int in range(field.combat.STOMPS_TO_END):
		field.combat.stomp(who, fallen)
		checkpoints.append(_snapshot(field, heard))
	assert_eq(fallen["state"], "dead")
	var shoved: Dictionary = _dead(field, who, 0.7, "tell")
	shoved["lunger"] = true
	who.swing_t = 0.0
	field.combat.shove(who)
	assert_gt(float(shoved.get("shoved_t", 0.0)), 0.0)
	checkpoints.append(_snapshot(field, heard))
	var ally: Variant = field.allies_alive().filter(func(person: Variant) -> bool: return person != who)[0]
	ally.position = who.position + Vector3(0, 0, 3)
	ally.facing = PI * 0.5
	_hand(ally, "axe")
	var target: Dictionary = _dead(field, ally)
	_body(field, ally, target)
	checkpoints.append(_snapshot(field, heard))
	ally.position = field.lift(Vector2i(25, 7), 0)
	for _i: int in range(12):
		field._step(DT)
	_no_b(field.combat.melee_tally, heard)
	var result: Dictionary = _snapshot(field, heard)
	result["checkpoints"] = checkpoints
	field.free()
	return result


func test_missing_options_and_explicit_off_match_the_whole_mixed_fight() -> void:
	for hit_power: bool in [false, true]:
		for seed_value: int in [17, 51]:
			assert_eq(_mixed_fight(false, seed_value, hit_power), _mixed_fight(true, seed_value, hit_power), "same rules and full signal trace, power %s" % hit_power)


func _matrix_case(mask: int, wall: bool) -> int:
	var field: FieldGame = _field(_options(mask))
	var who: Variant = field.player
	if wall:
		who.position = Vector3(61.0, 0.0, 7.5)
		field.grid.set_solid(Vector2i(62, 7), FieldGrid.Solid.WALL)
	var z: Dictionary = _dead(field, who)
	var start: Vector3 = z["pos"]
	var heard: Array = _trace(field)
	var push: bool = (mask & 1) != 0
	var clip: bool = (mask & 2) != 0
	var counter: bool = (mask & 4) != 0
	var distance: float = Combat.push_distance(1.25, _q(field, who, z, push and counter)) if push else 0.3
	var expected: float = distance
	if wall:
		# At x=61.8 the cell boundary is 0.2 m away; landing on it is blocked.
		var steps: int = floori((distance - 0.2 + EPS) / 0.05) + 1
		expected = maxf(0.05, distance - float(steps) * 0.05) if clip else 0.0
	_body(field, who, z)
	assert_almost_eq(start.distance_to(z["pos"]), expected, EPS, "mask %d, wall %s" % [mask, wall])
	assert_eq(z["state"], "chase" if counter else "attack")
	assert_eq(float(z["stun"]), 0.9)
	assert_eq(float(z["hit_hold"]), 0.9)
	assert_eq(float(z["windup"]), 0.4)
	assert_eq(float(z["cooldown"]), 0.0)
	assert_eq(z["victim"], who)
	assert_eq(field.zombies.seen_pos(z), z["pos"])
	assert_false(field.grid_at(z["pos"]).blocks_body(FieldGrid.cell_of(z["pos"])))
	assert_eq(heard.size(), 1)
	assert_eq(heard[0]["result"], "body")
	assert_eq(heard[0].has("wall"), clip)
	if clip:
		assert_eq(heard[0]["wall"], wall)
	if mask == 0:
		_no_b(field.combat.melee_tally, heard)
	else:
		assert_true(heard[0]["b"])
		assert_eq(heard[0]["pre_state"], "attack")
		assert_almost_eq(float(heard[0]["d0"]), who.position.distance_to(start), EPS)
		assert_almost_eq(float(heard[0]["d1"]), who.position.distance_to(z["pos"]), EPS)
		assert_almost_eq(float(heard[0]["moved"]), start.distance_to(z["pos"]), EPS)
		assert_eq(heard[0]["cut"], "counter" if counter else "")
		assert_true(heard[0]["victim_is_striker"])
	_count(field.combat.melee_tally, "b_push", 1 if push and expected > 0.0 else 0)
	_count(field.combat.melee_tally, "b_wall", 1 if clip and wall else 0)
	_count(field.combat.melee_tally, "b_counter_cut", 1 if counter else 0)
	_count(field.combat.melee_tally, "b_dash_cut", 0)
	var state: int = field.rng.state
	field.free()
	return state


func test_all_eight_options_match_the_contract_and_use_the_same_dice() -> void:
	var baseline: int = 0
	for wall: bool in [false, true]:
		for mask: int in range(8):
			var state: int = _matrix_case(mask, wall)
			if mask == 0 and not wall:
				baseline = state
			assert_eq(state, baseline, "a single hit consumes the same rule dice")


func test_push_distance_examples_limits_and_weapon_weights() -> void:
	for row: Array in [[0.7, 1.0, 0.21], [0.7, 0.5, 0.2], [1.25, 1.0, 0.375], [1.25, 1.12, 0.42], [1.25, 1.344, 0.43125]]:
		assert_almost_eq(Combat.push_distance(float(row[0]), float(row[1])), float(row[2]), 0.000001)
	for k: float in [-2.0, 0.0, 0.7, 0.8, 1.0, 1.25, 10.0]:
		for q: float in [-10.0, 0.5, 0.85, 1.0, 1.12, 1.344, 10.0]:
			assert_between(Combat.push_distance(k, q), 0.2, 0.45)
	var weights: Dictionary = {"broken_bottle": 0.7, "knife": 0.7, "wood_stake": 0.8, "axe": 1.0, "frying_pan": 1.25, "crowbar": 1.25}
	for wid: String in weights:
		assert_eq(Combat.push_k(wid), float(weights[wid]))
	assert_eq(Combat.push_k("missing_weapon"), 1.0)


func test_strength_five_axe_uses_q_from_blow_power() -> void:
	game.opts["hit_push"] = true
	_hand(p, "axe")
	var z: Dictionary = _dead(game, p)
	var start: Vector3 = z["pos"]
	var q: float = _q(game, p, z)
	var expected: float = clampf(0.3 * clampf(q, 0.85, 1.15), 0.2, 0.45)
	_body(game, p, z)
	assert_almost_eq(start.distance_to(z["pos"]), expected, EPS)


func test_push_distance_is_independent_of_hit_power_and_strike_wrapper() -> void:
	var baseline: float = -1.0
	for power: bool in [false, true]:
		for direct: bool in [false, true]:
			var field: FieldGame = _field({"hit_push": true, "hit_power": power})
			var who: Variant = field.player
			var z: Dictionary = _dead(field, who)
			var start: Vector3 = z["pos"]
			var expected: float = Combat.push_distance(1.25, _q(field, who, z))
			_body(field, who, z, direct)
			var moved: float = start.distance_to(z["pos"])
			assert_almost_eq(moved, expected, EPS)
			if baseline < 0.0:
				baseline = moved
			assert_eq(moved, baseline)
			field.free()


func test_a_bottle_broken_by_the_blow_keeps_its_own_push_weight() -> void:
	game.opts["hit_push"] = true
	_hand(p, "broken_bottle")
	p.hands[0]["condition"] = 0.01
	p.body.exhaustion = 0.7999
	var z: Dictionary = _dead(game, p, 0.8, "chase")
	var start: Vector3 = z["pos"]
	var q: float = _q(game, p, z)
	var expected: float = Combat.push_distance(0.7, q)
	var heard: Array = _trace(game)
	_body(game, p, z)
	assert_eq(p.weapon_id(), "")
	assert_eq(p.body.exhaustion_level(), 2)
	assert_eq(int(heard[0]["edge"]), 2)
	assert_almost_eq(start.distance_to(z["pos"]), expected, EPS)
	assert_gt(absf(expected - Combat.push_distance(1.0, q)), EPS, "the fixture catches a lost weapon id")


func test_push_reads_fatigue_and_edge_before_spending_them() -> void:
	for crossing: String in ["fatigue", "edge"]:
		var field: FieldGame = _field({"hit_push": true})
		var who: Variant = field.player
		who.skills["strength"] = 7
		who.body.exhaustion = 0.4999 if crossing == "fatigue" else 0.0
		who.hands[0]["condition"] = 0.6001 if crossing == "edge" else 1.0
		var z: Dictionary = _dead(field, who, 0.8, "chase")
		var start: Vector3 = z["pos"]
		var before: float = Combat.push_distance(1.25, _q(field, who, z))
		_body(field, who, z)
		var after: float = Combat.push_distance(1.25, _q(field, who, z))
		assert_gt(absf(before - after), EPS, crossing + " must distinguish early and late reads")
		assert_almost_eq(start.distance_to(z["pos"]), before, EPS)
		if crossing == "fatigue":
			assert_eq(who.body.exhaustion_level(), 1)
		else:
			assert_eq(field.combat._edge_of(who), 1)
		field.free()


func _reaches(field: FieldGame) -> int:
	var total: int = 0
	for side: Dictionary in field.combat.contacts.values():
		total += int(side["reach"])
	return total


func _counter_timing(enabled: bool, crawl: bool) -> float:
	var field: FieldGame = _field({"hit_counter": enabled})
	var who: Variant = field.player
	var z: Dictionary = _dead(field, who, 0.5)
	z["crawl"] = crawl
	z["windup"] = 0.1
	_body(field, who, z)
	assert_eq(z["state"], "chase" if enabled else "attack")
	assert_eq(float(z["stun"]), 0.9)
	assert_eq(float(z["hit_hold"]), 0.9)
	assert_eq(float(z["windup"]), 0.1, "the cut does not write windup")
	assert_eq(float(z["cooldown"]), 0.0)
	assert_eq(z["victim"], who)
	var windup: float = 2.0 if crawl else 0.8
	var earliest: float = 0.9 + windup
	var before: int = _reaches(field)
	var first: float = -1.0
	var reentered: bool = false
	var standing_at: Vector3 = who.position
	for frame: int in range(300):
		var was: String = String(z["state"])
		field._step(DT)
		var elapsed: float = float(frame + 1) * DT
		if enabled and was != "attack" and z["state"] == "attack" and not reentered:
			reentered = true
			assert_almost_eq(float(z["windup"]), windup, EPS, "entering attack starts a whole windup")
		if enabled and elapsed < earliest - EPS:
			assert_eq(_reaches(field), before, "no reach during stun plus the new windup")
		if _reaches(field) > before:
			first = elapsed
			break
		assert_eq(who.position, standing_at, "the timing fixture keeps the player still")
	assert_gt(first, 0.0, "the attack eventually reaches its victim")
	if enabled:
		assert_true(reentered)
		assert_true(first >= earliest - EPS)
	else:
		assert_lt(first, 0.9, "legacy attack continues through body stun")
	field.free()
	return first


func test_counter_restarts_full_windup_after_stun_for_walkers_and_crawlers() -> void:
	for crawl: bool in [false, true]:
		var off: float = _counter_timing(false, crawl)
		var on: float = _counter_timing(true, crawl)
		assert_gt(on, off)


func test_counter_ends_live_dash_in_both_attack_and_chase() -> void:
	for state: String in ["attack", "chase"]:
		for enabled: bool in [false, true]:
			var field: FieldGame = _field({"hit_counter": enabled})
			var who: Variant = field.player
			var z: Dictionary = _dead(field, who, 0.8, state)
			z["lunger"] = true
			z["dash_t"] = 0.25
			z["dash_dir"] = Vector3.LEFT
			z["path_t"] = 2.4
			z["cooldown"] = 0.35
			var heard: Array = _trace(field)
			_body(field, who, z)
			assert_eq(float(z["dash_t"]), 0.0 if enabled else 0.25)
			assert_eq(float(z["spent_t"]), 6.0 if enabled else 0.0)
			assert_eq(float(z["path_t"]), 0.0 if enabled else 2.4)
			assert_eq(float(z["windup"]), 0.4)
			assert_eq(float(z["cooldown"]), 0.35)
			assert_eq(z["victim"], who)
			assert_eq(float(z["stun"]), 0.9)
			assert_eq(float(z["hit_hold"]), 0.9)
			assert_eq(z["state"], "chase" if enabled else state)
			_count(field.combat.melee_tally, "b_dash_cut", 1 if enabled else 0)
			_count(field.combat.melee_tally, "b_counter_cut", 1 if enabled and state == "attack" else 0)
			_count(field.combat.melee_tally, "b_push", 0)
			_count(field.combat.melee_tally, "b_wall", 0)
			if enabled:
				assert_eq(heard[0]["cut"], "both" if state == "attack" else "dash")
				assert_eq(heard[0]["pre_state"], state)
				assert_false(heard[0].has("wall"))
			else:
				_no_b(field.combat.melee_tally, heard)
			field.free()


func _unchanged_case(mask: int, state: String, kind: String = "dead", weapon: String = "crowbar") -> Dictionary:
	var field: FieldGame = _field(_options(mask))
	var who: Variant = field.player
	_hand(who, weapon)
	var z: Dictionary = _dead(field, who, 0.8, state, kind)
	z["t"] = 0.3
	var heard: Array = _trace(field)
	if state == "downed":
		field.rng.seed = _roll_seed(0.0, 0.1, 0.0, 0.1)
		field.combat._strike(who, z)
		assert_eq(z["state"], "dead", "the existing downed finish is kept")
	else:
		_body(field, who, z)
	if kind == "clothed":
		assert_eq(heard[0]["result"], "blocked")
		assert_eq(float(z["stun"]), 0.3)
	if mask != 0 and state not in ["downed", "climb"] and kind != "clothed":
		assert_true(heard[0]["b"])
		assert_eq(heard[0]["pre_state"], state)
		assert_eq(heard[0]["cut"], "")
		heard = _legacy_b_trace(heard)
	elif mask != 0:
		for info: Dictionary in heard:
			assert_false(info.has("b"), "an excluded state's blow carries no B fields")
	_no_b(field.combat.melee_tally, heard)
	var before: Dictionary = _record(field, z)
	field._step(DT)
	var result: Dictionary = _snapshot(field, heard)
	result["before_step"] = before
	result["after_step"] = _record(field, z)
	field.free()
	return result


func test_tell_and_plain_chase_are_unchanged_with_counter_only() -> void:
	for state: String in ["tell", "chase"]:
		var off: Dictionary = _unchanged_case(0, state)
		assert_eq(_unchanged_case(4, state), off, state)
		if state == "tell":
			assert_eq(off["before_step"]["state"], "tell")
			assert_eq(off["after_step"]["state"], "chase")
			assert_eq(off["after_step"]["spent_t"], 6.0)


func test_clothed_blade_blocks_and_excluded_states_ignore_all_b_options() -> void:
	assert_eq(_unchanged_case(7, "attack", "clothed", "knife"), _unchanged_case(0, "attack", "clothed", "knife"))
	for state: String in ["climb", "downed"]:
		assert_eq(_unchanged_case(7, state), _unchanged_case(0, state), state)


func _grab_case(mask: int, breaks: String) -> Dictionary:
	var options: Dictionary = _options(mask)
	options["melee_break"] = breaks
	var field: FieldGame = _field(options)
	var who: Variant = field.player
	var z: Dictionary = _dead(field, who, 0.8, "grab")
	who.grabbers.append(z)
	who.grab_left = 1.0
	who.strike_at = z
	who.strike_kind = "swing"
	who.strike_total = 0.18
	who.strike_t = 0.01
	var heard: Array = _trace(field)
	var before: int = int(field.combat.melee_tally["body_stun"])
	_seed_body(field, who, z)
	field.combat._land_strike(who)
	assert_eq(int(field.combat.melee_tally["body_stun"]), before + (1 if breaks == "none" else 0))
	assert_eq(z["state"], "grab")
	assert_eq(who.grabbers.size(), 1)
	for info: Dictionary in heard:
		assert_false(info.has("b"), "a grab's blow carries no B fields")
	_no_b(field.combat.melee_tally, heard)
	var result: Dictionary = _snapshot(field, heard)
	result["body"] = _record(field, z)
	result["swing_t"] = who.swing_t
	result["grab_left"] = who.grab_left
	field._step(DT)
	result["after_step"] = _record(field, z)
	result["contacts_after_step"] = field.combat.contacts.duplicate(true)
	field.free()
	return result


func test_pre_hit_grab_is_unchanged_for_both_melee_break_rules() -> void:
	for breaks: String in ["grab", "none"]:
		assert_eq(_grab_case(7, breaks), _grab_case(0, breaks), breaks)


func test_push_only_attack_retention_follows_distance_and_reach() -> void:
	for weapon: String in ["knife", "crowbar"]:
		for d0: float in [0.6, 0.85, 1.0, 1.1]:
			var field: FieldGame = _field({"hit_push": true})
			var who: Variant = field.player
			_hand(who, weapon)
			var z: Dictionary = _dead(field, who, d0)
			var start: Vector3 = z["pos"]
			var standing_at: Vector3 = who.position
			_body(field, who, z)
			var moved: float = start.distance_to(z["pos"])
			var stays: bool = d0 + moved <= 0.85 + GrabRules.CONTACT_MARGIN and field.zombies.can_reach(z, who)
			field._step(DT)
			assert_eq(who.position, standing_at)
			assert_eq(z["state"] == "attack", stays, "%s at %.2f + %.5f" % [weapon, d0, moved])
			field.free()


func test_two_people_in_one_tick_keep_pushes_below_point_nine_and_out_of_walls() -> void:
	for wall: bool in [false, true]:
		var field: FieldGame = _field(_options(7))
		var who: Variant = field.player
		if wall:
			who.position = Vector3(61.0, 0.0, 7.5)
			field.grid.set_solid(Vector2i(62, 7), FieldGrid.Solid.WALL)
		var ally: Variant = field.allies_alive().filter(func(person: Variant) -> bool: return person != who)[0]
		ally.position = who.position - Vector3(0.1, 0, 0)
		ally.facing = PI * 0.5
		_hand(ally, "crowbar")
		var z: Dictionary = _dead(field, who)
		var start: Vector3 = z["pos"]
		var elapsed: float = field.clock.elapsed
		var total: float = 0.0
		var heard: Array = _trace(field)
		for hitter: Variant in [who, ally]:
			var previous: Vector3 = z["pos"]
			_body(field, hitter, z)
			total += previous.distance_to(z["pos"])
			assert_eq(field.level_of(z["pos"]), field.level_of(start))
			assert_false(field.grid_at(z["pos"]).blocks_body(FieldGrid.cell_of(z["pos"])))
		assert_true(total <= 0.9 + EPS)
		assert_almost_eq(start.distance_to(z["pos"]), total, EPS)
		assert_eq(field.clock.elapsed, elapsed, "both hits are in the same tick")
		assert_eq(heard.size(), 2)
		for info: Dictionary in heard:
			assert_eq(info["wall"], wall)
		field.free()


func test_wall_point_two_away_clips_only_with_hit_wall() -> void:
	for enabled: bool in [false, true]:
		var field: FieldGame = _field({"hit_wall": enabled})
		var who: Variant = field.player
		who.position = Vector3(61.0, 0.0, 7.5)
		field.grid.set_solid(Vector2i(62, 7), FieldGrid.Solid.WALL)
		var z: Dictionary = _dead(field, who)
		var start: Vector3 = z["pos"]
		var heard: Array = _trace(field)
		_body(field, who, z)
		assert_almost_eq(start.distance_to(z["pos"]), 0.15 if enabled else 0.0, EPS)
		assert_false(field.grid.blocks_body(FieldGrid.cell_of(z["pos"])))
		assert_eq(heard[0].has("wall"), enabled)
		if enabled:
			assert_true(heard[0]["wall"])
		field.free()


func test_wall_checks_the_last_point_zero_five_and_reports_a_fully_blocked_push() -> void:
	for gap: float in [0.06, 0.04]:
		var field: FieldGame = _field({"hit_wall": true})
		var who: Variant = field.player
		who.position = Vector3(62.0 - gap - 0.8, 0, 7.5)
		field.grid.set_solid(Vector2i(62, 7), FieldGrid.Solid.WALL)
		var z: Dictionary = _dead(field, who)
		var start: Vector3 = z["pos"]
		var heard: Array = _trace(field)
		_body(field, who, z)
		assert_almost_eq(start.distance_to(z["pos"]), 0.05 if gap > 0.05 else 0.0, EPS)
		assert_true(heard[0]["wall"])
		_count(field.combat.melee_tally, "b_wall", 1)
		_count(field.combat.melee_tally, "b_push", 0)
		field.free()


func test_push_spots_require_same_floor_clear_cell_and_clear_corner() -> void:
	var start: Vector3 = Vector3(60.9, 0, 7.9)
	var cell: Vector2i = FieldGrid.cell_of(start)
	assert_true(game.grid.body_line_clear(cell, cell), "same-cell lines return true")
	assert_true(game.combat._push_spot_ok(start, start + Vector3(0.02, 0, 0)))
	assert_false(game.combat._push_spot_ok(start, Vector3(start.x, game.level_y(1), start.z)))
	game.grid.set_solid(cell, FieldGrid.Solid.WALL)
	assert_false(game.combat._push_spot_ok(start, start), "the destination must still be clear")
	game.grid.set_solid(cell, FieldGrid.Solid.NONE)
	game.grid.set_solid(Vector2i(61, 7), FieldGrid.Solid.WALL)
	game.grid.set_solid(Vector2i(60, 8), FieldGrid.Solid.WALL)
	var across: Vector3 = Vector3(61.1, 0, 8.1)
	assert_false(game.grid.blocks_body(FieldGrid.cell_of(across)))
	assert_false(game.combat._push_spot_ok(start, across), "a clear endpoint cannot cut a closed corner")
	game.opts["hit_push"] = true
	p.position = start - Vector3(0.6, 0, 0.6)
	var z: Dictionary = _dead(game, p)
	z["pos"] = start
	_body(game, p, z)
	assert_eq(z["pos"], start)
	_count(game.combat.melee_tally, "b_push", 0)
	game.opts["hit_wall"] = true
	_body(game, p, z)
	assert_gt(start.distance_to(z["pos"]), 0.0)
	assert_eq(FieldGrid.cell_of(z["pos"]), cell)
	_count(game.combat.melee_tally, "b_wall", 1)


func test_diagonal_push_crossing_one_wall_clips_only_with_hit_wall() -> void:
	for mask: int in [1, 2]:
		var field: FieldGame = _field(_options(mask))
		var who: Variant = field.player
		var start: Vector3 = Vector3(60.9, 0, 7.9)
		var direction: Vector3 = Vector3(3, 0, 2).normalized()
		var wall_on: bool = mask == 2
		who.position = start - direction * 0.8
		var z: Dictionary = _dead(field, who)
		z["pos"] = start
		field.grid.set_solid(Vector2i(61, 7), FieldGrid.Solid.WALL)
		assert_false(field.grid.blocks_body(Vector2i(60, 8)))
		assert_false(field.grid.blocks_body(FieldGrid.cell_of(start + direction * 0.3)))
		var dice_before: int = field.rng.state
		var pushed: Dictionary = field.combat._push_b(z, who.position, 0.3, wall_on)
		assert_true(pushed["wall"], "the segment crosses the single blocked side cell")
		assert_almost_eq(float(pushed["moved"]), 0.1 if wall_on else 0.0, EPS)
		assert_eq(field.rng.state, dice_before, "cell walking consumes no rule dice")
		z["pos"] = start
		var heard: Array = _trace(field)
		_body(field, who, z)
		assert_almost_eq(start.distance_to(z["pos"]), 0.1 if wall_on else 0.0, EPS)
		assert_eq(FieldGrid.cell_of(z["pos"]), FieldGrid.cell_of(start))
		assert_eq(heard[0].has("wall"), wall_on)
		if wall_on:
			assert_true(heard[0]["wall"])
			_count(field.combat.melee_tally, "b_wall", 1)
		else:
			assert_eq(z["pos"], start)
			_count(field.combat.melee_tally, "b_push", 0)
		field.free()


func test_diagonal_push_five_centimeters_from_corner_stays_clear() -> void:
	# Perpendicular distance from this line to the corner is 0.05 m.
	var start: Vector3 = Vector3(60.9, 0, 7.9 + sqrt(2.0) * 0.05)
	var direction: Vector3 = Vector3(1, 0, 1).normalized()
	var finish: Vector3 = start + direction * 0.3
	game.grid.set_solid(Vector2i(61, 7), FieldGrid.Solid.WALL)
	assert_eq(FieldGrid.cell_of(start), Vector2i(60, 7))
	assert_eq(FieldGrid.cell_of(finish), Vector2i(61, 8))
	assert_true(Combat.line_cells_clear(game.grid, start, finish))
	assert_true(Combat.line_cells_clear(game.grid, finish, start))
	assert_true(game.combat._push_spot_ok(start, finish))
	for wall_on: bool in [false, true]:
		var z: Dictionary = {"pos": start}
		var pushed: Dictionary = game.combat._push_b(z, start - direction, 0.3, wall_on)
		assert_false(pushed["wall"])
		assert_almost_eq(float(pushed["moved"]), 0.3, EPS)
		assert_almost_eq(z["pos"].distance_to(finish), 0.0, EPS)


func test_line_cells_clear_rejects_either_side_of_an_exact_corner() -> void:
	var start: Vector3 = Vector3(60.75, 0, 7.75)
	var finish: Vector3 = Vector3(61.25, 0, 8.25)
	assert_true(Combat.line_cells_clear(game.grid, start, finish))
	for side: Vector2i in [Vector2i(61, 7), Vector2i(60, 8)]:
		game.grid.set_solid(side, FieldGrid.Solid.WALL)
		assert_false(Combat.line_cells_clear(game.grid, start, finish))
		assert_false(Combat.line_cells_clear(game.grid, finish, start))
		assert_false(game.combat._push_spot_ok(start, finish))
		game.grid.set_solid(side, FieldGrid.Solid.NONE)


func test_line_cells_clear_checks_exact_corner_endpoints_in_both_directions() -> void:
	var finish: Vector3 = Vector3(61, 0, 8)
	var cases: Array = [
		[Vector3(60.75, 0, 8.25), [Vector2i(60, 7), Vector2i(61, 8)]],
		[Vector3(60.75, 0, 7.75), [Vector2i(61, 7), Vector2i(60, 8)]],
		[Vector3(61.25, 0, 7.75), [Vector2i(60, 7), Vector2i(61, 8)]],
		[Vector3(61.25, 0, 8.25), [Vector2i(60, 8), Vector2i(61, 7)]]]
	for row: Array in cases:
		var start: Vector3 = row[0]
		assert_true(Combat.line_cells_clear(game.grid, start, finish))
		assert_true(Combat.line_cells_clear(game.grid, finish, start))
		for side: Vector2i in row[1]:
			game.grid.set_solid(side, FieldGrid.Solid.WALL)
			assert_false(Combat.line_cells_clear(game.grid, start, finish))
			assert_false(Combat.line_cells_clear(game.grid, finish, start))
			assert_false(game.combat._push_spot_ok(start, finish))
			assert_false(game.combat._push_spot_ok(finish, start))
			game.grid.set_solid(side, FieldGrid.Solid.NONE)
		assert_true(Combat.line_cells_clear(game.grid, start, finish))
		assert_true(Combat.line_cells_clear(game.grid, finish, start))


func _shoved_dead(field: FieldGame) -> Dictionary:
	var who: Variant = field.player
	who.position = Vector3(59.8875, 0, 8.05)
	var z: Dictionary = _dead(field, who, 0.8, "chase")
	z["pos"] = Vector3(60.6875, 0, 8.05)
	z["shoved_from"] = Vector3(60.6875, 0, 6.75)
	z["shoved_t"] = field.zombies.SHOVED_TIME * sqrt(0.1)
	assert_almost_eq(field.zombies.shoved_k(z), 0.9, EPS)
	return z


func test_push_during_shove_checks_both_drawn_segments_for_every_candidate() -> void:
	for wall_present: bool in [false, true]:
		for wall_on: bool in [false, true]:
			var field: FieldGame = _field({})
			var z: Dictionary = _shoved_dead(field)
			if wall_present:
				field.grid.set_solid(Vector2i(61, 7), FieldGrid.Solid.WALL)
			var start: Vector3 = z["pos"]
			var now: Vector3 = field.zombies.draw_pos(z)
			var shove_from: Vector3 = z["shoved_from"]
			var shove_t: float = float(z["shoved_t"])
			var dice_before: int = field.rng.state
			assert_true(field.combat._push_spot_ok(start, start + Vector3(0.375, 0, 0)))
			var pushed: Dictionary = field.combat._push_b(z, field.player.position, 0.375, wall_on)
			assert_eq(pushed["wall"], wall_present)
			if wall_present:
				assert_lt(float(pushed["moved"]), 0.375)
				if wall_on:
					assert_gt(float(pushed["moved"]), 0.0)
				else:
					assert_eq(z["pos"], start)
			else:
				assert_almost_eq(float(pushed["moved"]), 0.375, EPS)
			var next: Vector3 = field.zombies.draw_pos(z)
			assert_false(field.grid.blocks_body(FieldGrid.cell_of(next)))
			assert_true(field.combat._push_spot_ok(now, next))
			assert_true(field.combat._push_spot_ok(next, z["pos"]))
			assert_eq(z["shoved_from"], shove_from)
			assert_eq(z["shoved_t"], shove_t)
			assert_eq(field.rng.state, dice_before)
			field.free()


func test_body_hit_during_shove_records_seen_distance_and_the_pre_hit_victim() -> void:
	for wall_present: bool in [false, true]:
		for victim_is_striker: bool in [false, true]:
			var field: FieldGame = _field({"hit_push": true, "hit_wall": true})
			var who: Variant = field.player
			var z: Dictionary = _shoved_dead(field)
			if not victim_is_striker:
				z["victim"] = field.allies_alive().filter(func(person: Variant) -> bool: return person != who)[0]
			if wall_present:
				field.grid.set_solid(Vector2i(61, 7), FieldGrid.Solid.WALL)
			var start: Vector3 = z["pos"]
			var now: Vector3 = field.zombies.draw_pos(z)
			var d0: float = who.position.distance_to(field.zombies.seen_pos(z))
			var shove_from: Vector3 = z["shoved_from"]
			var shove_t: float = float(z["shoved_t"])
			assert_gt(absf(d0 - who.position.distance_to(start)), EPS)
			assert_almost_eq(Combat.push_distance(1.25, _q(field, who, z)), 0.375, EPS)
			var heard: Array = _trace(field)
			_body(field, who, z)
			assert_eq(heard.size(), 1)
			var info: Dictionary = heard[0]
			assert_true(info["b"])
			assert_eq(info["pre_state"], "chase")
			assert_almost_eq(float(info["d0"]), d0, EPS)
			assert_almost_eq(float(info["d1"]), who.position.distance_to(z["pos"]), EPS)
			assert_almost_eq(float(info["moved"]), start.distance_to(z["pos"]), EPS)
			assert_eq(info["cut"], "")
			assert_eq(info["victim_is_striker"], victim_is_striker)
			assert_eq(info["wall"], wall_present)
			assert_true(info["by_player"])
			if wall_present:
				assert_gt(float(info["moved"]), 0.0)
				assert_lt(float(info["moved"]), 0.375)
			else:
				assert_almost_eq(float(info["moved"]), 0.375, EPS)
			var next: Vector3 = field.zombies.draw_pos(z)
			assert_false(field.grid.blocks_body(FieldGrid.cell_of(next)))
			assert_true(field.combat._push_spot_ok(now, next))
			assert_true(field.combat._push_spot_ok(next, z["pos"]))
			assert_eq(z["shoved_from"], shove_from)
			assert_eq(z["shoved_t"], shove_t)
			field.free()


func test_zero_horizontal_direction_does_not_move_or_claim_an_event() -> void:
	game.opts.merge(_options(7), true)
	var z: Dictionary = _dead(game, p, 0.0, "chase")
	var start: Vector3 = z["pos"]
	var heard: Array = _trace(game)
	_body(game, p, z)
	assert_eq(z["pos"], start)
	assert_false(heard[0]["wall"])
	for key: String in ["b_push", "b_wall", "b_counter_cut", "b_dash_cut"]:
		_count(game.combat.melee_tally, key, 0)


func _finite_save(value: Variant) -> void:
	assert_ne(typeof(value), TYPE_VECTOR3I, "no Vector3i in combat save state")
	if value is float:
		assert_true(is_finite(float(value)), "saved floats are finite")
	elif value is Dictionary:
		for key: Variant in value:
			_finite_save(key)
			_finite_save(value[key])
	elif value is Array:
		for entry: Variant in value:
			_finite_save(entry)


func test_b_adds_no_zombie_fields_and_saves_only_finite_integer_tallies() -> void:
	for dash: bool in [false, true]:
		var legacy_keys: Array = []
		for mask: int in [0, 7]:
			var field: FieldGame = _field(_options(mask))
			var who: Variant = field.player
			var z: Dictionary = _dead(field, who)
			if dash:
				z["lunger"] = true
				z["dash_t"] = 0.25
				z["dash_dir"] = Vector3.LEFT
			_body(field, who, z)
			var keys: Array = z.keys()
			keys.sort()
			if mask == 0:
				legacy_keys = keys
			else:
				assert_eq(keys, legacy_keys)
			for key: String in field.combat.melee_tally:
				if key.begins_with("b_"):
					assert_eq(typeof(field.combat.melee_tally[key]), TYPE_INT, key)
			_finite_save(FieldSave._script_state(field, field.combat))
			field.free()
