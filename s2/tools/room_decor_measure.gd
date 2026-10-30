extends SceneTree
## -- houses_01 houses_02 ...; 생략하면 houses_01~07. 고리 띠 이전의 살림방을 센다.

const FieldMaps = preload("res://game/world/field_maps.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const RoomDecor = preload("res://game/world/room_decor.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const CellarRules = preload("res://game/world/cellar_rules.gd")
const RoofRules = preload("res://game/world/roof_rules.gd")
const RoomSplit = preload("res://game/world/room_split.gd")
const HOUSES: Array[String] = ["houses_01", "houses_02", "houses_03", "houses_04", "houses_05", "houses_06", "houses_07"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ids: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if not FieldMaps.has(arg) or ids.has(arg):
			push_error("지도 이름이 없거나 겹칩니다: " + arg)
			quit(2)
			return
		ids.append(arg)
	if ids.is_empty():
		ids.assign(HOUSES)
	var all_rooms: Array = []
	var all_rows := 0
	var all_ms := 0.0
	var walls := {"north": 0, "west": 0}
	for id: String in ids:
		var data := prepare(id)
		var before := Time.get_ticks_usec()
		var stats := RoomDecor.dress(data)
		var elapsed := float(Time.get_ticks_usec() - before) / 1000.0
		var rooms := census(data)
		var wall := wall_counts(data)
		print("ROOM_DECOR ", JSON.stringify({"map": id, "classes": summarize(rooms), "wall": wall,
			"rows": stats["rows"], "dress_ms": elapsed}))
		all_rooms.append_array(rooms)
		all_rows += int(stats["rows"])
		all_ms += elapsed
		walls["north"] += int(wall["north"])
		walls["west"] += int(wall["west"])
		await process_frame
	print("ROOM_DECOR_TOTAL ", JSON.stringify({"maps": ids, "classes": summarize(all_rooms),
		"wall": _wall_ratios(walls), "rows": all_rows, "dress_ms": all_ms}))
	quit(0)


## field_maps의 name_boxes_by_furniture까지. 바깥 띠 확장과 그 뒤 단계는 실행하지 않는다.
static func prepare(id: String) -> Dictionary:
	var script: Script = load(FieldMaps.path_of(FieldMaps.resolve(id)))
	var data: Dictionary = script.build()
	var consts: Dictionary = script.get_script_constant_map()
	if not data.has("place_id"):
		data["place_id"] = String(consts.get("PLACE_ID", id))
	if not data.has("place_kind"):
		data["place_kind"] = "freight"
	for key: String in FieldMaps.OPTIONAL:
		if not data.has(key):
			data[key] = FieldMaps.OPTIONAL[key].duplicate(true)
	if data["train_doors"].is_empty() and data.get("spawns", {}).has("train_door"):
		data["train_doors"] = {"lower": data["spawns"]["train_door"].duplicate()}
	if data.has("train"):
		if not data.has("platform"):
			data["platform"] = data["train"].grow(FieldMaps.BY_TRAIN)
		if not data.has("unload"):
			data["unload"] = data["platform"]
		if data["train_cars"].is_empty():
			data["train_cars"] = FieldMaps.cars_of(data["train"])
		data["boarding"] = [data["platform"]] + FieldMaps.side_strips(data, data["platform"])
		data["unloading"] = [data["unload"]] + FieldMaps.side_strips(data, data["unload"])
	var ground: FieldGrid = data["grid"]
	for r: Rect2i in data["slow_rects"]:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				ground.floor[ground.index(Vector2i(x, y))] = FieldGrid.Floor.DEEP_SNOW
	data["_defer_paths"] = true
	var hatches := CellarRules.hatches(data)
	RoofRules.plan(data)
	RoomSplit.apply(data, script)
	data["room_stats"] = RoomFurnish.furnish_rooms(data)
	data["room_stats"]["hatches"] = hatches
	data["room_stats"]["fronts"] = RoomFurnish.clear_fronts(data)
	data["furniture_stats"] = RoomFurnish.block_furniture(data)
	data["room_stats"]["boxes_moved"] = RoomFurnish.boxes_into_furniture(data)
	data["room_stats"]["boxes_renamed"] = RoomFurnish.name_boxes_by_furniture(data)
	return data


static func census(data: Dictionary) -> Array:
	var out: Array = []
	var props: Array = data.get("props", [])
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var lvs: Array = levels.keys()
	lvs.sort()
	for lv: int in lvs:
		var g: FieldGrid = levels[lv]
		var map := RoomFurnish._rooms(data, lv, g)
		var of: PackedInt32Array = map["of"]
		var in_room := RoomFurnish._props_by_room(g, of, props, lv)
		for ri in range(map["rooms"].size()):
			var cls := String(data.get("density_classes", {}).get("%d:%d" % [lv, ri], ""))
			var room: Dictionary = map["rooms"][ri]
			if not RoomFurnish.LAYOUT_CLASSES.has(cls) or (cls != "bath" and room["cells"].size() < RoomFurnish.ROOM_MIN_CELLS):
				continue
			var kinds: Dictionary = {}
			var eligible := false
			# 참고 표의 TV 갈래 자리는 우리 세계에서 거실 라디오(radio_set, 이미 있는 가구)가 맡는다.
			var tv := false
			for i: int in in_room.get(ri, []):
				var p: Dictionary = props[i]
				if p.get("decor", false):
					kinds[p["kind"]] = int(kinds.get(p["kind"], 0)) + 1
				elif p.get("kind", "") == "radio_set":
					tv = true
				elif cls == "bath" and p.get("kind", "") == "washstand":
					var r: Rect2i = RoomFurnish._rect(p["rect"])
					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x, r.end.x):
							var cell_rect := Rect2i(Vector2i(x, y), Vector2i.ONE)
							for d: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0)]:
								eligible = eligible or RoomFurnish._wall_side(g, of, ri, cell_rect, d)
			out.append({"map": String(data.get("place_id", "")), "level": lv, "room": ri, "class": cls,
				"kinds": kinds, "kind_count": kinds.size() + int(tv), "tv_role": tv, "mirror_eligible": eligible})
	return out


