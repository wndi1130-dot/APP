extends "res://addons/gut/test.gd"

const RegionLooks = preload("res://game/world/region_looks.gd")
const BuildingUses = preload("res://game/world/building_uses.gd")
const MapRing = preload("res://game/world/map_ring.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const Carry = preload("res://game/sim/carry.gd")
const Weapons = preload("res://game/sim/weapons.gd")
const USES: Array[String] = ["home", "shop", "store", "barn", "works", "depot", "office", "hall",
	"clinic", "church", "station", "lodge", "sawmill", "headframe", "shelter", "shed"]
const REGIONS: Array[String] = ["town", "rail_works", "mountain_works", "high_mountain", "waterside", "bare_line"]
## 기존 꾸러미의 갈래는 field_game.gd의 STOCK_OF와 같다. 낱개는 FieldItems가 읽는다.
const LEGACY_STOCK: Dictionary = {"food_pack": "food", "med_box": "medicine", "luxury_pack": "luxury",
	"symbol_bell": "symbol", "info_telegraph": "info", "info_timetable": "info", "medkit": "medicine",
	"document": "info", "plank": "wood", "bottle_spirit": "luxury", "cloth": "cloth",
	"wood": "wood", "scrap": "scrap"}
static var _built: Dictionary = {}


func after_all() -> void:
	_built.clear()


func test_fourteen_keys_and_shared_values() -> void:
	assert_eq(RegionLooks.LOOKS.size(), 14)
	for number: int in range(1, 13):
		assert_true(RegionLooks.LOOKS.has("K%d" % number))
	assert_true(RegionLooks.LOOKS.has("mountain_works"))
	assert_true(RegionLooks.LOOKS.has("high_mountain"))
	assert_eq(RegionLooks.LOOKS["K2"], RegionLooks.LOOKS["K1"])
	assert_eq(RegionLooks.LOOKS["K5"], RegionLooks.LOOKS["K4"])
	assert_eq(RegionLooks.LOOKS["high_mountain"], RegionLooks.LOOKS["mountain_works"])


func test_of_validates_band_before_region_and_copies_nested_values() -> void:
	for pair: Array in [["", "houses"], ["K99", "houses"], ["", "lodge"], ["K4", "story"],
		["K01", "houses"], ["mountain_works", "mine"]]:
		assert_eq(RegionLooks.of(String(pair[0]), String(pair[1])), {}, str(pair))
	var expected: Dictionary = RegionLooks.LOOKS["K4"].duplicate(true)
	expected.erase("waterside")
	expected.erase("bare_line")
	assert_eq(RegionLooks.of("K4", "houses"), expected)
	assert_eq(RegionLooks.of("K4", "factory"), expected)
	assert_eq(RegionLooks.of("K1", "lodge"), RegionLooks.of("K9", "lodge"))
	assert_eq(RegionLooks.of("K1", "lodge"), RegionLooks.LOOKS["high_mountain"])
	assert_eq(RegionLooks.of("K4", "mine"), RegionLooks.LOOKS["mountain_works"])
	assert_eq(RegionLooks.of("K10", "lake"), RegionLooks.LOOKS["K10"].get("waterside", {}))
	assert_eq(RegionLooks.of("K10", "bare_line"), RegionLooks.LOOKS["K10"].get("bare_line", {}))
	var changed: Dictionary = RegionLooks.of("K4", "houses")
	changed["names"]["home"][0] = "바꾼 집"
	changed["uses"]["home"] = 0
	changed["sheds"][0] = "바꾼 헛간"
	changed["ground"][0] = 999
	changed["symbols"].clear()
	changed["facade"]["town"] = 0.0
	assert_eq(RegionLooks.of("K4", "houses"), expected, "중첩 배열과 사전도 별개다")
	var mountain: Dictionary = RegionLooks.of("K1", "lodge")
	mountain["names"]["lodge"].clear()
	assert_eq(RegionLooks.of("K9", "lodge"), RegionLooks.LOOKS["high_mountain"])


## 상자 양 배율: 띠 없음·호숫가·빈 땅은 정확히 1.0, 방향은 석탄·도시 많게, 평야 그대로, 외딴·산골 적게.
func test_loot_scale_is_one_without_a_band_and_follows_region_direction() -> void:
	assert_eq(RegionLooks.LOOT_SCALE.size(), 14)
	for key: String in RegionLooks.LOOKS:
		assert_true(RegionLooks.LOOT_SCALE.has(key), key)
		assert_between(float(RegionLooks.LOOT_SCALE[key]), 0.85, 1.15, key)
	for pair: Array in [["", "houses"], ["K99", "houses"], ["", "lodge"], ["", "mine"], ["K01", "houses"],
		["K4", "lake"], ["K4", "bare_line"], ["K4", "story"], ["mountain_works", "mine"]]:
		assert_eq(RegionLooks.loot_scale(String(pair[0]), String(pair[1])), 1.0, str(pair))
	for band: String in ["K4", "K5", "K9"]:
		assert_gt(RegionLooks.loot_scale(band, "houses"), 1.0, band)
	assert_gt(RegionLooks.loot_scale("K3", "houses"), 1.0)
	for band: String in ["K1", "K2", "K6", "K7", "K8", "K10"]:
		assert_eq(RegionLooks.loot_scale(band, "freight"), 1.0, band)
	for band: String in ["K11", "K12"]:
		assert_lt(RegionLooks.loot_scale(band, "church"), 1.0, band)
	for place_kind: String in ["mine", "sawmill", "lodge", "summit"]:
		assert_lt(RegionLooks.loot_scale("K4", place_kind), 1.0, place_kind)
		assert_eq(RegionLooks.loot_scale("K4", place_kind), RegionLooks.loot_scale("K9", place_kind), place_kind)


func test_names_weights_ranges_ground_and_existing_prop_catalogs() -> void:
	var assets: Dictionary = _catalog_names()
	assert_gt(assets.size(), 0)
	for band: String in RegionLooks.LOOKS:
		var look: Dictionary = RegionLooks.LOOKS[band]
		assert_false(look.has("waterside"), band + ": 들름 값은 다음 작업")
		assert_false(look.has("bare_line"), band + ": 들름 값은 다음 작업")
		assert_false(look.has("outer_lots"), band + ": 집터 수는 원래 뽑기에서 옮기기만 한다")
		assert_between(int(look["lot_shift"]), -2, 2, band)
		assert_gt(int(look["lot_step"]), 0, band)
		assert_gt(look["sheds"].size(), 0, band)
		for shed: String in look["sheds"]:
			assert_true(BuildingUses.use_of({"name": shed}) in ["barn", "depot", "shed"], band + ": " + shed)
		var total: float = 0.0
		for use: String in look["uses"]:
			assert_true(USES.has(use), band + ": " + use)
			assert_true(float(look["uses"][use]) >= 0.0, band + ": " + use)
			total += float(look["uses"][use])
		assert_gt(total, 0.0, band)
		assert_almost_eq(total, 100.0, 0.001, band)
		for use: String in look["names"]:
			assert_true(USES.has(use), band + ": " + use)
			assert_gt(look["names"][use].size(), 0, band + ": " + use)
			for building_name: String in look["names"][use]:
				assert_eq(BuildingUses.use_of({"name": building_name}), use, band + ": " + building_name)
		for use: String in look["sizes"]:
			var bounds: Array = look["sizes"][use]
			assert_true(USES.has(use), band + ": " + use)
			assert_eq(bounds.size(), 4, band + ": " + use)
			assert_true(int(bounds[0]) > 0 and int(bounds[0]) <= int(bounds[2]), band + ": " + use)
			assert_true(int(bounds[1]) > 0 and int(bounds[1]) <= int(bounds[3]), band + ": " + use)
		var facade_total: float = 0.0
		var facades: Dictionary = look.get("facade", {})
		for region: String in facades:
			assert_true(REGIONS.has(region), band + ": " + region)
			assert_gt(float(facades[region]), 0.0, band + ": " + region)
			facade_total += float(facades[region])
		if not facades.is_empty():
			assert_almost_eq(facade_total, 1.0, 0.001, band)
		assert_eq(look["ground"].size(), 4, band)
		for layer: int in look["ground"]:
			assert_between(layer, 0, 7, band)
		for field: String in ["yard_cars", "symbols"]:
			for prop_name: String in look.get(field, []):
				assert_true(assets.has(prop_name), band + ": " + prop_name)
		for field: String in ["ground_wish", "tree_wish"]:
			for wish: Variant in look.get(field, []):
				assert_true(wish is String, band + ": " + field)
	assert_eq(int(RegionLooks.LOOKS["mountain_works"]["uses"]["office"]), 0)
	assert_false(RegionLooks.LOOKS["mountain_works"].has("facade"))


func test_absent_and_empty_bands_keep_the_same_old_village() -> void:
	for place: String in ["houses_01", "lodge_01"]:
		var absent: Dictionary = _ringed(place, "", false)
		var empty: Dictionary = _ringed(place, "")
		assert_eq(_signature(absent), _signature(empty), place)
		assert_eq(_signature(absent), _signature(_ringed(place, "K99")), place + ": 모르는 띠")
		var count: int = int(absent["map_ring"]["buildings"])
		assert_between(count, 4 if place == "houses_01" else 1, 8 if place == "houses_01" else 3, place)


func test_k4_lot_shift_names_and_repeatability() -> void:
	var data: Dictionary = _ringed("houses_01", "K4")
	var look: Dictionary = RegionLooks.of("K4", "houses")
	var buildings: Array[Dictionary] = _outer_buildings(data)
	var allowed_names: Array[String] = []
	for names: Array in look["names"].values():
		for building_name: String in names:
			allowed_names.append(building_name)
	assert_gt(buildings.size(), 0, "빈 마을로 범위 검사를 통과하지 않는다")
	var plain_target: int = int(_ringed("houses_01", "")["map_ring"]["target"])
	assert_eq(int(data["map_ring"]["target"]), plain_target + int(look["lot_shift"]), "원래 뽑은 수 + 지역 몫")
	assert_true(buildings.size() <= int(data["map_ring"]["target"]), "고리가 좁으면 목표보다 적게 둔다")
	assert_eq(buildings.size(), int(data["map_ring"]["buildings"]))
	for building: Dictionary in buildings:
		assert_true(allowed_names.has(String(building["name"])), String(building["name"]))
		assert_eq(BuildingUses.use_of(building), String(building["role"]))
	assert_eq(_signature(data), _signature(_build("houses_01", "K4", true)), "같은 지도와 띠는 다시 지어도 같다")
	_assert_ring_bounds(data)


func test_mountain_village_is_independent_of_valid_band() -> void:
	var first: Dictionary = _ringed("lodge_01", "K1")
	var ninth: Dictionary = _ringed("lodge_01", "K9")
	assert_eq(_signature(first), _signature(ninth))
	var plain: Dictionary = _ringed("lodge_01", "")
	assert_eq(int(first["map_ring"]["target"]), int(plain["map_ring"]["target"]) + int(RegionLooks.LOOKS["high_mountain"]["lot_shift"]))
	assert_true(int(first["map_ring"]["buildings"]) <= int(first["map_ring"]["target"]))
	for building: Dictionary in _outer_buildings(first):
		assert_ne(BuildingUses.use_of(building), "office", "0 비중인 경찰 초소는 짓지 않는다")
	_assert_ring_bounds(first)


func test_neighbour_names_sizes_and_long_buildings_stay_varied() -> void:
	for band: String in ["K4", "K9"]:
		var data: Dictionary = _ringed("houses_01", band)
		var counts: Dictionary = {}
		var sides: Array = [[], [], [], []]
		var buildings: Array[Dictionary] = _outer_buildings(data)
		assert_gt(buildings.size(), 0, band + ": 바깥 마을을 실제로 지어야 한다")
		for building: Dictionary in buildings:
			var building_name: String = String(building["name"])
			counts[building_name] = int(counts.get(building_name, 0)) + 1
			assert_true(int(counts[building_name]) <= 2, band + ": " + building_name)
			sides[_side_of(data, building)].append(building)
		for side: int in range(4):
			var rows: Array = sides[side]
			rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var ar: Rect2i = a["rect"]
				var br: Rect2i = b["rect"]
				return ar.position.x < br.position.x if side % 2 == 0 else ar.position.y < br.position.y)
			var previous_size: Vector2i = Vector2i.ZERO
			var previous_name: String = ""
			var previous_length: int = 0
			var repeated_long: int = 0
			for building: Dictionary in rows:
				var rect: Rect2i = building["rect"]
				var size: Vector2i = rect.size if side % 2 == 0 else Vector2i(rect.size.y, rect.size.x)
				var length: int = maxi(size.x, size.y)
				if previous_length > 0:
					assert_ne(String(building["name"]), previous_name, band + ": 이웃 이름")
					assert_ne(size, previous_size, band + ": 이웃 크기")
					if maxi(length, previous_length) >= 20:
						assert_true(absi(length - previous_length) >= 3, band + ": 긴 이웃은 세 칸 이상 차이")
				# 고리는 지상층만 만든다. 같은 길이·같은 층의 긴 건물 넷을 찾는다.
				repeated_long = repeated_long + 1 if length >= 20 and length == previous_length else (1 if length >= 20 else 0)
				assert_true(repeated_long <= 3, band + ": 같은 긴 건물 넷 연속 금지")
				previous_size = size
				previous_name = String(building["name"])
				previous_length = length
		_assert_ring_bounds(data)


