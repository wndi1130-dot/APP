extends SceneTree
## Map look loop: from one map, the same spots by the same rules every run, at the play zoom,
## with counts, so a change to the map can be looked at and measured before and after it.
## Needs a real renderer, so run it without --headless:
##   godot --path s2 --resolution 1688x780 -s res://tools/map_shots.gd -- --out=<folder> [--zoom=24] [--seed=5]
##       [--mask] [--dead] [--hud] [--front [--front-zoom=20]] <place>
## By default as the first loop shots were taken: no sight mask, no dead drawn, no HUD. The play screen
## has all three; turn them on to see it as a player does (the files get _mask, _dead, _hud on the name):
##   --mask   the sight mask, the squad leader looking up the screen (or at the door, at the dead); each
##            spot as on first coming there (what earlier spots saw is forgotten)
##   --dead   the dead drawn, and one more spot, dead: four cells short of the outdoor dead nearest
##            where the squad steps off, looking at it. Without it no dead are shown.
##   --hud    the field HUD
##   --front  one more spot per kind of building (front_shop, front_home, front_store): the leader 12-14
##            cells straight out from an outer door on a south or east wall (the walls the camera sees)
##            of the first such building, looking at the door, at --front-zoom; see front_spots. The
##            field lifts the roof of every building within 10 cells of the camera's focus
##            (building_view.gd NEAR_R), so a building shows its outside only that far off the middle
##            of the screen, as here; pushing the camera onto the door would open it. The metrics get
##            "fronts" (the building, its door, how many of its outer doors are on seen walls).
## A map name with no map, a zoom not above 0, a shot or the metrics not written: MAP_SHOTS_FAIL, exit 1.
## Every run counts, over all buildings, those with an outer door and those with one on a seen wall
## (map.outer_doors): a door on a north or west wall never shows from outside.
##
## Spots are picked from the map's data, never by hand (so nobody shoots only the good corners):
##   start        the squad's first cell off the train
##   road         a road cell over 15 cells from the train, the one with the most road in the 9x9 round it
##   yard         bare ground 2-3 cells out from a small building, the one with the median count of
##                things within 6 cells (an ordinary yard)
##   inside       the ground-floor building with the most boxes, at the walkable cell of it nearest its
##                rect's middle (its walls cut away)
##   edge         4 cells in from the middle of the inner side farthest from the train
##   items        outside, the thing with the most other things within 6 cells (the busiest ground)
##   room_<class> the biggest ground-floor room of each furnished class (bed, kitchen, living, bath, ...)
## At every spot the floors and the cut-away walls are chosen as the field chooses them each step
## (field_game.gd _update_zone), and the resume wait is let go, else the camera stands still.
##
## Writes <place>_<spot>.jpg and <place>_metrics.json, and prints a SHOT line per spot and a MAP line.
## Counts per spot, in the 36x36 cells round it (about one phone screen at zoom 24):
##   outdoor_m2   cells outside buildings; things: props outside buildings that are not trees;
##   made         those that are not plants, stones or drifts (what people left); trees: tree props;
##   indoor       props inside buildings. A room spot also counts the props in that room and their kinds.
## Per map (ground floor, see map_counts): rooms by class, homes and homes with a bath, the furniture tints of the homes,
## tree props by kind.
const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FxState = preload("res://fx/fx_state.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const BuildingUses = preload("res://game/world/building_uses.gd")
const BuildingView = preload("res://game/world/building_view.gd")
const EdgeBand = preload("res://game/world/edge_band.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const USAGE: String = "usage: -- --out=<folder> [--zoom=24] [--seed=5] [--mask] [--dead] [--hud] [--front [--front-zoom=20]] <place>"
const FRONT_USES: Array[String] = ["shop", "home", "store"]
const OUTDOOR_SPOTS: Array[String] = ["start", "road", "yard", "inside", "edge", "items"]
const TREE_KINDS: Array[String] = ["bare_tree", "thicket", "fir", "pine", "spruce", "birch", "stump", "street_tree", "bare_willow"]
## Grown or fallen, not made: a screen full of these still reads as an empty field.
const NATURE_KINDS: Array[String] = ["bush_juniper", "bush_dry", "dry_bush", "dry_grass", "fern_dry", "stump_cluster", "boulder", "snow_drift", "rock_outcrop", "frozen_reeds"]
## Picking leaves out the trees the first loop shots left out, so the spots stay where they were.
const PICK_SKIP: Array[String] = ["bare_tree", "thicket", "fir", "pine", "spruce", "birch", "stump"]
const BOX: int = 36
const PICK_RADIUS: int = 6


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = parse_args(OS.get_cmdline_user_args())
	if args.has("error"):
		_fail(String(args["error"]))
		return
	var out_dir: String = args["out"]
	var zoom: float = args["zoom"]
	var front_zoom: float = args["front_zoom"]
	var run_seed: int = args["seed"]
	var place: String = args["place"]
	var mask: bool = args["mask"]
	var dead: bool = args["dead"]
	var hud: bool = args["hud"]
	var front: bool = args["front"]
	# The field plays the default stop for a name with no map (FieldMaps.resolve): never shoot that
	# under the name asked for.
	if not FieldMaps.has(place):
		_fail("no map: " + place)
		return
	var suffix: String = ("_mask" if mask else "") + ("_dead" if dead else "") + ("_hud" if hud else "")
	var made: Error = DirAccess.make_dir_recursive_absolute(out_dir)
	if made != OK:
		_fail("cannot make %s: %s" % [out_dir, error_string(made)])
		return
	var game = FieldGame.new()
	game.opts = {"seed": run_seed, "raiders": false, "auto_pause": false, "arrive": false, "place": place,
		"weather": ["clear"], "look": ["overcast"], "look_hour": 12.0}
	root.add_child(game)
	game.clock.elapsed = (12.0 - 10.5) * 240.0
	game.set_process(true)
	game.paused = true
	game.hud.visible = false
	game.cam_push = Vector3.ZERO
	game.mask_on = false
	game.view.set_mask_enabled(false)
	for _i in range(4):
		await process_frame
	game.paused = false
	game.set_process(false)
	# Those four frames drew the dead in sight (field_game.gd _process); without --dead none are shown.
	if game.zombies != null:
		game.zombies.visible = dead
	game.fx_params["fx_fade"] = 0.0
	FxState.apply({"fx_fade": 0.0})
	game._update_light()
	var cloud := Vector4(game.fx_params.get("fx_cloud", Vector4.ZERO))
	FxState.apply({"fx_cloud": Vector4(cloud.x, 0.0, 0.0, cloud.w)})
	game.mask_on = mask
	game.view.set_mask_enabled(mask)
	game.hud.visible = hud
	var data: Dictionary = game.data
	var g: FieldGrid = data["grid"]
	var spots: Dictionary = pick_spots(data, g)
	var rooms: Dictionary = room_spots(data, g)
	var looks: Dictionary = {}  # spot -> the cell the leader looks at (else up the screen)
	var tags: Array[String] = []
	tags.append_array(OUTDOOR_SPOTS)
	var room_tags: Array = rooms.keys()
	room_tags.sort()
	for tag: String in room_tags:
		tags.append(tag)
		spots[tag] = rooms[tag]["cell"]
	if dead:
		var near_dead: Dictionary = dead_spot(game.zombies.list, data, g)
		if not near_dead.is_empty():
			tags.append("dead")
			spots["dead"] = near_dead["cell"]
			looks["dead"] = near_dead["look"]
	var fronts: Dictionary = {}
	if front:
		# Roofs lift round the camera's focus, which the field pulls in from the map's edge
		# (field_game.gd _update_camera): judge them from where the camera will stand, at --front-zoom.
		var screen: Vector2 = root.get_visible_rect().size
		var aspect: float = screen.x / maxf(screen.y, 1.0)
		var half: Vector2 = EdgeBand.view_half(front_zoom, aspect, FieldGame.CAM_PITCH, FieldGame.CAM_YAW)
		var focus_of: Callable = func(c: Vector2i) -> Vector2i:
			var at: Vector3 = FieldGrid.center(c)
			var f: Vector3 = EdgeBand.clamp_focus(at, half, g.width, g.height)
			f = EdgeBand.keep_on_screen(f, at, front_zoom, aspect, FieldGame.CAM_PITCH, FieldGame.CAM_YAW)
			return Vector2i(floori(f.x), floori(f.z))
		var footprints: Dictionary = {}
		if game.view.buildings != null:
			footprints = game.view.buildings.footprints
		fronts = front_spots(data, g, footprints, focus_of)
	var front_rows: Dictionary = {}
	if front:
		for use: String in FRONT_USES:
			var tag: String = "front_" + use
			tags.append(tag)
			front_rows[tag] = null
			if fronts.has(tag):
				spots[tag] = fronts[tag]["cell"]
				looks[tag] = fronts[tag]["look"]
				var chosen: Dictionary = fronts[tag]
				var door: Vector2i = chosen["look"]
				front_rows[tag] = {"building": chosen["building"], "door": [door.x, door.y],
					"doors": chosen["doors"], "doors_seen": chosen["doors_seen"], "near_roofs": chosen["near_roofs"]}
	var metrics: Dictionary = {"place": place, "seed": run_seed, "zoom": zoom, "front_zoom": front_zoom,
		"mask": mask, "dead": dead, "hud": hud, "size": [g.width, g.height], "spots": {}, "map": map_counts(data, g)}
	metrics["map"]["outer_doors"] = door_faces(data, g)
	if front:
		metrics["fronts"] = front_rows
	print("MAP %s %s" % [place, JSON.stringify(metrics["map"])])
	var first: bool = true
	for tag: String in tags:
		if not spots.has(tag):
			print("SHOT %s %s skipped (no spot)" % [place, tag])
			continue
		var cell: Vector2i = spots[tag]
		game.player.position = FieldGrid.center(cell)
		var lv: int = game.level_of(game.player.position)
		game.view.show_levels(lv)
		game.view.cut_away(game.grid_at(game.player.position).building_at(FieldGrid.cell_of(game.player.position)), lv)
		game.cam_size = front_zoom if tag.begins_with("front_") else zoom
		game.camera.size = game.cam_size
		game._update_camera(1.0)
		game.view.refresh_props(game.camera)
		await create_timer(2.6 if first else 1.6).timeout
		first = false
		if game.resume_pending:
			game.resume_pending = false
			game.hud.close_resume()
		game._update_camera(1.0)
		game.view.refresh_props(game.camera)
		if mask:
			# Up the screen (away from the camera), or at what the spot is for.
			var ahead: Vector3 = -game.camera.global_transform.basis.z
			if looks.has(tag):
				ahead = FieldGrid.center(looks[tag]) - game.player.position
			game.player.facing = atan2(ahead.x, ahead.z)
			game.mask_in = 1.0
			game.view.set_mask_shade(1.0)
			_forget_seen(game)
			game._refresh_vision()
		# The dead read one body in a frame (zombies.gd render): draw them over a few frames.
		for _i in range(8 if dead else 2):
			if dead:
				game.zombies.render(game.camera, game.seen_now, game.mask_on)
			await process_frame
		var shot_path: String = out_dir.path_join("%s_%s%s.jpg" % [place, tag, suffix])
		var saved: Error = save_shot(root.get_viewport().get_texture().get_image(), shot_path)
		if saved != OK:
			_fail("cannot save %s: %s" % [shot_path, error_string(saved)])
			return
		var row: Dictionary = spot_counts(data, g, cell)
		row["cell"] = [cell.x, cell.y]
		if rooms.has(tag):
			row.merge(rooms[tag]["counts"])
		metrics["spots"][tag] = row
		print("SHOT %s %s %s" % [place, tag, JSON.stringify(row)])
	var metrics_path: String = out_dir.path_join("%s%s_metrics.json" % [place, suffix])
	var wrote: Error = write_json(metrics_path, metrics)
	if wrote != OK:
		_fail("cannot write %s: %s" % [metrics_path, error_string(wrote)])
		return
	print("MAP_SHOTS_DONE %s spots=%d" % [place, (metrics["spots"] as Dictionary).size()])
	quit(0)


func _fail(message: String) -> void:
	printerr("MAP_SHOTS_FAIL " + message)
	quit(1)


## With the sight mask, each spot is shot as on first coming there: what earlier spots saw is
## forgotten (the field's seen cells, and the props the map view keeps drawn once seen).
func _forget_seen(game) -> void:
	game.seen_memory.fill(0)
	for batch: Dictionary in game.view.prop_batches.values():
		for item: Dictionary in batch["items"]:
			item["remembered"] = false


## The command line after "--" as {out, zoom, front_zoom, seed, place, mask, dead, hud, front}, or as
## {error} for an unknown or repeated argument, a zoom that is not a finite number above 0, a seed that
## is not a whole number, an empty --out, or no --out or place.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"out": "", "zoom": 24.0, "front_zoom": 20.0, "seed": 5, "place": "",
		"mask": false, "dead": false, "hud": false, "front": false}
	var given: Dictionary = {}
	for arg: String in args:
		var key: String = arg.get_slice("=", 0) if arg.begins_with("--") else "place"
		if given.has(key):
			return {"error": "repeated argument: " + arg}
		given[key] = true
		var value: String = arg.substr(key.length() + 1) if arg.begins_with("--") else arg
		match key:
			"--out":
				if value.is_empty():
					return {"error": "empty --out"}
				out["out"] = value
			"--zoom", "--front-zoom":
				var z: float = float(value) if value.is_valid_float() else NAN
				if not is_finite(z) or z <= 0.0:
					return {"error": "zoom must be a number above 0: " + arg}
				out["zoom" if key == "--zoom" else "front_zoom"] = z
			"--seed":
				if not value.is_valid_int():
					return {"error": "seed must be a whole number: " + arg}
				out["seed"] = value.to_int()
			"--mask", "--dead", "--hud", "--front":
				if arg != key:
					return {"error": "flag takes no value: " + arg}
				out[key.trim_prefix("--")] = true
			"place":
				out["place"] = value
			_:
				return {"error": "unknown argument: " + arg}
	if String(out["out"]).is_empty() or String(out["place"]).is_empty():
		return {"error": USAGE}
	return out


## The shot as a jpg at path; an empty image (no frame read back) is an error, not a blank file.
static func save_shot(img: Image, path: String) -> Error:
	if img == null or img.is_empty():
		return ERR_INVALID_DATA
	return img.save_jpg(path, 0.9)


## value as indented JSON at path, every write checked (a full disk or a folder in the way is an error).
static func write_json(path: String, value: Variant) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored: bool = file.store_string(JSON.stringify(value, "\t", true))
	var err: Error = file.get_error()
	file.close()
	if err == OK and not stored:
		err = ERR_FILE_CANT_WRITE
	return err


static func pick_spots(data: Dictionary, g: FieldGrid) -> Dictionary:
	var out: Dictionary = {}
	var squad: Array = data.get("spawns", {}).get("squad", [])
	if not squad.is_empty():
		out["start"] = squad[0]
	var train: Rect2i = data.get("train", Rect2i())
	var inner: Rect2i = data.get("map_ring", {}).get("inner", Rect2i(0, 0, g.width, g.height))
	var far_train: Callable = func(c: Vector2i) -> bool:
		return train.size == Vector2i.ZERO or not train.grow(15).has_point(c)
	var best_road: int = -1
	for y: int in range(inner.position.y + 4, inner.end.y - 4, 2):
		for x: int in range(inner.position.x + 4, inner.end.x - 4, 2):
			var c := Vector2i(x, y)
			if g.floor_at(c) != FieldGrid.Floor.ROAD or g.building_at(c) >= 0 or not far_train.call(c):
				continue
			var n: int = 0
			for dy: int in range(-4, 5):
				for dx: int in range(-4, 5):
					var d := c + Vector2i(dx, dy)
					if g.inside(d) and g.floor_at(d) == FieldGrid.Floor.ROAD:
						n += 1
			if n > best_road:
				best_road = n
				out["road"] = c
	var yards: Array = []
	var buildings: Array = data.get("buildings", [])
	for b: Dictionary in buildings:
		var r: Rect2i = b["rect"]
		if r.get_area() > 900:
			continue
		for c: Vector2i in [Vector2i(r.get_center().x, r.end.y + 2), Vector2i(r.end.x + 2, r.get_center().y), Vector2i(r.get_center().x, r.position.y - 3), Vector2i(r.position.x - 3, r.get_center().y)]:
			if not g.inside(c) or not inner.has_point(c) or g.building_at(c) >= 0 or g.floor_at(c) == FieldGrid.Floor.ROAD or not far_train.call(c):
				continue
			yards.append({"cell": c, "n": near_things(data, c, PICK_RADIUS)})
	if not yards.is_empty():
		yards.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
			return int(p["n"]) < int(q["n"]) if int(p["n"]) != int(q["n"]) else str(p["cell"]) < str(q["cell"]))
		out["yard"] = yards[yards.size() >> 1]["cell"]
	var count_by: Dictionary = {}
	for id: Variant in data.get("containers", {}):
		var box: Dictionary = data["containers"][id]
		if int(box.get("level", 0)) != 0:
			continue
		var bid: int = g.building_at(box["cell"])
		if bid >= 0:
			count_by[bid] = int(count_by.get(bid, 0)) + 1
	var best_box: int = -1
	for b: Dictionary in buildings:
		var n: int = int(count_by.get(int(b["id"]), 0))
		if n > best_box and (b["rect"] as Rect2i).get_area() <= 900:
			best_box = n
			out["inside"] = inside_cell(g, int(b["id"]), b["rect"])
	var mids: Array[Vector2i] = [Vector2i(inner.get_center().x, inner.position.y + 4), Vector2i(inner.end.x - 5, inner.get_center().y),
		Vector2i(inner.get_center().x, inner.end.y - 5), Vector2i(inner.position.x + 4, inner.get_center().y)]
	var far: float = -1.0
	for m: Vector2i in mids:
		var d: float = Vector2(m).distance_to(Vector2(train.get_center())) if train.size != Vector2i.ZERO else 0.0
		if d > far:
			far = d
			out["edge"] = m
	var best_items: int = -1
	for p: Dictionary in data.get("props", []):
		if not p.get("rect") is Rect2i or int(p.get("level", 0)) != 0:
			continue
		var c: Vector2i = (p["rect"] as Rect2i).get_center()
		if not g.inside(c) or g.building_at(c) >= 0 or not far_train.call(c) or not inner.has_point(c):
			continue
		var n: int = near_things(data, c, PICK_RADIUS)
		if n > best_items:
			best_items = n
			out["items"] = c
	return out


