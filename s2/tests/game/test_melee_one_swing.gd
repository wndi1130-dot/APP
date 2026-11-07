extends "res://addons/gut/test.gd"
## 결정 564: 적을 누르거나 공격 패드를 누른 한 동작에서 한 번만 휘두르는 선택 설정.
## 실제 fight·표적 추적·준비/회복 상태 전이를 쓰고 타격은 기록과 고정 회복 시간으로 대신한다.

const FieldGame = preload("res://game/field_game.gd")
const FieldCombat = preload("res://game/field_combat.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const Boot = preload("res://game/boot.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const SETTING_PATH: String = "res://game/ui/melee_press.gd"
const ScreenLift = preload("res://game/ui/screen_lift.gd")
const GlassPane = preload("res://game/ui/glass_pane.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")

var game: FieldGame
var roots: Array[Node] = []
var folder: String
var old_where: String
var old_screen_where: String
var melee_press: Variant = null


class SurvivingCombat extends FieldCombat:
	var holds: Array[bool] = []
	var landed: Array = []
	var shots: Array = []

	func _init(field_game) -> void:
		super(field_game)

	func fight(p, target, hold: bool) -> void:
		holds.append(hold)
		super.fight(p, target, hold)

	func _strike(p, at) -> void:
		# 살아 있는 같은 적에게 두 번째 공격이 나오는지 피해 난수 없이 확인한다.
		landed.append({"person": p, "target": at})
		p.swing_t = 1.0

	func fire(p, at: Vector3, target = null) -> String:
		# 명중·걸림 난수 대신 실제 HUD의 발사 호출 도달만 기록한다.
		shots.append({"person": p, "at": at, "target": target})
		return "shot"


class MenuProbe extends Boot:
	func _ready() -> void:
		# 자동 시작·메뉴 예열 없이 실제 _start의 즉시/지연 필드 생성 경로를 쓴다.
		for row: Array in CHOICES:
			settings[row[0]] = row[2][0][0]


func before_each() -> void:
	old_screen_where = ScreenLift.where
	folder = "user://test_melee_one_swing_%d_%d_한글 공백" % [OS.get_process_id(), Time.get_ticks_usec()]
	assert_eq(DirAccess.make_dir_recursive_absolute(folder), OK)
	# 수정 전 코드에서도 입력 시험이 누락된 설정 preload에 막히지 않고 hold 단언까지 간다.
	melee_press = load(SETTING_PATH) if ResourceLoader.exists(SETTING_PATH) else null
	if melee_press != null:
		old_where = melee_press.where
		melee_press.where = folder + "/근접 설정.cfg"
	ScreenLift.where = folder + "/screen.cfg"


func after_each() -> void:
	for root: Node in roots:
		if is_instance_valid(root):
			root.free()
	roots.clear()
	game = null
	if melee_press != null:
		melee_press.where = old_where
	ScreenLift.where = old_screen_where
	# 이 시험이 만든 고유 폴더만 정리한다. 실제 설정 파일은 열거나 지우지 않는다.
	for name: String in DirAccess.get_files_at(folder):
		assert_eq(DirAccess.remove_absolute(folder.path_join(name)), OK)
	if DirAccess.dir_exists_absolute(folder + "/막힌 설정"):
		assert_eq(DirAccess.remove_absolute(folder + "/막힌 설정"), OK)
	assert_eq(DirAccess.remove_absolute(folder), OK)


func _field(extra: Dictionary = {}) -> FieldGame:
	if is_instance_valid(game):
		roots.erase(game)
		game.free()
	var field := FieldGame.new()
	field.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	field.opts.merge(extra, true)
	roots.append(field)
	add_child(field)
	field.set_process(false)
	field.zombies.list.clear()
	field.pending_spawn.clear()
	field.player.position = field.lift(Vector2i(60, 7), 0)
	for person in field.squad:
		if person != field.player:
			person.position = field.lift(Vector2i(30, 7), 0)
	field.player.hands = [{"id": "axe", "quality": "factory", "condition": 0.9, "loaded": 0}]
	field.player.facing = PI * 0.5
	field.combat = SurvivingCombat.new(field)
	game = field
	return field


func _target() -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(1.0, 0, 0))
	z["state"] = "chase"
	game._refresh_vision()
	return z


func _press(z: Dictionary) -> Vector2:
	game._update_camera(1.0)
	var at: Vector2 = game.hud._project(z["pos"])
	game.hud._press(at)
	assert_eq(game.hud.melee_pending, z, "실제 화면 누름이 이 적을 고른다")
	return at


func _hold() -> void:
	game.hud.press_ms = Time.get_ticks_msec() - int(game.hud.HOLD_TIME * 1000.0) - 1
	game.hud.tick(0.02)


func _step(seconds: float) -> void:
	for _i in range(ceili(seconds / 0.05)):
		game.clock.elapsed += 0.05
		game.combat.update(0.05)


func _swings() -> int:
	return int(game.combat.melee_tally["swung"])


func _recorder() -> SurvivingCombat:
	return game.combat as SurvivingCombat


func _has_setting() -> bool:
	assert_not_null(melee_press, "결정 564 설정 모듈이 있어야 한다")
	return melee_press != null


func test_only_a_bool_true_enables_the_option() -> void:
	if not _has_setting():
		return
	assert_false(melee_press.enabled({}))
	for value: Variant in [false, "true", "false", 0, 1, 1.0, null, [], {}]:
		assert_false(melee_press.enabled({"melee_one_swing": value}), str(value))
	assert_true(melee_press.enabled({"melee_one_swing": true}))


func test_a_tap_orders_hold_false_and_swings_once_at_a_survivor() -> void:
	_field({"melee_one_swing": true})
	var z := _target()
	var at := _press(z)
	game.hud._release(at)
	assert_eq(_recorder().holds, [false], "fight에 한 번 휘두르기 명령")
	assert_false(game.player.hold_attack)
	_step(4.0)
	assert_eq(_swings(), 1)
	assert_eq(_recorder().landed.size(), 1)
	assert_eq(z["state"], "chase", "같은 적이 살아 있어도 다시 치지 않는다")
	assert_true(game.player.target_zombie.is_empty())
	assert_false(game.player.hold_attack)


