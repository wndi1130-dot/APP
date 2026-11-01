extends RefCounted
## An existing freight map under a story name, before the story's own script exists.

const Freight = preload("res://game/world/maps/freight_01.gd")
const PLACE_ID: String = "story_02"


static func build() -> Dictionary:
	var data: Dictionary = Freight.build()
	data["place_id"] = PLACE_ID
	return data
