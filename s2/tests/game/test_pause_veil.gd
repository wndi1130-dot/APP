extends "res://addons/gut/test.gd"
## 정지 가림막(pause_veil.gd, 사용자 2026-10-25: 정지를 눌렀을 때 정지인 걸 알아챌 무언가):
## 정지면 서서히 올라오고, 패널이 열리면 비켜서고, 그동안 세상의 입자(눈·연기)는 멈췄다가 풀면 이어 간다.

const PauseVeil = preload("res://game/ui/pause_veil.gd")


class FakeGame extends Node3D:
	var paused: bool = false
	var ended: bool = false


class FakeHud extends Node:
	const TOP_ROW_H: float = 58.0
	var game
	var modal_open: bool = false
	var pause_button: Control = null
	var radio_pill: Control = null


func _setup() -> Array:
	var game: FakeGame = add_child_autofree(FakeGame.new())
	var snow := GPUParticles3D.new()
	snow.speed_scale = 0.8
	game.add_child(snow)
	var hud: FakeHud = add_child_autofree(FakeHud.new())
	hud.game = game
	var veil: Control = add_child_autofree(PauseVeil.new())
	veil.setup(hud)
	return [game, snow, hud, veil]


func test_the_veil_comes_up_while_paused_and_goes_after() -> void:
	var s := _setup()
	var game: FakeGame = s[0]
	var veil = s[3]
	veil._process(0.5)
	assert_eq(veil.shown, 0.0, "nothing while playing")
	assert_false(veil.visible)
	game.paused = true
	veil._process(PauseVeil.EASE * 0.5)
	assert_between(veil.shown, 0.1, 0.9, "it comes up over a moment")
	veil._process(PauseVeil.EASE)
	assert_eq(veil.shown, 1.0)
	assert_true(veil.visible)
	game.paused = false
	veil._process(PauseVeil.EASE * 2.0)
	assert_eq(veil.shown, 0.0, "and goes when play goes on")


## Each pause shows a world line under the word, the next one each time, never the one just read.
func test_each_pause_shows_the_next_world_line() -> void:
	var s := _setup()
	var game: FakeGame = s[0]
	var veil = s[3]
	var lines: Array = PauseVeil.WorldLines.LINES
	var got: Array = []
	for i in range(3):
		game.paused = true
		veil._process(PauseVeil.EASE)
		assert_true(lines.has(veil.line), "a world line while paused")
		got.append(veil.line)
		var held: String = veil.line
		veil._process(PauseVeil.EASE * 0.5)
		assert_eq(veil.line, held, "the same line while the pause lasts")
		game.paused = false
		veil._process(PauseVeil.EASE * 2.0)
	for i in range(1, got.size()):
		assert_ne(got[i], got[i - 1], "a new line each pause")
		assert_eq(lines.find(got[i]), (lines.find(got[i - 1]) + 1) % lines.size(), "the one after the last")


## A panel over a pause hides the veil and gives it back with the same line; a pause
## ended and begun again before the veil has gone shows the next line.
func test_a_line_is_drawn_once_per_pause_not_per_showing() -> void:
	var s := _setup()
	var game: FakeGame = s[0]
	var hud: FakeHud = s[2]
	var veil = s[3]
	var lines: Array = PauseVeil.WorldLines.LINES
	game.paused = true
	veil._process(PauseVeil.EASE)
	var first: String = veil.line
	hud.modal_open = true
	veil._process(PauseVeil.EASE * 2.0)
	assert_eq(veil.shown, 0.0, "the panel's own shade")
	hud.modal_open = false
	veil._process(PauseVeil.EASE)
	assert_eq(veil.line, first, "back from the panel: the same pause, the same line")
	game.paused = false
	veil._process(PauseVeil.EASE * 0.25)
	assert_gt(veil.shown, 0.0, "the veil not gone yet")
	game.paused = true
	veil._process(PauseVeil.EASE * 0.25)
	assert_eq(lines.find(veil.line), (lines.find(first) + 1) % lines.size(), "a new pause, the next line")


