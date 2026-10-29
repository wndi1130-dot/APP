extends Control
## A train-turn card on paper (UI 3단계 시안 2차 「사건 카드」, k3b_views.js vCard,
## c2·c6·c11 .cd__* · .sayb, B1): the sheet comes in from the left as the
## stop's does (paper_sheet.gd at (−10, 50), 446 × 346, −0.45°). On it, at the
## top, who brings the card — the ink bust on its own scrap of paper, or the
## papers mark for a report — the title in pen, the name underlined and what
## they are, and what has happened in pen; at the foot, numbered, what the
## captain says, each over what it costs now: the stores as their marks and
## numbers, the rest in words, support in blue and grudge in red (decisions.md
## 256), 「지금 드는 값 없음」 when nothing. A way that cannot be paid is dimmed,
## says why in the seal's brown and shakes. A way that leaves a person behind is
## a black stone: the first press arms it, the second says it. How many papers
## wait (「1/3」) and a witness's mark sit at the title's right, with no kick
## line and no 「서류」 or 「지켜보는 사람 있음」 words (결정 417). As the field's
## decision card (field_hud.gd card), the scene is in pen, in print when pen
## would not fit over the ways, and never pushes them off the sheet; when print
## would not fit either, the paper is cut wider (the leave strip's 「cut to its
## lines」), up to WIDE. The sheet shows once it has settled. Folded to the left
## (결정 508) only its right edge stays in sight and a press there opens it
## again, never a way under it; a new card comes open.
##
## The words are S1's (turn/turn_card_text.gd); the card only reads. A press
## hands on the state train_advance.gd choose_card gives back as `chose`, a
## 「_turn_port_error」 as it is; the state it was given is not changed. A kind
## the train turn does not draw yet is not drawn: `chose` carries choose_card's
## error at once. Measured part by part (the mockup's px × ui_fonts.gd K).

