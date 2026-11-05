extends "res://addons/gut/test.gd"

const PersonVisual = preload("res://game/actors/person_visual.gd")
const Person = preload("res://game/actors/person.gd")
const BodyCast = preload("res://game/actors/body_cast.gd")
const FieldGame = preload("res://game/field_game.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const Wear = preload("res://game/sim/wear.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const Observer = preload("res://tests/game/fixtures/person_prewarm_observer.gd")

var saved_settings: Dictionary = {}


class _Pace:
	extends RefCounted
	var on := true


class _Field:
	extends RefCounted
	signal built
	var people: Array = []
	var is_built := false
	var opts := {"staged": true}
	var standing_by := true
	var pace := _Pace.new()
	var slow := 1.0
	var paused := false
	var ended := false
	var hitstop := false
	var feel = null
	var combat = null
	var hidden: Array = []
	var rode_off: Array = []

	func level_of(at: Vector3) -> int:
		return int(at.y)

	func level_shown(level: int) -> bool:
		return level == 0

	func _person_visible(p) -> bool:
		return not hidden.has(p)


class _RecordingVisual:
	extends "res://game/actors/person_visual.gd"
	var dress_calls: Array[String] = []
	var missing_own := ""
	var no_own: Array[String] = []
	var missing_garments: Array[String] = []
	var garment_calls: Array[String] = []

	func _picture() -> MultiMeshInstance3D:
		var picture := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true
		mm.mesh = BoxMesh.new()
		mm.instance_count = MAX_PEOPLE
		mm.visible_instance_count = 0
		picture.multimesh = mm
		add_child(picture)
		return picture

	func _dress(dead_dir: String, own_dir: String) -> Dictionary:
		dress_calls.append(own_dir)
		if own_dir == missing_own:
			return {}
		return {"vat": {"clips": [], "source": dead_dir}, "draw": _picture(),
			"table": [], "own_vat": {"clips": [{"name": "p_stand", "length": 1.0}]},
			"own_draw": null if no_own.has(own_dir) else _picture(), "own_table": [],
			"own_mix": {}, "own_frames": [], "frames": [], "wear": {},
			"wear_dir": own_dir.path_join("wear"), "n": 0, "k": 0, "worn_n": {}}

	func garment_of(d: Dictionary, kind: String) -> MultiMeshInstance3D:
		if not d["wear"].has(kind):
			garment_calls.append(String(d["wear_dir"]).path_join(kind))
			d["wear"][kind] = null if missing_garments.has(kind) else _picture()
		return d["wear"][kind]


func before_each() -> void:
	for key: String in [PersonVisual.SETTING, PersonVisual.BODIES_SETTING]:
		saved_settings[key] = {"exists": ProjectSettings.has_setting(key),
			"value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting(PersonVisual.SETTING, true)
	ProjectSettings.set_setting(PersonVisual.BODIES_SETTING, 0)


func after_each() -> void:
	for key: String in saved_settings:
		if saved_settings[key]["exists"]:
			ProjectSettings.set_setting(key, saved_settings[key]["value"])
		else:
			ProjectSettings.clear(key)
	saved_settings.clear()


func _person(pid: String, role: String = "companion") -> Person:
	var p := Person.new()
	add_child_autofree(p)
	p.setup(pid, pid, role, Vector3.ZERO)
	Wear.dress_from(p, {})
	p.bag = "pack"
	return p


func _people(count: int) -> Array:
	var ids := ["p_chief", "p_guard_marek", "p_med_joanna", "p_tail_tomasz"]
	var people: Array = []
	for i in count:
		people.append(_person(ids[i] if i < ids.size() else "p_extra_%d" % i))
	return people


func _visual(field: _Field) -> _RecordingVisual:
	var visual := _RecordingVisual.new()
	add_child_autofree(visual)
	visual.set_process(false)
	visual.setup(field)
	return visual


func _cache(visual: PersonVisual) -> Dictionary:
	var out := {}
	for body: String in visual.worn:
		var d: Dictionary = visual.worn[body]
		var entry := d.duplicate()
		for key: String in ["draw", "own_draw", "n", "k", "worn_n"]:
			entry.erase(key)
		entry["wear"] = {}
		for kind: String in d["wear"]:
			entry["wear"][kind] = d["wear"][kind] != null
		entry["fallback"] = d["draw"] == visual.worn[""]["draw"]
		out[body] = entry
	return out


func _read_over_frames(visual: _RecordingVisual, limit: int) -> void:
	# Each person can need a body and up to three shells, plus a settling frame.
	for tick in limit * 4:
		var before: int = visual.worn.size()
		var bodies_before: Array = visual.worn.keys()
		var reads: int = visual.dress_calls.size() + visual.garment_calls.size()
		visual._process(1.0 / 60.0)
		var added: int = visual.worn.size() - before
		var read_count: int = visual.dress_calls.size() + visual.garment_calls.size() - reads
		var body_shells := 0
		var counted := {}
		for p in visual.game.people:
			if not visual.body_by.has(p):
				continue
			var body: String = visual.body_by[p]
			if visual.worn.has(body) and not bodies_before.has(body) and not counted.has(body):
				counted[body] = true
				body_shells += (PersonVisual.looks_on(p) + PersonVisual.bag_on(p)).size()
		assert_lte(added, PersonVisual.READS_PER_FRAME)
		assert_lte(read_count, PersonVisual.READS_PER_FRAME + body_shells)
		if added == 0 and read_count == 0:
			return
	fail_test("body and shell reads did not settle within the bounded frame count")


func _finish_preparation(visual: _RecordingVisual) -> void:
	visual.prepare()
	for frame in 256:
		if not visual.is_preparing():
			return
		await get_tree().process_frame
		var reads: int = visual.dress_calls.size() + visual.garment_calls.size()
		visual.prepare_step()
		var after: int = visual.dress_calls.size() + visual.garment_calls.size()
		assert_lte(after - reads, PersonVisual.READS_PER_FRAME)
		assert_lte(int(visual.prepare_stats["last_frame_work"]), PersonVisual.READS_PER_FRAME)
		visual.prepare_step()
		assert_eq(visual.dress_calls.size() + visual.garment_calls.size(), after)
	fail_test("preparation did not settle within the bounded frame count")


func _assert_equivalent(warm: _RecordingVisual, cold: _RecordingVisual) -> void:
	assert_eq(warm.worn.keys(), cold.worn.keys())
	assert_eq_deep(_cache(warm), _cache(cold))
	assert_eq_deep(warm.body_by, cold.body_by)
	assert_eq_deep(warm.taken, cold.taken)
	assert_eq(warm.dress_calls, cold.dress_calls)


func test_preparation_uses_restored_people_and_final_visibility() -> void:
	var field := _Field.new()
	field.people = _people(4)
	var visual := _visual(field)
	assert_eq(visual.worn.keys(), [""])
	assert_true(visual.body_by.is_empty())
	var late := _person("p_restored_worker", "worker")
	field.people.append(late)
	field.hidden.append(field.people[1])
	field.rode_off.append(field.people[2])
	field.people[3].position.y = 1.0
	field.is_built = true
	field.built.emit()
	assert_true(visual.body_by.is_empty())
	await _finish_preparation(visual)
	assert_eq(visual.body_by.keys(), [field.people[0], late])
	assert_false(visual.worn_of(late, false).is_empty())
	assert_true(visual.notes.is_empty())
	for p in field.people:
		assert_true(p.visible)
		assert_true(p.body_mesh.visible)
		assert_true(p.head_mesh.visible)
	for d: Dictionary in visual.worn.values():
		assert_eq(d["n"], 0)
		assert_eq(d["k"], 0)
		for key: String in ["draw", "own_draw"]:
			assert_eq(d[key].multimesh.instance_count, PersonVisual.MAX_PEOPLE)
			assert_eq(d[key].multimesh.visible_instance_count, 0)


func test_prewarm_matches_incremental_cache_assignment_and_capacity() -> void:
	var cases := [[PersonVisual.READS_PER_FRAME + 2, 0],
		[PersonVisual.MAX_PEOPLE + 3, 0], [PersonVisual.MAX_PEOPLE + 3, 1]]
	for row: Array in cases:
		ProjectSettings.set_setting(PersonVisual.BODIES_SETTING, row[1])
		var field := _Field.new()
		field.people = _people(row[0])
		field.is_built = true
		var warm := _visual(field)
		var cold := _visual(field)
		await _finish_preparation(warm)
		var report: Dictionary = warm.prepare_stats
		assert_eq(report["count"], warm.worn.size() - 1)
		assert_gte(float(report["ms"]), 0.0)
		_read_over_frames(cold, field.people.size() + 1)
		_assert_equivalent(warm, cold)
		var reads: int = warm.dress_calls.size()
		var keys: Array = warm.worn.keys()
		for tick in 3:
			warm._process(1.0 / 60.0)
			assert_eq(warm.dress_calls.size() - reads, 0)
			assert_eq(warm.worn.keys(), keys)
		var children: int = warm.get_child_count()
		var notes: Dictionary = warm.notes.duplicate(true)
		var counts: Array = []
		for d: Dictionary in warm.worn.values():
			counts.append([d["n"], d["k"], d["draw"].multimesh.visible_instance_count,
				d["own_draw"].multimesh.visible_instance_count])
		await _finish_preparation(warm)
		assert_eq(warm.prepare_stats["count"], 0)
		assert_eq(warm.prepare_stats["garments"], 0)
		assert_eq(warm.dress_calls.size(), reads)
		assert_eq(warm.get_child_count(), children)
		assert_eq_deep(warm.notes, notes)
		var after_counts: Array = []
		for d: Dictionary in warm.worn.values():
			after_counts.append([d["n"], d["k"], d["draw"].multimesh.visible_instance_count,
				d["own_draw"].multimesh.visible_instance_count])
		assert_eq_deep(after_counts, counts)
		if int(row[1]) == 1:
			assert_eq(warm.body_by.size(), PersonVisual.MAX_PEOPLE)
		else:
			assert_eq(warm.body_by.size(), field.people.size())


func test_late_people_keep_the_per_frame_read_budget() -> void:
	var field := _Field.new()
	var people := _people(4)
	field.people = [people[0]]
	var visual := _visual(field)
	field.is_built = true
	field.built.emit()
	await _finish_preparation(visual)
	field.people.append_array(people.slice(1))
	for tick in 3:
		var before: int = visual.worn.size()
		var reads: int = visual.dress_calls.size()
		visual._process(1.0 / 60.0)
		assert_eq(visual.worn.size() - before, PersonVisual.READS_PER_FRAME)
		assert_eq(visual.dress_calls.size() - reads, PersonVisual.READS_PER_FRAME)
	await _finish_preparation(visual)
	assert_eq(visual.prepare_stats["count"], 0)


func test_already_drawn_person_gets_new_bag_when_frame_budget_is_spent() -> void:
	var field := _Field.new()
	var people := _people(2)
	var shown: Person = people[0]
	shown.bag = "pockets"
	field.people = [shown]
	var visual := _visual(field)
	_read_over_frames(visual, 4)
	var before: Dictionary = Observer.appearance(visual, field.people)
	assert_eq(before["drawn"], [String(shown.pid)] as Array[String])
	assert_true(before["incomplete"].is_empty())
	# The newcomer spends the only body-read slot before the existing person.
	field.people = [people[1], shown]
	shown.bag = "big_pack"
	var reads: int = visual.dress_calls.size()
	visual._process(1.0 / 60.0)
	assert_eq(visual.dress_calls.size() - reads, PersonVisual.READS_PER_FRAME)
	var sample: Dictionary = Observer.appearance(visual, field.people)
	assert_eq(sample["ambiguous"], 0)
	assert_true(sample["drawn"].has(String(shown.pid)), "the existing person stays on show")
	assert_true(sample["incomplete"].is_empty(), "both bodies have their shells in this frame")
	var d: Dictionary = visual.worn_of(shown, false)
	assert_true(d["wear"].has("big_pack"), "the new bag is read despite the spent slot")
	assert_true(visual.garment_calls.has(String(d["wear_dir"]).path_join("big_pack")))
	if d["wear"].has("big_pack"):
		assert_not_null(d["wear"]["big_pack"])
		if d["wear"]["big_pack"] != null:
			assert_eq(d["wear"]["big_pack"].multimesh.visible_instance_count, 1)


func test_direct_first_visible_frames_match_617baa40_with_mixed_shells() -> void:
	assert_eq(PersonVisual.READS_PER_FRAME, 1, "the baseline spends one body bundle per frame")
	var field := _Field.new()
	field.opts = {"staged": false}
	field.standing_by = false
	field.is_built = true
	field.people = _people(4)
	field.people[0].bag = "pockets"
	field.people[0].hat = Wear.make("hat_knit")
	field.people[1].worn["coat"] = Wear.make("coat_padded")
	field.people[2].bag = "big_pack"
	field.people[3].bag = "pockets"
	var visual := _visual(field)
	assert_true(visual.notes.is_empty())
	var visible_counts: Array[int] = []
	var dressed_counts: Array[int] = []
	var all_visible_frame := 0
	var all_dressed_frame := 0
	# 617baa40: _process 568-574 reads one new body, 603-614 draws its
	# shells immediately. These four ids select four distinct, uncached bodies.
	for tick in 4:
		var reads: int = visual.dress_calls.size()
		visual._process(1.0 / 60.0)
		assert_eq(visual.dress_calls.size() - reads, 1)
		var sample: Dictionary = Observer.appearance(visual, field.people)
		assert_eq(sample["ambiguous"], 0)
		assert_eq(sample["missing"], 0, "no body appears before its shells are cached")
		assert_true(sample["incomplete"].is_empty(), "shells are drawn in the body's first frame")
		visible_counts.append(sample["drawn"].size())
		dressed_counts.append(sample["drawn"].size() - sample["incomplete"].size())
		if visible_counts.back() == 4 and all_visible_frame == 0:
			all_visible_frame = tick + 1
		if dressed_counts.back() == 4 and all_dressed_frame == 0:
			all_dressed_frame = tick + 1
	assert_eq_deep(visible_counts, [1, 2, 3, 4])
	assert_eq_deep(dressed_counts, [1, 2, 3, 4])
	assert_eq(all_visible_frame, 4)
	assert_eq(all_dressed_frame, 4)
	assert_eq(all_visible_frame - 4, 0, "no extra frames before direct-path people appear")


func test_unavailable_body_keeps_the_fallback_without_reading_again() -> void:
	var field := _Field.new()
	field.people = [_person("p_guard_marek")]
	field.is_built = true
	var visual := _visual(field)
	visual.missing_own = BodyCast.own_folder("n5-crew_guard")
	await _finish_preparation(visual)
	assert_eq(visual.prepare_stats["count"], 1)
	assert_eq(visual.worn["n5-crew_guard"]["draw"], visual.worn[""]["draw"])
	var reads: int = visual.dress_calls.size()
	await _finish_preparation(visual)
	assert_eq(visual.prepare_stats["count"], 0)
	visual._process(1.0 / 60.0)
	assert_eq(visual.dress_calls.size(), reads)


func test_setup_without_a_field_keeps_manual_cache_loading() -> void:
	var visual := _RecordingVisual.new()
	add_child_autofree(visual)
	visual.set_process(false)
	visual.setup(null)
	assert_true(visual.is_worn())
	assert_true(visual.body_by.is_empty())
	var p := _person("p_chief")
	assert_false(visual.worn_of(p).is_empty())
	assert_eq(visual.body_by[p], BodyCast.BY_ID["p_chief"])


func test_empty_or_disabled_visual_does_not_assign_bodies() -> void:
	var field := _Field.new()
	field.is_built = true
	var visual := _visual(field)
	await _finish_preparation(visual)
	assert_eq(visual.prepare_stats["count"], 0)
	ProjectSettings.set_setting(PersonVisual.SETTING, false)
	field.people = _people(3)
	var disabled := _visual(field)
	await _finish_preparation(disabled)
	assert_eq(disabled.prepare_stats["count"], 0)
	assert_true(disabled.worn.is_empty())
	assert_true(disabled.body_by.is_empty())
	assert_true(disabled.taken.is_empty())
	assert_true(disabled.dress_calls.is_empty())


func test_prewarm_matches_incremental_from_partial_cache() -> void:
	var field := _Field.new()
	field.people = _people(PersonVisual.MAX_PEOPLE + 3)
	field.is_built = true
	var warm := _visual(field)
	var cold := _visual(field)
	for visual: _RecordingVisual in [warm, cold]:
		var d: Dictionary = visual.worn_of(field.people[0])
		visual.worn_of(field.people[1], false)
		visual.garment_of(d, PersonVisual.looks_on(field.people[0])[0]["shell"])
	await _finish_preparation(warm)
	_read_over_frames(cold, field.people.size() + 1)
	_assert_equivalent(warm, cold)


func test_prewarm_matches_incremental_with_mixed_failures() -> void:
	var field := _Field.new()
	field.people = _people(7)
	field.is_built = true
	var warm := _visual(field)
	var cold := _visual(field)
	for visual: _RecordingVisual in [warm, cold]:
		visual.missing_own = BodyCast.own_folder("n5-crew_medic")
		visual.no_own = [BodyCast.own_folder("n3-body_sheepskin")]
		visual.missing_garments = ["pack"]
		visual.worn_of(field.people[0])
	await _finish_preparation(warm)
	_read_over_frames(cold, field.people.size() + 1)
	_assert_equivalent(warm, cold)
	assert_eq(warm.worn["n5-crew_medic"]["draw"], warm.worn[""]["draw"])
	assert_eq(warm.worn["n3-body_sheepskin"]["draw"], warm.worn[""]["draw"])
	for visual: _RecordingVisual in [warm, cold]:
		assert_eq(visual.dress_calls.count(BodyCast.own_folder("n5-crew_medic")), 1)
		assert_eq(visual.dress_calls.count(BodyCast.own_folder("n3-body_sheepskin")), 1)
		for d: Dictionary in visual.worn.values():
			assert_true(d["wear"].has("pack"))
			assert_null(d["wear"].get("pack"))
		var reads: int = visual.dress_calls.size() + visual.garment_calls.size()
		await _finish_preparation(visual)
		assert_eq(visual.dress_calls.size() + visual.garment_calls.size(), reads)


func test_setup_reentry_is_idempotent() -> void:
	var a := _Field.new()
	a.people = _people(1)
	var visual := _visual(a)
	var children: int = visual.get_child_count()
	visual.setup(a)
	assert_eq(visual.get_child_count(), children)
	assert_eq(visual.dress_calls.size(), 1)
	visual.worn_of(a.people[0])
	a.is_built = true
	visual.prepare()
	assert_true(visual.is_preparing())
	var b := _Field.new()
	b.people = [_person("p_med_joanna")]
	b.is_built = true
	var reads: int = visual.dress_calls.size()
	visual.setup(b)
	assert_true(visual.body_by.is_empty())
	assert_true(visual.taken.is_empty())
	assert_false(visual.is_preparing())
	visual.prepare()
	visual.setup(b)
	a.built.emit()
	b.built.emit()
	assert_eq(visual.dress_calls.size(), reads)
	assert_true(visual.is_preparing())
	await _finish_preparation(visual)
	assert_eq(visual.body_by.keys(), b.people)
	assert_eq(visual.body_by[b.people[0]], BodyCast.BY_ID["p_med_joanna"])


func test_targets_and_garments_are_rechecked_before_preparation_finishes() -> void:
	var field := _Field.new()
	field.people = _people(3)
	field.is_built = true
	var visual := _visual(field)
	visual.prepare()
	await get_tree().process_frame
	visual.prepare_step()
	var late := _person("p_tail_tomasz")
	field.people.append(late)
	field.people[0].bag = "big_pack"
	await _finish_preparation(visual)
	assert_false(visual.worn_of(late, false).is_empty())
	assert_true(visual.worn_of(field.people[0], false)["wear"].has("big_pack"))
	assert_lte(visual.prepare_stats["max_frame_work"], PersonVisual.READS_PER_FRAME)


func test_target_replacement_prepares_new_targets_only() -> void:
	var field := _Field.new()
	var a := _person("p_swap_a")
	var b := _person("p_swap_b")
	field.people = [a, b]
	field.hidden = [b]
	field.is_built = true
	var visual := _visual(field)
	visual.prepare()
	await get_tree().process_frame
	visual.prepare_step()
	assert_true(visual.body_by.has(a))
	field.hidden = [a]
	# Changing candidates retains earlier reservations; this checks new-target caches only.
	await _finish_preparation(visual)
	var d: Dictionary = visual.worn_of(b, false)
	assert_false(d.is_empty())
	for garment: Dictionary in PersonVisual.looks_on(b) + PersonVisual.bag_on(b):
		assert_true(d["wear"].has(garment["shell"]))


func test_cancelled_preparation_cannot_spend_another_read() -> void:
	var field := _Field.new()
	field.people = _people(4)
	field.is_built = true
	var visual := _visual(field)
	visual.prepare()
	await get_tree().process_frame
	visual.prepare_step()
	visual.cancel_preparation()
	var reads: int = visual.dress_calls.size() + visual.garment_calls.size()
	await get_tree().process_frame
	visual.prepare()
	visual.prepare_step()
	assert_false(visual.is_preparing())
	assert_true(visual.preparation_cancelled())
	assert_eq(visual.dress_calls.size() + visual.garment_calls.size(), reads)


func test_restarting_preparation_shares_the_same_engine_frame_budget() -> void:
	var field := _Field.new()
	field.people = _people(1)
	field.is_built = true
	var visual := _visual(field)
	await _finish_preparation(visual)
	assert_eq(visual.prepare_stats["last_frame_work"], PersonVisual.READS_PER_FRAME)
	field.people.append(_person("p_med_joanna"))
	var reads: int = visual.dress_calls.size() + visual.garment_calls.size()
	visual.prepare()
	visual.prepare_step()
	assert_eq(visual.dress_calls.size() + visual.garment_calls.size(), reads)
	assert_eq(visual.prepare_stats["frames"], 0)
	await _finish_preparation(visual)
	assert_false(visual.worn_of(field.people[1], false).is_empty())


func test_resume_direct_path_skips_prewarm() -> void:
	var source := FieldGame.new()
	source.opts = {"seed": 7, "arrive": false, "raiders": false, "auto_pause": false}
	source.map_script = BareLine
	add_child_autofree(source)
	source.process_mode = Node.PROCESS_MODE_DISABLED
	assert_true(source.is_built)
	assert_eq(source.people_look.worn.keys(), [""])
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(source)))
	var resumed := FieldGame.new()
	resumed.opts = FieldSave.resume_opts(saved)
	resumed.map_script = BareLine
	add_child_autofree(resumed)
	resumed.process_mode = Node.PROCESS_MODE_DISABLED
	assert_true(resumed.is_built)
	assert_true(resumed.resume_pending)
	assert_false(bool(resumed.opts.get("staged", false)))
	var visual: PersonVisual = resumed.people_look
	assert_eq(visual.worn.keys(), [""])
	assert_true(visual.body_by.is_empty())
	visual.prepare()
	assert_false(visual.is_preparing())
	assert_eq(visual.prepare_stats["count"], 0)
	for frame in 3:
		var before: int = visual.worn.size()
		visual._process(0.0)
		assert_eq(visual.worn.size() - before, PersonVisual.READS_PER_FRAME)
