extends SceneTree
## 한 out은 한 프로세스가 소유한다. JSONL은 뽑기 도구와 같은 {key,digest,ms} 꼴이다.
const Loader = preload("res://game/stop_loader.gd")
const Maps = preload("res://game/world/field_maps.gd")
const Bounds = preload("res://game/world/map_bounds.gd")
const Rule = preload("res://game/world/map_bounds_rule.gd")
const Grid = preload("res://game/world/field_grid.gd")
const Dump = preload("res://tools/bounds_baseline_dump.gd")
const VERSION: String = "bounds-ratio-sweep-1"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var options: Dictionary = {"--out": "", "--seeds": "1-50,71", "--forms": ",edge,remote", "--place": "lake_01"}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() % 2 != 0:
		_fail("옵션마다 값이 필요합니다")
		return
	var seen: Dictionary = {}
	for i: int in range(0, args.size(), 2):
		if not options.has(args[i]) or seen.has(args[i]):
			_fail("알 수 없거나 중복인 옵션: " + args[i])
			return
		seen[args[i]] = true
		options[args[i]] = args[i + 1]
	var output: String = options["--out"]
	var place: String = options["--place"]
	if not output.is_absolute_path() or output.begins_with("user://") or output.begins_with("res://") or not output.ends_with(".json"):
		_fail("--out에는 절대 경로.json이 필요합니다")
		return
	if not Rule.enabled(place) or not Maps.has(place):
		_fail("경계 ON인 실제 지도만 지정할 수 있습니다: " + place)
		return
	var seeds: Array[int] = _seeds(options["--seeds"])
	if seeds.is_empty():
		_fail("씨앗은 0 이상 정수/오름차순 범위의 쉼표 목록입니다")
		return
	var forms: Array[String] = []
	for form: String in String(options["--forms"]).split(",", true):
		if form not in ["", "edge", "remote"] or forms.has(form):
			_fail("꼴은 기본(빈 문자열), edge, remote를 중복 없이 지정합니다")
			return
		forms.append(form)
	var revision: String = _head()
	if revision.is_empty():
		_fail("HEAD 조회 실패")
		return
	var source_hash: String = _source_hash()
	if source_hash.is_empty():
		_fail("소스 지문 읽기 실패")
		return
	var keys: Array[String] = []
	for form: String in forms:
		for seed_value: int in seeds: keys.append("%s|%s|%d|" % [place, form, seed_value])
	# JSON은 정수를 float로 읽는다. 머리를 한 번 정규화해 공용 도우미의 문자열 대조도 안정시킨다.
	var header: Dictionary = JSON.parse_string(JSON.stringify({"progress_version": VERSION,
		"bounds_rule": Rule.RULE, "base_revision": revision, "source_sha256": source_hash,
		"engine": Engine.get_version_info(), "place": place, "seeds": seeds, "forms": forms,
		"band": "", "form_m": -1.0, "keys": keys}))
	var progress: Dictionary = Dump.read_progress(output, header)
	if not String(progress["error"]).is_empty():
		_fail(progress["error"])
		return
	var script: Script = load(Maps.path_of(place))
	var started: int = Time.get_ticks_usec()
	var fingerprint_time: Dictionary = {"usec": 0}
	for form: String in forms:
		for seed_value: int in seeds:
			var key: String = "%s|%s|%d|" % [place, form, seed_value]
			if progress["cases"].has(key): continue
			var mark: int = Time.get_ticks_usec()
			var fingerprint_before: int = int(fingerprint_time.get("usec", 0))
			var record: Dictionary = _case(script, place, form, seed_value, fingerprint_time)
			var fingerprint_usec: int = int(fingerprint_time.get("usec", 0)) - fingerprint_before
			var case_ms: float = float(Time.get_ticks_usec() - mark - fingerprint_usec) / 1000.0
			var error: String = Dump.append_case(output, progress, key, record, case_ms)
			if not error.is_empty():
				_fail(error)
				return
			print("bounds/sweep %s stamp=%s ratio=%s" % [key, str(record["stamped"]), str(record["new_ratio"])])
	# 메모리 대신 flush한 디스크를 다시 읽고 요약한다.
	progress = Dump.read_progress(output, header)
	if not String(progress["error"]).is_empty() or not Dump.remaining_keys(keys, progress.get("cases", {})).is_empty():
		_fail("마무리 진행 확인 실패: " + String(progress.get("error", "")))
		return
	if _source_hash() != source_hash or _head() != revision:
		_fail("실행 중 소스 또는 HEAD 변경: 기존 진행 파일을 다른 판과 섞지 않습니다")
		return
	var receipt: Dictionary = {"header": header, "case_count": keys.size(), "forms": _summary(progress["cases"], forms),
		"elapsed_this_run_ms": float(Time.get_ticks_usec() - started - int(fingerprint_time.get("usec", 0))) / 1000.0,
		"timing_note": "paired_ms의 null은 해당 단계 없음. budget_delta_ms는 ring_expand+ring_lights+bounds+bounds_work_prepare+bounds_groves+edge_plan의 판 1 - 판 0 차이. build_plain은 제외. 새 tree/connect 지문 계산은 단계 측정 뒤 실행하며 JSONL ms와 elapsed_this_run_ms에서도 제외."}
	if FileAccess.file_exists(output):
		_fail("기존 최종 파일을 덮어쓰지 않습니다: " + output)
		return
	# 공용 도우미: 같은 폴더 임시 파일 -> 바이트 대조 -> 이름 바꾸기.
	var finish_error: String = Dump._replace_text(output, JSON.stringify(receipt, "\t", true, true) + "\n")
	if not finish_error.is_empty():
		_fail(finish_error)
		return
	print("bounds/sweep 완료: " + output)
	quit(0)


