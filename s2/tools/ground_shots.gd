extends SceneTree
## Windowed before/after capture. Uses only APIs already present in the box
## version: copy this tool there unchanged to produce the baseline directory.
## godot --path s2 --resolution 1688x780 -s res://tools/ground_shots.gd -- <out_dir>
## Contrast is measured on raw viewport images, before lossy JPG encoding.
## No ground-model helper, builder or baked-template API is used here.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const MapShots = preload("res://tools/map_shots.gd")
const FxState = preload("res://fx/fx_state.gd")
const RUN_TIMEOUT: float = 600.0
const SCENE_TIMEOUT: float = 90.0
const ZOOM: float = 24.0
const CLOSE_ZOOM: float = 18.0
const CHANGE: float = 2.0 / 255.0
## Low pixel counts are reported, never used to move or exclude a drawn row.
const MIN_VISIBLE_PIXELS: int = 40
const PROBE_VISIBLE: float = 0.95
const SPARE_CELLS: int = 24
## The three on one cell and the clothes cell lie this far from where the camera
## looks from (the hidden leader's cell) at least.
const CLOSE_MIN_DISTANCE: float = 3.0
## Zoom 18 frames are also cut round the cell and enlarged (the things are a few
## dozen pixels in the whole frame): a PNG, pixels kept as drawn (nearest).
const CROP_HALF: Vector2i = Vector2i(120, 80)
const CROP_SCALE: int = 3
const THINGS: Array[String] = [
	"knife", "drawers_cotton", "cloth", "note_map", "plank", "oats", "can_empty", "food_pack",
	"core_engine", "ammo_craft", "axe", "coat_long", "bottle_spirit", "junk_nails", "can_beans", "jar_jam",
]
const TRIPLE: Array[String] = ["knife", "shirt_cotton", "can_beans"]
const CLOTHES_CELL: Array[String] = ["coat_long", "shirt_flannel", "trousers_work", "boots_work"]
const EXPECTED_SHOTS: int = 25
const SCENES: Array[Dictionary] = [
	{"name": "yard_autumn", "spot": "yard", "cold": 0.0, "side": 0.0},
	{"name": "road_autumn", "spot": "road", "cold": 0.0, "side": 0.0},
	{"name": "inside_autumn", "spot": "inside", "cold": 0.0, "side": 0.0},
	{"name": "yard_winter", "spot": "yard", "cold": 1.0, "side": 0.5},
	{"name": "inside_winter", "spot": "inside", "cold": 1.0, "side": 0.5},
]