## The class of every ground-floor room as "0:room": the class most of the furniture the furnishing
## put in it was put there for (each piece keeps it as "rule", room_furnish.gd). Read off the pieces,
## not the furnishing's own table: the ring round a map (map_ring.gd) numbers the rooms anew and drops
## that table, and reading the classes again from a furnished map guesses some of them wrong.
static func room_classes(data: Dictionary, g: FieldGrid) -> Dictionary:
	var map: Dictionary = RoomFurnish._rooms(data, 0, g)
	var of: PackedInt32Array = map["of"]
	var votes: Dictionary = {}
	for p: Dictionary in data.get("props", []):
		if not p.has("rule") or int(p.get("level", 0)) != 0 or not p.get("rect") is Rect2i:
			continue
		var c: Vector2i = (p["rect"] as Rect2i).position
		if not g.inside(c):
			continue
		var ri: int = RoomFurnish._at(g, of, c)
		if ri < 0:
			continue
		var tally: Dictionary = votes.get_or_add(ri, {})
		var cls: String = String(p["rule"])
		tally[cls] = int(tally.get(cls, 0)) + 1
	var out: Dictionary = {}
	for ri: int in votes:
		var names: Array = (votes[ri] as Dictionary).keys()
		names.sort()
		var pick: String = ""
		for cls: String in names:
			if pick.is_empty() or int(votes[ri][cls]) > int(votes[ri][pick]):
				pick = cls
		if not pick.is_empty():
			out["0:%d" % ri] = pick
	return out


