extends Control
## The refit pane (decision 426 PR 4): the same smoked glass and keys as the
## workshop's pane (workshop_pane.gd), opened by the bottom bar's 개조 room.
## On it: the stores a refit uses; then one row a car the people live in, of
## the cars this train has now (the coordinator's PR 4 note: armour and the
## greenhouse come with their cars, PR 9). A row says what insulating that car
## gives and takes in numbers (S1 insulateNumbers) and its wood, red when
## short; or how far the workshop is with it; or, once done, what it now gets.
## Its key: 단열, or 취소 while the workshop has not touched the job (the wood
## comes back). A key that cannot is dimmed and shakes; why is its tooltip
## (결정 417: no sentence on the pane); while 단열 개조 is not researched the
## head names it by the research room's mark.
##
## The rules are train_mods.gd; the pane asks them and draws again. It changes
## the state it was given.

signal folded
signal changed

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")
const TrainMods = preload("res://game/train/train_mods.gd")
const TrainResearch = preload("res://game/train/train_research.gd")
const TrainRules = preload("res://game/train/train_rules.gd")
const GLASS := preload("res://game/ui/tex/pane_glass.png")

const CSS_W: float = 330.0
const CSS_H_MIN: float = 286.0
## No higher than the car's pane (the band to the bottom bar): more cars than
## fit are dragged up under the stores (glass_pane.gd scroll), as S1's
## thirteen-car train has seven lived-in cars.
const CSS_H_MAX: float = 286.0
const STORES: Array = [["scrap", "it_nails"], ["wood", "it_plank"], ["parts", "gear"], ["cloth", "it_cloth"]]
const ROW_TOP: float = 66.0
const ROW_H: float = 54.0
const KEY_H: float = 44.0
const KEY_W: float = 84.0
const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)
const HAIR := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.16)
const WELL := Color(0, 0, 0, 0.6)
const ACCENT := Color("f2a63c")
const RED := Color("e2604b")
const SOOT_CUT := Color("10151a")
const SHADE := Color("0b0e12")

var g: Dictionary = {}
## The cars of this train a refit can go on, in train order: {id, name}.
## Empty means the default train's (formation()).
var cars: Array = []
var _parts: Control
## Where a row's parts go while the rows are laid (the scrolled list), else the pane.
var _into: Control = null


## The cars of `rules` (train_rules.json's shape) that people live in.
static func formation(rules: Dictionary = {}) -> Array:
	var d: Dictionary = rules if not rules.is_empty() else TrainRules.load_default()
	var out: Array = []
	for car: Dictionary in d.get("cars", []):
		var id: String = String(car.get("id", ""))
		if TrainMods.CAR_COMM.has(id):
			out.append({"id": id, "name": String(car.get("name", TrainMods.CAR_NAME.get(id, id)))})
	return out


## What the pane says for state `g0` and these cars (tests read this; the pane draws it).
static func model(g0: Dictionary, cars0: Array = []) -> Dictionary:
	var dom: Dictionary = g0.get("dom", {}) if g0.get("dom") is Dictionary else {}
	var stores: Array = []
	for row: Array in STORES:
		stores.append({"key": row[0], "icon": row[1], "n": float(dom.get(String(row[0]), 0))})
	var job: Variant = dom.get("job")
	var rows: Array = []
	for car: Dictionary in (cars0 if not cars0.is_empty() else formation()):
		var id: String = String(car["id"])
		var done: bool = (dom.get("insulated", []) as Array).has(id)
		var on_line: bool = job is Dictionary and job.get("kind") == "insulate" and String(job.get("car", "")) == id
		var r := {"id": id, "car": id, "kind": "insulate", "name": String(car["name"]), "done": done, "on_line": on_line,
			"gain": TrainMods.insulate_numbers(id), "word": "", "can": false, "why": "", "share": 0.0,
			"cost": {"key": "wood", "icon": "it_plank", "n": float(TrainMods.D["insulateWood"]),
				"short": float(dom.get("wood", 0)) < float(TrainMods.D["insulateWood"])}}
		if on_line:
			r["share"] = float(job["progress"]) / maxf(1.0, float(job["need"]))
			r["word"] = "취소"
			r["can"] = TrainMods.cancel_open(g0)
			r["why"] = "" if r["can"] else "공방이 이미 손댔다"
		elif not done:
			var check: Dictionary = TrainMods.job_check(g0, "insulate", id)
			r["word"] = "단열"
			r["can"] = bool(check["ok"])
			r["why"] = String(check.get("why", ""))
		rows.append(r)
		if TrainMods.FURNISH_CARS.has(id):
			rows.append(_furnish_row(g0, car))
	# Insulating needs research's 단열 개조 (e5): while it does not work the keys are dim,
	# and the head says which technology (a phone has no tooltip).
	var need: String = "" if TrainResearch.usable(g0, {}, "e5") else String(TrainResearch.TECHS["e5"]["name"])
	return {"stores": stores, "rows": rows, "need": need}


