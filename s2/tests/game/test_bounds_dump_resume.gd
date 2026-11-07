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
	var state_error: String = String(state.get("error", "진행 상태의 error가 없음"))
	assert_eq(state_error, "", "이어 하기 상태: " + state_error)
	if not state_error.is_empty():
		return false
	assert_true(state.get("cases") is Dictionary, "이어 하기 상태의 cases가 사전이어야 함")
	assert_true(state.get("header") is Dictionary, "이어 하기 상태의 header가 사전이어야 함")
	if not state.get("cases") is Dictionary or not state.get("header") is Dictionary:
		return false
	var cases: Dictionary = state.get("cases", {})
	for key: String in Dump.remaining_keys(KEYS, cases):
		built_keys.append(key)
		var built: Dictionary = Dump.build_case(key, BareLine, cases.is_empty())
		assert_eq(built.get("error"), "", key)
		if not String(built.get("error", "실패")).is_empty():
			return false
		var error: String = Dump.append_case(output, state, key, built.get("digest", {}), float(built.get("ms", -1.0)))
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
	assert_true(FileAccess.file_exists(output), "최종 JSON이 있어야 함: " + output)
	if not FileAccess.file_exists(output):
		return {}
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(FileAccess.get_file_as_string(output))
	assert_eq(parse_error, OK, "최종 JSON 파싱: " + parser.get_error_message())
	if parse_error != OK:
		return {}
	assert_true(parser.data is Dictionary, "최종 JSON이 사전이어야 함")
	if not parser.data is Dictionary:
		return {}
	return parser.data


func _assert_final(output: String, total_ms: float) -> void:
	var receipt: Dictionary = _read_final(output)
	assert_false(receipt.is_empty(), "최종 JSON에 결과 필드가 있어야 함")
	if receipt.is_empty():
		return
	assert_eq(int(receipt.get("case_count", -1)), KEYS.size())
	assert_eq(receipt.get("cases"), _expected, "한 번에 뽑은 실제 지도 지문과 같음")
	assert_eq(int(receipt.get("digest_version", -1)), BoundsDigest.VERSION)
	assert_eq(receipt.get("base_revision"), REVISION)
	assert_eq(receipt.get("base_checked"), "")
	assert_eq(float(receipt.get("total_ms", -1.0)), total_ms, "소수 실행 시간도 보존")
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
		var parser: JSON = JSON.new()
		var parse_error: Error = parser.parse(lines[index])
		assert_eq(parse_error, OK, "진행 기록 JSON: %d" % index)
		if parse_error != OK:
			return
		assert_true(parser.data is Dictionary, "진행 기록이 사전이어야 함")
		if not parser.data is Dictionary:
			return
		var record: Dictionary = parser.data
		assert_true(record.get("key") is String, "진행 기록의 key가 문자열이어야 함")
		assert_true(record.get("digest") is Dictionary, "진행 기록의 digest가 사전이어야 함")
		if not record.get("key") is String or not record.get("digest") is Dictionary:
			return
		var key: String = record.get("key", "")
		assert_false(recorded.has(key), "겹친 건 0")
		recorded[key] = record.get("digest", {})
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
	# 같은 머리의 숫자를 실수로, 사전 키를 역순으로 넣어도 같은 판이다.
	var parser: JSON = JSON.new()
	var header_line: String = FileAccess.get_file_as_string(output + ".jsonl").get_slice("\n", 0)
	assert_eq(parser.parse(header_line), OK)
	assert_true(parser.data is Dictionary)
	if not parser.data is Dictionary:
		return
	var round_trip: Dictionary = parser.data
	var reordered: Dictionary = {}
	var fields: Array = round_trip.keys()
	fields.reverse()
	for field: String in fields:
		reordered[field] = round_trip[field]
	for field: String in ["progress_version", "digest_version", "seed"]:
		reordered[field] = float(reordered[field])
	var saved: Dictionary = Dump.read_progress(output, reordered)
	assert_eq(saved.get("error"), "", "JSON 왕복과 사전 키 순서는 같은 머리")
	assert_eq(saved.get("cases"), _expected)
	assert_eq(saved.get("repaired"), false, "정상 파일은 복구하지 않음")
	assert_eq(Dump.finish_progress(output, state, 1.25), "")
	_assert_final(output, 1.25)


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
	assert_eq(Dump.append_case(output, state, KEYS[0], first.get("digest", {}), float(first.get("ms", -1.0))), "")
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
	_assert_final(output, 2.0)


