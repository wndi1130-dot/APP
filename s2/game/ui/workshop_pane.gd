extends Control
## The workshop's pane (decision 426 PR 3): the same smoked glass as a
## carriage's pane (car_pane.gd), where it stands, when the bottom bar's 공방
## room is pressed. On it: the stores the workshop uses as their marks and
## numbers; the parts it keeps with their target and a key either side; the
## three things decision 070 lets it make, each with what it costs as marks and
## numbers and a key to put it on the line. The thing on the line shows how far
## along it is in its own row, and its key takes it back while the workshop has
## not touched it. A store that is short turns its number red (결정 417: no
## sentence for why).
##
## The rules are train_workshop.gd; the pane reads them, asks them and draws
## again. It changes the state it was given (the slice's own train state).

signal folded
signal changed

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")
const TrainWorkshop = preload("res://game/train/train_workshop.gd")
const GLASS := preload("res://game/ui/tex/pane_glass.png")

const CSS_SIZE := Vector2(330, 286)
## The stores and their marks (hud_icons.gd).
const STORES: Array = [["scrap", "it_nails"], ["wood", "it_plank"], ["parts", "gear"], ["cloth", "it_cloth"]]
const ICON: Dictionary = {"scrap": "it_nails", "wood": "it_plank", "parts": "gear", "cloth": "it_cloth"}
## Rows: the parts first, then decision 070's three (train_workshop.gd ORDER).
const ROW_TOP: float = 66.0
const ROW_H: float = 54.0
## A key: 44 tall (81 game px, over the 48 dp of field_hud.gd MIN_TOUCH).
const KEY_H: float = 44.0
const KEY_W: float = 84.0
const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)
const HAIR := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.16)
const WELL := Color(0, 0, 0, 0.6)
const ACCENT := Color("f2a63c")
const RED := Color("e2604b")
const SOOT_CUT := Color("10151a")

var g: Dictionary = {}
var _parts: Control


## What the pane says for state `g0` (tests read this; the pane draws it).
static func model(g0: Dictionary) -> Dictionary:
	var dom: Dictionary = g0.get("dom", {}) if g0.get("dom") is Dictionary else {}
	var stores: Array = []
	for row: Array in STORES:
		stores.append({"key": row[0], "icon": row[1], "n": float(dom.get(String(row[0]), 0))})
	var tgt: int = TrainWorkshop.target(g0) if not dom.is_empty() else TrainWorkshop.TARGET0
	var now: Dictionary = TrainWorkshop.now(g0)
	var rows: Array = []
	for id: String in TrainWorkshop.ORDER:
		var r: Dictionary = TrainWorkshop.RECIPES[id]
		var cost: Array = []
		var rc: Dictionary = r["cost"]
		for key: String in rc:
			cost.append({"key": key, "icon": ICON.get(key, ""), "n": float(rc[key]), "short": float(dom.get(key, 0)) < float(rc[key])})
		var on_line: bool = String(now["id"]) == id
		# How many the train holds: in the armory or the wardrobe, wherever the field put them too.
		var have: int = 0
		var held: Variant = dom.get("wardrobe" if String(r["to"]) == "wardrobe" else "armory")
		if held is Array:
			for it: Variant in held:
				if it is Dictionary and String((it as Dictionary).get("id", "")) == id:
					have += 1
		rows.append({
			"id": id, "name": String(r["name"]), "cost": cost, "on_line": on_line, "have": have,
			"share": float(now["share"]) if on_line else 0.0,
			"can_cancel": on_line and bool(now["can_cancel"]),
			"why": TrainWorkshop.why_not(g0, id),
		})
	return {
		"stores": stores,
		"parts": {"n": float(dom.get("parts", 0)), "target": tgt, "can_down": tgt > 0, "can_up": tgt < TrainWorkshop.TARGET_MAX,
			"cost": [{"key": "scrap", "icon": ICON["scrap"], "n": TrainWorkshop.PART_SCRAP, "short": float(dom.get("scrap", 0)) < TrainWorkshop.PART_SCRAP},
				{"key": "wood", "icon": ICON["wood"], "n": TrainWorkshop.PART_WOOD, "short": float(dom.get("wood", 0)) < TrainWorkshop.PART_WOOD}]},
		"rows": rows,
	}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var glass := TextureRect.new()
	glass.name = "Glass"
	glass.texture = GLASS
	glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glass.stretch_mode = TextureRect.STRETCH_SCALE
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(glass)
	_parts = Control.new()
	_parts.name = "Parts"
	_parts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_parts)
	_draw_all()


