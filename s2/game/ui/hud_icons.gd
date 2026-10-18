extends RefCounted
## The icons of the 「성에 낀 계기」 look, path for path the mockup's own (UI 3단계
## 시안 2차 `_src4\k2_parts.js` ICD, the field's in `k3e_views.js`, the top band's
## 2판 in `k3g_fx.js`): a 24 grid, a 2px line with round ends and joins, a faint
## fill (".t", 16%) where a shape is solid and a full one for a dot (".f"). The
## top band's six (불만 · 지지 · 석탄 · 식량 · 의약품 · 사치품) are the 2판: a solid
## shape (".f") with lines cut back in the colour of what it sits on (".c",
## 1.25px). Kept as text and drawn at the size asked for, so there is no import
## step and the phone shows what the tests see. No cross, crescent, star,
## banner, lock or bag among them (med is a bottle and a bandage roll, aim has
## its ticks on one axis only, inv is a grid, fetch a box with no handle).
## Every line is drawn at LINE of the width asked for (user 2026-10-18: the
## lines were too heavy next to Frostpunk's), so the mockup's widths stay at
## the call sites. Crouch is a figure down on one knee, its back bent and its
## head low, a hand on the other knee (the same day: the user's own drawing,
## the first of four, traced into one line like the others).

const VIEW: float = 24.0
## The share of the asked line width that is drawn: 2px of 24 comes out 1.5.
const LINE: float = 0.75
## ".t": the faint fill of a solid shape.
const FAINT: float = 0.16
## ".c": the lines cut back into a 2판 shape.
const CUT_WIDTH: float = 1.25
## What a cut line shows through (디자인 토큰 2차 5절): the soot band, a medal, paper.
const CUT_SOOT := Color("10151a")
const CUT_MEDAL := Color("141b22")
const CUT_PAPER := Color("cdc2a8")

