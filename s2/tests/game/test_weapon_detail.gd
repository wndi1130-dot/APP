extends "res://addons/gut/test.gd"
## Weapon rules beside the rows (weapons.md 규칙): silencers one step and worn,
## melee wear and skill, a factory blade that cracks and then breaks, arrows.

const FieldGame = preload("res://game/field_game.gd")
const W = preload("res://game/sim/weapons.gd")
const WR = preload("res://game/sim/weapon_rules.gd")
const SimNoise = preload("res://game/sim/noise.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


func test_a_silencer_is_one_step_and_never_quiet() -> void:
	assert_eq(WR.shot_level("pistol"), SimNoise.Level.LOUD)
	assert_eq(WR.shot_level("pistol", "silencer"), SimNoise.Level.NORMAL)
	assert_eq(WR.shot_level("pistol", "silencer_bottle"), SimNoise.Level.NORMAL)
	assert_eq(WR.shot_level("shotgun", "silencer"), SimNoise.Level.VERY_LOUD, "pistols and rifles only")
	assert_eq(WR.shot_level("bow", "silencer"), SimNoise.Level.QUIET)


func test_silencers_wear_the_bottle_in_a_few_shots() -> void:
	assert_eq(WR.silencer_wear("silencer_bottle", "pistol"), 0.25)
	assert_eq(WR.silencer_wear("silencer", "pistol"), 0.01)
	assert_eq(WR.silencer_wear("silencer", "shotgun"), 0.0)


func _last_gun_level() -> int:
	for i in range(game.sounds.size() - 1, -1, -1):
		if String(game.sounds[i]["tag"]) == "gun":
			return int(game.sounds[i]["level"])
	return -1


func test_a_silenced_pistol_shot_is_normal_and_the_bottle_gives_out() -> void:
	var p = game.player
	p.hands = [{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 8, "silencer": "silencer_bottle", "silencer_cond": 1.0}]
	var shots := 0
	var guard := 0
	while p.weapon().has("silencer") and guard < 50:
		guard += 1
		p.jam_t = 0.0
		p.reload_t = 0.0
		if game.combat.fire(p, p.position + Vector3(6, 0, 0)) == "shot":
			shots += 1
			if p.weapon().has("silencer"):
				assert_eq(_last_gun_level(), SimNoise.Level.NORMAL)
	assert_eq(shots, 4, "four shots and the bottle is gone")
	assert_eq(_last_gun_level(), SimNoise.Level.NORMAL, "the last one through it is still muffled")
	p.jam_t = 0.0
	p.reload_t = 0.0
	while game.combat.fire(p, p.position + Vector3(6, 0, 0)) != "shot":
		p.jam_t = 0.0
		p.reload_t = 0.0
	assert_eq(_last_gun_level(), SimNoise.Level.LOUD, "then the pistol is as loud as ever")


func test_melee_skill_wears_a_weapon_less() -> void:
	assert_eq(WR.melee_wear_mult("knife", 1), 1.0)
	assert_almost_eq(WR.melee_wear_mult("knife", 4), 15.0 / 17.0, 0.0001)
	assert_almost_eq(WR.melee_wear_mult("crowbar", 4), 70.0 / 72.0, 0.0001)
	assert_eq(WR.melee_wear_mult("broken_bottle", 8), 1.0, "improvised ones are meant to go")


func test_a_crowbar_outlasts_a_knife_by_seven() -> void:
	var knife: float = 1.0 / W.wear_per_use("knife", "factory")
	var crowbar: float = 1.0 / W.wear_per_use("crowbar", "factory")
	assert_eq(W.DATA["crowbar"]["wear"], 0.0014)
	assert_almost_eq(crowbar / knife, 7.0, 0.2)


func test_a_factory_knife_cracks_then_breaks() -> void:
	var p = game.player
	p.set_weapon_slots([{"id": "knife", "quality": "factory", "condition": 0.35, "loaded": 0}])
	assert_true(WR.cracks("knife", 0.35, 0.25))
	assert_false(WR.cracks("knife", 0.25, 0.15), "once")
	game.combat._wear(p, 0.1)
	assert_eq(p.hands.size(), 1, "cracked, still in the hand")
	game.combat._wear(p, 0.5)
	assert_true(p.hands.is_empty(), "broken at nothing")


func test_arrows_break_now_and_then() -> void:
	assert_true(WR.arrow_breaks(0.29, true))
	assert_false(WR.arrow_breaks(0.31, true))
	assert_true(WR.arrow_breaks(0.09, false))
	assert_false(WR.arrow_breaks(0.11, false))
