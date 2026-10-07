extends "res://addons/gut/test.gd"

const W = preload("res://game/sim/weapons.gd")

const MELEE_KEYS := ["name", "kind", "hands", "weight", "sound", "reach", "swing", "head_base", "head_kill", "knockdown", "blade", "fatigue", "wear", "pry"]
const RANGED_KEYS := ["name", "kind", "hands", "weight", "sound", "ammo", "mag", "reload", "reload_each", "pellets", "spread_deg", "start_deg", "min_deg", "shrink_time", "bloom_deg", "min_dist", "range", "head_kill", "body_knockdown", "action", "wear", "min_skill"]


func test_data_has_seven_weapons_with_all_keys() -> void:
	assert_eq(W.DATA.size(), 7)
	for id: String in ["knife", "crowbar", "axe"]:
		assert_eq(W.DATA[id]["kind"], "melee", id)
		for k: String in MELEE_KEYS:
			assert_true(W.DATA[id].has(k), "%s.%s" % [id, k])
	for id: String in ["pistol", "shotgun", "bow", "pipe_shotgun"]:
		for k: String in RANGED_KEYS:
			assert_true(W.DATA[id].has(k), "%s.%s" % [id, k])
	assert_eq(W.DATA["bow"]["kind"], "bow")
	assert_eq(W.DATA["pistol"]["kind"], "gun")


func test_spec_numbers() -> void:
	assert_eq(W.DATA["knife"]["weight"], 1.0)
	assert_eq(W.DATA["axe"]["weight"], 3.0)
	assert_eq(W.DATA["pipe_shotgun"]["weight"], 3.0)
	assert_eq(W.DATA["knife"]["sound"], 0)
	assert_eq(W.DATA["bow"]["sound"], 0)
	assert_eq(W.DATA["pistol"]["sound"], 2)
	assert_eq(W.DATA["shotgun"]["sound"], 3)
	assert_eq(W.DATA["pipe_shotgun"]["sound"], 3)
	assert_eq(W.DATA["crowbar"]["reach"], 1.15)
	assert_true(W.DATA["crowbar"]["pry"])
	assert_false(W.DATA["knife"]["pry"])
	assert_true(W.DATA["knife"]["blade"])
	assert_true(W.DATA["axe"]["blade"])
	assert_false(W.DATA["crowbar"]["blade"])
	assert_eq(W.DATA["pistol"]["mag"], 8)
	assert_eq(W.DATA["shotgun"]["mag"], 4)
	assert_eq(W.DATA["shotgun"]["pellets"], 8)
	assert_eq(W.DATA["pipe_shotgun"]["pellets"], 7)
	assert_true(W.DATA["shotgun"]["reload_each"])
	assert_false(W.DATA["pistol"]["reload_each"])
	assert_eq(W.DATA["pipe_shotgun"]["ammo"], "shell")
	assert_eq(W.DATA["bow"]["ammo"], "craft")
	assert_eq(W.DATA["bow"]["min_skill"], 4)
	assert_eq(W.DATA["pipe_shotgun"]["action"], "single")
	assert_eq(W.DATA["shotgun"]["hands"], 2)
	assert_eq(W.DATA["pistol"]["hands"], 1)
	for id: String in W.DATA:
		var ammo: String = W.DATA[id].get("ammo", "")
		if ammo != "":
			assert_true(W.AMMO_NAMES.has(ammo), id)


func test_condition_level_boundaries() -> void:
	assert_eq(W.condition_level(1.0), 0)
	assert_eq(W.condition_level(0.61), 0)
	assert_eq(W.condition_level(0.6), 1)
	assert_eq(W.condition_level(0.31), 1)
	assert_eq(W.condition_level(0.3), 2)
	assert_eq(W.condition_level(0.0), 2)
	assert_eq(W.CONDITION_NAMES.size(), 3)


func test_jam_chance_semi_pump() -> void:
	assert_eq(W.jam_chance("pistol", 0.9, false), 0.0)
	assert_eq(W.jam_chance("pistol", 0.5, false), 0.03)
	assert_eq(W.jam_chance("pistol", 0.1, false), 0.10)
	assert_eq(W.jam_chance("shotgun", 0.9, true), 0.03)
	assert_eq(W.jam_chance("shotgun", 0.5, true), 0.10)
	assert_eq(W.jam_chance("shotgun", 0.1, true), 0.15)


func test_jam_chance_single_bow_melee_zero() -> void:
	for id: String in ["pipe_shotgun", "bow", "knife"]:
		assert_eq(W.jam_chance(id, 0.0, true), 0.0, id)


