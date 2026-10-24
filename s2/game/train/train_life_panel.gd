extends PanelContainer
## A fold-out part of the existing test panel. These controls only edit its input.

const Catalog = preload("res://game/train/train_catalog.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")
const LAW_NAMES := {
	"common_kitchen": "공동 취사", "contribution_ration": "기여 배급", "common_heating": "공동 난방",
	"heat_quota": "난방 배당", "child_labor": "아동 노동", "child_pack": "짐 꾸리기",
	"treat_all": "모두 치료", "triage": "중환자 분류", "triage_std": "분류 기준",
	"edu_letters": "글과 셈", "edu_trade": "일 배우기", "edu_engine": "엔진의 가르침",
	"corpse_store": "안치", "corpse_throw": "시신 처리", "corpse_burn": "화장",
	"evening_pot": "저녁 솥", "night_of_names": "추모의 밤", "wall_ledger": "벽 장부",
	"emergency_powers": "비상대권", "secret_ballot": "비밀 투표", "apprentice_duty": "견습",
}
var hand: CanvasLayer
var scene: Node3D
var controls: Dictionary = {}
var status: Label
var stage_picker: OptionButton
var law_picker: OptionButton
var interaction_picker: OptionButton
var _grid: GridContainer
var _filling: bool = false


func _ready() -> void:
	theme = UiTheme.make(18)
	position = Vector2(16, 16)
	size = Vector2(540, 420)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 420)
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var close := Button.new()
	close.text = "생활 값 · 접기"
	close.pressed.connect(func() -> void: hide())
	column.add_child(close)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	_grid = GridContainer.new()
	_grid.columns = 2
	column.add_child(_grid)
	for row in [["train.coal", "석탄", 1000], ["train.food", "식량", 1000], ["train.med", "약", 1000],
		["train.lux", "물품", 1000], ["dom.wood", "목재", 1000], ["dom.scrap", "고철", 1000], ["dom.parts", "부품", 1000],
		["train.hunger", "굶은 구간", 30], ["train.injured", "다친 사람", 30], ["train.sickCount", "아픈 사람", 30],
		["train.stored", "안치 수", 30], ["train.trust", "신임", 100], ["train.decreeLeft", "비상대권 구간", 20], ["train.seg", "구간", 100]]:
		_number(row[0], row[1], row[2])
	_enum("view.daytime", "낮밤", ["day", "night"], ["낮", "밤"])
	_enum("view.motion", "열차", ["auto", "running", "stopped", "departing"], ["단계에 따름", "달림", "정차", "출발 직전"])
	# The season table's four states (game/season_table.gd); unset, the stretch's own.
	_enum("view.season", "계절", ["late_autumn", "early_winter", "deep_winter", "early_thaw"], ["늦가을", "초겨울", "한겨울", "해빙 초입"])
	_enum("stop.weather", "날씨", ["overcast", "snow", "fog", "sleet", "clear", "blizzard"], ["흐림", "눈", "안개", "진눈깨비", "맑음", "눈보라(화면)"])
	_enum("view.riot_stage", "폭동 입력", ["none", "protest", "riot"], ["없음", "항의", "폭동"])
	_text("view.region", "지역 띠")
	_text("view.country", "나라")
	for row in [["view.work_time", "일 시간"], ["view.meal_time", "밥 시간"], ["view.memorial", "추모"],
		["view.teacher_present", "교사 있음"], ["view.accident", "사고 신호"], ["train.council.martial", "계엄 회기"],
		["view.outside.chasing", "창밖: 쫓는 망자"], ["view.outside.refugees", "창밖: 피난민"], ["view.outside.passing", "창밖: 지나침"]]:
		_toggle(row[0], row[1])
	_label("이 칸의 화면 단계")
	stage_picker = OptionButton.new()
	stage_picker.add_item("값에서 고름", -1)
	for row in Catalog.data()["collapse"]:
		stage_picker.add_item(row["name"], int(row["id"]))
	stage_picker.item_selected.connect(_stage)
	_grid.add_child(stage_picker)
	_label("법")
	law_picker = OptionButton.new()
	for id in LAW_NAMES:
		law_picker.add_item(LAW_NAMES[id])
	_grid.add_child(law_picker)
	_button("고른 법 켜기·끄기", _law)
	_button("이 칸 단열 켜기·끄기", _insulate)
	_label("맞물림 장면")
	interaction_picker = OptionButton.new()
	var labels := ["수다", "가르치기", "짐 넘기기", "둘이 들기", "부축", "어깨 툭", "간병", "의회", "교실", "밀침", "맞붙기", "치우기"]
	var i := 0
	for id in Catalog.data()["interactions"]:
		interaction_picker.add_item(labels[i])
		i += 1
	_grid.add_child(interaction_picker)
	_button("고른 장면 시작", _start)
	_button("교실 역할 보기", _classroom_sample)
	for row in [["bell", "종"], ["wrench", "렌치"], ["interrupt", "장면 끊기"], ["cleanup", "치우기"]]:
		_button(row[1], func() -> void: scene.life_signal(row[0], _car_id()))
	scene.rules_applied.connect(fill)
	fill()


