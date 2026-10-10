extends CanvasLayer
## Field screen (s2_station 2.7): only four things stay up (clock and sun,
## one radio line, the portrait with bag and cold, sound icons at the moment
## of an action). Companion portraits, thumb buttons, cards and the end
## screen come and go. Taps on the world become orders (field_unified 10).

const FieldGrid = preload("res://game/world/field_grid.gd")
const W = preload("res://game/sim/weapons.gd")
const Carry = preload("res://game/sim/carry.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const HordeDirector = preload("res://game/sim/horde_director.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")
const Treatment = preload("res://game/sim/treatment.gd")
const BodyState = preload("res://game/sim/body_state.gd")

const PANEL_BG := Color(0.07, 0.075, 0.08, 0.78)
const INK := Color(0.93, 0.91, 0.86)
const DIM := Color(0.62, 0.62, 0.6)
const WARN := Color(0.95, 0.55, 0.42)
const FROST := Color(0.8, 0.81, 0.8)     # off-white, not sky blue (fx colour rule)
const HOLD_TIME: float = 0.35
const DRAG_PX: float = 28.0
const AIM_CANCEL_PX: float = 56.0   # drag the aim back onto yourself and let go: no shot
const STICK_R: float = 72.0         # thumb travel to full push (the rim runs, if set)
const STICK_DEAD: float = 10.0
const AIM_SLIDE_PX: float = 70.0    # slide along the aim pad: next target
const AIM_PAD_EDGE: float = 24.0    # this far past the pad's edge still counts as on it
const STICK_STOPS_FIGHT: float = 0.3  # a push this hard away from the target calls off a fight
const DOUBLE_TAP_MS: int = 300
## The fixed stick (the default; build 47: a floating one made the thumb re-set
## it all the time). Home is 21 mm in and 14.5 mm up from the bottom-left corner,
## under the run and crouch keys; a touch within STICK_CATCH radii of it takes the stick.
const STICK_HOME_MM := Vector2(21.0, 14.5)
const STICK_CATCH: float = 2.0
## The body picture slows the field, it does not stop it (body_injury 4.6).
const BODY_SLOW: float = 0.3
## The portrait sits top left under the pause key and the clock.
const PORTRAIT_AT := Vector2(16.0, 14.0 + 11.0 * PX_PER_MM + 6.0)
const PORTRAIT_W: float = 290.0
## State icons sit in a row right of the blood key: the two most urgent big,
## the rest small (body_injury 4 '둘까지만 크게').
## Narrow enough that all five stay on the left half of a 1280-wide screen.
const STATUS_AT := Vector2(16.0 + 290.0 + 8.0 + 84.0 + 6.0, 14.0 + 11.0 * PX_PER_MM + 6.0)
const STATUS_BIG := Vector2(60.0, 56.0)
const STATUS_SMALL := Vector2(48.0, 44.0)
const STATUS_SLOTS: int = 5
const BLOOD_BROWN := Color(0.33, 0.2, 0.12, 0.97)   # blood is dark brown here, never red
const FESTER_RIM := Color(0.74, 0.7, 0.3)           # a festering part: a sallow rim, never red
## Where the six parts sit in the body picture (your left on the left, like a mirror).
const BODY_LAYOUT: Dictionary = {
	"head_neck": Rect2(109, 0, 100, 76),
	"arm_left": Rect2(0, 84, 100, 128),
	"torso": Rect2(109, 84, 100, 128),
	"arm_right": Rect2(218, 84, 100, 128),
	"leg_left": Rect2(56, 220, 100, 110),
	"leg_right": Rect2(162, 220, 100, 110),
}
const TOAST_NORMAL := "normal"      # play and block notes (ui_states N1)
const TOAST_WARN := "warn"          # save or system trouble: amber, long, tap to close (N2)
const TOAST_S: float = 3.5
const TOAST_WARN_S: float = 6.0
const TOAST_MAX: int = 4
## Millimetres on the S22+ held sideways: 720 view px over about 70 mm.
const PX_PER_MM: float = 10.3
const BRASS := Color(0.86, 0.72, 0.42)
const AMBER := Color(0.98, 0.66, 0.22)
## Stick-rim run (a setting): stay past 90% for 0.15 s to run, back under 75%
## to walk, so a shaking thumb does not flicker (field_unified 10, A3).
const RIM_IN: float = 0.9
const RIM_OUT: float = 0.75
const RIM_DWELL: float = 0.15
## Omens are pale bone, never a red flag (presentation_motion 93).
const OMEN_COL := Color(0.86, 0.84, 0.78, 0.85)
const MOAN_R: float = 20.0
const COMMANDS: Array = [["follow", "따라와"], ["wait", "대기"], ["search", "수색"], ["cover", "엄호"], ["retreat", "후퇴"]]

var game
var theme: Theme
var root: Control
var touch: Control
var overlay: Control
var clock_label: Label
var sun_bar: ProgressBar
var weather_label: Label
var radio_label: Label
var radio_left: float = 0.0
var portrait: PanelContainer
var portrait_style: StyleBoxFlat
var name_label: Label
var status_label: Label
var bag_bar: ProgressBar
var bag_label: Label
var weapon_label: Label
var allies_box: HBoxContainer
var ally_buttons: Array = []
var crew_button: Button
var context_button: Button
var context_rows: Array = []
var context_t: float = 0.0
var offer_box: HBoxContainer
var toast_box: VBoxContainer
var toasts: Array = []
var grab_button: Button
var grab_bar: ProgressBar
var grab_total: float = 1.0
var crouch_button: Button
var run_button: Button
var aim_button: Button
var manual_button: Button
var attack_button: Button
var shove_button: Button
var blood_button: Button
var lamp_button: Button
var lamp_hint_done: bool = false   # the one-time line when the key first shows
var pads: Array = []                   # Buttons the HUD hit-tests itself (any finger)
var fingers: Dictionary = {}           # touch index -> {"kind", "start", "ms", ...}
var stick_index: int = -1
var stick_origin := Vector2.ZERO
var stick_at := Vector2.ZERO
var auto_aim: bool = false             # the aim pad is held: the gun picks its target
var auto_t: float = 0.0
var auto_skip: int = 0                 # thumb slid along the pad: next target
var auto_free: bool = false            # thumb dragged off the pad: the aim follows it, enemy or bare ground
var stick_dash: bool = false           # double-tap run (a setting): this hold runs
var stick_push: float = 0.0
var rim_t: float = 0.0
var rim_run: bool = false
var stick_tap_ms: int = -10000
var stick_tap_pos := Vector2(-999, -999)
var pause_button: Button
var debug_panel: PanelContainer
var debug_label: Label
var modal: Control
var modal_paused_before: bool = false
var modal_open: bool = false
var modal_slows: bool = false      # the panel up slows the field instead of stopping it
var status_pads: Array = []        # the state icons, most urgent first
var status_rows: Array = []        # what each shows now (body.status_notes())
var bleed_hint_done: bool = false  # the one-time line that points at the blood key
var body_shown = null              # whose body picture is (or was last) up
var body_part: String = ""
var body_parts: Dictionary = {}    # part -> its button in the picture
var body_buttons: Array = []       # [{wound, aid, full}] of the rows shown
var fps_t: float = 0.0
var frame_ms: float = 0.0

var pressing: bool = false
var press_pos := Vector2.ZERO
var press_ms: int = 0
var aim_cancel: bool = false
var aim_armed: bool = false        # the finger has been off the shooter at least once
var aiming: bool = false
var aim_point := Vector3.ZERO
var aim_target = null
var melee_pending = null
var melee_holding: bool = false
var dest_marker := Vector3.INF


func setup(field_game) -> void:
	game = field_game
	layer = 10
	theme = UiTheme.make(22)
	root = Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	touch = Control.new()
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.gui_input.connect(_on_touch)
	root.add_child(touch)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	root.add_child(overlay)
	_build_top()
	_build_portrait()
	_build_allies()
	_build_thumbs()
	_build_toasts()
	_build_grab()
	_build_debug()


# ---------------------------------------------------------------- building

func _panel(color: Color = PANEL_BG) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _label(text: String, size: int = 22, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, cb: Callable, min_size := Vector2(96, 64), size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


## A thumb pad: drawn like a button, hit-tested by the HUD (any finger).
func _pad(text: String, at: Vector2, size: Vector2, font: int = 22, anchor: int = Control.PRESET_BOTTOM_RIGHT) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.size = size
	b.add_theme_font_size_override("font_size", font)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_anchors_preset(anchor)
	b.position = at
	root.add_child(b)
	pads.append(b)
	return b


## A toggle that is on keeps a brass rim; running glows amber (presentation_motion 5).
func _lit_style(b: Button, rim: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.27, 0.2, 0.98)
	sb.border_color = rim
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("hover_pressed", sb)
	b.add_theme_color_override("font_pressed_color", rim)
	b.add_theme_color_override("font_hover_pressed_color", rim)


func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(160, 10)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _build_top() -> void:
	# Tactical pause sits at the left end of the gauge row, about 11 mm, away
	# from the fight under the right thumb (presentation_motion 666274f).
	pause_button = _pad("멈춤", Vector2(16, 14), Vector2(11.0 * PX_PER_MM, 11.0 * PX_PER_MM), 22, Control.PRESET_TOP_LEFT)
	var tl := _panel()
	tl.position = Vector2(16 + 11.0 * PX_PER_MM + 10, 14)
	var v := VBoxContainer.new()
	tl.add_child(v)
	clock_label = _label("D1 10:30", 28)
	v.add_child(clock_label)
	sun_bar = _bar(Color(0.92, 0.78, 0.42))
	sun_bar.max_value = 1.0
	v.add_child(sun_bar)
	weather_label = _label(game.weather.label() + " · 영하 14도", 16, DIM)
	v.add_child(weather_label)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)
	radio_label = _label("", 22, INK)
	radio_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	radio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio_label.position = Vector2(-380, 18)
	radio_label.size = Vector2(760, 40)
	radio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	radio_label.add_theme_constant_override("outline_size", 6)
	root.add_child(radio_label)
	var tr := HBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-238, 14)
	tr.add_theme_constant_override("separation", 8)
	root.add_child(tr)
	tr.add_child(_button("−", _zoom.bind(4.0), Vector2(64, 56)))
	tr.add_child(_button("+", _zoom.bind(-4.0), Vector2(64, 56)))
	tr.add_child(_button("D", _toggle_debug, Vector2(56, 56)))


