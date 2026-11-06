extends "res://addons/gut/test.gd"
## 카메라 목표와 게임 시계만 검증한다. 지도 생성과 렌더 갱신은 시험에서 제외한다.

const FieldGame = preload("res://game/field_game.gd")
const EdgeBand = preload("res://game/world/edge_band.gd")

class CameraField extends "res://game/field_game.gd":

	func _ready() -> void:
		set_process(false)

	func _set_sight_round() -> void:
		pass

	func _update_storm() -> void:
		pass

	func _update_light() -> void:
		pass


var game: CameraField
var screen: SubViewport
var pane: Control
var other_pane: Control


func before_each() -> void:
	screen = SubViewport.new()
	screen.size = Vector2i(600, 1000)
	screen.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(screen)
	game = CameraField.new()
	game.grid = FieldGame.FieldGrid.new(60, 64)
	game.player = autofree(FieldGame.Person.new())
	game.player.position = Vector3(30, 0, 32)
	game.zombies = autofree(FieldGame.Zombies.new())
	game.hud = autofree(FieldGame.Hud.new())
	pane = autofree(Control.new())
	other_pane = autofree(Control.new())
	game.camera = Camera3D.new()
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = 20.0
	game.add_child(game.camera)
	game.snow = GPUParticles3D.new()
	game.snow.emitting = false
	game.add_child(game.snow)
	screen.add_child(game)


func _dead(distance: float, state: String = "wander", floor_id: int = 0) -> Dictionary:
	var z := {"state": state, "pos": game.player.position + Vector3(distance, game.level_y(floor_id), 0)}
	game.zombies.list.append(z)
	return z


func _loot(open: bool) -> void:
	game.hud.modal_open = open
	game.hud.box_pane = pane
	game.hud.modal = pane if open else null


func _at(seconds: float) -> float:
	game.clock.elapsed = seconds
	return game._camera_target_size()


func test_new_field_uses_twenty_without_changing_the_selected_zoom() -> void:
	assert_eq(game.cam_size, 20.0)
	assert_eq(_at(0.0), 20.0)
	assert_eq(_at(100.0), 20.0)
	assert_eq(game.cam_size, 20.0)


func test_unbuilt_optional_view_state_keeps_the_base_zoom() -> void:
	game.hud = null
	game.zombies = null
	game.player = null
	assert_eq(_at(0.0), 20.0)


func test_loot_has_priority_and_keeps_a_tighter_selected_zoom() -> void:
	_dead(5.0)
	_loot(true)
	assert_eq(_at(0.0), 18.0)
	game.cam_size = 14.0
	assert_eq(_at(0.0), 14.0)
	_loot(false)
	assert_eq(_at(0.0), 22.0)


func test_other_or_closed_modals_are_not_loot() -> void:
	_loot(true)
	assert_eq(_at(0.0), 18.0)
	game.hud.modal = other_pane
	assert_eq(_at(0.0), 20.0)
	game.hud.modal = pane
	game.hud.modal_open = false
	assert_eq(_at(0.0), 20.0)
	game.hud.box_pane = null
	game.hud.modal_open = true
	assert_eq(_at(0.0), 20.0)


func test_fifteen_metres_is_inclusive_and_hidden_dead_count() -> void:
	game.mask_on = true
	game.seen_now.clear()
	var z := _dead(15.0)
	assert_true(game._camera_dead_near())
	assert_eq(_at(0.0), 22.0)
	z["pos"] = game.player.position + Vector3(15.001, 0, 0)
	assert_false(game._camera_dead_near())


func test_only_living_dead_on_the_same_floor_count() -> void:
	_dead(1.0, "wander", 1)
	_dead(1.0, "wander", -1)
	_dead(1.0, "dead")
	_dead(1.0, "rising")
	assert_false(game._camera_dead_near())
	assert_eq(_at(0.0), 20.0)
	# 쓰러짐과 얼어붙음은 기존 threat 판정상 살아 있는 개체다.
	for state in ["downed", "frozen", "waking", "wander"]:
		game.zombies.list.clear()
		_dead(1.0, state)
		assert_true(game._camera_dead_near(), state)


func test_return_wait_starts_at_exit_and_ends_after_three_clock_seconds() -> void:
	var z := _dead(14.0)
	assert_eq(_at(10.0), 22.0)
	z["pos"] = game.player.position + Vector3(16, 0, 0)
	assert_eq(_at(11.0), 22.0)
	assert_eq(_at(13.999), 22.0)
	assert_eq(_at(14.0), 20.0)
	assert_eq(game.cam_size, 20.0)


