extends GutTest
## A lived car is dressed in three layers (대조표 T4: the floor, the wall and the ceiling,
## three of each at least): the layout rows marked with their layer, the new small things
## marked "dress" drawn as one mesh a car (결정 505 잰 값), up close only on the diagonal.
## Each layer row keeps its place, and a dress row more strictly: no higher than the diagonal
## brings high props down to, on the back wall between the windows, off the walking line and
## the end doors and as far from where people stand as people keep from things.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const TrainDecor = preload("res://game/train/train_decor.gd")
const KIT: String = "res://models/train_interior/catalog.json"
const LIVED: Array[String] = ["tail1", "tail2", "tail3", "medtech", "guard", "front", "dining", "workshop", "captain", "engine"]
const LAYERS: Array[String] = ["floor", "wall", "ceiling"]
const BACK: float = -1.30
const WINDOWS: Array[Vector2] = [Vector2(1.2, 2.8), Vector2(5.2, 6.8), Vector2(9.2, 10.8), Vector2(13.2, 14.8)]
## The walking line kept from door to door (z3 of the 0.5 m floor grid), and the end doors' way in.
const LANE := Vector2(0.25, 0.75)
const DOOR := Vector2(0.2, 1.1)
const EPS: float = 0.00001
const UPPER_BUNKS: Array[String] = ["bunk_upper", "sack_bunk_upper", "open_bunk_upper"]


func _def(id: String) -> Dictionary:
	for c: Dictionary in Rules.load_default()["cars"]:
		if String(c["id"]) == id:
			return c
	return {}


func _rows(id: String, stage: int) -> Array:
	var out: Array = []
	for source: Dictionary in Catalog.layout(_def(id))["props"]:
		if source.has("cars") and not (source["cars"] as Array).has(id):
			continue
		var home: Array = source.get("home", [0, 3])
		if stage < int(home[0]) or stage > int(home[1]):
			continue
		var row: Dictionary = source.duplicate(true)
		row["model"] = String((source.get("home_model", {}) as Dictionary).get(str(stage), source["model"]))
		out.append(row)
	return out


## [x0, x1, y0, y1, z0, z1] of a row's box (rows turned a quarter swap their x and z).
func _box(row: Dictionary) -> Array:
	var at: Array = row["at"]
	var s: Array = row["size"]
	var sx: float = float(s[0])
	var sz: float = float(s[2])
	if absf(sin(float(row.get("yaw", 0.0)))) > 0.5:
		sx = float(s[2])
		sz = float(s[0])
	return [float(at[0]) - sx * 0.5, float(at[0]) + sx * 0.5,
		float(at[1]) - float(s[1]) * 0.5, float(at[1]) + float(s[1]) * 0.5,
		float(at[2]) - sz * 0.5, float(at[2]) + sz * 0.5]


func test_every_lived_car_has_three_of_each_layer() -> void:
	for id: String in LIVED:
		assert_false(_def(id).is_empty(), id + " is in the train")
		for stage: int in range(4):
			var n: Dictionary = {"floor": 0, "wall": 0, "ceiling": 0}
			for row: Dictionary in _rows(id, stage):
				if row.has("layer") and String(row.get("when", "always")) == "always":
					var layer: String = String(row["layer"])
					assert_has(n, layer, "%s stage %d" % [id, stage])
					if n.has(layer):
						n[layer] += 1
			for layer: String in LAYERS:
				assert_gte(int(n[layer]), 3, "%s stage %d: %s %d" % [id, stage, layer, int(n[layer])])


