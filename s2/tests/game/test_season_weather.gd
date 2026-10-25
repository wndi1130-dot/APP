extends "res://addons/gut/test.gd"
## A plain stop's weather from the season table (코디네이터 10-25, 결정 423):
## the season's weights, what falls by the midday temperature, the same draw
## as S1 (omens.ts pickWeather on a game with the outside temperature on), and
## the picture's rain/snow edges the same as the table's.

const SeasonTable = preload("res://game/season_table.gd")
const Atmosphere = preload("res://fx/atmosphere.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const StopCinema = preload("res://game/stop_cinema.gd")
const FieldGame = preload("res://game/field_game.gd")
const OutsideTemp = preload("res://game/sim/outside_temp.gd")

## S1's own draws (tools run on s1, seed and stretch -> pickWeather, 10-25).
const S1_DRAWS: Dictionary = {
	"1": {1: "snow", 2: "fog", 5: "overcast", 16: "sleet", 18: "overcast", 22: "overcast"},
	"2": {1: "snow", 2: "overcast", 5: "overcast", 16: "fog", 18: "overcast", 22: "clear"},
	"3": {1: "snow", 2: "fog", 5: "overcast", 16: "fog", 18: "fog", 22: "snow"},
	"7": {1: "snow", 2: "fog", 5: "fog", 16: "sleet", 18: "overcast", 22: "fog"},
	"42": {1: "fog", 2: "overcast", 5: "clear", 16: "sleet", 18: "sleet", 22: "overcast"},
	"slice": {1: "snow", 2: "overcast", 5: "fog", 16: "overcast", 18: "clear", 22: "fog"},
}


func test_the_same_draw_as_s1() -> void:
	for s in S1_DRAWS:
		for seg in S1_DRAWS[s]:
			var p := SeasonTable.pick_weather("prologue", SeasonTable.seg_progress(seg), String(s))
			assert_eq(p["weather"], S1_DRAWS[s][seg], "%s / %d" % [s, seg])


func test_the_hash_is_s1s() -> void:
	# omens.ts hash("") and hash("a") (FNV-1a 32 bit)
	assert_eq(SeasonTable.hash32(""), 2166136261)
	assert_eq(SeasonTable.hash32("a"), 3826002220)


func test_what_falls_follows_the_temperature() -> void:
	var f := SeasonTable.falls()
	for i in 300:
		for seg in range(1, SeasonTable.segments() + 1):
			var p := SeasonTable.pick_weather("prologue", SeasonTable.seg_progress(seg), "fall-%d" % i)
			var t := float(SeasonTable.row(seg)["temp"])
			assert_true(["snow", "fog", "sleet", "overcast", "clear"].has(p["weather"]), "a plain stop never draws a blizzard")
			if t <= float(f["snow_below"]):
				assert_ne(p["weather"], "sleet", "no sleet or rain at %d C" % int(t))
			else:
				assert_ne(p["weather"], "snow", "no snow at %d C" % int(t))
			if p["weather"] == "sleet":
				assert_eq(p["falls"], "rain" if t > float(f["rain_above"]) else "sleet")


func test_the_shares_are_the_seasons() -> void:
	var count := {}
	var n := 0
	for i in 400:
		for seg in [3, 6, 9, 12]:
			var p := SeasonTable.pick_weather("prologue", SeasonTable.seg_progress(seg), "share-%d" % i)
			count[p["weather"]] = int(count.get(p["weather"], 0)) + 1
			n += 1
	# late autumn: overcast 30, fog 25, clear 15, what falls (snow 5 + sleet 25) 30
	assert_almost_eq(float(count.get("overcast", 0)) / n, 0.30, 0.05)
	assert_almost_eq(float(count.get("fog", 0)) / n, 0.25, 0.05)
	assert_almost_eq(float(count.get("sleet", 0)) / n, 0.30, 0.05)
	assert_eq(int(count.get("snow", 0)), 0, "late autumn above +1 C: rain, not snow")


func test_the_acts_draw_their_seasons() -> void:
	var seen := {}
	for i in 300:
		var p := SeasonTable.pick_weather("act2", 0.5, "act-%d" % i)
		seen[p["weather"]] = true
		assert_ne(p["weather"], "sleet", "deep winter at -20 C: no sleet")
	assert_true(seen.has("snow"))


func test_the_picture_edges_are_the_tables() -> void:
	var f := SeasonTable.falls()
	assert_eq(Atmosphere.RAIN_ABOVE, float(f["rain_above"]))
	assert_eq(Atmosphere.SNOW_BELOW, float(f["snow_below"]))


## 코디네이터 10-25: the stop scene, the field and the train wear the same
## weather, and the field's air is the stretch's temperature (it was -14 C).
func test_the_slice_stop_wears_one_weather_on_the_train_the_scene_and_the_field() -> void:
	var f = SliceFlow.new()
	# Seed 12 draws sleet for the stop (stretch 2, -1 C).
	f.opts = {"skip_field": true, "seed": 12, "cinema": false}
	add_child_autofree(f)
	f.next()
	assert_eq(f.current(), "stop_pick")
	var w: Dictionary = f.stop_weather(2)
	assert_eq(String(w["weather"]), "sleet")
	var o: Dictionary = f._field_opts()
	assert_eq(o["look"], w["look"], "the field and the scene get the table's weather")
	assert_eq(o["weather"], w["rules"])
	assert_eq(String(f.outside_look({}, 2)["falls"]), "sleet", "the train outside at the stop")
	var scene: Dictionary = StopCinema.stop_look(o)
	var field = FieldGame.new()
	var fo: Dictionary = o.duplicate()
	fo.merge({"raiders": false, "auto_pause": false}, true)
	field.opts = fo
	add_child_autofree(field)
	field.set_process(false)
	assert_eq(field.look_kinds, w["look"])
	assert_eq(field.weather.kinds, ["sleet"] as Array[String], "the rules fall as the picture does")
	assert_almost_eq(field.weather.ambient_c, float(SeasonTable.row(2)["temp"]), 0.001, "the field's air is the stretch's")
	assert_almost_eq(OutsideTemp.of(o, field.cold, field.side), field.weather.ambient_c, 0.001, "the scene's air is the same")
	assert_eq(String(field.atmo["falls"]), String(scene["look"]["falls"]), "the scene and the field: what falls")


func test_a_rainy_stretch_rains_in_the_rules() -> void:
	# Stretch 4 of seed 2: sleet drawn at +6 C falls as rain.
	var p := SeasonTable.pick_weather("prologue", SeasonTable.seg_progress(4), "2")
	assert_eq(String(p["falls"]), "rain")
	assert_eq(p["rules"], ["rain"])
	var field = FieldGame.new()
	field.opts = {"seed": 2, "raiders": false, "auto_pause": false, "act": "prologue", "act_progress": SeasonTable.seg_progress(4), "weather": p["rules"], "look": p["look"]}
	add_child_autofree(field)
	field.set_process(false)
	assert_eq(field.weather.kinds, ["rain"] as Array[String])
	assert_true(field.weather.wets_clothes(), "the clothing rules read this (wet)")
	assert_false(field.weather.ice_everywhere())
	assert_eq(String(field.atmo["falls"]), "rain")