func test_a_long_press_is_consumed_once_and_release_adds_no_swing() -> void:
	_field({"melee_one_swing": true})
	var at := _press(_target())
	_hold()
	assert_true(game.hud.melee_holding, "전투 연타 여부와 별개인 누름 처리 표식")
	assert_eq(_recorder().holds, [false])
	for _i in range(4):
		_step(1.0)
		game.hud.tick(0.02)
	assert_eq(_swings(), 1, "손을 계속 대도 한 번")
	game.hud._release(at)
	_step(2.0)
	assert_eq(_recorder().holds, [false], "떼면서 두 번째 fight를 내지 않는다")
	assert_eq(_swings(), 1)
	assert_null(game.hud.melee_pending)
	assert_false(game.hud.melee_holding)


func test_one_swing_does_not_chain_even_when_chaining_is_on() -> void:
	_field({"melee_one_swing": true, "melee_chain": true})
	var first := _target()
	var next: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(1.2, 0, 0.4))
	next["state"] = "chase"
	game._refresh_vision()
	game.hud._release(_press(first))
	_step(1.5)
	first["state"] = "dead"
	_step(3.0)
	assert_eq(_swings(), 1)
	assert_true(game.player.target_zombie.is_empty())
	assert_false(game.player.hold_attack)
	assert_eq(next["state"], "chase")


func _assert_default_repeats(extra: Dictionary, held: bool) -> void:
	var options := extra.duplicate()
	options["melee_chain"] = false
	_field(options)
	var z := _target()
	var at := _press(z)
	if held:
		_hold()
	game.hud._release(at)
	assert_eq(_recorder().holds, [true])
	assert_true(game.player.hold_attack)
	_step(3.0)
	assert_gt(_swings(), 1, "끔/키 없음은 손을 떼도 같은 적에게 연타")
	z["state"] = "dead"
	_step(1.0)
	assert_true(game.player.target_zombie.is_empty())
	assert_false(game.player.hold_attack)


func test_default_and_false_keep_tap_autorepeat() -> void:
	for extra: Dictionary in [{}, {"melee_one_swing": false}]:
		_assert_default_repeats(extra, false)


func test_default_and_false_keep_long_press_autorepeat() -> void:
	for extra: Dictionary in [{}, {"melee_one_swing": false}]:
		_assert_default_repeats(extra, true)


func test_attack_pad_and_primary_melee_use_the_same_choice() -> void:
	for primary: bool in [false, true]:
		_field({"melee_one_swing": true, "primary_one": primary})
		_target()
		var pad: Button = game.hud.aim_button if primary else game.hud.attack_button
		game.hud._pad_down(pad, Vector2.ZERO)
		game.hud._pad_up(pad, Vector2.ZERO)
		assert_eq(_recorder().holds, [false])
		_step(3.0)
		assert_eq(_swings(), 1)
		game.hud.tick(0.02)
		assert_false(game.hud.attack_button.button_pressed)


func test_losing_a_held_finger_does_not_add_an_attack() -> void:
	_field({"melee_one_swing": true})
	_press(_target())
	game.hud.fingers[7] = {"kind": "hand"}
	_hold()
	assert_true(game.hud.finger_cancel(7))
	_step(3.0)
	assert_eq(_recorder().holds, [false])
	assert_eq(_swings(), 1)
	assert_false(game.hud.pressing)
	assert_false(game.hud.melee_holding)


func test_an_ally_ai_keeps_repeating_with_either_setting() -> void:
	for on: bool in [false, true]:
		_field({"melee_one_swing": on})
		var ally = game.squad[1]
		assert_ne(ally, game.player)
		ally.position = game.player.position
		ally.hands = [{"id": "axe", "quality": "factory", "condition": 0.9, "loaded": 0}]
		ally.facing = PI * 0.5
		ally.look = ally.facing   # 이 시험은 이동·회전 프레임 대신 전투 시간만 전진시킨다.
		var z := _target()
		game.ai._engage(ally, z)
		assert_true(ally.hold_attack, "아군의 실제 AI 명령은 설정을 읽지 않는다")
		_step(4.0)
		assert_gt(_swings(), 1)
		assert_eq(ally.target_zombie, z)


func test_a_hostile_person_also_requires_one_swing() -> void:
	_field({"melee_one_swing": true})
	var at: Vector3 = game.player.position + Vector3(1.0, 0, 0)
	var raider = game.make_person({"id": "npc_melee_press", "name": "약탈자", "role": "raider",
		"skills": {"strength": 6, "melee": 4}, "hands": [["axe", "factory", 0.9]]}, at)
	raider.brain = {"role": "flanker", "state": "fight", "morale": 1.0, "home": at}
	game.raiders.append(raider)
	game.hud.melee_pending = raider
	game.hud._release(Vector2.ZERO)
	assert_eq(_recorder().holds, [false])
	_step(4.0)
	# field_combat._pursue_person도 좀비 쪽처럼 hold_attack이 꺼져 있으면 한 번 휘두른 뒤 표적을 놓는다.
	# 이 줄이 없던 판에서는 4초 동안 3번 휘둘렀다(11-07 고치기 전 실행).
	assert_eq(_swings(), 1, "사람 적도 한 번만")
	assert_null(game.player.target_person, "한 번 휘두른 뒤 표적을 놓음")


func test_saved_bool_round_trips_in_a_korean_path_and_replaces_previous_value() -> void:
	if not _has_setting():
		return
	assert_false(melee_press.load_enabled())
	for on: bool in [true, false, true]:
		assert_eq(melee_press.save_enabled(on), OK)
		assert_eq(melee_press.load_enabled(), on)
		var cfg := ConfigFile.new()
		assert_eq(cfg.load(melee_press.where), OK)
		assert_eq(cfg.get_value("melee", "one_swing"), on)
		assert_eq(typeof(cfg.get_value("melee", "one_swing")), TYPE_BOOL)
	assert_eq(DirAccess.get_files_at(folder).size(), 1, "임시 파일을 남기지 않는다")


