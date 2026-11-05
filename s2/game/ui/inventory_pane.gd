extends RefCounted
## The bag pane at the right edge (결정 558): the bag and the selected place side
## by side, each a column of rows 52 css high (48 dp), beside a rail of places with
## the pane's main key at its foot. A press on a row moves it across at once; a long
## press (LONG_S) opens it under itself with what it can do; the two works that
## cannot be undone, throwing a can and loading all on the train, are held to
## confirm (hold_confirm.gd, 결정 559). Bars are one colour; the bag's weight alone
## climbs a scale of danger (결정 560). field_hud.gd keeps the move, time and sound
## callbacks.

const GlassPane = preload("res://game/ui/glass_pane.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const HoldConfirm = preload("res://game/ui/hold_confirm.gd")
const Carry = preload("res://game/sim/carry.gd")
const Sled = preload("res://game/sim/sled.gd")
const W = preload("res://game/sim/weapons.gd")
const Wear = preload("res://game/sim/wear.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")

## The mockup's sizes in css (시안 「나」 고친 판): two columns of 200, the rail of 52.
const COL_W: float = 200.0
const COL_GAP: float = 8.0
const RAIL_GAP: float = 10.0
const EDGE_L: float = 16.0
const FOLD_EDGE_L: float = 12.0
const FOLD_W: float = 52.0
const FOLD_LINGER_S: float = 1.0
const EDGE_R: float = 2.0
const EDGE_T: float = 4.0
const EDGE_B: float = 6.0
const PANE_W: float = EDGE_L + COL_W + COL_GAP + COL_W + RAIL_GAP + 52.0 + EDGE_R
## Every press is 52 css = 48 dp: rows, the weapons, the places, the keys.
const KEY: float = 52.0
const TOUCH_MIN: float = KEY
const ROW_H: float = KEY
const ROW_GAP: float = 2.0
const GAP: float = 6.0
const PLACE_H: float = KEY
const MAIN_H: float = 64.0
## A row's picture: the coloured art in 44, a line icon in 26 inside it.
const ART: float = 44.0
const ITEM_ICON: float = 26.0
const BAR_H: float = 4.0 * 390.0 / 360.0
const HEAD_ICON: float = 20.0
## The bag's own mark, in its column's head and on the folded strip: 1.3 times
## the heads' (결정 561 ③).
const BAG_ICON: float = 26.0
## A key or row pressed sinks this far and its rim lights (결정 561 ④).
const PRESS_SINK: float = 1.5
## A one-press key's buzz on the way down, very short (결정 561 ④, the system
## key-click's length); the hold keys have their own at the full hold.
const TAP_BUZZ_MS: int = 10
## Painted art (결정 550·561 ①: the baked 3D pictures, 256 px) is at least this
## wide: drawn smooth from its mipmaps at ART, not snapped like pixel art.
const PAINTED_MIN_PX: int = 128
## Things that share another's picture (the same model would be baked twice).
const ART_ALIAS: Dictionary = {
	"rusk": "hardtack", "can_dented_bad": "can_dented", "peas": "oats", "flour": "oats",
	"jar_cabbage": "jar_jam", "jar_honey": "jar_jam", "fever_pills": "painkillers",
	"junk_rag": "cloth", "info_timetable": "document", "info_telegraph": "document",
}
## The places rail shows five keys at most, then scrolls, fading at its foot while
## more lie below (MORE_H); a short screen cuts it sooner.
const RAIL_MAX: float = PLACE_H * 5.0 + 4.0 * 4.0
const MORE_H: float = 16.0
const PIXEL_BASE: float = 32.0
const FOOT_GAP: float = 8.0
const FULL_GAP: float = 0.05
## A row held this long opens under itself; moved this far first, it is a drag.
const LONG_S: float = 0.4
const DRAG_CSS: float = 8.0
## 결정 560: the bars' one colour, and the bag's weight's scale (carry.gd states:
## up to half, past half, over — the field HUD's bag key climbs the same).
const BONE := Color("d8d2c4")
const TRACK := Color(216 / 255.0, 210 / 255.0, 196 / 255.0, 0.14)
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
	for sled_id: int in game.actions.near_sleds(p):
		out.append({"kind": "sled", "id": sled_id, "name": "썰매"})
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
		if place["kind"] not in ["box", "sled"]:
			return -1 if place["kind"] == "train" else all.size() + shown.size()
		var at: int = shown.find(place_key(place))
		return at if at >= 0 else shown.size() + i
	var order: Array = range(all.size())
	order.sort_custom(func(a: int, b: int) -> bool: return rank.call(a) < rank.call(b))
	return order.map(func(i: int) -> Dictionary: return all[i])


## The colour of a weight on the carry scale (carry.gd state): the bar's own
## bone up to half, amber past half, the bad colour once it spills (결정 560).
static func carry_bar(state: int) -> Color:
	return [BONE, GlassPane.AMBER, GlassPane.RED_L][clampi(state, 0, 2)]


## The weight's number on the same scale (the ink up to half).
static func carry_ink(state: int) -> Color:
	return [GlassPane.INK, GlassPane.AMBER, GlassPane.RED_L][clampi(state, 0, 2)]


static func open(hud, want: Dictionary) -> void:
	var game = hud.game
	var p = game.player
	# A pane opened afresh (the bag key, a box, a sled) names its weapons only and
	# opens no row.
	var again: bool = hud.modal != null and hud.modal == hud.box_pane
	if not again:
		hud.inv_weapon_open = -1
		hud.inv_weapon_open_id = ""
		hud.inv_expand = {}
		hud.inv_fold_until_ms = 0
		hud.inv_fold_taking = false
		hud.inv_fold_open = false
		hud.inv_bag_scroll = 0
		hud.inv_scroll_pending = {}
	var taking: bool = taking_id(game, p) != ""
	var now_ms: int = Time.get_ticks_msec()
	if taking:
		hud.inv_fold_taking = true
	elif hud.inv_fold_taking:
		# The last thing is out: the fold stays FOLD_LINGER_S from this moment on.
		hud.inv_fold_taking = false
		hud.inv_fold_until_ms = now_ms + int(FOLD_LINGER_S * 1000.0)
	if not taking and now_ms >= hud.inv_fold_until_ms:
		hud.inv_fold_open = false
	var folded: bool = not hud.inv_fold_open and (taking or now_ms < hud.inv_fold_until_ms)
	var kept: Dictionary = hud._bag_scrolls() if again else {}
	var all: Array = places(game, p)
	# Laid again over itself (a row taken): the places keep their order.
	if again:
		all = keep_order(all, hud.bag_places)
	var at: Dictionary = chosen(all, want)
	hud.inv_near = at
	hud.bag_places = place_keys(all)
	hud.take_bar = null
	var pane: GlassPane = hud._open_pane(_place_name(game, at), "", _place_icon(at), pane_px(folded) / UiFonts.px(1.0), true, true)
	_bare(pane, folded)
	var layout := GlassPane.row()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 0)
	pane.body.add_child(layout)
	if folded:
		layout.add_child(_bag_strip(hud, p))
	else:
		layout.add_child(_bag_side(hud, p, at))
		layout.add_child(_gap(COL_GAP))
	var place_side: VBoxContainer = _place_side(hud, p, at)
	layout.add_child(place_side)
	layout.add_child(_gap(RAIL_GAP))
	var rail_side: VBoxContainer = _rail_side(hud, p, all, at)
	layout.add_child(rail_side)
	pane.title_label = place_side.find_child("Title", true, false) as Label
	# A lambda, not _fit_screen.bind(): bound callables of one function compare
	# equal whatever they bind, so a pane laid over the last would clash with it.
	# It holds the pane weakly: a deferred fit may land after the pane is freed.
	var pane_ref: WeakRef = weakref(pane)
	var layout_ref: WeakRef = weakref(layout)
	var fit: Callable = func() -> void:
		var shown: GlassPane = pane_ref.get_ref() as GlassPane
		var row: Control = layout_ref.get_ref() as Control
		if shown != null and row != null:
			_fit_screen(shown, row)
	var goals: String = game.goal_text() if game.mission_play != null else ""
	if goals != "":
		var journal: Control = hud._journal_note(goals)
		var entries: Node = journal.get_child(0)
		for entry: Node in entries.get_children():
			if entry is Label:
				(entry as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				(entry as Label).text = UiFonts.keep_all((entry as Label).text)
		journal.minimum_size_changed.connect(fit, CONNECT_DEFERRED)
		journal.custom_minimum_size.x = 0.0
		journal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var journal_scroll := ScrollContainer.new()
		journal_scroll.name = "JournalScroll"
		journal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		journal_scroll.add_child(journal)
		pane.body.add_child(journal_scroll)
	for list_name: String in ["Bag", "Near", "Places"]:
		var list: Control = layout.find_child(list_name, true, false) as Control
		if list != null:
			list.minimum_size_changed.connect(fit, CONNECT_DEFERRED)
	pane.motion_finished.connect(fit)
	var screen: Viewport = pane.get_viewport()
	screen.size_changed.connect(fit)
	pane.tree_exiting.connect(func() -> void:
		if screen.size_changed.is_connected(fit):
			screen.size_changed.disconnect(fit))
	_fit_screen(pane, layout)
	fit.call_deferred()
	hud.run_while_taking()
	hud.box_pane = hud.modal
	hud.inv_laid_place = place_key(at)
	if again:
		hud._bag_scrolls_back(kept)
	if not taking and now_ms < hud.inv_fold_until_ms:
		# The lingering pane owns one timer, with no strong Node captures. It counts
		# from now, after the laying (which takes its own time), to the deadline.
		var hud_ref: WeakRef = weakref(hud)
		var left_s: float = maxf(0.0, float(hud.inv_fold_until_ms - Time.get_ticks_msec()) / 1000.0)
		pane.get_tree().create_timer(left_s).timeout.connect(func() -> void:
			var hud_now: Object = hud_ref.get_ref()
			var shown: GlassPane = pane_ref.get_ref() as GlassPane
			if hud_now != null and shown != null and hud_now.get("modal_pane") == shown and hud_now.get("modal") == hud_now.get("box_pane"):
				var game_now: Variant = hud_now.get("game")
				if taking_id(game_now, game_now.player) == "":
					hud_now.call("_lay_bag_again"))
	hud.box_shown_now(String(at.get("id", "")) if String(at.get("kind", "")) == "box" else "")
	hud.dim_under_bag()


## The glass without its common head (each column has its own, the fold stands
## at the rail's top), its rows edged as the mockup.
static func _bare(pane: GlassPane, folded: bool = false) -> void:
	var margin: MarginContainer = pane.get_node("Rows")
	margin.add_theme_constant_override("margin_left", GlassPane.px(FOLD_EDGE_L if folded else EDGE_L))
	margin.add_theme_constant_override("margin_right", GlassPane.px(EDGE_R))
	margin.add_theme_constant_override("margin_top", GlassPane.px(EDGE_T))
	margin.add_theme_constant_override("margin_bottom", GlassPane.px(EDGE_B))
	pane.body.add_theme_constant_override("separation", GlassPane.px(GAP))
	var head: Control = pane.find_child("Head", true, false) as Control
	if head != null:
		head.get_parent().remove_child(head)
		head.free()


## A width in whole game pixels. A container rounds each child's fractional
## minimum up (369.2 → 370), so the columns and gaps are whole and the pane is
## exactly their sum — never a few pixels wider than asked.
static func whole(css: float) -> float:
	return ceilf(UiFonts.px(css))


## The pane's width: the edges, the two columns, their gaps and the rail (PANE_W
## css, give or take a pixel a part).
static func pane_px(folded: bool = false) -> float:
	if folded:
		return float(GlassPane.px(FOLD_EDGE_L) + GlassPane.px(EDGE_R)) + whole(FOLD_W) + whole(COL_W) + whole(RAIL_GAP) + whole(KEY)
	return float(GlassPane.px(EDGE_L) + GlassPane.px(EDGE_R)) + whole(COL_W) * 2.0 + whole(COL_GAP) + whole(RAIL_GAP) + whole(KEY)


static func _gap(css: float) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size.x = whole(css)
	return c


static func _spring() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## The pane stays inside the screen: each column's list gives up height first,
## then the places rail (down to one place); each shows all it holds while it fits.
static func _fit_screen(pane: GlassPane, layout: Control) -> void:
	if not is_instance_valid(pane) or not pane.is_inside_tree() or pane.is_moving():
		return
	var room: float = pane.get_viewport_rect().size.y - pane.position.y - UiFonts.px(FOOT_GAP)
	var journal_scroll := pane.body.get_node_or_null("JournalScroll") as ScrollContainer
	if journal_scroll != null:
		journal_scroll.custom_minimum_size.y = (journal_scroll.get_child(0) as Control).get_combined_minimum_size().y
	var fits: float = room - (pane.get_combined_minimum_size().y - layout.get_combined_minimum_size().y)
	for side: String in ["BagSide", "PlaceSide"]:
		var col: Control = layout.get_node_or_null(side) as Control
		if col == null:
			continue
		var scroll: ScrollContainer = col.get_node_or_null("BagScroll" if side == "BagSide" else "NearScroll") as ScrollContainer
		if scroll == null:
			continue
		var rows := scroll.get_child(0) as Control
		var want: float = rows.get_combined_minimum_size().y
		scroll.custom_minimum_size.y = 0.0
		var fixed: float = col.get_combined_minimum_size().y
		scroll.custom_minimum_size.y = maxf(UiFonts.px(ROW_H), minf(want, fits - fixed))
	var rail_col: Control = layout.get_node_or_null("RailSide") as Control
	var rail: ScrollContainer = layout.find_child("PlaceScroll", true, false) as ScrollContainer
	if rail_col != null and rail != null:
		var keys := rail.get_child(0) as Control
		rail.custom_minimum_size.y = 0.0
		var fixed_rail: float = rail_col.get_combined_minimum_size().y
		rail.custom_minimum_size.y = maxf(UiFonts.px(PLACE_H), minf(minf(keys.get_combined_minimum_size().y, UiFonts.px(RAIL_MAX)), fits - fixed_rail))
	# The journal gives up height only after each list reaches its minimum.
	if journal_scroll != null:
		var journal_h: float = journal_scroll.custom_minimum_size.y
		var overflow: float = pane.get_combined_minimum_size().y - room
		journal_scroll.custom_minimum_size.y = maxf(0.0, journal_h - maxf(0.0, overflow))
	pane._fit()


static func _column(gap: float = GAP) -> VBoxContainer:
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


static func _number(word: String, css: float, ink: Color = GlassPane.INK) -> Label:
	var label := UiFonts.label(word, UiFonts.NUMBER, 500, css, ink)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


static func _place_name(game, place: Dictionary, short: bool = false) -> String:
	if place["kind"] != "box":
		return "열차" if short and place["kind"] == "train" else String(place["name"])
	var c: Dictionary = game.data["containers"][place["id"]]
	var fallback: String = String(c["name"])
	return String(NAMES.get(String(c.get("furniture", "")), fallback.left(4) if short else fallback))


static func _place_icon(place: Dictionary) -> String:
	return "train" if place["kind"] == "train" else ("fetch" if place["kind"] in ["box", "sled"] else "drop")


## A thin bar of `ink` on the faint track, `frac` of it full.
static func _thin_bar(hud, ink: Color, frac: float) -> ProgressBar:
	var bar: ProgressBar = hud._bar(ink)
	bar.custom_minimum_size = Vector2(0, UiFonts.px(BAR_H))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = 1.0
	bar.value = clampf(frac, 0.0, 1.0)
	var under := StyleBoxFlat.new()
	under.bg_color = TRACK
	under.set_corner_radius_all(GlassPane.px(2.0))
	bar.add_theme_stylebox_override("background", under)
	return bar


# ---------------------------------------------------------------- keys


## A key of the pane: `main` the amber one (one to a pane), else the steel edge.
## Its word stays on it for tests and tips; what shows is drawn on it.
static func _key(word: String, cb: Callable, main: bool = false, w: float = KEY, h: float = KEY) -> Button:
	var b := Button.new()
	b.text = word
	# The word is drawn by the key's own label (or not at all): the hidden text
	# must not widen the key past its css width (싣기 widened the rail).
	b.clip_text = true
	b.tooltip_text = word
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiFonts.px(w), UiFonts.px(h))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var fill: Color = GlassPane.AMBER * Color(1, 1, 1, 0.16) if main else GlassPane.CELL
	var edge: Color = GlassPane.AMBER if main else GlassPane.HAIR
	for state: String in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, _skin(fill, edge, 0.0))
	for state: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, _skin(fill.darkened(0.25), GlassPane.AMBER_L if main else GlassPane.INK, UiFonts.px(PRESS_SINK)))
	b.add_theme_stylebox_override("disabled", _skin(Color(fill, fill.a * 0.5), Color(edge, edge.a * 0.4), 0.0))
	_hide_text(b)
	_press_feel(b)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## Pressed, a one-press key buzzes very short; a hold key (its "Hold" child) keeps