static func _furnish_row(g0: Dictionary, car: Dictionary) -> Dictionary:
	var id: String = String(car["id"])
	var dom: Dictionary = g0.get("dom", {})
	var job: Variant = dom.get("job")
	var tier: int = int(TrainMods.furnish_of(g0, id)["tier"])
	var on_line: bool = job is Dictionary and job.get("kind") == "furnish" and job.get("car") == id
	var step: int = int(job["furnishStep"]) if on_line else TrainMods.next_furnish_work(g0, id)
	var cost: Dictionary = TrainMods.furnish_cost(step)
	var price: Array[String] = []
	for key: String in ["wood", "scrap", "cloth", "parts", "work"]:
		if float(cost.get(key, 0)) > 0.0:
			var word: String = {"wood": "목재", "scrap": "고철", "cloth": "천", "parts": "부품", "work": "일"}[key]
			price.append("%s %d" % [word, int(cost[key])])
	var check: Dictionary = TrainMods.job_check(g0, "furnish", id)
	var can: bool = TrainMods.cancel_open(g0) if on_line else bool(check["ok"])
	var why: String = ("" if can else "공방이 이미 손댔다") if on_line else String(check.get("why", ""))
	var tooltip: String = " · ".join(price)
	if why != "":
		tooltip += ("\n" if tooltip != "" else "") + why
	return {"id": "furnish_" + id, "car": id, "kind": "furnish", "name": String(car["name"]),
		"done": tier >= 3, "on_line": on_line, "gain": "살림 %d단 → %d단" % [tier, tier + 1] if tier < 3 else "살림 3단 · 북유럽식",
		"word": "취소" if on_line else ("살림" if tier < 3 else ""), "can": can, "why": tooltip,
		"share": float(job["progress"]) / maxf(1.0, float(job["need"])) if on_line else 0.0,
		"cost": {"key": "wood", "icon": "it_plank", "n": float(cost.get("wood", 0)), "short": float(dom.get("wood", 0)) < float(cost.get("wood", 0))}}


static func css_size(rows: int) -> Vector2:
	return Vector2(CSS_W, clampf(ROW_TOP + ROW_H * rows + 12.0, CSS_H_MIN, CSS_H_MAX))


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


## At the right of the screen under a band `top` game px high (as workshop_pane.gd).
func pin(top: float) -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var s: Vector2 = css_size((cars if not cars.is_empty() else formation()).size()) * UiFonts.K
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
	var m: Dictionary = model(g, cars)
	_head(String(m["need"]))
	_stores(m["stores"])
	var rows: Array = m["rows"]
	var k: float = UiFonts.K
	var list := Control.new()
	list.name = "Rows"
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	list.custom_minimum_size = Vector2(CSS_W, ROW_H * rows.size()) * k
	var s := ScrollContainer.new()
	s.name = "List"
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	s.position = Vector2(0.0, ROW_TOP) * k
	s.size = Vector2(CSS_W, css_size(rows.size()).y - ROW_TOP - 12.0) * k
	s.add_child(list)
	_parts.add_child(s)
	_into = list
	for i in rows.size():
		_row(rows[i], ROW_H * i)
	_into = null
	if list.custom_minimum_size.y > s.size.y + 0.5:
		_parts.add_child(_more(s))


## While rows are left under the list's foot, the glass darkens there (a fold
## of shade 22 high), so the cars below are known to be there to drag up.
func _more(s: ScrollContainer) -> Control:
	var k: float = UiFonts.K
	var fade := Control.new()
	fade.name = "More"
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.position = Vector2(0.0, s.position.y + s.size.y - 22.0 * k)
	fade.size = Vector2(s.size.x, 22.0 * k)
	fade.draw.connect(func() -> void:
		var w: float = fade.size.x
		var h: float = fade.size.y
		fade.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(SHADE, 0.0), Color(SHADE, 0.0), Color(SHADE, 0.85), Color(SHADE, 0.85)])))
	var bar: ScrollBar = s.get_v_scroll_bar()
	bar.value_changed.connect(func(v: float) -> void: fade.visible = v < bar.max_value - bar.page - 1.0)
	return fade