## 정차 전체의 상자를 잰다. 몫은 각 stock 갈래의 물건 무게 / 전체 물건 무게다.
## 갈래가 없는 물건도 빈 문자열 갈래로 세어 분모에서 빠지는 물건이 없게 한다.
## 무게는 바깥 마을이 바꾼 몫에 상자 양 배율(LootDress.dress가 거는 값)을 곱해, 띠 없는 판 대비 지역 폭 안인지 본다.
func test_stop_loot_weight_and_stock_shares_remain_in_bounds() -> void:
	for pair: Array in [["houses_01", "K4"], ["hospital_01", "K4"], ["church_01", "K4"], ["freight_01", "K4"],
		["houses_01", "K9"], ["church_01", "K12"], ["houses_01", "K12"], ["lodge_01", "K7"]]:
		var place: String = String(pair[0])
		var band: String = String(pair[1])
		var base: Dictionary = _loot(_ringed(place, ""))
		var changed_data: Dictionary = _ringed(place, band)
		var changed: Dictionary = _loot(changed_data)
		var base_weight: float = float(base["weight"])
		var changed_weight: float = float(changed["weight"])
		assert_gt(base_weight, 0.0, place + ": 비교 기준 무게")
		assert_gt(changed_weight, 0.0, place + ": 지역 무게")
		if base_weight <= 0.0 or changed_weight <= 0.0:
			continue
		var scale: float = RegionLooks.loot_scale(band, String(changed_data.get("place_kind", "")))
		var difference: float = changed_weight * scale / base_weight - 1.0
		var bounds: Array = _weight_bounds(band, String(changed_data.get("place_kind", "")))
		var context: String = "%s %s: 기준 %.3f, 지역 %.3f × 배율 %.2f, 증감 %+.2f%% (폭 %+d%% ~ %+d%%)" % [place, band, base_weight,
			changed_weight, scale, difference * 100.0, roundi(float(bounds[0]) * 100.0), roundi(float(bounds[1]) * 100.0)]
		print(context)
		assert_between(difference, float(bounds[0]) - 0.000001, float(bounds[1]) + 0.000001, context + ": 지역 무게 폭")
		var stocks: Dictionary = (base["stocks"] as Dictionary).duplicate()
		stocks.merge(changed["stocks"])
		for stock: String in stocks:
			var base_share: float = float(base["stocks"].get(stock, 0.0)) / base_weight
			var changed_share: float = float(changed["stocks"].get(stock, 0.0)) / changed_weight
			var delta: float = changed_share - base_share
			var stock_context: String = "%s / %s: 기준 %.2f%%, 지역 %.2f%%, 차이 %+.2f%%p" % [place, stock, base_share * 100.0, changed_share * 100.0, delta * 100.0]
			print(stock_context)
			assert_true(absf(delta) <= 0.050001, stock_context + ": 몫 ±5%포인트")


