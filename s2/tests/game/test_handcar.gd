extends "res://addons/gut/test.gd"

const Cart = preload("res://game/actors/handcar.gd")
const Rules = preload("res://game/sim/field_stage_rules.gd")


## 기존 순수 계산 시험처럼 참조 계수 객체를 지역 변수로 만들고 범위 끝에서 해제한다.
func _cart(coal: int = 12, dock: Vector3 = Vector3(30.0, 0.0, 0.0)):
	var points: Array[Vector3] = [Vector3.ZERO, Vector3(10.0, 0.0, 0.0), Vector3(30.0, 0.0, 0.0)]
	return Cart.new(points, dock, coal)


func _person(id: String, position: Vector3, capable: bool = true) -> Dictionary:
	return {"id": id, "position": position, "capable": capable}


func test_handcar_requires_capable_rider_or_near_pusher() -> void:
	var cart = _cart()
	assert_eq(cart.state, Cart.STOPPED)
	cart.advance(10.0)
	assert_eq(cart.position, Vector3.ZERO, "무인 자동 귀환은 없다")
	var rider: Dictionary = _person("rider", Vector3.ZERO)
	assert_true(cart.board(rider))
	assert_false(cart.board(rider), "같은 탑승자를 두 번 넣지 않는다")
	assert_false(cart.board({}))
	cart.advance(1.0)
	assert_eq(cart.state, Cart.MOVING)
	assert_almost_eq(cart.position.x, Rules.HANDCAR_SPEED, 0.00001)
	rider.capable = false
	var stopped_at: Vector3 = cart.position
	cart.advance(1.0)
	assert_eq(cart.state, Cart.STOPPED)
	assert_eq(cart.position, stopped_at, "행동 불능을 즉시 읽는다")
	rider.capable = true
	cart.advance(1.0)
	assert_eq(cart.state, Cart.MOVING)
	assert_true(cart.unboard("rider"))
	assert_eq(cart.state, Cart.STOPPED)
	assert_false(cart.unboard("rider"))
	var pusher: Dictionary = _person("pusher", cart.position + Vector3(2.01, 0.0, 0.0))
	cart.set_pushers([pusher])
	stopped_at = cart.position
	cart.advance(1.0)
	assert_eq(cart.position, stopped_at, "멀리 있는 밀기 인원은 힘을 주지 못한다")
	pusher.position = cart.position + Vector3(Cart.PUSH_DISTANCE, 0.0, 0.0)
	cart.advance(1.0)
	assert_eq(cart.state, Cart.MOVING)
	assert_almost_eq(cart.position.x - stopped_at.x, Rules.HANDCAR_SPEED, 0.00001)
	pusher.position = cart.position
	pusher.capable = false
	stopped_at = cart.position
	cart.advance(1.0)
	assert_eq(cart.position, stopped_at)
	cart.set_pushers([])
	assert_eq(cart.state, Cart.STOPPED)
	assert_eq(cart.coal, 12, "적재는 사람 소지품으로 옮기지 않는다")


func test_handcar_stops_at_zombies_without_auto_kill() -> void:
	var cart = _cart()
	cart.board(_person("rider", Vector3.ZERO))
	var obstruction: Dictionary = {"position": Vector3(12.0, 0.0, 0.0), "active": true}
	cart.set_blocker(func(from: Vector3, to: Vector3) -> bool:
		return bool(obstruction.active) and from.x <= obstruction.position.x and to.x >= obstruction.position.x)
	cart.advance(100.0)
	assert_eq(cart.state, Cart.STOPPED)
	assert_almost_eq(cart.position.x, 10.0, 0.00001, "경로 조각을 건너뛰어 관통하지 않는다")
	assert_true(obstruction.active, "수동차가 망자를 처치하지 않는다")
	assert_eq(obstruction.position, Vector3(12.0, 0.0, 0.0), "수동차가 망자를 밀지 않는다")
	var stopped_at: Vector3 = cart.position
	cart.advance(10.0)
	assert_eq(cart.position, stopped_at)
	obstruction.active = false
	cart.advance(1.0)
	assert_eq(cart.state, Cart.MOVING, "밖에서 길을 열면 다시 간다")
	assert_almost_eq(cart.position.x - stopped_at.x, Rules.HANDCAR_SPEED, 0.00001)
	assert_eq(cart.coal, 12)


## 석탄 납품과 판 종료 한 번 처리는 뒤 제어기와 영수증 적용 시험으로 잇는다.
func test_escort_return_requires_loaded_cart_at_dock() -> void:
	var loaded = _cart()
	var rider: Dictionary = _person("rider", loaded.dock)
	loaded.board(rider)
	assert_false(loaded.dock_reached(), "열차장만 먼저 닿아서는 끝나지 않는다")
	loaded.advance(100.0)
	assert_true(loaded.dock_reached())
	assert_eq(loaded.state, Cart.ARRIVED)
	assert_eq(loaded.coal, 12, "실제 납품 전까지 석탄을 따로 보관한다")
	var arrived_at: Vector3 = loaded.position
	loaded.advance(100.0)
	assert_eq(loaded.position, arrived_at, "도착은 상태로 고정된다")
	assert_eq(loaded.coal, 12)
	var empty = _cart(0)
	empty.board(_person("rider", Vector3.ZERO))
	empty.advance(100.0)
	assert_false(empty.dock_reached(), "빈 수동차는 도착 성공이 아니다")
	assert_eq(empty.state, Cart.STOPPED)
	assert_eq(empty.position, empty.route.back())
	var boundary = _cart()
	boundary.position = boundary.dock + Vector3(Cart.DOCK_RADIUS, 0.0, 0.0)
	assert_true(boundary.dock_reached())
	boundary.position += Vector3(0.001, 0.0, 0.0)
	assert_false(boundary.dock_reached())
	var crossing = _cart(12, Vector3(5.0, 0.0, 0.0))
	crossing.board(_person("rider", Vector3.ZERO))
	crossing.advance(100.0)
	assert_true(crossing.dock_reached(), "큰 시간 증가에도 도착 영역을 지나치지 않는다")
	assert_eq(crossing.state, Cart.ARRIVED)
	var no_route = Cart.new()
	assert_false(no_route.dock_reached(), "빠진 경로는 도착 성공으로 바꾸지 않는다")