## its buzz for the full hold (결정 561 ④). Its marks and words sink PRESS_SINK with
## its face (GlassPane.sinks, laid with them), as its pressed stylebox moves the face.
static func _press_feel(b: Button) -> void:
	b.button_down.connect(func() -> void:
		if b.get_node_or_null("Hold") == null:
			Input.vibrate_handheld(TAP_BUZZ_MS)
			b.set_meta("tap_buzz", int(b.get_meta("tap_buzz", 0)) + 1))


static func _skin(fill: Color, edge: Color, sink: float) -> StyleBoxFlat:
	var sb := GlassPane._box(fill, edge, sink)
	sb.set_border_width_all(maxi(1, GlassPane.px(1.5)))
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	return sb


## An icon laid in the middle of `key` (and sinking with it), `css` high, `dy` off
## the middle.
static func _key_icon(hud, key: Button, icon: String, css: float, ink: Color, dy: float = 0.0) -> TextureRect:
	var mark: TextureRect = hud._icon_rect(icon, UiFonts.size(css), ink)
	mark.name = "Mark"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_child(mark)
	mark.size = Vector2.ONE * UiFonts.size(css)
	mark.position = (key.custom_minimum_size - mark.size) * 0.5 + Vector2(0, UiFonts.px(dy))
	GlassPane.sinks(key, mark, PRESS_SINK)
	return mark


