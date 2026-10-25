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
