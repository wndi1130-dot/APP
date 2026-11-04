extends "res://addons/gut/test.gd"
## 부팅 무리 데우기: 꺼짐 판은 무읽기, 켬 판은 셰이더·아틀라스를 붙잡고 숨은 그림 뒤 스스로 걷힌다.
## 화면 없는 실행이라 실제 컴파일은 못 본다 — 그 몫은 실제 렌더러 탐침·폰 재기에서.

const Horde = preload("res://game/world/horde_view.gd")
const Warm = preload("res://game/world/horde_warm.gd")
const Switch = preload("res://game/perf_switch.gd")
const Pace = preload("res://game/world/build_pace.gd")
const Boot = preload("res://game/boot.gd")


# 읽기 상한 + 렌더 끝 기다림 상한 + 뿌리에 붙는 틈·걷히는 틈.
const GONE_FRAMES: int = Warm.WAIT_FRAMES + Warm.DRAW_WAIT_FRAMES + 30


func before_each() -> void:
	# 앞 시험의 데우기가 남았으면 걷고(남은 요청은 수거로) 수거가 끝난 뒤, 빈 자리에서 시작한다.
	await _clear_left()
	Warm.warmed = false
	Warm.last_stats = {}
	Horde._shader_kept = null
	Horde._atlas_kept = null
	# 이 파일의 시험은 화면 없는 판에서도 숨은 그림·카메라 처리를 본다(다른 시험 파일에서는 꺼져 있다).
	Warm.rig_without_screen = true


func after_each() -> void:
	await _clear_left()
	Warm.rig_without_screen = false


func _clear_left() -> void:
	var left: Node = get_tree().root.get_node_or_null("HordeWarm")
	if left != null:
		left.free()
	for _frame: int in range(GONE_FRAMES):
		if Warm._keep_paths.is_empty():
			return
		await get_tree().process_frame


func _wait_gone(node: Node, frames: int = GONE_FRAMES) -> void:
	for _frame: int in range(frames):
		if not is_instance_valid(node):
			return
		await get_tree().process_frame


func _wait_kept(frames: int = 900) -> void:
	for _frame: int in range(frames):
		if Warm._keep_paths.is_empty() and Horde._shader_kept != null and Horde._atlas_kept != null:
			return
		await get_tree().process_frame


func test_off_switches_read_nothing() -> void:
	var parent := Node.new()
	add_child_autofree(parent)
	var reads: int = Horde.resource_reads
	assert_null(Warm.start(parent, Switch._valid({"horde": false})), "무리 꺼짐")
	assert_null(Warm.start(parent, Switch._valid({"horde_warm": false})), "데우기 끔(폰 재기의 끔 판)")
	await get_tree().process_frame
	assert_null(get_tree().root.get_node_or_null("HordeWarm"))
	assert_eq(Horde.resource_reads, reads)
	assert_null(Horde._atlas_kept)
	assert_eq(Switch._valid({"horde_warm": false}), {"horde_warm": false})
	assert_eq(Switch._valid({"horde_warm": true}), {"horde_warm": true})
	assert_false(Switch._valid({"horde_warm": "off"}).has("horde_warm"), "참/거짓만 받는다")


func test_warm_keeps_the_shader_and_atlas_and_leaves_without_a_camera() -> void:
	assert_null(Horde._atlas_kept, "빈 자리에서 시작")
	var parent := Node.new()
	add_child_autofree(parent)
	var reads: int = Horde.resource_reads
	var node: Node = Warm.start(parent, {})
	assert_not_null(node)
	await get_tree().process_frame
	assert_eq(node.get_parent(), get_tree().root, "부팅 장면이 아니라 뿌리에 — 장면이 바뀌어도 산다")
	assert_between(Horde.resource_reads - reads, 2, 3, "아틀라스·셰이더 요청 둘(+ 칸 표)")
	await _wait_gone(node)
	assert_false(is_instance_valid(node), "끝나면 스스로 걷힌다")
	assert_true(Horde._shader_kept is Shader, str(Warm.last_stats))
	assert_true(Horde._atlas_kept is Texture2D)
	assert_eq(Horde._atlas_kept.get_size(), Vector2(Horde.ATLAS_SIZE))
	assert_null(get_viewport().get_camera_3d(), "숨은 카메라는 남지 않는다")
	assert_true(Warm._keep_paths.is_empty(), "요청 하나에 get 하나 — 남은 요청 없음")
	# 그렸다(drawn)는 그 카메라로 렌더가 끝난 신호를 센 것: 렌더가 끝나지 않는 판은 그리지 않은 것으로 남는다.
	var drawn: bool = bool(Warm.last_stats.get("drawn", false))
	assert_eq(drawn, int(Warm.last_stats.get("post_draws", 0)) >= Warm.DRAW_FRAMES, str(Warm.last_stats))
	assert_true(String(Warm.last_stats.get("reason", "?")) in ["", "no render finished"], str(Warm.last_stats))
	assert_eq(Warm.warmed, drawn, "실제로 그린 판만 다시 안 함")
	if drawn:
		assert_null(Warm.start(parent, {}), "데운 뒤에는 되풀이하지 않는다")
	# 첫 정차의 무리 짓기는 붙잡은 두 자원을 캐시로 받는다.
	var horde_parent := Node3D.new()
	add_child_autofree(horde_parent)
	var horde: Horde = await Horde.attach(horde_parent, Horde.test_walls(), {"map_size": Vector2(120, 80)}, Pace.new(), {})
	assert_true(bool(horde.stats["ready"]))
	assert_eq(int(horde.stats["resource_cached"]), 2)
	assert_eq(int(horde.stats["resource_first"]), 0)


