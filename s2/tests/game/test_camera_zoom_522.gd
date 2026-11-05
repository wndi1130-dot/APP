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
