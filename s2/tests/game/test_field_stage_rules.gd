extends "res://addons/gut/test.gd"

const R = preload("res://game/sim/field_stage_rules.gd")


func _day_receipt() -> Dictionary:
	return {"placeState": {"fieldStage": {
		"kind": "rest_day", "stopSerial": 2, "turnIndex": 3, "outcome": "day_closed",
		"peopleNoise": 13, "trackWest": 3, "trackEast": 2, "nightBonusPp": 20,
		"foodDelivered": 2, "siteRemaining": {"food_site": 4}, "outsidePeople": []}}}


func _return_receipt() -> Dictionary:
	return {"placeState": {"fieldStage": {
		"kind": "escort_return", "stopSerial": 2, "turnIndex": 3, "outcome": "cart_arrived",
		"trackAtFightEnd": R.capture_fight_end(11, 3), "ploughPartsPreview": 2,
		"coalDelivered": 12, "trainDamage": {"door": 1}}}}


func test_rest_food_cap_counts_reservations_and_all_carriers() -> void:
	var empty: Dictionary = R.food_account()
	var first: Dictionary = R.reserve_food(empty)
	assert_true(first.ok, "처음 두 묶음을 예약할 수 있다")
	assert_eq(empty, R.food_account(), "입력 계정은 바꾸지 않는다")
	var food: Dictionary = R.reserve_food(first.food).food
	assert_eq(food.reserved, 4)
	assert_false(R.reserve_food(food).ok, "다른 사람과 상자에도 같은 네 묶음 한도를 쓴다")
	food = R.complete_food(food).food
	assert_eq(food, {"reserved": 2, "carried": 2, "delivered": 0})
	var cancelled: Dictionary = R.cancel_food(food)
	assert_true(cancelled.ok)
	assert_eq(cancelled.food, {"reserved": 0, "carried": 2, "delivered": 0})
	assert_eq(food.reserved, 2, "취소는 입력 예약을 바꾸지 않는다")
	var one: Dictionary = R.deliver_food(cancelled.food, 1)
	assert_true(one.ok)
	assert_eq(one.foodDelta, 0, "한 묶음을 올림하지 않는다")
	var pair: Dictionary = R.deliver_food(one.food, 1)
	assert_eq(pair.foodDelta, 1, "둘째 묶음만 식량 하나가 된다")
	assert_false(R.deliver_food(pair.food, 1).ok, "같은 짐을 중복 납품하지 않는다")
	food = R.reserve_food(pair.food).food
	assert_false(R.reserve_food(food).ok, "납품한 묶음도 한도를 차지한다")
	food = R.complete_food(food).food
	var last: Dictionary = R.deliver_food(food, 2)
	assert_eq(last.foodDelta, 1)
	assert_eq(R.food_delivered(last.food.delivered), R.REST_FOOD_CAP)
	assert_false(R.reserve_food(last.food).ok)
	assert_false(R.cancel_food(last.food).ok, "취소로 납품 몫을 지우지 않는다")
	assert_eq(R.food_delivered(3), 1)
	assert_false(R.reserve_food(empty, 1).ok, "새 작업은 두 묶음으로 예약한다")
	assert_false(R.deliver_food(empty, -1).ok)
	assert_false(R.reserve_food({"reserved": -1, "carried": 0, "delivered": 0}).ok)
	assert_false(R.reserve_food({"reserved": 9223372036854775807,
		"carried": 9223372036854775807, "delivered": 0}).ok)
	assert_false(R.reserve_food({}).ok)


