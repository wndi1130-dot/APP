extends GutTest
## Decision 422, first round: the living's new motions are picked from what the
## rules already know (how high a container is, which leg hurts, whose wound is
## seen to, where a bite came from, how the body is), and a folder without them
## draws exactly as before. That every map's containers have a height is checked
## where every map is built (test_all_maps_open.gd).

const PersonVisual = preload("res://game/actors/person_visual.gd")
const Person = preload("res://game/actors/person.gd")
const SearchHeight = preload("res://game/actors/search_height.gd")
const FieldGame = preload("res://game/field_game.gd")
const Pose = preload("res://game/actors/person_pose.gd")
const Stamina = preload("res://game/sim/stamina.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")

const OLD: Array = ["p_walk", "p_run", "p_stand", "p_crouch_walk", "p_crouch_idle", "p_bitten",
	"p_search_mid", "p_search_low", "p_kneel_work", "p_treat", "p_pry"]
const NEW: Array = ["p_search_high", "p_limp_heavy_l", "p_limp_heavy_r", "p_limp_light",
	"p_treat_head", "p_treat_arm", "p_treat_leg", "p_bitten_front", "p_bitten_back",
	"p_shiver", "p_pain_head", "p_pain_torso", "p_pain_arm", "p_pain_leg", "p_tired_stretch"]


class Held:
	extends RefCounted
	var grab_left: float = 1.0
	var grabbers: Array = []


func before_each() -> void:
	DeadBody.rounds = {}
	DeadBody.table = []
	DeadBody.named = {}


func after_all() -> void:
	DeadBody.table = []
	DeadBody.named = {}


func _own(names: Array) -> Array:
	var own: Array = []
	for n: String in names:
		own.append({"name": n, "length": 2.0, "round": 1.2})
	return own


func _named(own: Array, c: Vector2) -> String:
	return String(own[int(c.y)].get("name", "")) if c.y >= 0.0 else ""


func _person() -> Node3D:
	var p := Person.new()
	add_child_autofree(p)
	p.setup("p_test", "시험", "companion", Vector3.ZERO)
	return p


func _working(p, action: String, busy: Dictionary = {}) -> void:
	p.action = action
	p.action_label = "일"
	p.action_t = 2.0
	p.action_total = 4.0
	p.action_busy = busy


func _walked(p, own: Array) -> String:
	var note := {}
	PersonVisual.motion_of(p, note, 0.05, [], own)
	p.position += Vector3(0.1, 0, 0)
	return _named(own, PersonVisual.motion_of(p, note, 0.05, [], own))


func test_a_container_is_searched_at_its_height() -> void:
	assert_eq(SearchHeight.clip_of({"name": "매점 선반"}), "p_search_high")
	assert_eq(SearchHeight.clip_of({"name": "주택 다락 상자"}), "p_search_low")
	assert_eq(SearchHeight.clip_of({"name": "문서 묶음"}), "p_kneel_work")
	assert_eq(SearchHeight.clip_of({"name": "역무실 책상"}), "p_search_mid")
	assert_eq(SearchHeight.clip_of({"name": "처음 보는 것"}), "p_search_mid", "a kind not in the table: chest height")
	var own := _own(OLD + NEW)
	var p := _person()
	for want in [["매점 선반", "p_search_high"], ["주택 다락 상자", "p_search_low"], ["문서 묶음", "p_kneel_work"], ["역무실 책상", "p_search_mid"]]:
		_working(p, "search", {"name": want[0]})
		assert_eq(_named(own, PersonVisual.work_of(p, {}, 1.0, own)), want[1], want[0])
	p.crouched = true
	_working(p, "search", {"name": "매점 선반"})
	assert_eq(_named(own, PersonVisual.work_of(p, {}, 1.0, own)), "p_search_low", "crouched it keeps low")
	p.crouched = false
	var old := _own(OLD)
	assert_eq(_named(old, PersonVisual.work_of(p, {}, 1.0, old)), "p_search_mid", "a folder without it: as before")
	_working(p, "search", {"name": "문서 묶음"})
	assert_eq(_named(_own(["p_search_mid"]), PersonVisual.work_of(p, {}, 1.0, _own(["p_search_mid"]))), "p_search_mid")


