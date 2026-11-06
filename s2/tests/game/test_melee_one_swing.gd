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

	func _init(field_game) -> void:
		super(field_game)

	func fight(p, target, hold: bool) -> void:
		holds.append(hold)
		super.fight(p, target, hold)

	func _strike(p, at) -> void:
		# 살아 있는 같은 적에게 두 번째 공격이 나오는지 피해 난수 없이 확인한다.
		landed.append({"person": p, "target": at})
		p.swing_t = 1.0


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
