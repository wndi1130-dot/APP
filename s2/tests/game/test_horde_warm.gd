extends "res://addons/gut/test.gd"
## 부팅 무리 데우기: 꺼짐 판은 무읽기, 켬 판은 셰이더·아틀라스를 붙잡고 숨은 그림 뒤 스스로 걷힌다.
## 화면 없는 실행이라 실제 컴파일은 못 본다 — 그 몫은 실제 렌더러 탐침·폰 재기에서.

const Horde = preload("res://game/world/horde_view.gd")
const Warm = preload("res://game/world/horde_warm.gd")
const Switch = preload("res://game/perf_switch.gd")
const Pace = preload("res://game/world/build_pace.gd")
const Boot = preload("res://game/boot.gd")


func before_each() -> void:
	# 앞선 무리 시험이 채운 붙잡기로 통과하지 않게, 빈 자리에서 시작한다.
	Warm.warmed = false
	Warm.last_stats = {}
	Horde._shader_kept = null
	Horde._atlas_kept = null


func _wait_gone(node: Node, frames: int = 900) -> void:
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


func test_boot_starts_the_warm_right_after_the_fps_cap() -> void:
	var boot = Boot.new()
	# 로컬 이어 하기 저장으로 장면이 바뀌지 않게 시험 전용(없는) 경로로.
	boot.slice_save_path = "user://_test_horde_warm_none_slice.save"
	boot.field_save_path = "user://_test_horde_warm_none_field.save"
	boot.train_save_path = "user://_test_horde_warm_none_train.save"
	add_child_autofree(boot)
	await get_tree().process_frame
	var warm: Node = get_tree().root.get_node_or_null("HordeWarm")
	assert_not_null(warm, "부팅 메뉴 동안 데운다")
	assert_not_null(boot.get("menu"), "저장이 없으면 메뉴")
	await _wait_gone(warm)
	assert_false(Warm.last_stats.is_empty(), "결과 줄 한 번")
	assert_true(String(Warm.last_stats.get("reason", "?")) in ["", "no render finished"], str(Warm.last_stats))
	assert_null(get_tree().root.get_node_or_null("HordeWarm"))