## The biggest ground-floor room of each furnished class, as "room_<class>" -> {cell, counts}.
static func room_spots(data: Dictionary, g: FieldGrid) -> Dictionary:
	var classes: Dictionary = room_classes(data, g)
	var map: Dictionary = RoomFurnish._rooms(data, 0, g)
	var best: Dictionary = {}
	for ri: int in range(map["rooms"].size()):
		var cls: String = String(classes.get("0:%d" % ri, ""))
		if cls.is_empty():
			continue
		var cells: Array[Vector2i] = map["rooms"][ri]["cells"]
		var tag: String = "room_" + cls
		if not best.has(tag) or cells.size() > int(best[tag]["area"]):
			best[tag] = {"area": cells.size(), "room": ri, "cells": cells}
	var out: Dictionary = {}
	for tag: String in best:
		var cells: Array[Vector2i] = best[tag]["cells"]
		out[tag] = {"cell": _middle(cells), "counts": room_counts(data, cells)}
	return out


## The room cell nearest the mean of its cells (a room can be an L, its mean outside it).
static func _middle(cells: Array[Vector2i]) -> Vector2i:
	var sum := Vector2.ZERO
	for c: Vector2i in cells:
		sum += Vector2(c)
	var mean: Vector2 = sum / float(cells.size())
	var pick: Vector2i = cells[0]
	for c: Vector2i in cells:
		if Vector2(c).distance_squared_to(mean) < Vector2(pick).distance_squared_to(mean):
			pick = c
	return pick


