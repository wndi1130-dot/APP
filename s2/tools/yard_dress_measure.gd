extends SceneTree
## 호출 예: --headless --path s2 --script res://tools/yard_dress_measure.gd -- houses_01 houses_07
## 실행은 문지기를 쓰는 호출자 몫. 이 파일은 결과를 stdout의 JSON 줄로만 내보낸다.
const FieldMaps = preload("res://game/world/field_maps.gd")
const MapRing = preload("res://game/world/map_ring.gd")
const YardDress = preload("res://game/world/yard_dress.gd")


func _initialize() -> void:
	call_deferred("_measure")


func _median(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	values.sort()
	var middle: int = values.size() / 2
	return float(values[middle]) if values.size() % 2 == 1 else float(values[middle - 1] + values[middle]) / 2.0


func _measure() -> void:
	var ids: PackedStringArray = OS.get_cmdline_user_args()
	if ids.is_empty():
		ids = PackedStringArray(["houses_01", "houses_02", "houses_03", "houses_04", "houses_05", "houses_06", "houses_07"])
	for requested_id: String in ids:
		if not FieldMaps.has(requested_id):
			printerr("F-INPUT-MISSING: 없는 지도 " + requested_id)
			quit(2)
			return
	var total: Dictionary = {"type": "summary", "scope": "before_map_ring", "maps": 0,
		"homes": 0, "yard_cells": 0, "old": 0, "new": 0, "rows": 0,
		"blocking": 0, "new_blocking": 0, "dress_ms": 0.0, "build_ms": 0.0, "kinds": {}, "target_misses": []}
	var all_variety: Array[int] = []
	for place_id: String in ids:
		var started: int = Time.get_ticks_usec()
		var script: Script = load(FieldMaps.path_of(place_id))
		# 기존 우회 함수를 통해 실제 build_from을 끝낸다. 고리가 방 번호표를 지우기 전의
		# 발주 대상만 잰다. 고리 집을 포함시켜 원래 마당의 수치를 희석하지 않는다.
		var data: Dictionary = MapRing.plain_build(script, FieldMaps.build_from)
		var build_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		var row: Dictionary = YardDress.census(data)
		var stats: Dictionary = data.get("yard_stats", {})
		row["type"] = "map"
		row["place_id"] = place_id
		row["scope"] = "before_map_ring"
		# 뒤의 창문·등불 단계가 있어도 분모는 마당 단계 직전의 빈 칸 수로 고정한다.
		row["yard_cells"] = int(stats.get("yard_cells", row["yard_cells"]))
		row["rows"] = int(row["old"]) + int(row["new"])
		row["per_100"] = 100.0 * float(row["rows"]) / float(row["yard_cells"]) if row["yard_cells"] > 0 else 0.0
		row["new_blocking"] = int(stats.get("blocking", 0))
		row["dress_ms"] = float(data.get("yard_dress_ms", 0.0))
		row["build_ms"] = build_ms
		row["target_met"] = row["homes"] > 0 and row["per_100"] >= 5.0 and row["per_100"] <= 8.0 \
			and row["median_kinds"] >= 4.0 and row["map_kinds"] >= 8
		for variety: int in row["home_variety"]:
			all_variety.append(variety)
		row.erase("home_variety")
		total["maps"] += 1
		for count_key: String in ["homes", "yard_cells", "old", "new", "rows", "blocking", "new_blocking", "dress_ms", "build_ms"]:
			total[count_key] += row[count_key]
		for kind: String in row["kinds"]:
			total["kinds"][kind] = int(total["kinds"].get(kind, 0)) + int(row["kinds"][kind])
		if not row["target_met"]:
			total["target_misses"].append(place_id)
		print(JSON.stringify(row))
	total["per_100"] = 100.0 * float(total["rows"]) / float(total["yard_cells"]) if total["yard_cells"] > 0 else 0.0
	total["median_kinds"] = _median(all_variety)
	total["map_kinds"] = total["kinds"].size()
	total["target_met"] = total["target_misses"].is_empty()
	print(JSON.stringify(total))
	quit(0 if total["target_met"] else 1)
