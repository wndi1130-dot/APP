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
