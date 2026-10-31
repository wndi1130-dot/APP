extends SceneTree
## Supplies per map and seed, then each map's medians (decision 490).
## -- --maps a,b,c --seeds 1:20 --out <path.csv>

const MAP_DIR: String = "res://game/world/maps/"
const ITEM_IDS: Array[String] = ["toilet_paper", "soap", "candle", "sewing_kit", "old_clothes", "child_clothes", "book", "toy", "razor"]
const TOTALS: Array[String] = ["items_total", "melt_raw", "melt_rounded", "boxes_with_supplies", "empty_before", "empty_after"]


func _initialize() -> void:
	# A script error aborting the run must still let the tree exit with failure.
	quit(1)
	_run()


func _run() -> void:
	var options := _options(OS.get_cmdline_user_args())
	if options.is_empty():
		return
	# Load after arming failure exit, so a broken dependency cannot leave a tree running.
	var field_maps: Script = load("res://game/world/field_maps.gd")
	var loot_dress: Script = load("res://game/sim/loot_dress.gd")
	var field_items: Script = load("res://game/sim/field_items.gd")
	for script: Script in [field_maps, loot_dress, field_items]:
		if script == null or not script.can_instantiate():
			_fail("지도·전리품 스크립트를 읽지 못했습니다.")
			return
	var maps: Array[String] = options["maps"]
	if maps.is_empty():
		var dir := DirAccess.open(MAP_DIR)
		if dir == null:
			_fail("지도 폴더를 열지 못했습니다: " + MAP_DIR)
			return
		for file: String in dir.get_files():
			if file.ends_with(".gd"):
				maps.append(file.get_basename())
		maps.sort()
	if maps.is_empty():
		_fail("측정할 지도가 없습니다.")
		return
	for place: String in maps:
		if not field_maps.has(place):
			_fail("없는 지도입니다: " + place)
			return
		var map_script: Script = load(field_maps.path_of(place))
		if map_script == null or not map_script.can_instantiate():
			_fail("지도 스크립트를 읽지 못했습니다: " + place)
			return
	var metrics: Array[String] = []
	metrics.append_array(ITEM_IDS)
	metrics.append_array(TOTALS)
	var header: PackedStringArray = ["row", "map", "seed", "samples"]
	for key: String in metrics:
		header.append(key)
	# Rows are written as they come, so a run cut short by its time limit still leaves its seeds.
	var out_path := String(options["out"])
	var output := FileAccess.open(out_path, FileAccess.WRITE)
	if output == null:
		_fail("CSV를 열지 못했습니다: %s (%d)" % [out_path, FileAccess.get_open_error()])
		return
	output.store_csv_line(header)
	var samples_by_map := {}
	for place: String in maps:
		var samples: Array = []
		for seed in range(int(options["first"]), int(options["last"]) + 1):
			var before: Dictionary = field_maps.build(place)
			var after: Dictionary = field_maps.build(place)
			if not (before.get("containers") is Dictionary) or not (after.get("containers") is Dictionary):
				_fail("지도 상자를 만들지 못했습니다: %s:%d" % [place, seed])
				return
			var base_report: Dictionary = loot_dress.dress(before, seed, {}, false)
			var report: Dictionary = loot_dress.dress(after, seed)
			if not base_report.has("supplies") or not report.has("supplies"):
				_fail("생필품 배치가 끝나지 않았습니다: %s:%d" % [place, seed])
				return
			var sample := _measure(before["containers"], after["containers"], field_items)
			if sample.is_empty():
				_fail("생필품을 세지 못했습니다: %s:%d" % [place, seed])
				return
			samples.append(sample)
			output.store_csv_line(_row("seed", place, str(seed), 1, sample, metrics))
			output.flush()
		samples_by_map[place] = samples
	# Summary rows follow all seed rows; even samples may have fractional medians.
	for place: String in maps:
		var samples: Array = samples_by_map[place]
		var medians := {}
		for key: String in metrics:
			medians[key] = _median(samples, key)
		output.store_csv_line(_row("median", place, "", samples.size(), medians, metrics))
	output.flush()
	var error := output.get_error()
	output.close()
	if error != OK:
		_fail("CSV를 쓰지 못했습니다: %s (%d)" % [out_path, error])
		return
	print("생필품 측정 완료: ", out_path)
	quit(0)


