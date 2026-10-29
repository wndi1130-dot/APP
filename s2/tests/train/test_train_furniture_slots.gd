extends "res://addons/gut/test.gd"
## 다음 가구 덩이가 쓸 빈 바닥. 게임 쪽에서는 아직 읽거나 그리지 않는다.

const Catalog = preload("res://game/train/train_catalog.gd")
const Interior = preload("res://game/train/train_interior.gd")
const Places = preload("res://game/train/train_places.gd")
const TrainScene = preload("res://game/train/train_scene.gd")
const WALL_MARGIN: float = 0.1
const EPSILON: float = 0.000001
## 최소 0.8 x 0.5m도 기존 설비와 모든 활동 여유를 동시에 피할 수 없다
## (자리 중심이 놓일 수 있는 곳 전체를 구획으로 나눠 확인함, PR #990 4단계).
const NO_FLOOR_SPACE: Dictionary = {
	"dining": "긴 식탁·벤치와 배식·회의·추모 활동이 빈 바닥을 모두 사용",
	"technical": "작업대·확장 작업대·공구함과 작업·생활 활동이 빈 바닥을 모두 사용",
}


func test_furniture_slots_keep_all_layout_floor_constraints() -> void:
	var layouts: Dictionary = Catalog.data()["layouts"]
	assert_false(layouts.is_empty(), "검사할 배치가 있어야 함")
	for layout_key: String in layouts:
		var layout_row: Dictionary = layouts[layout_key]
		var layout_tag: String = "배치=%s" % layout_key
		var raw_slots: Variant = layout_row.get("furniture_slots", null)
		assert_true(raw_slots is Array, "%s 상대=furniture_slots 배열" % layout_tag)
		if not raw_slots is Array:
			continue
		var slot_rows: Array = raw_slots
		if bool(layout_row.get("storage_only", false)) or NO_FLOOR_SPACE.has(layout_key):
			assert_eq(slot_rows.size(), 0, "%s 상대=설비·전용 사용 배치의 빈 배열" % layout_tag)
		else:
			assert_between(slot_rows.size(), 2, 3, "%s 상대=자리 수 2~3" % layout_tag)
		if slot_rows.is_empty():
			continue
		var footprints: Array[Dictionary] = _all_prop_footprints(layout_row, layout_tag)
		var anchors: Array[Dictionary] = _all_activity_anchors(layout_key)
		var previous_slots: Array[Dictionary] = []
		for slot_index: int in range(slot_rows.size()):
			var slot_tag: String = "%s 자리=%d" % [layout_tag, slot_index + 1]
			if not _valid_slot(slot_rows[slot_index], slot_tag):
				continue
			var slot_row: Dictionary = slot_rows[slot_index]
			var slot_rect: Rect2 = _slot_rectangle(slot_row)
			var slot_polygon: PackedVector2Array = _rectangle_polygon(slot_rect)
			assert_true(_inside_floor().encloses(slot_rect), "%s 상대=벽 여유 0.1m" % slot_tag)
			assert_false(slot_rect.intersects(_door_aisle()), "%s 상대=문 사이 통로" % slot_tag)
			for footprint: Dictionary in footprints:
				var prop_polygon: PackedVector2Array = footprint["polygon"]
				assert_false(_polygons_overlap(slot_polygon, prop_polygon),
					"%s 상대=소품 %s" % [slot_tag, footprint["label"]])
			for anchor_row: Dictionary in anchors:
				var anchor_point: Vector2 = anchor_row["point"]
				var nearest: Vector2 = Vector2(
					clampf(anchor_point.x, slot_rect.position.x, slot_rect.end.x),
					clampf(anchor_point.y, slot_rect.position.y, slot_rect.end.y))
				assert_gte(anchor_point.distance_to(nearest) + EPSILON,
					float(Catalog.tuning("actor_clearance")),
					"%s 상대=활동 닻 %s (0.55m)" % [slot_tag, anchor_row["label"]])
			for previous: Dictionary in previous_slots:
				var previous_rect: Rect2 = previous["rect"]
				assert_false(slot_rect.intersects(previous_rect),
					"%s 상대=가구 자리 %d" % [slot_tag, previous["number"]])
			previous_slots.append({"rect": slot_rect, "number": slot_index + 1})


