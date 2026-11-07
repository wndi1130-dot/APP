extends "res://addons/gut/test.gd"
## What lies on the ground is drawn (ground_look.gd, map_view.update_ground): a
## shape of its kind on its floor, no heaps, the shining ones left to their light.

const GroundLook = preload("res://game/world/ground_look.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const TwoLids = preload("res://tests/game/fixtures/two_lids_map.gd")
const MapView = preload("res://game/world/map_view.gd")
const GroundModels = preload("res://game/world/ground_models.gd")

var _old_cache: Dictionary = {}


func before_each() -> void:
	_old_cache = GroundModels.cache_snapshot()
	GroundModels.restore_cache({})


func after_each() -> void:
	GroundModels.restore_cache(_old_cache)


func test_each_thing_has_a_shape_of_its_kind() -> void:
	var kinds := {
		"knife": "weapon", "undershirt_wool": "garment", "cloth": "cloth", "note_map": "paper",
		"key_3": "paper", "plank": "board", "oats": "sack", "can_beans": "small",
		"ammo_craft": "small", "can_empty": "small", "food_pack": "crate", "rare_can_crate": "big",
		"core_engine": "big",
	}
	for id: String in kinds:
		assert_eq(GroundLook.kind_of({"id": id, "n": 1}), kinds[id], id)
	assert_eq(GroundLook.kind_of({"id": "pipe", "n": 1, "weapon": {"id": "pipe"}}), "weapon", "a dropped weapon row")


func test_no_bag_or_bundle_shape_among_the_looks() -> void:
	# 금지선: no case, bundle or bag by the train; sacks and crates are allowed.
	for kind: String in GroundLook.LOOKS:
		assert_false(kind in ["bag", "case", "bundle", "suitcase"], kind)
	assert_eq(GroundLook.kind_of({"id": "found_big_pack", "n": 1}), "small", "a found pack is not drawn as a bag")


func test_the_shining_ones_are_left_to_their_light() -> void:
	var items := [
		{"pos": Vector3(5.5, 0, 5.5), "id": "hare_frozen", "n": 1, "glint": true},
		{"pos": Vector3(9.5, 0, 9.5), "id": "plank", "n": 1},
	]
	var out: Array = GroundLook.pieces(items)
	assert_eq(out.size(), 1)
	var c: Color = out[0]["color"]
	var seen: Color = GroundLook.LOOKS["board"][1]
	assert_almost_eq(c.r, seen.r, 0.0001, "as seen (sRGB): the world shader makes it linear")
	assert_almost_eq(c.b, seen.b, 0.0001)
	assert_eq(c.a, 0.0, "no snow laid over it in the world shader")


func test_things_at_one_spot_are_spread_and_never_more_than_three_drawn() -> void:
	# What a fallen one had all falls where it fell (field_game.gd): no heap.
	var at := Vector3(12.4, 0, 7.6)
	var items: Array = []
	for id: String in ["can_beans", "plank", "cloth", "oats", "knife", "note_map"]:
		items.append({"pos": at, "id": id, "n": 1})
	var out: Array = GroundLook.pieces(items)
	assert_eq(out.size(), GroundLook.PER_CELL)
	var biggest: Dictionary = out[0]
	for piece: Dictionary in out:
		if (piece["size"] as Vector3).x * (piece["size"] as Vector3).z > (biggest["size"] as Vector3).x * (biggest["size"] as Vector3).z:
			biggest = piece
	assert_almost_eq(Vector2(biggest["at"].x, biggest["at"].z).distance_to(Vector2(at.x, at.z)), 0.0, 0.001, "the biggest lies where it was put")
	var spots := {}
	for piece: Dictionary in out:
		var flat := Vector2(piece["at"].x, piece["at"].z)
		assert_true(flat.distance_to(Vector2(at.x, at.z)) < 0.9, "within a tap of where it lies")
		spots[flat.snapped(Vector2(0.01, 0.01))] = true
	assert_eq(spots.size(), out.size(), "none on top of another")
	# Another cell gets its own three.
	items.append({"pos": at + Vector3(3, 0, 0), "id": "cloth", "n": 1})
	assert_eq(GroundLook.pieces(items).size(), GroundLook.PER_CELL + 1)


## 11-07 shots: three clothes at real size on one cell lay on one another (a heap,
## the 금지선) and a knife was lost under a shirt. Now each lies clear of the rest.
func test_clothes_and_a_knife_on_one_cell_lie_clear_of_one_another() -> void:
	var at := Vector3(20.5, 0, 9.5)
	for ids: Array in [["coat_long", "shirt_flannel", "trousers_work", "boots_work"], ["knife", "shirt_cotton", "can_beans"]]:
		var items: Array = []
		for id: String in ids:
			items.append({"pos": at, "id": id, "n": 1})
		var out: Array = GroundLook.pieces(items)
		assert_eq(out.size(), mini(ids.size(), GroundLook.PER_CELL))
		for i: int in out.size():
			var a: Dictionary = out[i]
			var flat_a := Vector2(a["at"].x, a["at"].z)
			assert_lte(flat_a.distance_to(Vector2(at.x, at.z)), GroundLook.SPREAD_MAX + 0.0001, "%s within reach of its spot" % ids[i])
			for j: int in range(i + 1, out.size()):
				var b: Dictionary = out[j]
				var gap: float = GroundLook.footprint_gap(flat_a, Vector2(a["size"].x, a["size"].z), a["yaw"],
					Vector2(b["at"].x, b["at"].z), Vector2(b["size"].x, b["size"].z), b["yaw"])
				assert_gte(gap, 0.0, "%s and %s do not lie on one another" % [ids[i], ids[j]])
		assert_eq(GroundLook.pieces(items), out, "the same list lies the same")


func test_footprint_gap_is_the_room_between_turned_rectangles() -> void:
	assert_almost_eq(GroundLook.footprint_gap(Vector2.ZERO, Vector2.ONE, 0.0, Vector2(3, 0), Vector2.ONE, 0.0), 2.0, 0.0001, "side by side")
	assert_almost_eq(GroundLook.footprint_gap(Vector2.ZERO, Vector2(2, 1), 0.0, Vector2(0, 2), Vector2(2, 1), 0.0), 1.0, 0.0001, "one above the other")
	assert_lt(GroundLook.footprint_gap(Vector2.ZERO, Vector2.ONE, 0.0, Vector2(0.5, 0), Vector2.ONE, 0.0), 0.0, "overlapping")
	# A long thin thing turned a quarter lies along z: it clears one beside it on x.
	assert_gt(GroundLook.footprint_gap(Vector2.ZERO, Vector2(2, 0.2), PI * 0.5, Vector2(0.5, 0), Vector2(0.2, 0.2), 0.0), 0.0)
	assert_lt(GroundLook.footprint_gap(Vector2.ZERO, Vector2(2, 0.2), 0.0, Vector2(0.5, 0), Vector2(0.2, 0.2), 0.0), 0.0, "unturned it covers it")
	# Two squares turned 45 degrees, 2 m apart on x: measured along their own edge
	# normals (the separating axes), 2·cos45 apart less a side each.
	assert_almost_eq(GroundLook.footprint_gap(Vector2.ZERO, Vector2.ONE, PI * 0.25, Vector2(2, 0), Vector2.ONE, PI * 0.25), sqrt(2.0) - 1.0, 0.0001)
	# Turned unlike each other: a square on its corner reaches √2/2 along x, so to a
	# straight one 2 m off it is 2 - √2/2 - 1/2, measured either way round.
	var mixed: float = 1.5 - sqrt(2.0) * 0.5
	assert_almost_eq(GroundLook.footprint_gap(Vector2.ZERO, Vector2.ONE, PI * 0.25, Vector2(2, 0), Vector2.ONE, 0.0), mixed, 0.0001, "corner to side")
	assert_almost_eq(GroundLook.footprint_gap(Vector2(2, 0), Vector2.ONE, 0.0, Vector2.ZERO, Vector2.ONE, PI * 0.25), mixed, 0.0001, "side to corner")


## The quick gap (each rectangle's sides turned once, its own reach taken as its
## half side) agrees with the plain one on long, thin, turned things at any angle.
func test_footprint_gap_agrees_with_the_plain_working() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1107
	for n: int in 300:
		var ca := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		var cb := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		var sa := Vector2(rng.randf_range(0.02, 1.2), rng.randf_range(0.02, 1.2))
		var sb := Vector2(rng.randf_range(0.02, 1.2), rng.randf_range(0.02, 1.2))
		var ya: float = rng.randf_range(-TAU, TAU)
		var yb: float = rng.randf_range(-TAU, TAU)
		assert_almost_eq(GroundLook.footprint_gap(ca, sa, ya, cb, sb, yb), _plain_gap(ca, sa, ya, cb, sb, yb), 0.00001, "case %d" % n)


## Every one of the four side directions, each rectangle reaching along it by
## both its sides.
func _plain_gap(ca: Vector2, sa: Vector2, ya: float, cb: Vector2, sb: Vector2, yb: float) -> float:
	var sides: Array = []
	for yaw: float in [ya, yb]:
		var turn := Basis(Vector3.UP, yaw)
		var x3: Vector3 = turn * Vector3.RIGHT
		var z3: Vector3 = turn * Vector3.BACK
		sides.append([Vector2(x3.x, x3.z), Vector2(z3.x, z3.z)])
	var best: float = -INF
	for axis: Vector2 in sides[0] + sides[1]:
		var reach_a: float = absf(axis.dot(sides[0][0])) * sa.x * 0.5 + absf(axis.dot(sides[0][1])) * sa.y * 0.5
		var reach_b: float = absf(axis.dot(sides[1][0])) * sb.x * 0.5 + absf(axis.dot(sides[1][1])) * sb.y * 0.5
		best = maxf(best, absf(axis.dot(cb - ca)) - reach_a - reach_b)
	return best


## A spot is sought out along the thing's own angle from SPREAD on; when nothing
## by SPREAD_MAX is clear, it takes the roomiest of eight angles there, the
## first of equals, and is left at the spot it was given.
func test_a_clear_spot_is_the_first_out_along_its_angle_else_the_roomiest() -> void:
	var laid: Array[GroundLook.Footprint] = [GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.2, 0.2), 0.0)]
	var small := GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.2, 0.2), 0.0)
	var spot: Vector2 = GroundLook._clear_spot(small, 0.0, laid)
	assert_almost_eq(spot.x, GroundLook.SPREAD, 0.0001, "clear at the first try")
	assert_almost_eq(spot.y, 0.0, 0.0001)
	assert_eq(small.centre, spot, "left where it goes")
	var down: Vector2 = GroundLook._clear_spot(GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.2, 0.2), PI * 0.5), PI * 0.5, laid)
	assert_almost_eq(down.y, GroundLook.SPREAD, 0.0001, "out along its own angle")
	# Under a 2 m square nothing by SPREAD_MAX is clear: straight out on x and z is
	# roomier than the diagonals, and of those four the first, along its own angle.
	var under: Array[GroundLook.Footprint] = [GroundLook.Footprint.new(Vector2.ZERO, Vector2(2, 2), 0.0)]
	var lost := GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.5, 0.5), 0.0)
	var best: Vector2 = GroundLook._clear_spot(lost, 0.0, under)
	assert_almost_eq(best.x, GroundLook.SPREAD_MAX, 0.0001)
	assert_almost_eq(best.y, 0.0, 0.0001)
	assert_eq(lost.centre, best, "left at the roomiest")
	assert_lt(GroundLook._room_among(lost, under), 0.0, "still under it, but no farther than reach")


