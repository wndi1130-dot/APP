extends "res://addons/gut/test.gd"
## What a companion shouts (user 2026-10-12): words over their head, not too
## often, and never the chief. Three times the lines there were, fitting the
## moment, the voice and how one stands with the chief (morning word, 10-18).

const FieldGame = preload("res://game/field_game.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const AllyLines = preload("res://game/sim/ally_lines.gd")
const Tables = preload("res://game/politics/tables.gd")

## The lines there were before the morning word (main d2f29454): VOICED 56, LINES 7.
const LINES_BEFORE: int = 63

var game
var mate
var other


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 4, "auto_pause": false, "raiders": false}
	add_child_autofree(game)
	game.set_process(false)
	var mates: Array = game.squad.filter(func(p): return p != game.player)
	mate = mates[0]
	other = mates[1]


func _line_of(p) -> String:
	for s in game.hud.says:
		if s["p"] == p:
			return String(s["line"])
	return ""


## What p may say for `event`, in their voice and as they stand with the chief.
func _bank_of(p, event: String, name: String = "") -> Array:
	var out: Array = []
	for line in AllyLines.lines_for(event, AllyLines.voice_of(p.pid), String(game.lines.rel_of.get(p.pid, "normal"))):
		out.append(String(line).replace("{이름}", name))
	return out


func test_every_event_has_a_line_and_a_bite_elsewhere_borrows_one() -> void:
	for event in ["hurt", "bite_leg", "grabbed", "rage", "left_behind"]:
		assert_gt(AllyLines.lines_for(event).size(), 0, event)
	assert_eq(AllyLines.lines_for("bite"), AllyLines.lines_for("hurt"))
	assert_eq(AllyLines.lines_for("no_such_thing"), [])


func test_one_person_does_not_shout_again_at_once_nor_the_squad_all_together() -> void:
	var lines := AllyLines.new()
	assert_ne(lines.pick("a", "hurt", 10.0), "")
	assert_eq(lines.pick("a", "grabbed", 12.0), "", "the same person, too soon")
	assert_eq(lines.pick("b", "hurt", 11.0), "", "someone else, on top of the first")
	assert_ne(lines.pick("b", "hurt", 10.0 + AllyLines.GAP_SQUAD + 0.1), "")
	assert_ne(lines.pick("a", "grabbed", 10.0 + AllyLines.GAP_SELF + 0.1), "")


func test_a_bitten_leg_is_shouted_over_the_companion_with_the_note_under_it() -> void:
	game.say(mate, "%s 다리를 물렸다." % mate.display_name, true, "bite_leg")
	assert_eq(game.hud.says.size(), 1, "one entry a person")
	assert_has(_bank_of(mate, "bite_leg"), _line_of(mate))
	assert_eq(String(game.hud.says[0]["text"]), "다리를 물렸다.", "what happened stays, under the line")
	assert_gte(float(game.hud.says[0]["t"]), FieldHud.LINE_S - 0.01)
	game.hud._tick_says(FieldHud.LINE_S + 0.1)
	assert_eq(game.hud.says.size(), 0, "and it goes away")


func test_the_chief_and_the_dead_keep_quiet() -> void:
	game.say(game.player, "열차장 긁혔다.", true, "hurt")
	assert_eq(game.hud.says.size(), 0)
	mate.body.dead = true
	game.shout(mate, "hurt")
	assert_eq(_line_of(mate), "")


func test_grabbed_they_call_for_help() -> void:
	game.shout(mate, "grabbed")
	assert_has(_bank_of(mate, "grabbed"), _line_of(mate))


func test_when_one_falls_the_nearest_companion_rages() -> void:
	mate.position = game.player.position + Vector3(30, 0, 0)
	other.position = mate.position + Vector3(2, 0, 0)
	game.on_person_died(mate)
	assert_has(_bank_of(other, "rage", mate.display_name), _line_of(other))


