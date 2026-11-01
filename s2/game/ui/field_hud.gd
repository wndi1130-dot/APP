extends CanvasLayer
## Field screen (s2_station 2.7): only four things stay up (clock and sun,
## one radio line, the portrait with bag and cold, sound icons at the moment
## of an action). Companion portraits, thumb buttons, cards and the end
## screen come and go. Taps on the world become orders (field_unified 10).
## The look is UI 3단계 시안 2차 「성에 낀 계기」 (hud_skin.gd): glass pills,
## matte round keys drawn inside the touch rects set here, a face that shows
## the body (portrait_face.gd), paper slips for notes.

const FieldGrid = preload("res://game/world/field_grid.gd")
const W = preload("res://game/sim/weapons.gd")
const Carry = preload("res://game/sim/carry.gd")
const Wear = preload("res://game/sim/wear.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const HordeDirector = preload("res://game/sim/horde_director.gd")
const FieldHoldout = preload("res://game/field_holdout.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")
const StatusArt = preload("res://game/ui/status_art.gd")
const HudSkin = preload("res://game/ui/hud_skin.gd")
const PauseVeil = preload("res://game/ui/pause_veil.gd")
const MapStamp = preload("res://game/ui/map_stamp.gd")
const TextFit = preload("res://game/ui/text_fit.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const PortraitFace = preload("res://game/ui/portrait_face.gd")
const ReceiptCard = preload("res://game/ui/receipt_card.gd")
const ReceiptSheet = preload("res://game/ui/receipt_sheet.gd")
const GlassPane = preload("res://game/ui/glass_pane.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const PaperSheet = preload("res://game/ui/paper_sheet.gd")
const Paper = preload("res://game/ui/paper_parts.gd")
const LampKey = preload("res://game/ui/lamp_key.gd")
const InventoryPane = preload("res://game/ui/inventory_pane.gd")
const SoundRows = preload("res://game/ui/sound_rows.gd")
const ScreenLift = preload("res://game/ui/screen_lift.gd")
const TypeLine = preload("res://game/ui/type_line.gd")
const Treatment = preload("res://game/sim/treatment.gd")
const BodyState = preload("res://game/sim/body_state.gd")
const Amputation = preload("res://game/sim/amputation.gd")
const LungerRules = preload("res://game/sim/lunger_rules.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const GrabRules = preload("res://game/sim/grab_rules.gd")
const Sled = preload("res://game/sim/sled.gd")

const PANEL_BG := Color(0.07, 0.075, 0.08, 0.78)
const INK := Color(0.93, 0.91, 0.86)
const DIM := Color(0.62, 0.62, 0.6)
const WARN := Color(0.95, 0.55, 0.42)
const FROST := Color(0.8, 0.81, 0.8)     # off-white, not sky blue (fx colour rule)
const HOLD_TIME: float = 0.35
const DRAG_PX: float = 28.0
const AIM_CANCEL_PX: float = 56.0   # drag the aim back onto yourself and let go: no shot
const BODY_H: float = 1.7           # feet to head: a finger anywhere on the body picks it
## How tall a box is drawn, for the finger (decision 476): a wardrobe, a cupboard or a
## shelf (RoomFurnish.TALL_KINDS), other furniture that holds things (a counter, a
## dresser, a chest), a crate standing on its own; and a thing lying on the ground.
const BOX_TALL_H: float = 1.9
const BOX_H: float = 0.9
const BOX_LOOSE_H: float = 0.55
const ITEM_H: float = 0.3
const STICK_R: float = 72.0         # thumb travel to full push (the rim runs, if set)
const STICK_DEAD: float = 10.0
const AIM_SLIDE_PX: float = 70.0    # slide along the aim pad: next target
const AIM_PAD_EDGE: float = 24.0    # this far past the pad's edge still counts as on it
const STICK_STOPS_FIGHT: float = 0.3  # a push this hard away from the target calls off a fight
const DOUBLE_TAP_MS: int = 300
## The fixed stick (the default; build 47: a floating one made the thumb re-set
## it all the time). Home is 21 mm in and 14.5 mm up from the bottom-left corner,
## under the run key; a touch within STICK_CATCH radii of it takes the stick.
const STICK_HOME_MM := Vector2(21.0, 14.5)
const STICK_CATCH: float = 2.0
## The body picture slows the field, it does not stop it (body_injury 4.6).
const BODY_SLOW: float = 0.3
## The pause key and the clock share one row this tall at the top left, the
## key's disc as tall as the clock's glass (user 2026-10-18: 「높이 맞춰서 서로
## 같은 높이에」); the key's touch square, round the disc's middle, is
## PAUSE_TOUCH across. The portrait sits PORTRAIT_GAP under that row.
const TOP_ROW_H: float = 58.0
const PAUSE_TOUCH: float = 74.0
const PAUSE_ICON: int = 22
const PORTRAIT_GAP: float = 14.0
const PORTRAIT_AT := Vector2(16.0, 14.0 + TOP_ROW_H + PORTRAIT_GAP)
const PORTRAIT_W: float = 290.0
## The stop's own lines (goals, promises), the radio and the notes (paper
## slips) make one column left of the state icons (user 2026-10-18: the notes
## in the middle covered the screen; 「상태이상 아이콘 좌측에」), this many css
## px from the icons, from the squad's orders, from one line to the next and
## from the right thumb's pads under it.
const MESSAGE_GAP: float = 10.0
# State icons: a column down the right edge, under the zoom keys, as in reference
# game 1 (field_system 82). Build 116 (user): at 58x38 with 15pt words nobody
# saw them. User 2026-10-12: pictures, not words: a round plate each
# (status_art.gd), 72 across ('a little smaller' than the 80 first tried), or
# 64 or 80 from the settings.
const STATUS_AT := Vector2(-16.0, 84.0)
const SETTINGS_KEY: float = 72.0   # the gear's touch square, top right while paused
const SET_RIM := Color("f4f1ea")   # its white rim, as the state plates wear (시안 .fset)
const STATUS_SIZES: Array[int] = [72, 64, 80]
const STATUS_SIZE_NAMES: Dictionary = {72: "보통", 64: "작게", 80: "크게"}
const STATUS_ART_SIZE: int = 80   # the pictures are drawn once, for the biggest
const STATUS_GAP: float = 6.0
# One column always (user 2026-10-18: 「4개이상 나오면 작아지면서 나열」): from
# STATUS_SMALL_FROM of them on each is STATUS_SMALL of its size, so five end
# above the crouch key and none starts a second column into the screen.
const STATUS_SMALL_FROM: int = 4
const STATUS_SMALL: float = 0.72
const DUSK_TEST_MIN: float = 940.0   # the test key jumps to 15:40, five minutes before sunset
const STATUS_SLOTS: int = 5
const BLOOD_BROWN := Color(0.33, 0.2, 0.12, 0.97)   # blood is dark brown here, never red
const FESTER_RIM := Color(0.74, 0.7, 0.3)           # a festering part: a sallow rim, never red
## Where the six parts sit in the body picture (your left on the left, like a mirror).
# The body picture (user 2026-10-12: one figure cut into its parts, not six
# boxes). Drawn 300 x 440; BODY_SHAPES are the outlines, BODY_LAYOUT where a
# press lands (wider than the picture, and never two parts at once).
const BODY_SIZE := Vector2(300.0, 440.0)
const BODY_SCALE: float = 0.75
const BODY_WORD_FONT: int = 14
const BODY_SHAPES: Dictionary = {
	"head_neck": [Vector2(137, 94), Vector2(137, 72), Vector2(127.2, 65.8), Vector2(120, 56.6), Vector2(116.4, 45.6), Vector2(116.7, 34), Vector2(120.8, 23.1), Vector2(128.4, 14.3), Vector2(138.5, 8.6), Vector2(150, 6.6), Vector2(161.5, 8.6), Vector2(171.6, 14.3), Vector2(179.2, 23.1), Vector2(183.3, 34), Vector2(183.6, 45.6), Vector2(180, 56.6), Vector2(172.8, 65.8), Vector2(163, 72), Vector2(163, 94)],
	"torso": [Vector2(98, 98), Vector2(202, 98), Vector2(194, 200), Vector2(200, 240), Vector2(100, 240), Vector2(106, 200)],
	"arm_left": [Vector2(94, 98), Vector2(72, 104), Vector2(58, 170), Vector2(44, 232), Vector2(42, 262), Vector2(60, 268), Vector2(72, 240), Vector2(82, 178), Vector2(94, 136)],
	"arm_right": [Vector2(206, 136), Vector2(218, 178), Vector2(228, 240), Vector2(240, 268), Vector2(258, 262), Vector2(256, 232), Vector2(242, 170), Vector2(228, 104), Vector2(206, 98)],
	"leg_left": [Vector2(102, 244), Vector2(147, 244), Vector2(146, 330), Vector2(142, 404), Vector2(150, 428), Vector2(108, 428), Vector2(116, 404), Vector2(108, 330)],
	"leg_right": [Vector2(192, 330), Vector2(184, 404), Vector2(192, 428), Vector2(150, 428), Vector2(158, 404), Vector2(154, 330), Vector2(153, 244), Vector2(198, 244)],
}
const BODY_LAYOUT: Dictionary = {
	"head_neck": Rect2(60, 0, 180, 96),
	"arm_left": Rect2(0, 96, 90, 180),
	"torso": Rect2(90, 96, 120, 146),
	"arm_right": Rect2(210, 96, 90, 180),
	"leg_left": Rect2(90, 242, 60, 198),
	"leg_right": Rect2(150, 242, 60, 198),
}
const TOAST_NORMAL := "normal"      # play and block notes (ui_states N1)
const TOAST_WARN := "warn"          # save or system trouble: amber, long, tap to close (N2)
const TOAST_S: float = 3.5
const TOAST_WARN_S: float = 6.0
const TOAST_MAX: int = 4
const TOAST_W: float = 560.0        # a note wider than this wraps onto a second line
const RADIO_W: float = 480.0        # so does a radio call, or at the column's own room
const SAY_S: float = 2.6            # a line over a companion's head stays this long
const SAY_FONT: int = 20
# A held train leaves: the field stands still and darkens, two lines come up,
# then the end card (user decision 142).
## The panels' glass pane, as wide as 시안 13's menu (mockup px); the body
## picture's, wider for the figure and the gap beside it (the bag's is
## inventory_pane.gd's).
const PANE_W: float = 420.0
const BODY_PANE_W: float = 500.0
const BODY_GAP: float = 12.0
## The cut asks twice (body_injury 2.2): a second press within this many
## seconds of the first cuts.
const CUT_CONFIRM_S: float = 3.0
## A key beside a thing's row (mockup px).
const DROP_W: float = 84.0
## How high the list of what one of the fallen has on stands before it is
## dragged (mockup px, about four rows; strip_pane).
const LOOT_LIST_MAX: float = 194.0
## A thing's picture in the loot and bag rows (decision 417: a picture and a short name).
const ITEM_ICON_PX: int = 18
## How fast a thing come up out of the snow glimmers (radians a second).
const GLINT_PULSE: float = 4.0
## The load's walk said at most this often (s).
const LOAD_WALK_EVERY: float = 6.0
## The journal's note in the bag (시안 .pnote: 240 wide, leaning 1.1°).
const JOURNAL_W: float = 240.0
const JOURNAL_LEAN_DEG: float = 1.1
## The orders' marks (hud_icons.gd).
const COMMAND_ICONS: Dictionary = {"follow": "people", "wait": "pause", "search": "search", "cover": "aim", "retreat": "train"}
## The decision card's paper (시안 06: the stop card's sheet and place). A scene
## longer than this many letters or lines is set in print, so it stays on the sheet.
const CARD_AT := Vector2(-10, 50)
const CARD_PEN_LETTERS: int = 90
const CARD_PEN_LINES: int = 3
## The leave beat's paper (시안 08 .sp: 452 wide, left −12, leaning −0.6°,
## the writing 46 in from the left, 30 from the right, 13 from the top), in the
## upper part of the screen under the clock's lines: the middle is where the
## people are.
const LEAVE_AT := Vector2(-12, 84)
const LEAVE_W: float = 452.0
const LEAVE_LEAN_DEG: float = -0.6
const LEAVE_IN := Rect2(46, 13, 30, 14)
const LEAVE_BEAT_S: float = 3.5
const LEAVE_DARK_S: float = 1.5
const LEAVE_DARK: float = 0.62
const LEAVE_WORDS_AT: float = 0.5   # the lines come up this long after the whistle
const LAST_CALL_FONT: int = 96
const READY_FONT: int = 52
## The end's record stands this far right of the receipt's sheet (mockup px).
const END_GAP: float = 32.0
# A line a companion shouts (ally_lines.gd): bigger and a little longer than
# the note of what happened, which goes small under it.
const LINE_S: float = 3.2
const LINE_FONT: int = 24
const SAY_UNDER_FONT: int = 16
const SAY_HURT_INK := Color(0.45, 0.16, 0.07)   # rust ink on the paper: a wound, never red
const HURT_FLASH_S: float = 0.7
# Right thumb (bottom right): attack big in the corner, aim small beside it.
const ATTACK_AT := Vector2(-192.0, -172.0)
const ATTACK_SIZE := Vector2(176.0, 156.0)
const AIM_AT := Vector2(-312.0, -104.0)
const AIM_SIZE := Vector2(108.0, 88.0)
const MANUAL_SIZE := Vector2(92.0, 88.0)
## Crouch rides the right thumb (decision 293, 배그처럼): on the right edge just
## over attack, where shove was; shove moved left of it, and the situation and
## leaving pads left of shove. The touch sizes are the hand-tested ones.
const SHOVE_AT := Vector2(-277.0, -268.0)
const SHOVE_SIZE := Vector2(140.0, 84.0)
const CONTEXT_AT := Vector2(-425.0, -204.0)
const DEPART_AT := Vector2(-425.0, -296.0)
## The squad's orders right of the clock (user 2026-10-18 「모두 열차로 버튼은
## 시간 오른쪽에」), css px. 'All aboard' (시안 2차 .fall's pill): its touch rect
## 44 high with the pill 34 inside it and its middle on the clock glass's, the
## train's mark 16 and the words 13 between 11 and 13 of room, 5 apart. Under
## it the two orders decision 408 brings out of a companion's card, 따라와 and
## 대기, for every living companion at once: words alone (13, 시안 .fcmd's) on
## pills 30 high in touch rects 40 high, the two as wide as 'all aboard'.
const ALL_ABOARD_H: float = 44.0
const ALL_ABOARD_SEEN: float = 34.0
const ORDER_H: float = 40.0
const ORDER_SEEN: float = 30.0
const SQUAD_GAP: float = 8.0          # from the clock's glass, and between the two orders
## The squad's orders fold under a small lever at the top middle (user
## 2026-10-18: 「레버처럼 … 정중앙 상단 … 내리고 올릴수있게 … 접었다
## 펼수있게」): its touch rect, the tab it shows hanging from the top edge, how
## far a thumb pulls it down (or pushes it up) to open (or fold) the orders, a
## tap flipping them, and how long the knob and the orders take to follow.
const LEVER_TOUCH := Vector2(88.0, 48.0)
const LEVER_SEEN := Vector2(56.0, 38.0)
const LEVER_PULL: float = 14.0
const LEVER_S: float = 0.12
## The promise line, small (user 2026-10-18): its seal, and the room the seal
## keeps before the words.
const PROMISE_SEAL: int = 18
const PROMISE_ROOM: float = 24.0
## Movement and use keys are see-through (user 2026-10-18): their glass, ring
## and light at this much; the mark and the word on them stay whole.
const PAD_SEE: float = 0.7
## The companions' row's top, from the screen's bottom: at the foot of the
## screen as the 시안's (.fally top 340 of 390, its chips' glass ending 9 above
## the edge), now that 'all aboard' is no longer under it.
const ALLIES_UP: float = 92.0
## Millimetres on the S22+ held sideways: 720 view px over about 70 mm.
const PX_PER_MM: float = 10.3
## 48 dp (7.62 mm), the least a finger lands on for sure: a smaller key keeps
## the picture it has and takes a finger this wide (user 2026-10-24).
const MIN_TOUCH: float = 79.0
const BRASS := Color(0.86, 0.72, 0.42)
const AMBER := Color(0.98, 0.66, 0.22)
## Stick-rim run (a setting): stay past 90% for 0.15 s to run, back under 75%
## to walk, so a shaking thumb does not flicker (field_unified 10, A3).
const RIM_IN: float = 0.9
const RIM_OUT: float = 0.75
const RIM_DWELL: float = 0.15
## Omens are pale bone, never a red flag (presentation_motion 93).
const OMEN_COL := Color(0.86, 0.84, 0.78, 0.85)
## An edge arrow under one of the HUD's pieces slides in along its ray by this
## step, never nearer the middle than EDGE_IN_MIN.
const EDGE_STEP: float = 8.0
const EDGE_IN_MIN: float = 150.0
## A sound drawn as a wifi mark (user 2026-10-18: 「와이파이 형태로 소음을
## 측정」): a dot and three arcs a quarter turn wide, their stroke; about as big
## as the four bars it took over.
const WIFI_DOT: float = 2.6
const WIFI_ARCS: Array[float] = [7.5, 13.0, 18.5]
const WIFI_SPAN: float = PI / 4.0
const WIFI_W: float = 3.0
# The mark over one of the dead that has dropped low and will run: a ring that
# closes on it as the beat runs out, in pixels. First values.
const TELL_RING_IN: float = 12.0
const TELL_RING_OUT: float = 40.0
const TELL_FONT: int = 28
const COMMANDS: Array = [["follow", "따라와"], ["wait", "대기"], ["search", "수색"], ["cover", "엄호"], ["retreat", "후퇴"]]
## What a key shows inside its touch rect (시안 2차 11절: keys 44, the attack
## pad 76, about 1.85 view px to a 시안 px). The touch rects above are the
## hand-tested ones and do not change with the look.
const KEY_SEEN: float = 82.0
const ATTACK_SEEN: float = 140.0
const ATTACK_ICON: int = 63      # 시안 .fpad--atk .ic 34
## Attack shows the letter A and run the word RUN, in Barlow (user 2026-10-18),
## css px. Shove, aim and the situation pad show their mark alone (the same
## day: no word), so bigger than over a word.
const ATTACK_LETTER: float = 44.0
const RUN_WORD: float = 15.0
const LONE_ICON: int = 40
## How far the attack A moves up to sit in the middle of its disc (measured on
## the drawn key: its line keeps room under the letter the eye does not count).
const LETTER_NUDGE: float = -3.5
## Leaving shows its word alone (user 2026-10-18: no train) on a slim lamp
## pill, the word as big as the 시안's lamp pill word (.fpad--ctx .lab 13).
const DEPART_SEEN: Vector2 = Vector2(116.0, 80.0)
const DEPART_FONT: float = 13.0
const FACE_SIZE: float = 84.0
## A companion's chip (시안 .fchip's face 32 across) folded to the face alone
## on a round of glass (user 2026-10-18: 「과감하게 가릴 때는 안 보이게」), the
## rounds CHIP_GAP apart. Each face gets its own headwear in turn (the 시안's
## three, then a hood).
const CHIP_FACE: float = 59.0
const CHIP_TOKEN: float = 72.0
const CHIP_GAP: float = 8.0
const CHIP_KINDS: Array[int] = [1, 4, 5, 2]
## The card a tap on a face opens over it: its words may take this much room (a
## longer one is cut short), CARD_GAP over the face, its words CARD_PAD in (css).
const CHIP_WORDS_W: float = 150.0
const CARD_GAP: float = 6.0
const CARD_PAD := Vector2(10.0, 5.0)
## The stick as the 시안 draws it (.fstick): a ring 96 across, a knob 40 (radii).
const STICK_RING: float = 89.0
const STICK_KNOB: float = 37.0
## The set's hiss before a call (시안 .fradio__hiss): each letter a little off
## its line and fainter or not ([letter, 시안 px down, alpha]).
const HISS: Array = [["치", -1.0, 0.9], ["지", 1.0, 0.5], ["지", 0.0, 0.78], ["직", -1.5, 0.6]]
const HISS_TEXT := "…치직"   # what the field puts up while the set only hisses

var game
var theme: Theme
var root: Control
var pause_veil: Control                   # pause_veil.gd
var map_stamp: Control                    # map_stamp.gd
var text_fit: Node                       # text_fit.gd
var touch: Control
var overlay: Control
var clock_label: Label
var day_label: Label
var sun_bar: ProgressBar
var weather_label: Label
var top_panel: Control                # the clock's box, top left
var urgent: bool = false              # dusk has begun: the radio and 'all aboard' burn amber
var radio_pill: PanelContainer
var test_keys: HBoxContainer          # − + D (tests only), top right on the clock's row
var radio_styles: Array = []          # [plain, urgent]
var face: Control                     # the chief's face (portrait_face.gd)
var cond_label: Label                 # the weapon's state, after its name
var ammo_label: Label
var tag_box: HBoxContainer            # the floor and blood-soaked tags beside the weapon
var bag_button: Button                # 인벤토리: the weight carried, opens the bag panel
var all_aboard_styles: Array = []     # [plain, urgent] key styles
var lever_button: Button              # the orders' lever, top middle
var lever_styles: Array = []          # its tab: [plain, urgent]
var lever_slot: StyleBoxFlat          # the slot its knob runs in
var orders_open: bool = false         # the drawer under the lever is open
var lever_t: float = 0.0              # the knob: 0 up (folded) to 1 down (open)
var promise_text: String = ""         # the promise line's words, open or folded
var promise_open: bool = false        # the promise line is down under its key
var goal_open: bool = false           # the goal line is down under its key
var clock_open: bool = false          # the clock shows the day and the weather too
var promise_key: Button               # the promises, folded to a key left of the view keys
var goal_key: Button                  # the stop's goals, the same, right of it
var fold_keys: HBoxContainer          # those two, on the clock's row
var feel_label: Label                 # the chief's aside beside the risk line
var goal_label: Label                 # the line under the clock (goal_shown; none on a plain stop)
var promise_label: Label              # 「약속: 서막 ○○ / 교대 ○○」 in the message column, while there are any
var info_box: VBoxContainer           # the stop's own lines at the head of the message column
var radio_label: Label
var radio_hiss: HBoxContainer          # the crackle before the call (시안 .fradio__hiss)
var radio_left: float = 0.0
var portrait: PanelContainer
var portrait_style: StyleBoxFlat
var name_label: Label
var status_label: Label
var weapon_label: Label
var allies_box: HBoxContainer
var ally_buttons: Array = []
var crew_button: Button
var all_aboard_button: Button         # every companion back to the train at one press
var follow_button: Button             # 따라와 for every living companion (decision 408)
var wait_button: Button               # 대기 for every living companion
var order_size: Vector2               # the touch rect of each of those two
var clock_pill: Control               # the clock's glass line; the squad's orders stand right of it
var radio_room: float = -1.0          # the column's width the radio's call was last fitted to
var card_row: int = -1                # whose card is open over their face (-1: none)
var context_button: Button
var depart_button: Button              # leaving: its own pad, there whenever the leader is by the train
var context_rows: Array = []
var context_t: float = 0.0
var context_icon: String = "search"     # the situation pad's picture now (HudIcons.context_icon)
var context_badge: PanelContainer       # how many more there are to do, on the situation pad's rim
var context_more: Label
var all_aboard_size: Vector2            # its touch rect, as wide as its mark and words need
var attack_icon: String = "-"           # the attack pad's picture now (_tick_attack_icon)
var pause_shows_play: bool = false      # the pause key shows 'play' while paused
var offer_box: Control
var toast_box: VBoxContainer
var toasts: Array = []
var grab_button: Button
var grab_bar: ProgressBar
var grab_total: float = 1.0
var crouch_button: Button
var run_button: Button
var load_walk_said: float = -999.0   # when the load last kept the feet to a walk (card G)
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
var resume_button: Button
var resume_view_ready: bool = false
var settings_button: Button          # shown while paused: opens the settings (stick, radio)
var bag_box: HBoxContainer           # the bag key, right under the portrait
var alarm_button: Button             # a found watch still set to ring: one press stops it (P19)
var says: Array = []                 # [{p, text, t, hurt}] short lines over companions' heads
var hurt_flash: float = 0.0          # the screen's side edges glow amber when the chief is hurt
var debug_panel: PanelContainer
var debug_label: Label
var modal: Control
var modal_paused_before: bool = false
var modal_open: bool = false
var modal_pane: GlassPane
var closing_modal: Control
var modal_fingers: Dictionary = {}     # touches stay consumed through their lift, even after closing
var modal_emulated_blocked: bool = false
var modal_back_captured: bool = false
var modal_quit_on_back: bool = false
## The bag pane keeps its destination while the bag tab is shown (decision 488).
var inv_near: Dictionary = {}
var inv_sort: String = "weight"
var inv_view: String = "near"
var inv_worn_open: bool = false
## Optional item art supplied locally; an empty entry falls back to the resource path.
var item_px_override: Dictionary = {}
## The places the bag pane listed when it was laid (InventoryPane.place_keys):
## changes to nearby places refresh it even though its stick sleeps (532).
var bag_places: Array = []
## What sleeps under the bag pane, each with the alpha it had: [CanvasItem, a].
var bag_dimmed: Array = []
## How far a key that sleeps under the bag pane fades (its alpha times this).
const BAG_DIM: float = 0.38
## The box shown while the player takes a thing out of it (card R1 가): the field
## goes on under the pane until the thing is out; and the bar on its row.
var taking_box: String = ""
var take_bar: ProgressBar
## The box the pane last opened with its sound (card R3 가, box_shown_now), and the shade
## that pane stood on: another panel in its place shuts the box at once.
var box_shown: String = ""
var box_pane: Control = null
var modal_slows: bool = false     # the panel up slows the field instead of stopping it
var status_pads: Array = []        # the state icons, most urgent first
var leaving: Dictionary = {}       # the beat as a held train leaves: {"result", "t", "veil", "words"}
var body_look: Dictionary = {}     # what the body picture shows of each part (body_looks())
var status_rows: Array = []        # what each shows now (body.status_notes())
var status_small: bool = false     # four or more show: each at STATUS_SMALL
var bleed_hint_done: bool = false  # the one-time line that points at the blood key
var body_shown = null              # whose body picture is (or was last) up
var body_part: String = ""
var body_parts: Dictionary = {}    # part -> its button in the picture
var body_buttons: Array = []       # [{wound, aid, full}] of the rows shown
var body_cut: Dictionary = {}      # {part, key, plan} the cut's row shown, {} with none
var cut_armed: Dictionary = {}     # {of, part, t} the first press on 자르기
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
	# The 시안's type on every word of the field: IBM Plex Sans KR (ui_fonts.gd).
	theme.default_font = UiFonts.face(UiFonts.WORD, 400)
	root = Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	touch = Control.new()
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.gui_input.connect(_on_touch)
	touch.draw.connect(_draw_stick)
	root.add_child(touch)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # the paper's fibre on the slips
	overlay.draw.connect(_draw_overlay)
	root.add_child(overlay)
	# A pause shows at a glance (pause_veil.gd), under the keys and over the world.
	pause_veil = PauseVeil.new()
	pause_veil.setup(self)
	root.add_child(pause_veil)
	# A read scrawled map marks its side path's gap (map_stamp.gd, 결정 카드 loot-feel M).
	map_stamp = MapStamp.new()
	map_stamp.setup(self)
	root.add_child(map_stamp)
	_build_top()
	_build_portrait()
	_build_allies()
	_build_thumbs()
	_build_toasts()
	_build_grab()
	_build_debug()
	# The bag and the blood key keep to the card as it grows with the weapon's words.
	portrait.resized.connect(_follow_portrait)
	_follow_portrait()
	# No key's word sticks out of it (text_fit.gd), the panes' keys too.
	text_fit = TextFit.new()
	text_fit.watch(root)
	add_child(text_fit)


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


## A glass pill (시안 .fglass) that lets touches through.
func _glass(pad_x: float = 12.0, pad_y: float = 4.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", HudSkin.glass(pad_x, pad_y))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## The semibold face of the 시안's type, for the few words that lead a line.
func _bold(c: Control) -> void:
	c.add_theme_font_override("font", UiFonts.face(UiFonts.WORD, 600))


## A line icon as a picture, `px` across.
func _icon_rect(id: String, px: int, color: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = HudIcons.texture(id, px, color)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Dress a key or pad in the 시안 look: a matte disc (or a pill) `seen` across
## inside its touch rect, which stays as it is; an icon over its word. `on` is
## how it looks while set or held; `rest` lights it even at rest (lamp pills).
func _dress(b: Button, icon: String, seen: Vector2, round_key: bool, on: int = HudSkin.Light.LAMP, rest: int = HudSkin.Light.NONE, icon_px: int = 32) -> void:
	var st: Dictionary = HudSkin.key_styles(seen, round_key, on, rest)
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(k, st[k])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ink: Color = HudSkin.LAMP_INK if rest != HudSkin.Light.NONE else HudSkin.INK
	for k in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(k, ink)
	for k in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, HudSkin.LAMP_INK)
	for k in ["icon_normal_color", "icon_hover_color", "icon_focus_color"]:
		b.add_theme_color_override(k, ink)
	for k in ["icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(k, HudSkin.LAMP_INK)
	b.add_theme_constant_override("h_separation", 6)
	_set_icon(b, icon, icon_px, not round_key)


## The icon over the word on a round key, before it on a pill, alone if no word.
## A key's mark or word is fixed in the middle of its disc (user 2026-10-18);
## with no mark nothing is kept for one over the word (Godot would keep room
## for it and the key would grow off its place).
func _set_icon(b: Button, icon: String, icon_px: int, beside: bool = false) -> void:
	b.icon = HudIcons.texture(icon, icon_px, Color.WHITE) if icon != "" else null
	b.add_theme_constant_override("icon_max_width", icon_px)
	if beside:
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP if b.text != "" and icon != "" else VERTICAL_ALIGNMENT_CENTER


## A key that shows a letter or a short word in Barlow where others show a mark
## (user 2026-10-18), in the middle of its disc as every key's mark is.
func _letter(b: Button, css: float, spacing: float = 0.0) -> void:
	b.add_theme_font_override("font", UiFonts.face(UiFonts.NUMBER, 500, spacing))
	b.add_theme_font_size_override("font_size", UiFonts.size(css))
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER


## Move what a key shows down by `dy` (up if less than 0), so a mark over a
## word sits in the middle of the disc as a lone mark does: the word's line
## keeps room under its letters that the eye does not count.
func _nudge(b: Button, dy: float) -> void:
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBox = b.get_theme_stylebox(k)
		sb.content_margin_top = 4.0 + maxf(dy, 0.0) * 2.0
		sb.content_margin_bottom = 4.0 + maxf(-dy, 0.0) * 2.0


## Light key `b` up twice when it first shows, so the eye finds it without a
## line saying where it is (결정 417): its glow only, nothing moves.
func _beckon(b: Button) -> void:
	if b == null:
		return
	var was: Color = b.modulate
	var tw := b.create_tween()
	for i in 2:
		tw.tween_property(b, "modulate", was * Color(1.6, 1.45, 1.2), 0.22)
		tw.tween_property(b, "modulate", was, 0.32)


## A pill's mark and word sit together in its middle (시안 .fpad--ctx, .fall),
## not the mark at one end and the word in the rest. Again after its word or
## its looks change.
func _center_pill(b: Button) -> void:
	var font: Font = b.get_theme_font("font")
	var fs: int = b.get_theme_font_size("font_size")
	var w: float = 0.0
	for line in b.text.split("\n"):
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var mark: float = 0.0
	if b.icon != null:
		mark = float(b.get_theme_constant("icon_max_width") + b.get_theme_constant("h_separation"))
	var room: float = maxf(floorf((maxf(b.size.x, b.custom_minimum_size.x) - mark - w) * 0.5), 6.0)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBox = b.get_theme_stylebox(k)
		sb.content_margin_left = room
		sb.content_margin_right = 4.0


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
	# Tactical pause sits at the left end of the clock's row, away from the
	# fight under the right thumb (presentation_motion 666274f), its disc as
	# tall as the clock's glass beside it (user 2026-10-18).
	var pause_mid := Vector2(16.0, 14.0) + Vector2.ONE * TOP_ROW_H * 0.5
	pause_button = _pad("", pause_mid - Vector2.ONE * PAUSE_TOUCH * 0.5, Vector2.ONE * PAUSE_TOUCH, 22, Control.PRESET_TOP_LEFT)
	_dress(pause_button, "pause", Vector2.ONE * TOP_ROW_H, true, HudSkin.Light.LAMP, HudSkin.Light.NONE, PAUSE_ICON)
	pause_button.tooltip_text = "멈춤"
	# The clock is one glass line (시안 2차 11절 「12:42 · 1일째 · −14℃」), the
	# weather beside it; the share of daylight left runs as a hairline under it.
	var tl := VBoxContainer.new()
	tl.position = Vector2(16.0 + TOP_ROW_H + 10.0, 14.0)
	tl.add_theme_constant_override("separation", 6)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := _glass(16.0, 4.0)
	# Its own width and the row's height, its lines in its middle: the time's
	# line (43 at Barlow 28), the hairline under it and 4 above and below are
	# the row's 58, so the glass is no taller than the pause disc beside it.
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.custom_minimum_size.y = TOP_ROW_H
	tl.add_child(pill)
	clock_pill = pill
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(v)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	# 시안 .ftime: the time in Barlow 15 (semibold), the rest in Plex 12.
	clock_label = _label("10:30", UiFonts.size(15))
	clock_label.add_theme_font_override("font", UiFonts.face(UiFonts.NUMBER, 600))
	line.add_child(clock_label)
	day_label = _label("· 1일째", UiFonts.size(12), HudSkin.INK2)
	line.add_child(day_label)
	weather_label = _label("· %s · −14℃" % game.weather.label(), UiFonts.size(12), HudSkin.INK2)
	line.add_child(weather_label)
	for l: Label in [clock_label, day_label, weather_label]:
		l.size_flags_vertical = Control.SIZE_SHRINK_END
	sun_bar = _bar(Color(HudSkin.LAMP1.r, HudSkin.LAMP1.g, HudSkin.LAMP1.b, 0.8))
	sun_bar.custom_minimum_size = Vector2(0, 3)
	sun_bar.max_value = 1.0
	v.add_child(sun_bar)
	# The stop's own lines (a held train's state or the stop's goals, the
	# chief's aside to it, its promises) head the message column left of the
	# state icons (user 2026-10-18: state lines go there, not over the
	# screen), each right-aligned; _place_messages puts them there.
	info_box = VBoxContainer.new()
	info_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	info_box.add_theme_constant_override("separation", 6)
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if game.mission_play != null and (game.mission_play.active() or game.holdout.enabled()):
		# A glass line of its own (시안 .fgoal): a held train's state, and the
		# stop's goals once they are opened (goal_shown).
		var gp := _glass(14.0, 5.0)
		gp.size_flags_horizontal = Control.SIZE_SHRINK_END
		info_box.add_child(gp)
		var mark := _icon_rect("compass", 22, HudSkin.GOAL)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		gp.add_child(mark)
		goal_label = _label(UiFonts.keep_all(goal_shown()), UiFonts.size(12), HudSkin.GOAL)
		goal_label.add_theme_font_override("font", UiFonts.face(UiFonts.WORD, 500))
		var room := StyleBoxEmpty.new()
		room.content_margin_left = 30
		goal_label.add_theme_stylebox_override("normal", room)
		gp.add_child(goal_label)
		# Folded under its key (user 2026-10-18); a held train's state is down to
		# begin with (decision 293 ②: it is the stop's state, not its goals).
		goal_open = game.holdout.enabled()
		gp.visible = goal_open and goal_label.text != ""
	# The promises this stop was sent out with (S3: the departure's promises, or
	# the state the train sends): one small glass line (user 2026-10-18: 「약속은
	# 껐다 킬 수 있게 작게」), down under its key on the clock's row only while
	# opened (「약속도 펼치거나 닫을 수 있도록」). Key and line are there only
	# while there are any (set_promises, once the key is built).
	var pp := _glass(10.0, 3.0)
	pp.size_flags_horizontal = Control.SIZE_SHRINK_END
	info_box.add_child(pp)
	var seal := _icon_rect("promise", PROMISE_SEAL, HudSkin.INK2)
	seal.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pp.add_child(seal)
	promise_label = _label("", UiFonts.size(10.5), HudSkin.INK2)
	var seal_room := StyleBoxEmpty.new()
	seal_room.content_margin_left = PROMISE_ROOM
	promise_label.add_theme_stylebox_override("normal", seal_room)
	pp.add_child(promise_label)
	pp.visible = false
	root.add_child(tl)
	top_panel = tl
	root.add_child(info_box)
	# The time and the day keep the room of their widest, so the glass (and the
	# orders right of it) holds still as the minutes and the days go by.
	_hold_widest(clock_label, "%d%d:%d%d")
	_hold_widest(day_label, "· %d%d일째")
	if goal_label != null:
		# The chief's aside to the risk line: there while that line is, under it.
		feel_label = _label(UiFonts.keep_all(game.holdout.feel_line()), 17, HudSkin.INK2)
		feel_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
		feel_label.add_theme_constant_override("outline_size", 5)
		feel_label.visible = feel_label.text != "" and goal_label.get_parent().visible
		feel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		feel_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		info_box.add_child(feel_label)
		info_box.move_child(feel_label, goal_label.get_parent().get_index() + 1)
	# The radio: one glass line in the top middle, the set's mark before the
	# words (시안 .fradio). From dusk it burns amber like 'all aboard'.
	radio_pill = PanelContainer.new()
	radio_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var calm: StyleBoxFlat = HudSkin.glass(18.0, 6.0)
	var hot: StyleBoxFlat = HudSkin.glass(18.0, 6.0)
	hot.bg_color = Color(0.36, 0.2, 0.07, 0.78)
	hot.shadow_color = Color(HudSkin.GLOW.r, HudSkin.GLOW.g, HudSkin.GLOW.b, 0.5)
	hot.shadow_size = 14
	hot.shadow_offset = Vector2.ZERO
	radio_styles = [calm, hot]
	radio_pill.add_theme_stylebox_override("panel", calm)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", int(UiFonts.px(7)))
	rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radio_pill.add_child(rh)
	rh.add_child(_icon_rect("radio", int(UiFonts.px(16)), HudSkin.INK2))
	# The set's crackle, letter by letter a little off its line, then the call
	# in Plex 14 semibold (시안 .fradio).
	radio_hiss = HBoxContainer.new()
	radio_hiss.add_theme_constant_override("separation", 0)
	radio_hiss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for row: Array in HISS:
		var c := Control.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UiFonts.label(row[0], UiFonts.WORD, 400, 12.0, Color(HudSkin.INK2.r, HudSkin.INK2.g, HudSkin.INK2.b, HudSkin.INK2.a * float(row[2])), 0.24)
		l.position = Vector2(0, UiFonts.px(float(row[1])))
		c.add_child(l)
		c.custom_minimum_size = l.get_combined_minimum_size()
		radio_hiss.add_child(c)
	radio_hiss.add_child(UiFonts.label("…", UiFonts.WORD, 400, 12.0, HudSkin.INK2))
	radio_hiss.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rh.add_child(radio_hiss)
	radio_label = _label("", UiFonts.size(14), INK)
	_bold(radio_label)
	radio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	radio_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rh.add_child(radio_label)
	radio_pill.position = Vector2(0, 14)
	radio_pill.visible = false
	root.add_child(radio_pill)
	# Test keys (not part of the game's look): zoom and the measures panel, on
	# the clock's row against the right edge (user 2026-10-18: 「우측에 붙여주고
	# 간격유지」), a step left of the gear while it shows (paused; tick).
	test_keys = HBoxContainer.new()
	test_keys.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	test_keys.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	test_keys.offset_left = STATUS_AT.x
	test_keys.offset_right = STATUS_AT.x
	test_keys.offset_top = 14.0
	test_keys.add_theme_constant_override("separation", 8)
	root.add_child(test_keys)
	# D (the debug view) is a builder's key: a release export leaves it out.
	var rows: Array = [["−", _zoom.bind(4.0), 64.0], ["+", _zoom.bind(-4.0), 64.0]]
	if OS.is_debug_build():
		rows.append(["D", _toggle_debug, 56.0])
	for row in rows:
		var k := _button(row[0], row[1], Vector2(row[2], TOP_ROW_H), 22)
		_dress(k, "", Vector2(46, 46), true)
		# Quieter than the game's own keys (they are not in the 시안): smaller,
		# no ring, faint glass and faint words.
		for st in ["normal", "hover", "disabled"]:
			var plate = k.get_theme_stylebox(st)
			plate.ring = Color(0, 0, 0, 0)
			plate.fill = Color(plate.fill.r, plate.fill.g, plate.fill.b, 0.32)
		for c in ["font_color", "font_hover_color", "font_focus_color"]:
			k.add_theme_color_override(c, HudSkin.INK3)
		test_keys.add_child(k)
	# The stop's goals and its promises fold to two keys on the clock's row,
	# left of the view keys (user 2026-10-18: 「시점 조절 버튼 좌측에 바깥 설비
	# 쪽 버튼」): a tap lets the line down at the head of the message column or
	# takes it up, the key lit while it is down. Each is there only while it
	# has words; the goals' key is the one next to the view keys.
	fold_keys = HBoxContainer.new()
	fold_keys.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fold_keys.add_theme_constant_override("separation", 8)
	root.add_child(fold_keys)
	promise_key = _fold_key("promise", "약속", _toggle_promise)
	goal_key = _fold_key("compass", "목표", _toggle_goal)
	goal_key.visible = goal_label != null and goal_label.text != ""
	goal_key.set_pressed_no_signal(goal_open)
	set_promises(game_promises())
	# The clock folds to its time (user 2026-10-18: 「시계도 클릭으로 펼칠 수
	# 있게」); a tap on it shows the day and the weather as well, or folds it.
	set_clock_open(false)


## A round glass key on the clock's row that lets a line down or takes it up,
## lit brass while the line is down.
func _fold_key(icon: String, tip: String, cb: Callable) -> Button:
	var k := _button("", cb, Vector2(56.0, TOP_ROW_H), 22)
	_dress(k, icon, Vector2(46, 46), true, HudSkin.Light.BRASS, HudSkin.Light.NONE, 24)
	k.toggle_mode = true
	k.tooltip_text = tip
	fold_keys.add_child(k)
	return k


## Fold the clock to its time, or open it to the day and the weather as well.
func set_clock_open(open: bool) -> void:
	clock_open = open
	day_label.visible = open
	weather_label.visible = open
	top_panel.reset_size()


func _zoom(step: float) -> void:
	game.cam_size = clampf(game.cam_size + step, 14.0, 36.0)


func _toggle_debug() -> void:
	debug_panel.visible = not debug_panel.visible


func _build_portrait() -> void:
	portrait = PanelContainer.new()
	portrait_style = StyleBoxFlat.new()
	portrait_style.bg_color = Color(0, 0, 0, 0)
	portrait.add_theme_stylebox_override("panel", portrait_style)
	# Top left, under the clock: the bottom-left corner is the fixed stick's
	# (it sat under the thumb there). A tap on it opens the body picture; the
	# HUD hit-tests it itself, like the pads.
	portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
	portrait.position = PORTRAIT_AT
	portrait.custom_minimum_size = Vector2(PORTRAIT_W, 0)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The chief's card (시안 2차 11절): the face shows the body, so there are no
	# state words and no state key on it; the weapon and its state beside it.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(row)
	face = PortraitFace.new()
	face.custom_minimum_size = Vector2.ONE * FACE_SIZE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(face)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var wp := _glass(16.0, 6.0)
	wp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(wp)
	var wh := HBoxContainer.new()
	wh.add_theme_constant_override("separation", 6)
	wh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wp.add_child(wh)
	# 시안 .fwpn: the weapon in Plex 13 semibold, its state 12 semibold.
	weapon_label = UiFonts.label("", UiFonts.WORD, 600, 13.0, INK, 0.52)
	wh.add_child(weapon_label)
	cond_label = UiFonts.label("", UiFonts.WORD, 600, 12.0, HudSkin.GOOD, 0.24)
	wh.add_child(cond_label)
	ammo_label = UiFonts.label("", UiFonts.WORD, 400, 12.0, HudSkin.INK2)
	wh.add_child(ammo_label)
	# The floor and a blood-soaked coat, as small tags under the weapon; the
	# chief's name is not written (the card is the chief's).
	tag_box = HBoxContainer.new()
	tag_box.add_theme_constant_override("separation", 6)
	tag_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tag_box)
	name_label = _tag("")
	tag_box.add_child(name_label.get_parent())
	status_label = _tag("피범벅", HudSkin.HEED)
	tag_box.add_child(status_label.get_parent())
	root.add_child(portrait)


## The bag key right under the card, the blood key at its right end. Laid out
## from the card's minimum size too, which is known before the first frame.
func _follow_portrait() -> void:
	var s: Vector2 = portrait.size.max(portrait.get_combined_minimum_size())
	bag_box.position = portrait.position + Vector2(0, s.y + 6.0)
	blood_button.position = portrait.position + Vector2(s.x + 8.0, (FACE_SIZE - blood_button.size.y) * 0.5)


## A small glass tag holding one word; returns its label.
func _tag(text: String, color: Color = HudSkin.INK2) -> Label:
	var p := _glass(10.0, 2.0)
	var l := _label(text, UiFonts.size(10.5), color)
	p.add_child(l)
	return l


## Give a label the width of `pattern` with its widest digit in every place.
func _hold_widest(l: Label, pattern: String) -> void:
	var font: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	var w: float = 0.0
	for d in 10:
		w = maxf(w, font.get_string_size(pattern.replace("%d", str(d)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	l.custom_minimum_size.x = ceilf(w)


## One of the stop's lines no wider than `cap` with its glass: a longer one
## wraps, between words only (its text carries UiFonts.keep_all's joiners).
func _cap_line(l: Label, cap: float) -> void:
	if l == null:
		return
	var own: float = 0.0
	var sb: StyleBox = l.get_theme_stylebox("normal")
	if sb != null:
		own = sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	var total: float = cap
	var glass = l.get_parent()
	if glass is PanelContainer:
		var gs: StyleBox = glass.get_theme_stylebox("panel")
		total -= gs.get_margin(SIDE_LEFT) + gs.get_margin(SIDE_RIGHT)
	total = floorf(total)
	var words: float = l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
	var wrap: bool = words > total - own
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = total if wrap else 0.0


func _build_allies() -> void:
	allies_box = HBoxContainer.new()
	# At the foot of the screen (시안 .fally), the middle face under the
	# screen's middle (user 2026-10-18: 「동료는 가운데 기준」): the faces alone,
	# their words on a card a tap opens over the face (「가릴 때는 안 보이게
	# 클릭하면 보일 수 있게」). _place_allies keeps it clear of the stick and the
	# right thumb's pads.
	allies_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	allies_box.add_theme_constant_override("separation", int(CHIP_GAP))
	root.add_child(allies_box)
	for p in game.squad:
		if p == game.player:
			continue
		var i: int = ally_buttons.size()
		var b := _button("", _toggle_card.bind(i), Vector2.ONE * CHIP_TOKEN, 17)
		_chip(b)
		var row := {"p": p, "b": b}
		_chip_face(b, row, i)
		allies_box.add_child(b)
		row["card"] = _ally_card(row, i)
		ally_buttons.append(row)
	# The work crew's chip stands right beside the faces (_place_allies), as
	# wide as its words and as tall as a face's round.
	crew_button = _button("작업조", work_panel, Vector2(0, CHIP_TOKEN), 17)
	_chip(crew_button)
	crew_button.add_theme_constant_override("icon_max_width", roundi(UiFonts.px(22)))
	crew_button.visible = false
	crew_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.add_child(crew_button)


## A companion's glass (the face's round, its card, the crew's pill); pressed it
## glows amber at its foot and takes an amber ring (시안 .fchip.on).
func _chip(b: Button) -> void:
	var rest: StyleBoxFlat = HudSkin.glass(14.0, 6.0)
	var lit: StyleBoxFlat = rest.duplicate()
	lit.bg_color = Color(0.34, 0.23, 0.1, 0.8)
	lit.border_color = HudSkin.HEED
	lit.set_border_width_all(2)
	lit.shadow_color = Color(HudSkin.GLOW.r, HudSkin.GLOW.g, HudSkin.GLOW.b, 0.4)
	lit.shadow_size = 14
	lit.shadow_offset = Vector2.ZERO
	for k in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(k, rest)
	for k in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(k, lit)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, HudSkin.INK)
	b.add_theme_constant_override("line_spacing", -2)


## The face in the middle of a companion's round (it carries the body, as the
## chief's does, decision 293 ①).
func _chip_face(b: Button, row: Dictionary, i: int) -> void:
	var f := PortraitFace.new()
	f.kind = CHIP_KINDS[i % CHIP_KINDS.size()]
	f.face_seed = 11 + i
	f.custom_minimum_size = Vector2.ONE * CHIP_FACE
	f.size = Vector2.ONE * CHIP_FACE
	f.position = Vector2.ONE * roundf((CHIP_TOKEN - CHIP_FACE) * 0.5)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(f)
	row["face"] = f


## The card over a companion's face (시안 .fchip's words): the name (13
## semibold) with the weapon in hand after it (H3), over the order (12) and, if
## it is more, what they are at. A tap on it opens their orders and state.
func _ally_card(row: Dictionary, i: int) -> Button:
	var card := _button("", _open_card.bind(i), Vector2.ZERO, 17)
	_chip(card)
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card.visible = false
	root.add_child(card)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = UiFonts.px(CARD_PAD.x)
	v.offset_right = -UiFonts.px(CARD_PAD.x)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(UiFonts.px(4)))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var who := UiFonts.label("", UiFonts.WORD, 600, 13.0, HudSkin.INK, 0.52)
	var arm := UiFonts.label("", UiFonts.WORD, 400, 11.0, HudSkin.INK3)
	arm.size_flags_vertical = Control.SIZE_SHRINK_END
	var note := UiFonts.label("", UiFonts.WORD, 400, 12.0, HudSkin.INK2)
	for l: Label in [who, arm, note]:
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(who)
	top.add_child(arm)
	v.add_child(note)
	row["words"] = v
	row["name"] = who
	row["arm"] = arm
	row["note"] = note
	return card


## A card as wide as its words, those cut short past CHIP_WORDS_W.
func _fit_card(row: Dictionary) -> void:
	var gap: float = UiFonts.px(4)
	var name_w: float = _fit_word(row["name"], CHIP_WORDS_W)
	var arm_w: float = _fit_word(row["arm"], CHIP_WORDS_W - name_w - gap)
	var note_w: float = _fit_word(row["note"], CHIP_WORDS_W)
	var words: float = maxf(name_w + gap + arm_w, note_w)
	var pad: Vector2 = Vector2(UiFonts.px(CARD_PAD.x), UiFonts.px(CARD_PAD.y)) * 2.0
	var card: Button = row["card"]
	card.custom_minimum_size = Vector2(ceilf(words + pad.x), ceilf((row["words"] as Control).get_combined_minimum_size().y + pad.y))
	card.size = card.custom_minimum_size


## A tap on a face opens its card over it, or folds it; one card at a time.
func _toggle_card(i: int) -> void:
	card_row = -1 if card_row == i else i
	for j in ally_buttons.size():
		(ally_buttons[j]["card"] as Control).visible = j == card_row
	_place_allies()


## A tap on an open card: the companion's orders and state, the card folded.
func _open_card(i: int) -> void:
	var p = ally_buttons[i]["p"]
	_toggle_card(i)
	_ally_menu(p)


## Give a label the width of its words, `room` at most; returns that width.
func _fit_word(l: Label, room: float) -> float:
	var w: float = ceilf(l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x)
	w = minf(w, maxf(room, 0.0))
	l.custom_minimum_size.x = w
	return w


## Thumb pads (field_unified 10, user 17:15, coordinators 18:10-18:30). Right:
## aim with a small 'manual' switch (only with a gun in hand), attack, shove,
## crouch (decision 293) and the situation pad (only when there is something
## to do). Left, above the stick: the run toggle and, after dark, the lamp;
## pause top left. These are pads, not Buttons: one thumb is
## on the stick, so the other is a second finger, which Godot buttons do not
## take. The HUD hit-tests them itself.
func _build_thumbs() -> void:
	# Attack is the big one in the corner; aim is small beside it and 'manual'
	# is in aim's row (user 2026-10-12). With 'one main action' the aim pad is
	# the only one, so it takes the big place.
	var one: bool = bool(game.opts.get("primary_one", false))
	attack_button = _pad("A", ATTACK_AT, ATTACK_SIZE, 20)
	_dress(attack_button, "", Vector2.ONE * ATTACK_SEEN, true, HudSkin.Light.LAMP, HudSkin.Light.NONE, ATTACK_ICON)
	_letter(attack_button, ATTACK_LETTER)
	_nudge(attack_button, LETTER_NUDGE)
	attack_button.tooltip_text = "공격"
	# Aim: its mark alone in the middle of its disc (user 2026-10-18: no word).
	aim_button = _pad("", ATTACK_AT if one else AIM_AT, ATTACK_SIZE if one else AIM_SIZE, 20 if one else 17)
	_dress(aim_button, "aim", Vector2.ONE * (ATTACK_SEEN if one else 84.0), true, HudSkin.Light.LAMP, HudSkin.Light.NONE, ATTACK_ICON if one else LONE_ICON)
	aim_button.tooltip_text = "조준"
	manual_button = _pad("수동", AIM_AT if one else AIM_AT + Vector2(-(MANUAL_SIZE.x + 8.0), 0), MANUAL_SIZE, 18)
	_dress(manual_button, "", Vector2.ONE * 76.0, true)
	# The shove mark alone in the middle of its disc (user 2026-10-18: no word).
	shove_button = _pad("", SHOVE_AT, SHOVE_SIZE, UiFonts.size(11))
	_dress(shove_button, "shove", Vector2.ONE * 84.0, true, HudSkin.Light.LAMP, HudSkin.Light.NONE, LONE_ICON)
	shove_button.tooltip_text = "밀치기"
	# Crouch: a round key on the right edge over attack (decision 293), a figure
	# on one knee (user 2026-10-18). It lights brass from inside while on.
	var key := 11.0 * PX_PER_MM
	crouch_button = _pad("", Vector2(-16.0 - key, ATTACK_AT.y - 8.0 - key), Vector2(key, key), 20)
	_dress(crouch_button, "crouch", Vector2.ONE * KEY_SEEN, true, HudSkin.Light.BRASS, HudSkin.Light.NONE, 44)
	crouch_button.tooltip_text = "웅크림"
	# The situation pad and leaving burn like lamps with a brass rim (시안 3절,
	# .fpad--ctx); dark ink on the light. Their touch rects stay as they were.
	# The situation pad: the nearest thing's mark alone on a round lamp key,
	# and on its rim how many more a hold lays out (user 2026-10-18: no word,
	# smaller).
	context_button = _pad("", CONTEXT_AT, Vector2(140, 84), UiFonts.size(DEPART_FONT))
	_dress(context_button, "search", Vector2.ONE * 84.0, true, HudSkin.Light.LAMP, HudSkin.Light.LAMP, LONE_ICON)
	context_button.tooltip_text = "상황"
	context_badge = _glass(UiFonts.px(4.0), 0.0)
	context_more = UiFonts.label("", UiFonts.NUMBER, 600, 12.0, HudSkin.INK)
	context_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	context_badge.add_child(context_more)
	context_badge.visible = false
	context_button.add_child(context_badge)
	# Leaving: its word alone on a pill at least MIN_TOUCH high.
	depart_button = _pad("출발", DEPART_AT, Vector2(140, 84), UiFonts.size(DEPART_FONT))
	_dress(depart_button, "", DEPART_SEEN, false, HudSkin.Light.LAMP, HudSkin.Light.LAMP)
	_bold(depart_button)
	depart_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	depart_button.visible = false
	# The squad's orders in a drawer under a lever at the top middle (user
	# 2026-10-18), folded to begin with. 'All aboard' sends every companion
	# back to the train at one press (user 2026-10-11), its word alone (no
	# train mark); glass by day, from dusk it burns like a lamp (시안 2차
	# 11절). Under it 따라와 and 대기 for every living companion (decision
	# 408), the two as wide as it.
	lever_button = _pad("", Vector2.ZERO, LEVER_TOUCH, 18, Control.PRESET_TOP_LEFT)
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		lever_button.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	lever_button.tooltip_text = "동료 명령"
	var calm: StyleBoxFlat = HudSkin.glass(0.0, 0.0)
	calm.corner_radius_top_left = 0
	calm.corner_radius_top_right = 0
	calm.corner_radius_bottom_left = 12
	calm.corner_radius_bottom_right = 12
	var hot: StyleBoxFlat = calm.duplicate() as StyleBoxFlat
	hot.bg_color = Color(0.36, 0.2, 0.07, 0.78)
	hot.shadow_color = Color(HudSkin.GLOW.r, HudSkin.GLOW.g, HudSkin.GLOW.b, 0.5)
	hot.shadow_size = 14
	hot.shadow_offset = Vector2.ZERO
	lever_styles = [calm, hot]
	lever_slot = StyleBoxFlat.new()
	lever_slot.bg_color = Color(0, 0, 0, 0.55)
	lever_slot.set_corner_radius_all(3)
	lever_button.draw.connect(_draw_lever)
	var aboard_font: Font = UiFonts.face(UiFonts.WORD, 500, 0.78)
	var aboard_words: float = aboard_font.get_string_size("모두 열차로", HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.size(13.0)).x
	var order_font: Font = UiFonts.face(UiFonts.WORD, 500, 0.26)
	var order_words: float = 0.0
	for c: Array in COMMANDS.slice(0, 2):
		order_words = maxf(order_words, order_font.get_string_size(command_word(c), HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.size(13.0)).x)
	var gap: float = UiFonts.px(SQUAD_GAP)
	var wide: float = maxf(ceilf(UiFonts.px(16.0 + 16.0) + aboard_words), 2.0 * ceilf(UiFonts.px(7.0 + 7.0) + order_words) + gap)
	all_aboard_size = Vector2(wide, roundf(UiFonts.px(ALL_ABOARD_H)))
	var aboard_seen := Vector2(all_aboard_size.x, roundf(UiFonts.px(ALL_ABOARD_SEEN)))
	all_aboard_button = _pad("모두 열차로", Vector2.ZERO, all_aboard_size, UiFonts.size(13.0), Control.PRESET_TOP_LEFT)
	all_aboard_styles = [HudSkin.key_styles(aboard_seen, false), HudSkin.key_styles(aboard_seen, false, HudSkin.Light.LAMP, HudSkin.Light.LAMP)]
	# By day matte as the two under it; from dusk it burns.
	for plate in all_aboard_styles[0].values():
		plate.brass_rim = false
	_dress(all_aboard_button, "", aboard_seen, false, HudSkin.Light.LAMP, HudSkin.Light.NONE, int(UiFonts.px(16.0)))
	_matte(all_aboard_button)
	all_aboard_button.add_theme_font_override("font", aboard_font)
	all_aboard_button.add_theme_constant_override("h_separation", int(UiFonts.px(5.0)))
	_center_pill(all_aboard_button)
	order_size = Vector2(floorf((wide - gap) * 0.5), roundf(UiFonts.px(ORDER_H)))
	follow_button = _order_pad(COMMANDS[0], order_font)
	wait_button = _order_pad(COMMANDS[1], order_font)
	_place_squad()
	_place_allies()
	# Running is a toggle, so no required move needs a double tap (presentation_motion 8c);
	# the stick rim and a double tap run only when set on the start screen.
	# Right over the stick (user 2026-10-18: 「왼쪽 조작 토글 바로 위에
	# (여유있게)」): an 11 mm key on the stick's middle line, its foot 4 mm over
	# the stick's ring, so the ring of nothing round it (finger_down) ends
	# where the stick's ring begins (presentation_motion 5, 57446c8 had it
	# 20 mm in and 35 mm up).
	var run_x: float = STICK_HOME_MM.x * PX_PER_MM - key * 0.5
	var up: float = -(STICK_HOME_MM.y * PX_PER_MM + STICK_RING + 4.0 * PX_PER_MM + key)
	# The round keys show a picture and no word (시안 2차 11절, 배그처럼), but run
	# shows RUN (user 2026-10-18); a key that is on lights from inside, running
	# and the lamp amber, crouching brass.
	run_button = _pad("RUN", Vector2(run_x, up), Vector2(key, key), 22, Control.PRESET_BOTTOM_LEFT)
	_dress(run_button, "", Vector2.ONE * KEY_SEEN, true, HudSkin.Light.LAMP, HudSkin.Light.NONE, 40)
	_letter(run_button, RUN_WORD, 1.5)
	run_button.tooltip_text = "뛰기"
	# The lantern key, right of run 3 mm apart; it is there only after sunset.
	lamp_button = _pad("", Vector2(run_x + key + 3.0 * PX_PER_MM, up), Vector2(key, key), 22, Control.PRESET_BOTTOM_LEFT)
	_dress(lamp_button, "lamp", Vector2.ONE * KEY_SEEN, true, HudSkin.Light.LAMP, HudSkin.Light.NONE, 36)
	lamp_button.tooltip_text = "등불"
	lamp_button.visible = false
	# A blood drop on the portrait's corner while you bleed: one press stops the
	# worst of it and binds it (body_injury 4.6, 0f95fc0). Nothing more.
	# It sits at the portrait's right edge, clear of the stick: a lamp pill
	# (tick keeps it there as the card widens with the weapon's words).
	blood_button = _pad("지혈", PORTRAIT_AT + Vector2(PORTRAIT_W + 8.0, 0), Vector2(84, 64), 19, Control.PRESET_TOP_LEFT)
	_dress(blood_button, "bandage", Vector2(84, 52), false, HudSkin.Light.LAMP, HudSkin.Light.LAMP, 20)
	_bold(blood_button)
	_center_pill(blood_button)
	blood_button.visible = false
	# State icons (user, build 47): press one and it says what it does to you.
	for i in STATUS_SLOTS:
		var pad := _pad("", STATUS_AT, Vector2.ONE * status_diameter(), 18, Control.PRESET_TOP_RIGHT)
		pad.visible = false
		pad.expand_icon = true
		pad.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# The picture brings its own plate; the key under it draws nothing.
		for state in ["normal", "hover", "pressed", "disabled"]:
			pad.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		status_pads.append(pad)
	_place_status()
	# Paused: the settings (stick, radio) open from one key; they are not on
	# the playing screen themselves (user 2026-10-12).
	# A round gear key in the top right corner (시안 2차 11절), over the state icons.
	settings_button = _pad("", Vector2(-16.0 - SETTINGS_KEY, STATUS_AT.y - 4.0 - SETTINGS_KEY), Vector2.ONE * SETTINGS_KEY, 19, Control.PRESET_TOP_RIGHT)
	settings_button.tooltip_text = "설정"
	_dress(settings_button, "gear", Vector2.ONE * 64.0, true, HudSkin.Light.LAMP, HudSkin.Light.NONE, 34)
	# A white rim round see-through glass, as the state plates under it.
	for st in ["normal", "hover", "disabled"]:
		var plate = settings_button.get_theme_stylebox(st)
		plate.ring = SET_RIM
		plate.ring_w = 3.0 * UiFonts.K
		plate.over_ring = false
	settings_button.visible = false
	for b in [manual_button, run_button, crouch_button, aim_button, attack_button, lamp_button]:
		b.toggle_mode = true
	# Movement and use keys are see-through (user 2026-10-18: 「Run 과 같은
	# 플레이어 이동과 상호작용 버튼은 반투명하게 … 출발과 밑에 있는 버튼도」):
	# no warm ground under their glass, the plate and its light at PAD_SEE, the
	# mark and the word on them whole.
	for b in [run_button, lamp_button, crouch_button, shove_button, attack_button, aim_button, manual_button, context_button, depart_button]:
		for k in ["normal", "hover", "pressed", "hover_pressed"]:
			var plate = b.get_theme_stylebox(k)
			plate.over_ring = false
			plate.dim = PAD_SEE
	# The bag is right under the chief's portrait (user 2026-10-12; tick keeps
	# it there as the portrait grows). There is no swap button here any more:
	# swapping is inside the bag panel (build 47). It is 인벤토리 now and shows
	# the weight carried on it (시안 2차 11절 「5.5/8」).
	bag_box = HBoxContainer.new()
	bag_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bag_box.position = PORTRAIT_AT + Vector2(0, 96)
	bag_box.add_theme_constant_override("separation", 8)
	root.add_child(bag_box)
	# 시안 .finv: the mark 15, the weight in Barlow 14.
	bag_button = _button("0.0/8", bag_panel, Vector2(124, 52), UiFonts.size(14))
	bag_button.tooltip_text = "인벤토리"
	_dress(bag_button, "pack", Vector2(124, 48), false, HudSkin.Light.LAMP, HudSkin.Light.NONE, 30)
	# Plain glass like the orders and 모두 열차로: a key that is not lit wears no
	# brass sweep (user 2026-10-25 on the phone: 「배낭 버튼 유광」).
	_matte(bag_button)
	bag_button.add_theme_font_override("font", UiFonts.face(UiFonts.NUMBER, 500))
	bag_box.add_child(bag_button)
	# A watch picked up still set: its mark lights beside the bag until pressed.
	alarm_button = _button("", _alarm_key_off, Vector2(52, 52), UiFonts.size(14))
	alarm_button.tooltip_text = "시계 알람 끄기"
	_dress(alarm_button, "clock", Vector2(48, 48), true, HudSkin.Light.LAMP, HudSkin.Light.LAMP, 26)
	alarm_button.visible = false
	bag_box.add_child(alarm_button)
	offer_box = Control.new()
	offer_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	offer_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(offer_box)
	root.resized.connect(_layout_offer.call_deferred)


func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Its place is the message column's, under the radio (_place_messages).
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)


func _build_grab() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-140, 40)
	root.add_child(v)
	grab_button = _button("밀쳐!", _shove, Vector2(280, 120), 44)
	_dress(grab_button, "shove", Vector2(280, 108), false, HudSkin.Light.LAMP, HudSkin.Light.LAMP, 40)
	v.add_child(grab_button)
	grab_bar = _bar(HudSkin.LAMP1)
	grab_bar.custom_minimum_size = Vector2(280, 10)
	grab_bar.max_value = 1.0
	v.add_child(grab_bar)
	grab_button.visible = false
	grab_bar.visible = false


func _build_debug() -> void:
	debug_panel = _panel(Color(0, 0, 0, 0.72))
	debug_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_panel.position = Vector2(-430 - 16 - (STATUS_ART_SIZE + STATUS_GAP) * 2.0, 84)   # left of the state icons' columns
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
	var h2 := HBoxContainer.new()
	v.add_child(h2)
	h2.add_child(_button("해 질 녘으로", _debug_dusk, Vector2(140, 48), 16))
	h2.add_child(_button("폭풍 층", _debug_storm, Vector2(96, 48), 16))
	h2.add_child(_button("망자 세우기", _debug_stand, Vector2(110, 48), 16))
	var h3 := HBoxContainer.new()
	v.add_child(h3)
	h3.add_child(_button("동작 시험", _debug_motion, Vector2(110, 48), 16))
	debug_panel.visible = false
	root.add_child(debug_panel)


func _debug_speed() -> void:
	game.clock.speed = 2.0 if game.clock.speed < 1.5 else 1.0


func _debug_fps() -> void:
	Engine.max_fps = 30 if Engine.max_fps != 30 else 60


func _debug_mask() -> void:
	game.mask_on = not game.mask_on


## Test key: stand 10, then 20, then 40 of the dead where the chief can see
## them, to measure what drawing a crowd costs on the phone. They are ordinary
## dead (the rules are not changed); each press clears the last lot first.
const STAND_COUNTS: Array[int] = [10, 20, 40]
var stand_step: int = -1
var stood: Array = []


func _debug_stand() -> void:
	for z in stood:
		game.zombies.list.erase(z)
	stood.clear()
	stand_step = (stand_step + 1) % STAND_COUNTS.size()
	var want: int = STAND_COUNTS[stand_step]
	var at: Vector3 = game.player.position
	# The cells the chief sees now, nearest first; a second body to a cell if they run out.
	var here: Vector2i = FieldGrid.cell_of(at)
	var cells: Array = []
	for dx in range(-14, 15):
		for dy in range(-14, 15):
			var c := here + Vector2i(dx, dy)
			var spot := FieldGrid.center(c)
			spot.y = at.y
			if dx * dx + dy * dy >= 6 and game.grid.inside(c) and game.grid.dead_can_walk(c) and game.seen_now.has(game.seen_key(spot)):
				cells.append([dx * dx + dy * dy, spot])
	cells.sort_custom(func(a, b): return a[0] < b[0])
	for round in 2:
		for row in cells:
			if stood.size() < want:
				stood.append(game.zombies.spawn("dead", row[1] + Vector3(0.3, 0, 0.3) * float(round)))
	toast("시험: 보이는 곳에 망자 %d을 세웠다(바란 수 %d)." % [stood.size(), want])


## Test key: sets up one scene of motion at a time in front of the chief, so
## the same moment can be filmed on the phone before and after a change to how
## bodies move. Each press clears the last scene's dead and sets up the next.
## The rules then run as ever (a held chief is bitten unless they shove free).
const MOTION_SCENES: Array[String] = ["잡힘", "덤빔", "밀칠 망자 둘", "뒤지기", "치료", "넘어짐"]
var motion_step: int = -1
var motion_dead: Array = []


func _debug_motion() -> void:
	var p = game.player
	for z in motion_dead:
		if p.grabbers.has(z):
			p.release_grab(z)
		game.zombies.list.erase(z)
	motion_dead.clear()
	motion_step = (motion_step + 1) % MOTION_SCENES.size()
	var forward := Vector3(sin(p.facing), 0, cos(p.facing))
	var side := Vector3(forward.z, 0, -forward.x)
	match MOTION_SCENES[motion_step]:
		"잡힘":
			var z: Dictionary = _motion_dead(p.position + forward * 0.5, p)
			z["state"] = "grab"
			z["victim"] = p
			z["cooldown"] = 1.6
			p.grabbers.append(z)
			p.grab_front = true
			p.grab_left = GrabRules.window(true, 1, int(p.skills["melee"]), int(p.skills["strength"]), float(p.mults()["shove_window"]))
			p.cancel_action()
			p.stop()
			p.aim.stop()
			grab_alert(true)
		"덤빔":
			var z: Dictionary = _motion_dead(p.position + forward * 3.0, p)
			z["state"] = "chase"
			z["victim"] = p
		"밀칠 망자 둘":
			for s in [-0.5, 0.5]:
				var z: Dictionary = _motion_dead(p.position + forward * 1.0 + side * s, p)
				z["state"] = "chase"
				z["victim"] = p
		"뒤지기":
			p.start_action("search", "뒤지기", 5.0, func() -> void: pass)
		"치료":
			p.start_action("treat", "붕대", 5.0, func() -> void: pass)
		"넘어짐":
			game.combat.fall(p, "시험으로 넘어짐", 0.0)
	toast("시험 동작: " + MOTION_SCENES[motion_step])


func _motion_dead(at: Vector3, facing_who) -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", at)
	z["angle"] = atan2(facing_who.position.x - at.x, facing_who.position.z - at.z)
	z["seen_t"] = 1.0
	motion_dead.append(z)
	return z


## Test key: what a storm stop draws, one layer off at a time (phone frames).
func _debug_storm() -> void:
	if game.storm.is_empty():
		toast("폭풍 정차 아님")
		return
	game.set_storm_cut(game.storm_cut + 1)
	toast("시험: 폭풍 층 " + String(game.STORM_CUTS[game.storm_cut]))


func _debug_horde() -> void:
	game.director.next_arrival = game.clock.elapsed


## Test key: the clock jumps to 15:40 so dusk and the lanterns can be seen
## without playing twenty minutes. The next horde keeps its distance in time.
func _debug_dusk() -> void:
	var to: float = (DUSK_TEST_MIN - float(game.clock.arrive_min)) * 60.0 / game.clock.GAME_PER_REAL
	var jump: float = to - game.clock.elapsed
	if jump <= 0.0:
		toast("이미 해 질 녘")
		return
	game.clock.elapsed = to
	if game.director.next_arrival < INF:
		game.director.next_arrival += jump
	toast("시험: 15:40으로 넘김 · 20초쯤 뒤 해 짐 · 떠날 때도 가까움")


# ---------------------------------------------------------------- per frame

func tick(delta: float) -> void:
	if game == null or game.player == null:
		return
	_tick_leave(delta)
	fps_t -= delta
	frame_ms = lerpf(frame_ms, delta * 1000.0, 0.1)
	var p = game.player
	_tick_clock()
	if goal_label != null:
		goal_label.text = UiFonts.keep_all(goal_shown())
		var gp: Control = goal_label.get_parent()
		gp.visible = goal_open and goal_label.text != ""
		goal_key.visible = goal_label.text != ""
		feel_label.text = UiFonts.keep_all(game.holdout.feel_line())
		feel_label.visible = feel_label.text != "" and gp.visible
	sun_bar.value = game.clock.sun_fraction()
	radio_left -= delta
	radio_label.modulate.a = clampf(radio_left / 1.5, 0.0, 1.0)
	_tick_urgent()
	radio_pill.modulate.a = radio_label.modulate.a
	radio_pill.visible = radio_label.text != "" and radio_left > 0.0
	_place_squad()
	_tick_lever(delta)
	_tick_portrait(p)
	_tick_allies()
	_tick_take()
	_tick_bag_pause()
	if box_shown != "" and (not modal_open or not is_instance_valid(box_pane) or modal != box_pane):
		box_shown_now("")
	_tick_grab(p, delta)
	_tick_toasts(delta)
	_tick_says(delta)
	_follow_portrait()
	context_t -= delta
	if context_t <= 0.0:
		context_t = 0.4
		_rebuild_context(p)
		_bag_places_moved()
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
	if p.sled_weapon_stowed:
		auto_aim = false
		aiming = false
		aim_target = null
	for key: Button in [attack_button, aim_button, shove_button, manual_button]:
		if p.sled_weapon_stowed and (key != shove_button or p.grabbers.is_empty()):
			if not key.has_meta("sled_disabled"):
				key.set_meta("sled_disabled", key.disabled)
			key.disabled = true
		elif key.has_meta("sled_disabled"):
			key.disabled = bool(key.get_meta("sled_disabled"))
			key.remove_meta("sled_disabled")
	_tick_primary(p)
	blood_button.visible = leaving.is_empty() and p.body.bleed > 0 and (p.items.has("bandage") or p.items.has("medkit"))
	lamp_button.visible = leaving.is_empty() and game.clock.is_dark()
	lamp_button.button_pressed = game.lamps_on()
	if lamp_button.visible and not lamp_hint_done:
		lamp_hint_done = true
		toast("해 짐")
		_beckon(lamp_button)
	# The first time it shows, a word and the key lighting up point at it
	# (build 47: it was never found; 결정 417: no how-to line).
	if blood_button.visible and not bleed_hint_done:
		bleed_hint_done = true
		toast("출혈")
		_beckon(blood_button)
	_tick_status(p)
	_place_messages()
	# The sleeping pause key keeps its play face while the bag is up, even
	# while taking advances the field (decision 532).
	var shows_play: bool = game.paused or _bag_up()
	if pause_shows_play != shows_play:
		pause_shows_play = shows_play
		_set_icon(pause_button, "play" if shows_play else "pause", PAUSE_ICON)
	settings_button.visible = game.paused and not modal_open and leaving.is_empty()
	var keys_right: float = STATUS_AT.x - (SETTINGS_KEY + 8.0 if settings_button.visible else 0.0)
	if test_keys.offset_right != keys_right:
		test_keys.offset_left = keys_right
		test_keys.offset_right = keys_right
	# The fold keys a step left of the view keys, on the same row.
	var fold: Vector2 = fold_keys.get_combined_minimum_size()
	fold_keys.size = fold
	fold_keys.position = Vector2(_view_size().x + keys_right - test_keys.get_combined_minimum_size().x - 8.0 - fold.x, 14.0)
	if debug_panel.visible and fps_t <= 0.0:
		fps_t = 0.25
		_tick_debug()
	overlay.queue_redraw()
	touch.queue_redraw()


## The promises the stop goes with: what the train sent (opts promises: [{kind,
## state}]), or else the departure's own (opts departure, S3 출발 명세).
func game_promises() -> Array:
	var sent = game.opts.get("promises", null)
	if sent is Array:
		return sent
	var dep = game.opts.get("departure", null)
	return (dep.get("promises", []) as Array) if dep is Dictionary else []


## Show `promises` on the promise line; none takes the line and its key away.
func set_promises(promises: Array) -> void:
	promise_text = ReceiptCard.promise_line(promises)
	promise_label.text = UiFonts.keep_all(promise_text)
	_show_promise()


## Let the promise line down under its key, or take it up.
func set_promise_open(open: bool) -> void:
	promise_open = open
	_show_promise()


func _toggle_promise() -> void:
	set_promise_open(not promise_open)


func _show_promise() -> void:
	var any: bool = promise_text != ""
	promise_key.visible = any
	promise_key.set_pressed_no_signal(promise_open)
	promise_label.get_parent().visible = any and promise_open


## Let the goal line down under its key, or take it up.
func set_goal_open(open: bool) -> void:
	goal_open = open
	goal_key.set_pressed_no_signal(open)
	if goal_label != null:
		var gp: Control = goal_label.get_parent()
		gp.visible = open and goal_label.text != ""
		feel_label.visible = feel_label.text != "" and gp.visible


func _toggle_goal() -> void:
	set_goal_open(not goal_open)


## The line under the clock (decision 293 ②): the stop's goals only once the
## technology opens them (opts goal_line; till then they are in the bag
## panel's journal). A held train's clock, doors and risk show all the same:
## they are the stop's state, not goals.
func goal_shown() -> String:
	if bool(game.opts.get("goal_line", false)):
		return game.goal_text()
	var h = game.holdout
	if h.enabled() and (h.opened or h.mode == "roll" or not game.mission_play.active()):
		return h.goal_line()
	return ""


## The clock line: the time, which day, then the weather and the cold.
func _tick_clock() -> void:
	var m: int = maxi(int(floor(game.clock.game_minutes())), 0)
	var in_day: int = m % 1440
	clock_label.text = "%02d:%02d" % [in_day / 60, in_day % 60]
	day_label.text = "· %d일째" % (1 + m / 1440)
	weather_label.text = "· %s · −14℃" % game.weather.label()


## From dusk (14:50, when the light starts to go) the radio and 'all aboard'
## burn amber (시안 2차 11절); before it they are glass.
func _tick_urgent() -> void:
	var now: bool = game.clock.dusk_share() > 0.0 or game.clock.is_dark()
	if now == urgent:
		return
	urgent = now
	radio_pill.add_theme_stylebox_override("panel", radio_styles[1 if urgent else 0])
	radio_label.add_theme_color_override("font_color", HudSkin.URGENT if urgent else INK)
	lever_button.queue_redraw()
	var st: Dictionary = all_aboard_styles[1 if urgent else 0]
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		all_aboard_button.add_theme_stylebox_override(k, st[k])
	all_aboard_button.add_theme_font_override("font", UiFonts.face(UiFonts.WORD, 600 if urgent else 500, 0.78))
	_center_pill(all_aboard_button)
	var ink: Color = HudSkin.LAMP_INK if urgent else HudSkin.INK
	for k in ["font_color", "font_hover_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_focus_color"]:
		all_aboard_button.add_theme_color_override(k, ink)


## The attack pad is A whatever is in hand (user 2026-10-18). With 'one main
## action' the aim pad stands in for it: A while a blade, a club or bare hands
## are out, the aim mark over 조준 with a gun.
func _tick_attack_icon(p) -> void:
	var want: String = "gun" if W.is_ranged(p.weapon_id()) else ""
	if want == attack_icon:
		return
	attack_icon = want
	if bool(game.opts.get("primary_one", false)):
		_set_icon(aim_button, "aim" if want == "gun" else "", 48)


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
	if (status_rows.size() >= STATUS_SMALL_FROM) != status_small:
		status_small = not status_small
		_place_status()
	for i in status_pads.size():
		var pad: Button = status_pads[i]
		pad.visible = i < status_rows.size()
		if pad.visible:
			var row: Dictionary = status_rows[i]
			var art: Texture2D = StatusArt.texture(String(row["id"]), bool(row["severe"]), bool(row.get("faint", false)), STATUS_ART_SIZE)
			pad.icon = art
			# No picture for it yet: its short name, so nothing goes unseen.
			pad.text = "" if art != null else String(row["short"])


## How wide a state icon is: 72, or 64 or 80 from the settings.
func status_diameter() -> int:
	var d: int = int(game.opts.get("status_size", STATUS_SIZES[0]))
	return d if STATUS_SIZES.has(d) else STATUS_SIZES[0]


## How wide the state icons are drawn now: status_diameter(), or STATUS_SMALL
## of it while four or more show.
func status_shown_diameter() -> float:
	var d: float = status_diameter()
	return roundf(d * STATUS_SMALL) if status_small else d


## The state icons down the right edge in one column, most urgent at the top,
## smaller while four or more show.
func _place_status() -> void:
	var d: float = status_shown_diameter()
	for i in status_pads.size():
		var pad: Button = status_pads[i]
		# Offsets from the top right corner the pad is anchored to.
		var at: Vector2 = STATUS_AT + Vector2(-d, i * (d + STATUS_GAP))
		pad.custom_minimum_size = Vector2(d, d)
		pad.offset_left = at.x
		pad.offset_top = at.y
		pad.offset_right = at.x + d
		pad.offset_bottom = at.y + d


## What a state icon says when pressed: the noun phrase, good or bad, and what it does.
func status_line(row: Dictionary) -> String:
	return "%s (%s): %s." % [row["title"], "좋음" if row["good"] else "나쁨", row["text"]]


func _tick_portrait(p) -> void:
	# The face carries the body: the most urgent look, frost on its rim while
	# cold (s2_station 2.7 '추움' tier; decision 293 ①).
	face.show_body(p)
	var lv: int = game.level_of(p.position)
	name_label.text = "%d층" % (lv + 1) if lv > 0 else ("지하" if lv < 0 else "")
	name_label.get_parent().visible = name_label.text != ""
	status_label.get_parent().visible = p.blood_soaked
	tag_box.visible = name_label.text != "" or p.blood_soaked
	# The weapon in hand and, once it wears, its state in its own colour (시안
	# 「손도끼 (양호)」; a sound one says nothing, 결정 417). The one at the hip
	# is in the bag's two hands.
	var h: Dictionary = p.weapon()
	var wid: String = String(h.get("id", ""))
	var cond := ""
	var cond_ink: Color = HudSkin.GOOD
	var extra := ""
	var text := "맨손"
	if wid != "":
		var d: Dictionary = W.get_data(wid)
		text = String(d.get("name", wid))
		var level: int = W.condition_level(float(h["condition"]))
		cond = W.CONDITION_NAMES[level] if level > 0 else ""
		cond_ink = [HudSkin.GOOD, HudSkin.HEED, HudSkin.BAD][level]
		if bool(h.get("broken", false)):
			cond = "망가짐"
			cond_ink = HudSkin.BAD
		elif W.is_ranged(wid):
			extra = "%d/%d · %d" % [int(h["loaded"]), int(d["mag"]), int(game.ammo.get(d["ammo"], 0))]
			if p.jam_t > 0.0:
				extra += " · 걸림"
			elif p.reload_t > 0.0:
				extra += " · 장전"
	weapon_label.text = text
	cond_label.text = cond
	cond_label.visible = cond != ""
	cond_label.add_theme_color_override("font_color", cond_ink)
	ammo_label.text = extra
	ammo_label.visible = extra != ""
	_tick_attack_icon(p)
	# 인벤토리 carries the weight: amber past half, the bad colour once it spills.
	var state: int = p.carry_state()
	bag_button.text = "%.1f/%.0f" % [p.weight(), p.carry_limit()]
	bag_button.tooltip_text = "인벤토리 · %s · %s" % [Carry.BAGS[p.bag]["name"], Carry.STATE_NAMES[state]]
	var heavy: Color = [HudSkin.INK, HudSkin.HEED, HudSkin.BAD, HudSkin.BAD][clampi(state, 0, 3)]
	for k in ["font_color", "font_hover_color", "font_focus_color"]:
		bag_button.add_theme_color_override(k, heavy)
	var ringing: bool = game.alarm_set()
	if alarm_button != null and ringing != alarm_button.visible:
		alarm_button.visible = ringing
		if ringing:
			_beckon(alarm_button)


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


## The faces at the foot of the screen, the middle one's under the screen's
## middle (user 2026-10-18: 「가장 가운데 동료가 화면 정중앙 하단 중앙」), the
## work crew's chip right beside them, and an open card over its face, kept
## between the stick's ring and the right thumb's pads.
func _place_allies() -> void:
	var view: Vector2 = _view_size()
	var one: bool = bool(game.opts.get("primary_one", false))
	var right: float = view.x + AIM_AT.x - (0.0 if one else MANUAL_SIZE.x + 8.0) - 16.0
	var left: float = stick_home().x + STICK_RING + UiFonts.px(SQUAD_GAP)
	var n: int = ally_buttons.size()
	var row_w: float = n * CHIP_TOKEN + maxi(n - 1, 0) * CHIP_GAP
	var x0: float = roundf(view.x * 0.5 - row_w * 0.5)
	var y: float = view.y - ALLIES_UP
	allies_box.position = Vector2(x0, y)
	allies_box.size = Vector2(row_w, CHIP_TOKEN)
	if crew_button.visible:
		var crew: Vector2 = crew_button.get_combined_minimum_size()
		crew_button.size = crew
		crew_button.position = Vector2(x0 + row_w + CHIP_GAP, y + roundf((CHIP_TOKEN - crew.y) * 0.5))
	if card_row >= 0 and card_row < n:
		var card: Button = ally_buttons[card_row]["card"]
		var mid: float = x0 + card_row * (CHIP_TOKEN + CHIP_GAP) + CHIP_TOKEN * 0.5
		var x: float = clampf(mid - card.size.x * 0.5, left, maxf(right - card.size.x, left))
		card.position = Vector2(roundf(x), roundf(y - UiFonts.px(CARD_GAP) - card.size.y))


## The lever at the top middle of the screen and the squad's orders under its
## tab ('all aboard', then 따라와 and 대기), where they are whether shown or
## folded, so nothing moves under a thumb; on a narrow screen never over the
## clock's glass.
func _place_squad() -> void:
	var gap: float = UiFonts.px(SQUAD_GAP)
	var mid: float = roundf(_view_size().x * 0.5)
	lever_button.position = Vector2(mid - roundf(LEVER_TOUCH.x * 0.5), 0.0)
	var glass: Vector2 = clock_pill.size.max(clock_pill.get_combined_minimum_size())
	var x: float = maxf(mid - roundf(all_aboard_size.x * 0.5), roundf(top_panel.position.x + glass.x + gap))
	var y: float = LEVER_TOUCH.y + 2.0
	all_aboard_button.position = Vector2(x, y)
	follow_button.position = Vector2(x, y + all_aboard_size.y)
	wait_button.position = Vector2(x + all_aboard_size.x - order_size.x, y + all_aboard_size.y)


## Open (or fold) the squad's orders under the lever; the knob and their fade
## follow in tick.
func set_orders_open(open: bool) -> void:
	orders_open = open
	var shown: bool = lever_button.visible and open
	for b: Button in [all_aboard_button, follow_button, wait_button]:
		b.visible = shown


## The knob and the orders' fade follow orders_open over LEVER_S.
func _tick_lever(delta: float) -> void:
	var to: float = 1.0 if orders_open else 0.0
	if lever_t == to:
		return
	lever_t = move_toward(lever_t, to, delta / LEVER_S)
	lever_button.queue_redraw()
	for b: Button in [all_aboard_button, follow_button, wait_button]:
		b.modulate.a = lever_t


## The lever's tab: glass hanging from the top edge (amber from dusk, as 'all
## aboard' burns), a slot down its middle and a brass knob in it, up while the
## orders are folded and down while they show. No word on it (decision 293).
func _draw_lever() -> void:
	var tab := Rect2(Vector2(roundf((LEVER_TOUCH.x - LEVER_SEEN.x) * 0.5), 0.0), LEVER_SEEN)
	lever_button.draw_style_box(lever_styles[1 if urgent else 0], tab)
	var slot := Rect2(tab.get_center() - Vector2(3.0, 11.0), Vector2(6.0, 22.0))
	lever_button.draw_style_box(lever_slot, slot)
	var knob := Vector2(slot.get_center().x, lerpf(slot.position.y + 3.0, slot.end.y - 3.0, lever_t))
	lever_button.draw_circle(knob, 7.0, HudSkin.BRASS3)
	lever_button.draw_circle(knob, 5.5, HudSkin.BRASS2)
	lever_button.draw_circle(knob + Vector2(-1.5, -1.5), 2.2, HudSkin.BRASS1)


## One of the squad's two orders under 'all aboard': its word alone in the
## middle of a matte glass pill (시안 .fcmd's buttons).
func _order_pad(c: Array, font: Font) -> Button:
	var b := _pad(command_word(c), Vector2.ZERO, order_size, UiFonts.size(13.0), Control.PRESET_TOP_LEFT)
	_dress(b, "", Vector2(order_size.x, roundf(UiFonts.px(ORDER_SEEN))), false)
	_matte(b)
	b.add_theme_font_override("font", font)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = "모두 " + command_word(c)
	return b


## Plain glass with a plain ring: no brass sweep under the glass nor round the
## rim (user 2026-10-18: 「따라와 대기 에 유광효과가 관측된다」).
func _matte(b: Button) -> void:
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var plate = b.get_theme_stylebox(k)
		plate.brass_rim = false


## The message column's left and right edges: right of the squad's orders
## (shown or folded, so nothing moves as they open), a gap left of the state
## icons at their full size even while none shows or they are small (so it
## does not jump as they come and shrink).
func _message_span() -> Vector2:
	var gap: float = UiFonts.px(MESSAGE_GAP)
	var right: float = _view_size().x + STATUS_AT.x - status_diameter() - gap
	return Vector2(all_aboard_button.position.x + all_aboard_size.x + gap, right)


## How wide a note may be with its paper: TOAST_W, or the column's room.
func _note_room() -> float:
	var span: Vector2 = _message_span()
	return minf(TOAST_W, maxf(span.y - span.x, 0.0))


## The message column (user 2026-10-18), from the state icons' top: the stop's
## own lines, then the radio's call, then the notes, each right-aligned on the
## column's right edge. A note that would reach down onto the right thumb's
## pads under the column takes the oldest plain note's place.
func _place_messages() -> void:
	var gap: float = UiFonts.px(MESSAGE_GAP)
	var span: Vector2 = _message_span()
	var top: float = STATUS_AT.y
	var lines := false
	for l: Label in [goal_label, promise_label, feel_label]:
		_cap_line(l, span.y - span.x)
	for c: Control in info_box.get_children():
		lines = lines or c.visible
	if lines:
		var ib: Vector2 = info_box.size.max(info_box.get_combined_minimum_size())
		info_box.position = Vector2(roundf(span.y - ib.x), top)
		top += ib.y + gap
	if radio_pill.visible:
		if absf(span.y - span.x - radio_room) > 0.5:
			radio_room = span.y - span.x
			_fit_radio()
		var rs: Vector2 = radio_pill.size.max(radio_pill.get_combined_minimum_size())
		radio_pill.position = Vector2(roundf(span.y - rs.x), top)
		top += rs.y + gap
	var box: Vector2 = toast_box.size.max(toast_box.get_combined_minimum_size())
	toast_box.position = Vector2(roundf(span.y - box.x), roundf(top))
	var floor_y: float = _view_size().y
	for b: Button in pads:
		if b.is_visible_in_tree() and not status_pads.has(b):
			var r: Rect2 = b.get_global_rect()
			if r.position.y > top and r.end.x > span.x and r.position.x < span.y:
				floor_y = minf(floor_y, r.position.y)
	if top + toast_box.get_combined_minimum_size().y > floor_y - gap:
		for t in toasts:
			if t["kind"] == TOAST_NORMAL:
				_toast_drop(t)
				break


func _tick_allies() -> void:
	for row in ally_buttons:
		var p = row["p"]
		var b: Button = row["b"]
		var cmd := ""
		for c in COMMANDS:
			if c[0] == p.command:
				cmd = command_word(c)
		# The face shows the body (decision 293 ①); the words say only what a face
		# cannot: held, down, dead, back on the train, or busy with something.
		var doing := ""
		if not p.grabbers.is_empty():
			doing = "잡힘!"
		elif not p.is_alive():
			doing = "죽음"
		elif p.body.downed:
			doing = "쓰러짐"
		elif p.brain.get("boarded", false):
			doing = "열차에"
		elif p.action != "":
			doing = p.action_label
		var note: String = doing if doing == "죽음" else (cmd if doing == "" else "%s · %s" % [cmd, doing])
		var arm: String = short_weapon(p)
		if row["name"].text != p.display_name or row["arm"].text != arm or row["note"].text != note:
			row["name"].text = p.display_name
			row["arm"].text = arm
			row["note"].text = note
			_fit_card(row)
		row["face"].show_body(p)
		b.tooltip_text = _ally_text(p, "%s · %s" % [cmd, p.body.status_words()])
		b.modulate = Color(1, 0.6, 0.55) if not p.grabbers.is_empty() or p.body.downed else (Color(0.6, 0.6, 0.6) if not p.is_alive() else Color.WHITE)
	lever_button.visible = not ally_buttons.is_empty()
	all_aboard_button.visible = lever_button.visible and orders_open
	follow_button.visible = all_aboard_button.visible
	wait_button.visible = all_aboard_button.visible
	crew_button.visible = game.actions.work_started
	if crew_button.visible:
		var alive := 0
		for c in game.crew:
			if c.is_alive():
				alive += 1
		var coal: bool = game.work.job(game.work.active_site)["yield"] == "coal"
		crew_button.text = "작업조 %d\n%s %.1f" % [alive, "석탄" if coal else "목재", game.actions.coal_delivered if coal else game.actions.wood_delivered]
		# The ration law's picture on the chip: the crew hauls less a trip (decision 430 ②).
		crew_button.icon = StatusArt.texture("ration", false, false, STATUS_ART_SIZE) if game.haul_mult() < 1.0 and coal else null
	_place_allies()


func _tick_grab(p, delta: float) -> void:
	var grabbed: bool = not p.grabbers.is_empty()
	grab_button.visible = grabbed
	grab_bar.visible = grabbed
	if grabbed:
		grab_bar.value = clampf(p.grab_left / maxf(grab_total, 0.01), 0.0, 1.0)


## Nothing is written across the screen for it: the shove key itself comes up
## and says where from (user 2026-10-12).
func grab_alert(front: bool) -> void:
	grab_total = maxf(game.player.grab_left, 0.01)
	grab_button.text = "밀쳐!" if front else "뒤에서! 밀쳐!"
	hurt_flash = HURT_FLASH_S


## What happens to someone is said over their own head, briefly, not written
## in the middle of the screen (user 2026-10-12). One line a person; a new
## one takes the old one's place. The chief stands in the middle, so what
## hurts him shows at the screen's edges and in the state icons instead, and
## his plain notes stay notes.
func say(p, text: String, hurt: bool = false) -> void:
	if p == game.player:
		if hurt:
			hurt_flash = HURT_FLASH_S
		else:
			toast(text)
		return
	if not game.squad.has(p):
		toast(text)
		return
	var line: String = text
	for lead: String in [p.display_name + ": ", p.display_name + " "]:
		if line.begins_with(lead):
			line = line.substr(lead.length())
			break
	for s in says.duplicate():
		if s["p"] == p:
			says.erase(s)
	says.append({"p": p, "text": line, "t": SAY_S, "hurt": hurt, "line": ""})


## A companion shouts: the line goes over their head, above the note of what
## happened if one is up.
func shout(p, line: String) -> void:
	for s in says:
		if s["p"] == p:
			s["line"] = line
			s["t"] = maxf(float(s["t"]), LINE_S)
			return
	says.append({"p": p, "text": "", "t": LINE_S, "hurt": false, "line": line})


func _tick_says(delta: float) -> void:
	hurt_flash = maxf(hurt_flash - delta, 0.0)
	for s in says.duplicate():
		s["t"] -= delta
		if s["t"] <= 0.0 or not is_instance_valid(s["p"]):
			says.erase(s)


func _draw_says(view_size: Vector2) -> void:
	if hurt_flash > 0.0:
		var a: float = 0.45 * hurt_flash / HURT_FLASH_S
		var edge := Color(AMBER.r, AMBER.g, AMBER.b, a)
		overlay.draw_rect(Rect2(Vector2.ZERO, Vector2(14, view_size.y)), edge)
		overlay.draw_rect(Rect2(Vector2(view_size.x - 14, 0), Vector2(14, view_size.y)), edge)
	var font: Font = UiFonts.face(UiFonts.WORD, 600, 0.48)   # 시안 .fsay: Plex semibold
	var taken: Array = []   # people standing together: the slips go one above another
	var pad := Vector2(10, 4)
	for s in says:
		var at: Vector2 = _project(s["p"].position + Vector3(0, 2.3, 0))
		var a: float = clampf(float(s["t"]) / 0.6, 0.0, 1.0)
		# Rows, top to bottom: the shouted line, then what happened (small when under a line).
		# Ink on a paper slip, a little askew (시안 .fsay); a wound in rust ink.
		var rows: Array = []
		if String(s["line"]) != "":
			rows.append([String(s["line"]), LINE_FONT, HudSkin.PAPER_INK])
		if String(s["text"]) != "":
			rows.append([String(s["text"]), SAY_UNDER_FONT if not rows.is_empty() else SAY_FONT, SAY_HURT_INK if s["hurt"] else HudSkin.PAPER_INK])
		var size := Vector2.ZERO
		for row in rows:
			size.x = maxf(size.x, font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, row[1]).x)
			size.y += float(row[1]) + 4.0
		var box := Rect2(at - Vector2(size.x * 0.5 + pad.x, size.y + pad.y * 2.0), size + pad * 2.0)
		var again := true
		while again:
			again = false
			for r: Rect2 in taken:
				if r.intersects(box):
					box.position.y = r.position.y - box.size.y - 2.0
					again = true
		taken.append(box)
		var mid: Vector2 = box.get_center()
		overlay.draw_set_transform(mid, deg_to_rad(-2.0), Vector2.ONE)
		var slip := Rect2(-box.size * 0.5, box.size)
		overlay.draw_rect(Rect2(slip.position + Vector2(1, 2), slip.size), Color(0, 0, 0, 0.45 * a))
		HudSkin.draw_paper(overlay, slip, a)
		var y: float = slip.position.y + pad.y
		for row in rows:
			y += float(row[1])
			var w: float = font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, row[1]).x
			var ink: Color = row[2]
			overlay.draw_string(font, Vector2(-w * 0.5, y - 3.0), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, row[1], Color(ink.r, ink.g, ink.b, a))
			y += 4.0
		overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	debug_label.text = "FPS %d · 프레임 %.1fms · 상한 %d\n좀비 화면 %d · 살아 있음 %d / 동시 상한 %d · 대기 %d\n%s · 다음 무리 %s초 (%s)\n부르는 범위 ×%.2f · 무리 %d · 시계 ×%.0f · 필드 %d초\n선로 위 망자 서 %d · 동 %d · %s" % [
		Engine.get_frames_per_second(), frame_ms, Engine.max_fps,
		game.zombies.drawn_count, alive, game.cap, game.waiting,
		noise_line(), "-" if is_inf(next) else str(roundi(next)), game.director.name_of(game.director.next_entry),
		game.director.call_range_mult(now), game.hordes.size(), game.clock.speed, roundi(now),
		track["west"], track["east"], "시야 가림 켬" if game.mask_on else "시야 가림 끔",
	]


## The sound the people made, next to how much of it still counts as a quiet
## stop (field_holdout). What the dead added by banging on doors is not in it:
## that total is kept in the record only. The words are a first wording.
func noise_line() -> String:
	return "사람이 낸 소리 %d (조용함은 %d까지)" % [game.holdout.people_noise(), FieldHoldout.QUIET_NOISE]


## The situation pad shows the nearest thing to do; a tap does it, a hold
## lays out the rest (open, pick up, door, stairs, bandage, depart...).
func _rebuild_context(p) -> void:
	context_rows = [] if game.ended else game.actions.context(p)
	depart_button.visible = not game.ended and game.actions.on_platform(p)
	# It rises only when there is something to do; otherwise the spot is empty.
	context_button.visible = not context_rows.is_empty()
	if context_rows.is_empty():
		return
	# The nearest thing's mark alone; its words go to the hold's list (and to a
	# screen reader), and how many more there are to the badge on the rim.
	var more: int = context_rows.size() - 1
	var first: String = String(context_rows[0]["label"])
	context_button.tooltip_text = first
	context_button.modulate = Color.WHITE if context_rows[0].get("work_ready", true) else Color(0.5, 0.5, 0.5)
	var count: String = "+%d" % more if more > 0 else ""
	if context_more.text != count:
		context_more.text = count
		context_badge.visible = more > 0
		context_badge.reset_size()
		# Its middle on the disc's rim, up and to the right (the disc is 84
		# across in the middle of the pad).
		var rim: Vector2 = context_button.size * 0.5 + Vector2(1, -1) * 42.0 * 0.7071
		context_badge.position = (rim - context_badge.size * 0.5).round()
	var icon: String = HudIcons.context_icon(first)
	if icon != context_icon:
		context_icon = icon
		_set_icon(context_button, icon, LONE_ICON)


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

## A note in the column left of the state icons. Normal ones fade in 3.5 s;
## a warn one stays 6 s, is amber (never red) and goes away when tapped. One
## warn at a time, and a normal note never pushes a warn out. Cries in the
## scene ("잡혔다!") stay normal.
func toast(text: String, kind: String = TOAST_NORMAL) -> void:
	if toast_box == null:
		return
	if kind == TOAST_WARN:
		_toast_warn(text)
		return
	# A paper slip with its fibre, a little askew (시안 .ftoast, Plex 12); a long
	# note wraps, between words only.
	var l := _label(UiFonts.keep_all(text), UiFonts.size(12), HudSkin.PAPER_INK)
	l.add_theme_stylebox_override("normal", HudSkin.slip(UiFonts.px(10), 5.0))
	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# Right-aligned in the column, askew about its right end so that end
	# keeps to the column's edge.
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	var room: float = _note_room()
	var paper: StyleBox = l.get_theme_stylebox("normal")
	if theme.default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.size(12)).x > room - paper.get_margin(SIDE_LEFT) - paper.get_margin(SIDE_RIGHT):
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = room
	l.rotation = deg_to_rad(-1.2 if toasts.size() % 2 == 0 else 0.8)
	l.resized.connect(func() -> void: l.pivot_offset = Vector2(l.size.x, 0.0))
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
	b.text = UiFonts.keep_all(text)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(minf(480.0, _note_room()), 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.08, 0.9)
	sb.border_color = AMBER
	sb.set_border_width_all(1)
	sb.border_width_left = 4
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, sb)
	toast_box.add_child(b)
	var entry := {"l": b, "t": TOAST_WARN_S, "kind": TOAST_WARN}
	toasts.append(entry)
	b.pressed.connect(_toast_drop.bind(entry))


