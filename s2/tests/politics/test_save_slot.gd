extends "res://addons/gut/test.gd"

const V = preload("res://tests/politics/field_vectors.gd")
const SaveSlot = preload("res://game/politics/save_slot.gd")
const Dom = preload("res://game/train/train_dom.gd")
const Workshop = preload("res://game/train/train_workshop.gd")
const Advance = preload("res://game/train/train_advance.gd")

const SAVE_PATH := "user://codex_field_port_save.json"
const BROKEN_PATH := "user://codex_field_port_broken.json"

var _tables: Dictionary


func before_all() -> void:
	_tables = V.tables()
	_cleanup()


func after_all() -> void:
	_cleanup()


func _cleanup() -> void:
	for path: String in [SAVE_PATH, BROKEN_PATH]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)


func _write_raw(text: String) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()


func test_fixture_states_round_trip_through_one_slot() -> void:
	var samples: Array = [V.cases()[0]["start"], V.cases()[4]["apply"]["after"], V.cases()[8]["arrival"]["state"]]
	for i: int in samples.size():
		assert_true(SaveSlot.save_slot(samples[i], SAVE_PATH), "save sample %d" % i)
		var loaded := SaveSlot.load_slot(_tables, SAVE_PATH, BROKEN_PATH)
		assert_null(loaded["why"], "load sample %d" % i)
		var expected: Dictionary = samples[i].duplicate(true)
		if not expected.has("lateOn"): expected["lateOn"] = false
		if not expected.has("lateCards"): expected["lateCards"] = []
		assert_eq(V.diff(expected, loaded["g"], "sample %d" % i), "")


func test_dom_slot_versions_use_an_independent_literal_matrix() -> void:
	# has_dom, supplies, read version, write version. Keep expectations independent of slot_board.
	var rows: Array = [[false, false, 1, 1], [false, false, 2, 2], [false, false, 3, 3], [false, false, 4, 4],
		[false, true, 1, 3], [false, true, 2, 3], [false, true, 3, 3], [false, true, 4, 3],
		[true, false, 1, 4], [true, false, 2, 4], [true, false, 3, 4], [true, false, 4, 4],
		[true, true, 1, 4], [true, true, 2, 4], [true, true, 3, 4], [true, true, 4, 4]]
	for row: Array in rows:
		var g: Dictionary = V.cases()[0]["start"].duplicate(true)
		g["version"] = row[2]
		g["supOn"] = row[1]
		if row[0]: g["dom"] = {"wood": 3}
		else: g.erase("dom")
		var read: Dictionary = SaveSlot.read_save(g, _tables)
		assert_true(read["ok"], str(row))
		if not read["ok"]: continue
		var before: String = JSON.stringify(read["g"], "", false)
		var written: Dictionary = SaveSlot.slot_board(read["g"])
		assert_eq(int(written["version"]), int(row[3]), str(row))
		assert_eq(JSON.stringify(read["g"], "", false), before, "input untouched")
		if row[0]:
			assert_gt(int(written["version"]), 3, "the old build's literal ceiling")
		else:
			assert_false(read["g"].has("dom"), "reading must not create domestic stores")
	assert_eq(SaveSlot.SAVE_VERSION, 4)
	assert_eq(SaveSlot.DOM_LOG_VERSION, 4)


func test_legacy_dom_gains_only_log_then_stats_at_the_end() -> void:
	var g: Dictionary = V.cases()[0]["start"].duplicate(true)
	g["dom"] = {"wood": 3, "store": {}, "decor80": [], "job": null}
	var old_dom: String = JSON.stringify(g["dom"], "", false)
	SaveSlot.fill_defaults(g)
	assert_eq(g["dom"].keys(), ["wood", "store", "decor80", "job", "log", "stats"])
	var expected: String = old_dom.trim_suffix("}") + ',"log":{"restores":[]},"stats":{"restored":0,"tier3":0,"defective":0}}'
	assert_eq(JSON.stringify(g["dom"], "", false), expected)
	SaveSlot.fill_defaults(g)
	assert_eq(JSON.stringify(g["dom"], "", false), expected, "second migration is identical")


