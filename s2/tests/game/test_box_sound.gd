extends "res://addons/gut/test.gd"
## 여닫는 소리는 효과음(카드 R3 가, 결정 469): 가구 갈래마다 열기·닫기·넣기·빼기 소리, 여닫기
## 사이는 0.5초, 망자는 듣지 않는다(make_sound 꼬리표 없음). 뒤지는 동안 망자가 듣는 소리는 큰
## 상자에만 남는다 — 처음 한 번, 그 뒤 4초마다.

const FieldGame = preload("res://game/field_game.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")


func _game() -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	return game


## A box on the ground floor made `furniture`, the player at it, holding `items`.
func _box(game, furniture: String, items: Array = ["food_pack"], searched: bool = false) -> String:
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if int(c.get("level", 0)) == 0 and not bool(c.get("locked", false)) and not c.has("pick"):
			c["furniture"] = furniture
			c["searched"] = searched
			c["items"] = items.duplicate()
			game.player.position = game.actions._container_at(c)
			game.player.stop()
			return String(id)
	return ""


func _heard(game) -> int:
	return int((game.ledger.by_action.get("search", {"events": 0}) as Dictionary)["events"])


func _since(game, n: int) -> Array:
	return game.audio.played.slice(n)


func test_only_a_big_box_s_rummage_is_heard() -> void:
	assert_true(SearchRules.rummage_heard({"furniture": "wardrobe"}), "a wardrobe takes three seconds")
	assert_true(SearchRules.rummage_heard({}), "a box of its own is a crate")
	for f: String in ["nightstand", "dresser", "cupboard", "shelf", "workbench", "fridge_open"]:
		assert_false(SearchRules.rummage_heard({"furniture": f}), f + ": no world sound")
	var game = _game()
	var p = game.player
	var small := _box(game, "dresser")
	game.actions.search(p, small)
	assert_eq(p.action, "search")
	game.actions.search_noise(p, SearchRules.NOISE_EVERY + 1.0)
	assert_eq(_heard(game), 0, "a dresser is looked into unheard")
	var game2 = _game()
	var p2 = game2.player
	var big := _box(game2, "wardrobe")
	game2.actions.search(p2, big)
	assert_eq(_heard(game2), 1, "the wardrobe's first rummage at once")
	game2.actions.search_noise(p2, SearchRules.NOISE_EVERY)
	assert_eq(_heard(game2), 2, "and one every four seconds")


func test_each_kind_its_sounds_and_the_half_second() -> void:
	var game = _game()
	var a = game.audio
	var c: Dictionary = game.data["containers"][_box(game, "dresser")]
	a.box_quiet_until = 0
	var n: int = a.played.size()
	assert_true(a.box_sound(c, "open"))
	assert_eq(_since(game, n), ["box_open_drawer"])
	c["furniture"] = "wardrobe"
	assert_false(a.box_sound(c, "close"), "within half a second of the last: none")
	a.box_quiet_until = 0
	assert_true(a.box_sound(c, "close"))
	assert_eq(a.played[-1], "box_close_door")
	a.box_quiet_until = 0
	c["furniture"] = "shelf"
	assert_false(a.box_sound(c, "open"), "an open shelf has nothing to open")
	assert_true(a.box_sound(c, "take"))
	assert_true(a.box_sound(c, "put"), "in and out are not held back by the half second")
	assert_eq(a.played.slice(-2), ["box_take", "box_put"])
	for f: String in ["", "blanket_chest", "toolbox", "medicine_cabinet", "counter"]:
		a.box_quiet_until = 0
		c["furniture"] = f
		assert_true(a.box_sound(c, "open"), "'%s' opens with a sound" % f)