func test_another_entry_restarts_the_wait_on_the_next_exit() -> void:
	var z := _dead(1.0)
	_at(0.0)
	z["pos"] = game.player.position + Vector3(16, 0, 0)
	_at(1.0)
	z["pos"] = game.player.position + Vector3(1, 0, 0)
	assert_eq(_at(3.9), 22.0)
	z["pos"] = game.player.position + Vector3(16, 0, 0)
	assert_eq(_at(4.0), 22.0)
	assert_eq(_at(6.999), 22.0)
	assert_eq(_at(7.0), 20.0)


func test_wide_and_tight_player_choices_are_preserved() -> void:
	game.cam_size = 36.0
	_dead(1.0)
	assert_eq(_at(0.0), 36.0)
	_loot(true)
	assert_eq(_at(0.0), 18.0)
	assert_eq(game.cam_size, 36.0)
	_loot(false)
	game.cam_size = 14.0
	assert_eq(_at(0.0), 22.0)
	game.zombies.list.clear()
	assert_eq(_at(1.0), 22.0)
	game.cam_size = 30.0
	assert_eq(_at(2.0), 30.0)
	assert_eq(_at(4.0), 30.0)


func test_legacy_twenty_four_is_kept_as_the_selected_zoom() -> void:
	game.cam_size = 24.0
	game._reset_camera_zoom()
	assert_eq(_at(0.0), 24.0)
	_dead(1.0)
	assert_eq(_at(0.0), 24.0)
	_loot(true)
	assert_eq(_at(0.0), 18.0)
	assert_eq(game.cam_size, 24.0)


func test_loot_does_not_stop_threat_tracking_or_restart_an_expired_wait() -> void:
	_dead(1.0)
	_loot(true)
	assert_eq(_at(0.0), 18.0)
	game.zombies.list.clear()
	assert_eq(_at(1.0), 18.0)
	_loot(false)
	assert_eq(_at(2.0), 22.0)
	_loot(true)
	assert_eq(_at(5.0), 18.0)
	_loot(false)
	assert_eq(_at(5.0), 20.0)


func test_a_stopped_clock_does_not_consume_return_time() -> void:
	_dead(1.0)
	_at(0.0)
	game.zombies.list.clear()
	_at(1.0)
	for _frame in range(120):
		game._update_camera(1.0 / 30.0)
	assert_eq(_at(1.0), 22.0)
	assert_eq(_at(4.0), 20.0)


func test_clock_rewind_and_restore_reset_discard_old_waits() -> void:
	_dead(1.0)
	_at(100.0)
	game.zombies.list.clear()
	assert_eq(_at(101.0), 22.0)
	assert_eq(_at(0.0), 20.0)
	_dead(1.0)
	_at(1.0)
	game.zombies.list.clear()
	_at(2.0)
	game._reset_camera_zoom()
	assert_eq(_at(2.0), 20.0)


func _targets_at_hz(hz: int) -> Array:
	game._reset_camera_zoom()
	game.zombies.list.clear()
	var z := _dead(1.0)
	var targets: Array = []
	for frame in range(hz * 5 + 1):
		var now := float(frame) / float(hz)
		z["pos"] = game.player.position + Vector3(1 if now < 1.0 else 16, 0, 0)
		var target := _at(now)
		if frame % hz == 0:
			targets.append(target)
	return targets


func test_thirty_and_sixty_fps_have_the_same_targets_at_the_same_times() -> void:
	var expected := [22.0, 22.0, 22.0, 22.0, 20.0, 20.0]
	assert_eq(_targets_at_hz(30), expected)
	assert_eq(_targets_at_hz(60), expected)


func test_edge_focus_and_camera_size_use_the_effective_target() -> void:
	for dimensions in [Vector2i(600, 1000), Vector2i(1600, 900)]:
		screen.size = dimensions
		var aspect := float(dimensions.x) / float(dimensions.y)
		for row in [[20.0, false, false, 20.0], [36.0, true, true, 18.0], [14.0, false, true, 22.0]]:
			game._reset_camera_zoom()
			game.zombies.list.clear()
			game.cam_size = float(row[0])
			game.player.position = Vector3(0.5, 0, 0.5)
			game.cam_push = Vector3(-100, 0, -100)
			game.cam_focus = game.player.position
			_loot(bool(row[1]))
			if bool(row[2]):
				_dead(1.0)
			var target := float(row[3])
			var half := EdgeBand.view_half(target, aspect, game.CAM_PITCH, game.CAM_YAW)
			var focus := EdgeBand.clamp_focus(game.player.position + game.cam_push, half, 60, 64)
			focus = EdgeBand.keep_on_screen(focus, game.player.position, target, aspect, game.CAM_PITCH, game.CAM_YAW)
			game._update_camera(1.0)
			assert_almost_eq(game.camera.size, target, 0.0001)
			assert_lt(game.cam_focus.distance_to(focus), 0.0001)


