extends Control
## A short world introduction on one sheet over the first train screen of a
## new slice. Its lamp key puts only this sheet away; the flow stays on the
## train. The words live here so the draft can be replaced in one place.

signal went_on

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const Paper = preload("res://game/ui/paper_parts.gd")
const PaperSheet = preload("res://game/ui/paper_sheet.gd")
const LampKey = preload("res://game/ui/lamp_key.gd")

const KICK: String = "열차에 오르기 전에"
const TEXT: String = "겨울이 끝나지 않는다. 죽은 이들이 일어나 걷기 시작한 뒤로, 사람이 모여 사는 곳은 선로를 달리는 이 열차뿐이다. 칸마다 사람들은 저마다의 몫을 따지고, 엔진이 식으면 모두 얼어 죽는다. 이 열차를 끌고 갈 사람은 열차장이다."
const GO_WORD: String = "출발"
## Fixed room for the draft, in the same mockup px as the other papers.
const SHEET_SIZE: Vector2 = Vector2(446, 270)
## The end card's dim and the short rise used when its words come up.
const DIM: Color = Color(2 / 255.0, 4 / 255.0, 6 / 255.0, 0.78)
const DIM_S: float = 0.7
const SHOW_S: float = 0.4
const RISE_CSS: float = 5.0

var still: bool = false
var sheet: PaperSheet
var body: Label
var go_key: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	sheet = PaperSheet.new(SHEET_SIZE)
	sheet.name = "Sheet"
	add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var kick: HBoxContainer = Paper.line_box(24.0)
	kick.name = "Kick"
	sheet.inner.add_child(kick)
	kick.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	kick.offset_bottom = UiFonts.px(24.0)
	var heading: Label = Paper.ink(KICK, UiFonts.NUMBER, 500, 10.0, Paper.INK2, 0.8)
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kick.add_child(heading)
	# The paragraph has a fixed room: longer copy must fail the fit check,
	# rather than push the paper or the key past the screen.
	var text_room: Control = Control.new()
	text_room.name = "TextRoom"
	text_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_room.clip_contents = true
	sheet.inner.add_child(text_room)
	text_room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_room.offset_top = UiFonts.px(36.0)
	text_room.offset_bottom = -UiFonts.px(60.0)
	body = Paper.ink(UiFonts.keep_all(TEXT), UiFonts.WORD, 400, 12.0, Paper.INK2)
	body.name = "Text"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var font: Font = body.get_theme_font("font")
	var font_size: int = body.get_theme_font_size("font_size")
	body.add_theme_constant_override("line_spacing", int(round(UiFonts.px(18.0) - font.get_height(font_size))))
	text_room.add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var foot: HBoxContainer = Paper.line_box(48.0)
	foot.name = "Foot"
	sheet.inner.add_child(foot)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -UiFonts.px(48.0)
	var fill: Control = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(fill)
	go_key = LampKey.new(GO_WORD)
	go_key.name = "Go"
	go_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go_key.pressed.connect(_go_on)
	foot.add_child(go_key)
	if not still:
		_come_up(dim)


## The end card's fade and cubic rise, with no delay between the words.
func _come_up(dim: ColorRect) -> void:
	dim.modulate.a = 0.0
	sheet.modulate.a = 0.0
	var at: Vector2 = sheet.position
	sheet.position = at + Vector2(0, UiFonts.px(RISE_CSS))
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, DIM_S)
	tw.tween_property(sheet, "modulate:a", 1.0, SHOW_S)
	tw.tween_property(sheet, "position", at, SHOW_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _go_on() -> void:
	if is_queued_for_deletion():
		return
	went_on.emit()
	queue_free()
