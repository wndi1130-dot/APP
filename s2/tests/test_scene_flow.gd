extends "res://addons/gut/test.gd"

const Flow = preload("res://scripts/scene_flow.gd")

func test_full_order_and_duplicate_rejection() -> void:
	var flow := Flow.new()
	assert_eq(flow.stage, Flow.Stage.HOME)
	assert_false(flow.advance(Flow.Stage.STATION))
	assert_true(flow.advance(Flow.Stage.BRAKING))
	assert_false(flow.advance(Flow.Stage.BRAKING))
	assert_true(flow.advance(Flow.Stage.LOADING))
	assert_true(flow.advance(Flow.Stage.STATION))
	assert_true(flow.advance(Flow.Stage.FIELD))
	assert_false(flow.advance(Flow.Stage.HOME))
	assert_false(flow.advance(Flow.Stage.FIELD + 1))

func test_reset_starts_a_new_measurement_flow() -> void:
	var flow := Flow.new()
	assert_true(flow.advance(Flow.Stage.BRAKING))
	flow.reset()
	assert_eq(flow.stage, Flow.Stage.HOME)
	assert_true(flow.advance(Flow.Stage.BRAKING))

# ---------------------------------------------------------------- loading note (ui_states L4)

func _at(stage: int) -> Flow:
	var flow := Flow.new()
	flow.stage = stage
	return flow

func test_a_load_the_brake_still_covers_shows_nothing() -> void:
	var flow := _at(Flow.Stage.LOADING)
	for seconds in [0.0, 0.45, 1.0, 1.5]:
		assert_eq(flow.loading_note(seconds), Flow.LoadNote.NONE, "%s s" % seconds)

func test_a_slow_load_shows_the_band_and_then_the_retry() -> void:
	var flow := _at(Flow.Stage.LOADING)
	assert_eq(flow.loading_note(1.6), Flow.LoadNote.BAND)
	assert_eq(flow.loading_note(8.0), Flow.LoadNote.BAND)
	assert_eq(flow.loading_note(8.1), Flow.LoadNote.RETRY)
	assert_eq(flow.loading_note(60.0), Flow.LoadNote.RETRY)

func test_only_the_loading_stage_has_a_loading_note() -> void:
	for stage in [Flow.Stage.HOME, Flow.Stage.BRAKING, Flow.Stage.STATION, Flow.Stage.FIELD]:
		assert_eq(_at(stage).loading_note(30.0), Flow.LoadNote.NONE, "stage %d" % stage)

func test_loading_words_are_plain_and_not_red_alarm() -> void:
	assert_eq(Flow.BAND_TEXT, "열차가 멈춰 선다…")
	assert_eq(Flow.RETRY_TEXT, "다시 해 본다")

# ---------------------------------------------------------------- blocked buttons (ui_states P3)

## The conditions the stage buttons used to be switched off by.
func _was_disabled(action: String, stage: int, ready: bool) -> bool:
	match action:
		"stop":
			return stage != Flow.Stage.HOME
		"field":
			return stage != Flow.Stage.STATION or not ready
		"noise", "restart":
			return stage != Flow.Stage.FIELD
		"posture":
			return stage == Flow.Stage.FIELD
	return false

func test_a_reason_exists_exactly_where_the_button_used_to_be_disabled() -> void:
	for stage in range(Flow.Stage.FIELD + 1):
		for ready in [false, true]:
			for action in ["stop", "field", "noise", "restart", "posture"]:
				var why := _at(stage).why_blocked(action, ready)
				assert_eq(why != "", _was_disabled(action, stage, ready), "%s at %d ready=%s" % [action, stage, ready])

func test_reasons_speak_in_the_world_voice() -> void:
	for stage in range(Flow.Stage.FIELD + 1):
		for ready in [false, true]:
			for action in ["stop", "field", "noise", "restart", "posture"]:
				var why := _at(stage).why_blocked(action, ready)
				if why != "":
					assert_true(why.ends_with("다."), why)
					assert_false(why.contains("!"), why)

func test_reasons_name_what_is_in_the_way() -> void:
	assert_eq(_at(Flow.Stage.HOME).why_blocked("field"), "먼저 정차해야 한다.")
	assert_eq(_at(Flow.Stage.BRAKING).why_blocked("stop"), "열차가 서는 중이다.")
	assert_eq(_at(Flow.Stage.LOADING).why_blocked("field"), "열차가 서는 중이다.")
	assert_eq(_at(Flow.Stage.STATION).why_blocked("field", false), "하차가 끝나야 한다.")
	assert_eq(_at(Flow.Stage.STATION).why_blocked("stop"), "이미 정차했다.")
	assert_eq(_at(Flow.Stage.FIELD).why_blocked("stop"), "이미 필드에 나와 있다.")
	assert_eq(_at(Flow.Stage.HOME).why_blocked("noise"), "필드에 나간 뒤에 쓴다.")
	assert_eq(_at(Flow.Stage.FIELD).why_blocked("posture"), "필드에서는 자세를 바꿀 수 없다.")
