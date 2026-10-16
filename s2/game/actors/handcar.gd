extends RefCounted
## 선로와 사람 상태만 받는 수동차다. 장면, 전투, 석탄 납품은 제어기가 맡는다.

const Rules = preload("res://game/sim/field_stage_rules.gd")
const PUSH_DISTANCE: float = 2.0 # 추정
const DOCK_RADIUS: float = 3.0 # 추정, 중심에서 잰 도착 영역이다.
const STOPPED: String = "stopped"
const MOVING: String = "moving"
const ARRIVED: String = "arrived"

var state: String = STOPPED
var position: Vector3 = Vector3.ZERO
var coal: int = 0
var route: Array[Vector3] = []
var dock: Vector3 = Vector3.ZERO
var riders: Array[Dictionary] = []
var pushers: Array[Dictionary] = []
var blocker: Callable = Callable()
var _next_point: int = 1


func _init(points: Array[Vector3] = [], dock_center: Vector3 = Vector3.ZERO,
		return_coal: int = 0) -> void:
	route.assign(points)
	dock = dock_center
	coal = return_coal
	if not route.is_empty():
		position = route[0]


## 사람은 id·capable·position을 가진 사전이다. 이후 몸 상태 변경을 같은 사전에서 읽는다.
func board(person: Dictionary) -> bool:
	if not person.get("id") is String or String(person.id).is_empty():
		return false
	for rider: Dictionary in riders:
		if rider.id == person.id:
			return false
	riders.append(person)
	return true


func unboard(person_id: String) -> bool:
	for index: int in range(riders.size()):
		if riders[index].id == person_id:
			riders.remove_at(index)
			_stop_if_unpowered()
			return true
	return false


func set_pushers(people: Array[Dictionary]) -> void:
	pushers.assign(people)
	_stop_if_unpowered()


## from·to 사이에 망자가 닿는지를 외부에서 판정한다. 한 이동 전체를 검사해야 한다.
func set_blocker(check: Callable) -> void:
	blocker = check


func advance(delta: float) -> void:
	if state == ARRIVED:
		return
	if route.size() < 2 or not position.is_finite() or not dock.is_finite():
		state = STOPPED
		return
	if dock_reached():
		state = ARRIVED
		return
	if not _has_power() or not is_finite(delta) or delta <= 0.0:
		state = STOPPED
		return
	var remaining: float = Rules.HANDCAR_SPEED * delta
	state = MOVING
	while remaining > 0.0 and _next_point < route.size():
		var target: Vector3 = route[_next_point]
		if not target.is_finite():
			state = STOPPED
			return
		var distance: float = position.distance_to(target)
		if distance <= 0.000001:
			_next_point += 1
			continue
		var step: float = minf(remaining, distance)
		var candidate: Vector3 = position.move_toward(target, step)
		candidate = _dock_entry(position, candidate)
		if blocker.is_valid() and bool(blocker.call(position, candidate)):
			state = STOPPED
			return
		position = candidate
		remaining -= step
		if dock_reached():
			state = ARRIVED
			return
		if step >= distance:
			_next_point += 1
	if _next_point >= route.size():
		state = STOPPED


## 중심의 도착과 적재만 본다. 납품하지 않고 도착 뒤에도 석탄을 차에 보관한다.
func dock_reached() -> bool:
	return route.size() >= 2 and coal > 0 and position.is_finite() and dock.is_finite() \
		and position.distance_to(dock) <= DOCK_RADIUS


func _has_power() -> bool:
	for rider: Dictionary in riders:
		if rider.get("capable") is bool and bool(rider.capable):
			return true
	for pusher: Dictionary in pushers:
		var at: Variant = pusher.get("position")
		if pusher.get("capable") is bool and bool(pusher.capable) and at is Vector3 \
				and at.is_finite() and position.distance_to(at) <= PUSH_DISTANCE:
			return true
	return false


func _stop_if_unpowered() -> void:
	if state != ARRIVED and not _has_power():
		state = STOPPED


## 큰 시간 증가에도 도착 영역을 건너뛰지 않는다. 선분이 영역에 처음 드는 곳까지 간다.
func _dock_entry(from: Vector3, to: Vector3) -> Vector3:
	if coal <= 0:
		return to
	var movement: Vector3 = to - from
	var length_squared: float = movement.length_squared()
	if length_squared <= 0.0:
		return to
	var offset: Vector3 = from - dock
	var b: float = 2.0 * offset.dot(movement)
	var c: float = offset.length_squared() - DOCK_RADIUS * DOCK_RADIUS
	var discriminant: float = b * b - 4.0 * length_squared * c
	if discriminant < 0.0:
		return to
	var entry: float = (-b - sqrt(discriminant)) / (2.0 * length_squared)
	if entry < 0.0 or entry > 1.0:
		return to
	# 경계의 반올림으로 도착을 놓치지 않도록 영역 안으로 아주 조금 들어간다.
	return from.lerp(to, minf(entry + 0.000001, 1.0))