## A word laid on `key`, centred across it at `top` css.
static func _key_word(key: Button, word: String, top: float, ink: Color, css: float = 12.0, number: bool = false) -> Label:
	var label: Label = _number(word, css, ink) if number else _label(word, css, ink)
	label.name = "Word"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	key.add_child(label)
	label.position = Vector2(UiFonts.px(2.0), UiFonts.px(top))
	label.size = Vector2(key.custom_minimum_size.x - UiFonts.px(4.0), UiFonts.px(css * 1.3))
	GlassPane.sinks(key, label, PRESS_SINK)
	return label


## Text stays on the button for accessibility; the row's labels draw it once.
static func _hide_text(b: Button) -> void:
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(state, Color.TRANSPARENT)


# ---------------------------------------------------------------- heads


## A column's head, 52 high: its mark, name and weight (a bar under them while
## the place has a limit), the sort key at its right end (away from the weapons).
static func _head(hud, prefix: String, icon: String, title: String, side: String, frac: float, ink: Color, bar_ink: Color, icon_css: float = HEAD_ICON) -> Control:
	var head := GlassPane.row()
	head.name = prefix + "Head"
	head.add_theme_constant_override("separation", GlassPane.px(6.0))
	head.custom_minimum_size.y = UiFonts.px(KEY)
	var words := _column(4.0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line := GlassPane.row()
	line.add_theme_constant_override("separation", GlassPane.px(7.0))
	line.add_child(GlassPane.mark(icon, icon_css, GlassPane.INK2))
	var name_l := _label(title, 15.0, GlassPane.INK)
	name_l.name = "Title" if prefix == "Place" else prefix + "Title"
	UiFonts.style(name_l, UiFonts.WORD, 500, 15.0, GlassPane.INK, 1.2)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_l)
	if side != "":
		var number := _number(side, 15.0, ink)
		number.name = "Side" if prefix == "Place" else prefix + "Load"
		line.add_child(number)
	words.add_child(line)
	if frac >= 0.0:
		var bar := _thin_bar(hud, bar_ink, frac)
		bar.name = prefix + "Bar"
		words.add_child(bar)
	head.add_child(words)
	var sort := _key("이름순" if hud.inv_sort == "name" else "무게순", hud._inv_sort)
	sort.name = prefix + "Sort"
	_key_icon(hud, sort, "weight", 24.0, GlassPane.INK2)
	head.add_child(sort)
	return head


# ---------------------------------------------------------------- the bag


## Find the work's box even while the bag or another place is being viewed.
static func taking_id(game, p) -> String:
	if p.action == "take":
		for id: String in game.data["containers"]:
			if is_same(p.action_busy, game.data["containers"][id]):
				return id
	return ""


## Seconds from one attack to the next with this weapon: a melee blow is its
## swing and the rest after it (weapons.gd swing + melee_gap); a gun or bow
## waits for its aim to close again (shrink_time), and one that holds a single
## round for its reload too. 0 for no weapon.
static func attack_seconds(id: String) -> float:
	var d: Dictionary = W.get_data(id)
	if d.is_empty():
		return 0.0
	if String(d.get("kind", "")) == "melee":
		return float(d.get("swing", 0.0)) + W.melee_gap(id)
	var wait: float = float(d.get("shrink_time", 0.0))
	if int(d.get("mag", 0)) <= 1:
		wait = maxf(wait, float(d.get("reload", 0.0)))
	return wait


