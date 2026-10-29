extends GutTest
## A lived car is dressed in three layers (대조표 T4: the floor, the wall and the ceiling,
## three of each at least): the layout rows marked with their layer, the new small things
## marked "dress" drawn as one mesh a car (결정 505 잰 값), up close only on the diagonal.
## Each dress row keeps its place: under the 2.2 m cut, on the back wall between the windows,
## off the walking line and clear of where people stand.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const KIT: String = "res://models/train_interior/catalog.json"
const LIVED: Array[String] = ["tail1", "tail2", "tail3", "medtech", "guard", "front", "dining", "workshop", "captain", "engine"]
const LAYERS: Array[String] = ["floor", "wall", "ceiling"]
const CUT: float = 2.2
const BACK: float = -1.30
const WINDOWS: Array[Vector2] = [Vector2(1.2, 2.8), Vector2(5.2, 6.8), Vector2(9.2, 10.8), Vector2(13.2, 14.8)]
const LANE := Vector2(0.25, 0.75)


func _def(id: String) -> Dictionary:
	for c: Dictionary in Rules.load_default()["cars"]:
		if String(c["id"]) == id:
			return c
	return {}


func _rows(id: String) -> Array:
	var out: Array = []
	for row: Dictionary in Catalog.layout(_def(id))["props"]:
		if row.has("cars") and not (row["cars"] as Array).has(id):
			continue
		out.append(row)
	return out


## [x0, x1, y0, y1, z0, z1] of a row's box (the dress rows stand square).
func _box(row: Dictionary) -> Array:
	var at: Array = row["at"]
	var s: Array = row["size"]
	return [float(at[0]) - float(s[0]) * 0.5, float(at[0]) + float(s[0]) * 0.5,
		float(at[1]) - float(s[1]) * 0.5, float(at[1]) + float(s[1]) * 0.5,
		float(at[2]) - float(s[2]) * 0.5, float(at[2]) + float(s[2]) * 0.5]


func test_every_lived_car_has_three_of_each_layer() -> void:
	for id: String in LIVED:
		assert_false(_def(id).is_empty(), id + " is in the train")
		var n: Dictionary = {"floor": 0, "wall": 0, "ceiling": 0}
		for row: Dictionary in _rows(id):
			if row.has("layer") and String(row.get("when", "always")) == "always":
				n[String(row["layer"])] += 1
		for layer: String in LAYERS:
			assert_gte(int(n[layer]), 3, "%s: %s %d" % [id, layer, int(n[layer])])


func test_each_dress_row_keeps_its_place() -> void:
	for id: String in LIVED:
		var layout: Dictionary = Catalog.layout(_def(id))
		var anchors: Array = []
		for spot: Dictionary in layout.get("spots", []):
			for a: Array in spot.get("anchors", []):
				anchors.append(Vector2(float(a[0]), float(a[2])))
		for row: Dictionary in _rows(id):
			if not bool(row.get("dress", false)):
				continue
			var b := _box(row)
			var what: String = "%s %s" % [id, String(row["id"])]
			assert_true(ResourceLoader.exists("res://models/train_interior/%s.glb" % String(row["model"])), what + " has its model")
			assert_true(b[0] >= 0.1 and b[1] <= 15.9 and b[4] >= BACK - 0.001 and b[5] <= 1.3, what + " is inside the car")
			match String(row["layer"]):
				"ceiling":
					assert_gte(b[2], 1.5, what + " hangs over heads")
					assert_lte(b[3], CUT + 0.001, what + " hangs under the diagonal's cut")
				"wall":
					assert_almost_eq(b[4], BACK, 0.001, what + " is on the back wall")
					for w: Vector2 in WINDOWS:
						assert_false(b[0] < w.y and b[1] > w.x and b[3] > 1.3, what + " is not over a window")
				"floor":
					assert_lt(b[2], 0.001, what + " stands on the floor")
					if b[3] - b[2] > 0.03:
						assert_false(b[4] < LANE.y and b[5] > LANE.x, what + " is off the walking line")
						for p: Vector2 in anchors:
							var dx: float = maxf(maxf(b[0] - p.x, 0.0), p.x - b[1])
							var dz: float = maxf(maxf(b[4] - p.y, 0.0), p.y - b[5])
							assert_gte(Vector2(dx, dz).length(), 0.45, what + " is clear of where people stand")
				_:
					fail_test(what + ": no such layer")


func _scene(extra: Dictionary = {}) -> Scene:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1688, 780)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	var s: Scene = Scene.new()
	s.rules = Rules.load_default()
	var o: Dictionary = {"seed": 7, "panel": false, "baked_people": false}
	o.merge(extra, true)
	s.opts = o
	viewport.add_child(s)
	return s


func test_the_dress_is_one_mesh_a_car_seen_up_close() -> void:
	var kit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KIT))
	var s: Scene = _scene({"view_mode": "diag"})
	for id: String in ["guard", "tail2", "dining"]:
		var room = s.life.rooms[id]
		var dress: MeshInstance3D = room.dress
		assert_not_null(dress, id + " has its dress")
		if dress == null:
			continue
		var tris := 0
		var rows := 0
		for row: Dictionary in _rows(id):
			if bool(row.get("dress", false)):
				tris += int(kit["assets"][String(row["model"])]["lod0_tris"])
				rows += 1
				assert_null(room.root.get_node_or_null(String(row["id"])), id + ": no node of its own for " + String(row["id"]))
		assert_gt(rows, 0)
		var index: PackedInt32Array = dress.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		assert_eq(dress.mesh.get_surface_count(), 1, id + ": one surface, one draw")
		assert_eq(int(index.size() / 3.0), tris, id + ": every dress model in it")
		assert_eq(dress.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var guard: MeshInstance3D = s.life.rooms["guard"].dress
	s.focus_car("guard", false)
	assert_false(guard.visible, "the wide diagonal leaves the small things out")
	s.focus_car("guard", true)
	assert_true(guard.visible, "up close they show")
	s.set_view_mode("section")
	s.toggle_zoom()
	assert_true(guard.visible, "the side view shows them at either zoom")
