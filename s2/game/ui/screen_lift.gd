extends RefCounted
## 설정의 밝기 한 칸(결정 471 B5): 폰은 밖에서 보면 더 어두워, 화면을 −20~+20 %(5 % 걸음) 들거나
## 낮춘다. 기본 0이 지금 화면이다. 값은 판 사이에 남는다(user://screen.cfg [screen] lift, −0.2~0.2).
## 화면에 얹는 곡선은 field_game.set_screen_lift(어두운 쪽을 더 드는 감마 꼴, mood)가 맡고, 이 파일은
## 줄·저장·불러오기만. 남긴 값은 플레이 흐름(시작 메뉴·슬라이스가 필드를 만든 뒤)과 설정 줄을 옮길 때만
## 얹는다 — 촬영 도구·밝기 셈·봇이 만든 필드는 저장값과 상관없이 늘 0이다.

const GlassPane = preload("res://game/ui/glass_pane.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const SoundRows = preload("res://game/ui/sound_rows.gd")

const FILE: String = "user://screen.cfg"
static var where: String = FILE     # tests point this at their own file
const SECTION: String = "screen"
const KEY: String = "lift"
const STEP: int = 5
const LIMIT: int = 20


## 남긴 밝기(%), 없으면 0.
static func load_lift(path: String = "") -> int:
	var cfg := ConfigFile.new()
	if cfg.load(_at(path)) != OK:
		return 0
	return _fit(roundi(float(cfg.get_value(SECTION, KEY, 0.0)) * 100.0))


static func save_lift(percent: int, path: String = "") -> int:
	var cfg := ConfigFile.new()
	cfg.load(_at(path))
	var fitted := _fit(percent)
	cfg.set_value(SECTION, KEY, fitted / 100.0)
	cfg.save(_at(path))
	return fitted


## 화면에 얹는다(그 판의 field_game에 곡선이 있을 때만).
static func apply(game: Object, percent: int) -> void:
	if game != null and game.has_method("set_screen_lift"):
		game.set_screen_lift(_fit(percent) / 100.0)


## 플레이 흐름이 필드를 만든 뒤 한 번: 남긴 값을 얹는다.
static func apply_saved(game: Object, path: String = "") -> void:
	apply(game, load_lift(path))


## 설정 창의 줄: 「밝기」, 막대(소리 막대와 같은 모양), 옆 숫자. 옮기면 바로 보이고 남는다.
## 막대는 그 판에 얹힌 값에서 시작한다(곡선이 아직 없는 판은 남긴 값).
static func make(game: Object, path: String = "") -> HBoxContainer:
	var row := GlassPane.row()
	row.name = "ScreenLift"
	row.add_child(GlassPane.row_word("밝기"))
	var bar := HSlider.new()
	bar.name = "Bar"
	bar.min_value = -LIMIT
	bar.max_value = LIMIT
	bar.step = STEP
	bar.value = shown(game, path)
	bar.focus_mode = Control.FOCUS_NONE
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(UiFonts.px(140.0), UiFonts.px(GlassPane.CELL_H))
	SoundRows._skin(bar)
	row.add_child(bar)
	var value := UiFonts.label(word(int(bar.value)), UiFonts.NUMBER, 500, 15.0, GlassPane.INK)
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(UiFonts.px(40.0), 0)
	row.add_child(value)
	bar.value_changed.connect(func(v: float) -> void:
		var kept := save_lift(int(v), path)
		apply(game, kept)
		value.text = word(kept))
	return row


## 막대가 보여 줄 값(%): 판에 얹힌 값, 곡선이 없는 판이면 남긴 값.
static func shown(game: Object, path: String = "") -> int:
	if game != null and game.has_method("set_screen_lift"):
		return _fit(roundi(float(game.get("screen_lift")) * 100.0))
	return load_lift(path)


## 0은 「기본」, 아니면 부호 붙은 %.
static func word(percent: int) -> String:
	return "기본" if percent == 0 else "%+d%%" % percent


static func _fit(percent: int) -> int:
	return clampi(snappedi(percent, STEP), -LIMIT, LIMIT)


static func _at(path: String) -> String:
	return where if path == "" else path