func _add(c: Control) -> Control:
	(_into if _into != null else _parts).add_child(c)
	return c


func _text(l: Label, x_css: float, base_css: float) -> void:
	_add(l)
	GlassParts.put_on(l, x_css * UiFonts.K, base_css * UiFonts.K)


## 개조 at the name's place, 접기 at the top right (workshop_pane.gd _head).
func _head(need: String) -> void:
	var k: float = UiFonts.K
	var name_l := UiFonts.label("개조", UiFonts.WORD, 500, 18.0, INK, 2.16)
	name_l.name = "Name"
	_text(name_l, 44.0, 27.0)
	if need != "":
		# The research room's mark and the technology it waits for.
		var x: float = (name_l.position.x + GlassParts.text_w(name_l)) / k + 14.0
		_add(_mark("papers", 15.0, Vector2(x, 14.0), ACCENT))
		var n := UiFonts.label(need, UiFonts.WORD, 400, 13.0, ACCENT, 0.52)
		n.name = "Need"
		_text(n, x + 19.0, 27.0)
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


func _stores(stores: Array) -> void:
	for i in stores.size():
		var s: Dictionary = stores[i]
		var x: float = 44.0 + 62.0 * i
		_add(_mark(String(s["icon"]), 18.0, Vector2(x, 39.0)))
		var n := UiFonts.label(_num(float(s["n"])), UiFonts.NUMBER, 500, 15.0, INK, 0.225)
		n.name = "Store_" + String(s["key"])
		_text(n, x + 22.0, 54.0)


## A car: its name and the wood insulating it takes; what it gives, how far
## the workshop is with it, or what it gets now; its key.
func _row(r: Dictionary, top: float) -> void:
	var k: float = UiFonts.K
	var id: String = String(r["id"])
	var word := UiFonts.label(String(r["name"]), UiFonts.WORD, 500, 13.0, INK, 2.08)
	word.name = "Name_" + id
	_text(word, 44.0, top + 18.0)
	var done: bool = bool(r["done"])
	if not done and not bool(r["on_line"]):
		var c: Dictionary = r["cost"]
		var x: float = (word.position.x + GlassParts.text_w(word)) / k + 12.0
		var short: bool = bool(c["short"])
		_add(_mark(String(c["icon"]), 15.0, Vector2(x, top + 5.0), RED if short else INK2))
		var n := UiFonts.label(_num(float(c["n"])), UiFonts.NUMBER, 400, 13.0, RED if short else INK2, 0.52)
		n.name = "Cost_%s_%s" % [id, c["key"]]
		_text(n, x + 19.0, top + 18.0)
	if bool(r["on_line"]):
		_bar(id, float(r["share"]), top)
	else:
		if done:
			_add(_mark("check", 13.0, Vector2(44.0, top + 28.0), INK2))
		var said := UiFonts.label(String(r["gain"]), UiFonts.WORD, 400, 12.0, INK2, 0.52)
		said.name = "Gain_" + id
		_text(said, 62.0 if done else 44.0, top + 40.0)
	if String(r["word"]) == "":
		return
	var key := _key(String(r["word"]), "Key_" + id, bool(r["can"]))
	_add(key)
	key.position = Vector2(232.0, top + 5.0) * k
	key.size = Vector2(KEY_W, KEY_H) * k
	key.tooltip_text = String(r["why"])
	key.pressed.connect(func() -> void:
		var ok: bool = TrainMods.cancel_job(g) if bool(r["on_line"]) else TrainMods.start_job(g, String(r["kind"]), String(r["car"]))
		if not ok:
			UiDeny.shake(key)
			return
		_after())


func _bar(id: String, share: float, top: float) -> void:
	var k: float = UiFonts.K
	var bar := Control.new()
	bar.name = "Progress_" + id
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(44.0, top + 30.0) * k
	bar.size = Vector2(164.0, 6.0) * k
	bar.draw.connect(func() -> void:
		var rad: float = 3.0 * k
		GlassParts.round_rect(bar, Rect2(Vector2.ZERO, bar.size), rad, WELL)
		bar.draw_polyline(GlassParts.outline(Rect2(Vector2.ZERO, bar.size), rad), HAIR, 1.0 * k, true)
		var w: float = bar.size.x * share
		if w > 0.5:
			GlassParts.round_rect(bar, Rect2(0, 0, maxf(w, rad * 2.0), bar.size.y), rad, ACCENT))
	_add(bar)


func _after() -> void:
	_draw_all()
	changed.emit()


func _mark(icon: String, css: float, at: Vector2, color: Color = INK2) -> Control:
	var t := TextureRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
