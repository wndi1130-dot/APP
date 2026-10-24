extends "res://addons/gut/test.gd"

const BloodFx = preload("res://fx/blood_fx.gd")
const FxState = preload("res://fx/fx_state.gd")
var fx


func before_each() -> void:
	FxState.set_blood_level(FxState.BloodLevel.NORMAL)
	fx = BloodFx.new()
	add_child_autofree(fx)
	fx.set_process(false)
	fx.begin_stop(42)


func after_each() -> void:
	fx.clear()
	FxState.set_blood_level(FxState.BloodLevel.NORMAL)


func _floor(y: float = 0.0, snow: bool = false) -> Dictionary:
	return {"position": Vector3(0, y, 0), "snow": snow}


## Let every drop in the air land.
func _settle() -> void:
	for _i in range(40):
		fx.advance(0.05)


func test_marks_are_one_multimesh_capped_and_oldest_goes_first() -> void:
	assert_eq(fx.find_children("*", "MultiMeshInstance3D", true, false).size(), 2, "marks and drops, one draw each")
	assert_eq(fx.splats.multimesh.instance_count, BloodFx.MAX_SPLATS)
	for i in range(BloodFx.MAX_SPLATS + 100):
		fx.stain(Vector3(i * 0.01, 0, 0))
	assert_eq(fx.splat_count(), BloodFx.MAX_SPLATS)
	var order: Array[int] = fx.splat_order()
	assert_eq(order[0], 100, "the 100 oldest were written over")
	assert_eq(order[-1], 99)


func test_every_weapon_and_strength_keeps_a_hit_at_most_24_drops() -> void:
	FxState.set_blood_level(FxState.BloodLevel.HIGH)
	for kind in ["blunt", "slash", "pierce", "firearm", "unknown"]:
		fx.clear()
		var hit: Dictionary = fx.hit(Vector3(0, 1.2, 0), Vector3.RIGHT, 100.0, kind, _floor())
		assert_lte(int(hit["count"]), BloodFx.MAX_DROPS_PER_HIT, kind)
		assert_gt(int(hit["count"]), 0, kind)
		assert_lte(fx.drop_count(), BloodFx.MAX_DROPS)


func test_drops_fly_then_land_as_marks_at_the_floor_height() -> void:
	var hit: Dictionary = fx.hit(Vector3(0, 1.2, 0), Vector3.RIGHT, 1.0, "slash", _floor(0.3))
	var flying: int = fx.drop_count()
	assert_eq(flying, int(hit["count"]))
	var before: int = fx.splat_count()
	_settle()
	assert_eq(fx.drop_count(), 0)
	assert_eq(fx.splat_count() - before, flying, "one mark per drop")
	var ahead := 0
	for index in fx.splat_order():
		var at: Vector3 = fx.records[index]["xf"].origin
		assert_almost_eq(at.y, 0.3, 0.02)
		if at.x > 0.05:
			ahead += 1
	assert_gt(ahead, flying / 2, "most marks lie the way the blow went")


func test_no_floor_contact_means_no_floor_marks() -> void:
	fx.hit(Vector3(0, 10, 0), Vector3.RIGHT)
	_settle()
	assert_eq(fx.splat_count(), 0, "no imaginary floor at height zero")
	assert_eq(fx.drop_count(), 0, "drops without a floor are let go")


func test_off_clears_and_blocks_every_entry_point() -> void:
	fx.hit(Vector3(0, 1, 0), Vector3.RIGHT, 1.0, "blunt", _floor())
	fx.pool(Vector3.ZERO)
	var anchor := Node3D.new()
	add_child_autofree(anchor)
	fx.body_mark(anchor, Transform3D.IDENTITY, "bite")
	FxState.set_blood_level(FxState.BloodLevel.OFF)
	assert_eq(fx.splat_count(), 0)
	assert_eq(fx.drop_count(), 0)
	assert_eq(fx.hit(Vector3.ZERO, Vector3.RIGHT, 1.0, "blunt", _floor()), {})
	assert_eq(fx.death(Vector3.ZERO, Vector3.RIGHT, "blunt", _floor()), {})
	assert_eq(fx.pool(Vector3.ZERO), {})
	assert_eq(fx.wall(Vector3.ZERO, Vector3.BACK), {})
	assert_eq(fx.stain(Vector3.ZERO), {})
	assert_eq(fx.body_mark(anchor, Transform3D.IDENTITY), -1)
	for slot in fx.body_marks:
		assert_false(bool(slot["active"]))


