extends RefCounted
## 판 밖의 상태를 받아 새 값만 돌려주는 규칙이다. 장면과 재고를 직접 바꾸지 않는다.

const Holdout = preload("res://game/field_holdout.gd")

const REST_WORKERS: int = 4 # 결정된 인원이다.
const REST_DAY_SEC: float = 360.0 # 추정
const REST_RECALL_SEC: float = 300.0 # 추정
const REST_FOOD_CAP: int = 2 # 추정
const REST_THREAT_R: float = 6.0 # 추정
const REST_SPAWN_GRACE_SEC: float = 120.0 # 추정
const REST_SPAWN_GAP_SEC: float = 60.0 # 추정
const REST_LOUD_GAP_SEC: float = 30.0 # 추정
const REST_ACTIVE_CAP: int = 12 # 추정
const REST_INITIAL_CAP: int = 6 # 추정
const NIGHT_BONUS_PP: int = 10 # 추정
const NIGHT_CHANCE_CAP: int = 90 # 추정
const HANDCAR_SPEED: float = 0.65 # 추정, 적재 상태의 초당 이동 거리다.
const FOOD_PACKS_PER_FOOD: int = 2
const FOOD_BATCH_PACKS: int = 2
const NIGHT_CURVE: Array[int] = [0, 30, 40, 60, 90] # 추정
const KINDS: Array[String] = ["rest_day", "defend_return", "escort_return"]
const OUTCOMES: Array[String] = ["day_closed", "cart_arrived", "return_failed"]


## 모든 사람과 수색 경로의 묶음을 한 계정에 합쳐 호출한다. 납품 낱묶음도 남는다.
static func food_account() -> Dictionary:
	return {"reserved": 0, "carried": 0, "delivered": 0}


static func reserve_food(food: Dictionary, packs: int = FOOD_BATCH_PACKS) -> Dictionary:
	return _food_move(food, "", "reserved", packs, true)


static func cancel_food(food: Dictionary, packs: int = FOOD_BATCH_PACKS) -> Dictionary:
	return _food_move(food, "reserved", "", packs, true)


static func complete_food(food: Dictionary, packs: int = FOOD_BATCH_PACKS) -> Dictionary:
	return _food_move(food, "reserved", "carried", packs, true)


## foodDelta만 재고에 더한다. 홀수 묶음은 다음 납품과 짝이 될 때까지 유지한다.
static func deliver_food(food: Dictionary, packs: int) -> Dictionary:
	return _food_move(food, "carried", "delivered", packs, false)


static func food_delivered(packs: int) -> int:
	return floori(float(maxi(packs, 0)) / FOOD_PACKS_PER_FOOD)


static func _food_move(food: Dictionary, source: String, target: String,
		packs: int, paired: bool) -> Dictionary:
	var next: Dictionary = food.duplicate(true)
	var errors: Array[String] = []
	for key: String in ["reserved", "carried", "delivered"]:
		if _nonnegative_int(food, key, errors) and int(food[key]) > REST_FOOD_CAP * FOOD_PACKS_PER_FOOD:
			errors.append("식량 계정이 한도를 넘는다")
	if packs <= 0 or (paired and packs != FOOD_BATCH_PACKS):
		errors.append("묶음 수가 작업 단위와 맞지 않는다")
	if not errors.is_empty():
		return {"ok": false, "food": next, "foodDelta": 0, "errors": errors}
	var total: int = int(food.reserved) + int(food.carried) + int(food.delivered)
	if total > REST_FOOD_CAP * FOOD_PACKS_PER_FOOD:
		errors.append("식량 계정이 한도를 넘는다")
	elif not source.is_empty() and int(food[source]) < packs:
		errors.append("옮길 묶음이 부족하다")
	elif source.is_empty() and total + packs > REST_FOOD_CAP * FOOD_PACKS_PER_FOOD:
		errors.append("식량 예약이 한도를 넘는다")
	if not errors.is_empty():
		return {"ok": false, "food": next, "foodDelta": 0, "errors": errors}
	if not source.is_empty():
		next[source] = int(food[source]) - packs
	if not target.is_empty():
		next[target] = int(food[target]) + packs
	var gained: int = food_delivered(int(next.delivered)) - food_delivered(int(food.delivered))
	return {"ok": true, "food": next, "foodDelta": gained, "errors": errors}