## Drop only the warning with these words, leaving other notes alone.
func drop_warning(text: String) -> void:
	for t: Dictionary in toasts.duplicate():
		if t["kind"] != TOAST_WARN or not is_instance_valid(t["l"]):
			continue
		var button := t["l"] as Button
		if button != null and button.text == UiFonts.keep_all(text):
			_toast_drop(t)


func _toast_drop(entry: Dictionary) -> void:
	if is_instance_valid(entry["l"]):
		# Out of the column at once, so the ones left close up this frame.
		if entry["l"].get_parent() != null:
			entry["l"].get_parent().remove_child(entry["l"])
		entry["l"].queue_free()
	toasts.erase(entry)
	toast_box.reset_size()


func radio(text: String) -> void:
	if radio_label == null:
		return
	# The crackle is drawn before every call, so a call that is only crackle
	# (the set hisses before it speaks) shows the crackle alone, and one that
	# could not be made out keeps only its own words after it.
	var words: String = text
	if text.begins_with(HISS_TEXT):
		words = text.substr(HISS_TEXT.length()).lstrip("… ")
	# A long call wraps between words only, like the goal and feel lines.
	radio_label.text = UiFonts.keep_all(words) if words != "" else text
	radio_label.visible = words != ""
	_fit_radio()
	radio_left = 8.0