func test_rest_single_spawns_respect_grace_noise_and_cap() -> void:
	var schedule: Dictionary = R.spawn_schedule()
	for elapsed: float in [0.0, 119.0, 120.0, 179.0]:
		var waiting: Dictionary = R.single_spawn(schedule, elapsed, 12, 0)
		assert_false(waiting.spawn, "유예와 기본 첫 입장 전에는 생성하지 않는다")
		schedule = waiting.schedule
	var count: int = 0
	for elapsed: float in [180.0, 240.0, 300.0, 360.0]:
		var due: Dictionary = R.single_spawn(schedule, elapsed, 12, count)
		assert_true(due.spawn)
		count += 1
		schedule = due.schedule
		assert_false(R.single_spawn(schedule, elapsed, 12, count).spawn, "같은 시간에는 한 번이다")
	assert_eq(count, 4)
	assert_false(R.single_spawn(schedule, 361.0, 13, 0).spawn)
	var loud: Dictionary = R.single_spawn(R.spawn_schedule(), 200.0, 13, 0)
	assert_true(loud.spawn, "지나간 기본 입장은 하나만 허용한다")
	loud = R.single_spawn(loud.schedule, 229.0, 13, 0)
	assert_false(loud.spawn)
	assert_true(R.single_spawn(loud.schedule, 230.0, 13, 0).spawn)
	var earlier: Dictionary = R.single_spawn(R.spawn_schedule(), 180.0, 12, 0)
	earlier = R.single_spawn(earlier.schedule, 200.0, 13, 1)
	assert_false(earlier.spawn)
	assert_eq(earlier.schedule.nextAt, 230.0, "문턱을 넘은 때부터 30초다")
	assert_true(R.single_spawn(earlier.schedule, 230.0, 13, 1).spawn)
	var during_grace: Dictionary = R.single_spawn(R.spawn_schedule(), 60.0, 13, 0)
	assert_eq(during_grace.schedule.nextAt, 150.0)
	assert_false(R.single_spawn(during_grace.schedule, 120.0, 13, 0).spawn)
	var capped: Dictionary = R.single_spawn(R.spawn_schedule(), 180.0, 12, 12)
	assert_false(capped.spawn)
	assert_false(R.single_spawn(capped.schedule, 181.0, 12, 0).spawn, "상한에서 놓친 입장은 버린다")
	var sparse: Dictionary = R.single_spawn(R.spawn_schedule(), 350.0, 12, 0)
	assert_true(sparse.spawn)
	assert_false(R.single_spawn(sparse.schedule, 351.0, 12, 0).spawn, "밀린 입장을 몰아 넣지 않는다")
	assert_eq(R.initial_extra(0), 0)
	assert_eq(R.initial_extra(1), 1)
	assert_eq(R.initial_extra(6), 6)
	assert_eq(R.initial_extra(30), 6)
	assert_eq(R.initial_extra(-1), 0)


func test_night_bonus_boundaries_and_ninety_percent_cap() -> void:
	assert_eq(R.night_bonus(12, 2, 2), 0)
	assert_eq(R.night_bonus(13, 2, 2), 10)
	assert_eq(R.night_bonus(12, 3, 0), 10)
	assert_eq(R.night_bonus(12, 0, 3), 10)
	assert_eq(R.night_bonus(13, 3, 3), 20, "양쪽을 더하지 않고 큰 쪽을 쓴다")
	assert_eq(R.night_probability(1, 13, 3, 3), 20, "첫 밤에도 추가값을 쓴다")
	var curve: Array[int] = [0, 30, 40, 60, 90, 90, 90]
	for index: int in range(curve.size()):
		assert_eq(R.night_probability(index + 1, 12, 2, 2), curve[index])
	assert_eq(R.night_probability(4, 13, 3, 3), 80)
	assert_eq(R.night_probability(5, 13, 3, 3), 90)
	assert_eq(R.night_probability(30, 13, 3, 3), 90)