func test_each_layer_row_keeps_its_place() -> void:
	var clear: float = float(Catalog.tuning("actor_clearance"))
	for id: String in LIVED:
		var layout: Dictionary = Catalog.layout(_def(id))
		var anchors: Array = []
		for spot: Dictionary in layout.get("spots", []):
			for a: Array in spot.get("anchors", []):
				anchors.append(Vector2(float(a[0]), float(a[2])))
		for stage: int in range(4):
			for row: Dictionary in _rows(id, stage):
				if not row.has("layer"):
					continue
				var b := _box(row)
				var dress: bool = bool(row.get("dress", false))
				var what: String = "%s stage %d %s" % [id, stage, String(row["id"])]
				assert_true(b[0] >= 0.0 and b[1] <= 16.0 and b[4] >= BACK - 0.06 and b[5] <= 1.4, what + " is inside the car")
				match String(row["layer"]):
					"ceiling":
						assert_gte(b[2], 1.5, what + " hangs over heads")
					"wall":
						assert_gte(b[2], 0.6, what + " hangs on a wall")
						assert_true(b[4] <= BACK + 0.06 or b[0] <= 0.15 or b[1] >= 15.85, what + " is on a wall")
					"floor":
						assert_lt(b[2], 0.25, what + " stands on the floor")
					_:
						fail_test(what + ": no such layer")
				if not dress:
					continue
				# A dress row: one of the kit's, always shown, with no state of its own.
				assert_true(ResourceLoader.exists("res://models/train_interior/%s.glb" % String(row["model"])), what + " has its model")
				assert_false(row.has("when") or row.has("trace"), what + " is always there and never moved")
				match String(row["layer"]):
					"ceiling":
						assert_lte(b[3], Scene.DIAG_PROP_TOP + 0.001, what + " hangs no higher than the diagonal's high props")
					"wall":
						assert_almost_eq(b[4], BACK, 0.001, what + " is on the back wall")
						for w: Vector2 in WINDOWS:
							assert_false(b[0] < w.y and b[1] > w.x and b[3] > 1.3, what + " is not over a window")
					"floor":
						assert_lt(b[2], 0.001, what + " stands on the floor")
						if b[3] - b[2] > 0.03:
							assert_false(b[4] < LANE.y and b[5] > LANE.x, what + " is off the walking line")
							assert_false((b[0] < 0.8 or b[1] > 15.2) and b[4] < DOOR.y and b[5] > DOOR.x, what + " is off the door's way")
							for p: Vector2 in anchors:
								var dx: float = maxf(maxf(b[0] - p.x, 0.0), p.x - b[1])
								var dz: float = maxf(maxf(b[4] - p.y, 0.0), p.y - b[5])
								assert_gte(Vector2(dx, dz).length(), clear, what + " keeps people's clearance")


## Only the half-open curtain, the two existing upper-bunk sites and the tail car's patched
## window may reach the glass; the patch boards only its lower part, the upper 0.4 m left open.
func _window_exception(row: Dictionary) -> bool:
	if String(row["model"]) == "curtain_half_open":
		return true
	if String(row["id"]) == "patched_window" and String(row["model"]) == "patch_boards":
		return _box(row)[3] <= 2.2 - 0.4 + EPS
	var sites: Dictionary = {"upper_bunk_a": Vector3(4, 1.8, -1), "upper_bunk_b": Vector3(12, 1.8, -1)}
	var id: String = String(row["id"])
	return (UPPER_BUNKS.has(String(row["model"])) and sites.has(id)
		and Catalog.vector(row["at"]) == sites[id] and Catalog.vector(row["size"]) == Vector3(2.8, 0.14, 0.6))


func _overlap(a: Array, b: Array) -> bool:
	for axis: int in [0, 2, 4]:
		if a[axis] >= b[axis + 1] - EPS or a[axis + 1] <= b[axis] + EPS:
			return false
	return true


## Include every home row without requiring a layer, and resolve fixture model swaps too.
func test_each_home_row_keeps_its_place_at_every_stage() -> void:
	var clear: float = float(Catalog.tuning("actor_clearance"))
	for id: String in TrainDecor.DECOR_CARS:
		var layout: Dictionary = Catalog.layout(_def(id))
		var anchors: Array = []
		for spot: Dictionary in layout.get("spots", []):
			for a: Array in spot.get("anchors", []):
				anchors.append(Vector2(float(a[0]), float(a[2])))
		for stage: int in range(4):
			for row: Dictionary in _rows(id, stage):
				if not (row.has("layer") or row.has("home") or row.has("home_model")):
					continue
				var b := _box(row)
				var what: String = "%s stage %d %s" % [id, stage, String(row["id"])]
				assert_true(b[0] >= -EPS and b[1] <= 16.0 + EPS and b[4] >= BACK - 0.06 - EPS and b[5] <= 1.4 + EPS, what + " is inside the car")
				# Existing fixture anchors are seats/beds. Added home/dress rows must keep clear of them.
				var added: bool = row.has("home") or bool(row.get("dress", false))
				if added and b[2] < 0.4 - EPS and b[3] - b[2] > 0.03 + EPS:
					assert_false(b[4] < LANE.y - EPS and b[5] > LANE.x + EPS, what + " leaves the walking line")
					assert_false((b[0] < 0.8 - EPS or b[1] > 15.2 + EPS) and b[4] < DOOR.y - EPS and b[5] > DOOR.x + EPS, what + " leaves the door's way")
					for p: Vector2 in anchors:
						var dx: float = maxf(maxf(b[0] - p.x, 0.0), p.x - b[1])
						var dz: float = maxf(maxf(b[4] - p.y, 0.0), p.y - b[5])
						assert_gte(Vector2(dx, dz).length(), clear - EPS, what + " keeps people's clearance")
				if b[4] < BACK + 0.45 - EPS and b[3] > 1.30 + EPS and b[2] < 2.20 - EPS and not _window_exception(row):
					for w: Vector2 in WINDOWS:
						assert_false(b[0] < w.y - EPS and b[1] > w.x + EPS, what + " leaves the window glass clear")


