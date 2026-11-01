extends RefCounted
## One slim pane at the right edge (decisions 488, 489): the selected place's
## things beside a vertical row of places. The bag remembers where a press
## sends a thing; field_hud.gd keeps the move, time and sound callbacks.

const GlassPane = preload("res://game/ui/glass_pane.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const Carry = preload("res://game/sim/carry.gd")
const W = preload("res://game/sim/weapons.gd")
const Wear = preload("res://game/sim/wear.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")

## Mockup sizes in css; rows keep a little more touch room than the sketch.
const PANE_W: float = 330.0
const HEAD_H: float = 30.0
const TOUCH_MIN: float = 32.0
const ROW_H: float = 34.0
const KEY_H: float = 36.0
const PLACE_H: float = 46.0
const LIST_MAX: float = 190.0
## The places rail shows five keys at most (the bag and four places, 46 css each
## with 4 between — coordinator 10-30, the second check's L13), then it scrolls,
## fading at its foot while more lie below (MORE_H); a short screen cuts it sooner.
const RAIL_MAX: float = PLACE_H * 5.0 + 4.0 * 4.0
const MORE_H: float = 16.0
const ITEM_ICON: float = 15.0
const PIXEL_BASE: float = 32.0
const FOOT_GAP: float = 8.0
const FULL_GAP: float = 0.05
const NAMES: Dictionary = {
	"wardrobe": "장롱", "dresser": "서랍장", "side_table": "협탁",
	"nightstand": "협탁", "bookcase": "책장", "blanket_chest": "담요 궤",
	"cupboard": "찬장", "medicine_cabinet": "약장", "office_cabinet": "서류함",
	"closet": "옷장", "locker": "옷장",
	"glass_cabinet": "유리장", "file_cabinet": "서류함", "map_cabinet": "지도함",
	"crate_stack": "궤", "tin_crate": "궤", "part_crate": "부품함",
	"ammo_crate": "탄약함", "relief_crate": "구호함", "blanket_crate": "담요 궤",
	"parish_chest": "궤", "vestry_chest": "궤", "medicine_crate": "약상자",
	"shelf": "선반", "small_shelf": "선반", "display_shelf": "진열대",
	"jar_shelf": "선반", "towel_shelf": "선반", "record_shelf_row": "책장",
	"hymn_shelf": "책장", "lamp_shelf": "선반", "evidence_shelf": "증거함",
	"desk": "책상", "office_desk": "책상", "typewriter_desk": "책상",
	"counter": "계산대", "shop_counter": "계산대", "service_counter": "계산대",
	"checkout": "계산대", "workbench": "작업대", "tool_bench": "작업대",
	"toolbox": "공구함", "tool_chest": "공구함", "strongbox": "금고",
	"hardware_rack": "선반", "parts_rack": "선반", "bread_rack": "빵 선반",
	"fridge_open": "냉장고", "freezer_chest": "냉동고", "washstand": "세면대",
	"waste_bin": "쓰레기통", "drawer_chest_spilled": "서랍장",
}


## The places near the player, the train's hold first.
static func places(game, p) -> Array:
	var out: Array = []
	if game.actions.at_unloading(p):
		out.append({"kind": "train", "id": "", "name": "열차 짐칸"})
	for id: String in game.actions.near_boxes(p):
		out.append({"kind": "box", "id": id, "name": String(game.data["containers"][id]["name"])})
	out.append({"kind": "ground", "id": "", "name": "바닥"})
	return out


## A place as one word ("box:cache_36"), to see what a walk brought near or left.
static func place_key(place: Dictionary) -> String:
	return "%s:%s" % [place.get("kind", ""), place.get("id", "")]


static func place_keys(all: Array) -> Array:
	return all.map(func(place: Dictionary) -> String: return place_key(place))


## The place asked for if it is still near, else the first.
static func chosen(all: Array, want: Dictionary) -> Dictionary:
	for place: Dictionary in all:
		if place["kind"] == want.get("kind", "") and place["id"] == want.get("id", ""):
			return place
	return all[0]


## The bag's rows in the order shown: heaviest first, or by name; rows alike
## keep the order they came into the bag in.
static func bag_order(game, p, by: String) -> Array:
	var ids: Array = p.items.keys()
	var first: Array = ids.duplicate()
	if by == "name":
		ids.sort_custom(func(a, b) -> bool: return _steady(game.item_name(a), game.item_name(b), first.find(a), first.find(b)))
	else:
		ids.sort_custom(func(a, b) -> bool: return _steady(-Carry.item_weight(a) * int(p.items[a]), -Carry.item_weight(b) * int(p.items[b]), first.find(a), first.find(b)))
	return ids


## The places in the order they were shown (`shown`, place keys): the train's
## hold first and the floor last as ever, a box come near after those there.
static func keep_order(all: Array, shown: Array) -> Array:
	var rank := func(i: int) -> int:
		var place: Dictionary = all[i]
		if place["kind"] != "box":
			return -1 if place["kind"] == "train" else all.size() + shown.size()
		var at: int = shown.find(place_key(place))
		return at if at >= 0 else shown.size() + i
	var order: Array = range(all.size())
	order.sort_custom(func(a: int, b: int) -> bool: return rank.call(a) < rank.call(b))
	return order.map(func(i: int) -> Dictionary: return all[i])


static func open(hud, want: Dictionary) -> void:
	var game = hud.game
	var p = game.player
	var all: Array = places(game, p)
	# Laid again over itself (a walk, a row taken): the places keep their order.
	if hud.modal != null and hud.modal == hud.box_pane:
		all = keep_order(all, hud.bag_places)
	var at: Dictionary = chosen(all, want)
	hud.inv_near = at
	hud.bag_places = place_keys(all)
	hud.take_bar = null
	var bag: bool = hud.inv_view == "bag"
	var title: String = String(Carry.BAGS[p.bag]["name"]) if bag else _place_name(game, at)
	var side: String = "%.1f / %.0f · %s" % [p.weight(), p.carry_limit(), Carry.STATE_NAMES[p.carry_state()]] if bag else ""
	if not bag and at["kind"] == "box":
		var c: Dictionary = game.data["containers"][at["id"]]
		side = "담긴 %.1f / %.0f" % [Carry.box_load(c), Carry.box_limit(c)]
	var pane: GlassPane = hud._open_pane(title, side, "pack" if bag else _place_icon(at), PANE_W, true, true)
	_slim_head(pane, hud, title, side, "pack" if bag else _place_icon(at))
	var layout := GlassPane.row()
	layout.add_theme_constant_override("separation", GlassPane.px(10.0))
	pane.body.add_child(layout)
	var main := _column()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(main)
	main.add_child(_tools(hud, p, at, bag))
	if not bag and at["kind"] == "box":
		main.add_child(_box_load(hud, game.data["containers"][at["id"]]))
	var rows: Control = _bag_rows(hud, p, at) if bag else _near_rows(hud, p, at)
	main.add_child(GlassPane.scroll(rows, LIST_MAX))
	if bag:
		main.add_child(_label("권총탄 %d · 산탄 %d · 화살 %d" % [int(game.ammo["pistol"]), int(game.ammo["shell"]), int(game.ammo["craft"])], 11.0))
	main.add_child(_foot(hud, p, at, bag))
	var place_col: Control = _places(hud, all, at, bag)
	var rail := GlassPane.scroll(place_col, RAIL_MAX)
	rail.name = "PlaceScroll"
	rail.custom_minimum_size.x = UiFonts.px(PLACE_H)
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_rail_with_more(rail))
	# A lambda, not _fit_screen.bind(): bound callables of one function compare
	# equal whatever they bind, so a pane laid over the last would clash with it.
	# It holds the pane weakly: a deferred fit may land after the pane is freed.
	var pane_ref: WeakRef = weakref(pane)
	var main_ref: WeakRef = weakref(main)
	var rail_ref: WeakRef = weakref(rail)
	var fit: Callable = func() -> void:
		var shown: Control = pane_ref.get_ref() as Control
		var col: Control = main_ref.get_ref() as Control
		var strip: ScrollContainer = rail_ref.get_ref() as ScrollContainer
		if shown != null and col != null and strip != null:
			_fit_screen(shown, col, strip)
	var goals: String = game.goal_text() if game.mission_play != null else ""
	if goals != "":
		var journal: Control = hud._journal_note(goals)
		var entries: Node = journal.get_child(0)
		for entry: Node in entries.get_children():
			if entry is Label:
				(entry as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				(entry as Label).text = UiFonts.keep_all((entry as Label).text)
		journal.minimum_size_changed.connect(fit, CONNECT_DEFERRED)
		pane.body.add_child(journal)
	rows.minimum_size_changed.connect(fit, CONNECT_DEFERRED)
	place_col.minimum_size_changed.connect(fit, CONNECT_DEFERRED)
	var screen: Viewport = pane.get_viewport()
	screen.size_changed.connect(fit)
	pane.tree_exiting.connect(func() -> void:
		if screen.size_changed.is_connected(fit):
			screen.size_changed.disconnect(fit))
	_fit_screen(pane, main, rail)
	fit.call_deferred()
	hud.run_while_taking()
	hud.box_pane = hud.modal
	hud.box_shown_now(String(at.get("id", "")) if not bag and String(at.get("kind", "")) == "box" else "")
	hud.dim_under_bag()


## The places rail in a holder whose foot fades while more places lie below
## (scrolled to the end, or all of them showing, it does not).
static func _rail_with_more(rail: ScrollContainer) -> Control:
	var holder := MarginContainer.new()
	holder.name = "PlaceRail"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(rail)
	var ramp := Gradient.new()
	var under: Color = GlassPane.BACKING[0][1]
	ramp.set_color(0, Color(under, 0.0))
	ramp.set_color(1, Color(under, 0.92))
	var shade := GradientTexture2D.new()
	shade.gradient = ramp
	shade.fill_from = Vector2(0.5, 0.0)
	shade.fill_to = Vector2(0.5, 1.0)
	shade.width = 4
	shade.height = 32
	var more := TextureRect.new()
	more.name = "PlaceMore"
	more.texture = shade
	more.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	more.stretch_mode = TextureRect.STRETCH_SCALE
	more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	more.custom_minimum_size.y = UiFonts.px(MORE_H)
	more.size_flags_vertical = Control.SIZE_SHRINK_END
	more.visible = false
	holder.add_child(more)
	# Weakly held, as the fit: a range change may come after the pane is freed.
	var rail_ref: WeakRef = weakref(rail)
	var more_ref: WeakRef = weakref(more)
	var show_more := func(_value: float = 0.0) -> void:
		var strip := rail_ref.get_ref() as ScrollContainer
		var mark := more_ref.get_ref() as Control
		if strip != null and mark != null:
			var bar: VScrollBar = strip.get_v_scroll_bar()
			mark.visible = bar.max_value - bar.page > bar.value + 1.0
	rail.get_v_scroll_bar().changed.connect(show_more)
	rail.get_v_scroll_bar().value_changed.connect(show_more)
	return holder


## The sketch's 30-high head; the fold touch extends one css above and below.
static func _slim_head(pane: GlassPane, hud, title: String, side: String, icon: String) -> void:
	var margin: MarginContainer = pane.get_node("Rows")
	margin.add_theme_constant_override("margin_right", 0)
	pane.body.add_theme_constant_override("separation", GlassPane.px(6.0))
	var old: Control = pane.find_child("Head", true, false)
	var parent: Node = old.get_parent()
	parent.remove_child(old)
	old.free()
	var head := Control.new()
	head.name = "Head"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.custom_minimum_size.y = UiFonts.px(HEAD_H)
	parent.add_child(head)
	parent.move_child(head, 0)
	var line := GlassPane.row()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_right = -UiFonts.px(KEY_H)
	line.add_child(GlassPane.mark(icon, 20.0, GlassPane.INK2))
	pane.title_label = _label(title, 15.0, GlassPane.INK)
	pane.title_label.name = "Title"
	UiFonts.style(pane.title_label, UiFonts.WORD, 500, 15.0, GlassPane.INK, 1.2)
	pane.title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(pane.title_label)
	if side != "":
		var sub := _label(side, 12.0, GlassPane.INK2)
		sub.name = "Side"
		sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(sub)
	head.add_child(line)
	var fold := _icon_key("back", "", hud._close_modal)
	fold.name = "Fold"
	fold.tooltip_text = "접기"
	fold.custom_minimum_size = Vector2.ONE * UiFonts.px(TOUCH_MIN)
	head.add_child(fold)
	fold.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fold.offset_left = -UiFonts.px(TOUCH_MIN)
	fold.offset_top = -UiFonts.px(1.0)
	fold.offset_bottom = UiFonts.px(HEAD_H + 1.0)


## The pane stays inside the screen: the item scroll gives up height first, then
## the places rail (down to one place); each shows all it holds while it fits.
static func _fit_screen(pane: Control, main: Control, rail: ScrollContainer) -> void:
	if not is_instance_valid(pane) or not pane.is_inside_tree():
		return
	for child: Node in main.get_children():
		if child is ScrollContainer:
			var scroll := child as ScrollContainer
			var rows := scroll.get_child(0) as Control
			scroll.custom_minimum_size.y = minf(rows.get_combined_minimum_size().y, UiFonts.px(LIST_MAX))
	rail.custom_minimum_size.y = minf((rail.get_child(0) as Control).get_combined_minimum_size().y, UiFonts.px(RAIL_MAX))
	var layout := main.get_parent() as Control
	var room: float = pane.get_viewport_rect().size.y - pane.position.y - UiFonts.px(FOOT_GAP)
	var fits: float = room - (pane.get_combined_minimum_size().y - layout.get_combined_minimum_size().y)
	var over: float = main.get_combined_minimum_size().y - fits
	for child: Node in main.get_children():
		if child is ScrollContainer and over > 0.0:
			var scroll := child as ScrollContainer
			scroll.custom_minimum_size.y = maxf(UiFonts.px(ROW_H), scroll.custom_minimum_size.y - over)
	rail.custom_minimum_size.y = maxf(UiFonts.px(PLACE_H), minf(rail.custom_minimum_size.y, fits))
	pane.size = pane.get_combined_minimum_size()
	pane.position.x = pane.get_viewport_rect().size.x - pane.size.x


static func _column(gap: float = 6.0) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", GlassPane.px(gap))
	return col


static func _label(word: String, css: float, ink: Color = GlassPane.INK2) -> Label:
	var label := UiFonts.label(word, UiFonts.WORD, 500, css, ink, 0.2)
	label.clip_text = true
	label.tooltip_text = word
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


static func _place_name(game, place: Dictionary, short: bool = false) -> String:
	if place["kind"] != "box":
		return "열차" if short and place["kind"] == "train" else String(place["name"])
	var c: Dictionary = game.data["containers"][place["id"]]
	var fallback: String = String(c["name"])
	return String(NAMES.get(String(c.get("furniture", "")), fallback.left(4) if short else fallback))


static func _place_icon(place: Dictionary) -> String:
	return "train" if place["kind"] == "train" else ("fetch" if place["kind"] == "box" else "drop")


## With the bag shown, the place a pressed row goes to keeps an amber edge.
static func _places(hud, all: Array, at: Dictionary, bag: bool) -> Control:
	var col := _column(4.0)
	col.name = "Places"
	col.add_child(_place_key(hud, "pack", "가방", bag, false, hud._inv_bag, {"kind": "bag", "id": ""}))
	for place: Dictionary in all:
		var empty: bool = place["kind"] == "box" and SearchRules.shows_empty(hud.game.data["containers"][place["id"]])
		col.add_child(_place_key(hud, _place_icon(place), _place_name(hud.game, place, true), not bag and place == at, empty, hud._inv_place.bind(place), place, bag and place == at))
	return col


static func _place_key(hud, icon: String, word: String, on: bool, empty: bool, cb: Callable, place: Dictionary, aim: bool = false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2.ONE * UiFonts.px(PLACE_H)
	b.text = word + ("·빈" if empty else "")
	b.clip_text = true
	b.tooltip_text = b.text
	b.set_meta("place_kind", place["kind"])
	b.set_meta("place_id", place["id"])
	b.set_meta("selected", on)
	b.set_meta("aim", aim)
	var sb := GlassPane._box(GlassPane.AMBER * Color(1, 1, 1, 0.26) if on else GlassPane.CELL, GlassPane.AMBER if on or aim else GlassPane.HAIR, 0.0)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, sb)
	_hide_text(b)
	var col := _column(1.0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var ink: Color = GlassPane.INK3 if empty else (GlassPane.AMBER_L if on else GlassPane.INK2)
	var mark: TextureRect = hud._icon_rect(icon, UiFonts.size(20.0), ink)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(mark)
	var label := _label(word, 10.0, ink)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if empty:
		var words := _column_word(label, ink)
		col.add_child(words)
	else:
		col.add_child(label)
	b.add_child(col)
	b.pressed.connect(cb)
	return b


## Keep the empty suffix visible even when a four-letter fallback is clipped: the
## name and the mark sit together in the middle of the key, inside its edge (the
## rail stands at the screen's edge), the name giving up its last letters first.
static func _column_word(label: Label, ink: Color) -> Control:
	var row := GlassPane.row()
	row.add_theme_constant_override("separation", 0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var suffix := _label("·빈", 10.0, ink)
	suffix.clip_text = false
	var font: Font = UiFonts.face(UiFonts.WORD, 500, 0.2)
	var px: int = UiFonts.size(10.0)
	var room: float = UiFonts.px(PLACE_H - 2.0) - font.get_string_size("·빈", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.custom_minimum_size.x = minf(ceilf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x), maxf(room, 0.0))
	row.add_child(label)
	row.add_child(suffix)
	return row


static func _icon_key(icon: String, word: String, cb: Callable, lit: bool = false) -> Button:
	var b := GlassPane.key(word, cb, icon, GlassPane.AMBER * Color(1, 1, 1, 0.28) if lit else GlassPane.CELL)
	b.custom_minimum_size = Vector2.ONE * UiFonts.px(KEY_H)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiFonts.style(b, UiFonts.WORD, 500, 11.0, GlassPane.INK, 0.2)
	return b


## Find the work's box even while the bag or another place is being viewed.
static func taking_id(game, p) -> String:
	if p.action == "take":
		for id: String in game.data["containers"]:
			if is_same(p.action_busy, game.data["containers"][id]):
				return id
	return ""


## By the train the bag tab keeps the hold's 열차에 싣기 key too (decision 448-13).
static func _tools(hud, p, at: Dictionary, bag: bool) -> Control:
	var row := GlassPane.row()
	row.add_child(_icon_key("scale", "이름순" if hud.inv_sort == "name" else "무게순", hud._inv_sort))
	var spring := Control.new()
	spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spring)
	var taking: String = taking_id(hud.game, p)
	if taking != "":
		row.add_child(_icon_key("pause", "멈추기", hud._loot_stop.bind(taking), true))
		return row
	if bag and p.hands.size() > 1:
		row.add_child(_icon_key("gun", "바꾸기", hud._swap_from_bag))
	elif not bag and at["kind"] == "box":
		if not (hud.game.data["containers"][at["id"]]["items"] as Array).is_empty():
			row.add_child(_icon_key("pickup", "모두 담기", hud._loot_all.bind(String(at["id"])), true))
	if at["kind"] == "train" and not hud.game.actions.loadable(p).is_empty():
		row.add_child(_icon_key("train", "열차에 싣기", hud._load_train, true))
	return row


## Weapons, folded clothing and the bag share one item scroll (the rounds stay
## under it); taking from a box leaves all of these at hand, as before.
static func _bag_rows(hud, p, at: Dictionary) -> Control:
	var game = hud.game
	var col := _column()
	var weapons: String = hud.short_weapon(p)
	if p.hands.size() > 1:
		weapons += " · " + String(W.get_data(p.hands[1]["id"]).get("name", ""))
	col.add_child(_label(weapons, 12.0, GlassPane.INK))
	var worn := _column(0.0)
	worn.name = "Worn"
	var ids: Dictionary = Wear.worn_ids(p)
	var names: PackedStringArray = []
	for slot: String in Wear.SLOTS:
		if String(ids[slot]) != "":
			names.append(game.item_name(String(ids[slot])))
			worn.add_child(hud._worn_row(slot, String(ids[slot])))
	var fold := GlassPane.key("입은 옷 %d%s" % [names.size(), " · " + " · ".join(names) if not names.is_empty() else ""], hud._inv_worn)
	fold.name = "WornFold"
	fold.custom_minimum_size.y = UiFonts.px(ROW_H)
	fold.clip_text = true
	fold.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiFonts.style(fold, UiFonts.WORD, 500, 12.0, GlassPane.INK2, 0.2)
	col.add_child(fold)
	worn.visible = hud.inv_worn_open and not names.is_empty()
	col.add_child(worn)
	var list := _column(0.0)
	list.name = "Bag"
	var loadable: Array = game.actions.loadable(p)
	var box: Dictionary = game.data["containers"][at["id"]] if at["kind"] == "box" else {}
	for id: String in bag_order(game, p, hud.inv_sort):
		var can_move: bool = loadable.has(id) if at["kind"] == "train" else (box.is_empty() or Carry.box_room(box, id) > 0)
		list.add_child(_bag_row(hud, p, id, can_move))
	if list.get_child_count() == 0:
		list.add_child(_label("빈 가방", 12.0, GlassPane.INK3))
	col.add_child(list)
	return col


static func _bag_row(hud, p, id: String, can_move: bool) -> Control:
	var row := GlassPane.row()
	row.add_theme_constant_override("separation", GlassPane.px(4.0))
	var n: int = int(p.items[id])
	row.add_child(_thin_row(hud, id, "%s ×%d" % [hud.game.item_name(id), n], Carry.item_weight(id) * n, hud._inv_put.bind(id), not can_move))
	var job: Button = null
	if Carry.FieldItems.rings(id):
		job = _icon_key("pause", "", hud._alarm_off)
		job.tooltip_text = "끄기"
	elif Carry.FieldItems.edible(id):
		job = _icon_key("ration", "", hud._eat.bind(id))
		job.tooltip_text = "먹기"
	elif Carry.FieldItems.throwable(id):
		job = _icon_key("arrow", "", hud._throw.bind(id))
		job.tooltip_text = "던지기"
	if job != null:
		job.custom_minimum_size = Vector2.ONE * UiFonts.px(ROW_H)
		row.add_child(job)
	return row


static func _box_load(hud, c: Dictionary) -> Control:
	var col := _column(4.0)
	col.name = "BoxLoad"
	var held: float = Carry.box_load(c)
	var cap: float = Carry.box_limit(c)
	col.add_child(_label("담긴 무게 %.1f / %.0f" % [held, cap], 11.0))
	var bar: ProgressBar = hud._bar(GlassPane.RED_L if held >= cap - FULL_GAP else GlassPane.AMBER)
	bar.custom_minimum_size = Vector2(0, GlassPane.px(4.0))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = cap
	bar.value = minf(held, cap)
	col.add_child(bar)
	return col


## Sorting changes display indices only; callbacks keep the source indices. While
## a thing comes out of this box its rows wait, as before; other places stay open.
static func _near_rows(hud, p, at: Dictionary) -> Control:
	var game = hud.game
	var list := _column(0.0)
	list.name = "Near"
	var empty: String = ""
	match String(at["kind"]):
		"box":
			var c: Dictionary = game.data["containers"][at["id"]]
			var items: Array = c["items"]
			var indices: Array = range(items.size())
			indices.sort_custom(func(a: int, b: int) -> bool:
				return _steady(_order_key(hud, String(items[a]), 1), _order_key(hud, String(items[b]), 1), a, b))
			var now: String = game.actions.taking_item(p) if is_same(p.action_busy, c) else ""
			var barred: bool = false
			for i: int in indices:
				var id: String = String(items[i])
				var row := _thin_row(hud, id, game.item_name(id), Carry.item_weight(id), hud._loot_take.bind(String(at["id"]), i), now != "")
				if id == now and not barred:
					barred = true
					row.add_child(_take_bar(hud, p))
				list.add_child(row)
			empty = "빈 곳"
		"ground":
			var indices: Array = game.actions.near_ground(p)
			indices.sort_custom(func(a: int, b: int) -> bool:
				var left: Dictionary = game.ground_items[a]
				var right: Dictionary = game.ground_items[b]
				return _steady(_order_key(hud, String(left["id"]), int(left["n"])), _order_key(hud, String(right["id"]), int(right["n"])), a, b))
			for i: int in indices:
				var g: Dictionary = game.ground_items[i]
				var id: String = String(g["id"])
				var word: String = game.item_name(id) + (" ×%d" % int(g["n"]) if int(g["n"]) > 1 else "")
				if g.has("garment"):
					word += " · 입기"
				list.add_child(_thin_row(hud, id, word, Carry.item_weight(id) * int(g["n"]), hud._inv_pick.bind(i)))
			empty = "발밑에 아무것도 없다"
		"train":
			var keys: Array = game.unloaded.keys()
			var ids: Array = keys.duplicate()
			ids.sort_custom(func(a, b) -> bool:
				return _steady(_order_key(hud, String(a), int(game.unloaded[a])), _order_key(hud, String(b), int(game.unloaded[b])), keys.find(a), keys.find(b)))
			for id: String in ids:
				var n: int = int(game.unloaded[id])
				list.add_child(_thin_row(hud, id, "%s ×%d" % [game.item_name(id), n], Carry.item_weight(id) * n, Callable(), true))
			empty = "이번 정차에 실은 것이 아직 없다"
	if list.get_child_count() == 0:
		list.add_child(_label(empty, 12.0, GlassPane.INK3))
	return list


## What a row sorts by: its name, or the heavier first (a negative weight).
static func _order_key(hud, id: String, n: int) -> Variant:
	if hud.inv_sort == "name":
		return hud.game.item_name(id)
	return -Carry.item_weight(id) * n


## A steady order: rows with equal keys keep their place between refreshes.
static func _steady(x: Variant, y: Variant, a: int, b: int) -> bool:
	return x < y if x != y else a < b


static func _foot(hud, p, at: Dictionary, bag: bool) -> Label:
	var word: String = "누르면 가방으로"
	var seconds: float = 0.0
	if bag:
		word = UiFonts.josa("누르면 %s(으)로 · 가방 %.1f / %.0f" % [_place_name(hud.game, at), p.weight(), p.carry_limit()])
	elif at["kind"] == "train":
		word = "열차에 실은 것"
	elif at["kind"] == "box":
		seconds = hud.game.actions.take_all_seconds(hud.game.data["containers"][at["id"]])
		if seconds > 0.0:
			word += " · 다 챙기면 %.1f초" % seconds
	var label := _label(word, 11.0, GlassPane.INK3)
	label.name = "TakeAll" if seconds > 0.0 else "MoveHint"
	return label


## Text stays on the button for accessibility; the row's labels draw it once.
static func _hide_text(b: Button) -> void:
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(state, Color.TRANSPARENT)


static func _thin_row(hud, id: String, word: String, weight: float, cb: Callable, dim: bool = false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiFonts.px(ROW_H))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = word
	b.clip_text = true
	b.tooltip_text = word
	b.disabled = dim
	b.set_meta("item_id", id)
	UiFonts.style(b, UiFonts.WORD, 500, 12.0, GlassPane.INK, 0.2)
	_hide_text(b)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.border_width_bottom = GlassPane.px(1.0)
	sb.border_color = GlassPane.HAIR
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, sb)
	var row := GlassPane.row()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = UiFonts.px(4.0)
	row.offset_right = -UiFonts.px(4.0)
	row.add_theme_constant_override("separation", GlassPane.px(8.0))
	row.add_child(_item_icon(hud, id))
	var label := _label(word, 12.0, GlassPane.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var kg := UiFonts.label("%.1f" % weight, UiFonts.NUMBER, 500, 13.0, GlassPane.INK2)
	kg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(kg)
	if dim:
		row.modulate = GlassPane.INK3
	b.add_child(row)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## Optional 32-pixel art uses whole multiples in screen pixels, not canvas units.
static func _item_icon(hud, id: String) -> Control:
	var texture: Texture2D = hud.item_px_override.get(id) as Texture2D
	var path: String = "res://assets/icons/items/%s.png" % id
	if texture == null and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture == null:
		var line: TextureRect = hud._icon_rect(hud.game.item_icon(id), UiFonts.size(ITEM_ICON), GlassPane.INK2)
		line.name = "ItemIcon"
		return line
	var art := TextureRect.new()
	art.name = "ItemIcon"
	art.texture = texture
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot := Control.new()
	slot.name = "ItemSlot"
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(art)
	# A lambda for the same reason as the pane's fit: many icons share one screen.
	var fit: Callable = func() -> void:
		if is_instance_valid(art) and is_instance_valid(slot):
			_fit_item_icon(art, slot)
	slot.resized.connect(fit)
	art.ready.connect(func() -> void:
		fit.call()
		art.get_viewport().size_changed.connect(fit))
	art.tree_exiting.connect(func() -> void:
		var screen: Viewport = art.get_viewport()
		if screen.size_changed.is_connected(fit):
			screen.size_changed.disconnect(fit))
	return slot


## From the art's canvas to the device's pixels: the window's stretch times the
## canvas (get_screen_transform leaves the stretch out while windows are embedded).
static func _to_pixels(item: CanvasItem) -> Transform2D:
	return item.get_viewport().get_final_transform() * item.get_global_transform_with_canvas()


## The art's side in device pixels: the whole multiple of 32 nearest the line
## icon's size that fits `room` pixels, or 0 when not even one does.
static func whole_pixels(target: float, room: float) -> float:
	var times: float = maxf(1.0, roundf(target / PIXEL_BASE))
	while times > 1.0 and PIXEL_BASE * times > room:
		times -= 1.0
	return PIXEL_BASE * times if PIXEL_BASE * times <= room else 0.0


static func _fit_item_icon(art: TextureRect, slot: Control) -> void:
	if not art.is_inside_tree():
		return
	var scale: Vector2 = _to_pixels(art).get_scale().abs()
	var s: float = maxf(minf(scale.x, scale.y), 0.001)
	var pixels: float = whole_pixels(UiFonts.px(ITEM_ICON) * s, UiFonts.px(ROW_H - 2.0) * s)
	# A window too small for one whole multiple draws the line icon's size instead.
	art.size = Vector2.ONE * (pixels / s if pixels > 0.0 else UiFonts.px(ITEM_ICON))
	# Containers round their children; a free child keeps the exact size.
	slot.custom_minimum_size = art.size.ceil()
	art.position = (slot.size - art.size) * 0.5
	if pixels > 0.0:
		var origin: Vector2 = _to_pixels(art).origin
		art.position += (origin.round() - origin) / s


## The thin bar along the foot of the row coming out; the HUD fills it each frame.
static func _take_bar(hud, p) -> ProgressBar:
	var bar: ProgressBar = hud._bar(GlassPane.AMBER)
	bar.name = "TakeBar"
	bar.custom_minimum_size = Vector2.ZERO
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -GlassPane.px(4.0)
	bar.max_value = 1.0
	bar.value = 1.0 - p.action_t / maxf(p.action_total, 0.001)
	hud.take_bar = bar
	return bar
