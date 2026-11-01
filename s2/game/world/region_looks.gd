extends RefCounted
## 지역 띠마다 바깥 마을을 고르는 값. 겉·소품·바닥 희망값은 다음 작업이 읽는다.
const BuildingUses = preload("res://game/world/building_uses.gd")

const LAKE_PLAIN: Dictionary = {
	"lot_shift": 0, "lot_step": 28, "sheds": ["외양간", "바깥 헛간"],
	"uses": {"home": 40, "barn": 20, "store": 10, "shop": 10, "station": 5, "depot": 5, "hall": 5, "office": 5},
	"names": {"home": ["벽돌 농가", "살림집"], "barn": ["목판 헛간"], "store": ["곡물 창고"],
		"shop": ["가게"], "station": ["작은 역사"], "depot": ["차고"], "hall": ["회관"], "office": ["관리 사무실"]},
	"sizes": {"home": [8, 10, 10, 12], "barn": [5, 6, 6, 6]},
	"facade": {"town": 1.0}, "yard_cars": ["car", "farm_cart", "hay_cart", "pickup_truck"],
	"symbols": ["water_tower", "power_pole", "fieldstone_wall", "plank_fence"], "ground": [4, 6, 2, 7],
}
const BORDER_RIVER: Dictionary = {
	"lot_shift": 0, "lot_step": 19, "sheds": ["차고", "바깥 헛간"],
	"uses": {"home": 35, "shop": 20, "depot": 15, "store": 15, "office": 5, "hall": 5, "barn": 5},
	"names": {"home": ["공동주택", "연립"], "shop": ["가게", "잡화점"], "depot": ["차고"],
		"store": ["강가 창고"], "office": ["관청"], "hall": ["회관"], "barn": ["헛간"]},
	"sizes": {"home": [24, 10, 30, 12], "shop": [12, 10, 16, 12]},
	"facade": {"town": 1.0}, "yard_cars": ["car", "box_truck", "city_bus"],
	"symbols": ["bridge_rail", "shop_awning", "garage_door_leaf", "mooring_post"], "ground": [0, 1, 3, 7],
}
const COAL_PLAIN: Dictionary = {
	"lot_shift": 1, "lot_step": 18, "sheds": ["석탄 헛간", "차고"],
	"uses": {"home": 42, "store": 18, "works": 12, "shop": 11, "hall": 5, "station": 4, "depot": 3, "barn": 3, "clinic": 2},
	"names": {"home": ["공동주택", "연립"], "store": ["석탄 창고", "자재 창고", "하역 창고"],
		"works": ["선탄장", "변전실", "정비 공방"], "shop": ["매점", "식료품점", "가게"],
		"hall": ["구내식당", "회관"], "station": ["역사"], "depot": ["기관고", "화차고"],
		"barn": ["헛간"], "clinic": ["진료소"]},
	"sizes": {"station": [30, 12, 36, 14], "home": [20, 10, 28, 12], "store": [16, 10, 30, 14]},
	"facade": {"town": 0.6, "rail_works": 0.4}, "yard_cars": ["ore_truck", "box_truck", "tow_truck", "car"],
	"symbols": ["coal_heap", "coal_bin", "coal_hopper", "conveyor", "coal_sorter", "coal_wagon", "slag_heap", "transformer_unit"],
	"ground": [2, 6, 4, 7], "ground_wish": ["석탄 가루 흙", "모래"], "tree_wish": ["소나무"],
}
const FLOOD_SUBURB: Dictionary = {
	"lot_shift": 0, "lot_step": 22, "sheds": ["바깥 헛간", "차고"],
	"uses": {"store": 25, "home": 25, "barn": 25, "works": 10, "shop": 10, "hall": 5},
	"names": {"store": ["화물 창고"], "home": ["살림집"], "barn": ["주말농장 헛간"],
		"works": ["작업장"], "shop": ["가게"], "hall": ["회관"]},
	"sizes": {"barn": [4, 5, 6, 5]}, "facade": {"town": 0.7, "rail_works": 0.3},
	"yard_cars": ["car", "pickup_truck"], "symbols": ["old_coach", "signal_post", "fallen_signal", "garden_bed", "laundry_line"],
	"ground": [0, 1, 3, 6],
}
const GRAIN_PLAIN: Dictionary = {
	"lot_shift": 0, "lot_step": 35, "sheds": ["바깥 헛간", "외양간"],
	"uses": {"store": 30, "works": 25, "home": 25, "barn": 10, "shop": 5, "hall": 5},
	"names": {"store": ["곡물 창고"], "works": ["제분 공방", "농기계 정비"], "home": ["농가"],
		"barn": ["사일로"], "shop": ["가게"], "hall": ["회관"]},
	"sizes": {"store": [30, 12, 40, 14], "barn": [6, 6, 6, 6], "home": [10, 12, 10, 12]},
	"facade": {"rail_works": 0.5, "town": 0.5}, "yard_cars": ["farm_tractor", "pickup_truck", "box_truck"],
	"symbols": ["grain_silo", "flour_sack_pile", "millstone", "pallet_stack", "weigh_platform"], "ground": [2, 6, 4, 7],
}
const HEATH_PLAIN: Dictionary = {
	"lot_shift": 0, "lot_step": 28, "sheds": ["장작 헛간", "외양간"],
	"uses": {"home": 35, "barn": 25, "depot": 10, "store": 10, "shop": 10, "church": 5, "hall": 5},
	"names": {"home": ["들돌 농가", "회칠 연립"], "barn": ["목재 헛간"], "depot": ["기관고"],
		"store": ["창고"], "shop": ["가게"], "church": ["교회"], "hall": ["회관"]},
	"sizes": {"home": [10, 12, 10, 12]}, "facade": {"town": 0.8, "rail_works": 0.2},
	"yard_cars": ["car", "log_truck"], "symbols": ["fieldstone_wall", "log_stack_high", "bush_juniper", "ice_saw_frame", "buoy_line"],
	"ground": [4, 6, 2, 7], "ground_wish": ["모래"], "tree_wish": ["소나무"],
}
const CITY_CANAL: Dictionary = {
	"lot_shift": 1, "lot_step": 17, "sheds": ["차고", "바깥 헛간"],
	"uses": {"home": 40, "depot": 15, "shop": 15, "office": 10, "station": 8, "works": 7, "hall": 5},
	"names": {"home": ["공동주택"], "depot": ["차고"], "shop": ["단지 가게"], "office": ["학교", "관청"],
		"station": ["신호소"], "works": ["정비 공방"], "hall": ["회관"]},
	"sizes": {"home": [30, 12, 34, 12]}, "facade": {"town": 0.7, "rail_works": 0.3},
	"yard_cars": ["city_bus", "stalled_tram", "car", "box_truck"],
	"symbols": ["signal_bridge", "water_crane", "switch_cluster", "playground_frame", "bin_bay"], "ground": [0, 1, 3, 5],
}
const FOREST_LAKES: Dictionary = {
	"lot_shift": 0, "lot_step": 29, "sheds": ["장작 헛간", "바깥 헛간"],
	"uses": {"home": 30, "barn": 25, "store": 15, "works": 15, "shop": 10, "church": 5},
	"names": {"home": ["살림집"], "barn": ["들돌 헛간", "장작 헛간"], "store": ["보트 창고"],
		"works": ["정비 공방"], "shop": ["가게"], "church": ["교회"]},
	"sizes": {"home": [8, 10, 10, 12]}, "facade": {"town": 0.8, "waterside": 0.2},
	"yard_cars": ["car", "pickup_truck", "log_truck"],
	"symbols": ["boat_on_blocks", "net_pile", "firewood_rick", "street_tree", "radio_set", "generator"],
	"ground": [1, 4, 3, 7], "ground_wish": ["숲 바닥"], "tree_wish": ["너도밤나무"],
}
const LAGOON_COAST: Dictionary = {
	"lot_shift": 0, "lot_step": 27, "sheds": ["어구 헛간", "바깥 헛간"],
	"uses": {"home": 40, "store": 20, "barn": 20, "works": 10, "church": 5, "hall": 5},
	"names": {"home": ["어촌 집", "농가"], "store": ["항만 창고"], "barn": ["어구 헛간", "훈제 헛간"],
		"works": ["배수 펌프장"], "church": ["교회"], "hall": ["회관"]},
	"sizes": {"home": [8, 10, 8, 10], "barn": [5, 5, 6, 5]}, "facade": {"waterside": 0.5, "town": 0.5},
	"yard_cars": ["fish_truck", "pickup_truck", "car"],
	"symbols": ["net_drying_rack", "fish_drying_frame", "fish_trap_stack", "fishing_boat", "pier_deck", "anchor", "reed_bundle"],
	"ground": [2, 6, 3, 6], "ground_wish": ["토탄 흙"],
}
const ISLAND: Dictionary = {
	"lot_shift": 0, "lot_step": 30, "sheds": ["바깥 헛간", "장작 헛간"],
	"uses": {"home": 45, "barn": 20, "store": 15, "shop": 10, "church": 10},
	"names": {"home": ["섬 마을 집"], "barn": ["헛간"], "store": ["구내 창고"], "shop": ["가게"], "church": ["교회"]},
	"sizes": {"home": [8, 10, 8, 10]}, "facade": {"town": 0.6, "waterside": 0.4},
	"yard_cars": ["car", "pickup_truck"], "symbols": ["anchor", "mooring_post", "fishing_boat", "reed_clump", "fieldstone_wall", "stone_wall_segment"],
	"ground": [4, 6, 3, 7], "ground_wish": ["모래"], "tree_wish": ["해안 소나무"],
}
const MOUNTAINS: Dictionary = {
	"lot_shift": 0, "lot_step": 50, "sheds": ["장작 헛간", "자재 헛간"],
	"uses": {"lodge": 35, "barn": 17, "sawmill": 15, "works": 10, "shop": 8, "depot": 5, "hall": 5, "home": 5, "office": 0},
	"names": {"lodge": ["산장", "통나무 오두막"], "barn": ["건조장", "자재 헛간"], "sawmill": ["제재소"],
		"works": ["임업 작업장"], "shop": ["작은 가게"], "depot": ["작은 소방 차고"], "hall": ["산골 식당"],
		"home": ["관리인 집"], "office": ["경찰 초소"]},
	"sizes": {"lodge": [12, 10, 16, 12], "home": [8, 8, 10, 10], "shop": [8, 8, 8, 8],
		"depot": [10, 8, 10, 8], "office": [6, 8, 6, 8]},
	"yard_cars": ["log_truck", "skidder", "snowplow_truck", "pickup_truck"],
	"symbols": ["firewood_stack", "log_stack_low", "lumber_rack", "sawhorse", "axe_rack", "sled_load", "boulder", "stump_cluster"],
	"ground": [4, 6, 4, 7], "ground_wish": ["바위 땅", "바늘잎 숲 바닥"],
}

