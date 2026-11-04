extends "res://addons/gut/test.gd"

const PersonVisual = preload("res://game/actors/person_visual.gd")
const Person = preload("res://game/actors/person.gd")
const BodyCast = preload("res://game/actors/body_cast.gd")
const FieldGame = preload("res://game/field_game.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")

var saved_settings: Dictionary = {}


class _Field:
	extends RefCounted
	signal built
	var people: Array = []
	var is_built := false
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

	func _picture() -> MultiMeshInstance3D:
		var picture := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
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
			"table": [], "own_vat": {}, "own_draw": _picture(), "own_table": [],
			"own_mix": {}, "own_frames": [], "frames": [], "wear": {},
			"wear_dir": own_dir.path_join("wear"), "n": 0, "k": 0, "worn_n": {}}


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
		entry["fallback"] = d["draw"] == visual.worn[""]["draw"]
		out[body] = entry
	return out


func _read_over_frames(visual: PersonVisual, limit: int) -> void:
	for tick in limit:
		var before: int = visual.worn.size()
		visual._process(1.0 / 60.0)
		var added: int = visual.worn.size() - before
		assert_lte(added, PersonVisual.READS_PER_FRAME)
		if added == 0:
			return
	fail_test("body reads did not settle within the bounded frame count")


func test_setup_waits_for_restored_people_and_final_visibility() -> void:
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
		var warm := _visual(field)
		var cold := _visual(field)
		var report: Dictionary = warm.prewarm(field.people)
		assert_eq(report["count"], warm.worn.size() - 1)
		assert_gte(float(report["ms"]), 0.0)
		_read_over_frames(cold, field.people.size() + 1)
		assert_eq(warm.worn.keys(), cold.worn.keys())
		assert_eq_deep(_cache(warm), _cache(cold))
		assert_eq_deep(warm.body_by, cold.body_by)
		assert_eq_deep(warm.taken, cold.taken)
		assert_eq(warm.dress_calls, cold.dress_calls)
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
		assert_eq(warm.prewarm(field.people)["count"], 0)
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
	field.people.append_array(people.slice(1))
	for tick in 3:
		var before: int = visual.worn.size()
		var reads: int = visual.dress_calls.size()
		visual._process(1.0 / 60.0)
		assert_eq(visual.worn.size() - before, PersonVisual.READS_PER_FRAME)
		assert_eq(visual.dress_calls.size() - reads, PersonVisual.READS_PER_FRAME)
	assert_eq(visual.prewarm(field.people)["count"], 0)


func test_unavailable_body_keeps_the_fallback_without_reading_again() -> void:
	var field := _Field.new()
	field.people = [_person("p_guard_marek")]
	var visual := _visual(field)
	visual.missing_own = BodyCast.own_folder("n5-crew_guard")
	assert_eq(visual.prewarm(field.people)["count"], 1)
	assert_eq(visual.worn["n5-crew_guard"]["draw"], visual.worn[""]["draw"])
	var reads: int = visual.dress_calls.size()
	assert_eq(visual.prewarm(field.people)["count"], 0)
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
	var visual := _visual(field)
	assert_eq(visual.prewarm([])["count"], 0)
	ProjectSettings.set_setting(PersonVisual.SETTING, false)
	field.people = _people(3)
	var disabled := _visual(field)
	assert_eq(disabled.prewarm(field.people)["count"], 0)
	assert_true(disabled.worn.is_empty())
	assert_true(disabled.body_by.is_empty())
	assert_true(disabled.taken.is_empty())
	assert_true(disabled.dress_calls.is_empty())


func test_built_fields_need_no_body_reads_in_the_first_three_process_frames() -> void:
	for staged: bool in [false, true]:
		var field := FieldGame.new()
		field.opts = {"seed": 7, "raiders": false, "auto_pause": false,
			"arrive": false, "staged": staged}
		field.map_script = BareLine
		field.visible = not staged
		add_child_autofree(field)
		if not field.is_built:
			await wait_for_signal(field.built, 60)
		assert_true(field.is_built)
		if not field.is_built:
			field.queue_free()
			return
		field.go_live()
		field.process_mode = Node.PROCESS_MODE_DISABLED
		field.paused = true
		var visual: PersonVisual = field.people_look
		assert_eq(visual.body_by.size(), field.people.size())
		for p in field.people:
			assert_false(visual.worn_of(p, false).is_empty())
		var keys: Array = visual.worn.keys()
		for tick in 3:
			field._process(1.0 / 60.0)
			visual._process(1.0 / 60.0)
			assert_eq(visual.worn.keys(), keys)