func test_player_stays_on_screen_while_size_and_focus_are_interpolated() -> void:
	for hz in [30, 60]:
		game.player.position = Vector3(0.5, 0, 0.5)
		game.cam_push = Vector3(-100, 0, -100)
		game.cam_size = 36.0
		game.camera.size = 36.0
		game.cam_focus = Vector3(20, 0, 20)
		_loot(true)
		for frame in range(hz):
			game._update_camera(1.0 / float(hz))
			var off: Vector3 = game.player.position - game.cam_focus
			var ground := Vector2(off.x, off.z).rotated(deg_to_rad(game.CAM_YAW))
			var half := game.camera.size * 0.5
			assert_lte(absf(ground.x) / (half * 0.6), EdgeBand.KEEP + 0.0001)
			assert_lte(absf(ground.y) * sin(deg_to_rad(game.CAM_PITCH)) / half, EdgeBand.KEEP + 0.0001)
			if frame == 0:
				assert_gt(game.camera.size, 18.0)
				assert_lt(game.camera.size, 36.0)


## 복원 회귀는 실제 FieldGame의 _ready와 저장 직렬화 경로까지 사용한다.
const FieldSave = preload("res://game/sim/field_save.gd")
const StopCinema = preload("res://game/stop_cinema.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const SliceFlow = preload("res://game/slice_flow.gd")


func _save_field(extra: Dictionary = {}):
	var scene = FieldGame.new()
	var opts := {"seed": 4, "auto_pause": false, "raiders": false, "arrive": false, "arrival_horde": false}
	opts.merge(extra, true)
	scene.opts = opts
	scene.map_script = BareLine
	# 같은 고정 화면 안에서 실제 _ready를 실행한다. 화면이 장면의 수명을 소유한다.
	screen.add_child(scene)
	scene.set_process(false)
	return scene


func _roundtrip_camera(base_size: float, near: bool, legacy: bool = false) -> Array:
	var source = _save_field()
	source.zombies.list.clear()
	source.pending_spawn.clear()
	source.player.position = Vector3(30, 0, 10)
	source.cam_size = base_size
	source.cam_focus = Vector3(32, 0, 11)
	source.cam_push = Vector3(4, 0, 3)
	if near:
		source.zombies.spawn("dead", source.player.position + Vector3(4, 0, 0))
	var focus: Vector3 = source.cam_focus
	var saved := FieldSave.from_json(FieldSave.to_json(FieldSave.capture(source)))
	assert_false(saved.is_empty(), "실제 필드 저장이 JSON 왕복을 통과해야 한다")
	if legacy:
		saved["version"] = 1
		saved.erase("runtime")
	var resumed = _save_field(FieldSave.resume_opts(saved))
	assert_true(resumed.resume_pending, "재개 안내가 떠 있는 첫 화면")
	assert_true(resumed.paused)
	return [resumed, focus]


func _assert_restored_camera(resumed, size: float, focus: Vector3) -> void:
	assert_almost_eq(resumed.camera.size, size, 0.0001, "재개 전에 복원된 실제 크기")
	assert_lt(resumed.cam_focus.distance_to(focus), 0.0001, "유효한 저장 초점을 player + cam_push로 바꾸지 않는다")
	var eye: Vector3 = focus + FieldGame.cam_back() * 60.0
	assert_lt(resumed.camera.position.distance_to(eye), 0.0001, "첫 화면 위치도 저장 초점에 맞는다")
	resumed._process(1.0 / 30.0)
	assert_true(resumed.resume_pending)
	assert_almost_eq(resumed.camera.size, size, 0.0001, "재개 안내 중에도 같은 크기")


func test_exact_save_shows_twenty_four_before_resume() -> void:
	var restored := _roundtrip_camera(24.0, false)
	assert_eq(restored[0].cam_size, 24.0)
	_assert_restored_camera(restored[0], 24.0, restored[1])


func test_exact_save_with_near_dead_keeps_selected_twenty_four_before_resume() -> void:
	var restored := _roundtrip_camera(24.0, true)
	assert_eq(restored[0].cam_size, 24.0)
	_assert_restored_camera(restored[0], 24.0, restored[1])


func test_exact_save_with_near_dead_shows_the_automatic_target_before_resume() -> void:
	var restored := _roundtrip_camera(14.0, true)
	assert_eq(restored[0].cam_size, 14.0)
	_assert_restored_camera(restored[0], 22.0, restored[1])


func test_legacy_restore_starts_at_its_effective_zoom_before_resume() -> void:
	var restored := _roundtrip_camera(24.0, true, true)
	var resumed = restored[0]
	# 옛 판에는 runtime.cam_size 자체가 없으므로 기존 기본값 복원 계약을 지킨다.
	assert_eq(resumed.cam_size, 20.0)
	assert_almost_eq(resumed.camera.size, 22.0, 0.0001)
	assert_true(resumed.resume_pending)


func test_cinema_handoff_starts_at_the_received_size_then_eases_out() -> void:
	assert_true(game.has_method("start_camera_at"), "넘겨받는 순간의 카메라 맞춤 경로")
	if not game.has_method("start_camera_at"):
		return
	for hz in [30, 60]:
		game._reset_camera_zoom()
		game.zombies.list.clear()
		var z := _dead(1.0)
		_at(0.0)
		z["pos"] = game.player.position + Vector3(16, 0, 0)
		_at(1.0)
		z["pos"] = game.player.position + Vector3(1, 0, 0)
		_at(2.0)
		game._update_camera(1.0)
		assert_eq(game.camera.size, 22.0, "숨은 동안에는 자동 목표에 도달해 있다")
		var state := [game.cam_size, game._cam_had_threat, game._cam_return_at, game._cam_zoom_clock]
		game.call("start_camera_at", StopCinema.FIELD_VIEW_H)
		assert_eq(game.camera.size, StopCinema.FIELD_VIEW_H)
		assert_eq([game.cam_size, game._cam_had_threat, game._cam_return_at, game._cam_zoom_clock], state,
			"선택값과 자동 줌 상태는 넘겨받기 전 그대로")
		var previous: float = game.camera.size
		for _frame in range(12):
			game._update_camera(1.0 / float(hz))
			assert_gte(game.camera.size, previous)
			assert_lte(game.camera.size, 22.0)
			previous = game.camera.size
		assert_gt(game.camera.size, StopCinema.FIELD_VIEW_H)


## 정차 장면 밑에서 숨어 지어진 필드가 망자 근처라 22로 가 있어도, 실제 넘기기
## (SliceFlow._start_field)에서 보이는 그 순간의 크기는 장면이 끝난 크기다.
func test_pending_field_receives_cinema_size_before_it_is_shown() -> void:
	var flow = SliceFlow.new()
	flow.opts = {"skip_field": true, "seed": 3, "cinema": false}
	add_child_autofree(flow)
	var built = FieldGame.new()
	built.opts = {"seed": 4, "auto_pause": false, "raiders": false, "arrive": false, "arrival_horde": false}
	built.map_script = BareLine
	built.visible = false
	flow.add_child(built)
	built.set_process(false)
	built.zombies.list.clear()
	built.pending_spawn.clear()
	built.zombies.spawn("dead", built.player.position + Vector3(4, 0, 0))
	built._update_camera(1.0)
	assert_eq(built.camera.size, 22.0, "숨은 동안 망자 근처라 자동 목표 22에 가 있다")
	var shown_at: Array = []
	var record := func() -> void:
		if built.visible:
			shown_at.append(built.camera.size)
	built.visibility_changed.connect(record)
	flow.pending_field = built
	flow._start_field()
	assert_eq(flow.field, built, "숨어 지어진 그 필드가 넘어간다")
	assert_true(built.visible)
	assert_eq(shown_at, [StopCinema.FIELD_VIEW_H], "보이는 순간의 크기는 장면이 끝난 크기")


func test_zooming_out_keeps_each_current_frame_inside_the_edge_band() -> void:
	var band := EdgeBand.view_band
	for hz in [30, 60]:
		for push in [Vector3.ZERO, Vector3(-100, 0, -100)]:
			game._reset_camera_zoom()
			game.zombies.list.clear()
			game.player.position = Vector3(0.5, 0, 0.5)
			game.cam_focus = game.player.position
			game.cam_push = push
			game.cam_size = 36.0
			_loot(true)
			game._update_camera(1.0)
			assert_eq(game.camera.size, 18.0)
			_loot(false)
			for frame in range(hz * 2):
				game._update_camera(1.0 / float(hz))
				var half := EdgeBand.view_half(game.camera.size, 0.6, game.CAM_PITCH, game.CAM_YAW)
				var note := "%d fps, frame %d, push %s" % [hz, frame, push]
				assert_gte(game.cam_focus.x - half.x, -band - 0.0001, note)
				assert_gte(game.cam_focus.z - half.y, -band - 0.0001, note)
				assert_lte(game.cam_focus.x + half.x, float(game.grid.width) + band + 0.0001, note)
				assert_lte(game.cam_focus.z + half.y, float(game.grid.height) + band + 0.0001, note)
				if frame == 0:
					assert_almost_eq(game.camera.size, 18.0 + 18.0 * 6.0 / float(hz), 0.0001, "크기 보간 속도 유지")
