extends SceneTree
## Map preview: builds one or more map files the way the field does (MapView)
## and saves pictures from the field's own camera (orthogonal, 52 degrees down),
## plus a text drawing of the grid and a row of measurements for review.
##
## Needs a real renderer, so run it without --headless:
##   godot --path s2 -s res://tools/map_preview.gd -- --stats --out=<folder> <map.gd> [<map.gd> ...]
## A map path may be res:// or a path on disk (a map in another checkout).
##
## Per map (<id> is its place_id, or the file name when there is none):
##   <id>_full.png   the whole map, with marks (see MARKS)
##   <id>_band.png   the train and both bands, with marks
##   <id>_deep<n>.png  a phone-sized view at each way into a deep zone
##   <id>_start.png  a phone-sized view where the squad steps off
##   <id>.txt        the ground grid as text
##   <id>.json       measurements

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapView = preload("res://game/world/map_view.gd")
const BaseMap = preload("res://game/world/sulehuf_map.gd")
const FxState = preload("res://fx/fx_state.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor

## The whole-map pictures look straight along the map's axes from this pitch, so a
## map reads as it is drawn; the phone pictures are the field camera's own
## (field_game.gd CAM_PITCH, CAM_YAW: the diagonal view, 결정 476).
const CAM_PITCH: float = 52.0
const FieldGame = preload("res://game/field_game.gd")
const CAM_BACK: float = 60.0
const CAM_SIZE: float = 24.0
## A phone held sideways, drawn at twice its points.
const PHONE := Vector2i(844, 390)
const PHONE_SCALE: int = 2
const MAX_SIDE: int = 2600
## Keys the map contract adds to the base map's.
const EXTRA_KEYS: Array[String] = ["place_id", "place_kind", "bands", "train_doors", "crossings", "barricade_slots", "interior_kind_slots"]
const OPTIONAL_KEYS: Array[String] = ["props"]
const MARKS: Dictionary = {
	"band": Color(0.2, 0.55, 1.0), "entry": Color(1.0, 0.15, 0.15), "barricade": Color(1.0, 0.6, 0.1),
	"train_door": Color(0.2, 0.9, 0.3), "crossing": Color(0.2, 0.9, 0.9), "unseen_block": Color(1.0, 0.1, 0.9),
	"spawn": Color(0.6, 0.1, 0.1), "phone": Color(1.0, 1.0, 0.3),
}
const FLOOR_CHARS: String = ".:_,=~-'"
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var viewport: SubViewport
var camera: Camera3D
var sun: DirectionalLight3D
var failed: bool = false
var stats: bool = false
var map_view: Node3D


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := ""
	var maps: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg == "--stats":
			stats = true
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		else:
			maps.append(arg)
	if out == "" or maps.is_empty():
		printerr("usage: -- [--stats] --out=<folder> <map.gd> [<map.gd> ...]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	_build_stage()
	for path in maps:
		await _preview(path, out)
	quit(1 if failed else 0)


func _build_stage() -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var light: Dictionary = FxState.lighting_for([], 12.0)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.72, 0.74, 0.78).darkened(0.75)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = light.get("ambient_color", Color(0.8, 0.82, 0.86))
	environment.ambient_light_energy = float(light.get("ambient_energy", 0.6))
	world.environment = environment
	viewport.add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(FxState.SUN_PITCH, -30, 0)
	sun.light_energy = float(light.get("sun_energy", 1.0))
	sun.light_color = light.get("sun_color", Color.WHITE)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	viewport.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 400.0
	viewport.add_child(camera)
	camera.current = true


func _preview(path: String, out: String) -> void:
	var script: Variant = load(path)
	if script == null or not script.has_method("build"):
		printerr("map_preview: cannot load a map with build(): %s" % path)
		failed = true
		return
	var data: Dictionary = script.build()
	var id := String(data.get("place_id", path.get_file().get_basename()))
	var grid: FieldGrid = data["grid"]
	var report := _measure(data, script)
	report["file"] = path.get_file()
	_save_text(out.path_join(id + ".txt"), _grid_text(data))
	_save_text(out.path_join(id + ".json"), JSON.stringify(report, "\t"))
	var missing: Array = report["missing_view_keys"]
	if not missing.is_empty():
		# MapView reads these without asking; without them there is nothing to draw.
		printerr("map_preview: %s has no %s, pictures skipped" % [id, ", ".join(missing)])
		failed = true
		return
	var view := MapView.new()
	map_view = view
	viewport.add_child(view)
	view.setup(data)
	view.set_mask_enabled(false)
	view.show_levels(0)
	view.cut_away(-1)
	view.update_labels(PackedByteArray(), false)
	var marks := _build_marks(data, report)
	viewport.add_child(marks)
	var middle := Vector3(grid.width * 0.5, 0, grid.height * 0.5)
	await _shoot(middle, Vector2(grid.width + 2.0, grid.height + 6.0), out.path_join(id + "_full.png"))
	var train: Rect2i = data.get("train", Rect2i())
	var around: Rect2i = train
	for side in data.get("bands", {}):
		around = around.merge(data["bands"][side])
	if around.size.x > 0:
		var at := Vector3(around.position.x + around.size.x * 0.5, 0, around.position.y + around.size.y * 0.5)
		await _shoot(at, Vector2(around.size.x + 6.0, around.size.y + 10.0), out.path_join(id + "_band.png"))
	marks.visible = false
	var n := 0
	for c in report["deep_entrances"]:
		n += 1
		await _shoot_phone(FieldGrid.center(_cell(c)), out.path_join("%s_deep%d.png" % [id, n]))
	var squad: Array = data.get("spawns", {}).get("squad", [])
	if not squad.is_empty():
		await _shoot_phone(FieldGrid.center(squad[0]), out.path_join(id + "_start.png"))
	view.queue_free()
	map_view = null
	marks.queue_free()
	await process_frame
	print("map_preview: %s done" % id)


## A picture of the ground rectangle `span` (metres across, metres deep) around `focus`.
func _shoot(focus: Vector3, span: Vector2, file: String) -> void:
	var pitch := deg_to_rad(CAM_PITCH)
	# What the camera sees top to bottom: the ground foreshortened, and wall height at the far edge.
	var tall := span.y * sin(pitch) + 4.0
	var px := minf(14.0, MAX_SIDE / maxf(span.x, tall))
	await _take(focus, tall, Vector2i(int(span.x * px), int(tall * px)), file)


## What the player sees on a phone at the default zoom, from the field camera's turn.
func _shoot_phone(focus: Vector3, file: String) -> void:
	await _take(focus, CAM_SIZE, PHONE * PHONE_SCALE, file, FieldGame.cam_back())


func _take(focus: Vector3, size: float, pixels: Vector2i, file: String, back := Vector3.ZERO) -> void:
	var pitch := deg_to_rad(CAM_PITCH)
	if back == Vector3.ZERO:
		back = Vector3(0, sin(pitch), cos(pitch))
	viewport.size = pixels
	camera.size = size
	camera.look_at_from_position(focus + back * CAM_BACK, focus, Vector3.UP)
	map_view.refresh_props(camera)
	for k in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	if stats:
		# 지금 찍는 뷰포트의 보이는 패스. 지도 전체의 삼각형 합이나 그림자 패스가 아니다.
		var triangles := RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE)
		var calls := RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE)
		print("map_preview_stats file=%s triangles=%d draw_calls=%d pixels=%dx%d" % [file.get_file(), triangles, calls, pixels.x, pixels.y])
	var image := viewport.get_texture().get_image()
	if image == null or image.save_png(file) != OK:
		printerr("map_preview: could not save %s" % file)
		failed = true


