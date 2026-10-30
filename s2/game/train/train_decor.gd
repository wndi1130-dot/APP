extends RefCounted
## Shared with S1 domestic/decor.ts. Coordinates are carried, not checked against a grid.

const TIER_CARS: Array[String] = ["tail1", "tail2", "tail3", "medtech", "guard", "front"]
const DECOR_CARS: Array[String] = ["tail1", "tail2", "tail3", "medtech", "guard", "front", "captain", "dining"]
const DECOR_SLOT_TABLE: Dictionary = {
	"tail1": "tier", "tail2": "tier", "tail3": "tier", "medtech": "tier", "guard": "tier", "front": "tier",
	"captain": "common", "dining": "common",
}
const DECOR_SLOTS: Array = [
	{"floor": 8, "wall": 0, "surface": 2}, {"floor": 14, "wall": 4, "surface": 4},
	{"floor": 21, "wall": 7, "surface": 6}, {"floor": 29, "wall": 10, "surface": 8},
]
const FURNISH_WALL_MAX: Dictionary = {"tail1": 6, "tail2": 7, "tail3": 5, "medtech": 12, "guard": 10, "front": 12, "captain": 11, "dining": 11}
## The dining car keeps its four-way walkway clear (row iz 4 is the aisle), so only 13 floor pieces fit.
const FURNISH_FLOOR_MAX: Dictionary = {"tail1": 29, "tail2": 29, "tail3": 29, "medtech": 29, "guard": 29, "front": 29, "captain": 29, "dining": 13}
const DECOR: Dictionary = {
	"chair": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "floor", "surface": false, "furniture": true, "model": ""},
	"side_table": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "floor", "surface": true, "furniture": true, "model": ""},
	"small_shelf": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "floor", "surface": true, "furniture": true, "model": ""},
	"oil_lamp": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "floor", "surface": false, "furniture": true, "model": "", "light": "lamp"},
	"small_box": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "floor", "surface": false, "furniture": true, "model": ""},
	"frame": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "wall", "surface": false, "furniture": true, "model": ""},
	"drawer": {"size": "medium", "warm": 0, "crowd": 0, "piano": false, "spot": "floor", "surface": true, "furniture": true, "model": ""},
	"bed_frame": {"size": "medium", "warm": 0, "crowd": -1, "piano": false, "spot": "floor", "surface": false, "furniture": true, "model": ""},
	"table": {"size": "medium", "warm": 0, "crowd": 0, "piano": false, "spot": "floor", "surface": true, "furniture": true, "model": ""},
	"bookshelf": {"size": "medium", "warm": 0, "crowd": 0, "piano": false, "spot": "floor", "surface": true, "furniture": true, "model": ""},
	"small_stove": {"size": "medium", "warm": 2, "crowd": 0, "piano": false, "spot": "floor", "surface": false, "furniture": true, "model": "", "light": "stove"},
	"wardrobe": {"size": "large", "warm": 0, "crowd": 0, "piano": false, "spot": "floor", "surface": false, "furniture": true, "model": ""},
	"piano": {"size": "large", "warm": 0, "crowd": 0, "piano": true, "spot": "floor", "surface": false, "furniture": true, "model": ""},
	"cupboard": {"size": "large", "warm": 0, "crowd": 0, "piano": false, "spot": "floor", "surface": true, "furniture": true, "model": ""},
	"iron_stove": {"size": "large", "warm": 4, "crowd": 0, "piano": false, "spot": "floor", "surface": false, "furniture": true, "model": "", "light": "stove"},
	"safe": {"size": "large", "warm": 0, "crowd": 0, "piano": false, "spot": "floor", "surface": false, "furniture": true, "model": ""},
	"painting": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "wall", "surface": false, "furniture": false, "model": "", "res": "lux", "v": 0.75},
	"record": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "surface", "surface": false, "furniture": false, "model": "", "res": "lux", "v": 0.5},
	"can_beans": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "surface", "surface": false, "furniture": false, "model": "", "res": "food", "v": 0.5},
	"can_meat": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "surface", "surface": false, "furniture": false, "model": "", "res": "food", "v": 0.5},
	"jar_cabbage": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "surface", "surface": false, "furniture": false, "model": "", "res": "food", "v": 0.5},
	"jar_jam": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "surface", "surface": false, "furniture": false, "model": "", "res": "food", "v": 0.5},
	"bottle_spirit": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "surface", "surface": false, "furniture": false, "model": "", "res": "lux", "v": 0.5},
	"rare_violin": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "wall", "surface": false, "furniture": false, "model": "", "res": "lux", "v": 1.5},
	"rare_wine_case": {"size": "small", "warm": 0, "crowd": 0, "piano": false, "spot": "surface", "surface": false, "furniture": false, "model": "", "res": "lux", "v": 2},
}
const FURNISH80: Dictionary = {
	"tail1": {
		"journal": "꼬리칸 선반에 인형과 장난감 차가 서고 전구 줄이 켜졌다. 아이들이 처음으로 늦게까지 논다.",
		"say": [
			"우리 칸도 이제 사람 사는 데 같다.",
			"열차장이 손수 놓은 거, 우리도 다 봤다.",
			"꾸며 준다고 빚이 없어지진 않는다. 그래도 고맙다."
		]
	},
	"tail2": {
		"journal": "꼬리칸 벽에 작은 그림이 줄지어 걸렸다. 사람들이 서로 자리를 비켜 앉는다.",
		"say": [
			"우리 칸도 이제 사람 사는 데 같다.",
			"열차장이 손수 놓은 거, 우리도 다 봤다.",
			"꾸며 준다고 빚이 없어지진 않는다. 그래도 고맙다."
		]
	},
	"tail3": {
		"journal": "꼬리칸 선반에 고무 오리와 병이 섰다. 처음으로 누가 노래를 흥얼거린다.",
		"say": [
			"우리 칸도 이제 사람 사는 데 같다.",
			"열차장이 손수 놓은 거, 우리도 다 봤다.",
			"꾸며 준다고 빚이 없어지진 않는다. 그래도 고맙다."
		]
	},
	"medtech": {
		"journal": "의무칸 선반에 약병이 크기대로 섰다. 환자들이 처음으로 창 쪽을 보고 눕는다.",
		"say": [
			"이 칸에서 웃는 환자는 처음 봤다. 적어 둔다.",
			"손 닿는 데 다 있다. 열차장 몫으로 적어 두겠다.",
			"보기 좋다. 그래도 침상 수는 그대로다."
		]
	},
	"guard": {
		"journal": "경비대 칸 벽에 지도와 작은 그림이 걸렸다. 교대하는 대원마다 멈춰 서서 한 번씩 본다.",
		"say": [
			"초소 같지 않다. 집 같다.",
			"대원들이 고맙다고 전해 달란다. 나도다.",
			"꾸밈은 받았다. 할 말은 회기에서 한다."
		]
	},
	"front": {
		"journal": "앞칸 탁자마다 등잔이 켜지고 레코드가 돈다. 앞칸 사람들이 다시 손님을 들이기 시작했다.",
		"say": [
			"이제야 손님을 맞을 만합니다.",
			"손수 놓으셨다지요. 앞칸이 기억해 두겠습니다.",
			"보기엔 좋지요. 그래도 셈은 따로 하겠습니다."
		]
	},
	"captain": {
		"journal": "열차장실 책상에 노선도가 펼쳐지고 등잔이 켜졌다. 찾아온 대표들이 처음으로 앉아서 말한다.",
		"say": []
	},
	"dining": {
		"journal": "식당칸 탁자마다 등잔이 켜지고 벽에 그림이 걸렸다. 칸이 다른 사람들이 처음으로 한 탁자에 앉는다.",
		"say": [
			"여기서 먹으니 같은 열차 사람 같다.",
			"열차장이 손수 걸었다더라. 오늘은 다 같이 먹자.",
			"탁자는 좋아졌다. 그릇이 차야 웃는다."
		]
	}
}
const POINTS: Dictionary = {"small": 1, "medium": 2, "large": 3}
const CROWD: Dictionary = {"small": 0, "medium": 0.5, "large": 1.5}


