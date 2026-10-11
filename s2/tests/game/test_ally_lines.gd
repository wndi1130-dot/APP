extends "res://addons/gut/test.gd"
## What a companion shouts (user 2026-10-12): words over their head, not too
## often, and never the chief.

const FieldGame = preload("res://game/field_game.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const AllyLines = preload("res://game/sim/ally_lines.gd")

var game
var mate
var other


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 4, "auto_pause": false, "raiders": false}
	add_child_autofree(game)
	game.set_process(false)
	var mates: Array = game.squad.filter(func(p): return p != game.player)
	mate = mates[0]
	other = mates[1]


func _line_of(p) -> String:
	for s in game.hud.says:
		if s["p"] == p:
			return String(s["line"])
	return ""


func test_every_event_has_a_line_and_a_bite_elsewhere_borrows_one() -> void:
	for event in ["hurt", "bite_leg", "grabbed", "rage", "left_behind"]:
		assert_gt(AllyLines.lines_for(event).size(), 0, event)
	assert_eq(AllyLines.lines_for("bite"), AllyLines.lines_for("hurt"))
	assert_eq(AllyLines.lines_for("no_such_thing"), [])


func test_one_person_does_not_shout_again_at_once_nor_the_squad_all_together() -> void:
	var lines := AllyLines.new()
	assert_ne(lines.pick("a", "hurt", 10.0), "")
	assert_eq(lines.pick("a", "grabbed", 12.0), "", "the same person, too soon")
	assert_eq(lines.pick("b", "hurt", 11.0), "", "someone else, on top of the first")
	assert_ne(lines.pick("b", "hurt", 10.0 + AllyLines.GAP_SQUAD + 0.1), "")
	assert_ne(lines.pick("a", "grabbed", 10.0 + AllyLines.GAP_SELF + 0.1), "")


func test_a_bitten_leg_is_shouted_over_the_companion_with_the_note_under_it() -> void:
	game.say(mate, "%s 다리를 물렸다." % mate.display_name, true, "bite_leg")
	assert_eq(game.hud.says.size(), 1, "one entry a person")
	assert_eq(_line_of(mate), "다리가 물렸어!!")
	assert_eq(String(game.hud.says[0]["text"]), "다리를 물렸다.", "what happened stays, under the line")
	assert_gte(float(game.hud.says[0]["t"]), FieldHud.LINE_S - 0.01)
	game.hud._tick_says(FieldHud.LINE_S + 0.1)
	assert_eq(game.hud.says.size(), 0, "and it goes away")


func test_the_chief_and_the_dead_keep_quiet() -> void:
	game.say(game.player, "열차장 긁혔다.", true, "hurt")
	assert_eq(game.hud.says.size(), 0)
	mate.body.dead = true
	game.shout(mate, "hurt")
	assert_eq(_line_of(mate), "")


func test_grabbed_they_call_for_help() -> void:
	game.shout(mate, "grabbed")
	assert_eq(_line_of(mate), "살려줘 살려줘!!")


func test_when_one_falls_the_nearest_companion_rages() -> void:
	mate.position = game.player.position + Vector3(30, 0, 0)
	other.position = mate.position + Vector3(2, 0, 0)
	game.on_person_died(mate)
	assert_eq(_line_of(other), "이 개새끼들")


func test_lying_hurt_with_the_chief_far_off_they_beg_not_to_be_left() -> void:
	mate.body.downed = true
	mate.position = game.player.position + Vector3(AllyLines.LEFT_BEHIND_M - 2.0, 0, 0)
	game._left_behind()
	assert_eq(_line_of(mate), "", "the chief is still near")
	mate.position = game.player.position + Vector3(AllyLines.LEFT_BEHIND_M + 2.0, 0, 0)
	game._left_behind()
	assert_eq(_line_of(mate), "제발... 두고가지마")
	game.hud.says.clear()
	game.clock.elapsed += AllyLines.GAP_SELF + 1.0
	game._left_behind()
	assert_eq(_line_of(mate), "", "not over and over")
	game.clock.elapsed += AllyLines.LEFT_BEHIND_GAP
	game._left_behind()
	assert_eq(_line_of(mate), "제발... 두고가지마")
