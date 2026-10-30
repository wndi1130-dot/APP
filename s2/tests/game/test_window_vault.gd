extends "res://addons/gut/test.gd"
## Someone climbing through a window's frame is heard (field_audio window_vault,
## from field_actions vault_window, once as they come into the frame): the
## player's ear only, no sound the dead hear. Cloth over the sill, and while
## broken glass is still in the frame the glass too; a boarded window is not
## climbed, so nothing. A companion's climb is softer the farther off it is.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")

var game


func before_each() -> void:
	seed(20261030)
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


## A whole, bare window on the ground with floor on both faces, open now.
func _open_window() -> Vector2i:
	var keys: Array = game.grid.windows.keys()
	keys.sort()
	for c: Vector2i in keys:
		var w: Dictionary = game.grid.windows[c]
		if w["broken"] or game.grid.outer_face(c) < 0 or BuildingRules.planks_total(w) > 0:
			continue
		var f: Array[Vector2i] = game.grid.faces(c)
		if f.size() == 2 and game.grid.people_can_walk(f[0]) and game.grid.people_can_walk(f[1]):
			w["open"] = true
			game.grid.refresh_cell(c)
			return c
	return Vector2i(-1, -1)


## The player runs from one face of `c` at it, the stick held (running: not
## stopped to be asked about glass in the frame). True once on the far face.
func _run_through(c: Vector2i) -> bool:
	var f: Array[Vector2i] = game.grid.faces(c)
	var p = game.player
	p.position = FieldGrid.center(f[0])
	p.stop()
	p.running = true
	var toward: Vector3 = FieldGrid.center(f[1]) - FieldGrid.center(f[0])
	p.stick = Vector2(toward.x, toward.z).normalized()
	var through := false
	for i in range(80):
		game._update_person(p, 0.05)
		if FieldGrid.cell_of(p.position) == f[1]:
			through = true
			break
	p.stick = Vector2.ZERO
	return through


## One of the squad who is not the player (the player is game.squad[0]).
func _companion():
	for s in game.squad:
		if s != game.player:
			return s
	return null


func test_running_through_an_open_window_is_heard_once_coming_into_the_frame() -> void:
	var c := _open_window()
	assert_ne(c, Vector2i(-1, -1), "a window with floor on both faces")
	var a = game.audio
	a.played.clear()
	assert_true(_run_through(c), "through to the far face")
	assert_eq(a.played.count("window_vault"), 1, "once, not again on the way out")
	assert_false(a.played.has("window_vault_glass"), "no glass in an open window")


func test_a_frame_with_its_broken_glass_still_in_crunches_too_until_the_glass_is_out() -> void:
	var c := _open_window()
	assert_ne(c, Vector2i(-1, -1))
	game.grid.break_window(c)
	assert_true(bool(game.grid.windows[c]["glass"]), "the glass still in the frame")
	var a = game.audio
	a.played.clear()
	assert_true(_run_through(c))
	assert_eq(a.played.count("window_vault"), 1)
	assert_eq(a.played.count("window_vault_glass"), 1, "the glass in the frame too")
	game.actions._clear_glass(c)
	a.played.clear()
	assert_true(_run_through(c))
	assert_eq(a.played.count("window_vault"), 1)
	assert_false(a.played.has("window_vault_glass"), "the glass out: the cloth alone")


func test_a_boarded_window_is_not_climbed_so_nothing_is_heard() -> void:
	var c := _open_window()
	assert_ne(c, Vector2i(-1, -1))
	BuildingRules.add_plank(game.grid.windows[c], 0)
	game.grid.refresh_cell(c)
	var a = game.audio
	a.played.clear()
	assert_false(_run_through(c), "the planks stop the way")
	assert_false(a.played.has("window_vault"))


func test_a_companion_climbing_through_is_softer_the_farther_off_and_the_dead_hear_nothing() -> void:
	var c := _open_window()
	assert_ne(c, Vector2i(-1, -1))
	var q = _companion()
	assert_not_null(q, "a companion in the squad")
	q.position = FieldGrid.center(game.grid.faces(c)[0])
	q.stop()
	var a = game.audio
	a.played.clear()
	a.last_tag_group = "none"
	var heard: int = game.ledger.sound_events
	game.player.position = FieldGrid.center(c) + Vector3(1.5, 0, 0)
	game.actions.vault_window(q, c)
	assert_true(a.played.has("window_vault"), "a companion's climb is heard")
	assert_not_null(a.last_shot)
	assert_true(a.last_shot.stream in a.lib["swing_light"], "a light swing stands in")
	var near_db: float = a.last_shot.volume_db
	game.player.position = FieldGrid.center(c) + Vector3(30, 0, 0)
	game.actions.vault_window(q, c)
	assert_not_null(a.last_shot)
	assert_lt(a.last_shot.volume_db, near_db - 3.0, "farther off, softer")
	assert_eq(game.ledger.sound_events, heard, "no sound the dead hear")
	assert_eq(a.last_tag_group, "none")