var _out: String = ""
var _failed: bool = false
var _game: FieldGame = null
var _scene_started: int = 0
var _scene_serial: int = 0
var _shots: Array[String] = []
var _probe_captures: int = 0
var _report: Dictionary = {
	"place": FieldMaps.DEFAULT_PLACE, "region": "K1", "seed": 5, "zoom": ZOOM,
	"rules_weather": ["clear"], "day_look": ["overcast"], "night_look": ["clear"],
	"contrast": {"space": "viewport sRGB", "luma": [0.2126, 0.7152, 0.0722], "changed_channel_threshold": CHANGE, "source": "raw viewport images before JPG encoding"},
	"scenes": [], "closeups": [],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		_fail("usage: -- <out_dir>")
		return
	if DisplayServer.get_name() == "headless":
		_fail("a rendering window is required")
		return
	_out = ProjectSettings.globalize_path(args[0])
	var made: Error = DirAccess.make_dir_recursive_absolute(_out)
	if made != OK:
		_fail("output directory: " + error_string(made))
		return
	root.close_requested.connect(_fail.bind("window closed before capture finished"))
	create_timer(RUN_TIMEOUT).timeout.connect(_fail.bind("run timeout"))
	for hour: float in [12.0, 22.0]:
		for scene: Dictionary in SCENES:
			await _scene(scene, hour)
			if _failed:
				return
	if _shots.size() != EXPECTED_SHOTS:
		_fail("expected %d JPGs, got %d" % [EXPECTED_SHOTS, _shots.size()])
		return
	_report["shots"] = _shots
	if not _write_reports():
		return
	print("GROUND_SHOTS_DONE scenes=10 jpgs=%d worst_items=300" % EXPECTED_SHOTS)
	quit(0)


func _scene(scene: Dictionary, hour: float) -> void:
	_scene_started = Time.get_ticks_msec()
	_scene_serial += 1
	create_timer(SCENE_TIMEOUT).timeout.connect(_scene_timeout.bind(_scene_serial))
	var game: FieldGame = FieldGame.new()
	_game = game
	var night: bool = hour > 20.0
	var tag: String = String(scene["name"]) + ("_night" if night else "_day")
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "arrive": false,
		"place": FieldMaps.DEFAULT_PLACE, "region": "K1", "weather": ["clear"],
		"look": ["clear"] if night else ["overcast"], "look_hour": hour,
		"cold": scene["cold"], "side": scene["side"]}
	root.add_child(game)
	if game.view == null or game.camera == null or game.player == null or game.data.is_empty():
		_fail(tag + ": field did not initialize")
		return
	game.clock.elapsed = maxf(hour - 10.5, 0.0) * 240.0
	game.hud.visible = false
	game.cam_push = Vector3.ZERO
	game.mask_on = false
	game.view.set_mask_enabled(false)
	game.paused = true
	var grid: FieldGrid = game.data["grid"]
	var spots: Dictionary = MapShots.pick_spots(game.data, grid)
	var spot: String = scene["spot"]
	if not spots.has(spot):
		_fail(tag + ": no " + spot + " cell")
		return
	var centre: Vector2i = spots[spot]
	# Choose the level and cut before the first tick, as in map_shots: otherwise
	# the roof/upper floors from the previous focus can survive into the image.
	_aim(game, centre, ZOOM)
	game.set_process(true)
	for _frame: int in range(4):
		await process_frame
		_resume(game)
	game.paused = false
	game.set_process(false)
	_resume(game)
	if game.zombies != null:
		game.zombies.visible = false
	game.fx_params["fx_fade"] = 0.0
	FxState.apply({"fx_fade": 0.0})
	game._update_light()
	var cloud := Vector4(game.fx_params.get("fx_cloud", Vector4.ZERO))
	FxState.apply({"fx_cloud": Vector4(cloud.x, 0.0, 0.0, cloud.w)})
	_aim(game, centre, ZOOM)
	await create_timer(2.6).timeout
	if not _alive():
		return
	_resume(game)
	_aim(game, centre, ZOOM)
	_freeze_particles(game)
	# The leader and the squad stand where the camera looks; they would cover
	# the things near them, in both versions alike.
	_hide_people(game)
	_probe_captures = 0
	var cells: Array[Vector2i] = _cells(game, grid, centre, spot, THINGS.size() + 1 + SPARE_CELLS)
	if cells.size() < THINGS.size() + 1:
		_fail(tag + ": insufficient visible walkable cells for all things")
		return
	_put(game, [])
	var floor_image: Image = await _capture(tag + "_floor.jpg")
	if floor_image == null:
		return
	var single_probes: Dictionary = await _probe_cells(game, cells, 0.7, floor_image)
	if _failed:
		return
	cells.assign(single_probes["cells"])
	if cells.size() < THINGS.size() + 1:
		_fail(tag + ": insufficient probe-visible cells for all things: " + str(cells.size()))
		return
	var far_cells: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if Vector2(cell).distance_to(Vector2(centre)) >= CLOSE_MIN_DISTANCE:
			far_cells.append(cell)
	var triple_probes: Dictionary = await _probe_cells(game, far_cells, 2.4, floor_image)
	if _failed:
		return
	var triple_candidates: Array[Vector2i] = []
	triple_candidates.assign(triple_probes["cells"])
	var triple_cell: Vector2i = _far_cell(triple_candidates, centre)
	if triple_cell == Vector2i(-1, -1):
		_fail(tag + ": no cell %.0f cells from the camera's for the three" % CLOSE_MIN_DISTANCE)
		return
	cells.erase(triple_cell)
	var rows: Array[Dictionary] = []
	var selected_singles: Array = []
	for index: int in THINGS.size():
		rows.append({"id": THINGS[index], "n": 1, "pos": FieldGrid.center(cells[index])})
		selected_singles.append([cells[index].x, cells[index].y])
	for id: String in TRIPLE:
		rows.append({"id": id, "n": 1, "pos": FieldGrid.center(triple_cell)})
	var geometry: Dictionary = _item_polygons(game, rows, floor_image.get_size())
	if _failed:
		return
	var item_image: Image = await _capture(tag + "_items.jpg")
	if item_image == null:
		return
	if item_image.get_size() != floor_image.get_size():
		_fail(tag + ": viewport size changed within pair")
		return
	var polygons: Array = geometry["polygons"]
	var measurements: Array[Dictionary] = _measure(floor_image, item_image, polygons, rows)
	var summary: Dictionary = summarize(measurements)
	if summary.is_empty():
		_fail(tag + ": no drawn rows in final geometry")
		return
	var triple_summary: Dictionary = summarize(measurements.slice(THINGS.size()))
	var boxes: Array[Rect2i] = []
	for polygon: PackedVector2Array in polygons:
		boxes.append(polygon_bounds(polygon))
	var update_ms: float = float(geometry["update_ms"])
	var metrics: Dictionary = _metrics(game, update_ms)
	(_report["scenes"] as Array).append({"name": tag, "hour": hour, "cold": scene["cold"], "side": scene["side"],
		"cell": [centre.x, centre.y], "items": measurements, "summary": summary, "metrics": metrics,
		"moved_from_hidden_cells": [], "still_hidden": [],
		"triple_summary": triple_summary, "vertex_counts": geometry["counts"],
		"selected_cells": {"singles": selected_singles, "triple": [triple_cell.x, triple_cell.y]},
		"probes": {"captures": _probe_captures, "threshold": PROBE_VISIBLE,
			"singles": single_probes["rows"], "triple": triple_probes["rows"]},
		"overlapping_boxes": _overlaps(boxes), "render_size": [item_image.get_width(), item_image.get_height()]})
	print("GROUND_SHOT %s contrast_min=%.6f update_ms=%.3f" % [tag, summary["weakest"]["mean_abs_luma"], update_ms])
	if String(scene["name"]) == "yard_autumn":
		var triple_rows: Array[Dictionary] = []
		for row: Dictionary in rows.slice(THINGS.size()):
			triple_rows.append(row)
		_put(game, triple_rows)
		_aim(game, triple_cell, CLOSE_ZOOM)
		_hide_people(game)
		var close_image: Image = await _capture(tag + "_triple_zoom18.jpg")
		if close_image == null:
			return
		var crop: String = _save_crop(game, close_image, triple_cell, tag + "_triple_zoom18_crop.png")
		if crop.is_empty():
			return
		(_report["closeups"] as Array).append({"name": tag, "zoom": CLOSE_ZOOM, "cell": [triple_cell.x, triple_cell.y], "items": TRIPLE, "crop": crop})
		await _clothes_cell(game, triple_cell, tag)
		if _failed:
			return
		if not night:
			_aim(game, centre, ZOOM)
			await _worst(game, grid, centre)
			if _failed:
				return
	game.queue_free()
	_game = null
	await process_frame


func _clothes_cell(game: FieldGame, cell: Vector2i, tag: String) -> void:
	var rows: Array[Dictionary] = []
	for id: String in CLOTHES_CELL:
		rows.append({"id": id, "n": 1, "pos": FieldGrid.center(cell)})
	# Compare public ground meshes after three and four rows: the fourth must
	# add no geometry in either the original box version or the model version.
	_put(game, rows.slice(0, 3))
	var first_three: Dictionary = _ground_shape_hashes(game)
	_put(game, rows)
	if _ground_shape_hashes(game) != first_three:
		_fail(tag + ": the fourth clothes row changed the ground geometry")
		return
	var drawn_rows: int = _drawn_rows(game)
	_aim(game, cell, CLOSE_ZOOM)
	_hide_people(game)
	var filename: String = tag + "_clothes_cell_zoom18.jpg"
	var image: Image = await _capture(filename)
	if image == null:
		return
	var crop: String = _save_crop(game, image, cell, tag + "_clothes_cell_zoom18_crop.png")
	if crop.is_empty():
		return
	(_report["closeups"] as Array).append({"name": tag, "kind": "clothes_cell", "shot": filename,
		"zoom": CLOSE_ZOOM, "cell": [cell.x, cell.y], "items": CLOTHES_CELL, "crop": crop,
		"submitted": 4, "drawable": 3, "drawn": drawn_rows, "omitted": 3 - drawn_rows, "fourth_keeps_geometry": true})


