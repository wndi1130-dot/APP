extends RefCounted
## The bare line with a small sewer: two lids that can be shut and a drain
## that cannot. What a town map's holes look like to the field.

const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")

const PLACE_ID: String = "houses_98"


static func build() -> Dictionary:
	var d: Dictionary = BareLine.build()
	d["place_kind"] = "houses"
	d["manholes"] = {"manhole_01": Vector2i(10, 22), "manhole_02": Vector2i(48, 22), "drain": Vector2i(30, 8)}
	d["sewer_names"] = {"manhole_01": "서쪽 맨홀", "manhole_02": "동쪽 맨홀", "drain": "배수구"}
	for key: String in d["manholes"]:
		d["entries"][key] = [d["manholes"][key]]
		d["entry_gap"][key] = 3.0
	return d