func _zoom(step: float) -> void:
	game.cam_size = clampf(game.cam_size + step, 14.0, 36.0)


func _toggle_debug() -> void:
	debug_panel.visible = not debug_panel.visible


func _build_portrait() -> void:
	portrait = _panel()
	portrait_style = portrait.get_theme_stylebox("panel").duplicate()
	portrait_style.set_border_width_all(0)
	portrait.add_theme_stylebox_override("panel", portrait_style)
	# Top left, under the clock: the bottom-left corner is the fixed stick's
	# (it sat under the thumb there). A tap on it opens the body picture; the
	# HUD hit-tests it itself, like the pads.
	portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
	portrait.position = PORTRAIT_AT
	portrait.custom_minimum_size = Vector2(PORTRAIT_W, 0)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	portrait.add_child(v)
	# Name and state share a line: the panel must end above the run and crouch keys.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	name_label = _label("열차장", 24)
	top.add_child(name_label)
	status_label = _label("멀쩡함", 18, DIM)
	top.add_child(status_label)
	weapon_label = _label("", 18, INK)
	v.add_child(weapon_label)
	bag_label = _label("가방", 16, DIM)
	v.add_child(bag_label)
	bag_bar = _bar(Color(0.75, 0.72, 0.6))
	bag_bar.custom_minimum_size = Vector2(260, 10)
	v.add_child(bag_bar)
	root.add_child(portrait)


func _build_allies() -> void:
	allies_box = HBoxContainer.new()
	allies_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	allies_box.position = Vector2(-300, -92)
	allies_box.add_theme_constant_override("separation", 10)
	root.add_child(allies_box)
	for p in game.squad:
		if p == game.player:
			continue
		var b := _button(_ally_text(p, ""), _ally_menu.bind(p), Vector2(150, 76), 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		allies_box.add_child(b)
		ally_buttons.append({"p": p, "b": b})
	crew_button = _button("작업조", work_panel, Vector2(110, 76), 18)
	crew_button.visible = false
	allies_box.add_child(crew_button)


## Thumb pads (field_unified 10, user 17:15, coordinators 18:10-18:30). Right:
## aim with a small 'manual' switch, attack, shove and the situation pad
## (only when there is something to do). Left, above the stick: run and
## crouch toggles, the two states that ride on moving; pause top left. These are pads, not Buttons: one thumb is
## on the stick, so the other is a second finger, which Godot buttons do not
## take. The HUD hit-tests them itself.
func _build_thumbs() -> void:
	attack_button = _pad("공격", Vector2(-160, -144), Vector2(140, 124), 26)
	aim_button = _pad("조준", Vector2(-312, -144), Vector2(140, 124), 26)
	manual_button = _pad("수동", Vector2(-312, -200), Vector2(92, 48), 18)
	shove_button = _pad("밀치기", Vector2(-160, -238), Vector2(140, 84))
	context_button = _pad("상황", Vector2(-312, -292), Vector2(140, 84), 20)
	# Running is a toggle, so no required move needs a double tap (presentation_motion 8c);
	# the stick rim and a double tap run only when set on the start screen.
	# Fixed spot just above where the left thumb rests: about 20 mm in, 35 mm
	# up, two 11 mm keys 3 mm apart (presentation_motion 5, 57446c8).
	var key := 11.0 * PX_PER_MM
	var up := -(35.0 * PX_PER_MM + key)
	run_button = _pad("뛰기", Vector2(20.0 * PX_PER_MM, up), Vector2(key, key), 22, Control.PRESET_BOTTOM_LEFT)
	crouch_button = _pad("웅크림", Vector2(20.0 * PX_PER_MM + key + 3.0 * PX_PER_MM, up), Vector2(key, key), 20, Control.PRESET_BOTTOM_LEFT)
	# The lantern key, a third in the row; it is there only after sunset.
	lamp_button = _pad("등불", Vector2(20.0 * PX_PER_MM + 2.0 * (key + 3.0 * PX_PER_MM), up), Vector2(key, key), 22, Control.PRESET_BOTTOM_LEFT)
	lamp_button.visible = false
	_lit_style(lamp_button, AMBER)
	_lit_style(run_button, AMBER)
	_lit_style(crouch_button, BRASS)
	# A blood drop on the portrait's corner while you bleed: one press stops the
	# worst of it and binds it (body_injury 4.6, 0f95fc0). Nothing more.
	# It sits at the portrait's right edge, clear of the stick.
	blood_button = _pad("지혈", PORTRAIT_AT + Vector2(PORTRAIT_W + 8.0, 0), Vector2(84, 64), 24, Control.PRESET_TOP_LEFT)
	blood_button.add_theme_color_override("font_color", WARN)
	blood_button.visible = false
	# State icons (user, build 47): press one and it says what it does to you.
	var sx := 0.0
	for i in STATUS_SLOTS:
		var size: Vector2 = STATUS_BIG if i < 2 else STATUS_SMALL
		var pad := _pad("", STATUS_AT + Vector2(sx, 0), size, 20 if i < 2 else 15, Control.PRESET_TOP_LEFT)
		pad.visible = false
		status_pads.append(pad)
		sx += size.x + 4.0
	for b in [manual_button, run_button, crouch_button, aim_button, attack_button, lamp_button]:
		b.toggle_mode = true
	# The bag sits on the left, above the fixed stick's catch ring. There is no
	# swap button here any more: swapping is inside the bag panel (build 47).
	var left := HBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left.position = Vector2(16, -340)
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	left.add_child(_button("가방", bag_panel, Vector2(110, 60), 20))
	offer_box = HBoxContainer.new()
	offer_box.set_anchors_preset(Control.PRESET_CENTER)
	offer_box.position = Vector2(-260, 90)
	offer_box.add_theme_constant_override("separation", 12)
	root.add_child(offer_box)


func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	# Right of the portrait and the blood key, under the state icons.
	toast_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	toast_box.position = STATUS_AT + Vector2(0, STATUS_BIG.y + 8.0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)


func _build_grab() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-140, 40)
	root.add_child(v)
	grab_button = _button("밀쳐!", _shove, Vector2(280, 120), 44)
	grab_button.add_theme_color_override("font_color", WARN)
	v.add_child(grab_button)
	grab_bar = _bar(WARN)
	grab_bar.custom_minimum_size = Vector2(280, 14)
	grab_bar.max_value = 1.0
	v.add_child(grab_bar)
	grab_button.visible = false
	grab_bar.visible = false


func _build_debug() -> void:
	debug_panel = _panel(Color(0, 0, 0, 0.72))
	debug_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_panel.position = Vector2(-430, 84)
	debug_panel.custom_minimum_size = Vector2(410, 0)
	var v := VBoxContainer.new()
	debug_panel.add_child(v)
	debug_label = _label("", 16, INK)
	v.add_child(debug_label)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(_button("배속", _debug_speed, Vector2(80, 48), 16))
	h.add_child(_button("FPS 상한", _debug_fps, Vector2(96, 48), 16))
	h.add_child(_button("시야 가림", _debug_mask, Vector2(96, 48), 16))
	h.add_child(_button("무리 지금", _debug_horde, Vector2(96, 48), 16))
	debug_panel.visible = false
	root.add_child(debug_panel)


func _debug_speed() -> void:
	game.clock.speed = 2.0 if game.clock.speed < 1.5 else 1.0


func _debug_fps() -> void:
	Engine.max_fps = 30 if Engine.max_fps != 30 else 60


func _debug_mask() -> void:
	game.mask_on = not game.mask_on


func _debug_horde() -> void:
	game.director.next_arrival = game.clock.elapsed


# ---------------------------------------------------------------- per frame

func tick(delta: float) -> void:
	if game == null or game.player == null:
		return
	fps_t -= delta
	frame_ms = lerpf(frame_ms, delta * 1000.0, 0.1)
	var p = game.player
	clock_label.text = game.clock.label()
	sun_bar.value = game.clock.sun_fraction()
	radio_left -= delta
	radio_label.modulate.a = clampf(radio_left / 1.5, 0.0, 1.0)
	_tick_portrait(p)
	_tick_allies()
	_tick_grab(p, delta)
	_tick_toasts(delta)
	context_t -= delta
	if context_t <= 0.0:
		context_t = 0.4
		_rebuild_context(p)
	# Hold on an enemy with a melee weapon: keep swinging (field_unified 10).
	if pressing and melee_pending != null and not melee_holding and Time.get_ticks_msec() - press_ms >= int(HOLD_TIME * 1000.0):
		melee_holding = true
		_melee(melee_pending, true)
	_tick_auto_aim(delta)
	_drop_stale_person()
	_tick_context_hold()
	if stick_index >= 0 and bool(game.opts.get("stick_rim_run", false)):
		var was := rim_run
		_update_rim(delta)
		if rim_run != was and p.stick != Vector2.ZERO:
			_set_running(p)
	# The attack pad stays lit while the fight goes on (one press, field_unified 10).
	attack_button.button_pressed = fighting(p)
	_tick_primary(p)
	blood_button.visible = p.body.bleed > 0 and (p.items.has("bandage") or p.items.has("medkit"))
	lamp_button.visible = game.clock.is_dark()
	lamp_button.button_pressed = game.lamps_on()
	if lamp_button.visible and not lamp_hint_done:
		lamp_hint_done = true
		toast("해가 졌다. 등불은 1분마다 들킨다. '등불'을 눌러 끄면 안 들키지만 멀리 안 보인다.")
	# The first time it shows, one line points at it (build 47: it was never found).
	if blood_button.visible and not bleed_hint_done:
		bleed_hint_done = true
		toast("피가 난다. 초상 옆 '지혈'을 누르면 붕대를 감는다.")
	_tick_status(p)
	pause_button.text = "계속" if game.paused else "멈춤"
	if debug_panel.visible and fps_t <= 0.0:
		fps_t = 0.25
		_tick_debug()
	overlay.queue_redraw()


