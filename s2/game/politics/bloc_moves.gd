extends RefCounted
## How deals and moved votes shift one community's bloc before the count (S3). A port of
## applyDeal() and shiftVotes() in s1/src/game/politics.ts. A bloc is
## {seats, absent, yes, und, no, hard, pool, poolChance, score, ideo}; "hard" is the part of "no"
## that nothing moves. Both functions return a new bloc and leave the one passed in alone.
## tests/politics/test_bloc_moves.gd checks them against tests/game/fixtures/s3/calc_data.json.

const CouncilMath = preload("res://game/politics/council_math.gd")


## tool: open | fetch | blackmail | bribe | favor. coh is the community's cohesion (used by bribe and favor).
static func apply_deal(bloc: Dictionary, tool: String, coh: float) -> Dictionary:
	var b := bloc.duplicate()
	var soft := int(b["no"]) - int(b["hard"])
	if tool == "open" or tool == "fetch":
		# A public promise: every undecided seat and a fifth of the movable no.
		var moved := CouncilMath.round_half_up(soft * 0.2)
		b["yes"] = int(b["yes"]) + int(b["und"]) + moved
		b["no"] = int(b["no"]) - moved
		b["und"] = 0
	elif tool == "blackmail":
		# The leader drags the whole community along, except the hard no.
		b["yes"] = int(b["yes"]) + int(b["und"]) + soft
		b["und"] = 0
		b["no"] = int(b["hard"])
	else:
		# Bribe and favor: the leader's share. Each of these seats is drawn at the count with chance coh.
		b["pool"] = int(b["pool"]) + int(b["und"]) + soft
		b["poolChance"] = coh
		b["und"] = 0
		b["no"] = int(b["hard"])
	return b


## Moves n seats toward yes (n > 0, taken from the movable no and then the undecided) or toward no
## (n < 0, taken from yes and then the undecided).
static func shift(bloc: Dictionary, n: float) -> Dictionary:
	var b := bloc.duplicate()
	var left := absi(CouncilMath.round_half_up(n))
	var from: Array[String] = ["no", "und"]
	if n <= 0:
		from = ["yes", "und"]
	for k: String in from:
		var room := int(b["no"]) - int(b["hard"]) if k == "no" else int(b[k])
		var take := mini(left, room)
		b[k] = int(b[k]) - take
		if n > 0:
			b["yes"] = int(b["yes"]) + take
		else:
			b["no"] = int(b["no"]) + take
		left -= take
	return b
