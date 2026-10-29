extends "res://addons/gut/test.gd"
## 결정 495 6절 gauges for the land going by the train: the windows of a stretch,
## the order of the land's sections (no run of three kinds again inside ten
## minutes), and the outside events (how many kinds in half an hour, gaps that do
## not keep a beat, none begun while a decision card is up, none where the line
## passes without showing). Clocks and seeds are given, so half an hour runs in a
## blink.

const Route = preload("res://game/train/journey/journey_route.gd")
const Sequencer = preload("res://game/train/journey/journey_sequencer.gd")
const Director = preload("res://game/train/journey/journey_director.gd")
const SeasonTable = preload("res://game/season_table.gd")

const SEEDS: int = 50
const STEP: float = 0.5
## How long an event's actor stays in sight, seconds: gone behind the camera, or its
## LIFE_S at most (journey_dead.gd 30, journey_crows.gd 24, journey_wagons.gd 60; the
## wagons' string is past in well under that at the run speed).
const ACTOR_S: Dictionary = {"dead_rush": Vector2(14.0, 30.0), "crows_rise": Vector2(12.0, 24.0), "dead_wagons": Vector2(20.0, 40.0)}


func test_stretch_windows_follow_the_bands_and_the_border_fields() -> void:
	var one: Array = Route.windows(1)
	assert_eq(one.size(), 1)
	assert_eq(String(one[0]["band"]), "K1")
	assert_false(bool(one[0]["neutral"]))
	var two: Array = Route.windows(2)
	assert_eq(two.size(), 2, "stretch 2 runs into the border fields at 18 km")
	assert_almost_eq(float(two[0]["to_km"]), 18.0, 0.001)
	assert_false(bool(two[0]["neutral"]))
	assert_true(bool(two[1]["neutral"]))
	var three: Array = Route.windows(3)
	assert_true(bool(three[0]["neutral"]))
	assert_false(bool(three[1]["neutral"]), "out of them at 32 km")
	var five: Array = Route.windows(5)
	assert_eq(String(five[0]["band"]), "K1")
	assert_eq(String(five[1]["band"]), "K2", "the Oder valley from 54 km")
	for seg: int in range(1, SeasonTable.segments() + 1):
		var mid: float = Route.STRETCH_KM * (float(seg) - 0.5)
		assert_eq(Route.band_at(mid), Route.band_of_seg(seg), "stretch %d: the 7b km table and the season table agree" % seg)


func test_a_neutral_window_lays_no_village_and_a_band_without_kit_lays_nothing() -> void:
	var bare: Array = Route.kinds({"band": "K1", "neutral": true})
	assert_false(bare.is_empty())
	for row: Dictionary in bare:
		assert_ne(String(row["kind"]), "village")
	assert_eq(Route.kinds({"band": "K9", "neutral": false}).size(), 0)


func test_no_run_of_three_kinds_comes_again_inside_ten_minutes() -> void:
	var worst: int = 0
	var lengthened: int = 0
	for s: int in SEEDS:
		for neutral: bool in [false, true]:
			var seq = Sequencer.new()
			seq.setup(7000 + s)
			var kinds: Array = Route.kinds({"band": "K1", "neutral": neutral})
			var t: float = 0.0
			while t < 7200.0:
				var section: Dictionary = seq.next(t, kinds)
				t += float(section["len_s"])
			worst = maxi(worst, Sequencer.repeats(seq.history))
			lengthened += seq.extended
	assert_eq(worst, 0, "two hours on each of %d seeds, the ordinary and the bare windows" % SEEDS)
	gut.p("sections lengthened instead of repeating: %d" % lengthened)


func test_the_order_holds_across_a_window_change() -> void:
	for s: int in SEEDS:
		var seq = Sequencer.new()
		seq.setup(9100 + s)
		var t: float = 0.0
		var neutral: bool = false
		var switch_at: float = 420.0
		while t < 3600.0:
			if t >= switch_at:
				neutral = not neutral
				switch_at += 300.0 + float(s % 7) * 60.0
			t += float(seq.next(t, Route.kinds({"band": "K1", "neutral": neutral}))["len_s"])
		assert_eq(Sequencer.repeats(seq.history), 0, "seed %d" % s)


## A border window after a village (not one of its kinds), every kind of it making a
## run of three seen inside ten minutes: a bare stretch goes between, nothing repeats.
func test_a_window_that_leaves_no_kind_open_bridges_instead_of_repeating() -> void:
	var seq = Sequencer.new()
	seq.setup(5)
	var order: Array = ["field", "village", "wood", "field", "village", "lake", "field", "village", "field", "village"]
	for i in order.size():
		seq.history.append({"kind": order[i], "at": 60.0 * i, "len_s": 60.0, "mirror": false, "seed": i})
	assert_eq(Sequencer.repeats(seq.history), 0, "the order given is clean")
	var bare: Array = Route.kinds({"band": "K1", "neutral": true})
	var first: Dictionary = seq.next(600.0, bare)
	assert_eq(String(first["kind"]), Sequencer.BRIDGE, "field, village, then any border kind would come again")
	var t: float = 600.0 + float(first["len_s"])
	for i in 30:
		t += float(seq.next(t, bare)["len_s"])
	assert_eq(Sequencer.repeats(seq.history), 0)
	assert_eq(seq.bridged, 1)


func test_every_window_has_kinds_enough_to_keep_the_order() -> void:
	for band: String in Route.KINDS:
		assert_gte((Route.KINDS[band] as Array).size(), 3, band + ": with fewer, a section would go on and on")
	assert_gte(Route.NEUTRAL_KINDS.size(), 3)


