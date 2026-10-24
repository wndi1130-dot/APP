extends SceneTree
## C 전용 실제 가져오기 검사. 다른 몫의 파일 집합은 검사하지 않는다.
const PropModels = preload("res://game/world/prop_models.gd")
const EXPECTED := [
	"circular_saw_bench",
	"fish_drying_frame",
	"sled_load",
	"track_switch",
	"cask_stack",
	"generator",
	"relief_crate",
	"slag_heap",
	"checkout",
	"community_banner",
	"conveyor",
	"ice_block_stack",
	"mail_sorting_rack",
	"plank_bridge",
	"rail_pile",
	"stump_cluster",
	"wrecked_car_cluster",
	"band_saw",
	"box_truck",
	"drain_ditch",
	"flour_sack_pile",
	"lumber_rack",
	"market_stall",
	"nave_pillar",
	"post_box_row",
	"printing_press",
	"water_barrel",
	"weigh_platform",
	"boat_on_blocks",
	"forklift",
	"jib_crane",
	"log_truck",
	"ore_cart",
	"pit_props",
	"coal_sorter",
	"farm_tractor",
	"generator_unit",
	"hopper",
	"mine_portal",
	"rail_stack"
]
const CATALOG := "res://models/props_field/catalog_c.json"
var failures: int = 0

func fail(message: String) -> void:
	failures += 1
	print("FAIL " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not FileAccess.file_exists(CATALOG):
		fail("catalog missing")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not parsed is Dictionary or not parsed.get("assets") is Dictionary:
		fail("catalog invalid")
		quit(1)
		return
	var assets: Dictionary = parsed["assets"]
	var listed: Array = assets.keys()
	listed.sort()
	var expected: Array = EXPECTED.duplicate()
	expected.sort()
	if listed != expected:
		fail("catalog set mismatch")
	var checked: int = 0
	var total_triangles: int = 0
	for kind: String in EXPECTED:
		if not assets.has(kind):
			fail(kind + " missing entry")
			continue
		var before: int = failures
		var asset: Dictionary = assets[kind]
		var path: String = "res://models/props_field/%s.glb" % kind
		if not FileAccess.file_exists(path) or not FileAccess.file_exists(path + ".import"):
			fail(kind + " glb/import missing")
			continue
		if FileAccess.get_sha256(path) != asset["sha256"]:
			fail(kind + " hash mismatch")
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() != int(asset["bytes"]):
			fail(kind + " byte count mismatch")
		var scene: Resource = load(path)
		if not scene is PackedScene:
			fail(kind + " not PackedScene")
			continue
		var instance: Node = scene.instantiate()
		instance.free()
		var batches: Dictionary = PropModels.batch_meshes(path)
		if batches.is_empty() or not batches.has(0):
			fail(kind + " batch empty")
			continue
		var mesh: Mesh = batches[0]
		if mesh.get_surface_count() != 1:
			fail(kind + " surface count")
		var triangles: int = 0
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			var count: int = indices.size() if indices != null and indices.size() > 0 else vertices.size()
			if count % 3 != 0:
				fail(kind + " non-triangle indices")
			triangles += count / 3
			var colors: Variant = arrays[Mesh.ARRAY_COLOR]
			if colors == null or colors.size() != vertices.size():
				fail(kind + " vertex colours missing")
		if triangles < 1 or triangles > 600 or triangles != int(asset["lod0_tris"]):
			fail(kind + " triangle count %d" % triangles)
		var bounds: AABB = mesh.get_aabb()
		var wh: Array = asset["footprint_m"]
		var limit_x: float = float(wh[0]) * 0.5 * 1.05
		var limit_z: float = float(wh[1]) * 0.5 * 1.05
		if bounds.position.x < -limit_x or bounds.end.x > limit_x or bounds.position.z < -limit_z or bounds.end.z > limit_z:
			fail(kind + " footprint AABB")
		if absf(bounds.position.y) > 0.005 or absf(bounds.size.y - float(asset["height_m"])) > 0.01:
			fail(kind + " floor/height")
		if absf(bounds.get_center().x) > 0.005 or absf(bounds.get_center().z) > 0.005:
			fail(kind + " origin not centred")
		if failures == before:
			checked += 1
			total_triangles += triangles
			print("PASS %s PackedScene batch=1 surface=1 Col tris=%d footprint=%sx%s height=%.2f" % [kind, triangles, wh[0], wh[1], bounds.size.y])
	print("C_CHECK %s checked=%d/40 failures=%d unique_triangles=%d" % ["PASS" if failures == 0 and checked == 40 else "FAIL", checked, failures, total_triangles])
	quit(0 if failures == 0 and checked == 40 else 1)