## A call no wider than the message column leaves it (RADIO_W at most): a
## longer one wraps onto more lines rather than reach over the squad's orders.
func _fit_radio() -> void:
	radio_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	radio_label.custom_minimum_size.x = 0.0
	if radio_label.visible:
		var font: Font = radio_label.get_theme_font("font")
		var words: float = font.get_string_size(radio_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, radio_label.get_theme_font_size("font_size")).x
		var chrome: float = radio_pill.get_combined_minimum_size().x - radio_label.get_combined_minimum_size().x
		var room: float = RADIO_W if radio_room < 0.0 else clampf(radio_room - chrome, UiFonts.px(80.0), RADIO_W)
		if words > room:
			radio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			radio_label.custom_minimum_size.x = room
	radio_pill.reset_size()


## A short row of choices in the middle (break a window, how to climb...).
## Wrap fixed-size choices before the right pads, then lift the whole group above the faces.
static func offer_rects(sizes: Array[Vector2], view: Vector2, right_limit: float, bottom_limit: float) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var start: Vector2 = view * 0.5 + Vector2(-260, 90)
	var cursor: Vector2 = start
	var row_height: float = 0.0
	var bottom: float = start.y
	for key_size: Vector2 in sizes:
		if cursor.x > start.x and cursor.x + key_size.x > minf(view.x, right_limit):
			cursor.x = start.x
			cursor.y += row_height + 12.0
			row_height = 0.0
		rects.append(Rect2(cursor, key_size))
		bottom = maxf(bottom, cursor.y + key_size.y)
		row_height = maxf(row_height, key_size.y)
		cursor.x += key_size.x + 12.0
	var lift: float = maxf(0.0, bottom - minf(view.y, bottom_limit))
	for index: int in rects.size():
		rects[index].position.y -= lift
	return rects


