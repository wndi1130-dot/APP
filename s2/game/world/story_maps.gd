extends RefCounted
## Hand-made story maps: their borrowed kind and the stop whose band they keep.

const BASE := {"story_01": "freight", "story_02": "freight", "story_03": "office"}
const STOP := {"story_02": ["act1", 10], "story_03": ["act2", 1]}


static func is_story(id: String) -> bool:
	return BASE.has(id)


static func base_of(id: String) -> String:
	return String(BASE.get(id, ""))


static func stop_of(id: String) -> Array:
	return STOP.get(id, [])