func test_warm_does_not_take_a_camera_that_is_already_up() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.make_current()
	var parent := Node.new()
	add_child_autofree(parent)
	var node: Node = Warm.start(parent, {})
	await _wait_gone(node)
	assert_eq(get_viewport().get_camera_3d(), camera, "필드 카메라는 그대로")
	assert_false(bool(Warm.last_stats.get("drawn", true)))
	assert_eq(String(Warm.last_stats.get("reason", "")), "another camera is up; read only")
	assert_true(Horde._shader_kept is Shader, "읽기·붙잡기는 한다")
	assert_true(Horde._atlas_kept is Texture2D)


func test_leaving_does_not_turn_on_a_camera_someone_switched_off() -> void:
	# 등록돼 있지만 일부러 꺼 둔 카메라: 데우기가 걷힐 때 그 카메라를 대신 켜면 안 된다.
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.make_current()
	camera.clear_current(false)
	assert_null(get_viewport().get_camera_3d())
	var parent := Node.new()
	add_child_autofree(parent)
	var node: Node = Warm.start(parent, {})
	await _wait_gone(node)
	assert_null(get_viewport().get_camera_3d(), "꺼 둔 카메라는 꺼진 그대로")
	assert_false(camera.is_current())


func test_freed_before_done_still_keeps_what_it_asked_for() -> void:
	# 다 받기 전에 지워져도(앱 정리 등) 요청은 붙잡는 수거가 받아 HordeView 자리에 넣는다.
	var parent := Node.new()
	add_child_autofree(parent)
	var node: Node = Warm.start(parent, {})
	await get_tree().process_frame
	assert_true(is_instance_valid(node) and node.is_inside_tree())
	node.free()
	assert_eq(String(Warm.last_stats.get("reason", "")), "freed before warm end")
	assert_false(bool(Warm.last_stats.get("drawn", true)))
	await _wait_kept()
	assert_true(Warm._keep_paths.is_empty(), "읽기가 끝나면 get으로 회수")
	assert_true(Horde._shader_kept is Shader, "받은 셰이더를 붙잡는다")
	assert_true(Horde._atlas_kept is Texture2D, "받은 아틀라스를 붙잡는다")


func test_freed_before_it_reaches_the_tree_ends_quietly_with_no_reads() -> void:
	# 뿌리에 붙기 전(다음 틈 전)에 지움: _ready 전이라 요청 0, 끝 처리는 기본값 키로 오류 없이.
	var parent := Node.new()
	add_child_autofree(parent)
	var reads: int = Horde.resource_reads
	var node: Node = Warm.start(parent, {})
	assert_false(node.is_inside_tree(), "아직 뿌리에 안 붙음")
	node.free()
	assert_eq(String(Warm.last_stats.get("reason", "")), "freed before warm end")
	assert_false(bool(Warm.last_stats.get("drawn", true)))
	assert_eq(float(Warm.last_stats.get("ms", -1.0)), 0.0, "시작 안 한 판은 0 ms")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(get_tree().root.get_node_or_null("HordeWarm"), "지운 노드를 뒤늦게 붙이지 않는다")
	assert_eq(Horde.resource_reads, reads, "요청 0")
	assert_true(Warm._keep_paths.is_empty())
	# 트리 밖 부모에 붙은 채 지워져도 같다.
	var outside := Node.new()
	var other: Node = Warm.start(outside, {})
	assert_eq(other.get_parent(), outside)
	outside.free()
	assert_eq(String(Warm.last_stats.get("reason", "")), "freed before warm end")
	assert_eq(Horde.resource_reads, reads)