## A finger still down on a raider who has just given up, ran or been taken:
## he stops being the target (nothing is struck, nothing is aimed at him).
func _drop_stale_person() -> void:
	if melee_pending != null and not (melee_pending is Dictionary) and not game.combat.hostile(melee_pending):
		melee_pending = null
		melee_holding = false
	if aim_target != null and not (aim_target is Dictionary) and not game.combat.hostile(aim_target):
		aim_target = null


func _tick_status(p) -> void:
	status_rows = p.body.status_notes()
	for i in status_pads.size():
		var pad: Button = status_pads[i]
		pad.visible = i < status_rows.size()
		if pad.visible:
			var row: Dictionary = status_rows[i]
			pad.text = String(row["short"])
			pad.add_theme_color_override("font_color", BRASS if row["good"] else (WARN if row["severe"] else INK))


## What a state icon says when pressed: the noun phrase, good or bad, and what it does.
func status_line(row: Dictionary) -> String:
	return "%s (%s): %s." % [row["title"], "좋음" if row["good"] else "나쁨", row["text"]]


func _tick_portrait(p) -> void:
	var lv: int = game.level_of(p.position)
	name_label.text = p.display_name + (" · %d층" % (lv + 1) if lv > 0 else (" · 지하" if lv < 0 else ""))
	var words: String = p.body.status_words()
	if p.cold_level() >= 1 and words == "멀쩡함":
		words = "추움"
	if p.blood_soaked:
		words += " · 피범벅"
	status_label.text = words
	status_label.add_theme_color_override("font_color", WARN if p.body.bleed >= 2 or p.body.infection == "bite" else DIM)
	# Cold shows as frost on the portrait border (s2_station 2.7, '추움' tier).
	var cold: bool = p.cold_level() >= 1
	portrait_style.set_border_width_all(4 if cold else 0)
	portrait_style.border_color = FROST
	var h: Dictionary = p.weapon()
	var wid: String = String(h.get("id", ""))
	var text := "맨손"
	if wid != "":
		var d: Dictionary = W.get_data(wid)
		text = "%s · %s" % [d.get("name", wid), W.CONDITION_NAMES[W.condition_level(float(h["condition"]))]]
		if bool(h.get("broken", false)):
			text = "%s · 망가짐" % d.get("name", wid)
		elif W.is_ranged(wid):
			text += "  %d/%d · 남은 %d" % [int(h["loaded"]), int(d["mag"]), int(game.ammo.get(d["ammo"], 0))]
			if p.jam_t > 0.0:
				text += " · 걸림"
			elif p.reload_t > 0.0:
				text += " · 장전"
	if p.hands.size() > 1:
		text += "   (허리: %s)" % W.get_data(p.hands[1]["id"]).get("name", "")
	weapon_label.text = text
	var lim: float = p.carry_limit()
	var wgt: float = p.weight()
	bag_bar.max_value = maxf(lim, 0.1)
	bag_bar.value = minf(wgt, lim)
	var state: int = p.carry_state()
	bag_label.text = "%s %.1f/%.0f · %s" % [Carry.BAGS[p.bag]["name"], wgt, lim, Carry.STATE_NAMES[state]]
	(bag_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = WARN if state >= 2 else Color(0.75, 0.72, 0.6)


## Short name of the weapon in hand ("펌프식 산탄총" -> "산탄총").
func short_weapon(p) -> String:
	var id: String = p.weapon_id()
	if id == "":
		return "맨손"
	var parts: PackedStringArray = String(W.get_data(id).get("name", id)).split(" ")
	return parts[parts.size() - 1]


## An ally's button: name and the weapon held, then what they are doing.
func _ally_text(p, second: String) -> String:
	var first := "%s · %s" % [p.display_name, short_weapon(p)]
	return first if second == "" else first + "\n" + second


func _tick_allies() -> void:
	for row in ally_buttons:
		var p = row["p"]
		var b: Button = row["b"]
		var cmd := ""
		for c in COMMANDS:
			if c[0] == p.command:
				cmd = c[1]
		var word: String = p.body.status_words()
		if not p.grabbers.is_empty():
			word = "잡힘!"
		elif p.brain.get("boarded", false):
			word = "열차에"
		elif p.action != "":
			word = p.action_label
		b.text = _ally_text(p, "%s · %s" % [cmd, word])
		b.modulate = Color(1, 0.6, 0.55) if not p.grabbers.is_empty() or p.body.downed else (Color(0.6, 0.6, 0.6) if not p.is_alive() else Color.WHITE)
	crew_button.visible = game.actions.work_started
	if crew_button.visible:
		var alive := 0
		for c in game.crew:
			if c.is_alive():
				alive += 1
		crew_button.text = "작업조 %d\n석탄 %.1f" % [alive, game.actions.coal_delivered]


func _tick_grab(p, delta: float) -> void:
	var grabbed: bool = not p.grabbers.is_empty()
	grab_button.visible = grabbed
	grab_bar.visible = grabbed
	if grabbed:
		grab_bar.value = clampf(p.grab_left / maxf(grab_total, 0.01), 0.0, 1.0)


func grab_alert(front: bool) -> void:
	grab_total = maxf(game.player.grab_left, 0.01)
	toast("잡혔다! 밀쳐라." if front else "뒤에서 잡혔다! 밀쳐라.")


func _tick_toasts(delta: float) -> void:
	for t in toasts.duplicate():
		t["t"] -= delta
		t["l"].modulate.a = clampf(t["t"] / 0.8, 0.0, 1.0)
		if t["t"] <= 0.0:
			_toast_drop(t)


func _tick_debug() -> void:
	var now: float = game.clock.elapsed
	var alive := 0
	for z in game.zombies.list:
		if game.zombies.threat(z) and z["state"] != "frozen":
			alive += 1
	var next: float = game.director.seconds_to_next(now)
	var track: Dictionary = game.track_dead()
	debug_label.text = "FPS %d · 프레임 %.1fms · 상한 %d\n좀비 화면 %d · 살아 있음 %d / 동시 상한 %d · 대기 %d\n소음 점수 %d · 다음 무리 %s초 (%s)\n부르는 범위 ×%.2f · 무리 %d · 시계 ×%.0f · 필드 %d초\n선로 위 망자 서 %d · 동 %d · %s" % [
		Engine.get_frames_per_second(), frame_ms, Engine.max_fps,
		game.zombies.drawn_count, alive, game.cap, game.waiting,
		game.ledger.total, "-" if is_inf(next) else str(roundi(next)), HordeDirector.ENTRY_NAMES.get(game.director.next_entry, ""),
		game.director.call_range_mult(now), game.hordes.size(), game.clock.speed, roundi(now),
		track["west"], track["east"], "시야 가림 켬" if game.mask_on else "시야 가림 끔",
	]


## The situation pad shows the nearest thing to do; a tap does it, a hold
## lays out the rest (open, pick up, door, stairs, bandage, depart...).
func _rebuild_context(p) -> void:
	context_rows = [] if game.ended else game.actions.context(p)
	# It rises only when there is something to do; otherwise the spot is empty.
	context_button.visible = not context_rows.is_empty()
	if context_rows.is_empty():
		return
	var more: int = context_rows.size() - 1
	context_button.text = String(context_rows[0]["label"]) + ("\n+%d (누르고 있기)" % more if more > 0 else "")


func _context_tap() -> void:
	_rebuild_context(game.player)
	if context_rows.is_empty():
		return
	_run_context(context_rows[0]["call"])


func _context_list() -> void:
	_rebuild_context(game.player)
	if context_rows.size() > 0:
		offer(context_rows)


func _tick_context_hold() -> void:
	for f in fingers.values():
		if f["kind"] == "pad" and f["pad"] == context_button and not f.get("opened", false) and Time.get_ticks_msec() - int(f["ms"]) >= int(HOLD_TIME * 1000.0):
			f["opened"] = true
			_context_list()


func _run_context(cb: Callable) -> void:
	cb.call()
	context_t = 0.0


# ---------------------------------------------------------------- messages

## A note on the left. Normal ones fade in 3.5 s; a warn one stays 6 s, is
## amber (never red) and goes away when tapped. One warn at a time, and a
## normal note never pushes a warn out. Cries in the scene ("잡혔다!") stay normal.
func toast(text: String, kind: String = TOAST_NORMAL) -> void:
	if toast_box == null:
		return
	if kind == TOAST_WARN:
		_toast_warn(text)
		return
	var l := _label(text, 20, INK)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	toast_box.add_child(l)
	toasts.append({"l": l, "t": TOAST_S, "kind": TOAST_NORMAL})
	while toasts.size() > TOAST_MAX:
		var oldest: Dictionary = toasts[0]
		for t in toasts:
			if t["kind"] == TOAST_NORMAL:
				oldest = t
				break
		_toast_drop(oldest)


func _toast_warn(text: String) -> void:
	for t in toasts.duplicate():
		if t["kind"] == TOAST_WARN:
			_toast_drop(t)
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(480, 0)
	b.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.12, 0.1, 0.94)
	sb.border_color = AMBER
	sb.set_border_width_all(1)
	sb.border_width_left = 4
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, sb)
	toast_box.add_child(b)
	var entry := {"l": b, "t": TOAST_WARN_S, "kind": TOAST_WARN}
	toasts.append(entry)
	b.pressed.connect(_toast_drop.bind(entry))


func _toast_drop(entry: Dictionary) -> void:
	if is_instance_valid(entry["l"]):
		entry["l"].queue_free()
	toasts.erase(entry)


func radio(text: String) -> void:
	if radio_label == null:
		return
	radio_label.text = text
	radio_left = 8.0


## A short row of choices in the middle (break a window, how to climb...).
func offer(list: Array) -> void:
	for c in offer_box.get_children():
		c.queue_free()
	for row in list:
		offer_box.add_child(_button(row["label"], _offer_pick.bind(row["call"]), Vector2(180, 72)))
	offer_box.add_child(_button("그만", _offer_pick.bind(Callable()), Vector2(100, 72)))


func _offer_pick(cb: Callable) -> void:
	for c in offer_box.get_children():
		c.queue_free()
	if cb.is_valid():
		cb.call()