## A number of seconds as it reads on the screen: one place, or two when that
## is what it is (0.85, not 0.8).
static func seconds_word(s: float) -> String:
	var two: float = snappedf(s, 0.01)
	return ("%.1f" % two) if is_equal_approx(snappedf(two, 0.1), two) else ("%.2f" % two)


## Which of the weapons named at the bag's top shows its numbers (-1 none): the
## one pressed, followed to wherever it now stands among the two (a weapon taken
## into the hand goes first); gone from them, none — and the HUD forgets it.
static func open_weapon(hud, p) -> int:
	var want: String = String(hud.inv_weapon_open_id)
	var shown: int = mini(p.hands.size(), 2)
	var at: int = -1
	if want != "" and int(hud.inv_weapon_open) >= 0:
		var was: int = int(hud.inv_weapon_open)
		if was < shown and String((p.hands[was] as Dictionary).get("id", "")) == want:
			at = was
		else:
			for i: int in shown:
				if String((p.hands[i] as Dictionary).get("id", "")) == want:
					at = i
					break
	hud.inv_weapon_open = at
	hud.inv_weapon_open_id = want if at >= 0 else ""
	return at


## A weapon's picture: its own if the field has one, else a gun or a blade.
static func weapon_icon(game, id: String) -> String:
	var icon: String = String(game.item_icon(id))
	if icon != "" and HudIcons.PATHS.has(icon):
		return icon
	return "gun" if W.is_ranged(id) else "axe"


## The weapons named at the bag's top (in hand, then the one carried after it),
## each a key with its picture and name that shows or hides its two numbers
## (결정 555: the name only, and on a press how fast it attacks and its weight),
## and the swap key beside them (결정 558: the weapons' row holds nothing else).
static func _weapons(hud, p) -> Control:
	var held := _column(4.0)
	held.name = "Weapons"
	var row := GlassPane.row()
	row.name = "WeaponKeys"
	row.add_theme_constant_override("separation", GlassPane.px(GAP))
	held.add_child(row)
	var shown: int = mini(p.hands.size(), 2)
	var open: int = open_weapon(hud, p)
	var each: float = (COL_W - KEY - GAP * 2.0) / 2.0
	if shown == 0:
		var bare := _label(hud.short_weapon(p), 12.0, GlassPane.INK2)
		bare.name = "BareHands"
		bare.custom_minimum_size = Vector2(UiFonts.px(each * 2.0 + GAP), UiFonts.px(KEY))
		row.add_child(bare)
	for i: int in shown:
		var id: String = String((p.hands[i] as Dictionary).get("id", ""))
		var word: String = hud.short_weapon(p) if i == 0 else _last_word(String(W.get_data(id).get("name", id)))
		var key := _key(word, hud._inv_weapon.bind(i), false, each, KEY)
		key.name = "WeaponName%d" % i
		var lit: bool = open == i
		if lit:
			for state: String in ["normal", "hover", "focus"]:
				key.add_theme_stylebox_override(state, _skin(Color(BONE, 0.08), BONE, 0.0))
		var ink: Color = GlassPane.INK if lit else GlassPane.INK2
		_key_icon(hud, key, weapon_icon(hud.game, id), 22.0, ink, -8.0)
		_key_word(key, word, 30.0, GlassPane.INK)
		row.add_child(key)
	var swap := _key("바꾸기", hud._swap_from_bag)
	swap.name = "Swap"
	swap.disabled = p.hands.size() < 2
	_key_icon(hud, swap, "swap", 24.0, GlassPane.INK3 if swap.disabled else GlassPane.INK2)
	row.add_child(swap)
	if open >= 0 and open < shown:
		held.add_child(_weapon_numbers(hud, String((p.hands[open] as Dictionary).get("id", ""))))
	return held


static func _last_word(name_word: String) -> String:
	var parts: PackedStringArray = name_word.split(" ")
	return parts[parts.size() - 1]


## A weapon's two numbers: a clock and its seconds an attack, a scale and its weight.
static func _weapon_numbers(hud, id: String) -> Control:
	var row := GlassPane.row()
	row.name = "WeaponStats"
	row.add_theme_constant_override("separation", GlassPane.px(6.0))
	for pair: Array in [["clock", seconds_word(attack_seconds(id)) + "초", "WeaponSpeed"], ["weight", "%.1f" % float(W.get_data(id).get("weight", 0.0)), "WeaponWeight"]]:
		row.add_child(hud._icon_rect(String(pair[0]), UiFonts.size(15.0), GlassPane.INK2))
		var number := UiFonts.label(String(pair[1]), UiFonts.NUMBER, 500, 15.0, GlassPane.INK)
		number.name = String(pair[2])
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(number)
		row.add_child(_gap(10.0))
	return row


## The clothes worn, folded into one key of their pictures (a thin bar under each
## for how worn it is); pressed, their rows with the keys that take them off.
static func _worn(hud, p) -> Array:
	var game = hud.game
	var ids: Dictionary = Wear.worn_ids(p)
	var names: PackedStringArray = []
	var worn := _column(0.0)
	worn.name = "Worn"
	var fold := _key("", hud._inv_worn, false, COL_W, KEY)
	fold.name = "WornFold"
	var strip := GlassPane.row()
	strip.name = "WornStrip"
	strip.add_theme_constant_override("separation", 0)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip.offset_left = UiFonts.px(6.0)
	strip.offset_right = -UiFonts.px(6.0)
	fold.add_child(strip)
	GlassPane.sinks(fold, strip, PRESS_SINK)
	for slot: String in Wear.SLOTS:
		var id: String = String(ids[slot])
		if id == "":
			continue
		names.append(game.item_name(id))
		worn.add_child(hud._worn_row(slot, id))
		var cell := _column(3.0)
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon: String = String(game.item_icon(id))
		cell.add_child(GlassPane.mark(icon if HudIcons.PATHS.has(icon) else "wear", 20.0, GlassPane.INK2))
		var cond: float = 1.0 - float(Wear.occupant(p, slot).get("wear", 0.0))
		var bar := _thin_bar(hud, BONE, cond)
		bar.custom_minimum_size = Vector2(UiFonts.px(18.0), UiFonts.px(2.5))
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(bar)
		strip.add_child(cell)
	fold.text = "입은 옷 %d%s" % [names.size(), " · " + " · ".join(names) if not names.is_empty() else ""]
	fold.tooltip_text = fold.text
	worn.visible = hud.inv_worn_open and not names.is_empty()
	return [fold, worn]