## 이미 멈춰 지낸 낮의 수다. 첫 낮은 0을 받는다.
static func initial_extra(days_already_stopped: int) -> int:
	return clampi(days_already_stopped, 0, REST_INITIAL_CAP)


static func spawn_schedule() -> Dictionary:
	return {"nextAt": REST_SPAWN_GRACE_SEC + REST_SPAWN_GAP_SEC,
		"loud": false, "lastElapsed": -1.0}


## elapsed는 배속이 적용된 필드 시간이다. 멈춘 시계의 재호출은 입장을 만들지 않는다.
## 문턱을 처음 관측한 때부터 당긴다. 유예 중 전환이면 유예 뒤 짧은 간격부터다.
## 지나간 입장은 버린다. 상한에서 놓친 입장도 다음 프레임에 쌓아 두지 않는다.
static func single_spawn(schedule: Dictionary, elapsed: float,
		people_noise: int, active: int) -> Dictionary:
	var next: Dictionary = schedule.duplicate(true)
	var result: Dictionary = {"schedule": next, "spawn": false}
	if not is_finite(elapsed) or elapsed < 0.0 or active < 0 or people_noise < 0:
		return result
	if elapsed <= float(next.lastElapsed):
		return result
	next.lastElapsed = elapsed
	if not bool(next.loud) and people_noise > Holdout.QUIET_NOISE:
		next.loud = true
		next.nextAt = minf(float(next.nextAt), maxf(elapsed, REST_SPAWN_GRACE_SEC) + REST_LOUD_GAP_SEC)
	if elapsed > REST_DAY_SEC or elapsed < float(next.nextAt):
		return result
	var gap: float = REST_LOUD_GAP_SEC if bool(next.loud) else REST_SPAWN_GAP_SEC
	next.nextAt = elapsed + gap
	result.spawn = active < REST_ACTIVE_CAP
	return result


## 밤 순서는 1부터다. 다섯째 밤 뒤에도 마지막 확률을 쓴다.
static func base_night_chance(night_index: int) -> int:
	return NIGHT_CURVE[clampi(night_index, 1, NIGHT_CURVE.size()) - 1]


static func night_bonus(people_noise: int, west: int, east: int) -> int:
	var bonus: int = NIGHT_BONUS_PP if people_noise > Holdout.QUIET_NOISE else 0
	if maxi(west, east) > Holdout.CLEAR_TRACK:
		bonus += NIGHT_BONUS_PP
	return bonus


## 사람 소리만 받는다. 굴림 자체와 추가값 소비는 받는 제어기가 한 번 처리한다.
static func night_probability(night_index: int, people_noise: int, west: int, east: int) -> int:
	return clampi(base_night_chance(night_index) + night_bonus(people_noise, west, east),
		0, NIGHT_CHANCE_CAP)


## 기존 고정값을 넘기면 다시 세지 않는다. 반환값도 별도 사본이다.
static func capture_fight_end(west: int, east: int, direction: String = "",
		existing: Dictionary = {}) -> Dictionary:
	if not existing.is_empty():
		return existing.duplicate(true)
	if west < 0 or east < 0 or direction not in ["", "west", "east"]:
		return {}
	var snapshot: Dictionary = {"west": west, "east": east, "direction": direction}
	snapshot.representative = track_representative(snapshot)
	return snapshot


## 나중에 방향이 정해져도 고정한 양쪽 수 중에서만 고른다.
static func track_representative(snapshot: Dictionary, direction: String = "") -> int:
	var chosen: String = direction if not direction.is_empty() else String(snapshot.get("direction", ""))
	if chosen in ["west", "east"]:
		return int(snapshot[chosen])
	return maxi(int(snapshot.west), int(snapshot.east))


static func plough_parts_preview(dead: int) -> int:
	for step: Array in Holdout.PLOUGH_STEPS:
		if maxi(dead, 0) <= int(step[0]):
			return int(step[1])
	# 표의 마지막 큰 무리 구간은 그 위의 수도 포함한다.
	return int(Holdout.PLOUGH_STEPS.back()[1])


