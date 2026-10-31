extends "res://addons/gut/test.gd"

const RoomDecor = preload("res://game/world/room_decor.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const PropModels = preload("res://game/world/prop_models.gd")
const PropKinds = preload("res://game/world/prop_kinds.gd")
const PropFit = preload("res://game/world/prop_fit.gd")
const ObjectRules = preload("res://game/sim/object_rules.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const MapView = preload("res://game/world/map_view.gd")
const Measure = preload("res://tools/room_decor_measure.gd")

var maps: Array = []


func before_all() -> void:
	for id: String in ["houses_01", "houses_04"]:
		var data := Measure.prepare(id)
		RoomDecor.dress(data)
		maps.append(data)


func test_seven_house_maps_restore_room_kind_medians() -> void:
	# 합격 잣대는 일곱 장 방을 합친 종류 수 가운데값(참고 사본 표): 침실 1·거실 2·부엌 0.
	var rooms: Array = []
	for data: Dictionary in maps:
		rooms.append_array(Measure.census(data))
	for id: String in ["houses_02", "houses_03", "houses_05", "houses_06", "houses_07"]:
		var data := Measure.prepare(id)
		RoomDecor.dress(data)
		rooms.append_array(Measure.census(data))
	var summary := Measure.summarize(rooms)
	for cls: String in {"bed": 1.0, "living": 2.0, "kitchen": 0.0}:
		assert_gt(int(summary[cls]["rooms"]), 0, cls)
		assert_eq(float(summary[cls]["median"]), float({"bed": 1.0, "living": 2.0, "kitchen": 0.0}[cls]), cls)


func test_every_top_has_a_room_host_a_free_surface_and_a_missing_wall_kind() -> void:
	var checked := 0
	var total := 0
	for data: Dictionary in maps:
		for prop: Dictionary in data["props"]:
			total += int(prop.get("mount", "") == "top")
		for lv: int in data["levels"]:
			var g: FieldGrid = data["levels"][lv]
			var rooms := RoomFurnish._rooms(data, lv, g)
			var in_room := RoomFurnish._props_by_room(g, rooms["of"], data["props"], lv)
			for ri in range(rooms["rooms"].size()):
				var cls := String(data["density_classes"].get("%d:%d" % [lv, ri], ""))
				var room: Dictionary = rooms["rooms"][ri]
				var seed_value: int = ("%s|%d|%d|%d|decor" % [data["place_id"], room["building"], lv, ri]).hash() & 0x7fffffff
				var tops: Array = []
				var walls: Dictionary = {}
				var idxs: Array = in_room.get(ri, [])
				for i: int in idxs:
					var p: Dictionary = data["props"][i]
					if p.get("mount", "") == "top":
						tops.append(p)
					elif p.get("mount", "") == "wall":
						walls[p["kind"]] = true
				var missing := 0
				if RoomDecor.TOP_PLAN.has(cls):
					for kind: String in RoomDecor.PLAN[cls]:
						if kind == "potted_plant":
							continue
						var roll := int(rand_from_seed(hash([seed_value, RoomDecor.PURPOSE[kind]]))[0])
						missing += int(float(roll % 1000) / 1000.0 < float(RoomDecor.PLAN[cls][kind][0]) and not walls.has(kind))
				assert_lte(tops.size(), missing, "%s %d:%d 보충 수" % [data["place_id"], lv, ri])
				var kinds: Dictionary = {}
				var spots: Dictionary = {}
				for p: Dictionary in tops:
					checked += 1
					assert_false(kinds.has(p["kind"]), "한 방 같은 탁상 종류 하나")
					kinds[p["kind"]] = true
					assert_has(RoomDecor._top_order(cls, seed_value), p["kind"])
					var host: Dictionary = {}
					for i: int in idxs:
						var f: Dictionary = data["props"][i]
						if not f.get("decor", false) and int(f.get("level", 0)) == lv \
								and f.get("kind", "") == p["on"] and RoomFurnish._rect(f.get("rect")) == p["host_rect"]:
							host = f
							break
					assert_false(host.is_empty(), "같은 방·층의 장식 아닌 받침")
					if host.is_empty():
						continue
					assert_has(RoomDecor.top_hosts(cls, p["kind"]), host["kind"])
					var r: Rect2i = RoomFurnish._rect(host["rect"])
					assert_eq(p["rect"], Rect2i(r.position, Vector2i.ONE))
					assert_true(r.encloses(p["rect"]))
					assert_eq(RoomFurnish._at(g, rooms["of"], p["rect"].position), ri)
					assert_eq(int(p["level"]), lv)
					assert_eq(int(p["facing"]), int(host.get("facing", 0)))
					var slot := "%s:%s:%d" % [p["on"], r, p["spot"]]
					assert_false(spots.has(slot), "받침 윗면 칸 하나에 하나")
					spots[slot] = true
					_check_surface(p, host, g)
	assert_gt(checked, 0, "탁상 줄을 실제로 검사한다")
	assert_eq(checked, total, "방에 속하지 못한 탁상도 없어야 한다")


func _check_surface(p: Dictionary, host: Dictionary, g: FieldGrid) -> void:
	var host_path := RoomDecor.drawn_model(host["kind"])
	var path := RoomDecor.drawn_model(p["kind"])
	assert_ne(host_path, "")
	assert_ne(path, "")
	if host_path.is_empty() or path.is_empty():
		return
	var tops := PropModels.tops(host_path)
	var spot := int(p["spot"])
	assert_between(spot, 0, tops.size() - 1)
	if spot < 0 or spot >= tops.size():
		return
	var surface: Rect2 = tops[spot]["rect"]
	var at: Vector2 = p["at"]
	assert_eq(at, surface.get_center())
	assert_true(surface.has_point(at))
	var box: AABB = PropModels.batch_meshes(path)[0].get_aabb()
	var half := Vector2(box.size.x, box.size.z) * 0.5
	assert_between(at.x, surface.position.x + half.x, surface.end.x - half.x)
	assert_between(at.y, surface.position.y + half.y, surface.end.y - half.y)
	assert_almost_eq(box.position.y, 0.0, 0.0001, "탁상 모형의 바닥 원점")
	var host_box: AABB = PropModels.batch_meshes(host_path)[0].get_aabb()
	var r: Rect2i = p["host_rect"]
	var fit := PropFit.fit(host_box.position, host_box.end, r, int(host.get("facing", 0)), g)
	var basis := Basis.from_scale(fit["scale"]) * Basis(Vector3.UP, -float(fit["facing"]) * PI * 0.5)
	var center := Vector3(r.position.x + r.size.x * 0.5, int(p["level"]) * MapView.LEVEL_H, r.position.y + r.size.y * 0.5)
	var host_xf := Transform3D(basis, center)
	var top_xf := MapView.top_mount_transform(host_xf, float(tops[spot]["y"]), at)
	assert_almost_eq(top_xf.origin.y, center.y + float(tops[spot]["y"]), 0.0001)
	for x in [box.position.x, box.end.x]:
		for z in [box.position.z, box.end.z]:
			var local: Vector3 = host_xf.affine_inverse() * (top_xf * Vector3(x, 0.0, z))
			assert_between(local.x, surface.position.x - 0.0001, surface.end.x + 0.0001)
			assert_between(local.z, surface.position.y - 0.0001, surface.end.y + 0.0001)


func test_hosts_cannot_be_broken_or_pushed_and_top_kinds_are_separate() -> void:
	assert_eq(RoomDecor.TOP_KINDS, PropModels.TABLETOP_KINDS)
	assert_eq(RoomDecor.TOP_KINDS.size(), 9)
	for cls: String in RoomDecor.TOP_PLAN:
		for kind: String in RoomDecor.TOP_HOSTS[cls]:
			assert_false(RoomDecor.KINDS.has(kind))
			assert_false(RoomDecor.PLAN[cls].has(kind))
			assert_true(RoomDecor.NAMES.has(kind))
			for host: String in RoomDecor.top_hosts(cls, kind):
				assert_false(ObjectRules.WOOD_KINDS.has(host), host)
				assert_false(ObjectRules.PUSH_KINDS.has(host), host)
				assert_false(["blanket_chest", "radio_set", "cupboard", "bookcase"].has(host), host)


func test_budget_counts_missing_kinds_and_ignores_partial_copies_plants_and_baths() -> void:
	for cls: String in ["bed", "living", "kitchen", "bath"]:
		for seed_value in range(120):
			var rolled: Array = []
			for kind: String in RoomDecor.PLAN[cls]:
				var roll := int(rand_from_seed(hash([seed_value, RoomDecor.PURPOSE[kind]]))[0])
				if kind != "potted_plant" and float(roll % 1000) / 1000.0 < float(RoomDecor.PLAN[cls][kind][0]):
					rolled.append({"kind": kind, "mount": "wall"})
			var expected := 0 if cls == "bath" else rolled.size()
			assert_eq(RoomDecor._top_budget(cls, seed_value, []), expected)
			assert_eq(RoomDecor._top_budget(cls, seed_value, rolled), 0, "하나씩만 걸려도 보충 없음")
			assert_eq(RoomDecor._top_budget(cls, seed_value, rolled + rolled), 0, "두 개씩 걸려도 보충 없음")
			assert_eq(RoomDecor._top_budget(cls, seed_value, [{"kind": "potted_plant", "mount": "floor"}]), expected)
			if not rolled.is_empty() and cls != "bath":
				assert_eq(RoomDecor._top_budget(cls, seed_value, rolled.slice(1)), 1, "0개인 종류만 한 차례")
	assert_eq(RoomDecor._top_budget("office", 7, []), 0)


func test_top_order_uses_independent_rolls_and_one_kettle() -> void:
	var starts: Dictionary = {}
	var kettles: Dictionary = {}
	for seed_value in range(120):
		for cls: String in RoomDecor.TOP_PLAN:
			var order := RoomDecor._top_order(cls, seed_value)
			assert_eq(order, RoomDecor._top_order(cls, seed_value))
			assert_eq(order.size(), RoomDecor.TOP_PLAN[cls].size())
			starts["%s:%s" % [cls, order[0]]] = true
			var unique: Dictionary = {}
			for kind: String in order:
				unique[kind] = true
			assert_eq(unique.size(), order.size())
			if cls == "kitchen":
				assert_ne(order.has("kettle"), order.has("kettle_enamel"))
				kettles["kettle" if order.has("kettle") else "kettle_enamel"] = true
	# 침실 3 + 거실 4 + 부엌 5(주전자 자리는 두 주전자 중 하나라 첫 자리가 둘로 갈린다).
	assert_eq(starts.size(), 12, "모든 시작 자리가 나온다")
	assert_eq(kettles.size(), 2)
	assert_eq(RoomDecor._top_order("bath", 7).size(), 0)
	for purpose: int in RoomDecor.PURPOSE.values():
		assert_ne(purpose, RoomDecor.TOP_PURPOSE)
		assert_ne(purpose, RoomDecor.KETTLE_PURPOSE)
	assert_ne(RoomDecor.TOP_PURPOSE, RoomDecor.KETTLE_PURPOSE)


func _choice(order: int, preference: int, slot: String) -> Dictionary:
	return {"order": order, "choice": preference, "slot": slot}


func test_matching_maximizes_count_before_kind_order_and_host_preference() -> void:
	var a := _choice(0, 0, "shared")
	var b := _choice(0, 1, "other")
	var c := _choice(1, 0, "shared")
	var picked := RoomDecor._match_tops([[a, b], [c]], 2)
	assert_eq(picked, [b, c], "먼저 좋은 받침을 쓰면 한 개를 잃는 경우")
	assert_eq(RoomDecor._match_tops([[a, b], [c]], 1), [a], "같은 수면 앞 종류·선호 받침")
	assert_eq(RoomDecor._match_tops([[], [c]], 1), [c], "받침 없는 종류는 차례를 쓰지 않는다")
	var later := _choice(2, 0, "other")
	assert_eq(RoomDecor._match_tops([[a, b], [c], [later]], 2), [b, c], "종류 차례가 받침 선호보다 먼저")
	assert_eq(RoomDecor._match_tops([[a], [_choice(1, 0, "shared")]], 2), [a], "윗면 칸 중복 없음")
	assert_eq(RoomDecor._match_tops([[a], [c]], 0), [])


func test_footprint_fits_the_center_without_scaling_the_top() -> void:
	var surface := Rect2(-0.3, -0.2, 0.6, 0.4)
	var small := AABB(Vector3(-0.1, 0.0, -0.08), Vector3(0.2, 0.2, 0.16))
	assert_true(RoomDecor._top_fits(small, surface))
	assert_true(RoomDecor._top_fits(small, surface, Vector2(0.65, 0.7)))
	assert_false(RoomDecor._top_fits(AABB(Vector3(-0.31, 0, -0.1), Vector3(0.62, 0.2, 0.2)), surface))
	assert_false(RoomDecor._top_fits(AABB(Vector3(0.2, 0, -0.1), Vector3(0.2, 0.2, 0.2)), surface), "원점이 치우친 모형")
	assert_false(RoomDecor._top_fits(small, surface, Vector2(0.3, 1.0)), "줄어든 받침에서도 실제 크기")


func test_transform_keeps_floor_height_rotation_and_unit_basis_on_every_facing() -> void:
	var surface := Rect2(-0.35, -0.15, 0.8, 0.5)
	var at := surface.get_center()
	for lv: int in [-1, 0, 1]:
		for facing in range(4):
			var turn := Basis(Vector3.UP, -float(facing) * PI * 0.5)
			var basis := Basis.from_scale(Vector3(0.65, 1.0, 0.8)) * turn
			var host := Transform3D(basis, Vector3(4.5, lv * MapView.LEVEL_H, 6.0))
			var xf := MapView.top_mount_transform(host, 0.84, at)
			assert_almost_eq(xf.origin.y, host.origin.y + 0.84, 0.0001)
			assert_almost_eq(xf.basis.x.length(), 1.0, 0.0001)
			assert_almost_eq(xf.basis.y.length(), 1.0, 0.0001)
			assert_almost_eq(xf.basis.z.length(), 1.0, 0.0001)
			assert_lt((xf.basis.x - turn.x).length(), 0.0001)
			assert_lt((xf.basis.z - turn.z).length(), 0.0001)
			var local: Vector3 = host.affine_inverse() * xf.origin
			assert_almost_eq(local.y, 0.84, 0.0001)
			assert_true(surface.has_point(Vector2(local.x, local.z)))
			assert_lt((xf.origin - host * Vector3(at.x, 0.84, at.y)).length(), 0.0001)


func test_unusable_first_model_uses_the_drawn_fallback_without_a_top() -> void:
	# 첫 후보의 메시만 없는 경우를 만들고 원래 캐시는 단언 전에 돌려놓는다.
	var primary := PropKinds.candidates("cold_stove")[0]
	var had_cache := PropModels._batches.has(primary)
	var original: Variant = PropModels._batches.get(primary)
	PropModels._batches[primary] = {}
	var selected := RoomDecor.drawn_model("cold_stove")
	var props := [{"kind": "cold_stove", "rect": Rect2i(2, 2, 1, 1), "level": 0}]
	var rows := RoomDecor._tabletops(props, [0], 0, "kitchen", 7, "부엌", 1)
	if had_cache:
		PropModels._batches[primary] = original
	else:
		PropModels._batches.erase(primary)
	assert_eq(selected, String(PropKinds.MODELS["cold_stove"]))
	assert_eq(PropModels.tops(selected), [])
	assert_eq(rows, [], "그려진 대체 모형에 윗면이 없으면 탁상 없음")


func test_actual_model_selection_missing_hosts_and_disabled_models() -> void:
	for kind: String in ["cold_stove", "dresser", "counter", "kettle", "missing_tabletop_fixture"]:
		var expected := ""
		for path in PropKinds.candidates(kind):
			if PropModels.enabled() and ResourceLoader.exists(path) and not PropModels.batch_meshes(path).is_empty():
				expected = path
				break
		assert_eq(RoomDecor.drawn_model(kind), expected)
	assert_eq(RoomDecor._tabletops([], [], 0, "bed", 7, "방", 2), [])
	var hosts := [{"kind": "radio_set", "rect": Rect2i(2, 2, 1, 1), "level": 0}]
	assert_eq(RoomDecor._tabletops(hosts, [0], 0, "living", 7, "방", 2), [])
	hosts[0]["kind"] = "nightstand"
	assert_eq(RoomDecor._tabletops(hosts, [0], 1, "bed", 7, "방", 2), [], "다른 층")
	hosts[0]["decor"] = true
	assert_eq(RoomDecor._tabletops(hosts, [0], 0, "bed", 7, "방", 2), [], "장식은 받침 아님")
	hosts[0]["decor"] = false
	var had_setting := ProjectSettings.has_setting(PropModels.MODE_SETTING)
	var setting: Variant = ProjectSettings.get_setting(PropModels.MODE_SETTING, true)
	ProjectSettings.set_setting(PropModels.MODE_SETTING, false)
	var path := RoomDecor.drawn_model("nightstand")
	var rows := RoomDecor._tabletops(hosts, [0], 0, "bed", 7, "방", 2)
	ProjectSettings.set_setting(PropModels.MODE_SETTING, setting if had_setting else null)
	assert_eq(path, "")
	assert_eq(rows, [])


func test_stove_uses_the_highest_fitting_surface_first() -> void:
	var props := [{"kind": "cold_stove", "rect": Rect2i(2, 2, 1, 1), "level": 0}]
	for seed_value in range(24):
		var rows := RoomDecor._tabletops(props, [0], 0, "kitchen", seed_value, "부엌", 1)
		assert_eq(rows.size(), 1)
		if rows.is_empty():
			continue
		var row: Dictionary = rows[0]
		assert_has(["kettle", "kettle_enamel"], row["kind"])
		var path := RoomDecor.drawn_model(row["kind"])
		var box: AABB = PropModels.batch_meshes(path)[0].get_aabb()
		var tops := PropModels.tops(RoomDecor.drawn_model("cold_stove"))
		for spot in range(tops.size()):
			if RoomDecor._top_fits(box, tops[spot]["rect"]):
				assert_gte(float(tops[int(row["spot"])]["y"]), float(tops[spot]["y"]))


func test_renderer_defers_tops_uses_the_fitted_host_and_counts_skips() -> void:
	var view = autofree(MapView.new())
	var g := FieldGrid.new(10, 10)
	view.grid = g
	view.levels = {1: g}
	var r := Rect2i(2, 2, 1, 2)
	var host := {"kind": "dresser", "rect": r, "level": 1, "facing": 0}
	var path := RoomDecor.drawn_model("dresser")
	assert_ne(path, "")
	if path.is_empty():
		return
	var surface: Dictionary = PropModels.tops(path)[0]
	var top := {"kind": "alarm_clock", "rect": Rect2i(r.position, Vector2i.ONE), "solid": "none",
		"mount": "top", "on": "dresser", "host_rect": r, "spot": 0, "at": surface["rect"].get_center(),
		"facing": 3, "level": 1, "decor": true}
	var rows: Array = [top, host]
	var no_surface := {"kind": "wall_picture", "rect": Rect2i(5, 2, 1, 1), "level": 1}
	var decor_host := {"kind": "dresser", "rect": Rect2i(6, 4, 2, 1), "level": 1, "decor": true}
	rows.append_array([no_surface, decor_host])
	for change: Dictionary in [
		{"host_rect": Rect2i(8, 8, 1, 1)},
		{"on": "wall_picture", "host_rect": no_surface["rect"]},
		{"kind": "missing_tabletop_fixture"}, {"spot": 99}, {"level": 2},
		{"host_rect": decor_host["rect"]},
	]:
		var bad := top.duplicate(true)
		bad.merge(change, true)
		rows.append(bad)
	view.data = {"props": rows}
	await view._build_props()
	assert_eq(view.prop_fit_counts["top_skipped"], 6)
	assert_eq(view.prop_fit_counts["turned"], 1, "받침은 실제로 돌아간다")
	var top_path := RoomDecor.drawn_model("alarm_clock")
	assert_true(view.prop_batches.has(top_path))
	if not view.prop_batches.has(top_path):
		return
	var items: Array = view.prop_batches[top_path]["items"]
	assert_eq(items.size(), 1)
	var host_xf: Transform3D = view.prop_batches[path]["items"][0]["xf"]
	var xf: Transform3D = items[0]["xf"]
	var expected := MapView.top_mount_transform(host_xf, float(surface["y"]), top["at"])
	assert_true(xf.is_equal_approx(expected), "줄 facing 대신 실제 받침의 최종 변환")
	assert_almost_eq(xf.basis.x.length(), 1.0, 0.0001)
	# 2칸 받침의 둘째 칸만 본 적 있어도 탁상이 보이게, 보이기·기억 칸은 받침 전체다.
	assert_eq(items[0]["rect"], r, "탁상 보이기 칸 = 받침 칸")
	assert_eq(view._prop_shade(top_path, items[0]), {}, "들뜬 탁상의 땅 그늘 없음")