static func items_of(g: Dictionary, car: String) -> Array:
	return g.get("dom", {}).get("furnish", {}).get(car, {}).get("items", []) if g.get("dom") is Dictionary else []


static func spot_of(item: Dictionary) -> String:
	return String(item.get("spot", DECOR[item["kind"]]["spot"]))


## Deferred D lookup avoids the Mods -> Decor preload cycle.
static func decor_parts(g: Dictionary, car: String) -> Array:
	if not DECOR_CARS.has(car):
		return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var d: Dictionary = load("res://game/train/train_mods.gd").D
	var items: Array = items_of(g, car)
	var kinds: Dictionary = {}
	var lights: Dictionary = {}
	var surfaces: Array[int] = []
	var occupied: Dictionary = {}
	var floors: int = 0
	var walls: int = 0
	var small: int = 0
	for i: int in items.size():
		var item: Dictionary = items[i]
		var def: Dictionary = DECOR[item["kind"]]
		kinds[item["kind"]] = true
		if def.has("light"): lights[def["light"]] = true
		match spot_of(item):
			"floor":
				floors += 1
				if def["surface"]: surfaces.append(i)
			"wall": walls += 1
			"surface":
				small += 1
				occupied[int(item.get("on", -1))] = true
	var covered: int = 0
	for i: int in surfaces:
		if occupied.has(i): covered += 1
	var parts: Array = [
		float(kinds.size()) / mini(int(d["decorKindMax"]), int(floor(float(d["decorKindShare"]) * DECOR.size()))),
		float(floors) / mini(int(d["decorFloorTarget"]), FURNISH_FLOOR_MAX[car]),
		float(walls) / mini(int(d["decorWallTarget"]), FURNISH_WALL_MAX[car]),
		float(covered) / surfaces.size() / float(d["decorSurfaceTarget"]) if not surfaces.is_empty() else 0.0,
		float(small) / float(d["decorSmallTarget"]), float(lights.size()) / float(d["decorLightTarget"]),
	]
	for i: int in parts.size(): parts[i] = minf(1.0, float(parts[i]))
	return parts


