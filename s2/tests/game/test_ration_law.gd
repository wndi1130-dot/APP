extends "res://addons/gut/test.gd"
## The emergency ration law in the field (decision 430): those who come down
## from a train under it tire sooner, and the state row says why.

const FieldGame = preload("res://game/field_game.gd")
const BodyState = preload("res://game/sim/body_state.gd")
const Stamina = preload("res://game/sim/stamina.gd")
const StatusArt = preload("res://game/ui/status_art.gd")


func _game(laws: Array) -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": true, "auto_pause": false, "laws": laws}
	add_child_autofree(game)
	game.set_process(false)
	return game


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
