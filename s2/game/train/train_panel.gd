extends CanvasLayer
## The hand panel of the skeleton scene: pick a car, push its numbers and the
## train's mood, and watch the car change. A test tool; the real numbers will
## come from the rules, and this panel goes when they do.

const UiTheme = preload("res://game/ui/ui_theme.gd")
const Rules = preload("res://game/train/train_rules.gd")
const CaptainBoard = preload("res://game/train/train_captain.gd")
const LifePanel = preload("res://game/train/train_life_panel.gd")

## [key, name, low, high]. sit0..sit3 are the car's situation, in S1's order.
const KNOBS: Array = [
	["sit0", "온기", 0, 100], ["sit1", "배급", 0, 100], ["sit2", "과밀", 0, 100], ["sit3", "노출", 0, 100],
	["rel", "관계", -100, 100], ["tension", "긴장", 0, 100], ["fear", "공포", 0, 100],
]
const TRAIN_KEYS: Array = ["tension", "fear"]
const BOOT_SCENE := "res://scenes/boot.tscn"
## Captains to look at in turn, after the rules' own (a test key like the
## sliders: the real captain will come from the rules).
const CAPTAIN_SHOWS: Array = [
	{"at": "captain", "doing": "", "hands": {"weapon": "crowbar", "tool": "flare"}, "wounds": [{"part": "arm_left", "kind": "scratch"}]},
	{"at": "medtech", "doing": "bed", "left": 3, "hands": {"weapon": "", "tool": ""}, "wounds": [
		{"part": "arm_left", "kind": "deep", "blood": 0.0, "bandaged": true, "disinfected": true},
		{"part": "leg_right", "kind": "fracture", "splinted": true},
		{"part": "torso", "kind": "laceration", "festering": true}]},
	{"at": "captain", "doing": "rest", "left": 1, "hands": {"weapon": "axe", "tool": ""}, "wounds": []},
	{"at": "out", "doing": "", "hands": {"weapon": "axe", "tool": "crowbar"}, "wounds": []},
]
const CAPTAIN_AT := Vector2(16, 16)
const READS := "지금 장면이 읽는 값: 온기(웅크림, 창 성에, 난로), 과밀(사람 수와 바닥에 앉음). 온기·배급·관계·긴장·공포에서 칸의 기색 하나를 뽑아 모이는 자리, 걷는 사람과 빠르기, 등불을 바꾼다. 이념 세 축이 가까운 칸끼리는 가끔 마실을 간다. 회기에는 식당칸이 의회가 된다: 긴장과 칸마다의 관계·원한을 더한 소란 다섯 단이 일어서는 사람과 몸을 기울이는 사람을 늘리고, 공포 60부터는 조용하며, 표결을 걸면 모두 멈춘다. 긴장 60부터는 칸마다 서 있는 무리의 둘이 말다툼하거나 수군거리고 한 사람은 두리번거린다. 긴장이 그보다 낮아도 관계가 -40 이하이거나 원한이 쌓인 칸에서는 서 있는 무리가 팔짱을 끼고 열차장실 쪽으로 몸을 틀며 한 사람은 등을 돌린다. 긴장한 열차에서도 그런 칸은 다투는 둘 옆에 한 사람이 팔짱을 끼고 선다. 공포 60부터는 넓은 칸에서도 둘까지 벤치에서 바닥으로 내려앉고(식탁이나 책상이 있는 칸은 빼고), 바닥에 앉은 사람 가운데 셋까지 무릎을 끌어안는다. 가라앉은 칸에서 배급이 45 아래이고 온기보다 높지 않으면 벤치의 둘이 빈 그릇을 들여다보고, 웅크리지 않고 바닥에 앉은 둘은 뒤로 기대 늘어진다. 온기가 45 아래이고 배급보다 낮으면 걷는 사람이 멈춰 서 있는 동안 손을 비비고 발을 구른다. 노출은 아직 글자만 바뀐다. 「열차장」 판은 규칙 값의 열차장 칸(있는 곳과 하는 일, 든 것, 상처)을 그대로 보인다."

var scene: Node3D
var car_i: int = 0
var root: Control
var title: Label
var grid: GridContainer
var note: Label
var fps: Label
var phase_button: Button
var vote_button: Button
var captain_board: PanelContainer
var captain_i: int = 0             # 0: the rules' own captain, then CAPTAIN_SHOWS in turn
var _captain_own = null
var sliders: Dictionary = {}
var readouts: Dictionary = {}
var _filling: bool = false
var _fps_t: float = 0.0
var life_panel: PanelContainer


