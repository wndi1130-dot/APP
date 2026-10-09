extends Node3D

const Flow = preload("res://scripts/scene_flow.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const HOME_SCENE = preload("res://scenes/home.tscn")
const STATION_SCENE = preload("res://scenes/station.tscn")
const FIELD_SCENE = preload("res://scenes/field.tscn")
const NOTE_S: float = 3.5

var flow := Flow.new()
var active_scene: Node3D
var vat_assets: Dictionary
var settings: Dictionary = {"zombies": 100, "vertices": 1500, "visibility": true, "fog": true, "rain": true, "shadows": true}
var vat_cache: Dictionary = {}
var confident: bool = true
var metrics: Label
var hint: Label
var stop_button: Button
var field_button: Button
var noise_button: Button
var restart_button: Button
var posture_button: Button
var retry_button: Button
var loading_band: Label
var note: Label
var note_left: float = 0.0
var loading_started_ms: int = 0
var action_buttons: Dictionary = {}   # action -> Button, kept pressable (ui_states P3)
var count_button: Button
var vertex_button: Button
var samples: Array[float] = []
var hud_elapsed: float = 0.0
var last_frame_us: int = 0
var station_ready: bool = false

func _ready() -> void:
	# Prewarm once before the train; field transition does not bake VAT again.
	vat_assets = _vat_for(int(settings["vertices"]))
	_build_hud()
	_switch_scene(HOME_SCENE)
	_update_controls()

func _switch_scene(scene: PackedScene) -> void:
	if is_instance_valid(active_scene):
		remove_child(active_scene)
		active_scene.queue_free()
	active_scene = scene.instantiate() as Node3D
	if scene == FIELD_SCENE:
		active_scene.set("settings", settings.duplicate())
		active_scene.set("vat_assets", vat_assets)
	add_child(active_scene)

func _stop() -> void:
	if not flow.advance(Flow.Stage.BRAKING):
		return
	active_scene.connect("braking_finished", _on_braked, CONNECT_ONE_SHOT)
	active_scene.call("brake")
	_update_controls()

func _on_braked() -> void:
	if not flow.advance(Flow.Stage.LOADING):
		return
	loading_started_ms = Time.get_ticks_msec()
	_update_controls()
	await get_tree().create_timer(0.45).timeout
	_finish_loading()

func _finish_loading() -> void:
	if not flow.advance(Flow.Stage.STATION):
		return
	station_ready = false
	_switch_scene(STATION_SCENE)
	active_scene.call("set_posture", confident)
	active_scene.call("set_fog", bool(settings["fog"]))
	active_scene.connect("sequence_finished", _on_station_ready, CONNECT_ONE_SHOT)
	_update_controls()

## The retry past 8 s: run the load step again. A no-op once the stop is done.
func _retry_loading() -> void:
	if flow.stage == Flow.Stage.LOADING:
		_finish_loading()

func _loading_elapsed() -> float:
	if flow.stage != Flow.Stage.LOADING:
		return 0.0
	return float(Time.get_ticks_msec() - loading_started_ms) / 1000.0

## Band and retry follow the time spent loading; a quick load never shows them.
func _update_loading_note() -> void:
	var state: int = flow.loading_note(_loading_elapsed())
	loading_band.visible = state != Flow.LoadNote.NONE
	retry_button.visible = state == Flow.LoadNote.RETRY

func _on_station_ready() -> void:
	station_ready = true
	_update_controls()

func _enter_field() -> void:
	if not station_ready or not flow.advance(Flow.Stage.FIELD):
		return
	_switch_scene(FIELD_SCENE)
	samples.clear()
	_update_controls()

func _restart() -> void:
	if flow.stage != Flow.Stage.FIELD:
		return
	flow.reset()
	station_ready = false
	_switch_scene(HOME_SCENE)
	samples.clear()
	_update_controls()

func _toggle_posture() -> void:
	confident = not confident
	posture_button.text = "자세: 당당함" if confident else "자세: 처짐"
	if flow.stage == Flow.Stage.STATION:
		active_scene.call("set_posture", confident)

func _cycle_count() -> void:
	var counts: Array[int] = [50, 100, 150]
	var index := counts.find(int(settings["zombies"]))
	settings["zombies"] = counts[(index + 1) % counts.size()]
	count_button.text = "좀비: %d" % int(settings["zombies"])
	_apply_settings()

func _vat_for(target: int) -> Dictionary:
	# Bake each vertex level once; switching back reuses the cached mesh.
	if not vat_cache.has(target):
		vat_cache[target] = VatBaker.build(target)
	return vat_cache[target]

func _cycle_vertices() -> void:
	var levels: Array[int] = [144, 1500, 3000]
	var index := levels.find(int(settings["vertices"]))
	settings["vertices"] = levels[(index + 1) % levels.size()]
	vat_assets = _vat_for(int(settings["vertices"]))
	vertex_button.text = "정점: %d" % int(vat_assets["vertices"])
	if flow.stage == Flow.Stage.FIELD:
		active_scene.call("set_vat_assets", vat_assets)

func _toggle_setting(enabled: bool, key: String) -> void:
	settings[key] = enabled
	_apply_settings()

func _apply_settings() -> void:
	if flow.stage == Flow.Stage.FIELD:
		active_scene.call("apply_settings", settings)
	elif flow.stage == Flow.Stage.STATION:
		active_scene.call("set_fog", bool(settings["fog"]))

func _make_button(row: HBoxContainer, text: String, callback: Callable, action: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 44)
	if action == "":
		button.pressed.connect(callback)
	else:
		# Never switched off: a press that cannot act says why (_guarded).
		button.pressed.connect(_guarded.bind(action, button, callback))
		action_buttons[action] = button
	row.add_child(button)
	return button

func _guarded(action: String, button: Button, callback: Callable) -> void:
	var why := flow.why_blocked(action, station_ready)
	if why == "":
		callback.call()
		return
	_say(why)
	UiDeny.shake(button)

## One plain note at a time; a new one replaces the one showing.
func _say(text: String) -> void:
	note.text = text
	note.modulate.a = 1.0
	note_left = NOTE_S

func _make_toggle(row: HBoxContainer, text: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.button_pressed = bool(settings[key])
	toggle.custom_minimum_size = Vector2(140, 44)
	toggle.toggled.connect(_toggle_setting.bind(key))
	row.add_child(toggle)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR", "Noto Sans KR", "Droid Sans Fallback", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 20
	root.theme = theme
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.position = Vector2(12, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metrics = Label.new()
	metrics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(metrics)
	hint = Label.new()
	root.add_child(hint)
	hint.position = Vector2(600, 16)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note = Label.new()
	root.add_child(note)
	note.position = Vector2(600, 52)
	note.modulate.a = 0.0
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_band = Label.new()
	root.add_child(loading_band)
	loading_band.text = Flow.BAND_TEXT
	loading_band.position = Vector2(600, 88)
	loading_band.visible = false
	loading_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var controls := VBoxContainer.new()
	root.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 12
	controls.offset_right = -12
	controls.offset_top = -120
	controls.offset_bottom = -12
	var stages := HBoxContainer.new()
	controls.add_child(stages)
	stop_button = _make_button(stages, "정차", _stop, "stop")
	field_button = _make_button(stages, "필드 진입", _enter_field, "field")
	posture_button = _make_button(stages, "자세: 당당함", _toggle_posture, "posture")
	noise_button = _make_button(stages, "소음 (반경 12m)", _noise, "noise")
	restart_button = _make_button(stages, "홈부터 다시", _restart, "restart")
	retry_button = _make_button(stages, Flow.RETRY_TEXT, _retry_loading)
	retry_button.visible = false
	var features := HBoxContainer.new()
	controls.add_child(features)
	count_button = _make_button(features, "좀비: 100", _cycle_count)
	vertex_button = _make_button(features, "정점: %d" % int(vat_assets["vertices"]), _cycle_vertices)
	_make_toggle(features, "시야 가리기", "visibility")
	_make_toggle(features, "안개", "fog")
	_make_toggle(features, "비", "rain")
	_make_toggle(features, "그림자", "shadows")

func _noise() -> void:
	if flow.stage == Flow.Stage.FIELD:
		active_scene.call("emit_noise")

func _update_controls() -> void:
	for action: String in action_buttons:
		UiDeny.dim(action_buttons[action], flow.why_blocked(action, station_ready) != "")
	var messages := ["정차를 눌러 장면 흐름 시작", "감속 중 · 제동 소리 자리", "짧은 로딩…", "하차가 끝나면 필드 진입", "바닥 탭: 이동 · 소음 단추: 유인"]
	hint.text = messages[flow.stage]

func _process(delta: float) -> void:
	var now_us := Time.get_ticks_usec()
	if last_frame_us > 0:
		samples.append(float(now_us - last_frame_us) / 1000.0)
	last_frame_us = now_us
	if note_left > 0.0:
		note_left -= delta
		note.modulate.a = clampf(note_left / 0.8, 0.0, 1.0)
	_update_loading_note()
	if samples.size() > 120:
		samples.pop_front()
	hud_elapsed += delta
	if hud_elapsed < 0.25:
		return
	hud_elapsed = 0.0
	var total: float = 0.0
	var maximum: float = 0.0
	for value in samples:
		total += value
		maximum = maxf(maximum, value)
	var average := total / maxf(1, samples.size())
	var drawn: int = 0
	var elapsed: float = 0.0
	var noise_hits: int = 0
	if flow.stage == Flow.Stage.FIELD:
		drawn = int(active_scene.get("drawn_count"))
		elapsed = (Time.get_ticks_msec() - int(active_scene.get("field_started_ms"))) / 1000.0
		noise_hits = int(active_scene.get("noise_hits"))
	metrics.text = "%s | FPS %d\nFrame %.2f ms | Max(120f) %.2f ms\n좀비 제출 %d / 설정 %d | 필드 %.0f 초\n정점 %d (설정 %d) · 시야 %s · 안개 %s · 비 %s · 그림자 %s | 소음 반응 %d" % [flow.label(), Engine.get_frames_per_second(), average, maximum, drawn, int(settings["zombies"]), elapsed, int(vat_assets["vertices"]), int(settings["vertices"]), _on_off("visibility"), _on_off("fog"), _on_off("rain"), _on_off("shadows"), noise_hits]

func _on_off(key: String) -> String:
	return "ON" if bool(settings[key]) else "OFF"
