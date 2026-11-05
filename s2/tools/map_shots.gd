extends SceneTree
## Map look loop: from one map, the same spots by the same rules every run, at the play zoom,
## with counts, so a change to the map can be looked at and measured before and after it.
## Needs a real renderer, so run it without --headless:
##   godot --path s2 --resolution 1688x780 -s res://tools/map_shots.gd -- --out=<folder> [--zoom=24] [--seed=5]
##       [--mask] [--dead] [--hud] [--front [--front-zoom=20]] <place>
## By default as the first loop shots were taken: no sight mask, no dead drawn, no HUD. The play screen
## has all three; turn them on to see it as a player does (the files get _mask, _dead, _hud on the name):
##   --mask   the sight mask, the squad leader looking up the screen (or at the door, at the dead)
##   --dead   the dead drawn, and one more spot, dead: four cells short of the outdoor dead nearest
##            where the squad steps off, looking at it
##   --hud    the field HUD
##   --front  one more spot per kind of building (front_shop, front_home, front_store): the leader 12-14
##            cells straight out from an outer door on a south or east wall (the walls the camera sees)
##            of the first such building, looking at the door, at --front-zoom; see front_spots. The
##            field lifts the roof of every building within 10 cells of the middle of the screen
##            (building_view.gd NEAR_R, the camera's focus), so a building shows its outside only that
##            far off the middle, as here; pushing the camera onto the door would open it. The metrics
##            get "fronts" (the building, its door, how many of its outer doors are on seen walls).
## Every run counts, over all buildings, those with an outer door and those with one on a seen wall
## (map.outer_doors): a door on a north or west wall never shows from outside.
##
## Spots are picked from the map's data, never by hand (so nobody shoots only the good corners):
##   start        the squad's first cell off the train
##   road         a road cell over 15 cells from the train, the one with the most road in the 9x9 round it
##   yard         bare ground 2-3 cells out from a small building, the one with the median count of
##                things within 6 cells (an ordinary yard)
##   inside       the middle of the ground-floor building with the most boxes (its walls cut away)
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
	var out_dir: String = ""
	var zoom: float = 24.0
	var front_zoom: float = 20.0
	var run_seed: int = 5
	var place: String = ""
	var mask: bool = false
	var dead: bool = false
	var hud: bool = false
	var front: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--zoom="):
			zoom = float(arg.trim_prefix("--zoom="))
		elif arg.begins_with("--front-zoom="):
			front_zoom = float(arg.trim_prefix("--front-zoom="))
		elif arg.begins_with("--seed="):
			run_seed = int(arg.trim_prefix("--seed="))
		elif arg == "--mask":
			mask = true
		elif arg == "--dead":
			dead = true
		elif arg == "--hud":
			hud = true
		elif arg == "--front":
			front = true
		elif not arg.begins_with("--") and place.is_empty():
			place = arg
		else:
			_fail("unknown or repeated argument: " + arg)
			return
	if out_dir.is_empty() or place.is_empty():
		_fail("usage: -- --out=<folder> [--zoom=24] [--seed=5] [--mask] [--dead] [--hud] [--front [--front-zoom=20]] <place>")
		return
	var suffix: String = ("_mask" if mask else "") + ("_dead" if dead else "") + ("_hud" if hud else "")
	DirAccess.make_dir_recursive_absolute(out_dir)
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
	var fronts: Dictionary = front_spots(data, g) if front else {}
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
			game._refresh_vision()
		# The dead read one body in a frame (zombies.gd render): draw them over a few frames.
		for _i in range(8 if dead else 2):
			if dead:
				game.zombies.render(game.camera, game.seen_now, game.mask_on)
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_jpg(out_dir.path_join("%s_%s%s.jpg" % [place, tag, suffix]), 0.9)
		var row: Dictionary = spot_counts(data, g, cell)
		row["cell"] = [cell.x, cell.y]
		if rooms.has(tag):
			row.merge(rooms[tag]["counts"])
		metrics["spots"][tag] = row
		print("SHOT %s %s %s" % [place, tag, JSON.stringify(row)])
	var file: FileAccess = FileAccess.open(out_dir.path_join("%s%s_metrics.json" % [place, suffix]), FileAccess.WRITE)
	if file == null:
		_fail("cannot write metrics: %d" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(metrics, "\t", true))
	file.close()
	print("MAP_SHOTS_DONE %s spots=%d" % [place, (metrics["spots"] as Dictionary).size()])
	quit(0)


func _fail(message: String) -> void:
	printerr("MAP_SHOTS_FAIL " + message)
	quit(1)


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
			out["inside"] = (b["rect"] as Rect2i).get_center()
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
	var area := Rect2i(c - Vector2i(BOX / 2, BOX / 2), Vector2i(BOX, BOX))
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
	var start: Vector2i = squad[0] if not squad.is_empty() else Vector2i(g.width / 2, g.height / 2)
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
## Of the cells 12-14 out, the one with the fewest other buildings within NEAR_R is taken (the field
## lifts their roofs, building_view.gd). "front_<use>" -> {cell, look, building, doors, doors_seen,
## near_roofs}; a kind with no such building is left out.
static func front_spots(data: Dictionary, g: FieldGrid) -> Dictionary:
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
		var fewest: int = rows.size() + 1
		for pair: Array in seen:
			for far: int in [12, 13, 14]:
				var at: Vector2i = (pair[0] as Vector2i) + (pair[1] as Vector2i) * far
				if not (g.inside(at) and g.building_at(at) < 0 and g.people_can_walk(at)):
					continue
				var lifted: int = near_roofs(rows, at, b)
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


## How many buildings other than b have their roof lifted with the camera's middle on c: within
## NEAR_R of their rect, measured as building_view.gd _update_near measures it.
static func near_roofs(rows: Array, c: Vector2i, b: int) -> int:
	var n: int = 0
	for row: Dictionary in rows:
		if int(row["id"]) == b:
			continue
		var r: Rect2i = row["rect"]
		var dx: int = maxi(maxi(r.position.x - c.x, c.x - (r.end.x - 1)), 0)
		var dy: int = maxi(maxi(r.position.y - c.y, c.y - (r.end.y - 1)), 0)
		if Vector2(dx, dy).length() <= BuildingView.NEAR_R:
			n += 1
	return n


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
