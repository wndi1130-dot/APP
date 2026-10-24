extends GutTest
## Each of the field's living wears a body of their own (body_cast.gd), drawn
## by person_visual.gd from that body's own folder pair.

const BodyCast = preload("res://game/actors/body_cast.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const Person = preload("res://game/actors/person.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")


func _person(pid: String, role: String) -> Node3D:
	var p := Person.new()
	add_child_autofree(p)
	p.setup(pid, "시험", role, Vector3.ZERO)
	return p


func _line_up(list: Array) -> Array:
	var out := []
	for clip: Dictionary in list:
		out.append([clip["name"], clip["start"], clip["frames"], clip["loop"]])
	return out


# Every body named here is in the build: the living's motions under the same
# numbers as the reference folder's, its colour picture, the dead's folder of
# the same mesh beside it, the right hand found for the weapon; and none is
# the body the dead wear.
func test_every_body_is_baked_with_the_living_motions_and_its_colour() -> void:
	var reference := _line_up(BodyBake.load_baked(PersonVisual.OWN_FOLDER)["clips"])
	for body: String in BodyCast.ALL:
		assert_ne(BodyCast.dead_folder(body), DeadBody.BUILT_IN, body)
		var own := DeadBody.with_albedo(BodyBake.load_baked(BodyCast.own_folder(body)), BodyCast.own_folder(body))
		assert_false(own.is_empty(), body)
		if own.is_empty():
			continue
		assert_eq(_line_up(own["clips"]), reference, body + " has the motions under the same numbers")
		assert_true(own.get("albedo") is Texture2D, body + " has its colour picture")
		var dead := BodyBake.load_baked(BodyCast.dead_folder(body))
		assert_eq(int(dead.get("vertices", -1)), int(own["vertices"]), body + "'s dead folder is the same mesh")
		assert_false(PersonVisual.hand_of(own).is_empty(), body + "'s right hand is found")
	for list: Array in BodyCast.BY_ROLE.values():
		for body: String in list:
			assert_has(BodyCast.ALL, body)
	for body: String in BodyCast.BY_ID.values():
		assert_has(BodyCast.ALL, body)


# The squad, the raiders and the work party (thirteen at most) all differ; past
# every body, the next shares the one fewest wear.
func test_no_two_of_the_field_wear_the_same_body() -> void:
	var taken := {}
	var picked := []
	for row in [["p_chief", "chief"], ["p_guard_marek", "companion"], ["p_med_joanna", "companion"], ["p_tail_tomasz", "companion"],
			["npc_raider_1", "raider"], ["npc_raider_2", "raider"], ["npc_raider_3", "raider"],
			["s2_crew_01", "worker"], ["s2_crew_02", "worker"], ["s2_crew_03", "worker"], ["s2_crew_04", "worker"],
			["s2_escort_01", "escort"], ["s2_escort_02", "escort"]]:
		picked.append(BodyCast.pick(row[0], row[1], taken))
	assert_eq(picked[0], "n5-crew_railman-old")
	assert_eq(picked[1], "n5-crew_guard")
	assert_eq(picked[2], "n5-crew_medic")
	assert_eq(picked[4], "n3-body_lumberjack", "a raider in plain clothes")
	for i in picked.size():
		assert_eq(picked.count(picked[i]), 1, "%s worn once" % picked[i])
	var next := BodyCast.pick("someone", "worker", taken)
	assert_eq(int(taken[next]), 2, "the fourteenth shares a body")


# Drawn: each person is put in their own body's multimesh, read in once.
func test_each_one_is_drawn_in_their_own_body() -> void:
	var v := PersonVisual.new()
	add_child_autofree(v)
	v.setup(null)
	assert_true(v.is_worn())
	var chief := _person("p_chief", "chief")
	var guard := _person("p_guard_marek", "companion")
	var a: Dictionary = v.worn_of(chief)
	var b: Dictionary = v.worn_of(guard)
	assert_eq(String(v.body_by[chief]), "n5-crew_railman-old")
	assert_ne(a["own_draw"], b["own_draw"], "two bodies, two multimeshes")
	assert_same(v.worn_of(chief), a, "read in once")
	assert_true((a["own_vat"] as Dictionary).has("arm"), "the weapon goes in this body's hand")
	assert_ne(a["own_draw"], v.own_draw, "not the reference body")
	# A frame that has read one in already leaves the next for later.
	var raider := _person("npc_raider_1", "raider")
	assert_true(v.worn_of(raider, false).is_empty(), "not read in while it may not be")
	assert_false(v.worn_of(raider).is_empty(), "read in when it may")
