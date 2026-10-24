extends "res://addons/gut/test.gd"

const ImpactFx = preload("res://fx/impact_fx.gd")
const BloodFx = preload("res://fx/blood_fx.gd")
const FxState = preload("res://fx/fx_state.gd")
var fx


func before_each() -> void:
	FxState.set_blood_level(FxState.BloodLevel.NORMAL)
	fx = ImpactFx.new()
	add_child_autofree(fx)
	fx.set_process(false)
	fx.begin_stop(12)


func after_each() -> void:
	fx.clear()
	FxState.set_blood_level(FxState.BloodLevel.NORMAL)


func test_all_transient_pools_share_120_even_across_instances() -> void:
	var blood = BloodFx.new()
	add_child_autofree(blood)
	blood.set_process(false)
	var other = ImpactFx.new()
	add_child_autofree(other)
	other.set_process(false)
	for _i in range(50):
		blood.hit(Vector3.ZERO, Vector3.RIGHT, 2.0, "firearm")
		fx.glass(Vector3.ZERO, Vector3.UP)
		other.wood(Vector3.ZERO, Vector3.UP)
		assert_lte(FxState.leased_particles(), FxState.TRANSIENT_PARTICLES)
	assert_eq(FxState.TRANSIENT_PARTICLES, 120)
	blood.clear()
	other.clear()
	fx.clear()
	assert_eq(FxState.leased_particles(), 0)


func test_emitters_expire_and_budget_can_be_reused() -> void:
	fx.spark(Vector3.ZERO, Vector3.UP)
	fx.breath(Vector3.ZERO, Vector3.BACK)
	assert_gt(fx.particles.active_count(), 0)
	fx.advance(1.0)
	assert_eq(fx.particles.active_count(), 0)
	assert_eq(FxState.leased_particles(), 0)
	assert_gt(fx.wood(Vector3.ZERO, Vector3.UP), 0)


func test_glass_residue_is_bounded_fifo_and_uses_confirmed_floor() -> void:
	fx.glass(Vector3(0, 5, 0), Vector3.UP)
	assert_eq(_glass_ids().size(), 0)
	for _i in range(10):
		fx.glass(Vector3(0, 5, 0), Vector3.UP, Vector3(0, 4, 0))
	var ids := _glass_ids()
	assert_eq(ids.size(), 32)
	assert_eq(ids[0], 29)
	for slot in fx.glass_marks:
		assert_almost_eq(slot["node"].global_position.y, 4.012, 0.001)
	fx.advance(121.0)
	assert_eq(_glass_ids().size(), 0)


func test_glass_cleanup_only_removes_nearby_shards() -> void:
	fx.glass(Vector3.ZERO, Vector3.UP, Vector3.ZERO)
	fx.glass(Vector3(5, 0, 0), Vector3.UP, Vector3(5, 0, 0))
	fx.clear_glass(Vector3.ZERO)
	assert_eq(_glass_ids().size(), 6)


func _glass_ids() -> Array[int]:
	var ids: Array[int] = []
	for slot in fx.glass_marks:
		if float(slot["left"]) > 0.0:
			ids.append(int(slot["id"]))
	ids.sort()
	return ids


func test_breath_is_cold_only_and_smoke_flows_sideways() -> void:
	assert_eq(fx.breath(Vector3.ZERO, Vector3.UP, 10.0), 0)
	assert_eq(fx.breath(Vector3.ZERO, Vector3.UP, -10.0), 4)
	var p: CPUParticles3D = fx.particles.slots[0]["node"]
	assert_almost_eq(p.direction.y, 0.0, 0.001)
	assert_lt(p.gravity.y, 0.1)
	assert_lte(p.color.a, 0.22)


func test_muzzle_uses_four_particles_and_no_light_nodes() -> void:
	assert_eq(fx.muzzle(Vector3.ZERO, Vector3.RIGHT), 4)
	assert_eq(fx.find_children("*", "Light3D", true, false).size(), 0)
	assert_eq(fx.find_children("*", "PhysicsBody3D", true, false).size(), 0)


func test_feedback_is_bounded_and_does_not_change_engine_time_scale() -> void:
	var time_scale := Engine.time_scale
	fx.hit_feedback(1.0)
	assert_almost_eq(fx.simulation_delta(0.1), 0.055, 0.00001)
	assert_almost_eq(fx.simulation_delta(0.1), 0.1, 0.00001)
	fx.advance(0.02)
	assert_lte(fx.camera_offset().length(), 0.03)
	assert_gt(fx.hurt_amount(), 0.0)
	fx.advance(1.0)
	assert_eq(fx.camera_offset(), Vector3.ZERO)
	assert_eq(fx.hurt_amount(), 0.0)
	assert_eq(Engine.time_scale, time_scale)


func test_overlapping_hits_do_not_extend_the_same_hitstop() -> void:
	fx.hit_feedback()
	fx.simulation_delta(0.03)
	fx.hit_feedback()
	assert_almost_eq(fx.simulation_delta(0.03), 0.015, 0.00001)


func test_glass_positions_repeat_after_stop_seed_reset() -> void:
	fx.begin_stop(52)
	fx.glass(Vector3.ONE, Vector3.UP, Vector3.ZERO)
	var first := []
	for slot in fx.glass_marks:
		first.append(slot["node"].transform)
	fx.begin_stop(52)
	fx.glass(Vector3.ONE, Vector3.UP, Vector3.ZERO)
	var again := []
	for slot in fx.glass_marks:
		again.append(slot["node"].transform)
	assert_eq(first, again)