static func room_counts(data: Dictionary, cells: Array[Vector2i]) -> Dictionary:
	var inside: Dictionary = {}
	for c: Vector2i in cells:
		inside[c] = true
	var kinds: Dictionary = {}
	var n: int = 0
	for p: Dictionary in data.get("props", []):
		if not p.get("rect") is Rect2i or int(p.get("level", 0)) != 0:
			continue
		if inside.has((p["rect"] as Rect2i).position):
			n += 1
			var kind: String = String(p.get("kind", ""))
			kinds[kind] = int(kinds.get(kind, 0)) + 1
	return {"room_cells": cells.size(), "room_things": n, "room_kinds": kinds.size(), "room_kind_list": kinds}


static func spot_counts(data: Dictionary, g: FieldGrid, c: Vector2i) -> Dictionary:
	var area := Rect2i(c - Vector2i(BOX >> 1, BOX >> 1), Vector2i(BOX, BOX))
	var outdoor_cells: int = 0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var d := Vector2i(x, y)
			if g.inside(d) and g.building_at(d) < 0:
				outdoor_cells += 1
	var things: int = 0
	var made: int = 0
	var trees: int = 0
	var indoor: int = 0
	var kinds: Dictionary = {}
	for p: Dictionary in data.get("props", []):
		if not p.get("rect") is Rect2i or int(p.get("level", 0)) != 0:
			continue
		var r: Rect2i = p["rect"]
		if not area.has_point(r.get_center()):
			continue
		var kind: String = String(p.get("kind", ""))
		if g.inside(r.get_center()) and g.building_at(r.get_center()) >= 0:
			indoor += 1
		elif TREE_KINDS.has(kind):
			trees += 1
		else:
			things += 1
			kinds[kind] = int(kinds.get(kind, 0)) + 1
			if not NATURE_KINDS.has(kind):
				made += 1
	var per: float = 100.0 / float(maxi(1, outdoor_cells))
	return {"outdoor_m2": outdoor_cells, "things": things, "things_per100": snappedf(things * per, 0.01),
		"made": made, "made_per100": snappedf(made * per, 0.01), "trees": trees, "indoor": indoor,
		"kinds": kinds.size(), "kind_list": kinds}


