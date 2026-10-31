extends "res://addons/gut/test.gd"
## Home rows share the existing one-mesh dress path. Run by the calling session;
## the bounded placement worker must not launch Godot/GUT in its worktree.

const Catalog = preload("res://game/train/train_catalog.gd")
const Interior = preload("res://game/train/train_interior.gd")
const Life = preload("res://game/train/train_life.gd")
const TrainLight = preload("res://game/train/train_light.gd")
const CARS: Dictionary = {
	"tail1": "coach", "tail2": "coach", "tail3": "coach", "medtech": "medical",
	"guard": "guard", "front": "front", "captain": "captain", "dining": "dining",
}
const SMALL: Array[String] = ["tiny_cup", "tiny_bowl", "tiny_plate", "tiny_bottle", "tiny_can", "tiny_jar",
	"tiny_teapot", "tiny_tray", "thread_spool", "tiny_brush", "tiny_clock", "tiny_book"]
const EPS: float = 0.00001
var _saved_catalog: Dictionary


class StoveHost extends Node3D:
	var models: Array[String] = []

	func _build_stove(_car: Dictionary, _at: Vector3, model: String = "") -> void:
		models.append(model)


func before_each() -> void:
	_saved_catalog = Catalog.data().duplicate(true)


func after_each() -> void:
	Catalog._data = _saved_catalog


func _room(car_id: String, stage: int, calls: Array) -> Interior:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var room := Interior.new()
	room.build(parent, {"id": car_id, "interior": CARS[car_id]},
		func(at: Vector3, model: String) -> void: calls.append({"at": at, "model": model}), stage)
	return room


