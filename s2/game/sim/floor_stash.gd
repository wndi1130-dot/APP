extends RefCounted
## What is under a loose board (결정 카드 K 가, 차이 9번): room_stories.gd lays the
## place (one a stop at most, a lived-in bedroom or living room, data["floor_stashes"])
## and leaves its box empty, as it is laid after the stop is dressed; this fills it.
## Small things someone hid away: a watch, a carton of cigarettes, a handful of
## rounds. One always, a second now and then, on dice of its own, so nothing else
## of the stop changes. The rare store (#689) and the named finds are apart.

## [weight, item, count] rows.
const TABLE: Array = [
	[3, "pocket_watch", 1],
	[3, "wrist_watch", 1],
	[2, "cigarettes", 1],
	[2, "ammo_pistol", 2],
	[1, "junk_smokes", 1],
]
const SECOND_CHANCE: float = 0.5


## Fill every floor stash of the stop (its box must still be empty: a resumed
## stop keeps what its save says). Returns what went in, [[id, box]].
static func fill(data: Dictionary, seed: int) -> Array:
	var out: Array = []
	for s: Dictionary in data.get("floor_stashes", []):
		var box: Dictionary = data.get("containers", {}).get(String(s["id"]), {})
		if box.is_empty() or not (box.get("items", []) as Array).is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = ("%d:floor_stash:%s" % [seed, s["id"]]).hash()
		var items: Array = []
		var rolls := 2 if rng.randf() < SECOND_CHANCE else 1
		for _i in range(rolls):
			var row: Array = _pick(rng)
			for _n in range(int(row[2])):
				items.append(String(row[1]))
			out.append([String(row[1]), String(s["id"])])
		box["items"] = items
	return out


static func _pick(rng: RandomNumberGenerator) -> Array:
	var total := 0
	for row: Array in TABLE:
		total += int(row[0])
	var at := rng.randi_range(1, total)
	for row: Array in TABLE:
		at -= int(row[0])
		if at <= 0:
			return row
	return TABLE[0]
