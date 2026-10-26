extends "res://addons/gut/test.gd"
## Decision 444 (전투 손맛 C): a blow is felt. The field holds a moment as the
## player's own blow lands, the camera kicks the way it went and settles, the
## phone buzzes, and the blow sounds by the weapon; a miss is the swing alone.
## None of it is read back by the rules (hit_feel.gd).

const FieldGame = preload("res://game/field_game.gd")
const HitFeel = preload("res://game/hit_feel.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const W = preload("res://game/sim/weapons.gd")

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
	_hand(p, "crowbar")
	game.audio.played.clear()


func _hand(who, id: String) -> void:
	who.hands = [] if id == "" else [{"id": id, "quality": "factory", "condition": 1.0, "loaded": 0}]
	who.set_weapon_slots(who.hands)


## The fight clock runs past the draw-back and the way back (zombies stand still).
func _land() -> void:
	for i in 40:
		game.combat.update(0.05)


func _hold_for(weapon: String) -> float:
	return HitFeel.STOP_BASE + HitFeel.STOP_PER_KG * float(W.get_data(weapon)["weight"])


func test_the_players_blow_holds_the_field_kicks_the_camera_and_buzzes() -> void:
	game.zombies.spawn("dead", p.position + Vector3(0.9, 0, 0))
	game.combat.swing_air(p)
	assert_true(game.audio.played.has("swing_heavy"), "a crowbar comes round with the heavy whoosh")
	_land()
	var f = game.feel
	assert_true(f.holding(), "the field holds")
	assert_between(f.hold_t, _hold_for("crowbar"), _hold_for("crowbar") + HitFeel.STOP_FELLED + 0.0001)
	assert_true(game.audio.played.has("hit_blunt"), "a crowbar lands blunt")
	var kick: Vector3 = f.camera_offset()
	assert_gt(kick.length(), 0.0, "the camera kicks")
	assert_gt(kick.x, 0.0, "the way the blow went (east)")
	assert_false(f.last_buzz.is_empty(), "the phone buzzes")


func test_the_blow_sounds_ship() -> void:
	var a = game.audio
	var counts := {"swing_light": 3, "swing_heavy": 3, "hit_blunt": 3, "hit_blade": 3, "hit_stomp": 2}
	for g: String in counts:
		assert_true(a.GROUPS.has(g), g)
		var list: Array = a._load_group(g)
		assert_eq(list.size(), int(counts[g]), g)
		for s in list:
			assert_gt(s.get_length(), 0.1, g)


func test_a_heavier_weapon_holds_longer() -> void:
	assert_lt(_hold_for("knife"), _hold_for("crowbar"))
	assert_lt(_hold_for("crowbar"), _hold_for("axe"))
	assert_almost_eq(_hold_for("axe"), 0.075, 0.0001)
	assert_lt(_hold_for("axe") + HitFeel.STOP_FELLED, HitFeel.STOP_MAX + 0.0001, "the longest hold is under the cap")


func test_an_edge_lands_with_its_own_sound() -> void:
	_hand(p, "knife")
	game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	game.combat.swing_air(p)
	assert_true(game.audio.played.has("swing_light"), "a knife whooshes light")
	_land()
	assert_true(game.audio.played.has("hit_blade"))
	assert_false(game.audio.played.has("hit_blunt"))


func test_a_miss_is_the_swing_alone_not_a_crash_of_glass() -> void:
	game.combat.swing_air(p)
	_land()
	assert_true(game.audio.played.has("swing_heavy"))
	for g in ["hit_blunt", "hit_blade", "hit_stomp"]:
		assert_false(game.audio.played.has(g), "no blow lands on air")
	assert_ne(game.audio.last_tag_group, "impact", "the swish is not a random crash any more")
	assert_false(game.feel.holding(), "nothing to hold for")


func test_a_companions_blow_is_heard_but_neither_holds_nor_shakes() -> void:
	var ally = null
	for o in game.allies_alive():
		if o != p:
			ally = o
			break
	assert_not_null(ally, "the stop has a companion")
	ally.position = p.position + Vector3(0, 0, 3)
	ally.facing = PI * 0.5
	_hand(ally, "axe")
	game.zombies.spawn("dead", ally.position + Vector3(0.9, 0, 0))
	game.combat.swing_air(ally)
	_land()
	assert_true(game.audio.played.has("hit_blade"), "a hatchet is an edge")
	assert_false(game.feel.holding())
	assert_eq(game.feel.camera_offset(), Vector3.ZERO)
	assert_true(game.feel.last_buzz.is_empty())


func test_the_hold_stands_the_rules_and_the_people_and_then_lets_go() -> void:
	game.feel.hold_t = 0.05
	var t0: float = game.clock.elapsed
	game._process(0.02)
	assert_true(game.hitstop)
	assert_eq(game.clock.elapsed, t0, "the rules do not step through a hold")
	assert_eq(PersonVisual.frame_delta(game, 0.02), 0.0, "the people stand with it")
	for i in 4:
		game._process(0.02)
	assert_false(game.hitstop)
	assert_gt(game.clock.elapsed, t0, "after it the field goes on")


func test_no_second_hold_straight_after_one() -> void:
	var f = game.feel
	f._hold(0.05)
	f.tick(0.06, true)
	assert_false(f.holding())
	f._hold(0.05)
	assert_false(f.holding(), "within the rest after a hold, none")
	f.tick(HitFeel.STOP_REST, true)
	f._hold(0.05)
	assert_true(f.holding())


func test_the_kick_settles() -> void:
	var f = game.feel
	f._kick(Vector3(1, 0, 0), 0.01)
	assert_gt(f.camera_offset().length(), 0.005)
	for i in 30:
		f.tick(0.02, true)
	assert_eq(f.camera_offset(), Vector3.ZERO, "gone within half a second")


func test_paused_the_hold_waits() -> void:
	var f = game.feel
	f.hold_t = 0.05
	f.tick(0.5, false)
	assert_almost_eq(f.hold_t, 0.05, 0.0001, "a pause does not eat the hold")


func test_a_bite_on_the_player_holds_and_shakes_hardest() -> void:
	game.feel.bitten(p, false)
	assert_almost_eq(game.feel.hold_t, HitFeel.STOP_BITTEN, 0.0001)
	assert_almost_eq(game.feel.camera_offset().length(), HitFeel.SHAKE_BITTEN, 0.0001)
	assert_eq(int(game.feel.last_buzz[0]), int(HitFeel.BUZZ_BITTEN[0]))


func test_the_players_shot_kicks_back_from_where_it_went() -> void:
	game.feel.shot(p, "shotgun", p.position + Vector3(5, 0, 0))
	var kick: Vector3 = game.feel.camera_offset()
	assert_lt(kick.x, 0.0, "back, away from the shot")
	assert_false(game.feel.holding(), "a shot does not hold the field")


# At 30 frames a second a frame is longer than the lightest holds: the hold is
# read as the frame starts, so even those stand one whole frame.
func test_a_hold_shorter_than_a_frame_still_stands_one_frame() -> void:
	game.feel.hold_t = 0.03
	var t0: float = game.clock.elapsed
	game._process(1.0 / 30.0)
	assert_true(game.hitstop)
	assert_eq(game.clock.elapsed, t0)
	game._process(1.0 / 30.0)
	assert_false(game.hitstop)
	assert_gt(game.clock.elapsed, t0)


func test_a_real_blow_on_the_frames_holds_the_rules() -> void:
	game.zombies.spawn("dead", p.position + Vector3(0.9, 0, 0))
	game.combat.swing_air(p)
	var frames := 0
	while not game.feel.holding() and frames < 60:
		game._process(1.0 / 30.0)
		frames += 1
	assert_true(game.feel.holding(), "the blow lands within two seconds of frames")
	var t0: float = game.clock.elapsed
	game._process(1.0 / 30.0)
	assert_true(game.hitstop)
	assert_eq(game.clock.elapsed, t0, "the frame after the blow, the rules stand")


func test_a_weapon_that_breaks_on_the_blow_still_sounds_it() -> void:
	p.hands = [{"id": "broken_bottle", "quality": "factory", "condition": 0.01, "loaded": 0}]
	p.set_weapon_slots(p.hands)
	game.zombies.spawn("dead", p.position + Vector3(0.7, 0, 0))
	game.combat.swing_air(p)
	_land()
	assert_eq(p.weapon_id(), "", "the bottle went to pieces")
	assert_true(game.audio.played.has("hit_blade"), "the blow that broke it is heard")


func test_a_field_with_no_frames_keeps_only_a_few_kicks() -> void:
	for i in 40:
		game.feel.shot(p, "pistol", p.position + Vector3(5, 0, 0))
	assert_eq(game.feel.kicks.size(), HitFeel.KICKS_MAX)