## Ground floor only (the spots are): rooms by class, buildings with a furnished bedroom ("homes") and
## how many of them have a furnished bathroom there too, the tints the furniture of the homes drew
## (room_furnish.gd tint_for, one per building), tree props by kind (the whole map).
static func map_counts(data: Dictionary, g: FieldGrid) -> Dictionary:
	var classes: Dictionary = room_classes(data, g)
	var by_class: Dictionary = {}
	var map: Dictionary = RoomFurnish._rooms(data, 0, g)
	var homes: Dictionary = {}
	var baths: Dictionary = {}
	for key: String in classes:
		var cls: String = String(classes[key])
		by_class[cls] = int(by_class.get(cls, 0)) + 1
		var b: int = int(map["rooms"][int(key.split(":")[1])]["building"])
		if cls == "bed":
			homes[b] = true
		elif cls == "bath":
			baths[b] = true
	var with_bath: int = 0
	for b: int in homes:
		with_bath += int(baths.has(b))
	var tints: Dictionary = {}
	for p: Dictionary in data.get("props", []):
		if p.has("rule") and p.has("tint") and int(p.get("level", 0)) == 0 and p.get("rect") is Rect2i:
			var c: Vector2i = (p["rect"] as Rect2i).position
			if g.inside(c) and homes.has(g.building_at(c)):
				tints[int(p["tint"])] = true
	var trees: Dictionary = {}
	for p: Dictionary in data.get("props", []):
		var kind: String = String(p.get("kind", ""))
		if TREE_KINDS.has(kind):
			trees[kind] = int(trees.get(kind, 0)) + 1
	return {"rooms_by_class": by_class, "room_classes": by_class.size(), "homes": homes.size(),
		"homes_with_bath": with_bath, "home_tints": tints.size(), "tree_props": trees}