func _catalog_names() -> Dictionary:
	var paths: Array[String] = ["res://models/props_common/catalog.json", "res://models/props_stop01/catalog_cc0.json"]
	for file_name: String in DirAccess.get_files_at("res://models/props_field"):
		if file_name.begins_with("catalog_") and file_name.ends_with(".json"):
			paths.append("res://models/props_field/" + file_name)
	var out: Dictionary = {}
	for path: String in paths:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_true(parsed is Dictionary, path)
		if parsed is Dictionary:
			var catalog: Dictionary = parsed
			for asset_name: String in catalog.get("assets", {}):
				out[asset_name] = true
	return out


## MapRing.build와 같은 plain_build 경로를 쓰고, add 전에만 띠를 넣는다.
## 완성한 사전만 캐시한다. FieldGrid를 공유한 plain 사본에 add를 두 번 하지 않는다.
func _build(place: String, band: String, include_band: bool) -> Dictionary:
	var previous_skip: bool = MapRing.skip_paths
	MapRing.skip_paths = true
	var plain: Dictionary = MapRing.plain_build(load(FieldMaps.path_of(place)), FieldMaps.build_from)
	MapRing.skip_paths = previous_skip
	if include_band:
		plain["region_band"] = band
	else:
		plain.erase("region_band")
	return MapRing.add(plain)


