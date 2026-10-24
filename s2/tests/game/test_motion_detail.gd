extends GutTest
## Motion details from the reading of the reference motions (2026-10-24): the
## rows keep their marks in order, the blows still land when the rules say,
## the feet are held through a swing, a turn on the spot is stepped, and a
## blow throws the body away from where it came.

const Motion = preload("res://game/sim/motion.gd")
const W = preload("res://game/sim/weapons.gd")
const Combat = preload("res://game/field_combat.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const Person = preload("res://game/actors/person.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")


func _rows() -> Dictionary:
	var rows := {}
	for id in Motion.TABLE:
		rows[id] = Motion.row(id)
	for wid in W.DATA:
		if not Motion.swing_row(wid).is_empty():
			rows["swing_" + wid] = Motion.swing_row(wid)
		if not Motion.reload_row(wid).is_empty():
			rows["reload_" + wid] = Motion.reload_row(wid)
	return rows


func test_every_row_keeps_its_marks_inside_it() -> void:
	for id in _rows():
		var row: Dictionary = _rows()[id]
		var length: float = float(row["len"])
		assert_gt(length, 0.0, id)
		for key in ["hit", "open", "sound"]:
			var at: float = float(row[key])
			assert_true(at == -1.0 or (at >= 0.0 and at <= length), "%s: %s inside it" % [id, key])
		var feet: Vector2 = row["feet"]
		assert_true(feet.x >= 0.0 and feet.y <= length + 0.0001 and feet.x <= feet.y, "%s: feet inside it" % id)


func test_the_blows_still_land_when_the_rules_say() -> void:
	# The pairs with the rules are as they were (decision 411: the moment a blow
	# lands stays; only what is seen changes).
	assert_almost_eq(float(Motion.row("shove")["hit"]), Combat.SHOVE_WINDUP, 0.0001)
	assert_almost_eq(float(Motion.row("shove")["len"]), Combat.SHOVE_WINDUP + Combat.SHOVE_TIME, 0.0001)
	assert_almost_eq(float(Motion.row("stomp")["hit"]), Combat.STOMP_WINDUP, 0.0001)
	assert_almost_eq(float(Motion.row("fall")["len"]), Combat.FALL_TIME, 0.0001)
	assert_almost_eq(W.melee_windup("knife"), 0.10, 0.0001)
	assert_almost_eq(W.melee_windup("crowbar"), 0.18, 0.0001)
	assert_almost_eq(W.melee_windup("axe"), 0.30, 0.0001)
	for wid in ["knife", "crowbar", "axe"]:
		assert_almost_eq(float(Motion.swing_row(wid)["hit"]), W.melee_windup(wid), 0.0001, wid)
		assert_almost_eq(float(Motion.swing_row(wid)["len"]), float(W.get_data(wid)["swing"]), 0.0001, wid)
	assert_almost_eq(float(Motion.row("dead_shoved")["len"]), Zombies.SHOVED_TIME, 0.0001, "the stumble back is the rules' shoved time")


func test_the_feet_are_held_through_a_swing() -> void:
	# A knife thrust keeps the feet free for its first half; a crowbar or an axe
	# plants them almost at once; both hold them to the end.
	var knife: Dictionary = Motion.swing_row("knife")
	var axe: Dictionary = Motion.swing_row("axe")
	assert_almost_eq(knife["feet"].x, 0.5 * float(knife["len"]), 0.0001)
	assert_almost_eq(axe["feet"].x, 0.1 * float(axe["len"]), 0.0001)
	for row in [knife, axe, Motion.swing_row("crowbar")]:
		assert_almost_eq(row["feet"].y, float(row["len"]), 0.0001)
	var m := Motion.new()
	m.start("swing", axe)
	assert_false(m.feet_held(), "not yet at the start")
	m.tick(0.1)
	assert_true(m.feet_held(), "held once the axe comes back")
	assert_true(Motion.swing_row("pistol").is_empty(), "a gun is not swung")


func test_a_door_is_beaten_on_at_the_end_of_each_round() -> void:
	var row: Dictionary = Motion.row("dead_thump")
	assert_true(bool(row["loop"]))
	assert_almost_eq(float(row["hit"]) / float(row["len"]), 0.85, 0.001)
	assert_eq(float(row["sound"]), float(row["hit"]), "the bang is heard as the arms land")
	var m := Motion.new()
	m.start_known("dead_thump")
	assert_false(m.tick(1.0).has("hit"), "the arms are still coming back")
	assert_true(m.tick(0.2).has("hit"))
	assert_true(m.tick(0.15).has("end"), "the round ends and starts over")
	assert_true(m.active())
	assert_true(m.tick(1.1).has("hit"), "and the arms land again the next round")


func _person() -> Node3D:
	var p := Person.new()
	add_child_autofree(p)
	p.setup("p_test", "시험", "companion", Vector3.ZERO)
	return p


func test_turning_on_the_spot_is_stepped() -> void:
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [])
	assert_eq(int(PersonVisual.motion_of(p, note, 0.3, []).y), DeadBody.STAND, "kept still: it stands")
	var before := float(note.get("step", 0.0))
	p.rotation.y += 0.2
	var turning := PersonVisual.motion_of(p, note, 0.05, [])
	assert_eq(int(turning.y), PersonVisual.WALK, "the feet step round")
	assert_almost_eq(fposmod(turning.x - before, 1.0), 0.2 * PersonVisual.TURN_FOOT / float(DeadBody.STRIDE[0]), 0.0001, "by the turn")
	PersonVisual.motion_of(p, note, PersonVisual.TURN_HOLD + 0.05, [])
	assert_eq(int(PersonVisual.motion_of(p, note, 0.05, []).y), DeadBody.STAND, "and stands again once it stops turning")
	# A snap round all at once is not stepped.
	p.rotation.y += PersonVisual.TURN_CAP + 0.3
	assert_eq(int(PersonVisual.motion_of(p, note, 0.05, []).y), DeadBody.STAND)


func test_a_blow_throws_the_body_away_from_where_it_came() -> void:
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [])
	# Bitten by one holding it from behind: thrown forward.
	p.grabbers.append({"state": "grab", "pos": p.position + Vector3(0, 0, -0.5)})
	p.grab_front = false
	p.body.apply_bite(RandomNumberGenerator.new(), "arm_right", 0.0)
	PersonVisual.motion_of(p, note, 0.0, [])
	var behind := PersonVisual.lean_of(p, note)
	p.grabbers.clear()
	assert_gt(behind.y.z, 0.0, "forward, away from the one behind")
	# From the right side (-x is the body's right): rolled over to the left.
	note = {}
	PersonVisual.motion_of(p, note, 0.1, [])
	p.grabbers.append({"state": "grab", "pos": p.position + Vector3(-0.5, 0, 0)})
	p.body.apply_bite(RandomNumberGenerator.new(), "arm_left", 0.0)
	PersonVisual.motion_of(p, note, 0.0, [])
	var from: Vector2 = note["hurt_from"]
	assert_almost_eq(from.x, 1.0, 0.001, "it came from the right")
	p.grabbers.clear()
	var side := PersonVisual.lean_of(p, note)
	assert_gt(side.y.x, 0.0, "the top goes over to the left (+x)")
	# None holding it: as before, thrown back.
	note = {}
	PersonVisual.motion_of(p, note, 0.1, [])
	p.body.apply_scratch(RandomNumberGenerator.new(), 0.0, "torso")
	PersonVisual.motion_of(p, note, 0.0, [])
	assert_lt(PersonVisual.lean_of(p, note).y.z, 0.0, "back, from in front")