func test_it_lies_on_its_own_floor() -> void:
	var items := [
		{"pos": Vector3(4.5, 3.0, 4.5), "id": "can_beans", "n": 1},
		{"pos": Vector3(4.5, -3.0, 4.5), "id": "plank", "n": 1},
	]
	var out: Array = GroundLook.pieces(items)
	assert_eq(out[0]["lv"], 1)
	assert_almost_eq(float(out[0]["at"].y), 3.0, 0.001, "footprint centre on the upper floor")
	assert_eq(out[1]["lv"], -1)
	assert_almost_eq(float(out[1]["at"].y), -3.0, 0.001)
	assert_eq(GroundLook.pieces(items).hash(), out.hash(), "the same list, the same spots")


func test_each_thing_has_a_dark_rim_round_it_on_its_floor() -> void:
	# T0-6: a quad a little wider than the thing, flat on the thing's own floor (contact_shade darkens it).
	var piece: Dictionary = GroundLook.pieces([{"pos": Vector3(4.5, 3.0, 4.5), "id": "undershirt_wool", "n": 1}])[0]
	var rim: Dictionary = GroundLook.rim(piece)
	var size: Vector3 = piece["size"]
	assert_eq(rim["lv"], piece["lv"])
	assert_almost_eq(rim["size"].x, size.x + 2.0 * GroundLook.RIM, 0.0001, "wider on both sides")
	assert_almost_eq(rim["size"].y, size.z + 2.0 * GroundLook.RIM, 0.0001)
	assert_almost_eq(float(rim["at"].y), 3.0 + GroundLook.RIM_LIFT, 0.0001, "flat on the thing's own floor")
	assert_true(GroundLook.RIM_LIFT < size.y, "under the thing's top, so the thing shows over it")
	assert_almost_eq(rim["inner"].x * rim["size"].x, size.x, 0.0001, "the thing's share of the quad")
	assert_almost_eq(rim["inner"].y * rim["size"].y, size.z, 0.0001)


