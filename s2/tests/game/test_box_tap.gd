extends "res://addons/gut/test.gd"
## 상자 누르기(결정 476 대각뷰, 442): 손가락 줄이 그려진 가구 높이 안에서 처음 만나는 상자,
## 없으면 줄이 가장 가까이 지나는 상자를 고른다. 바닥점에서 1.0 m 안 「첫 상자」를 고르던 때는
## 줄지은 조리대에서 옆 칸이 열리고, 조리대 윗면·찬장 위쪽을 누르면 아무것도 안 열렸다.

const FieldGame = preload("res://game/field_game.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 4, "place": "houses_01", "raiders": false, "auto_pause": false, "arrive": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


## Stand by the box and point the camera as in play.
func _look_at(c: Dictionary) -> void:
	game.player.position = game.walkable_near(game.lift(c["cell"], 0), false, 2)
	game._update_camera(1.0)


## A finger on the box as drawn, h metres above its floor.
func _press(c: Dictionary, h: float) -> String:
	var s: Vector2 = game.camera.unproject_position(game.lift(c["cell"], 0) + Vector3(0, h, 0))
	return game.hud._pick_box(game.screen_to_ground(s))


## Ground-floor boxes of one furniture kind, in a building, by id.
func _boxes(kinds: Dictionary) -> Array:
	var out: Array = []
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if int(c.get("level", 0)) == 0 and int(c.get("building", -1)) >= 0 and kinds.has(String(c.get("furniture", ""))):
			out.append(String(id))
	out.sort()
	return out


func test_a_row_of_counters_opens_the_one_pressed_at_its_front_and_top() -> void:
	var counters := _boxes({"counter": true})
	var row: Array = []
	# Three counters side by side.
	for id: String in counters:
		var c: Vector2i = game.data["containers"][id]["cell"]
		var side := [id]
		for other: String in counters:
			var o: Vector2i = game.data["containers"][other]["cell"]
			if other != id and absi(o.x - c.x) + absi(o.y - c.y) == 1:
				side.append(other)
		if side.size() >= 3:
			row = side
			break
	assert_eq(row.size(), 3, "houses_01 has a row of counters")
	var missed: Array = []
	for id: String in row:
		var c: Dictionary = game.data["containers"][id]
		_look_at(c)
		for h in [0.0, 0.45, 0.9]:
			var got := _press(c, h)
			if got != id:
				missed.append("%s %.2f → %s" % [id, h, got])
	assert_eq(missed, [], "the counter pressed is the one opened")


func test_a_tall_piece_is_picked_anywhere_up_its_front() -> void:
	var tall := _boxes(RoomFurnish.TALL_KINDS)
	assert_gt(tall.size(), 0)
	var missed: Array = []
	for id: String in tall.slice(0, 6):
		var c: Dictionary = game.data["containers"][id]
		_look_at(c)
		for h in [0.9, 1.5]:
			var got := _press(c, h)
			if got != id:
				missed.append("%s %s %.2f → %s" % [id, c.get("furniture", ""), h, got])
	assert_eq(missed, [], "a wardrobe or a cupboard pressed high is the one opened")


func test_a_press_far_from_every_box_picks_none() -> void:
	var id: String = _boxes({"counter": true})[0]
	var c: Dictionary = game.data["containers"][id]
	_look_at(c)
	var world: Vector3 = game.lift(c["cell"], 0)
	assert_eq(game.hud._pick_box(world), id, "on the counter's own floor")
	assert_eq(game.hud._pick_box(world + Vector3(30, 0, 30)), "", "nothing within reach")


func test_the_box_height_follows_the_furniture() -> void:
	var hud = game.hud
	assert_eq(hud._box_h({"furniture": "cupboard"}), hud.BOX_TALL_H)
	assert_eq(hud._box_h({"furniture": "counter"}), hud.BOX_H)
	assert_eq(hud._box_h({}), hud.BOX_LOOSE_H)
	assert_eq([hud.BOX_TALL_H, hud.BOX_H, hud.BOX_LOOSE_H, hud.ITEM_H], [1.9, 0.9, 0.55, 0.3])
	# A body still reads feet to head (the dead are picked as before).
	assert_eq(hud.BODY_H, 1.7)