## The rounds carried and the body's burden, one short line under the weapons.
static func _ammo(game, p) -> Control:
	var row := GlassPane.row()
	row.name = "Ammo"
	row.add_theme_constant_override("separation", GlassPane.px(4.0))
	var rounds := _label("권총탄 %d · 산탄 %d · 화살 %d" % [int(game.ammo["pistol"]), int(game.ammo["shell"]), int(game.ammo["craft"])], 11.0, GlassPane.INK2)
	rounds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rounds)
	row.add_child(GlassPane.mark("run", 13.0, GlassPane.INK3))
	var burden := _number("%.1f" % p.body_burden(), 13.0, GlassPane.INK2)
	burden.name = "Burden"
	burden.tooltip_text = "몸 부담"
	row.add_child(burden)
	return row


## The bag folded while things come out of a box (결정 558: the field runs then,
## so the pane covers no more than the old one): a strip key, 52 css, with the
## bag's mark, its weight and a standing bar on the carry scale. Pressed, the bag
## opens again while the taking goes on (결정 488: the bag stays at hand).
static func _bag_strip(hud, p) -> Button:
	var strip := _key("가방 펴기", hud._inv_unfold, false, FOLD_W, KEY)
	strip.name = "BagStrip"
	strip.tooltip_text = strip.text
	_hide_text(strip)
	strip.custom_minimum_size.x = whole(FOLD_W)
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := GlassPane.row()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = UiFonts.px(8.0)
	row.offset_right = -UiFonts.px(8.0)
	row.offset_top = UiFonts.px(8.0)
	row.offset_bottom = -UiFonts.px(8.0)
	row.add_theme_constant_override("separation", GlassPane.px(4.0))
	var words := _column()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(GlassPane.mark("pack", BAG_ICON, GlassPane.INK2))
	var weight := _number("%.1f" % p.weight(), 13.0, carry_ink(p.carry_state()))
	weight.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(weight)
	row.add_child(words)
	var bar := _thin_bar(hud, carry_bar(p.carry_state()), p.weight() / maxf(p.carry_limit(), 0.001))
	bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	bar.custom_minimum_size = Vector2(UiFonts.px(2.0), 0.0)
	bar.size_flags_horizontal = Control.SIZE_FILL
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	strip.add_child(row)
	GlassPane.sinks(strip, row, PRESS_SINK)
	return strip


## The bag's column: its head with the weight on the carry scale, the weapons'
## row, the clothes (beside the floor, the train's hold or a sled; folded away
## beside a box so one more row shows), the rounds, then its rows.
static func _bag_side(hud, p, at: Dictionary) -> VBoxContainer:
	var game = hud.game
	var col := _column()
	col.name = "BagSide"
	col.custom_minimum_size.x = whole(COL_W)
	var state: int = p.carry_state()
	var head := _head(hud, "Bag", "pack", String(Carry.BAGS[p.bag]["name"]), "%.1f / %.0f" % [p.weight(), p.carry_limit()], p.weight() / maxf(p.carry_limit(), 0.001), carry_ink(state), carry_bar(state), BAG_ICON)
	var load_l: Label = head.find_child("BagLoad", true, false) as Label
	load_l.tooltip_text = "%.1f / %.0f · %s" % [p.weight(), p.carry_limit(), Carry.STATE_NAMES[state]]
	col.add_child(head)
	col.add_child(_weapons(hud, p))
	# The clothes' key stays in place; opened, their rows head the bag's list and
	# scroll with it, so the pane never grows past the screen.
	var worn: Array = _worn(hud, p) if String(at["kind"]) != "box" else []
	if not worn.is_empty():
		col.add_child(worn[0])
	col.add_child(_ammo(game, p))
	var list := _column(ROW_GAP)
	list.name = "Bag"
	var loadable: Array = game.actions.loadable(p)
	var box: Dictionary = game.data["containers"][at["id"]] if at["kind"] == "box" else {}
	for id: String in bag_order(game, p, hud.inv_sort):
		var can_move: bool = loadable.has(id) if at["kind"] in ["train", "sled"] else (box.is_empty() or Carry.box_room(box, id) > 0)
		var n: int = int(p.items[id])
		# 결정 559: moving one kind is one press, including beside the train.
		list.add_child(_row(hud, id, game.item_name(id), n, Carry.item_weight(id) * n, hud._inv_put.bind(id), not can_move, "bag"))
		if _expanded(hud, "bag", id):
			list.add_child(_bag_more(hud, p, id, at, can_move))
	if list.get_child_count() == 0:
		list.add_child(_label("빈 가방", 12.0, GlassPane.INK3))
	var rows := _column(ROW_GAP)
	rows.name = "BagRows"
	if not worn.is_empty():
		rows.add_child(worn[1])
	rows.add_child(list)
	var scroll := GlassPane.scroll(rows, 9999.0)
	scroll.name = "BagScroll"
	col.add_child(scroll)
	return col


static func _expanded(hud, side: String, id: String, i: int = -1) -> bool:
	var e: Dictionary = hud.inv_expand
	return String(e.get("side", "")) == side and String(e.get("id", "")) == id and e.get("i") == i and e.get("at") == place_key(hud.inv_near)


## A bag row held open: its weight and count, and what it can do — eat it, throw
## it (held to confirm), switch the watch off — and the amber key that moves it
## across as a press on the row does.
static func _bag_more(hud, p, id: String, at: Dictionary, can_move: bool) -> Control:
	var n: int = int(p.items.get(id, 0))
	var more := _more(id, Carry.item_weight(id), n)
	var keys: HBoxContainer = more.find_child("Keys", true, false) as HBoxContainer
	if Carry.FieldItems.rings(id):
		var off := _key("끄기", hud._alarm_off)
		off.name = "AlarmOff"
		_key_icon(hud, off, "pause", 22.0, GlassPane.INK2)
		keys.add_child(off)
	if Carry.FieldItems.edible(id):
		var eat := _key("먹기", hud._eat.bind(id))
		eat.name = "Eat"
		_key_icon(hud, eat, "ration", 24.0, GlassPane.INK2)
		keys.add_child(eat)
	if Carry.FieldItems.throwable(id):
		# 결정 559: thrown, it calls the dead with its sound — held to confirm.
		var throw := _key("던지기", Callable(), false, 100.0, KEY)
		throw.name = "Throw"
		_key_icon(hud, throw, "it_can", 24.0, GlassPane.INK2).position.x = UiFonts.px(10.0)
		var word := _label("던지기", 14.0, GlassPane.INK)
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		throw.add_child(word)
		word.position = Vector2(UiFonts.px(42.0), UiFonts.px(16.0))
		word.size = Vector2(UiFonts.px(54.0), UiFonts.px(20.0))
		GlassPane.sinks(throw, word, PRESS_SINK)
		# The hold's line and flash keep to the pressed face (결정 561 ④).
		GlassPane.sinks(throw, HoldConfirm.attach(throw, hud._throw.bind(id, hud.pane_era)), PRESS_SINK)
		keys.add_child(throw)
	else:
		# 결정 559: only loading everything is held; this move stays one press.
		var move := _key("옮기기", hud._inv_put.bind(id), true)
		move.name = "Move"
		move.disabled = not can_move
		_key_icon(hud, move, _place_icon(at), 24.0, GlassPane.AMBER_L if can_move else GlassPane.INK3)
		keys.add_child(move)
	return more