static func decor_percent(g: Dictionary, car: String) -> float:
	var total: float = 0.0
	for value: float in decor_parts(g, car): total += value
	return total / 6.0


static func decor_band(percent: float) -> int:
	var d: Dictionary = load("res://game/train/train_mods.gd").D
	var band: int = -1
	for i: int in d["decorThresholds"].size():
		if percent + float(d["decorEpsilon"]) >= float(d["decorThresholds"][i]): band = i
	return band


static func common_tier(g: Dictionary) -> int:
	if not g.get("dom") is Dictionary:
		return 0
	var result: int = 0
	for car: String in TIER_CARS:
		result = maxi(result, int(g.get("dom", {}).get("furnish", {}).get(car, {}).get("tier", 0)))
	return result


static func tier_of(g: Dictionary, car: String) -> int:
	return common_tier(g) if DECOR_SLOT_TABLE[car] == "common" else int(g.get("dom", {}).get("furnish", {}).get(car, {}).get("tier", 0))


static func slots_open(g: Dictionary, car: String) -> Dictionary:
	if not g.get("dom") is Dictionary or not DECOR_SLOT_TABLE.has(car):
		return {"floor": 0, "wall": 0, "surface": 0}
	var slots: Dictionary = DECOR_SLOTS[tier_of(g, car)]
	var result: Dictionary = {"floor": mini(int(slots["floor"]), int(FURNISH_FLOOR_MAX[car])), "wall": mini(int(slots["wall"]), int(FURNISH_WALL_MAX[car])), "surface": 0}
	for item: Dictionary in items_of(g, car):
		result[spot_of(item)] -= 1
		if DECOR[item["kind"]]["surface"]:
			result["surface"] += int(slots["surface"])
	for spot: String in result:
		result[spot] = maxi(0, int(result[spot]))
	return result


static func slots_fit(car: String, items: Array, tier: int) -> bool:
	var slots: Dictionary = DECOR_SLOTS[tier]
	var floor_used: int = 0
	var wall_used: int = 0
	var surfaces: Dictionary = {}
	for item: Dictionary in items:
		match spot_of(item):
			"floor": floor_used += 1
			"wall": wall_used += 1
			"surface":
				var on: int = int(item["on"])
				surfaces[on] = int(surfaces.get(on, 0)) + 1
				if int(surfaces[on]) > int(slots["surface"]):
					return false
	return floor_used <= mini(int(slots["floor"]), int(FURNISH_FLOOR_MAX[car])) and wall_used <= mini(int(slots["wall"]), int(FURNISH_WALL_MAX[car]))


