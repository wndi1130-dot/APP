extends "res://addons/gut/test.gd"
## The dead in sight are heard walking (field_audio _tick_feet; 결정 509, user
## 2026-10-24: only the dead the player can see are heard): the nearest few
## that move, by the floor under them, a stride drawn new for every step so
## their feet keep no beat. Standing, crawling, far or out of sight, no step.
## An ally's feet are heard too, softer; a raider's not. Only the player's
## ear: nothing in the rules hears it.

const FieldGame = preload("res://game/field_game.gd")

var game


func before_each() -> void:
	seed(20261030)
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	# Every floor falls to the snow; the snow has three files.
	for row: Array in game.audio.STEP_FLOORS:
		for g: String in row[0]:
			game.audio.lib[g] = []
	game.audio.lib["step_snow"] = [_tone(), _tone(), _tone()]


func _tone() -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = 8000
	w.data = PackedByteArray([0, 40, 80, 40, 0, 216, 176, 216])
	return w


## A spot on the ground where a w x h block of cells east and south of it
## has nothing that stops the eye (as in test_field_audio).
func _open_spot(w: int, h: int) -> Vector2i:
	var g = game.grid
	for y in range(4, g.height - h - 4):
		for x in range(4, g.width - w - 4):
			if not g.people_can_walk(Vector2i(x, y)):
				continue
			var clear := true
			for dy in range(h):
				for dx in range(-2, w):
					if g.opaque(Vector2i(x + dx, y + dy)):
						clear = false
						break
				if not clear:
					break
			if clear:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Stand at c looking east, the camera on you as on a phone, and look.
func _look_east_from(c: Vector2i) -> void:
	assert_ne(c, Vector2i(-1, -1), "the map has such a spot")
	var p = game.player
	p.position = game.lift(c, 0)
	p.facing = PI * 0.5
	game.cam_size = 36.0
	game.cam_focus = p.position
	game._update_camera(1.0)
	game._refresh_vision()


func _steps_of(z: Dictionary) -> Array:
	var out: Array = []
	for st: Array in game.audio.dead_steps:
		if int(st[0]) == int(z["id"]):
			out.append(st)
	return out


## z goes `by` each tick of 0.1 s, n times, and the ear ticks.
func _walk(z: Dictionary, n: int, by: Vector3) -> void:
	for i in range(n):
		z["pos"] += by
		game.audio.tick(0.1)


func test_one_of_the_dead_in_sight_walking_up_is_heard_and_keeps_no_beat() -> void:
	_look_east_from(_open_spot(14, 1))
	var a = game.audio
	var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(8, 0, 0))
	z["state"] = "wander"
	a.pick_t = 0.0
	a.tick(0.1)
	assert_true(a.in_view(z["pos"]), "in sight")
	# Shambling 6 m up to the player at half a metre a second.
	var marks: Array = []
	for i in range(120):
		var before: int = a.dead_steps.size()
		_walk(z, 1, Vector3(-0.05, 0, 0))
		if a.dead_steps.size() > before:
			marks.append(i)
	var heard: Array = _steps_of(z)
	assert_gt(heard.size(), 3, "its feet are heard")
	assert_lt(heard.size(), int(6.0 / float(a.DEAD_GAITS["shamble"]["stride"][0])), "not every stride: some drag")
	var gaps: Dictionary = {}
	for k in range(1, marks.size()):
		gaps[int(marks[k]) - int(marks[k - 1])] = true
	assert_gt(gaps.size(), 1, "the gaps between its steps are not all one")
	for k in range(1, heard.size()):
		assert_ne(int(heard[k][2]), int(heard[k - 1][2]), "never the same file twice running")
	assert_eq(a.steps.size(), 0, "the player's own steps are not touched")
	assert_true(a.step_last.is_empty())
	assert_eq(a.played.size(), 0, "nor the groups the tests follow")


func test_one_standing_in_sight_makes_no_step() -> void:
	_look_east_from(_open_spot(14, 1))
	var a = game.audio
	var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(5, 0, 0))
	z["state"] = "chase"
	a.pick_t = 0.0
	_walk(z, 50, Vector3.ZERO)
	assert_eq(a.dead_steps.size(), 0)


