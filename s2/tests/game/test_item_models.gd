extends "res://addons/gut/test.gd"
## Primitive loot pictures can be checked without a viewport or a rendered frame.

const ItemModels = preload("res://tools/item_models.gd")
## The clothes' and the food bundle's shared pictures (it_shirt … it_hood, food,
## it_herbs) gave way to each thing's own (item_models_wear.gd, item_models_goods.gd).
const NEW_KEYS: Array[String] = [
	"it_apple", "it_apple_wilted", "it_meat", "it_meat_bad", "it_hare",
	"it_bread_moldy", "it_tube", "it_toilet_paper", "it_soap",
	"it_child_clothes", "it_old_clothes", "it_razor", "gear", "it_nails", "it_opener",
	"it_fuel", "it_spring", "it_record", "it_violin", "ammo_pistol", "ammo_shell",
	"it_bottle_broken", "it_stake",
	"pack", "it_wire",
	"it_syrup", "clock", "it_pocket_watch", "it_sewing_kit", "it_needle",
	"it_doctor_box", "herbal_book", "it_saline", "it_toy",
]
const GONE_KEYS: Array[String] = [
	"it_shirt", "it_trousers", "it_gloves", "it_undershirt", "it_drawers", "it_sweater",
	"it_overalls", "it_socks", "it_scarf", "it_cap", "it_mask", "it_dress", "food",
	"it_herbs", "it_coat", "it_jacket", "it_vest", "it_hat", "it_hood",
]


func test_ids_include_all_34_picture_keys_and_none_of_the_shared_clothes() -> void:
	assert_eq(NEW_KEYS.size(), 34)
	var available: Array = ItemModels.ids()
	for key: String in NEW_KEYS:
		assert_has(available, key, key + " has a recipe")
	for gone: String in GONE_KEYS:
		assert_does_not_have(available, gone, gone + " gave way to each thing's own picture")


func test_empty_or_unregistered_picture_keys_return_null() -> void:
	var unknown_keys: Array[String] = [
		"", "missing_loot_picture", "없는 물건 / 등록 안 됨", "긴 이름/".repeat(128),
	]
	for key: String in unknown_keys:
		var model: Node3D = ItemModels.build(key)
		assert_null(model, "an unregistered key has no model: " + key)
		if model != null:
			model.free()


func test_all_new_models_have_grounded_geometry_and_muted_materials() -> void:
	for key: String in NEW_KEYS:
		var model: Node3D = ItemModels.build(key)
		assert_not_null(model, key + " builds")
		if model == null:
			continue
		var parts: Array[Dictionary] = []
		_collect_meshes(model, Transform3D.IDENTITY, parts)
		assert_gte(parts.size(), 2, key + " has at least two mesh instances")
		var combined: AABB = AABB()
		var have_bounds: bool = false
		for entry: Dictionary in parts:
			var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
			assert_not_null(instance.mesh, key + " has a mesh resource")
			if instance.mesh == null:
				continue
			var pose: Transform3D = entry["pose"]
			var local_box: AABB = instance.mesh.get_aabb()
			var part_box: AABB = AABB(pose * local_box.get_endpoint(0), Vector3.ZERO)
			for corner: int in range(1, 8):
				part_box = part_box.expand(pose * local_box.get_endpoint(corner))
			combined = combined.merge(part_box) if have_bounds else part_box
			have_bounds = true
			assert_gt(instance.mesh.get_surface_count(), 0, key + " has a surface")
			for surface: int in instance.mesh.get_surface_count():
				var material: BaseMaterial3D = instance.get_active_material(surface) as BaseMaterial3D
				assert_not_null(material, key + " has an albedo material on every surface")
				if material == null:
					continue
				assert_lte(material.albedo_color.s, 0.75, key + " saturation")
				assert_gte(material.albedo_color.v, 0.12, key + " brightness")
		assert_true(have_bounds, key + " has measurable geometry")
		if have_bounds:
			for axis: int in 3:
				assert_between(combined.size[axis], 0.06, 0.6, key + " axis " + str(axis) + " in metres")
			# Foot on y = 0: neither sunk under it nor floating above it.
			assert_between(combined.position.y, -0.01, 0.01, key + " rests at y = 0")
		model.free()