func fill() -> void:
	if scene == null or status == null or scene.cars.is_empty():
		return
	_filling = true
	for path in controls:
		var node: Control = controls[path]
		var value = Catalog.field_value(scene.rules, path)
		if node is SpinBox:
			node.set_value_no_signal(float(value if value != null else 0))
		elif node is CheckButton:
			node.set_pressed_no_signal(value == true)
		elif node is OptionButton:
			node.select(maxi(0, (node.get_meta("values") as Array).find(value)))
		elif node is LineEdit and not node.has_focus():
			node.text = str(value if value != null else "")
	var id := _car_id()
	var c: Dictionary = scene.life.contexts.get(id, {})
	if not c.is_empty():
		var stage: int = int(scene.rules.get("view", {}).get("collapse_by_car", {}).get(id, -1))
		stage_picker.select(stage + 1)
		status.text = "%s · %s · 화면용 첫 값" % [scene.car(id)["def"]["name"], Catalog.data()["collapse"][int(c["stage"])]["name"]]
	_filling = false


## 부모 판의 번호가 아직 옛 편성을 가리켜도 칸 목록 밖을 읽지 않는다.
func _car_id() -> String:
	if scene == null or scene.cars.is_empty():
		return ""
	var i: int = hand.car_i if hand != null else 0
	return String(scene.cars[clampi(i, 0, scene.cars.size() - 1)]["id"])


func _changed(value, path: String) -> void:
	if not _filling:
		scene.set_value(path, value)


func _number(path: String, label_text: String, maximum: float) -> void:
	_label(label_text)
	var spin := SpinBox.new()
	spin.max_value = maximum
	spin.step = 1
	spin.value_changed.connect(_changed.bind(path))
	_grid.add_child(spin)
	controls[path] = spin


func _enum(path: String, label_text: String, values: Array, labels: Array) -> void:
	_label(label_text)
	var picker := OptionButton.new()
	for label_text_i in labels:
		picker.add_item(label_text_i)
	picker.set_meta("values", values)
	picker.item_selected.connect(func(index: int) -> void: _changed(values[index], path))
	_grid.add_child(picker)
	controls[path] = picker


func _toggle(path: String, label_text: String) -> void:
	_label(label_text)
	var toggle := CheckButton.new()
	toggle.toggled.connect(_changed.bind(path))
	_grid.add_child(toggle)
	controls[path] = toggle


func _text(path: String, label_text: String) -> void:
	_label(label_text)
	var edit := LineEdit.new()
	edit.text_submitted.connect(_changed.bind(path))
	_grid.add_child(edit)
	controls[path] = edit


func _label(words: String) -> void:
	var label := Label.new()
	label.text = words
	_grid.add_child(label)


func _button(words: String, action: Callable) -> void:
	var button := Button.new()
	button.text = words
	button.pressed.connect(action)
	_grid.add_child(button)


func _stage(index: int) -> void:
	if _filling:
		return
	var values: Dictionary = scene.rules.get("view", {}).get("collapse_by_car", {}).duplicate(true)
	values[_car_id()] = index - 1
	scene.set_value("view.collapse_by_car", values)


func _law() -> void:
	var id: String = LAW_NAMES.keys()[law_picker.selected]
	var values: Dictionary = scene.rules["train"].get("passed", {}).duplicate(true)
	if values.has(id):
		values.erase(id)
	else:
		values[id] = 1
	scene.set_value("train.passed", values)


func _insulate() -> void:
	var values: Array = scene.rules.get("dom", {}).get("insulated", []).duplicate()
	if values.has(_car_id()):
		values.erase(_car_id())
	else:
		values.append(_car_id())
	scene.set_value("dom.insulated", values)


func _start() -> void:
	var id: String = Catalog.data()["interactions"].keys()[interaction_picker.selected]
	var started: bool = scene.life.start_interaction(id, _car_id())
	status.text = "장면 시작" if started else "지금 자리가 닫혔거나 역할·빈자리가 모자람"


func _classroom_sample() -> void:
	if scene.car(_car_id())["def"].get("kind") != "dining":
		status.text = "식당칸에서 교실 역할을 본다"
		return
	var actors: Dictionary = scene.rules.get("view", {}).get("actors", {}).duplicate(true)
	actors[_car_id()] = {"0": {"role": "teacher"}, "1": {"child": true}, "2": {"child": true}, "3": {"child": true}}
	scene.set_value("view.actors", actors)
	var passed: Dictionary = scene.rules["train"].get("passed", {}).duplicate(true)
	passed["edu_letters"] = 1
	scene.set_value("train.passed", passed)
