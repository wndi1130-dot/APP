extends Node
## Start screen for the S2 graybox: pick the run settings, then play one stop
## at Sulechów. The old phone performance test stays one tap away.

const FieldGame = preload("res://game/field_game.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")

const CHOICES: Array = [
	["raiders", "약탈자", [[true, "있음"], [false, "없음"]]],
	["clock_speed", "시계", [[1.0, "보통"], [2.0, "2배 (짧은 판)"]]],
	["pipe_quality", "파이프 산탄총", [["crude", "조잡"], ["usable", "쓸 만함"], ["fine", "정교"]]],
	["weather", "날씨", [[["fog", "snow"], "안개·가는 눈"], [["fog"], "짙은 안개"], [["clear"], "맑음"], [["blizzard"], "눈보라"]]],
	["cap", "동시 상한", [[60, "60"], [40, "40"], [80, "80"]]],
	["fps_cap", "FPS 상한", [[60, "60"], [30, "30"]]],
	["inertia", "몸 관성", [["mid", "중간 0.12·0.15·0.25초"], ["short", "짧게 0.10·0.12·0.20"], ["now", "처음 0.2·0.25·0.4"]]],
	["melee_chain", "근접 이어 치기", [[true, "2m 안 다음 놈까지"], [false, "한 놈만"]]],
	["stick_rim_run", "스틱 끝 뛰기", [[false, "끔"], [true, "켬"]]],
	["double_tap_run", "두 번 톡 뛰기", [[false, "끔"], [true, "켬"]]],
	["primary_one", "주 행동 하나로", [[false, "끔 (조준·공격 따로)"], [true, "켬 (시험)"]]],
]

var settings: Dictionary = {}
var menu_scroll: int = 0
var menu: Control
var field: Node3D
var theme: Theme


func _ready() -> void:
	theme = UiTheme.make(24)
	for row in CHOICES:
		settings[row[0]] = row[2][0][0]
	var auto: String = OS.get_environment("S2_AUTOSTART")
	if auto != "":
		_start()
		return
	_show_menu()


func _show_menu() -> void:
	if menu != null:
		menu.queue_free()
	var layer := CanvasLayer.new()
	add_child(layer)
	menu = Control.new()
	menu.theme = theme
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(menu)
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.11, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	center.add_child(v)
	var title := Label.new()
	title.text = "술레후프 · 직접 정차 (S2 회색 상자)"
	title.add_theme_font_size_override("font_size", 34)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "얼어붙은 급수탑 옆 작은 역. 열차는 승강장에 서 있다. 해 지기 전에 떠난다."
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.68))
	v.add_child(sub)
	# Start first, so it never falls off a short screen; the settings scroll.
	var go := HBoxContainer.new()
	go.add_theme_constant_override("separation", 12)
	v.add_child(go)
	var start := Button.new()
	start.text = "내린다"
	start.custom_minimum_size = Vector2(240, 64)
	start.pressed.connect(_start)
	go.add_child(start)
	var perf := Button.new()
	perf.text = "성능 시험 (이전 판)"
	perf.custom_minimum_size = Vector2(240, 64)
	perf.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	go.add_child(perf)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1000, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	for row in CHOICES:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var l := Label.new()
		l.text = row[1]
		l.custom_minimum_size = Vector2(200, 0)
		h.add_child(l)
		for opt in row[2]:
			var b := Button.new()
			b.text = opt[1] + (" ●" if settings[row[0]] == opt[0] else "")
			b.custom_minimum_size = Vector2(150, 50)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_pick.bind(row[0], opt[0]))
			h.add_child(b)
		rows.add_child(h)
	if menu_scroll > 0:
		scroll.set_deferred("scroll_vertical", menu_scroll)
	scroll.get_v_scroll_bar().value_changed.connect(func(x: float) -> void: menu_scroll = int(x))


func _pick(key: String, value) -> void:
	settings[key] = value
	_show_menu()


func _start() -> void:
	if menu != null:
		menu.get_parent().queue_free()
		menu = null
	field = FieldGame.new()
	var opts := settings.duplicate(true)
	opts["squad"] = field.default_squad(String(settings["pipe_quality"]))
	var seed_env: String = OS.get_environment("S2_SEED")
	if seed_env != "":
		opts["seed"] = int(seed_env)
	field.opts = opts
	field.restart_requested.connect(_on_restart)
	add_child(field)


func _on_restart() -> void:
	if field != null:
		field.queue_free()
		field = null
	Engine.max_fps = 60
	_show_menu()
