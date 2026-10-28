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
const Uses = preload("res://game/world/building_uses.gd")
const OUT := "res://build/building_census/"
## 겉 꼴을 이루는 칸. 지붕 꼴·벽 재질·문창은 하나씩, 덧붙이는 묶음.
const PARTS := ["roof", "wall", "openings", "extras"]
## 지붕 조각 가운데 꼴이 아닌 것(박공 끝 벽·난간은 그 지붕의 일부).
const ROOF_TRIM := ["roof_gable_end", "roof_parapet"]
## 덧붙이 조각(지붕 목록이든 벽 조각 목록이든). 그리기 계획이 놓은 것만 센다.
const EXTRA_PIECES := ["chimney", "porch_hood", "awning", "sign_board", "bell_turret", "loading_dock", "roof_vent",
	"snow_guard", "eave_deep"]


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
	for r: Dictionary in plan["roofs"] + plan["pieces"]:
		if not r.has("id") or not r.has("b"):
			continue
		var b := int(r["b"])
		var piece := String(r["id"])
		if piece.begins_with("roof_") and piece not in ROOF_TRIM:
			var shape := piece.trim_prefix("roof_")
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
	for row: Dictionary in data.get("buildings", []):
		var b := int(row.get("id", -1))
		if not plan["outer"].has(b):
			continue  # 안이 없는 껍데기(겉 조각을 그리지 않는다)
		var rect: Variant = row.get("rect")
		out.append({
			"map": id, "group": Uses.group_of(id), "region": Uses.region_of(id), "b": b,
			"name": String(row.get("name", "")), "role": String(row.get("role", "")),
			"levels": _levels_of(levels, b, rect), "basement": levels.has(-1) and _levels_of({-1: levels[-1]}, b, rect) > 0,
			"cells": (rect as Rect2i).get_area() if rect is Rect2i else 0,
			"roof": _joined(roofs.get(b, {})), "wall": String(looks.get(b, {}).get("wall", "paint")),
			"openings": _joined(openings.get(b, {})), "extras": _joined(extras.get(b, {})),
		})
	return out


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
	for file: String in DirAccess.get_files_at(OUT):
		if file.begins_with("rows_%s_" % phase) and file.ends_with(".json"):
			rows.append_array(JSON.parse_string(FileAccess.get_file_as_string(OUT + file)))
	var table: Dictionary = {}
	for row: Dictionary in rows:
		var use := Uses.use_of(row)
		var key := "%s|%s|%s" % [row["region"], row["group"], use]
		if not table.has(key):
			table[key] = {"region": row["region"], "group": row["group"], "use": use, "buildings": 0, "names": {}, "looks": {}}
			for part: String in PARTS:
				table[key][part] = {}
		var t: Dictionary = table[key]
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
		"| 지역 | 갈래 | 용도 | 건물 | 지붕 | 벽 | 문창 | 덧붙이 | 꼴 가짓수 | 이름(많은 차례) |", "|---|---|---|---:|---|---|---|---|---:|---|"]
	var looks_all: Dictionary = {}
	for key: String in keys:
		var t: Dictionary = table[key]
		for l: String in t["looks"]:
			looks_all[l] = true
		var cells: Array = []
		for part: String in PARTS:
			cells.append(_counts(t[part]))
		lines.append("| %s | %s | %s | %d | %s | %d | %s |" % [t["region"], t["group"], t["use"], t["buildings"],
			" | ".join(cells), t["looks"].size(), _counts(t["names"], 6)])
	lines.insert(1, "꼴(지붕·벽·문창·덧붙이 묶음) 가짓수 전체 %d." % looks_all.size())
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