## Rows drawn on the ground now, counted the same way in both versions: every
## drawn thing lays one rim quad (six vertices) on its floor's Rim mesh, whatever
## its own shape. A thing left undrawn (a fourth on a cell, or no clear room)
## adds none.
static func _drawn_rows(game: FieldGame) -> int:
	var rim_vertices: int = 0
	for level: Variant in game.view.ground_nodes:
		var rim := (game.view.ground_nodes[level] as Node).get_node_or_null("Rim") as MeshInstance3D
		if rim != null:
			rim_vertices += _vertices(rim.mesh).size()
	return floori(float(rim_vertices) / 6.0)


## Measure each final hull independently, excluding every shared pixel.
static func _measure(floor_image: Image, item_image: Image, polygons: Array, rows: Array[Dictionary]) -> Array[Dictionary]:
	var measurements: Array[Dictionary] = []
	var masks: Array[Dictionary] = exclusive_pixels(polygons, floor_image.get_size())
	for index: int in rows.size():
		var polygon: PackedVector2Array = polygons[index]
		var pixels: Array[Vector2i] = []
		pixels.assign(masks[index]["pixels"])
		var measured: Dictionary = contrast_pixels(floor_image, item_image, pixels)
		var rect: Rect2i = polygon_bounds(polygon)
		measured["box"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		var coordinates: Array = []
		for point: Vector2 in polygon:
			coordinates.append([point.x, point.y])
		measured["polygon"] = coordinates
		measured["polygon_area_px"] = polygon_area(polygon)
		measured["polygon_pixels"] = masks[index]["polygon_pixels"]
		measured["shared_pixels"] = masks[index]["shared_pixels"]
		measured["exclusive_pixels"] = pixels.size()
		measured["drawn"] = not polygon.is_empty()
		measured.merge(visibility(int(measured["changed_pixels"]), float(measured["polygon_area_px"]),
			int(measured["shared_pixels"]), bool(measured["drawn"])))
		if polygon.is_empty():
			measured["status"] = "not_drawn"
		measured["id"] = rows[index]["id"]
		measured["slot"] = index
		measured["group"] = "triple" if index >= THINGS.size() else "single"
		measured["cell"] = [FieldGrid.cell_of(rows[index]["pos"]).x, FieldGrid.cell_of(rows[index]["pos"]).y]
		measurements.append(measured)
	return measurements


## The first of `cells` (nearest first) CLOSE_MIN_DISTANCE or more from
## `centre`; (-1, -1) when none is.
static func _far_cell(cells: Array[Vector2i], centre: Vector2i) -> Vector2i:
	for cell: Vector2i in cells:
		if Vector2(cell).distance_to(Vector2(centre)) >= CLOSE_MIN_DISTANCE:
			return cell
	return Vector2i(-1, -1)


func _hide_people(game: FieldGame) -> void:
	if game.player != null:
		game.player.visible = false
	for person: Variant in game.squad:
		if person is Node3D:
			(person as Node3D).visible = false


## The frame cut round `cell` (CROP_HALF each way, kept inside the frame) and
## enlarged CROP_SCALE times, saved as PNG; its file name, "" on failure.
func _save_crop(game: FieldGame, image: Image, cell: Vector2i, filename: String) -> String:
	var screen_size: Vector2 = game.camera.get_viewport().get_visible_rect().size
	var scale: Vector2 = Vector2(image.get_size()) / screen_size
	var at: Vector2 = game.camera.unproject_position(FieldGrid.center(cell)) * scale
	var size: Vector2i = CROP_HALF * 2
	var corner := Vector2i(clampi(roundi(at.x) - CROP_HALF.x, 0, maxi(image.get_width() - size.x, 0)),
		clampi(roundi(at.y) - CROP_HALF.y, 0, maxi(image.get_height() - size.y, 0)))
	var cut: Image = image.get_region(Rect2i(corner, size))
	if cut == null or cut.is_empty():
		_fail("cannot cut " + filename)
		return ""
	cut.resize(size.x * CROP_SCALE, size.y * CROP_SCALE, Image.INTERPOLATE_NEAREST)
	var saved: Error = cut.save_png(_out.path_join(filename))
	if saved != OK:
		_fail("cannot save %s: %s" % [filename, error_string(saved)])
		return ""
	return filename


static func _ground_shape_hashes(game: FieldGame) -> Dictionary:
	var hashes: Dictionary = {}
	for level: Variant in game.view.ground_nodes:
		var node: MeshInstance3D = game.view.ground_nodes[level]
		var surfaces: Array[int] = []
		if node.mesh != null:
			for surface: int in node.mesh.get_surface_count():
				surfaces.append(node.mesh.surface_get_arrays(surface).hash())
		hashes[level] = surfaces
	return hashes


func _resume(game: FieldGame) -> void:
	if game.resume_pending:
		game.resume_pending = false
		game.hud.close_resume()


func _aim(game: FieldGame, cell: Vector2i, zoom: float) -> void:
	_resume(game)
	game.player.position = FieldGrid.center(cell)
	var level: int = game.level_of(game.player.position)
	game.view.show_levels(level)
	game.view.cut_away(game.grid_at(game.player.position).building_at(cell), level)
	game.cam_size = zoom
	game.camera.size = zoom
	game._update_camera(1.0)
	# The play camera widens to CAM_THREAT_SIZE (22) while a dead one is near, hidden
	# or not (field_game.camera_zoom_target), and would refuse the 18 of the one-cell
	# shots: place it at the asked size as the first frame of a stop is placed.
	game.start_camera_at(zoom)
	game.camera.force_update_transform()
	game.view.refresh_props(game.camera)
	if not is_equal_approx(game.camera.size, zoom):
		_fail("camera rejected zoom " + str(zoom))


func _alive() -> bool:
	if _failed:
		return false
	if _game == null or not is_instance_valid(_game):
		_fail("field disappeared")
		return false
	if float(Time.get_ticks_msec() - _scene_started) / 1000.0 > SCENE_TIMEOUT:
		_fail("scene timeout")
		return false
	_resume(_game)
	return true


func _scene_timeout(serial: int) -> void:
	if serial == _scene_serial and _game != null:
		_fail("scene timeout")


func _freeze_particles(node: Node) -> void:
	if node is GPUParticles3D:
		(node as GPUParticles3D).speed_scale = 0.0
	elif node is CPUParticles3D:
		(node as CPUParticles3D).speed_scale = 0.0
	for child: Node in node.get_children():
		_freeze_particles(child)


## Stable cells on the requested floor, within the actual camera. Single items
## use distinct cells; the 300-item case uses exactly three on each of 100.
func _cells(game: FieldGame, grid: FieldGrid, centre: Vector2i, spot: String, count: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var building: int = grid.building_at(centre)
	var screen: Rect2 = game.camera.get_viewport().get_visible_rect().grow(-28.0)
	for y: int in range(maxi(0, centre.y - 14), mini(grid.height, centre.y + 15)):
		for x: int in range(maxi(0, centre.x - 14), mini(grid.width, centre.x + 15)):
			var cell := Vector2i(x, y)
			if grid.solid_at(cell) != FieldGrid.Solid.NONE or grid.doors.has(cell):
				continue
			if spot == "inside":
				if grid.building_at(cell) != building:
					continue
			elif grid.building_at(cell) >= 0:
				continue
			if spot == "road" and grid.floor_at(cell) != FieldGrid.Floor.ROAD:
				continue
			if spot == "yard" and grid.floor_at(cell) != grid.floor_at(centre):
				continue
			var world_at: Vector3 = FieldGrid.center(cell)
			if game.camera.is_position_behind(world_at) or not screen.has_point(game.camera.unproject_position(world_at)):
				continue
			candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = (a - centre).length_squared()
		var db: int = (b - centre).length_squared()
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	var result: Array[Vector2i] = []
	# Prefer a free neighbouring cell between singles wherever space permits.
	for separation: float in [2.0, 1.0]:
		for cell: Vector2i in candidates:
			if result.size() >= count:
				return result
			var clear: bool = true
			for chosen: Vector2i in result:
				if Vector2(cell).distance_to(Vector2(chosen)) < separation:
					clear = false
					break
			if clear:
				result.append(cell)
	return result


func _put(game: FieldGame, rows: Array) -> float:
	game.ground_items.clear()
	game.ground_items.append_array(rows)
	var started: int = Time.get_ticks_usec()
	game.view.update_ground(game.ground_items)
	return float(Time.get_ticks_usec() - started) / 1000.0


## Read only common mesh APIs; retain both vertex streams and their transforms.
func _ground_geometry(game: FieldGame) -> Dictionary:
	var result: Dictionary = {}
	for level: Variant in game.view.ground_nodes:
		var node: MeshInstance3D = game.view.ground_nodes[level]
		var rim := node.get_node_or_null("Rim") as MeshInstance3D
		if rim == null:
			_fail("missing Rim mesh at level " + str(level))
			return {}
		result[level] = {"body": _vertices(node.mesh), "rim": _vertices(rim.mesh),
			"body_transform": node.global_transform, "rim_transform": rim.global_transform}
	return result


## Flatten surfaces in their original order, without interpreting model data.
static func _vertices(mesh: Mesh) -> PackedVector3Array:
	var result := PackedVector3Array()
	if mesh != null:
		for surface: int in mesh.get_surface_count():
			result.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	return result


## Return the two stream sizes, including an absent or empty floor.
static func _vertex_count(geometry: Dictionary, level: Variant) -> Vector2i:
	if not geometry.has(level):
		return Vector2i.ZERO
	return Vector2i((geometry[level]["body"] as PackedVector3Array).size(),
		(geometry[level]["rim"] as PackedVector3Array).size())


## Prefixes determine counts only; every projected position comes from the final rebuild.
func _item_polygons(game: FieldGame, rows: Array[Dictionary], image_size: Vector2i) -> Dictionary:
	var prefix: Array[Dictionary] = []
	var previous: Dictionary = {}
	var counts: Array[Dictionary] = []
	_put(game, [])
	for row: Dictionary in rows:
		if not _alive():
			return {}
		prefix.append(row)
		_put(game, prefix)
		var geometry: Dictionary = _ground_geometry(game)
		if _failed:
			return {}
		var levels: Dictionary = previous.duplicate()
		for level: Variant in geometry:
			levels[level] = true
		var added: Dictionary = {}
		for level: Variant in levels:
			var before: Vector2i = previous.get(level, Vector2i.ZERO)
			var after: Vector2i = _vertex_count(geometry, level)
			var delta: Vector2i = after - before
			if delta.x < 0 or delta.y < 0:
				_fail("prefix vertex count decreased at level %s, row %s: %s -> %s (body, rim)" %
					[level, row["id"], before, after])
				return {}
			added[level] = delta
			previous[level] = after
		counts.append(added)
	_put(game, [])
	var update_ms: float = _put(game, rows)
	var final_geometry: Dictionary = _ground_geometry(game)
	if _failed:
		return {}
	var final_levels: Dictionary = previous.duplicate()
	for level: Variant in final_geometry:
		final_levels[level] = true
	for level: Variant in final_levels:
		var expected: Vector2i = previous.get(level, Vector2i.ZERO)
		var actual: Vector2i = _vertex_count(final_geometry, level)
		if actual != expected:
			_fail("final vertex count mismatch at level %s: expected %s, got %s (body, rim)" %
				[level, expected, actual])
			return {}
	var offsets: Dictionary = {}
	var polygons: Array = []
	var count_report: Array = []
	for index: int in rows.size():
		var world_points: Array[Vector3] = []
		var row_counts: Dictionary = {}
		for level: Variant in counts[index]:
			var count: Vector2i = counts[index][level]
			var offset: Vector2i = offsets.get(level, Vector2i.ZERO)
			row_counts[str(level)] = {"vertices": count.x, "rim_vertices": count.y}
			if count != Vector2i.ZERO:
				var streams: Dictionary = final_geometry[level]
				var body: PackedVector3Array = streams["body"]
				var rim: PackedVector3Array = streams["rim"]
				var body_transform: Transform3D = streams["body_transform"]
				var rim_transform: Transform3D = streams["rim_transform"]
				for at: int in range(offset.x, offset.x + count.x):
					world_points.append(body_transform * body[at])
				for at: int in range(offset.y, offset.y + count.y):
					world_points.append(rim_transform * rim[at])
			offsets[level] = offset + count
		count_report.append({"slot": index, "levels": row_counts, "drawn": not world_points.is_empty()})
		if world_points.is_empty():
			polygons.append(PackedVector2Array())
			continue
		var polygon: PackedVector2Array = _project_polygon(game, world_points, image_size, 1.0,
			"item " + str(index) + ": " + String(rows[index]["id"]))
		if _failed:
			return {}
		polygons.append(polygon)
	return {"polygons": polygons, "counts": count_report, "update_ms": update_ms}


## Project a world hull in raw image pixels and reject empty or clipped geometry.
func _project_polygon(game: FieldGame, points: Array[Vector3], image_size: Vector2i, padding: float, label: String) -> PackedVector2Array:
	var screen_size: Vector2 = game.camera.get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		_fail(label + ": empty viewport")
		return PackedVector2Array()
	var scale: Vector2 = Vector2(image_size) / screen_size
	var projected: Array[Vector2] = []
	for point: Vector3 in points:
		if not point.is_finite() or game.camera.is_position_behind(point):
			_fail(label + ": invalid or behind-camera vertex")
			return PackedVector2Array()
		projected.append(game.camera.unproject_position(point) * scale)
	var polygon: PackedVector2Array = expand_hull(convex_hull(projected), padding)
	if polygon.is_empty():
		_fail(label + ": empty projected polygon")
		return polygon
	for point: Vector2 in polygon:
		if not point.is_finite() or point.x < 0.0 or point.y < 0.0 or point.x > image_size.x or point.y > image_size.y:
			_fail(label + ": screen polygon was clipped")
			return PackedVector2Array()
	return polygon


## Compute a counterclockwise hull; duplicate, collinear or invalid input is safe.
static func convex_hull(points: Array[Vector2]) -> PackedVector2Array:
	var sorted: Array[Vector2] = points.duplicate()
	for point: Vector2 in sorted:
		if not point.is_finite():
			return PackedVector2Array()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y)
	var unique: Array[Vector2] = []
	for point: Vector2 in sorted:
		if unique.is_empty() or point != unique.back():
			unique.append(point)
	if unique.size() < 3:
		return PackedVector2Array()
	var lower: Array[Vector2] = []
	for point: Vector2 in unique:
		while lower.size() >= 2 and (lower[-1] - lower[-2]).cross(point - lower[-1]) <= 0.0:
			lower.pop_back()
		lower.append(point)
	var upper: Array[Vector2] = []
	for index: int in range(unique.size() - 1, -1, -1):
		var point: Vector2 = unique[index]
		while upper.size() >= 2 and (upper[-1] - upper[-2]).cross(point - upper[-1]) <= 0.0:
			upper.pop_back()
		upper.append(point)
	lower.pop_back()
	upper.pop_back()
	lower.append_array(upper)
	return PackedVector2Array(lower) if lower.size() >= 3 else PackedVector2Array()


## Offset a counterclockwise convex hull by intersecting adjacent offset edges.
static func expand_hull(hull: PackedVector2Array, padding: float = 1.0) -> PackedVector2Array:
	if hull.size() < 3 or not is_finite(padding) or padding < 0.0:
		return PackedVector2Array()
	var result := PackedVector2Array()
	for index: int in hull.size():
		var before: Vector2 = (hull[index] - hull[(index + hull.size() - 1) % hull.size()]).normalized()
		var after: Vector2 = (hull[(index + 1) % hull.size()] - hull[index]).normalized()
		var normal_before := Vector2(before.y, -before.x)
		var normal_after := Vector2(after.y, -after.x)
		var denominator: float = 1.0 + normal_before.dot(normal_after)
		if denominator <= 0.000001:
			return PackedVector2Array()
		result.append(hull[index] + (normal_before + normal_after) * padding / denominator)
	return result


## Return the continuous polygon area in square pixels.
static func polygon_area(polygon: PackedVector2Array) -> float:
	var twice: float = 0.0
	for index: int in polygon.size():
		twice += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return absf(twice) * 0.5


## Return integer scan bounds; empty polygons have empty bounds.
static func polygon_bounds(polygon: PackedVector2Array) -> Rect2i:
	if polygon.is_empty():
		return Rect2i()
	var lo: Vector2 = polygon[0]
	var hi: Vector2 = lo
	for point: Vector2 in polygon:
		lo = lo.min(point)
		hi = hi.max(point)
	var corner := Vector2i(floori(lo.x), floori(lo.y))
	return Rect2i(corner, Vector2i(ceili(hi.x), ceili(hi.y)) - corner)


## Enumerate pixel centres inside a polygon, within the supplied image.
static func polygon_pixels(polygon: PackedVector2Array, image_size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if polygon.size() < 3 or polygon_area(polygon) <= 0.0:
		return result
	var rect: Rect2i = polygon_bounds(polygon).intersection(Rect2i(Vector2i.ZERO, image_size))
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), polygon):
				result.append(Vector2i(x, y))
	return result


