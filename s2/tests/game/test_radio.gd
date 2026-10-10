extends "res://addons/gut/test.gd"
## The radio can be turned down, and a call rings where the chief stands
## (user 2026-10-11, decisions 032): more talk, more to know, more rings.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.radio_last = -INF
	game.radio_rings.clear()


func _call(text: String, kind: String, at = null) -> bool:
	game.radio_wait = {}
	game.set_radio(text, kind, at)
	var taken: bool = not game.radio_wait.is_empty()
	game._tick_radio(game.RADIO_HISS + 0.01)
	return taken


func test_the_default_calls_only_a_horde_coming_in() -> void:
	assert_eq(game.radio_mode(), "urgent")
	assert_false(_call("예보", "info"))
	assert_true(_call("들어온다", "urgent"))
	assert_eq(game.radio, "들어온다")
	assert_eq(game.radio_rings.size(), 1)


func test_often_calls_the_rest_too_and_off_only_the_call_to_leave() -> void:
	game.opts["radio"] = "often"
	assert_true(_call("예보", "info"))
	game.opts["radio"] = "off"
	game.radio_last = -INF
	assert_false(_call("들어온다", "urgent"))
	assert_false(_call("예보", "info"))
	assert_false(_call("물이 나온다", "reply"))
	assert_true(_call("떠나야 한다", "must"))
	assert_eq(game.radio, "떠나야 한다")


func test_calls_keep_their_distance_in_time() -> void:
	game.clock.elapsed = 100.0
	assert_true(_call("하나", "urgent"))
	game.clock.elapsed = 100.0 + game.RADIO_GAP["urgent"] - 1.0
	assert_false(_call("둘", "urgent"), "too soon")
	assert_true(_call("물", "reply"), "an answer to what you did comes anyway")
	assert_true(_call("떠나야 한다", "must"), "and so does the call to leave")
	game.clock.elapsed = 400.0
	assert_true(_call("셋", "urgent"))
	game.opts["radio"] = "often"
	game.clock.elapsed = 400.0 + game.RADIO_GAP["often"] + 1.0
	assert_true(_call("넷", "info"), "often: the gap is short")


func test_the_set_hisses_first_then_speaks_and_rings() -> void:
	var p = game.player
	var near: Dictionary = game.zombies.spawn("dead", p.position + Vector3(game.RADIO_RING_URGENT - 2.0, 0, 0))
	var far: Dictionary = game.zombies.spawn("dead", p.position + Vector3(game.RADIO_RING_URGENT + 4.0, 0, 0))
	game.radio = ""
	game.set_radio("들어온다", "urgent")
	assert_eq(game.hud.radio_label.text, "…치직")
	assert_eq(game.radio, "", "not yet")
	game._tick_radio(game.RADIO_HISS * 0.5)
	assert_eq(game.radio_rings.size(), 0, "the hiss is not heard by the dead")
	assert_eq(near["state"], "wander")
	game._tick_radio(game.RADIO_HISS)
	assert_eq(game.radio, "들어온다")
	assert_eq(game.radio_rings[0]["r"], game.RADIO_RING_URGENT)
	assert_eq(near["state"], "investigate", "the one within the ring comes to look")
	assert_eq(far["state"], "wander")


func test_an_ordinary_call_rings_less_far_and_crouching_does_not_hide_it() -> void:
	var p = game.player
	p.crouched = true
	game.opts["radio"] = "often"
	var out: Dictionary = game.zombies.spawn("dead", p.position + Vector3(game.RADIO_RING + 3.0, 0, 0))
	var inside: Dictionary = game.zombies.spawn("dead", p.position + Vector3(game.RADIO_RING - 2.0, 0, 0))
	assert_true(_call("예보", "info"))
	assert_eq(game.radio_rings[0]["r"], game.RADIO_RING)
	assert_lt(game.RADIO_RING, game.RADIO_RING_URGENT)
	assert_eq(inside["state"], "investigate")
	assert_eq(out["state"], "wander")


func test_what_is_said_to_your_face_does_not_ring() -> void:
	game.opts["radio"] = "off"
	game.set_radio("신호소 위: 동쪽", "say")
	assert_eq(game.radio, "신호소 위: 동쪽", "at once, set or no set")
	assert_true(game.radio_wait.is_empty())
	assert_eq(game.radio_rings.size(), 0)


func test_near_only_a_horde_far_from_you_is_not_called() -> void:
	var p = game.player
	assert_eq(game.radio_near, "horde")
	assert_false(_call("먼 입구", "urgent", p.position + Vector3(game.RADIO_NEAR_M + 5.0, 0, 0)))
	assert_eq(game.radio_rings.size(), 0, "no call, no ring")
	assert_true(_call("가까운 입구", "urgent", p.position + Vector3(game.RADIO_NEAR_M - 5.0, 0, 0)))


func test_near_the_other_meaning_far_from_the_train_only_a_hiss() -> void:
	var p = game.player
	game.radio_near = "train"
	var train: Vector3 = FieldGrid.center(game.HORDE_HOME)
	p.position = train + Vector3(game.RADIO_NEAR_M - 10.0, 0, 0)
	assert_true(_call("들어온다", "urgent", train + Vector3(200, 0, 0)), "where the horde is does not matter")
	assert_eq(game.radio, "들어온다")
	p.position = train + Vector3(game.RADIO_NEAR_M + 10.0, 0, 0)
	game.radio_last = -INF
	assert_true(_call("들어온다", "urgent"))
	assert_true(game.radio.begins_with("…치직"), "nothing can be made out")
	assert_eq(game.radio_rings[-1]["r"], game.RADIO_RING, "it rings all the same")
	game.radio_last = -INF
	assert_true(_call("떠나야 한다", "must"))
	assert_eq(game.radio, "떠나야 한다", "the call to leave gets through")


func test_paused_the_radio_key_goes_round_the_three_settings() -> void:
	var hud = game.hud
	hud.tick(0.02)
	assert_false(hud.radio_opt_button.visible)
	game.paused = true
	hud.tick(0.02)
	assert_true(hud.radio_opt_button.visible)
	assert_eq(hud.radio_opt_button.text, "무전: 급한 것만")
	await wait_frames(2)
	assert_false(hud.radio_opt_button.get_global_rect().intersects(hud.stick_opt_button.get_global_rect()))
	hud._pad_down(hud.radio_opt_button, Vector2.ZERO)
	assert_eq(game.radio_mode(), "often")
	hud._pad_down(hud.radio_opt_button, Vector2.ZERO)
	assert_eq(game.radio_mode(), "off")
	hud._pad_down(hud.radio_opt_button, Vector2.ZERO)
	assert_eq(game.radio_mode(), "urgent")


func test_a_horde_coming_in_near_you_is_called_and_rings_loud() -> void:
	game.clock.elapsed = 300.0
	game.radio_near = "train"   # so the way in it picks does not matter here
	game.player.position = FieldGrid.center(game.HORDE_HOME)
	game._start_horde({"index": 0, "size": 3, "entry": "north_road"})
	assert_false(game.radio_wait.is_empty(), "the horde is called")
	game._tick_radio(game.RADIO_HISS + 0.01)
	assert_true(game.radio.contains("기관사"))
	assert_eq(game.radio_rings[-1]["r"], game.RADIO_RING_URGENT)