## Under a held row: its weight and count at the left, its keys at the right.
static func _more(id: String, weight: float, n: int) -> Control:
	var more := PanelContainer.new()
	more.name = "More"
	more.set_meta("item_id", id)
	more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BONE, 0.05)
	sb.set_corner_radius_all(GlassPane.px(GlassPane.RADIUS))
	more.add_theme_stylebox_override("panel", sb)
	var row := GlassPane.row()
	row.add_theme_constant_override("separation", GlassPane.px(GAP))
	row.custom_minimum_size.y = UiFonts.px(KEY)
	more.add_child(row)
	var facts := GlassPane.row()
	facts.name = "Facts"
	facts.add_theme_constant_override("separation", GlassPane.px(4.0))
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_child(_gap(4.0))
	facts.add_child(GlassPane.mark("weight", 11.0, GlassPane.INK3))
	facts.add_child(_number("%.1f" % weight, 13.0, GlassPane.INK2))
	facts.add_child(_gap(4.0))
	facts.add_child(_number("×%d" % n, 13.0, GlassPane.INK2))
	row.add_child(facts)
	var keys := GlassPane.row()
	keys.name = "Keys"
	keys.add_theme_constant_override("separation", GlassPane.px(GAP))
	row.add_child(keys)
	return more


# ---------------------------------------------------------------- the place


## The selected place's column: its head (the box's load against its limit, a
## sled's against its limit, the floor's or the hold's weight), then its rows.
static func _place_side(hud, p, at: Dictionary) -> VBoxContainer:
	var game = hud.game
	var col := _column()
	col.name = "PlaceSide"
	col.custom_minimum_size.x = whole(COL_W)
	var side: String = ""
	var frac: float = -1.0
	var ink: Color = GlassPane.INK
	var bar_ink: Color = BONE
	match String(at["kind"]):
		"box":
			var c: Dictionary = game.data["containers"][at["id"]]
			side = "%.1f / %.0f" % [Carry.box_load(c), Carry.box_limit(c)]
			frac = Carry.box_load(c) / maxf(Carry.box_limit(c), 0.001)
		"sled":
			var sled: Dictionary = Sled.find(game, int(at["id"]))
			side = "%.1f / %.0f" % [Sled.weight(sled), Sled.LIMIT]
			frac = Sled.weight(sled) / maxf(Sled.LIMIT, 0.001)
		"ground":
			var held: float = 0.0
			for i: int in game.actions.near_ground(p):
				held += Carry.item_weight(String(game.ground_items[i]["id"])) * int(game.ground_items[i]["n"])
			side = "%.1f" % held
		"train":
			var loaded: float = 0.0
			for id: String in game.unloaded.keys():
				loaded += Carry.item_weight(id) * int(game.unloaded[id])
			side = "%.1f" % loaded
	col.add_child(_head(hud, "Place", _place_icon(at), _place_name(game, at), side, frac, ink, bar_ink))
	var scroll := GlassPane.scroll(_near_rows(hud, p, at), 9999.0)
	scroll.name = "NearScroll"
	col.add_child(scroll)
	return col


## Sorting changes display indices only; callbacks keep the source indices. While
## a thing comes out of this box its rows wait, as before; other places stay open.
static func _near_rows(hud, p, at: Dictionary) -> Control:
	var game = hud.game
	var list := _column(ROW_GAP)
	list.name = "Near"
	var empty: String = ""
	match String(at["kind"]):
		"sled":
			var cargo: Dictionary = Sled.find(game, int(at["id"])).get("items", {})
			var keys: Array = cargo.keys()
			var ids: Array = keys.duplicate()
			ids.sort_custom(func(a: String, b: String) -> bool:
				return _steady(_order_key(hud, a, int(cargo[a])), _order_key(hud, b, int(cargo[b])), keys.find(a), keys.find(b)))
			for item: String in ids:
				var count: int = int(cargo[item])
				var cb: Callable = hud._inv_sled_take.bind(int(at["id"]), item)
				list.add_child(_row(hud, item, game.item_name(item), count, Carry.item_weight(item) * count, cb, false, "near"))
				if _expanded(hud, "near", item):
					list.add_child(_near_more(hud, item, Carry.item_weight(item), count, cb))
			empty = "빈 썰매"
		"box":
			var c: Dictionary = game.data["containers"][at["id"]]
			var items: Array = c["items"]
			var indices: Array = range(items.size())
			indices.sort_custom(func(a: int, b: int) -> bool:
				return _steady(_order_key(hud, String(items[a]), 1), _order_key(hud, String(items[b]), 1), a, b))
			var now: String = game.actions.taking_item(p) if is_same(p.action_busy, c) else ""
			var barred: bool = false
			var opened: bool = false
			for i: int in indices:
				var id: String = String(items[i])
				var cb: Callable = hud._loot_take.bind(String(at["id"]), i)
				var row := _row(hud, id, game.item_name(id), 1, Carry.item_weight(id), cb, now != "", "near", i)
				if id == now and not barred:
					barred = true
					row.add_child(_take_bar(hud, p))
				list.add_child(row)
				if now == "" and not opened and _expanded(hud, "near", id, i):
					opened = true
					list.add_child(_near_more(hud, id, Carry.item_weight(id), 1, cb))
			empty = "빈 곳"
		"ground":
			var indices: Array = game.actions.near_ground(p)
			indices.sort_custom(func(a: int, b: int) -> bool:
				var left: Dictionary = game.ground_items[a]
				var right: Dictionary = game.ground_items[b]
				return _steady(_order_key(hud, String(left["id"]), int(left["n"])), _order_key(hud, String(right["id"]), int(right["n"])), a, b))
			var opened_g: bool = false
			for i: int in indices:
				var g: Dictionary = game.ground_items[i]
				var id: String = String(g["id"])
				var word: String = game.item_name(id) + (" · 입기" if g.has("garment") else "")
				var cb_g: Callable = hud._inv_pick.bind(i)
				list.add_child(_row(hud, id, word, int(g["n"]), Carry.item_weight(id) * int(g["n"]), cb_g, false, "near", i))
				if not opened_g and _expanded(hud, "near", id, i):
					opened_g = true
					list.add_child(_near_more(hud, id, Carry.item_weight(id) * int(g["n"]), int(g["n"]), cb_g))
			empty = "발밑에 아무것도 없다"
		"train":
			var keys: Array = game.unloaded.keys()
			var ids: Array = keys.duplicate()
			ids.sort_custom(func(a, b) -> bool:
				return _steady(_order_key(hud, String(a), int(game.unloaded[a])), _order_key(hud, String(b), int(game.unloaded[b])), keys.find(a), keys.find(b)))
			for id: String in ids:
				var n: int = int(game.unloaded[id])
				list.add_child(_row(hud, id, game.item_name(id), n, Carry.item_weight(id) * n, Callable(), true, "near"))
			empty = "이번 정차에 실은 것이 아직 없다"
	if list.get_child_count() == 0:
		var none := _label(empty, 12.0, GlassPane.INK3)
		none.custom_minimum_size.y = UiFonts.px(ROW_H)
		list.add_child(none)
	return list


## A place's row held open: its weight and count, and the amber key that takes it
## into the bag as a press on the row does.
static func _near_more(hud, id: String, weight: float, n: int, cb: Callable) -> Control:
	var more := _more(id, weight, n)
	var take := _key("담기", cb, true)
	take.name = "Take"
	_key_icon(hud, take, "pack", 24.0, GlassPane.AMBER_L)
	(more.find_child("Keys", true, false) as HBoxContainer).add_child(take)
	return more