func _options(args: PackedStringArray) -> Dictionary:
	var maps: Array[String] = []
	var options := {"maps": maps, "first": 1, "last": 20, "out": ""}
	var seen := {}
	var i := 0
	while i < args.size():
		var key := String(args[i])
		if not (key in ["--maps", "--seeds", "--out"]) or seen.has(key) or i + 1 >= args.size():
			_fail("사용법: -- --maps a,b,c --seeds 1:20 --out <경로.csv>")
			return {}
		seen[key] = true
		var value := String(args[i + 1])
		match key:
			"--maps":
				for part: String in value.split(",", true):
					var place := part.strip_edges()
					if place.is_empty():
						_fail("지도 이름이 비어 있습니다.")
						return {}
					if not maps.has(place):
						maps.append(place)
			"--seeds":
				var bounds := value.split(":", true)
				if bounds.size() != 2 or not bounds[0].is_valid_int() or not bounds[1].is_valid_int():
					_fail("씨앗 범위는 정수 두 개로 적어야 합니다: 1:20")
					return {}
				options["first"] = int(bounds[0])
				options["last"] = int(bounds[1])
				if int(options["first"]) > int(options["last"]) or int(options["last"]) == 9223372036854775807:
					_fail("씨앗 범위의 끝을 확인해 주세요.")
					return {}
			"--out":
				options["out"] = value
		i += 2
	if String(options["out"]).strip_edges().is_empty():
		_fail("CSV를 쓸 --out 경로가 필요합니다.")
		return {}
	return options


func _measure(before: Dictionary, after: Dictionary, field_items: Script) -> Dictionary:
	var sample := {"items_total": 0, "melt_raw": 0.0, "melt_rounded": 0, "boxes_with_supplies": 0, "empty_before": 0, "empty_after": 0}
	for id: String in ITEM_IDS:
		sample[id] = 0
	# All containers count, including protected and outdoor ones.
	for c: Dictionary in before.values():
		if (c.get("items", []) as Array).is_empty():
			sample["empty_before"] += 1
	for c: Dictionary in after.values():
		var items: Array = c.get("items", [])
		if items.is_empty():
			sample["empty_after"] += 1
		var has_supplies := false
		for item: String in items:
			if not ITEM_IDS.has(item):
				continue
			var melt: Array = field_items.stock_of(item)
			if melt.size() != 2 or String(melt[0]) != "supplies":
				return {}
			sample[item] += 1
			sample["items_total"] += 1
			sample["melt_raw"] += float(melt[1])
			has_supplies = true
		if has_supplies:
			sample["boxes_with_supplies"] += 1
	# field_game.finish rounds once, after all unloaded things are added up.
	sample["melt_rounded"] = roundi(float(sample["melt_raw"]))
	return sample


func _row(kind: String, place: String, seed: String, samples: int, values: Dictionary, metrics: Array[String]) -> PackedStringArray:
	var fields: PackedStringArray = [kind, place, seed, str(samples)]
	for key: String in metrics:
		fields.append("%.4f" % float(values[key]) if key == "melt_raw" else str(values[key]))
	return fields


func _median(samples: Array, key: String) -> float:
	var values: Array[float] = []
	for sample: Dictionary in samples:
		values.append(float(sample[key]))
	values.sort()
	var middle := floori(values.size() / 2.0)
	if values.size() % 2 == 1:
		return values[middle]
	return (values[middle - 1] + values[middle]) / 2.0


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