static func near_things(data: Dictionary, c: Vector2i, radius: int) -> int:
	var area := Rect2i(c - Vector2i(radius, radius), Vector2i(radius * 2 + 1, radius * 2 + 1))
	var n: int = 0
	for p: Dictionary in data.get("props", []):
		if not p.get("rect") is Rect2i or int(p.get("level", 0)) != 0:
			continue
		if PICK_SKIP.has(String(p.get("kind", ""))):
			continue
		if area.intersects(p["rect"]):
			n += 1
	return n


## Four cells short of the outdoor ground-floor dead nearest where the squad steps off, on the side
## toward the squad: {cell, look}. Empty without one.
static func dead_spot(dead: Array, data: Dictionary, g: FieldGrid) -> Dictionary:
	var squad: Array = data.get("spawns", {}).get("squad", [])
	var start: Vector2i = squad[0] if not squad.is_empty() else Vector2i(g.width >> 1, g.height >> 1)
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = -1
	for z: Dictionary in dead:
		var c: Vector2i = FieldGrid.cell_of(z["pos"])
		if not g.inside(c) or g.building_at(c) >= 0 or int(z.get("level", 0)) != 0:
			continue
		var d: int = (c - start).length_squared()
		if best_d < 0 or d < best_d:
			best_d = d
			best = c
	if best_d < 0:
		return {}
	var toward: Vector2 = Vector2(start - best)
	var step: Vector2i = Vector2i(0, 4) if toward.length_squared() < 1.0 else Vector2i((toward.normalized() * 4.0).round())
	var at: Vector2i = best + step
	if not g.inside(at) or not g.people_can_walk(at):
		at = best
	return {"cell": at, "look": best}