## At the right of the screen under a band `top` game px high (as car_pane.gd).
func pin(top: float) -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var s: Vector2 = CSS_SIZE * UiFonts.K
	offset_left = -s.x
	offset_right = 0.0
	offset_top = top
	offset_bottom = top + s.y


func show_state(g0: Dictionary) -> void:
	g = g0
	_draw_all()


func _draw_all() -> void:
	if _parts == null:
		return
	for c in _parts.get_children():
		_parts.remove_child(c)
		c.queue_free()
	if g.is_empty():
		return
	var m: Dictionary = model(g)
	_head()
	_stores(m["stores"])
	_parts_row(m["parts"], ROW_TOP)
	var rows: Array = m["rows"]
	for i in rows.size():
		_row(rows[i], ROW_TOP + ROW_H * (i + 1))


func _add(c: Control) -> Control:
	_parts.add_child(c)
	return c


func _text(l: Label, x_css: float, base_css: float) -> void:
	_add(l)
	GlassParts.put_on(l, x_css * UiFonts.K, base_css * UiFonts.K)


## 공방 at the name's place, 접기 at the top right (car_pane.gd _head).
func _head() -> void:
	var k: float = UiFonts.K
	var name_l := UiFonts.label("공방", UiFonts.WORD, 500, 18.0, INK, 2.16)
	name_l.name = "Name"
	_text(name_l, 44.0, 27.0)
	var fold := _bare("Fold")
	fold.position = Vector2(266.0, 0.0) * k
	fold.size = Vector2(56.0, 44.0) * k
	fold.pressed.connect(func() -> void: folded.emit())
	_add(fold)
	var mark := TextureRect.new()
	var px: int = int(round(14.0 * k))
	mark.texture = HudIcons.texture("fwd", px, INK2, 2.0, SOOT_CUT)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size = Vector2(px, px)
	mark.position = Vector2(36.0, 15.0) * k
	fold.add_child(mark)
	var word := UiFonts.label("접기", UiFonts.WORD, 400, 13.0, INK2, 1.3)
	fold.add_child(word)
	GlassParts.put_on(word, mark.position.x - 3.0 * k - GlassParts.text_w(word), 26.5 * k)


## The stores as marks and numbers across under the name.
func _stores(stores: Array) -> void:
	for i in stores.size():
		var s: Dictionary = stores[i]
		var x: float = 44.0 + 68.0 * i
		_add(_mark(String(s["icon"]), 18.0, Vector2(x, 39.0)))
		var n := UiFonts.label(_num(float(s["n"])), UiFonts.NUMBER, 500, 15.0, INK, 0.225)
		n.name = "Store_" + String(s["key"])
		_text(n, x + 22.0, 54.0)


## The parts: their number over the target, what one costs, − and + for the target.
func _parts_row(p: Dictionary, top: float) -> void:
	var k: float = UiFonts.K
	var word := UiFonts.label("부품", UiFonts.WORD, 500, 13.0, INK, 2.08)
	_text(word, 44.0, top + 18.0)
	var count := UiFonts.label("%s/%d" % [_num(float(p["n"])), int(p["target"])], UiFonts.NUMBER, 500, 15.0, INK, 0.225)
	count.name = "PartsCount"
	_text(count, (word.position.x + GlassParts.text_w(word)) / k + 10.0, top + 18.0)
	_cost(p["cost"], top + 40.0, "PartCost")
	var down := _key("−", "TargetDown", bool(p["can_down"]))
	_add(down)
	down.position = Vector2(224.0, top + 5.0) * k
	down.size = Vector2(KEY_H, KEY_H) * k
	down.pressed.connect(func() -> void:
		if not bool(p["can_down"]):
			UiDeny.shake(down)
			return
		TrainWorkshop.set_target(g, int(p["target"]) - 1)
		_after())
	var up := _key("+", "TargetUp", bool(p["can_up"]))
	_add(up)
	up.position = Vector2(272.0, top + 5.0) * k
	up.size = Vector2(KEY_H, KEY_H) * k
	up.pressed.connect(func() -> void:
		if not bool(p["can_up"]):
			UiDeny.shake(up)
			return
		TrainWorkshop.set_target(g, int(p["target"]) + 1)
		_after())


