extends "res://addons/gut/test.gd"
## 결정 569(사용자 2026-11-06 「옮기는게 낫네 그러자」): 무전은 영화 자막처럼 아래 가운데, 동료 얼굴 줄
## 바로 위에 한 줄(화면 폭 46 %까지, 글은 RADIO_W까지). 고르기 줄·열린 동료 카드가 떠 있는 동안만
## 예전 자리(오른쪽 위 메시지 칸, 알림 위)로 간다 — 그 위로 올리면 화면 가운데 대장을 덮어서(안 2-4-2).
## 알림(토스트)은 지금 자리(오른쪽 메시지 칸), 보이는 시간 8초는 그대로다. 좌우는 막대 고리와 오른쪽
## 엄지 단추 사이(상황·출발 단추 열까지), 무전·고르기 줄·카드가 바뀐 그 프레임에 자리를 잡는다(6 Pro 점검).

const FieldGame = preload("res://game/field_game.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")

## The longest call in the game (field_game.gd), two lines on a 16:9 screen.
const LONG: String = "무전수: 이 근처에 무리가 돕니다. 소리를 내면 열차로 몰려들어 떠날 때 붙들릴 겁니다."
const SHORT: String = "무리가 역 쪽으로 접근 중!"

var game
var hud


func _start(extra: Dictionary = {}) -> void:
	game = FieldGame.new()
	var opts: Dictionary = {"seed": 11, "raiders": false, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
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
	assert_almost_eq(400.0 - r.position.x, r.end.x - 700.0, 0.5, "wider than the room: it overhangs both sides alike, not 300 px into the thumb's keys")
	assert_gte(r.position.x, 0.0, "and stays on the screen")
	assert_lte(r.end.x, view.x)
	r = FieldHud.radio_spot(Vector2(1200, 40), Vector2(1000, 720), [628.0], 300.0, 700.0, 18.0)
	assert_eq(r.position.x, 0.0, "wider than the screen too: from its left edge")


## The room between the thumbs on a 16:9, a 19.5:9 and a 4:3 screen (720 high), with
## the aim and manual keys or a single primary key: never into the right thumb's
## keys — the context and depart column included — nor onto the stick's ring.
func test_the_room_keeps_off_every_right_thumb_key_on_each_screen() -> void:
	var stick_x: float = 150.0
	for view: Vector2 in [Vector2(1280, 720), Vector2(1560, 720), Vector2(960, 720)]:
		for one: bool in [false, true]:
			var b: Vector2 = FieldHud.radio_bounds_for(view, stick_x, one)
			var why: String = "%dx%d %s" % [view.x, view.y, "one key" if one else "aim + manual"]
			assert_almost_eq(b.x, stick_x + FieldHud.STICK_RING + UiFonts.px(FieldHud.SQUAD_GAP), 0.01, why + ": off the ring")
			for key_x: float in [FieldHud.CONTEXT_AT.x, FieldHud.DEPART_AT.x, FieldHud.AIM_AT.x - (0.0 if one else FieldHud.MANUAL_SIZE.x + 8.0)]:
				assert_lte(b.y, view.x + key_x - 16.0, why + ": 16 short of a key's left edge")
			assert_gt(b.y - b.x, 0.0, why + ": some room left")


# ---------------------------------------------------------------- the field


func _assert_back(calm: Rect2, why: String) -> void:
	var now: Rect2 = hud.radio_pill.get_global_rect()
	assert_almost_eq(now.position.x, calm.position.x, 0.5, why)
	assert_almost_eq(now.position.y, calm.position.y, 0.5, why)
	assert_almost_eq(now.size.x, calm.size.x, 0.5, why + " (width)")
	assert_almost_eq(now.size.y, calm.size.y, 0.5, why + " (height)")


## The call in the message column: right-aligned on its edge, above the notes,
## off the screen's middle where the leader stands.
func _assert_in_column(why: String) -> void:
	var radio: Rect2 = hud.radio_pill.get_global_rect()
	var span: Vector2 = hud._message_span()
	assert_almost_eq(radio.end.x, span.y, 1.0, why + ": on the column's right edge")
	assert_gte(radio.position.x, span.x - 0.5, why + ": inside the column")
	assert_false(radio.has_point(hud._view_size() * 0.5), why + ": off the leader in the middle")
	assert_gte(hud.toast_box.get_global_rect().position.y, radio.end.y, why + ": the notes under it")


func _settle() -> void:
	hud.tick(0.02)
	await get_tree().process_frame
	hud.tick(0.02)


func test_a_row_of_choices_sends_the_call_to_the_message_column() -> void:
	_start()
	hud.toast("가방이 무겁다.")
	var calm: Rect2 = await _call(LONG)
	hud.offer([{"label": "창 깨기", "call": Callable()}, {"label": "넘어가기", "call": Callable()}])
	assert_true(hud.radio_raised())
	assert_almost_eq(hud.radio_pill.get_global_rect().end.x, hud._message_span().y, 1.0, "in the column in the frame the choices come")
	await _settle()
	_assert_in_column("choices up")
	for key: Node in hud.offer_box.get_children():
		assert_false(hud.radio_pill.get_global_rect().intersects((key as Control).get_global_rect()), "never over a choice")
	hud._offer_pick(Callable())
	assert_false(hud.radio_raised())
	await _settle()
	_assert_back(calm, "back to the subtitle once they go, as wide as before")


func test_an_open_card_sends_the_call_to_the_message_column() -> void:
	_start()
	assert_gt(hud.ally_buttons.size(), 0, "a squad to open a card of")
	var calm: Rect2 = await _call("기관사: 서쪽 둑 쪽에서 옵니다, 한 시간쯤.")
	hud._toggle_card(0)
	await _settle()
	_assert_in_column("a card open")
	assert_false(hud.radio_pill.get_global_rect().intersects((hud.ally_buttons[0]["card"] as Control).get_global_rect()))
	hud._toggle_card(0)
	await _settle()
	_assert_back(calm, "back over the faces once it shuts")


## 6 Pro 점검: a new call stood on the old spot with its new size until the next tick.
func test_a_call_stands_in_its_place_in_the_frame_it_comes() -> void:
	_start()
	var long_call: Rect2 = await _call(LONG)
	var faces_top: float = hud.allies_box.get_global_rect().position.y
	assert_almost_eq(long_call.end.y, faces_top - UiFonts.px(FieldHud.MESSAGE_GAP), 1.0, "its foot over the faces")
	hud.radio(SHORT)
	var short_call: Rect2 = hud.radio_pill.get_global_rect()
	assert_lt(short_call.size.y, long_call.size.y, "one line now, at once, not the long call's two")
	assert_almost_eq(short_call.end.y, long_call.end.y, 1.0, "on the same foot")
	hud.tick(0.02)
	assert_eq(hud.radio_pill.get_global_rect(), short_call, "the next tick leaves it where it came")


## 6 Pro 점검 / 2-4-2 시험이 잡은 것: the pill only ever grew (size.max), so a call once
## fitted narrower stayed tall after its room came back.
func test_the_pill_is_as_small_as_its_words_each_time_it_stands() -> void:
	_start()
	var calm: Rect2 = await _call(LONG)
	hud.radio_pill.size = calm.size + Vector2(0, 60)
	hud.tick(0.02)
	_assert_back(calm, "back to its words' size, its foot where it was")


## With a single primary key the context and depart keys stay where they are: the
## call keeps off them as it does off the aim key (6 Pro 점검).
func test_with_one_primary_key_the_call_keeps_off_the_context_and_depart_keys() -> void:
	_start({"primary_one": true})
	var radio: Rect2 = await _call(LONG)
	for b: Button in [hud.context_button, hud.depart_button, hud.aim_button]:
		assert_false(radio.intersects(b.get_global_rect()), "clear of " + String(b.name))
	assert_lte(radio.end.x, hud.context_button.get_global_rect().position.x - 16.0 + 0.5, "16 short of the context column")


func test_the_call_fades_in_its_last_breath_and_a_new_one_is_whole() -> void:
	_start()
	await _call(SHORT)
	hud.tick(7.0)
	var a: float = hud.radio_label.modulate.a
	assert_almost_eq(a, hud.radio_left / 1.5, 0.001, "fading over its last 1.5 seconds")
	assert_between(a, 0.05, 0.95)
	hud.radio(LONG)
	hud.tick(0.01)
	assert_almost_eq(hud.radio_label.modulate.a, 1.0, 0.001, "a new call is whole again")


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
