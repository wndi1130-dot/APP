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

var hud                             # field_hud.gd
var shown: float = 0.0              # 0 gone .. 1 fully up
var _held: Array = []               # the particle systems held still, with their own speed
var still: float = 0.0              # fx_still: seconds stood paused


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


## A rectangle whose corners carry their own colour (top left, top right,
## bottom right, bottom left), blended between them.
func _ramp(r: Rect2, tl: Color, tr: Color, br: Color, bl: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(pts, PackedColorArray([tl, tr, br, bl]))