## A thing to make: its name; what it costs, or how far along it is on the
## line; its key (만들기, or 취소 on the line).
func _row(r: Dictionary, top: float) -> void:
	var k: float = UiFonts.K
	var id: String = String(r["id"])
	var word := UiFonts.label(String(r["name"]), UiFonts.WORD, 500, 13.0, INK, 2.08)
	word.name = "Name_" + id
	_text(word, 44.0, top + 18.0)
	if int(r["have"]) > 0:
		var have := UiFonts.label("×%d" % int(r["have"]), UiFonts.NUMBER, 500, 13.0, INK2, 0.52)
		have.name = "Have_" + id
		_text(have, (word.position.x + GlassParts.text_w(word)) / k + 8.0, top + 18.0)
	var on_line: bool = bool(r["on_line"])
	if on_line:
		var bar := Control.new()
		bar.name = "Progress_" + id
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.position = Vector2(44.0, top + 30.0) * k
		bar.size = Vector2(164.0, 6.0) * k
		var share: float = float(r["share"])
		bar.draw.connect(func() -> void:
			var rad: float = 3.0 * k
			GlassParts.round_rect(bar, Rect2(Vector2.ZERO, bar.size), rad, WELL)
			bar.draw_polyline(GlassParts.outline(Rect2(Vector2.ZERO, bar.size), rad), HAIR, 1.0 * k, true)
			var w: float = bar.size.x * share
			if w > 0.5:
				GlassParts.round_rect(bar, Rect2(0, 0, maxf(w, rad * 2.0), bar.size.y), rad, ACCENT))
		_add(bar)
	else:
		_cost(r["cost"], top + 40.0, "Cost_" + id)
	var can: bool = String(r["why"]) == "" or bool(r["can_cancel"])
	var key := _key("취소" if on_line else "만들기", "Key_" + id, can)
	_add(key)
	key.position = Vector2(232.0, top + 5.0) * k
	key.size = Vector2(KEY_W, KEY_H) * k
	key.tooltip_text = String(r["why"])
	key.pressed.connect(func() -> void:
		var ok: bool = TrainWorkshop.cancel(g) if on_line else TrainWorkshop.start(g, id)
		if not ok:
			UiDeny.shake(key)
			return
		_after())


## What a thing costs: each store's mark and number, red when short.
func _cost(cost: Array, base: float, prefix: String) -> void:
	var k: float = UiFonts.K
	var x: float = 44.0
	for c: Dictionary in cost:
		var short: bool = bool(c["short"])
		_add(_mark(String(c["icon"]), 15.0, Vector2(x, base - 13.0), RED if short else INK2))
		var n := UiFonts.label(_num(float(c["n"])), UiFonts.NUMBER, 400, 13.0, RED if short else INK2, 0.52)
		n.name = "%s_%s" % [prefix, c["key"]]
		_text(n, x + 19.0, base)
		x += 19.0 + GlassParts.text_w(n) / k + 12.0


func _after() -> void:
	_draw_all()
	changed.emit()


func _mark(icon: String, css: float, at: Vector2, color: Color = INK2) -> Control:
	var t := TextureRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon == "":
		return t
	var px: int = int(round(css * UiFonts.K))
	t.texture = HudIcons.texture(icon, px, color, 2.0, SOOT_CUT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size = Vector2(px, px)
	t.position = at * UiFonts.K
	return t


## A matte key with its word; dimmed when it cannot (a press then shakes it).
func _key(word: String, key_name: String, can: bool) -> Button:
	var k: float = UiFonts.K
	var b := _bare(key_name)
	b.draw.connect(func() -> void:
		var rect := Rect2(Vector2(1, 1) * k, b.size - Vector2(2, 2) * k)
		GlassParts.round_rect(b, rect, 8.0 * k, Color(1, 1, 1, 0.06))
		b.draw_polyline(GlassParts.outline(rect, 8.0 * k), HAIR, 1.5 * k, true))
	var lab := UiFonts.label(word, UiFonts.WORD, 500, 13.0, INK, 0.52)
	lab.name = "Word"
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	UiDeny.dim(b, not can)
	return b


func _bare(key_name: String) -> Button:
	var b := Button.new()
	b.name = key_name
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	return b


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