static func receipt_key(stage: Dictionary) -> String:
	return "%s:%d:%d" % [stage.kind, int(stage.stopSerial), int(stage.turnIndex)]


static func check_receipt(receipt: Variant, expected_stop: int = -1,
		expected_turn: int = -1) -> Array[String]:
	if not receipt is Dictionary or not receipt.get("placeState") is Dictionary:
		return ["placeState가 없다"]
	return check_field_stage(receipt.placeState.get("fieldStage"), expected_stop, expected_turn)


## 정수로 읽히는 유한 실수도 허용한다. 기존 영수증의 JSON 읽기 관례와 같다.
static func check_field_stage(stage: Variant, expected_stop: int = -1,
		expected_turn: int = -1) -> Array[String]:
	var errors: Array[String] = []
	if not stage is Dictionary:
		return ["fieldStage는 사전이어야 한다"]
	if stage.get("kind") not in KINDS:
		errors.append("판 종류가 잘못되었다")
	if stage.get("outcome") not in OUTCOMES:
		errors.append("종료 값이 잘못되었다: invalid_context는 영수증이 아니다")
	var stop_ok: bool = _nonnegative_int(stage, "stopSerial", errors)
	var turn_ok: bool = _nonnegative_int(stage, "turnIndex", errors)
	if stop_ok and expected_stop >= 0 and int(stage.stopSerial) != expected_stop:
		errors.append("멈춤 순번이 맞지 않는다")
	if turn_ok and expected_turn >= 0 and int(stage.turnIndex) != expected_turn:
		errors.append("턴이 맞지 않는다")
	if stage.get("kind") == "rest_day":
		if stage.get("outcome") != "day_closed":
			errors.append("낮의 종료 값이 맞지 않는다")
		_check_day(stage, errors)
	elif stage.get("kind") in ["defend_return", "escort_return"]:
		if stage.get("outcome") not in ["cart_arrived", "return_failed"]:
			errors.append("밤의 종료 값이 맞지 않는다")
		_check_return(stage, errors)
	return errors


## 원자적 적용을 위한 사전 판정이다. ok 뒤 실제 정산이 성공해야 applied를 보관한다.
## 입력 영수증과 기존 적용 목록은 바꾸지 않는다. 재고와 상처 정산은 여기서 하지 않는다.
## failed는 귀환에 실패한 밤의 목록이다(결정 334). 그 밤의 귀환 영수증은 더 받지 않고,
## 이번 영수증이 귀환 실패면 돌려주는 failed에 그 밤을 더한다.
static func accept_receipt(receipt: Variant, expected_stop: int, expected_turn: int,
		applied: Array[String], failed: Array[String] = []) -> Dictionary:
	var errors: Array[String] = check_receipt(receipt, expected_stop, expected_turn)
	var keys: Array[String] = applied.duplicate()
	var nights: Array[String] = failed.duplicate()
	var key: String = ""
	if expected_stop < 0 or expected_turn < 0:
		errors.append("적용할 멈춤 순번과 턴이 필요하다")
	if errors.is_empty():
		var stage: Dictionary = receipt.placeState.fieldStage
		key = receipt_key(stage)
		if key in keys:
			errors.append("이미 적용한 영수증이다")
		elif not can_depart(String(stage.kind), int(stage.stopSerial), int(stage.turnIndex), failed).ok:
			errors.append("귀환에 실패한 밤에는 다시 시도하지 않는다")
		else:
			keys.append(key)
			if stage.outcome == "return_failed":
				nights.append(night_key(int(stage.stopSerial), int(stage.turnIndex)))
	return {"ok": errors.is_empty(), "errors": errors, "key": key, "applied": keys, "failed": nights}


## 결정 334: 직접 귀환에 실패하면 같은 밤에 다시 시도하지 않는다. 실패는 원정 실패와 같은
## 흐름 하나로 다음 정산에서 다룬다. 판 종류(엄호·호송)를 바꿔도 같은 멈춤·턴이면 같은 밤이다.
static func night_key(stop_serial: int, turn_index: int) -> String:
	return "%d:%d" % [stop_serial, turn_index]