## The resource numbers have already been credited by the receipt owner.
static func receive_decor(g: Dictionary, gained: Array) -> void:
	if not g.get("dom") is Dictionary:
		return
	if not g["dom"].has("store"):
		g["dom"]["store"] = {}
	for kind: Variant in gained:
		if DECOR.has(kind):
			add_stored(g["dom"]["store"], kind, DECOR[kind].get("v"))
	reconcile_store(g)


static func receive_receipt(g: Dictionary, receipt: Dictionary) -> void:
	receive_decor(g, receipt.get("items", {}).get("gained", []))


static func add_stored(store: Dictionary, kind: String, value: Variant = null) -> void:
	if not store.has(kind):
		store[kind] = {"n": 0}
	var entry: Dictionary = store[kind]
	entry["n"] += 1
	if value != null:
		var newest: int = -1
		for row: Dictionary in store.values():
			for tag: Dictionary in row.get("tags", []):
				newest = maxi(newest, int(tag["at"]))
		if not entry.has("tags"):
			entry["tags"] = []
		entry["tags"].append({"v": value, "at": newest + 1})


static func oldest(entry: Dictionary) -> Dictionary:
	var first: Dictionary = {}
	for tag: Dictionary in entry.get("tags", []):
		if first.is_empty() or int(tag["at"]) < int(first["at"]):
			first = tag
	return first


## One reconciliation used after settlement and on inventory reads. Placed items are never visited.
static func reconcile_store(g: Dictionary) -> void:
	if not g.get("dom") is Dictionary or not g["dom"].get("store") is Dictionary:
		return
	var store: Dictionary = g["dom"]["store"]
	for res: String in ["lux", "food", "med", "sup"]:
		var tags: Array = []
		var total: float = 0.0
		for kind: String in store:
			if DECOR.has(kind) and DECOR[kind].get("res") == res:
				var rows: Array = store[kind].get("tags", [])
				for i: int in rows.size():
					tags.append({"kind": kind, "tag": rows[i], "i": i})
					total += float(rows[i]["v"])
		tags.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["tag"]["at"] != b["tag"]["at"]: return a["tag"]["at"] > b["tag"]["at"]
			if a["kind"] != b["kind"]: return a["kind"] < b["kind"]
			return a["i"] > b["i"])
		for row: Dictionary in tags:
			if float(total) <= float(g.get(res, 0)):
				break
			var entry: Dictionary = store[row["kind"]]
			entry["tags"].erase(row["tag"])
			entry["n"] -= 1
			total -= float(row["tag"]["v"])
			if entry["n"] == 0:
				store.erase(row["kind"])


static func read_store(g: Dictionary) -> Dictionary:
	if not g.get("dom") is Dictionary:
		return {}
	if not g["dom"].has("store"):
		g["dom"]["store"] = {}
	reconcile_store(g)
	return g["dom"]["store"]


static func integer(v: Variant, minimum: int = 0) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floorf(float(v)) and float(v) >= minimum and absf(float(v)) <= 9007199254740991.0


## A tag carries what the field credited, so it may be a fraction (0.5, 0.75, 1.5).
static func worth(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) > 0.0


static func valid_at(at: Variant) -> bool:
	return at == null or (at is Array and at.size() == 2 and integer(at[0], -9007199254740991) and integer(at[1], -9007199254740991))


static func valid_rot(rot: Variant) -> bool:
	return rot == null or (integer(rot) and float(rot) <= 3.0)