## Exclude multiply owned pixels from every row, recording each row's loss.
static func exclusive_pixels(polygons: Array, image_size: Vector2i) -> Array[Dictionary]:
	var masks: Array = []
	var owners: Dictionary = {}
	for polygon: PackedVector2Array in polygons:
		var pixels: Array[Vector2i] = polygon_pixels(polygon, image_size)
		masks.append(pixels)
		for pixel: Vector2i in pixels:
			owners[pixel] = int(owners.get(pixel, 0)) + 1
	var result: Array[Dictionary] = []
	for mask: Array in masks:
		var pixels: Array[Vector2i] = []
		var shared: int = 0
		for pixel: Vector2i in mask:
			if int(owners[pixel]) == 1:
				pixels.append(pixel)
			else:
				shared += 1
		result.append({"pixels": pixels, "shared_pixels": shared, "polygon_pixels": mask.size()})
	return result


## Decide probe visibility from depth-tested and unrestricted changed counts.
static func probe_visibility(depth_pixels: int, unrestricted_pixels: int) -> Dictionary:
	var valid: bool = depth_pixels >= 0 and unrestricted_pixels > 0
	var ratio: float = float(depth_pixels) / float(unrestricted_pixels) if valid else 0.0
	return {"visible": valid and ratio >= PROBE_VISIBLE, "ratio": ratio,
		"depth_pixels": depth_pixels, "unrestricted_pixels": unrestricted_pixels,
		"reason": "no_reference_pixels" if unrestricted_pixels <= 0 else ("invalid_count" if depth_pixels < 0 else "")}