## Flat marks just above the ground and posts where the dead come in.
func _build_marks(data: Dictionary, report: Dictionary) -> Node3D:
	var node := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in data.get("bands", {}):
		_outline(st, data["bands"][side], MARKS["band"])
	for name in data.get("entries", {}):
		for c in data["entries"][name]:
			MapView.box(st, Vector3(0.9, 0.1, 0.9), FieldGrid.center(c) + Vector3(0, 0.1, 0), MARKS["entry"])
			MapView.box(st, Vector3(0.25, 4.0, 0.25), FieldGrid.center(c) + Vector3(0, 2.0, 0), MARKS["entry"])
	for name in data.get("spawns", {}):
		if name == "squad" or name == "train_door":
			continue
		for row in data["spawns"][name]:
			var c: Vector2i = row[0] if row is Array else row
			if not (row is Array) or int(row[1]) == 0:
				MapView.box(st, Vector3(0.5, 0.1, 0.5), FieldGrid.center(c) + Vector3(0, 0.1, 0), MARKS["spawn"])
	for c in data.get("barricade_slots", []):
		MapView.box(st, Vector3(0.8, 0.08, 0.8), FieldGrid.center(c) + Vector3(0, 0.08, 0), MARKS["barricade"])
	for side in data.get("train_doors", {}):
		for c in data["train_doors"][side]:
			MapView.box(st, Vector3(0.9, 0.12, 0.9), FieldGrid.center(c) + Vector3(0, 0.1, 0), MARKS["train_door"])
	for crossing in data.get("crossings", []):
		for c in crossing.get("cells", []):
			MapView.box(st, Vector3(0.4, 0.06, 0.4), FieldGrid.center(c) + Vector3(0, 0.06, 0), MARKS["crossing"])
	for c in report["unseen_block_cells"]:
		MapView.box(st, Vector3(0.9, 0.06, 0.9), FieldGrid.center(_cell(c)) + Vector3(0, 0.06, 0), MARKS["unseen_block"])
	# The ground a phone shows at the default zoom, where the squad steps off.
	var squad: Array = data.get("spawns", {}).get("squad", [])
	if not squad.is_empty():
		var wide := CAM_SIZE * PHONE.x / PHONE.y
		var deep := CAM_SIZE / sin(deg_to_rad(CAM_PITCH))
		var c: Vector2i = squad[0]
		_outline(st, Rect2i(int(c.x - wide * 0.5), int(c.y - deep * 0.5), int(wide), int(deep)), MARKS["phone"])
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	node.mesh = st.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _outline(st: SurfaceTool, r: Rect2i, color: Color) -> void:
	var w := 0.3
	var mid := Vector3(r.position.x + r.size.x * 0.5, 0.07, r.position.y + r.size.y * 0.5)
	MapView.box(st, Vector3(r.size.x, 0.06, w), Vector3(mid.x, 0.07, r.position.y), color)
	MapView.box(st, Vector3(r.size.x, 0.06, w), Vector3(mid.x, 0.07, r.end.y), color)
	MapView.box(st, Vector3(w, 0.06, r.size.y), Vector3(r.position.x, 0.07, mid.z), color)
	MapView.box(st, Vector3(w, 0.06, r.size.y), Vector3(r.end.x, 0.07, mid.z), color)


