extends "res://addons/gut/test.gd"
## Decision 494: route slots choose bands for the stop and its approach.

const RouteBands = preload("res://game/train/route_bands.gd")
const Atmosphere = preload("res://fx/atmosphere.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")


func test_the_first_five_stops_and_clamped_ends() -> void:
	var bands := ["K1", "K3", "K4", "K4", "K6"]
	for i in range(bands.size()):
		assert_eq(RouteBands.stop_band("prologue", i + 1), bands[i], "stop %d" % (i + 1))
	assert_eq(RouteBands.stop_band("prologue", -3, 1.0), "K1")
	assert_eq(RouteBands.stop_band("prologue", 0, 1.0), "K1")
	assert_eq(RouteBands.stop_band("prologue", 6, 0.0), "K6")
	assert_eq(RouteBands.stop_band("prologue", 99, 0.0), "K6")


func test_act_slots_take_priority_over_progress() -> void:
	for row: Array in [
		["act1", 1, "K7"], ["act1", 2, "K8"], ["act1", 6, "K8"],
		["act1", 7, "K9"], ["act1", 8, "K9"], ["act1", 9, "K10"], ["act1", 12, "K10"],
		["act2", 1, "K10"], ["act2", 5, "K10"], ["act2", 6, "K11"], ["act2", 12, "K11"],
		["act3", 1, "K12"], ["act3", 6, "K12"],
	]:
		assert_eq(RouteBands.stop_band(String(row[0]), int(row[1]), 1.0), row[2], "%s stop %d" % [row[0], row[1]])


func test_out_of_range_act_slots_use_clamped_progress() -> void:
	for row: Array in [
		["act1", 0, -0.2, "K7"], ["act1", 13, 0.0, "K7"],
		["act1", -1, 1.0 / 12.0, "K8"], ["act1", 13, 0.49, "K8"],
		["act1", 0, 0.5, "K9"], ["act1", 13, 2.0 / 3.0, "K10"],
		["act1", 99, 1.0, "K10"], ["act1", 0, 1.2, "K10"],
		["act2", 0, 0.4, "K10"], ["act2", 13, 5.0 / 12.0, "K11"],
		["act3", 0, 0.0, "K12"], ["act3", 7, 1.0, "K12"],
	]:
		assert_eq(RouteBands.stop_band(String(row[0]), int(row[1]), float(row[2])), row[3], "%s at %s" % [row[0], row[2]])


func test_an_unknown_act_keeps_the_default_band() -> void:
	assert_eq(RouteBands.stop_band("unknown", 3, 0.5), Atmosphere.DEFAULT_REGION)
	assert_eq(RouteBands.stop_band("", 0, 1.0), Atmosphere.DEFAULT_REGION)


func test_a_stops_own_map_keeps_its_band_on_any_stretch() -> void:
	assert_eq(RouteBands.place_stop(FieldMaps.DEFAULT_PLACE), ["prologue", 1])
	assert_eq(RouteBands.place_stop("houses_01"), [])
	for seg in [1, 2, 5]:
		assert_eq(RouteBands.band_of(FieldMaps.DEFAULT_PLACE, "prologue", seg), "K1", "the first stop's own map on stretch %d" % seg)
	assert_eq(RouteBands.band_of("houses_01", "prologue", 2), "K3", "a shared map: the band of the stop it is played at")
	assert_eq(_field({"departure": {"segment": 2}}).region, "K1", "the first stop's map on stretch 2 is still the first stop")


func test_the_field_uses_the_departure_segment_and_act_progress() -> void:
	assert_eq(_field({"place": "houses_01", "departure": {"segment": 5}}).region, "K6")
	assert_eq(_field({"place": "houses_01", "act": "act2", "act_progress": 0.5, "departure": {"segment": 0}}).region, "K11")


func test_the_field_keeps_an_explicit_region_and_the_bare_default() -> void:
	assert_eq(_field({"region": "K8", "departure": {"segment": 5}}).region, "K8")
	assert_eq(_field({"act": "act2", "act_progress": 1.0}).region, Atmosphere.DEFAULT_REGION)
	assert_eq(_field({"place": "houses_01", "act": "act2", "act_progress": 1.0}).region, Atmosphere.DEFAULT_REGION, "no departure: the default")


func _field(extra: Dictionary):
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	game.opts.merge(extra, true)
	add_child_autofree(game)
	game.set_process(false)
	return game