func _assert_shelf_support(row: Dictionary, shelf: Dictionary, what: String) -> void:
	assert_true(bool(shelf.get("tier_shelf", false)), what + " has a support shelf")
	var model: String = String(shelf["model"])
	assert_has(["end_shelf", "top_shelf"], model, what + " resolves its shelf model")
	if model not in ["end_shelf", "top_shelf"]:
		return
	var end: bool = model == "end_shelf"
	var b := _box(row)
	var sb := _box(shelf)
	var k: float = minf(1.0, float(shelf["size"][1]) / (0.9 if end else 0.24))
	var levels: Array = [0.025, 0.4625, 0.9] if end else [0.24]
	var board: int = int(row.get("shelf_board", -1))
	assert_between(board, 0, levels.size() - 1, what + " names a board")
	if board < 0 or board >= levels.size():
		return
	var top: float = sb[2] + float(levels[board]) * k
	var half_width: float = (0.204 if end else 0.24) * k
	var back: float = (-0.105 if end else -0.14) * k
	var front: float = ([0.14, 0.075, 0.01][board] if end else 0.14) * k
	assert_almost_eq(b[2], top, EPS, what + " rests on the board")
	assert_true(b[0] >= float(shelf["at"][0]) - half_width - EPS and b[1] <= float(shelf["at"][0]) + half_width + EPS, what + " fits the board width")
	assert_true(b[4] >= float(shelf["at"][2]) + back - EPS and b[5] <= float(shelf["at"][2]) + front + EPS, what + " fits the board depth")
	assert_true(b[0] >= sb[0] - EPS and b[1] <= sb[1] + EPS and b[4] >= sb[4] - EPS and b[5] <= sb[5] + EPS, what + " stays within its shelf")


## A support must be present at this stage and clear of every other active fixture.
func test_home_shelves_and_their_contents_do_not_overlap_other_rows() -> void:
	for id: String in TrainDecor.DECOR_CARS:
		for stage: int in range(4):
			var rows: Array = _rows(id, stage)
			var by_id: Dictionary = {}
			for row: Dictionary in rows:
				assert_false(by_id.has(row["id"]), "%s stage %d: unique row %s" % [id, stage, row["id"]])
				by_id[row["id"]] = row
			for row: Dictionary in rows:
				var what: String = "%s stage %d %s" % [id, stage, row["id"]]
				var b := _box(row)
				if row.has("on_shelf"):
					var support: String = String(row["on_shelf"])
					assert_has(by_id, support, what + " has a visible support at this stage")
					if by_id.has(support):
						_assert_shelf_support(row, by_id[support], what)
					for other: Dictionary in rows:
						if String(other["id"]) == String(row["id"]) or String(other["id"]) == support:
							continue
						assert_false(_overlap(b, _box(other)), what + " clears " + String(other["id"]))
				if bool(row.get("tier_shelf", false)):
					for other: Dictionary in rows:
						if String(other["id"]) == String(row["id"]) or String(other.get("on_shelf", "")) == String(row["id"]):
							continue
						assert_false(_overlap(b, _box(other)), what + " support clears " + String(other["id"]))


func _scene(extra: Dictionary = {}) -> Scene:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1688, 780)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	var s: Scene = Scene.new()
	s.rules = Rules.load_default()
	var o: Dictionary = {"seed": 7, "panel": false, "baked_people": false}
	o.merge(extra, true)
	s.opts = o
	viewport.add_child(s)
	return s