## The line is the radio call's body size (field_hud.gd radio_label), the HUD's own words.
func test_the_line_is_the_radio_calls_size() -> void:
	assert_eq(PauseVeil.LINE_SIZE, PauseVeil.UiFonts.size(PauseVeil.LINE_CSS))


## The longest line fits the narrowest field screen (1280 wide at 720 high) with room either side.
func test_the_longest_world_line_fits_the_screen() -> void:
	var face: Font = PauseVeil.UiFonts.face(PauseVeil.UiFonts.WORD, 600, 0.0)
	var widest: float = 0.0
	for line: String in PauseVeil.WorldLines.LINES:
		widest = maxf(widest, face.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, PauseVeil.LINE_SIZE).x)
	assert_gt(widest, 0.0)
	assert_lte(widest, 1280.0 - 2.0 * 160.0, "clear of the screen's sides and the corner keys")


## The radio's call (field_hud radio_pill) never covers the line: a call over the line's
## strip, of any length, puts the line under its foot; one beside it leaves the line where it was.
func test_the_world_line_keeps_clear_of_the_radio_call() -> void:
	var s := _setup()
	var hud: FakeHud = s[2]
	var veil = s[3]
	var wanted: float = 238.0
	var tall: float = PauseVeil.LINE_SIZE * 1.9
	var span := Vector2(430.0, 855.0)
	assert_eq(PauseVeil.clear_of_radio(wanted, tall, span, Rect2()), wanted, "no call: where it was")
	assert_eq(PauseVeil.clear_of_radio(wanted, tall, span, Rect2(900, 85, 300, 175)), wanted, "a call beside it: where it was")
	for foot: float in [220.0, 260.0, 300.0]:   # three, four, five lines of call
		var mid: float = PauseVeil.clear_of_radio(wanted, tall, span, Rect2(760, 85, 410, foot - 85.0))
		assert_gte(mid - tall * 0.5, foot + PauseVeil.LINE_CLEAR - 0.01, "under the call's foot at %d" % int(foot))
	# The veil reads the call from the HUD as it stands on screen.
	var pill := Control.new()
	add_child_autofree(pill)
	pill.position = Vector2(760, 85)
	pill.size = Vector2(410, 175)
	hud.radio_pill = pill
	assert_eq(veil._radio_rect(), Rect2(760, 85, 410, 175))
	pill.visible = false
	assert_eq(veil._radio_rect(), Rect2(), "a hidden call is no call")


func test_a_panel_brings_its_own_shade() -> void:
	var s := _setup()
	var game: FakeGame = s[0]
	var hud: FakeHud = s[2]
	var veil = s[3]
	game.paused = true
	hud.modal_open = true
	veil._process(1.0)
	assert_eq(veil.shown, 0.0, "the settings pane is over it")
	game.ended = true
	hud.modal_open = false
	veil._process(1.0)
	assert_eq(veil.shown, 0.0, "not at the end")


func test_what_falls_holds_still_while_paused() -> void:
	var s := _setup()
	var game: FakeGame = s[0]
	var snow: GPUParticles3D = s[1]
	var veil = s[3]
	game.paused = true
	veil._process(0.1)
	assert_eq(snow.speed_scale, 0.0, "the snow stops where it is")
	game.paused = false
	veil._process(0.1)
	assert_eq(snow.speed_scale, 0.8, "and falls on at its own speed")


## The bodies' motions hold too: fx_still counts the seconds stood paused, and
## stays where it is while the field plays (the shader runs on TIME - fx_still).
func test_the_bodies_hold_still_while_paused() -> void:
	var s := _setup()
	var game: FakeGame = s[0]
	var veil = s[3]
	veil._process(0.5)
	assert_eq(veil.still, 0.0, "nothing counted while playing")
	game.paused = true
	veil._process(0.25)
	veil._process(0.25)
	assert_almost_eq(veil.still, 0.5, 0.0001)
	game.paused = false
	veil._process(1.0)
	assert_almost_eq(veil.still, 0.5, 0.0001, "kept, so the motions go on from where they stood")