const PATHS: Dictionary = {
	"coal": '<path class="f" d="M7 12.200 9.500 6.600 14 5l3.600 3-.4 4.200zM3 19.600 4.500 14l4-2 3.600 2.600-.5 5zM11 19.600l1.200-5.400 4.300-1.700 4 2.500.5 4.600z"/><path class="c" d="M9.500 6.600 12 9.600l5.600-1.600M12 9.600l.4 2.600M4.500 14l3 2 1-4M7.500 16l-.5 3.600M12.200 14.200l3.800 2.300.5-4M16 16.500l1 3.100M4.500 14l4-2 3.600 2.600M12.200 14.200l4.300-1.700 4 2.500"/>',
	"food": '<path class="f" d="M13.400 9.100c0-1.500 7.200-1.500 7.200 0v9.900c0 1.500-7.200 1.500-7.200 0zM2.500 19.600v-4c0-4.300 3.300-6 6.500-6s6.500 1.700 6.500 6v4z"/><path class="c" d="M13.400 9.100c0 1.400 7.200 1.400 7.200 0M15.600 12.600c1.500.4 3.400.4 5 0M15.600 16c1.500.4 3.400.4 5 0M6 11.900l1.600 2.400M9.200 11.100l1.600 2.600M12.200 11.900l1.400 2.300M2.500 17.700h13M15.500 19.600v-4c0-2.200-.9-3.800-2.100-4.700"/>',
	"med": '<path class="f" d="M8.400 2.500h4.200V5H8.400zM9 4.800h3V7H9zM6.500 9.500C6.500 8.200 7.600 7 9 7h3c1.400 0 2.500 1.200 2.500 2.500v11h-8zM13.500 15.500H19a2.750 2.750 0 0 1 0 5.500h-5.500z"/><path class="c" d="M8.400 5h4.200M6.500 12h8M6.500 15h7M8.800 13.500h3.400M13.500 15.500H19M15.400 15.500l.8 5.500M17.400 15.500l.6 5.500M19 16.600a1.650 1.650 0 1 1 0 3.300"/>',
	"lux": '<path class="f" d="M6 21v-9.500c0-1.300.8-2.300 1.800-2.900V3.200h2.600v5.400c1 .6 1.800 1.600 1.800 2.900V21zM14.150 16h6.100l-.45 5h-5.200z"/><path class="c" d="M7.800 5h2.600M6 14h6.200M6 18h6.200M6.700 10.700c1-.6 3.800-.6 4.800 0"/><path d="M13.800 12.500l.8 8.500h5.200l.8-8.500" stroke-width="1.6"/>',
	"fist": '<path class="f" d="M5 9.6a1.8 1.8 0 0 1 3.6 0V13H5zM8.6 8.6a1.8 1.8 0 0 1 3.6 0V13H8.6zM12.2 8.8a1.8 1.8 0 0 1 3.6 0V13h-3.6zM15.8 10a1.7 1.7 0 0 1 3.4 0v3h-3.4zM5 12.4h14.2v3.1c0 1.900-1.400 3.100-3.200 3.100H8.200C6.400 18.600 5 17.400 5 15.500zM7.800 18h8.600v3.500H7.800z"/><path class="c" d="M8.600 9.400v3.300M12.200 8.800v3.900M15.800 9.800v2.900M5 13.600c2.200-.9 5.400-.8 8.200.2.900.4 1.100 1.300.3 1.800M7.800 19.500h8.600"/><path d="M2.300 6.600 3.800 5 2.700 3.900 4.200 2.300M21.700 6.600 20.200 5l1.100-1.100-1.500-1.600" stroke-width="1.5"/>',
	"hand": '<path class="f" d="M6.600 6.450a1.050 1.050 0 0 1 2.100 0V12H6.600zM9.600 4.850a1.050 1.050 0 0 1 2.100 0V12H9.600zM12.600 5.650a1.050 1.050 0 0 1 2.100 0V12h-2.100zM15.600 7.800a1 1 0 0 1 2 0V12h-2zM6.600 11.400h11v2.900c0 2.100-1.500 3.600-3.600 3.600h-3.600c-2.200 0-3.800-1.500-3.800-3.800zM7.600 15.900 4.200 12.100a1.200 1.200 0 0 1 1.800-1.600l3.200 3.500zM9.100 17.200h5.800v4.600H9.100z"/><path class="c" d="M9.100 19.500h5.800"/>',
	"book": '<path class="t" d="M5 4.500h12.500c.8 0 1.500.7 1.500 1.500v12.500c0 .8-.7 1.500-1.500 1.500H5z"/><path d="M5 4.500h12.500c.8 0 1.500.7 1.500 1.500v12.500c0 .8-.7 1.500-1.500 1.500H5z"/><path d="M8.250 4.500V20M11.500 9H16M11.500 12.500h3"/><path d="M13.500 20v3l1.500-1.200 1.500 1.200v-3"/>',
	"menu": '<path d="M4 7h16M4 12h11M4 17h14"/>',
	"overview": '<path class="t" d="M2.500 9.500h5v5h-5zM9.500 9.500h5v5h-5zM16.500 9.500h5v5h-5z"/><path d="M2.500 9.500h5v5h-5zM9.500 9.500h5v5h-5zM16.500 9.500h5v5h-5z"/><path d="M7.500 12h2M14.500 12h2M2 5.500h20M2 18.500h20"/>',
	"arrow": '<path d="M5 12h13M13 6l6 6-6 6"/>',
	"back": '<path d="M15 5l-7 7 7 7"/>',
	"fwd": '<path d="M9 5l7 7-7 7"/>',
	"up": '<path d="M5 15l7-7 7 7"/>',
	"down": '<path d="M5 9l7 7 7-7"/>',
	"eye": '<path d="M2 12c4-7 16-7 20 0-4 7-16 7-20 0z"/><circle cx="12" cy="12" r="3"/>',
	"eyeOff": '<path d="M2 11c4 6 16 6 20 0"/><path d="M6 15l-2 3M12 16v4M18 15l2 3"/>',
	"secret": '<path class="t" d="M3 6h18v12H3z"/><path d="M3 6h18v12H3z"/><path d="M3 6l9 7 9-7"/>',
	"heat": '<path class="t" d="M12 3c4 5 6 7 6 11a6 6 0 0 1-12 0c0-3 2-4 3-7 1 2 2 2 3 2z"/><path d="M12 3c4 5 6 7 6 11a6 6 0 0 1-12 0c0-3 2-4 3-7 1 2 2 2 3 2z"/><path d="M12 21a3 3 0 0 0 0-6"/>',
	"ration": '<path class="t" d="M4 12h16c0 4.500-3.500 8-8 8s-8-3.500-8-8z"/><path d="M4 12h16c0 4.500-3.500 8-8 8s-8-3.500-8-8z"/><path d="M9 8c-1-1.500 1-2.500 0-4M13 8c-1-1.500 1-2.500 0-4"/>',
	"people": '<circle cx="8" cy="8" r="3"/><circle cx="17" cy="9" r="2.500"/><path d="M2 20c0-6 12-6 12 0M15 20c0-4 7-4 7 0"/>',
	"witness": '<circle cx="12" cy="7" r="3"/><path d="M5 20c0-7 14-7 14 0"/><path d="M2 4l3 2M22 4l-3 2"/>',
	"open": '<path class="t" d="M4 5h16v11H11l-5 4v-4H4z"/><path d="M4 5h16v11H11l-5 4v-4H4z"/><path d="M8 9h8M8 12h5"/>',
	"favor": '<circle cx="12" cy="9" r="4"/><path d="M9.500 12l-3 8M14.500 12l3 8"/>',
	"fetch": '<path class="t" d="M4 11h16v9H4z"/><path d="M4 11h16v9H4z"/><path d="M4 14h16M4 17h16"/><path d="M12 2.500V8M9.500 5.500 12 8l2.500-2.500"/>',
	"bribe": '<ellipse cx="12" cy="7" rx="7" ry="3"/><path d="M5 7v5c0 4 14 4 14 0V7M5 12v5c0 4 14 4 14 0v-5"/>',
	"blackmail": '<path class="t" d="M5 4h14v11l-5 5H5z"/><path d="M5 4h14v11l-5 5H5z"/><path d="M14 20v-5h5M8 9h8M8 13h4"/>',
	"papers": '<path class="t" d="M7.500 3.500h8L19 7v11H7.500z"/><path d="M7.500 3.500h8L19 7v11H7.500z"/><path d="M15.500 3.500V7H19M10.500 10.500H16M10.500 14H16"/><path d="M4.500 7.500v13H15"/>',
	"numbers": '<path d="M5 20V11M10 20V5M15 20v-7M20 20v-4"/>',
	"scale": '<path class="t" d="M4 11h16v9.500H4z"/><path d="M4 11h16v9.500H4z"/><path d="M8.500 11V3.500h7V11M8.500 14.500h7M11 6.500h2"/>',
	"bed": '<path d="M3 6v13M3 15.500h18V19M7.500 15.500V12H19c1.100 0 2 .9 2 2v1.500"/><circle cx="5.300" cy="11.500" r="1.600"/>',
	"gear": '<path d="M19.48 13.32 22.07 14.60 20.96 17.28 18.23 16.36 16.36 18.23 17.28 20.96 14.60 22.07 13.32 19.48 10.68 19.48 9.40 22.07 6.72 20.96 7.64 18.23 5.77 16.36 3.04 17.28 1.93 14.60 4.52 13.32 4.52 10.68 1.93 9.40 3.04 6.72 5.77 7.64 7.64 5.77 6.72 3.04 9.40 1.93 10.68 4.52 13.32 4.52 14.60 1.93 17.28 3.04 16.36 5.77 18.23 7.64 20.96 6.72 22.07 9.40 19.48 10.68z"/><circle cx="12" cy="12" r="3.2"/>',
	"wrench": '<path class="t" d="M14 6a4 4 0 0 0 5 5l-9 9-3-3 9-9"/><path d="M14 6a4 4 0 0 0 5 5l-9 9-3-3 9-9"/><path d="M14 6l3 1 1 3"/>',
	"radio": '<path class="t" d="M4 9h16v11H4z"/><path d="M4 9h16v11H4z"/><path d="M8 9l8-6"/><circle cx="9" cy="14.500" r="2.500"/><path d="M15 13h2M15 17h2"/>',
	"compass": '<circle cx="12" cy="12" r="9"/><path class="t" d="M15.500 8.500l-2 5-5 2 2-5z"/><path d="M15.500 8.500l-2 5-5 2 2-5z"/>',
	"check": '<path d="M5 12l5 5 9-10"/>',
	"alert": '<path class="t" d="M12 4l9 16H3z"/><path d="M12 4l9 16H3z"/><path d="M12 10v5"/><circle class="f" cx="12" cy="17.300" r="1"/>',
	"dot": '<circle class="f" cx="12" cy="12" r="4"/>',
	"lever": '<path d="M4 20h16"/><path d="M9 20l5-13"/><circle class="t" cx="14.700" cy="5" r="2.200"/><circle cx="14.700" cy="5" r="2.200"/><path d="M6 20a6 6 0 0 1 12 0"/>',
	"snow": '<path d="M12 12V3M12 12l7.800-4.500M12 12l7.800 4.500M12 12v9M12 12l-7.800 4.500M12 12L4.200 7.500"/><path d="M10 5l2 2 2-2M10 19l2-2 2 2M17 6.500l-.8 2.800 2.800.7M7 6.500l.8 2.800-2.800.7M17 17.500l-.8-2.800 2.800-.7M7 17.500l.8-2.800-2.800-.7"/>',
	"temp": '<path class="t" d="M10 4h4v10a4 4 0 1 1-4 0z"/><path d="M10 4h4v10a4 4 0 1 1-4 0z"/><path d="M12 9v8M16 6h3M16 10h2"/>',
	"horde": '<circle cx="6" cy="9" r="2"/><circle cx="12" cy="7" r="2"/><circle cx="18" cy="9" r="2"/><path d="M3 20v-4c0-3 6-3 6 0v4M9 20v-6c0-3 6-3 6 0v6M15 20v-4c0-3 6-3 6 0v4"/>',
	"clock": '<circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 3"/>',
	"run": '<circle class="f" cx="15.6" cy="4.4" r="2.5"/><path d="M13.6 8.2L10.6 13.8M13.3 9.2l3.3 2.2 2.6-1M13.3 9.2l-3.6.6-2 2.4M10.6 13.8l3.8 2.6-1.2 4.8M10.6 13.8l-2.2 4-3.8.8"/>',
	"crouch": '<circle class="f" cx="18" cy="5.6" r="2.5"/><path d="M15.6 7.6C12.8 7.8 9.8 11.6 10.3 15.2L11.4 19.8 4.4 20.1l1.5-1.1M10.3 15.2L17 13.8l-.4 6h2.6M14.1 9l-1.1 3.6 4.1-.5"/>',
	"inv": '<path class="t" d="M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4z"/><path d="M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z"/>',
	"bandage": '<path class="t" d="M4 9l11-5 5 11-11 5z"/><path d="M4 9l11-5 5 11-11 5z"/><path d="M9 7l5 11"/>',
	"aim": '<circle cx="12" cy="12" r="8"/><circle class="f" cx="12" cy="12" r="1.600"/><path d="M12 2v4M12 18v4"/>',
	"shove": '<path d="M5 12h9M11 8l4 4-4 4"/><path d="M19 5v14"/>',
	"pause": '<path d="M8 5v14M16 5v14"/>',
	"train": '<path class="t" d="M2 6h14l4 5v5H2z"/><path d="M2 6h14l4 5v5H2z"/><path d="M2 11h18"/><circle cx="6" cy="18" r="1.500"/><circle cx="11" cy="18" r="1.500"/><circle cx="16" cy="18" r="1.500"/><path d="M1 21.500h22"/>',
	"tension": '<circle cx="12" cy="13" r="8"/><path d="M12 13l5-4"/><path d="M12 3v2"/><circle class="f" cx="12" cy="13" r="1.500"/>',
	"trust": '<path d="M9 9h6l2 11H7z"/><path d="M10 9V5h4v4"/><path d="M12 13v3"/><path d="M12 5V2"/>',
	"axe": '<path d="M14 6.500V21"/><path class="t" d="M16.800 4H12C8 4 5.100 6.600 4.600 10.600c-.2 1.500 1 2.400 2.400 1.900 2-.7 3.400-2.500 5-3h4.800z"/><path d="M16.800 4H12C8 4 5.100 6.600 4.600 10.600c-.2 1.500 1 2.400 2.400 1.900 2-.7 3.400-2.500 5-3h4.800z"/>',
	"lamp": '<path d="M9.500 5.500h5M12 5.500V3"/><path class="t" d="M8.500 8.500h7l1.500 9h-10z"/><path d="M8.500 8.500h7l1.500 9h-10zM7 20.500h10"/><path d="M12 11.500v3.500"/>',
	"drop": '<path class="t" d="M12 3.500c3.500 4.800 6 7.800 6 10.800a6 6 0 0 1-12 0c0-3 2.500-6 6-10.800z"/><path d="M12 3.500c3.500 4.800 6 7.800 6 10.800a6 6 0 0 1-12 0c0-3 2.500-6 6-10.800z"/>',
	"search": '<circle cx="10.500" cy="10.500" r="6"/><path d="M15 15l5.500 5.500"/>',
	# Not in the mockup's table: drawn in the same hand for what the game needs.
	"gun": '<path class="t" d="M3 9h15l3 1.5v2H9.5l-1.5 5h-3l1.2-5H3z"/><path d="M3 9h15l3 1.5v2H9.5l-1.5 5h-3l1.2-5H3zM18 9V7.5"/>',
	"play": '<path class="t" d="M8 5l11 7-11 7z"/><path d="M8 5l11 7-11 7z"/>',
	"door": '<path class="t" d="M7 3h10v18H7z"/><path d="M7 3h10v18H7zM4 21h16"/><circle class="f" cx="14.5" cy="12.5" r="1.1"/>',
	"promise": '<path class="t" d="M6 3h9l3 3v15H6z"/><path d="M6 3h9l3 3v15H6zM15 3v3h3M9 10h6M9 13.5h4"/><circle cx="14.5" cy="17.5" r="1.8"/>',
	"stairs": '<path class="t" d="M3 21v-4h5v-4h5V9h5V5h3v16z"/><path d="M3 17h5v-4h5V9h5V5h3M3 21h18"/>',
}


