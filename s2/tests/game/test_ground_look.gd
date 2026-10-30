extends "res://addons/gut/test.gd"
## What lies on the ground is drawn (ground_look.gd, map_view.update_ground): a
## shape of its kind on its floor, no heaps, the shining ones left to their light.

const GroundLook = preload("res://game/world/ground_look.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const TwoLids = preload("res://tests/game/fixtures/two_lids_map.gd")
const MapView = preload("res://game/world/map_view.gd")


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
	assert_almost_eq(Vector2(out[0]["at"].x, out[0]["at"].z).distance_to(Vector2(at.x, at.z)), 0.0, 0.001, "the first lies where it was put")
	var spots := {}
	for piece: Dictionary in out:
		var flat := Vector2(piece["at"].x, piece["at"].z)
		assert_true(flat.distance_to(Vector2(at.x, at.z)) < 0.9, "within a tap of where it lies")
		spots[flat.snapped(Vector2(0.01, 0.01))] = true
	assert_eq(spots.size(), out.size(), "none on top of another")
	# Another cell gets its own three.
	items.append({"pos": at + Vector3(3, 0, 0), "id": "cloth", "n": 1})
	assert_eq(GroundLook.pieces(items).size(), GroundLook.PER_CELL + 1)


func test_it_lies_on_its_own_floor() -> void:
	var items := [
		{"pos": Vector3(4.5, 3.0, 4.5), "id": "can_beans", "n": 1},
		{"pos": Vector3(4.5, -3.0, 4.5), "id": "plank", "n": 1},
	]
	var out: Array = GroundLook.pieces(items)
	assert_eq(out[0]["lv"], 1)
	assert_almost_eq(float(out[0]["at"].y), 3.0 + out[0]["size"].y / 2.0, 0.001, "on the floor above, not in the air")
	assert_eq(out[1]["lv"], -1)
	assert_almost_eq(float(out[1]["at"].y), -3.0 + out[1]["size"].y / 2.0, 0.001)
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
