extends SceneTree
## 건물 꼴 현황 셈(결정 478 ①): 지도 갈래 × 용도마다 겉 꼴(지붕 꼴·벽 재질·문창·덧붙이)이 몇 가지인지.
## 두 단계다. 짓기(무거움): 지도를 짓고 BuildingView.plan의 겉 조각을 건물마다 한 줄로 남긴다.
##   godot --headless --path s2 -s res://tools/building_census.gd -- --phase=before --only=church
##   지도 80장을 한 판에 지으면 메모리가 2 GB를 넘어 갈래 몇 개씩(--only=church,office) 따로 띄운다.
## 세기(가벼움): 남긴 줄에 용도 표(building_uses.gd)를 대어 갈래·용도별 조합을 센다.
##   godot --headless --path s2 -s res://tools/building_census.gd -- --phase=before --sum
## 결과는 build/building_census/ 아래 rows_<phase>_<갈래>.json, sum_<phase>.json·.md.
const Maps = preload("res://game/world/field_maps.gd")
const BuildingView = preload("res://game/world/building_view.gd")
const BuildingForms = preload("res://game/world/building_forms.gd")
const Uses = preload("res://game/world/building_uses.gd")
const OUT := "res://build/building_census/"
## 겉 꼴을 이루는 칸. 지붕 꼴·벽 재질·문창은 하나씩, 덧붙이는 묶음.
const PARTS := ["roof", "wall", "openings", "extras"]
## 지붕 조각 가운데 꼴이 아닌 것(박공 끝 벽·난간은 그 지붕의 일부).
const ROOF_TRIM := ["roof_gable_end", "roof_parapet", "roof_half_hip_wall", "roof_mansard_end", "roof_shed_side", "roof_dormer"]
## 덧붙이 조각(지붕 목록이든 벽 조각 목록이든). 그리기 계획이 놓은 것만 센다.
const EXTRA_PIECES := ["chimney", "porch_hood", "awning", "sign_board", "bell_turret", "loading_dock", "roof_vent",
	"snow_guard", "eave_deep", "roof_dormer"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var phase := "before"
	var only := ""
	var sum := false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--phase="):
			phase = a.substr(8)
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a == "--sum":
			sum = true
	DirAccess.make_dir_recursive_absolute(OUT)
	if sum:
		_sum(phase)
		quit(0)
		return
	var rows: Array = []
	for id: String in Maps.ids():
		if only != "" and Uses.group_of(id) not in only.split(","):
			continue
		var data := Maps.build(id)
		rows.append_array(rows_of(id, data, BuildingView.plan(data)))
		print("CENSUS ", id, " rows=", rows.size())
		await process_frame
	var f := FileAccess.open(OUT + "rows_%s_%s.json" % [phase, only.replace(",", "+") if only != "" else "all"], FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "\t"))
	print("DONE rows=", rows.size())
	quit(0)


