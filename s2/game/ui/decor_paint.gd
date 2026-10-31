extends RefCounted
## The strip's fixed shapes share one triangle submission; text stays on the UI fonts.

const Fonts = preload("res://game/ui/ui_fonts.gd")
const Glass = preload("res://game/ui/glass_parts.gd")
const Bake = preload("res://game/ui/ui_bake.gd")
const K: float = Fonts.K
const INK := Color("eee9dc")
const INK2 := Color(0.933, 0.914, 0.863, 0.7)
const INK3 := Color(0.933, 0.914, 0.863, 0.54)
const HAIR := Color(0.933, 0.914, 0.863, 0.16)
const ACCENT := Color("f2a63c")
const PATHS := {
	"chair": [[[8,16],[24,16],[24,20],[8,20],[8,16]], [[10,20],[10,27]], [[22,20],[22,27]], [[10,16],[10,7],[22,7],[22,16]]],
	"table": [[[4,12],[28,12],[28,16],[4,16],[4,12]], [[7,16],[7,27]], [[25,16],[25,27]]],
	"shelf": [[[6,4],[26,4],[26,28],[6,28],[6,4]], [[6,12],[26,12]], [[6,20],[26,20]]],
	"lamp": [[[13,6],[19,6],[21,14],[11,14],[13,6]], [[16,14],[16,26]], [[11,27],[21,27]]],
	"wall": [[[6,7],[26,7],[26,25],[6,25],[6,7]], [[9,21],[14,15],[18,19],[21,16],[24,21]]],
	"surface": [[[11,5],[21,5],[21,9],[23,12],[23,27],[9,27],[9,12],[11,9],[11,5]]],
	"can": [[[10,9],[22,9],[22,26],[10,26],[10,9]], [[10,13],[22,13]], [[13,9],[13,6],[19,6],[19,9]]],
	"bed": [[[4,23],[4,10],[11,10],[11,16],[28,16],[28,27]], [[4,23],[28,23]]],
	"stove": [[[7,12],[25,12],[25,27],[7,27],[7,12]], [[12,12],[12,4],[18,4]], [[12,17],[20,17],[20,23],[12,23],[12,17]]],
	"box": [[[6,9],[26,9],[26,27],[6,27],[6,9]], [[6,15],[26,15]], [[14,18],[18,18]]],
	"piano": [[[5,7],[27,7],[27,25],[5,25],[5,7]], [[5,18],[27,18]], [[10,18],[10,23]], [[16,18],[16,23]], [[22,18],[22,23]]],
	"violin": [[[14,4],[18,4],[18,13],[23,17],[20,20],[23,25],[18,28],[14,28],[9,25],[12,20],[9,17],[14,13],[14,4]], [[16,10],[16,25]]],
}


static func rounded(batch: Bake.Batch, rect: Rect2, radius: float, color: Color) -> void:
	batch.polygon(Glass.outline(Rect2(rect.position * K, rect.size * K), radius * K), PackedColorArray([color]))


static func glass(batch: Bake.Batch, rect: Rect2, radius: float = 10.0) -> void:
	rounded(batch, Rect2(rect.position + Vector2(0, 2), rect.size), radius, Color(0, 0, 0, 0.35))
	var points := Glass.outline(Rect2(rect.position * K, rect.size * K), radius * K)
	var colors := PackedColorArray()
	for p: Vector2 in points:
		colors.append(Color(0.086, 0.106, 0.125, 0.90).lerp(Color(0.047, 0.059, 0.071, 0.94), (p.y / K - rect.position.y) / rect.size.y))
	batch.polygon(points, colors)
	points.append(points[0])
	batch.polyline(points, PackedColorArray([HAIR]), K)


static func icon(batch: Bake.Batch, kind: String, spot: String, at: Vector2, width: float, ink: Color = INK) -> void:
	var key: String = spot
	match kind:
		"chair": key = "chair"
		"side_table", "table": key = "table"
		"small_shelf", "bookshelf", "drawer", "wardrobe", "cupboard": key = "shelf"
		"oil_lamp": key = "lamp"
		"bed_frame": key = "bed"
		"small_stove", "iron_stove": key = "stove"
		"small_box", "safe", "rare_wine_case": key = "box"
		"piano": key = "piano"
		"can_beans", "can_meat": key = "can"
		"rare_violin": key = "violin"
	if kind == "record":
		batch.arc((at + Vector2.ONE * width * 0.5) * K, width * 0.37 * K, 0, TAU, 33, ink, 1.5 * K)
		batch.circle((at + Vector2.ONE * width * 0.5) * K, width * 0.055 * K, ink)
		return
	for stroke: Array in PATHS.get(key, PATHS["box"]):
		var line := PackedVector2Array()
		for p: Array in stroke:
			line.append((at + Vector2(float(p[0]), float(p[1])) * width / 32.0) * K)
		batch.polyline(line, PackedColorArray([ink]), 1.5 * K)


static func text(ci: CanvasItem, word: String, box: Rect2, css: float, ink: Color = INK, numeric: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT, weight: int = 400, minimum_css: float = 8.5) -> void:
	var font: Font = Fonts.face(Fonts.NUMBER if numeric else Fonts.WORD, weight)
	var px: int = Fonts.size(css)
	# Keep full object names on one line, down to the card's detail size.
	while px > Fonts.size(minimum_css) and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > box.size.x * K:
		px -= 1
	var base: float = (box.position.y + box.size.y * 0.5) * K + (font.get_ascent(px) - font.get_descent(px)) * 0.5
	ci.draw_string(font, Vector2(box.position.x * K, base), word, align, box.size.x * K, px, ink)