func test_field_stage_receipt_applies_only_to_matching_turn_once() -> void:
	var receipt: Dictionary = _day_receipt()
	var before: Dictionary = receipt.duplicate(true)
	var applied: Array[String] = []
	assert_eq(R.check_receipt(receipt, 2, 3).size(), 0)
	assert_eq(R.check_receipt(JSON.parse_string(JSON.stringify(receipt)), 2, 3).size(), 0)
	var wrong: Dictionary = R.accept_receipt(receipt, 2, 4, applied)
	assert_false(wrong.ok)
	assert_eq(wrong.applied.size(), 0)
	assert_false(R.accept_receipt(receipt, 1, 3, applied).ok)
	assert_false(R.accept_receipt(receipt, -1, 3, applied).ok)
	var accepted: Dictionary = R.accept_receipt(receipt, 2, 3, applied)
	assert_true(accepted.ok)
	assert_eq(accepted.applied.size(), 1)
	assert_eq(applied.size(), 0, "사전 판정은 적용 목록을 직접 바꾸지 않는다")
	var duplicate: Dictionary = R.accept_receipt(receipt, 2, 3, accepted.applied)
	assert_false(duplicate.ok)
	assert_eq(duplicate.applied, accepted.applied)
	assert_eq(receipt, before)
	var night: Dictionary = _return_receipt()
	assert_true(R.accept_receipt(night, 2, 3, accepted.applied).ok, "판 종류도 중복 키에 포함한다")
	for row: Array in [["kind", "unknown"], ["stopSerial", -1], ["turnIndex", 1.5],
		["outcome", "invalid_context"], ["outcome", "cart_arrived"], ["peopleNoise", true],
		["trackWest", -1], ["trackEast", "2"], ["nightBonusPp", 10], ["foodDelivered", 3],
		["siteRemaining", {"food_site": -1}], ["outsidePeople", {}]]:
		var bad: Dictionary = receipt.duplicate(true)
		bad.placeState.fieldStage[row[0]] = row[1]
		assert_gt(R.check_receipt(bad).size(), 0, "잘못된 낮 필드를 거절한다: %s" % row[0])
	var missing: Dictionary = receipt.duplicate(true)
	missing.placeState.fieldStage.erase("trackEast")
	assert_gt(R.check_receipt(missing).size(), 0)
	assert_gt(R.check_receipt({}).size(), 0)
	assert_gt(R.check_receipt({"placeState": {"fieldStage": "invalid_context"}}).size(), 0)
	assert_eq(R.check_receipt(night).size(), 0)
	night.placeState.fieldStage.kind = "defend_return"
	assert_eq(R.check_receipt(night).size(), 0)
	for row: Array in [["coalDelivered", 0], ["coalDelivered", -1], ["ploughPartsPreview", 3],
		["trainDamage", {"door": -1}], ["trackAtFightEnd", {"west": 1, "east": 2, "representative": 1}],
		["trackAtFightEnd", {"west": -1, "east": 2, "representative": 2}],
		["trackAtFightEnd", {"west": 1, "east": 2, "direction": "unknown", "representative": 2}]]:
		var bad: Dictionary = night.duplicate(true)
		bad.placeState.fieldStage[row[0]] = row[1]
		assert_gt(R.check_receipt(bad).size(), 0, "잘못된 밤 필드를 거절한다: %s" % row[0])
	var failed: Dictionary = _return_receipt()
	var stage: Dictionary = failed.placeState.fieldStage
	stage.outcome = "return_failed"
	stage.coalDelivered = 0
	stage.coalUndelivered = 12
	stage.erase("trackAtFightEnd")
	stage.erase("ploughPartsPreview")
	assert_eq(R.check_receipt(failed).size(), 0)
	stage.coalUndelivered = -1
	assert_gt(R.check_receipt(failed).size(), 0)
	stage.coalUndelivered = 12
	stage.coalDelivered = 1
	assert_gt(R.check_receipt(failed).size(), 0)
	stage.coalDelivered = 0
	stage.trackAtFightEnd = R.capture_fight_end(0, 0)
	assert_gt(R.check_receipt(failed).size(), 0, "실패에는 빈 성공 고정값도 넣지 않는다")


func test_fight_end_snapshot_freezes_both_track_sides() -> void:
	var frozen: Dictionary = R.capture_fight_end(11, 31)
	assert_eq(frozen.west, 11)
	assert_eq(frozen.east, 31)
	assert_eq(frozen.representative, 31)
	var replay: Dictionary = R.capture_fight_end(0, 99, "east", frozen)
	assert_eq(replay, frozen, "이후 사망과 입장 수로 다시 세지 않는다")
	replay.west = 0
	assert_eq(frozen.west, 11, "다시 받은 사본이 원수를 바꾸지 않는다")
	assert_eq(R.track_representative(frozen, "west"), 11)
	assert_eq(R.track_representative(frozen, "east"), 31)
	assert_eq(R.capture_fight_end(-1, 3).size(), 0)
	assert_eq(R.capture_fight_end(1, 3, "unknown").size(), 0)


## 출발 소비는 뒤 연결의 일이다. 여기서는 고정 원수의 선택과 기존 표만 검사한다.
func test_plough_snapshot_boundaries_and_next_departure_consumption() -> void:
	for row: Array in [[0, 0], [1, 1], [10, 1], [11, 2], [30, 2], [31, 3], [1 << 31, 3]]:
		assert_eq(R.plough_parts_preview(row[0]), row[1])
	var frozen: Dictionary = R.capture_fight_end(10, 31)
	assert_eq(R.plough_parts_preview(R.track_representative(frozen)), 3)
	assert_eq(R.plough_parts_preview(R.track_representative(frozen, "west")), 1)
	assert_eq(R.plough_parts_preview(R.track_representative(frozen, "east")), 3)
	var directed: Dictionary = R.capture_fight_end(10, 31, "west")
	assert_eq(directed.representative, 10)
	assert_eq(R.track_representative(directed), 10)
	var receipt: Dictionary = _return_receipt()
	receipt.placeState.fieldStage.trackAtFightEnd = directed
	receipt.placeState.fieldStage.ploughPartsPreview = 1
	assert_eq(R.check_receipt(receipt).size(), 0)
