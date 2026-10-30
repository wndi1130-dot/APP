extends "res://addons/gut/test.gd"
## 빈 상자는 열기 전부터 다르게(카드 P3 가, 결정 472): 비어 있고 잠기지 않은 상자(목표 기록 상자
## 빼고)는 바닥 네 귀퉁이 표시를 상자 그림에 함께 그린다 — 그래서 상자가 보일 때만 보인다. 동료는
## 그런 상자에 들르지 않는다.

const FieldGame = preload("res://game/field_game.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")


func _game() -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	return game


func test_which_boxes_show_they_are_empty() -> void:
	assert_true(SearchRules.shows_empty({"items": [], "locked": false}))
	assert_true(SearchRules.shows_empty({"items": [], "locked": false, "searched": true}), "searched and left empty")
	assert_false(SearchRules.shows_empty({"items": ["scrap"], "locked": false}))
	assert_false(SearchRules.shows_empty({"items": [], "locked": true}), "a locked one must be opened to know")
	assert_false(SearchRules.shows_empty({"items": [], "locked": false, "pick": "quiet"}), "nor a goal's record box")
	assert_false(SearchRules.shows_empty({}))


## The chunk's rim colours (contact_shade quads under the marks), none when no box there shows empty.
func _rim_colours(game, id: String) -> PackedColorArray:
	var node: MeshInstance3D = game.view.container_chunks[game.view._container_chunk[id]]["node"]
	var rim := node.get_node_or_null("Rim") as MeshInstance3D
	if rim == null or rim.mesh == null:
		return PackedColorArray()
	return rim.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]


func _roofed(colours: PackedColorArray) -> int:
	var n := 0
	for c: Color in colours:
		if c.a < 0.5:
			n += 1
	return n


func test_the_mark_lies_on_dark_rims_kept_full_under_a_roof() -> void:
	# The pale corners alone sink into a pale room floor (loot-feel's 0.085); a dark rim under each
	# bar, as the ground things have, marked under a roof so deep winter's snow does not halve it.
	var game = _game()
	var id := ""
	for key in game.data["containers"]:
		var c: Dictionary = game.data["containers"][key]
		if not c["locked"] and not c.has("pick") and String(key) != "bell" and int(c.get("level", 0)) == 0 \
				and game.view.grid.indoor(c["cell"]):
			id = String(key)
			break
	assert_ne(id, "", "a box indoors")
	var c: Dictionary = game.data["containers"][id]
	c["items"] = ["scrap"]
	game.view.update_container(id)
	var full := _rim_colours(game, id)
	c["items"] = []
	game.view.update_container(id)
	var empty := _rim_colours(game, id)
	assert_eq(empty.size() - full.size(), 8 * 6, "a quad under each of the eight bars")
	assert_eq(_roofed(empty) - _roofed(full), 8 * 6, "all of them under the roof")
	c["items"] = ["scrap"]
	game.view.update_container(id)
	assert_eq(_rim_colours(game, id).size(), full.size(), "something in it: no rims")


func _vertices(game, id: String) -> int:
	var mesh: Mesh = game.view.container_mesh(id)
	var n := 0
	for s in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n


func test_the_mark_is_drawn_with_the_box() -> void:
	var game = _game()
	var id := ""
	for key in game.data["containers"]:
		var c: Dictionary = game.data["containers"][key]
		if not c["locked"] and not c.has("pick") and String(key) != "bell":
			id = String(key)
			break
	assert_ne(id, "")
	var c: Dictionary = game.data["containers"][id]
	c["items"] = ["scrap"]
	game.view.update_container(id)
	var full := _vertices(game, id)
	c["items"] = []
	game.view.update_container(id)
	assert_gt(_vertices(game, id), full, "an empty box carries its corners")
	c["locked"] = true
	game.view.update_container(id)
	var locked := _vertices(game, id)
	c["locked"] = false
	c["items"] = ["scrap"]
	game.view.update_container(id)
	assert_eq(_vertices(game, id), full, "something in it: no mark")
	assert_gt(locked, 0)


func test_a_companion_passes_a_box_that_shows_empty() -> void:
	var game = _game()
	var p = game.player
	var near_lv: int = game.level_of(p.position)
	var first := ""
	for key in game.data["containers"]:
		var c: Dictionary = game.data["containers"][key]
		if int(c.get("level", 0)) == near_lv and not c["locked"] and not c["searched"] and not c.has("pick"):
			first = String(key)
			break
	assert_ne(first, "")
	var box: Dictionary = game.data["containers"][first]
	p.position = game.walkable_near(game.lift(box["cell"], near_lv), false, 2)
	box["items"] = ["scrap"]
	game.ai._help_ok = false
	assert_has(game.ai._help_near().map(func(r: Array) -> String: return String(r[0])), first, "worth the stop")
	box["items"] = []
	game.ai._help_ok = false
	assert_does_not_have(game.ai._help_near().map(func(r: Array) -> String: return String(r[0])), first, "seen empty: passed by")
