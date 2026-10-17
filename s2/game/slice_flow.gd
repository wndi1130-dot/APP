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
const ReceiptCard = preload("res://game/ui/receipt_card.gd")
const StopPickCard = preload("res://game/ui/stop_pick_card.gd")
const TRAIN_SCENE := preload("res://game/train/train.tscn")
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
	"train": ["열차 안 · 칸마다 사람과 기색", "정차 고르기 화면 자리"],
	"council": ["식당칸 의회 · 안건과 표 자리", "귀환 영수증의 약속 판정이 여기서 쓰임"],
	"travel": ["둘째 구간 · 열차 턴 자리"],
	"arrive": ["둘째 역 도착 화면 자리"],
	"end": ["끝 카드 자리 · 이번 판의 남길 만한 일"],
}
const PANEL_W: float = 560.0

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
var next_button: Button
var panel_style: StyleBoxFlat
var card: Control = null           # a real screen standing in for the panel (stop_pick)


func _ready() -> void:
	theme = UiTheme.make(22)
	layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
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
	c.promises = _sample(DEPARTURE_SAMPLE).get("promises", [])
	c.sent.connect(func(_g: Dictionary) -> void: next())
	c.passed_by.connect(func() -> void: go(_index_of("travel")))
	layer.add_child(c)
	card = c


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
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.07, 0.86)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	panel_style = sb
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	layer.add_child(panel)
	# Wrapped lines settle their height after a layout pass: pin again then.
	panel.minimum_size_changed.connect(_pin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 30)
	v.add_child(title)
	lines = VBoxContainer.new()
	lines.add_theme_constant_override("separation", 4)
	v.add_child(lines)
	next_button = Button.new()
	next_button.custom_minimum_size = Vector2(220, 64)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	next_button.focus_mode = Control.FOCUS_NONE
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
		var l := Label.new()
		l.text = String(text)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = PANEL_W - 44.0
		l.add_theme_font_size_override("font_size", 19)
		lines.add_child(l)
	next_button.text = go_word + " ›"
	panel.visible = true
	_pin()


## Bottom right at its own size, growing up and to the left: the carriage's
## name line and its people stay in sight above it.
func _pin() -> void:
	panel.reset_size()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