signal chose(g: Dictionary)
signal fold_changed(folded: bool)

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")
const Paper = preload("res://game/ui/paper_parts.gd")
const PaperSheet = preload("res://game/ui/paper_sheet.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const CouncilCard = preload("res://game/ui/council_card.gd")
const CardText = preload("res://game/train/turn/turn_card_text.gd")
const Advance = preload("res://game/train/train_advance.gd")
const BUSTS := preload("res://game/ui/tex/busts.png")
const PAPER_TEX := preload("res://game/ui/tex/paper.png")

## Where the mockup lays the sheet on its 844 × 390 stage.
const SHEET_AT := Vector2(-10, 50)
## .cd__por 80 × 96, 4 down, 14 to the words (.cd__top gap).
const POR := Vector2(80, 96)
const POR_GAP: float = 14.0
## .sayb: 55 high at least, padded 7 · 6 · 6 · 4; the number's column 22 and 4 to the words.
const SAY_H: float = 55.0
const NUM_W: float = 26.0
## .scene: pen 18 or print 13.5, on lines of 20; the title in pen 36 on lines of 30.
const SCENE_LINE: float = 20.0
const TITLE_LINE: float = 30.0
## How much wider the paper is cut at a time, and at the most: the car the
## card is about still shows at the right of the 844 stage.
const WIDEN: float = 47.0
const WIDE: float = 540.0
## Frames a layout takes to settle (wrapped words find their lines).
const SETTLE: int = 2
## Folded, the paper keeps TAB of its right edge in sight (≈110 px on the 720-high
## view, 결정 508). Its fold key is the right margin (PaperSheet.INSET_R) for
## FOLD_KEY_H, level with the title; it slides either way in FOLD_S.
const TAB: float = 60.0
const FOLD_KEY_H: float = 56.0
const FOLD_S: float = 0.22
## Opened again, the paper still takes presses as the open key this much longer (s):
## a second tap of a double tap opens nothing more, never a way that came under it.
const OPEN_GUARD: float = 0.15
## The black stone (.sayb>s): 13 across, 8 in from the right and 13 down.
const STONE_AT := Vector2(14.5, 19.5)
## Ways that leave someone behind take two presses (k3b_views.js 「무거운 선택지」).
const HEAVY_IDS: Array[String] = ["leave", "leave_law"]
## What the top band shows reads as its mark and number (the stores, trust,
## tension); the rest in words (k3b_views.js 「위 띠에 있는 수는 그림과 수로」).
const MARKED: Array[String] = ["coal", "food", "med", "lux", "trust", "tension"]
## .p--y · .p--n, the armed way's amber wash, the rule over a way, the
## dot between costs (c6.css) and 「한 번 더 눌러 확정」's brown (c2.css).
const BLUE := Color("2a6a96")
const RED := Color("a8361f")
const ARMED := Color(242 / 255.0, 166 / 255.0, 60 / 255.0, 0.24)
const DOWN := Color(42 / 255.0, 32 / 255.0, 24 / 255.0, 0.07)
const DOT := Color(42 / 255.0, 32 / 255.0, 24 / 255.0, 0.4)
const CONFIRM := Color("8a4a0a")
const PAPER := Color("cdc2a8")
const STONE := [Color("6a5644"), Color("2c2119"), Color("120c08")]

var g: Dictionary = {}
var t: Dictionary = {}
## The card to show; −1 is the first in the pile.
var uid: int = -1
var sheet: Control
var body: VBoxContainer
var _armed: int = -1
## The widest the holder lets the paper be, mockup px (0: as drawn, cut wider up to
## WIDE): on a narrow screen it stops short of what stands at its right, and the
## words wrap to it.
var fit_w: float = 0.0
## The paper's width in mockup px, and frames left before the fit is looked at.
var _w: float = PaperSheet.SIZE.x
var _settle: int = 0
## Folded off to the left with only TAB of it in sight.
var folded: bool = false
var _fold_tween: Tween
var _opening: bool = false


## What the card says for card `uid0` in state `g0` (tests read this; the card
## draws it). {} when there is no such card or its kind is not drawn yet.
static func model(g0: Dictionary, t0: Dictionary, uid0: int = -1) -> Dictionary:
	var card: Dictionary = _card(g0, uid0)
	if card.is_empty():
		return {}
	var v: Dictionary = CardText.view(g0, t0, card)
	if v.is_empty():
		return {}
	var sp: Variant = v["speaker"]
	var bust: int = -1
	var name: String = ""
	var role: String = ""
	if sp is Dictionary:
		name = String(sp["name"])
		role = String(sp["role"])
		bust = CouncilCard.bust_of(g0["comms"][sp["comm"]]["leader"] if sp.has("comm") else {"name": name})
	var cards: Array = g0["cards"]
	var choices: Array = []
	var witness: bool = false
	for i: int in (v["choices"] as Array).size():
		var ch: Dictionary = v["choices"][i]
		witness = witness or bool(ch.get("witness", false))
		var say: String = String(ch["say"])
		var why: String = UiFonts.josa(String(ch["why"]))
		var fx: Array = effects(t0, ch)
		# A why that says what it costs stands for 「지금 드는 값 없음」.
		if why != "" and String(fx[0]["tone"]) == "none":
			fx = []
		choices.append({
			"n": i + 1, "id": String(ch["id"]),
			"say": UiFonts.josa(say if say != "" else String(ch["label"])),
			"effects": fx, "off": String(ch["disabled"]), "why": why,
			"heavy": HEAVY_IDS.has(String(ch["id"])),
		})
	return {"uid": int(card["uid"]), "at": cards.find(card) + 1, "count": cards.size(), "witness": witness,
		"title": UiFonts.josa(String(v["title"])), "name": name, "role": role, "bust": bust,
		"body": UiFonts.josa(String(v["body"])), "choices": choices}


## What a way costs now, as the line under it reads, in the order S1 lists
## it: what the top band shows as its mark and number ({icon, text, tone ""}),
## the other costs and the politics in S1's words (tone "" ink, "blue" support,
## "red" grudge, "gray" fear); 「지금 드는 값 없음」 (tone "none") when it costs
## nothing now (the mockup's 「숨겨 준다」).
static func effects(t0: Dictionary, choice: Dictionary) -> Array:
	var out: Array = []
	for e: Array in choice["effs"]:
		if MARKED.has(String(e[0])):
			out.append({"icon": e[0], "text": CardText.sign_of(float(e[1])), "tone": ""})
			continue
		for line: String in CardText.cost_lines(t0, {"effs": [e]}):
			out.append({"icon": "", "text": line, "tone": ""})
		for p: Dictionary in CardText.politics_lines(t0, {"effs": [e]}):
			out.append({"icon": "", "text": String(p["text"]), "tone": String(p["tone"])})
	# What it costs that is no effect (S1 costLines' extra: wood and scrap, coal a stretch).
	for line: String in CardText.cost_lines(t0, {"effs": [], "extra": choice.get("extra", [])}):
		out.append({"icon": "", "text": line, "tone": ""})
	if out.is_empty():
		out.append({"icon": "", "text": "지금 드는 값 없음", "tone": "none"})
	return out


static func _card(g0: Dictionary, uid0: int) -> Dictionary:
	var cards: Array = g0.get("cards", []) if g0.get("cards") is Array else []
	for c: Dictionary in cards:
		if uid0 < 0 or int(c["uid"]) == uid0:
			return c
	return {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_fill()


## Show card `uid0` of state `g0` (the first when −1).
func show_card(g0: Dictionary, t0: Dictionary, uid0: int = -1) -> void:
	g = g0
	t = t0
	uid = uid0
	_armed = -1
	folded = false
	_opening = false
	if _fold_tween != null:
		_fold_tween.kill()
	_w = PaperSheet.SIZE.x if fit_w <= 0.0 else minf(PaperSheet.SIZE.x, fit_w)
	_fill()
	if sheet != null:
		sheet.position = _lie()
		_mark_fold()


## Fold the paper off to the left with its edge left in sight (결정 508), or open it again.
func set_folded(on: bool) -> void:
	if on == folded:
		return
	folded = on
	_opening = false
	if on and _armed >= 0:
		# A heavy way armed before the fold is not left armed under the edge.
		_armed = -1
		_fill()
	if sheet != null:
		_opening = not on
		_mark_fold()
		if _fold_tween != null:
			_fold_tween.kill()
		_fold_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_fold_tween.tween_property(sheet, "position", _lie(), FOLD_S)
		if _opening:
			_fold_tween.tween_interval(OPEN_GUARD)
			_fold_tween.tween_callback(_opened)
	fold_changed.emit(folded)


## Lain open: the ways take their presses again.
func _opened() -> void:
	_opening = false
	if sheet != null:
		_mark_fold()


## The right edge a folded paper leaves in sight, in the view's px.
func folded_edge() -> float:
	return global_position.x + TAB * UiFonts.K


## Where the sheet lies: as the mockup lays it, or folded with TAB of it in sight.
func _lie() -> Vector2:
	var at := SHEET_AT * UiFonts.K
	if folded:
		at.x = (TAB - _w) * UiFonts.K
	return at


## Folded, the edge in sight is bare paper with its mark: no cut-off words on it.
func _mark_fold() -> void:
	(sheet.get_node("Open") as Control).visible = folded or _opening
	(sheet.get_node("Fold") as Control).queue_redraw()
	(sheet as PaperSheet).inner.visible = not folded


## The paper `_w` wide, new when its width changes.
func _sheet() -> void:
	if sheet != null and is_equal_approx(sheet.size.x, _w * UiFonts.K):
		return
	if sheet != null:
		# A new sheet lies where the fold has it; no slide is left on the old one.
		if _fold_tween != null:
			_fold_tween.kill()
		_opening = false
		remove_child(sheet)
		sheet.queue_free()
	var paper = PaperSheet.new(Vector2(_w, PaperSheet.SIZE.y))
	paper.name = "Sheet"
	paper.position = _lie()
	sheet = paper
	add_child(paper)
	body = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.inner.add_child(body)
	paper.add_child(_fold_key(paper))
	paper.add_child(_open_key())
	_mark_fold()


## The fold key in the paper's right margin, level with the title: 「‹」 open, 「›」 folded.
func _fold_key(paper: Control) -> Button:
	var k: float = UiFonts.K
	var key := Button.new()
	key.name = "Fold"
	key.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
		key.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	key.position = Vector2(paper.size.x - PaperSheet.INSET_R * k, 0.0)
	key.size = Vector2(PaperSheet.INSET_R, FOLD_KEY_H) * k
	key.draw.connect(func() -> void:
		var px: float = 16.0 * k
		var mark := HudIcons.texture("fwd" if folded else "back", int(round(px)), Paper.INK2, 2.2, HudIcons.CUT_PAPER)
		key.draw_texture_rect(mark, Rect2((key.size - Vector2(px, px)) * 0.5, Vector2(px, px)), false))
	key.pressed.connect(set_folded.bind(true))
	return key


## Folded, the whole paper is one key that opens it: over all else on the sheet, so a
## press on the edge in sight never reaches a way or its black stone.
func _open_key() -> Button:
	var key := Button.new()
	key.name = "Open"
	key.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
		key.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	key.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	key.visible = folded
	key.pressed.connect(set_folded.bind(false))
	return key


func _fill() -> void:
	if not is_inside_tree():
		return
	_sheet()
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	var card: Dictionary = _card(g, uid)
	var m: Dictionary = model(g, t, uid)
	sheet.visible = not m.is_empty()
	if card.is_empty():
		return
	if m.is_empty():
		# Not drawn yet: whoever holds the state gets choose_card's own answer.
		call_deferred("emit_signal", "chose", Advance.choose_card(g, t, int(card["uid"]), 0))
		return
	_top(m)
	for ch: Dictionary in m["choices"]:
		body.add_child(_say(ch, int(m["uid"])))
	sheet.modulate.a = 0.0
	_settle = SETTLE
	set_process(true)


## Once laid out: pen that does not fit over the ways goes to print; print that
## does not fit cuts the paper wider; then the sheet shows.
func _process(_delta: float) -> void:
	_settle -= 1
	if _settle > 0:
		return
	set_process(false)
	for why: Node in body.find_children("Why", "Label", true, false):
		if why.has_meta("dot"):
			(why.get_meta("dot") as Control).visible = (why as Control).position.y < UiFonts.px(9.0)
	var said := body.find_child("Said", true, false) as Control
	var scene := body.find_child("Scene", true, false) as Label
	if said != null and scene.get_combined_minimum_size().y > said.size.y + 0.5:
		if not scene.has_meta("print"):
			scene.set_meta("print", true)
			UiFonts.style(scene, UiFonts.WORD, 400, 13.5, Paper.INK)
			_space(scene, SCENE_LINE)
			_settle = SETTLE
			set_process(true)
			return
		var widest: float = WIDE if fit_w <= 0.0 else minf(WIDE, fit_w)
		if _w < widest:
			_w = minf(widest, _w + WIDEN)
			_fill()
			return
	sheet.modulate.a = 1.0


## Who brings it and what has happened (.cd__top: the portrait, 14 to the
## words; the title in pen 36 on a 30 line with how many papers wait and a
## witness's mark at its right, the name 14/500 underlined · what they are 12
## on a 20 line, 3 under it the scene). It takes what the ways leave.
func _top(m: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "Top"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(round(UiFonts.px(POR_GAP))))
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	row.add_child(_portrait(int(m["bust"])))
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var head := HBoxContainer.new()
	head.name = "Head"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", int(round(UiFonts.px(6.0))))
	words.add_child(head)
	var title := _lines(String(m["title"]), UiFonts.HAND, 36.0, TITLE_LINE)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if int(m["count"]) > 1:
		var n := Paper.ink("%d/%d" % [int(m["at"]), int(m["count"])], UiFonts.NUMBER, 400, 14.0, Paper.INK2, 0.56)
		n.name = "Count"
		n.custom_minimum_size = Vector2(0, UiFonts.px(TITLE_LINE))
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		head.add_child(n)
	if bool(m["witness"]):
		var w := Paper.mark("witness", 14.0)
		w.name = "Witness"
		w.custom_minimum_size.y = UiFonts.px(TITLE_LINE)
		w.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		head.add_child(w)
	if String(m["name"]) != "":
		var who := Paper.line_box(23.0)
		who.name = "Who"
		var nm := Paper.name_word(String(m["name"]), 14.0, Paper.INK)
		nm.name = "Name"
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		who.add_child(nm)
		if String(m["role"]) != "":
			var role := Paper.ink(" · " + String(m["role"]), UiFonts.WORD, 400, 12.0, Paper.INK2, 0.72)
			role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			who.add_child(role)
		words.add_child(who)
	var said := ScrollContainer.new()
	said.name = "Said"
	said.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	said.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	said.size_flags_vertical = Control.SIZE_EXPAND_FILL
	said.mouse_filter = Control.MOUSE_FILTER_PASS
	words.add_child(said)
	var scene := _lines(String(m["body"]), UiFonts.HAND, 18.0, SCENE_LINE)
	scene.name = "Scene"
	scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	said.add_child(scene)


## Ink wrapping between words on lines of `line_css` (a face taller than its
## line keeps to the line, as CSS's does; field_hud.gd _ink_lines).
func _lines(text: String, kind: int, css_px: float, line_css: float) -> Label:
	var l := Paper.ink(UiFonts.keep_all(text), kind, 400, css_px)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_space(l, line_css)
	return l


func _space(l: Label, line_css: float) -> void:
	var natural: float = l.get_theme_font("font").get_height(l.get_theme_font_size("font_size"))
	l.add_theme_constant_override("line_spacing", int(round(UiFonts.px(line_css) - natural)))


## The bust on its scrap of paper (.cd__por), or the papers mark for a report.
func _portrait(kind: int) -> Control:
	var k: float = UiFonts.K
	var p := Control.new()
	p.name = "Portrait"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = (POR + Vector2(0, 4)) * k
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p.set_meta("bust", kind)
	p.draw.connect(func() -> void:
		var r := Rect2(Vector2(0, 4.0 * k), POR * k)
		GlassParts.shadow(p, r, 0.0, 2.0 * k, 2.0 * k, Color(0, 0, 0, 0.5))
		p.draw_rect(r, PAPER)
		var tile: float = 240.0 * k
		p.draw_texture_rect_region(PAPER_TEX, r, Rect2(Vector2.ZERO, r.size / tile * Vector2(PAPER_TEX.get_size())))
		if kind >= 0:
			p.draw_texture_rect_region(BUSTS, r, Rect2(float(kind) * 92.0, 0.0, 92.0, 112.0))
		else:
			var px: float = 34.0 * k
			p.draw_texture_rect(HudIcons.texture("papers", int(round(px)), Paper.INK2, 2.0, HudIcons.CUT_PAPER), Rect2(r.get_center() - Vector2(px, px) * 0.5, Vector2(px, px)), false))
	return p


## One way (.sayb): its number, 「what the captain says」, under it what it
## costs now, a rule over it; a black stone at the right of a heavy one. The
## whole row is the key.
func _say(ch: Dictionary, at: int) -> Control:
	var k: float = UiFonts.K
	var i: int = int(ch["n"]) - 1
	var armed: bool = _armed == i
	var heavy: bool = bool(ch["heavy"])
	var row := PanelContainer.new()
	row.name = "Say_%d" % int(ch["n"])
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, SAY_H * k)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ARMED if armed else Color(0, 0, 0, 0)
	sb.border_color = Paper.TRACK
	sb.border_width_top = int(round(2.0 * k))
	row.add_theme_stylebox_override("panel", sb)
	var pad := MarginContainer.new()
	pad.name = "Pad"
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", int(round(4.0 * k)))
	pad.add_theme_constant_override("margin_right", int(round((26.0 if heavy else 6.0) * k)))
	pad.add_theme_constant_override("margin_top", int(round(7.0 * k)))
	pad.add_theme_constant_override("margin_bottom", int(round(6.0 * k)))
	row.add_child(pad)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 0)
	pad.add_child(line)
	var n := Paper.ink(str(int(ch["n"])), UiFonts.NUMBER, 600, 21.0, Paper.INK2)
	n.custom_minimum_size = Vector2(NUM_W * k, 22.0 * k)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(n)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(col)
	var wide: float = UiFonts.px(_w - PaperSheet.INSET_L - PaperSheet.INSET_R - 4.0 - NUM_W - (26.0 if heavy else 6.0))
	var q := Paper.ink(UiFonts.keep_all("「%s」" % String(ch["say"])), UiFonts.WORD, 500, 14.0)
	q.name = "Quote"
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size = Vector2(wide, 22.0 * k)
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	col.add_child(q)
	col.add_child(_costs(ch, armed, wide))
	var key := Button.new()
	key.name = "Key_%d" % int(ch["n"])
	key.focus_mode = Control.FOCUS_NONE
	key.tooltip_text = String(ch["off"])
	for state in ["normal", "hover", "focus", "disabled"]:
		key.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var down := StyleBoxFlat.new()
	down.bg_color = DOWN
	for state in ["pressed", "hover_pressed"]:
		key.add_theme_stylebox_override(state, down)
	key.draw.connect(func() -> void:
		if armed:
			key.draw_rect(Rect2(0, 0, 3.0 * k, key.size.y), Paper.AMBER)
		if heavy:
			var c := Vector2(key.size.x - STONE_AT.x * k, STONE_AT.y * k)
			if armed:
				key.draw_circle(c, 13.0 * k, Color(Paper.AMBER, 0.18), true, -1.0, true)
				key.draw_circle(c, 9.5 * k, Color(Paper.AMBER, 0.55), true, -1.0, true)
			key.draw_circle(c + Vector2(0, 1.0 * k), 7.0 * k, Color(0, 0, 0, 0.35), true, -1.0, true)
			key.draw_circle(c, 6.5 * k, STONE[2], true, -1.0, true)
			key.draw_circle(c - Vector2(0.4, 0.6) * k, 5.2 * k, STONE[1], true, -1.0, true)
			key.draw_circle(c - Vector2(1.6, 2.3) * k, 2.2 * k, STONE[0], true, -1.0, true))
	key.pressed.connect(func() -> void: _press(i, at, pad, ch))
	row.add_child(key)
	if String(ch["off"]) != "":
		UiDeny.dim(pad, true)
	return row


