extends "res://addons/gut/test.gd"
## 60×30 빈 선로 두 건. 실제 로더/지문을 쓰되 큰 지도 전체 회귀는 리드가 돌린다.

const Dump = preload("res://tools/bounds_baseline_dump.gd")
const BoundsDigest = preload("res://tests/game/bounds_digest.gd")
const StopLoader = preload("res://game/stop_loader.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const KEYS: Array[String] = ["mine_98||71|", "mine_98||71|K4"]
const MAPS: Array[String] = ["mine_98"]
const REVISION: String = "0123456789012345678901234567890123456789"

var _folder: String = ""
var _expected: Dictionary = {}


func before_all() -> void:
	# 진행 파일이나 build_case를 거치지 않고 한 번에 뽑은 독립 비교값.
	for key: String in KEYS:
		var parts: PackedStringArray = key.split("|", true)
		var data: Dictionary = StopLoader.make_ready(BareLine, 71, parts[1], -1.0, parts[3])
		_expected[key] = BoundsDigest.digest(data)
		data.clear()


func before_each() -> void:
	_folder = "user://bounds_dump_resume_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_folder)), OK)


func after_each() -> void:
	# 이 시험이 만든 고유 폴더 안의 파일만 지운다. 하위 폴더는 만들지 않는다.
	for filename: String in DirAccess.get_files_at(_folder):
		assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(_folder.path_join(filename))), OK)
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(_folder)), OK)


func _header() -> Dictionary:
	return Dump.progress_header(MAPS, KEYS, REVISION)


func _resume(output: String, state: Dictionary, built_keys: Array[String]) -> bool:
	var cases: Dictionary = state["cases"]
	for key: String in Dump.remaining_keys(KEYS, cases):
		built_keys.append(key)
		var built: Dictionary = Dump.build_case(key, BareLine, cases.is_empty())
		assert_eq(built.get("error"), "", key)
		if not String(built.get("error", "실패")).is_empty():
			return false
		var error: String = Dump.append_case(output, state, key, built["digest"], float(built["ms"]))
		assert_eq(error, "", key)
		if not error.is_empty():
			return false
	return true