func test_header_mismatch_stops_without_repair_or_append() -> void:
	var output: String = _folder.path_join("mismatch.json")
	var header: Dictionary = _header()
	var state: Dictionary = Dump.read_progress(output, header)
	assert_eq(Dump.append_case(output, state, KEYS[0], _expected[KEYS[0]], 1.0), "")
	_append_raw(output, "{broken")
	var original: String = FileAccess.get_file_as_string(output + ".jsonl")
	var alternatives: Array[Dictionary] = []
	for field: String in ["progress_version", "digest_version", "seed", "base_revision",
			"base_checked", "selected_maps", "keys", "forms", "bands"]:
		var different: Dictionary = header.duplicate(true)
		if field in ["progress_version", "digest_version", "seed"]:
			different[field] = int(header[field]) + 1
		elif field in ["base_revision", "base_checked"]:
			different[field] = "changed-revision"
		elif field in ["keys", "forms", "bands"]:
			var reversed: Array = (header[field] as Array).duplicate()
			reversed.reverse()
			different[field] = reversed
		else:
			different[field] = ["different"]
		alternatives.append(different)
	# 정수로 자르거나 문자열로 바꿔 잘못된 판을 받아들이지 않아야 한다.
	for field: String in ["progress_version", "digest_version", "seed"]:
		var fractional: Dictionary = header.duplicate(true)
		fractional[field] = float(header[field]) + 0.25
		alternatives.append(fractional)
		var string_number: Dictionary = header.duplicate(true)
		string_number[field] = str(header[field])
		alternatives.append(string_number)
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
	assert_string_contains(Dump.finish_progress(output, state, 1.0), "아직 끝나지 않은 건")
	assert_eq(FileAccess.get_file_as_string(output + ".jsonl"), original)
	assert_false(FileAccess.file_exists(output))


func test_corrupt_middle_line_is_not_discarded() -> void:
	var output: String = _folder.path_join("middle.json")
	var state: Dictionary = Dump.read_progress(output, _header())
	assert_eq(state.get("error"), "")
	_append_raw(output, "{broken\n" + JSON.stringify({"key": KEYS[1], "digest": _expected[KEYS[1]], "ms": 1.0}) + "\n")
	var original: String = FileAccess.get_file_as_string(output + ".jsonl")
	assert_string_contains(String(Dump.read_progress(output, _header()).get("error", "")), "중간 줄")
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
	if not _resume(output, state, built_keys):
		return
	assert_true(built_keys.is_empty())
	assert_eq(Dump.finish_progress(output, state, 1.0), "")
	_assert_final(output, 1.0)


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
	assert_true(state.get("cases") is Dictionary, "복구 상태의 cases가 사전이어야 함")
	if not state.get("cases") is Dictionary:
		return
	assert_eq((state.get("cases", {}) as Dictionary).size(), 1)
	assert_eq(Dump.append_case(output, state, KEYS[1], _expected[KEYS[1]], 1.0), "")
	assert_eq(Dump.finish_progress(output, state, 1.0), "")
	_assert_final(output, 1.0)


func test_duplicate_record_on_disk_is_rejected_without_repair() -> void:
	var output: String = _folder.path_join("duplicate.json")
	var state: Dictionary = Dump.read_progress(output, _header())
	assert_eq(Dump.append_case(output, state, KEYS[0], _expected[KEYS[0]], 1.0), "")
	_append_raw(output, JSON.stringify({"key": KEYS[0], "digest": _expected[KEYS[0]], "ms": 1.0}) + "\n")
	var original: String = FileAccess.get_file_as_string(output + ".jsonl")
	assert_string_contains(String(Dump.read_progress(output, _header()).get("error", "")), "대상 밖/중복/빈 지문")
	assert_eq(FileAccess.get_file_as_string(output + ".jsonl"), original)
