extends RefCounted
## 지도 반환 자료 밖의 표시 전용 표. 지도 스크립트는 이 파일을 읽지 않는다.

const Story01 = preload("res://game/world/maps/story_01.gd")
const LOOKS: Dictionary = {
	Story01.PLACE_ID: {
		"turntable": {
			"center": Vector2(Story01.TURNTABLE_CENTER) + Vector2(0.5, 0.5),
			"radius": Story01.TURNTABLE_RADIUS,
			"outer_radius": 8.55, "inner_radius": 7.3, "wall_z": 71.0,
			"bridge_axis": Vector2(0, 1), "bridge_width": 2.4,
			"fan_angles": [-55.0, -30.0, 30.0, 55.0],
		},
		"rail_skip": [Rect2(32, 62, 17, 1)],
		"prop_skip": [
			{"kind": "mine_track", "rect": Rect2i(36, 68, 1, 2)},
			{"kind": "mine_track", "rect": Rect2i(35, 69, 2, 1)},
			{"kind": "mine_track", "rect": Rect2i(35, 69, 1, 3)},
			{"kind": "mine_track", "rect": Rect2i(44, 68, 1, 2)},
			{"kind": "mine_track", "rect": Rect2i(44, 69, 2, 1)},
			{"kind": "mine_track", "rect": Rect2i(45, 69, 1, 3)},
		],
	},
}


static func for_place(place_id: String) -> Dictionary:
	var look: Dictionary = LOOKS.get(place_id, {})
	return look.duplicate(true)


static func skips_prop(look: Dictionary, prop: Dictionary) -> bool:
	if int(prop.get("level", 0)) != 0:
		return false
	for omitted: Dictionary in look.get("prop_skip", []):
		if prop.get("kind") == omitted["kind"] and prop.get("rect") == omitted["rect"]:
			return true
	return false