func test_missing_key_and_non_bool_saved_values_default_to_off() -> void:
	if not _has_setting():
		return
	var empty := FileAccess.open(melee_press.where, FileAccess.WRITE)
	assert_not_null(empty)
	if empty == null:
		return
	empty.close()
	assert_false(melee_press.load_enabled(), "빈 파일도 기본 끔")
	var cfg := ConfigFile.new()
	cfg.set_value("other", "key", true)
	assert_eq(cfg.save(melee_press.where), OK)
	assert_false(melee_press.load_enabled())
	for value: Variant in ["true", "false", 0, 1, 1.0]:
		cfg.set_value("melee", "one_swing", value)
		assert_eq(cfg.save(melee_press.where), OK)
		assert_false(melee_press.load_enabled(), "bool 이외에는 끔: %s" % str(value))


func test_a_corrupt_file_defaults_to_off_and_can_be_replaced() -> void:
	if not _has_setting():
		return
	var file := FileAccess.open(melee_press.where, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string("[melee\none_swing=true")
	file.close()
	assert_false(melee_press.load_enabled())
	assert_engine_error_count(1, "ConfigFile의 잘못된 구역 구문 진단")
	assert_eq(melee_press.save_enabled(true), OK)
	assert_true(melee_press.load_enabled())


func test_an_interrupted_temporary_save_leaves_the_committed_value() -> void:
	if not _has_setting():
		return
	assert_eq(melee_press.save_enabled(true), OK)
	var partial := FileAccess.open(String(melee_press.where) + ".interrupted.tmp", FileAccess.WRITE)
	assert_not_null(partial)
	if partial == null:
		return
	partial.store_string("[melee\none_swing=")
	partial.close()
	assert_true(melee_press.load_enabled(), "교체 전 중단된 파일은 읽지 않는다")


func test_explicit_path_is_isolated_and_failed_replace_keeps_opts() -> void:
	if not _has_setting():
		return
	var other: String = folder + "/별도 설정.cfg"
	assert_eq(melee_press.save_enabled(true, other), OK)
	assert_true(melee_press.load_enabled(other))
	assert_false(melee_press.load_enabled())
	_field()
	var blocked: String = folder + "/막힌 설정"
	assert_eq(DirAccess.make_dir_absolute(blocked), OK)
	melee_press.where = blocked
	game.hud.call("_set_melee_press")
	assert_false(melee_press.enabled(game.opts), "저장 실패를 켬으로 표시하지 않는다")
	assert_true(DirAccess.dir_exists_absolute(blocked))
	for name: String in DirAccess.get_files_at(folder):
		assert_false(name.ends_with(".tmp"), "교체 실패 뒤 임시 파일 정리")


func _cell() -> Button:
	return game.hud.modal.find_child("MeleePress", true, false) as Button


func test_setting_cell_shares_the_row_saves_reopens_and_fits() -> void:
	_field({"stick_float": true, "radio": "urgent"})   # 기존 칸도 가장 긴 값으로 확인한다.
	game.hud.settings_panel()
	for value: String in ["연타", "한 번씩", "연타"]:
		var cell := _cell()
		assert_not_null(cell)
		if cell == null:
			return
		assert_eq((cell.get_node("Words/Value") as Label).text, value)
		var row := cell.get_parent() as HBoxContainer
		assert_not_null(row)
		assert_eq(row.get_child_count(), 4, "기존 세 칸과 같은 한 줄")
		var names: Array[String] = []
		var needed: float = row.get_theme_constant("separation") * 3.0
		for key: Button in row.get_children():
			names.append((key.get_node("Words/Name") as Label).text)
			needed += key.get_combined_minimum_size().x
			for label: Label in [key.get_node("Words/Name"), key.get_node("Words/Value")]:
				assert_lte(GlassParts.text_w(label), key.custom_minimum_size.x)
		assert_eq(names, ["스틱", "무전", "상태 아이콘", "근접"])
		var pane := game.hud.modal_pane as GlassPane
		assert_lte(needed, pane.custom_minimum_size.x - GlassPane.px(GlassPane.PAD_L) - GlassPane.px(GlassPane.PAD_R))
		var before: bool = bool(game.opts.get("melee_one_swing", false))
		cell.pressed.emit()
		assert_eq(bool(game.opts.get("melee_one_swing", false)), not before)
		assert_eq(melee_press.load_enabled(), not before)
		assert_ne(game.hud.modal_pane, pane, "바뀐 값으로 설정 창을 다시 연다")


func test_direct_fields_keep_defaults_or_explicit_opts_until_flow_applies_saved() -> void:
	if not _has_setting():
		return
	assert_eq(melee_press.save_enabled(true), OK)
	_field()
	assert_false(melee_press.enabled(game.opts), "촬영 도구·봇은 저장값을 자동으로 읽지 않는다")
	game.hud.settings_panel()
	assert_false(melee_press.enabled(game.opts), "설정 창을 여는 것만으로 덮지 않는다")
	melee_press.apply_saved(game)
	assert_true(melee_press.enabled(game.opts))
	assert_eq(melee_press.save_enabled(false), OK)
	_field({"melee_one_swing": true})
	assert_true(melee_press.enabled(game.opts), "직접 만든 필드의 명시 opts")
	melee_press.apply_saved(game)
	assert_false(melee_press.enabled(game.opts), "플레이 흐름에서는 저장값이 우선")
	assert_true(FieldSave._start_opts({"melee_one_swing": true})["melee_one_swing"])
	assert_true(FieldSave._whole_start({"melee_one_swing": true}))


func _wait_built(field: FieldGame) -> void:
	for _i in range(1200):
		if field.is_built:
			field.set_process(false)
			field.set_physics_process(false)
			return
		await get_tree().process_frame
	fail_test("필드가 1200 프레임 안에 완성되지 않았다")


func test_boot_applies_saved_after_immediate_and_staged_builds() -> void:
	if not _has_setting():
		return
	assert_eq(melee_press.save_enabled(true), OK)
	for staged: bool in [false, true]:
		var boot := MenuProbe.new()
		boot.field_save_path = folder + "/field_%s.json" % str(staged)
		roots.append(boot)
		add_child(boot)
		boot._start({"seed": 11, "raiders": false, "auto_pause": false,
			"staged": staged, "melee_one_swing": false})
		await _wait_built(boot.field)
		assert_true(melee_press.enabled(boot.field.opts), "시작 메뉴는 필드 완성 뒤 저장값을 얹는다")


func test_slice_applies_saved_when_entering_a_stop() -> void:
	if not _has_setting():
		return
	assert_eq(melee_press.save_enabled(true), OK)
	var flow := SliceFlow.new()
	flow.opts = {"seed": 11, "cinema": false, "map_threads": false, "still": true, "save": false}
	roots.append(flow)
	add_child(flow)
	flow.set_process(false)
	flow.go(flow._index_of("field"))
	assert_not_null(flow.field)
	if flow.field == null:
		return
	await _wait_built(flow.field)
	assert_true(melee_press.enabled(flow.field.opts))
	assert_eq(melee_press.save_enabled(false), OK)
	flow._field_ready(flow.field)
	assert_false(melee_press.enabled(flow.field.opts), "다음 정차 준비에도 현재 저장값을 쓴다")


# 검토 보강: 아래 입력 시험은 _press/_release에 바로 들어가지 않고 실제 손가락 분배를 거친다.
func _person_target():
	var at: Vector3 = game.player.position + Vector3(1.0, 0, 0)
	var raider = game.make_person({"id": "npc_melee_review", "name": "약탈자", "role": "raider",
		"skills": {"strength": 6, "melee": 4}, "hands": [["axe", "factory", 0.9]]}, at)
	raider.brain = {"role": "flanker", "state": "fight", "morale": 1.0,
		"home": at, "last_seen": game.player.position, "aware_of_us": true}
	game.raiders.append(raider)
	game._refresh_vision()
	return raider


func _enemy(person: bool):
	return _person_target() if person else _target()


func _finger_press(target, index: int = 7) -> Vector2:
	game._update_camera(1.0)
	var spot: Vector3 = target["pos"] if target is Dictionary else target.position
	var at: Vector2 = game.hud._project(spot)
	assert_true(game.hud.finger_down(index, at))
	assert_eq(game.hud.fingers.get(index, {}).get("kind", ""), "hand", "화면의 적을 누르는 손가락")
	assert_eq(game.hud.melee_pending, target, "손가락 분배 뒤 실제 적 선택")
	return at


func _finger_tap(target) -> void:
	var at := _finger_press(target)
	assert_true(game.hud.finger_up(7, at))


func _pad_press(pad: Button, index: int = 8) -> Vector2:
	var at := pad.get_global_rect().get_center()
	assert_true(game.hud.finger_down(index, at))
	assert_eq(game.hud.fingers.get(index, {}).get("kind", ""), "pad")
	assert_eq(game.hud.fingers.get(index, {}).get("pad"), pad)
	return at


func _assert_target(target) -> void:
	if target is Dictionary:
		assert_eq(game.player.target_zombie, target, "아직 처리하지 않은 좀비 명령")
	else:
		assert_eq(game.player.target_person, target, "아직 처리하지 않은 사람 명령")


func _assert_no_target() -> void:
	assert_true(game.player.target_zombie.is_empty())
	assert_null(game.player.target_person)


func _wait_swings(count: int) -> void:
	for _i in range(200):
		if _swings() >= count:
			return
		_step(0.05)
	fail_test("10초 안에 %d번째 휘두름이 시작되지 않았다" % count)


func _wait_landed(count: int) -> void:
	for _i in range(200):
		if _recorder().landed.size() >= count:
			return
		_step(0.05)
	fail_test("10초 안에 %d번째 타격이 끝나지 않았다" % count)


func test_pending_one_swing_survives_a_15px_stick_move() -> void:
	for person: bool in [false, true]:
		_field({"melee_one_swing": true})
		var target = _enemy(person)
		_finger_tap(target)
		var home: Vector2 = game.hud.stick_home()
		assert_true(game.hud.finger_down(8, home))
		assert_true(game.hud.finger_move(8, home + Vector2(15, 0)))
		_assert_target(target)
		assert_eq(game.player.stick, Vector2.ZERO, "작은 움직임은 대기 명령을 지킨다")
		assert_true(game.hud.finger_up(8, home + Vector2(15, 0)))
		_step(4.0)
		assert_eq(_swings(), 1)
		assert_eq(_recorder().landed.size(), 1)


func test_a_deliberate_stick_move_cancels_a_pending_one_swing() -> void:
	for person: bool in [false, true]:
		_field({"melee_one_swing": true})
		_finger_tap(_enemy(person))
		var home: Vector2 = game.hud.stick_home()
		var away: Vector2 = (-game.hud._fight_dir(game.player)).rotated(deg_to_rad(game.CAM_YAW))
		var at: Vector2 = home + away * game.hud.STICK_R * 0.8
		assert_true(game.hud.finger_down(8, home))
		assert_true(game.hud.finger_move(8, at))
		_assert_no_target()
		assert_true(game.hud.finger_up(8, at))
		_step(3.0)
		assert_eq(_swings(), 0, "명시 이동으로 취소한 명령은 돌아오지 않는다")


func test_shove_pad_cancels_a_pending_one_swing() -> void:
	for person: bool in [false, true]:
		_field({"melee_one_swing": true})
		_finger_tap(_enemy(person))
		var at := _pad_press(game.hud.shove_button)
		_assert_no_target()
		assert_gt(game.player.shove_t, 0.0)
		assert_true(game.hud.finger_up(8, at))
		_step(4.0)
		_assert_no_target()
		assert_eq(_swings(), 0, "밀치기 뒤 옛 명령으로 다시 휘두르지 않는다")


func test_pending_one_swing_is_not_an_attack_pad_repeat_toggle() -> void:
	for primary: bool in [false, true]:
		_field({"melee_one_swing": true, "primary_one": primary})
		var target := _target()
		_finger_tap(target)
		game.hud.tick(0.0)
		var pad: Button = game.hud.aim_button if primary else game.hud.attack_button
		assert_false(pad.button_pressed, "대기 명령은 연타 표시가 아니다")
		var at := _pad_press(pad)
		_assert_target(target)
		assert_eq(_recorder().holds, [false, false], "다음 누름을 연타 끄기로 읽지 않는다")
		assert_true(game.hud.finger_up(8, at))
		_step(4.0)
		assert_eq(_swings(), 1)


func test_shove_cancels_the_path_of_a_pending_one_swing_approach() -> void:
	for person: bool in [false, true]:
		_field({"melee_one_swing": true})
		var target = _enemy(person)
		var far: Vector3 = game.player.position + Vector3(4.0, 0, 0)
		if target is Dictionary:
			target["pos"] = far
		else:
			target.position = far
		game._refresh_vision()
		_finger_tap(target)
		_step(0.05)
		assert_false(game.player.path.is_empty(), "추적 경로가 실제로 생긴 뒤 밀친다")
		var before: Vector3 = game.player.position
		var at := _pad_press(game.hud.shove_button)
		_assert_no_target()
		assert_true(game.player.path.is_empty(), "대기 명령이 남긴 경로도 취소한다")
		assert_true(game.hud.finger_up(8, at))
		for _i in range(80):
			_step(0.05)
			game._update_person(game.player, 0.05)
		assert_eq(game.player.position, before, "밀치기 뒤 옛 적에게 걸어가지 않는다")
		assert_eq(_swings(), 0)


func _cancel_repeat(person: bool, recovery: bool, second: bool, focus_loss: bool) -> void:
	_field({"melee_one_swing": false})
	var target = _enemy(person)
	_finger_press(target)
	_hold()
	var count: int = 2 if second else 1
	_wait_swings(count)
	if recovery:
		_wait_landed(count)
		assert_eq(game.player.strike_t, 0.0)
		assert_gt(game.player.swing_t, 0.0)
	else:
		assert_gt(game.player.strike_t, 0.0)
		assert_eq(game.player.strike_at, target)
	if focus_loss:
		game.hud.drop_touch()
	else:
		assert_true(game.hud.finger_cancel(7))
	assert_false(game.player.hold_attack)
	if not recovery:
		assert_eq(game.player.strike_at, target, "이미 시작한 공격은 취소하지 않는다")
	_step(4.0)
	assert_eq(_swings(), count, "취소 뒤 새 공격을 시작하지 않는다")
	assert_eq(_recorder().landed.size(), count, "진행 중이던 타격은 끝까지 간다")
	_assert_no_target()


func test_cancel_during_repeat_windup_finishes_only_that_swing() -> void:
	for person: bool in [false, true]:
		_cancel_repeat(person, false, false, false)


func test_cancel_during_repeat_recovery_adds_no_swing() -> void:
	for person: bool in [false, true]:
		_cancel_repeat(person, true, false, false)


func test_focus_loss_after_a_full_repeat_cycle_adds_no_swing() -> void:
	for person: bool in [false, true]:
		for recovery: bool in [false, true]:
			_cancel_repeat(person, recovery, true, true)


func test_normal_finger_up_after_windup_or_recovery_keeps_default_repeat() -> void:
	for person: bool in [false, true]:
		for recovery: bool in [false, true]:
			_field({"melee_one_swing": false})
			var at := _finger_press(_enemy(person))
			_hold()
			_wait_swings(1)
			if recovery:
				_wait_landed(1)
			assert_true(game.hud.finger_up(7, at))
			_step(4.0)
			assert_true(game.player.hold_attack)
			assert_gt(_swings(), 1, "정상 손 떼기의 기본 연타는 그대로")


func test_cancel_keeps_a_one_swing_order_that_has_not_started() -> void:
	for person: bool in [false, true]:
		_field({"melee_one_swing": true})
		var target = _enemy(person)
		_finger_press(target)
		_hold()
		assert_eq(_swings(), 0)
		assert_true(game.hud.finger_cancel(7))
		_assert_target(target)
		_step(4.0)
		assert_eq(_swings(), 1)
		assert_eq(_recorder().landed.size(), 1)


func test_busy_hands_keep_one_swing_until_it_can_really_start() -> void:
	for person: bool in [false, true]:
		_field({"melee_one_swing": true})
		var target = _enemy(person)
		game.player.action = "swap"   # BLOW_BREAKS에 없는 손 작업: 끝날 때까지 기다린다.
		_finger_tap(target)
		_step(0.5)
		assert_eq(_swings(), 0)
		_assert_target(target)
		assert_eq(game.player.action, "swap")
		game.player.action = ""
		_step(4.0)
		assert_eq(_swings(), 1, "거절된 시작은 명령을 소비하지 않는다")
		assert_eq(_recorder().landed.size(), 1)
		_assert_no_target()


func test_reused_hand_index_on_a_pad_clears_the_old_hold_timer() -> void:
	_field({"melee_one_swing": true})
	_finger_press(_target())
	game.hud.press_ms = Time.get_ticks_msec() - int(game.hud.HOLD_TIME * 1000.0) - 1
	var at := _pad_press(game.hud.shove_button, 7)
	assert_false(game.hud.pressing)
	assert_null(game.hud.melee_pending)
	assert_eq(game.hud.press_ms, 0, "옛 손가락의 시각도 비운다")
	game.hud.tick(0.4)
	assert_true(game.hud.finger_up(7, at))
	_step(4.0)
	assert_true(_recorder().holds.is_empty(), "옛 표적에 늦은 fight가 나가지 않는다")
	assert_eq(_swings(), 0)


func test_reused_hand_index_accepts_a_new_hand_target() -> void:
	_field({"melee_one_swing": true})
	_finger_press(_target())
	var next: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(-1.0, 0, 0))
	next["state"] = "chase"
	game._refresh_vision()
	var at := _finger_press(next)
	assert_true(game.hud.finger_up(7, at))
	_step(4.0)
	assert_eq(_recorder().holds, [false])
	assert_eq(_recorder().landed.size(), 1)
	if not _recorder().landed.is_empty():
		assert_eq(_recorder().landed[0]["target"], next)


