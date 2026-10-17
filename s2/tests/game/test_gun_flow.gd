extends "res://addons/gut/test.gd"
## Guns on the field: the shove inside the least distance, a shot past the
## reach, jams and misfires, a burst barrel, one shell at a time in a pump
## gun, the shared rounds and the arrow that is picked up again
## (weapons.md weapon condition, cold, aim, S2 range).

const FieldGame = preload("res://game/field_game.gd")
const W = preload("res://game/sim/weapons.gd")

const TRIES: int = 400

var game
var p


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 23, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)


func _hand(id: String, quality: String = "factory", condition: float = 1.0, loaded: int = 0) -> void:
	p.hands = [{"id": id, "quality": quality, "condition": condition, "loaded": loaded}]
	p.set_weapon_slots(p.hands)
	p.aim.stop()
	p.jam_t = 0.0
	p.reload_t = 0.0


func _body_at(dx: float, state: String = "wander", kind: String = "dead") -> Dictionary:
	var z: Dictionary = game.zombies.spawn(kind, p.position + Vector3(dx, 0, 0))
	z["state"] = state
	return z


func test_a_body_inside_the_least_distance_is_shoved_not_shot() -> void:
	_hand("pistol", "factory", 1.0, 8)
	var z := _body_at(0.5)
	var before: int = int(p.weapon()["loaded"])
	assert_lt(0.5, float(W.get_data("pistol")["min_dist"]))
	assert_eq(game.combat.fire(p, z["pos"], z), "shove")
	assert_eq(int(p.weapon()["loaded"]), before, "no round leaves the gun")


func test_a_body_past_the_reach_is_shot_at_and_left_whole() -> void:
	_hand("pistol", "factory", 1.0, 8)
	var reach: float = float(W.get_data("pistol")["range"])
	var z := _body_at(reach + 4.0)
	assert_eq(game.combat.fire(p, z["pos"], z), "shot")
	# The shot is heard (it may come to look), but nothing lands on it.
	assert_ne(z["state"], "dead", "past the reach nothing lands on it")
	assert_ne(z["state"], "downed")
	assert_eq(float(z["stun"]), 0.0)
	assert_eq(int(p.weapon()["loaded"]), 7, "the round still leaves the gun")


func test_a_worn_pistol_jams_and_the_clearing_takes_time() -> void:
	_hand("pistol", "factory", 0.0, 8)
	var jammed := false
	for i in range(TRIES):
		p.jam_t = 0.0
		p.reload_t = 0.0
		if int(p.weapon()["loaded"]) <= 0:
			p.weapon()["loaded"] = 8
		if game.combat.fire(p, p.position + Vector3(6, 0, 0)) == "jam":
			jammed = true
			break
	assert_true(jammed, "a pistol at 0.0 condition jams at last")
	assert_almost_eq(p.jam_t, game.combat.JAM_CLEAR, 0.001)
	assert_false(game.combat.can_shoot(p), "a jammed gun cannot fire")
	# The hands clear it at their own pace (mults "hands").
	game.combat.update(game.combat.JAM_CLEAR / float(p.mults()["hands"]) + 0.1)
	assert_true(p.jam_t <= 0.0, "the jam is cleared")
	assert_true(game.combat.can_shoot(p), "cleared, it fires again")


func test_a_single_shot_misfire_spends_the_round_and_starts_a_reload() -> void:
	_hand("pipe_shotgun", "factory", 0.0, 1)
	game.ammo["shell"] = 4
	var misfired := false
	for i in range(TRIES):
		p.weapon()["loaded"] = 1
		game.ammo["shell"] = 4
		p.jam_t = 0.0
		p.reload_t = 0.0
		if game.combat.fire(p, p.position + Vector3(6, 0, 0)) == "misfire":
			misfired = true
			break
	assert_true(misfired, "a pipe shotgun at 0.0 misfires at last")
	assert_eq(int(p.weapon()["loaded"]), 0, "the thrown round is spent")
	assert_gt(p.reload_t, 0.0, "the reload starts on its own")


func test_a_crude_pipe_shotgun_bursts_and_hurts_the_one_who_fired() -> void:
	_hand("pipe_shotgun", "crude", 1.0, 1)
	game.ammo["shell"] = 4
	var burst := false
	for i in range(TRIES):
		p.weapon()["loaded"] = 1
		game.ammo["shell"] = 4
		p.jam_t = 0.0
		p.reload_t = 0.0
		if game.combat.fire(p, p.position + Vector3(6, 0, 0)) == "burst":
			burst = true
			break
	assert_true(burst, "a crude pipe shotgun bursts at last")
	assert_true(bool(p.weapon()["broken"]))
	assert_eq(float(p.weapon()["condition"]), 0.0)
	assert_gt(p.body.wounds.size(), 0, "the barrel left a wound on the one who fired")
	assert_false(game.combat.start_aim(p), "a broken gun cannot be aimed")


func test_a_pump_gun_takes_one_shell_at_a_time() -> void:
	_hand("shotgun", "factory", 1.0, 0)
	game.ammo["shell"] = 4
	assert_true(game.combat.start_reload(p), "the empty gun starts loading")
	assert_gt(p.reload_t, 0.0)
	# The hands load at their own pace (mults "reload").
	game.combat.update(p.reload_t / float(p.mults()["reload"]) + 0.01)
	assert_eq(int(p.weapon()["loaded"]), 1, "one shell went in")
	assert_gt(p.reload_t, 0.0, "and the next shell has started")


func test_no_shared_rounds_no_reload() -> void:
	_hand("pistol", "factory", 1.0, 0)
	game.ammo["pistol"] = 0
	assert_false(game.combat.start_reload(p), "an empty pool loads nothing")


func test_an_arrow_lands_and_is_picked_up_as_a_crafted_round() -> void:
	_hand("bow", "factory", 1.0, 1)
	game.ground_items.clear()
	assert_eq(game.combat.fire(p, p.position + Vector3(8, 0, 0)), "shot")
	assert_eq(game.ground_items.size(), 1, "one arrow fell")
	assert_eq(game.ground_items[0]["id"], "arrow")
	var before: int = int(game.ammo["craft"])
	p.position = game.ground_items[0]["pos"]
	game.actions._auto_pickup()
	assert_eq(game.ground_items.size(), 0, "the arrow is gone")
	assert_eq(int(game.ammo["craft"]), before + 1, "and counts as a crafted round")