func _valid_slot(raw_slot: Variant, slot_tag: String) -> bool:
	assert_true(raw_slot is Dictionary, "%s 상대=자리 자료 형식" % slot_tag)
	if not raw_slot is Dictionary:
		return false
	var slot_row: Dictionary = raw_slot
	assert_eq(slot_row.size(), 4, "%s 상대=x,z,w,d 네 필드" % slot_tag)
	for field_key: String in ["x", "z", "w", "d"]:
		var field_value: Variant = slot_row.get(field_key, null)
		var numeric: bool = field_value is int or field_value is float
		assert_true(numeric, "%s 상대=숫자 필드 %s" % [slot_tag, field_key])
		if not numeric:
			return false
		assert_true(is_finite(float(field_value)), "%s 상대=유한한 %s" % [slot_tag, field_key])
		if not is_finite(float(field_value)):
			return false
	assert_between(float(slot_row["w"]), 0.8, 1.6, "%s 상대=폭 0.8~1.6m" % slot_tag)
	assert_between(float(slot_row["d"]), 0.5, 0.9, "%s 상대=깊이 0.5~0.9m" % slot_tag)
	return float(slot_row["w"]) > 0.0 and float(slot_row["d"]) > 0.0


func _slot_rectangle(slot_row: Dictionary) -> Rect2:
	var extent: Vector2 = Vector2(float(slot_row["w"]), float(slot_row["d"]))
	return Rect2(Vector2(float(slot_row["x"]), float(slot_row["z"])) - extent * 0.5, extent)


func _inside_floor() -> Rect2:
	var back_edge: float = TrainScene.CAR_SCREEN_BOUNDS.position.z + WALL_MARGIN
	return Rect2(Vector2(WALL_MARGIN, back_edge),
		Vector2(TrainScene.CAR_LENGTH - WALL_MARGIN * 2.0, TrainScene.FRONT_Z - WALL_MARGIN - back_edge))


func _door_aisle() -> Rect2:
	# train_life._route는 AISLE_Z를 따라 이동한다. 양 끝 문 전체 폭을 보존한다.
	assert_almost_eq(TrainScene.AISLE_Z, (TrainScene.DOOR_FROM + TrainScene.DOOR_TO) * 0.5,
		EPSILON, "통로 중심과 문 중심의 일치")
	return Rect2(Vector2(0.0, TrainScene.DOOR_FROM),
		Vector2(TrainScene.CAR_LENGTH, TrainScene.DOOR_TO - TrainScene.DOOR_FROM))


func _all_activity_anchors(layout_key: String) -> Array[Dictionary]:
	var places: Places = Places.new()
	places.add_car({"id": layout_key, "interior": layout_key}, 0.0)
	var result: Array[Dictionary] = []
	# 열림·정원·cycle로 거르지 않는다. 위 침상까지 바닥에 투영해 보수적으로 비운다.
	for spot_key: String in places.spots:
		var spot_row: Dictionary = places.spots[spot_key]
		var raw_anchors: Array = spot_row["anchors"]
		for anchor_index: int in range(raw_anchors.size()):
			var anchor_at: Vector3 = Catalog.vector(raw_anchors[anchor_index])
			anchor_at += Vector3(float(spot_row["x0"]), 0.0, 0.0)
			result.append({"point": Vector2(anchor_at.x, anchor_at.z),
				"label": "%s/%d" % [spot_key, anchor_index + 1]})
	return result


