extends Node
## No word sticks out of its key (user 2026-10-25: some keys' words stick out
## of them). Every Button under the watched root is looked at when its word,
## its size or its font changes: if a line of its word is wider than the room
## on the plate it shows (hud_skin.gd Plate.seen, a disc's chord or a pill's
## length, less its mark beside the word) or than the key itself, its type
## steps down, no smaller than SMALLEST of its own size; a word still too wide
## then ends in an ellipsis inside the key. A key's own size is never touched.
## Read only otherwise: the HUD keeps what each key says.

const EVERY: float = 0.2              # seconds between looks over the keys
const SMALLEST: float = 0.62          # of a key's own type size
const LEAST: int = 11                 # px: never smaller than this
const DISC_CHORD: float = 0.82        # of a round plate's width: the room across its middle
const PAD: float = 6.0                # px clear on each side of the word

var roots: Array = []
var _since: float = EVERY
var _seen: Dictionary = {}            # key id -> what it was fitted for


func watch(root: Control) -> void:
	roots.append(root)


func _process(delta: float) -> void:
	_since += delta
	if _since < EVERY:
		return
	_since = 0.0
	fit_all()


## Look over every key now.
func fit_all() -> void:
	for root in roots:
		if is_instance_valid(root):
			for b in root.find_children("*", "Button", true, false):
				fit(b as Button)


## Fit one key's word to its room (again only when what it shows has changed).
func fit(b: Button) -> void:
	if b == null or b.text == "" or not b.is_visible_in_tree():
		return
	if not b.has_meta("fit_base"):
		b.set_meta("fit_base", b.get_theme_font_size("font_size"))
	var base: int = int(b.get_meta("fit_base"))
	var room: float = room_of(b)
	var stamp := "%s|%d|%d|%d" % [b.text, int(room), base, b.get_theme_font("font").get_instance_id()]
	if String(_seen.get(b.get_instance_id(), "")) == stamp:
		return
	_seen[b.get_instance_id()] = stamp
	var size: int = size_for(b.get_theme_font("font"), b.text, base, room)
	b.add_theme_font_size_override("font_size", size)
	var still_wide: bool = widest(b.get_theme_font("font"), b.text, size) > room + 0.5
	b.clip_text = still_wide
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if still_wide else TextServer.OVERRUN_NO_TRIMMING


## The room across a key for its word: the plate it shows, or the key itself,
## less a mark beside the word and a little clear on each side.
static func room_of(b: Button) -> float:
	var width: float = maxf(b.size.x, b.custom_minimum_size.x)
	var sb: StyleBox = b.get_theme_stylebox("normal")
	if sb != null and "seen" in sb and "round_key" in sb:
		var seen: Vector2 = sb.get("seen")
		if seen.x > 0.0:
			width = minf(width, seen.x * (DISC_CHORD if bool(sb.get("round_key")) else 1.0))
	var mark: float = 0.0
	if b.icon != null and b.icon_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		mark = float(b.get_theme_constant("icon_max_width") + b.get_theme_constant("h_separation"))
	return maxf(width - mark - PAD * 2.0, 1.0)


## The widest line of a word at a type size.
static func widest(font: Font, text: String, size: int) -> float:
	var w: float = 0.0
	for line in text.split("\n"):
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return w


## The largest type size up to `base` at which every line fits in `room`, not
## below SMALLEST of base (nor LEAST).
static func size_for(font: Font, text: String, base: int, room: float) -> int:
	var low: int = maxi(LEAST, int(ceil(float(base) * SMALLEST)))
	var size: int = base
	while size > low and widest(font, text, size) > room:
		size -= 1
	return size