# ---------------------------------------------------------------- modal panels

## pauses false: the field goes on at BODY_SLOW under the panel (the body picture).
func _open_modal(width: float = 640.0, pauses: bool = true) -> VBoxContainer:
	_close_modal()
	# Fingers held now will lift under the panel: let go of them first.
	drop_touch()
	modal_slows = not pauses
	if pauses:
		modal_paused_before = game.paused
		game.paused = true
	else:
		game.slow = BODY_SLOW
	modal_open = true
	body_buttons = []
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel := _panel(Color(0.09, 0.09, 0.1, 0.96))
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	root.add_child(modal)
	return v


func _close_modal() -> void:
	if modal != null:
		modal.queue_free()
		modal = null
		if modal_open and not modal_slows:
			game.paused = modal_paused_before
		game.slow = 1.0
		modal_slows = false
		modal_open = false


## The body picture (body_injury 4.6): six parts, the wounds of the part
## chosen, and two buttons a wound: first aid (blood only) and full care (every
## step the tools allow; a step whose tool is missing is named and the run
## stops there). The most urgent wound comes chosen. While it is open the field
## runs at BODY_SLOW, it does not stop; pressing a button closes it and the
## care goes on in the field at its own pace.
func body_panel(o = null, part: String = "") -> void:
	var p = game.player
	if o == null:
		o = p
	var v := _open_modal(920.0, false)
	body_shown = o
	var urgent: int = o.body.most_urgent()
	if part == "":
		part = String(o.body.wounds[urgent]["part"]) if urgent >= 0 else "torso"
	body_part = part
	v.add_child(_label("%s · %s" % [o.display_name, o.body.status_words()], 24))
	var have: Dictionary = game.actions.care_tools(p, o)
	v.add_child(_label("가진 것: 붕대 %d · 술 %d · 판자 %d · 천 %d · 핀셋 %d · 바늘과 실 %d" % [int(have.get("bandage", 0)), int(have.get("bottle_spirit", 0)), int(have.get("plank", 0)) + int(have.get("wood", 0)), int(have.get("cloth", 0)), int(have.get("tweezers", 0)), int(have.get("needle_thread", 0))], 18, DIM))
	var near: bool = game.actions.in_care_reach(p, o)
	if not near:
		v.add_child(_label("가까이 가야 처치할 수 있다.", 18, WARN))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	v.add_child(h)
	h.add_child(_body_figure(o, part))
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(540, 0)
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	right.add_child(_label(Treatment.PART_NAMES[part], 22, BRASS))
	var rows: Array = body_rows(o, part)
	if rows.is_empty():
		right.add_child(_label("다친 데가 없다.", 20, DIM))
	for w: Dictionary in rows:
		var first: bool = urgent >= 0 and is_same(w, o.body.wounds[urgent])
		right.add_child(_label(Treatment.wound_text(w) + (" · 가장 급함" if first else ""), 20, WARN if float(w["blood"]) >= BodyState.HEAVY_BLOOD else INK))
		var full: Array = game.actions.care_plan(p, o, w, Treatment.FULL)
		var steps := _label(Treatment.steps_text(full), 16, DIM)
		steps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		steps.custom_minimum_size = Vector2(520, 0)
		right.add_child(steps)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		right.add_child(hb)
		var aid := _button("응급", _care.bind(o, w, Treatment.FIRST_AID), Vector2(150, 60), 20)
		aid.disabled = not near or Treatment.runnable(game.actions.care_plan(p, o, w, Treatment.FIRST_AID)).is_empty()
		hb.add_child(aid)
		var all := _button("정밀", _care.bind(o, w, Treatment.FULL), Vector2(150, 60), 20)
		all.disabled = not near or Treatment.runnable(full).is_empty()
		hb.add_child(all)
		body_buttons.append({"wound": w, "aid": aid, "full": all})
	v.add_child(_button("닫기", _close_modal, Vector2(140, 60)))


## The wounds on a part, the most urgent first.
func body_rows(o, part: String) -> Array:
	var rows: Array = []
	for i in o.body.wounds.size():
		if o.body.wounds[i]["part"] == part:
			rows.append([o.body._order_key(i), -i, o.body.wounds[i]])
	rows.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
	return rows.map(func(r): return r[2])


## Six parts laid out like a body. A part that bleeds is dark brown (no red,
## nothing gory); the chosen one has a brass rim.
func _body_figure(o, chosen: String) -> Control:
	var fig := Control.new()
	fig.custom_minimum_size = Vector2(318, 330)
	body_parts = {}
	for part: String in BODY_LAYOUT:
		var r: Rect2 = BODY_LAYOUT[part]
		var kinds: Array = []
		var blood := 0.0
		var festering := false
		for w: Dictionary in o.body.wounds:
			if w["part"] == part:
				blood += float(w["blood"])
				festering = festering or bool(w["festering"])
				var k: String = Treatment.KIND_NAMES[w["kind"]]
				if not kinds.has(k):
					kinds.append(k)
		var text: String = Treatment.PART_NAMES[part]
		if not kinds.is_empty():
			text += "\n" + "\n".join(kinds.slice(0, 2)) + ("…" if kinds.size() > 2 else "")
		var b := _button(text, body_panel.bind(o, part), r.size, 16)
		b.position = r.position
		b.size = r.size
		var sb := StyleBoxFlat.new()
		sb.bg_color = BLOOD_BROWN if blood > 0.0 else (Color(0.2, 0.2, 0.2, 0.95) if kinds.is_empty() else Color(0.3, 0.29, 0.26, 0.95))
		sb.set_corner_radius_all(6)
		# The chosen part wears brass; a festering one a sallow rim (inside the brass when both).
		sb.set_border_width_all(4 if part == chosen else (3 if festering else 0))
		sb.border_color = BRASS if part == chosen else FESTER_RIM
		if festering:
			text += "\n곪음"
			b.text = text
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, sb)
		fig.add_child(b)
		body_parts[part] = b
	return fig


func _care(o, wound: Dictionary, mode: String) -> void:
	_close_modal()
	if not game.actions.treat_wound(game.player, o, wound, mode):
		toast("지금은 처치할 수 없다.")


## Decision card: the line the leader shouts, and the cost under it (S1a style).
func card(id: String, text: String, options: Array, cb: Callable) -> void:
	var v := _open_modal(720.0)
	var t := _label(text, 24)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	for o in options:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(680, 84)
		b.add_theme_font_size_override("font_size", 20)
		b.text = "%s\n%s%s" % [o["label"], o.get("say", ""), ("\n" + String(o["cost"])) if o.has("cost") else ""]
		b.pressed.connect(_card_pick.bind(cb, String(o["id"])))
		v.add_child(b)


func _card_pick(cb: Callable, choice: String) -> void:
	_close_modal()
	if cb.is_valid():
		cb.call(choice)


func loot(id: String) -> void:
	var c: Dictionary = game.data["containers"][id]
	var p = game.player
	var v := _open_modal(560.0)
	v.add_child(_label(c["name"], 26))
	v.add_child(_label("가방 %.1f / %.0f" % [p.weight(), p.carry_limit()], 18, DIM))
	if c["items"].is_empty():
		v.add_child(_label("빈 곳이다.", 20, DIM))
	for i in range(c["items"].size()):
		var item: String = c["items"][i]
		v.add_child(_button("%s  (%.1f)" % [game.item_name(item), Carry.item_weight(item)], _loot_take.bind(id, i), Vector2(520, 56), 20))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	if not c["items"].is_empty():
		h.add_child(_button("모두 담기", _loot_all.bind(id), Vector2(200, 64)))
	h.add_child(_button("닫기", _close_modal, Vector2(140, 64)))


func _loot_take(id: String, i: int) -> void:
	game.actions.take(game.player, id, i)
	loot(id)


func _loot_all(id: String) -> void:
	game.actions.take_all(game.player, id)
	_close_modal()


func bag_panel() -> void:
	var p = game.player
	var v := _open_modal(560.0)
	v.add_child(_label("%s · %.1f / %.0f · %s" % [Carry.BAGS[p.bag]["name"], p.weight(), p.carry_limit(), Carry.STATE_NAMES[p.carry_state()]], 22))
	if p.hands.size() > 1:
		var hw := HBoxContainer.new()
		hw.add_child(_label("손 %s · 허리 %s" % [short_weapon(p), W.get_data(p.hands[1]["id"]).get("name", "")], 20))
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hw.add_child(gap)
		hw.add_child(_button("바꾸기", _swap_from_bag, Vector2(120, 52), 18))
		v.add_child(hw)
	if p.items.is_empty():
		v.add_child(_label("빈 가방이다.", 20, DIM))
	for id in p.items.keys():
		var h := HBoxContainer.new()
		h.add_child(_label("%s ×%d  (%.1f)" % [game.item_name(id), int(p.items[id]), Carry.item_weight(id) * int(p.items[id])], 20))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(spacer)
		h.add_child(_button("내려놓기", _drop.bind(id), Vector2(120, 52), 18))
		v.add_child(h)
	v.add_child(_label("탄: 권총 %d · 산탄 %d · 화살 %d" % [int(game.ammo["pistol"]), int(game.ammo["shell"]), int(game.ammo["craft"])], 18, DIM))
	v.add_child(_button("닫기", _close_modal, Vector2(140, 60)))


func _swap_from_bag() -> void:
	_close_modal()
	_swap()


func _drop(id: String) -> void:
	var p = game.player
	var n: int = int(p.items.get(id, 0))
	if n <= 0:
		return
	p.take_item(id, n)
	game.ground_items.append({"pos": p.position + Vector3(0.4, 0, 0.4), "id": id, "n": n})
	bag_panel()


func _ally_menu(p) -> void:
	if not p.is_alive():
		return
	var v := _open_modal(520.0)
	v.add_child(_label("%s · %s" % [p.display_name, p.body.status_words()], 24))
	var weapons: Array = []
	for h in p.hands:
		weapons.append(W.get_data(h["id"]).get("name", h["id"]))
	v.add_child(_label("손: %s · 가방 %.1f/%.0f" % [", ".join(weapons), p.weight(), p.carry_limit()], 18, DIM))
	var g := GridContainer.new()
	g.columns = 3
	v.add_child(g)
	for c in COMMANDS:
		g.add_child(_button(c[1], _command.bind(p, c[0]), Vector2(150, 64)))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	foot.add_child(_button("몸 상태", body_panel.bind(p), Vector2(150, 60)))
	foot.add_child(_button("닫기", _close_modal, Vector2(140, 60)))