func _all_prop_footprints(layout_row: Dictionary, layout_tag: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# when와 cars를 걸러 내지 않아 과밀·추위·차량별 소품을 모두 합친다.
	for prop_row: Dictionary in layout_row["props"]:
		var prop_at: Vector3 = Catalog.vector(prop_row["at"])
		var reserved: Vector3 = Catalog.vector(prop_row["size"])
		var is_stove: bool = String(prop_row.get("system", "")) == "stove"
		var prop_yaw: float = 0.0 if is_stove else float(prop_row["yaw"])
		var prop_label: String = "%s [when=%s,cars=%s]" % [prop_row["id"],
			prop_row.get("when", "always"), JSON.stringify(prop_row.get("cars", []))]
		var tilts: Array[float] = [0.0]
		if bool(prop_row.get("trace", false)):
			tilts.append(float(Catalog.tuning("trace_tilt")))
		# 모델이 없는 경우의 상자도 검사한다. grow는 상자에 적용하지 않는다.
		var fallback_size: Vector3 = Vector3(0.4, 0.7, 0.4) if is_stove else reserved
		var fallback_box: AABB = AABB(-fallback_size * 0.5, fallback_size)
		for tilt: float in tilts:
			var fallback_pose: Transform3D = Transform3D(Basis.from_euler(Vector3(0.0, prop_yaw, tilt)), prop_at)
			_append_footprint(result, fallback_box, fallback_pose, "%s/box/tilt=%s" % [prop_label, tilt])
		var model_path: String = Interior.MODEL_ROOT + String(prop_row["model"]) + ".glb"
		if not ResourceLoader.exists(model_path):
			model_path = Interior.COMMON_ROOT + String(prop_row["model"]) + ".glb"
		if is_stove:
			model_path = TrainScene.STOVE_MODEL
		if String(prop_row["model"]).is_valid_identifier() and ResourceLoader.exists(model_path):
			var loaded_model: Resource = load(model_path)
			if loaded_model is PackedScene:
				var model_node: Node3D = (loaded_model as PackedScene).instantiate() as Node3D
				assert_not_null(model_node, "%s 상대=소품 %s 루트" % [layout_tag, prop_label])
				if model_node != null:
					model_node.position = prop_at
					if is_stove:
						model_node.position.y += 0.35
					else:
						# 실제 함수: k=min(max(grow,1), size.y/model_bounds.size.y).
						Interior._fit_to(model_node, prop_at, reserved, float(prop_row.get("grow", 1.0)))
						model_node.rotation.y = prop_yaw
					var model_box: AABB = Interior._bounds_of(model_node)
					assert_gt(model_box.size.y, 0.0, "%s 상대=소품 %s 모델 경계" % [layout_tag, prop_label])
					for tilt: float in tilts:
						if bool(prop_row.get("trace", false)):
							model_node.rotation.z = tilt
						_append_footprint(result, model_box, model_node.transform,
							"%s/model/tilt=%s" % [prop_label, tilt])
					model_node.free()
		if is_stove:
			var pipe_box: AABB = AABB(Vector3(-0.05, 0.0, -0.05), Vector3(0.1, 1.0, 0.1))
			_append_footprint(result, pipe_box, Transform3D(Basis.IDENTITY, prop_at + Vector3(0.0, 0.7, -0.1)),
				"%s/pipe" % prop_label)
	var fire_size: Vector3 = Catalog.vector(Catalog.tuning("fire_mark_size"))
	_append_footprint(result, AABB(-fire_size * 0.5, fire_size),
		Transform3D(Basis.IDENTITY, Catalog.vector(Catalog.tuning("fire_mark_at"))), "FirePlaceholder [fire]")
	return result


func _append_footprint(target: Array[Dictionary], bounds: AABB, pose: Transform3D, prop_label: String) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for corner_index: int in range(8):
		var corner: Vector3 = pose * bounds.get_endpoint(corner_index)
		points.append(Vector2(corner.x, corner.z))
	# 실제 경계를 돌린 뒤 바닥에 투영한다. 회전 전 size 네모로 대체하지 않는다.
	target.append({"polygon": Geometry2D.convex_hull(points), "label": prop_label})


func _rectangle_polygon(rectangle: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rectangle.position, Vector2(rectangle.end.x, rectangle.position.y),
		rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)])


func _polygons_overlap(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	# 분리축 검사: 닿기만 하는 경계는 겹침 면적이 없다.
	for polygon: PackedVector2Array in [first, second]:
		for edge_index: int in range(polygon.size()):
			var edge: Vector2 = polygon[(edge_index + 1) % polygon.size()] - polygon[edge_index]
			if edge.length_squared() <= EPSILON * EPSILON:
				continue
			var axis: Vector2 = Vector2(-edge.y, edge.x).normalized()
			var first_interval: Vector2 = _projection_interval(first, axis)
			var second_interval: Vector2 = _projection_interval(second, axis)
			if first_interval.y <= second_interval.x + EPSILON or second_interval.y <= first_interval.x + EPSILON:
				return false
	return true


func _projection_interval(polygon: PackedVector2Array, axis: Vector2) -> Vector2:
	var lower: float = INF
	var upper: float = -INF
	for vertex: Vector2 in polygon:
		var projection: float = vertex.dot(axis)
		lower = minf(lower, projection)
		upper = maxf(upper, projection)
	return Vector2(lower, upper)