static func _seeds(value: String) -> Array[int]:
	var out: Array[int] = []
	for part: String in value.split(",", true):
		var ends: PackedStringArray = part.split("-", true)
		if ends.size() not in [1, 2] or not ends[0].is_valid_int(): return []
		if ends.size() == 2 and not ends[1].is_valid_int(): return []
		var first: int = int(ends[0])
		var last: int = int(ends[-1])
		if first < 0 or last < first or last > 2147483646: return []
		for seed_value: int in range(first, last + 1):
			if not out.has(seed_value): out.append(seed_value)
	return out


static func _case(script: Script, place: String, form: String, seed_value: int, fingerprint_time: Dictionary = {}) -> Dictionary:
	var on_observed: Dictionary = {"_sweep": true}
	var zero_observed: Dictionary = {"_sweep": true}
	var active: Dictionary = Loader.make_ready(script, seed_value, form, -1.0, "", -1, Callable(), on_observed)
	var base: Dictionary = Loader.make_ready(script, seed_value, form, -1.0, "", 0, Callable(), zero_observed)
	var stamped: bool = int(active.get("bounds_stamp", 0)) == Rule.RULE
	var grid: Grid = active["grid"]
	var base_grid: Grid = base["grid"]
	var denominator: int = Bounds.count_playable(base)
	var numerator: int = Bounds.count_playable(active)
	var old_denominator: int = base_grid.walk_people.count(1)
	var old_numerator: int = grid.walk_people.count(1)
	var attempts: Array = active.get("bounds_attempts", [])
	var times: Dictionary = active.get("_ms", {}).duplicate()
	var base_times: Dictionary = base.get("_ms", {}).duplicate()
	on_observed.erase("_sweep")
	zero_observed.erase("_sweep")
	times.merge(on_observed, true)
	base_times.merge(zero_observed, true)
	var names: Dictionary = times.duplicate()
	names.merge(base_times)
	var paired: Dictionary = {}
	for name: String in names:
		paired[name] = {"on": times.get(name), "zero": base_times.get(name)}
	var envelope: float = 0.0
	for name: String in ["ring_expand", "ring_lights", "bounds", "bounds_work_prepare", "bounds_groves", "edge_plan"]:
		envelope += float(times.get(name, 0.0)) - float(base_times.get(name, 0.0))
	var blocked: int = int(active.get("bounds_blocked", -1))
	var new_ratio: Variant = float(numerator) / denominator if stamped and denominator > 0 else null
	var blocked_share: Variant = float(blocked) / (grid.width * grid.height) if stamped else null
	# 게임 생성과 모든 단계 측정이 끝난 뒤 읽기만 한다. 바깥 경과 시간에서도 이 구간을 뺀다.
	var fingerprint_started: int = Time.get_ticks_usec()
	var tree_fingerprint: String = _tree_fingerprint(active)
	var tree_fingerprint_zero: String = _tree_fingerprint(base)
	var connect_fingerprint: String = _connect_fingerprint(attempts)
	fingerprint_time["usec"] = int(fingerprint_time.get("usec", 0)) + Time.get_ticks_usec() - fingerprint_started
	return {"place": place, "form": form, "seed": seed_value, "stamped": stamped,
		"bounds_stamp": active.get("bounds_stamp"), "failure": active.get("bounds_failure", ""),
		"attempt_count": attempts.size(), "attempts": attempts,
		"new_walk": numerator if stamped else null, "new_denominator": denominator, "new_ratio": new_ratio,
		"old_walk": old_numerator if stamped else null, "old_denominator": old_denominator,
		"old_ratio": float(old_numerator) / old_denominator if stamped and old_denominator > 0 else null,
		"newly_blocked": blocked if stamped else null, "blocked_denominator": grid.width * grid.height if stamped else null,
		"blocked_share": blocked_share, "ratio_pass": stamped and denominator > 0 and (numerator * 10 >= denominator * 11 if Rule.PLAN_A else numerator * 4 >= denominator * 5),
		"blocked_pass": stamped and blocked >= 0 and float(blocked) / (grid.width * grid.height) <= 0.18,
		"paired_ms": paired, "budget_delta_ms": envelope, "budget_pass": stamped and envelope <= 100.0,
		"outline_fingerprint": _fingerprint(active.get("bounds", {})) if stamped else "",
		"tree_fingerprint": tree_fingerprint, "tree_fingerprint_zero": tree_fingerprint_zero,
		"connect_fingerprint": connect_fingerprint}