func test_level_changes_density() -> void:
	var counts := []
	for level in [FxState.BloodLevel.LOW, FxState.BloodLevel.NORMAL, FxState.BloodLevel.HIGH]:
		FxState.set_blood_level(level)
		fx.clear()
		counts.append(int(fx.hit(Vector3(0, 1, 0), Vector3.RIGHT, 1.0, "blunt", _floor())["count"]))
	assert_lt(counts[0], counts[1])
	assert_lt(counts[1], counts[2])
	assert_eq(counts[1], 10)


func _landing_spots() -> Array:
	for kind in ["blunt", "slash", "pierce", "firearm"]:
		fx.hit(Vector3(0, 1.1, 0), Vector3(1, 0, 0.3), 0.8, kind, _floor(0.0, true))
	_settle()
	var spots := []
	for index in fx.splat_order():
		spots.append(fx.records[index]["xf"])
	return spots


func test_same_seed_reproduces_where_the_blood_lands() -> void:
	fx.begin_stop(918)
	var first := _landing_spots()
	fx.begin_stop(918)
	assert_eq(_landing_spots(), first)
	fx.begin_stop(919)
	assert_ne(_landing_spots(), first)


func test_marks_carry_kind_snow_and_birth_time_for_the_shader() -> void:
	fx.advance(2.0)
	var mark: Dictionary = fx.pool(Vector3.ZERO, true)
	var custom: Color = fx.records[int(mark["index"])]["custom"]
	assert_almost_eq(custom.g, 2.0, 0.001, "birth time")
	assert_almost_eq(custom.b, float(BloodFx.Kind.POOL) + 0.5, 0.001, "pool on snow")
	fx.advance(5.0)
	assert_almost_eq(float(fx.splat_material.get_shader_parameter("now")), 7.0, 0.001)


func test_wall_marks_face_out_and_run_down() -> void:
	var mark: Dictionary = fx.wall(Vector3(2, 1, 4), Vector3.RIGHT)
	var basis: Basis = fx.records[int(mark["index"])]["xf"].basis
	assert_almost_eq(basis.y.normalized().dot(Vector3.RIGHT), 1.0, 0.001)
	assert_almost_eq(basis.x.normalized().dot(Vector3.UP), 1.0, 0.001, "+X is up, drips go toward -X")


func test_drops_share_the_transient_budget_and_give_it_back() -> void:
	fx.hit(Vector3(0, 1, 0), Vector3.RIGHT, 1.0, "firearm", _floor())
	assert_gt(FxState.leased_particles(), 0)
	assert_lte(FxState.leased_particles(), FxState.TRANSIENT_PARTICLES)
	_settle()
	assert_eq(FxState.leased_particles(), 0)


func test_death_leaves_a_pool_under_the_body() -> void:
	fx.death(Vector3(0, 1, 0), Vector3.RIGHT, "blunt", _floor())
	var kinds := []
	for index in fx.splat_order():
		kinds.append(int(fx.records[index]["custom"].b))
	assert_has(kinds, BloodFx.Kind.POOL)
	assert_has(kinds, BloodFx.Kind.SPLAT)


func test_blood_colours_stay_dark_and_muted() -> void:
	# Blood must not read as the warning red: low saturation, dark.
	for c in [BloodFx.FRESH, BloodFx.DRIED]:
		assert_lt(c.s, 0.85)
		assert_lt(c.v, 0.3)


func test_body_marks_follow_anchor_and_release_removed_actor() -> void:
	var anchor := Node3D.new()
	add_child(anchor)
	fx.body_mark(anchor, Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)), "scratch")
	anchor.position = Vector3(3, 0, 0)
	fx.advance(0.1)
	assert_eq(fx.body_marks[0]["node"].global_position, Vector3(3, 1, 0))
	anchor.free()
	fx.advance(0.1)
	assert_false(bool(fx.body_marks[0]["active"]))


func test_stop_reset_keeps_nodes_and_clears_marks() -> void:
	var count: int = fx.get_child_count()
	fx.hit(Vector3(0, 1, 0), Vector3.RIGHT, 1.0, "blunt", _floor())
	fx.pool(Vector3.ZERO)
	fx.begin_stop(42)
	assert_eq(fx.get_child_count(), count)
	assert_eq(fx.splat_count(), 0)
	assert_eq(fx.drop_count(), 0)
	assert_eq(FxState.leased_particles(), 0)
