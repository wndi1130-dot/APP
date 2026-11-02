extends Control
## What tells a tactical pause at a glance (user 2026-10-25: pressing pause
## needs something that shows it is paused). Under the HUD's keys and over the
## world: the screen's top and bottom go dark and a faint dim lies over the
## rest, 「일시 정지」 stands in the middle of the upper screen between two
## rules, a lamp ring breathes round the pause key (now the play key), and
## what falls or drifts in the world (the snow, smoke, sparks) holds still,
## and so do the bodies' motions (fx_still: the seconds stood paused, which
## the people's and the dead's shader takes off TIME).
## The world itself already fades like an old photo (field_game.gd fx_fade).
## Nothing here touches the game's state; it reads game.paused only. A panel
## (settings, a pane) brings its own shade, so the veil steps aside for it.

const HudSkin = preload("res://game/ui/hud_skin.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const FxState = preload("res://fx/fx_state.gd")

const WORD := "일시 정지"
const EASE: float = 0.22            # seconds the veil takes to come or go
const BAND: float = 0.2             # of the screen's height, dark at the top and at the bottom
const BAND_DARK: float = 0.5
const DIM: float = 0.14             # over the rest of the screen
const WORD_Y: float = 0.27          # of the height: the word's middle, under the clock's row
const WORD_SIZE: int = 30
const RULE: float = 64.0            # the rules either side of the word
const RING_PULSE: float = 1.6       # seconds a breath of the ring takes
const STILL_WRAP: float = 3600.0    # the engine's TIME rolls over at an hour; fx_still keeps in step
## A line of this world under the word, a new one each pause (world_lines.gd): the
## place a loading screen's line would have. Smaller than the word, a little fainter.
const WorldLines = preload("res://game/sim/world_lines.gd")
## The radio call's body size (field_hud.gd radio_label, UiFonts.size(14)): the line is
## read on a phone at arm's length, never smaller than the HUD's own words.
const LINE_CSS: float = 14.0
const LINE_SIZE: int = 26            # UiFonts.size(LINE_CSS) at K = 720/390 (test_pause_veil.gd holds them equal)
const LINE_INK: float = 0.9          # of the word's ink
const LINE_SHADE: float = 0.6        # the dark strip under the line (the word's is 0.45 over less snow)
const LINE_CLEAR: float = 8.0        # px kept between the line's strip and the radio's call above it

var hud                             # field_hud.gd
var shown: float = 0.0              # 0 gone .. 1 fully up
var _held: Array = []               # the particle systems held still, with their own speed
var still: float = 0.0              # fx_still: seconds stood paused
var line: String = ""               # the world line this pause shows
var _was_paused: bool = false       # the field was paused last frame: a line is drawn once per pause
## The last world line shown while the game runs (-1: none yet, the first is drawn at random).
static var _line_at: int = -1


func setup(field_hud) -> void:
	hud = field_hud
	name = "PauseVeil"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Up while the player has the field paused and no panel is over it.
func wanted() -> bool:
	if hud == null or hud.game == null:
		return false
	return bool(hud.game.paused) and not bool(hud.game.ended) and not bool(hud.modal_open)


func _process(delta: float) -> void:
	var up: bool = wanted()
	var was: float = shown
	shown = move_toward(shown, 1.0 if up else 0.0, delta / EASE)
	var hold: bool = hud != null and hud.game != null and bool(hud.game.paused) and not bool(hud.game.ended)
	# A new line when a pause begins, not when the veil comes back from a panel.
	if hold and not _was_paused:
		line = next_line()
	_was_paused = hold
	_hold_world(hold)
	if hold:
		still = fposmod(still + delta, STILL_WRAP)
		FxState.set_still(still)
	visible = shown > 0.0
	if visible or was > 0.0:
		queue_redraw()


## Snow, smoke and sparks stop where they are while paused, and go on after.
func _hold_world(hold: bool) -> void:
	if hold == not _held.is_empty():
		return
	if hold:
		for p in hud.game.find_children("*", "GPUParticles3D", true, false):
			var parts := p as GPUParticles3D
			_held.append([parts, parts.speed_scale])
			parts.speed_scale = 0.0
	else:
		for row in _held:
			if is_instance_valid(row[0]):
				(row[0] as GPUParticles3D).speed_scale = float(row[1])
		_held.clear()


func _draw() -> void:
	if shown <= 0.0:
		return
	var k: float = shown * shown * (3.0 - 2.0 * shown)
	var s: Vector2 = size
	var band: float = s.y * BAND
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, DIM * k))
	# Dark at the edge, clear toward the middle (a smooth ramp, no steps).
	var dark := Color(0, 0, 0, BAND_DARK * k)
	var clear := Color(0, 0, 0, 0)
	_ramp(Rect2(0.0, 0.0, s.x, band), dark, dark, clear, clear)
	_ramp(Rect2(0.0, s.y - band, s.x, band), clear, clear, dark, dark)
	# The word between two rules, on a soft dark strip so it reads over the roofs.
	var font: Font = UiFonts.face(UiFonts.WORD, 600, 6.0)
	var ink := Color(HudSkin.PAPER, 0.92 * k)
	var w: float = font.get_string_size(WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, WORD_SIZE).x
	var mid := Vector2(s.x * 0.5, s.y * WORD_Y)
	var base := Vector2(mid.x - w * 0.5, mid.y + font.get_ascent(WORD_SIZE) * 0.38)
	var strip: float = WORD_SIZE * 1.9
	var reach: float = w * 0.5 + 18.0 + RULE + 40.0
	var shade := Color(0, 0, 0, 0.45 * k)
	_ramp(Rect2(mid.x - reach, mid.y - strip * 0.5, reach, strip), clear, shade, shade, clear)
	_ramp(Rect2(mid.x, mid.y - strip * 0.5, reach, strip), shade, clear, clear, shade)
	draw_string(font, base + Vector2(0, 2), WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, WORD_SIZE, Color(0, 0, 0, 0.6 * k))
	draw_string(font, base, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, WORD_SIZE, ink)
	var gap: float = 18.0
	var rule := Color(HudSkin.PAPER, 0.55 * k)
	draw_line(Vector2(mid.x - w * 0.5 - gap - RULE, mid.y), Vector2(mid.x - w * 0.5 - gap, mid.y), rule, 1.5, true)
	draw_line(Vector2(mid.x + w * 0.5 + gap, mid.y), Vector2(mid.x + w * 0.5 + gap + RULE, mid.y), rule, 1.5, true)
	# This pause's line of the world, just under the word's strip.
	if line != "":
		var face: Font = UiFonts.face(UiFonts.WORD, 600, 0.0)
		var lw: float = face.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_SIZE).x
		var half: float = lw * 0.5 + 48.0
		var tall: float = LINE_SIZE * 1.9
		var line_mid: float = clear_of_radio(mid.y + strip * 0.5 + LINE_SIZE * 0.9, tall, Vector2(mid.x - half, mid.x + half), _radio_rect())
		var at := Vector2(mid.x - lw * 0.5, line_mid + face.get_ascent(LINE_SIZE) * 0.38)
		# Its own soft dark strip, as the word has, so it reads over the snow.
		var under := Color(0, 0, 0, LINE_SHADE * k)
		_ramp(Rect2(mid.x - half, line_mid - tall * 0.5, half, tall), clear, under, under, clear)
		_ramp(Rect2(mid.x, line_mid - tall * 0.5, half, tall), under, clear, clear, under)
		draw_string(face, at + Vector2(0, 1.5), line, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_SIZE, Color(0, 0, 0, 0.7 * k))
		draw_string(face, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_SIZE, Color(HudSkin.PAPER, 0.92 * LINE_INK * k))
	# A lamp ring breathing round the key that plays on.
	var key: Control = hud.pause_button
	if key != null and key.is_visible_in_tree():
		var r: Rect2 = key.get_global_rect()
		var centre: Vector2 = r.get_center() - get_global_rect().position
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		var breath: float = 0.5 + 0.5 * sin(TAU * t / RING_PULSE)
		# Round the disc the key shows (field_hud.gd TOP_ROW_H), not its larger touch area.
		var disc: float = minf(float(hud.TOP_ROW_H), minf(r.size.x, r.size.y))
		var radius: float = disc * 0.5 + 3.0 + 3.0 * breath
		draw_arc(centre, radius, 0.0, TAU, 48, Color(HudSkin.LAMP1, (0.45 + 0.4 * breath) * k), 3.0, true)