## Hold RUN is released only by the old pad's cancellation, not by overwriting its record.
func test_reused_pad_index_hands_over_to_a_new_hand_and_cancels_cleanly() -> void:
	_field({"melee_one_swing": true, "run_mode": "hold"})
	var target := _target()
	game.player.moving = true
	_pad_press(game.hud.run_button, 7)
	assert_true(game.hud.run_button.button_pressed, "누르는 동안 달리기")
	assert_true(game.player.running)
	_finger_press(target)
	assert_false(game.hud.run_button.button_pressed, "옛 RUN 누름을 실제로 놓는다")
	assert_false(game.player.running)
	assert_eq(game.hud.fingers.size(), 1, "옛 pad 기록이 남지 않는다")
	assert_true(game.hud.pressing, "새 hand 누름")
	assert_true(game.hud.finger_cancel(7))
	assert_false(game.hud.pressing)
	assert_eq(game.hud.press_ms, 0)
	assert_null(game.hud.melee_pending)
	assert_false(game.hud.fingers.has(7))
	_step(4.0)
	assert_true(_recorder().holds.is_empty(), "취소된 hand는 fight를 내지 않는다")


func test_person_ai_repeats_and_stops_for_both_settings_and_directions() -> void:
	for on: bool in [false, true]:
		for raider_attacks: bool in [false, true]:
			_field({"melee_one_swing": on})
			var raider = _person_target()
			var attacker = raider if raider_attacks else game.squad[1]
			var target = game.player if raider_attacks else raider
			if raider_attacks:
				game.ai._raider_fight(raider, target, true)
			else:
				attacker.position = game.player.position
				attacker.hands = game.player.hands.duplicate(true)
				game.ai._companion(attacker)
			assert_eq(attacker.target_person, target, "실제 AI가 사람 표적을 정한다")
			assert_true(attacker.hold_attack)
			_step(4.0)
			assert_gt(_swings(), 1, "hold=true인 AI는 사람 표적에게도 반복한다")
			assert_eq(attacker.target_person, target)
			var before := _swings()
			target.body.downed = true
			_step(4.0)
			assert_null(attacker.target_person)
			assert_false(attacker.hold_attack)
			assert_eq(_swings(), before, "표적이 쓰러지면 새 공격은 끝난다")