## Keep 24 px before the departure touch pad unless even one fixed-size choice cannot fit.
static func offer_gap(sizes: Array[Vector2], view: Vector2, depart_left: float) -> float:
	var widest: float = 0.0
	for key_size: Vector2 in sizes:
		widest = maxf(widest, key_size.x)
	return 24.0 if view.x * 0.5 - 260.0 + widest <= depart_left - 24.0 else 12.0


func _layout_offer() -> void:
	if offer_box.get_child_count() == 0:
		return
	_place_allies()
	var sizes: Array[Vector2] = []
	for key: Control in offer_box.get_children():
		sizes.append(key.custom_minimum_size)
	var origin: Vector2 = offer_box.global_position
	var depart_left: float = depart_button.get_global_rect().position.x - origin.x
	var right_limit: float = depart_left - offer_gap(sizes, _view_size(), depart_left)
	var bottom_limit: float = allies_box.get_global_rect().position.y - origin.y - 12.0
	var rects: Array[Rect2] = offer_rects(sizes, _view_size(), right_limit, bottom_limit)
	for index: int in rects.size():
		var key: Control = offer_box.get_child(index)
		key.position = rects[index].position
		key.size = rects[index].size


func offer(list: Array) -> void:
	for c in offer_box.get_children():
		offer_box.remove_child(c)
		c.queue_free()
	for row in list:
		var key: Button = _offer_key(row["label"], _offer_pick.bind(row["call"]), Vector2(180, 72))
		key.modulate = Color.WHITE if row.get("work_ready", true) else Color(0.5, 0.5, 0.5)
		offer_box.add_child(key)
	offer_box.add_child(_offer_key("그만", _offer_pick.bind(Callable()), Vector2(100, 72), true))
	_layout_offer()