func test_a_leg_that_hurts_limps_on_its_side() -> void:
	var own := _own(OLD + NEW)
	var p := _person()
	assert_eq(_walked(p, own), "p_walk")
	p.body.add_wound("leg_left", "deep", 1.0)
	assert_eq(_walked(p, own), "p_limp_heavy_l", "cut deep, on its own side")
	var q := _person()
	q.body.add_wound("leg_right", "laceration", 1.0)
	assert_eq(_walked(q, own), "p_limp_light", "lightly cut: one for both sides")
	var r := _person()
	r.body.add_wound("leg_right", "fracture", 1.0)
	assert_eq(_walked(r, own), "p_walk", "broken and not splinted: as before")
	r.body.wounds[0]["splinted"] = true
	assert_eq(_walked(r, own), "p_limp_heavy_r", "splinted")
	# A splinted leg cannot run (body_state.gd can_run): with the run on it goes
	# at a walk, so it limps on (gait.gd runs). One that can run does not limp.
	r.running = true
	assert_eq(_walked(r, own), "p_limp_heavy_r", "the run on but the leg cannot: it limps at a walk")
	q.running = true
	assert_ne(_walked(q, own).begins_with("p_limp"), true, "running it does not limp")
	var arm := _person()
	arm.body.add_wound("arm_left", "deep", 1.0)
	assert_eq(_walked(arm, own), "p_walk", "an arm does not limp")
	assert_eq(_walked(p, _own(OLD)), "p_walk", "a folder without them: as before")


func test_a_wound_is_treated_where_it_is_and_someone_else_knelt_by() -> void:
	var own := _own(OLD + NEW)
	var p := _person()
	p.body.add_wound("arm_right", "laceration", 1.0)
	_working(p, "treat")
	assert_eq(_named(own, PersonVisual.work_of(p, {}, 1.0, own)), "p_treat_arm", "its own worst wound")
	p.set_meta(Pose.CARE, {"of": p, "part": "leg_left", "total": 4.0, "label": "일"})
	assert_eq(_named(own, PersonVisual.work_of(p, {}, 1.0, own)), "p_treat_leg", "the wound being seen to")
	p.set_meta(Pose.CARE, {"of": p, "part": "head_neck", "total": 4.0, "label": "일"})
	assert_eq(_named(own, PersonVisual.work_of(p, {}, 1.0, own)), "p_treat_head")
	var other := _person()
	p.set_meta(Pose.CARE, {"of": other, "part": "leg_left", "total": 4.0, "label": "일"})
	assert_eq(_named(own, PersonVisual.work_of(p, {}, 1.0, own)), "p_kneel_work", "someone else's: knelt by")
	p.set_meta(Pose.CARE, {"of": other, "part": "leg_left", "total": 6.0, "label": "다른 일"})
	assert_eq(_named(own, PersonVisual.work_of(p, {}, 1.0, own)), "p_treat_arm", "a note from an earlier job is not read")
	p.remove_meta(Pose.CARE)
	assert_eq(_named(_own(OLD), PersonVisual.work_of(p, {}, 1.0, _own(OLD))), "p_treat", "a folder without them: as before")


func test_the_treatment_notes_whom_it_is_for() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	var medic = game.player
	var o = null
	for q in game.squad:
		if q != medic:
			o = q
			break
	assert_not_null(o, "someone to treat")
	o.position = medic.position + Vector3(0.5, 0, 0)
	o.body.add_wound("arm_left", "laceration", 1.0)
	medic.items["bandage"] = 2
	medic.action = ""
	game.actions.treat(medic, o)
	assert_eq(medic.action, "treat")
	var care: Dictionary = medic.get_meta(Pose.CARE, {})
	assert_eq(care.get("of"), o)
	assert_almost_eq(float(care.get("total", 0.0)), medic.action_total, 0.001)
	assert_eq(String(care.get("label", "")), medic.action_label)


func test_a_flinch_from_in_front_or_behind_has_its_own() -> void:
	assert_eq(PersonVisual.bitten_name({"hurt_from": Vector2(0.1, 0.9)}), "p_bitten_front")
	assert_eq(PersonVisual.bitten_name({"hurt_from": Vector2(0.2, -0.8)}), "p_bitten_back")
	assert_eq(PersonVisual.bitten_name({"hurt_from": Vector2(0.9, 0.2)}), "", "from the side: the old one")
	assert_eq(PersonVisual.bitten_name({}), "p_bitten_front", "nothing holding it: from in front")
	var own := _own(OLD + NEW)
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.05, [], own)
	p.body.add_wound("arm_left", "bite", 1.0)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.05, [], own)), "p_bitten_front")
	assert_eq(String(note.get("hurt_own", "")), "p_bitten_front", "the lean leaves the throw to it")
	var old := _own(OLD)
	var q := _person()
	var n2 := {}
	PersonVisual.motion_of(q, n2, 0.05, [], old)
	q.body.add_wound("arm_left", "bite", 1.0)
	assert_eq(_named(old, PersonVisual.motion_of(q, n2, 0.05, [], old)), "p_bitten", "a folder without them: as before")


