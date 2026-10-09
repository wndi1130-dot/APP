extends "res://addons/gut/test.gd"
## The stage buttons of the graybox flow stay pressable: a press that cannot
## act says why in a note and shakes the button (ui_states P3), and a slow
## stop load shows the band and the retry (L4).

const Main = preload("res://scripts/main.gd")
const Flow = preload("res://scripts/scene_flow.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")

var m


func before_each() -> void:
	m = Main.new()
	add_child_autofree(m)


func _buttons() -> Array[Button]:
	return [m.stop_button, m.field_button, m.noise_button, m.restart_button, m.posture_button]


func test_no_stage_button_is_ever_switched_off() -> void:
	for stage in range(Flow.Stage.FIELD + 1):
		m.flow.stage = stage
		m._update_controls()
		for b in _buttons():
			assert_false(b.disabled, "%s at %d" % [b.text, stage])


func test_blocked_buttons_look_dim_and_allowed_ones_do_not() -> void:
	assert_eq(m.flow.stage, Flow.Stage.HOME)
	assert_almost_eq(m.stop_button.modulate.a, 1.0, 0.001)
	assert_almost_eq(m.posture_button.modulate.a, 1.0, 0.001)
	for b in [m.field_button, m.noise_button, m.restart_button]:
		assert_almost_eq(b.modulate.a, UiDeny.DIM, 0.001, b.text)
	m.flow.stage = Flow.Stage.FIELD
	m._update_controls()
	assert_almost_eq(m.noise_button.modulate.a, 1.0, 0.001)
	assert_almost_eq(m.posture_button.modulate.a, UiDeny.DIM, 0.001)
	assert_almost_eq(m.stop_button.modulate.a, UiDeny.DIM, 0.001)


func test_pressing_a_blocked_button_says_why_and_shakes_it() -> void:
	m.field_button.pressed.emit()
	assert_eq(m.note.text, "먼저 정차해야 한다.")
	assert_almost_eq(m.note.modulate.a, 1.0, 0.001)
	assert_true(UiDeny.is_shaking(m.field_button))
	assert_eq(m.flow.stage, Flow.Stage.HOME, "nothing ran")


func test_the_reason_comes_from_the_stage_it_is_in() -> void:
	m.flow.stage = Flow.Stage.STATION
	m.station_ready = false
	m.field_button.pressed.emit()
	assert_eq(m.note.text, "하차가 끝나야 한다.")
	m.flow.stage = Flow.Stage.FIELD
	m.posture_button.pressed.emit()
	assert_eq(m.note.text, "필드에서는 자세를 바꿀 수 없다.")
	assert_true(m.confident, "the posture did not change")


func test_a_new_note_replaces_the_one_showing() -> void:
	m.field_button.pressed.emit()
	m.noise_button.pressed.emit()
	assert_eq(m.note.text, "필드에 나간 뒤에 쓴다.")


func test_the_note_fades_out_after_its_time() -> void:
	m.field_button.pressed.emit()
	m.note_left = 0.5
	m._process(0.6)
	assert_almost_eq(m.note.modulate.a, 0.0, 0.001)


func test_pressing_an_allowed_button_runs_it_without_a_note() -> void:
	m.stop_button.pressed.emit()
	assert_eq(m.flow.stage, Flow.Stage.BRAKING)
	assert_eq(m.note.text, "")
	assert_false(UiDeny.is_shaking(m.stop_button))


func test_a_quick_load_never_shows_the_band() -> void:
	m.flow.stage = Flow.Stage.LOADING
	m.loading_started_ms = Time.get_ticks_msec() - 450
	m._update_loading_note()
	assert_false(m.loading_band.visible)
	assert_false(m.retry_button.visible)
	m.loading_started_ms = Time.get_ticks_msec() - 1400
	m._update_loading_note()
	assert_false(m.loading_band.visible, "the brake scene still covers it")


func test_a_slow_load_shows_the_band_then_the_retry() -> void:
	m.flow.stage = Flow.Stage.LOADING
	m.loading_started_ms = Time.get_ticks_msec() - 2000
	m._update_loading_note()
	assert_true(m.loading_band.visible)
	assert_eq(m.loading_band.text, "열차가 멈춰 선다…")
	assert_false(m.retry_button.visible)
	m.loading_started_ms = Time.get_ticks_msec() - 9000
	m._update_loading_note()
	assert_true(m.loading_band.visible)
	assert_true(m.retry_button.visible)
	assert_eq(m.retry_button.text, "다시 해 본다")


func test_the_band_goes_when_the_stop_is_done() -> void:
	m.flow.stage = Flow.Stage.LOADING
	m.loading_started_ms = Time.get_ticks_msec() - 9000
	m._update_loading_note()
	assert_true(m.retry_button.visible)
	m.flow.stage = Flow.Stage.STATION
	m._update_loading_note()
	assert_false(m.loading_band.visible)
	assert_false(m.retry_button.visible)


func test_the_retry_runs_the_load_again_and_a_late_one_is_ignored() -> void:
	m.flow.stage = Flow.Stage.LOADING
	m.retry_button.pressed.emit()
	assert_eq(m.flow.stage, Flow.Stage.STATION)
	assert_false(m.station_ready)
	var scene = m.active_scene
	m.retry_button.pressed.emit()
	assert_eq(m.flow.stage, Flow.Stage.STATION)
	assert_eq(m.active_scene, scene, "no second load")
