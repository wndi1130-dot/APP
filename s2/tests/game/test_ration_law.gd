extends "res://addons/gut/test.gd"
## The emergency ration law in the field (decision 430): those who come down
## from a train under it tire sooner, and the state row says why.

const FieldGame = preload("res://game/field_game.gd")
const BodyState = preload("res://game/sim/body_state.gd")
const Stamina = preload("res://game/sim/stamina.gd")
const StatusArt = preload("res://game/ui/status_art.gd")
const FieldWork = preload("res://game/field_work.gd")


func _game(laws: Array) -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": true, "auto_pause": false, "laws": laws}
	add_child_autofree(game)
	game.set_process(false)
	return game


## Decision 486: at a clear site the first press has the train offer, the second sends the
## escort, and the carriers follow FieldWork.ESCORT_LEAD later.
func _call_crew(game) -> void:
	var at: Vector3 = game.player.position
	game.player.position = game.work.position_of("work_site")
	game.actions.start_work(game.player)
	game.actions.start_work(game.player)
	game.player.position = at
	game.work.update(FieldWork.ESCORT_LEAD)


func test_the_value_is_the_listed_one() -> void:
	assert_almost_eq(Stamina.RATION_CUT_STAMINA, 0.85, 0.0001, "decision 430's starting point: stamina 15% short")


func test_an_underfed_body_tires_sooner_and_runs_out_of_breath_sooner() -> void:
	var fed := BodyState.new()
	var cut := BodyState.new()
	cut.ration_cut = true
	for b: BodyState in [fed, cut]:
		b.exhaustion = Stamina.FATIGUE_LIGHT * 0.9
	assert_eq(fed.exhaustion_level(), 0)
	assert_eq(cut.exhaustion_level(), 1, "tired at 85% of what tires a fed body")
	for b: BodyState in [fed, cut]:
		b.exhaustion = Stamina.FATIGUE_HEAVY * 0.9
	assert_eq(fed.exhaustion_level(), 1)
	assert_eq(cut.exhaustion_level(), 2)
	# Breath: rested, it comes back to 85% of a full chest, so a sprint ends sooner.
	var sprint := {}
	for b: BodyState in [fed, cut]:
		b.exhaustion = 0.0
		b.breath = 1.0
		b.tick(0.1, {})
		var t := 0.0
		while b.can_run() and t < 60.0:
			b.tick(0.1, {"running": true})
			t += 0.1
		sprint[b] = t
	assert_almost_eq(cut.breath, Stamina.RUN_BREATH_MIN, 0.02)
	assert_almost_eq(float(sprint[cut]) / float(sprint[fed]), (0.85 - Stamina.RUN_BREATH_MIN) / (1.0 - Stamina.RUN_BREATH_MIN), 0.03, "the sprint is that much shorter")
	cut.breath_locked = false
	for i in 200:
		cut.tick(0.1, {})
	assert_almost_eq(cut.breath, 0.85, 0.0001, "never more than its share back")


func test_the_state_row_shows_the_law_and_why() -> void:
	var b := BodyState.new()
	assert_false(b.icons().any(func(i: Dictionary) -> bool: return i["id"] == "ration"))
	b.ration_cut = true
	b.exhaustion = Stamina.FATIGUE_LIGHT
	var ids: Array = b.icons().map(func(i: Dictionary) -> String: return String(i["id"]))
	assert_eq(ids, ["exhaustion", "ration"], "after what hurts now")
	var row: Dictionary = b.status_notes()[1]
	assert_eq(row["title"], "비상식량감축법")
	assert_string_contains(String(row["text"]), "빨리 지친다")
	assert_not_null(StatusArt.texture("ration", false, false, 80), "a picture of its own")


func test_only_those_from_the_train_carry_the_law() -> void:
	var game = _game(["emergency_ration"])
	for p in game.squad:
		assert_true(p.body.ration_cut, p.pid)
	var raiders: Array = game.people.filter(func(q) -> bool: return q.team == "raider")
	assert_false(raiders.is_empty())
	for r in raiders:
		assert_false(r.body.ration_cut, "a raider eats as it eats")
	var worker = game.make_person({"id": "s2_crew_09", "name": "운송조", "role": "worker", "hands": []}, game.player.position)
	assert_true(worker.body.ration_cut, "the work crew is the train's too")
	var lawless = _game([])
	for p in lawless.squad:
		assert_false(p.body.ration_cut, "no law, nothing short")


func test_the_crews_haul_is_the_laws_value_in_the_train_tables() -> void:
	# Decision 430 ②, card domestic Q1 가: one value with S1 data.ts (LAWS_RES).
	var f := FileAccess.open("res://tests/fixtures/train/train_vectors.json", FileAccess.READ)
	var tables: Dictionary = JSON.parse_string(f.get_as_text())["tables"]
	assert_almost_eq(FieldGame.RATION_HAUL, float(tables["LAWS_RES"]["emergency_ration"]["haulMult"]), 0.0001)
	assert_eq(_game([]).haul_mult(), 1.0, "no law, the trip as it was")
	assert_almost_eq(_game(["emergency_ration"]).haul_mult(), 0.8, 0.0001)


func test_under_the_law_a_carrier_takes_less_coal_a_trip() -> void:
	var loads := []
	for laws: Array in [[], ["emergency_ration"]]:
		var game = _game(laws)
		game.zombies.list.clear()
		_call_crew(game)
		assert_true(game.actions.work_started)
		var w: Dictionary = game.ai._wagon_with_coal()
		assert_false(w.is_empty(), "a wagon to dig")
		var worker = game.crew.filter(func(q) -> bool: return q.role == "worker")[0]
		game.ai._dug(worker)
		loads.append(float(worker.brain["load"]))
	assert_almost_eq(loads[1], loads[0] * 0.8, 0.0001, "a fifth less a trip")


func test_the_crews_chip_and_the_work_pane_show_the_law_and_why() -> void:
	var game = _game(["emergency_ration"])
	game.zombies.list.clear()
	_call_crew(game)
	game.hud._tick_allies()
	assert_not_null(game.hud.crew_button.icon, "the law's picture on the crew's chip")
	game.hud.work_panel()
	var why: Node = game.hud.modal.find_child("RationHaul", true, false)
	assert_not_null(why)
	var text := ""
	for l in why.find_children("*", "Label", true, false):
		text += String(l.text)
	assert_true(text.replace(game.hud.UiFonts.WORD_JOINER, "").contains("20% 덜 나른다"), text)
	game.hud._close_modal()
	var plain = _game([])
	plain.zombies.list.clear()
	_call_crew(plain)
	plain.hud._tick_allies()
	assert_null(plain.hud.crew_button.icon, "no law, no picture")
