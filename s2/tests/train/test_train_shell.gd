extends "res://addons/gut/test.gd"
## 열차 칸 껍데기(tools/blender/train_shell.py): 장부·파일, 칸마다 껍데기와 창 자리,
## 난방에 따른 벽 빛깔, 과밀 단계에 따라 늘어나는 짐·담요.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const SHELL_DIR := "res://models/train_shell"


func _scene() -> Scene:
	var s: Scene = Scene.new()
	s.rules = Rules.load_default()
	s.opts = {"seed": 7, "panel": false}
	add_child_autofree(s)
	return s


func test_the_five_shells_match_their_catalog_and_budget() -> void:
	var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHELL_DIR + "/catalog.json"))
	var assets: Dictionary = book["assets"]
	assert_eq(assets.keys().size(), 5)
	assert_eq(int(book["script_version"]), 3)
	assert_almost_eq(float(book["cut_y_m"]), Scene.SHELL_CUT_Y, 0.0001)
	for variant: String in ["plain", "clean", "chief", "medic", "engine"]:
		var id: String = "shell_" + variant
		assert_true(assets.has(id), id)
		var path: String = "%s/%s.glb" % [SHELL_DIR, id]
		assert_true(ResourceLoader.exists(path), path)
		assert_eq(FileAccess.get_sha256(path), assets[id]["sha256"], id)
		assert_eq(FileAccess.get_file_as_bytes(path).size(), int(assets[id]["bytes"]), id)
		assert_eq(int(assets[id]["tris_low"]) + int(assets[id]["tris_top"]), int(assets[id]["tris"]), id)
		assert_lte(int(assets[id]["tris"]), int(book["triangle_limit"]), id)
		var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		autofree(model)
		var mesh_nodes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
		assert_eq(mesh_nodes.size(), 2, id)
		var counts: Dictionary = {"low": 0, "top": 0}
		var minimum: Vector3 = Vector3(INF, INF, INF)
		var maximum: Vector3 = Vector3(-INF, -INF, -INF)
		var shared_material: Material = null
		for mesh_node: Node in mesh_nodes:
			var shell_mesh: MeshInstance3D = mesh_node as MeshInstance3D
			var part: String = String(shell_mesh.name)
			assert_true(counts.has(part), id + "/" + part)
			if not counts.has(part):
				continue
			assert_eq(shell_mesh.mesh.get_surface_count(), 1, id + "/" + part)
			var arrays: Array = shell_mesh.mesh.surface_get_arrays(0)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			counts[part] = int(indices.size() / 3.0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var point: Vector3 = shell_mesh.transform * vertex
				minimum = minimum.min(point)
				maximum = maximum.max(point)
				if part == "low":
					assert_lte(point.y, Scene.SHELL_CUT_Y + 0.0001, id + "/low")
				else:
					assert_gte(point.y, Scene.SHELL_CUT_Y - 0.0001, id + "/top")
			var part_material: Material = shell_mesh.get_active_material(0)
			assert_not_null(part_material)
			if shared_material == null:
				shared_material = part_material
			else:
				assert_eq(part_material, shared_material, id + " shares one material")
		assert_eq(int(counts["low"]), int(assets[id]["tris_low"]), id)
		assert_eq(int(counts["top"]), int(assets[id]["tris_top"]), id)
		for axis: int in 3:
			assert_almost_eq(minimum[axis], float(assets[id]["bounds_m"][0][axis]), 0.0001, id)
			assert_almost_eq(maximum[axis], float(assets[id]["bounds_m"][1][axis]), 0.0001, id)


func test_every_car_wears_its_shell_and_the_glass_sits_in_the_reveal() -> void:
	var s: Scene = _scene()
	for c: Dictionary in s.cars:
		var shell: Node = (c["node"] as Node3D).get_node_or_null("Shell")
		assert_not_null(shell, c["id"])
		assert_true(c.has("shell_mat"), c["id"])
		if shell != null:
			assert_eq(shell.find_children("*", "MeshInstance3D", true, false).size(), 2, c["id"])
	var panes := 0
	for child in (s.car("tail1")["node"] as Node3D).get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).material_override == s.car("tail1")["glass"]:
			panes += 1
			assert_almost_eq((child as Node3D).position.z, Scene.SHELL_GLASS_Z + 0.02, 0.001)
	assert_eq(panes, 4)
	assert_not_null(s.backdrop, "land and sky behind the windows")