class SaveFailure extends RefCounted:
	var fail_write: bool
	var calls: Array[String] = []
	var temporary: String = ""
	var destination: String = ""

	func _init(write_fails: bool) -> void:
		fail_write = write_fails

	func write(cfg: ConfigFile, at: String) -> Error:
		calls.append("write")
		temporary = at
		if not fail_write:
			return cfg.save(at)
		var partial := FileAccess.open(at, FileAccess.WRITE)
		if partial == null:
			return FileAccess.get_open_error()
		partial.store_string("[melee\none_swing=")
		partial.close()
		return ERR_CANT_CREATE

	func replace(_from: String, to: String) -> Error:
		calls.append("replace")
		destination = to
		return ERR_FILE_CANT_WRITE


func test_injected_write_and_replace_failures_preserve_an_existing_file() -> void:
	if not _has_setting():
		return
	for on: bool in [false, true]:
		for write_fails: bool in [false, true]:
			assert_eq(melee_press.save_enabled(on), OK)
			var before := FileAccess.get_file_as_bytes(melee_press.where)
			var failure := SaveFailure.new(write_fails)
			var error: Error = melee_press.save_enabled(not on, "", failure.write, failure.replace)
			assert_eq(error, ERR_CANT_CREATE if write_fails else ERR_FILE_CANT_WRITE)
			assert_eq(failure.calls, ["write"] if write_fails else ["write", "replace"])
			assert_ne(failure.temporary, melee_press.where)
			if not write_fails:
				assert_eq(failure.destination, melee_press.where)
			assert_eq(FileAccess.get_file_as_bytes(melee_press.where), before, "정상 파일 바이트 보존")
			assert_eq(melee_press.load_enabled(), on)
			assert_false(FileAccess.file_exists(failure.temporary), "실패한 임시 파일만 정리")
			assert_eq(DirAccess.get_files_at(folder).size(), 1)


