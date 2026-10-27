extends "res://addons/gut/test.gd"
## 소리 물결(결정 471 H1): 우리 쪽이 문을 차거나 창을 깨거나 장작을 패면, 또 플레이어가 뛰면 그 소리가
## 닿는 넓이가 바닥에 옅은 동그라미로 1초 보인다. 반경은 make_sound가 잰 그대로(누가 듣는지는 그대로),
## 망자·열차·다른 소리는 그리지 않는다.

const FieldGame = preload("res://game/field_game.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const SoundRipple = preload("res://game/world/sound_ripple.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.player.position = game.lift(Vector2i(60, 7), 0)


## The reach make_sound gives a sound here, as it reckons it.
func _reach(level: int, tag: String) -> float:
	var at: Vector3 = game.player.position
	var indoor: bool = game.grid_at(at).indoor(game.FieldGrid.cell_of(at))
	return SimNoise.radius(level, indoor, game.director.call_range_mult(game.clock.elapsed)) * game.weather.sound_mult(false) * SimNoise.reach(tag)


func test_a_kick_by_the_squad_draws_its_reach_on_the_ground() -> void:
	game.make_sound(game.player.position, SimNoise.Level.LOUD, "kick", game.player)
	assert_eq(game.ripples.rings.size(), 1)
	assert_almost_eq(float(game.ripples.rings[0]["r"]), minf(_reach(SimNoise.Level.LOUD, "kick"), SoundRipple.MOST_RADIUS), 0.001)
	game.make_sound(game.player.position, SimNoise.Level.LOUD, "glass", game.player)
	assert_eq(game.ripples.rings.size(), 2, "glass broken too")


func test_the_ring_grows_and_is_gone_after_a_second() -> void:
	game.make_sound(game.player.position, SimNoise.Level.LOUD, "kick", game.player)
	var ring: Dictionary = game.ripples.rings[0]
	var first: float = (ring["node"] as Node3D).scale.x
	game.ripples.advance(0.5)
	assert_gt((ring["node"] as Node3D).scale.x, first, "it spreads out")
	assert_eq(game.ripples.rings.size(), 1)
	game.ripples.advance(0.6)
	assert_eq(game.ripples.rings.size(), 0)


func test_other_sounds_draw_nothing() -> void:
	game.make_sound(game.player.position, SimNoise.Level.LOUD, "kick")
	game.make_sound(game.player.position, SimNoise.Level.NORMAL, "melee", game.player)
	game.make_sound(game.player.position, SimNoise.Level.QUIET, "pry", game.player)
	assert_eq(game.ripples.rings.size(), 0, "nobody's kick, a blow, a quiet pry")


func test_a_sound_heard_over_the_whole_map_draws_a_ring_forty_wide() -> void:
	game.make_sound(game.player.position, SimNoise.Level.VERY_LOUD, "kick", game.player)
	assert_eq(float(game.ripples.rings[0]["r"]), SoundRipple.MOST_RADIUS)


func test_running_draws_a_ring_a_second_at_most_and_only_the_player() -> void:
	for t in [10.0, 10.5, 11.0, 11.5, 12.0]:
		game.clock.elapsed = t
		game._ripple_run(game.player, 12.0)
	assert_eq(game.ripples.rings.size(), 3, "at 10, 11 and 12")
	var other = null
	for q in game.squad:
		if q != game.player:
			other = q
	game.clock.elapsed = 20.0
	game._ripple_run(other, 12.0)
	assert_eq(game.ripples.rings.size(), 3, "a companion running draws none")