static func quantile(values: Array, fraction: float) -> Variant:
	if values.is_empty():
		return null
	var sorted := values.duplicate()
	sorted.sort()
	var at := (sorted.size() - 1) * fraction
	return lerpf(float(sorted[int(floor(at))]), float(sorted[int(ceil(at))]), at - floor(at))


static func summarize(rooms: Array) -> Dictionary:
	var out: Dictionary = {}
	for cls: String in RoomDecor.PLAN:
		var counts: Array = []
		var present: Dictionary = {}
		for kind: String in RoomDecor.KINDS:
			present[kind] = 0
		var eligible := 0
		var mirrored := 0
		var unsupported := 0
		var tv_rooms := 0
		for room: Dictionary in rooms:
			if room["class"] != cls:
				continue
			counts.append(room["kind_count"])
			tv_rooms += int(room.get("tv_role", false))
			for kind: String in room["kinds"]:
				present[kind] += 1
			if cls == "bath":
				eligible += int(room["mirror_eligible"])
				mirrored += int(room["mirror_eligible"] and room["kinds"].has("wall_mirror"))
				unsupported += int(not room["mirror_eligible"] and room["kinds"].has("wall_mirror"))
		var ratios: Dictionary = {}
		for kind: String in present:
			ratios[kind] = _ratio(int(present[kind]), counts.size())
		out[cls] = {"rooms": counts.size(), "present_rooms": present, "ratios": ratios,
			"median": quantile(counts, 0.5), "p90": quantile(counts, 0.9),
			"tv_role_ratio": _ratio(tv_rooms, counts.size())}
		if cls == "bath":
			out[cls]["mirror_eligible"] = eligible
			out[cls]["eligible_mirrors"] = mirrored
			out[cls]["eligible_mirror_ratio"] = _ratio(mirrored, eligible)
			out[cls]["unsupported_mirrors"] = unsupported
	return out


static func wall_counts(data: Dictionary) -> Dictionary:
	var out := {"north": 0, "west": 0}
	for p: Dictionary in data.get("props", []):
		if p.get("decor", false) and p.get("mount", "") == "wall":
			if int(p["facing"]) == 0:
				out["north"] += 1
			elif int(p["facing"]) == 3:
				out["west"] += 1
	return _wall_ratios(out)


static func _wall_ratios(counts: Dictionary) -> Dictionary:
	var total := int(counts["north"]) + int(counts["west"])
	return {"north": counts["north"], "west": counts["west"],
		"north_ratio": _ratio(int(counts["north"]), total), "west_ratio": _ratio(int(counts["west"]), total)}


static func _ratio(n: int, d: int) -> Variant:
	return float(n) / d if d > 0 else null
