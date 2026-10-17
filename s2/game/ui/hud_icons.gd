extends RefCounted
## The field's line icons (UI 3단계 시안 2차, 「성에 낀 계기」): one stroke on
## a 24 grid, round ends, a faint fill where the shape is solid. Kept as text
## and drawn at the size asked for, like status_art.gd, so there is no import
## step and the phone shows what the tests see. No cross, crescent, star or
## two crossed bars among them (the aim ring has its ticks on one axis only).

const VIEW: float = 24.0
## "t": the faint fill of a solid shape; "f": a solid dot.
const FAINT: float = 0.16

const PATHS: Dictionary = {
	"run": '<circle cx="15" cy="5" r="2"/><path d="M8 11l4-3 3 3 3 1M12 8l-1 6 3 3v4M11 14l-3 2-3 0"/>',
	"crouch": '<circle cx="14" cy="8" r="2"/><path d="M13 11l-5 3 2 4h6M8 14l-3 5"/>',
	"lamp": '<path d="M9.5 5.5h5M12 5.5V3"/><path class="t" d="M8.5 8.5h7l1.5 9h-10z"/><path d="M8.5 8.5h7l1.5 9h-10zM7 20.5h10"/><path d="M12 11.5v3.5"/>',
	"axe": '<path d="M14 6.5V21"/><path class="t" d="M16.8 4H12C8 4 5.1 6.6 4.6 10.6c-.2 1.5 1 2.4 2.4 1.9 2-.7 3.4-2.5 5-3h4.8z"/><path d="M16.8 4H12C8 4 5.1 6.6 4.6 10.6c-.2 1.5 1 2.4 2.4 1.9 2-.7 3.4-2.5 5-3h4.8z"/>',
	"gun": '<path class="t" d="M3 9h15l3 1.5v2H9.5l-1.5 5h-3l1.2-5H3z"/><path d="M3 9h15l3 1.5v2H9.5l-1.5 5h-3l1.2-5H3zM18 9V7.5"/>',
	"shove": '<path d="M4 12h9M10 8l4 4-4 4"/><path d="M18 5v14"/>',
	"search": '<circle cx="10.5" cy="10.5" r="6"/><path d="M15 15l5.5 5.5"/>',
	"train": '<path class="t" d="M2 6h14l4 5v5H2z"/><path d="M2 6h14l4 5v5H2z"/><path d="M2 11h18"/><circle cx="6" cy="18" r="1.5"/><circle cx="11" cy="18" r="1.5"/><circle cx="16" cy="18" r="1.5"/><path d="M1 21.5h22"/>',
	"inv": '<path class="t" d="M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4z"/><path d="M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z"/>',
	"radio": '<path class="t" d="M4 9h16v11H4z"/><path d="M4 9h16v11H4z"/><path d="M8 9l8-6"/><circle cx="9" cy="14.5" r="2.5"/><path d="M15 13h2M15 17h2"/>',
	"gear": '<path d="M19.48 13.32 22.07 14.6 20.96 17.28 18.23 16.36 16.36 18.23 17.28 20.96 14.6 22.07 13.32 19.48 10.68 19.48 9.4 22.07 6.72 20.96 7.64 18.23 5.77 16.36 3.04 17.28 1.93 14.6 4.52 13.32 4.52 10.68 1.93 9.4 3.04 6.72 5.77 7.64 7.64 5.77 6.72 3.04 9.4 1.93 10.68 4.52 13.32 4.52 14.6 1.93 17.28 3.04 16.36 5.77 18.23 7.64 20.96 6.72 22.07 9.4 19.48 10.68z"/><circle cx="12" cy="12" r="3.2"/>',
	"bandage": '<path class="t" d="M4 9l11-5 5 11-11 5z"/><path d="M4 9l11-5 5 11-11 5z"/><path d="M9 7l5 11"/>',
	"compass": '<circle cx="12" cy="12" r="9"/><path class="t" d="M15.5 8.5l-2 5-5 2 2-5z"/><path d="M15.5 8.5l-2 5-5 2 2-5z"/>',
	"aim": '<circle cx="12" cy="12" r="8"/><circle class="f" cx="12" cy="12" r="1.6"/><path d="M12 2v4M12 18v4"/>',
	"pause": '<path d="M8 5v14M16 5v14"/>',
	"play": '<path class="t" d="M8 5l11 7-11 7z"/><path d="M8 5l11 7-11 7z"/>',
	"drop": '<path class="t" d="M12 3.5c3.5 4.8 6 7.8 6 10.8a6 6 0 0 1-12 0c0-3 2.5-6 6-10.8z"/><path d="M12 3.5c3.5 4.8 6 7.8 6 10.8a6 6 0 0 1-12 0c0-3 2.5-6 6-10.8z"/>',
	"crew": '<circle cx="8" cy="8" r="2.5"/><circle cx="16" cy="8" r="2.5"/><path d="M3.5 19c.5-3.5 2.2-5.5 4.5-5.5s4 2 4.5 5.5M11.5 19c.5-3.5 2.2-5.5 4.5-5.5s4 2 4.5 5.5"/>',
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
## sharp edge; give the Button icon_max_width = px). Null for an unknown id.
static func texture(id: String, px: int, color: Color, weight: float = 2.0) -> Texture2D:
	if not PATHS.has(id):
		return null
	var slot: String = "%s@%d@%s@%.2f" % [id, px, color.to_html(true), weight]
	if not _made.has(slot):
		var hex: String = "#" + color.to_html(false)
		var body: String = String(PATHS[id])
		body = body.replace('class="t"', 'fill="%s" fill-opacity="%.2f" stroke="none"' % [hex, FAINT * color.a])
		body = body.replace('class="f"', 'fill="%s" fill-opacity="%.2f" stroke="none"' % [hex, color.a])
		var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="%s" stroke-opacity="%.2f" stroke-width="%.2f" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [hex, color.a, weight, body]
		var img := Image.new()
		if img.load_svg_from_string(svg, px * 2.0 / VIEW) != OK:
			return null
		_made[slot] = ImageTexture.create_from_image(img)
	return _made[slot]
