extends RefCounted
## The bag and what is near on one glass (decision 448-1, inventory.md 3절):
## the bag at the left, at the right one place near at a time (the train's hold
## by the train, a searched box within reach, the ground at one's feet) chosen
## by its key. A press on a row moves it across: from the bag into the box, onto
## the ground or aboard; from the box or the ground into the bag. One key under
## the right side moves them all. Nothing here takes time that did not before.
## Built on field_hud.gd's pane; field_hud.gd keeps the keys' callbacks.

const GlassPane = preload("res://game/ui/glass_pane.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const LampKey = preload("res://game/ui/lamp_key.gd")
const Carry = preload("res://game/sim/carry.gd")
const W = preload("res://game/sim/weapons.gd")
const Wear = preload("res://game/sim/wear.gd")

## The pane and its two sides (css): within a 16:9 screen's 693 across.
const PANE_W: float = 640.0
const SIDE_W: float = 284.0
const LIST_MAX: float = 176.0
## As field_hud.gd's: a side key's width, the worn list's height.
const KEY_W: float = 84.0
const WORN_MAX: float = 132.0
## The key of the place chosen at the right.
const CHOSEN := Color(0.95, 0.65, 0.24, 0.24)


## The places near `p`, as the right side's keys, the train's hold first.
static func places(game, p) -> Array:
	var out: Array = []
	if game.actions.at_unloading(p):
		out.append({"kind": "train", "id": "", "name": "열차 짐칸"})
	for id: String in game.actions.near_boxes(p):
		out.append({"kind": "box", "id": id, "name": String(game.data["containers"][id]["name"])})
	out.append({"kind": "ground", "id": "", "name": "바닥"})
	return out


## The place asked for if it is still near, else the first.
static func chosen(all: Array, want: Dictionary) -> Dictionary:
	for place: Dictionary in all:
		if place["kind"] == want.get("kind", "") and place["id"] == want.get("id", ""):
			return place
	return all[0]


## The bag's rows in the order shown: heaviest first, or by name.
static func bag_order(game, p, by: String) -> Array:
	var ids: Array = p.items.keys()
	if by == "name":
		ids.sort_custom(func(a, b) -> bool: return game.item_name(a) < game.item_name(b))
	else:
		ids.sort_custom(func(a, b) -> bool: return Carry.item_weight(a) * int(p.items[a]) > Carry.item_weight(b) * int(p.items[b]))
	return ids


static func open(hud, want: Dictionary) -> void:
	var game = hud.game
	var p = game.player
	var all := places(game, p)
	var at := chosen(all, want)
	hud.inv_near = at
	var pane = hud._open_pane(String(Carry.BAGS[p.bag]["name"]), "%.1f / %.0f · %s" % [p.weight(), p.carry_limit(), Carry.STATE_NAMES[p.carry_state()]], "inv", PANE_W)
	var sides := GlassPane.row()
	sides.add_theme_constant_override("separation", GlassPane.px(16.0))
	pane.body.add_child(sides)
	sides.add_child(_bag_side(hud, p, at))
	sides.add_child(_near_side(hud, p, at, all))
	# 일지: this stop's goals (decision 293 ②), under both sides.
	var goals: String = game.goal_text() if game.mission_play != null else ""
	if goals != "":
		pane.body.add_child(hud._journal_note(goals))


static func _side() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.custom_minimum_size.x = UiFonts.px(SIDE_W)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", GlassPane.px(GlassPane.GAP))
	return v


## The left: the two weapons and their swap, what is worn (folded in a scroll),
## the bag's rows with the order key, the rounds.
static func _bag_side(hud, p, at: Dictionary) -> Control:
	var game = hud.game
	var side := _side()
	var head := GlassPane.row()
	head.add_child(UiFonts.label("내 가방", UiFonts.WORD, 600, 13.0, GlassPane.INK, 0.39))
	var order := GlassPane.key("이름순" if hud.inv_sort == "name" else "무게순", hud._inv_sort)
	order.size_flags_horizontal = Control.SIZE_SHRINK_END
	order.custom_minimum_size.x = UiFonts.px(KEY_W)
	head.add_child(order)
	side.add_child(head)
	if p.hands.size() > 1:
		var hw := GlassPane.row()
		hw.add_child(GlassPane.mixed("%s · %s" % [hud.short_weapon(p), String(W.get_data(p.hands[1]["id"]).get("name", ""))], 13.0, 13.0, GlassPane.INK, GlassPane.INK))
		hw.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var swap := GlassPane.key("바꾸기", hud._swap_from_bag)
		swap.size_flags_horizontal = Control.SIZE_SHRINK_END
		swap.custom_minimum_size.x = UiFonts.px(KEY_W)
		hw.add_child(swap)
		side.add_child(hw)
	var worn := VBoxContainer.new()
	worn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	worn.add_theme_constant_override("separation", 0)
	var ids: Dictionary = Wear.worn_ids(p)
	for slot: String in Wear.SLOTS:
		if String(ids[slot]) != "":
			worn.add_child(hud._worn_row(slot, String(ids[slot])))
	if worn.get_child_count() > 0:
		var worn_list := GlassPane.scroll(worn, WORN_MAX)
		worn_list.name = "Worn"
		side.add_child(worn_list)
	else:
		worn.free()
	if p.items.is_empty():
		side.add_child(GlassPane.note("빈 가방", SIDE_W, GlassPane.INK3, 13.0))
	else:
		var list := VBoxContainer.new()
		list.name = "Bag"
		list.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_theme_constant_override("separation", GlassPane.px(GlassPane.GAP))
		var loadable: Array = game.actions.loadable(p)
		for id: String in bag_order(game, p, hud.inv_sort):
			list.add_child(_bag_row(hud, p, id, at["kind"] != "train" or loadable.has(id)))
		side.add_child(GlassPane.scroll(list, LIST_MAX))
	side.add_child(GlassPane.mixed("권총탄 %d · 산탄 %d · 화살 %d" % [int(game.ammo["pistol"]), int(game.ammo["shell"]), int(game.ammo["craft"])]))
	return side


## One kind in the bag: a press moves it to the place chosen at the right
## (as many as move_count); its own job (eat, throw, switch off) on a key
## beside it. Aboard, what stays on the body cannot be pressed.
static func _bag_row(hud, p, id: String, can_move: bool) -> Control:
	var game = hud.game
	var h := GlassPane.row()
	var n: int = int(p.items[id])
	var row: Button = hud._thing_key("%s ×%d" % [game.item_name(id), n], "%.1f" % (Carry.item_weight(id) * n), hud._inv_put.bind(id), game.item_icon(id))
	row.disabled = not can_move
	h.add_child(row)
	var job: Button = null
	if Carry.FieldItems.rings(id):
		job = GlassPane.key("끄기", hud._alarm_off)
	elif Carry.FieldItems.edible(id):
		job = GlassPane.key("먹기", hud._eat.bind(id))
	elif Carry.FieldItems.throwable(id):
		job = GlassPane.key("던지기", hud._throw.bind(id))
	if job != null:
		job.size_flags_horizontal = Control.SIZE_SHRINK_END
		job.custom_minimum_size.x = UiFonts.px(KEY_W)
		h.add_child(job)
	return h


## The right: a key to each place near (the chosen one lit), what is there,
## and the key that moves it all.
static func _near_side(hud, p, at: Dictionary, all: Array) -> Control:
	var game = hud.game
	var side := _side()
	var keys := HFlowContainer.new()
	keys.name = "Places"
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.add_theme_constant_override("h_separation", GlassPane.px(GlassPane.GAP))
	keys.add_theme_constant_override("v_separation", GlassPane.px(GlassPane.GAP))
	for place: Dictionary in all:
		var k := GlassPane.key(String(place["name"]), hud._inv_place.bind(place), "train" if place["kind"] == "train" else "", CHOSEN if place == at else GlassPane.CELL)
		k.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		k.custom_minimum_size.x = UiFonts.px(KEY_W)
		keys.add_child(k)
	side.add_child(keys)
	var list := VBoxContainer.new()
	list.name = "Near"
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_theme_constant_override("separation", GlassPane.px(GlassPane.GAP))
	var empty := ""
	var all_key: LampKey = null
	match String(at["kind"]):
		"box":
			var items: Array = game.data["containers"][at["id"]]["items"]
			for i in items.size():
				var item: String = items[i]
				list.add_child(hud._thing_key(game.item_name(item), "%.1f" % Carry.item_weight(item), hud._loot_take.bind(String(at["id"]), i), game.item_icon(item)))
			empty = "빈 곳"
			if not items.is_empty():
				all_key = LampKey.new("모두 담기", false)
				all_key.pressed.connect(hud._loot_all.bind(String(at["id"])))
		"ground":
			for i: int in game.actions.near_ground(p):
				var g: Dictionary = game.ground_items[i]
				var word: String = game.item_name(String(g["id"])) + (" ×%d" % int(g["n"]) if int(g["n"]) > 1 else "")
				if g.has("garment"):
					word = "%s · 입기" % word
				list.add_child(hud._thing_key(word, "%.1f" % (Carry.item_weight(String(g["id"])) * int(g["n"])), hud._inv_pick.bind(i), game.item_icon(String(g["id"]))))
			empty = "발밑에 아무것도 없다"
		"train":
			for id: String in game.unloaded:
				var line := GlassPane.mixed("%s %d" % [game.item_name(id), int(game.unloaded[id])], 13.0, 13.0, GlassPane.INK2, GlassPane.INK)
				list.add_child(line)
			empty = "이번 정차에 실은 것이 아직 없다"
			if not game.actions.loadable(p).is_empty():
				all_key = LampKey.new("열차에 싣기", false)
				all_key.pressed.connect(hud._load_train)
	if list.get_child_count() == 0:
		list.free()
		side.add_child(GlassPane.note(empty, SIDE_W, GlassPane.INK3, 13.0))
	else:
		side.add_child(GlassPane.scroll(list, LIST_MAX))
	if all_key != null:
		var foot := GlassPane.row()
		foot.alignment = BoxContainer.ALIGNMENT_END
		foot.add_child(all_key)
		side.add_child(foot)
	return side
