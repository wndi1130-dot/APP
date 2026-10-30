extends "res://addons/gut/test.gd"

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const Person = preload("res://game/actors/person.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const BloodFx = preload("res://fx/blood_fx.gd")
const FxState = preload("res://fx/fx_state.gd")
const GRID_SIZE: int = 16
const WALL_X: int = 6
const HIT_AT: Vector3 = Vector3(5.5, 0.0, 8.5)
const OWN: Array = [{"name": "p_stab", "length": 1.0}, {"name": "p_held", "length": 1.0}]

var game: FieldGame
var p: Person
var fx: BloodFx
var _blood_level: int


class LandingCheck:
	extends Node

	func can_land(_at: Vector3) -> bool:
		return true


func before_each() -> void:
	_blood_level = FxState.blood_level
	FxState.set_blood_level(FxState.BloodLevel.NORMAL)
	game = FieldGame.new()
	game.opts = {"seed": 17, "raiders": false, "auto_pause": false, "hit_power": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.grid = FieldGrid.new(GRID_SIZE, GRID_SIZE)
	game.grid.refresh_paths()
	game.levels = {0: game.grid}
	p = game.player
	p.position = HIT_AT - Vector3.RIGHT
	p.facing = PI * 0.5
	p.hands = [{"id": "knife", "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.set_weapon_slots(p.hands)
	fx = game.blood_fx as BloodFx
	fx.set_process(false)
	fx.begin_stop(42)


func after_each() -> void:
	fx.clear()
	FxState.set_blood_level(_blood_level)


func _settle() -> void:
	for _i in range(40):
		fx.advance(0.05)
	assert_eq(fx.drop_count(), 0, "all drops have left the air")


func _drop_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for record: Dictionary in fx.records:
		var custom: Color = record["custom"]
		if int(custom.b) == BloodFx.Kind.DROP:
			var xf: Transform3D = record["xf"]
			spots.append(xf.origin)
	return spots


func _drops_past(x: float) -> int:
	var count: int = 0
	for at: Vector3 in _drop_spots():
		if at.x >= x:
			count += 1
	return count


func _wall() -> void:
	for z in range(GRID_SIZE):
		game.grid.set_solid(Vector2i(WALL_X, z), FieldGrid.Solid.WALL)
	game.grid.refresh_paths()


func _land_fixed_drop(from: Vector3, to: Vector3) -> void:
	fx._land({
		"pos": to, "vel": to - from, "floor": to.y,
		"snow": false, "mark": 0.1, "seed": 0.5,
		"has_land_check": true, "can_land": game.feel._blood_can_land.bind(from),
	})


func test_the_real_segment_blocks_a_wall_missed_by_cell_centers() -> void:
	game.grid.set_solid(Vector2i(9, 8), FieldGrid.Solid.WALL)
	var from: Vector3 = Vector3(5.99, 0.0, 8.01)
	var to: Vector3 = Vector3(9.70, 0.0, 9.01)
	assert_false(game.feel._blood_can_land(to, from), "the segment crosses cell (9, 8)")
	_land_fixed_drop(from, to)
	assert_eq(_drop_spots().size(), 0, "the missed wall leaves no drop mark beyond it")


func test_the_real_segment_keeps_a_drop_wrongly_blocked_by_cell_centers() -> void:
	game.grid.set_solid(Vector2i(6, 8), FieldGrid.Solid.WALL)
	var from: Vector3 = Vector3(5.90, 0.0, 8.99)
	var to: Vector3 = Vector3(7.10, 0.0, 9.90)
	assert_true(game.feel._blood_can_land(to, from), "the segment enters row 9 before column 6")
	_land_fixed_drop(from, to)
	assert_eq(_drop_spots().size(), 1, "a clear segment keeps its drop mark")


func test_a_drop_tenth_of_a_metre_from_a_wall_can_land_on_its_own_side() -> void:
	_wall()
	var from: Vector3 = Vector3(5.90, 0.0, 8.10)
	var to: Vector3 = Vector3(5.90, 0.0, 10.90)
	assert_true(game.feel._blood_can_land(to, from), "a drop needs no walking width")
	assert_true(game.feel._blood_can_land(from, to), "the reverse segment stays on the same side")
	_land_fixed_drop(from, to)
	assert_eq(_drop_spots().size(), 1, "a mark survives 0.1m from the wall")


func test_an_exact_corner_checks_both_side_cells_in_every_direction() -> void:
	var from: Vector3 = Vector3(8.5, 0.0, 8.5)
	var start: Vector2i = FieldGrid.cell_of(from)
	for step: Vector2i in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var to: Vector3 = from + Vector3(step.x * 2.0, 0.0, step.y * 2.0)
		assert_true(game.feel._blood_can_land(to, from), "an open diagonal is clear")
		for side: Vector2i in [start + Vector2i(step.x, 0), start + Vector2i(0, step.y)]:
			game.grid.set_solid(side, FieldGrid.Solid.WALL)
			assert_false(game.feel._blood_can_land(to, from), "either side of the corner blocks the drop")
			game.grid.set_solid(side, FieldGrid.Solid.NONE)


func test_a_segment_just_clear_of_a_corner_is_not_widened() -> void:
	game.grid.set_solid(Vector2i(6, 8), FieldGrid.Solid.WALL)
	var from: Vector3 = Vector3(5.5, 0.0, 8.5)
	var to: Vector3 = Vector3(7.5, 0.0, 10.500001)
	assert_true(game.feel._blood_can_land(to, from), "near a corner is not an exact corner")
	assert_true(game.feel._blood_can_land(from, to), "reverse traversal keeps the same narrow clearance")


func test_the_start_cell_is_skipped_but_the_landing_cell_must_be_clear() -> void:
	var from: Vector3 = Vector3(5.5, 0.0, 8.5)
	var to: Vector3 = Vector3(7.5, 0.0, 8.5)
	assert_true(game.feel._blood_can_land(from, from), "a stationary drop can land on clear floor")
	game.grid.set_solid(FieldGrid.cell_of(from), FieldGrid.Solid.WALL)
	assert_true(game.feel._blood_can_land(to, from), "the hit's cell is excluded from traversal")
	assert_false(game.feel._blood_can_land(from, from), "even a stationary drop needs a clear landing cell")
	assert_false(game.feel._blood_can_land(from, to), "the same wall blocks a landing in reverse")
	assert_false(game.feel._blood_can_land(Vector3(GRID_SIZE, 0.0, 8.5), to), "outside the map has no floor")
	assert_false(game.feel._blood_can_land(to + Vector3.UP * game.level_y(1), to), "a drop cannot land on another level")


func test_an_open_map_keeps_the_same_marks_with_and_without_a_landing_check() -> void:
	var contact: Dictionary = {"position": HIT_AT, "can_land": game.feel._blood_can_land.bind(HIT_AT)}
	var checked_hit: Dictionary = fx.hit(HIT_AT + Vector3.UP, Vector3.RIGHT, 1.0, "firearm", contact)
	var count: int = int(checked_hit["count"])
	assert_gt(count, 0)
	_settle()
	var checked_spots: Array[Vector3] = _drop_spots()
	var checked_rng_state: int = fx._rng.state
	assert_eq(checked_spots.size(), count, "the checked open map keeps every drop")
	fx.begin_stop(42)
	var unchecked_hit: Dictionary = fx.hit(HIT_AT + Vector3.UP, Vector3.RIGHT, 1.0, "firearm", {"position": HIT_AT})
	assert_eq(int(unchecked_hit["count"]), count, "both hits throw the same number of drops")
	assert_eq(int(unchecked_hit["seed"]), int(checked_hit["seed"]), "both hits use the same effect seed")
	_settle()
	assert_eq(_drop_spots().size(), checked_spots.size(), "omitting the check keeps the same mark count")
	assert_eq(_drop_spots(), checked_spots, "the surviving marks have the same positions")
	assert_eq(fx._rng.state, checked_rng_state, "the check consumes no extra effect dice")


func test_an_invalidated_landing_check_drops_marks_but_an_omitted_check_keeps_them() -> void:
	var checker: LandingCheck = LandingCheck.new()
	var can_land: Callable = checker.can_land
	var contact: Dictionary = {"position": HIT_AT, "can_land": can_land}
	var hit: Dictionary = fx.hit(HIT_AT + Vector3.UP, Vector3.RIGHT, 1.0, "firearm", contact)
	var count: int = int(hit["count"])
	assert_gt(count, 0)
	assert_true(can_land.is_valid(), "the supplied check is valid when drops are made")
	checker.free()
	assert_false(can_land.is_valid(), "the check loses its owner before landing")
	_settle()
	assert_eq(_drop_spots().size(), 0, "a lost check cannot approve a mark")
	var rejected_rng_state: int = fx._rng.state
	fx.begin_stop(42)
	var unchecked_hit: Dictionary = fx.hit(HIT_AT + Vector3.UP, Vector3.RIGHT, 1.0, "firearm", {"position": HIT_AT})
	assert_eq(int(unchecked_hit["count"]), count, "omitting the check leaves the spray unchanged")
	_settle()
	assert_eq(_drop_spots().size(), count, "legacy callers without a check keep every mark")
	assert_eq(fx._rng.state, rejected_rng_state, "rejected drops still spend one floor angle each")


func test_an_explicit_empty_landing_check_is_not_an_omitted_check() -> void:
	var hit: Dictionary = fx.hit(HIT_AT + Vector3.UP, Vector3.RIGHT, 1.0, "firearm", {"position": HIT_AT, "can_land": Callable()})
	assert_gt(int(hit["count"]), 0)
	_settle()
	assert_eq(_drop_spots().size(), 0, "a supplied empty check cannot approve a mark")


func test_a_thin_wall_stops_drop_marks_that_land_beyond_it_in_the_open() -> void:
	var dead: Dictionary = game.zombies.spawn("dead", HIT_AT)
	game.feel.shot_in(p, dead["pos"], false, false)
	var count: int = fx.drop_count()
	assert_gt(count, 0, "the shot throws drops off the dead")
	_settle()
	assert_eq(_drop_spots().size(), count, "open ground keeps every drop")
	assert_gt(_drops_past(float(WALL_X + 1)), 0, "without the wall, drops reach the far room")
	var open_rng_state: int = fx._rng.state
	_wall()
	fx.begin_stop(42)
	game.feel.shot_in(p, dead["pos"], false, false)
	assert_eq(fx.drop_count(), count, "the wall does not change the spray count")
	_settle()
	assert_eq(_drops_past(float(WALL_X)), 0, "no drop mark in the wall or beyond it")
	assert_eq(fx._rng.state, open_rng_state, "discarded marks keep later sprays' dice unchanged")


func test_an_upper_edge_leaves_no_drop_marks_over_air() -> void:
	var upper: FieldGrid = FieldGrid.new(GRID_SIZE, GRID_SIZE)
	upper.refresh_paths()
	game.levels[1] = upper
	var at: Vector3 = HIT_AT + Vector3.UP * game.level_y(1)
	p.position = at - Vector3.RIGHT
	var dead: Dictionary = game.zombies.spawn("dead", at)
	game.feel.shot_in(p, dead["pos"], false, false)
	var count: int = fx.drop_count()
	_settle()
	assert_eq(_drop_spots().size(), count, "a continuous upper floor keeps every drop")
	assert_gt(_drops_past(float(WALL_X)), 0, "the same spray reaches past the future edge")
	for z in range(GRID_SIZE):
		for x in range(WALL_X, GRID_SIZE):
			upper.set_solid(Vector2i(x, z), FieldGrid.Solid.AIR)
	upper.refresh_paths()
	assert_true(game.grid.people_can_walk(Vector2i(WALL_X, 8)), "the ground below is still walkable")
	fx.begin_stop(42)
	game.feel.shot_in(p, dead["pos"], false, false)
	assert_eq(fx.drop_count(), count, "the edge does not change the spray count")
	_settle()
	assert_eq(_drops_past(float(WALL_X)), 0, "ground below cannot support an upper-floor mark")
	for spot: Vector3 in _drop_spots():
		assert_almost_eq(spot.y, game.level_y(1) + 0.02, 0.02, "remaining marks stay upstairs")
	game.levels.erase(1)
	fx.begin_stop(42)
	game.feel.shot_in(p, dead["pos"], false, false)
	_settle()
	assert_eq(_drop_spots().size(), 0, "a missing upper level cannot fall back to the ground grid")


func test_each_drop_checks_its_landing_once() -> void:
	var checks: Array[int] = [0]
	var can_land: Callable = func(_at: Vector3) -> bool:
		checks[0] += 1
		return true
	var contact: Dictionary = {"position": HIT_AT, "can_land": can_land}
	var hit: Dictionary = fx.hit(HIT_AT + Vector3.UP, Vector3.RIGHT, 1.0, "firearm", contact)
	var count: int = int(hit["count"])
	assert_gt(count, 0)
	fx.advance(1.0 / 120.0)
	assert_eq(checks[0], 0, "no checks during flight")
	_settle()
	assert_eq(checks[0], count, "one check for each drop, none for the puff")
	fx.advance(1.0)
	assert_eq(checks[0], count, "settled drops are not checked again")


func _knife_contact() -> Dictionary:
	var note: Dictionary = {}
	p.strike_kind = "swing"
	p.strike_at = {"state": "chase"}
	p.strike_total = 0.4
	p.strike_t = 0.4
	p.swing_t = 0.0
	PersonVisual.motion_of(p, note, 0.0, [], OWN)
	p.strike_t = 0.0
	p.swing_t = 0.3
	PersonVisual.motion_of(p, note, 0.4, [], OWN)
	return note


func _yaw(note: Dictionary) -> float:
	var forward: Vector3 = PersonVisual.lean_of(p, note) * Vector3.BACK
	forward.y = 0.0
	return Vector3.BACK.signed_angle_to(forward, Vector3.UP)


func test_a_grab_at_knife_contact_clears_the_turn_but_a_free_blow_keeps_it() -> void:
	var note: Dictionary = _knife_contact()
	assert_almost_eq(_yaw(note), float(PersonVisual.OWN_BLOW_AIM["p_stab"]), 0.001, "the free stab turns at contact")
	p.swing_t = 0.15
	PersonVisual.motion_of(p, note, 0.15, [], OWN)
	assert_gt(_yaw(note), 0.0, "a free blow still turns on its way back")
	note = _knife_contact()
	p.grabbers = [{"pos": p.position + Vector3.RIGHT}]
	p.grab_front = true
	for i in range(6):
		p.swing_t = maxf(0.0, 0.3 - float(i) * 0.1)
		var motion: Vector2 = PersonVisual.motion_of(p, note, 0.1, [], OWN)
		assert_eq(int(motion.y), 1, "the held motion takes over")
		assert_almost_eq(_yaw(note), 0.0, 0.001, "held: no leftover stab turn, even after the blow ends")


func test_blood_and_interrupted_aim_leave_the_game_rng_unchanged() -> void:
	var dead: Dictionary = game.zombies.spawn("dead", HIT_AT)
	_wall()
	var state: int = game.rng.state
	game.feel.shot_in(p, dead["pos"], false, false)
	_settle()
	var note: Dictionary = _knife_contact()
	p.grabbers = [dead]
	PersonVisual.motion_of(p, note, 0.1, [], OWN)
	PersonVisual.lean_of(p, note)
	assert_eq(game.rng.state, state, "blood and drawing leave the rules' dice untouched")