func test_the_pane_opens_the_box_once_and_shuts_it_once() -> void:
	var game = _game()
	var hud = game.hud
	var a = game.audio
	var id := _box(game, "dresser", ["food_pack"], true)
	a.box_quiet_until = 0
	var n: int = a.played.size()
	hud.loot(id)
	assert_eq(_since(game, n), ["box_open_drawer"], "the box the pane comes to opens")
	a.box_quiet_until = 0
	hud.loot(id)
	assert_eq(_since(game, n), ["box_open_drawer"], "laid again (a row taken): nothing more")
	hud._close_modal()
	a.box_quiet_until = 0
	hud.tick(0.016)
	assert_eq(_since(game, n), ["box_open_drawer", "box_close_drawer"], "put away: it shuts")
	assert_eq(hud.box_shown, "")
	# The rummage stays unheard: the pane's sounds are no world sound.
	assert_eq(_heard(game), 0)


func test_taking_sounds_once_as_it_starts_and_putting_each_time() -> void:
	var game = _game()
	var p = game.player
	var a = game.audio
	p.items.clear()
	var id := _box(game, "dresser", ["food_pack", "bandage"], true)
	var n: int = a.played.size()
	game.actions.take_all(p, id)
	assert_eq(p.action, "take")
	p.action_t = 0.001
	game._update_person(p, 0.1)
	assert_eq(p.action, "take", "the next one coming out")
	assert_eq(_since(game, n).count("box_take"), 1, "one sound for 「모두 담기」")
	p.cancel_action()
	game.actions.take_queue.clear()
	p.items["bandage"] = 1
	var m: int = a.played.size()
	assert_true(game.actions.store(p, id, "bandage"))
	assert_eq(_since(game, m), ["box_put"])


func test_taking_one_sounds_once() -> void:
	var game = _game()
	var p = game.player
	var a = game.audio
	p.items.clear()
	var id := _box(game, "dresser", ["food_pack"], true)
	var n: int = a.played.size()
	game.actions.take(p, id, 0)
	assert_eq(p.action, "take")
	assert_eq(_since(game, n), ["box_take"])


## The four are for the ear: nothing the dead hear is made, and the impact file that stands
## in for an empty group is what plays.
func test_the_box_sounds_are_no_world_sound_and_a_stand_in_plays() -> void:
	var game = _game()
	var a = game.audio
	var c: Dictionary = game.data["containers"][_box(game, "dresser")]
	game.sounds.clear()
	for what: String in ["open", "close", "put", "take"]:
		a.box_quiet_until = 0
		assert_true(a.box_sound(c, what), what)
	assert_eq(game.sounds.size(), 0, "nothing the dead hear")
	a.box_quiet_until = 0
	assert_true(a.box_sound(c, "open"))
	assert_not_null(a.last_shot, "the stand-in is heard")
	if a.last_shot != null:
		assert_true(a.last_shot.stream.resource_path.get_file().begins_with("wooden"), "a drawer stands in with wood")
	assert_false(a.box_sound({}, "open"), "no box on the map, no sound")


func test_another_panel_in_its_place_shuts_the_box() -> void:
	var game = _game()
	var hud = game.hud
	var a = game.audio
	var id := _box(game, "dresser", ["food_pack"], true)
	a.box_quiet_until = 0
	hud.loot(id)
	var n: int = a.played.size()
	a.box_quiet_until = 0
	hud._open_pane("다른 창")
	hud.tick(0.016)
	assert_eq(_since(game, n), ["box_close_drawer"], "the pane gone under another: the box shuts at once")
	assert_eq(hud.box_shown, "")
	hud.box_shown_now("no_such_box")
	hud.box_shown_now("")
	assert_eq(_since(game, n), ["box_close_drawer"], "a box not on the map sounds nothing")


func test_from_the_box_to_the_ground_the_box_shuts() -> void:
	var game = _game()
	var hud = game.hud
	var a = game.audio
	var id := _box(game, "dresser", ["food_pack"], true)
	a.box_quiet_until = 0
	hud.loot(id)
	var n: int = a.played.size()
	a.box_quiet_until = 0
	hud._inv_place({"kind": "ground", "id": "", "name": "바닥"})
	assert_eq(_since(game, n), ["box_close_drawer"], "the ground has no lid")
	assert_eq(hud.box_shown, "")
