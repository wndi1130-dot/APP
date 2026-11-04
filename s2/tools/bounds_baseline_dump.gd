extends SceneTree
## 정차 지도 지문 뽑기(결정 548 경계 PR의 「지형이 안 바뀜」 확인).
##
## 표본 다시 뽑기 — 표본에 든 지도를 일부러 바꾼 PR은 이 한 줄을 돌려 표본 파일을 같이 커밋한다:
##   godot --headless --path s2 -s res://tools/bounds_baseline_dump.gd -- --sample
## (tests/fixtures/bounds_baseline_sample.json의 열쇠를 지금 코드로 다시 지어 덮어쓴다. 3분 안팎.)
##
## 전체 뽑기 — 경계 PR마다 갈래 자리와 PR 머리를 같은 도구로 뽑아 맞댄다:
##   godot --headless --path s2 -s res://tools/bounds_baseline_dump.gd -- --out <절대 경로.json> [--base <sha>] [--only a,b]
## --base를 주면 그 커밋과 게임 코드가 같은지 먼저 본다(이 도구·지문 도우미·.import 제외). 전체 뽑기는 기존 파일을 덮어쓰지 않는다.
## <out>.jsonl은 매 건 flush하며 남겨 둔다. 같은 인자로 다시 실행하면 이어서 짓는다.

const FieldMaps = preload("res://game/world/field_maps.gd")
const StopLoader = preload("res://game/stop_loader.gd")
const BoundsDigest = preload("res://tests/game/bounds_digest.gd")
const SAMPLE: String = "res://tests/fixtures/bounds_baseline_sample.json"
const RUN_SEED: int = 71
const FORMS: Array[String] = ["", "edge", "remote"]
## 지역 띠 회귀 표본 K4(test_stop_loader와 같은 띠).
const BANDS: Array[String] = ["", "K4"]
## 경계를 켠 지도는 전체 뽑기에서 뺀다(그 PR이 지형을 일부러 바꾼다).
const BOUNDS_ON: Array[String] = ["lake_01"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var sample: bool = false
	var output: String = ""
	var base: String = ""
	var all_ids: Array[String] = FieldMaps.all_ids()
	var selected: Array[String] = []
	var seen: Dictionary = {}
	var index: int = 0
	while index < args.size():
		var option: String = args[index]
		if seen.has(option) or option not in ["--sample", "--only", "--out", "--base"]:
			_fail("알 수 없거나 중복된 인자: " + option)
			return
		seen[option] = true
		index += 1
		if option == "--sample":
			sample = true
			continue
		if index >= args.size() or args[index].is_empty() or args[index].begins_with("--"):
			_fail("인자 값이 필요합니다: " + option)
			return
		var value: String = args[index]
		index += 1
		if option == "--out":
			if not value.begins_with("res://") and (not value.is_absolute_path() or value.contains("://")):
				_fail("--out에는 res:// 또는 절대 경로가 필요합니다")
				return
			output = value
		elif option == "--base":
			base = value
		else:
			for raw_id: String in value.split(",", true):
				var place_id: String = raw_id.strip_edges()
				if not all_ids.has(place_id) or selected.has(place_id):
					_fail("등록되지 않았거나 중복된 지도: " + place_id)
					return
				selected.append(place_id)
	if sample and (not output.is_empty() or not base.is_empty() or not selected.is_empty()):
		_fail("--sample은 혼자 쓴다")
		return
	if not sample and output.is_empty():
		_fail("전체 뽑기는 --out이 필요합니다(표본은 --sample)")
		return
	if not base.is_empty() and not _same_code_as(base):
		return
	var keys: Array[String] = []
	if sample:
		output = SAMPLE
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE))
		if not old is Dictionary or not (old as Dictionary).get("cases") is Dictionary:
			_fail("표본 파일을 읽지 못했습니다: " + SAMPLE)
			return
		for key: Variant in ((old as Dictionary)["cases"] as Dictionary).keys():
			keys.append(String(key))
		keys.sort()
	else:
		if FileAccess.file_exists(output):
			_fail("기존 파일을 덮어쓰지 않습니다: " + output)
			return
		if selected.is_empty():
			selected.assign(all_ids)
			for place_id: String in BOUNDS_ON:
				selected.erase(place_id)
		for place_id: String in selected:
			for form: String in FORMS:
				for band: String in BANDS:
					keys.append("%s|%s|%d|%s" % [place_id, form, RUN_SEED, band])
	var started_us: int = Time.get_ticks_usec()
	var cases: Dictionary = {}
	var verified: bool = false
	var progress: Dictionary = {}
	if not sample:
		var revision: String = _head()
		if revision == "unknown":
			_fail("이어 하기용 코드 HEAD를 확인하지 못했습니다")
			return
		progress = read_progress(output, progress_header(selected, keys, revision, base))
		if not String(progress["error"]).is_empty():
			_fail(String(progress["error"]))
			return
		cases = progress["cases"]
		# 첫 건은 결정성 확인까지 끝내야 기록한다. 기록된 건은 다시 짓지 않는다.
		verified = not cases.is_empty()
	print("BOUNDS_DUMP_START cases=%d seed=%d sample=%s base=%s" % [keys.size(), RUN_SEED, str(sample), base.left(8)])
	for key: String in remaining_keys(keys, cases):
		var built: Dictionary = build_case(key, null, not verified)
		if not String(built["error"]).is_empty():
			_fail(String(built["error"]))
			return
		if sample:
			cases[key] = built["digest"]
		else:
			var append_error: String = append_case(output, progress, key, built["digest"], float(built["ms"]))
			if not append_error.is_empty():
				_fail(append_error)
				return
		verified = true
		print("BOUNDS_CASE key=%s ms=%.1f" % [key, float(built["ms"])])
	if not sample:
		var finish_error: String = finish_progress(output, progress, _ms_since(started_us))
		if not finish_error.is_empty():
			_fail(finish_error)
			return
		print("BOUNDS_DUMP_DONE cases=%d total_ms=%.1f file=%s" % [cases.size(), _ms_since(started_us), output])
		quit(0)
		return
	# 표본은 기존 경로에 기존 JSON 꼴로 직접 덮어쓴다. 진행 파일을 쓰지 않는다.
	var receipt: Dictionary = make_receipt(cases, _head(), base, sample, verified, _ms_since(started_us))
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	if directory_error != OK:
		_fail("폴더를 만들지 못했습니다: %d" % directory_error)
		return
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		_fail("파일을 열지 못했습니다: %d" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(receipt, "\t", true, true) + "\n")
	file.close()
	var readback: Variant = JSON.parse_string(FileAccess.get_file_as_string(output))
	if not readback is Dictionary or (readback as Dictionary).get("cases", {}) != cases:
		_fail("다시 읽은 결과가 다릅니다: " + output)
		return
	print("BOUNDS_DUMP_DONE cases=%d total_ms=%.1f file=%s" % [cases.size(), _ms_since(started_us), output])
	quit(0)


