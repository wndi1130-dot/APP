extends "res://addons/gut/test.gd"
## Decision 474 N2: S1 answers, including UTF-16 seeds and all 24 stretches.

const RouteWeather = preload("res://game/train/route_weather.gd")
const TrainClimate = preload("res://game/train/train_climate.gd")
const SeasonTable = preload("res://game/season_table.gd")
const PATH: String = "res://tests/fixtures/train/route_weather.json"

var _data: Dictionary = {}


func before_all() -> void:
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed


func test_fixture_is_the_s1_route_weather_table() -> void:
	assert_eq(_data.get("format", ""), "route-weather-v1")
	assert_eq(int(_data.get("stay", -1)), RouteWeather.STAY)
	assert_eq((_data.get("routes", []) as Array).size(), 5)


func test_route_and_both_climate_readers_match_s1() -> void:
	assert_false(_data.is_empty(), "generate tools/route_weather_fixtures.ts first")
	if _data.is_empty():
		return
	var tables: Dictionary = _data["tables"]
	for route: Dictionary in _data["routes"]:
		var seed: String = String(route["seed"])
		assert_eq((route["weather"] as Array).size(), 24)
		for seg: int in range(24, 0, -1):
			var want: String = String(route["weather"][seg - 1])
			var label: String = "%s/%d" % [seed, seg]
			assert_eq(RouteWeather.weather(seed, seg), want, label + " direct")
			var g: Dictionary = {"seed": seed, "seg": seg, "climate": true}
			assert_eq(TrainClimate.weather(g, tables), want, label + " train")
			var view: Dictionary = SeasonTable.pick_weather("prologue", float(seg - 1) / 23.0, seed)
			assert_eq(view["weather"], want, label + " scene")
			g["climate"] = false
			assert_null(TrainClimate.weather(g, tables), label + " climate off")