func _slice(extra: Dictionary = {}) -> SliceFlow:
	var flow := SliceFlow.new()
	flow.opts = {"seed": 11, "cinema": false, "map_threads": false, "still": true, "save": false,
		"field_save_path": folder + "/field.json"}
	flow.opts.merge(extra, true)
	roots.append(flow)
	add_child(flow)
	flow.set_process(false)
	return flow


func test_slice_prebuilt_handoff_reads_the_current_saved_value() -> void:
	if not _has_setting():
		return
	assert_eq(melee_press.save_enabled(false), OK)
	var flow := _slice()
	var built := FieldGame.new()
	built.opts = {"seed": 11, "raiders": false, "auto_pause": false, "melee_one_swing": false,
		"field_save": false, "field_save_path": folder + "/prebuilt.json"}
	flow.add_child(built)
	await _wait_built(built)
	flow._on_field_built(built)
	assert_eq(flow.pending_field, built)
	assert_eq(melee_press.save_enabled(true), OK)
	flow.go(flow._index_of("field"))
	assert_eq(flow.field, built, "미리 지은 인스턴스를 실제로 인계한다")
	assert_null(flow.pending_field)
	assert_true(melee_press.enabled(flow.field.opts), "인계 직전 바뀐 저장값을 얹는다")
	flow.field.set_process(false)
	flow.field.set_physics_process(false)


func test_slice_resume_overrides_the_old_saved_field_option() -> void:
	if not _has_setting():
		return
	_field({"melee_one_swing": true})
	game.clock.elapsed = 37.0
	var saved: Dictionary = FieldSave.capture(game)
	assert_true(saved["start_opts"]["melee_one_swing"])
	assert_eq(melee_press.save_enabled(false), OK)
	var flow := _slice()
	flow.field_resume = FieldSave.resume_opts(saved)
	assert_false(flow.field_resume.is_empty())
	flow.go(flow._index_of("field"))
	assert_not_null(flow.field)
	if flow.field == null:
		return
	await _wait_built(flow.field)
	assert_true(flow.field_resume.is_empty(), "실제 이어 하기 분기가 저장 필드를 소비한다")
	assert_almost_eq(flow.field.clock.elapsed, 37.0, 0.001, "필드 상태도 실제로 이어 받는다")
	assert_false(melee_press.enabled(flow.field.opts), "옛 필드의 true보다 현재 저장 false가 우선")