## 정차 없는 띠와 산간 두 지역은 같은 원본 값을 쓴다. 바깥에는 복사본만 준다.
const LOOKS: Dictionary = {
	"K1": LAKE_PLAIN, "K2": LAKE_PLAIN, "K3": BORDER_RIVER, "K4": COAL_PLAIN, "K5": COAL_PLAIN,
	"K6": FLOOD_SUBURB, "K7": GRAIN_PLAIN, "K8": HEATH_PLAIN, "K9": CITY_CANAL,
	"K10": FOREST_LAKES, "K11": LAGOON_COAST, "K12": ISLAND,
	"mountain_works": MOUNTAINS, "high_mountain": MOUNTAINS,
}

## 정차 상자 물건 양에 거는 지역 배율. 석탄 지대·큰 도시는 많게, 산골·외딴 해안과 섬은 적게 한다.
## 바깥 마을 집터는 그 지도의 원래 수에서 lot_shift만큼만 옮겨, 띠 없이 지은 판 대비 무게 합이 ±15% 안에 들게 한다.
## LootDress.dress가 끝에서 읽는다.
const LOOT_SCALE: Dictionary = {
	"K1": 1.0, "K2": 1.0, "K3": 1.05, "K4": 1.06, "K5": 1.06, "K6": 1.0, "K7": 1.0, "K8": 1.0,
	"K9": 1.06, "K10": 1.0, "K11": 0.91, "K12": 0.91, "mountain_works": 0.91, "high_mountain": 0.91,
}


