extends "res://addons/gut/test.gd"
## The picture of hands at work with a weapon: aiming, the kick of a shot,
## loading, clearing a jam, prising and kicking a door, held by the dead
## (person_pose.gd). It only reads the rules' clocks, and the motion rows for
## them are today's rule times written down (sim/motion.gd).

const FieldGame = preload("res://game/field_game.gd")
const Pose = preload("res://game/actors/person_pose.gd")
const Motion = preload("res://game/sim/motion.gd")
const FieldCombat = preload("res://game/field_combat.gd")
const FieldActions = preload("res://game/field_actions.gd")
const W = preload("res://game/sim/weapons.gd")

var game
var p


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)


func _hold(wid: String, loaded: int = 0) -> void:
	p.hands = [{"id": wid, "quality": "factory", "condition": 1.0, "loaded": loaded}]
	p.set_weapon_slots(p.hands)
	p.aim.stop()
	p.jam_t = 0.0
	p.reload_t = 0.0


func _weapon_pos(pose: Dictionary) -> Vector3:
	return pose["weapon"]["pos"]


# ---------------------------------------------------------------- pictures

func test_each_weapon_is_held_its_own_way() -> void:
	assert_eq(Pose.hold_of("pistol"), "one")
	assert_eq(Pose.hold_of("shotgun"), "two")
	assert_eq(Pose.hold_of("pipe_shotgun"), "two")
	assert_eq(Pose.hold_of("bow"), "bow")
	for wid in ["knife", "crowbar", "axe", ""]:
		assert_eq(Pose.hold_of(wid), "", "%s is not aimed" % wid)


func test_an_aimed_gun_is_raised_in_front() -> void:
	for hold in ["one", "two"]:
		var pose: Dictionary = Pose.aim_at(hold)
		assert_gt(_weapon_pos(pose).y, Pose.WEAPON_REST.y + 0.3, "%s: up at the eye" % hold)
		assert_gt(_weapon_pos(pose).z, 0.4, "%s: out in front" % hold)
	var bow: Dictionary = Pose.aim_at("bow")
	assert_lt(_weapon_pos(bow).x, 0.0, "the bow is in the left hand")


func test_a_shot_throws_the_muzzle_up_and_the_gun_back() -> void:
	for hold in ["one", "two"]:
		var still: Dictionary = Pose.aim_at(hold, 0.0)
		var kicked: Dictionary = Pose.aim_at(hold, 1.0)
		assert_lt(_weapon_pos(kicked).z, _weapon_pos(still).z, "%s comes back" % hold)
		assert_lt((kicked["weapon"]["rot"] as Vector3).x, (still["weapon"]["rot"] as Vector3).x, "%s: the muzzle comes up" % hold)
	assert_gt(absf(float(Pose.aim_at("two", 1.0)["lean"]) - float(Pose.aim_at("two", 0.0)["lean"])), absf(float(Pose.aim_at("one", 1.0)["lean"]) - float(Pose.aim_at("one", 0.0)["lean"])), "a long gun pushes the body more than a pistol")


func test_a_bow_string_comes_back_as_it_is_drawn() -> void:
	var loose: Dictionary = Pose.aim_at("bow", 0.0, 0.0)
	var drawn: Dictionary = Pose.aim_at("bow", 0.0, 1.0)
	assert_lt((drawn["arms"][1]["pos"] as Vector3).z, (loose["arms"][1]["pos"] as Vector3).z - 0.3, "the right hand comes back to the cheek")


func test_loading_takes_the_left_hand_to_the_gun_and_back() -> void:
	var start: Dictionary = Pose.reload_at("one", 0.0)
	var mid: Dictionary = Pose.reload_at("one", 0.5)
	var end: Dictionary = Pose.reload_at("one", 1.0)
	var gun := _weapon_pos(mid)
	var hand_start: Vector3 = start["arms"][0]["pos"]
	var hand_mid: Vector3 = mid["arms"][0]["pos"]
	assert_lt(hand_mid.distance_to(gun), hand_start.distance_to(gun) - 0.2, "at the gun halfway through")
	assert_almost_eq((end["arms"][0]["pos"] as Vector3).distance_to(hand_start), 0.0, 0.001, "back at the belt at the end")
	assert_lt(gun.y, Pose.aim_at("one")["weapon"]["pos"].y, "the gun is down at the waist")


