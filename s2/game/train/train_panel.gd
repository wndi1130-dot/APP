extends CanvasLayer
## The hand panel of the skeleton scene: pick a car, push its numbers and the
## train's mood, and watch the car change. A test tool; the real numbers will
## come from the rules, and this panel goes when they do.

const UiTheme = preload("res://game/ui/ui_theme.gd")
const Rules = preload("res://game/train/train_rules.gd")

## [key, name, low, high]. sit0..sit3 are the car's situation, in S1's order.
const KNOBS: Array = [
	["sit0", "온기", 0, 100], ["sit1", "배급", 0, 100], ["sit2", "과밀", 0, 100], ["sit3", "노출", 0, 100],
	["rel", "관계", -100, 100], ["tension", "긴장", 0, 100], ["fear", "공포", 0, 100],
]
const TRAIN_KEYS: Array = ["tension", "fear"]
const BOOT_SCENE := "res://scenes/boot.tscn"
const READS := "지금 장면이 읽는 값: 온기(웅크림), 과밀(사람 수와 바닥에 앉음), 회기(식당칸 사람 수와 오가는 길). 배급·노출·관계·긴장·공포는 아직 글자만 바뀐다."

var scene: Node3D
var car_i: int = 0
var root: Control
var title: Label
var grid: GridContainer
var note: Label
var fps: Label
var phase_button: Button
var sliders: Dictionary = {}
var readouts: Dictionary = {}
var _filling: bool = false
var _fps_t: float = 0.0


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
	var c: Dictionary = scene.cars[car_i]
	var comm := Rules.comm_of(scene.rules, c["def"])
	var train: Dictionary = scene.rules["train"]
	title.text = String((c["def"] as Dictionary).get("name", c["id"]))
	phase_button.text = "회기 중" if scene.phase() == "council" else "이동 중"
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
	scene.set_train("phase", "travel" if scene.phase() == "council" else "council")


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
