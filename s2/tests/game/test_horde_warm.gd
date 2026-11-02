extends "res://addons/gut/test.gd"
## 부팅 무리 데우기: 꺼짐 판은 무읽기, 켬 판은 셰이더·아틀라스를 붙잡고 숨은 그림 뒤 스스로 걷힌다.
## 화면 없는 실행이라 실제 컴파일은 못 본다 — 그 몫은 문지기 촬영·폰 재기에서.

const Horde = preload("res://game/world/horde_view.gd")
const Warm = preload("res://game/world/horde_warm.gd")
const Switch = preload("res://game/perf_switch.gd")
const Pace = preload("res://game/world/build_pace.gd")
const Boot = preload("res://game/boot.gd")


func before_each() -> void:
	Warm.warmed = false
	Warm.last_stats = {}


func _wait_gone(node: Node, frames: int = 900) -> void:
	for _frame: int in range(frames):
		if not is_instance_valid(node):
			return
		await get_tree().process_frame


func test_off_switches_read_nothing() -> void:
	var parent := Node.new()
	add_child_autofree(parent)
	var reads: int = Horde.resource_reads
	assert_null(Warm.start(parent, Switch._valid({"horde": false})), "무리 꺼짐")
	assert_null(Warm.start(parent, Switch._valid({"horde_warm": false})), "데우기 끔(폰 재기의 끔 판)")
	assert_eq(parent.get_child_count(), 0)
	assert_eq(Horde.resource_reads, reads)
	assert_eq(Switch._valid({"horde_warm": false}), {"horde_warm": false})
	assert_eq(Switch._valid({"horde_warm": true}), {"horde_warm": true})
	assert_false(Switch._valid({"horde_warm": "off"}).has("horde_warm"), "참/거짓만 받는다")


func test_warm_keeps_the_shader_and_atlas_and_draws_once_then_leaves() -> void:
	var parent := Node.new()
	add_child_autofree(parent)
	var node: Node = Warm.start(parent, {})
	assert_not_null(node)
	await _wait_gone(node)
	assert_false(is_instance_valid(node), "다 데우면 스스로 걷힌다")
	assert_true(bool(Warm.last_stats.get("drawn", false)), str(Warm.last_stats))
	assert_true(Horde._shader_kept is Shader)
	assert_true(Horde._atlas_kept is Texture2D)
	assert_eq(Horde._atlas_kept.get_size(), Vector2(Horde.ATLAS_SIZE))
	assert_null(get_viewport().get_camera_3d(), "숨은 카메라는 남지 않는다")
	assert_true(Horde._orphan_paths.is_empty(), "요청 하나에 get 하나 — 남은 요청 없음")
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
	assert_true(Horde._shader_kept is Shader, "읽기는 한다")


func test_freed_before_done_hands_open_reads_to_the_collector() -> void:
	# 부팅이 바로 지워져도(이어 하기로 곧장 필드) 요청 하나에 get 하나는 수거 목록이 한다.
	var parent := Node.new()
	add_child(parent)
	var node: Node = Warm.start(parent, {})
	assert_not_null(node)
	parent.free()
	assert_eq(String(Warm.last_stats.get("reason", "")), "freed before warm end")
	for _frame: int in range(600):
		if Horde._orphan_paths.is_empty():
			break
		await get_tree().process_frame
	assert_true(Horde._orphan_paths.is_empty(), "읽기가 끝나면 get으로 회수")


func test_boot_starts_the_warm_right_after_the_fps_cap() -> void:
	var boot = Boot.new()
	add_child_autofree(boot)
	var warm: Node = boot.get_node_or_null("HordeWarm")
	assert_not_null(warm, "부팅 메뉴 동안 데운다")
	await _wait_gone(warm)
	# 그렸는지는 그사이 필드가 떴는지에 달렸다(로컬 이어 하기 저장이 있으면 곧장 필드) — 끝난 것만 본다.
	assert_false(Warm.last_stats.is_empty(), "결과 줄 한 번")
	assert_null(boot.get_node_or_null("HordeWarm"))