## What a reviewer would otherwise count by hand. Cells are written [x, y].
func _measure(data: Dictionary, script: Variant) -> Dictionary:
	var grid: FieldGrid = data["grid"]
	var report: Dictionary = {"place_id": data.get("place_id", ""), "place_kind": data.get("place_kind", ""), "size": [grid.width, grid.height]}
	var base_keys: Array = BaseMap.build().keys()
	var missing: Array = []
	for key in base_keys + EXTRA_KEYS:
		if not data.has(key):
			missing.append(key)
	report["missing_keys"] = missing
	var extra: Array = []
	for key in data:
		if not base_keys.has(key) and not EXTRA_KEYS.has(key) and not OPTIONAL_KEYS.has(key):
			extra.append(key)
	report["unknown_keys"] = extra
	var need: Array = []
	for key in ["containers", "spots", "stoves", "manholes", "labels", "train", "train_cars", "spawns", "lights", "wagons", "trees", "low_blocks"]:
		if not data.has(key):
			need.append(key)
	report["missing_view_keys"] = need
	var constants: Dictionary = script.get_script_constant_map()
	report["zone_names"] = constants.get("ZONE_NAMES", {})
	report["levels"] = data.get("levels", {}).keys()
	report["stairs"] = data.get("stairs", []).size()
	var train: Rect2i = data.get("train", Rect2i())
	report["train"] = _rect(train)
	report["train_edge_gap"] = [train.position.x, train.position.y, grid.width - train.end.x, grid.height - train.end.y]
	var bands: Dictionary = data.get("bands", {})
	var band_rows: Dictionary = {}
	for side in bands:
		var band: Rect2i = bands[side]
		var low := 0
		for r in data.get("low_blocks", []):
			if band.intersects(r):
				low += 1
		var trees := 0
		for c in data.get("trees", []):
			if band.has_point(c):
				trees += 1
		# A side of the band counts as open when most of it can be walked across.
		var open_sides: Array = []
		for edge in _band_edges(band):
			var walk := 0
			for c in edge["cells"]:
				if grid.people_can_walk(c):
					walk += 1
			if walk * 2 > edge["cells"].size():
				open_sides.append("%s %d/%d" % [edge["name"], walk, edge["cells"].size()])
		band_rows[side] = {"rect": _rect(band), "low_blocks": low, "trees": trees, "open_sides": open_sides, "train_doors": data.get("train_doors", {}).get(side, []).size()}
	report["bands"] = band_rows
	var entries: Dictionary = {}
	var entries_in_band := 0
	for name in data.get("entries", {}):
		var inside := 0
		var blocked := 0
		for c in data["entries"][name]:
			if _in_bands(bands, c):
				inside += 1
			if not grid.dead_can_walk(c):
				blocked += 1
		entries_in_band += inside
		entries[name] = {"cells": data["entries"][name].size(), "first": _xy(data["entries"][name][0]), "in_band": inside, "not_walkable": blocked, "gap": data.get("entry_gap", {}).get(name, null), "level": data.get("entry_levels", {}).get(name, 0)}
	report["entries"] = entries
	report["entries_in_band"] = entries_in_band
	var spawns_in_band := 0
	var spawn_count := 0
	for name in data.get("spawns", {}):
		if name == "squad" or name == "train_door":
			continue
		for row in data["spawns"][name]:
			spawn_count += 1
			if _in_bands(bands, row[0] if row is Array else row):
				spawns_in_band += 1
	report["spawns"] = spawn_count
	report["spawns_in_band"] = spawns_in_band
	# Walking from the train doors (people open closed doors, locked ones stop them).
	var doors: Array = data.get("spawns", {}).get("train_door", [])
	var reached := _flood(grid, doors)
	var zones: Dictionary = {}
	var unreached := 0
	for y in range(grid.height):
		for x in range(grid.width):
			var c := Vector2i(x, y)
			if not grid.people_can_walk(c):
				continue
			var z := grid.zone_at(c)
			if not zones.has(z):
				zones[z] = {"cells": 0, "reached": 0}
			zones[z]["cells"] += 1
			if reached[grid.index(c)] == 1:
				zones[z]["reached"] += 1
			else:
				unreached += 1
	report["zones"] = zones
	# Each way in: can the dead walk from it to a train door as the map stands (shut doors stop them).
	for name in data.get("entries", {}):
		if int(data.get("entry_levels", {}).get(name, 0)) != 0:
			entries[name]["reaches_train_door"] = null
			continue
		var from_entry := _flood(grid, data["entries"][name], true)
		var hit := false
		for c in doors:
			if grid.inside(c) and from_entry[grid.index(c)] == 1:
				hit = true
		entries[name]["reaches_train_door"] = hit
	# How alike the two sides of the train are: the share of cells, mirrored across
	# the train, that hold the same solid and floor (1.0 is a mirror image).
	var same := 0
	var pairs := 0
	for k in range(1, mini(train.position.y, grid.height - train.end.y) + 1):
		for x in range(grid.width):
			var up := Vector2i(x, train.position.y - k)
			var down := Vector2i(x, train.end.y - 1 + k)
			pairs += 1
			if grid.solid_at(up) == grid.solid_at(down) and grid.floor_at(up) == grid.floor_at(down):
				same += 1
	report["mirror_share"] = snappedf(float(same) / maxf(1.0, pairs), 0.001)
	var solid_same := 0
	var solid_any := 0
	for k in range(1, mini(train.position.y, grid.height - train.end.y) + 1):
		for x in range(grid.width):
			var a := grid.solid_at(Vector2i(x, train.position.y - k))
			var b := grid.solid_at(Vector2i(x, train.end.y - 1 + k))
			if a != S.NONE or b != S.NONE:
				solid_any += 1
				if a == b:
					solid_same += 1
	report["mirror_share_of_solids"] = snappedf(float(solid_same) / maxf(1.0, solid_any), 0.001)
	report["walkable_not_reached"] = unreached
	# Ways into each deep zone: runs of walkable cells of the zone that touch another zone.
	var deep_rows: Dictionary = {}
	var deep_cells: Array = []
	for slot in data.get("interior_kind_slots", []):
		var zone := String(slot.get("zone", ""))
		var mouths: Array[Vector2i] = []
		for y in range(grid.height):
			for x in range(grid.width):
				var c := Vector2i(x, y)
				if grid.zone_at(c) != zone or not grid.people_can_walk(c):
					continue
				for d in DIRS:
					if grid.people_can_walk(c + d) and grid.zone_at(c + d) != zone:
						mouths.append(c)
						break
		var groups := _groups(mouths)
		deep_rows[zone] = {"entrances": groups.size(), "kinds": slot.get("kinds", [])}
		var fronts: Array = []
		for group in groups:
			deep_cells.append(_xy(group[0]))
			# Open ground outside the way in: walkable cells of other zones within four cells.
			var open := 0
			var at: Vector2i = group[0]
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					var n := at + Vector2i(dx, dy)
					if grid.people_can_walk(n) and grid.zone_at(n) != zone:
						open += 1
			fronts.append(open)
		deep_rows[zone]["open_cells_in_front"] = fronts
	report["deep"] = deep_rows
	report["deep_entrances"] = deep_cells
	# Buildings: inner wall cells say whether a building is more than one box.
	var buildings: Array = []
	for b in data.get("buildings", []):
		var r: Rect2i = b["rect"]
		var inner := 0
		for y in range(r.position.y + 1, r.end.y - 1):
			for x in range(r.position.x + 1, r.end.x - 1):
				if grid.solid_at(Vector2i(x, y)) == S.WALL:
					inner += 1
		var door_count := 0
		var window_count := 0
		for c in grid.doors:
			if int(grid.doors[c].get("building", -1)) == int(b["id"]):
				door_count += 1
		for c in grid.windows:
			if int(grid.windows[c].get("building", -1)) == int(b["id"]):
				window_count += 1
		buildings.append({"id": b["id"], "name": b["name"], "rect": _rect(r), "inner_wall_cells": inner, "doors": door_count, "windows": window_count})
	report["buildings"] = buildings
	var door_states: Dictionary = {}
	for c in grid.doors:
		var state := String(grid.doors[c]["state"])
		door_states[state] = int(door_states.get(state, 0)) + 1
	report["door_states"] = door_states
	var boxes: Dictionary = {}
	for id in data.get("containers", {}):
		var box: Dictionary = data["containers"][id]
		var z := grid.zone_at(box["cell"]) + ("@%d" % int(box.get("level", 0)) if int(box.get("level", 0)) != 0 else "")
		boxes[z] = int(boxes.get(z, 0)) + 1
	report["containers_by_zone"] = boxes
	report["spots"] = data.get("spots", {}).size()
	report["wagons"] = data.get("wagons", []).size()
	report["trees"] = data.get("trees", []).size()
	report["low_blocks"] = data.get("low_blocks", []).size()
	report["barricade_slots"] = data.get("barricade_slots", []).size()
	report["crossings"] = data.get("crossings", []).size()
	# MapView draws a BLOCK only as the train, a wagon, a tree, or (inside x<14, y<14)
	# a six-metre tower. Any other BLOCK outdoors stops people and shows nothing.
	var unseen: Array = []
	var tower := 0
	var drawn: Dictionary = {}
	for c in data.get("trees", []):
		drawn[c] = true
	for y in range(grid.height):
		for x in range(grid.width):
			var c := Vector2i(x, y)
			if grid.solid_at(c) != S.BLOCK or grid.building_at(c) >= 0 or train.has_point(c) or drawn.has(c):
				continue
			var in_wagon := false
			for w in data.get("wagons", []):
				if w["rect"].has_point(c):
					in_wagon = true
			if in_wagon:
				continue
			if x < 14 and y < 14:
				tower += 1
			else:
				unseen.append(_xy(c))
	report["unseen_block_cells"] = unseen
	report["unseen_blocks"] = unseen.size()
	report["tower_blocks"] = tower
	var low_unlisted := 0
	var listed: Dictionary = {}
	for r in data.get("low_blocks", []):
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				listed[Vector2i(x, y)] = true
	for st in data.get("stoves", []):
		listed[st["cell"]] = true
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.solid_at(Vector2i(x, y)) == S.LOW and not listed.has(Vector2i(x, y)):
				low_unlisted += 1
	report["low_cells_not_drawn"] = low_unlisted
	var floors: Dictionary = {}
	for kind in grid.floor:
		floors[F.keys()[kind]] = int(floors.get(F.keys()[kind], 0)) + 1
	report["floor_cells"] = floors
	return report


