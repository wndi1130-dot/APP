extends "res://addons/gut/test.gd"
## 열차 칸 껍데기(tools/blender/train_shell.py): 장부·파일, 칸마다 껍데기와 창 자리,
## 난방에 따른 벽 빛깔, 과밀 단계에 따라 늘어나는 짐·담요.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const SHELL_DIR := "res://models/train_shell"


func _scene() -> Node3D:
	var s := Scene.new()
	s.rules = Rules.load_default()
	s.opts = {"seed": 7, "panel": false}
	add_child_autofree(s)
	return s


func test_the_four_shells_match_their_catalog_and_budget() -> void:
	var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHELL_DIR + "/catalog.json"))
	var assets: Dictionary = book["assets"]
	assert_eq(assets.keys().size(), 4)
	for variant in ["plain", "clean", "chief", "medic"]:
		var id: String = "shell_" + variant
		assert_true(assets.has(id), id)
		var path: String = "%s/%s.glb" % [SHELL_DIR, id]
		assert_true(ResourceLoader.exists(path), path)
		assert_eq(FileAccess.get_sha256(path), assets[id]["sha256"], id)
		assert_lte(int(assets[id]["tris"]), int(book["triangle_limit"]), id)


func test_every_car_wears_its_shell_and_the_glass_sits_in_the_reveal() -> void:
	var s = _scene()
	for c in s.cars:
		var shell: Node = (c["node"] as Node3D).get_node_or_null("Shell")
		assert_not_null(shell, c["id"])
		assert_true(c.has("shell_mat"), c["id"])
	var panes := 0
	for child in (s.car("tail1")["node"] as Node3D).get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).material_override == s.car("tail1")["glass"]:
			panes += 1
			assert_almost_eq((child as Node3D).position.z, Scene.SHELL_GLASS_Z + 0.02, 0.001)
	assert_eq(panes, 4)
	assert_not_null(s.backdrop, "land and sky behind the windows")


func test_a_cold_car_looks_bluer_than_a_warm_one() -> void:
	var s = _scene()
	assert_true(s.set_sit("tail", 0, 85.0))
	var warm: Color = s.car("tail1")["shell_mat"].albedo_color
	assert_true(s.set_sit("tail", 0, 15.0))
	var cold: Color = s.car("tail1")["shell_mat"].albedo_color
	assert_gt(cold.b - cold.r, warm.b - warm.r)


func test_crowding_brings_out_sacks_and_bedding_step_by_step() -> void:
	var s = _scene()
	var props: Dictionary = s.life.rooms["tail1"].props
	assert_true(s.set_sit("tail", 2, 20.0))
	assert_false(props["under_sacks"].visible)
	assert_false(props["floor_bedding_a"].visible)
	assert_true(s.set_sit("tail", 2, 85.0))
	assert_true(props["under_sacks"].visible)
	assert_true(props["under_crates"].visible)
	assert_false(props["floor_bedding_a"].visible)
	assert_true(s.set_sit("tail", 2, 97.0))
	assert_true(props["floor_bedding_a"].visible)
