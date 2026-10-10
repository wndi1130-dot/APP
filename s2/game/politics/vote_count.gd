extends RefCounted
## Counting one council vote from the blocs (S3). A port of the draw loop in vote() of
## s1/src/game/politics.ts: each undecided seat and each seat a bought leader brings is one draw,
## then the drawn seats are shuffled so the screen can turn them over one by one.
## What the vote does to the train (laws, relations, journal) is not here.
## tests/politics/test_vote_count.gd checks it against real votes in tests/game/fixtures/s3/calc_data.json.

const Rng = preload("res://game/politics/rng.gd")
const CouncilMath = preload("res://game/politics/council_math.gd")


## blocs: one per community, in community order, each {yes, und, no, absent, pool, poolChance, score}.
## Returns {yes, no, absent, passed, by_comm: [[yes, no, absent]], flips: [[comm index, yes]], state}.
## The draw order is fixed: per community its undecided seats, then its pool seats, then the shuffle.
static func count(blocs: Array, state: int, need: int) -> Dictionary:
	var by_comm: Array = []
	var flips: Array = []
	var yes := 0
	var no := 0
	var absent := 0
	for c: int in blocs.size():
		var b: Dictionary = blocs[c]
		var cy := int(b["yes"])
		var cn := int(b["no"])
		var chance := CouncilMath.undecided_chance(int(b["score"]))
		for i: int in int(b["und"]):
			var got := Rng.next(state)
			state = got[1]
			var v: bool = got[0] < chance
			flips.append([c, v])
			if v:
				cy += 1
			else:
				cn += 1
		var pool_chance := float(b["poolChance"])
		for i: int in int(b["pool"]):
			var got := Rng.next(state)
			state = got[1]
			var v: bool = got[0] < pool_chance
			flips.append([c, v])
			if v:
				cy += 1
			else:
				cn += 1
		by_comm.append([cy, cn, int(b["absent"])])
		yes += cy
		no += cn
		absent += int(b["absent"])
	# Fisher-Yates from the back, one draw per step.
	for i: int in range(flips.size() - 1, 0, -1):
		var got := Rng.next(state)
		state = got[1]
		var j := int(floor(got[0] * (i + 1)))
		var tmp: Variant = flips[i]
		flips[i] = flips[j]
		flips[j] = tmp
	return {
		"yes": yes, "no": no, "absent": absent, "passed": yes >= need,
		"by_comm": by_comm, "flips": flips, "state": state,
	}