## What a row sorts by: its name, or the heavier first (a negative weight).
static func _order_key(hud, id: String, n: int) -> Variant:
	if hud.inv_sort == "name":
		return hud.game.item_name(id)
	return -Carry.item_weight(id) * n


## A steady order: rows with equal keys keep their place between refreshes.
static func _steady(x: Variant, y: Variant, a: int, b: int) -> bool:
	return x < y if x != y else a < b


# ---------------------------------------------------------------- rows


## One row, COL_W × ROW_H: the thing's picture, its name on one line (cut with …
## when long), its count and its weight. A press moves it (`cb`); held LONG_S
## without moving, it opens under itself instead (`side` is the column).
static func _row(hud, id: String, word: String, n: int, weight: float, cb: Callable, dim: bool, side: String, i: int = -1) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiFonts.px(COL_W), UiFonts.px(ROW_H))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = word if n <= 1 else "%s ×%d" % [word, n]
	b.clip_text = true
	b.tooltip_text = b.text
	b.disabled = dim and side != "bag"
	b.set_meta("item_id", id)
	UiFonts.style(b, UiFonts.WORD, 500, 12.0, GlassPane.INK, 0.2)
	_hide_text(b)
	var open: bool = _expanded(hud, side, id, i)
	var edge: Color = BONE if open else GlassPane.HAIR
	for state: String in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, _skin(Color(BONE, 0.08) if open else GlassPane.CELL, edge, 0.0))
	for state: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, _skin(Color(BONE, 0.07), GlassPane.INK, UiFonts.px(PRESS_SINK)))
	b.add_theme_stylebox_override("disabled", _skin(Color(0, 0, 0, 0.12), Color(GlassPane.HAIR, 0.5), 0.0))
	if dim and side == "bag":
		# Dim, it still opens on a long press: its face sinks with its line.
		for state: String in ["normal", "hover", "focus"]:
			b.add_theme_stylebox_override(state, b.get_theme_stylebox("disabled"))
		for state: String in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, _skin(Color(0, 0, 0, 0.12), Color(GlassPane.HAIR, 0.5), UiFonts.px(PRESS_SINK)))
	_press_feel(b)
	var row := GlassPane.row()
	row.name = "Line"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = UiFonts.px(4.0)
	row.offset_right = -UiFonts.px(8.0)
	row.add_theme_constant_override("separation", GlassPane.px(6.0))
	row.add_child(_item_icon(hud, id))
	var label := _label(word, 12.5, GlassPane.INK)
	label.name = "Name"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	if n > 1:
		var count := _number("×%d" % n, 13.0, GlassPane.INK)
		count.name = "Count"
		row.add_child(count)
	var kg := _number("%.1f" % weight, 13.0, GlassPane.INK2)
	kg.name = "Weight"
	kg.custom_minimum_size.x = UiFonts.px(26.0)
	row.add_child(kg)
	if dim:
		row.modulate = Color(1, 1, 1, 0.5)
	b.add_child(row)
	GlassPane.sinks(b, row, PRESS_SINK)
	if cb.is_valid() and not dim:
		b.pressed.connect(func() -> void:
			if bool(b.get_meta("held_long", false)) or bool(b.get_meta("dragged", false)):
				b.set_meta("held_long", false)
				return
			cb.call())
	_long_press(hud, b, side, id, i)
	return b


## Held LONG_S without a drag, a row opens under itself (or closes again); the
## press that follows its lift does nothing. Still down means no lift since
## (press_n): a second finger's press reaches the row by its signals alone
## (field_hud.gd), the button's own pressed state never set. The timer holds
## the row and the HUD weakly: a tap that moves the row lays the pane again and
## frees the row before the timer ends (a lambda calling a freed capture errors).
static func _long_press(hud, b: Button, side: String, id: String, i: int) -> void:
	b.set_meta("press_n", 0)
	var row_ref: WeakRef = weakref(b)
	var hud_ref: WeakRef = weakref(hud)
	b.button_down.connect(func() -> void:
		var n: int = int(b.get_meta("press_n")) + 1
		b.set_meta("press_n", n)
		b.set_meta("press_at", b.get_local_mouse_position())
		b.set_meta("dragged", false)
		b.get_tree().create_timer(LONG_S, false).timeout.connect(func() -> void:
			var row := row_ref.get_ref() as Button
			var hud_now: Object = hud_ref.get_ref()
			if row == null or hud_now == null or int(row.get_meta("press_n")) != n or bool(row.get_meta("dragged")):
				return
			row.set_meta("held_long", true)
			hud_now.call("_inv_expand", side, id, i)))
	b.button_up.connect(func() -> void: b.set_meta("press_n", int(b.get_meta("press_n")) + 1))
	b.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseMotion or event is InputEventScreenDrag) and b.is_pressed() and b.has_meta("press_at"):
			var at: Vector2 = (event as InputEventMouseMotion).position if event is InputEventMouseMotion else (event as InputEventScreenDrag).position
			if at.distance_to(b.get_meta("press_at") as Vector2) > UiFonts.px(DRAG_CSS):
				b.set_meta("dragged", true))


## The thing's art: the baked painted picture (결정 550·561, 256 px) is drawn
## smooth at ART; small pixel art (32 px) uses whole multiples in screen pixels;
## with neither, the line icon.
static func _item_icon(hud, id: String) -> Control:
	var texture: Texture2D = hud.item_px_override.get(id) as Texture2D
	if texture == null:
		texture = art_texture(id)
	if texture == null:
		var line := TextureRect.new()
		line.name = "ItemIcon"
		line.texture = HudIcons.texture(hud.game.item_icon(id), UiFonts.size(ITEM_ICON), GlassPane.INK2, 1.0 / HudIcons.LINE)
		line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		line.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.custom_minimum_size = Vector2.ONE * UiFonts.px(ITEM_ICON)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var line_slot := CenterContainer.new()
		line_slot.name = "ItemSlot"
		line_slot.custom_minimum_size = Vector2.ONE * UiFonts.px(ART)
		line_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line_slot.add_child(line)
		return line_slot
	var art := TextureRect.new()
	art.name = "ItemIcon"
	art.texture = texture
	if is_painted(texture):
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2.ONE * UiFonts.px(ART)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var painted_slot := CenterContainer.new()
		painted_slot.name = "ItemSlot"
		painted_slot.custom_minimum_size = Vector2.ONE * UiFonts.px(ART)
		painted_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		painted_slot.add_child(art)
		return painted_slot
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


## The thing's baked picture (res://assets/icons/items/<id>.png, or the one it
## shares, ART_ALIAS), null without one.
static func art_texture(id: String) -> Texture2D:
	for name: String in [id, String(ART_ALIAS.get(id, ""))]:
		var path: String = "res://assets/icons/items/%s.png" % name
		if name != "" and ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


## Painted art, not pixel art: wide enough to be shrunk smooth.
static func is_painted(texture: Texture2D) -> bool:
	return texture != null and texture.get_width() >= PAINTED_MIN_PX