func _reach_step(flow: SliceFlow, wanted: String) -> void:
	for _turn: int in range(32):
		if flow.current() == wanted or flow.campaign_error != "":
			break
		if not flow.current() in ["train", "travel"]:
			break
		if SliceFlow.papers_of(flow.train_g):
			flow._take(SliceFlow.pick_first(flow.train_g, flow.train_t))
		flow.train_on()
	assert_eq(flow.campaign_error, "")
	assert_eq(flow.port_error, "")
	assert_eq(flow.current(), wanted)


func test_slice_next_stop_builds_a_new_field_with_the_current_setting() -> void:
	if not _has_setting():
		return
	var starts: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/game/fixtures/campaign_starts.json"))
	assert_true(starts is Array and not starts.is_empty())
	if not (starts is Array) or starts.is_empty():
		return
	assert_eq(melee_press.save_enabled(false), OK)
	var flow := _slice({"mode": "campaign", "run": "melee_next_stop", "start_board": starts[0]})
	_reach_step(flow, "stop_pick")
	flow.next()
	assert_eq(flow.current(), "field")
	assert_not_null(flow.field)
	if flow.field == null:
		return
	await _wait_built(flow.field)
	var first_id: int = flow.field.get_instance_id()
	var first_visit: String = flow.field.opts["visit_id"]
	assert_false(melee_press.enabled(flow.field.opts))
	flow.field.finish("departed")
	flow.next()
	assert_eq(flow.current(), "receipt")
	flow.next()
	assert_eq(flow.current(), "council")
	if flow.train_g["phase"] == "council" and not flow.train_g["council"].get("result") is Dictionary:
		flow.card.cast()
	flow.next()
	_reach_step(flow, "arrive")
	flow.next()
	assert_eq(flow.current(), "stop_pick")
	assert_eq(melee_press.save_enabled(true), OK)
	flow.next()
	assert_eq(flow.current(), "field")
	assert_not_null(flow.field)
	if flow.field == null:
		return
	await _wait_built(flow.field)
	assert_ne(flow.field.get_instance_id(), first_id, "다음 정차는 새 인스턴스")
	assert_ne(flow.field.opts["visit_id"], first_visit, "다른 정차의 필드")
	assert_true(melee_press.enabled(flow.field.opts), "새 필드에도 현재 저장값을 얹는다")


func test_ranged_melee_pad_keeps_a_rejected_shove_order() -> void:
	_field({"melee_one_swing": true})
	game.player.hands = [{"id": "pistol", "quality": "factory", "condition": 0.9, "loaded": 0}]
	var target := _target()
	game.player.action = "swap"
	var at := _pad_press(game.hud.attack_button)
	assert_true(game.hud.finger_up(8, at))
	_step(0.2)
	_assert_target(target)
	assert_eq(game.player.swing_t, 0.0)
	game.player.action = ""
	_step(0.05)
	_assert_no_target()
	assert_gt(game.player.swing_t, 0.0, "실제 밀치기가 시작된 뒤 명령을 소비한다")
	assert_eq(_swings(), 0, "총을 든 근접의 기존 밀치기 유지")


func test_start_swing_reports_rejection_and_a_running_shove_start() -> void:
	_field()
	var target := _target()
	game.player.action = "swap"
	assert_false(game.combat.start_swing(game.player, target))
	assert_eq(_swings(), 0)
	game.player.action = ""
	game.player.running = true
	game.player.moving = true
	assert_true(game.player.is_running_now(), "실제로 달릴 수 있는 시험 상태")
	game.player.shove_rest_t = 0.2
	assert_false(game.combat.start_swing(game.player, target), "밀치기 쉼 동안 시작 거절")
	assert_eq(game.player.shove_t, 0.0)
	game.player.shove_rest_t = 0.0
	assert_true(game.combat.start_swing(game.player, target))
	assert_gt(game.player.shove_t, 0.0)
	assert_false(game.combat.start_swing(game.player, target), "이미 준비 중이면 거절")
	assert_eq(_swings(), 0, "달리는 동안의 기존 밀치기를 그대로 쓴다")


func _gun_for_fingers() -> void:
	game.player.set_weapon_slots([{"id": "pistol", "quality": "factory", "condition": 0.9, "loaded": 8}])
	game.hud.tick(0.0)


func test_reused_run_finger_preserves_another_fingers_aim_and_release_shot() -> void:
	_field({"run_mode": "hold"})
	_gun_for_fingers()
	_pad_press(game.hud.run_button, 7)
	var aim_at := _pad_press(game.hud.aim_button, 8)
	assert_true(game.hud.auto_aim)
	assert_true(game.player.aim.active)
	var crouch_at := _pad_press(game.hud.crouch_button, 7)
	assert_false(game.hud.run_button.button_pressed)
	assert_true(game.hud.auto_aim, "7번 RUN 취소는 8번 조준을 끝내지 않는다")
	assert_true(game.player.aim.active)
	assert_true(game.hud.finger_up(7, crouch_at))
	assert_true(_recorder().shots.is_empty())
	assert_true(game.hud.finger_up(8, aim_at))
	assert_eq(_recorder().shots.size(), 1, "8번의 정상 손 떼기는 발사 길로 간다")
	assert_false(game.player.aim.active)


func test_old_aim_pad_finger_does_not_cancel_the_new_aim_owner() -> void:
	_field()
	_gun_for_fingers()
	_pad_press(game.hud.aim_button, 7)
	var aim_at := _pad_press(game.hud.aim_button, 8)
	_pad_press(game.hud.crouch_button, 7)
	assert_true(game.hud.auto_aim, "같은 조준 pad도 마지막으로 시작한 손가락의 것")
	assert_true(game.player.aim.active)
	assert_true(game.hud.finger_up(8, aim_at))
	assert_eq(_recorder().shots.size(), 1)