func _append_raw(output: String, suffix: String) -> void:
	var file: FileAccess = FileAccess.open(output + ".jsonl", FileAccess.READ_WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.seek_end()
	file.store_string(suffix)
	file.flush()
	assert_eq(file.get_error(), OK)
	file.close()


func _read_final(output: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(output))
	assert_true(parsed is Dictionary)
	if not parsed is Dictionary:
		return {}
	return parsed


func _assert_final(output: String) -> void:
	var receipt: Dictionary = _read_final(output)
	assert_eq(int(receipt.get("case_count", -1)), KEYS.size())
	assert_eq(receipt.get("cases"), _expected, "한 번에 뽑은 실제 지도 지문과 같음")
	assert_eq(int(receipt.get("digest_version", -1)), BoundsDigest.VERSION)
	assert_eq(receipt.get("base_revision"), REVISION)
	assert_eq(receipt.get("sample"), false)
	assert_eq(receipt.get("determinism_verified"), true)
	var expected_fields: Array = ["digest_version", "base_revision", "base_checked", "engine",
		"seed", "forms", "bands", "sample", "case_count", "determinism_verified", "total_ms", "cases"]
	var actual_fields: Array = receipt.keys()
	expected_fields.sort()
	actual_fields.sort()
	assert_eq(actual_fields, expected_fields, "최종 JSON 필드 보존")
	assert_false(FileAccess.file_exists(output + ".tmp"), "이름을 바꾼 임시 파일은 남지 않음")
	assert_true(FileAccess.file_exists(output + ".jsonl"), "진행 기록 보존")
	var lines: PackedStringArray = FileAccess.get_file_as_string(output + ".jsonl").strip_edges().split("\n")
	assert_eq(lines.size(), KEYS.size() + 1, "머리 한 줄과 중복 없는 두 건")
	var recorded: Dictionary = {}
	for index: int in range(1, lines.size()):
		var record: Dictionary = JSON.parse_string(lines[index])
		assert_false(recorded.has(record["key"]), "겹친 건 0")
		recorded[record["key"]] = record["digest"]
	assert_eq(recorded, _expected)


func test_full_dump_matches_one_shot() -> void:
	var output: String = _folder.path_join("full.json")
	var state: Dictionary = Dump.read_progress(output, _header())
	assert_eq(state.get("error"), "")
	if not String(state.get("error", "실패")).is_empty():
		return
	var built_keys: Array[String] = []
	if not _resume(output, state, built_keys):
		return
	assert_eq(built_keys, KEYS)
	assert_eq(Dump.finish_progress(output, state, 1.0), "")
	_assert_final(output)


func test_resume_repairs_torn_tail_and_builds_only_remaining() -> void:
	var output: String = _folder.path_join("resume.json")
	var state: Dictionary = Dump.read_progress(output, _header())
	assert_eq(state.get("error"), "")
	if not String(state.get("error", "실패")).is_empty():
		return
	var first: Dictionary = Dump.build_case(KEYS[0], BareLine, true)
	assert_eq(first.get("error"), "")
	if not String(first.get("error", "실패")).is_empty():
		return
	assert_eq(Dump.append_case(output, state, KEYS[0], first["digest"], float(first["ms"])), "")
	var intact: String = FileAccess.get_file_as_string(output + ".jsonl")
	_append_raw(output, "{\"key\":\"mine_98||71|K4\",\"digest\":")
	# 새 상태로 읽어 프로세스가 사라진 상황을 흉내 낸다.
	state = Dump.read_progress(output, _header())
	assert_eq(state.get("error"), "")
	if not String(state.get("error", "실패")).is_empty():
		return
	assert_eq(state.get("repaired"), true)
	assert_eq(FileAccess.get_file_as_string(output + ".jsonl"), intact)
	assert_false(FileAccess.file_exists(output + ".jsonl.tmp"))
	var built_keys: Array[String] = []
	if not _resume(output, state, built_keys):
		return
	assert_eq(built_keys, [KEYS[1]], "완료된 첫 건은 다시 짓지 않음")
	assert_eq(Dump.finish_progress(output, state, 2.0), "")
	_assert_final(output)


func test_header_mismatch_stops_without_repair_or_append() -> void:
	var output: String = _folder.path_join("mismatch.json")
	var header: Dictionary = _header()
	var state: Dictionary = Dump.read_progress(output, header)
	assert_eq(Dump.append_case(output, state, KEYS[0], _expected[KEYS[0]], 1.0), "")
	_append_raw(output, "{broken")
	var original: String = FileAccess.get_file_as_string(output + ".jsonl")
	var alternatives: Array[Dictionary] = []
	for field: String in ["digest_version", "base_revision", "selected_maps", "keys"]:
		var different: Dictionary = header.duplicate(true)
		if field == "digest_version":
			different[field] = BoundsDigest.VERSION + 1
		elif field == "base_revision":
			different[field] = "changed-head"
		else:
			different[field] = ["different"]
		alternatives.append(different)
	for different: Dictionary in alternatives:
		var rejected: Dictionary = Dump.read_progress(output, different)
		assert_string_contains(String(rejected.get("error", "")), "판 정보")
		assert_eq(FileAccess.get_file_as_string(output + ".jsonl"), original)
	assert_false(FileAccess.file_exists(output))


func test_incomplete_dump_cannot_publish_and_duplicate_cannot_append() -> void:
	var output: String = _folder.path_join("incomplete.json")
	var state: Dictionary = Dump.read_progress(output, _header())
	assert_eq(Dump.append_case(output, state, KEYS[0], _expected[KEYS[0]], 1.0), "")
	var original: String = FileAccess.get_file_as_string(output + ".jsonl")
	assert_ne(Dump.append_case(output, state, KEYS[0], _expected[KEYS[0]], 1.0), "")
	assert_ne(Dump.finish_progress(output, state, 1.0), "")
	assert_eq(FileAccess.get_file_as_string(output + ".jsonl"), original)
	assert_false(FileAccess.file_exists(output))


func test_corrupt_middle_line_is_not_discarded() -> void:
	var output: String = _folder.path_join("middle.json")
	var state: Dictionary = Dump.read_progress(output, _header())
	assert_eq(state.get("error"), "")
	_append_raw(output, "{broken\n" + JSON.stringify({"key": KEYS[1], "digest": _expected[KEYS[1]], "ms": 1.0}) + "\n")
	var original: String = FileAccess.get_file_as_string(output + ".jsonl")
	assert_ne(Dump.read_progress(output, _header()).get("error", ""), "")
	assert_eq(FileAccess.get_file_as_string(output + ".jsonl"), original)


func test_existing_final_is_never_overwritten() -> void:
	var output: String = _folder.path_join("exists.json")
	var state: Dictionary = Dump.read_progress(output, _header())
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string("keep-existing")
	file.close()
	assert_ne(Dump.read_progress(output, _header()).get("error", ""), "")
	assert_ne(Dump.append_case(output, state, KEYS[0], _expected[KEYS[0]], 1.0), "")
	assert_ne(Dump.finish_progress(output, state, 1.0), "")
	assert_eq(FileAccess.get_file_as_string(output), "keep-existing")


func test_complete_progress_publishes_without_building_again() -> void:
	var output: String = _folder.path_join("complete.json")
	var state: Dictionary = Dump.read_progress(output, _header())
	for key: String in KEYS:
		assert_eq(Dump.append_case(output, state, key, _expected[key], 1.0), "")
	state = Dump.read_progress(output, _header())
	assert_eq(state.get("error"), "")
	var built_keys: Array[String] = []
	assert_true(_resume(output, state, built_keys))
	assert_true(built_keys.is_empty())
	assert_eq(Dump.finish_progress(output, state, 1.0), "")
	_assert_final(output)


func test_complete_tail_without_newline_is_preserved_before_append() -> void:
	var output: String = _folder.path_join("no_newline.json")
	var state: Dictionary = Dump.read_progress(output, _header())
	assert_eq(state.get("error"), "")
	_append_raw(output, JSON.stringify({"key": KEYS[0], "digest": _expected[KEYS[0]], "ms": 1.0}))
	state = Dump.read_progress(output, _header())
	assert_eq(state.get("error"), "")
	if not String(state.get("error", "실패")).is_empty():
		return
	assert_eq(state.get("repaired"), true)
	assert_eq((state["cases"] as Dictionary).size(), 1)
	assert_eq(Dump.append_case(output, state, KEYS[1], _expected[KEYS[1]], 1.0), "")
	assert_eq(Dump.finish_progress(output, state, 1.0), "")
	_assert_final(output)


func test_duplicate_record_on_disk_is_rejected_without_repair() -> void:
	var output: String = _folder.path_join("duplicate.json")
	var state: Dictionary = Dump.read_progress(output, _header())
	assert_eq(Dump.append_case(output, state, KEYS[0], _expected[KEYS[0]], 1.0), "")
	_append_raw(output, JSON.stringify({"key": KEYS[0], "digest": _expected[KEYS[0]], "ms": 1.0}) + "\n")
	var original: String = FileAccess.get_file_as_string(output + ".jsonl")
	assert_ne(Dump.read_progress(output, _header()).get("error", ""), "")
	assert_eq(FileAccess.get_file_as_string(output + ".jsonl"), original)
