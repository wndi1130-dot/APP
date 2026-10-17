extends RefCounted
## The type of the 「성에 낀 계기」 look (UI 3단계 시안 2차): IBM Plex Sans KR for
## words, Barlow Condensed for numbers (tabular, its Korean falling back to IBM
## Plex), Nanum Pen Script for what is written by hand on paper. The files are
## under fonts/ with their licences (SIL OFL 1.1). Sizes and letter spacing
## are given in the mockup's CSS px and turned into the game's here: the
## mockup's stage is 390 high, the game's 720.

## Mockup px → game px.
const K: float = 720.0 / 390.0
const DIR := "res://game/ui/fonts/"
const BODY: Dictionary = {400: "IBMPlexSansKR-Regular.ttf", 500: "IBMPlexSansKR-Medium.ttf", 600: "IBMPlexSansKR-SemiBold.ttf"}
const NUM: Dictionary = {400: "BarlowCondensed-Regular.ttf", 500: "BarlowCondensed-Medium.ttf", 600: "BarlowCondensed-SemiBold.ttf"}
const PEN := "NanumPenScript-Regular.ttf"

enum { WORD, NUMBER, HAND }

static var _files: Dictionary = {}
static var _made: Dictionary = {}


## A mockup length in game px.
static func px(css: float) -> float:
	return css * K


## A mockup font size in game px, whole.
static func size(css: float) -> int:
	return int(round(css * K))


static func _file(name: String) -> FontFile:
	if not _files.has(name):
		_files[name] = load(DIR + name)
	return _files[name]


## The face for `kind` at `weight` (400, 500, 600) with `spacing` (the
## mockup's letter-spacing in px) between letters.
static func face(kind: int = WORD, weight: int = 400, spacing: float = 0.0) -> Font:
	var w: int = 600 if weight >= 600 else (500 if weight >= 500 else 400)
	var key: String = "%d@%d@%.2f" % [kind, w, spacing]
	if not _made.has(key):
		var v := FontVariation.new()
		var word: FontFile = _file(BODY[w])
		match kind:
			NUMBER:
				v.base_font = _file(NUM[w])
				v.fallbacks = [word]
				var ts := TextServerManager.get_primary_interface()
				v.opentype_features = {ts.name_to_tag("tnum"): 1}
			HAND:
				v.base_font = _file(PEN)
				v.fallbacks = [word]
			_:
				v.base_font = word
		v.spacing_glyph = int(round(spacing * K))
		_made[key] = v
	return _made[key]


## A label as the mockup sets it: `css_px` and `spacing` in mockup px.
static func label(text: String, kind: int, weight: int, css_px: float, color: Color, spacing: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	style(l, kind, weight, css_px, color, spacing)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Give a Label or Button the mockup's face, size and colour.
static func style(c: Control, kind: int, weight: int, css_px: float, color: Color, spacing: float = 0.0) -> void:
	c.add_theme_font_override("font", face(kind, weight, spacing))
	c.add_theme_font_size_override("font_size", size(css_px))
	if c is Button:
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			c.add_theme_color_override(k, color)
	else:
		c.add_theme_color_override("font_color", color)