func test_first_return_save_load_save_keeps_dom_keys_order_and_values() -> void:
	var g: Dictionary = V.cases()[0]["start"].duplicate(true)
	g.erase("dom")
	SaveSlot.fill_defaults(g)
	assert_false(g.has("dom"))
	assert_true(Dom.take_extras(g, {"fragments": ["engine"], "coreCount": 1}))
	assert_eq(g["dom"].keys(), ["frags", "armory", "wardrobe", "furnish", "store", "decor80", "scrap", "wood", "parts", "cores", "cloth", "ammo_pistol", "ammo_shell", "ammo_craft", "lures", "sleds", "stretchers", "carts", "long_sleds", "runners", "log", "stats"])
	assert_true(g["dom"].has("log") and g["dom"].has("stats"), "present at the first save")
	assert_true(SaveSlot.save_slot(g, SAVE_PATH))
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	var loaded: Dictionary = SaveSlot.load_slot(_tables, SAVE_PATH, BROKEN_PATH)
	assert_null(loaded["why"])
	if not loaded["g"] is Dictionary: return
	assert_true(SaveSlot.save_slot(loaded["g"], SAVE_PATH))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	assert_eq(int(first["version"]), 4)
	assert_eq(int(second["version"]), 4)
	assert_eq(first["dom"].keys(), second["dom"].keys())
	assert_eq(JSON.stringify(first["dom"], "", false), JSON.stringify(second["dom"], "", false))


func test_legacy_pipe_pending_migration_preserves_explicit_false_and_pipe_moved() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/lawtech_vectors.json"))
	var tables: Dictionary = data["tables"]
	for kind: String in ["missing", "false", "moved"]:
		var g: Dictionary = V.cases()[0]["start"].duplicate(true)
		# No crisis, so the session's agendas are not forced (a forced session leaves pipe out, as S1).
		g["coal"] = 1000.0
		g["food"] = 1000.0
		g["med"] = 1000.0
		g["corpseIssue"] = false
		g["dom"] = Dom.start()
		g["dom"]["restoring"] = "e3"
		g["dom"]["techs"]["e3"] = {"stage": "restoring", "defect": false, "progress": 6, "need": 6, "variant": "a"}
		g["dom"]["target"] = 0
		if kind == "false": g["dom"]["techs"]["e3"]["pending"] = false
		if kind == "moved": g["dom"]["pipeMoved"] = "a"
		var read: Dictionary = SaveSlot.read_save(JSON.parse_string(JSON.stringify(g)), tables)
		assert_true(read["ok"], kind)
		if not read["ok"]: continue
		g = read["g"]
		if kind == "missing":
			assert_true(g["dom"]["techs"]["e3"]["pending"])
			g = Advance.open_council(g, tables)
			assert_true((g["council"]["options"] as Array).has({"kind": "motion", "motion": "pipe"}))
			assert_eq(int(SaveSlot.slot_board(g)["version"]), 4, "pre-vote slot")
		elif kind == "false":
			assert_false(g["dom"]["techs"]["e3"]["pending"])
		else:
			assert_false(g["dom"]["techs"]["e3"].has("pending"))
		var written: Dictionary = SaveSlot.slot_board(g)
		var again: Dictionary = SaveSlot.read_save(JSON.parse_string(JSON.stringify(written)), tables)
		assert_true(again["ok"], kind + " next save reads")
		if not again["ok"]: continue
		g = again["g"]
		Workshop.run(g, tables)
		assert_eq(g["dom"]["restoring"], "e3" if kind == "missing" else null, kind)
		assert_eq(g["dom"]["techs"]["e3"]["stage"], "restoring" if kind == "missing" else "done", kind)


func test_bad_saves_are_rejected_with_reason_and_preserved_beside_slot() -> void:
	var base: Dictionary = V.cases()[0]["start"]
	var no_version: Dictionary = base.duplicate(true)
	no_version.erase("version")
	var newer: Dictionary = base.duplicate(true)
	newer["version"] = SaveSlot.SAVE_VERSION + 1
	var bad_field: Dictionary = (V.cases()[0]["apply"]["after"] as Dictionary).duplicate(true)
	bad_field["fieldReturns"]["applied"] = []
	var cases := [
		{"raw": JSON.stringify(no_version), "why": "판 번호가 없다"},
		{"raw": JSON.stringify(newer), "why": "더 새 빌드에서 저장한 판이다"},
		{"raw": "{not json", "why": "저장 글이 깨졌다"},
		{"raw": JSON.stringify(bad_field), "why": "필드 귀환 기록이 이상하다"},
	]
	for row: Dictionary in cases:
		_cleanup()
		_write_raw(row["raw"])
		var loaded := SaveSlot.load_slot(_tables, SAVE_PATH, BROKEN_PATH)
		assert_null(loaded["g"], row["why"])
		assert_true(String(loaded["why"]).contains(row["why"]), String(loaded["why"]))
		assert_true(FileAccess.file_exists(BROKEN_PATH), row["why"] + " broken copy")
		assert_eq(FileAccess.get_file_as_string(BROKEN_PATH), row["raw"], row["why"] + " broken bytes")
		assert_true(FileAccess.file_exists(SAVE_PATH), row["why"] + " original retained")
		assert_eq(FileAccess.get_file_as_string(SAVE_PATH), row["raw"], row["why"] + " original bytes")
