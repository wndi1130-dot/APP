extends "res://addons/gut/test.gd"
## 결정 441: 경로의 발 묶음, 사람별 봐주기, 먹힌 시간, 머리·목 물림.

const FieldGame = preload("res://game/field_game.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const Motion = preload("res://game/sim/motion.gd")
const EatRules = preload("res://game/sim/eat_rules.gd")
const GrabRules = preload("res://game/sim/grab_rules.gd")
const BodyState = preload("res://game/sim/body_state.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const FieldCombat = preload("res://game/field_combat.gd")

var game
var p
var ally


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)
	for q in game.squad:
		if q != p:
			q.position = game.lift(Vector2i(30, 7), 0)
			if ally == null:
				ally = q
	ally.position = p.position + Vector3(0, 0, 2)
	ally.hands = [{"id": "axe", "quality": "factory", "condition": 1.0, "loaded": 0}]


func after_each() -> void:
	ally = null
	DeadBody.table = []
	DeadBody.named = {}


func _dead(at: Vector3) -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", at)
	z["lunger"] = false
	z["sense_t"] = 0.0
	return z


func test_paths_hold_player_companion_and_raider_only_during_the_weapon_feet_span() -> void:
	for who in [p, ally]:
		for team in ["squad", "raider"]:
			who.team = team
			who.running = false
			who.stop()
			who.swing_t = 0.0
			who.strike_t = 0.0
			game.combat.start_swing(who, {})
			var row: Dictionary = Motion.swing_row(who.weapon_id())
			var mult: float = float(who.mults()["swing"])
			who.path = PackedVector3Array([who.position + Vector3(2, 0, 0)])
			var at: Vector3 = who.position
			game._move_person(who, 0.01)
			assert_ne(who.position, at, "feet_from 전에는 경로를 걸을 수 있다")
			game.clock.elapsed += (float(row["feet"].x) + 0.01) / mult
			at = who.position
			var path: PackedVector3Array = who.path.duplicate()
			game._move_person(who, 0.1)
			assert_eq(who.position, at)
			assert_eq(who.path, path, "묶여 있는 동안 경로를 소비하지 않는다")
			assert_false(who.moving)
			game.clock.elapsed += float(row["len"]) / mult
			who.strike_t = 0.0
			who.swing_t = 0.0
			game._move_person(who, 0.1)
			assert_ne(who.position, at, "휘두름 뒤 같은 경로로 돌아간다")
		who.team = "squad"


func test_a_stomp_does_not_hold_path_feet() -> void:
	p.stop()
	p.swing_t = 0.0
	p.strike_t = 0.0
	p.hands = []
	var z := _dead(p.position + Vector3(0.5, 0, 0))
	z["state"] = "downed"
	game.combat.start_swing(p, z)
	assert_eq(p.strike_kind, "stomp")
	p.path = PackedVector3Array([p.position + Vector3(2, 0, 0)])
	var at: Vector3 = p.position
	assert_false(game.combat.feet_held(p))
	game._move_person(p, 0.1)
	assert_ne(p.position, at)


# A shove plants the feet from the arms drawn back until just after it lands, the
# first half of it (user field test 10-25: the shove a little longer), then they are free.
func test_a_shove_plants_the_feet_for_its_first_half() -> void:
	p.stop()
	p.swing_t = 0.0
	p.strike_t = 0.0
	game.combat.start_shove(p)
	p.path = PackedVector3Array([p.position + Vector3(2, 0, 0)])
	var at: Vector3 = p.position
	assert_true(game.combat.feet_held(p), "drawn back, the feet are planted")
	game._move_person(p, 0.1)
	assert_eq(p.position, at)
	p.shove_t = 0.0
	p.lunge_t = FieldCombat.SHOVE_LUNGE - FieldCombat.SHOVE_PLANT * 0.5
	assert_true(game.combat.feet_held(p), "just landed, still planted")
	p.lunge_t = FieldCombat.SHOVE_LUNGE - FieldCombat.SHOVE_PLANT - 0.01
	assert_false(game.combat.feet_held(p), "the arms coming back, it may step")
	game._move_person(p, 0.1)
	assert_ne(p.position, at)


# A companion's reflex shove (not drawn back first) is seen all the same, plants the
# feet just after it lands, and keeps the walk it was on: the hold is for swings.
func test_a_reflex_shove_is_seen_plants_the_feet_and_keeps_the_order() -> void:
	ally.stop()
	ally.swing_t = 0.0
	ally.strike_t = 0.0
	ally.strike_kind = "swing"      # it swung before
	game.combat.shove(ally)
	assert_almost_eq(ally.lunge_t, FieldCombat.SHOVE_LUNGE, 0.001, "the arms out and back are seen")
	assert_true(game.combat.feet_held(ally), "planted as it lands")
	ally.path = PackedVector3Array([ally.position + Vector3(2, 0, 0)])
	assert_false(game.ai._hold_swing(ally), "the order is not held")
	assert_false(ally.path.is_empty(), "nor the walk dropped")
	var at: Vector3 = ally.position
	game._move_person(ally, 0.05)
	assert_eq(ally.position, at)
	game.combat.update(FieldCombat.SHOVE_PLANT + 0.01)
	assert_false(game.combat.feet_held(ally))
	game._move_person(ally, 0.05)
	assert_ne(ally.position, at, "then it walks on")


func test_companion_walks_between_targets_then_stops_before_swinging() -> void:
	var z := _dead(ally.position + Vector3(5, 0, 0))
	ally.facing = PI * 0.5
	game.ai._engage(ally, z)
	game.combat._pursue_zombie(ally, 0.1)
	assert_gt(ally.path.size(), 0)
	game._move_person(ally, 0.1)
	assert_true(ally.moving)
	assert_eq(ally.strike_t, 0.0, "다음 표적까지 걷는 동안 휘두르지 않는다")
	z["pos"] = ally.position + Vector3(0.8, 0, 0)
	game.ai._engage(ally, z)
	game.combat._pursue_zombie(ally, 0.1)
	assert_false(ally.moving)
	assert_true(ally.path.is_empty())
	assert_gt(ally.strike_t, 0.0, "닿는 표적 앞에 멈춰서 휘두른다")
	var next := _dead(ally.position + Vector3(4, 0, 0))
	game.ai._engage(ally, next)
	assert_eq(ally.target_zombie, z, "진행 중인 휘두름의 표적을 버리지 않는다")
	assert_true(ally.path.is_empty())


func test_raider_stops_in_reach_and_does_not_swing_on_the_way() -> void:
	ally.team = "raider"
	ally.brain["role"] = "flanker"
	p.position = ally.position + Vector3(5, 0, 0)
	game.ai._raider_fight(ally, p, true)
	assert_gt(ally.path.size(), 0)
	assert_eq(ally.strike_t, 0.0)
	p.position = ally.position + Vector3(0.8, 0, 0)
	game.ai._raider_fight(ally, p, true)
	game.combat._pursue_person(ally, 0.1)
	assert_true(ally.path.is_empty())
	assert_false(ally.moving)
	assert_gt(ally.strike_t, 0.0)


func _sense(z: Dictionary, who, age: float) -> void:
	z["age"] = age
	z["sense_t"] = 0.0
	z["cooldown"] = 0.0
	game.zombies._sense(z, [who], 0.1)


func test_each_new_person_gets_grace_but_switching_back_does_not_restart_it() -> void:
	var z := _dead(p.position + Vector3(0.5, 0, 0))
	ally.position = p.position
	_sense(z, p, 10.0)
	assert_eq(String(z["state"]), "chase")
	_sense(z, p, 10.5)
	assert_eq(String(z["state"]), "attack")
	z["state"] = "chase"
	_sense(z, ally, 11.0)
	assert_eq(String(z["state"]), "chase", "새로 본 두 번째 사람도 봐준다")
	_sense(z, ally, 11.49)
	assert_eq(String(z["state"]), "chase")
	_sense(z, ally, 11.5)
	assert_eq(String(z["state"]), "attack")
	z["state"] = "chase"
	_sense(z, p, 11.6)
	assert_eq(String(z["state"]), "attack", "돌아온 표적은 다시 봐주지 않는다")
	assert_eq(float(z["seen_at"][p.get_instance_id()]), 10.0)
	assert_eq(float(z["seen_at"][ally.get_instance_id()]), 11.0)
	z["state"] = "wander"
	_sense(z, ally, 12.0)
	assert_eq(String(z["state"]), "attack", "추격을 끊어도 기억은 남는다")


func test_first_sensed_person_is_remembered_even_when_another_is_closer() -> void:
	var z := _dead(p.position + Vector3(0.4, 0, 0))
	ally.position = p.position + Vector3(1, 0, 0)
	z["age"] = 20.0
	game.zombies._sense(z, [p, ally], 0.1)
	assert_eq(z["victim"], p)
	assert_true(z["seen_at"].has(ally.get_instance_id()))
	_sense(z, ally, 20.5)
	assert_eq(String(z["state"]), "attack")
	assert_eq(float(z["seen_at"][ally.get_instance_id()]), 20.0)
	var other := _dead(z["pos"])
	_sense(other, ally, 20.5)
	assert_eq(String(other["state"]), "chase", "다른 망자의 첫 감지는 별개다")


func _corpse(permanent: bool) -> Dictionary:
	ally.position = game.lift(Vector2i(60, 60), 0)
	game.on_person_died(ally)
	var risen: Dictionary = game.zombies.find(int(ally.brain["rising_id"]))
	if permanent:
		risen["state"] = "dead"
	game.zombies._food = game.zombies._edible_bodies()
	return risen


func _eater(offset: float) -> Dictionary:
	var z := _dead(ally.position + Vector3(offset, 0, 0))
	z["eat_of"] = ally.get_instance_id()
	assert_true(game.zombies._begin_eating(z))
	return z


func test_eaters_add_their_time_and_all_leave_at_120_without_removing_the_body() -> void:
	var risen := _corpse(true)
	var first := _eater(0.5)
	var second := _eater(-0.5)
	game.zombies.update(30.0)
	assert_eq(float(ally.get_meta(EatRules.EATEN_META, 0.0)), 60.0)
	assert_true(EatRules.edible(ally, risen))
	game.zombies.update(30.0)
	assert_eq(float(ally.get_meta(EatRules.EATEN_META, 0.0)), EatRules.EAT_TOTAL)
	assert_false(EatRules.edible(ally, risen))
	assert_false(game.zombies._edible_bodies().has(ally))
	for z in [first, second]:
		assert_eq(String(z["state"]), "wander")
		assert_true(z.has("ate_until"), "기존 eat_rise로 일어나는 길을 쓴다")
		assert_false(z.has("eat_of"))
	DeadBody.table = []
	for i in 30:
		DeadBody.table.append([i * 32, 32, true, 1.0])
	DeadBody.named = {"eat_start": 27, "eat": 28, "eat_rise": 29}
	first["body_at"] = first["pos"]
	assert_eq(DeadBody.motion_in(DeadBody.custom(first, 0.0, 0.0, 1.0, true).g), 29)
	var late := _dead(ally.position + Vector3(5, 0, 0))
	assert_false(game.zombies._go_to_food(late), "다 먹힌 몸은 새 망자를 모으지 않는다")
	assert_true(is_instance_valid(ally))
	assert_has(game.people, ally)
	assert_eq(String(risen["state"]), "dead")


func test_the_eaten_time_rides_the_field_save() -> void:
	ally.set_meta(EatRules.EATEN_META, EatRules.EAT_TOTAL)
	var row: Dictionary = FieldSave._person(game, ally)
	var key := String(EatRules.EATEN_META)
	assert_eq(float(row["meta"][key]), EatRules.EAT_TOTAL, "판 2는 사람 메타 칸(PERSON_META)에 싣는다")
	ally.set_meta(EatRules.EATEN_META, 0.0)
	FieldSave._put_person(ally, row)
	assert_eq(float(ally.get_meta(EatRules.EATEN_META, 0.0)), EatRules.EAT_TOTAL, "다 먹힌 몸은 이어 하기 뒤에도 다 먹힌 몸")
	(row["meta"] as Dictionary).erase(key)
	row["eaten"] = EatRules.EAT_TOTAL
	FieldSave._put_person(ally, row)
	assert_eq(float(ally.get_meta(EatRules.EATEN_META, 0.0)), EatRules.EAT_TOTAL, "판 1 줄의 eaten 칸도 읽는다")
	row.erase("eaten")
	FieldSave._put_person(ally, row)
	assert_eq(float(ally.get_meta(EatRules.EATEN_META, 0.0)), 0.0, "이 칸이 없던 저장은 0초")


func test_interrupted_eating_keeps_the_total_and_a_living_body_still_rises() -> void:
	var risen := _corpse(false)
	var eater := _eater(0.5)
	game.zombies.update(10.0)
	assert_eq(float(ally.get_meta(EatRules.EATEN_META, 0.0)), 10.0)
	eater["state"] = "downed"
	eater["t"] = 20.0
	game.zombies.update(10.0)
	assert_eq(float(ally.get_meta(EatRules.EATEN_META, 0.0)), 10.0)
	assert_true(game.zombies._begin_eating(eater))
	game.zombies.update(10.0)
	assert_eq(String(risen["state"]), "wander", "원래의 30초 기상은 그대로다")
	game.zombies.update(0.01)
	assert_ne(String(eater["state"]), "eat")
	assert_false(EatRules.edible(ally, risen))


func test_bite_shares_are_60_20_5_15_and_crawlers_only_bite_legs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 441
	var counts: Dictionary = {"arm": 0, "torso": 0, "head_neck": 0, "leg": 0}
	for i in 20000:
		var part: String = GrabRules.bite_location(rng, false)
		counts[part] += 1
	assert_almost_eq(float(counts["arm"]) / 20000.0, 0.60, 0.015)
	assert_almost_eq(float(counts["torso"]) / 20000.0, 0.20, 0.015)
	assert_almost_eq(float(counts["head_neck"]) / 20000.0, 0.05, 0.01)
	assert_almost_eq(float(counts["leg"]) / 20000.0, 0.15, 0.015)
	for i in 100:
		assert_eq(GrabRules.bite_location(rng, true), "leg")


func test_actual_head_neck_bite_bleeds_one_and_says_neck_other_bites_stay_point_four() -> void:
	var rng := RandomNumberGenerator.new()
	var head_seed := -1
	for value in range(1, 1000):
		rng.seed = value
		if GrabRules.bite_location(rng, false) == "head_neck":
			head_seed = value
			break
	assert_gt(head_seed, 0)
	var victim = ally
	var z := _dead(victim.position + Vector3(0.5, 0, 0))
	z["state"] = "grab"
	z["victim"] = victim
	victim.grabbers.append(z)
	victim.grab_left = 0.0
	game.rng.seed = head_seed
	game.combat.bite(victim)
	assert_true(victim.body.has_bite_wound())
	assert_eq(String(victim.body.wounds[-1]["part"]), "head_neck")
	assert_eq(float(victim.body.wounds[-1]["blood"]), 1.0)
	var said_neck := false
	for line in game.hud.says:
		if String(line["text"]).contains("목을 물렸다"):
			said_neck = true
	assert_true(said_neck)
	for part in ["arm_left", "torso", "leg_right"]:
		var body := BodyState.new()
		body.apply_bite(rng, part, 0.0)
		assert_eq(float(body.wounds[-1]["blood"]), 0.4)


func test_crowded_companion_finishes_a_reachable_fallen_one_before_moving_on() -> void:
	ally.facing = PI * 0.5
	var fallen := _dead(ally.position + Vector3(0.8, 0, 0))
	fallen["state"] = "downed"
	var threat := _dead(ally.position + Vector3(2.0, 0, 0.5))
	_dead(ally.position + Vector3(2.1, 0, -0.5))
	_dead(ally.position + Vector3(0, 0, 2.2))
	assert_gte(game.ai._crowd(ally), game.ai.CROWD_N)
	ally.path = PackedVector3Array([ally.position + Vector3(-2, 0, 0)])
	ally.moving = true
	game.ai._engage(ally, threat)
	assert_eq(ally.target_zombie, fallen, "닿는 쓰러진 몸을 먼저 마무리한다")
	assert_true(ally.path.is_empty())
	assert_false(ally.moving)
	game.combat._pursue_zombie(ally, 0.1)
	assert_gt(ally.strike_t, 0.0)
	assert_eq(ally.strike_at, fallen)


func test_finishing_never_starts_a_walk_to_a_far_body_or_replaces_a_shove_with_a_stomp() -> void:
	var fallen := _dead(ally.position + Vector3(3, 0, 0))
	fallen["state"] = "downed"
	var threat := _dead(ally.position + Vector3(5, 0, 0))
	game.ai._engage(ally, threat)
	assert_eq(ally.target_zombie, threat)
	game.combat._pursue_zombie(ally, 0.1)
	assert_gt(ally.path.size(), 0)
	assert_eq(ally.strike_t, 0.0)
	fallen["pos"] = ally.position + Vector3(0.5, 0, 0)
	ally.hands = [{"id": "bow", "quality": "factory", "condition": 1.0, "loaded": 1}]
	assert_false(game.ai._finish_fallen(ally), "활을 들고 있을 때 새 밟기로 바꾸지 않는다")
	ally.hands = []
	assert_false(game.ai._finish_fallen(ally), "맨손일 때도 기존 밀치기 선택을 유지한다")


func test_finishing_measures_to_the_chest_a_blow_is_judged_at() -> void:
	# Decision 487 (J2): one on the ground is struck on its chest, toward the head the
	# way it went over; a companion does not walk out to one whose chest is past reach.
	var r: float = game.combat.melee_range(ally)
	var fallen := _dead(ally.position + Vector3(r - 0.2, 0, 0))
	fallen["state"] = "downed"
	fallen["t"] = 99.0            # lying flat, not getting up
	fallen["angle"] = -PI * 0.5   # it faced the companion
	fallen["phase"] = 0.5 / 5.17  # lying straight on its line
	fallen["fell_fwd"] = false    # on its back: the chest away, past the reach
	assert_false(game.ai._finish_fallen(ally))
	fallen["fell_fwd"] = true     # on its face: the chest toward the companion
	assert_true(game.ai._finish_fallen(ally))
	assert_eq(ally.target_zombie, fallen)