func _command(p, cmd: String) -> void:
	p.command = cmd
	p.brain["boarded"] = false
	p.target_zombie = {}
	p.aim.stop()
	match cmd:
		"wait":
			p.command_target = p.position
		"search":
			p.command_target = game.player.position
	_close_modal()


## Work crew settings: attitude and fire permission per crew (s2_station 2.4).
func work_panel() -> void:
	var v := _open_modal(620.0)
	v.add_child(_label("석탄 작업 · 남은 석탄 %.1f · 실은 석탄 %.1f" % [game.actions.coal_left(), game.actions.coal_delivered], 22))
	v.add_child(_label("호위조 태도", 18, DIM))
	var h1 := HBoxContainer.new()
	v.add_child(h1)
	for row in [["aggressive", "공격적"], ["defensive", "방어적"], ["neutral", "중립"]]:
		var b := _button(row[1] + (" ●" if game.ai.crew_attitude == row[0] else ""), _set_crew.bind("attitude", row[0]), Vector2(170, 60))
		h1.add_child(b)
	v.add_child(_label("사격 허가", 18, DIM))
	var h2 := HBoxContainer.new()
	v.add_child(h2)
	for row in [["free", "자유"], ["threat", "위협만"], ["melee", "근접만"]]:
		h2.add_child(_button(row[1] + (" ●" if game.ai.crew_fire == row[0] else ""), _set_crew.bind("fire", row[0]), Vector2(170, 60)))
	var h3 := HBoxContainer.new()
	v.add_child(h3)
	h3.add_child(_button("작업조 철수", _set_crew.bind("recall", ""), Vector2(200, 64)))
	h3.add_child(_button("닫기", _close_modal, Vector2(140, 64)))


func _set_crew(key: String, value: String) -> void:
	match key:
		"attitude":
			game.ai.crew_attitude = value
		"fire":
			game.ai.crew_fire = value
		"recall":
			game.ai.crew_recalled = true
			_close_modal()
			return
	work_panel()


## Departure: the leader on the platform blows the whistle; who is not here stays.
func depart_card() -> void:
	var left: Array = []
	for p in game.squad + game.crew:
		if not p.is_alive() or p.brain.get("boarded", false):
			continue
		if not game.actions.on_platform(p) or p.body.downed:
			left.append(p.display_name)
	var text := "기적을 울리고 떠난다. 기적 소리는 멀리까지 간다."
	if not left.is_empty():
		text += "\n승강장에 없는 사람: %s. 이들은 남는다." % ", ".join(left)
	# Words, not seconds: arrival spreads too widely to promise a number
	# (s2_play/measure_depart.md: 30 m leaves about 20 s to 10 m).
	if horde_close():
		text += "\n무리가 가깝다."
	card("depart", text, [
		{"id": "go", "label": "떠난다", "say": "\"올라타! 기다리지 않는다!\""},
		{"id": "wait", "label": "기다린다", "say": "\"조금만 더. 다 올 때까지.\""},
	], _depart_pick)
	game.audio.hold(true)


## Some dead of a horde within 30 m of the player (presentation_motion 5b.5).
func horde_close() -> bool:
	for z in game.zombies.list:
		if int(z["horde"]) >= 0 and game.zombies.threat(z) and z["pos"].distance_to(game.player.position) <= 30.0:
			return true
	return false


func _depart_pick(choice: String) -> void:
	game.audio.hold(false)
	if choice == "go":
		game.audio.depart()
		game.finish("departed")


func show_end(result: Dictionary) -> void:
	_close_modal()
	context_rows = []
	var v := _open_modal(820.0)
	game.paused = true
	var reason: String = {"departed": "출발했다", "limit": "기다릴 수 있는 시간이 끝났다", "wiped": "수색대가 모두 쓰러졌다"}.get(result["reason"], result["reason"])
	v.add_child(_label("술레후프 · " + reason, 28))
	var r: Dictionary = result["receipt"]
	var lines: Array = []
	lines.append("머문 시간: 게임 %d분 (실제 %d분 %d초)" % [int(result["stay"]), int(result["real_seconds"]) / 60, int(result["real_seconds"]) % 60])
	lines.append("탄 사람: %d명 · 무리 %d번 · 소음 점수 %d" % [int(result["boarded"]), int(result["hordes"]), int(result["noise"])])
	var stock: Dictionary = r.get("stock", {})
	var parts: Array = []
	var names := {"coal": "석탄", "food": "식량", "medicine": "의약품", "luxury": "사치품", "symbol": "상징물", "info": "정보", "scrap": "고철", "wood": "목재", "ammo_pistol": "권총탄", "ammo_shell": "산탄", "ammo_craft": "공방탄"}
	for k in stock:
		parts.append("%s %+d" % [names.get(k, k), int(stock[k])])
	lines.append("영수증: " + (", ".join(parts) if not parts.is_empty() else "변화 없음"))
	var people: Dictionary = r.get("people", {})
	for key in [["leftBehind", "남은 사람"], ["bitten", "물린 사람"], ["injured", "다친 사람"], ["dead", "죽은 사람"]]:
		var ids: Array = people.get(key[0], [])
		if not ids.is_empty():
			lines.append("%s: %s" % [key[1], ", ".join(_names(ids))])
	for d in game.decisions:
		lines.append("결정: %s → %s" % [d["id"], d["choice"]])
	var body := _label("\n".join(lines), 20)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	h.add_child(_button("영수증 복사", _copy.bind(result["receipt_json"], "영수증을 복사했다."), Vector2(200, 64)))
	h.add_child(_button("기록 복사", _copy.bind(result["telemetry"], "기록을 복사했다."), Vector2(180, 64)))
	h.add_child(_button("다시", _restart, Vector2(140, 64)))


func _copy(text: String, note: String) -> void:
	DisplayServer.clipboard_set(text)
	toast(note)


func _restart() -> void:
	game.restart_requested.emit()