func test_the_dead_out_of_sight_walk_silently() -> void:
	_look_east_from(_open_spot(14, 1))
	var a = game.audio
	# One behind the player, never seen, coming up.
	var behind: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(-6, 0, 0))
	behind["state"] = "chase"
	assert_false(a.in_view(behind["pos"]))
	_walk(behind, 40, Vector3(0.05, 0, 0))
	assert_eq(_steps_of(behind).size(), 0, "never seen, never heard walking")
	# One seen, then turned from: once its voice has gone, so have its feet.
	var seen: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(7, 0, 0))
	seen["state"] = "chase"
	a.pick_t = 0.0
	a.tick(0.1)
	game.player.facing = -PI * 0.5
	game._refresh_vision()
	assert_false(a.in_view(seen["pos"]))
	_walk(seen, int(ceilf((a.VOICE_KEEP + 0.5) / 0.1)), Vector3.ZERO)
	var n: int = _steps_of(seen).size()
	_walk(seen, 40, Vector3(-0.05, 0, 0))
	assert_eq(_steps_of(seen).size(), n, "out of sight its feet fall silent")


func test_a_crawler_makes_no_step_nor_does_one_past_the_range() -> void:
	_look_east_from(_open_spot(14, 2))
	var a = game.audio
	var crawler: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(4, 0, 0.5))
	crawler["state"] = "chase"
	crawler["crawl"] = true
	a.pick_t = 0.0
	_walk(crawler, 60, Vector3(-0.03, 0, 0))
	assert_eq(_steps_of(crawler).size(), 0, "a crawler drags itself without a step")
	# Past the range nothing; the same walk inside it is heard.
	var far: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(9, 0, 0))
	far["state"] = "chase"
	var s := {"z": far}
	for i in range(40):
		far["pos"] += Vector3(-0.05, 0, 0)
		a._tick_feet(s, far, a.DEAD_STEP_RANGE + 1.0)
	assert_eq(_steps_of(far).size(), 0, "past the range, no step")
	for i in range(40):
		far["pos"] += Vector3(-0.05, 0, 0)
		a._tick_feet(s, far, 5.0)
	assert_gt(_steps_of(far).size(), 0, "inside it, steps")


func test_only_the_nearest_few_are_heard_stepping() -> void:
	_look_east_from(_open_spot(14, 4))
	var a = game.audio
	var dead: Array = []
	for i in range(5):
		var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(3.0 + i * 1.5, 0, 0))
		z["state"] = "chase"
		dead.append(z)
	a.pick_t = 0.0
	a.tick(0.1)
	# All five walk across the player's way, keeping their distances.
	for i in range(100):
		for z: Dictionary in dead:
			z["pos"] += Vector3(0, 0, 0.03)
		a.tick(0.1)
	for k in range(a.DEAD_STEPPERS):
		assert_gt(_steps_of(dead[k]).size(), 0, "the nearest step")
	for k in range(a.DEAD_STEPPERS, dead.size()):
		assert_eq(_steps_of(dead[k]).size(), 0, "the farther are not heard stepping")


func test_its_gait_follows_what_it_is_doing() -> void:
	var a = game.audio
	assert_eq(a.gait_of("wander"), "shamble")
	assert_eq(a.gait_of("horde"), "shamble")
	assert_eq(a.gait_of("chase"), "chase")
	assert_eq(a.gait_of("attack"), "chase")
	assert_eq(a.gait_of("dash"), "dash")
	for gait: String in a.DEAD_GAITS:
		var g: Dictionary = a.DEAD_GAITS[gait]
		assert_true(float(g["loud"]) <= 0.3, "never louder than the player's walk")
		assert_true(float(g["pitch"][1]) <= 0.9, "never above the player's own feet")


# An ally's feet (squad or crew) are heard too, softer than the player's own;
# a raider's or a stranger's stay unheard (field_game _footsteps).
func test_an_allys_steps_are_heard_softer_and_a_raiders_not_at_all() -> void:
	var a = game.audio
	var mate = game.squad[1]
	assert_eq(String(mate.team), "squad")
	mate.position = game.player.position + Vector3(3, 0, 0)
	var cell: Vector2i = game.FieldGrid.cell_of(mate.position)
	game._footsteps(mate, 0.1, cell, 2.0)
	assert_gt(a.company_steps.size(), 0, "an ally walking near is heard")
	assert_eq(a.steps.size(), 0, "not as the player's own")
	var o: AudioStreamPlayer3D = a.feet[(a.feet_n - 1) % a.feet.size()]
	var row: Array = a._step_group(mate.position)[1]
	assert_lt(o.volume_db, a._db(0.3 * float(row[1])), "softer than the player's own walk")
	var heard: int = a.company_steps.size()
	for team: String in ["raider", "survivor"]:
		mate.team = team
		game._footsteps(mate, 0.1, cell, 2.0)
		assert_eq(a.company_steps.size(), heard, team + ": unheard")
	mate.team = "squad"
	a.company_step(game.player.position + Vector3(a.DEAD_STEP_RANGE + 1.0, 0, 0), false)
	assert_eq(a.company_steps.size(), heard, "past the range, no step")