## 건물마다 한 줄: 지도·갈래·이름·role·층과 겉 꼴(지붕 꼴, 벽 재질, 문창, 덧붙이).
static func rows_of(id: String, data: Dictionary, plan: Dictionary) -> Array:
	var roofs: Dictionary = {}
	var extras: Dictionary = {}
	var dormers: Dictionary = {}
	for r: Dictionary in plan["roofs"] + plan["pieces"]:
		if not r.has("id") or not r.has("b"):
			continue
		var b := int(r["b"])
		var piece := String(r["id"])
		if piece == "roof_dormer":
			dormers[b] = int(dormers.get(b, 0)) + 1
		if piece.begins_with("roof_") and piece not in ROOF_TRIM:
			var shape: String = String(r.get("silhouette", piece.trim_prefix("roof_")))
			var pitch := float(r.get("pitch", 1.0))
			shape += "_steep" if pitch > 1.2 else ("_low" if pitch < 0.9 else "")
			_put(roofs, b, shape)
		elif piece in EXTRA_PIECES:
			_put(extras, b, piece)
	var openings: Dictionary = {}
	for key: String in ["doors", "windows"]:
		for o: Dictionary in plan[key]:
			if bool(o.get("outer", key == "windows")):
				_put(openings, int(o["b"]), String(o.get("kind", key.trim_suffix("s"))))
	# 벽 재질은 그리기 계획이 고른 값(결정 478 1단계부터), 없으면 건물마다 굴린 칠.
	var looks: Dictionary = plan.get("looks", {})
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var out: Array = []
	var seen: Dictionary = {}
	for row: Dictionary in data.get("buildings", []):
		var b := int(row.get("id", -1))
		if seen.has(b) or not plan["outer"].has(b):
			continue  # 안이 없는 껍데기(겉 조각을 그리지 않는다)
		seen[b] = true
		var representative: Dictionary = BuildingView._form_row(data, b)
		var rect: Variant = plan.get("footprints", {}).get(b, row.get("rect"))
		var look: Dictionary = looks.get(b, {})
		var center: Array = []
		if rect is Rect2i:
			var footprint: Rect2i = rect
			center = [footprint.position.x + footprint.size.x * 0.5, footprint.position.y + footprint.size.y * 0.5]
		var silhouette: String = String(look.get("silhouette", "?"))
		var pitch_band: String = BuildingForms.pitch_band(float(look.get("pitch", 1.0)))
		var wall: String = String(look.get("wall", "paint"))
		out.append({
			"map": id, "group": Uses.group_of(id), "region": Uses.region_of(id), "b": b,
			"name": String(representative.get("name", "")), "role": String(representative.get("role", "")),
			"use": String(look.get("use", "?")),
			"levels": _levels_of(levels, b, rect), "basement": levels.has(-1) and _levels_of({-1: levels[-1]}, b, rect) > 0,
			"cells": (rect as Rect2i).get_area() if rect is Rect2i else 0,
			"roof": _joined(roofs.get(b, {})), "wall": wall,
			"openings": _joined(openings.get(b, {})), "extras": _joined(extras.get(b, {})),
			"silhouette": silhouette, "pitch_band": pitch_band, "dormers": int(dormers.get(b, 0)),
			"palette": look.get("palette", "?"), "paint_index": int(look.get("paint_index", -1)),
			"center": center, "row_group": plan.get("row_groups", {}).get(b, row.get("row_group")),
			"signature": BuildingForms.signature(look) if look.has("silhouette") else "?",
			"form_combo": "%s|%s|%s|%d" % [silhouette, pitch_band, wall, 1 if int(dormers.get(b, 0)) > 0 else 0],
		})
	return out


