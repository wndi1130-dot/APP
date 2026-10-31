extends SceneTree
## Static room census. --phase before|after; JSON and Markdown under build/room_density.
## Coverage is the union of furniture cells that block bodies on this level.
const Maps = preload("res://game/world/field_maps.gd")
const Furnish = preload("res://game/world/room_furnish.gd")
const Grid = preload("res://game/world/field_grid.gd")
const Kinds = preload("res://game/world/prop_kinds.gd")
const Models = preload("res://game/world/prop_models.gd")
const OUT := "res://build/room_density/"
const METRICS := ["area", "furniture_cells", "cover", "layout_cover", "count", "wall", "corner", "door_empty", "window_large"]
var phase := "before"
var rows: Array = []
var maps: Array = []
var chosen: Dictionary = {}
var lod_counts: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--phase" and args[1] in ["before", "after"]:
		phase = args[1]
	elif not args.is_empty():
		push_error("Expected --phase before|after")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	for id in Maps.ids():
		var data := Maps.build(id)
		measure_map(id, data)
		print("MEASURE ", id, " rooms=", rows.size())
		_save()
		await process_frame
	print("DONE maps=", maps.size(), " rooms=", rows.size())
	quit(0)

static func quantile(values: Array, fraction: float) -> Variant:
	if values.is_empty():
		return null
	var sorted := values.duplicate()
	sorted.sort()
	var at := (sorted.size() - 1) * fraction
	return lerpf(float(sorted[int(floor(at))]), float(sorted[int(ceil(at))]), at - floor(at))

static func summary(source: Array) -> Dictionary:
	var grouped: Dictionary = {}
	for row: Dictionary in source:
		var cls: String = row["class"]
		if not grouped.has(cls):
			grouped[cls] = []
		grouped[cls].append(row)
	var out: Dictionary = {}
	for cls: String in grouped:
		var group: Array = grouped[cls]
		var stats := {"rooms": group.size()}
		for metric: String in METRICS:
			var values: Array = []
			for row: Dictionary in group:
				if row.get(metric) != null:
					values.append(row[metric])
			stats[metric] = {"median": quantile(values, 0.5), "p10": quantile(values, 0.1), "p25": quantile(values, 0.25), "p75": quantile(values, 0.75), "p90": quantile(values, 0.9), "n": values.size()}
		out[cls] = stats
	return out

static func _ratio(n: int, d: int) -> Variant:
	return float(n) / d if d > 0 else null

static func item_quantity(items: Array) -> int:
	var count := 0
	for item: Variant in items:
		count += int(item.get("n", 1)) if item is Dictionary else 1
	return count

