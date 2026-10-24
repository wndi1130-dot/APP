extends "res://addons/gut/test.gd"
## The stop seen from the train (stop_cinema.gd, 결정 421-3): its beats in
## order on both ways, the least time over the stop and the wait for a slow
## field, skipping once seen, standing still while the app is away, and the
## look down ending where the field's camera begins. The scene is driven by
## its own tick here, not by the clock on the wall.

const StopCinema = preload("res://game/stop_cinema.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldAudio = preload("res://game/audio/field_audio.gd")

const TICK: float = 0.05

static var _map: Dictionary = {}


func _data() -> Dictionary:
	if _map.is_empty():
		_map = FieldMaps.build("")
	return _map


func _scene(seen: bool = false, with_map: bool = true):
	var c = StopCinema.new()
	c.seen = seen
	c.remember = false
	if with_map:
		c.data = _data()
	add_child_autofree(c)
	c.set_process(false)          # ticked by hand
	return c


## Tick until `beat` begins (or `limit` seconds of the scene pass).
func _run_to(c, beat: String, limit: float = 60.0) -> void:
	var spent: float = 0.0
	while c.beat != beat and spent < limit and is_instance_valid(c):
		c._step(TICK)
		spent += TICK


func test_sent_the_beats_go_roof_run_near_card_brake_down_rest_out() -> void:
	var c = _scene()
	watch_signals(c)
	_run_to(c, "hold")
	assert_eq(c.beats_seen, ["rise", "run", "near", "hold"])
	assert_signal_emit_count(c, "card_time", 1, "the card comes up once, as the train slows")
	assert_almost_eq(c.speed, StopCinema.CARD_SPEED, 0.5, "the train is slowing, not standing, when the card comes")
	c.send()
	_run_to(c, "rest")
	assert_eq(c.beats_seen.slice(4), ["brake", "down", "rest"])
	assert_almost_eq(c.p, c.p_stand, 0.01, "the train stands where the stop's map has it")
	c.land()
	c._step(TICK)
	assert_eq(c.beat, "out")
	assert_signal_emitted_with_parameters(c, "done", ["sent"])


func test_passed_by_the_train_picks_up_speed_and_its_screen_comes_back() -> void:
	var c = _scene()
	watch_signals(c)
	_run_to(c, "hold")
	for i in 20:
		c._step(TICK)
	c.pass_by()
	_run_to(c, "out")
	assert_eq(c.beats_seen.slice(3), ["hold", "away", "out"])
	assert_gt(c.speed, StopCinema.RUN_SPEED * 0.9, "back up to speed")
	assert_gt(c.p, c.p_stand, "past the stand: it did not stop")
	assert_signal_emitted_with_parameters(c, "done", ["passed"])


func test_a_field_ready_at_once_still_gets_the_least_look_down() -> void:
	var c = _scene()
	_run_to(c, "hold")
	c.land()                        # the field was ready before the crew was even sent
	c.send()
	_run_to(c, "down")
	var over: float = 0.0
	while c.beat != "out":
		c._step(TICK)
		over += TICK
	assert_gte(over, StopCinema.DOWN_S, "never shorter than the way down")
	assert_lt(over, StopCinema.DOWN_S + 0.2)


func test_a_slow_field_keeps_the_look_down_till_it_is_ready() -> void:
	var c = _scene()
	_run_to(c, "hold")
	c.send()
	_run_to(c, "rest")
	for i in int(30.0 / TICK):
		c._step(TICK)
	assert_eq(c.beat, "rest", "still over the stop after half a minute without the field")
	assert_true(c.at_rest(), "at rest: the field may be built in longer slices")
	c.land()
	c._step(TICK)
	assert_eq(c.beat, "out")


func test_a_tap_skips_a_beat_only_once_the_scene_has_been_seen() -> void:
	var c = _scene(false)
	watch_signals(c)
	c._step(TICK)
	c.skip()
	assert_eq(c.beat, "rise", "the first time it is seen whole")
	var d = _scene(true)
	watch_signals(d)
	d._step(TICK)
	d.skip()
	assert_eq(d.beat, "hold", "seen before: on to the card")
	assert_signal_emit_count(d, "card_time", 1)
	d.skip()
	assert_eq(d.beat, "hold", "the card is not skipped")
	d.send()
	d.skip()
	assert_eq(d.beat, "down", "the brakes skipped")
	assert_almost_eq(d.p, d.p_stand, 0.01, "standing where it stands at the end of the brakes")
	d.skip()
	assert_eq(d.beat, "rest", "the way down skipped")
	d.skip()
	d._step(TICK)
	assert_eq(d.beat, "rest", "the wait for the field is not skipped")
	d.land()
	d._step(TICK)
	assert_signal_emitted_with_parameters(d, "done", ["sent"])


func test_skipped_or_not_the_scene_ends_on_the_same_stand_and_view() -> void:
	var a = _scene(false)
	_run_to(a, "hold")
	a.send()
	a.land()
	_run_to(a, "out")
	var b = _scene(true)
	b._step(TICK)
	b.skip()
	b.send()
	b.skip()
	b.skip()
	b.land()
	b._step(TICK)
	assert_eq(b.beat, "out")
	assert_almost_eq(b.train_pivot.position.x - b.station.position.x, a.train_pivot.position.x - a.station.position.x, 0.01, "the train stands in the same place of the stop")
	assert_true(b._down_pose().is_equal_approx(a._down_pose()), "the same view over the stop")


func test_away_from_the_app_the_scene_stands_and_comes_back_on_the_same_beat() -> void:
	var c = _scene()
	c.set_process(true)
	_run_to(c, "near")
	c._step(1.0)
	var t0: float = c.t
	var p0: float = c.p
	c._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(c.paused)
	c._process(0.5)
	c._process(5.0)
	assert_eq(c.beat, "near")
	assert_eq(c.t, t0, "no time passes while away")
	assert_eq(c.p, p0)
	c._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(c.paused)
	c._process(30.0)
	assert_almost_eq(c.t, t0 + 0.1, 0.001, "a long frame on the way back counts as a short one")


func test_the_look_down_ends_where_the_field_s_camera_begins() -> void:
	var c = _scene()
	_run_to(c, "hold")
	c.send()
	_run_to(c, "rest")
	c._step(TICK)
	var focus: Vector3 = c.station.to_global(FieldGrid.center(_data()["spawns"]["squad"][0]))
	var at: Vector3 = c._down_pose().origin
	var pitch: float = rad_to_deg(asin((at - focus).normalized().y))
	assert_almost_eq(pitch, StopCinema.FIELD_PITCH_DEG, 0.01, "the field's pitch")
	var height: float = 2.0 * at.distance_to(focus) * tan(deg_to_rad(c.camera.fov * 0.5))
	assert_almost_eq(height, StopCinema.FIELD_VIEW_H, 0.01, "as much ground on the screen as the field shows")
	assert_true(c._down_focus().is_equal_approx(focus), "over the first of the crew's places, by the door")


func test_the_way_there_stops_short_of_the_stop_s_place() -> void:
	var c = _scene()
	_run_to(c, "hold")
	assert_lt(c._corridor_to, c.station.position.x, "no pole or tree laid inside the stop's own map")


func test_the_place_comes_in_far_off_when_the_map_comes_late() -> void:
	var c = _scene(false, false)
	for i in int(6.0 / TICK):
		c._step(TICK)
	assert_eq(c.beat, "run", "no map: the run goes on")
	c.set_map(_data())
	var ahead: float = c.p_stand - c.p
	assert_gt(ahead, StopCinema.D_NEAR + StopCinema.RUN_SPEED * StopCinema.RUN_LEAD_S * 0.9, "laid out far ahead in the weather, never in sight")
	_run_to(c, "hold")
	assert_eq(c.beat, "hold")


func test_the_brakes_are_the_field_s_own_brake_sound_as_loud() -> void:
	var c = _scene()
	assert_almost_eq(c.brake_player.volume_db, FieldAudio._db(FieldAudio.BRAKE_LOUD), 0.001)
	_run_to(c, "hold")
	c.send()
	assert_eq(c.beat, "brake")
	assert_not_null(c.brake_player.stream, "the stop's brake sound (audio/train_brake)")
	assert_between(float(c._brake["len"]), StopCinema.BRAKE_MIN_S, StopCinema.BRAKE_MAX_S)


func _worn(stop_opts: Dictionary):
	var c = StopCinema.new()
	c.remember = false
	c.stop_opts = stop_opts
	c.data = _data()
	add_child_autofree(c)
	c.set_process(false)
	return c


# The scene wears the weather the field opens with (사용자가 가장 싫어하는
# 어긋남: 비 오는 열차 화면, 눈밭 연출, 비 오는 필드): late autumn's rain on wet
# ground in the prologue's second stretch, snow lying white in the deep cold.
func test_the_scene_wears_the_weather_the_field_opens_with() -> void:
	var autumn = _worn({"act": "prologue", "act_progress": 0.25})
	assert_eq(autumn.falls, "rain", "the prologue's second stretch: rain")
	assert_lt(autumn.white, 0.1, "no snow lying")
	assert_true(autumn.snow.emitting)
	assert_eq(int(autumn.snow.draw_pass_1.material.get_shader_parameter("shape")), 0, "streaks, not flakes")
	var ground: Color = autumn._ground(StopCinema.SNOW)
	assert_lt(ground.v, StopCinema.SNOW.v, "wet ground, darker than snow")
	var deep = _worn({"act": "prologue", "cold": 1.0})
	assert_eq(deep.falls, "snow", "deep cold: snow")
	assert_gt(deep.white, 0.5, "snow lying")
	assert_gt(deep._ground(StopCinema.SNOW).v, ground.v, "the snowy ground is the paler")
	# The field itself opens with the same: what falls, the lying snow, the sun.
	var field = preload("res://game/field_game.gd").new()
	field.opts = {"seed": 3, "act": "prologue", "act_progress": 0.25, "raiders": false, "auto_pause": false}
	add_child_autofree(field)
	field.set_process(false)
	assert_eq(String(field.atmo["falls"]), autumn.falls)
	assert_almost_eq(float(field.fx_params["fx_snow"]), float(autumn.fx["fx_snow"]), 0.001)
	assert_almost_eq(float(field.fx_params["fx_wet"]), float(autumn.fx["fx_wet"]), 0.001)
	assert_almost_eq(float(field.atmo["sun_pitch"]), float(autumn.look["sun_pitch"]), 0.001)