## 저장된 줄만으로 셈한다. 2가 이전 rows는 값을 추측하지 않고 not_collected로 둔다.
static func roof_metrics(rows: Array, all_rows: Array = []) -> Dictionary:
	var silhouettes: Dictionary = {}
	var maps: Dictionary = {}
	var vicinity: Dictionary = {}
	var scope: Array = rows if all_rows.is_empty() else all_rows
	for row: Dictionary in scope:
		if not row.has("form_combo") or String(row.get("signature", "?")) == "?" or (row.get("center", []) as Array).size() != 2:
			return {"status": "not_collected"}
		var map_id: String = String(row["map"])
		if not vicinity.has(map_id):
			vicinity[map_id] = []
		vicinity[map_id].append(row)
	for row: Dictionary in rows:
		if not row.has("form_combo") or String(row.get("signature", "?")) == "?" or (row.get("center", []) as Array).size() != 2:
			return {"status": "not_collected"}
		var shape: String = String(row["silhouette"])
		silhouettes[shape] = int(silhouettes.get(shape, 0)) + 1
		var map_id: String = String(row["map"])
		if not maps.has(map_id):
			maps[map_id] = []
		maps[map_id].append(row)
	var counts: Array[int] = []
	var per_map: Dictionary = {}
	var near_max: int = 0
	var crowded: int = 0
	for map_id: String in maps:
		var combinations: Dictionary = {}
		var buildings: Array = maps[map_id]
		for row: Dictionary in buildings:
			combinations[row["form_combo"]] = true
			var center: Vector2 = Vector2(float(row["center"][0]), float(row["center"][1]))
			var same: int = 0
			for other: Dictionary in vicinity[map_id]:
				if int(row["b"]) == int(other["b"]) or row["signature"] != other["signature"] or BuildingForms.same_row_group(row.get("row_group"), other.get("row_group")):
					continue
				var there: Vector2 = Vector2(float(other["center"][0]), float(other["center"][1]))
				if center.distance_to(there) <= BuildingView.LOOK_RADIUS:
					same += 1
			near_max = maxi(near_max, same)
			crowded += 1 if same >= 3 else 0
		counts.append(combinations.size())
		per_map[map_id] = combinations.size()
	counts.sort()
	var median: float = 0.0
	if not counts.is_empty():
		var middle: int = floori(float(counts.size()) * 0.5)
		median = float(counts[middle]) if counts.size() % 2 == 1 else float(counts[middle - 1] + counts[middle]) * 0.5
	var most: int = 0
	for count: int in silhouettes.values():
		most = maxi(most, count)
	return {"status": "collected", "silhouette_count": silhouettes.size(), "silhouettes": silhouettes,
		"dominant_silhouette_share": float(most) / float(rows.size()) if not rows.is_empty() else 0.0,
		"map_form_median": median, "map_form_min": counts[0] if not counts.is_empty() else 0,
		"map_form_counts": per_map, "near_same_max": near_max, "near_same_ge3_buildings": crowded}


static func _metric_cells(metrics: Dictionary) -> String:
	if metrics["status"] != "collected":
		return "not_collected | — | — | — | — | —"
	return "%d | %.1f%% | %.1f | %d | %d | %d" % [metrics["silhouette_count"], float(metrics["dominant_silhouette_share"]) * 100.0,
		metrics["map_form_median"], metrics["map_form_min"], metrics["near_same_max"], metrics["near_same_ge3_buildings"]]


## 그 건물 칸이 있는 층 수(땅 위만, 지하는 따로).
static func _levels_of(levels: Dictionary, b: int, rect: Variant) -> int:
	if not rect is Rect2i:
		return 0
	var n := 0
	for lv: int in levels:
		if lv < 0 and levels.size() > 1:
			continue
		var g = levels[lv]
		var r: Rect2i = rect
		var found := false
		for y in range(r.position.y, r.end.y, 2):
			for x in range(r.position.x, r.end.x, 2):
				if g.inside(Vector2i(x, y)) and g.building_at(Vector2i(x, y)) == b:
					found = true
					break
			if found:
				break
		n += 1 if found else 0
	return n


static func _put(into: Dictionary, b: int, what: String) -> void:
	if not into.has(b):
		into[b] = {}
	into[b][what] = true


static func _joined(found: Dictionary) -> String:
	var keys: Array = found.keys()
	keys.sort()
	return "+".join(keys) if not keys.is_empty() else "-"