func _ringed(place: String, band: String, include_band: bool = true) -> Dictionary:
	var key: String = "%s|%s|%s" % [place, band, str(include_band)]
	if not _built.has(key):
		_built[key] = _build(place, band, include_band)
	return _built[key]


func _outer_buildings(data: Dictionary) -> Array[Dictionary]:
	var inner: Rect2i = data["map_ring"]["inner"]
	var out: Array[Dictionary] = []
	for building: Dictionary in data["buildings"]:
		var rect: Rect2i = building["rect"]
		if not inner.intersects(rect):
			out.append(building)
	return out


func _signature(data: Dictionary) -> Dictionary:
	var grid: FieldGrid = data["grid"]
	return {"ring": data["map_ring"], "buildings": data["buildings"], "containers": data["containers"],
		"props": data["props"], "trees": data["trees"], "labels": data["labels"], "low_blocks": data["low_blocks"],
		"solid": grid.solid, "floor": grid.floor, "building": grid.building, "doors": grid.doors, "windows": grid.windows}


func _side_of(data: Dictionary, building: Dictionary) -> int:
	var rect: Rect2i = building["rect"]
	var inner: Rect2i = data["map_ring"]["inner"]
	if rect.end.y <= inner.position.y:
		return 0
	if rect.position.x >= inner.end.x:
		return 1
	return 2 if rect.position.y >= inner.end.y else 3


