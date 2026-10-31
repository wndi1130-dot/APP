extends "res://addons/gut/test.gd"
## Canonical slot boundaries, normal difficulty (decisions 383, 387, 134, 250).

const HordeMix = preload("res://game/sim/horde_mix.gd")
const EDGE: float = 0.001
const TOLERANCE: float = 0.000000001


func _expect(act: String, progress: float, lunger: float, evolved: float) -> void:
	var mix: Dictionary = HordeMix.of(act, progress)
	assert_eq(mix.size(), 2)
	assert_typeof(mix["lunger_share"], TYPE_FLOAT)
	assert_typeof(mix["evolved_share"], TYPE_FLOAT)
	assert_almost_eq(float(mix["lunger_share"]), lunger, TOLERANCE, "%s at %s: lunger" % [act, progress])
	assert_almost_eq(float(mix["evolved_share"]), evolved, TOLERANCE, "%s at %s: evolved" % [act, progress])


func test_prologue_and_unknown_act_always_have_zero_shares() -> void:
	for act: String in ["prologue", "unknown", ""]:
		for progress: float in [-1.0, 0.0, 0.5, 1.0, 2.0]:
			_expect(act, progress, 0.0, 0.0)


func test_act1_starts_at_slot_eight_and_reaches_its_share_at_slot_twelve() -> void:
	var start: float = 7.0 / 12.0
	var end: float = 11.0 / 12.0
	for progress: float in [0.0, 6.0 / 12.0, start - EDGE, start]:
		_expect("act1", progress, 0.0, 0.0)
	_expect("act1", start + EDGE, 0.0003, 0.0)
	_expect("act1", 9.0 / 12.0, 0.05, 0.0)
	_expect("act1", end - EDGE, 0.0997, 0.0)
	for progress: float in [end, end + EDGE, 1.0]:
		_expect("act1", progress, 0.10, 0.0)


func test_act2_evolved_share_reaches_its_end_at_slot_twelve() -> void:
	var end: float = 11.0 / 12.0
	_expect("act2", 0.0, 0.10, 0.001)
	_expect("act2", EDGE, 0.10, 0.001 + 0.009 * EDGE / end)
	_expect("act2", end / 2.0, 0.10, 0.0055)
	_expect("act2", end - EDGE, 0.10, 0.010 - 0.009 * EDGE / end)
	for progress: float in [end, end + EDGE, 1.0]:
		_expect("act2", progress, 0.10, 0.010)


func test_act3_evolved_share_reaches_five_percent_at_slot_six() -> void:
	var end: float = 5.0 / 6.0
	_expect("act3", 0.0, 0.10, 0.03)
	_expect("act3", EDGE, 0.10, 0.03 + 0.02 * EDGE / end)
	_expect("act3", end / 2.0, 0.10, 0.04)
	_expect("act3", end - EDGE, 0.10, 0.05 - 0.02 * EDGE / end)
	for progress: float in [end, end + EDGE, 1.0]:
		_expect("act3", progress, 0.10, 0.05)


func test_act_transitions_and_clamped_progress_keep_the_table_values() -> void:
	_expect("prologue", 1.0 - EDGE, 0.0, 0.0)
	_expect("act1", EDGE, 0.0, 0.0)
	_expect("act1", 1.0 - EDGE, 0.10, 0.0)
	_expect("act2", 0.0, 0.10, 0.001)
	_expect("act2", 1.0 - EDGE, 0.10, 0.010)
	_expect("act3", 0.0, 0.10, 0.03)
	for act: String in ["prologue", "act1", "act2", "act3", "unknown"]:
		assert_eq(HordeMix.of(act, -1.0), HordeMix.of(act, 0.0))
		assert_eq(HordeMix.of(act, 2.0), HordeMix.of(act, 1.0))


func test_both_shares_never_decrease_through_the_acts_and_early_evolved_is_zero() -> void:
	var last_lunger: float = 0.0
	var last_evolved: float = 0.0
	for act: String in ["prologue", "act1", "act2", "act3"]:
		for step: int in range(1201):
			var mix: Dictionary = HordeMix.of(act, float(step) / 1200.0)
			var lunger: float = float(mix["lunger_share"])
			var evolved: float = float(mix["evolved_share"])
			assert_gte(lunger, last_lunger)
			assert_gte(evolved, last_evolved)
			if act in ["prologue", "act1"]:
				assert_eq(evolved, 0.0)
			last_lunger = lunger
			last_evolved = evolved
	assert_eq(last_evolved, 0.05)
	assert_false(HordeMix.EVOLVED_READY, "table only; evolved kinds are not spawned")
