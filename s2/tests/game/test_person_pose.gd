extends "res://addons/gut/test.gd"
## The picture of a shove and of a melee swing (arms, weapon) only reads the
## rules' clocks: drawn back while the blow is drawn back, out as it lands,
## home again by the end of the swing time.

const FieldGame = preload("res://game/field_game.gd")
const Pose = preload("res://game/actors/person_pose.gd")
const Protest = preload("res://game/actors/person_protest.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.player.position = game.lift(Vector2i(60, 7), 0)
	for q in game.squad:
		if q != game.player:
			q.position = game.lift(Vector2i(30, 7), 0)


func _hold(wid: String) -> void:
	game.player.hands = [{"id": wid, "quality": "factory", "condition": 1.0, "loaded": 0}]


## A body that any landed blow finishes (zombies.md 갓 일어난 자), so the dice stay out of it.
func _rising() -> Dictionary:
	var p = game.player
	p.facing = PI * 0.5
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	z["state"] = "rising"
	return z


# ---------------------------------------------------------------- picture

func test_shove_arms_come_back_then_go_out_then_hang() -> void:
	assert_eq(Pose.shove_push(0.0, 0.0, 0.15), 0.0)
	assert_almost_eq(Pose.shove_push(0.15, 0.0, 0.15), 0.0, 0.001, "just pressed")
	assert_lt(Pose.shove_push(0.01, 0.0, 0.15), -0.9, "pulled right back before it lands")
	assert_almost_eq(Pose.shove_push(0.0, Pose.LUNGE, 0.15), 1.0, 0.001, "thrown out as it lands")
	assert_lt(Pose.shove_push(0.0, 0.01, 0.15), 0.4, "and coming home")
	var out: Dictionary = Pose.arm_at(1.0, 1.0)
	var hang: Dictionary = Pose.arm_at(0.0, 1.0)
	assert_gt((out["pos"] as Vector3).z, (hang["pos"] as Vector3).z + 0.3, "forward of the body")
	assert_lt((Pose.arm_at(1.0, -1.0)["pos"] as Vector3).x, 0.0, "the left arm stays left")


func test_each_weapon_goes_back_before_it_goes_forward() -> void:
	for wid in ["knife", "crowbar", "axe"]:
		var rest: Dictionary = Pose.weapon_at(wid, 0.0, 0.0, false)
		var back: Dictionary = Pose.weapon_at(wid, Pose.DRAW, 0.0, false)
		var struck: Dictionary = Pose.weapon_at(wid, 1.0, 0.0, true)
		var home: Dictionary = Pose.weapon_at(wid, 1.0, 1.0, true)
		assert_ne(back["pos"], struck["pos"], wid)
		var arriving: Dictionary = Pose.weapon_at(wid, 1.0, 0.0, false)
		assert_almost_eq((arriving["pos"] as Vector3).distance_to(struck["pos"]), 0.0, 0.001, "%s: it is there as the blow lands" % wid)
		assert_lt(float(back["lean"]), 0.0, "%s: the body goes back with it" % wid)
		assert_gt(float(struck["lean"]), 0.0, "%s: and in behind the blow" % wid)
		assert_almost_eq((home["pos"] as Vector3).distance_to(rest["pos"]), 0.0, 0.001, "%s: it ends where it began" % wid)
		assert_almost_eq(float(home["lean"]), 0.0, 0.001, wid)
	assert_gt((Pose.weapon_at("knife", 1.0, 0.0, true)["pos"] as Vector3).z, Pose.WEAPON_REST.z + 0.3, "a knife stabs forward")
	assert_lt((Pose.weapon_at("axe", Pose.DRAW, 0.0, false)["rot"] as Vector3).x, -1.0, "an axe comes up")


func test_the_view_follows_the_swing_and_puts_the_weapon_back() -> void:
	var p = game.player
	_hold("knife")
	var z := _rising()
	p.refresh_view(false)
	assert_eq(p.weapon_mesh.position, Pose.WEAPON_REST)
	var parts: int = p.get_child_count()
	game.combat.start_swing(p, z)
	game.combat.update(0.05)
	p.refresh_view(false)
	assert_lt(p.weapon_mesh.position.z, Pose.WEAPON_REST.z, "drawn back")
	game.combat.update(0.07)
	assert_eq(z["state"], "dead", "the blow")
	p.refresh_view(false)
	assert_gt(p.weapon_mesh.position.z, Pose.WEAPON_REST.z, "out with the blow")
	game.combat.update(2.0)
	p.refresh_view(false)
	assert_eq(p.weapon_mesh.position, Pose.WEAPON_REST)
	assert_eq(p.get_child_count(), parts, "the arms are made once")
	p.fallen_t = 1.0
	p.refresh_view(false)
	for arm in p.get_meta(Pose.META):
		assert_false(arm.visible, "no arms sticking out of a body on the ground")


func test_a_shove_after_a_swing_is_not_drawn_as_a_swing() -> void:
	var p = game.player
	_hold("crowbar")
	var z := _rising()
	z["pos"] = p.position + Vector3(6.0, 0, 0)
	game.combat.start_swing(p, z)
	game.combat.update(0.3)
	game.combat.update(1.0)
	p.refresh_view(false)
	game.combat.start_shove(p)
	p.refresh_view(false)
	assert_true(Pose.swing_state(p).is_empty())
	assert_eq(p.weapon_mesh.position, Pose.WEAPON_REST)


# ---------------------------------------------------------------- a body on the ground

func test_what_is_drawn_follows_the_rules_kind_and_the_target() -> void:
	assert_eq(Pose.strike_mode(null, {"state": "chase"}), "swing")
	assert_eq(Pose.strike_mode("swing", {"state": "downed"}), "floor", "a weapon at a body on the ground comes down")
	assert_eq(Pose.strike_mode("stomp", {"state": "downed"}), "stomp")
	assert_eq(Pose.strike_mode("swing", null), "swing")


func test_a_floor_blow_goes_up_then_down_in_front_of_the_feet() -> void:
	var up: Dictionary = Pose.floor_strike_at(Pose.DRAW, 0.0, false)
	var hit: Dictionary = Pose.floor_strike_at(1.0, 0.0, true)
	var home: Dictionary = Pose.floor_strike_at(1.0, 1.0, true)
	assert_gt((up["pos"] as Vector3).y, Pose.WEAPON_REST.y + 0.3)
	assert_lt((hit["pos"] as Vector3).y, Pose.WEAPON_REST.y - 0.4, "down at the ground")
	assert_gt(float(hit["lean"]), 0.5, "bent over it")
	assert_almost_eq((home["pos"] as Vector3).distance_to(Pose.WEAPON_REST), 0.0, 0.001)


func test_a_stomp_lifts_the_foot_then_puts_it_down_ahead() -> void:
	var up: Dictionary = Pose.stomp_at(Pose.DRAW, 0.0, false)
	var hit: Dictionary = Pose.stomp_at(1.0, 0.0, true)
	var home: Dictionary = Pose.stomp_at(1.0, 1.0, true)
	assert_gt((up["pos"] as Vector3).y, 0.5, "knee up")
	assert_lt(float(up["lean"]), 0.0)
	assert_almost_eq((hit["pos"] as Vector3).y, Pose.FOOT_REST.y, 0.001, "on the ground")
	assert_gt((hit["pos"] as Vector3).z, Pose.FOOT_REST.z + 0.3, "ahead of the body")
	assert_almost_eq((home["pos"] as Vector3).distance_to(Pose.FOOT_REST), 0.0, 0.001)


func test_a_weapon_at_a_downed_body_is_drawn_coming_down() -> void:
	var p = game.player
	_hold("crowbar")
	var z := _rising()
	z["state"] = "downed"
	z["t"] = 8.0
	game.combat.start_swing(p, z)
	game.combat.update(0.1)
	p.refresh_view(false)
	assert_eq(p.get_meta(Pose.MODE), "floor")
	assert_gt(p.weapon_mesh.position.y, Pose.WEAPON_REST.y, "going up first")
	assert_false(p.get_meta(Pose.META)[2].visible, "no foot for a weapon blow")
	game.combat.update(0.2)
	assert_eq(z["state"], "dead", "one blow ends it, as before")
	game.combat.update(2.0)
	p.refresh_view(false)
	assert_false(p.has_meta(Pose.MODE))


func test_bare_hands_at_a_downed_body_are_drawn_as_a_stomp() -> void:
	var p = game.player
	p.hands = []
	var z := _rising()
	z["state"] = "downed"
	z["t"] = 20.0
	game.combat.start_swing(p, z)
	assert_eq(p.strike_kind, "stomp")
	game.combat.update(0.25)
	p.refresh_view(false)
	var foot = p.get_meta(Pose.META)[2]
	assert_true(foot.visible)
	assert_gt(foot.position.y, 0.3, "the knee is up")
	game.combat.update(0.25)
	assert_eq(int(z.get("stomped", 0)), 1, "the boot has come down")
	p.refresh_view(false)
	assert_almost_eq(foot.position.y, Pose.FOOT_REST.y, 0.02, "on the ground as the rules land it")
	assert_gt(foot.position.z, Pose.FOOT_REST.z + 0.3)
	game.combat.update(0.3)
	game.combat.update(2.0)
	p.refresh_view(false)
	assert_false(foot.visible, "the foot is put away")


# ---------------------------------------------------------------- left on the platform

func test_the_three_protests_are_three_different_pictures() -> void:
	# Fists: both hands above the head while it shouts, down in the breath between.
	var high := 0
	for n in 40:
		var d: Dictionary = Protest.at(Protest.FISTS, float(n) * 0.05 + 0.3)
		if d["arms"][0]["pos"].y > 1.4 and d["arms"][1]["pos"].y > 1.4:
			high += 1
	assert_gt(high, 25, "the fists are up for most of a burst")
	var rest: Dictionary = Protest.at(Protest.FISTS, Protest.ROUND - 0.2)
	assert_almost_eq(rest["arms"][0]["pos"].y, 1.0, 0.05, "and hang in the breath after it")
	assert_almost_eq(Protest.loud(Protest.ROUND - 0.2), 0.0, 0.01)
	# Pointing: the right arm goes out in front again and again, the left stays back.
	var far := 0.0
	var near := 9.0
	for n in 40:
		var d: Dictionary = Protest.at(Protest.POINTS, float(n) * 0.031 + 0.4)
		far = maxf(far, d["arms"][1]["pos"].z)
		near = minf(near, d["arms"][1]["pos"].z)
		assert_lt(d["arms"][0]["pos"].z, 0.1, "the other fist is held back")
	assert_gt(far, 0.45)
	assert_lt(near, 0.2)
	# Sinking: arms wide first, then down on the knees, and it stays down.
	var wide: Dictionary = Protest.at(Protest.SINKS, 0.8)
	assert_gt(wide["arms"][1]["pos"].x - wide["arms"][0]["pos"].x, 1.0)
	assert_almost_eq(wide["lift"], 0.0, 0.001)
	for t in [3.0, 8.0, 60.0]:
		assert_almost_eq(Protest.at(Protest.SINKS, t)["lift"], -Protest.KNEEL, 0.001, "down at %s s" % t)
	# Any number picks one of the three.
	assert_eq(Protest.at(5, 1.0), Protest.at(Protest.SINKS, 1.0))
	# Nothing leans past what a body on its feet can.
	for kind in Protest.KINDS:
		for n in 200:
			var d: Dictionary = Protest.at(kind, float(n) * 0.07)
			assert_between(float(d["lean"]), -0.2, 0.55)


func test_someone_marked_as_protesting_is_drawn_so_and_a_shove_comes_first() -> void:
	var p = game.player
	p.hands = []
	p.refresh_view(false)
	var arms: Array = p.get_meta(Pose.META)
	var hung: Vector3 = arms[0].position
	var stood: float = p.body_mesh.position.y
	p.set_meta(Protest.META, {"kind": Protest.SINKS, "t": 5.0})
	p.refresh_view(false)
	assert_almost_eq(p.body_mesh.position.y, stood - Protest.KNEEL - 0.5 * 0.25, 0.001, "on the knees, bent over")
	assert_lt(arms[0].position.y, hung.y, "hands down by the ground")
	assert_true(arms[0].visible)
	# A shove is the rules' and is drawn as a shove.
	p.lunge_t = Pose.LUNGE
	p.refresh_view(false)
	assert_almost_eq(arms[0].position.z, 0.5, 0.01)
	p.lunge_t = 0.0
	# The mark taken off, they stand as they stood.
	p.remove_meta(Protest.META)
	p.refresh_view(false)
	assert_eq(arms[0].position, hung)
	assert_almost_eq(p.body_mesh.position.y, stood, 0.001)

