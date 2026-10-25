extends GutTest
## J05: a bitten or scratched arm or leg can be cut off in the field
## (body_injury 2.2, decisions.md 「물리면 절단」·「절단은 확률이 아니다」): what
## it takes, how long, why not, what is left after, that it always stops the
## infection inside the window, and the body picture that offers it.

const Amputation = preload("res://game/sim/amputation.gd")
const BodyState = preload("res://game/sim/body_state.gd")
const Person = preload("res://game/actors/person.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const Stamina = preload("res://game/sim/stamina.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


func _person(pid: String = "p_cut", name_text: String = "자름") -> Node3D:
	var p := Person.new()
	add_child_autofree(p)
	p.setup(pid, name_text, "companion", Vector3.ZERO)
	return p


func _bitten(part: String) -> Node3D:
	var p := _person()
	p.body.apply_bite(RandomNumberGenerator.new(), part, 0.0)
	return p


func _blade(p, wid: String = "axe") -> void:
	p.hands = [{"id": wid, "quality": "factory", "condition": 1.0, "loaded": 0}]


func _why(medic, o, part: String, have: Dictionary) -> String:
	return String(Amputation.plan(medic, o, part, have)["why"])


# ---------------------------------------------------------------- the plan

func test_what_a_cut_takes_and_why_not() -> void:
	var o := _bitten("arm_left")
	var have := {}
	assert_eq(_why(o, o, "arm_left", have), "칼이나 손도끼 없음")
	_blade(o, "knife")
	assert_eq(_why(o, o, "arm_left", have), "지혈대 없음(천과 판자)")
	have = {"cloth": 1, "plank": 1}
	var plan: Dictionary = Amputation.plan(o, o, "arm_left", have)
	assert_true(plan["ok"])
	assert_eq(plan["uses"], {"cloth": 1, "plank": 1}, "a tourniquet made on the spot")
	assert_almost_eq(float(plan["seconds"]), 20.0, 0.001, "no medical knowledge: 20 s")
	assert_eq(Amputation.plan_text(plan), "칼 · 지혈대(천+판자) · 20초 · 비명이 온 지도에 들린다")
	have = {"tourniquet": 1, "medkit": 1}
	plan = Amputation.plan(o, o, "arm_left", have)
	assert_eq(plan["uses"], {"tourniquet": 1, "medkit": 1})
	assert_true(plan["kit"])
	assert_eq(Amputation.plan_text(plan), "칼 · 지혈대 · 구급함 · 20초 · 비명이 온 지도에 들린다")
	assert_eq(_why(o, o, "torso", have), "팔이나 다리만 자를 수 있다")
	assert_eq(_why(o, o, "leg_left", have), "자를 까닭이 없다", "nothing there to cut for")
	o.body.window_left = 15.0
	assert_eq(_why(o, o, "arm_left", have), "창이 15초 남아 다 자르기 전에 닫힌다", "20 s of work in a window of 15")
	o.body.window_left = 0.0
	assert_eq(_why(o, o, "arm_left", have), "감염 창이 닫혀 소용없다")
	for row in [["none", 20.0], ["apprentice", 16.0], ["skilled", 12.0], ["master", 8.0]]:
		assert_almost_eq(Amputation.seconds(String(row[0])), float(row[1]), 0.001)


func test_a_blade_in_either_ones_hands_does() -> void:
	var o := _bitten("leg_right")
	var medic := _person("p_medic", "의사")
	var have := {"tourniquet": 1}
	assert_eq(_why(medic, o, "leg_right", have), "칼이나 손도끼 없음")
	_blade(o, "axe")
	assert_eq(String(Amputation.plan(medic, o, "leg_right", have)["blade"]), "axe", "the one bitten carries the hatchet")
	medic.hands = [{"id": "crowbar", "quality": "factory", "condition": 1.0, "loaded": 0}]
	assert_eq(String(Amputation.plan(medic, o, "leg_right", have)["blade"]), "axe", "a crowbar is no blade")
	medic.medical = "master"
	assert_almost_eq(float(Amputation.plan(medic, o, "leg_right", have)["seconds"]), 8.0, 0.001, "a master's hands")


func test_a_bite_where_no_cut_reaches_says_so() -> void:
	var o := _bitten("arm_left")
	_blade(o)
	o.body.apply_bite(RandomNumberGenerator.new(), "torso", 1.0)
	assert_eq(_why(o, o, "arm_left", {"tourniquet": 1}), "몸통도 물려 잘라도 막지 못한다")
	var neck := _bitten("arm_right")
	_blade(neck)
	neck.body.apply_bite(RandomNumberGenerator.new(), "head_neck", 1.0)
	assert_eq(_why(neck, neck, "arm_right", {"tourniquet": 1}), "머리·목도 물려 잘라도 막지 못한다", "결정 441: the neck too")
	var two := _bitten("arm_left")
	_blade(two)
	two.body.apply_bite(RandomNumberGenerator.new(), "leg_right", 1.0)
	var plan: Dictionary = Amputation.plan(two, two, "arm_left", {"tourniquet": 1})
	assert_true(plan["ok"], "each bitten limb can go")
	assert_eq(plan["also"], ["leg_right"], "the other one must go too")


func test_the_shock_by_hands_strength_and_kit() -> void:
	assert_almost_eq(Amputation.shock_chance("none", 5, false), 0.15, 0.0001)
	assert_almost_eq(Amputation.shock_chance("none", 7, false), 0.075, 0.0001, "a strong body: half")
	assert_almost_eq(Amputation.shock_chance("none", 5, true), 0.075, 0.0001, "a medkit: half")
	assert_almost_eq(Amputation.shock_chance("master", 8, true), 0.005, 0.0001)
	assert_eq(Amputation.stump_kind("apprentice"), "deep")
	assert_eq(Amputation.stump_kind("skilled"), "laceration")


# ---------------------------------------------------------------- the body after

func test_a_cut_in_time_always_stops_the_bite() -> void:
	var o := _bitten("arm_left")
	o.body.apply_scratch(RandomNumberGenerator.new(), 1.0, "arm_left")
	assert_eq(o.body.infection, "bite")
	var saved: bool = o.body.amputate("arm_left", "deep", 10.0)
	assert_true(saved)
	assert_eq(o.body.infection, "")
	assert_false(o.body.infected)
	assert_almost_eq(o.body.window_left, 0.0, 0.0001, "nothing left to count down")
	assert_eq(o.body.lost, ["arm_left"] as Array[String])
	var on_arm: Array = o.body.wounds.filter(func(w): return w["part"] == "arm_left")
	assert_eq(on_arm.size(), 1, "the arm's wounds go with it; the stump is left")
	assert_eq(String(on_arm[0]["kind"]), "deep")
	assert_true(bool(on_arm[0]["stump"]))
	assert_true(bool(on_arm[0]["tourniquet"]), "the tourniquet the cut was made under stays on")
	assert_almost_eq(float(on_arm[0]["blood"]), BodyState.SEEP_BLOOD, 0.0001, "it seeps under the tourniquet")
	assert_eq(o.body.bleed_level(), 1)
	assert_gte(o.body.exhaustion, Stamina.FATIGUE_HEAVY, "spent after it, whoever it is")
	assert_true(bool(o.mults()["one_hand"]), "one arm: one-handed weapons only")
	assert_eq(o.body.status_words(), "한 손")


func test_a_bite_elsewhere_or_a_closed_window_is_not_stopped() -> void:
	var o := _bitten("arm_left")
	o.body.apply_bite(RandomNumberGenerator.new(), "leg_right", 1.0)
	assert_false(o.body.amputate("arm_left", "deep", 2.0), "the leg is bitten too")
	assert_true(o.body.infected)
	assert_eq(o.body.infection, "bite")
	assert_true(o.body.amputate("leg_right", "deep", 3.0), "both gone in time: saved")
	var late := _bitten("leg_right")
	late.body.window_left = 0.0
	assert_false(late.body.amputate("leg_right", "laceration", 600.0), "too late: the limb is gone for nothing")
	assert_true(late.body.infected)
	assert_eq(late.body.lost, ["leg_right"] as Array[String])


func test_scratches_by_which_one_held_it() -> void:
	var o := _person()
	var rng := RandomNumberGenerator.new()
	o.body.apply_scratch(rng, 0.0, "arm_right")
	o.body.wounds[0]["infects"] = true
	o.body.infected = true
	o.body.apply_scratch(rng, 1.0, "torso")
	o.body.wounds[1]["infects"] = false
	assert_true(o.body.amputate("arm_right", "laceration", 2.0), "the infected scratch went with the arm")
	assert_false(o.body.infected)
	assert_eq(o.body.infection, "scratch", "the other scratch's window runs on (not knowing)")
	assert_gt(o.body.window_left, 0.0)


func test_a_lost_leg_crawls_and_cannot_run() -> void:
	var o := _bitten("leg_left")
	o.body.amputate("leg_left", "laceration", 1.0)
	o.body.exhaustion = 0.0
	assert_false(o.body.can_run())
	assert_almost_eq(float(o.mults()["move"]), BodyState.MOVE_FLOOR, 0.0001, "it drags itself, as on a broken leg")
	assert_eq(o.body.status_words(), "못 걸음")
	var notes: Array = o.body.status_notes()
	var lost: Array = notes.filter(func(r): return r["id"] == "lost")
	assert_eq(lost.size(), 1)
	assert_eq(String(lost[0]["title"]), "잘린 왼다리")
	assert_eq(String(lost[0]["text"]), "기어간다. 뛰지 못한다")


func test_nothing_lands_where_a_limb_was_cut_off() -> void:
	var o := _bitten("arm_left")
	o.body.amputate("arm_left", "deep", 1.0)
	var rng := RandomNumberGenerator.new()
	o.body.apply_bite(rng, "arm_left", 2.0)
	assert_eq(String(o.body.wounds[-1]["part"]), "arm_right", "the bite takes the arm still there")
	o.body.amputate("arm_right", "deep", 3.0)
	o.body.apply_scratch(rng, 4.0, "arm")
	assert_eq(String(o.body.wounds[-1]["part"]), "torso", "no arms left: the torso")
	var before: int = o.body.wounds.size()
	o.body.fracture(true)
	assert_eq(o.body.wounds.size(), before, "no arm to break")


func test_the_window_says_what_to_cut() -> void:
	var o := _bitten("arm_left")
	var row: Dictionary = o.body.status_notes()[0]
	assert_eq(String(row["id"]), "infection")
	assert_eq(String(row["text"]), "감염 창이 8분 00초 남았다. 닫히기 전에 정해야 한다: 왼팔을 자르면 막는다")
	o.body.apply_bite(RandomNumberGenerator.new(), "leg_right", 1.0)
	assert_eq(String(o.body.status_notes()[0]["text"]), "감염 창이 8분 00초 남았다. 닫히기 전에 정해야 한다: 왼팔·오른다리를 자르면 막는다")
	var scratched := _person()
	scratched.body.apply_scratch(RandomNumberGenerator.new(), 0.0, "arm_right")
	assert_eq(String(scratched.body.status_notes()[0]["text"]), "감염됐는지 아직 모른다. 창이 끝나야 안다. 오른팔을 자르면 감염이어도 막는다")


## 결정 441 (4): a bite no cut reaches says why and how long until the fever,
## with nothing to decide; 「정해야 한다」 is for an arm or a leg.
func test_a_bite_no_cut_reaches_says_why_and_how_long() -> void:
	var torso := _bitten("torso")
	assert_eq(String(torso.body.status_notes()[0]["text"]), "몸통이라 자를 수 없다. 열이 오르기까지 8분 00초")
	var neck := _bitten("head_neck")
	assert_eq(String(neck.body.status_notes()[0]["text"]), "머리·목이라 자를 수 없다. 열이 오르기까지 8분 00초")
	var both := _bitten("arm_left")
	both.body.apply_bite(RandomNumberGenerator.new(), "torso", 1.0)
	assert_eq(String(both.body.status_notes()[0]["text"]), "몸통이라 자를 수 없다. 열이 오르기까지 8분 00초", "the arm would not save it")
	var scratched := _person()
	scratched.body.apply_scratch(RandomNumberGenerator.new(), 0.0, "torso")
	assert_eq(String(scratched.body.status_notes()[0]["text"]), "감염됐는지 아직 모른다. 몸통이라 자를 수 없다. 8분 00초 뒤 창이 끝나면 안다")
	var mixed := _bitten("arm_right")
	mixed.body.apply_scratch(RandomNumberGenerator.new(), 1.0, "torso")
	assert_eq(String(mixed.body.status_notes()[0]["text"]), "감염 창이 8분 00초 남았다. 닫히기 전에 정해야 한다: 오른팔을 자르면 막는다. 몸통 긁힘은 자를 수 없다")


func test_a_clean_scratch_leaves_nothing_to_cut_for() -> void:
	var o := _person()
	_blade(o)
	o.body.apply_scratch(RandomNumberGenerator.new(), 0.0, "arm_right")
	o.body.wounds[0]["infects"] = false
	o.body.infected = false
	assert_true(o.body.at_risk_on("arm_right"))
	o.body.tick(BodyState.WINDOW + 1.0, {})
	assert_eq(o.body.infection, "")
	assert_false(o.body.at_risk_on("arm_right"), "the window closed clean")
	assert_eq(_why(o, o, "arm_right", {"tourniquet": 1}), "자를 까닭이 없다")


# ---------------------------------------------------------------- in the field

func _field():
	var game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.player.position = game.lift(Vector2i(60, 7), 0)
	for q in game.squad:
		if q != game.player:
			q.position = game.lift(Vector2i(30, 7), 0)
	game.player.items = {}
	return game


func _mate(game):
	for q in game.squad:
		if q != game.player:
			q.position = game.player.position + Vector3(1.0, 0, 0)
			q.items = {}
			return q
	return null


func _step_all(game, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		for q in game.squad:
			game._update_person(q, 0.05)
		t += 0.05


func test_the_cut_from_the_body_picture() -> void:
	var game = _field()
	var p = game.player
	var o = _mate(game)
	o.body.apply_bite(RandomNumberGenerator.new(), "arm_left", game.clock.elapsed)
	_blade(p, "axe")
	p.add_item("cloth", 1)
	p.add_item("plank", 1)
	var hud = game.hud
	hud.body_panel(o, "arm_left")
	assert_false(hud.body_cut.is_empty(), "the bitten arm offers the cut")
	var key: Button = hud.body_cut["key"]
	assert_false(key.disabled)
	assert_true(String(Amputation.plan_text(hud.body_cut["plan"])).begins_with("손도끼 · 지혈대(천+판자)"))
	key.pressed.emit()
	assert_eq(p.action, "", "the first press only asks")
	assert_eq(key.text, "한 번 더 누르면 자른다")
	var heard: int = game.sounds.size()
	key.pressed.emit()
	assert_eq(p.action, "treat")
	assert_eq(p.action_label, "절단")
	assert_eq(game.sounds.size(), heard + 1, "the scream")
	assert_eq(int(game.sounds[-1]["level"]), SimNoise.Level.VERY_LOUD)
	assert_eq(String(game.sounds[-1]["tag"]), "scream")
	_step_all(game, 60.0)
	assert_eq(p.action, "")
	assert_eq(o.body.lost, ["arm_left"] as Array[String], "cut off, whether the shock was borne or not")
	assert_eq(o.body.infection, "", "and the bite stopped")
	assert_false(p.items.has("cloth") or p.items.has("plank"), "the tourniquet was made of them")
	assert_true(p.blood_soaked and o.blood_soaked, "the blood of it on both")
	assert_eq(String(hud.body_looks(o, "torso")["arm_left"]["kinds"][0]), "잘림")


func test_the_torso_shows_why_and_no_key() -> void:
	var game = _field()
	var o = _mate(game)
	o.body.apply_bite(RandomNumberGenerator.new(), "torso", game.clock.elapsed)
	_blade(game.player, "axe")
	game.player.add_item("tourniquet", 1)
	var hud = game.hud
	hud.body_panel(o, "torso")
	assert_true(hud.body_cut.is_empty(), "no key to cut the torso")
	var said: Array = []
	for n in hud.modal.find_children("*", "Label", true, false):
		said.append(String(n.text).replace(UiFonts.WORD_JOINER, ""))
	assert_true(said.any(func(t): return t.begins_with("자를 수 없다 · 열이 오르기까지")), "why, and how long")
	hud.body_panel(o, "arm_left")
	assert_true(hud.body_cut.is_empty(), "an arm not bitten has nothing to cut for")


func test_the_cut_is_for_nothing_if_the_one_cut_is_taken_off() -> void:
	var game = _field()
	var p = game.player
	var o = _mate(game)
	o.body.apply_bite(RandomNumberGenerator.new(), "leg_left", game.clock.elapsed)
	_blade(o, "knife")
	p.add_item("tourniquet", 1)
	assert_true(game.actions.amputate(p, o, "leg_left"))
	o.position += Vector3(6.0, 0, 0)
	_step_all(game, 40.0)
	assert_true(o.body.lost.is_empty(), "too far to finish it")
	assert_eq(int(p.items.get("tourniquet", 0)), 1, "nothing used")
	assert_eq(o.body.infection, "bite")


func test_the_shock_can_kill_or_be_borne() -> void:
	var game = _field()
	var p = game.player
	var o = _mate(game)
	_blade(p)
	p.add_item("tourniquet", 2)
	p.medical = "none"
	o.skills["strength"] = 5
	# Seeds whose first roll lies under and over the shock: the one roll the cut takes.
	var low := -1
	var high := -1
	for s in range(1, 400):
		var r := RandomNumberGenerator.new()
		r.seed = s
		var x: float = r.randf()
		if low < 0 and x < 0.01:
			low = s
		if high < 0 and x > 0.5:
			high = s
	assert_true(low > 0 and high > 0)
	o.body.apply_bite(RandomNumberGenerator.new(), "arm_right", game.clock.elapsed)
	game.rng.seed = high
	game.actions._amputated(p, o, "arm_right")
	assert_true(o.is_alive(), "borne")
	o.body.apply_bite(RandomNumberGenerator.new(), "arm_left", game.clock.elapsed)
	game.rng.seed = low
	game.actions._amputated(p, o, "arm_left")
	assert_false(o.is_alive(), "15% with no medical knowledge: the shock killed")


func test_a_cut_body_comes_back_from_a_save() -> void:
	var a = FieldGame.new()
	a.opts = {"seed": 4, "auto_pause": false}
	a.map_script = BareLine
	add_child_autofree(a)
	a.set_process(false)
	var p = a.player
	p.body.apply_bite(RandomNumberGenerator.new(), "leg_right", 0.0)
	p.body.apply_bite(RandomNumberGenerator.new(), "arm_left", 0.0)
	p.body.amputate("leg_right", "deep", 5.0)
	p.body.window_left = 300.0
	var d := FieldSave.from_json(FieldSave.to_json(FieldSave.capture(a)))
	var b = FieldGame.new()
	var opts: Dictionary = FieldSave.resume_opts(d)
	opts.merge({"seed": 4, "auto_pause": false}, false)
	b.opts = opts
	b.map_script = BareLine
	add_child_autofree(b)
	b.set_process(false)
	var q = b.player
	assert_eq(q.body.lost, ["leg_right"] as Array[String], "the leg stays cut off")
	assert_almost_eq(q.body.window_left, 300.0, 0.01, "the window runs on where it was (it used to read as closed)")
	assert_true(q.body.at_risk_on("arm_left"), "the arm can still be cut")
	assert_almost_eq(float(q.mults()["move"]), BodyState.MOVE_FLOOR, 0.0001)