## Flag low visibility without guessing occlusion or dropping a drawn row.
static func visibility(changed_pixels: int, area_px: float, shared_pixels: int, drawn: bool = true) -> Dictionary:
	var low: bool = drawn and changed_pixels < MIN_VISIBLE_PIXELS
	return {"low_visibility": low, "low_visibility_reason":
		{"changed_pixels": changed_pixels, "polygon_area_px": area_px, "shared_pixels": shared_pixels} if low else {}}


## Test plates in disjoint screen batches, with two raw captures per batch.
func _probe_cells(game: FieldGame, cells: Array[Vector2i], side: float, floor_image: Image) -> Dictionary:
	var plates: Array[MeshInstance3D] = []
	var polygons: Array = []
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_fog = true
	material.albedo_color = Color(1.0, 0.0, 1.0, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var half: float = side * 0.5
	for cell: Vector2i in cells:
		var level: int = game.level_of(FieldGrid.center(cell))
		if not game.view.level_roots.has(level):
			_fail("probe has no level root: " + str(level))
			break
		var plate := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(side, side)
		plate.mesh = mesh
		plate.material_override = material
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plate.visible = false
		game.view.level_roots[level].add_child(plate)
		plate.position = FieldGrid.center(cell) + Vector3(0.0, 0.01, 0.0)
		plates.append(plate)
		var points: Array[Vector3] = []
		for corner: Vector3 in [Vector3(-half, 0.0, -half), Vector3(half, 0.0, -half),
				Vector3(half, 0.0, half), Vector3(-half, 0.0, half)]:
			points.append(plate.global_transform * corner)
		polygons.append(_project_polygon(game, points, floor_image.get_size(), 0.0, "probe " + str(cell)))
		if _failed:
			break
	var pending: Array[int] = []
	for index: int in plates.size():
		pending.append(index)
	var results: Dictionary = {}
	while not pending.is_empty() and not _failed:
		var batch: Array[int] = []
		for index: int in pending:
			var disjoint: bool = true
			for chosen: int in batch:
				if polygon_bounds(polygons[index]).intersects(polygon_bounds(polygons[chosen])):
					disjoint = false
					break
			if disjoint:
				batch.append(index)
		for index: int in batch:
			plates[index].visible = true
		material.no_depth_test = false
		var depth_image: Image = await _capture("")
		if depth_image == null:
			break
		_probe_captures += 1
		material.no_depth_test = true
		var unrestricted_image: Image = await _capture("")
		if unrestricted_image == null:
			break
		_probe_captures += 1
		if depth_image.get_size() != floor_image.get_size() or unrestricted_image.get_size() != floor_image.get_size():
			_fail("probe viewport size changed")
			break
		for index: int in batch:
			var pixels: Array[Vector2i] = polygon_pixels(polygons[index], floor_image.get_size())
			var tested: Dictionary = contrast_pixels(floor_image, depth_image, pixels)
			var unrestricted: Dictionary = contrast_pixels(floor_image, unrestricted_image, pixels)
			var measured: Dictionary = probe_visibility(int(tested["changed_pixels"]), int(unrestricted["changed_pixels"]))
			measured["cell"] = [cells[index].x, cells[index].y]
			measured["side_m"] = side
			measured["polygon_area_px"] = polygon_area(polygons[index])
			results[index] = measured
			plates[index].visible = false
			pending.erase(index)
	# Immediate removal also covers readback, timeout and projection failures.
	for plate: MeshInstance3D in plates:
		plate.free()
	if _failed:
		return {}
	var accepted: Array[Vector2i] = []
	var report_rows: Array = []
	var reference_pixels: int = 0
	for index: int in cells.size():
		var measured: Dictionary = results[index]
		report_rows.append(measured)
		reference_pixels += int(measured["unrestricted_pixels"])
		if bool(measured["visible"]):
			accepted.append(cells[index])
	if cells.is_empty() or reference_pixels == 0:
		_fail("no visible reference probe pixels for %.1f m plates (%d candidates)" % [side, cells.size()])
	elif accepted.is_empty():
		_fail("all %.1f m candidate plates are occluded (%d candidates)" % [side, cells.size()])
	return {"cells": accepted, "rows": report_rows}


func _capture(filename: String) -> Image:
	if not _alive():
		return null
	for _frame: int in range(3):
		_resume(_game)
		await process_frame
		await RenderingServer.frame_post_draw
		if not _alive():
			return null
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("viewport readback failed: " + filename)
		return null
	# Raw probe readbacks never create files or count toward EXPECTED_SHOTS.
	if filename.is_empty():
		return image
	var path: String = _out.path_join(filename)
	var saved: Error = image.save_jpg(path, 0.95)
	if saved != OK:
		_fail("cannot save %s: %s" % [filename, error_string(saved)])
		return null
	var check := Image.new()
	var loaded: Error = check.load(path)
	if loaded != OK or check.get_size() != image.get_size():
		_fail("cannot read saved JPG: " + filename)
		return null
	if not _shots.has(filename):
		_shots.append(filename)
	return image


static func luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


## Retain the rectangle API for callers; captures use hull masks.
static func contrast(floor_image: Image, item_image: Image, rect: Rect2i) -> Dictionary:
	var pixels: Array[Vector2i] = []
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			pixels.append(Vector2i(x, y))
	var result: Dictionary = contrast_pixels(floor_image, item_image, pixels)
	result["box"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	return result


## Measure only supplied pixels, retaining zero-change rows as zero contrast.
static func contrast_pixels(floor_image: Image, item_image: Image, pixels: Array[Vector2i]) -> Dictionary:
	var changed: int = 0
	var difference: float = 0.0
	var signed_difference: float = 0.0
	var object_luma: float = 0.0
	var floor_luma: float = 0.0
	for pixel: Vector2i in pixels:
		var a: Color = floor_image.get_pixelv(pixel)
		var b: Color = item_image.get_pixelv(pixel)
		if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) <= CHANGE:
			continue
		var delta: float = luma(b) - luma(a)
		difference += absf(delta)
		signed_difference += delta
		object_luma += luma(b)
		floor_luma += luma(a)
		changed += 1
	var divisor: float = float(maxi(changed, 1))
	return {"changed_pixels": changed,
		"mean_abs_luma": difference / divisor, "mean_signed_luma": signed_difference / divisor,
		"object_luma": object_luma / divisor, "floor_luma": floor_luma / divisor,
		"status": "measured" if changed > 0 else "no_changed_pixels"}


## Rank every drawn row and list low-visibility rows without excluding them.
static func summarize(rows: Array) -> Dictionary:
	var sorted: Array = []
	var low_names: Array[String] = []
	var low_rows: Array = []
	var not_drawn: Array = []
	for row: Dictionary in rows:
		if not bool(row.get("drawn", true)):
			not_drawn.append({"id": row["id"], "slot": row.get("slot", -1)})
			continue
		sorted.append(row)
		if bool(row.get("low_visibility", int(row.get("changed_pixels", MIN_VISIBLE_PIXELS)) < MIN_VISIBLE_PIXELS)):
			low_names.append(String(row["id"]))
			low_rows.append({"id": row["id"], "slot": row.get("slot", -1), "group": row.get("group", "")})
	if sorted.is_empty():
		return {}
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["mean_abs_luma"]) < float(b["mean_abs_luma"]))
	var darkest: Dictionary = sorted[0]
	for row: Dictionary in sorted:
		if float(row["object_luma"]) < float(darkest["object_luma"]):
			darkest = row
	var middle: int = sorted.size() >> 1
	var median: float = float(sorted[middle]["mean_abs_luma"])
	if sorted.size() % 2 == 0:
		median = (median + float(sorted[middle - 1]["mean_abs_luma"])) * 0.5
	return {"weakest": sorted[0], "median": median, "middle_items": [sorted[maxi(0, middle - 1)]["id"], sorted[middle]["id"]], "darkest": darkest,
		"low_visibility_count": low_names.size(), "low_visibility_names": low_names,
		"low_visibility_rows": low_rows, "not_drawn": not_drawn, "drawn_count": sorted.size()}


