extends Node
## The vertical slice end to end (밤 계획 2026-10-18 「밤에 할 것」 3, 결정 402): the
## train → choosing the stop → the field → the return receipt → the special
## session → the train → the second station → the end card, one after another
## from the boot screen. The train is the real inside (train.tscn) at the phase
## each step names; the field is the real stop. The screens that are not built
## yet are plain panels over them that read what there is (the field's own
## receipt, or the sample one when the field is skipped), and PR 3 swaps them
## for the real ones in turn. It sets no game value.

const FieldGame = preload("res://game/field_game.gd")
const TrainRules = preload("res://game/train/train_rules.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const LampKey = preload("res://game/ui/lamp_key.gd")
const ReceiptCard = preload("res://game/ui/receipt_card.gd")
const StopPickCard = preload("res://game/ui/stop_pick_card.gd")
const TrainGauges = preload("res://game/ui/train_gauges.gd")
const TRAIN_SCENE := preload("res://game/train/train.tscn")
const EDGE_BOT := preload("res://game/ui/tex/edge_bot.png")
## The frost grown in from the screen's corners over the world (시안 .w-frost,
## its left and right halves; the middle is clear).
const FROST_L := preload("res://game/ui/tex/frost_l.png")
const FROST_R := preload("res://game/ui/tex/frost_r.png")
const BOOT_SCENE := "res://scenes/boot.tscn"
## The receipt shown when the field was skipped, and the departure the field
## goes out with, till the train sends its own (S3 영수증 판 4 표본).
const RECEIPT_SAMPLE := "res://tests/game/fixtures/field_v4/case1_symbol_kept.json"
const DEPARTURE_SAMPLE := "res://tests/game/fixtures/field_v4/departure_prologue.json"

## The steps in order: [id, the train's phase behind the panel ("" for none),
## the stretch it is on, the panel's title, the next key's word].
const STEPS: Array = [
	["train", "travel", 1, "열차 · 1구간", "정차 고르기"],
	["stop_pick", "stop", 1, "정차 고르기", "내리기"],
	["field", "", 1, "", ""],
	["receipt", "settle", 1, "귀환 영수증", "특별 회기"],
	["council", "council", 1, "특별 회기", "출발"],
	["travel", "travel", 2, "열차 · 2구간", "다음 역"],
	["arrive", "stop", 2, "둘째 역 도착", "끝 카드"],
	["end", "end", 2, "끝", "처음으로"],
]
## The words on each plain panel until its real screen comes (가제).
const NOTES: Dictionary = {
	"train": ["열차 안 · 칸마다 사람과 기색"],
	"council": ["식당칸 의회 · 안건과 표 자리", "귀환 영수증의 약속 판정이 여기서 쓰임"],
	"travel": ["둘째 구간 · 열차 턴 자리"],
	"arrive": ["둘째 역 도착 화면 자리"],
	"end": ["끝 카드 자리 · 이번 판의 남길 만한 일"],
}
const PANEL_W: float = 560.0
## What stays lit in the gauges while a step's sheet is up (the stop is about stock).
const FOCUS: Dictionary = {"stop_pick": ["coal", "food", "med", "lux"]}
## 디자인 토큰 2차: the smoked glass of a pane (B1) and its words.
const PANE := Color(8 / 255.0, 11 / 255.0, 15 / 255.0, 0.84)
const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)

var opts: Dictionary = {}          # skip_field: true goes past the field with the sample receipt
var step: int = -1
var stage: Node = null             # what is up behind the panel: the train or the field
var train: Node3D = null
var field: Node3D = null
var result: Dictionary = {}        # the field's result, when the field was played
var receipt: Dictionary = {}       # the receipt the receipt panel reads
var theme: Theme
var layer: CanvasLayer
var panel: PanelContainer
var title: Label
var lines: VBoxContainer
var next_button: Button             # the main key (lamp_key.gd), its arrow drawn by itself
var panel_style: StyleBoxFlat
var card: Control = null           # a real screen standing in for the panel (stop_pick)
var gauges: Control                # the train's gauges along the top, over the train
var soot_bot: TextureRect          # the soot rising from the bottom edge under the keys
var frost: Control                 # the corners' frost over the train (.w-frost)
var plates: Control                # the carriages' name plates, where the train's cars are