## The line under a way: the stores' marks and numbers, then words, a faint
## dot between, then what else it does (S1's 까닭, with no 「까닭」 word: 결정
## 417), on a line of its own when it does not fit; a shut way's why in the
## seal's brown; armed, 「한 번 더 눌러 확정」.
func _costs(ch: Dictionary, armed: bool, wide: float) -> Control:
	var k: float = UiFonts.K
	var flow := HFlowContainer.new()
	flow.name = "Costs"
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.custom_minimum_size = Vector2(0, 18.0 * k)
	flow.add_theme_constant_override("h_separation", 0)
	flow.add_theme_constant_override("v_separation", 0)
	var parts: Array = ch["effects"]
	for j: int in parts.size():
		var e: Dictionary = parts[j]
		if j > 0:
			flow.add_child(_small(" · ", 400, DOT))
		if String(e["icon"]) != "":
			var cell := HBoxContainer.new()
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_theme_constant_override("separation", int(round(2.0 * k)))
			cell.add_child(Paper.mark(String(e["icon"]), 14.0, Paper.INK, 2.2))
			var num := Paper.ink(String(e["text"]), UiFonts.NUMBER, 600, 14.0)
			num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.add_child(num)
			flow.add_child(cell)
		else:
			var tone: String = String(e["tone"])
			var pol: bool = tone == "blue" or tone == "red"
			flow.add_child(_small(String(e["text"]), 500 if pol else 400, BLUE if tone == "blue" else (RED if tone == "red" else Paper.INK2)))
	if String(ch["why"]) != "":
		var why := _small(UiFonts.keep_all(String(ch["why"])), 400, Paper.INK2)
		why.name = "Why"
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size.x = minf(wide, why.get_theme_font("font").get_string_size(why.text, HORIZONTAL_ALIGNMENT_LEFT, -1, why.get_theme_font_size("font_size")).x + 1.0)
		if not parts.is_empty():
			# The dot goes when the why starts a line of its own.
			var dot := _small(" · ", 400, DOT)
			flow.add_child(dot)
			why.set_meta("dot", dot)
		flow.add_child(why)
	if String(ch["off"]) != "":
		var off := _small("  " + String(ch["off"]), 600, Paper.SEAL)
		off.name = "Off"
		flow.add_child(off)
	if armed:
		var em := Paper.ink("  한 번 더 눌러 확정", UiFonts.WORD, 500, 12.0, CONFIRM, 0.96)
		em.name = "Confirm"
		em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		flow.add_child(em)
	return flow


func _small(text: String, weight: int, color: Color) -> Label:
	var l := Paper.ink(text, UiFonts.WORD, weight, 12.0, color, 0.36)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.custom_minimum_size = Vector2(0, UiFonts.px(18.0))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## A press: a shut way shakes; a heavy way arms first; otherwise the card is
## answered through the train's own rule.
func _press(i: int, at: int, pad: Control, ch: Dictionary) -> void:
	if String(ch["off"]) != "":
		UiDeny.shake(pad)
		return
	if bool(ch["heavy"]) and _armed != i:
		_armed = i
		_fill()
		return
	_armed = -1
	chose.emit(Advance.choose_card(g, t, at, i))