## Per kind of building (FRONT_USES): the first building of that kind (by id, at most 900 cells) with
## an outer door on a wall the camera sees, the leader 12-14 cells straight out from that door, looking
## at it. The camera never turns (field_game.gd CAM_YAW, from the south-east), so only south and east
## walls face it; a door on a north or west wall never shows from outside and is not shot from.
## The roofs are judged as the field lifts them (building_view.gd _update_near): round the camera's
## focus for that cell (focus_of: cell -> focus cell, the field pulls it in from the map's edge), by the
## buildings' ground-floor footprints (footprints: building -> Rect2i; one without a footprint is never
## lifted). A cell whose focus would lift the building's own roof is not taken; of the rest 12-14 out,
## the one with the fewest other roofs lifted, the nearer on a tie. "front_<use>" -> {cell, look,
## building, doors, doors_seen, near_roofs}; a kind with no such building is left out.
static func front_spots(data: Dictionary, g: FieldGrid, footprints: Dictionary, focus_of: Callable) -> Dictionary:
	var rows: Array = data.get("buildings", []).duplicate()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
	var doors: Array = g.doors.keys()
	doors.sort()
	var out: Dictionary = {}
	for row: Dictionary in rows:
		var use: String = BuildingUses.use_of(row)
		var tag: String = "front_" + use
		if not FRONT_USES.has(use) or out.has(tag) or (row["rect"] as Rect2i).get_area() > 900:
			continue
		var b: int = int(row["id"])
		var outer: Array = outer_doors(g, b, doors)
		var seen: Array = outer.filter(func(pair: Array) -> bool: return faces_camera(pair[1]))
		var best: Dictionary = {}
		var fewest: int = footprints.size() + 1
		for pair: Array in seen:
			for far: int in [12, 13, 14]:
				var at: Vector2i = (pair[0] as Vector2i) + (pair[1] as Vector2i) * far
				if not (g.inside(at) and g.building_at(at) < 0 and g.people_can_walk(at)):
					continue
				var focus: Vector2i = focus_of.call(at)
				if footprints.has(b) and roof_lifted(footprints[b], focus):
					continue
				var lifted: int = near_roofs(footprints, focus, b)
				if lifted < fewest:
					fewest = lifted
					best = {"cell": at, "look": pair[0]}
		if best.is_empty():
			continue
		best.merge({"building": b, "doors": outer.size(), "doors_seen": seen.size(), "near_roofs": fewest})
		out[tag] = best
	return out


