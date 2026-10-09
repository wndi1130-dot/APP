extends "res://addons/gut/test.gd"
## Press feel and the "can't press" shake (ui_states P1 and P3).

const UiTheme = preload("res://game/ui/ui_theme.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")


func test_pressed_sinks_the_content_two_pixels_and_keeps_the_size() -> void:
	var theme := UiTheme.make()
	var normal: StyleBoxFlat = theme.get_stylebox("normal", "Button")
	for state in ["pressed", "hover_pressed"]:
		var sb: StyleBoxFlat = theme.get_stylebox(state, "Button")
		assert_almost_eq(sb.content_margin_top, normal.content_margin_top + 2.0, 0.001, state)
		assert_almost_eq(sb.content_margin_bottom, normal.content_margin_bottom - 2.0, 0.001, state)
		assert_eq(sb.content_margin_left, normal.content_margin_left, state)
		assert_eq(sb.content_margin_right, normal.content_margin_right, state)
		assert_eq(sb.get_minimum_size(), normal.get_minimum_size(), "%s: the button does not grow or shrink" % state)


func test_the_other_states_do_not_sink() -> void:
	var theme := UiTheme.make()
	var normal: StyleBoxFlat = theme.get_stylebox("normal", "Button")
	for state in ["hover", "disabled"]:
		var sb: StyleBoxFlat = theme.get_stylebox(state, "Button")
		assert_eq(sb.content_margin_top, normal.content_margin_top, state)
		assert_eq(sb.content_margin_bottom, normal.content_margin_bottom, state)


func test_the_shake_is_the_s1_one() -> void:
	# styles.css `denied`: .24 s, 3 px; rest -> left (25%) -> right (75%) -> rest.
	assert_almost_eq(UiDeny.SHAKE_S, 0.24, 0.0001)
	assert_almost_eq(UiDeny.SHAKE_PX, 3.0, 0.0001)
	var legs := 0.0
	var offsets: Array[float] = []
	for s in UiDeny.STEPS:
		offsets.append(float(s[0]))
		legs += float(s[1])
	assert_almost_eq(legs, 1.0, 0.0001)
	assert_eq(offsets, [-1.0, 1.0, 0.0] as Array[float])


func test_a_dimmed_button_is_still_a_live_one() -> void:
	var b := Button.new()
	UiDeny.dim(b, true)
	assert_almost_eq(b.modulate.a, 0.45, 0.001)
	assert_false(b.disabled)
	UiDeny.dim(b, false)
	assert_almost_eq(b.modulate.a, 1.0, 0.001)
	b.free()


func test_shaking_starts_once_and_a_second_press_restarts_from_rest() -> void:
	var b := Button.new()
	add_child_autofree(b)
	b.position = Vector2(40, 10)
	assert_false(UiDeny.is_shaking(b))
	UiDeny.shake(b)
	assert_true(UiDeny.is_shaking(b))
	b.position.x = 43.0  # mid shake
	UiDeny.shake(b)
	assert_true(UiDeny.is_shaking(b))
	assert_eq(b.position.x, 40.0, "the second shake starts from where the button rests")
	assert_eq(b.position.y, 10.0)


func test_a_button_outside_the_tree_just_stays_still() -> void:
	var b := Button.new()
	UiDeny.shake(b)
	assert_false(UiDeny.is_shaking(b))
	b.free()
