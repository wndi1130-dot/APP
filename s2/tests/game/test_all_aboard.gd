extends "res://addons/gut/test.gd"
## One pad sends every companion back to the train (user 2026-10-11). The
## one-by-one 'retreat' order stays as it was.

const FieldGame = preload("res://game/field_game.gd")

var game
var hud


func _start(extra: Dictionary = {}) -> void:
	game = FieldGame.new()
	var opts := {"seed": 11, "raiders": false, "auto_pause": false}
	opts.merge(extra)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	hud = game.hud
	hud.tick(0.016)


func _allies() -> Array:
	return game.squad.filter(func(q) -> bool: return q != game.player)


func _press() -> void:
	var at: Vector2 = hud.all_aboard_button.get_global_rect().get_center()
	assert_true(hud.finger_down(3, at))
	hud.finger_up(3, at)


func test_one_press_sends_every_living_companion_to_the_train() -> void:
	_start()
	var allies := _allies()
	assert_gt(allies.size(), 1)
	var gone = allies[0]
	gone.body.dead = true
	gone.command = "wait"
	allies[1].brain["boarded"] = true
	var mine: String = game.player.command
	_press()
	for q in allies:
		if q == gone:
			assert_eq(q.command, "wait", "the dead are given no order")
		else:
			assert_eq(q.command, "retreat")
			assert_false(q.brain.get("boarded", false))
	assert_eq(game.player.command, mine, "the one you play is not a companion")


func test_the_work_crew_is_not_in_it() -> void:
	_start()
	_press()
	assert_false(game.ai.crew_recalled, "the crew has its own recall")


func test_it_works_with_a_thumb_on_the_stick_and_leaves_an_open_card_alone() -> void:
	_start()
	hud.finger_down(0, hud.stick_home())
	assert_eq(hud.stick_index, 0)
	_press()
	assert_eq(_allies()[0].command, "retreat", "a second finger takes it")
	assert_eq(hud.stick_index, 0, "the stick is still held")
	hud.finger_up(0, hud.stick_home())
	for q in _allies():
		q.command = "follow"
	hud.card("t", "고른다", [{"id": "a", "label": "하나"}], func(_c: String) -> void: pass)
	assert_true(hud.modal_open)
	hud._all_aboard()
	assert_true(hud.modal_open, "an open card is not shut by it")


func test_the_pad_sits_clear_of_every_other_key() -> void:
	_start()
	hud.context_button.visible = true
	hud.lamp_button.visible = true
	hud.blood_button.visible = true
	hud.crew_button.visible = true
	for pad in hud.status_pads:
		pad.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	hud.tick(0.02)
	await get_tree().process_frame
	var r: Rect2 = hud.all_aboard_button.get_global_rect()
	var view: Vector2 = hud._view_size()
	assert_true(Rect2(Vector2.ZERO, view).encloses(r), "on the screen")
	for b in hud.pads:
		if b != hud.all_aboard_button:
			assert_false(r.intersects(b.get_global_rect()), "clear of " + b.text + b.tooltip_text)
	assert_false(r.intersects(hud.allies_box.get_global_rect()), "clear of the companions' row")
	assert_false(r.intersects(hud.portrait.get_global_rect()))
	# In the top middle, under the radio (시안 2차 .fall): the driver's words and
	# the way back to the train in one place.
	assert_almost_eq(r.get_center().x, view.x * 0.5, 1.0, "in the middle")
	assert_lt(r.end.y, view.y * 0.25, "at the top")


func test_it_sits_under_the_radio_even_when_a_call_wraps() -> void:
	_start()
	var view: Vector2 = hud._view_size()
	for words in ["무리가 역 쪽으로 접근 중!", "무리 근접! 곧 출발! 모두 열차로! 무리 근접! 곧 출발! 모두 열차로! 무리 근접! 곧 출발!"]:
		hud.radio(words)
		hud.tick(0.02)
		await get_tree().process_frame
		hud.tick(0.02)
		assert_true(hud.radio_pill.visible, words)
		var radio: Rect2 = hud.radio_pill.get_global_rect()
		var r: Rect2 = hud.all_aboard_button.get_global_rect()
		assert_gt(r.position.y, radio.end.y, "under the radio: " + words)
		assert_almost_eq(r.get_center().x, view.x * 0.5, 1.0)
	assert_gt(hud.radio_label.get_line_count(), 1, "the long call wrapped")


func test_the_one_by_one_order_can_be_shown_as_to_the_train() -> void:
	_start()
	var row: Array = hud.COMMANDS.filter(func(c) -> bool: return c[0] == "retreat")[0]
	assert_eq(hud.command_word(row), "후퇴")
	game.opts["retreat_name"] = "train"
	assert_eq(hud.command_word(row), "열차로")
	assert_eq(hud.command_word(hud.COMMANDS[0]), "따라와", "the others keep their words")