func test_lying_hurt_with_the_chief_far_off_they_beg_not_to_be_left() -> void:
	mate.body.downed = true
	mate.position = game.player.position + Vector3(AllyLines.LEFT_BEHIND_M - 2.0, 0, 0)
	game._left_behind()
	assert_eq(_line_of(mate), "", "the chief is still near")
	mate.position = game.player.position + Vector3(AllyLines.LEFT_BEHIND_M + 2.0, 0, 0)
	game._left_behind()
	assert_has(_bank_of(mate, "left_behind"), _line_of(mate))
	game.hud.says.clear()
	game.clock.elapsed += AllyLines.GAP_SELF + 1.0
	game._left_behind()
	assert_eq(_line_of(mate), "", "not over and over")
	game.clock.elapsed += AllyLines.LEFT_BEHIND_GAP
	game._left_behind()
	assert_has(_bank_of(mate, "left_behind"), _line_of(mate))


func test_a_person_keeps_one_voice_and_a_name_is_put_in() -> void:
	assert_eq(AllyLines.voice_of("a7"), AllyLines.voice_of("a7"))
	var lines := AllyLines.new()
	for i in 20:
		var line: String = lines.pick("p%d" % i, "ally_down", 10.0 * i, true, "민수")
		assert_false(line.contains("{이름}"), line)
	var nameless := AllyLines.new()
	for i in 20:
		assert_false(nameless.pick("q%d" % i, "ally_down", 10.0 * i, true).contains("{이름}"))


func test_kills_are_said_seldom_and_a_horde_by_one_only() -> void:
	var lines := AllyLines.new()
	assert_ne(lines.pick("a", "kill", 10.0), "")
	assert_eq(lines.pick("a", "kill", 20.0), "", "the same one, ten seconds on")
	assert_ne(lines.pick("a", "kill", 41.0), "")
	assert_ne(lines.pick("b", "horde_near", 50.0), "")
	assert_eq(lines.pick("c", "horde_near", 60.0), "", "someone already said it")


func test_not_the_same_line_twice_running() -> void:
	for rel in AllyLines.RELS:
		var lines := AllyLines.new()
		lines.rel_of["a"] = rel
		var last := ""
		for i in 30:
			var line: String = lines.pick("a", "retreat", 10.0 * i)
			assert_ne(line, last, rel)
			last = line


func test_three_times_the_lines_there_were() -> void:
	assert_gte(AllyLines.count_all(), 3 * LINES_BEFORE)


## An id voice_of gives `voice`.
func _pid_with(voice: String) -> String:
	for i in 100:
		if AllyLines.voice_of("v%d" % i) == voice:
			return "v%d" % i
	return ""


func test_every_voice_and_standing_has_a_line_for_every_moment() -> void:
	var events: Array = AllyLines.VOICED.keys() + AllyLines.LINES.keys()
	for event in events:
		for voice in AllyLines.VOICES:
			for rel in AllyLines.RELS:
				var lines := AllyLines.new()
				var pid: String = _pid_with(voice)
				lines.rel_of[pid] = rel
				assert_ne(lines.pick(pid, event, 10.0, true, "민수"), "", "%s %s %s" % [event, voice, rel])


func test_said_to_the_chief_bad_and_good_sound_nothing_alike() -> void:
	for event in AllyLines.TOWARD_CHIEF:
		var theirs: Array = AllyLines.LINES.get(event, [])
		for voice in AllyLines.VOICES:
			var bad: Array = AllyLines.lines_for(event, voice, "bad").filter(func(l): return not theirs.has(l))
			var good: Array = AllyLines.lines_for(event, voice, "good").filter(func(l): return not theirs.has(l))
			var normal: Array = AllyLines.lines_for(event, voice, "normal")
			assert_false(bad.is_empty() or good.is_empty(), "%s %s" % [event, voice])
			for line in bad:
				assert_false(good.has(line) or normal.has(line), "%s %s: %s" % [event, voice, line])
			for line in good:
				assert_false(normal.has(line), "%s %s: %s" % [event, voice, line])
	# Elsewhere it is mixed in: the scream is the same, the aside is not.
	for event in AllyLines.REL_LINES:
		for voice in AllyLines.VOICES:
			var good2: Array = AllyLines.lines_for(event, voice, "good")
			assert_true(AllyLines.lines_for(event, voice, "bad").any(func(l): return not good2.has(l)), "%s %s" % [event, voice])