func test_each_section_is_dressed_its_own_way() -> void:
	var seq = Sequencer.new()
	seq.setup(1)
	var kinds: Array = Route.kinds({"band": "K1"})
	var seeds: Dictionary = {}
	var t: float = 0.0
	for i in 40:
		var section: Dictionary = seq.next(t, kinds)
		t += float(section["len_s"])
		if not bool(section["extend"]):
			assert_false(seeds.has(int(section["seed"])), "a dressing seed comes once")
			seeds[int(section["seed"])] = true


## Half an hour of the train's screen: the land from the sequencer, the event
## where it would come into sight `ahead` seconds on, the cards from `cards`
## ([[open, close], …]), each event's actor in sight for a while as journey.gd has
## it (busy, then finished). Returns the director.
func _run(seed_value: int, minutes: float, cards: Array = [], neutral: bool = false, light: String = "day", weather: String = "overcast"):
	var seq = Sequencer.new()
	seq.setup(seed_value)
	var kinds: Array = Route.kinds({"band": "K1", "neutral": neutral})
	var sections: Array = []
	var t: float = 0.0
	while t < minutes * 60.0 + 120.0:
		var section: Dictionary = seq.next(t, kinds)
		sections.append(section)
		t += float(section["len_s"])
	var d = Director.new()
	d.setup(seed_value * 31 + 5)
	var actors := RandomNumberGenerator.new()
	actors.seed = seed_value * 17 + 3
	var actor_until: float = -1.0
	var now: float = 0.0
	var i: int = 0
	while now < minutes * 60.0:
		var ahead: float = now + 3.0
		while i + 1 < sections.size() and float(sections[i + 1]["at"]) <= ahead:
			i += 1
		if actor_until >= 0.0 and now >= actor_until:
			actor_until = -1.0
			d.finished(now)
		var begun: Dictionary = d.tick(now, _quiet(cards, now), String(sections[i]["kind"]), light, weather, neutral, actor_until >= 0.0)
		if not begun.is_empty():
			var span: Vector2 = ACTOR_S[String(begun["id"])]
			actor_until = now + actors.randf_range(span.x, span.y)
		now += STEP
	return d


static func _quiet(cards: Array, now: float) -> bool:
	for c: Array in cards:
		if now >= float(c[0]) and now < float(c[1]):
			return true
	return false


func test_half_an_hour_brings_many_kinds_of_event_at_gaps_that_keep_no_beat() -> void:
	var kinds_total: int = 0
	var spreads: Array = []
	var shortest: float = INF
	var scenes: int = 0
	var fewest_kinds: int = 1 << 30
	for s: int in SEEDS:
		var d = _run(300 + s, 30.0)
		var kinds: int = Director.distinct(d.started)
		kinds_total += kinds
		fewest_kinds = mini(fewest_kinds, kinds)
		assert_gte(d.started.size(), 8, "seed %d: an event every few minutes" % s)
		# Each run on its own too, not only the fifty together (a kind is an event and its variant).
		assert_gte(kinds, 3, "seed %d: kinds of event" % s)
		assert_between(Director.spread(d.started), 0.2, 0.85, "seed %d: the gaps keep no beat" % s)
		spreads.append(Director.spread(d.started))
		for g: float in Director.gaps(d.started):
			shortest = minf(shortest, g)
		var wagons: int = d.started.filter(func(e: Dictionary) -> bool: return String(e["id"]) == "dead_wagons").size()
		assert_lte(wagons, 1, "a scene comes once a stretch pass")
		scenes += wagons
	var mean_kinds: float = float(kinds_total) / float(SEEDS)
	spreads.sort()
	var median: float = float(spreads[spreads.size() / 2])
	gut.p("30 min: kinds of (event, variant) %.2f on average (fewest %d), gap spread median %.2f, shortest gap %.1f s, scene in %d of %d" % [mean_kinds, fewest_kinds, median, shortest, scenes, SEEDS])
	assert_gte(mean_kinds, 5.0)
	assert_between(median, 0.3, 0.7)
	assert_gte(shortest, 30.0)
	assert_between(scenes, 1, SEEDS - 1, "the occasional scene is rolled, not always there")


func test_no_event_begins_while_a_decision_card_is_up() -> void:
	var cards: Array = []
	var t: float = 12.0
	var flip: bool = false
	while t < 1800.0:
		var length: float = 25.0 + fmod(t * 7.3, 70.0) if not flip else 30.0 + fmod(t * 3.1, 150.0)
		if not flip:
			cards.append([t, t + length])
		t += length
		flip = not flip
	for s: int in SEEDS:
		var d = _run(600 + s, 30.0, cards)
		for e: Dictionary in d.started:
			assert_false(_quiet(cards, float(e["at"])), "seed %d: begun at %.1f under a card" % [s, float(e["at"])])
			for c: Array in cards:
				var since: float = float(e["at"]) - float(c[1])
				if since >= 0.0 and since < Director.AFTER_CARD.x:
					fail_test("seed %d: begun %.1f s after a card closed" % [s, since])


func test_a_stretch_passed_without_showing_has_no_event() -> void:
	for s: int in 10:
		var d = _run(900 + s, 20.0, [], true)
		assert_eq(d.started.size(), 0)


func test_crows_keep_to_the_light_and_the_dead_to_the_settled_land() -> void:
	for s: int in 10:
		var d = _run(1200 + s, 30.0, [], false, "night")
		for e: Dictionary in d.started:
			assert_ne(String(e["id"]), "crows_rise", "no crows rise in the dark")
		var day = _run(1300 + s, 30.0)
		for e: Dictionary in day.started:
			if String(e["id"]) == "dead_rush":
				assert_true(String(e["kind"]) in ["village", "field"], "the dead come from where people lived")