func measure_map(id: String, data: Dictionary) -> void:
	var all_props: Array = data.get("props", [])
	# Wall-hung decor (room_decor.gd, "decor": true) stands on no floor cell and blocks nothing: the
	# room census reads the furniture only, as before decor came; the draw counts below take all rows.
	var props: Array = []
	var decor_rows := 0
	for row: Variant in all_props:
		if row is Dictionary and bool((row as Dictionary).get("decor", false)):
			decor_rows += 1
		else:
			props.append(row)
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var classified := Furnish._classified_buildings(data, levels, props)
	var floor_hashes: Dictionary = {}
	for lv: int in levels:
		var g: Grid = levels[lv]
		floor_hashes[str(lv)] = var_to_str(g.floor).sha256_text()
		var partition := Furnish.rooms_of(g)
		var of: PackedInt32Array = partition["of"]
		var in_room := Furnish._props_by_room(g, of, props, lv)
		var labels := Furnish._room_labels(data, lv, g, of)
		var inherited := Furnish._building_classes(data, lv, partition, in_room, props, labels, classified)
		for ri in range(partition["rooms"].size()):
			var room: Dictionary = partition["rooms"][ri]
			var cells: Array[Vector2i] = room["cells"]
			var idxs: Array = in_room.get(ri, [])
			var kinds: Dictionary = {}
			var cls := ""
			for i: int in idxs:
				kinds[props[i]["kind"]] = true
				if props[i].has("rule"):
					cls = props[i]["rule"]
			if cls.is_empty():
				var name := Furnish._note_name(props, idxs)
				cls = Furnish.room_class(labels.get(ri, "") if name.is_empty() else name, kinds, lv)
			if cls.is_empty():
				cls = inherited.get(ri, "other")
			# 바깥 띠(map_ring)는 지도를 넓혀 방 번호를 다시 매기므로, 가구 놓기 때 번호로 적은 표는 그 뒤로는
			# 다른 방을 가리킨다. 그때는 놓인 가구의 묶음(rule)과 이름으로만 읽는다.
			if not data.has("map_ring"):
				cls = data.get("density_classes", {}).get("%d:%d" % [lv, ri], cls)
			if cls.is_empty():
				cls = "other"
			var footprint: Dictionary = {}
			var blocked: Dictionary = {}
			var large: Dictionary = {}
			var count := 0
			var walls := 0
			var corners := 0
			for i: int in idxs:
				var p: Dictionary = props[i]
				var kind := String(p.get("kind", ""))
				if kind.is_empty() or Furnish.PASS_KINDS.has(kind):
					continue
				var r: Rect2i = Furnish._rect(p["rect"])
				count += 1
				var sides := Furnish._wall_sides(g, of, ri, r)
				walls += int(sides > 0)
				corners += int(sides > 1)
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						var c := Vector2i(x, y)
						if Furnish._at(g, of, c) != ri:
							continue
						footprint[c] = true
						if Furnish.blocks(kind, lv) and g.solid_at(c) in [Grid.Solid.LOW, Grid.Solid.BLOCK]:
							blocked[c] = true
						if r.get_area() >= 2 or Furnish.TALL_KINDS.has(kind):
							large[c] = true
			var door_fronts: Dictionary = {}
			var window_fronts: Dictionary = {}
			for c in cells:
				for direction in Furnish.DIRS:
					if g.doors.has(c + direction):
						door_fronts[c] = true
					if g.windows.has(c + direction):
						window_fronts[c] = true
			var empty := 0
			var window_large := 0
			for c: Vector2i in door_fronts:
				empty += int(not footprint.has(c) and g.solid_at(c) == Grid.Solid.NONE)
			for c: Vector2i in window_fronts:
				window_large += int(large.has(c))
			rows.append({"map": id, "level": lv, "room": ri, "building": room["building"], "class": cls,
				"area": cells.size(), "furniture_cells": blocked.size(), "cover": _ratio(blocked.size(), cells.size()),
				"layout_cover": _ratio(footprint.size(), cells.size()), "count": count,
				"wall": _ratio(walls, count), "corner": _ratio(corners, count),
				"door_empty": _ratio(empty, door_fronts.size()), "window_large": _ratio(window_large, window_fronts.size()),
				"door_fronts": door_fronts.size(), "door_free": empty, "window_fronts": window_fronts.size(), "window_occupied": window_large,
				"kinds": kinds.keys()})
	var contents: Dictionary = {}
	var slots := 0
	var quantity := 0
	var ids: Array = data.get("containers", {}).keys()
	ids.sort()
	for box_id: String in ids:
		var items: Array = data["containers"][box_id].get("items", [])
		contents[box_id] = items
		slots += items.size()
		quantity += item_quantity(items)
	var batch_paths: Dictionary = {}
	var modelled: Dictionary = {}
	for p: Dictionary in all_props:
		var kind := String(p.get("kind", ""))
		if not chosen.has(kind):
			chosen[kind] = ""
			for path in Kinds.candidates(kind):
				if ResourceLoader.exists(path):
					var meshes := Models.batch_meshes(path)
					if not meshes.is_empty():
						chosen[kind] = path
						lod_counts[path] = meshes.size()
						break
		var path: String = chosen[kind]
		if path.is_empty() or not levels.has(int(p.get("level", 0))):
			continue
		batch_paths[path] = true
		if int(p.get("level", 0)) == 0:
			var r: Rect2i = Furnish._rect(p["rect"])
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					modelled[Vector2i(x, y)] = true
	var grey: Dictionary = {}
	for r: Rect2i in data.get("low_blocks", []):
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if not modelled.has(c):
					grey[c] = true
	var multi_meshes := 0
	for path: String in batch_paths:
		multi_meshes += int(lod_counts[path])
	maps.append({"map": id, "props": all_props.size(), "decor_rows": decor_rows, "grey_cells": grey.size(), "prop_batches": batch_paths.size(),
		"multi_meshes": multi_meshes, "containers": ids.size(), "item_slots": slots, "item_quantity": quantity,
		"contents_sha256": var_to_str(contents).sha256_text(), "floors_sha256": floor_hashes,
		"furnish": data.get("room_stats", {}), "bath_selection": data.get("density_baths", {})})

func _save() -> void:
	var stats := summary(rows)
	var file := FileAccess.open(OUT + phase + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase": phase, "engine": Engine.get_version_info()["string"], "maps": maps, "rooms": rows, "summary": stats}, "\t"))
	file.close()
	var table := "|class|rooms|cover median [p10-p90]|count|wall|corner|door empty|\n|---|---:|---|---|---|---|---|\n"
	var classes: Array = stats.keys()
	classes.sort()
	for cls: String in classes:
		var s: Dictionary = stats[cls]
		var line: Array[String] = [cls, str(s["rooms"])]
		for key in ["cover", "count", "wall", "corner", "door_empty"]:
			var m: Dictionary = s[key]
			line.append("n/a" if m["median"] == null else "%.3f [%.3f-%.3f]" % [m["median"], m["p10"], m["p90"]])
		table += "|" + "|".join(line) + "|\n"
	file = FileAccess.open(OUT + phase + ".md", FileAccess.WRITE)
	file.store_string(table)