static func of(band: String, place_kind: String) -> Dictionary:
	if not band.begins_with("K") or not LOOKS.has(band):
		return {}
	var region: String = String(BuildingUses.REGION_OF_GROUP.get(place_kind, ""))
	if region in ["mountain_works", "high_mountain"]:
		return LOOKS[region].duplicate(true)
	var band_look: Dictionary = LOOKS[band]
	if region in ["waterside", "bare_line"]:
		var visit: Dictionary = band_look.get(region, {})
		return visit.duplicate(true)
	if region not in ["town", "rail_works"]:
		return {}
	var out: Dictionary = band_look.duplicate(true)
	out.erase("waterside")
	out.erase("bare_line")
	return out


## 띠가 없거나 모르는 띠, 호숫가·빈 땅 지도는 정확히 1.0이다. 산간 지도는 띠와 상관없이 산골 값을 쓴다.
static func loot_scale(band: String, place_kind: String) -> float:
	if not band.begins_with("K") or not LOOKS.has(band):
		return 1.0
	var region: String = String(BuildingUses.REGION_OF_GROUP.get(place_kind, ""))
	if region in ["mountain_works", "high_mountain"]:
		return float(LOOT_SCALE[region])
	if region not in ["town", "rail_works"]:
		return 1.0
	return float(LOOT_SCALE[band])
