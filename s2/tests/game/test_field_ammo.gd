extends "res://addons/gut/test.gd"
## Ammo on the receipt counts the rounds fired from the magazine, not only
## the ones taken from the reserve on reload (A2 code review, 2026-10-07).

const FieldGame = preload("res://game/field_game.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


func _stock(key: String) -> int:
	var stock: Dictionary = game.receipt.to_dict().get("stock", {})
	return int(stock.get(key, 0))


## Pull the trigger until n rounds have left the gun (jams clear in between).
func _fire_rounds(n: int) -> int:
	var p = game.player
	p.hands = [{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 8}]
	var before: int = int(p.weapon()["loaded"])
	var guard := 0
	while before - int(p.weapon()["loaded"]) < n and guard < 200:
		guard += 1
		p.jam_t = 0.0
		p.reload_t = 0.0
		game.combat.fire(p, p.position + Vector3(6, 0, 0))
	return before - int(p.weapon()["loaded"])


func test_rounds_fired_from_the_magazine_leave_the_stock() -> void:
	var p = game.player
	# The squad ammo total at the start includes what is already loaded.
	game.ammo_start = game.ammo.duplicate()
	game.loaded_start = game.loaded_totals()
	assert_eq(_fire_rounds(3), 3)
	p.position = game.lift(Vector2i(50, 6), 0)
	game.finish("departed")
	assert_eq(_stock("ammo_pistol"), -3, "three pistol rounds went out of the gun")


func test_found_rounds_still_count_as_a_gain() -> void:
	game.ammo["pistol"] = int(game.ammo["pistol"]) + 6
	game.player.position = game.lift(Vector2i(50, 6), 0)
	game.finish("departed")
	assert_eq(_stock("ammo_pistol"), 6)


func test_a_gun_left_with_someone_left_behind_loses_its_rounds() -> void:
	var marek = game.squad[1]
	var loaded: int = int(marek.hands[0]["loaded"])
	assert_gt(loaded, 0, "Marek's shotgun starts loaded")
	for q in game.squad:
		q.position = game.lift(Vector2i(50, 6), 0)
	marek.position = game.lift(Vector2i(60, 66), 0)
	game.finish("departed")
	assert_eq(_stock("ammo_shell"), -loaded, "the shells in his gun stay with him")