## 귀환 판을 이 밤에 열 수 있는지 본다. 낮 판은 막지 않는다. failed는 바꾸지 않는다.
static func can_depart(kind: String, stop_serial: int, turn_index: int,
		failed: Array[String]) -> Dictionary:
	var errors: Array[String] = []
	if kind in ["defend_return", "escort_return"] and night_key(stop_serial, turn_index) in failed:
		errors.append("귀환에 실패한 밤에는 다시 시도하지 않는다")
	return {"ok": errors.is_empty(), "errors": errors}


static func _check_day(stage: Dictionary, errors: Array[String]) -> void:
	var counts_ok: bool = true
	for key: String in ["peopleNoise", "trackWest", "trackEast", "nightBonusPp", "foodDelivered"]:
		if not _nonnegative_int(stage, key, errors):
			counts_ok = false
	if counts_ok:
		if int(stage.foodDelivered) > REST_FOOD_CAP:
			errors.append("식량 납품이 낮 한도를 넘는다")
		if int(stage.nightBonusPp) != night_bonus(int(stage.peopleNoise), int(stage.trackWest), int(stage.trackEast)):
			errors.append("밤 추가값이 마감 수와 맞지 않는다")
	_check_count_map(stage.get("siteRemaining"), "siteRemaining", errors)
	if not stage.get("outsidePeople") is Array:
		errors.append("outsidePeople은 목록이어야 한다")


static func _check_return(stage: Dictionary, errors: Array[String]) -> void:
	var coal_ok: bool = _nonnegative_int(stage, "coalDelivered", errors)
	_check_count_map(stage.get("trainDamage"), "trainDamage", errors)
	if stage.get("outcome") == "return_failed":
		_nonnegative_int(stage, "coalUndelivered", errors)
		if coal_ok and int(stage.coalDelivered) != 0:
			errors.append("귀환 실패에는 석탄을 지급하지 않는다")
		if stage.has("trackAtFightEnd") or stage.has("ploughPartsPreview"):
			errors.append("귀환 실패에는 성공 도착의 고정값을 넣지 않는다")
		return
	if coal_ok and int(stage.coalDelivered) <= 0:
		errors.append("도착 성공에는 석탄 적재가 필요하다")
	var parts_ok: bool = _nonnegative_int(stage, "ploughPartsPreview", errors)
	var snapshot: Variant = stage.get("trackAtFightEnd")
	if not snapshot is Dictionary:
		errors.append("trackAtFightEnd는 사전이어야 한다")
		return
	var west_ok: bool = _nonnegative_int(snapshot, "west", errors)
	var east_ok: bool = _nonnegative_int(snapshot, "east", errors)
	var representative_ok: bool = _nonnegative_int(snapshot, "representative", errors)
	if snapshot.get("direction", "") not in ["", "west", "east"]:
		errors.append("선로 방향이 잘못되었다")
	elif west_ok and east_ok and representative_ok:
		var representative: int = track_representative(snapshot)
		if int(snapshot.representative) != representative:
			errors.append("선로 대표 수가 양쪽 수와 맞지 않는다")
		if parts_ok and int(stage.ploughPartsPreview) != plough_parts_preview(representative):
			errors.append("쟁기 미리보기가 고정 수와 맞지 않는다")


static func _check_count_map(value: Variant, name: String, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("%s는 사전이어야 한다" % name)
		return
	for key: Variant in value:
		if not key is String or String(key).is_empty() or not _is_nonnegative_integer(value[key]):
			errors.append("%s의 식별값과 수가 잘못되었다" % name)


static func _nonnegative_int(data: Dictionary, key: String, errors: Array[String]) -> bool:
	if not _is_nonnegative_integer(data.get(key)):
		errors.append("%s는 비음수 정수여야 한다" % key)
		return false
	return true


static func _is_nonnegative_integer(value: Variant) -> bool:
	if value is int:
		return value >= 0
	if value is float:
		# 변환 범위 밖의 실수와 무한대는 정수로 취급하지 않는다.
		return is_finite(value) and value >= 0.0 and value < 9223372036854775808.0 and value == floor(value)
	return false