## The outer doors of building b, each with the way out of it (the first of down, right, up, left
## whose cell is outside every building and walkable): [[door, way], ...] in the order of doors.
static func outer_doors(g: FieldGrid, b: int, doors: Array) -> Array:
	var out: Array = []
	for door: Vector2i in doors:
		if g.building_at(door) != b and int(g.doors[door].get("building", -1)) != b:
			continue
		for d: Vector2i in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
			var outside: Vector2i = door + d
			if g.inside(outside) and g.building_at(outside) < 0 and g.people_can_walk(outside):
				out.append([door, d])
				break
	return out


## A wall whose way out is d faces the camera: d points toward where the camera stands on the ground
## (field_game.gd cam_back, CAM_YAW from north toward east).
static func faces_camera(d: Vector2i) -> bool:
	var yaw: float = deg_to_rad(FieldGame.CAM_YAW)
	return Vector2(d).dot(Vector2(sin(yaw), cos(yaw))) > 0.0


## How many buildings other than b have their roof lifted with the camera's focus on c
## (footprints: building -> Rect2i, building_view.gd footprints).
static func near_roofs(footprints: Dictionary, c: Vector2i, b: int) -> int:
	var n: int = 0
	for other: int in footprints:
		if other != b and roof_lifted(footprints[other], c):
			n += 1
	return n


## The field lifts the roof of a building whose footprint r is within NEAR_R of the focus cell c,
## measured as building_view.gd _update_near measures it.
static func roof_lifted(r: Rect2i, c: Vector2i) -> bool:
	var dx: int = maxi(maxi(r.position.x - c.x, c.x - (r.end.x - 1)), 0)
	var dy: int = maxi(maxi(r.position.y - c.y, c.y - (r.end.y - 1)), 0)
	return Vector2(dx, dy).length() <= BuildingView.NEAR_R


## The middle of rect r when it is a walkable cell of building b (not a door), else the walkable cell
## of b nearest it, the first in rows on a tie: an L-shaped building's middle can lie outside it, and a
## middle can fall on an inner wall. r's middle when b has no such cell.
static func inside_cell(g: FieldGrid, b: int, r: Rect2i) -> Vector2i:
	var mid: Vector2i = r.get_center()
	var best: Vector2i = mid
	var best_d: int = -1
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if not g.inside(c) or g.building_at(c) != b or g.doors.has(c) or not g.people_can_walk(c):
				continue
			var d: int = (c - mid).length_squared()
			if best_d < 0 or d < best_d:
				best_d = d
				best = c
	return best


## Outer doors by the walls they are on, over every building: how many buildings have an outer door at
## all, and how many have one on a wall the camera sees (the rest show no way in from outside).
static func door_faces(data: Dictionary, g: FieldGrid) -> Dictionary:
	var doors: Array = g.doors.keys()
	doors.sort()
	var with_door: int = 0
	var with_seen: int = 0
	for row: Dictionary in data.get("buildings", []):
		var outer: Array = outer_doors(g, int(row["id"]), doors)
		if outer.is_empty():
			continue
		with_door += 1
		if outer.any(func(pair: Array) -> bool: return faces_camera(pair[1])):
			with_seen += 1
	return {"buildings_with_door": with_door, "with_door_on_seen_wall": with_seen}