## 시험은 작은 지도 Script를 주입하되 실제 make_ready/지문 경로를 그대로 쓴다.
static func build_case(key: String, map_script: Script = null, verify: bool = false) -> Dictionary:
	var parts: PackedStringArray = key.split("|", true)
	if parts.size() != 4 or int(parts[2]) != RUN_SEED:
		return {"error": "열쇠 꼴이 다릅니다: " + key}
	if map_script == null:
		if not FieldMaps.all_ids().has(parts[0]):
			return {"error": "등록되지 않은 지도: " + parts[0]}
		map_script = load(FieldMaps.path_of(parts[0])) as Script
	if map_script == null:
		return {"error": "지도 스크립트를 읽지 못했습니다: " + parts[0]}
	var started_us: int = Time.get_ticks_usec()
	var data: Dictionary = StopLoader.make_ready(map_script, RUN_SEED, parts[1], -1.0, parts[3])
	if String(data.get("place_id", "")) != parts[0]:
		return {"error": "요청 지도와 실제 지도가 다릅니다: " + key}
	var fingerprint: Dictionary = BoundsDigest.digest(data)
	data.clear()
	var elapsed_ms: float = _ms_since(started_us)
	if verify:
		var again: Dictionary = BoundsDigest.digest(StopLoader.make_ready(map_script, RUN_SEED, parts[1], -1.0, parts[3]))
		var changed: Array[String] = changed_items(fingerprint, again)
		print("BOUNDS_DETERMINISM key=%s equal=%s changed=%s" % [key, str(changed.is_empty()), str(changed)])
		if not changed.is_empty():
			return {"error": "같은 입력으로 다시 지은 지도 지문이 다릅니다"}
	return {"error": "", "digest": fingerprint, "ms": elapsed_ms}