static func _overlaps(boxes: Array[Rect2i]) -> Array:
	var overlaps: Array = []
	for first: int in boxes.size():
		for second: int in range(first + 1, boxes.size()):
			if boxes[first].intersects(boxes[second]):
				overlaps.append([first, second])
	return overlaps


func _metrics(game: FieldGame, update_ms: float) -> Dictionary:
	var floors: Dictionary = {}
	for level: Variant in game.view.ground_nodes:
		var node: MeshInstance3D = game.view.ground_nodes[level]
		floors[str(level)] = {"items": _mesh_counts(node.mesh), "rim": _mesh_counts((node.get_node("Rim") as MeshInstance3D).mesh), "children": node.get_child_count()}
	return {
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"video_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
		"buffer_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),
		"update_ground_ms": update_ms, "timing": "one rebuild after clearing; template cache warm", "floors": floors,
	}


static func _mesh_counts(mesh: Mesh) -> Dictionary:
	var vertices: int = 0
	var triangles: int = 0
	var surfaces: int = 0
	if mesh != null:
		surfaces = mesh.get_surface_count()
		for surface: int in surfaces:
			var arrays: Array = mesh.surface_get_arrays(surface)
			var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			vertices += count
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			if indices is PackedInt32Array and not (indices as PackedInt32Array).is_empty():
				count = (indices as PackedInt32Array).size()
			triangles += floori(float(count) / 3.0)
	return {"vertices": vertices, "triangles": triangles, "surfaces": surfaces}


