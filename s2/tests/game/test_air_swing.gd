extends "res://addons/gut/test.gd"
## Decision 405 (as in Zomboid): the attack pad swings even with nobody in
## reach. The blow comes round all the same and lands on whatever is in its
## arc by then; with nothing there it only tires the arm and swishes.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const SimNoise = preload("res://game/sim/noise.gd")

var game
var p


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 17, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)
	p.facing = PI * 0.5   # east
	_hand("crowbar")
	game.sounds.clear()


func _hand(id: String) -> void:
	p.hands = [] if id == "" else [{"id": id, "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.set_weapon_slots(p.hands)


## The fight clock runs past the draw-back and the way back (zombies stand still).
func _land() -> void:
	for i in 40:
		game.combat.update(0.05)


func _was_hit(z: Dictionary) -> bool:
	return String(z["state"]) in ["dead", "downed"] or float(z.get("stun", 0.0)) > 0.0


func test_a_swing_at_nothing_starts_tires_and_swishes_but_hurts_none() -> void:
	var far: Dictionary = game.zombies.spawn("dead", p.position + Vector3(6, 0, 0))
	var tired: float = p.body.exhaustion
	game.combat.swing_air(p)
	assert_gt(p.strike_t, 0.0, "the weapon is drawn back")
	assert_eq(p.strike_kind, "swing")
	_land()
	assert_eq(game.sounds.size(), 1, "one swish")
	assert_eq(int(game.sounds[0]["level"]), SimNoise.Level.QUIET)
	assert_gt(p.body.exhaustion, tired, "it tires the arm")
	assert_false(_was_hit(far), "nobody out of reach is hurt")
	assert_eq(float(p.weapon()["condition"]), 1.0, "air does not wear the weapon")


func test_one_that_steps_into_the_arc_is_hit() -> void:
	game.combat.swing_air(p)
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.9, 0, 0))
	_land()
	assert_true(_was_hit(z))


func test_one_behind_is_not_hit() -> void:
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(-0.9, 0, 0))
	game.combat.swing_air(p)
	_land()
	assert_false(_was_hit(z))


func test_a_whole_window_in_the_arc_breaks() -> void:
	var c := Vector2i(-1, -1)
	var stand := Vector2i(-1, -1)
	for w in game.grid.windows:
		if game.grid.windows[w]["broken"]:
			continue
		for n in [w + Vector2i(1, 0), w + Vector2i(-1, 0), w + Vector2i(0, 1), w + Vector2i(0, -1)]:
			if not game.grid.blocks_body(n) and not game.grid.windows.has(n) and not game.grid.doors.has(n):
				c = w
				stand = n
				break
		if c.x >= 0:
			break
	assert_true(c.x >= 0, "the map has a whole window to stand at")
	p.position = game.lift(stand, 0)
	var to: Vector3 = FieldGrid.center(c) - p.position
	p.facing = atan2(to.x, to.z)
	game.combat.swing_air(p)
	_land()
	assert_true(game.grid.windows[c]["broken"])


func test_bare_hands_shove_the_air() -> void:
	_hand("")
	game.combat.swing_air(p)
	assert_gt(p.shove_t, 0.0)


func test_the_attack_pad_with_nobody_in_reach_swings() -> void:
	game.hud._pad_down(game.hud.attack_button, Vector2.ZERO)
	assert_gt(p.strike_t, 0.0)