func test_drawn_counts_even_if_the_camera_changes_right_after() -> void:
	# 두 번째 렌더 끝 바로 뒤, 다음 처리 전에 다른 카메라가 켜져도 그린 판으로 남는다.
	var parent := Node.new()
	add_child_autofree(parent)
	var node: Node = Warm.start(parent, {})
	for _frame: int in range(GONE_FRAMES):
		if not is_instance_valid(node) or node.get("_rig") != null:
			break
		await get_tree().process_frame
	assert_true(is_instance_valid(node) and node.get("_rig") != null, "숨은 그림이 섰다")
	node.call("_on_post_draw")
	node.call("_on_post_draw")
	var game_camera := Camera3D.new()
	add_child_autofree(game_camera)
	game_camera.make_current()
	await _wait_gone(node)
	assert_true(bool(Warm.last_stats.get("drawn", false)), str(Warm.last_stats))
	assert_eq(String(Warm.last_stats.get("reason", "?")), "")
	assert_true(Warm.warmed)
	assert_eq(get_viewport().get_camera_3d(), game_camera, "필드 카메라는 그대로")


func test_no_screen_reads_only_and_never_holds_a_camera() -> void:
	# 부팅을 띄우는 다른 시험(화면 없음)의 데우기: 숨은 카메라를 한 프레임도 current로 두지 않고, 읽기·붙잡기만 하고 걷힌다.
	# (카메라가 남으면 뒤 시험 파일의 건물 뷰가 그 카메라로 가까운 건물을 고른다 — #1399 GUT 3/3.)
	if DisplayServer.get_name() != "headless":
		pass_test("화면 있는 실행: 숨은 그림을 세우는 판")
		return
	Warm.rig_without_screen = false
	var parent := Node.new()
	add_child_autofree(parent)
	var node: Node = Warm.start(parent, {})
	var held: int = 0
	for _frame: int in range(GONE_FRAMES):
		if not is_instance_valid(node):
			break
		if get_viewport().get_camera_3d() != null or node.get("_rig") != null:
			held += 1
		await get_tree().process_frame
	assert_false(is_instance_valid(node), "읽기가 끝나면 바로 걷힌다(렌더 끝 기다림 없음)")
	assert_eq(held, 0, "숨은 그림·카메라를 세우지 않는다")
	assert_eq(String(Warm.last_stats.get("reason", "?")), "no screen; read only", str(Warm.last_stats))
	assert_false(bool(Warm.last_stats.get("drawn", true)))
	assert_false(Warm.warmed, "그리지 않았으니 다음 부팅은 다시 데운다")
	assert_true(Horde._shader_kept is Shader, "읽기·붙잡기는 한다")
	assert_true(Horde._atlas_kept is Texture2D)
	assert_null(get_viewport().get_camera_3d())


func test_boot_starts_the_warm_right_after_the_fps_cap() -> void:
	var boot = Boot.new()
	# 로컬 이어 하기 저장·자동 시작 환경으로 장면이 바뀌지 않게: 시험 전용(없는) 경로, S2_AUTOSTART 잠시 비움.
	boot.slice_save_path = "user://_test_horde_warm_none_slice.save"
	boot.field_save_path = "user://_test_horde_warm_none_field.save"
	boot.train_save_path = "user://_test_horde_warm_none_train.save"
	var auto: String = OS.get_environment("S2_AUTOSTART")
	OS.unset_environment("S2_AUTOSTART")
	add_child_autofree(boot)
	if auto != "":
		OS.set_environment("S2_AUTOSTART", auto)
	await get_tree().process_frame
	var warm: Node = get_tree().root.get_node_or_null("HordeWarm")
	assert_not_null(warm, "부팅 메뉴 동안 데운다")
	assert_not_null(boot.get("menu"), "저장이 없으면 메뉴")
	await _wait_gone(warm)
	assert_false(Warm.last_stats.is_empty(), "결과 줄 한 번")
	assert_true(String(Warm.last_stats.get("reason", "?")) in ["", "no render finished"], str(Warm.last_stats))
	assert_null(get_tree().root.get_node_or_null("HordeWarm"))