func _resolved(car_id: String, stage: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: Dictionary in Catalog.data()["layouts"][CARS[car_id]]["props"]:
		if source.has("cars") and not (source["cars"] as Array).has(car_id):
			continue
		var home: Array = source.get("home", [0, 3])
		if stage < int(home[0]) or stage > int(home[1]):
			continue
		var row: Dictionary = source.duplicate(true)
		var models: Dictionary = source.get("home_model", {})
		row["model"] = String(models.get(str(stage), source["model"]))
		result.append(row)
	return result


func test_home_range_filters_ordinary_dress_and_stove_before_build() -> void:
	var common: Dictionary = {"model": "tiny_cup", "at": [2.0, 0.5, -1.0],
		"size": [0.07, 0.09, 0.07], "yaw": 0, "material": "wood", "home": [1, 2]}
	var ordinary: Dictionary = common.duplicate(true)
	ordinary["id"] = "ranged_prop"
	var dressed: Dictionary = common.duplicate(true)
	dressed["id"] = "ranged_dress"
	dressed["dress"] = true
	var stove: Dictionary = common.duplicate(true)
	stove.merge({"id": "ranged_stove", "model": "stove", "system": "stove",
		"home_model": {"1": "drum_stove", "2": "stove"}}, true)
	Catalog.data()["layouts"]["front"]["props"] = [ordinary, dressed, stove]
	for stage: int in range(4):
		var calls: Array = []
		var room := _room("front", stage, calls)
		var included: bool = stage == 1 or stage == 2
		assert_eq(room.props.has("ranged_prop"), included, "ordinary stage %d" % stage)
		assert_eq(room.dress != null, included, "dress stage %d" % stage)
		assert_eq(calls.size(), 1 if included else 0, "stove stage %d" % stage)
		if included and calls.size() == 1:
			assert_eq(String(calls[0]["model"]), "drum_stove" if stage == 1 else "", "an explicit default model still uses the legacy stove")


func test_bunk_models_change_without_moving_their_reservations() -> void:
	for car_id: String in ["tail1", "medtech"]:
		var ids: Array = ["upper_bunk_a", "upper_bunk_b"] if car_id == "tail1" else ["bed_0", "bed_1", "bed_2", "bed_3", "bed_4", "bed_5"]
		var base: String = "bunk_upper" if car_id == "tail1" else "bunk_lower"
		for stage: int in range(4):
			var calls: Array = []
			var room := _room(car_id, stage, calls)
			var expected: String = "sack_" + base if stage == 0 else ("open_" + base if stage == 3 else base)
			for id: String in ids:
				assert_true(room.props.has(id), id)
				if not room.props.has(id):
					continue
				var node: Node3D = room.props[id]
				assert_true(node.has_meta("model_key"), id + " model metadata")
				if node.has_meta("model_key"):
					assert_eq(String(node.get_meta("model_key")), expected, id + " stage %d" % stage)
				assert_true(node.scene_file_path.ends_with("/" + expected + ".glb"), id + " loads the replacement, not a fallback box")
				var row: Dictionary = room.rows[id]
				assert_almost_eq(node.position.x, float(row["at"][0]), EPS)
				assert_almost_eq(node.position.z, float(row["at"][2]), EPS)
				assert_almost_eq(node.rotation.y, float(row["yaw"]), EPS)
				assert_true(node.has_meta("reserved_size"), id + " reservation")
				if node.has_meta("reserved_size"):
					assert_eq(node.get_meta("reserved_size"), Catalog.vector(row["size"]))


func test_stove_builder_receives_tier_model_or_empty_default() -> void:
	var expected: Array[String] = ["tin_stove", "drum_stove", "", ""]
	for car_id: String in CARS:
		for stage: int in range(4):
			var calls: Array = []
			_room(car_id, stage, calls)
			assert_eq(calls.size(), 1, car_id + " one stove")
			if calls.size() == 1:
				assert_eq(String(calls[0]["model"]), expected[stage], car_id + " stage %d" % stage)


func test_six_layouts_four_stages_merge_all_dress_into_one_surface() -> void:
	for car_id: String in ["tail1", "front", "medtech", "guard", "captain", "dining"]:
		for stage: int in range(4):
			var calls: Array = []
			var room := _room(car_id, stage, calls)
			var count: int = 0
			for child: Node in room.root.get_children():
				if child is MeshInstance3D and child.name == "Dress":
					count += 1
			assert_between(count, 0, 1, car_id + " merged dress stage %d" % stage)
			assert_not_null(room.dress, car_id + " these layouts all contain dress")
			if room.dress != null:
				assert_eq(count, 1)
				assert_eq(room.dress.mesh.get_surface_count(), 1, "one draw surface")
				var expected_tris: int = 0
				for row: Dictionary in _resolved(car_id, stage):
					if bool(row.get("dress", false)):
						var mesh: Mesh = Interior._dress_mesh(String(row["model"]))
						assert_not_null(mesh, String(row["id"]))
						if mesh != null:
							expected_tris += mesh.get_faces().size() / 3
				assert_eq(room.dress.mesh.get_faces().size() / 3, expected_tris, "every filtered/replaced row is merged")


func test_tier_small_items_stand_on_new_shelf_boards_for_every_car() -> void:
	for car_id: String in CARS:
		for stage: int in [2, 3]:
			var rows: Array[Dictionary] = _resolved(car_id, stage)
			var by_id: Dictionary = {}
			for row: Dictionary in rows:
				by_id[String(row["id"])] = row
			var amount: int = 0
			var kinds: Dictionary = {}
			var boxes: Array[AABB] = []
			for row: Dictionary in rows:
				if not SMALL.has(String(row["model"])):
					continue
				amount += 1
				kinds[row["model"]] = true
				assert_true(bool(row.get("dress", false)), String(row["id"]))
				var support: String = String(row.get("on_shelf", ""))
				assert_true(by_id.has(support), car_id + " new shelf is visible")
				if not by_id.has(support):
					continue
				var shelf: Dictionary = by_id[support]
				assert_true(bool(shelf.get("tier_shelf", false)), support)
				var shelf_model: String = String(shelf["model"])
				assert_has(["end_shelf", "top_shelf"], shelf_model)
				var k: float = minf(1.0, float(shelf["size"][1]) / (0.9 if shelf_model == "end_shelf" else 0.24))
				var board: int = int(row.get("shelf_board", -1))
				var levels: Array = [0.025, 0.4625, 0.9] if shelf_model == "end_shelf" else [0.24]
				assert_between(board, 0, levels.size() - 1)
				if board < 0 or board >= levels.size():
					continue
				var top: float = float(shelf["at"][1]) - float(shelf["size"][1]) * 0.5 + levels[board] * k
				var at: Vector3 = Catalog.vector(row["at"])
				var size: Vector3 = Catalog.vector(row["size"])
				assert_almost_eq(at.y - size.y * 0.5, top, EPS, String(row["id"]) + " rests on the board")
				var half_width: float = (0.204 if shelf_model == "end_shelf" else 0.24) * k
				var front: float = ([0.14, 0.075, 0.01][board] if shelf_model == "end_shelf" else 0.14) * k
				var back: float = (-0.105 if shelf_model == "end_shelf" else -0.14) * k
				assert_true(at.x - size.x * 0.5 >= float(shelf["at"][0]) - half_width - EPS)
				assert_true(at.x + size.x * 0.5 <= float(shelf["at"][0]) + half_width + EPS)
				assert_true(at.z - size.z * 0.5 >= float(shelf["at"][2]) + back - EPS)
				assert_true(at.z + size.z * 0.5 <= float(shelf["at"][2]) + front + EPS)
				var box := AABB(at - size * 0.5, size)
				for previous: AABB in boxes:
					assert_false(box.intersects(previous), car_id + " small items do not overlap")
				boxes.append(box)
			assert_eq(amount, 24 if stage == 2 else 60, car_id + " small item count")
			assert_eq(kinds.size(), 12, car_id + " mixes all twelve kinds")


func test_life_clamps_stage_and_keeps_train_light_default() -> void:
	for stage: int in [-9, 0, 1, 2, 3, 99]:
		var host := StoveHost.new()
		add_child_autofree(host)
		var life := Life.new()
		life.setup(host)
		life.add_car({"id": "front", "node": host, "def": {"id": "front", "interior": "front"}, "x0": 0.0, "home_stage": stage})
		var models: Array[String] = ["tin_stove", "drum_stove", "", ""]
		assert_eq(host.models, [models[clampi(stage, 0, 3)]])
	var default_host := StoveHost.new()
	add_child_autofree(default_host)
	var default_life := Life.new()
	default_life.setup(default_host)
	default_life.add_car({"id": "front", "node": default_host, "def": {"id": "front", "interior": "front"}, "x0": 0.0})
	assert_eq(TrainLight.STAGE_DEFAULT, 1)
	assert_eq(default_host.models, ["drum_stove"])


func test_legacy_three_argument_build_and_catalog_stay_usable() -> void:
	var original: Dictionary = Catalog.data().duplicate(true)
	var parent := Node3D.new()
	add_child_autofree(parent)
	var calls: Array = []
	var room := Interior.new()
	room.build(parent, {"id": "front", "interior": "front"}, func(at: Vector3) -> void: calls.append(at))
	assert_eq(calls.size(), 1, "legacy one-argument callback and omitted stage")
	assert_eq(Catalog.data(), original, "stage resolution never mutates cached source rows")
