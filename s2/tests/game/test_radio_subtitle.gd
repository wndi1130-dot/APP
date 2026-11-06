extends "res://addons/gut/test.gd"
## 결정 569(사용자 2026-11-06 「옮기는게 낫네 그러자」): 무전은 영화 자막처럼 아래 가운데, 동료 얼굴 줄
## 바로 위에 한 줄(화면 폭 46 %까지, 글은 RADIO_W까지). 고르기 줄·열린 동료 카드가 뜨면 그 위로 올라가고,
## 알림(토스트)은 지금 자리(오른쪽 메시지 칸), 보이는 시간 8초는 그대로다.

const FieldGame = preload("res://game/field_game.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")

var game
var hud


func _start() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	hud = game.hud
	hud.tick(0.016)


func _call(words: String) -> Rect2:
	hud.radio(words)
	hud.tick(0.02)
	await get_tree().process_frame
	hud.tick(0.02)
	return hud.radio_pill.get_global_rect()


# ---------------------------------------------------------------- the rule


func test_the_spot_is_centred_with_its_foot_over_the_highest_floor() -> void:
	var view := Vector2(1280, 720)
	var pill := Vector2(400, 40)
	var r: Rect2 = FieldHud.radio_spot(pill, view, [628.0], 0.0, 1280.0, 18.0)
	assert_eq(r, Rect2(440, 570, 400, 40), "centred, its foot 18 over the faces")
	r = FieldHud.radio_spot(pill, view, [628.0, 540.0, 600.0], 0.0, 1280.0, 18.0)
	assert_eq(r.end.y, 522.0, "over the highest: a row of choices at 540")
	r = FieldHud.radio_spot(pill, view, [], 0.0, 1280.0, 18.0)
	assert_eq(r.end.y, 702.0, "nothing there: over the screen's foot")


func test_the_spot_keeps_between_the_stick_and_the_thumb() -> void:
	var view := Vector2(1280, 720)
	var r: Rect2 = FieldHud.radio_spot(Vector2(600, 40), view, [628.0], 400.0, 1280.0, 18.0)
	assert_eq(r.position.x, 400.0, "pushed off the stick's ring")
	r = FieldHud.radio_spot(Vector2(600, 40), view, [628.0], 0.0, 900.0, 18.0)
	assert_eq(r.end.x, 900.0, "kept off the thumb's pads")
	r = FieldHud.radio_spot(Vector2(600, 40), view, [628.0], 400.0, 700.0, 18.0)
	assert_eq(r.position.x, 400.0, "wider than the room: the left edge wins, never off the stick side")


# ---------------------------------------------------------------- the field


func test_a_row_of_choices_lifts_the_call_over_it() -> void:
	_start()
	var calm: Rect2 = await _call("기관사: 서쪽 둑 쪽에서 옵니다, 한 시간쯤.")
	hud.offer([{"label": "창 깨기", "call": Callable()}, {"label": "넘어가기", "call": Callable()}])
	hud.tick(0.02)
	var top: float = INF
	for key: Node in hud.offer_box.get_children():
		top = minf(top, (key as Control).get_global_rect().position.y)
	var lifted: Rect2 = hud.radio_pill.get_global_rect()
	assert_lte(lifted.end.y, top, "over the choices")
	assert_lt(lifted.position.y, calm.position.y, "higher than without them")
	for key: Node in hud.offer_box.get_children():
		assert_false(lifted.intersects((key as Control).get_global_rect()), "never over a choice")
	hud._offer_pick(Callable())
	await get_tree().process_frame
	hud.tick(0.02)
	assert_almost_eq(hud.radio_pill.get_global_rect().position.y, calm.position.y, 0.5, "back down once they go")


func test_an_open_card_lifts_the_call_over_it() -> void:
	_start()
	assert_gt(hud.ally_buttons.size(), 0, "a squad to open a card of")
	await _call("기관사: 서쪽 둑 쪽에서 옵니다, 한 시간쯤.")
	hud._toggle_card(0)
	hud.tick(0.02)
	var card: Rect2 = (hud.ally_buttons[0]["card"] as Control).get_global_rect()
	var radio: Rect2 = hud.radio_pill.get_global_rect()
	assert_lte(radio.end.y, card.position.y, "over the open card")
	assert_false(radio.intersects(card))


func test_notes_keep_their_place_in_the_message_column() -> void:
	_start()
	hud.toast("가방이 무겁다.")
	hud.tick(0.02)
	var alone: Rect2 = hud.toast_box.get_global_rect()
	var radio: Rect2 = await _call("무리 근접! 곧 출발! 모두 열차로!")
	var with_call: Rect2 = hud.toast_box.get_global_rect()
	assert_almost_eq(with_call.position.y, alone.position.y, 0.5, "the call no longer pushes the notes down")
	assert_false(with_call.intersects(radio), "and the two never meet")


func test_the_call_shows_eight_seconds_as_before() -> void:
	_start()
	await _call("무리가 역 쪽으로 접근 중!")
	hud.tick(7.8)
	assert_true(hud.radio_pill.visible, "still up just before eight seconds")
	hud.tick(0.3)
	assert_false(hud.radio_pill.visible, "gone after eight")
