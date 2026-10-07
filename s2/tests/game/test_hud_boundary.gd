extends "res://addons/gut/test.gd"
## The HUD gives orders through field_combat (fight, call_off, stop_fight,
## drop_melee, drop_target, stop_holding); it never writes the fight state
## (targets, hold, goal, path) of the player itself.

const WRITES := [
	"\\.target_zombie\\s*=[^=]", "\\.target_person\\s*=[^=]", "\\.hold_attack\\s*=[^=]",
	"\\.path\\s*=[^=]", "brain\\.erase\\(\"goal\"\\)", "brain\\[\"goal\"\\]\\s*=[^=]",
]
# Orders to a companion from its card are commands, not the player's fight.
const ALLOWED := ["func _command("]


func test_hud_does_not_write_the_fight_state() -> void:
	var text := FileAccess.get_file_as_string("res://game/ui/field_hud.gd")
	assert_ne(text, "")
	var found: Array[String] = []
	var in_allowed := false
	var n := 0
	for line: String in text.split("\n"):
		n += 1
		if line.begins_with("func "):
			in_allowed = ALLOWED.any(func(a: String) -> bool: return line.begins_with(a))
		if in_allowed or line.strip_edges().begins_with("#"):
			continue
		for w: String in WRITES:
			if RegEx.create_from_string(w).search(line) != null:
				found.append("%d: %s" % [n, line.strip_edges()])
	assert_eq(found, [] as Array[String])
