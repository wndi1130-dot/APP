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
const WORD_JOINER := "\u2060"
## [two-way, after a final consonant, after none] (josa).
const PARTICLES: Array = [["\uacfc(\uc640)", "\uacfc", "\uc640"], ["\uc744(\ub97c)", "\uc744", "\ub97c"], ["\uc774(\uac00)", "\uc774", "\uac00"], ["\uc740(\ub294)", "\uc740", "\ub294"], ["(\uc73c)\ub85c", "\uc73c\ub85c", "\ub85c"]]
## \uc601 \uc77c \uc774 \uc0bc \uc0ac \uc624 \uc721 \uce60 \ud314 \uad6c: each one's final consonant (\u3147 21, \u3139 8, \u3141 16, \u3131 1).
const DIGIT_TAIL: Array = [21, 8, 0, 16, 0, 0, 1, 8, 8, 0]

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


## `text` to wrap as the mockup wraps Korean (word-break: keep-all), between
## words only: Godot's lines break between any two Hangul letters, so a word
## joiner (U+2060, no width) goes between each two letters of a word.
static func keep_all(text: String) -> String:
	var out := PackedStringArray()
	var n: int = text.length()
	for i in n:
		var c: String = text[i]
		out.append(c)
		if i + 1 < n and c != " " and c != "\n" and text[i + 1] != " " and text[i + 1] != "\n":
			out.append(WORD_JOINER)
	return "".join(out)


## `text` with the port's two-way particles (「과(와)」, 「을(를)」, 「이(가)」,
## 「은(는)」, 「(으)로」) settled by the letter before them as written Korean
## has it: 과·을·이·은·으로 after a final consonant, 와·를·가·는·로 after none,
## and 로 after ㄹ. A digit is read as its Korean number; after anything else
## the two-way form stays. After a closing bracket it goes by the word before
## the bracket, which only adds to that word: 「블라스타(기관실)가」.
static func josa(text: String) -> String:
	var out: String = text
	for p: Array in PARTICLES:
		var both: String = p[0]
		var at: int = out.find(both)
		while at >= 0:
			var end: int = _word_end(out, at - 1)
			var tail: int = _tail(out.unicode_at(end)) if end >= 0 else -1
			var pick: String = both
			if tail == 0 or (tail == 8 and both == "(으)로"):
				pick = p[2]
			elif tail > 0:
				pick = p[1]
			out = out.substr(0, at) + pick + out.substr(at + both.length())
			at = out.find(both, at + pick.length())
	return out


## Where the word a particle settles by ends: `i` itself, or, when `i` is a
## closing bracket, the letter before its opening one — past every bracket when
## brackets follow one another (-1 when one has no opening bracket).
static func _word_end(text: String, i: int) -> int:
	while i >= 0 and text[i] == ")":
		var depth: int = 0
		var open: int = -1
		while i >= 0:
			if text[i] == ")":
				depth += 1
			elif text[i] == "(":
				depth -= 1
				if depth == 0:
					open = i
					break
			i -= 1
		if open < 0:
			return -1
		i = open - 1
	return i


## The final consonant of a letter (0 for none, 8 for ㄹ), -1 when it is not
## a Hangul syllable or a digit.
static func _tail(code: int) -> int:
	if code >= 0xAC00 and code <= 0xD7A3:
		return (code - 0xAC00) % 28
	if code >= 0x30 and code <= 0x39:
		return DIGIT_TAIL[code - 0x30]
	return -1


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