func test_misfire_only_single_and_cold_one_step() -> void:
	assert_eq(W.misfire_chance("pipe_shotgun", 0.9, false), 0.03)
	assert_eq(W.misfire_chance("pipe_shotgun", 0.5, false), 0.06)
	assert_eq(W.misfire_chance("pipe_shotgun", 0.2, false), 0.10)
	assert_eq(W.misfire_chance("pipe_shotgun", 0.9, true), 0.06)
	assert_eq(W.misfire_chance("pipe_shotgun", 0.5, true), 0.10)
	assert_eq(W.misfire_chance("pipe_shotgun", 0.2, true), 0.10)
	assert_eq(W.misfire_chance("pistol", 0.0, true), 0.0)
	assert_eq(W.misfire_chance("bow", 0.0, true), 0.0)


func test_crude_pipe_never_jams_more_than_factory_semi() -> void:
	# 2026-10-07 axis split: jam comes from action, not quality.
	for c: float in [0.9, 0.5, 0.1]:
		assert_true(W.jam_chance("pipe_shotgun", c, true) <= W.jam_chance("pistol", c, true))


func test_burst_only_crude_single() -> void:
	assert_eq(W.burst_chance("pipe_shotgun", "crude"), 0.03)
	assert_eq(W.burst_chance("pipe_shotgun", "usable"), 0.0)
	assert_eq(W.burst_chance("pipe_shotgun", "fine"), 0.0)
	assert_eq(W.burst_chance("pipe_shotgun", "factory"), 0.0)
	assert_eq(W.burst_chance("shotgun", "crude"), 0.0)


func test_min_deg_quality_on_crafted() -> void:
	# skill 5: 1.3 - 0.3 = 1.0
	assert_almost_eq(W.min_deg("pipe_shotgun", "crude", 5), 2.0 * 1.8, 0.0001)
	assert_almost_eq(W.min_deg("pipe_shotgun", "usable", 5), 2.0 * 1.3, 0.0001)
	assert_almost_eq(W.min_deg("pipe_shotgun", "fine", 5), 2.0 * 1.05, 0.0001)
	assert_almost_eq(W.min_deg("pipe_shotgun", "factory", 5), 2.0, 0.0001)
	assert_true(W.min_deg("pipe_shotgun", "crude", 5) > W.min_deg("pipe_shotgun", "usable", 5))
	assert_true(W.min_deg("pipe_shotgun", "usable", 5) > W.min_deg("pipe_shotgun", "fine", 5))


func test_min_deg_factory_ignores_quality() -> void:
	assert_almost_eq(W.min_deg("pistol", "crude", 5), 1.2, 0.0001)


func test_min_deg_skill_curve_and_floor() -> void:
	assert_almost_eq(W.min_deg("pistol", "factory", 0), 1.2 * 1.3, 0.0001)
	assert_almost_eq(W.min_deg("pistol", "factory", 10), 1.2 * 0.7, 0.0001)
	assert_almost_eq(W.min_deg("pistol", "factory", 20), 1.2 * 0.7, 0.0001)


func test_min_deg_bow_skill_shortfall() -> void:
	# skill 0: 4 short -> x2.0; skill 2: x1.5; skill 4: none
	assert_almost_eq(W.min_deg("bow", "factory", 0), 1.0 * 1.3 * 2.0, 0.0001)
	assert_almost_eq(W.min_deg("bow", "factory", 2), 1.0 * (1.3 - 0.12) * 1.5, 0.0001)
	assert_almost_eq(W.min_deg("bow", "factory", 4), 1.0 * (1.3 - 0.24), 0.0001)
	assert_almost_eq(W.min_deg("bow", "factory", 5), 1.0 * 1.0, 0.0001)


func test_wear_per_use() -> void:
	assert_almost_eq(W.wear_per_use("pipe_shotgun", "crude"), 0.04, 0.0001)
	assert_almost_eq(W.wear_per_use("pipe_shotgun", "usable"), 0.026, 0.0001)
	assert_almost_eq(W.wear_per_use("pistol", "crude"), 0.006, 0.0001)
	assert_almost_eq(W.wear_per_use("knife", "factory"), 0.01, 0.0001)


func test_melee_head_chance() -> void:
	assert_eq(W.melee_head_chance("crowbar", 0, true, false), 1.0)
	assert_almost_eq(W.melee_head_chance("knife", 0, false, false), 0.30, 0.0001)
	assert_almost_eq(W.melee_head_chance("knife", 3, false, false), 0.42, 0.0001)
	assert_almost_eq(W.melee_head_chance("knife", 3, false, true), 0.57, 0.0001)
	assert_almost_eq(W.melee_head_chance("axe", 10, false, true), 0.87, 0.0001)
	assert_almost_eq(W.melee_head_chance("axe", 12, false, true), 0.9, 0.0001)


func test_unknown_id_is_safe() -> void:
	assert_false(W.is_known("rifle"))
	assert_eq(W.jam_chance("rifle", 0.0, true), 0.0)
	assert_eq(W.min_deg("rifle", "factory", 0), 0.0)
	assert_true(W.is_ranged("bow"))
	assert_false(W.is_ranged("axe"))
