extends SceneTree
## 정차 지도 지문 뽑기(결정 548 경계 PR의 「지형이 안 바뀜」 확인).
##
## 표본 다시 뽑기 — 표본에 든 지도를 일부러 바꾼 PR은 이 한 줄을 돌려 표본 파일을 같이 커밋한다:
##   godot --headless --path s2 -s res://tools/bounds_baseline_dump.gd -- --sample
## (tests/fixtures/bounds_baseline_sample.json의 열쇠를 지금 코드로 다시 지어 덮어쓴다. 3분 안팎.)
##
## 전체 뽑기 — 경계 PR마다 갈래 자리와 PR 머리를 같은 도구로 뽑아 맞댄다(82장 × 꼴 셋 × 띠 둘 = 492건, 25~45분):
##   godot --headless --path s2 -s res://tools/bounds_baseline_dump.gd -- --out <절대 경로.json> [--base <sha>] [--only a,b]
## --base를 주면 그 커밋과 게임 코드가 같은지 먼저 본다(이 도구·지문 도우미·.import 제외). 전체 뽑기는 기존 파일을 덮어쓰지 않는다.

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
	print("BOUNDS_DUMP_START cases=%d seed=%d sample=%s base=%s" % [keys.size(), RUN_SEED, str(sample), base.left(8)])
	for key: String in keys:
		var parts: PackedStringArray = key.split("|", true)
		if parts.size() != 4 or not all_ids.has(parts[0]) or int(parts[2]) != RUN_SEED:
			_fail("열쇠 꼴이 다릅니다: " + key)
			return
		var script: Script = load(FieldMaps.path_of(parts[0])) as Script
		if script == null:
			_fail("지도 스크립트를 읽지 못했습니다: " + parts[0])
			return
		var case_started_us: int = Time.get_ticks_usec()
		var data: Dictionary = StopLoader.make_ready(script, RUN_SEED, parts[1], -1.0, parts[3])
		if String(data.get("place_id", "")) != parts[0]:
			_fail("요청 지도와 실제 지도가 다릅니다: " + key)
			return
		var fingerprint: Dictionary = BoundsDigest.digest(data)
		cases[key] = fingerprint
		data.clear()
		print("BOUNDS_CASE key=%s ms=%.1f" % [key, _ms_since(case_started_us)])
		if not verified:
			# 자료를 놓은 뒤 새로 짓는다. 같은 사전을 두 번 해시하는 검사가 아니다.
			var again: Dictionary = BoundsDigest.digest(StopLoader.make_ready(script, RUN_SEED, parts[1], -1.0, parts[3]))
			var changed: Array[String] = changed_items(fingerprint, again)
			print("BOUNDS_DETERMINISM key=%s equal=%s changed=%s" % [key, str(changed.is_empty()), str(changed)])
			if not changed.is_empty():
				_fail("같은 입력으로 다시 지은 지도 지문이 다릅니다")
				return
			verified = true
	var receipt: Dictionary = {
		"digest_version": BoundsDigest.VERSION, "base_revision": _head(), "base_checked": base,
		"engine": Engine.get_version_info(), "seed": RUN_SEED, "forms": FORMS, "bands": BANDS,
		"sample": sample, "case_count": cases.size(), "determinism_verified": verified,
		"total_ms": _ms_since(started_us), "cases": cases,
	}
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