func _names(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var n: String = id
		for p in game.people:
			if p.pid == id:
				n = p.display_name
		out.append(n)
	return out


func _swap() -> void:
	game.combat.swap(game.player)


func _toggle_pause() -> void:
	if modal_open:
		return
	game.paused = not game.paused


func _toggle_crouch() -> void:
	var p = game.player
	p.crouched = crouch_button.button_pressed
	if p.crouched:
		p.running = false
		run_button.button_pressed = false


func _toggle_run() -> void:
	var p = game.player
	if run_button.button_pressed:
		p.crouched = false
		crouch_button.button_pressed = false
	if p.moving:
		p.running = run_button.button_pressed


func run_hold() -> bool:
	return String(game.opts.get("run_mode", "toggle")) == "hold"


## The run key let go in hold mode: the run ends unless the stick keeps it going.
func _run_key_up() -> void:
	run_button.button_pressed = false
	if game.player != null:
		game.player.running = stick_dash or rim_run


func _shove() -> void:
	var p = game.player
	if game.paused:
		toast("멈춘 동안은 밀치지 못한다.")
		return
	if not p.grabbers.is_empty():
		game.combat.break_grab(p)
	elif p.can_act():
		game.combat.shove(p)


# ---------------------------------------------------------------- input

## Fingers on a phone: every touch index, so the left thumb can hold the
## stick while the right one aims or presses a pad.
func _input(event: InputEvent) -> void:
	if game == null or game.ended:
		return
	if modal_open:
		# A panel is up: its buttons get the touch, but a lift or cancel still
		# clears any finger the field held (never fires, never taps).
		if event is InputEventScreenTouch and not event.pressed:
			finger_cancel(event.index)
		return
	if event is InputEventScreenTouch:
		# A cancelled touch is not a lift: no shot, no tap.
		var used: bool
		if event.canceled:
			used = finger_cancel(event.index)
		else:
			used = finger_down(event.index, event.position) if event.pressed else finger_up(event.index, event.position)
		if used:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if finger_move(event.index, event.position):
			get_viewport().set_input_as_handled()


## A desktop mouse is one finger (index 0). Mouse events a touch screen makes
## up for its first finger are skipped: _input already has that finger.
func _on_touch(event: InputEvent) -> void:
	if game == null or game.ended:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			finger_down(0, event.position)
		else:
			finger_up(0, event.position)
	elif event is InputEventMouseMotion and fingers.has(0):
		finger_move(0, event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		game.cam_size = maxf(game.cam_size - 2.0, 14.0)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		game.cam_size = minf(game.cam_size + 2.0, 36.0)


## Who gets a new finger: a pad, an ordinary button (left to Godot for the
## first finger, pressed by hand for the others), the stick on the left
## half, or the right hand (aim in manual mode, an enemy, a thing to use).
func finger_down(index: int, pos: Vector2) -> bool:
	# The same index again means its lift was lost (the app went away): let the
	# old stick go before the new finger is read.
	if fingers.has(index) and fingers[index]["kind"] == "stick":
		fingers.erase(index)
		stick_index = -1
		stick_dash = false
		_stick_release()
	for b in pads:
		if b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			fingers[index] = {"kind": "pad", "pad": b, "start": pos, "ms": Time.get_ticks_msec()}
			_pad_down(b, pos)
			return true
	# The portrait: a tap opens the body picture (on the lift, if it never moved).
	if portrait.get_global_rect().has_point(pos):
		fingers[index] = {"kind": "portrait", "start": pos}
		return true
	# A ring 4 mm round the run and crouch keys starts nothing: setting the
	# stick down there must not toggle them, nor plant a stick on their edge.
	for b in [run_button, crouch_button]:
		if b.get_global_rect().grow(4.0 * PX_PER_MM).has_point(pos):
			return true
	var ui := _button_at(pos)
	if ui != null:
		if index != 0:
			fingers[index] = {"kind": "button", "button": ui, "start": pos}
			return true
		return false
	var floats := stick_floats()
	var in_reach: bool = pos.x < _view_size().x * 0.5 if floats else pos.distance_to(stick_home()) <= STICK_R * STICK_CATCH
	if in_reach and stick_index < 0:
		stick_index = index
		# Fixed (default): the base stays at home and the touch is the knob.
		# Floating (a setting): the base is wherever the thumb landed.
		stick_origin = pos if floats else stick_home()
		stick_at = pos
		var now := Time.get_ticks_msec()
		# Double-tap run (a setting, off by default): tap, then hold and push.
		stick_dash = bool(game.opts.get("double_tap_run", false)) and now - stick_tap_ms < DOUBLE_TAP_MS and pos.distance_to(stick_tap_pos) < 80.0
		fingers[index] = {"kind": "stick", "start": pos, "ms": now, "fixed": not floats}
		if not floats:
			_apply_stick()
		return true
	if fingers.values().any(func(f): return f["kind"] == "hand"):
		return false
	fingers[index] = {"kind": "hand", "start": pos}
	_press(pos)
	return true


func finger_move(index: int, pos: Vector2) -> bool:
	if not fingers.has(index):
		return false
	var f: Dictionary = fingers[index]
	match f["kind"]:
		"stick":
			stick_at = pos
			_apply_stick()
		"pad":
			_pad_move(f["pad"], pos, f)
		"hand":
			_hand_move(pos)
	return true


func finger_up(index: int, pos: Vector2) -> bool:
	if not fingers.has(index):
		return false
	var f: Dictionary = fingers[index]
	fingers.erase(index)
	match f["kind"]:
		"stick":
			stick_index = -1
			stick_dash = false
			_stick_release()
			# A short touch that never moved is a tap on whatever is there; in a
			# fight it is only a thumb set down, not an order to stop.
			# The fixed stick is not the world: a tap on it is only a thumb set down.
			if pos.distance_to(f["start"]) < DRAG_PX and Time.get_ticks_msec() - int(f["ms"]) < 350 and not fighting(game.player):
				stick_tap_ms = Time.get_ticks_msec()
				stick_tap_pos = pos
				if not f.get("fixed", false):
					_tap(pos)
		"pad":
			_pad_up(f["pad"], pos, f)
		"button":
			var b: Button = f["button"]
			if b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
				if b.toggle_mode:
					b.button_pressed = not b.button_pressed
				b.pressed.emit()
		"hand":
			_release(pos)
		"portrait":
			if pos.distance_to(f["start"]) < DRAG_PX and portrait.get_global_rect().has_point(pos):
				body_panel()
	return true


## The system took this finger away (a cancelled touch): let go of what it
## held without firing, tapping or pressing anything.
func finger_cancel(index: int) -> bool:
	if not fingers.has(index):
		return false
	var f: Dictionary = fingers[index]
	fingers.erase(index)
	match f["kind"]:
		"stick":
			stick_index = -1
			stick_dash = false
			_stick_release()
		"pad":
			if auto_aim:
				aim_cancel = true
				_auto_aim_end(Vector2.ZERO)
			for b in [aim_button, context_button, shove_button]:
				if f["pad"] == b:
					b.button_pressed = false
			if f["pad"] == run_button and run_hold():
				_run_key_up()
		"hand":
			if aiming and game.player.aim.active:
				game.player.aim.stop()
			pressing = false
			aiming = false
			aim_cancel = false
			aim_armed = false
			aim_target = null
			melee_pending = null
			if melee_holding:
				game.combat.stop_holding(game.player)
			melee_holding = false
	return true


func _view_size() -> Vector2:
	return root.get_viewport_rect().size


## An ordinary visible button under the point (cards, companions, context).
func _button_at(pos: Vector2) -> Button:
	var stack: Array = [root]
	var hit: Button = null
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is Button and n.mouse_filter != Control.MOUSE_FILTER_IGNORE and n.is_visible_in_tree() and n.get_global_rect().has_point(pos):
			hit = n
		for c in n.get_children():
			if c is Control and c.visible:
				stack.append(c)
	return hit


# ---------------------------------------------------------------- stick

func _apply_stick() -> void:
	var p = game.player
	var v := stick_at - stick_origin
	if v.length() > STICK_R:
		if stick_floats():
			stick_origin = stick_at - v.normalized() * STICK_R   # the floating base follows a long drag
			v = stick_at - stick_origin
		else:
			v = v.normalized() * STICK_R                          # the fixed base stays put
	if v.length() < STICK_DEAD:
		# Back in the dead zone: no push left over to run on.
		p.stick = Vector2.ZERO
		stick_push = 0.0
		rim_t = 0.0
		rim_run = false
		p.running = run_button.button_pressed or stick_dash
		return
	# The camera looks north with no turn: screen right is +x, screen down is +z.
	var push := clampf(v.length() / STICK_R, 0.0, 1.0)
	stick_push = push
	if fighting(p):
		# A resting thumb, or a push at the one being hit, keeps the fight going;
		# a real push elsewhere calls it off (field_unified 10).
		var to := _fight_dir(p)
		if push < STICK_STOPS_FIGHT or (to != Vector2.ZERO and v.normalized().dot(to) > 0.7):
			p.stick = Vector2.ZERO
			return
		stop_fight(p)
	p.stick = v.normalized() * push
	game.combat.drop_melee(p)
	_update_rim(0.0)
	_set_running(p)


## The floating stick is a start-screen option; the default is fixed at home.
func stick_floats() -> bool:
	return bool(game.opts.get("stick_float", false))


## Where the fixed stick sits (bottom-left, under the run and crouch keys).
func stick_home() -> Vector2:
	return Vector2(STICK_HOME_MM.x * PX_PER_MM, _view_size().y - STICK_HOME_MM.y * PX_PER_MM)


## Running from the stick, the run key or the rim; running stands you up.
func _set_running(p) -> void:
	p.running = run_button.button_pressed or stick_dash or rim_run
	if p.running:
		p.crouched = false
		crouch_button.button_pressed = false


## Stick-rim running with a way in and a way out (a setting, off by default).
func _update_rim(delta: float) -> void:
	if not bool(game.opts.get("stick_rim_run", false)) or stick_index < 0 and delta > 0.0:
		rim_t = 0.0
		rim_run = false
		return
	if stick_push >= RIM_IN:
		rim_t += delta
		if rim_t >= RIM_DWELL - 0.0001:
			rim_run = true
	elif stick_push < RIM_OUT:
		rim_t = 0.0
		rim_run = false
	else:
		rim_t = 0.0


func _stick_release() -> void:
	var p = game.player
	stick_push = 0.0
	rim_t = 0.0
	rim_run = false
	p.stick = Vector2.ZERO
	p.running = run_button.button_pressed


# ---------------------------------------------------------------- pads

func _pad_down(b: Button, pos: Vector2) -> void:
	var p = game.player
	if b == aim_button and primary_melee(p):
		b = attack_button
	if status_pads.has(b):
		var slot: int = status_pads.find(b)
		if slot < status_rows.size():
			toast(status_line(status_rows[slot]))
		return
	if b == blood_button:
		# Say what the press does: it was pressed without knowing (build 47).
		var worst: int = p.body._top_bleeder()
		if worst >= 0 and p.action == "" and p.can_act():
			toast("지혈한다: %s." % Treatment.wound_text(p.body.wounds[worst]))
		game.actions.self_bandage(p)
	elif b == aim_button:
		aim_button.button_pressed = true
		_auto_aim_start()
	elif b == attack_button:
		# One press fights the one in reach until it is down, then the next
		# within 2 m; a second press stops (field_unified 10, coordinator 18:10).
		if fighting(p):
			stop_fight(p)
			return
		var t = game.combat.melee_pick(p)
		if t == null:
			toast("팔 닿는 데에 아무도 없다.")
			return
		_melee(t, true)
		attack_button.button_pressed = true
	elif b == context_button:
		context_button.button_pressed = true
	elif b == pause_button:
		_toggle_pause()
	elif b == lamp_button:
		game.set_lamps(not game.lamps_on())
		lamp_button.button_pressed = game.lamps_on()
		toast("등불을 켰다. 1분마다 불빛이 들킨다." if game.lamps_on() else "모두 등불을 껐다. 불빛으로는 안 들킨다. 멀리 안 보인다.")
	elif b == manual_button:
		manual_button.button_pressed = not manual_button.button_pressed
		toast("수동 조준: 오른손으로 겨눌 곳을 끌어 놓고 뗀다." if manual_button.button_pressed else "자동 조준으로 돌아왔다.")
	elif b == shove_button:
		shove_button.button_pressed = true
		_shove()
	elif b == run_button:
		# Toggle (default), or run only while the key is held (a setting).
		run_button.button_pressed = true if run_hold() else not run_button.button_pressed
		_toggle_run()
	elif b == crouch_button:
		crouch_button.button_pressed = not crouch_button.button_pressed
		_toggle_crouch()


func _pad_move(b: Button, pos: Vector2, f: Dictionary) -> void:
	if b != aim_button or not auto_aim:
		return
	var over := _over_player(pos)
	aim_armed = aim_armed or not over
	aim_cancel = aim_armed and over
	# Dragged off the pad onto the field: the aim goes where the thumb is, an
	# enemy under it or the bare ground (build 89: no shot at empty ground).
	# Back on the pad the gun picks for itself again.
	var on_pad: bool = b.get_global_rect().grow(AIM_PAD_EDGE).has_point(pos)
	if not on_pad:
		auto_free = true
		if not aim_cancel:
			var world: Vector3 = game.screen_to_ground(pos)
			aim_target = _pick_enemy(world)
			aim_point = _on_target_floor(world, aim_target)
			game.player.face_point(aim_point)
		return
	if auto_free:
		auto_free = false
		aim_target = null
		f["slide_x"] = pos.x
	# Slide along the pad: the next target (or back).
	var dx: float = pos.x - float(f.get("slide_x", f["start"].x))
	if absf(dx) >= AIM_SLIDE_PX:
		f["slide_x"] = pos.x
		auto_skip += 1 if dx > 0 else -1
		aim_target = null
		auto_t = maxf(auto_t, game.combat.acquire_time(game.player))


func _pad_up(b: Button, pos: Vector2, f: Dictionary = {}) -> void:
	if b == aim_button and primary_melee(game.player):
		return
	if b == aim_button:
		aim_button.button_pressed = false
		_auto_aim_end(pos)
	elif b == context_button:
		context_button.button_pressed = false
		if not f.get("opened", false) and b.get_global_rect().has_point(pos):
			_context_tap()
	elif b == shove_button:
		shove_button.button_pressed = false
	elif b == run_button and run_hold():
		_run_key_up()


## Hold the aim pad: the gun comes up and, after a moment that shortens with
## shooting skill, settles on the nearest threat ahead (field_unified 10).
func _auto_aim_start() -> void:
	var p = game.player
	if not W.is_ranged(p.weapon_id()):
		toast("총을 든 사람만 조준한다. 무기를 바꿔라.")
		return
	if not game.combat.start_aim(p):
		return
	auto_aim = true
	aiming = true
	aim_armed = true
	aim_cancel = false
	auto_t = 0.0
	auto_skip = 0
	auto_free = false
	aim_target = null
	aim_point = p.position + Vector3(sin(p.facing), 0, cos(p.facing)) * 4.0
	game.combat.drop_target(p)


func _auto_aim_end(pos: Vector2) -> void:
	var p = game.player
	if not auto_aim:
		return
	auto_aim = false
	aiming = false
	if p.aim.active:
		if (aim_target != null or auto_free) and not aim_cancel:
			game.combat.fire(p, aim_point, aim_target)
		elif aim_target == null and not aim_cancel:
			toast("겨눌 것을 못 잡았다. 누른 채 쏠 곳으로 끌면 빈 땅에도 쏜다.")
		p.aim.stop()
	auto_free = false
	aim_cancel = false
	aim_target = null


func _tick_auto_aim(delta: float) -> void:
	if not auto_aim:
		return
	var p = game.player
	if not p.aim.active:
		auto_aim = false
		aiming = false
		return
	auto_t += delta
	if aim_target != null and not _target_ok(aim_target):
		aim_target = null
	if auto_free:
		# The thumb is aiming: follow the one under it, pick nothing else.
		if aim_target != null:
			aim_point = aim_target["pos"] if aim_target is Dictionary else aim_target.position
		p.face_point(aim_point)
		return
	if aim_target == null and auto_t >= game.combat.acquire_time(p):
		var list: Array = game.combat.aim_candidates(p)
		if not list.is_empty():
			aim_target = list[posmod(auto_skip, list.size())]
	if aim_target != null:
		aim_point = aim_target["pos"] if aim_target is Dictionary else aim_target.position
		p.face_point(aim_point)


func _target_ok(t) -> bool:
	if t is Dictionary:
		return t["state"] != "dead" and game.cell_seen(t["pos"])
	return game.combat.hostile(t) and t.visible


func _press(pos: Vector2) -> void:
	pressing = true
	press_pos = pos
	press_ms = Time.get_ticks_msec()
	melee_pending = null
	melee_holding = false
	aiming = false
	aim_cancel = false
	var p = game.player
	var world: Vector3 = game.screen_to_ground(pos)
	var target = _pick_enemy(world)
	var gun: bool = W.is_ranged(p.weapon_id()) and not bool(p.weapon().get("broken", false))
	# Manual aim: the right thumb puts the aim point anywhere, enemy or not.
	if target == null and not (gun and manual_button.button_pressed):
		return
	if gun:
		if game.combat.start_aim(p):
			aiming = true
			# An enemy at your feet: pressing on it must not count as letting go on yourself.
			aim_armed = not _over_player(pos)
			aim_target = target
			aim_point = _on_target_floor(world, target)
			game.combat.drop_target(p)
	else:
		melee_pending = target


func _release(pos: Vector2) -> void:
	pressing = false
	var p = game.player
	if aiming:
		aiming = false
		if p.aim.active:
			if not (aim_cancel or (aim_armed and _over_player(pos))):
				_aim_from(pos)
				game.combat.fire(p, aim_point, aim_target)
			p.aim.stop()
		aim_cancel = false
		aim_target = null
		return
	if melee_pending != null:
		if not melee_holding:
			# A tap keeps swinging until it is down (no tap per swing).
			_melee(melee_pending, true)
		melee_pending = null
		melee_holding = false
		return
	if pos.distance_to(press_pos) > DRAG_PX:
		return
	_tap(pos)


## The right thumb dragging the aim point (manual, or pressed on an enemy).
func _hand_move(pos: Vector2) -> void:
	if not (pressing and aiming):
		return
	var over := _over_player(pos)
	aim_armed = aim_armed or not over
	aim_cancel = aim_armed and over
	if aim_cancel:
		return
	_aim_from(pos)


## Where the dragged finger puts the aim: on an enemy within the pick radius
## it is that enemy, on empty ground it is that ground (free aim; build 47: the
## shot used to snap back to the enemy first pressed). A finger that has not
## really moved off the one it pressed stays on him.
func _aim_from(pos: Vector2) -> void:
	if aim_target != null and pos.distance_to(press_pos) <= DRAG_PX and _target_ok(aim_target):
		return
	var world: Vector3 = game.screen_to_ground(pos)
	aim_target = _pick_enemy(world)
	aim_point = _on_target_floor(world, aim_target)


func drop_touch() -> void:
	# The finger that was down when the app lost focus never comes back up.
	fingers.clear()
	stick_index = -1
	auto_aim = false
	auto_free = false
	stick_dash = false
	if run_button != null and run_hold():
		run_button.button_pressed = false
	if game.player != null:
		_stick_release()
	for b in [aim_button, shove_button, context_button]:
		if b != null:
			b.button_pressed = false
	pressing = false
	aiming = false
	aim_cancel = false
	aim_armed = false
	aim_target = null
	melee_pending = null
	if melee_holding and game.player != null:
		game.combat.stop_holding(game.player)
	melee_holding = false
	if game.player != null:
		game.player.aim.stop()


func _over_player(pos: Vector2) -> bool:
	return pos.distance_to(_project(game.player.position + Vector3(0, 1.0, 0))) <= AIM_CANCEL_PX


## 'One main action' (a start-screen trial, off by default; the user's card
## decides): the aim pad turns into the attack pad while a melee weapon or
## bare hands are out, and 'manual' shows only with a gun.
func primary_melee(p) -> bool:
	return bool(game.opts.get("primary_one", false)) and not W.is_ranged(p.weapon_id())


func _tick_primary(p) -> void:
	if not bool(game.opts.get("primary_one", false)):
		return
	var melee := primary_melee(p)
	attack_button.visible = false
	manual_button.visible = not melee
	aim_button.text = "공격" if melee else "조준"
	if melee:
		aim_button.button_pressed = fighting(p)


## The player is in a one-press fight: still after someone, swinging on.
func fighting(p) -> bool:
	return game.combat.fighting(p)


func stop_fight(p) -> void:
	game.combat.stop_fight(p)
	attack_button.button_pressed = false


## Screen direction from the player to the one being hit (camera looks north).
func _fight_dir(p) -> Vector2:
	var at: Vector3 = p.target_zombie["pos"] if not p.target_zombie.is_empty() else p.target_person.position
	var d := Vector2(at.x - p.position.x, at.z - p.position.z)
	return d.normalized() if d.length() > 0.05 else Vector2.ZERO


func _melee(target, hold: bool) -> void:
	game.combat.fight(game.player, target, hold)


## The finger's point moved to the floor the target stands on (shooting
## down from an upstairs window at the yard).
func _on_target_floor(world: Vector3, target) -> Vector3:
	if target == null:
		return world
	var y: float = target["pos"].y if target is Dictionary else target.position.y
	return game.shift_to_height(world, y)


## Nearest visible zombie, rising corpse or hostile person under the finger.
func _pick_enemy(world: Vector3):
	var best = null
	var best_d := 1.3
	for z in game.zombies.list:
		if z["state"] == "dead" or not game.cell_seen(z["pos"]):
			continue
		# The finger is on your floor; a body on another floor sits elsewhere on the screen.
		var d: float = game.shift_to_height(world, z["pos"].y).distance_to(z["pos"])
		if d < best_d:
			best_d = d
			best = z
	for r in game.raiders:
		if r.visible and game.combat.hostile(r):
			var d: float = game.shift_to_height(world, r.position.y).distance_to(r.position)
			if d < best_d:
				best_d = d
				best = r
	return best


func _tap(pos: Vector2) -> void:
	var p = game.player
	var world: Vector3 = game.screen_to_ground(pos)
	if game.actions.on_signal_top(p):
		offer([{"label": "내려간다", "call": game.actions.ladder.bind(p, "fast")}])
		return
	if not p.can_act():
		return
	if _tap_thing(p, world):
		return
	# The ground itself is not an order any more (the stick walks, user 17:15);
	# a tap on it only calls off a fight.
	game.combat.call_off(p)


## Doors, windows, containers, spots, lids, ground items and companions.
func _tap_thing(p, world: Vector3) -> bool:
	var cell := FieldGrid.cell_of(world)
	for row in ally_buttons:
		var o = row["p"]
		if o.is_alive() and o.position.distance_to(world) < 0.8:
			_ally_menu(o)
			return true
	for i in range(game.ground_items.size()):
		var g: Dictionary = game.ground_items[i]
		if world.distance_to(g["pos"]) < 0.9:
			game.actions.go_and_do(p, "item", i, g["pos"])
			return true
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		var at: Vector3 = game.lift(c["cell"], int(c.get("level", 0)))
		if at.distance_to(world) < 1.0:
			game.actions.go_and_do(p, "container", id, at)
			return true
	# Stairs: a tap on them goes up (or down) them.
	var lv: int = game.level_of(p.position)
	for s in game.stairs:
		if s["ladder"] or not (s["low"] == lv or s["high"] == lv):
			continue
		if game.lift(s["cell"], lv).distance_to(world) < 1.0:
			game.actions.take_stairs(p, s)
			if not p.path.is_empty():
				dest_marker = p.path[p.path.size() - 1]
			return true
	if lv != 0:
		return false
	for id in game.data["spots"]:
		var spot: Dictionary = game.data["spots"][id]
		if FieldGrid.center(spot["cell"]).distance_to(world) < 1.3:
			game.actions.go_and_do(p, "spot", id, FieldGrid.center(spot["cell"]))
			return true
	if game.data["manholes"].has("manhole") and FieldGrid.center(game.data["manholes"]["manhole"]).distance_to(world) < 1.0:
		game.actions.go_and_do(p, "manhole", "manhole", FieldGrid.center(game.data["manholes"]["manhole"]))
		return true
	for c in [cell, cell + Vector2i(1, 0), cell + Vector2i(-1, 0), cell + Vector2i(0, 1), cell + Vector2i(0, -1)]:
		if game.grid.doors.has(c) and FieldGrid.center(c).distance_to(world) < 0.9:
			var door: Dictionary = game.grid.doors[c]
			if door["state"] == "locked" and not game.actions.has_pry(p):
				offer([{"label": "문을 찬다 (시끄러움)", "call": game.actions.go_and_do.bind(p, "door", c, FieldGrid.center(c), "kick")}])
				return true
			game.actions.go_and_do(p, "door", c, FieldGrid.center(c))
			return true
		if game.grid.windows.has(c) and FieldGrid.center(c).distance_to(world) < 0.9:
			game.actions.go_and_do(p, "window", c, FieldGrid.center(c))
			return true
	return false


# ---------------------------------------------------------------- overlay

func _project(at: Vector3) -> Vector2:
	return game.camera.unproject_position(at)


func _draw_overlay() -> void:
	if game == null or game.player == null:
		return
	var p = game.player
	var view_size: Vector2 = overlay.size
	var now: float = game.clock.elapsed
	# Pressure at the edges: no numbers, just a darker rim as the next horde nears.
	var pressure: float = game.director.pressure(now)
	if pressure > 0.5 and game.deaf_t <= 0.0:
		var a := (pressure - 0.5) * 0.35
		overlay.draw_rect(Rect2(Vector2.ZERO, Vector2(view_size.x, 18)), Color(0.25, 0.05, 0.04, a))
		overlay.draw_rect(Rect2(Vector2(0, view_size.y - 18), Vector2(view_size.x, 18)), Color(0.25, 0.05, 0.04, a))
	# Walk target.
	if p.moving and not p.path.is_empty() and dest_marker != Vector3.INF:
		overlay.draw_arc(_project(dest_marker), 10.0, 0, TAU, 20, Color(1, 1, 1, 0.5), 2.0)
	# The stick under the left thumb: base ring and knob (rim = run).
	# The fixed one stays drawn faintly where it is; the floating one only while held.
	var fixed := not stick_floats()
	if fixed or stick_index >= 0:
		var base := stick_home() if fixed else stick_origin
		overlay.draw_arc(base, STICK_R, 0, TAU, 40, Color(1, 1, 1, 0.28 if stick_index >= 0 else 0.14), 3.0)
		if stick_index >= 0:
			var knob := base + (stick_at - base).limit_length(STICK_R)
			overlay.draw_circle(knob, 26.0, Color(1, 1, 1, 0.35 if not p.running else 0.55))
		else:
			overlay.draw_circle(base, 8.0, Color(1, 1, 1, 0.14))
	# Sharp shooters see the dangerous ones marked while aiming (not chosen for them).
	if auto_aim and int(p.skills.get("shooting", 0)) >= 7:
		for z in game.zombies.list:
			if z != aim_target and game.combat.marks_danger(p, z) and game.cell_seen(z["pos"]):
				var m := _project(z["pos"] + Vector3(0, 2.1, 0))
				overlay.draw_colored_polygon(PackedVector2Array([m + Vector2(-7, -10), m + Vector2(7, -10), m + Vector2(0, 0)]), Color(1, 0.75, 0.4, 0.9))
	# What the auto aim has settled on.
	if auto_aim and aim_target != null:
		var at: Vector3 = aim_target["pos"] if aim_target is Dictionary else aim_target.position
		var c := _project(at + Vector3(0, 1.0, 0))
		overlay.draw_arc(c, 22.0, 0, TAU, 24, Color(1, 0.9, 0.7, 0.9), 2.5)
	# Aim circle: big when raised, shrinks while still (field_unified 10).
	if p.aim.active:
		var c := _project(aim_point + Vector3(0, 1.0, 0))
		var dist: float = p.position.distance_to(aim_point)
		var r: float = maxf(p.aim.radius_at(dist) * game.pixels_per_metre(), 6.0)
		var tight: bool = p.aim.deg <= p.aim.floor_deg * 1.05
		overlay.draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.9) if tight else Color(1, 0.85, 0.6, 0.8), 3.0 if tight else 2.0)
		overlay.draw_circle(c, 2.5, Color(1, 1, 1, 0.9))
		if aiming and aim_armed:
			# Where to let go to lower the gun without firing.
			var me := _project(p.position + Vector3(0, 1.0, 0))
			var col := Color(1, 1, 1, 0.85) if aim_cancel else Color(1, 1, 1, 0.3)
			overlay.draw_arc(me, AIM_CANCEL_PX, 0, TAU, 32, col, 2.0)
			overlay.draw_string(theme.default_font, me + Vector2(-14, AIM_CANCEL_PX + 18), "내리기", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
	for row in game.people:
		if row.aim.active and row != p and row.visible:
			var t = row.brain.get("target")
			if row.team == "raider" and t != null and row.brain.get("aiming", false):
				overlay.draw_line(_project(row.position + Vector3(0, 1.3, 0)), _project(t.position + Vector3(0, 1.0, 0)), Color(0.95, 0.25, 0.2, 0.65), 2.0)
	for tr in game.combat.tracers:
		overlay.draw_line(_project(tr["from"]), _project(tr["to"]), Color(1, 0.92, 0.6, clampf(tr["t"] / 0.12, 0, 1)), 2.0)
	_draw_sounds(now)
	if game.deaf_t > 0.0:
		overlay.draw_string(theme.default_font, Vector2(view_size.x * 0.5 - 60, 92), "귀가 먹먹하다", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))
		return
	_draw_edges(view_size)