func _ready() -> void:
	theme = UiTheme.make(22)
	theme.default_font = UiFonts.face(UiFonts.WORD, 400)
	layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	plates = Control.new()
	plates.name = "Plates"
	plates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plates.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(plates)
	frost = Control.new()
	frost.name = "Frost"
	frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frost.add_child(_sheet(FROST_L, 0.0, 0.5))
	frost.add_child(_sheet(FROST_R, 0.5, 1.0))
	layer.add_child(frost)
	# The soot the keys stand on at the bottom edge (.edge--bot, 104 high; the
	# gauges bring their own at the top).
	soot_bot = _sheet(EDGE_BOT, 0.0, 1.0)
	soot_bot.anchor_top = 1.0
	soot_bot.offset_top = -UiFonts.px(104.0)
	layer.add_child(soot_bot)
	# The train's gauges read the train sample's first stop, as the stop card does.
	gauges = TrainGauges.new()
	var s: Array = StopPickCard.sample()
	gauges.g = s[0]
	gauges.t = s[1]
	layer.add_child(gauges)
	_build_panel()
	go(0)


## The step now ("train", "field", …).
func current() -> String:
	return String(STEPS[step][0]) if step >= 0 else ""


func go(i: int) -> void:
	step = i
	_clear_stage()
	if is_instance_valid(card):
		card.queue_free()
	card = null
	var row: Array = STEPS[i]
	var id: String = row[0]
	# Over the train, not over the field or the receipt (a slip of its own).
	gauges.visible = String(row[1]) != "" and id != "receipt"
	gauges.set_focus(FOCUS.get(id, []))
	frost.visible = String(row[1]) != ""
	soot_bot.visible = gauges.visible and id != "stop_pick"
	if id == "field":
		panel.visible = false
		if bool(opts.get("skip_field", false)):
			_field_done({})
		else:
			_start_field()
		return
	if String(row[1]) != "":
		_show_train(String(row[1]), int(row[2]))
	if id == "receipt":
		_show_receipt(String(row[4]))
		return
	if id == "stop_pick":
		_show_stop_pick()
		return
	_show_panel(String(row[3]), NOTES.get(id, []), String(row[4]))


func next() -> void:
	if step + 1 >= STEPS.size():
		get_tree().change_scene_to_file(BOOT_SCENE)
		return
	go(step + 1)


## Choosing the stop: the paper card over the train at its stop. The first
## stop is Sulechów, a freight siding; the numbers are the train sample's.
func _show_stop_pick() -> void:
	panel.visible = false
	var c = StopPickCard.new()
	var s: Array = StopPickCard.sample()
	c.g = s[0]
	c.t = s[1]
	if c.g.get("stop") is Dictionary:
		c.g["stop"]["place"] = "freight"
	c.stop_name = "술레후프"
	c.top_room = TrainGauges.BAND_H
	c.promises = _sample(DEPARTURE_SAMPLE).get("promises", [])
	c.sent.connect(func(_g: Dictionary) -> void: next())
	c.passed_by.connect(func() -> void: go(_index_of("travel")))
	layer.add_child(c)
	card = c