func _rim_alphas(rim: Dictionary) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MapView._rim_quad(st, rim)
	return Array(st.commit().surface_get_arrays(0)[Mesh.ARRAY_COLOR]).map(func(c: Color) -> float: return c.a)


func test_a_rim_under_a_roof_says_so_in_its_alpha() -> void:
	# contact_shade lightens a rim on snow out of doors only (alpha 1); under a roof (0) no snow lies
	# on the floor, so the rim keeps its strength in deep winter too.
	var piece: Dictionary = GroundLook.pieces([{"pos": Vector3(4.5, 0.0, 4.5), "id": "cloth", "n": 1}])[0]
	var rim: Dictionary = GroundLook.rim(piece)
	assert_eq(_rim_alphas(rim), [1.0, 1.0, 1.0, 1.0, 1.0, 1.0], "open to the sky unless told")
	rim["sky"] = 0.0
	assert_eq(_rim_alphas(rim), [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "under a roof")


func test_a_thing_put_down_shows_on_the_map_and_goes_when_picked_up() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 4, "auto_pause": false}
	game.map_script = TwoLids
	add_child_autofree(game)
	game.set_process(false)
	var p = game.player
	game._update_zone(0.1)
	assert_false(game.view.ground_nodes.has(0) and game.view.ground_nodes[0].mesh != null, "nothing lies there yet")
	game.ground_items.append({"pos": p.position + Vector3(0.4, 0, 0.4), "id": "plank", "n": 1})
	game._update_zone(0.1)
	assert_true(game.view.ground_nodes.has(0))
	assert_not_null(game.view.ground_nodes[0].mesh, "a plank put down is seen where it lies")
	assert_not_null((game.view.ground_nodes[0].get_node("Rim") as MeshInstance3D).mesh, "on its dark rim")
	var sky := MapView.sky_alpha(game.view.grid, FieldGrid.cell_of(p.position + Vector3(0.4, 0, 0.4)))
	var rim_mesh: Mesh = (game.view.ground_nodes[0].get_node("Rim") as MeshInstance3D).mesh
	for c: Color in rim_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		assert_eq(c.a, sky, "open to the sky or under a roof, as the floor it lies on")
	game.ground_items.clear()
	game._update_zone(0.1)
	assert_null(game.view.ground_nodes[0].mesh, "picked up, it is gone")
	assert_null((game.view.ground_nodes[0].get_node("Rim") as MeshInstance3D).mesh, "its rim with it")