## Sound icon at the moment of an action: bars for the four levels.
func _draw_sounds(now: float) -> void:
	for s in game.sounds:
		var age: float = now - float(s["t"])
		if age > 1.4 or s["tag"] in ["blood", "light"]:
			continue
		var at: Vector3 = s["pos"]
		if at.distance_to(game.player.position) > 30.0:
			continue
		var c := _project(at + Vector3(0, 2.2, 0))
		var a := clampf(1.0 - age / 1.4, 0.0, 1.0)
		var lvl: int = int(s["level"])
		for i in range(4):
			var h := 6.0 + i * 5.0
			var col := Color(1, 1, 1, a) if i <= lvl else Color(1, 1, 1, a * 0.2)
			if lvl >= SimNoise.Level.LOUD and i <= lvl:
				col = Color(1, 0.6, 0.45, a)
			overlay.draw_rect(Rect2(c + Vector2(i * 7 - 12, -h), Vector2(5, h)), col)


## Off-screen threats: hordes on the way and rattling lids, as edge arrows.
func _draw_edges(view_size: Vector2) -> void:
	var center := view_size * 0.5
	var groups: Dictionary = {}
	for z in game.zombies.list:
		if int(z["horde"]) < 0 or not game.zombies.active(z):
			continue
		if game.camera.is_position_in_frustum(z["pos"]):
			continue
		var k: int = int(z["horde"])
		if not groups.has(k):
			groups[k] = {"sum": Vector3.ZERO, "n": 0}
		groups[k]["sum"] += z["pos"]
		groups[k]["n"] += 1
	for k in groups:
		var g: Dictionary = groups[k]
		_edge_arrow(center, view_size, g["sum"] / float(g["n"]), "먼 신음")
	for key in game.rattle:
		var at: Vector3 = FieldGrid.center(game.data["manholes"][key])
		if not game.camera.is_position_in_frustum(at):
			_edge_arrow(center, view_size, at, "덜컹")
	_draw_moans()