## 기관차는 객차 창·나무 벽 대신 쇠판 벽(운전실 창 하나) 껍데기를 입고, 사람 칸은 그대로다(열세 칸 점검).
func test_the_locomotive_wears_the_iron_shell() -> void:
	var s = _scene()
	var loco: Dictionary = {}
	for c in s.cars:
		if String((c["def"] as Dictionary).get("kind", "")) == "loco":
			loco = c
	assert_false(loco.is_empty(), "the default train has its locomotive")
	if loco.is_empty():
		return
	var shell: Node = (loco["node"] as Node3D).get_node_or_null("Shell")
	assert_not_null(shell)
	if shell != null:
		assert_string_ends_with(shell.scene_file_path, "shell_engine.glb")
	var tail: Node = (s.car("tail1")["node"] as Node3D).get_node_or_null("Shell")
	assert_string_ends_with(tail.scene_file_path, "shell_plain.glb")


func test_a_cold_car_looks_bluer_than_a_warm_one() -> void:
	var s: Scene = _scene()
	assert_true(s.set_sit("tail", 0, 85.0))
	var warm: Color = s.car("tail1")["shell_mat"].albedo_color
	_assert_tinted(s.car("tail1"), warm)
	assert_true(s.set_sit("tail", 0, 15.0))
	var cold: Color = s.car("tail1")["shell_mat"].albedo_color
	_assert_tinted(s.car("tail1"), cold)
	assert_gt(cold.b - cold.r, warm.b - warm.r)


## Every piece of the car's shell takes the tint: the atlas pieces as it is, a plain
## piece (the diagonal view's front wall) over its own colour.
func _assert_tinted(c: Dictionary, tint: Color) -> void:
	var materials: Array = c["shell_mats"]
	for material_index: int in materials.size():
		var shell_material: StandardMaterial3D = materials[material_index]
		var base: Color = Color.WHITE if shell_material.albedo_texture != null else c["shell_colors"][material_index]
		var expected: Color = Color(base.r * tint.r, base.g * tint.g, base.b * tint.b, base.a)
		assert_true(shell_material.albedo_color.is_equal_approx(expected), String(c["id"]))


func test_shell_fragments_share_the_car_materials() -> void:
	var s: Scene = _scene()
	var car_materials: Array[Material] = []
	for c: Dictionary in s.cars:
		var shell: Node = (c["node"] as Node3D).get_node("Shell")
		var materials: Array = c["shell_mats"]
		# One atlas material for the shell's pieces, and the front wall's own plain one.
		assert_eq(materials.size(), 2, c["id"])
		assert_true(materials.has((c["front_wall"] as MeshInstance3D).material_override), c["id"])
		for shell_material: Material in materials:
			assert_false(car_materials.has(shell_material), "each car owns its tint")
			car_materials.append(shell_material)
		for mesh_node: Node in shell.find_children("*", "MeshInstance3D", true, false):
			var shell_mesh: MeshInstance3D = mesh_node as MeshInstance3D
			for surface_index: int in shell_mesh.mesh.get_surface_count():
				assert_true(materials.has(shell_mesh.get_active_material(surface_index)), c["id"])
			if shell_mesh.name == &"low":
				assert_eq(shell_mesh.get_active_material(0), c["shell_mat"], "legacy tint is low")
			elif shell_mesh.name == &"top":
				assert_true((c["shell_top"] as Array).has(shell_mesh), c["id"])


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