func test_a_door_kick_lifts_the_knee_then_drives_the_foot_out() -> void:
	var up: Dictionary = Pose.kick_at(Pose.DRAW)
	var out: Dictionary = Pose.kick_at(1.0)
	assert_gt((up["foot"] as Vector3).y, Pose.FOOT_REST.y + 0.3, "the knee is up")
	assert_gt((out["foot"] as Vector3).z, (up["foot"] as Vector3).z + 0.3, "the sole goes out at the door")


func test_prising_bends_over_a_low_bar() -> void:
	var pose: Dictionary = Pose.pry_at(0.0)
	assert_lt(_weapon_pos(pose).y, Pose.WEAPON_REST.y, "the bar is low in the gap")
	assert_gt(float(pose["lean"]), 0.2, "the back is bent")


func test_held_from_the_front_leans_back_and_from_behind_bends_forward() -> void:
	assert_lt(float(Pose.held_at(true, 0.0)["lean"]), 0.0)
	assert_gt(float(Pose.held_at(false, 0.0)["lean"]), 0.0)


# ---------------------------------------------------------------- on a person

func test_an_aiming_person_holds_the_gun_up() -> void:
	_hold("pistol", 8)
	assert_true(game.combat.start_aim(p))
	p.refresh_view(true)
	assert_gt(p.weapon_mesh.position.y, Pose.WEAPON_REST.y + 0.3, "aimed, the pistol is up")
	p.aim.stop()
	p.refresh_view(true)
	assert_eq(p.weapon_mesh.position, Pose.WEAPON_REST, "lowered again once the aim stops")


func test_a_shot_is_seen_as_a_kick_and_a_swap_is_not() -> void:
	_hold("pistol", 8)
	game.combat.start_aim(p)
	p.refresh_view(true)
	var still: float = p.weapon_mesh.rotation.x
	p.weapon()["loaded"] = 7
	p.refresh_view(true)
	assert_lt(p.weapon_mesh.rotation.x, still - 0.1, "one round fewer is a shot")
	p.remove_meta(Pose.KICK_AT)
	# Fewer rounds than the pistol had, but another gun: no shot.
	_hold("pipe_shotgun", 1)
	assert_true(game.combat.start_aim(p))
	p.refresh_view(true)
	assert_almost_eq(p.weapon_mesh.rotation.x, 0.0, 0.001, "a swapped-in gun did not fire")


func test_a_jammed_or_loading_gun_is_drawn_so() -> void:
	_hold("pistol", 0)
	p.reload_t = 0.9
	p.refresh_view(true)
	assert_almost_eq(p.weapon_mesh.rotation.x, 0.5, 0.001, "loading: the gun is tipped down at the waist")
	p.reload_t = 0.0
	p.jam_t = 2.0
	p.refresh_view(true)
	assert_almost_eq(p.weapon_mesh.rotation.y, 0.7, 0.001, "a jam: the gun is turned on its side")


func test_a_melee_weapon_has_no_aim_picture() -> void:
	_hold("crowbar")
	p.reload_t = 1.0
	p.refresh_view(true)
	assert_eq(p.weapon_mesh.position, Pose.WEAPON_REST)


# ---------------------------------------------------------------- motion rows

func test_motion_rows_are_the_rule_times() -> void:
	assert_eq(float(Motion.row("stomp")["len"]), FieldCombat.STOMP_TIME)
	assert_eq(float(Motion.row("stomp")["hit"]), FieldCombat.STOMP_WINDUP)
	assert_eq(float(Motion.row("jam_clear")["len"]), FieldCombat.JAM_CLEAR)
	assert_eq(float(Motion.row("pry")["len"]), FieldActions.PRY_TIME)
	assert_eq(float(Motion.row("kick")["len"]), FieldActions.KICK_TIME)
	for wid in ["pistol", "shotgun", "bow", "pipe_shotgun"]:
		assert_eq(float(Motion.reload_row(wid)["len"]), float(W.get_data(wid)["reload"]), wid)
	assert_true(Motion.reload_row("knife").is_empty(), "a knife is not loaded")