static func can_place(g: Dictionary, car: String, kind: String, spot: String, at: Variant = null, rot: Variant = null, on: Variant = null) -> Dictionary:
	if not g.get("dom") is Dictionary or not DECOR_SLOT_TABLE.has(car):
		return {"ok": false, "why": "꾸미기는 객차 여덟 칸만"}
	if not DECOR.has(kind):
		return {"ok": false, "why": "알 수 없는 물건"}
	var def: Dictionary = DECOR[kind]
	if spot != def["spot"]:
		return {"ok": false, "why": "이 물건을 놓는 면이 아니다"}
	if not valid_at(at) or not valid_rot(rot):
		return {"ok": false, "why": "자리나 회전 값이 올바르지 않다"}
	if spot == "surface":
		var items: Array = items_of(g, car)
		if not integer(on) or float(on) >= items.size() or not DECOR[items[int(on)]["kind"]]["surface"] or spot_of(items[int(on)]) != "floor":
			return {"ok": false, "why": "올려놓을 면 가구가 없다"}
		var used: int = 0
		for item: Dictionary in items:
			if spot_of(item) == "surface" and item.get("on") == on:
				used += 1
		if used >= int(DECOR_SLOTS[tier_of(g, car)]["surface"]):
			return {"ok": false, "why": "그 가구 위에 자리가 없다"}
	else:
		if on != null:
			return {"ok": false, "why": "면 위 물건만 가구를 고른다"}
		if slots_open(g, car)[spot] <= 0:
			return {"ok": false, "why": "이 면에 물건을 놓을 자리가 없다"}
	var entry: Dictionary = read_store(g).get(kind, {})
	if entry.is_empty() or int(entry["n"]) < 1:
		return {"ok": false, "why": "창고에 그 물건이 없다"}
	if def.has("res"):
		var tag: Dictionary = oldest(entry)
		if tag.is_empty() or float(g.get(def["res"], 0)) < float(tag["v"]):
			return {"ok": false, "why": "이름표 몫의 물자가 모자라다"}
	return {"ok": true}


static func furniture_points(items: Array) -> int:
	var result: int = 0
	for item: Dictionary in items:
		if DECOR[item["kind"]]["furniture"]:
			result += int(POINTS[item["size"]])
	return result


static func decor_crowd(items: Array) -> float:
	var result: float = 0.0
	for item: Dictionary in items:
		if spot_of(item) == "floor":
			var def: Dictionary = DECOR[item["kind"]]
			result += float(CROWD[item["size"]]) + float(def["crowd"]) if def["furniture"] else (0.5 if item["size"] == "large" else 0.0)
	return result


static func is_inventory(v: Variant) -> bool:
	if not v is Dictionary:
		return false
	for kind: Variant in v:
		if not DECOR.has(kind) or not v[kind] is Dictionary:
			return false
		var entry: Dictionary = v[kind]
		if not integer(entry.get("n")):
			return false
		for key: Variant in entry:
			if key not in ["n", "tags"]:
				return false
		if DECOR[kind].has("res"):
			if not entry.get("tags") is Array or entry["tags"].size() != int(entry["n"]):
				return false
			for tag: Variant in entry["tags"]:
				if not tag is Dictionary or tag.size() != 2 or not worth(tag.get("v")) or not integer(tag.get("at")):
					return false
		elif entry.has("tags"):
			return false
	return true


static func is_items(items: Variant) -> bool:
	if not items is Array:
		return false
	for item: Variant in items:
		if not item is Dictionary or not DECOR.has(item.get("kind")):
			return false
		var def: Dictionary = DECOR[item["kind"]]
		if item.get("size") != def["size"] or item.get("spot", def["spot"]) != def["spot"]:
			return false
		for key: Variant in item:
			if key not in ["kind", "size", "spot", "at", "rot", "on", "v"]:
				return false
		if (item.has("at") and item["at"] == null) or not valid_at(item.get("at")) or (item.has("rot") and item["rot"] == null) or not valid_rot(item.get("rot")):
			return false
		if def.has("res"):
			if not worth(item.get("v")):
				return false
		elif item.has("v"):
			return false
		if def["spot"] == "surface":
			if not integer(item.get("on")) or float(item["on"]) >= items.size():
				return false
			var host: Variant = items[int(item["on"])]
			if not host is Dictionary or not DECOR.has(host.get("kind")) or not DECOR[host["kind"]]["surface"]:
				return false
		elif item.has("on"):
			return false
	return true


static func migrate(g: Dictionary) -> void:
	if not g.get("dom") is Dictionary:
		return
	var d: Dictionary = g["dom"]
	if not d.has("store"):
		d["store"] = {}
	if not d.has("decor80"):
		d["decor80"] = []
	if d.get("furnish") is Dictionary:
		for state: Variant in d["furnish"].values():
			if not state is Dictionary or not state.get("items") is Array:
				continue
			if state.has("tier"):
				state["best"] = maxi(int(state.get("best", state["tier"])), int(state["tier"]))
			for item: Variant in state["items"]:
				if item is Dictionary and DECOR.has(item.get("kind")) and not item.has("spot"):
					item["spot"] = DECOR[item["kind"]]["spot"]
	if is_inventory(d["store"]):
		reconcile_store(g)