func _template() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex: Vector3 in [Vector3(-0.6, 0, -0.2), Vector3(0.6, 0, -0.2), Vector3(0, 0.08, 0.2)]:
		surface.set_normal(Vector3.UP)
		surface.set_color(Color(0.4, 0.3, 0.2, 0))
		surface.add_vertex(vertex)
	return surface.commit()


func test_model_name_footprint_yaw_and_floor_are_from_the_shared_template() -> void:
	assert_true(GroundModels.cache_template("knife", _template()))
	var items: Array = [{"id": "knife", "n": 1, "pos": Vector3(5.5, 3, 7.5)}]
	var piece: Dictionary = GroundLook.pieces(items)[0]
	assert_eq(piece["model"], "knife")
	assert_eq(piece["size"], Vector3(1.2, 0.08, 0.4))
	assert_eq(piece["at"], Vector3(5.5, 3, 7.5))
	assert_eq(GroundLook.pieces(items)[0]["yaw"], piece["yaw"])
	assert_gte(float(piece["yaw"]), 0.0)
	assert_lt(float(piece["yaw"]), TAU)
	var rim: Dictionary = GroundLook.rim(piece)
	assert_eq(rim["yaw"], piece["yaw"])
	assert_almost_eq(rim["size"].x, 1.2 + GroundLook.RIM * 2.0, 0.00001)
	assert_almost_eq(rim["size"].y, 0.4 + GroundLook.RIM * 2.0, 0.00001)
	assert_almost_eq(rim["at"].y, 3.0 + GroundLook.RIM_LIFT, 0.00001)


