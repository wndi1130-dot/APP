extends "res://addons/gut/test.gd"
## The weapon in the hand is drawn as its model where the build has one
## (models/weapons/<id>.glb), under the weapon box's node so the poses move it,
## and as the box where it has none (person.gd).

const FieldGame = preload("res://game/field_game.gd")
const Person = preload("res://game/actors/person.gd")

const IDS: Array = ["crowbar", "axe", "pistol", "shotgun", "bow", "pipe_shotgun", "knife"]

var game
var p


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	p = game.player


func _hold(wid: String) -> void:
	p.hands = [{"id": wid, "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.set_weapon_slots(p.hands)


func test_each_weapon_is_its_model_or_else_its_box() -> void:
	for wid in IDS:
		_hold(wid)
		assert_true(p.weapon_mesh.visible, wid)
		if ResourceLoader.exists(Person.WEAPON_MODEL % wid):
			assert_not_null(p.weapon_model, "%s: the model is drawn" % wid)
			assert_eq(p.weapon_model.get_parent(), p.weapon_mesh, "%s: it moves with the poses" % wid)
			assert_null(p.weapon_mesh.mesh, "%s: the box is put away" % wid)
		else:
			assert_null(p.weapon_model, "%s: no model in the build" % wid)
			assert_eq(p.weapon_mesh.mesh, p.weapon_box, "%s: the box stands in" % wid)


func test_a_swap_changes_the_model_and_empty_hands_show_nothing() -> void:
	_hold("crowbar")
	var first = p.weapon_model
	_hold("pistol")
	if first != null:
		assert_true(first.is_queued_for_deletion(), "the crowbar's model is let go")
	assert_eq(p.weapon_model_id, "pistol")
	p.hands = []
	p.set_weapon_slots(p.hands)
	assert_false(p.weapon_mesh.visible, "empty hands show no weapon")
	assert_null(p.weapon_model)


func test_the_hatchet_is_turned_so_its_edge_faces_down() -> void:
	_hold("axe")
	if p.weapon_model == null:
		pass_test("no hatchet model in this build")
		return
	assert_almost_eq(p.weapon_model.rotation.z, -PI * 0.5, 0.0001)