func test_the_dress_is_one_mesh_a_car_where_its_rows_say_seen_up_close() -> void:
	var kit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KIT))
	var s: Scene = _scene({"view_mode": "diag"})
	for id: String in ["guard", "tail2", "dining"]:
		var room = s.life.rooms[id]
		var dress: MeshInstance3D = room.dress
		assert_not_null(dress, id + " has its dress")
		if dress == null:
			continue
		var tris := 0
		var rows := 0
		var reach := AABB()
		# Only the rows of the car's home stage, each with that stage's model (train_interior.gd build).
		var stage: int = int(s.car(id).get("home_stage", 1))
		for row: Dictionary in _rows(id, stage):
			if bool(row.get("dress", false)):
				var model: String = String(row["model"])
				tris += int(kit["assets"][model]["lod0_tris"])
				rows += 1
				var b := _box(row)
				var one := AABB(Vector3(b[0], b[2], b[4]), Vector3(b[1] - b[0], b[3] - b[2], b[5] - b[4]))
				reach = one if rows == 1 else reach.merge(one)
				assert_null(room.root.get_node_or_null(String(row["id"])), id + ": no node of its own for " + String(row["id"]))
		assert_gt(rows, 0)
		var index: PackedInt32Array = dress.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		assert_eq(dress.mesh.get_surface_count(), 1, id + ": one surface, one draw")
		assert_eq(int(index.size() / 3.0), tris, id + ": every dress model in it")
		# Laid where the rows keep them: the mesh stays in the rows' boxes (nothing in the wall or the
		# floor), and a model a stage puts in a row's place (home_model) may be smaller than its box.
		var got: AABB = dress.mesh.get_aabb()
		for axis: int in 3:
			assert_true(got.position[axis] >= reach.position[axis] - 0.011, "%s: from %s, rows %s" % [id, got.position, reach.position])
			assert_true(got.end[axis] <= reach.end[axis] + 0.011, "%s: to %s, rows %s" % [id, got.end, reach.end])
		assert_gt(got.get_volume(), reach.get_volume() * 0.5, id + ": the mesh fills most of the rows' reach")
		assert_eq(dress.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var guard: MeshInstance3D = s.life.rooms["guard"].dress
	s.focus_car("guard", false)
	assert_false(guard.visible, "the wide diagonal leaves the small things out")
	s.focus_car("guard", true)
	assert_true(guard.visible, "up close they show")
	s.set_view_mode("section")
	s.toggle_zoom()
	assert_true(guard.visible, "the side view shows them at either zoom")


func test_the_lamp_leaves_a_warm_pool_on_the_floor_up_close() -> void:
	var s: Scene = _scene({"view_mode": "diag"})
	for c: Dictionary in s.cars:
		var pool: MeshInstance3D = c.get("lamp_pool")
		assert_not_null(pool, String(c["id"]) + " has a pool under its lamp")
		if pool == null:
			continue
		var lamp: OmniLight3D = c["lamp"]
		assert_almost_eq(pool.position.x, lamp.position.x, 0.06, String(c["id"]) + ": under the lamp along the car")
		assert_almost_eq(pool.position.z, lamp.position.z, 0.001, String(c["id"]) + ": under the lamp across")
		assert_lt(pool.position.y, 0.05, "on the floor")
		assert_eq(pool.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var strength: float = pool.get_instance_shader_parameter("pool_strength")
		assert_almost_eq(strength, sqrt(lamp.light_energy) * Scene.LAMP_POOL_GAIN, 0.001, "follows the lamp")
		if lamp.light_energy > 0.0:
			assert_gt(strength, 0.0, "the day's low lamp still leaves a faint pool")
	var guard: Dictionary = s.cars.filter(func(c: Dictionary) -> bool: return c["id"] == "guard")[0]
	assert_false((guard["lamp_pool"] as MeshInstance3D).visible, "the first wide diagonal leaves it out")
	s.focus_car("guard", false)
	assert_false((guard["lamp_pool"] as MeshInstance3D).visible, "the wide diagonal leaves it out with the dress")
	s.focus_car("guard", true)
	assert_true((guard["lamp_pool"] as MeshInstance3D).visible, "up close it shows")