## The situation pad's picture for what it would do first (its row's word).
static func context_icon(label: String) -> String:
	if label.begins_with("붕대") or label.begins_with("부목") or label.ends_with("치료") or label.ends_with("문지름"):
		return "bandage"
	if label.begins_with("문"):
		return "door"
	if label.ends_with("가기"):
		return "stairs"
	if label.begins_with("열차"):
		return "train"
	return "search"

static var _made: Dictionary = {}


## The icon `id` in `color`, `px` across on screen (drawn at twice that, for a
## sharp edge; give the Button icon_max_width = px), its cut lines in `cut`.
## The colour's alpha is the whole icon's, as CSS opacity is: overlapping lines
## do not darken. Null for an unknown id.
static func texture(id: String, px: int, color: Color, weight: float = 2.0, cut: Color = CUT_SOOT) -> Texture2D:
	if not PATHS.has(id):
		return null
	var slot: String = "%s@%d@%s@%.2f@%s" % [id, px, color.to_html(true), weight, cut.to_html(false)]
	if not _made.has(slot):
		var hex: String = "#" + color.to_html(false)
		var body: String = String(PATHS[id])
		body = body.replace('class="t"', 'fill="%s" fill-opacity="%.2f" stroke="none"' % [hex, FAINT])
		body = body.replace('class="f"', 'fill="%s" stroke="none"' % hex)
		body = body.replace('class="c"', 'fill="none" stroke="#%s" stroke-width="%.2f"' % [cut.to_html(false), CUT_WIDTH])
		var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="%s" stroke-width="%.2f" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [hex, weight * LINE, body]
		var img := Image.new()
		if img.load_svg_from_string(svg, px * 2.0 / VIEW) != OK:
			return null
		if color.a < 0.999:
			img.convert(Image.FORMAT_RGBA8)
			for y in img.get_height():
				for x in img.get_width():
					var c: Color = img.get_pixel(x, y)
					c.a *= color.a
					img.set_pixel(x, y, c)
		_made[slot] = ImageTexture.create_from_image(img)
	return _made[slot]