func _worst(game: FieldGame, grid: FieldGrid, centre: Vector2i) -> void:
	var cells: Array[Vector2i] = _cells(game, grid, centre, "yard", 100)
	if cells.size() != 100:
		_fail("worst scene: fewer than 100 visible yard cells for 300 things")
		return
	var rows: Array[Dictionary] = []
	for index: int in range(300):
		rows.append({"id": THINGS[index % THINGS.size()], "n": 1, "pos": FieldGrid.center(cells[floori(float(index) / 3.0)])})
	_put(game, [])
	var update_ms: float = _put(game, rows)
	var image: Image = await _capture("yard_autumn_day_worst300.jpg")
	if image == null:
		return
	var drawn_rows: int = _drawn_rows(game)
	_report["worst"] = {"items": 300, "cells": 100, "per_cell": 3, "zoom": ZOOM, "hour": 12.0, "cold": 0.0,
		"drawn": drawn_rows, "omitted": 300 - drawn_rows, "metrics": _metrics(game, update_ms)}


func _write_reports() -> bool:
	var json_text: String = JSON.stringify(_report, "\t") + "\n"
	var markdown: PackedStringArray = [
		"# 땅 물건 촬영·측정", "", "첫 정차 · K1 · seed 5 · 가림 끔 · 줌 24. 낮 12:00은 규칙 맑음/그림 흐림, 밤 22:00은 맑음.",
		"대비는 저장 전 원본 화면의 sRGB Rec.709 루마(0~1)로 잰다. 채널 차가 2/255를 넘는 화소만 포함한다.",
		"최종 물건·테 정점의 볼록 껍질을 1px 넓혀 재며, 겹친 화소는 모든 줄에서 제외한다. 면적·공유 화소·선택한 칸·시험판 비율은 JSON에 적는다.",
		"바뀐 화소가 40 미만이어도 그려진 줄은 요약에 포함한다. 낮은 보임은 가림 확정이 아니다. 기존 moved_from_hidden_cells·still_hidden은 빈 배열로 유지한다.",
		"가장 어두운 물건은 해당 화소의 물건 루마 평균이 가장 낮은 것. 요약에는 단독 물건과 셋의 각 구성원을 모두 포함한다.", "",
		"| 장면 | 가장 약한 물건 / 대비 | 가운데 대비 | 가장 어두운 물건 / 대비 | 그리기 호출 | 기본 도형 | 비디오 / 버퍼(bytes) | 재구성(ms) | 낮은 보임 수 / 이름 |",
		"|---|---|---:|---|---:|---:|---:|---:|---|",
	]
	for scene: Dictionary in _report["scenes"]:
		var summary: Dictionary = scene["summary"]
		var metrics: Dictionary = scene["metrics"]
		markdown.append("| %s | %s / %.6f | %.6f | %s / %.6f | %d | %d | %d / %d | %.3f | %d / %s |" % [
			scene["name"], summary["weakest"]["id"], summary["weakest"]["mean_abs_luma"], summary["median"],
			summary["darkest"]["id"], summary["darkest"]["mean_abs_luma"], metrics["draw_calls"], metrics["primitives"],
			metrics["video_bytes"], metrics["buffer_bytes"], metrics["update_ground_ms"],
			summary["low_visibility_count"], ", ".join(summary["low_visibility_names"])])
		var triple: Dictionary = scene["triple_summary"]
		if triple.is_empty():
			markdown.append("| %s 셋 | 안 그려짐 | — | — | — | — | — | — | 0 / — |" % scene["name"])
		else:
			markdown.append("| %s 셋 | %s / %.6f | %.6f | %s / %.6f | — | — | — | — | %d / %s |" % [
				scene["name"], triple["weakest"]["id"], triple["weakest"]["mean_abs_luma"], triple["median"],
				triple["darkest"]["id"], triple["darkest"]["mean_abs_luma"], triple["low_visibility_count"],
				", ".join(triple["low_visibility_names"])])
	markdown.append_array(["", "| 장면 / 층 | 물건 정점 | 물건 삼각형 | 물건 표면 | 테 정점 | 테 삼각형 |", "|---|---:|---:|---:|---:|---:|"])
	var all_metrics: Array = (_report["scenes"] as Array).duplicate()
	all_metrics.append({"name": "worst300", "metrics": _report["worst"]["metrics"]})
	for scene: Dictionary in all_metrics:
		for level: String in scene["metrics"]["floors"]:
			var floor_row: Dictionary = scene["metrics"]["floors"][level]
			markdown.append("| %s / %s | %d | %d | %d | %d | %d |" % [scene["name"], level,
				floor_row["items"]["vertices"], floor_row["items"]["triangles"], floor_row["items"]["surfaces"], floor_row["rim"]["vertices"], floor_row["rim"]["triangles"]])
	var worst: Dictionary = _report["worst"]["metrics"]
	markdown.append("\n300개(100칸, 칸마다 셋): 그려짐 %d · 안 그려짐 %d, 호출 %d, 기본 도형 %d, 비디오 %d bytes, 버퍼 %d bytes, 재구성 %.3f ms." % [_report["worst"]["drawn"], _report["worst"]["omitted"], worst["draw_calls"], worst["primitives"], worst["video_bytes"], worst["buffer_bytes"], worst["update_ground_ms"]])
	for closeup: Dictionary in _report["closeups"]:
		if closeup.get("kind", "") == "clothes_cell":
			markdown.append("\nclothes_cell %s: 넷 중 그릴 수 있는 셋에서 그려짐 %d · 안 그려짐 %d." % [closeup["name"], closeup["drawn"], closeup["omitted"]])
	markdown.append("\n재구성 시간은 빈 목록 뒤 전체 목록으로 한 번 다시 만든 값이며 템플릿 캐시는 데워진 상태다. 한 칸 셋의 낮·밤 사진은 줌 18이다.")
	markdown.append("\nclothes_cell 낮·밤 사진(줌 18)은 한 칸에 coat_long·shirt_flannel·trousers_work·boots_work 넷을 넣는다. 첫 셋과 넷을 넣은 뒤의 메시를 대조해 넷째가 그림을 더하지 않는지 확인한다.")
	if not _write_text("ground_shots.json", json_text) or not _write_text("ground_shots.md", "\n".join(markdown) + "\n"):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_out.path_join("ground_shots.json")))
	if not parsed is Dictionary or (parsed as Dictionary).get("scenes", []).size() != 10:
		_fail("JSON readback failed")
		return false
	return true


func _write_text(filename: String, content: String) -> bool:
	var path: String = _out.path_join(filename)
	var temporary: String = path + ".%d.tmp" % OS.get_process_id()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		_fail("cannot write " + filename + ": " + error_string(FileAccess.get_open_error()))
		return false
	file.store_string(content)
	file.flush()
	var wrote: Error = file.get_error()
	file.close()
	if wrote != OK:
		_fail("write failed " + filename + ": " + error_string(wrote))
		return false
	var renamed: Error = DirAccess.rename_absolute(temporary, path)
	if renamed != OK or FileAccess.get_file_as_string(path) != content:
		_fail("report rename/readback failed " + filename)
		return false
	return true


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	printerr("GROUND_SHOTS_FAIL " + message)
	quit(1)