func _assert_ring_bounds(data: Dictionary) -> void:
	var grid: FieldGrid = data["grid"]
	var inner: Rect2i = data["map_ring"]["inner"]
	var map_bounds: Rect2i = Rect2i(0, 0, grid.width, grid.height)
	var yards: Array[Rect2i] = []
	for building: Dictionary in _outer_buildings(data):
		var rect: Rect2i = building["rect"]
		var yard: Rect2i = rect.grow(1)
		assert_true(map_bounds.encloses(yard), String(building["name"]))
		assert_false(inner.intersects(yard), "옛 지도 안에는 놓지 않는다")
		for road: Rect2i in data["map_ring"]["roads"]:
			assert_false(yard.intersects(road), "기존 길 자리는 비운다")
		for other: Rect2i in yards:
			assert_false(yard.intersects(other), "여러 집을 같은 울타리에 넣지 않는다")
		yards.append(yard)


## 띠 없이 지은 판 대비 정차 상자 무게 합의 폭: 석탄·큰 도시 0~+15%, 작은 도시 0~+10%, 외딴·산골 -15~0%, 나머지 ±5%.
func _weight_bounds(band: String, place_kind: String) -> Array:
	if String(BuildingUses.REGION_OF_GROUP.get(place_kind, "")) in ["mountain_works", "high_mountain"]:
		return [-0.15, 0.0]
	if band in ["K4", "K5", "K9"]:
		return [0.0, 0.15]
	if band == "K3":
		return [0.0, 0.10]
	if band in ["K11", "K12"]:
		return [-0.15, 0.0]
	return [-0.05, 0.05]


func _loot(data: Dictionary) -> Dictionary:
	var weight: float = 0.0
	var stocks: Dictionary = {}
	for box: Dictionary in data["containers"].values():
		for item: Variant in box.get("items", []):
			var item_id: String = MapRing._item_id(item)
			var amount: float = float(item.get("n", 1)) if item is Dictionary else 1.0
			var item_weight: float = Carry.item_weight(item_id) * amount
			assert_true(Carry.ITEM_WEIGHTS.has(item_id) or FieldItems.has(item_id) or Weapons.is_known(item_id), item_id + ": 무게가 정의되어야 한다")
			var stock: String = String(LEGACY_STOCK.get(item_id, FieldItems.stock_of(item_id)[0]))
			weight += item_weight
			stocks[stock] = float(stocks.get(stock, 0.0)) + item_weight
	return {"weight": weight, "stocks": stocks}