## The body's proxy volume is its mesh AABB times scale, independent of rotation.
## Check every tied largest part so a pale duplicate cannot escape the limit.
func test_largest_mesh_parts_are_not_brighter_than_point_eight() -> void:
	for key: String in NEW_KEYS:
		var model: Node3D = ItemModels.build(key)
		assert_not_null(model, key + " builds for the body colour check")
		if model == null:
			continue
		var parts: Array[Dictionary] = []
		_collect_meshes(model, Transform3D.IDENTITY, parts)
		var largest_volume: float = -1.0
		var largest_parts: Array[MeshInstance3D] = []
		for entry: Dictionary in parts:
			var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
			if instance.mesh == null:
				continue
			var pose: Transform3D = entry["pose"]
			var volume: float = instance.mesh.get_aabb().get_volume() * absf(pose.basis.determinant())
			var volume_slack: float = maxf(volume, largest_volume) * 0.00001
			if volume > largest_volume + volume_slack:
				largest_volume = volume
				largest_parts.clear()
			if absf(volume - largest_volume) <= volume_slack:
				largest_parts.append(instance)
		assert_false(largest_parts.is_empty(), key + " has a largest mesh part")
		for largest_instance: MeshInstance3D in largest_parts:
			for surface: int in largest_instance.mesh.get_surface_count():
				var material: BaseMaterial3D = largest_instance.get_active_material(surface) as BaseMaterial3D
				assert_not_null(material, key + " largest part has a material")
				if material != null:
					assert_lte(material.albedo_color.v, 0.8, key + " body brightness")
		model.free()


func test_a_missing_colour_map_gives_no_material() -> void:
	const NO_MAP: String = "res://models/props_field/Textures/colormap.png"
	assert_false(FileAccess.file_exists(ProjectSettings.globalize_path(NO_MAP)), "this folder has no colour map")
	assert_null(ItemModels._tinted(NO_MAP, []), "no half-painted material from a map that is not there")


func test_hidden_parts_are_not_measured() -> void:
	var root: Node3D = Node3D.new()
	var shown_part: MeshInstance3D = MeshInstance3D.new()
	shown_part.mesh = BoxMesh.new()
	root.add_child(shown_part)
	var hidden_frame: Node3D = Node3D.new()
	hidden_frame.visible = false
	root.add_child(hidden_frame)
	var under_hidden: MeshInstance3D = MeshInstance3D.new()
	under_hidden.mesh = BoxMesh.new()
	hidden_frame.add_child(under_hidden)
	var hidden_part: MeshInstance3D = MeshInstance3D.new()
	hidden_part.mesh = BoxMesh.new()
	hidden_part.visible = false
	root.add_child(hidden_part)
	var parts: Array[Dictionary] = []
	_collect_meshes(root, Transform3D.IDENTITY, parts)
	assert_eq(parts.size(), 1, "a hidden part and one under a hidden frame are left out, as the bake does")
	if parts.size() == 1:
		assert_eq(parts[0]["instance"], shown_part)
	root.free()


## Local transforms work on detached nodes, including nested rotated/scaled parts.
## Only what is drawn: a hidden node hides what is under it, as the bake tool
## (icon_bake._copy_meshes) leaves it out.
func _collect_meshes(node: Node, parent_pose: Transform3D, parts: Array[Dictionary], shown: bool = true) -> void:
	var pose: Transform3D = parent_pose
	if node is Node3D:
		var spatial: Node3D = node as Node3D
		pose = spatial.transform if spatial.top_level else parent_pose * spatial.transform
		shown = shown and spatial.visible
	if node is MeshInstance3D and shown:
		parts.append({"instance": node, "pose": pose})
	for child: Node in node.get_children():
		_collect_meshes(child, pose, parts, shown)


## The bake tool reads a model's vertex colours only when its file defines no
## materials (it is painted that way); a file with materials keeps them as made.
func test_bake_reads_vertex_colours_only_for_files_without_materials() -> void:
	var bake: Script = load("res://tools/icon_bake.gd") as Script
	assert_true(bake.call("_paints_with_vertex_colours", "res://models/props_field/tin_crate.glb"), "no materials, COLOR_0 only")
	assert_true(bake.call("_paints_with_vertex_colours", "res://models/train_interior/bell.glb"))
	assert_false(bake.call("_paints_with_vertex_colours", "res://models/items/kenney_survival/fish.glb"), "its colour map material")
	assert_false(bake.call("_paints_with_vertex_colours", "res://models/weapons/axe.glb"), "a textured model")
	assert_false(bake.call("_paints_with_vertex_colours", "res://models/no_such_model.glb"))
	assert_false(bake.call("_paints_with_vertex_colours", "res://tools/item_models.gd"), "not a glTF file")
