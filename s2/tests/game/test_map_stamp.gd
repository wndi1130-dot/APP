extends "res://addons/gut/test.gd"
## 쪽지 지도의 × 도장(map_stamp.gd, 결정 카드 loot-feel M 가): 틈이 화면 안이면 그 위에,
## 밖이면 가장자리에서 그쪽을 가리키고, 필드의 side_hint가 비면(틈에 닿음) 사라진다. 글은 없다.

const MapStamp = preload("res://game/ui/map_stamp.gd")


class FakeGame extends Node3D:
	var camera: Camera3D
	var side_hint: Dictionary = {}


class FakeHud extends Node:
	var game


func test_on_the_screen_the_mark_stands_over_the_place() -> void:
	var row := MapStamp.place_on(Vector2(1280, 720), Vector2(500, 300), false)
	assert_eq(row[0], Vector2(500, 300))
	assert_false(row[1], "not at the edge")


func test_off_the_screen_it_waits_at_the_edge_toward_the_place() -> void:
	var size := Vector2(1280, 720)
	var right := MapStamp.place_on(size, Vector2(3000, 360), false)
	assert_true(right[1])
	assert_almost_eq((right[0] as Vector2).x, size.x - MapStamp.INSET, 0.01, "on the right edge")
	assert_almost_eq((right[0] as Vector2).y, 360.0, 0.01)
	assert_true((right[2] as Vector2).x > 0.9, "pointing right")
	var low := MapStamp.place_on(size, Vector2(700, 5000), false)
	assert_almost_eq((low[0] as Vector2).y, size.y - MapStamp.INSET, 0.01, "on the bottom edge")
	# Behind the camera the screen point is mirrored: the mark still points the right way.
	var behind := MapStamp.place_on(size, Vector2(700, 100), true)
	assert_true(behind[1], "behind is never on the screen")
	assert_gt((behind[0] as Vector2).y, size.y * 0.5, "toward the bottom, where the place is")


func _setup() -> Array:
	var game: FakeGame = add_child_autofree(FakeGame.new())
	game.camera = Camera3D.new()
	game.add_child(game.camera)
	game.camera.position = Vector3(0, 20, 12)
	game.camera.look_at(Vector3.ZERO)
	var hud: FakeHud = add_child_autofree(FakeHud.new())
	hud.game = game
	var stamp: Control = add_child_autofree(MapStamp.new())
	stamp.setup(hud)
	return [game, stamp]


func test_it_shows_while_the_field_holds_a_hint_and_fades_after() -> void:
	var s := _setup()
	var game: FakeGame = s[0]
	var stamp = s[1]
	stamp._process(0.1)
	assert_false(stamp.visible, "nothing read, nothing shown")
	game.side_hint = {"at": Vector3(40, 0, 30)}
	stamp._process(0.1)
	assert_true(stamp.visible)
	assert_eq(stamp.point, Vector3(40, 0, 30))
	game.side_hint = {}
	stamp._process(0.1)
	assert_true(stamp.visible, "it fades, it does not blink out")
	for i in 10:
		stamp._process(0.1)
	assert_false(stamp.visible, "gone once the gap is reached")
	assert_null(stamp.point)


func test_a_field_without_the_hint_shows_nothing() -> void:
	var hud: FakeHud = add_child_autofree(FakeHud.new())
	hud.game = add_child_autofree(Node3D.new())
	var stamp: Control = add_child_autofree(MapStamp.new())
	stamp.setup(hud)
	stamp._process(0.1)
	assert_false(stamp.visible)


## At the edge the mark slides off a key it would sit under, toward the middle.
func test_the_mark_keeps_off_the_keys() -> void:
	var mid := Vector2(640, 360)
	var corner := Vector2(1234, 674)
	var key := Rect2(1100, 560, 150, 150)
	var at := MapStamp.clear_of(corner, mid, [key])
	assert_false(key.grow(MapStamp.RADIUS + MapStamp.NOTCH).has_point(at), "clear of the key")
	assert_lt(at.distance_to(corner), corner.distance_to(mid), "still on the way out")
	assert_eq(MapStamp.clear_of(Vector2(46, 360), mid, [key]), Vector2(46, 360), "a free place stays")