## From the art's canvas to the device's pixels: the window's stretch times the
## canvas (get_screen_transform leaves the stretch out while windows are embedded).
static func _to_pixels(item: CanvasItem) -> Transform2D:
	return item.get_viewport().get_final_transform() * item.get_global_transform_with_canvas()


## The art's side in device pixels: the whole multiple of 32 nearest the row's
## picture size that fits `room` pixels, or 0 when not even one does.
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
	var pixels: float = whole_pixels(UiFonts.px(ART) * s, UiFonts.px(ROW_H - 4.0) * s)
	# A window too small for one whole multiple draws the line icon's size instead.
	art.size = Vector2.ONE * (pixels / s if pixels > 0.0 else UiFonts.px(ITEM_ICON))
	# Containers round their children; a free child keeps the exact size.
	slot.custom_minimum_size = art.size.ceil()
	art.position = (slot.size - art.size) * 0.5
	if pixels > 0.0:
		var origin: Vector2 = _to_pixels(art).origin
		art.position += (origin.round() - origin) / s


## The thin bar along the foot of the row coming out, in the bars' one colour;
## the HUD fills it each frame.
static func _take_bar(hud, p) -> ProgressBar:
	var bar: ProgressBar = _thin_bar(hud, BONE, 1.0 - p.action_t / maxf(p.action_total, 0.001))
	bar.name = "TakeBar"
	bar.custom_minimum_size = Vector2.ZERO
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = UiFonts.px(54.0)
	bar.offset_right = -UiFonts.px(8.0)
	bar.offset_top = -UiFonts.px(12.0)
	bar.offset_bottom = -UiFonts.px(12.0 - BAR_H)
	hud.take_bar = bar
	return bar


# ---------------------------------------------------------------- the rail


## The rail: the fold at its top, the places under it, the pane's main key at its
## foot — 모두 담기 by a box (멈추기 while things come out), 싣기 by the train's
## hold (held to confirm, 결정 559).
static func _rail_side(hud, p, all: Array, at: Dictionary) -> VBoxContainer:
	var col := _column(8.0)
	col.name = "RailSide"
	col.custom_minimum_size.x = whole(KEY)
	var fold := _key("접기", hud._close_modal)
	fold.name = "Fold"
	_key_icon(hud, fold, "back", 22.0, GlassPane.INK2)
	col.add_child(fold)
	var place_col: Control = _places(hud, all, at)
	var rail := GlassPane.scroll(place_col, RAIL_MAX)
	rail.name = "PlaceScroll"
	rail.custom_minimum_size.x = whole(KEY)
	col.add_child(_rail_with_more(rail))
	col.add_child(_spring())
	var main: Button = _main_key(hud, p, at)
	if main != null:
		col.add_child(main)
	return col


static func _places(hud, all: Array, at: Dictionary) -> Control:
	var col := _column(4.0)
	col.name = "Places"
	for place: Dictionary in all:
		var empty: bool = place["kind"] == "box" and SearchRules.shows_empty(hud.game.data["containers"][place["id"]])
		col.add_child(_place_key(hud, _place_icon(place), _place_name(hud.game, place, true), place == at, empty, hud._inv_place.bind(place), place))
	return col


static func _place_key(hud, icon: String, word: String, on: bool, empty: bool, cb: Callable, place: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2.ONE * UiFonts.px(PLACE_H)
	b.text = word + ("·빈" if empty else "")
	b.clip_text = true
	b.tooltip_text = b.text
	b.set_meta("place_kind", place["kind"])
	b.set_meta("place_id", place["id"])
	b.set_meta("selected", on)
	var fill: Color = Color(BONE, 0.08) if on else GlassPane.CELL
	var sb := _skin(fill, BONE if on else GlassPane.HAIR, 0.0)
	for state: String in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, sb)
	# Pressed, it sinks and its rim lights as the pane's other keys (결정 561 ④).
	for state: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, _skin(fill.darkened(0.25), GlassPane.INK, UiFonts.px(PRESS_SINK)))
	_hide_text(b)
	_press_feel(b)
	var col := _column(1.0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var ink: Color = GlassPane.INK3 if empty else (GlassPane.INK if on else GlassPane.INK2)
	var mark: TextureRect = hud._icon_rect(icon, UiFonts.size(20.0), ink)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(mark)
	var label := _label(word, 10.0, ink)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if empty:
		col.add_child(_column_word(label, ink))
	else:
		col.add_child(label)
	b.add_child(col)
	GlassPane.sinks(b, col, PRESS_SINK)
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


## The places rail in a holder whose foot fades while more places lie below
## (scrolled to the end, or all of them showing, it does not).
static func _rail_with_more(rail: ScrollContainer) -> Control:
	var holder := MarginContainer.new()
	holder.name = "PlaceRail"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


## The pane's one amber key at the rail's foot, 52 × 64: 모두 담기 with the seconds
## it takes by a box with things in, 멈추기 with the seconds left while they come
## out, 싣기 by the train (held to confirm); none by the floor.
static func _main_key(hud, p, at: Dictionary) -> Button:
	var game = hud.game
	var taking: String = taking_id(game, p)
	if taking != "":
		var stop := _key("멈추기", hud._loot_stop.bind(taking), true, KEY, MAIN_H)
		stop.name = "MainKey"
		_key_icon(hud, stop, "pause", 18.0, GlassPane.AMBER_L, -9.0)
		var left: Label = _key_word(stop, "%.1f초" % take_left(game, p), 40.0, GlassPane.AMBER_L, 12.0, true)
		left.name = "TakeLeft"
		return stop
	if at["kind"] == "box":
		var c: Dictionary = game.data["containers"][at["id"]]
		var seconds: float = game.actions.take_all_seconds(c)
		var all := _key("모두 담기", hud._loot_all.bind(String(at["id"])), true, KEY, MAIN_H)
		all.name = "MainKey"
		all.disabled = (c["items"] as Array).is_empty()
		var ink: Color = GlassPane.INK3 if all.disabled else GlassPane.AMBER_L
		_key_icon(hud, all, "pickup", 24.0, ink, -9.0)
		var total: Label = _key_word(all, "%.1f초" % seconds, 40.0, ink, 12.0, true)
		total.name = "TakeAll"
		return all
	if (at["kind"] == "train" or not game.sleds.is_empty()) and game.actions.at_unloading(p) and game.actions.has_load(p):
		# 결정 559: what is loaded is the train's — held to confirm.
		var load_key := _key("열차에 싣기", Callable(), true, KEY, MAIN_H)
		load_key.name = "MainKey"
		_key_icon(hud, load_key, "train", 24.0, GlassPane.AMBER_L, -9.0)
		_key_word(load_key, "싣기", 40.0, GlassPane.AMBER_L, 12.0)
		GlassPane.sinks(load_key, HoldConfirm.attach(load_key, hud._load_train.bind(hud.pane_era)), PRESS_SINK)
		return load_key
	return null


## The seconds left of what is coming out: this thing's own, and the rest of the
## box's while 모두 담기 runs.
static func take_left(game, p) -> float:
	var left: float = maxf(p.action_t, 0.0)
	var queue: Dictionary = game.actions.take_queue.get(p.get_instance_id(), {})
	for item in queue.get("left", []):
		left += SearchRules.take_seconds(String(item))
	return left
