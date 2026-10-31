extends Node
## Start screen for the S2 graybox: pick the run settings, then play one stop
## at Sulechów. The old phone performance test stays one tap away.

const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")
const Atmosphere = preload("res://fx/atmosphere.gd")
const ScreenLift = preload("res://game/ui/screen_lift.gd")
## Shader gallery (fx library), opened from the menu for a look on the phone.
const GALLERY_SCENE := "res://fx/gallery.tscn"
const TRAIN_SCENE := "res://game/train/train.tscn"

const CHOICES: Array = [
	["raiders", "약탈자", [[true, "있음"], [false, "없음"]]],
	["clock_speed", "시계", [[1.0, "보통"], [2.0, "2배 (짧은 판)"]]],
	["pipe_quality", "파이프 산탄총", [["crude", "조잡"], ["usable", "쓸 만함"], ["fine", "정교"]]],
	["weather", "날씨", [[["fog", "snow"], "안개·가는 눈"], [["fog"], "짙은 안개"], [["clear"], "맑음"], [["blizzard"], "눈보라"]]],
	["storm", "폭풍 정차", [["", "아님 (위 날씨대로)"], ["before", "다가옴"], ["during", "한창"], ["after", "지나감"]]],
	["cap", "동시 상한", [[60, "60"], [40, "40"], [80, "80"]]],
	["fps_cap", "FPS 상한", [[60, "60"], [30, "30"]]],
	["inertia", "몸 관성", [["now", "무거움 0.2·0.25·0.4초"], ["mid", "중간 0.12·0.15·0.25"], ["short", "짧게 0.10·0.12·0.20"]]],
	["melee_chain", "근접 이어 치기", [[true, "2m 안 다음 놈까지"], [false, "한 놈만"]]],
	["stick_float", "스틱", [[false, "고정 (왼쪽 아래)"], [true, "스틱 따라오기"]]],
	["run_mode", "뛰기 키", [["toggle", "토글"], ["hold", "누르는 동안"]]],
	["radio", "무전", [["urgent", "급한 것만"], ["often", "자주 (지나가면 다음 예보도, 자주 울림)"], ["off", "끔"]]],
	["stick_rim_run", "스틱 끝 뛰기", [[false, "끔"], [true, "켬"]]],
	["double_tap_run", "두 번 톡 뛰기", [[false, "끔"], [true, "켬"]]],
	["primary_one", "주 행동 하나로", [[false, "끔 (조준·공격 따로)"], [true, "켬 (시험)"]]],
	["retreat_name", "동료 한 명을 물릴 때 이름", [["", "후퇴"], ["train", "열차로"]]],
	["melee_break", "근접 겨눔 끊김", [["grab", "잡히면 끊긴다"], ["none", "안 끊긴다"]]],
	# One in ten of the standing dead lunges after a tell (user 2026-10-12). From
	# which stop on is counted in S3; here it is on or off. zombies.gd reads it.
	["lungers", "달려드는 자", [[false, "끔"], [true, "켬"]]],
	["holdout", "버티기 판 (재는 판)", [["", "없음"], ["depart", "「떠난다」를 부르면 열린다"], ["start", "처음부터"], ["roll", "굴려서 (장소 확률대로, 조용하면 안 뜬다)"]]],
	# The radio operator's forecast of a held train (user decision 150); who is
	# on watch is the train's to say, here it is on or off.
	["radio_watch", "무전수 당직 (「굴려서」의 예보)", [[false, "없음"], [true, "있음 (뜰 판 열에 여덟을 알림)"]]],
	# Switches for looking at a thing on the phone: with one on, what is rare is
	# sure to come. All off unless picked; they are not values of the game.
	["holdout_chance", "시험: 「굴려서」의 굴림", [[-1, "장소 확률대로"], [100, "늘 뜬다"]]],
	["holdout_forecast_heard", "시험: 무전수가 듣는 판", [[80, "열에 여덟"], [100, "늘 듣는다"]]],
	["lungers_many", "시험: 달려드는 자의 수", [[false, "열에 하나"], [true, "서 있는 망자는 모두"]]],
	# The atmosphere frame (fx/atmosphere.gd), picture only: which season table the
	# cold comes from (the user's 10-24 answer, or the old 10-09 one to compare),
	# which act, and an hour to draw the stop at. The slice follows the table too.
	["cold_scheme", "시험: 계절 흐름", [["", "늦가을 → 한겨울 → 해빙 초입 (10-24)"], ["winter_to_thaw", "옛 표: 한겨울 → 해빙 초입 (10-09)"]]],
	["act", "시험: 막 (추위 값)", [["prologue", "서막"], ["act1", "1막"], ["act2", "2막"], ["act3", "3막"]]],
	["look_hour", "시험: 그림 시각", [[-1.0, "시계대로"], [-2.0, "해 뜰 녘"], [-3.0, "해 질 녘"], [-4.0, "밤"]]],
	["region", "시험: 지역 띠", [["K1", "K1 호수 평야"], ["K4", "K4 소나무 평원"], ["K10", "K10 호수와 숲"], ["K11", "K11 늪과 해안"]]],
	# Which map the stop is played on, for looking at one on the phone: a kind
	# and its number. Left as it is, the stop is the one it always was. A
	# number the kind has no map for is the usual stop too.
	["place_kind", "시험: 지도 종류", [["", "지금 그대로"], ["mine", "탄광"], ["lodge", "산장"], ["sawmill", "목재소"], ["lake", "호수"], ["freight", "화물역"], ["houses", "주택가"], ["hospital", "병원"], ["factory", "공장"], ["church", "교회"], ["office", "관청"], ["summit", "고개"], ["bare_line", "빈 땅"]]],
	["place_no", "시험: 지도 장", [[1, "1"], [2, "2"], [3, "3"], [4, "4"], [5, "5"], [6, "6"], [7, "7"], [8, "8"], [9, "9"]]],
	["mission", "이번 정차의 일", [["", "지금 원정"], ["survey", "관리소 조사 (작업조 없음)"], ["depot", "적재장 복구 (석탄 12)"]]],
]