## The radio's call on screen (field_hud.gd radio_pill) in this control's space;
## an empty rect when none shows.
func _radio_rect() -> Rect2:
	if hud == null or not ("radio_pill" in hud):
		return Rect2()
	var pill = hud.radio_pill
	if not (pill is Control) or not (pill as Control).is_visible_in_tree():
		return Rect2()
	var r: Rect2 = (pill as Control).get_global_rect()
	r.position -= get_global_rect().position
	return r


## The line's middle: under the word's strip, and lower still when the radio's
## call hangs over the line's strip (span: its left and right), however many
## lines the call has.
static func clear_of_radio(wanted: float, tall: float, span: Vector2, radio: Rect2) -> float:
	if radio.size.x <= 0.0 or radio.size.y <= 0.0 or span.y <= radio.position.x or span.x >= radio.end.x:
		return wanted
	return maxf(wanted, radio.end.y + LINE_CLEAR + tall * 0.5)


## The next world line: the one after the last shown, the first at random, so a
## pause never repeats the line just read while there are others.
static func next_line() -> String:
	var n: int = WorldLines.LINES.size()
	if n == 0:
		return ""
	_line_at = randi() % n if _line_at < 0 else (_line_at + 1) % n
	return WorldLines.LINES[_line_at]


## A rectangle whose corners carry their own colour (top left, top right,
## bottom right, bottom left), blended between them.
func _ramp(r: Rect2, tl: Color, tr: Color, br: Color, bl: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(pts, PackedColorArray([tl, tr, br, bl]))