## A choice offered on the field: a glass pill of the field's (시안 .fglass) in
## its touch rect, its word at 15/500; 그만 in side ink.
func _offer_key(word: String, cb: Callable, at_least: Vector2, quiet: bool = false) -> Button:
	var b := _button(word, cb, at_least)
	UiFonts.style(b, UiFonts.WORD, 500, 15.0, HudSkin.INK2 if quiet else HudSkin.INK, 0.6)
	var rest: StyleBoxFlat = HudSkin.glass(UiFonts.px(14.0), 0.0)
	var down: StyleBoxFlat = HudSkin.glass(UiFonts.px(14.0), 0.0, 0.8)
	down.content_margin_top = UiFonts.px(HudSkin.PRESS_SINK)
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, rest)
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, down)
	return b


func _offer_pick(cb: Callable) -> void:
	for c in offer_box.get_children():
		offer_box.remove_child(c)
		c.queue_free()
	if cb.is_valid():
		cb.call()


# ---------------------------------------------------------------- modal panels

## The settings that can be changed in the middle of a stop: the stick, how
## much the driver calls and how big the state icons are, a named cell each
## (시안 13 메뉴판's 손맛 row); the values say what each is set to, with no
## line under them (결정 417). Opened from the pause screen; a press goes round
## that setting's values.
func settings_panel() -> void:
	var pane := _open_pane("설정", "", "gear")
	var cells := GlassPane.row()
	cells.add_child(GlassPane.cell("스틱", "따라오기" if stick_floats() else "고정", _set_stick))
	cells.add_child(GlassPane.cell("무전", String(game.RADIO_NAMES[game.radio_mode()]), _set_radio))
	cells.add_child(GlassPane.cell("상태 아이콘", String(STATUS_SIZE_NAMES[status_diameter()]), _set_status_size))
	pane.body.add_child(cells)
	pane.body.add_child(SoundRows.make())   # 전체·음악·효과·목소리 (결정 448)
	pane.body.add_child(ScreenLift.make(game))   # 밝기 (결정 471 B5)


func _set_status_size() -> void:
	game.opts["status_size"] = STATUS_SIZES[(STATUS_SIZES.find(status_diameter()) + 1) % STATUS_SIZES.size()]
	_place_status()
	settings_panel()


func _set_stick() -> void:
	game.opts["stick_float"] = not stick_floats()
	settings_panel()


func _set_radio() -> void:
	var modes: Array = game.RADIO_MODES
	game.opts["radio"] = modes[(modes.find(game.radio_mode()) + 1) % modes.size()]
	settings_panel()


## The shade over the playing screen while a panel is up (시안 .mscrim), the
## panel laid on it by the caller. pauses false: the field goes on at
## BODY_SLOW under it (the body picture).
func _open_shade(pauses: bool = true) -> Control:
	_close_modal(false)
	_discard_closing_modal()
	# Decision 532: opening the bag releases every field finger too.
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
	modal.name = "Modal"
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Shade"
	dim.color = GlassPane.SCRIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(dim)
	root.add_child(modal)
	return modal


## A glass pane (glass_pane.gd) at the left under the band, `width_css` wide in
## the mockup's px; its 접기 closes it. A pane laid over one already up (a
## setting changed, a row taken) stands where it is rather than coming in again.
## The inventory comes in by its width from the right (decision 532).
func _open_pane(title: String, side: String = "", icon: String = "", width_css: float = PANE_W, pauses: bool = true, right_edge: bool = false) -> GlassPane:
	var again: bool = modal != null
	var shade: Control = _open_shade(pauses)
	var pane: GlassPane = GlassPane.new(width_css, title, side, icon)
	modal_pane = pane
	_capture_modal_back()
	pane.folded.connect(_close_modal)
	shade.add_child(pane)
	var dim: ColorRect = shade.get_node("Shade") as ColorRect
	if right_edge:
		# Decision 532: the shade stays behind the pane; the visible HUD sleeps.
		dim.anchor_left = 1.0
		dim.offset_left = -UiFonts.px(width_css)
	pane.pin(not again, Vector2.RIGHT if right_edge else Vector2.LEFT, dim)
	return pane


## pauses false: the field goes on at BODY_SLOW under the panel (the body picture).
func _open_modal(width: float = 640.0, pauses: bool = true) -> VBoxContainer:
	_close_modal(false)
	_discard_closing_modal()
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


func _close_modal(animate: bool = true) -> void:
	if game.resume_pending:
		return
	# A thing still coming out goes on in the field (field_actions.gd take).
	taking_box = ""
	_wake_under_bag()
	if modal != null:
		var old: Control = modal
		var pane: GlassPane = modal_pane
		modal = null
		modal_pane = null
		if modal_open and not modal_slows:
			game.paused = modal_paused_before or game.away
		game.slow = 1.0
		modal_slows = false
		modal_open = false
		_restore_modal_back.call_deferred()
		# The remaining picture has no input ownership. Existing touches must
		# still finish here; fresh touches already belong to the field.
		for index: int in modal_fingers:
			if modal_fingers[index].get("owner") == old:
				modal_fingers[index]["owner"] = null
				finger_cancel(index)
		_mute_modal(old)
		_discard_closing_modal()
		if animate and is_instance_valid(pane):
			closing_modal = old
			var shade: ColorRect = old.get_node("Shade") as ColorRect
			pane.slide_out(pane.motion_direction, shade)
			pane.left.connect(func() -> void:
				if closing_modal == old:
					closing_modal = null
				old.queue_free())
		else:
			old.hide()
			old.queue_free()


func _mute_modal(node: Node) -> void:
	if node is Control:
		var control: Control = node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children():
		_mute_modal(child)


func _discard_closing_modal() -> void:
	if is_instance_valid(closing_modal):
		closing_modal.hide()
		closing_modal.queue_free()
	closing_modal = null


## Android back must reach the pane before the tree's default quit behavior.
func _capture_modal_back() -> void:
	if not modal_back_captured:
		modal_quit_on_back = get_tree().is_quit_on_go_back()
		modal_back_captured = true
	get_tree().set_quit_on_go_back(false)


func _restore_modal_back() -> void:
	if modal_back_captured and modal_pane == null:
		get_tree().set_quit_on_go_back(modal_quit_on_back)
		modal_back_captured = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and modal_open and modal_pane != null:
		_close_modal()
	elif what == NOTIFICATION_EXIT_TREE and modal_back_captured:
		get_tree().set_quit_on_go_back(modal_quit_on_back)


## Decision 532: all field controls, including the stick, RUN and lamp, sleep
## dimmed under the bag. Words and world overlays keep their normal opacity.
func dim_under_bag() -> void:
	_wake_under_bag()
	var awake: Array = [modal, closing_modal, overlay, pause_veil, map_stamp, toast_box, radio_pill]
	for c: Node in root.get_children():
		if c is CanvasItem and not awake.has(c):
			var item := c as CanvasItem
			bag_dimmed.append([item, item.modulate.a])
			item.modulate.a *= BAG_DIM


func _wake_under_bag() -> void:
	for pair: Array in bag_dimmed:
		if is_instance_valid(pair[0]):
			var item: CanvasItem = pair[0]
			item.modulate.a = float(pair[1])
	bag_dimmed = []


func show_resume() -> void:
	# Reuse the existing pause shade and button style, with only one action.
	resume_view_ready = false
	game.resume_pending = false
	var box: VBoxContainer = _open_modal(320.0)
	game.resume_pending = true
	resume_button = _button("이어서", _continue_resume)
	resume_button.disabled = true
	box.add_child(resume_button)


func tick_resume() -> void:
	if not resume_view_ready:
		# The paused field must already show the restored clock, wounds and orders.
		# These are read-only UI updates; action/input/timer updates stay stopped.
		_tick_clock()
		_tick_portrait(game.player)
		_tick_allies()
		_tick_status(game.player)
		_tick_grab(game.player, 0.0)
		grab_button.text = "밀쳐!" if game.player.grab_front else "뒤에서! 밀쳐!"
		if goal_label != null:
			goal_label.text = UiFonts.keep_all(goal_shown())
			var goal_parent: Control = goal_label.get_parent()
			goal_parent.visible = goal_open and goal_label.text != ""
			goal_key.visible = goal_label.text != ""
			feel_label.text = UiFonts.keep_all(game.holdout.feel_line())
			feel_label.visible = feel_label.text != "" and goal_parent.visible
		resume_view_ready = true
	if is_instance_valid(resume_button):
		resume_button.disabled = game.resume_wait_left > 0.0 or game.away


func _continue_resume() -> void:
	game.continue_resume()


func close_resume() -> void:
	game.resume_pending = false
	_close_modal()
	resume_button = null


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
	# On the glass of the panels, a little wider for the figure beside the list.
	var pane := _open_pane(String(o.display_name), o.body.status_words(), "bandage", BODY_PANE_W, false)
	body_shown = o
	var urgent: int = o.body.most_urgent()
	if part == "":
		part = String(o.body.wounds[urgent]["part"]) if urgent >= 0 else "torso"
	body_part = part
	var have: Dictionary = game.actions.care_tools(p, o)
	pane.body.add_child(GlassPane.mixed("붕대 %d · 술 %d · 판자 %d · 천 %d · 핀셋 %d · 바늘과 실 %d" % [int(have.get("bandage", 0)), int(have.get("bottle_spirit", 0)), int(have.get("plank", 0)) + int(have.get("wood", 0)), int(have.get("cloth", 0)), int(have.get("tweezers", 0)), int(have.get("needle_thread", 0))]))
	var near: bool = game.actions.in_care_reach(p, o)
	if not near:
		pane.body.add_child(GlassPane.mixed("가까이 가기", 12.0, 13.0, GlassPane.AMBER, GlassPane.AMBER))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", GlassPane.px(BODY_GAP))
	pane.body.add_child(h)
	h.add_child(_body_figure(o, part))
	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", GlassPane.px(GlassPane.GAP))
	h.add_child(right)
	var room: float = BODY_PANE_W - GlassPane.PAD_L - GlassPane.PAD_R - BODY_SIZE.x * BODY_SCALE / UiFonts.K - BODY_GAP
	right.add_child(UiFonts.label(Treatment.PART_NAMES[part], UiFonts.WORD, 600, 14.0, GlassPane.AMBER, 1.12))
	var rows: Array = body_rows(o, part)
	if rows.is_empty():
		right.add_child(GlassPane.note("다친 데 없음", room, GlassPane.INK3, 13.0))
	for w: Dictionary in rows:
		var first: bool = urgent >= 0 and is_same(w, o.body.wounds[urgent])
		var heavy: bool = float(w["blood"]) >= BodyState.HEAVY_BLOOD
		# The most urgent in amber, no word after it (결정 417).
		right.add_child(GlassPane.note(Treatment.wound_text(w), room, GlassPane.RED_L if heavy else (GlassPane.AMBER if first else GlassPane.INK), 13.0, 500))
		var full: Array = game.actions.care_plan(p, o, w, Treatment.FULL)
		right.add_child(GlassPane.note(Treatment.steps_text(full), room))
		var hb := GlassPane.row()
		right.add_child(hb)
		var aid := GlassPane.key("응급", _care.bind(o, w, Treatment.FIRST_AID))
		aid.disabled = not near or Treatment.runnable(game.actions.care_plan(p, o, w, Treatment.FIRST_AID)).is_empty()
		hb.add_child(aid)
		var all := GlassPane.key("정밀", _care.bind(o, w, Treatment.FULL))
		all.disabled = not near or Treatment.runnable(full).is_empty()
		hb.add_child(all)
		body_buttons.append({"wound": w, "aid": aid, "full": all})
	# Cutting the limb off (body_injury 2.2): under a limb whose bite or
	# scratch carries the window, what it takes or why not; a second press cuts.
	body_cut = {}
	if o.body.lost.has(part):
		right.add_child(GlassPane.note("잘렸다", room, GlassPane.INK3, 13.0))
	elif Amputation.LIMBS.has(part) and o.body.at_risk_on(part):
		var plan: Dictionary = Amputation.plan(p, o, part, have)
		right.add_child(GlassPane.note("자르기 · " + Amputation.plan_text(plan), room, GlassPane.INK if bool(plan["ok"]) else GlassPane.INK3, 13.0, 500))
		var also: Array = plan["also"]
		if not also.is_empty():
			right.add_child(GlassPane.note("%s도 물렸다. 그것도 잘라야 막는다" % "·".join(also.map(func(x): return Treatment.PART_NAMES[x])), room))
		var cut_row := GlassPane.row()
		right.add_child(cut_row)
		var cut := GlassPane.key("자르기", _cut.bind(o, part))
		cut.disabled = not near or not bool(plan["ok"])
		cut_row.add_child(cut)
		body_cut = {"part": part, "key": cut, "plan": plan}
	elif o.body.at_risk_on(part) and o.body.window_left > 0.0:
		# No cut reaches it (결정 441 (4)): why and how long, and no key.
		var bitten: bool = o.body.wounds.any(func(w): return w["part"] == part and w["kind"] == "bite" and bool(w.get("risk", false)))
		var when: String = ("열이 오르기까지 %s" if bitten else "감염인지는 %s 뒤에 안다") % o.body.window_words()
		right.add_child(GlassPane.note("자를 수 없다 · " + when, room, GlassPane.INK3, 13.0, 500))


## The wounds on a part, the most urgent first.
func body_rows(o, part: String) -> Array:
	var rows: Array = []
	for i in o.body.wounds.size():
		if o.body.wounds[i]["part"] == part:
			rows.append([o.body._order_key(i), -i, o.body.wounds[i]])
	rows.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
	return rows.map(func(r): return r[2])


## What the body picture shows of each part: {"fill", "rim", "rim_w",
## "cracked", "kinds", "festering"}. A part that bleeds is dark brown (no red,
## nothing gory); the chosen one wears brass, a festering one a sallow rim (the
## brass wins when both), a broken one a crack. A limb cut off is left all but
## empty, with its word.
func body_looks(o, chosen: String) -> Dictionary:
	var out: Dictionary = {}
	for part: String in BODY_LAYOUT:
		if o.body.lost.has(part):
			out[part] = {
				"fill": Color(0.2, 0.2, 0.2, 0.2), "rim": BRASS if part == chosen else Color(INK, 0.3),
				"rim_w": 4.0 if part == chosen else 1.5, "cracked": false, "kinds": ["잘림"], "festering": false,
			}
			continue
		var kinds: Array = []
		var blood := 0.0
		var festering := false
		var cracked := false
		for w: Dictionary in o.body.wounds:
			if w["part"] == part:
				blood += float(w["blood"])
				festering = festering or bool(w["festering"])
				cracked = cracked or String(w["kind"]) == "fracture"
				var k: String = Treatment.KIND_NAMES[w["kind"]]
				if not kinds.has(k):
					kinds.append(k)
		out[part] = {
			"fill": BLOOD_BROWN if blood > 0.0 else (Color(0.2, 0.2, 0.2, 0.95) if kinds.is_empty() else Color(0.3, 0.29, 0.26, 0.95)),
			"rim": BRASS if part == chosen else (FESTER_RIM if festering else Color(INK, 0.55)),
			"rim_w": 4.0 if part == chosen else (3.0 if festering else 1.5),
			"cracked": cracked, "kinds": kinds, "festering": festering,
		}
	return out


## One figure cut into six parts. Each part is a key as wide as BODY_LAYOUT
## says (it draws nothing itself); the picture is drawn under them.
func _body_figure(o, chosen: String) -> Control:
	var fig := Control.new()
	fig.custom_minimum_size = BODY_SIZE * BODY_SCALE
	body_parts = {}
	body_look = body_looks(o, chosen)
	fig.draw.connect(_draw_body.bind(fig, chosen))
	for part: String in BODY_LAYOUT:
		var r: Rect2 = BODY_LAYOUT[part]
		var b := _button("", body_panel.bind(o, part), r.size * BODY_SCALE, 16)
		b.position = r.position * BODY_SCALE
		b.size = r.size * BODY_SCALE
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		fig.add_child(b)
		body_parts[part] = b
	return fig