func test_reusing_the_aim_owner_cancels_without_a_shot() -> void:
	_field()
	_gun_for_fingers()
	_pad_press(game.hud.aim_button, 7)
	assert_true(game.player.aim.active)
	_pad_press(game.hud.crouch_button, 7)
	assert_false(game.hud.auto_aim)
	assert_false(game.player.aim.active, "자기 조준은 재사용 때 끝낸다")
	assert_true(_recorder().shots.is_empty(), "취소는 발사가 아니다")


func test_stale_hand_cancellation_preserves_a_new_pad_melee_order() -> void:
	for how: String in ["reuse", "cancel", "focus"]:
		_field({"melee_one_swing": false, "melee_chain": false})
		var first := _target()
		_finger_press(first, 7)
		_hold()
		_wait_landed(1)
		first["state"] = "dead"
		_step(2.0)
		_assert_no_target()
		assert_false(game.player.hold_attack)
		assert_true(game.hud.melee_holding, "손 떼기를 잃은 옛 hand 표식은 아직 남음")
		var second := _target()
		var pad_at := _pad_press(game.hud.attack_button, 8)
		assert_true(game.hud.finger_up(8, pad_at))
		_assert_target(second)
		var before := _swings()
		if how == "reuse":
			_pad_press(game.hud.crouch_button, 7)
		elif how == "cancel":
			assert_true(game.hud.finger_cancel(7))
		else:
			game.hud.drop_touch()
		_assert_target(second)
		assert_true(game.player.hold_attack, "옛 hand는 새 pad의 B 연타를 소유하지 않는다: " + how)
		_step(4.0)
		assert_gt(_swings(), before + 1, "B의 반복이 이어진다")


func test_same_target_new_pad_order_is_not_owned_by_the_old_hand() -> void:
	_field({"melee_one_swing": false})
	var target := _target()
	_finger_press(target, 7)
	_hold()
	_wait_swings(1)
	var pad_at := _pad_press(game.hud.attack_button, 8)
	assert_true(game.hud.finger_up(8, pad_at))
	_assert_no_target()
	pad_at = _pad_press(game.hud.attack_button, 8)
	assert_true(game.hud.finger_up(8, pad_at))
	_assert_target(target)
	_pad_press(game.hud.crouch_button, 7)
	_assert_target(target)
	assert_true(game.player.hold_attack, "표적과 hold가 같아도 새로 받은 명령은 다른 소유권")
	_step(4.0)
	assert_gt(_swings(), 1)


func test_reused_hand_cancels_its_own_started_melee_order() -> void:
	_field({"melee_one_swing": false})
	var target := _target()
	_finger_press(target, 7)
	_hold()
	_wait_swings(1)
	assert_gt(game.player.strike_t, 0.0)
	_pad_press(game.hud.crouch_button, 7)
	_assert_no_target()
	assert_false(game.player.hold_attack)
	assert_eq(game.player.strike_at, target, "진행 중인 자기 타격은 끝까지")
	_step(4.0)
	assert_eq(_swings(), 1)
	assert_eq(_recorder().landed.size(), 1)


func _begin_far_repeat(person: bool) -> void:
	var target = _enemy(person)
	var far: Vector3 = game.player.position + Vector3(4.0, 0, 0)
	if target is Dictionary:
		target["pos"] = far
	else:
		target.position = far
	game._refresh_vision()
	_finger_press(target, 7)
	_hold()
	_step(0.05)
	assert_false(game.player.path.is_empty(), "전투가 실제 접근 길을 만들었다")
	assert_eq(_swings(), 0)


func _step_with_player_movement(seconds: float) -> void:
	for _i in range(ceili(seconds / 0.05)):
		_step(0.05)
		game._update_person(game.player, 0.05)


func test_cancel_before_first_swing_stops_the_melee_approach() -> void:
	for person: bool in [false, true]:
		_field({"melee_one_swing": false})
		_begin_far_repeat(person)
		_step_with_player_movement(0.3)
		assert_eq(_swings(), 0, "첫 공격 전에 취소하는 시험")
		assert_false(game.player.path.is_empty())
		var before: Vector3 = game.player.position
		assert_true(game.hud.finger_cancel(7))
		assert_true(game.player.path.is_empty(), "연타 명령이 만든 접근 길도 끝낸다")
		assert_false(game.player.brain.has("goal"))
		_assert_no_target()
		_step_with_player_movement(4.0)
		assert_eq(game.player.position, before, "취소 뒤 실제 이동 소비를 해도 적에게 가지 않는다")
		assert_eq(_swings(), 0)


func test_old_hand_cancel_does_not_stop_stick_movement() -> void:
	_field({"melee_one_swing": false})
	_begin_far_repeat(false)
	var home: Vector2 = game.hud.stick_home()
	var away: Vector2 = (-game.hud._fight_dir(game.player)).rotated(deg_to_rad(game.CAM_YAW))
	assert_true(game.hud.finger_down(8, home))
	assert_true(game.hud.finger_move(8, home + away * game.hud.STICK_R * 0.8))
	_step_with_player_movement(0.2)
	var stick: Vector2 = game.player.stick
	var speed: float = game.player.drive_speed
	var before: Vector3 = game.player.position
	assert_gt(stick.length(), 0.0)
	assert_gt(speed, 0.0)
	assert_true(game.hud.finger_cancel(7))
	assert_eq(game.player.stick, stick)
	assert_eq(game.player.drive_speed, speed, "전투 취소가 직접 걷기의 관성을 지우지 않는다")
	_step_with_player_movement(0.2)
	assert_gt(game.player.position.distance_to(before), 0.0)
	assert_eq(game.hud.stick_index, 8)


func test_melee_cancel_keeps_a_replacement_path_and_its_goal() -> void:
	_field({"melee_one_swing": false})
	_begin_far_repeat(false)
	var goal: Vector3 = game.player.position + Vector3(0, 0, 3.0)
	var replacement := PackedVector3Array([goal])
	game.player.go_to(replacement, false)
	game.player.brain["goal"] = goal
	assert_true(game.hud.finger_cancel(7))
	_assert_no_target()
	assert_false(game.player.hold_attack)
	assert_eq(game.player.path, replacement, "뒤에 받은 별도 이동 경로는 남긴다")
	assert_eq(game.player.brain.get("goal"), goal, "전투가 소유하지 않은 이동 목표 보존")
