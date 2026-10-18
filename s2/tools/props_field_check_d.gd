extends SceneTree
## D 60종의 실제 가져온 PackedScene·배치 메시·경계·색·삼각형 검사.

const PropModels = preload("res://game/world/prop_models.gd")
const DIR := "res://models/props_field/"
const EXPECTED := [
	"rubble_pile", "service_counter", "skidder", "support_frame", "bark_heap",
	"cleaning_table", "debarker", "drying_rack", "fish_hoist", "fishing_platform",
	"flat_trailer", "fuel_drum_group", "log_carriage", "log_cart", "log_conveyor",
	"oil_drum", "ore_cart_tipped", "ore_truck", "pickup_truck", "planer",
	"rubbish_pile", "sawdust_bin", "sawdust_pile", "sawhorse", "sleeper_pile",
	"weigh_scale", "arcade_column", "farm_cart", "fish_truck", "garden_rack",
	"grave_plot", "ice_saw_frame", "ladder_rack", "repair_lumber", "signal_post",
	"tender_wagon", "anvil_block", "box_wagon", "city_bus", "cooking_pot",
	"dough_table", "grave_slab", "parish_chest", "reed_bundle", "altar_table",
	"bell_frame", "bell_rope", "cloister_post", "fallen_signal", "high_rack",
	"meeting_table", "old_coach", "plow_blade", "pulpit", "snowplow_truck",
	"wire_coil", "blanket_screen", "boulder", "butcher_block", "courtyard_planter",
]


func _initialize() -> void:
	call_deferred("_run")


func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _mesh_count(child)
	return count


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "catalog_d.json"))
	if not parsed is Dictionary or not parsed.get("assets") is Dictionary:
		printerr("PROPS_FIELD_D FAIL catalog_unreadable")
		quit(1)
		return
	var assets: Dictionary = parsed["assets"]
	var listed: Array = assets.keys()
	var expected: Array = EXPECTED.duplicate()
	listed.sort()
	expected.sort()
	if listed != expected or not parsed.get("failures", ["missing"]).is_empty():
		printerr("PROPS_FIELD_D FAIL catalog_set_or_generation_failures")
		quit(1)
		return
	var passed := 0
	var total_triangles := 0
	for id: String in EXPECTED:
		var row: Dictionary = assets[id]
		var path := DIR + id + ".glb"
		var problems: Array[String] = []
		if not FileAccess.file_exists(path + ".import"):
			problems.append("missing_import")
		if FileAccess.get_sha256(path) != row.get("sha256", ""):
			problems.append("sha256")
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			printerr("FAIL %s PackedScene" % id)
			continue
		var instance: Node = scene.instantiate()
		if _mesh_count(instance) != 1:
			problems.append("mesh_count")
		instance.free()
		var batches: Dictionary = PropModels.batch_meshes(path)
		if not batches.has(0) or batches.is_empty():
			printerr("FAIL %s empty_batch" % id)
			continue
		var mesh: Mesh = batches[0]
		var triangles := 0
		if mesh.get_surface_count() != 1:
			problems.append("surface_count")
		for surface: int in range(mesh.get_surface_count()):
			if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				problems.append("primitive_type")
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var element_count: int = indices.size() if not indices.is_empty() else vertices.size()
			triangles += int(element_count / 3)
			if element_count % 3 != 0 or colors.size() != vertices.size():
				problems.append("triangles_or_vertex_colors")
		if triangles <= 0 or triangles > 600 or triangles != int(row.get("lod0_tris", -1)):
			problems.append("triangle_budget_or_catalog")
		var bounds: AABB = mesh.get_aabb()
		var fp: Array = row["footprint_m"]
		var x_limit := float(fp[0]) * 0.5 * 1.05
		var z_limit := float(fp[1]) * 0.5 * 1.05
		if bounds.position.x < -x_limit or bounds.end.x > x_limit or bounds.position.z < -z_limit or bounds.end.z > z_limit:
			problems.append("footprint")
		if absf(bounds.position.y) > 0.001 or absf(bounds.size.y - float(row["height_m"])) > 0.005:
			problems.append("floor_or_height")
		if absf(bounds.get_center().x) > 0.001 or absf(bounds.get_center().z) > 0.001:
			problems.append("center_origin")
		if problems.is_empty():
			passed += 1
			total_triangles += triangles
			print("PASS %s PackedScene=ok batch=ok surfaces=1 colors=ok aabb=ok floor=ok tris=%d size=(%.3f,%.3f,%.3f)" % [id, triangles, bounds.size.x, bounds.size.y, bounds.size.z])
		else:
			printerr("FAIL %s %s" % [id, ",".join(problems)])
	print("PROPS_FIELD_D %s passed=%d expected=60 unique_triangles=%d" % ["PASS" if passed == 60 else "FAIL", passed, total_triangles])
	quit(0 if passed == 60 else 1)
