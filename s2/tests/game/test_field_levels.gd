extends "res://addons/gut/test.gd"
## Floors (build 21, user after build 20): upstairs, the cellar, stairs between
## them, sight out of upstairs windows, the dead on other floors.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const SulehufMap = preload("res://game/world/sulehuf_map.gd")
const SimNoise = preload("res://game/sim/noise.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 21, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


func _zombie(at: Vector3) -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", at)
	z["angle"] = 0.0
	return z


func _levels_on(path: PackedVector3Array) -> Array:
	var out: Array = []
	for q in path:
		var lv: int = game.level_of(q)
		if out.is_empty() or out[-1] != lv:
			out.append(lv)
	return out


func test_map_is_about_twice_the_old_one() -> void:
	# Build 20 was 120 x 70; twenty minutes should no longer cover it.
	assert_gte(SulehufMap.WIDTH * SulehufMap.HEIGHT, 2 * 120 * 70)
	for lv in [-1, 1, 2]:
		assert_true(game.levels.has(lv), "level %d exists" % lv)


func test_every_entry_reaches_the_platform_across_floors() -> void:
	var platform: Vector3 = game.lift(Vector2i(50, 6), 0)
	for key in game.data["entries"]:
		var path: PackedVector3Array = game.find_path(game.entry_pos(key), platform, false)
		assert_gt(path.size(), 0, "%s reaches the platform" % key)
		if path.size() > 0:
			assert_eq(game.level_of(path[path.size() - 1]), 0, "%s ends on the ground" % key)


func test_every_container_can_be_reached_on_its_floor() -> void:
	var start: Vector3 = game.player.position
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		var lv: int = int(c["level"])
		if int(c["building"]) == 1 and lv == 1:
			continue   # up the signal box ladder: an action, not a path
		var at: Vector3 = game.walkable_near(game.lift(c["cell"], lv), false, 2)
		var path: PackedVector3Array = game.find_path(start, at, false)
		assert_gt(path.size(), 0, "%s reachable" % id)
		if path.size() > 0:
			assert_eq(game.level_of(path[path.size() - 1]), lv, "%s on its floor" % id)


func test_path_to_the_top_floor_climbs_each_stair() -> void:
	var top: Vector3 = game.walkable_near(game.lift(Vector2i(122, 42), 2))
	var path: PackedVector3Array = game.find_path(game.lift(Vector2i(116, 36), 0), top, false)
	assert_eq(_levels_on(path), [0, 1, 2])
	var cellar: Vector3 = game.walkable_near(game.lift(Vector2i(106, 42), -1))
	path = game.find_path(top, cellar, false)
	assert_eq(_levels_on(path), [2, 1, 0, -1])


func test_a_person_walks_up_the_stairs() -> void:
	var p = game.player
	p.position = game.lift(Vector2i(70, 44), 0)
	p.go_to(game.find_path(p.position, game.walkable_near(game.lift(Vector2i(76, 46), 1)), false), false)
	for i in range(400):
		game._update_person(p, 0.05)
		if p.path.is_empty():
			break
	assert_eq(game.level_of(p.position), 1, "upstairs now")
	assert_true(p.upstairs)


func test_upstairs_window_sees_the_street_below() -> void:
	var p = game.player
	p.position = game.lift(Vector2i(71, 39), 1)
	p.facing = PI   # north, toward the window at (71, 38) and the street
	game._refresh_vision()
	var n: int = game.grid.width * game.grid.height
	var street := Vector2i(71, 33)
	assert_true(game.seen_now.has(n + game.grid.index(street)), "the street is seen on the ground slice")
	assert_true(game.cell_seen(game.lift(street, 0)))
	assert_false(game.cell_seen(game.lift(Vector2i(71, 44), 0)), "not the room under your feet")


func test_from_the_ground_upstairs_is_not_seen() -> void:
	var p = game.player
	p.position = game.lift(Vector2i(71, 34), 0)
	p.facing = 0.0   # south, at the house
	game._refresh_vision()
	assert_false(game.cell_seen(game.lift(Vector2i(71, 39), 1)))
	assert_false(game.level_shown(1))
	assert_true(game.level_shown(0))


func test_cellar_shows_alone_and_sees_little() -> void:
	var p = game.player
	p.position = game.lift(Vector2i(112, 50), -1)
	game._refresh_vision()
	assert_true(game.level_shown(-1))
	assert_false(game.level_shown(0))
	assert_false(game.cell_seen(game.lift(Vector2i(126, 50), -1)), "far end of the cellar is dark")


func test_the_dead_do_not_see_through_a_floor() -> void:
	var p = game.player
	p.position = game.lift(Vector2i(75, 44), 1)
	for q in game.squad:
		if q != p:
			q.position = game.lift(Vector2i(50, 6), 0)
	var z := _zombie(game.lift(Vector2i(75, 45), 0))
	game.zombies._sense(z, [p], 0.2)
	assert_ne(z["state"], "chase", "right under the player, but a floor between")


func test_sound_through_a_floor_is_halved() -> void:
	var below := _zombie(game.lift(Vector2i(75, 45), 0))
	var same := _zombie(game.lift(Vector2i(71, 45), 1))
	var at: Vector3 = game.lift(Vector2i(76, 45), 1)
	game.zombies.hear(at, SimNoise.Level.NORMAL, 5.5)
	assert_eq(same["state"], "investigate", "same floor, 5 m: heard")
	assert_eq(below["state"], "wander", "one floor down, 3.2 m: the floor halves 5.5 m")


func test_the_dead_follow_a_sound_up_the_stairs() -> void:
	var z := _zombie(game.lift(Vector2i(115, 45), 0))
	game.zombies.hear(game.lift(Vector2i(116, 44), 1), SimNoise.Level.LOUD, 30.0)
	z["turn_t"] = 0.0
	for i in range(600):
		game.zombies._move(z, 0.05)
	assert_eq(game.level_of(z["pos"]), 1, "climbed to where the noise was")


func test_cellar_drain_is_a_sewer_mouth_down_in_the_cellar() -> void:
	assert_eq(game.level_of(game.sewer_pos("cellar")), -1)
	assert_true(game.director.is_open("cellar"))
	assert_eq(game.level_of(game.entry_pos("cellar")), -1)


func test_signal_box_ladder_is_never_a_path() -> void:
	var top: Vector3 = game.lift(Vector2i(106, 9), 1)
	var path: PackedVector3Array = game.find_path(game.lift(Vector2i(100, 9), 0), top, false)
	assert_gt(path.size(), 0, "walks to under it")
	assert_eq(game.level_of(path[path.size() - 1]), 0, "but stays on the ground")


# ---------------------------------------------------------------- finding floors (H3 2026-10-09)

func _labels_at(c: Vector2i, lv: int) -> Array:
	var out: Array = []
	for row in game.view.label_nodes:
		if row[1] == c and int(row[2]) == lv:
			out.append(row[0].text)
	return out


func test_every_stair_is_named_on_both_floors() -> void:
	var names := {-1: "지하로", 0: "1층으로", 1: "2층으로", 2: "3층으로"}
	var seen := 0
	for s in game.stairs:
		if s["ladder"]:
			continue
		assert_has(_labels_at(s["cell"], s["low"]), names[s["high"]])
		assert_has(_labels_at(s["cell"], s["high"]), names[s["low"]])
		seen += 1
	assert_gt(seen, 0, "the map has stairs")


func test_the_cellar_stair_says_down_to_the_cellar_from_the_ground() -> void:
	var found := false
	for s in game.stairs:
		if not s["ladder"] and s["low"] == -1:
			found = found or _labels_at(s["cell"], 0).has("지하로")
	assert_true(found)


func test_stair_names_wait_until_the_spot_is_seen() -> void:
	var memory := PackedByteArray()
	memory.resize(4 * game.grid.width * game.grid.height)
	game.view.update_labels(memory, true)
	for row in game.view.label_nodes:
		assert_false(row[0].visible, "nothing is named before it is seen")


func test_the_street_manhole_is_named() -> void:
	var c: Vector2i = game.data["manholes"]["manhole"]
	var named := false
	for row in game.view.label_nodes:
		named = named or (row[0].text == "맨홀" and int(row[2]) == 0 and (row[1] - c).length() <= 1.5)
	assert_true(named)


func test_the_driver_says_once_how_to_shut_the_manhole() -> void:
	game.lid_tip_told = false
	game.director.next_entry = "manhole"
	var tip: String = game.lid_tip()
	assert_string_contains(tip, "판자나 고철")
	assert_eq(game.lid_tip(), "", "only once")


func test_no_manhole_tip_when_the_next_wave_comes_elsewhere_or_it_is_shut() -> void:
	game.lid_tip_told = false
	game.director.next_entry = "culvert"
	assert_eq(game.lid_tip(), "")
	game.director.next_entry = "manhole"
	game.director.block("manhole")
	assert_eq(game.lid_tip(), "", "already shut")