func _band_edges(band: Rect2i) -> Array:
	var rows: Array = [{"name": "north", "cells": []}, {"name": "south", "cells": []}, {"name": "west", "cells": []}, {"name": "east", "cells": []}]
	for x in range(band.position.x, band.end.x):
		rows[0]["cells"].append(Vector2i(x, band.position.y))
		rows[1]["cells"].append(Vector2i(x, band.end.y - 1))
	for y in range(band.position.y, band.end.y):
		rows[2]["cells"].append(Vector2i(band.position.x, y))
		rows[3]["cells"].append(Vector2i(band.end.x - 1, y))
	return rows


func _in_bands(bands: Dictionary, c: Vector2i) -> bool:
	for side in bands:
		if bands[side].has_point(c):
			return true
	return false


func _flood(grid: FieldGrid, from: Array, for_dead: bool = false) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(grid.width * grid.height)
	var queue: Array[Vector2i] = []
	for c in from:
		if grid.inside(c) and (grid.dead_can_walk(c) if for_dead else grid.people_can_walk(c)):
			seen[grid.index(c)] = 1
			queue.append(c)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in DIRS:
			var n := c + d
			if (grid.dead_can_walk(n) if for_dead else grid.people_can_walk(n)) and seen[grid.index(n)] == 0:
				seen[grid.index(n)] = 1
				queue.append(n)
	return seen