## 각 항목을 문자열로 정규화해 정렬한다. 실행 순서와 Dictionary 삽입 순서에 기대지 않는다.
static func _fingerprint(bounds: Dictionary) -> String:
	var parts: Array[String] = []
	for point: Vector2i in bounds.get("outline", []): parts.append("p:%d,%d" % [point.x, point.y])
	var points: Array = bounds.get("outline", [])
	for run: Dictionary in bounds.get("runs", []):
		for i: int in range(int(run["from"]), int(run["to"])):
			var a: Vector2i = points[i]
			var b: Vector2i = points[(i + 1) % points.size()]
			parts.append("s:%s:%d,%d:%d,%d" % [run["kind"], a.x, a.y, b.x, b.y])
	for tile: Dictionary in bounds.get("tiles", []):
		var rect: Rect2i = tile["rect"]
		parts.append("t:%s:%d,%d:%d,%d" % [tile["kind"], rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	parts.sort()
	return "\n".join(parts).sha256_text().left(16)


## 소수를 반올림하지 않고 64비트 실수 바이트를 고정 길이 16진수로 담는다.
static func _float_fingerprint(value: float) -> String:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()


## 키 삽입 순서 대신 이 순서로 읽는다. skip과 크기 키의 유무도 구별한다.
static func _tree_item_parts(parts: Array[String], item: Dictionary) -> void:
	var at: Vector3 = item.get("at", Vector3.ZERO)
	parts.append("at:%d:%s:%s:%s" % [int(item.has("at")), _float_fingerprint(at.x), _float_fingerprint(at.y), _float_fingerprint(at.z)])
	parts.append("model:" + String(item.get("model", "")).to_utf8_buffer().hex_encode())
	for field: String in ["yaw", "height", "spread", "scale"]:
		parts.append("%s:%d:%s" % [field, int(item.has(field)), _float_fingerprint(float(item.get(field, 0.0)))])
	parts.append("skip:%d" % int(bool(item.get("skip", false))))


## trees의 첨자가 fell_groves의 plan_idx다. 숨긴 나무도 포함하고 배열을 정렬하지 않는다.
static func _tree_fingerprint(data: Dictionary) -> String:
	var plan: Dictionary = data.get("_edge_plan", {}).get("plan", {})
	var trees: Array = plan.get("trees", [])
	var parts: Array[String] = ["trees-v1", "plan:%d" % int(not plan.is_empty()), "trees:%d" % trees.size()]
	for plan_idx: int in range(trees.size()):
		parts.append("plan_idx:%d" % plan_idx)
		var tree: Dictionary = trees[plan_idx]
		_tree_item_parts(parts, tree)
	var glades: Array = plan.get("glades", [])
	parts.append("glades:%d" % glades.size())
	for glade: Dictionary in glades:
		var rect: Rect2 = glade.get("rect", Rect2())
		parts.append("glade:%s:%d:%s:%s:%s:%s" % [String(glade.get("kind", "")).to_utf8_buffer().hex_encode(), int(bool(glade.get("skip", false))), _float_fingerprint(rect.position.x), _float_fingerprint(rect.position.y), _float_fingerprint(rect.size.x), _float_fingerprint(rect.size.y)])
		var props: Array = glade.get("props", [])
		parts.append("props:%d" % props.size())
		for prop: Dictionary in props: _tree_item_parts(parts, prop)
	var clear: Array = plan.get("clear", [])
	parts.append("clear:%d" % clear.size())
	for rect: Rect2 in clear:
		parts.append("rect:%s:%s:%s:%s" % [_float_fingerprint(rect.position.x), _float_fingerprint(rect.position.y), _float_fingerprint(rect.size.x), _float_fingerprint(rect.size.y)])
	for key: String in ["fell_groves", "_bounds_groves"]:
		var groves: Array = data.get(key, [])
		parts.append("%s:%d" % [key, groves.size()])
		for grove: Dictionary in groves:
			parts.append("grove:%s:%d:%d:%d:%d" % [String(grove.get("kind", "")).to_utf8_buffer().hex_encode(), int(grove.get("level", 0)), int(grove.get("trees", 0)), int(bool(grove.get("edge", false))), int(bool(grove.get("bounds", false)))])
			for field: String in ["cells", "stand"]:
				var cells: Array = grove.get(field, [])
				parts.append("%s:%d" % [field, cells.size()])
				for cell: Vector2i in cells: parts.append("%d,%d" % [cell.x, cell.y])
			var indices: Array = grove.get("plan_idx", [])
			parts.append("indices:%d" % indices.size())
			for plan_idx: int in indices: parts.append("%d" % plan_idx)
	return "\n".join(parts).sha256_text().left(16)


## 이번 from부터 다음 from 직전까지(마지막은 배열 끝)가 새로 더한 보호 경로다.
static func _connect_fingerprint(attempts: Array) -> String:
	var parts: Array[String] = ["connect-v1", "attempts:%d" % attempts.size()]
	for i: int in range(attempts.size()):
		var record: Dictionary = attempts[i]
		var checked: bool = bool(record.get("connect_checked", false))
		var rejected: Array = record.get("rejected", [])
		var outcome: String = "rejected" if not rejected.is_empty() else ("accepted" if checked else "unchecked")
		parts.append("attempt:%d:%d:%d:%s:%d:%d" % [i, int(record.get("candidate", -1)), int(checked), outcome, int(record.get("detached_people", -1)), int(record.get("detached_dead_pairs", -1))])
		parts.append("reasons:%d" % rejected.size())
		for reason: String in rejected: parts.append(reason.to_utf8_buffer().hex_encode())
		var trace: Dictionary = record.get("connect_routes", {})
		var cells: Array = trace.get("cells", [])
		var first: int = int(trace.get("from", 0))
		var last: int = cells.size()
		if i + 1 < attempts.size():
			var next: Dictionary = attempts[i + 1]
			last = int(next.get("connect_routes", {}).get("from", last))
		parts.append("routes:%d:%d" % [int(record.has("connect_routes")), last - first])
		for route_idx: int in range(first, last):
			var cell: Vector2i = cells[route_idx]
			parts.append("%d,%d" % [cell.x, cell.y])
	return "\n".join(parts).sha256_text().left(16)


static func _summary(cases: Dictionary, forms: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for form: String in forms:
		var row: Dictionary = {"count": 0, "failures": 0, "ratio_failures": 0, "blocked_failures": 0,
			"min_ratio": null, "max_ratio": null, "min_seed": null, "max_seed": null,
			"min_old_ratio": null, "max_old_ratio": null, "min_blocked_share": null, "max_blocked_share": null,
			"min_budget_delta_ms": null, "max_budget_delta_ms": null, "budget_failures": 0, "fingerprints": {},
			"tree_fingerprints": {}, "tree_fingerprints_zero": {}, "connect_fingerprints": {}}
		for key: String in cases:
			var record: Dictionary = cases[key]
			if record["form"] != form: continue
			row["count"] += 1
			# 탈락 판도 지문을 남긴다. 기존 윤곽/비율 집계의 성공 판 조건은 유지한다.
			for field: String in ["tree_fingerprint", "tree_fingerprint_zero", "connect_fingerprint"]:
				var new_fingerprint: String = String(record.get(field, ""))
				if new_fingerprint.is_empty(): continue
				var group_key: String = "tree_fingerprints_zero" if field == "tree_fingerprint_zero" else field + "s"
				var groups: Dictionary = row.get(group_key, {})
				groups.get_or_add(new_fingerprint, []).append(record.get("seed", -1))
			if not bool(record["stamped"]):
				row["failures"] += 1
				continue
			row["ratio_failures"] += int(not bool(record["ratio_pass"]))
			row["blocked_failures"] += int(not bool(record["blocked_pass"]))
			row["budget_failures"] += int(not bool(record["budget_pass"]))
			for metric: String in ["ratio", "old_ratio", "blocked_share", "budget_delta_ms"]:
				var value: float = float(record["new_ratio" if metric == "ratio" else metric])
				for direction: String in ["min", "max"]:
					var field: String = direction + "_" + metric
					if row[field] == null or (value < float(row[field]) if direction == "min" else value > float(row[field])):
						row[field] = value
						if metric == "ratio": row[direction + "_seed"] = record["seed"]
			var fingerprint: String = record["outline_fingerprint"]
			row["fingerprints"].get_or_add(fingerprint, []).append(record["seed"])
		row["same_outline_across_seeds"] = row["failures"] == 0 and row["fingerprints"].size() == 1
		out[form] = row
	return out


static func _source_hash() -> String:
	var pending: Array[String] = ["res://game"]
	var files: Array[String] = ["res://project.godot", "res://tools/bounds_ratio_sweep.gd", "res://tools/bounds_baseline_dump.gd"]
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		var access: DirAccess = DirAccess.open(directory)
		if access == null: return ""
		for child: String in access.get_directories(): pending.append(directory.path_join(child))
		for file: String in access.get_files():
			if file.ends_with(".gd"): files.append(directory.path_join(file))
	files.sort()
	var parts: Array[String] = []
	for path: String in files:
		var digest: String = FileAccess.get_sha256(path)
		if digest.is_empty(): return ""
		parts.append(path + ":" + digest)
	return "\n".join(parts).sha256_text()


static func _head() -> String:
	var output: Array = []
	if OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"]), output, true) != 0 or output.is_empty(): return ""
	return String(output[0]).strip_edges()


func _fail(message: String) -> void:
	push_error("BOUNDS_RATIO_SWEEP_FAILED " + message)
	quit(1)