static func progress_header(selected: Array[String], keys: Array[String], revision: String, base: String = "") -> Dictionary:
	var maps: Array[String] = selected.duplicate()
	maps.sort()
	return {
		"progress_version": 1, "digest_version": BoundsDigest.VERSION,
		"selected_maps": maps, "keys": keys.duplicate(), "base_revision": revision,
		"base_checked": base, "seed": RUN_SEED, "forms": FORMS, "bands": BANDS,
	}


## error가 빈 상태만 쓸 수 있다. 깨진 중간 줄·중복·대상 밖 기록은 복구하지 않는다.
static func read_progress(output: String, header: Dictionary) -> Dictionary:
	if FileAccess.file_exists(output):
		return {"error": "기존 파일을 덮어쓰지 않습니다: " + output}
	var path: String = output + ".jsonl"
	var cases: Dictionary = {}
	if not FileAccess.file_exists(path):
		var create_error: String = _replace_text(path, JSON.stringify(header) + "\n")
		if not create_error.is_empty():
			return {"error": create_error}
		return {"error": "", "header": header, "cases": cases, "repaired": false}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "진행 파일을 읽지 못했습니다: " + path}
	var length: int = file.get_length()
	var bytes: PackedByteArray = file.get_buffer(length)
	var read_error: Error = file.get_error()
	file.close()
	if bytes.size() != length or read_error not in [OK, ERR_FILE_EOF]:
		return {"error": "진행 파일 읽기 실패: %d" % read_error}
	var contents: String = bytes.get_string_from_utf8()
	var lines: PackedStringArray = contents.split("\n", true)
	if lines[lines.size() - 1].is_empty():
		lines.remove_at(lines.size() - 1)
	var parser: JSON = JSON.new()
	if lines.is_empty() or parser.parse(lines[0]) != OK or not parser.data is Dictionary:
		return {"error": "진행 파일 머리가 깨졌습니다: " + path}
	if JSON.stringify(parser.data) != JSON.stringify(header):
		return {"error": "진행 파일 판 정보가 다릅니다: " + path}
	var retained: String = lines[0] + "\n"
	var repaired: bool = not contents.ends_with("\n")
	var expected_keys: Array = header["keys"]
	for line_index: int in range(1, lines.size()):
		if parser.parse(lines[line_index]) != OK:
			if line_index != lines.size() - 1:
				return {"error": "진행 파일 중간 줄이 깨졌습니다: %d" % (line_index + 1)}
			repaired = true
			break
		if not parser.data is Dictionary:
			return {"error": "진행 기록 꼴이 다릅니다: %d" % (line_index + 1)}
		var record: Dictionary = parser.data
		if not record.get("key") is String or not record.get("digest") is Dictionary:
			return {"error": "진행 기록 열쇠/지문이 잘못됐습니다"}
		var key: String = record["key"]
		var digest: Dictionary = record["digest"]
		var elapsed: Variant = record.get("ms")
		if not (elapsed is float or elapsed is int) or float(elapsed) < 0.0 or not is_finite(float(elapsed)):
			return {"error": "진행 기록 시간이 잘못됐습니다: " + key}
		if not expected_keys.has(key) or cases.has(key) or digest.is_empty():
			return {"error": "대상 밖/중복/빈 지문인 진행 기록: " + key}
		cases[key] = digest
		retained += lines[line_index] + "\n"
	if repaired:
		var repair_error: String = _replace_text(path, retained)
		if not repair_error.is_empty():
			return {"error": repair_error}
	return {"error": "", "header": header, "cases": cases, "repaired": repaired}


static func remaining_keys(keys: Array[String], cases: Dictionary) -> Array[String]:
	var remaining: Array[String] = []
	for key: String in keys:
		if not cases.has(key):
			remaining.append(key)
	return remaining


## 한 실행만 같은 out을 소유한다. flush 성공 뒤에만 메모리의 완료 목록에 넣는다.
static func append_case(output: String, progress: Dictionary, key: String, digest: Dictionary, elapsed_ms: float) -> String:
	if String(progress.get("error", "상태 없음")) != "" or FileAccess.file_exists(output):
		return "진행 상태 오류 또는 이미 있는 최종 파일: " + output
	var cases: Dictionary = progress["cases"]
	var header: Dictionary = progress["header"]
	if not (header["keys"] as Array).has(key) or cases.has(key) or digest.is_empty():
		return "대상 밖/중복/빈 지문인 건: " + key
	if elapsed_ms < 0.0 or not is_finite(elapsed_ms):
		return "건 시간이 잘못됐습니다: " + key
	var path: String = output + ".jsonl"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		return "진행 파일을 열지 못했습니다: " + path
	file.seek_end()
	file.store_line(JSON.stringify({"key": key, "digest": digest, "ms": elapsed_ms}))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return "진행 기록 쓰기 실패: %d" % write_error
	cases[key] = digest
	return ""