## A picture laid over the screen from `x0` to `x1` of its width, top to bottom.
func _sheet(tex: Texture2D, x0: float, x1: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = x0
	r.anchor_right = x1
	r.anchor_top = 0.0
	r.anchor_bottom = 1.0
	return r


func _index_of(id: String) -> int:
	for i in STEPS.size():
		if STEPS[i][0] == id:
			return i
	return 0


func _clear_stage() -> void:
	if is_instance_valid(stage):
		stage.queue_free()
	stage = null
	train = null
	field = null


## The inside of the train at `phase`, without its test panel.
func _show_train(phase: String, seg: int) -> void:
	var rules: Dictionary = TrainRules.load_default()
	rules["train"]["phase"] = phase
	rules["train"]["seg"] = seg
	train = TRAIN_SCENE.instantiate()
	train.opts = {"panel": false, "seed": int(opts.get("seed", 1))}
	train.rules = rules
	add_child(train)
	stage = train
	_quiet_labels()
	_quiet_labels.call_deferred()


## The train's own floating names and value lines are for its test bench;
## here the carriages wear name plates instead (.plate), under their floors.
func _quiet_labels() -> void:
	if not is_instance_valid(train):
		return
	for c in plates.get_children():
		c.queue_free()
	for l in train.find_children("*", "Label3D", true, false):
		var label := l as Label3D
		label.visible = false
		if label.font_size >= 60 and label.text != "":
			plates.add_child(_plate(label))


## A carriage's name plate (시안 .plate): a dark enamel plate, its name between
## two brass dots, where the car's floor meets its wheels.
func _plate(name_label: Label3D) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("161d24")
	sb.set_corner_radius_all(int(round(UiFonts.px(2.0))))
	sb.border_width_top = 1
	sb.border_color = Color(1, 1, 1, 0.2)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = UiFonts.px(12.0)
	sb.content_margin_right = UiFonts.px(12.0)
	p.add_theme_stylebox_override("panel", sb)
	var word := UiFonts.label(name_label.text, UiFonts.WORD, 500, 12.0, Color("e6e1d4"), 1.44)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.custom_minimum_size = Vector2(0, UiFonts.px(18.0))
	p.add_child(word)
	var dots := func() -> void:
		var r: float = UiFonts.px(1.2)
		var y: float = p.size.y * 0.5
		p.draw_circle(Vector2(UiFonts.px(5.0), y), r, Color(202 / 255.0, 164 / 255.0, 92 / 255.0, 0.9))
		p.draw_circle(Vector2(p.size.x - UiFonts.px(5.0), y), r, Color(202 / 255.0, 164 / 255.0, 92 / 255.0, 0.9))
	p.draw.connect(dots)
	p.set_meta("car", name_label.get_parent())
	p.set_meta("x", name_label.position.x)
	return p


func _process(_delta: float) -> void:
	if not is_instance_valid(train) or plates.get_child_count() == 0:
		return
	var cam: Camera3D = train.get("camera")
	if cam == null:
		return
	for p: Control in plates.get_children():
		var car = p.get_meta("car")
		if not is_instance_valid(car):
			continue
		var at: Vector3 = (car as Node3D).to_global(Vector3(float(p.get_meta("x")), -0.45, 0.0))
		p.visible = not cam.is_position_behind(at) and card == null
		var s: Vector2 = cam.unproject_position(at)
		p.size = p.get_combined_minimum_size()
		p.position = s - p.size * 0.5


func _start_field() -> void:
	field = FieldGame.new()
	var o := {"seed": int(opts.get("seed", 1))}
	o["squad"] = field.default_squad("crude")
	var dep: Dictionary = _sample(DEPARTURE_SAMPLE)
	if not dep.is_empty():
		o["departure"] = dep
	field.opts = o
	field.finished.connect(_field_done)
	add_child(field)
	stage = field


## The field is over: its end card stays where it is, and a key over it goes
## on to the receipt.
func _field_done(r: Dictionary) -> void:
	result = r
	receipt = r.get("receipt", {}) if not r.is_empty() else _sample(RECEIPT_SAMPLE)
	if field == null:
		go(step + 1)
		return
	_show_panel("", [], "귀환 영수증")
	panel.visible = true


func _sample(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## What the receipt card reads off a field result, made from a bare receipt
## when the field was skipped.
static func result_of(r: Dictionary) -> Dictionary:
	var people: Dictionary = r.get("people", {})
	var gone: int = 0
	for k in ["dead", "missing", "leftBehind"]:
		gone += (people.get(k, []) as Array).size()
	return {
		"reason": String(r.get("endReason", "departed")),
		"receipt": r,
		"stay": int((r.get("time", {}) as Dictionary).get("stayGameMinutes", 0)),
		"boarded": maxi(0, (people.get("sent", []) as Array).size() - gone),
		"hordes": 0,
	}


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.theme = theme
	# The smoked glass of a pane (B1), a faint light along its top.
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANE
	sb.set_corner_radius_all(int(round(UiFonts.px(4.0))))
	sb.border_width_top = 1
	sb.border_color = Color(1, 1, 1, 0.1)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = int(round(UiFonts.px(8.0)))
	sb.set_content_margin_all(UiFonts.px(14.0))
	panel_style = sb
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	layer.add_child(panel)
	# Wrapped lines settle their height after a layout pass: pin again then.
	panel.minimum_size_changed.connect(_pin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(UiFonts.px(6.0))))
	panel.add_child(v)
	title = UiFonts.label("", UiFonts.WORD, 600, 18.0, INK, 0.36)
	v.add_child(title)
	lines = VBoxContainer.new()
	lines.add_theme_constant_override("separation", int(round(UiFonts.px(2.0))))
	v.add_child(lines)
	next_button = LampKey.new("")
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	next_button.pressed.connect(next)
	v.add_child(next_button)


## The receipt step: the paper receipt itself on clear glass, the key under it.
func _show_receipt(go_word: String) -> void:
	_show_panel("", [], go_word)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.custom_minimum_size = Vector2.ZERO
	if receipt.is_empty():
		var none := Label.new()
		none.text = "영수증 없음"
		lines.add_child(none)
	else:
		var slip: Control = ReceiptCard.build(result if not result.is_empty() else result_of(receipt))
		slip.name = "Receipt"
		lines.add_child(slip)
	_pin()


func _show_panel(head: String, rows: Array, go_word: String) -> void:
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	title.text = head
	title.visible = head != ""
	for c in lines.get_children():
		lines.remove_child(c)
		c.queue_free()
	for text in rows:
		var l := UiFonts.label(String(text), UiFonts.WORD, 400, 13.0, INK2)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = PANEL_W - UiFonts.px(28.0)
		lines.add_child(l)
	next_button.text = go_word
	panel.visible = true
	_pin()


## Bottom right at its own size, growing up and to the left: the carriage's
## name line and its people stay in sight above it.
func _pin() -> void:
	panel.reset_size()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(round(UiFonts.px(12.0))))
