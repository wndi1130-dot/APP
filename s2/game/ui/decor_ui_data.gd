extends RefCounted
## Presentation values only. The shared rules own stock, slots and every mutation.

const Decor = preload("res://game/train/train_decor.gd")
const Mods = preload("res://game/train/train_mods.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const TABS: Array[String] = ["모두", "가구", "벽", "면 위", "생필품", "사치품"]
const SPOTS := {"floor": "바닥", "wall": "벽", "surface": "면 위"}
const SIZES := {"small": "작음", "medium": "중간", "large": "큼"}
const RESOURCES := {"food": "식량", "sup": "생필품", "med": "약품", "lux": "사치품"}
const NAMES := {
	"chair": "의자", "side_table": "작은 탁자", "small_shelf": "작은 선반",
	"oil_lamp": "등잔", "small_box": "작은 상자", "frame": "액자",
	"drawer": "서랍장", "bed_frame": "침대", "table": "탁자", "bookshelf": "책장",
	"small_stove": "작은 난로", "wardrobe": "옷장", "piano": "피아노",
	"cupboard": "찬장", "iron_stove": "무쇠 난로", "safe": "금고", "painting": "작은 그림",
	"bottle_spirit": "술 한 병", # The legacy stock name in carry.gd.
}
const HINT := "끌어서 놓기 · 길게 눌러 집기 · 두 손가락으로 돌리기 · 창고 띠로 끌면 거두기"
const PAPER_LOCK := "종이 카드를 고르는 동안에는 꾸밀 수 없어요."
const COUNCIL_LOCK := "의회 중에는 꾸밀 수 없어요."


static func lock_reason(g: Dictionary, choosing_paper: bool = true) -> String:
	if String(g.get("phase", "")) == "council":
		return COUNCIL_LOCK
	if choosing_paper and g.get("cards") is Array and not (g["cards"] as Array).is_empty():
		return PAPER_LOCK
	return ""


static func percent(g: Dictionary, car: String) -> int:
	return int(round(Decor.decor_percent(g, car) * 100.0))


static func item_name(kind: String) -> String:
	if NAMES.has(kind):
		return NAMES[kind]
	return String(FieldItems.ITEMS.get(kind, FieldItems.RARE.get(kind, {})).get("name", kind))


static func number(value: float) -> String:
	return ("%.1f" % snappedf(value, 0.1)).trim_suffix(".0")


static func in_tab(def: Dictionary, tab: int) -> bool:
	match tab:
		1: return bool(def["furniture"]) and def["spot"] == "floor"
		2: return def["spot"] == "wall"
		3: return def["spot"] == "surface"
		4: return def.get("res", "") == "sup"
		5: return def.get("res", "") == "lux"
	return true


static func model(g: Dictionary, car: String, tab: int = 0) -> Dictionary:
	var store: Dictionary = Decor.read_store(g)
	var known: Dictionary = {}
	for kind: String in store:
		known[kind] = true
	# An exhausted kind remains visible while it stands in any car.
	for id: String in Decor.DECOR_CARS:
		for item: Dictionary in Decor.items_of(g, id):
			known[item["kind"]] = true
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	var cards: Array[Dictionary] = []
	for kind: String in Decor.DECOR:
		if not known.has(kind):
			continue
		var def: Dictionary = Decor.DECOR[kind]
		var entry: Dictionary = store.get(kind, {})
		var n: int = int(entry.get("n", 0))
		for i: int in counts.size():
			if in_tab(def, i):
				counts[i] += n
		if not in_tab(def, tab):
			continue
		var detail: String = SPOTS[def["spot"]] + " · " + SIZES[def["size"]]
		if def.has("light"):
			detail += " · 빛"
		var cost: String = ""
		if def.has("res"):
			var value: float = float(Decor.oldest(entry).get("v", def.get("v", 0.0)))
			cost = "놓으면 %s −%s" % [RESOURCES[def["res"]], number(value)]
		cards.append({"kind": kind, "name": item_name(kind), "n": n, "count": "×%d" % n,
			"detail": detail if n > 0 else "다 놓음", "cost": cost, "spot": def["spot"]})
	var slots: Array[Dictionary] = []
	var used := {"floor": 0, "wall": 0, "surface": 0}
	for item: Dictionary in Decor.items_of(g, car):
		used[Decor.spot_of(item)] += 1
	var open: Dictionary = Decor.slots_open(g, car)
	for spot: String in ["floor", "wall", "surface"]:
		var total: int = int(used[spot]) + int(open[spot])
		slots.append({"spot": spot, "word": SPOTS[spot], "used": used[spot], "total": total,
			"text": "%s %d/%d" % [SPOTS[spot], used[spot], total], "dim": int(open[spot]) == 0})
	var tier: String = Mods.FURNISH_NAMES[Decor.tier_of(g, car)]
	return {"title": String(Mods.CAR_NAME.get(car, car)) + " 꾸미기",
		"subtitle": "%s · 꾸밈 %d%%" % [tier, percent(g, car)],
		"slots": slots, "counts": counts, "cards": cards, "hint": HINT}
