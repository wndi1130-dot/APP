extends Node3D

const Flow = preload("res://scripts/scene_flow.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const HOME_SCENE = preload("res://scenes/home.tscn")
const STATION_SCENE = preload("res://scenes/station.tscn")
const FIELD_SCENE = preload("res://scenes/field.tscn")

var flow := Flow.new()
var active_scene: Node3D
var vat_assets: Dictionary
var settings: Dictionary = {"zombies": 100, "visibility": true, "fog": true, "rain": true}
var confident: bool = true
var metrics: Label
var hint: Label
var stop_button: Button
var field_button: Button
var noise_button: Button
var restart_button: Button
var posture_button: Button
var count_button: Button
var samples: Array[float] = []
var hud_elapsed: float = 0.0
var last_frame_us: int = 0
var station_ready: bool = false

func _ready() -> void:
	# Prewarm once before the train; field transition does not bake VAT again.
	vat_assets = VatBaker.build()
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
	_update_controls()
	await get_tree().create_timer(0.45).timeout
	if not flow.advance(Flow.Stage.STATION):
		return
	station_ready = false
	_switch_scene(STATION_SCENE)
	active_scene.call("set_posture", confident)
	active_scene.call("set_fog", bool(settings["fog"]))
	active_scene.connect("sequence_finished", _on_station_ready, CONNECT_ONE_SHOT)
	_update_controls()

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

func _toggle_setting(enabled: bool, key: String) -> void:
	settings[key] = enabled
	_apply_settings()

func _apply_settings() -> void:
	if flow.stage == Flow.Stage.FIELD:
		active_scene.call("apply_settings", settings)
	elif flow.stage == Flow.Stage.STATION:
		active_scene.call("set_fog", bool(settings["fog"]))

func _make_button(row: HBoxContainer, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 44)
	button.pressed.connect(callback)
	row.add_child(button)
	return button

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
	var controls := VBoxContainer.new()
	root.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 12
	controls.offset_right = -12
	controls.offset_top = -120
	controls.offset_bottom = -12
	var stages := HBoxContainer.new()
	controls.add_child(stages)
	stop_button = _make_button(stages, "정차", _stop)
	field_button = _make_button(stages, "필드 진입", _enter_field)
	posture_button = _make_button(stages, "자세: 당당함", _toggle_posture)
	noise_button = _make_button(stages, "소음 (반경 12m)", _noise)
	restart_button = _make_button(stages, "홈부터 다시", _restart)
	var features := HBoxContainer.new()
	controls.add_child(features)
	count_button = _make_button(features, "좀비: 100", _cycle_count)
	_make_toggle(features, "시야 가리기", "visibility")
	_make_toggle(features, "안개", "fog")
	_make_toggle(features, "비", "rain")

func _noise() -> void:
	if flow.stage == Flow.Stage.FIELD:
		active_scene.call("emit_noise")

func _update_controls() -> void:
	stop_button.disabled = flow.stage != Flow.Stage.HOME
	field_button.disabled = flow.stage != Flow.Stage.STATION or not station_ready
	noise_button.disabled = flow.stage != Flow.Stage.FIELD
	restart_button.disabled = flow.stage != Flow.Stage.FIELD
	posture_button.disabled = flow.stage == Flow.Stage.FIELD
	var messages := ["정차를 눌러 장면 흐름 시작", "감속 중 · 제동 소리 자리", "짧은 로딩…", "하차가 끝나면 필드 진입", "바닥 탭: 이동 · 소음 단추: 유인"]
	hint.text = messages[flow.stage]

func _process(delta: float) -> void:
	var now_us := Time.get_ticks_usec()
	if last_frame_us > 0:
		samples.append(float(now_us - last_frame_us) / 1000.0)
	last_frame_us = now_us
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
	metrics.text = "%s | FPS %d\nFrame %.2f ms | Max(120f) %.2f ms\n좀비 제출 %d / 설정 %d | 필드 %.0f 초\n시야 %s · 안개 %s · 비 %s | 소음 반응 %d" % [flow.label(), Engine.get_frames_per_second(), average, maximum, drawn, int(settings["zombies"]), elapsed, _on_off("visibility"), _on_off("fog"), _on_off("rain"), noise_hits]

func _on_off(key: String) -> String:
	return "ON" if bool(settings[key]) else "OFF"