## Heard, not seen (body_injury 8.3): the dead moving within MOAN_R of the
## leader but outside sight show as a faint tick around the leader, one per
## eighth of the compass. No count, no exact spot.
func _draw_moans() -> void:
	var p = game.player
	var me := _project(p.position)
	var marks: Dictionary = {}
	for z in game.zombies.list:
		if not game.zombies.active(z) or z["state"] == "frozen" or z["state"] == "wander":
			continue
		var d: float = z["pos"].distance_to(p.position)
		if d > MOAN_R or d < 2.0 or game.cell_seen(z["pos"]):
			continue
		var dir := _project(z["pos"]) - me
		if dir.length() < 1.0:
			continue
		var octant := int(round(dir.angle() / (PI / 4.0))) & 7
		marks[octant] = minf(float(marks.get(octant, 1e9)), d)
	for o in marks:
		var a := float(o) * PI / 4.0
		var v := Vector2(cos(a), sin(a))
		var near := 1.0 - float(marks[o]) / MOAN_R
		var col := Color(OMEN_COL.r, OMEN_COL.g, OMEN_COL.b, 0.35 + 0.5 * near)
		overlay.draw_arc(me, 92.0, a - 0.28, a + 0.28, 10, col, 3.0)
		overlay.draw_string(theme.default_font, me + v * 112.0 - Vector2(16, -6), "신음", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


func _edge_arrow(center: Vector2, view_size: Vector2, at: Vector3, text: String) -> void:
	var sp := _project(at)
	var dir := (sp - center)
	if dir.length() < 1.0:
		return
	dir = dir.normalized()
	var margin := 46.0
	var half := view_size * 0.5 - Vector2(margin, margin)
	var t := minf(absf(half.x / dir.x) if absf(dir.x) > 0.001 else 1e9, absf(half.y / dir.y) if absf(dir.y) > 0.001 else 1e9)
	var tip := center + dir * t
	var side := Vector2(-dir.y, dir.x)
	var col := OMEN_COL
	overlay.draw_colored_polygon(PackedVector2Array([tip + dir * 14.0, tip - dir * 8.0 + side * 10.0, tip - dir * 8.0 - side * 10.0]), col)
	overlay.draw_string(theme.default_font, tip - dir * 30.0 - Vector2(24, -6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