## Cells that touch (corners count) fall into one group.
func _groups(cells: Array[Vector2i]) -> Array:
	var left: Dictionary = {}
	for c in cells:
		left[c] = true
	var groups: Array = []
	for c in cells:
		if not left.has(c):
			continue
		var group: Array[Vector2i] = [c]
		left.erase(c)
		var head := 0
		while head < group.size():
			var at := group[head]
			head += 1
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := at + Vector2i(dx, dy)
					if left.has(n):
						left.erase(n)
						group.append(n)
		groups.append(group)
	return groups


## The ground grid as text. Floors: . snow  : road  _ platform  , wood  = rail
## ~ deep snow  - ice  ' gravel. Solids: # wall  B block  T train  W wagon
## t tree  o low  D door  L locked door  w window. Over those: ! entry
## x barricade slot  d train door  c container  s spot.
func _grid_text(data: Dictionary) -> String:
	var grid: FieldGrid = data["grid"]
	var over: Dictionary = {}
	for id in data.get("spots", {}):
		over[data["spots"][id]["cell"]] = "s"
	for id in data.get("containers", {}):
		if int(data["containers"][id].get("level", 0)) == 0:
			over[data["containers"][id]["cell"]] = "c"
	for c in data.get("barricade_slots", []):
		over[c] = "x"
	for side in data.get("train_doors", {}):
		for c in data["train_doors"][side]:
			over[c] = "d"
	for name in data.get("entries", {}):
		for c in data["entries"][name]:
			over[c] = "!"
	var trees: Dictionary = {}
	for c in data.get("trees", []):
		trees[c] = true
	var train: Rect2i = data.get("train", Rect2i())
	var lines := PackedStringArray()
	for y in range(grid.height):
		var line := ""
		for x in range(grid.width):
			var c := Vector2i(x, y)
			var ch := FLOOR_CHARS[grid.floor_at(c)]
			match grid.solid_at(c):
				S.WALL:
					ch = "#"
				S.BLOCK:
					ch = "T" if train.has_point(c) else ("t" if trees.has(c) else "B")
					for w in data.get("wagons", []):
						if w["rect"].has_point(c):
							ch = "W"
				S.LOW:
					ch = "o"
				S.DOOR:
					ch = "L" if grid.doors.has(c) and grid.doors[c]["state"] == "locked" else "D"
				S.WINDOW:
					ch = "w"
			line += String(over.get(c, ch))
		lines.append(line)
	return "\n".join(lines) + "\n"


func _save_text(file: String, text: String) -> void:
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		printerr("map_preview: could not write %s" % file)
		failed = true
		return
	f.store_string(text)


func _rect(r: Rect2i) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]


func _xy(c: Vector2i) -> Array:
	return [c.x, c.y]


func _cell(row: Variant) -> Vector2i:
	return Vector2i(int(row[0]), int(row[1]))