func test_missing_models_and_box_only_ids_and_bags_keep_boxes() -> void:
	GroundModels.cache_template("no_art_550", null)
	var missing: Dictionary = GroundLook.pieces([{"id": "no_art_550", "n": 1, "pos": Vector3.ZERO}])[0]
	assert_eq(missing["model"], "")
	assert_eq(missing["size"], GroundLook.LOOKS["small"][0])
	var ids: Array = GroundModels.BOX_ONLY_IDS.keys()
	ids.append("found_big_pack")
	for id: String in ids:
		assert_true(GroundModels.cache_template(id, _template()))
		var piece: Dictionary = GroundLook.pieces([{"id": id, "n": 1, "pos": Vector3.ZERO}])[0]
		assert_eq(piece["model"], "", id + " stays a box even with a baked resource")


func test_rim_rotates_all_four_corners_and_keeps_uvs_attached() -> void:
	var rim: Dictionary = {"at": Vector3(5, 3, 7), "size": Vector2(2, 1), "inner": Vector2(0.8, 0.6), "yaw": PI * 0.5}
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	MapView._rim_quad(surface, rim)
	var arrays: Array = surface.commit().surface_get_arrays(0)
	var rotation := Basis(Vector3.UP, PI * 0.5)
	var corners: Array[Vector3] = [Vector3(-1, 0, -0.5), Vector3(1, 0, -0.5), Vector3(1, 0, 0.5), Vector3(-1, 0, 0.5)]
	var order: Array[int] = [0, 1, 2, 0, 2, 3]
	var uvs: Array[Vector2] = [Vector2.ZERO, Vector2(1, 0), Vector2.ONE, Vector2(0, 1)]
	for offset: int in order.size():
		assert_almost_eq((arrays[Mesh.ARRAY_VERTEX][offset] as Vector3).distance_to(rim["at"] + rotation * corners[order[offset]]), 0.0, 0.00001)
		assert_eq(arrays[Mesh.ARRAY_TEX_UV][offset], uvs[order[offset]])


func test_existing_container_rims_still_accept_box_centres() -> void:
	var rim: Dictionary = GroundLook.rim({"lv": 0, "at": Vector3(2, 0.5, 3), "size": Vector3.ONE})
	assert_almost_eq(rim["at"].y, GroundLook.RIM_LIFT, 0.00001)
	assert_eq(rim["yaw"], 0.0)