func _ready() -> void:
	root = PanelContainer.new()
	root.theme = UiTheme.make(20)
	root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(root)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 8)
	root.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pad.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	_button(top, "‹", func() -> void: pick(car_i - 1))
	title = Label.new()
	title.custom_minimum_size = Vector2(150, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(title)
	_button(top, "›", func() -> void: pick(car_i + 1))
	phase_button = _button(top, "", _flip_phase)
	vote_button = _button(top, "", _flip_vote)
	_button(top, "열차장", _flip_captain)
	_button(top, "생활 값", _flip_life)
	_button(top, "멀리·가까이", func() -> void: scene.toggle_zoom())
	_button(top, "판 접기", _fold)
	_button(top, "나가기", func() -> void: get_tree().change_scene_to_file(BOOT_SCENE))
	fps = Label.new()
	fps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(fps)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	v.add_child(grid)
	for knob in KNOBS:
		_knob(knob)
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.68))
	v.add_child(note)
	captain_board = CaptainBoard.new()
	captain_board.position = CAPTAIN_AT
	captain_board.visible = false
	add_child(captain_board)
	_button(captain_board.foot, "다른 보기", next_captain)
	life_panel = LifePanel.new()
	life_panel.hand = self
	life_panel.scene = scene
	life_panel.visible = false
	add_child(life_panel)
	if scene != null:
		scene.rules_applied.connect(fill)
	fill()


func _process(delta: float) -> void:
	_fps_t -= delta
	if _fps_t <= 0.0 and fps != null:
		_fps_t = 0.5
		fps.text = "%d fps" % int(Engine.get_frames_per_second())


func pick(i: int) -> void:
	if scene == null or scene.cars.is_empty():
		return
	car_i = posmod(i, scene.cars.size())
	scene.focus_car(scene.cars[car_i]["id"])
	fill()
	if life_panel != null:
		life_panel.fill()


## The community of the car picked ("" for a car without one).
func comm_id() -> String:
	if scene == null or scene.cars.is_empty():
		return ""
	return String((scene.cars[car_i]["def"] as Dictionary).get("comm", ""))


## Put the rules' numbers on the sliders (no rule is changed by this).
func fill() -> void:
	if scene == null or title == null:
		return
	if not scene.problems.is_empty():
		title.text = "규칙 값 오류"
		note.text = "\n".join(scene.problems)
		return
	_filling = true
	car_i = clampi(car_i, 0, scene.cars.size() - 1)
	var c: Dictionary = scene.cars[car_i]
	var comm := Rules.comm_of(scene.rules, c["def"])
	var train: Dictionary = scene.rules["train"]
	title.text = String((c["def"] as Dictionary).get("name", c["id"]))
	phase_button.text = "회기 중" if scene.phase() == "council" else "이동 중"
	# The vote is called only in session; outside it the button waits, dimmed.
	vote_button.text = "표결 중" if bool(train.get("voting", false)) else "표결"
	vote_button.disabled = scene.phase() != "council"
	for knob in KNOBS:
		var key: String = knob[0]
		var slider: HSlider = sliders[key]
		var of_train := TRAIN_KEYS.has(key)
		slider.editable = of_train or not comm.is_empty()
		slider.modulate.a = 1.0 if slider.editable else 0.3
		var value = null
		if of_train:
			value = train.get(key, 0)
		elif not comm.is_empty():
			value = (comm["sit"] as Array)[int(key.substr(3))] if key.begins_with("sit") else comm.get(key, 0)
		if value != null:
			slider.value = float(value)
		(readouts[key] as Label).text = "–" if value == null else str(roundi(float(value)))
	note.text = READS
	_filling = false
	captain_board.show_captain(_captain(), scene.rules["cars"])


func _changed(value: float, key: String) -> void:
	if _filling or scene == null:
		return
	if TRAIN_KEYS.has(key):
		scene.set_train(key, value)
	elif comm_id() == "":
		return
	elif key.begins_with("sit"):
		scene.set_sit(comm_id(), int(key.substr(3)), value)
	else:
		scene.set_comm(comm_id(), key, value)


func _flip_phase() -> void:
	scene.rules["train"]["voting"] = false
	scene.set_train("phase", "travel" if scene.phase() == "council" else "council")


func _flip_vote() -> void:
	scene.set_train("voting", not bool(scene.rules["train"].get("voting", false)))


func _flip_captain() -> void:
	captain_board.visible = not captain_board.visible


func _flip_life() -> void:
	life_panel.visible = not life_panel.visible
	if life_panel.visible:
		life_panel.fill()


## Put the next captain to look at into the rules: their own first, then
## CAPTAIN_SHOWS, and round again. Nothing in the cars reads it.
func next_captain() -> void:
	if scene == null or not scene.problems.is_empty():
		return
	if captain_i == 0:
		_captain_own = scene.rules.get("captain")
	captain_i = (captain_i + 1) % (CAPTAIN_SHOWS.size() + 1)
	if captain_i > 0:
		scene.rules["captain"] = (CAPTAIN_SHOWS[captain_i - 1] as Dictionary).duplicate(true)
	elif _captain_own == null:
		scene.rules.erase("captain")
	else:
		scene.rules["captain"] = _captain_own
	fill()


func _captain() -> Dictionary:
	var c = scene.rules.get("captain", {})
	return c if c is Dictionary else {}


func _fold() -> void:
	grid.visible = not grid.visible
	note.visible = grid.visible


func _knob(knob: Array) -> void:
	var key: String = knob[0]
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = knob[1]
	name_label.custom_minimum_size = Vector2(52, 0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = knob[2]
	slider.max_value = knob[3]
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(120, 44)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_changed.bind(key))
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size = Vector2(46, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	grid.add_child(row)
	sliders[key] = slider
	readouts[key] = readout


func _button(parent: Control, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(64, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b