func test_standing_still_the_body_now_and_then_shows_how_it_is() -> void:
	var own := _own(OLD + NEW)
	var p := _person()
	var unit: float = p.name_unit("mood")
	var every := lerpf(PersonVisual.MOOD_EVERY.x, PersonVisual.MOOD_EVERY.y, unit)
	# A time when it shows, and one when it does not.
	var on := every - fposmod(unit * every, every) + 0.5
	var off := on + 2.5
	assert_eq(PersonVisual.mood_of(p, {}, on, own).y, -1.0, "nothing to show")
	p.body.exhaustion = Stamina.FATIGUE_LIGHT
	assert_eq(_named(own, PersonVisual.mood_of(p, {}, on, own)), "p_tired_stretch")
	assert_almost_eq(PersonVisual.mood_of(p, {}, on, own).x, 0.25, 0.001, "half a second into two")
	assert_eq(PersonVisual.mood_of(p, {}, off, own).y, -1.0, "the rest of the time it stands")
	p.heat.heat = 50.0
	assert_eq(_named(own, PersonVisual.mood_of(p, {}, on, own)), "p_shiver", "cold before tired")
	p.body.add_wound("torso", "laceration", 1.0)
	assert_eq(_named(own, PersonVisual.mood_of(p, {}, on, own)), "p_pain_torso", "hurting before cold")
	p.crouched = true
	assert_eq(PersonVisual.mood_of(p, {}, on, own).y, -1.0, "crouched it keeps still")
	p.crouched = false
	assert_eq(PersonVisual.mood_of(p, {}, on, _own(OLD)).y, -1.0, "a folder without them: as before")
	# Two people do not show it at the same time.
	var q := _person()
	q.display_name = "다른 사람"
	assert_ne(q.name_unit("mood"), unit)
	# Through motion_of: standing still it is shown; moving it is not.
	var note := {}
	note["t"] = on - 0.3
	PersonVisual.motion_of(p, note, 0.05, [], own)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.25, [], own)), "p_pain_torso")


func test_the_first_of_the_dead_holding_someone_bites_as_the_hold_runs_out() -> void:
	DeadBody.table = []
	for i in 29:
		DeadBody.table.append([i * 32, 32, true, 1.0])
	DeadBody.named = {"bite": 27, "bite_miss": 28}
	var z := {"state": "grab", "phase": 0.3, "crawl": false, "age": 5.0, "pos": Vector3.ZERO, "angle": 0.0, "t": 0.0}
	var held := Held.new()
	held.grabbers = [z]
	z["victim"] = held
	held.grab_left = 1.0
	assert_eq(DeadBody.motion_in(DeadBody.custom(z, 0.0, 0.0, 1.0, true).g), DeadBody.LUNGE, "holding on")
	held.grab_left = 0.25
	var c := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_eq(DeadBody.motion_in(c.g), 27, "bending to them")
	assert_almost_eq(c.r, 0.25, 0.001)
	held.grab_left = 0.0
	assert_almost_eq(DeadBody.custom(z, 0.0, 0.0, 1.0, true).r, DeadBody.BITE_LANDS, 0.001, "the teeth go in as the bite lands")
	var second := {"state": "grab", "phase": 0.6, "crawl": false, "age": 5.0, "pos": Vector3.ZERO, "angle": 0.0, "t": 0.0, "victim": held}
	held.grabbers.append(second)
	assert_eq(DeadBody.motion_in(DeadBody.custom(second, 0.0, 0.0, 1.0, true).g), DeadBody.LUNGE, "only the first bites")
	var missed := {"state": "chase", "phase": 0.3, "crawl": false, "age": 5.0, "pos": Vector3.ZERO, "angle": 0.0, "t": 0.0, "missed_at": 4.5}
	var snap := DeadBody.custom(missed, 0.0, 0.0, 1.0, true)
	assert_eq(DeadBody.motion_in(snap.g), 28, "reached and missed: it snaps at the air")
	assert_almost_eq(snap.r, 0.5, 0.001)
	missed["age"] = 5.6
	assert_ne(DeadBody.motion_in(DeadBody.custom(missed, 0.0, 0.0, 1.0, true).g), 28, "then it comes on")
	DeadBody.named = {}
	held.grab_left = 0.25
	assert_eq(DeadBody.motion_in(DeadBody.custom(z, 0.0, 0.0, 1.0, true).g), DeadBody.LUNGE, "a folder without them: as before")


func test_the_living_folder_in_the_build_has_every_motion_these_ask_for() -> void:
	var own: Array = BodyBake.load_baked(PersonVisual.OWN_FOLDER).get("clips", [])
	for n: String in NEW + ["p_limp_light_l", "p_limp_light_r"]:
		if n == "p_limp_light":
			continue
		assert_gt(PersonVisual.clip_named(own, n, -1), -1, n)
	for h in SearchHeight.CLIP.values():
		assert_gt(PersonVisual.clip_named(own, String(h), -1), -1, String(h))
	# The shiver goes round: kept up a while, not one round.
	var p := _person()
	p.heat.heat = 50.0
	var unit: float = p.name_unit("mood")
	var every := lerpf(PersonVisual.MOOD_EVERY.x, PersonVisual.MOOD_EVERY.y, unit)
	var start := every - fposmod(unit * every, every)
	assert_eq(_named(own, PersonVisual.mood_of(p, {}, start + 2.5, own)), "p_shiver")
	assert_eq(PersonVisual.mood_of(p, {}, start + PersonVisual.MOOD_LOOP + 0.1, own).y, -1.0)
