extends RefCounted
## The sound rows of the settings pane (결정 448: 「정지-설정에 소리조절버튼없음」): 전체, 음악, 효과,
## 목소리, a bar each in steps of 10 %, the level in the number face beside it. A move is heard at
## once and kept (sound_levels.gd). The bar is a finger's height (GlassPane.CELL_H) on a phone.

const GlassPane = preload("res://game/ui/glass_pane.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const SoundLevels = preload("res://game/audio/sound_levels.gd")

const KNOB_CSS: float = 22.0


## The block of rows; `path` is where the levels are kept (tests give their own).
static func make(path: String = "") -> VBoxContainer:
	var levels := SoundLevels.load_levels(path)
	var col := VBoxContainer.new()
	col.name = "SoundRows"
	col.add_theme_constant_override("separation", int(UiFonts.px(GlassPane.GAP)))
	for bus in SoundLevels.BUSES:
		col.add_child(_row(bus, int(levels[bus]), path))
	return col


static func _row(bus: String, percent: int, path: String) -> HBoxContainer:
	var row := GlassPane.row()
	row.name = bus
	row.add_child(GlassPane.row_word(String(SoundLevels.NAMES[bus])))
	var bar := HSlider.new()
	bar.name = "Bar"
	bar.min_value = 0
	bar.max_value = 100
	bar.step = SoundLevels.STEP
	bar.value = percent
	bar.focus_mode = Control.FOCUS_NONE
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(UiFonts.px(140.0), UiFonts.px(GlassPane.CELL_H))
	_skin(bar)
	row.add_child(bar)
	var value := UiFonts.label(_word(percent), UiFonts.NUMBER, 500, 15.0, GlassPane.INK)
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(UiFonts.px(40.0), 0)
	row.add_child(value)
	bar.value_changed.connect(func(v: float) -> void:
		SoundLevels.set_level(bus, int(v), path)
		value.text = _word(int(v)))
	return row


## 「끔」 at 0, else the percent.
static func _word(percent: int) -> String:
	return "끔" if percent <= 0 else "%d%%" % percent


## The track a hair line, the part up to the knob in amber, the knob a round lamp.
static func _skin(bar: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = GlassPane.HAIR
	track.content_margin_top = UiFonts.px(2.0)
	track.content_margin_bottom = UiFonts.px(2.0)
	track.set_corner_radius_all(int(UiFonts.px(2.0)))
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = GlassPane.AMBER
	bar.add_theme_stylebox_override("slider", track)
	bar.add_theme_stylebox_override("grabber_area", fill)
	bar.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob(GlassPane.AMBER_L)
	for k in ["grabber", "grabber_highlight", "grabber_disabled"]:
		bar.add_theme_icon_override(k, knob)


static func _knob(color: Color) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.84, 0.92])
	g.colors = PackedColorArray([color, color, Color(color, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = int(UiFonts.px(KNOB_CSS))
	t.height = int(UiFonts.px(KNOB_CSS))
	return t