func test_how_one_stands_follows_the_train_stages() -> void:
	assert_eq(AllyLines.rel_stage(15.0), "good", "호의")
	assert_eq(AllyLines.rel_stage(14.0), "normal")
	assert_eq(AllyLines.rel_stage(-14.0), "normal", "중립")
	assert_eq(AllyLines.rel_stage(-15.0), "bad", "회의")
	var stages: Array = Tables.load_file("res://tests/game/fixtures/s3/tables_sample.json")["STAGES"]
	for st: Dictionary in stages:
		var band := int(st["band"])
		assert_eq(AllyLines.rel_stage(float(st["min"])), "good" if band > 0 else ("bad" if band < 0 else "normal"), String(st["name"]))


func test_the_squad_stands_as_its_cars_did_when_the_train_set_out() -> void:
	var rel0: Dictionary = Tables.load_file("res://tests/game/fixtures/s3/tables_sample.json")["REL0"]
	for row: Dictionary in game.default_squad("crude"):
		if row.has("comm"):
			assert_eq(float(row["rel"]), float(rel0[row["comm"]]), String(row["id"]))
	var by_id := {}
	for p in game.squad:
		by_id[p.pid] = game.lines.rel_of.get(p.pid, "")
	assert_eq(by_id["p_guard_marek"], "good")
	assert_eq(by_id["p_med_joanna"], "normal")
	assert_eq(by_id["p_tail_tomasz"], "bad")


func test_who_stands_badly_says_their_own_lines() -> void:
	var lines := AllyLines.new()
	lines.rel_of["a"] = "bad"
	var good: Array = AllyLines.lines_for("order_wait", AllyLines.voice_of("a"), "good")
	var bad: Array = AllyLines.lines_for("order_wait", AllyLines.voice_of("a"), "bad")
	for i in 20:
		var line: String = lines.pick("a", "order_wait", 10.0 * i)
		assert_has(bad, line)
		assert_does_not_have(good, line)


func test_an_order_is_answered() -> void:
	game.hud._command(mate, "wait")
	assert_has(_bank_of(mate, "order_wait"), _line_of(mate))
	game.hud.says.clear()
	game.clock.elapsed += AllyLines.GAP_SELF + 1.0
	game.hud._command(mate, "retreat")
	assert_eq(_line_of(mate), "", "the retreat is said as they turn, not here")


func test_a_search_is_begun_and_what_came_of_it_said() -> void:
	var id := ""
	for key in game.data["containers"]:
		var c: Dictionary = game.data["containers"][key]
		if not c["locked"] and not c["searched"] and not c.has("pick"):
			id = key
			break
	game.actions.search(mate, id)
	assert_has(_bank_of(mate, "search_start"), _line_of(mate))
	game.hud.says.clear()
	game.clock.elapsed += AllyLines.GAP_SELF + 1.0
	var had_items: bool = not (game.data["containers"][id]["items"] as Array).is_empty()
	game.actions._searched(mate, id)
	assert_has(_bank_of(mate, "found" if had_items else "empty"), _line_of(mate))


func test_one_treated_by_another_says_so() -> void:
	game.actions._treated(other, mate, other, false)
	assert_has(_bank_of(mate, "treated"), _line_of(mate))


func test_at_the_last_call_the_one_nearest_the_chief_hurries() -> void:
	var held = FieldGame.new()
	held.opts = {"seed": 5, "raiders": false, "auto_pause": false, "holdout": "start"}
	add_child_autofree(held)
	held.set_process(false)
	game = held
	var near = held.squad[1]
	near.position = held.player.position + Vector3(1, 0, 0)
	for o in held.squad:
		if o != held.player and o != near:
			o.position = held.player.position + Vector3(20, 0, 0)
	held.lines._last_any = held.clock.elapsed
	held.depart()
	assert_has(_bank_of(near, "last_call"), _line_of(near), "said even on top of another")


func test_the_dead_at_a_door_are_called_out_once_in_a_while() -> void:
	game.shout_nearest(mate.position, "door_bang", INF)
	assert_has(_bank_of(mate, "door_bang"), _line_of(mate))
	game.hud.says.clear()
	game.clock.elapsed += AllyLines.GAP_SELF + 1.0
	game.shout_nearest(other.position, "door_bang", INF)
	assert_eq(_line_of(other), "", "someone said it just now")
	game.clock.elapsed += float(AllyLines.SQUAD_GAP["door_bang"])
	game.shout_nearest(other.position, "door_bang", INF)
	assert_has(_bank_of(other, "door_bang"), _line_of(other))
