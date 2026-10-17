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
const TRAIN_SCENE := preload("res://game/train/train.tscn")
const BOOT_SCENE := "res://scenes/boot.tscn"
## The receipt the receipt panel shows when the field was skipped (tests).
const RECEIPT_SAMPLE := "res://tests/game/fixtures/receipt_gd_sample.json"

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
	"stop_pick": ["술레후프 · 얼어붙은 급수탑 옆 작은 역", "정차 카드 · 작업조 · 위험 줄 자리"],
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
	_show_panel(String(row[3]), _lines_of(id), String(row[4]))


func next() -> void:
	if step + 1 >= STEPS.size():
		get_tree().change_scene_to_file(BOOT_SCENE)
		return
	go(step + 1)


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
	field.opts = o
	field.finished.connect(_field_done)
	add_child(field)
	stage = field


## The field is over: its end card stays where it is, and a key over it goes
## on to the receipt.
func _field_done(r: Dictionary) -> void:
	result = r
	receipt = r.get("receipt", {}) if not r.is_empty() else _sample_receipt()
	if field == null:
		go(step + 1)
		return
	_show_panel("", [], "귀환 영수증")
	panel.visible = true


func _sample_receipt() -> Dictionary:
	if not FileAccess.file_exists(RECEIPT_SAMPLE):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RECEIPT_SAMPLE))
	return parsed if parsed is Dictionary else {}


func _lines_of(id: String) -> Array:
	if id == "receipt":
		return receipt_lines(receipt)
	return NOTES.get(id, [])


## What the plain receipt panel lists: the place and the hours, the stock in
## and out, who came back how, and the promises.
static func receipt_lines(r: Dictionary) -> Array:
	if r.is_empty():
		return ["영수증 없음"]
	var out: Array = []
	var place: Dictionary = r.get("place", {})
	var time: Dictionary = r.get("time", {})
	out.append("%s · %s → %s" % [place.get("id", "?"), time.get("arrive", "?"), time.get("depart", "?")])
	var stock: Dictionary = r.get("stock", {})
	var parts: Array = []
	for k in stock:
		parts.append("%s %+d" % [k, int(stock[k])])
	if not parts.is_empty():
		out.append("물자: " + ", ".join(parts))
	var people: Dictionary = r.get("people", {})
	var who: Array = []
	for k in ["sent", "injured", "bitten", "dead", "missing", "leftBehind", "rescued"]:
		var n: int = (people.get(k, []) as Array).size()
		if n > 0:
			who.append("%s %d" % [k, n])
	if not who.is_empty():
		out.append("사람: " + ", ".join(who))
	for p in r.get("promises", []):
		out.append("약속: %s · %s" % [p.get("condition", "?"), "지킴" if p.get("kept", false) else "어김"])
	out.append("끝: %s" % r.get("endReason", "?"))
	return out


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.theme = theme
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.07, 0.86)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	# Top right, growing to the left and down: the train's people stay in sight.
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -24.0
	panel.offset_top = 24.0
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	layer.add_child(panel)
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


func _show_panel(head: String, rows: Array, go_word: String) -> void:
	title.text = head
	title.visible = head != ""
	for c in lines.get_children():
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
	panel.reset_size()