var settings: Dictionary = {}
## Save slots read at start (tests point them elsewhere before adding the boot).
var slice_save_path: String = SliceSave.PATH
var field_save_path: String = FieldSave.PATH
var train_save_path: String = FieldSave.TRAIN_PATH
var menu_scroll: int = 0
var menu: Control
var field: Node3D
var theme: Theme


func _ready() -> void:
	theme = UiTheme.make(24)
	for row in CHOICES:
		settings[row[0]] = row[2][0][0]
	var board: Array = SliceFlow.start_board()
	var slice_resume: Dictionary = SliceSave.pick(slice_save_path, train_save_path, board[1], field_save_path)
	if not slice_resume.is_empty():
		_start_slice(slice_resume)
		return
	# A stop the app was shut in the middle of comes back where it was (user decision 296).
	var resume := FieldSave.pick_start(field_save_path, train_save_path)
	if bool(resume.get("slice", false)):
		_show_menu()
		return
	if not resume.is_empty():
		_start(resume)
		return
	var auto: String = OS.get_environment("S2_AUTOSTART")
	if auto != "":
		_start()
		return
	_show_menu()


func _show_menu() -> void:
	if menu != null:
		menu.get_parent().queue_free()
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
	var gallery := Button.new()
	gallery.name = "GalleryButton"
	gallery.text = "셰이더 보기"
	gallery.custom_minimum_size = Vector2(240, 64)
	gallery.pressed.connect(func() -> void: get_tree().change_scene_to_file(GALLERY_SCENE))
	go.add_child(gallery)
	var train := Button.new()
	train.name = "TrainButton"
	train.text = "열차 안 보기"
	train.custom_minimum_size = Vector2(240, 64)
	train.pressed.connect(func() -> void: get_tree().change_scene_to_file(TRAIN_SCENE))
	go.add_child(train)
	# The vertical slice end to end, its unbuilt screens as plain panels (밤 계획 2026-10-18).
	var slice := Button.new()
	slice.name = "SliceButton"
	slice.text = "슬라이스 흐름(시험)"
	slice.custom_minimum_size = Vector2(240, 64)
	slice.pressed.connect(_start_slice)
	go.add_child(slice)
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
			# A long row (the map kinds) keeps to the screen with narrower buttons.
			b.custom_minimum_size = Vector2(150 if row[2].size() <= 8 else 92, 50)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_pick.bind(row[0], opt[0]))
			h.add_child(b)
		rows.add_child(h)
	if menu_scroll > 0:
		scroll.set_deferred("scroll_vertical", menu_scroll)
	scroll.get_v_scroll_bar().value_changed.connect(func(x: float) -> void: menu_scroll = int(x))


func _pick(key: String, value) -> void:
	settings[key] = value
	if key == "cold_scheme":
		Atmosphere.scheme = String(value) if String(value) != "" else Atmosphere.DEFAULT_SCHEME
	_show_menu()


func _make_slice(resume: Dictionary = {}) -> Node:
	var flow = SliceFlow.new()
	flow.opts = {
		"save": true, "resume": resume, "slice_save_path": slice_save_path,
		"train_save_path": train_save_path, "field_save_path": field_save_path,
	}
	return flow


func _start_slice(resume: Dictionary = {}) -> void:
	# Boot can be in _ready; switch only after the tree has finished adding it.
	get_tree().change_scene_to_node.call_deferred(_make_slice(resume))


## `resume` is the start options of a stop coming back (FieldSave.pick_start); none starts a new one.
func _start(resume: Dictionary = {}) -> void:
	if menu != null:
		menu.get_parent().queue_free()
		menu = null
	field = FieldGame.new()
	var opts := resume.duplicate()
	if resume.is_empty():
		opts = settings.duplicate(true)
		opts["squad"] = field.default_squad(String(settings["pipe_quality"]))
		if place_picked() != "":
			opts["place"] = place_picked()
		var seed_env: String = OS.get_environment("S2_SEED")
		if seed_env != "":
			opts["seed"] = int(seed_env)
	# The one save slot: written when the app is pushed away and when the stop ends.
	opts["field_save"] = true
	opts["field_save_path"] = field_save_path
	field.opts = opts
	field.restart_requested.connect(_on_restart)
	add_child(field)
	# The brightness the player left in the settings (결정 471 B5): the play flow's own, never a
	# tool's, put on once the field is built.
	if field.is_built:
		ScreenLift.apply_saved(field)
	else:
		field.built.connect(func() -> void: ScreenLift.apply_saved(field), CONNECT_ONE_SHOT)


## The map picked on the start screen ("mine_03"), or "" for the usual stop.
func place_picked() -> String:
	var kind := String(settings.get("place_kind", ""))
	return "" if kind == "" else "%s_%02d" % [kind, int(settings.get("place_no", 1))]


func _on_restart() -> void:
	if field != null:
		field.queue_free()
		field = null
	Engine.max_fps = 60
	_show_menu()