## 남긴 줄을 모아 갈래 × 용도마다 건물 수, 칸마다 가짓수, 꼴(네 칸 묶음) 가짓수.
func _sum(phase: String) -> void:
	var rows: Array = []
	var files: PackedStringArray = DirAccess.get_files_at(OUT)
	files.sort()
	for file: String in files:
		if file.begins_with("rows_%s_" % phase) and file.ends_with(".json"):
			rows.append_array(JSON.parse_string(FileAccess.get_file_as_string(OUT + file)))
	# 같은 phase의 --only 묶음이 겹쳐도 한 지도·건물을 두 번 세지 않는다.
	var unique: Dictionary = {}
	for row: Dictionary in rows:
		unique["%s|%d" % [row["map"], int(row["b"])]] = row
	rows = unique.values()
	var table: Dictionary = {}
	for row: Dictionary in rows:
		var use: String = String(row.get("use", Uses.use_of(row)))
		var key := "%s|%s|%s" % [row["region"], row["group"], use]
		if not table.has(key):
			table[key] = {"region": row["region"], "group": row["group"], "use": use, "buildings": 0, "names": {}, "looks": {}, "rows": []}
			for part: String in PARTS:
				table[key][part] = {}
		var t: Dictionary = table[key]
		t["rows"].append(row)
		t["buildings"] += 1
		t["names"][row["name"]] = int(t["names"].get(row["name"], 0)) + 1
		var look: Array = []
		for part: String in PARTS:
			t[part][row[part]] = int(t[part].get(row[part], 0)) + 1
			look.append(row[part])
		t["looks"]["|".join(look)] = true
	var keys: Array = table.keys()
	keys.sort()
	var lines: Array = ["# 건물 꼴 현황 셈 (%s, 건물 %d)" % [phase, rows.size()], "",
		"| 지역 | 갈래 | 용도 | 건물 | 지붕 | 벽 | 문창 | 덧붙이 | 꼴 가짓수 | 실루엣 수 | 최다 실루엣 몫 | 지도 꼴 조합 가운데값 | 지도 꼴 조합 최소 | 24 m 같은 서명 최대 | 24 m 셋 이상 건물 | 이름(많은 차례) |",
		"|---|---|---|---:|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|"]
	var looks_all: Dictionary = {}
	for key: String in keys:
		var t: Dictionary = table[key]
		t["roof_2a"] = roof_metrics(t["rows"], rows)
		t.erase("rows")
		for l: String in t["looks"]:
			looks_all[l] = true
		var cells: Array = []
		for part: String in PARTS:
			cells.append(_counts(t[part]))
		lines.append("| %s | %s | %s | %d | %s | %d | %s | %s |" % [t["region"], t["group"], t["use"], t["buildings"],
			" | ".join(cells), t["looks"].size(), _metric_cells(t["roof_2a"]), _counts(t["names"], 6)])
	lines.insert(1, "꼴(지붕·벽·문창·덧붙이 묶음) 가짓수 전체 %d." % looks_all.size())
	var overall: Dictionary = roof_metrics(rows)
	lines.append_array(["", "| 범위 | 실루엣 수 | 최다 실루엣 몫 | 지도 꼴 조합 가운데값 | 지도 꼴 조합 최소 | 24 m 같은 서명 최대 | 24 m 셋 이상 건물 |",
		"|---|---:|---:|---:|---:|---:|---:|", "| 전체 | %s |" % _metric_cells(overall), "",
		"꼴 조합 = 실루엣 × 물매 급 × 벽 재질 × 지붕창 유무. 이웃 서명은 지붕창 대신 칠 색 번호를 쓴다.",
		"24 m는 바닥 경계 상자 가운데 사이 거리, 자신·같은 row_group 제외. 용도별 줄도 지도 전체의 이웃을 센다.",
		"지도 꼴 조합 수는 각 줄의 용도 범위 안에서 센다. 전체 줄은 지도 전체. 옛 rows는 not_collected."])
	if overall["status"] == "collected":
		lines.append_array(["", "| 지도 | 꼴 조합 수 |", "|---|---:|"])
		var map_ids: Array = overall["map_form_counts"].keys()
		map_ids.sort()
		for map_id: String in map_ids:
			lines.append("| %s | %d |" % [map_id, int(overall["map_form_counts"][map_id])])
	FileAccess.open(OUT + "sum_%s.md" % phase, FileAccess.WRITE).store_string("\n".join(lines) + "\n")
	FileAccess.open(OUT + "sum_%s.json" % phase, FileAccess.WRITE).store_string(JSON.stringify(table, "\t"))
	print("SUM rows=", rows.size(), " groups=", keys.size(), " looks=", looks_all.size())


static func _counts(c: Dictionary, most: int = 0) -> String:
	var keys: Array = c.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(c[a]) > int(c[b]))
	if most > 0 and keys.size() > most:
		keys = keys.slice(0, most)
	var parts: Array = []
	for k: Variant in keys:
		parts.append("%s %d" % [k, c[k]])
	return ", ".join(parts)