func _draw_body(fig: Control, chosen: String) -> void:
	# The chosen part last, so its brass is not drawn over by a neighbour.
	var order: Array = BODY_SHAPES.keys()
	if order.has(chosen):
		order.erase(chosen)
		order.append(chosen)
	for part: String in order:
		var look: Dictionary = body_look[part]
		var pts := PackedVector2Array()
		for v: Vector2 in BODY_SHAPES[part]:
			pts.append(v * BODY_SCALE)
		fig.draw_colored_polygon(pts, look["fill"])
		pts.append(pts[0])
		fig.draw_polyline(pts, look["rim"], float(look["rim_w"]), true)
		var r: Rect2 = Rect2(pts[0], Vector2.ZERO)
		for v in pts:
			r = r.expand(v)
		var c: Vector2 = r.get_center()
		if look["cracked"]:
			# A broken bone: a crack across the part, above its word.
			var half: float = minf(r.size.x, 40.0) * 0.3
			var at: Vector2 = c + Vector2(0, -22)
			fig.draw_polyline(PackedVector2Array([at + Vector2(-half, -5), at + Vector2(-half * 0.3, 4), at + Vector2(half * 0.3, -4), at + Vector2(half, 5)]), INK, 2.0, true)
		# The worst kind of wound there, in a word (the rest is in the list).
		var lines: Array = look["kinds"].slice(0, 1)
		if look["festering"]:
			lines.append("곪음")
		var font: Font = UiFonts.face(UiFonts.WORD, 500)
		for i in lines.size():
			var w: float = font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_WORD_FONT).x
			fig.draw_string(font, c + Vector2(-w * 0.5, 4.0 + i * (BODY_WORD_FONT + 2.0)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_WORD_FONT, INK)


func _care(o, wound: Dictionary, mode: String) -> void:
	_close_modal()
	if not game.actions.treat_wound(game.player, o, wound, mode):
		toast("지금은 처치 불가")


## 자르기: the first press asks once more (the key says so); a second within
## CUT_CONFIRM_S closes the picture and the cut goes on in the field.
func _cut(o, part: String) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if not is_same(cut_armed.get("of"), o) or String(cut_armed.get("part", "")) != part or now - float(cut_armed.get("t", -INF)) > CUT_CONFIRM_S:
		cut_armed = {"of": o, "part": part, "t": now}
		if not body_cut.is_empty():
			(body_cut["key"] as Button).text = "한 번 더 누르면 자른다"
		return
	cut_armed = {}
	_close_modal()
	if not game.actions.amputate(game.player, o, part):
		toast("지금은 자를 수 없음")


## Decision card (시안 2차 06 사건 카드, B1): paper come in from the left, as the
## stop card's sheet; what it is for in its kick, its first sentence in pen for
## its title and the rest in pen under it (in print when long, so it stays on
## the sheet), and at its foot the choices as the leader's lines (.sayb): the
## number, the line in 「」, what it does and what it costs under it in side
## ink. A press picks.
func card(id: String, text: String, options: Array, cb: Callable) -> void:
	var shade := _open_shade()
	var sheet = PaperSheet.new()
	sheet.name = "Card"
	sheet.position = CARD_AT * UiFonts.K
	shade.add_child(sheet)
	var col := VBoxContainer.new()
	col.name = "Body"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.inner.add_child(col)
	# No 「현장 결정」 · 「출발」 kick over the title (결정 417): the card is its title.
	var words: Array = card_lines(text)
	# .cd__txt h2 in pen: 36 on lines of 30.
	var title := _ink_lines(String(words[0]), UiFonts.HAND, 36.0, 30.0)
	title.name = "Title"
	col.add_child(title)
	var scene_text: String = String(words[1])
	var said := ScrollContainer.new()
	said.name = "Scene"
	said.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	said.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	said.size_flags_vertical = Control.SIZE_EXPAND_FILL
	said.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(said)
	if scene_text != "":
		# .scene: pen 18 on lines of 20; print 13.5 when it is long.
		var long: bool = scene_text.length() > CARD_PEN_LETTERS or scene_text.count("\n") >= CARD_PEN_LINES
		var scene := _ink_lines(scene_text, UiFonts.WORD if long else UiFonts.HAND, 13.5 if long else 18.0, 20.0)
		scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		said.add_child(scene)
	var says := VBoxContainer.new()
	says.name = "Says"
	says.mouse_filter = Control.MOUSE_FILTER_IGNORE
	says.add_theme_constant_override("separation", 0)
	col.add_child(says)
	for i in options.size():
		says.add_child(_say(i, options[i], cb))


## A card's words as [title, the rest]: its first sentence is its title (with
## no full stop, as 06's), the rest the scene under it.
static func card_lines(text: String) -> Array:
	var t: String = text.strip_edges()
	for i in t.length():
		if t[i] == "." and (i + 1 == t.length() or t[i + 1] == " " or t[i + 1] == "\n"):
			return [t.substr(0, i), t.substr(i + 1).strip_edges()]
	return [t, ""]


## Ink on the paper in `kind` at `css_px`, wrapping between words on lines of
## `line_css` (a face taller than its line keeps to the line, as CSS's does).
func _ink_lines(text: String, kind: int, css_px: float, line_css: float, color: Color = Paper.INK) -> Label:
	var l := Paper.ink(UiFonts.keep_all(text), kind, 400, css_px, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var f: Font = l.get_theme_font("font")
	var natural: float = f.get_height(l.get_theme_font_size("font_size"))
	l.add_theme_constant_override("line_spacing", int(round(UiFonts.px(line_css) - natural)))
	return l


## One of the leader's lines (.sayb): a faint rule over it, its number at the
## left (a column of 22), the line in 「」 at 14/500 on a line of 22, and under
## it what it does and what it costs in side ink at 12; pressed, a faint shade.
func _say(i: int, o: Dictionary, cb: Callable) -> Button:
	var b := Button.new()
	b.name = "Say_" + String(o["id"])
	b.disabled = bool(o.get("off", false))
	b.modulate = Color(0.5, 0.5, 0.5) if b.disabled else Color.WHITE
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, UiFonts.px(55.0))
	var rest := StyleBoxFlat.new()
	rest.bg_color = Color(0, 0, 0, 0)
	rest.border_width_top = GlassPane.px(2.0)
	rest.border_color = Paper.TRACK
	var down := rest.duplicate() as StyleBoxFlat
	down.bg_color = Color(42 / 255.0, 32 / 255.0, 24 / 255.0, 0.07)
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, rest)
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, down)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", GlassPane.px(4.0))
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# padding 7 6 6 4.
	h.offset_left = UiFonts.px(4.0)
	h.offset_right = -UiFonts.px(6.0)
	h.offset_top = UiFonts.px(7.0)
	h.offset_bottom = -UiFonts.px(6.0)
	b.add_child(h)
	var n := Paper.ink(str(i + 1), UiFonts.NUMBER, 600, 21.0, Paper.INK2)
	n.custom_minimum_size = Vector2(UiFonts.px(22.0), UiFonts.px(22.0))
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(n)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	h.add_child(col)
	var line: String = String(o.get("say", "")).strip_edges().trim_prefix("\"").trim_suffix("\"")
	var q := Paper.ink(UiFonts.keep_all("「%s」" % line if line != "" else String(o["label"])), UiFonts.WORD, 500, 14.0)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size = Vector2(0, UiFonts.px(22.0))
	col.add_child(q)
	var under: Array = []
	if line != "":
		under.append(String(o["label"]))
	if o.has("cost"):
		under.append(String(o["cost"]))
	if not under.is_empty():
		var s := Paper.ink(UiFonts.keep_all(" · ".join(under)), UiFonts.WORD, 400, 12.0, Paper.INK2, 0.36)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(s)
	# As high as its words once they wrap (55 at the least).
	var fit := func() -> void:
		b.custom_minimum_size.y = maxf(UiFonts.px(55.0), h.get_combined_minimum_size().y + UiFonts.px(13.0))
	h.minimum_size_changed.connect(fit)
	fit.call()
	GlassPane.sinks(b, h)
	b.pressed.connect(_card_pick.bind(cb, String(o["id"])))
	return b


func _card_pick(cb: Callable, choice: String) -> void:
	_close_modal()
	if cb.is_valid():
		cb.call(choice)


func loot(id: String) -> void:
	inv_view = "near"
	InventoryPane.open(self, {"kind": "box", "id": id})