static func make_receipt(cases: Dictionary, revision: String, base: String, sample: bool, verified: bool, total_ms: float) -> Dictionary:
	return {
		"digest_version": BoundsDigest.VERSION, "base_revision": revision, "base_checked": base,
		"engine": Engine.get_version_info(), "seed": RUN_SEED, "forms": FORMS, "bands": BANDS,
		"sample": sample, "case_count": cases.size(), "determinism_verified": verified,
		"total_ms": total_ms, "cases": cases,
	}


static func finish_progress(output: String, progress: Dictionary, total_ms: float) -> String:
	if String(progress.get("error", "상태 없음")) != "" or FileAccess.file_exists(output):
		return "진행 상태 오류 또는 이미 있는 최종 파일: " + output
	var header: Dictionary = progress["header"]
	var keys: Array[String] = []
	keys.assign(header["keys"])
	# 마무리도 디스크의 기록을 기준으로 한다. 저장하지 못한 메모리 자료는 쓰지 않는다.
	var saved: Dictionary = read_progress(output, header)
	if not String(saved["error"]).is_empty():
		return String(saved["error"])
	var cases: Dictionary = saved["cases"]
	if not remaining_keys(keys, cases).is_empty():
		return "아직 끝나지 않은 건이 있습니다"
	var receipt: Dictionary = make_receipt(cases, String(header["base_revision"]),
		String(header["base_checked"]), false, not cases.is_empty(), total_ms)
	var temporary: String = output + ".tmp"
	var write_error: String = _write_text(temporary, JSON.stringify(receipt, "\t", true, true) + "\n")
	if not write_error.is_empty():
		return write_error
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(temporary)) != OK or JSON.stringify(parser.data) != JSON.stringify(receipt):
		return "다시 읽은 최종 JSON이 다릅니다: " + temporary
	if FileAccess.file_exists(output):
		return "기존 파일을 덮어쓰지 않습니다: " + output
	var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(output))
	return "" if rename_error == OK else "최종 파일 이름 바꾸기 실패: %d" % rename_error


static func _write_text(path: String, contents: String) -> String:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if directory_error != OK:
		return "폴더를 만들지 못했습니다: %d" % directory_error
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "파일을 열지 못했습니다: " + path
	file.store_string(contents)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	return "" if write_error == OK else "파일 쓰기 실패: %d" % write_error


static func _replace_text(path: String, contents: String) -> String:
	var temporary: String = path + ".tmp"
	var write_error: String = _write_text(temporary, contents)
	if not write_error.is_empty():
		return write_error
	if FileAccess.get_file_as_bytes(temporary) != contents.to_utf8_buffer():
		return "다시 읽은 진행 파일이 다릅니다: " + temporary
	var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	return "" if rename_error == OK else "진행 파일 이름 바꾸기 실패: %d" % rename_error


## 기준 커밋과 게임 코드가 같은지(이 도구·지문 도우미·.import 제외). 다르면 잘못된 기준을 쓰지 않는다.
func _same_code_as(base: String) -> bool:
	var output: Array = []
	var code: int = OS.execute("git", PackedStringArray([
		"-C", ProjectSettings.globalize_path("res://"), "diff", "--quiet", base, "--", ".",
		":(exclude)tests/game/bounds_digest.gd", ":(exclude)tools/bounds_baseline_dump.gd",
		":(exclude)tools/_bounds_baseline_dump.gd", ":(exclude)tests/fixtures", ":(exclude)*.import",
	]), output, true)
	if code != 0:
		_fail("기준 코드 확인 실패(exit=%d): %s" % [code, str(output)])
		return false
	return true


func _head() -> String:
	var output: Array = []
	if OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"]), output, true) != 0 or output.is_empty():
		return "unknown"
	return String(output[0]).strip_edges()


func _fail(message: String) -> void:
	push_error("BOUNDS_DUMP_FAILED " + message)
	quit(1)


static func _ms_since(started_us: int) -> float:
	return float(Time.get_ticks_usec() - started_us) / 1000.0


static func changed_items(first: Dictionary, second: Dictionary) -> Array[String]:
	var keys: Dictionary = first.duplicate()
	keys.merge(second)
	var changed: Array[String] = []
	for key: String in keys:
		if not first.has(key) or not second.has(key) or first[key] != second[key]:
			changed.append(key)
	changed.sort()
	return changed
