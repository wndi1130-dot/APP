extends RefCounted
## Council arithmetic that needs no game state (S3): seats, relation stage, how a bloc splits.
## A port of seats()/stageOf() in s1/src/game/state.ts and split()/undecidedChance() in
## s1/src/game/politics.ts. Per-community arrays follow the community order of the data tables.
## tests/politics/test_council_math.gd checks it against tests/game/fixtures/s3/.

const SEATS := 100


## JS Math.round: halves go up (-2.5 -> -2). GDScript round() sends halves away from zero.
static func round_half_up(x: float) -> int:
	return int(floor(x + 0.5))


## Largest-remainder split of 100 seats by head count. Equal remainders go to the earlier community.
## With nobody aboard every community reads as a 20-seat quota, as in the reference.
static func seats(pops: Array) -> Array[int]:
	var total := 0
	for p: Variant in pops:
		total += int(p)
	var out: Array[int] = []
	var frac: Array[float] = []
	var left := SEATS
	for p: Variant in pops:
		var q := (100.0 * int(p)) / float(total) if total > 0 else 20.0
		var whole := int(floor(q))
		out.append(whole)
		frac.append(q - whole)
		left -= whole
	# Rank by remainder, biggest first; the index breaks ties, so the order never depends on the sort.
	var ranked: Array[int] = []
	for i: int in pops.size():
		var at := ranked.size()
		while at > 0 and frac[ranked[at - 1]] < frac[i]:
			at -= 1
		ranked.insert(at, i)
	var k := 0
	while left > 0 and not ranked.is_empty():
		out[ranked[k]] += 1
		k = (k + 1) % ranked.size()
		left -= 1
	return out


## The first stage whose floor the relation reaches. stages: [{min, name, band}], warmest first.
static func stage_of(rel: float, stages: Array) -> Dictionary:
	var index := stages.size() - 1
	for i: int in stages.size():
		if rel >= float(stages[i]["min"]):
			index = i
			break
	return {"name": stages[index]["name"], "band": int(stages[index]["band"]), "index": index}


## Shares of a bloc's present seats by stance score: [yes, undecided, no].
static func split(score: int) -> Array[float]:
	if score >= 3:
		return [0.8, 0.2, 0.0]
	if score >= 1:
		return [0.4, 0.5, 0.1]
	if score == 0:
		return [0.1, 0.8, 0.1]
	if score >= -2:
		return [0.1, 0.5, 0.4]
	return [0.0, 0.2, 0.8]


## Chance that one undecided seat lands on yes.
static func undecided_chance(score: int) -> float:
	return clampf(0.5 + 0.1 * score, 0.2, 0.8)