## A thing as a cell across its row: its picture and its name at 13/500 at the
## left (decision 417: a picture and a short name), its weight in the number
## face at the right.
func _thing_key(word: String, weight: String, cb: Callable, icon: String = "") -> Button:
	var b := GlassPane.key("", cb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = UiFonts.px(12.0)
	h.offset_right = -UiFonts.px(12.0)
	h.add_theme_constant_override("separation", GlassPane.px(8.0))
	if icon != "" and HudIcons.PATHS.has(icon):
		h.add_child(_icon_rect(icon, ITEM_ICON_PX, GlassPane.INK))
	var name_l := UiFonts.label(word, UiFonts.WORD, 500, 13.0, GlassPane.INK, 0.39)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.size_flags_vertical = Control.SIZE_FILL
	h.add_child(name_l)
	var kg := UiFonts.label(weight, UiFonts.NUMBER, 500, 15.0, GlassPane.INK2, 0.22)
	kg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kg.size_flags_vertical = Control.SIZE_FILL
	h.add_child(kg)
	b.add_child(h)
	GlassPane.sinks(b, h)
	return b


func _loot_take(id: String, i: int) -> void:
	game.actions.take(game.player, id, i)
	loot(id)


func _loot_all(id: String) -> void:
	game.actions.take_all(game.player, id)
	loot(id)


## 「멈추기」 while things come out: what is out stays out, the rest stays in.
func _loot_stop(id: String) -> void:
	var p = game.player
	game.actions.take_queue.erase(p.get_instance_id())
	if p.action == "take":
		p.cancel_action()
	taking_box = ""
	InventoryPane.open(self, inv_near if not inv_near.is_empty() else {"kind": "box", "id": id})


## Looking is free, taking costs the time (card R1 가): with the box shown and a
## thing coming out of it the field goes on under the pane; it stops again once
## the thing is out (took) — called each time the pane is laid.
func run_while_taking() -> void:
	var p = game.player
	taking_box = InventoryPane.taking_id(game, p) if modal_open else ""
	if taking_box != "" and not game.away and not game.resume_pending:
		game.paused = false


## Decision 532: only taking a thing advances the field under the bag pane.
func _tick_bag_pause() -> void:
	if _bag_up():
		_bag_pause()


## The app away (field_game.gd interrupt) holds the field still whatever.
func _bag_pause() -> void:
	if game.away or game.resume_pending:
		return
	game.paused = taking_box == ""


## External changes to nearby places refresh the pane using the same reach.
## A different distance order alone does not require a rebuild.
func _bag_places_moved() -> void:
	if not _bag_up():
		return
	var now: Array = InventoryPane.place_keys(InventoryPane.places(game, game.player))
	var was: Array = bag_places.duplicate()
	now.sort()
	was.sort()
	if now != was:
		_lay_bag_again()


## Lay the bag pane again where it is; a place shown that is no longer near hands
## over to the bag tab. A destination no longer in reach falls to the floor, never
## on its own to the train's hold: a thing loaded there cannot be taken back from
## this pane (coordinator 10-30). The places keep their order and the lists their
## scroll; the field goes on without a frame's stop.
func _lay_bag_again() -> void:
	var kept: Dictionary = _bag_scrolls()
	var near: Array = InventoryPane.place_keys(InventoryPane.places(game, game.player))
	if not near.has(InventoryPane.place_key(inv_near)):
		if inv_view == "near":
			inv_view = "bag"
		inv_near = {"kind": "ground", "id": ""}
	InventoryPane.open(self, inv_near)
	_bag_scrolls_back(kept)
	_bag_pause()


## The bag pane's two scrolls as they stand, with the tab and place they show.
func _bag_scrolls() -> Dictionary:
	var kept := {"view": inv_view, "at": InventoryPane.place_key(inv_near)}
	if _bag_up():
		for scroll_name: String in ["List", "PlaceScroll"]:
			var list := box_pane.find_child(scroll_name, true, false) as ScrollContainer
			if list != null:
				kept[scroll_name] = list.scroll_vertical
	return kept


## Back where they were once the new pane is laid out (a scroll set before its
## rows are sized falls to the top): the places rail always, the item list while
## it shows the same rows (the bag tab whatever its destination, a place's tab
## for that place).
func _bag_scrolls_back(kept: Dictionary) -> void:
	var pane: Control = box_pane
	var same: bool = kept["view"] == inv_view and (inv_view == "bag" or kept["at"] == InventoryPane.place_key(inv_near))
	var back := func() -> void:
		if not is_instance_valid(pane) or modal != pane:
			return
		for scroll_name: String in ["List", "PlaceScroll"]:
			var list := pane.find_child(scroll_name, true, false) as ScrollContainer
			if list != null and kept.has(scroll_name) and (same or scroll_name == "PlaceScroll"):
				list.scroll_vertical = int(kept[scroll_name])
	get_tree().process_frame.connect(back, CONNECT_ONE_SHOT)


## The pane now shows box `id` ("" for none): the box it comes to opens with its sound,
## the one it leaves shuts with its own — once, where the new one has no opening sound
## (field_audio.gd box_sound, card R3 가). A box laid again (a row taken) sounds nothing;
## the pane put away shuts the box (the frame after, as laying again closes it first).
func box_shown_now(id: String) -> void:
	if id == box_shown:
		return
	var was := box_shown
	box_shown = id
	if game.audio == null:
		return
	var boxes: Dictionary = game.data["containers"]
	if id != "" and boxes.has(id) and game.audio.box_sound(boxes[id], "open"):
		return
	if was != "" and boxes.has(was):
		game.audio.box_sound(boxes[was], "close")


## A thing is out of box `id` (field_actions.gd _take_done): refresh the current
## tab, with the next of 「모두 담기」 running or stopped when none is left.
func took(id: String) -> void:
	if modal_open and box_pane == modal and (taking_box == id or String(inv_near.get("id", "")) == id):
		InventoryPane.open(self, inv_near)


## Each frame while taking with the pane up: the row's bar fills; a blow or a
## grab that lets the work go puts the pane away, the field already running, so
## it can be met. The sleeping stick cannot interrupt this work (decision 532).
func _tick_take() -> void:
	if taking_box == "":
		return
	var p = game.player
	if p.action != "take":
		_close_modal(false)
		toast("챙기다 손을 뗐다")
		return
	if take_bar != null and is_instance_valid(take_bar):
		take_bar.value = 1.0 - p.action_t / maxf(p.action_total, 0.001)


## Open the bag tab afresh, or refresh the current tab with its destination kept.
func bag_panel() -> void:
	if modal == null or not is_instance_valid(box_pane) or modal != box_pane:
		inv_near = {}
		inv_view = "bag"
	InventoryPane.open(self, inv_near)


func sled_panel(sled_id: int) -> void:
	inv_view = "near"
	InventoryPane.open(self, {"kind": "sled", "id": sled_id, "name": "썰매"})


func _inv_sled_take(sled_id: int, item: String) -> void:
	game.actions.move_sled(game.player, sled_id, item, false)
	bag_panel()


## A row of the bag pressed: it goes across to the place shown at the right.
func _inv_put(id: String) -> void:
	var p = game.player
	match String(inv_near.get("kind", "ground")):
		"sled":
			game.actions.move_sled(p, int(inv_near["id"]), id, true)
		"box":
			game.actions.store(p, String(inv_near["id"]), id)
		"train":
			game.actions.load_train(p, id)
		_:
			game.actions.put_down(p, id)
	bag_panel()


## A thing lying near pressed: picked up (a garment is put on, the pane closing
## on the hands' work).
func _inv_pick(i: int) -> void:
	game.actions.pick_up(game.player, i)
	if game.player.action != "":
		_close_modal()
	else:
		bag_panel()


func _inv_place(place: Dictionary) -> void:
	inv_near = place
	inv_view = "near"
	bag_panel()


func _inv_bag() -> void:
	inv_view = "bag"
	bag_panel()


func _inv_worn() -> void:
	inv_worn_open = not inv_worn_open
	bag_panel()


func _inv_sort() -> void:
	inv_sort = "name" if inv_sort == "weight" else "weight"
	bag_panel()


func _load_train() -> void:
	game.actions.load_train(game.player)
	bag_panel()


## One thing worn: its picture and name, how worn it is once it shows
## (해짐, 너덜), and a key that takes it off (field_actions.gd undress).
func _worn_row(slot: String, id: String) -> Control:
	var p = game.player
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.custom_minimum_size = Vector2(0, UiFonts.px(GlassPane.CELL_H))
	h.add_theme_constant_override("separation", GlassPane.px(10.0))
	var icon: String = game.item_icon(id)
	if icon != "" and HudIcons.PATHS.has(icon):
		h.add_child(_icon_rect(icon, ITEM_ICON_PX, GlassPane.INK))
	var word: String = Wear.state_word(Wear.occupant(p, slot))
	var shown: String = game.item_name(id) if word == "" or word == Wear.STATE_WORDS[0] else "%s · %s" % [game.item_name(id), word]
	var name_l := UiFonts.label(shown, UiFonts.WORD, 500, 13.0, GlassPane.INK, 0.39)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(name_l)
	# One under others takes them off and back on: how long shows on the key.
	var plan: Array = Wear.undress_plan(p, slot)
	var off := GlassPane.key("벗기" if plan.size() <= 1 else "벗기 %d초" % ceili(Wear.plan_time(plan)), _undress.bind(slot))
	off.size_flags_horizontal = Control.SIZE_SHRINK_END
	off.custom_minimum_size.x = UiFonts.px(DROP_W)
	h.add_child(off)
	return h


func _undress(slot: String) -> void:
	game.actions.undress(game.player, slot)
	_close_modal()


## Putting on a garment that takes layers off and back on (decision 434,
## clothing.md 7장): the steps in a line, what comes off for good, the seconds,
## and the key that does it. `src`: {"box", "i"} for one in a searched box or
## {"ground": the garment lying there}, and its "id".
func wear_pane(src: Dictionary) -> void:
	var p = game.player
	var id: String = String(src["id"])
	var plan: Array = Wear.dress_plan(p, id)
	var pane := _open_pane(game.item_name(id), "%d초" % ceili(Wear.plan_time(plan)), game.item_icon(id))
	var w: float = PANE_W - GlassPane.PAD_L - GlassPane.PAD_R
	var steps: Array = []
	for step: Dictionary in plan:
		var slot: String = String(step["slot"])
		match String(step["op"]):
			"off", "aside":
				steps.append("%s 벗기" % game.item_name(String(Wear.occupant(p, slot).get("id", ""))))
			"on":
				steps.append("%s 입기" % game.item_name(id))
			"back":
				steps.append(game.item_name(String(Wear.occupant(p, slot).get("id", ""))))
	pane.body.add_child(GlassPane.note(" → ".join(steps), w, GlassPane.INK, 13.0, 500))
	var down: Array = Wear.displaced(p, id).map(func(g: Dictionary) -> String: return game.item_name(String(g.get("id", ""))))
	if not down.is_empty():
		pane.body.add_child(GlassPane.note("발밑에 둠: %s" % ", ".join(down), w, GlassPane.INK2, 12.0))
	var foot := GlassPane.row()
	foot.alignment = BoxContainer.ALIGNMENT_END
	var go := LampKey.new("입기", false)
	go.pressed.connect(_wear_go.bind(src))
	foot.add_child(go)
	pane.body.add_child(foot)


func _wear_go(src: Dictionary) -> void:
	_close_modal()
	var p = game.player
	var id: String = String(src["id"])
	if src.has("box"):
		var items: Array = game.data["containers"].get(String(src["box"]), {}).get("items", [])
		var i: int = int(src["i"]) if int(src["i"]) < items.size() and String(items[int(src["i"])]) == id else items.find(id)
		if i >= 0:
			game.actions.take(p, String(src["box"]), i, true)
		return
	for i in game.ground_items.size():
		if is_same(game.ground_items[i], src["ground"]):
			game.actions.pick_up(p, i, true)
			return


## What one of the fallen has on (decision 434, clothing.md 8장): a row each,
## the outermost first, its name and how worn (해짐, 너덜), and its seconds; a
## press takes that one off (field_actions.gd strip_body) and it is put down
## by the body.
func strip_pane(zid: int) -> void:
	var z: Dictionary = game.zombies.find(zid)
	if not game.zombies.strippable(z):
		return
	var worn: Dictionary = game.zombies.worn_of(z)
	var pane := _open_pane("옷 가져오기", "", "search")
	var list := VBoxContainer.new()
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_theme_constant_override("separation", GlassPane.px(GlassPane.GAP))
	for slot: String in Wear.OUTSIDE_IN:
		if not worn.has(slot):
			continue
		var g: Dictionary = worn[slot]
		var gid: String = String(g.get("id", ""))
		var word: String = Wear.state_word(g)
		var shown: String = game.item_name(gid) if word == Wear.STATE_WORDS[0] else "%s · %s" % [game.item_name(gid), word]
		list.add_child(_thing_key(shown, "%d초" % ceili(Wear.strip_time(gid)), _strip.bind(zid, slot), game.item_icon(gid)))
	pane.body.add_child(GlassPane.scroll(list, LOOT_LIST_MAX))


func _strip(zid: int, slot: String) -> void:
	_close_modal()
	game.actions.strip_body(game.player, zid, slot)


## The journal on a note pinned in the bag (시안 .pnote: paper with its fibre,
## a brass clip at its top, leaning 1.1° from its foot's right): 일지 in pen on
## a line of 28, this stop's goals one to a line of 20 at 13.
func _journal_note(goals: String) -> Control:
	var note := PanelContainer.new()
	note.name = "Journal"
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	note.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	note.custom_minimum_size = Vector2(UiFonts.px(JOURNAL_W), 0)
	var sb: StyleBox = HudSkin.slip()
	# padding 11 14 6 18.
	sb.content_margin_left = UiFonts.px(18.0)
	sb.content_margin_right = UiFonts.px(14.0)
	sb.content_margin_top = UiFonts.px(11.0)
	sb.content_margin_bottom = UiFonts.px(8.0)
	note.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	note.add_child(v)
	var title = TypeLine.new(28.0)
	title.add_child(Paper.ink("일지", UiFonts.HAND, 400, 24.0))
	v.add_child(title)
	for part in goals.split(" · "):
		var line := Paper.ink("· " + part, UiFonts.WORD, 400, 13.0)
		line.custom_minimum_size = Vector2(0, UiFonts.px(20.0))
		line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(line)
	note.rotation = deg_to_rad(JOURNAL_LEAN_DEG)
	note.resized.connect(func() -> void: note.pivot_offset = note.size)
	note.draw.connect(_draw_clip.bind(note))
	return note


## The brass clip over a pinned note's top (.pnote::before): 26 × 11, 5 above
## its edge, brass from light to dark down it, a small shadow under it.
func _draw_clip(note: Control) -> void:
	var k: float = UiFonts.K
	var r := Rect2(note.size.x * 0.5 - 13.0 * k, -5.0 * k, 26.0 * k, 11.0 * k)
	GlassParts.shadow(note, r, 2.0 * k, 2.0 * k, 3.0 * k, Color(0, 0, 0, 0.5))
	var mid: float = r.position.y + r.size.y * 0.5
	note.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, mid), Vector2(r.position.x, mid)]),
			PackedColorArray([HudSkin.RIM1, HudSkin.RIM1, HudSkin.RIM2, HudSkin.RIM2]))
	note.draw_polygon(PackedVector2Array([Vector2(r.position.x, mid), Vector2(r.end.x, mid), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([HudSkin.RIM2, HudSkin.RIM2, HudSkin.RIM3, HudSkin.RIM3]))


func _swap_from_bag() -> void:
	_close_modal()
	_swap()


## Eat one there and then: the bag closes and the hands get to it.
func _eat(id: String) -> void:
	_close_modal()
	game.eat(game.player, id)


## Throw an empty tin where the chief faces (a lure): the bag closes.
func _throw(id: String) -> void:
	_close_modal()
	game.throw_lure(game.player, id)


## The watch row's key: every set watch is switched off, the bag shown again.
func _alarm_off() -> void:
	game.alarm_off()
	bag_panel()


## The key beside the bag: the same, without opening anything.
func _alarm_key_off() -> void:
	game.alarm_off()
	toast("시계 알람을 껐다.")


func _ally_menu(p) -> void:
	if not p.is_alive():
		return
	var pane := _open_pane(String(p.display_name), p.body.status_words(), "people")
	var weapons: Array = []
	for h in p.hands:
		weapons.append(W.get_data(h["id"]).get("name", h["id"]))
	pane.body.add_child(GlassPane.mixed("손: %s · 인벤토리 %.1f/%.0f" % [", ".join(weapons), p.weight(), p.carry_limit()]))
	# The orders as picks, the one standing in its amber corners (시안 13's
	# picks), two rows of three with the body picture last.
	var rows: Array = [GlassPane.row(), GlassPane.row()]
	for i in COMMANDS.size():
		var c: Array = COMMANDS[i]
		rows[0 if i < 3 else 1].add_child(GlassPane.pick(command_word(c), "", String(p.command) == String(c[0]), _command.bind(p, c[0]), String(COMMAND_ICONS.get(c[0], ""))))
	var look := GlassPane.key("몸 상태", body_panel.bind(p), "bandage")
	# Set as the picks beside it are: the mark and the word from the left.
	look.alignment = HORIZONTAL_ALIGNMENT_LEFT
	rows[1].add_child(look)
	for r: Control in rows:
		pane.body.add_child(r)


## The word for an order. The one-by-one 'retreat' may be shown as '열차로'
## (opts["retreat_name"] = "train"), to be chosen on the phone.
func command_word(c: Array) -> String:
	if c[0] == "retreat" and String(game.opts.get("retreat_name", "")) == "train":
		return "열차로"
	return c[1]


## Every living companion gets the 'retreat' order at once. The work crew is
## not in it: it has its own recall on its card.
func _all_aboard() -> void:
	var sent := 0
	for row in ally_buttons:
		if row["p"].is_alive():
			_command(row["p"], "retreat", false)
			sent += 1
	toast("모두 열차로" if sent > 0 else "보낼 동료 없음")


## 따라와 or 대기 for every living companion at once (decision 408), as 'all
## aboard' sends them all to the train; 대기 keeps each where they stand. The
## work crew is not in it.
func _order_all(cmd: String) -> void:
	var sent := 0
	for row in ally_buttons:
		if row["p"].is_alive():
			_command(row["p"], cmd, false)
			sent += 1
	var c: Array = COMMANDS.filter(func(r: Array) -> bool: return r[0] == cmd)[0]
	toast("모두 " + command_word(c) if sent > 0 else "남은 동료 없음")


func _command(p, cmd: String, close: bool = true) -> void:
	p.command = cmd
	# Said back to the chief (ally_lines.gd); the retreat is said as they turn (field_ai.gd).
	game.shout(p, "order_" + cmd)
	p.brain["boarded"] = false
	p.target_zombie = {}
	p.aim.stop()
	match cmd:
		"wait":
			p.command_target = p.position
		"search":
			p.command_target = game.player.position
	if close:
		_close_modal()


## Work crew settings: attitude and fire permission per crew (s2_station 2.4).
func work_panel() -> void:
	var site: String = game.work.active_site
	var template: Dictionary = game.work.job(site)
	var coal: bool = template["yield"] == "coal"
	var title: String = "석탄 작업" if coal else String(template["name"])
	var cargo: String = "석탄" if coal else "목재"
	var delivered: float = game.actions.coal_delivered if coal else game.actions.wood_delivered
	var pane := _open_pane(title, "남은 %s %.1f · 실은 %s %.1f" % [cargo, game.work.remaining(site), cargo, delivered], "coal" if coal else "wood")
	if game.haul_mult() < 1.0 and coal:
		var why := GlassPane.row()
		why.name = "RationHaul"
		var art := TextureRect.new()
		art.texture = StatusArt.texture("ration", false, false, STATUS_ART_SIZE)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.custom_minimum_size = Vector2.ONE * UiFonts.px(22)
		why.add_child(art)
		why.add_child(GlassPane.note("비상식량감축법 — 덜 먹은 작업조라 한 번에 %d%% 덜 나른다." % roundi((1.0 - game.haul_mult()) * 100.0), 360.0))
		pane.body.add_child(why)
	# Each setting a row headed by its word, its values as picks, the one set in
	# its amber corners (시안 13's 레버 꼴 row).
	var h1 := GlassPane.row()
	h1.add_child(GlassPane.row_word("태도"))
	for row in [["aggressive", "공격적"], ["defensive", "방어적"], ["neutral", "중립"]]:
		h1.add_child(GlassPane.pick(row[1], "", game.ai.crew_attitude == row[0], _set_crew.bind("attitude", row[0])))
	pane.body.add_child(h1)
	var h2 := GlassPane.row()
	h2.add_child(GlassPane.row_word("사격"))
	for row in [["free", "자유"], ["threat", "위협만"], ["melee", "근접만"]]:
		h2.add_child(GlassPane.pick(row[1], "", game.ai.crew_fire == row[0], _set_crew.bind("fire", row[0])))
	pane.body.add_child(h2)
	var h3 := GlassPane.row()
	h3.add_child(GlassPane.key("작업조 철수", _set_crew.bind("recall", ""), "train"))
	pane.body.add_child(h3)


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


## Who stays if the train leaves now: alive, not aboard, and off the platform or
## down on it. The departure card counts them; a mark on the ally row can use the
## same people.
func would_stay() -> Array:
	var out: Array = []
	for p in game.squad + game.crew:
		if not p.is_alive() or p.brain.get("boarded", false):
			continue
		if not game.actions.on_platform(p) or p.body.downed:
			out.append(p)
	return out


## Departure: the leader on the platform blows the whistle; who is not here stays.
## Only how many stay is said, never their names (결정 147·183: the end of a stop counts
## those left behind).
func depart_card() -> void:
	var left: Array = would_stay()
	var text := "기적을 울리고 떠난다. 기적 소리는 멀리까지 간다."
	if not left.is_empty():
		text += "\n지금 떠나면 %d명이 그대로 남는다." % left.size()
	text += Sled.leaving_note(game)
	# Words, not seconds: arrival spreads too widely to promise a number
	# (s2_play/measure_depart.md: 30 m leaves about 20 s to 10 m).
	if horde_close():
		text += "\n무리가 가깝다."
	if game.holdout.opens_on_leaving():
		text += "\n떠날 채비에 시간이 걸린다. 그동안 문을 지켜야 한다."
	elif game.holdout.on:
		# Both prices side by side, before the choice (user decisions 143, 146, 147).
		var cost: Dictionary = game.holdout.early_cost()
		var push: Dictionary = game.holdout.plough(game.holdout.track_now())
		if game.holdout.ready:
			text += "\n채비가 끝났다. 선로 위: %s." % push["word"]
			text += "\n지금 떠나면: 부품 %d (쟁기 값뿐). 더 머물면 선로에 서는 만큼 오른다." % int(push["parts"])
		else:
			text += "\n채비가 %d초 남았다. 선로 위: %s." % [int(ceil(game.holdout.left)), push["word"]]
			text += "\n지금 떠나면: 석탄 +%d, 부품 %d (쟁기 %d · 덜 된 채비 %d)." % [int(cost["coal"]), int(push["parts"]) + int(cost["plow_part"]), int(push["parts"]), int(cost["plow_part"])]
			text += "\n끝까지 버티면: 덜 된 채비 값이 없다. 그때 선로에 선 만큼 쟁기 값만 든다."
		text += "\n셋을 센 뒤 떠난다. 그때 열차에 닿지 못한 사람은 남는다."
		var out: int = game.outside()
		if out > 0:
			text += "\n지금 밖에 있는 사람 %d. 남기면 신임 −%d." % [out, game.holdout.trust_drop(out)]
	card("depart", text, [
		{"id": "go", "label": "떠나기", "say": "\"올라타! 기다리지 않는다!\""},
		{"id": "wait", "label": "기다리기", "say": "\"조금만 더. 다 올 때까지.\""},
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
		game.depart()


## The whistle has gone and the stage is over: the screen darkens over the
## still field, the lines come up with what the stop came to side by side
## under them ([title, [rows]] columns), and after LEAVE_BEAT_S the end card.
func leave_beat(result: Dictionary, lines: Array, columns: Array = []) -> void:
	_close_modal(false)
	context_rows = []
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(veil)
	# Under the overlay, so what those left behind shout stays readable.
	root.move_child(veil, overlay.get_index())
	var words := Control.new()
	words.name = "Words"
	words.set_anchors_preset(Control.PRESET_FULL_RECT)
	words.modulate.a = 0.0
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(words)
	if not columns.is_empty():
		# The stage is over: the thumb pads go, so the columns are not under them.
		for b in pads:
			b.visible = false
	# The leader is aboard: their card and the bag under it go, so the paper is
	# not under them.
	portrait.visible = false
	bag_box.visible = false
	words.add_child(_leave_strip(result, lines, columns))
	leaving = {"result": result, "t": LEAVE_BEAT_S, "veil": veil, "words": words}


## The leave beat on paper (시안 2차 08 짧은 판, B1), in the upper part of the
## screen: the middle is where the people are, and those left behind shout over
## their heads there. The place and how the stop ended in its kick (a line of
## 20), what it came to at 26/600 (36), how long it was at 14 (22 each), then
## under a rule the four columns side by side, each its title in side ink (18)
## over its rows at 13/500 (20). The paper is cut to its lines.
func _leave_strip(result: Dictionary, lines: Array, columns: Array) -> Control:
	var k: float = UiFonts.K
	var gap: int = GlassPane.px(10.0)
	var col_w: float = floorf(((LEAVE_W - LEAVE_IN.position.x - LEAVE_IN.size.x) * k - gap * 3.0) / 4.0)
	var cells: Array = []
	var most: float = 0.0
	for column: Array in columns:
		var made: Array = []
		var high: float = 0.0
		for line in column[1]:
			var r: Label = _leave_cell(String(line), col_w)
			made.append(r)
			high += r.custom_minimum_size.y
		cells.append(made)
		most = maxf(most, high)
	var tall: float = LEAVE_IN.position.y + 20.0 + 36.0 + 22.0 * maxi(lines.size() - 1, 0) + LEAVE_IN.size.y
	if not columns.is_empty():
		tall += 10.0 + 18.0 + most / k
	var sheet = PaperSheet.new(Vector2(LEAVE_W, tall))
	sheet.name = "Strip"
	sheet.rotation = deg_to_rad(LEAVE_LEAN_DEG)
	sheet.position = LEAVE_AT * k
	sheet.inner.position = LEAVE_IN.position * k
	sheet.inner.size = Vector2(LEAVE_W - LEAVE_IN.position.x - LEAVE_IN.size.x, tall - LEAVE_IN.position.y - LEAVE_IN.size.y) * k
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.inner.add_child(col)
	var d: Dictionary = ReceiptCard.rows(result)
	var kick = TypeLine.new(20.0)
	kick.add_child(Paper.ink(String(d["place"]) + (" · " + String(d["stamp"]) if String(d["stamp"]) != "" else ""), UiFonts.WORD, 400, 12.0, Paper.INK2, 1.2))
	col.add_child(kick)
	for i in lines.size():
		var line = TypeLine.new(36.0 if i == 0 else 22.0)
		var l := Paper.ink(String(lines[i]), UiFonts.WORD, 600 if i == 0 else 400, 26.0 if i == 0 else 14.0, Paper.INK, 0.52 if i == 0 else 0.0)
		line.add_child(l)
		col.add_child(line)
	if columns.is_empty():
		return sheet
	var rule := Control.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size = Vector2(0, UiFonts.px(10.0))
	rule.draw.connect(func() -> void:
		rule.draw_rect(Rect2(0, (rule.size.y - UiFonts.px(2.0)) * 0.5, rule.size.x, UiFonts.px(2.0)), Paper.LINE))
	col.add_child(rule)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", gap)
	col.add_child(row)
	for i in columns.size():
		var column: Array = columns[i]
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.custom_minimum_size = Vector2(col_w, 0)
		box.add_theme_constant_override("separation", 0)
		row.add_child(box)
		var t := Paper.ink(String(column[0]), UiFonts.WORD, 400, 12.0, Paper.INK2, 1.44)
		t.custom_minimum_size = Vector2(0, UiFonts.px(18.0))
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(t)
		for r: Label in cells[i]:
			box.add_child(r)
	return sheet


## One row of a leave beat's column: a count (「석탄 6」, 「4명」) at 13/500 on a
## line of 20; a line with no number in it in side ink at 12, wrapping in its
## column between words, as high as its lines.
func _leave_cell(text: String, col_w: float) -> Label:
	if RegEx.create_from_string("[0-9]").search(text) != null:
		var r := Paper.ink(text, UiFonts.WORD, 500, 13.0)
		r.custom_minimum_size = Vector2(0, UiFonts.px(20.0))
		r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return r
	var said: String = UiFonts.keep_all(text)
	var l := Paper.ink(said, UiFonts.WORD, 400, 12.0, Paper.INK2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var f: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	var para := TextParagraph.new()
	para.add_string(said, f, fs)
	para.width = col_w
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	l.custom_minimum_size = Vector2(col_w, maxf(UiFonts.px(20.0), para.get_size().y))
	return l


func _tick_leave(delta: float) -> void:
	if leaving.is_empty():
		return
	leaving["t"] = float(leaving["t"]) - delta
	var gone: float = LEAVE_BEAT_S - float(leaving["t"])
	leaving["veil"].color.a = LEAVE_DARK * clampf(gone / LEAVE_DARK_S, 0.0, 1.0)
	leaving["words"].modulate.a = clampf((gone - LEAVE_WORDS_AT) / 0.6, 0.0, 1.0)
	if float(leaving["t"]) <= 0.0:
		var result: Dictionary = leaving["result"]
		leaving["veil"].queue_free()
		leaving = {}
		show_end(result)


## The end of a stop played alone: on the shade, the return receipt on the
## stop's own sheet at the left, as the slice hands it back (receipt_sheet.gd,
## its foot bare), and at the right, from under the band to the sheet's foot,
## what the play came to (the real time and the noise, the holdout's lines) in
## glass ink over the keys: copy the receipt, copy the record, again. The
## stop's choices are in the receipt it copies.
func show_end(result: Dictionary) -> void:
	_close_modal(false)
	context_rows = []
	var shade := _open_shade()
	var sheet = ReceiptSheet.new()
	sheet.name = "Receipt"
	sheet.result = result
	sheet.seg = 0
	shade.add_child(sheet)
	var side := VBoxContainer.new()
	side.name = "Record"
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_theme_constant_override("separation", GlassPane.px(4.0))
	side.anchor_right = 1.0
	side.anchor_bottom = 1.0
	side.offset_left = UiFonts.px(ReceiptSheet.SHEET_AT.x + PaperSheet.SIZE.x + END_GAP)
	side.offset_right = -UiFonts.px(16.0)
	side.offset_top = UiFonts.px(GlassPane.TOP + GlassPane.PAD_T)
	side.offset_bottom = -UiFonts.px(16.0)
	shade.add_child(side)
	side.add_child(UiFonts.label("기록", UiFonts.WORD, 400, 12.0, GlassPane.INK3, 1.92))
	var lines: Array = ["실제 %d분 %d초" % [int(result["real_seconds"]) / 60, int(result["real_seconds"]) % 60], noise_line()]
	lines.append_array(result.get("holdout_lines", []))
	for line in lines:
		var l := UiFonts.label(UiFonts.keep_all(String(line)), UiFonts.WORD, 400, 13.0, GlassPane.INK2, 0.39)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.add_child(l)
	var room := Control.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(room)
	# On no pane: the keys take the pane's dark for their ground.
	var ground: Color = GlassPane.BACKING[0][1]
	var keys := GlassPane.row()
	keys.name = "Keys"
	side.add_child(keys)
	keys.add_child(GlassPane.key("영수증 복사", _copy.bind(result["receipt_json"], "영수증 복사됨"), "", ground))
	keys.add_child(GlassPane.key("기록 복사", _copy.bind(result["telemetry"], "기록 복사됨"), "", ground))
	keys.add_child(GlassPane.key("다시", _restart, "", ground))


func _copy(text: String, note: String) -> void:
	DisplayServer.clipboard_set(text)
	toast(note)


func _restart() -> void:
	game.restart_requested.emit()


func _swap() -> void:
	game.combat.swap(game.player)


func _toggle_pause() -> void:
	if modal_open or game.resume_pending:
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
		_load_walk_note(p)
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
		toast("멈춘 동안 밀치기 불가")
		return
	if not p.grabbers.is_empty():
		game.combat.break_grab(p)
	elif p.can_act():
		game.combat.start_shove(p)


# ---------------------------------------------------------------- input

## Fingers on a phone: every touch index, so the left thumb can hold the
## stick while the right one aims or presses a pad.
func _input(event: InputEvent) -> void:
	if game == null or game.ended:
		return
	if game.arrive_t >= 0.0:
		# The train is still coming in: a touch only brings it to its stand.
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			game.skip_arrival()
			get_viewport().set_input_as_handled()
		return
	if _modal_input(event):
		get_viewport().set_input_as_handled()
		return
	if modal_open:
		if event.is_action_pressed("ui_cancel"):
			if modal_pane != null:
				_close_modal()
			get_viewport().set_input_as_handled()
		# No field input under any panel (decision 532). The GUI keeps the
		# first finger inside; extra fingers use the same pane hit test.
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
	if game == null or game.ended or modal_open:
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
	if modal_open:
		return true
	# The same index again means its lift was lost (the app went away): let the
	# old stick go before the new finger is read.
	if fingers.has(index) and fingers[index]["kind"] == "stick":
		fingers.erase(index)
		stick_index = -1
		stick_dash = false
		_stick_release()
	if offer_box.get_child_count() > 0:
		# The last child is drawn on top; its full touch rect wins over every pad.
		for choice_index: int in range(offer_box.get_child_count() - 1, -1, -1):
			var choice: Button = offer_box.get_child(choice_index) as Button
			if choice != null and choice.is_visible_in_tree() and touch_rect(choice).has_point(pos):
				fingers[index] = {"kind": "button", "button": choice, "start": pos}
				return true
		# Only new presses are blocked. Existing pad fingers keep their move/lift rules.
		for covered: Button in [depart_button, shove_button, attack_button, aim_button, manual_button]:
			if covered.is_visible_in_tree() and touch_rect(covered).has_point(pos):
				return true
	for b in pads:
		if b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			if _pad_blocked(b):
				return true
			fingers[index] = {"kind": "pad", "pad": b, "start": pos, "ms": Time.get_ticks_msec()}
			_pad_down(b, pos)
			return true
	# The portrait: a tap opens the body picture (on the lift, if it never moved).
	if portrait.get_global_rect().has_point(pos):
		fingers[index] = {"kind": "portrait", "start": pos}
		return true
	# The clock, or a goal or promise line that is down: a tap folds it (or
	# opens the clock), on the lift.
	var glass: Control = _fold_at(pos)
	if glass != null:
		fingers[index] = {"kind": "fold", "start": pos, "glass": glass}
		return true
	if _by_stick_keys(pos):
		return true
	var ui := _button_at(pos)
	if ui != null:
		if index != 0:
			fingers[index] = {"kind": "button", "button": ui, "start": pos, "off": ui.disabled}
			return true
		return false
	# Nothing drawn under the finger: a small key whose 48 dp skirt holds it
	# takes it, the nearer where two skirts meet (user 2026-10-24). The first
	# finger as well: Godot sees no button there.
	var near: Control = _skirt_at(pos)
	if near != null:
		if pads.has(near):
			if _pad_blocked(near as Button):
				return true
			fingers[index] = {"kind": "pad", "pad": near, "start": pos, "ms": Time.get_ticks_msec()}
			_pad_down(near as Button, pos)
		elif near == portrait:
			fingers[index] = {"kind": "portrait", "start": pos}
		elif near is Button:
			fingers[index] = {"kind": "button", "button": near, "start": pos, "off": (near as Button).disabled}
		else:
			fingers[index] = {"kind": "fold", "start": pos, "glass": near}
		return true
	if _stick_down(index, pos):
		return true
	if fingers.values().any(func(f): return f["kind"] == "hand"):
		return false
	fingers[index] = {"kind": "hand", "start": pos}
	_press(pos)
	return true


## The stick takes a finger set down in its reach (the left half when it floats).
func _stick_down(index: int, pos: Vector2) -> bool:
	var floats := stick_floats()
	var in_reach: bool = pos.x < _view_size().x * 0.5 if floats else pos.distance_to(stick_home()) <= STICK_R * STICK_CATCH
	if not in_reach or stick_index >= 0:
		return false
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


## A ring 4 mm round the keys over the stick (run, and the lamp after dark)
## starts nothing: setting the stick down there must not toggle them, nor
## plant a stick on their edge.
func _by_stick_keys(pos: Vector2) -> bool:
	for b in [run_button, lamp_button]:
		if b.is_visible_in_tree() and b.get_global_rect().grow(4.0 * PX_PER_MM).has_point(pos):
			return true
	return false


## Own each modal gesture until its lift, even if another finger closes or
## rebuilds the pane. Outside taps close only glass panes with a fold key.
## A touch-generated mouse is consumed along with its outside first finger.
func _modal_input(event: InputEvent) -> bool:
	if event.device == InputEvent.DEVICE_ID_EMULATION and modal_emulated_blocked:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			modal_emulated_blocked = false
		return true
	var index: int = -1
	var pos: Vector2 = Vector2.ZERO
	var down: bool = false
	var up: bool = false
	var canceled: bool = false
	if event is InputEventScreenTouch:
		index = event.index
		pos = event.position
		down = event.pressed
		up = not event.pressed
		canceled = event.canceled
	elif event is InputEventScreenDrag:
		index = event.index
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# A real mouse has its own slot, separate from touch index zero.
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventMouseMotion:
		pos = event.position
	else:
		return false
	if down and not canceled:
		modal_fingers.erase(index)
		if event is InputEventScreenTouch and index == 0:
			modal_emulated_blocked = false
		if not modal_open:
			return false
		var outside: bool = modal_pane != null and not modal_pane.get_global_rect().has_point(pos)
		var manual: bool = event is InputEventScreenTouch and index > 0 and not outside
		modal_fingers[index] = {"owner": modal, "outside": outside, "manual": manual, "start": pos, "ms": Time.get_ticks_msec(), "dragged": false}
		if outside:
			if event is InputEventScreenTouch and index == 0:
				modal_emulated_blocked = true
			return true
		if manual:
			var under: Dictionary = _pane_under(modal, pos)
			var list: ScrollContainer = under["scroll"]
			var key: Button = under["button"]
			fingers[index] = {"kind": "button", "button": key, "start": pos, "off": key != null and key.disabled, "scroll": list, "from": list.scroll_vertical if list != null else 0, "dragged": false}
			return true
		return false
	if not modal_fingers.has(index):
		return false
	var held: Dictionary = modal_fingers[index]
	if up or canceled:
		modal_fingers.erase(index)
	if canceled or held.get("owner") == null or held["owner"] != modal:
		finger_cancel(index)
		return true
	if pos.distance_to(held["start"]) >= DRAG_PX:
		held["dragged"] = true
	if held["outside"]:
		if up and not held["dragged"] and Time.get_ticks_msec() - int(held["ms"]) < 350 and modal_pane != null and not modal_pane.get_global_rect().has_point(pos):
			_close_modal()
		return true
	if held["manual"]:
		return finger_up(index, pos) if up else finger_move(index, pos)
	return false


func _bag_up() -> bool:
	return modal_open and is_instance_valid(box_pane) and modal == box_pane


## The key and the list under a finger on a pane; a list holds only what
## shows through it (a row scrolled out of it is not under the finger).
func _pane_under(pane: Control, pos: Vector2) -> Dictionary:
	var under := {"button": null, "scroll": null}
	var stack: Array = [pane]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is ScrollContainer:
			if not n.get_global_rect().has_point(pos):
				continue
			under["scroll"] = n
		if n is Button and n.mouse_filter != Control.MOUSE_FILTER_IGNORE and n.is_visible_in_tree() and n.get_global_rect().has_point(pos):
			under["button"] = n
		for c in n.get_children():
			if c is Control and c.visible:
				stack.append(c)
	return under


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
		"button":
			# A finger on the bag pane drags its list once it goes past a tap.
			var list: Variant = f.get("scroll")
			if is_instance_valid(list) and (f["dragged"] or pos.distance_to(f["start"]) >= DRAG_PX):
				f["dragged"] = true
				var scroll: ScrollContainer = list
				scroll.scroll_vertical = int(f["from"]) - int(pos.y - f["start"].y)
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
			# A bag pane finger may hold no key (a gap in a list), or one laid away
			# since, or have dragged its list, or have come down on a key still off
			# (it may wake before the lift): then the lift presses nothing.
			var held: Variant = f["button"]
			if not is_instance_valid(held) or f.get("dragged", false) or f.get("off", false):
				return true
			var b: Button = held
			if not b.disabled and b.is_visible_in_tree() and touch_rect(b).has_point(pos):
				if b.toggle_mode:
					b.button_pressed = not b.button_pressed
				b.pressed.emit()
		"hand":
			_release(pos)
		"portrait":
			if pos.distance_to(f["start"]) < DRAG_PX and touch_rect(portrait).has_point(pos):
				body_panel()
		"fold":
			var glass: Control = f["glass"]
			if pos.distance_to(f["start"]) < DRAG_PX and touch_rect(glass).has_point(pos):
				_fold(glass)
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
			for b in [aim_button, context_button, depart_button, shove_button]:
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


## The glass a tap folds or opens: the clock, or a goal or promise line that is
## down (its key takes it up as well).
func _fold_at(pos: Vector2) -> Control:
	for g: Control in _fold_glasses():
		if g.is_visible_in_tree() and g.get_global_rect().has_point(pos):
			return g
	return null


func _fold_glasses() -> Array:
	var glasses: Array = [clock_pill, promise_label.get_parent()]
	if goal_label != null:
		glasses.append(goal_label.get_parent())
	return glasses


func _fold(glass: Control) -> void:
	if glass == clock_pill:
		set_clock_open(not clock_open)
	elif glass == promise_label.get_parent():
		set_promise_open(false)
	else:
		set_goal_open(false)


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


## Where a finger takes a key: its drawn rect, a side shorter than MIN_TOUCH
## grown evenly to it. What is drawn stays as it is.
func touch_rect(c: Control) -> Rect2:
	var r: Rect2 = c.get_global_rect()
	var gx: float = maxf(MIN_TOUCH - r.size.x, 0.0) * 0.5
	var gy: float = maxf(MIN_TOUCH - r.size.y, 0.0) * 0.5
	return r.grow_individual(gx, gy, gx, gy)


## The key whose touch rect holds the point, the one whose drawn edge is
## nearest first: the pads, the portrait, the folding glass, every ordinary
## button.
func _skirt_at(pos: Vector2) -> Control:
	var keys: Array = pads.filter(func(b: Button) -> bool: return b.is_visible_in_tree())
	for c: Control in [portrait] + _fold_glasses():
		if c.is_visible_in_tree():
			keys.append(c)
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is Button and n.mouse_filter != Control.MOUSE_FILTER_IGNORE and n.is_visible_in_tree():
			keys.append(n)
		for c in n.get_children():
			if c is Control and c.visible:
				stack.append(c)
	var best: Control = null
	var best_gap: float = INF
	for k: Control in keys:
		if not touch_rect(k).has_point(pos):
			continue
		var gap: float = _gap_to(k.get_global_rect(), pos)
		if gap < best_gap:
			best = k
			best_gap = gap
	return best


static func _gap_to(r: Rect2, p: Vector2) -> float:
	var dx: float = maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
	var dy: float = maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
	return Vector2(dx, dy).length()


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
	# The camera is turned (field_game.gd CAM_YAW): the push on the screen turns
	# with it onto the ground, so up on the stick is up on the screen.
	var push := clampf(v.length() / STICK_R, 0.0, 1.0)
	var dir: Vector2 = game.screen_dir(v.normalized())
	stick_push = push
	if fighting(p):
		# A resting thumb, or a push at the one being hit, keeps the fight going;
		# a real push elsewhere calls it off (field_unified 10).
		var to := _fight_dir(p)
		if push < STICK_STOPS_FIGHT or (to != Vector2.ZERO and dir.dot(to) > 0.7):
			p.stick = Vector2.ZERO
			return
		stop_fight(p)
	p.stick = dir * push
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
		_load_walk_note(p)


## Running asked for under a load that does not let one run (card G 가): why,
## once in a while, and the feet walk.
func _load_walk_note(p) -> void:
	if p.load_lets_run() or game.clock.elapsed - load_walk_said < LOAD_WALK_EVERY:
		return
	load_walk_said = game.clock.elapsed
	for id: String in p.items:
		if int(p.items[id]) > 0 and Carry.item_weight(id) >= Carry.BIG_THING and not W.is_known(id):
			toast("%s을(를) 안고는 못 뛴다 · 걷는다" % game.item_name(id))
			return
	toast("짐이 넘쳐 못 뛴다 · 걷는다")


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

## Custom touch hit testing must respect the same lock as native buttons.
func _pad_blocked(b: Button) -> bool:
	var p: Variant = game.player
	if b == shove_button and not p.grabbers.is_empty():
		return false
	return b.disabled or (p.sled_weapon_stowed and b in [attack_button, aim_button, shove_button, manual_button])


func _pad_down(b: Button, pos: Vector2) -> void:
	if _pad_blocked(b):
		return
	var p = game.player
	if b == aim_button and primary_melee(p):
		b = attack_button
	if status_pads.has(b):
		var slot: int = status_pads.find(b)
		if slot < status_rows.size():
			toast(status_line(status_rows[slot]))
			# The window's answer is on the body picture: it opens at the limb to cut.
			var cuts: Array = p.body.cut_parts()
			if String(status_rows[slot]["id"]) == "infection" and not cuts.is_empty() and p.body.window_left > 0.0:
				body_panel(p, String(cuts[0]))
		return
	if b == blood_button:
		# Say what the press does: it was pressed without knowing (build 47).
		var worst: int = p.body._top_bleeder()
		if worst >= 0 and p.action == "" and p.can_act():
			toast("지혈 중: %s" % Treatment.wound_text(p.body.wounds[worst]))
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
			# Nobody in reach: swing at the air all the same (decision 405).
			game.combat.swing_air(p)
			return
		_melee(t, true)
		attack_button.button_pressed = true
	elif b == context_button:
		context_button.button_pressed = true
	elif b == depart_button:
		depart_button.button_pressed = true
	elif b == pause_button:
		_toggle_pause()
	elif b == all_aboard_button:
		_all_aboard()
	elif b == follow_button:
		_order_all(String(COMMANDS[0][0]))
	elif b == wait_button:
		_order_all(String(COMMANDS[1][0]))
	elif b == settings_button:
		settings_panel()
	elif b == lamp_button:
		game.set_lamps(not game.lamps_on())
		lamp_button.button_pressed = game.lamps_on()
		toast("등불 켬" if game.lamps_on() else "등불 끔")
	elif b == manual_button:
		manual_button.button_pressed = not manual_button.button_pressed
		toast("수동 조준" if manual_button.button_pressed else "자동 조준")
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
	if _pad_blocked(b):
		return
	if b == lever_button:
		# Pulled down it opens, pushed up it folds, as the thumb goes.
		var dy: float = pos.y - Vector2(f["start"]).y
		if absf(dy) >= LEVER_PULL:
			f["pulled"] = true
			if (dy > 0.0) != orders_open:
				set_orders_open(dy > 0.0)
		return
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
	if _pad_blocked(b):
		if b in [attack_button, aim_button, shove_button]:
			b.button_pressed = false
		return
	if b == aim_button and primary_melee(game.player):
		return
	if b == aim_button:
		aim_button.button_pressed = false
		_auto_aim_end(pos)
	elif b == context_button:
		context_button.button_pressed = false
		if not f.get("opened", false) and touch_rect(b).has_point(pos):
			_context_tap()
	elif b == depart_button:
		depart_button.button_pressed = false
		if touch_rect(b).has_point(pos) and not game.ended:
			depart_card()
	elif b == shove_button:
		shove_button.button_pressed = false
	elif b == run_button and run_hold():
		_run_key_up()
	elif b == lever_button:
		# A tap flips it; a pull or a push did its work as the thumb went.
		if not f.get("pulled", false) and touch_rect(b).has_point(pos):
			set_orders_open(not orders_open)


## Hold the aim pad: the gun comes up and, after a moment that shortens with
## shooting skill, settles on the nearest threat ahead (field_unified 10).
func _auto_aim_start() -> void:
	var p = game.player
	if not W.is_ranged(p.weapon_id()):
		toast("총 없음")
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
		# Nothing picked: the shot goes where the gun points (decision 405).
		if not aim_cancel:
			game.combat.fire(p, aim_point, aim_target)
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
	# If it does lift after a pane opened, consume it without a tap or shot.
	for held_index: int in modal_fingers:
		modal_fingers[held_index] = {"owner": null}
	for index: int in fingers:
		modal_fingers[index] = {"owner": null}
	if fingers.has(0):
		modal_fingers[-1] = {"owner": null}
		modal_emulated_blocked = true
	fingers.clear()
	stick_index = -1
	auto_aim = false
	auto_free = false
	stick_dash = false
	if run_button != null and run_hold():
		run_button.button_pressed = false
	if game.player != null:
		_stick_release()
	for b in [aim_button, shove_button, context_button, depart_button]:
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
		# A blade, a club or bare hands in hand: no aim and no 'manual' (decision
		# 293; aim only ever takes up a gun that is in hand). A held aim stays.
		var gun: bool = W.is_ranged(p.weapon_id()) or auto_aim
		aim_button.visible = gun
		manual_button.visible = gun
		return
	var melee := primary_melee(p)
	attack_button.visible = false
	manual_button.visible = not melee
	# A with a blade in hand, as attack shows; the aim mark alone with a gun
	# (user 2026-10-18), never the two at once.
	var word: String = "A" if melee else ""
	if aim_button.text != word:
		aim_button.text = word
		if melee:
			aim_button.icon = null
			_letter(aim_button, ATTACK_LETTER)
			_nudge(aim_button, LETTER_NUDGE)
		else:
			_set_icon(aim_button, "aim", ATTACK_ICON)
			_nudge(aim_button, 0.0)
	if melee:
		aim_button.button_pressed = fighting(p)


## The player is in a one-press fight: still after someone, swinging on.
func fighting(p) -> bool:
	return game.combat.fighting(p)


func stop_fight(p) -> void:
	game.combat.stop_fight(p)
	attack_button.button_pressed = false


## Ground direction (x, z) from the player to the one being hit.
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
		var d: float = _finger_off(world, z["pos"])
		if d < best_d:
			best_d = d
			best = z
	for r in game.raiders:
		if r.visible and game.combat.hostile(r):
			var d: float = _finger_off(world, r.position)
			if d < best_d:
				best_d = d
				best = r
	return best


## How far the finger's line on the screen passes from a body standing at base,
## on the ground, at its nearest between the feet and the head. The finger is on
## your floor; a body on another floor sits elsewhere on the screen. Read at the
## feet alone, a press on the chest landed 1.4 m off once the camera leaned to 35°.
## tall: how high the thing stands (a body by default).
func _finger_off(world: Vector3, base: Vector3, tall: float = BODY_H) -> float:
	var at: Vector3 = game.shift_to_height(world, base.y)
	var rise: Vector3 = game.shift_to_height(world, base.y + 1.0) - at
	var off := Vector2(at.x - base.x, at.z - base.z)
	var step := Vector2(rise.x, rise.z)
	var h := 0.0
	if step.length_squared() > 0.000001:
		h = clampf(-off.dot(step) / step.length_squared(), 0.0, tall)
	return (off + step * h).length()


## Where the finger's line enters a box standing in base's cell, up to tall: the
## highest point of the line inside it (the first it meets from the camera), or
## -INF when the line passes by.
func _enters_at(world: Vector3, base: Vector3, tall: float) -> float:
	var at: Vector3 = game.shift_to_height(world, base.y)
	var rise: Vector3 = game.shift_to_height(world, base.y + 1.0) - at
	var lo := 0.0
	var hi := tall
	for axis in [0, 2]:
		var o: float = at[axis] - base[axis]
		var s: float = rise[axis]
		if absf(s) < 0.000001:
			if absf(o) > 0.5:
				return -INF
			continue
		var a := (-0.5 - o) / s
		var b := (0.5 - o) / s
		lo = maxf(lo, minf(a, b))
		hi = minf(hi, maxf(a, b))
	return base.y + hi if lo <= hi else -INF


func _box_h(c: Dictionary) -> float:
	var kind := String(c.get("furniture", ""))
	if kind == "":
		return BOX_LOOSE_H
	return BOX_TALL_H if RoomFurnish.TALL_KINDS.has(kind) else BOX_H


## The box under the finger (decision 476), on the floor the finger is on: of the
## boxes whose drawn furniture (its cell, up to _box_h) the finger's line passes
## through, the one it meets first; else the one the line passes nearest, within
## 1.0 m. Read at the floor alone, a press on a counter's top landed 1.3 m behind
## it once the camera leaned to 35°, and the first box within reach won over the
## nearest, so a row of counters opened the one next to the one pressed.
func _pick_box(world: Vector3) -> String:
	var first := ""
	var first_y := -INF
	var near := ""
	var near_d := 1.0
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		var at: Vector3 = game.lift(c["cell"], int(c.get("level", 0)))
		if absf(at.y - world.y) > 0.1:
			continue
		var tall := _box_h(c)
		var y := _enters_at(world, at, tall)
		if y > first_y:
			first_y = y
			first = String(id)
		var d := _finger_off(world, at, tall)
		if d < near_d:
			near_d = d
			near = String(id)
	return first if first != "" else near


## The ally (or the ground thing) the finger's line passes nearest, within reach:
## the same rule as the boxes, nearest and not first, a body read feet to head.
func _pick_ally(world: Vector3):
	var best = null
	var best_d := 0.8
	for row in ally_buttons:
		var o = row["p"]
		if o.is_alive():
			var d := _finger_off(world, o.position)
			if d < best_d:
				best_d = d
				best = o
	return best


func _pick_item(world: Vector3) -> int:
	var best := -1
	var best_d := 0.9
	for i in range(game.ground_items.size()):
		var d := _finger_off(world, game.ground_items[i]["pos"], ITEM_H)
		if d < best_d:
			best_d = d
			best = i
	return best


func _tap(pos: Vector2) -> void:
	var p = game.player
	var world: Vector3 = game.screen_to_ground(pos)
	if game.actions.on_signal_top(p):
		offer([{"label": "내려가기", "call": game.actions.ladder.bind(p, "fast")}])
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
	var ally = _pick_ally(world)
	if ally != null:
		_ally_menu(ally)
		return true
	var item := _pick_item(world)
	if item >= 0:
		_go_and_do(p, "item", item, game.ground_items[item]["pos"])
		return true
	var box := _pick_box(world)
	if box != "":
		var c: Dictionary = game.data["containers"][box]
		_go_and_do(p, "container", box, game.lift(c["cell"], int(c.get("level", 0))))
		return true
	# Stairs: a tap on them goes up (or down) them.
	var lv: int = game.level_of(p.position)
	for s in game.stairs:
		if not (s["low"] == lv or s["high"] == lv):
			continue
		if s["ladder"]:
			# A rooftop's ladder: walk to its foot (or top) and climb it.
			if s.has("roof") and game.lift(s["cell"], lv).distance_to(world) < 1.0:
				game.actions.go_and_do(p, "ladder", s, game.lift(s["cell"], lv))
				return true
			continue
		if game.lift(s["cell"], lv).distance_to(world) < 1.0:
			if _assist_off(p):
				return true
			game.actions.take_stairs(p, s)
			if not p.path.is_empty():
				dest_marker = p.path[p.path.size() - 1]
			return true
	if lv != 0:
		return false
	for id in game.data["spots"]:
		var spot: Dictionary = game.data["spots"][id]
		if FieldGrid.center(spot["cell"]).distance_to(world) < 1.3:
			_go_and_do(p, "spot", id, FieldGrid.center(spot["cell"]))
			return true
	for key: String in game.data["manholes"]:
		var lid_at: Vector3 = FieldGrid.center(game.data["manholes"][key])
		if game.FieldMaps.lid(key) and lid_at.distance_to(world) < 1.0:
			_go_and_do(p, "manhole", key, lid_at)
			return true
	for c in [cell, cell + Vector2i(1, 0), cell + Vector2i(-1, 0), cell + Vector2i(0, 1), cell + Vector2i(0, -1)]:
		if game.grid.doors.has(c) and FieldGrid.center(c).distance_to(world) < 0.9:
			var door: Dictionary = game.grid.doors[c]
			if door["state"] == "locked" and not game.actions.has_pry(p):
				offer([{"label": "문 차기", "call": _go_and_do.bind(p, "door", c, FieldGrid.center(c), "kick")}])
				return true
			_go_and_do(p, "door", c, FieldGrid.center(c))
			return true
		if game.grid.windows.has(c) and FieldGrid.center(c).distance_to(world) < 0.9:
			_go_and_do(p, "window", c, FieldGrid.center(c))
			return true
	return false


## A tap's walk-and-do (user decision 330): off while the dead are near;
## then only the stick and the pads, and the tap says so in a word.
func _assist_off(p) -> bool:
	if not game.combat.tap_assist_off(p):
		return false
	toast("망자 가까움")
	return true


func _go_and_do(p, kind: String, key, at: Vector3, verb: String = "") -> void:
	if _assist_off(p):
		return
	game.actions.go_and_do(p, kind, key, at, verb)


# ---------------------------------------------------------------- overlay

func _project(at: Vector3) -> Vector2:
	return game.camera.unproject_position(at)


## A separate canvas lets the stick dim with the sleeping HUD (decision 532)
## without dimming world cues, speech or aiming marks on the overlay.
func _draw_stick() -> void:
	if game == null or game.player == null or game.ended:
		return
	var fixed: bool = not stick_floats()
	if fixed or stick_index >= 0:
		var base: Vector2 = stick_home() if fixed else stick_origin
		var held: bool = stick_index >= 0
		var knob: Vector2 = base + ((stick_at - base).limit_length(STICK_R) if held else Vector2.ZERO)
		HudSkin.draw_stick(touch, base, knob, STICK_RING, STICK_KNOB, held, game.player.running)


func _draw_overlay() -> void:
	if game == null or game.player == null:
		return
	var p = game.player
	var view_size: Vector2 = overlay.size
	var now: float = game.clock.elapsed
	# The stop is over (the leave beat, the end): its cues go with the pads (the
	# stick, the tells, the arrows at the edge); what those left behind shout stays.
	if game.ended:
		_draw_says(view_size)
		return
	_draw_tells()
	_draw_says(view_size)
	# The last call: the count, big, where nobody can miss it. The same place
	# says, for a few seconds, that the train is ready.
	var big: String = "채비 끝 · 출발 가능" if game.holdout.on and game.holdout.ready_shown > 0.0 else ""
	if game.holdout.calling or big != "":
		var count: String = str(int(ceil(maxf(game.holdout.call_left, 0.0)))) if game.holdout.calling else big
		var size: int = LAST_CALL_FONT if game.holdout.calling else READY_FONT
		var f: Font = theme.default_font
		var w: float = f.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2((view_size.x - w) * 0.5, view_size.y * 0.3)
		overlay.draw_string_outline(f, at, count, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(0, 0, 0, 0.85))
		overlay.draw_string(f, at, count, HORIZONTAL_ALIGNMENT_LEFT, -1, size, AMBER)
	# Pressure at the edges: no numbers, just a darker rim as the next horde nears.
	var pressure: float = game.director.pressure(now)
	if pressure > 0.5 and game.deaf_t <= 0.0:
		var a := (pressure - 0.5) * 0.35
		overlay.draw_rect(Rect2(Vector2.ZERO, Vector2(view_size.x, 18)), Color(0.25, 0.05, 0.04, a))
		overlay.draw_rect(Rect2(Vector2(0, view_size.y - 18), Vector2(view_size.x, 18)), Color(0.25, 0.05, 0.04, a))
	# Walk target.
	if p.moving and not p.path.is_empty() and dest_marker != Vector3.INF:
		overlay.draw_arc(_project(dest_marker), 10.0, 0, TAU, 20, Color(1, 1, 1, 0.5), 2.0)
	# Something come up out of the snow (decision 423 card 11): a small light
	# that comes and goes on it, no word and no key.
	var glow: float = 0.45 + 0.4 * sin(now * GLINT_PULSE)
	for g: Dictionary in game.ground_items:
		if bool(g.get("glint", false)) and game.level_shown(game.level_of(g["pos"])):
			var at := _project(g["pos"])
			overlay.draw_circle(at, 3.0, Color(1, 1, 1, glow))
			overlay.draw_arc(at, 7.0 + 2.0 * glow, 0, TAU, 18, Color(1, 1, 1, glow * 0.6), 1.5)
	# Where a thrown tin came down, a moment (P22).
	for m: Dictionary in game.lure_marks:
		var fade: float = 1.0 - (now - float(m["t"])) / game.LURE_MARK_S
		overlay.draw_arc(_project(m["pos"]), 12.0, 0, TAU, 24, Color(1, 0.85, 0.6, 0.8 * fade), 2.0)
	# Sharp shooters see the dangerous ones marked while aiming (not chosen for them).
	if auto_aim and int(p.skills.get("shooting", 0)) >= 7:
		for z in game.zombies.list:
			if z != aim_target and game.combat.marks_danger(p, z) and game.cell_seen(z["pos"]):
				var m := _project(z["pos"] + Vector3(0, 2.1, 0))
				overlay.draw_colored_polygon(PackedVector2Array([m + Vector2(-7, -10), m + Vector2(7, -10), m + Vector2(0, 0)]), Color(1, 0.75, 0.4, 0.9))
	# What the auto aim has settled on.
	if auto_aim and aim_target != null:
		var at: Vector3 = game.zombies.seen_pos(aim_target) if aim_target is Dictionary else aim_target.position
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
			# Its mark under the ring, not a word (결정 417): the gun goes down.
			overlay.draw_texture_rect(HudIcons.texture("down", 18, col, 2.0), Rect2(me + Vector2(-9, AIM_CANCEL_PX + 4), Vector2(18, 18)), false)
	for row in game.people:
		if row.aim.active and row != p and row.visible:
			var t = row.brain.get("target")
			if row.team == "raider" and t != null and row.brain.get("aiming", false):
				overlay.draw_line(_project(row.position + Vector3(0, 1.3, 0)), _project(t.position + Vector3(0, 1.0, 0)), Color(0.95, 0.25, 0.2, 0.65), 2.0)
	for tr in game.combat.tracers:
		overlay.draw_line(_project(tr["from"]), _project(tr["to"]), Color(1, 0.92, 0.6, clampf(tr["t"] / 0.12, 0, 1)), 2.0)
	_draw_sounds(now)
	if game.deaf_t > 0.0:
		overlay.draw_string(theme.default_font, Vector2(view_size.x * 0.5 - 60, 92), "귀 먹먹함", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))
		return
	_draw_edges(view_size)


## The sound of an action at the moment it is made, over where it was made: a
## wifi mark (user 2026-10-18), one more of its dot and arcs lit for each of
## the four levels, warm from loud on.
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
		var col := Color(1, 0.6, 0.45, a) if lvl >= SimNoise.Level.LOUD else Color(1, 1, 1, a)
		_draw_wifi(c + Vector2(0, -2), Vector2.UP, lvl + 1, col)


## A wifi mark: a dot at `at` and three arcs opening toward `dir`, the first
## `lit` of the four in `col` and the rest faint, each over a dark edge so it
## reads on snow.
func _draw_wifi(at: Vector2, dir: Vector2, lit: int, col: Color) -> void:
	var a: float = dir.angle()
	for i in WIFI_ARCS.size() + 1:
		var on: bool = i < lit
		var ink := Color(col.r, col.g, col.b, col.a * (1.0 if on else 0.22))
		var edge := Color(0, 0, 0, col.a * (0.45 if on else 0.2))
		if i == 0:
			overlay.draw_circle(at, WIFI_DOT + 1.2, edge, true, -1.0, true)
			overlay.draw_circle(at, WIFI_DOT, ink, true, -1.0, true)
			continue
		var r: float = WIFI_ARCS[i - 1]
		overlay.draw_arc(at, r, a - WIFI_SPAN, a + WIFI_SPAN, 16, edge, WIFI_W + 2.0, true)
		overlay.draw_arc(at, r, a - WIFI_SPAN, a + WIFI_SPAN, 16, ink, WIFI_W, true)


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
	var keep: Array[Rect2] = []
	if not groups.is_empty() or not game.rattle.is_empty():
		keep = hud_rects()
	# A horde shows its sound mark, no word (user 2026-10-18: 「신음 저거 삭제」).
	for k in groups:
		var g: Dictionary = groups[k]
		_edge_arrow(center, view_size, g["sum"] / float(g["n"]), "", keep)
	for key in game.rattle:
		var at: Vector3 = FieldGrid.center(game.data["manholes"][key])
		if not game.camera.is_position_in_frustum(at):
			_edge_arrow(center, view_size, at, "덜컹", keep)


## The HUD's own pieces on screen now (keys, state icons, glass, notes, the
## stick's ring), for what is drawn on the world to keep clear of them.
func hud_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for b: Button in pads:
		if b.is_visible_in_tree():
			out.append(b.get_global_rect())
	for c: Control in [top_panel, portrait, bag_box, radio_pill, allies_box, crew_button, fold_keys, test_keys]:
		if c != null and c.is_visible_in_tree():
			out.append(c.get_global_rect())
	for row in ally_buttons:
		var card: Control = row["card"]
		if card.is_visible_in_tree():
			out.append(card.get_global_rect())
	for box: Control in [toast_box, info_box]:
		for c in box.get_children():
			if c is Control and (c as Control).is_visible_in_tree():
				out.append((c as Control).get_global_rect())
	out.append(Rect2(stick_home() - Vector2.ONE * STICK_RING, Vector2.ONE * STICK_RING * 2.0))
	return out


## The spot an edge arrow toward `at` takes: on its ray from the middle, as far
## out as the margin lets it, then in along the ray until neither it nor its
## word (with no word, its sound mark) touches one of `keep` (user 2026-10-18:
## no piece of the HUD over another). Vector2.INF when `at` is straight ahead.
func edge_tip(center: Vector2, view_size: Vector2, at: Vector3, text: String, keep: Array[Rect2] = []) -> Vector2:
	var dir := _project(at) - center
	if dir.length() < 1.0:
		return Vector2.INF
	dir = dir.normalized()
	var margin := 46.0
	var half := view_size * 0.5 - Vector2(margin, margin)
	var t := minf(absf(half.x / dir.x) if absf(dir.x) > 0.001 else 1e9, absf(half.y / dir.y) if absf(dir.y) > 0.001 else 1e9)
	var f: Font = UiFonts.face(UiFonts.WORD, 500, 1.2)
	var fs: float = UiFonts.size(12)
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
	while t > EDGE_IN_MIN:
		var tip := center + dir * t
		var word := Rect2(tip - dir * 40.0 - Vector2(w * 0.5 + 4.0, fs), Vector2(w + 8.0, fs * 2.0))
		if text == "":
			# The sound mark's dot 42 back from the tip, its arcs toward it.
			word = Rect2(tip - dir * 33.0 - Vector2(17.0, 17.0), Vector2(34.0, 34.0))
		var cue := word.merge(Rect2(tip - Vector2(16.0, 16.0), Vector2(32.0, 32.0)))
		if not keep.any(func(r: Rect2) -> bool: return r.intersects(cue)):
			break
		t -= EDGE_STEP
	return center + dir * maxf(t, EDGE_IN_MIN)


## The dead that have dropped low and will run, of those in sight.
func tells() -> Array:
	var out: Array = []
	for z in game.zombies.list:
		if z["state"] == "tell" and game.cell_seen(z["pos"]):
			out.append(z)
	return out


## Over each of them, a ring that closes as its beat runs out, and a mark.
func _draw_tells() -> void:
	for z in tells():
		var left: float = clampf(float(z["t"]) / LungerRules.TELL, 0.0, 1.0)
		var at: Vector2 = _project(z["pos"] + Vector3(0, 1.0, 0))
		overlay.draw_arc(at, lerpf(TELL_RING_IN, TELL_RING_OUT, left), 0, TAU, 32, AMBER, 3.0)
		var head: Vector2 = _project(z["pos"] + Vector3(0, 2.3, 0))
		var w: float = theme.default_font.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, TELL_FONT).x
		overlay.draw_string(theme.default_font, head - Vector2(w * 0.5, 0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, TELL_FONT, AMBER)


## A word on the world, centred on `at`, with a dark shadow round it (시안
## .fedge: Plex 12, wide apart).
func _shadowed_word(text: String, at: Vector2, col: Color) -> void:
	var f: Font = UiFonts.face(UiFonts.WORD, 500, 1.2)
	var fs: int = UiFonts.size(12)
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base: Vector2 = at + Vector2(-w * 0.5, fs * 0.36)
	overlay.draw_string_outline(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.72 * col.a))
	overlay.draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _edge_arrow(center: Vector2, view_size: Vector2, at: Vector3, text: String, keep: Array[Rect2] = []) -> void:
	var tip: Vector2 = edge_tip(center, view_size, at, text, keep)
	if tip == Vector2.INF:
		return
	var dir: Vector2 = (tip - center).normalized()
	var side := Vector2(-dir.y, dir.x)
	var col := OMEN_COL
	var head := PackedVector2Array([tip + dir * 14.0, tip - dir * 8.0 + side * 10.0, tip - dir * 8.0 - side * 10.0])
	var shade := PackedVector2Array()
	for q in head:
		shade.append(q + (q - tip).normalized() * 2.0 + Vector2(0, 1))
	overlay.draw_colored_polygon(shade, Color(0, 0, 0, 0.6))
	overlay.draw_colored_polygon(head, col)
	if text == "":
		_draw_wifi(tip - dir * 42.0, dir, WIFI_ARCS.size() + 1, col)
	else:
		_shadowed_word(text, tip - dir * 40.0, col)
