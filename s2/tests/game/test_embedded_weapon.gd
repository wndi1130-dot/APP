extends "res://addons/gut/test.gd"
## 몸에 박힌 무기(결정 423 카드 2): 처음 서 있던 망자 가운데 드물게 등에 도끼가 박혀 있고,
## 쓰러뜨려 뒤지면 그 도끼가 나온다. 무리로 온 것과 언 것에는 없다.

const FieldGame = preload("res://game/field_game.gd")
const Zombies = preload("res://game/actors/zombies.gd")

var game


func _start(seed_value: int = 5) -> void:
	game = FieldGame.new()
	game.opts = {"seed": seed_value, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)


func _embedded_ids() -> Array:
	var out: Array = []
	for z in game.zombies.list:
		if z.has("embedded"):
			out.append(z["id"])
	return out


func test_few_of_the_first_dead_have_one_and_never_more_than_the_cap() -> void:
	_start()
	game.zombies.list.clear()
	for i in range(400):
		game.zombies.spawn("dead", game.lift(Vector2i(40 + i % 20, 20 + i / 20), 0))
	var n: int = game.zombies.embed_weapons()
	assert_eq(n, Zombies.EMBED_MAX, "400 가운데 3%면 상한에 닿는다")
	assert_eq(_embedded_ids().size(), Zombies.EMBED_MAX)


func test_not_on_a_horde_nor_on_the_frozen() -> void:
	_start()
	game.zombies.list.clear()
	for i in range(300):
		game.zombies.spawn("dead", game.lift(Vector2i(40, 20), 0), {"horde": 1, "target": game.lift(Vector2i(41, 20), 0)})
		game.zombies.spawn("frozen", game.lift(Vector2i(42, 20), 0))
	assert_eq(game.zombies.embed_weapons(), 0)


func test_its_pockets_give_the_axe_and_then_it_is_no_longer_drawn() -> void:
	_start()
	game.zombies.list.clear()
	var z: Dictionary = game.zombies.spawn("dead", game.lift(Vector2i(40, 20), 0))
	z["embedded"] = Zombies.EMBED_TOOL
	assert_true(game.zombies.shows_embedded(z))
	game.zombies.knock_down(z)
	var axes := 0
	for row: Dictionary in z["loot"]:
		if row.get("weapon", {}).get("id", "") == Zombies.EMBED_TOOL:
			axes += 1
	assert_eq(axes, 1, "확정 물건")
	z["searched"] = true
	assert_false(game.zombies.shows_embedded(z))


func test_same_seed_same_dead_with_an_axe() -> void:
	_start(11)
	var a := _embedded_ids()
	_start(11)
	assert_eq(_embedded_ids(), a)
	assert_lte(a.size(), Zombies.EMBED_MAX)


func test_the_axe_has_its_model() -> void:
	_start()
	assert_not_null(game.zombies.embedded_draw, "res://models/weapons/axe.glb")
