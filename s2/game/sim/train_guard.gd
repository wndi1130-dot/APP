extends RefCounted
## The train holds the dead its brakes brought (decision 416): the plough on
## the front, the armoured cars, and the people at the doors and on the roof
## put down each one that reaches the train in the stop's first minutes. Who
## got hurt doing it goes on the stop's receipt. Nobody dies of it: a death
## that comes with every stop, whatever anyone does, would be unfair.
##
## One pure function for every stop (resolve): a stop the squad goes out on
## feeds it the dead as they really reach the train, a stop it does not (the
## receipt's source "auto") feeds it the ones its kind of place would send
## (arrival_horde.gd auto_bodies), and both come out the same way.
##
## It is causal: what it says of a time depends on nothing after it, so the
## field can run it again whenever one more reaches the train or the squad
## takes one, and what already happened stays as it was.

const ArrivalHorde = preload("res://game/sim/arrival_horde.gd")

## One pair of hands puts one of the dead down this long after it gets to it.
const KILL_S := 4.0
## Hands at the train when the stop does not say (opts "train_guards").
const HANDS := 2
## The chance a guard is hurt putting one down: a little every time, more for
## every one already waiting when it came (more than the hands can take).
const HURT_BASE := 0.05
const HURT_PER_WAITING := 0.15
const HURT_MAX := 0.6
## Of those hurt, this share is a scratch; the rest a cut (never a bite: a
## bite turns, and this defence kills nobody).
const SCRATCH_SHARE := 0.7
## Where the guards stand (the receipt's names for them, ids).
const POSTS: Array[String] = ["plow", "cab_door", "roof", "car_door"]
const KINDS: Array[String] = ["scratch", "laceration"]


## bodies: [{"id": int, "t": seconds it reached the train, "post": one of
## POSTS (where it did), "taken": when it stopped being the guards' (INF:
## never), "by": "squad" (the squad put it down there, the default) or
## "left" (it walked off before a guard got to it)}].
## hands: guards at the train (0: none, nobody is put down). seed: the stop's.
## Returns {"came", "killed" (by the guards), "by_squad", "took" (seconds from
## the first in to the last down; 0 with none), "kills": {id: t}, "starts":
## {id: when a guard got to it}, "hurt": [{"post", "kind", "t", "id"}] one
## row a post (a person), the worse wound}.
static func resolve(bodies: Array, hands: int, seed: int) -> Dictionary:
	var order: Array = bodies.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["t"]) < float(b["t"]) or (float(a["t"]) == float(b["t"]) and int(a["id"]) < int(b["id"])))
	var free: Array[float] = []
	for i in range(maxi(hands, 0)):
		free.append(0.0)
	var rows: Array[Dictionary] = []   # {t, start, out}: when it came, a guard got to it (INF: none), it was down
	var kills: Dictionary = {}
	var starts: Dictionary = {}
	var hurt_by_post: Dictionary = {}
	var by_squad := 0
	var first_t := INF
	var last_t := -INF
	for b: Dictionary in order:
		var t: float = float(b["t"])
		var taken: float = float(b.get("taken", INF))
		var squad: bool = String(b.get("by", "squad")) == "squad"
		first_t = minf(first_t, t)
		# How many were already waiting (no guard on them yet) when it came.
		var waiting := 0
		for r: Dictionary in rows:
			if float(r["t"]) <= t and t < minf(float(r["start"]), float(r["out"])):
				waiting += 1
		var start := INF
		var slot := -1
		if not free.is_empty():
			slot = 0
			for i in range(1, free.size()):
				if free[i] < free[slot]:
					slot = i
			start = maxf(t, free[slot])
		var out: float
		if taken <= start:
			# The squad got to it before any guard did, or it walked off.
			out = taken
			if squad and taken < INF:
				by_squad += 1
			start = INF
		elif slot < 0:
			out = INF
		else:
			var end := start + KILL_S
			out = minf(end, taken)
			free[slot] = out
			starts[int(b["id"])] = start
			if taken < end:
				if squad:
					by_squad += 1
			else:
				kills[int(b["id"])] = end
			# A guard was on it: were they hurt? Decided by the stop's seed and
			# this one alone, so the rolls never shift between runs.
			var p := minf(HURT_MAX, HURT_BASE + HURT_PER_WAITING * float(waiting))
			if _roll(seed, int(b["id"]), 0) < p:
				var kind: String = KINDS[0] if _roll(seed, int(b["id"]), 1) < SCRATCH_SHARE else KINDS[1]
				var post: String = String(b.get("post", POSTS[0]))
				var had: Dictionary = hurt_by_post.get(post, {})
				if had.is_empty() or KINDS.find(kind) > KINDS.find(String(had["kind"])):
					hurt_by_post[post] = {"post": post, "kind": kind, "t": start, "id": int(b["id"])}
		if out < INF:
			last_t = maxf(last_t, out)
		rows.append({"t": t, "start": start, "out": out})
	var hurt: Array[Dictionary] = []
	for post in POSTS:
		if hurt_by_post.has(post):
			hurt.append(hurt_by_post[post])
	for post: String in hurt_by_post:
		if not POSTS.has(post):
			hurt.append(hurt_by_post[post])
	return {
		"came": order.size(), "killed": kills.size(), "by_squad": by_squad,
		"took": maxf(0.0, last_t - first_t) if last_t > -INF else 0.0,
		"kills": kills, "starts": starts, "hurt": hurt,
	}


## The guard's post nearest a spot by the train: past its front end the
## plough, along the engine the cab door, else a car's door or, on every
## other car, the one on its roof. x in cells; train: the train's Rect2i.
static func post_at(x: int, train: Rect2i, engine_cells: int = 8) -> String:
	if x >= train.end.x:
		return "plow"
	if x >= train.end.x - engine_cells:
		return "cab_door"
	return "car_door" if (int((x - train.position.x) / engine_cells) % 2) == 0 else "roof"


## On the stop's receipt as it is now (receipt v4): the sum under the place's
## state ("trainGuard", a key the schema leaves open). The same for a played
## stop and an auto one. The people and their wounds go in the S3 contract's
## "defense" (receipt v5, defense() below) once the receipt has it.
static func write(receipt, result: Dictionary, heard: int, hands: int, at_doors: int = 0) -> void:
	var posts: Array = []
	for h: Dictionary in result["hurt"]:
		posts.append(String(h["post"]))
	receipt.place_note("trainGuard", {
		"heard": heard, "came": int(result["came"]), "atDoors": at_doors, "hands": hands,
		"killed": int(result["killed"]), "bySquad": int(result["by_squad"]),
		"tookSeconds": snappedf(float(result["took"]), 0.1), "hurt": posts,
	})


## The S3 contract's "defense" (docs/design/briefs/s3_departure_receipt_contract.md
## 3: held, people, hurt, dead, wounds): ids are the train's people at the
## posts, in POSTS order, the departure contract's; none gives null (there is
## nobody to name). A post's guard is ids[post's place % ids]. The wound is on
## an arm mostly (fending them off from a door or the roof), never a bite, and
## nobody is dead.
static func defense(result: Dictionary, ids: Array, seed: int) -> Variant:
	if ids.is_empty():
		return null
	var hurt: Array = []
	var wounds: Array = []
	for h: Dictionary in result["hurt"]:
		var who: String = String(ids[maxi(POSTS.find(String(h["post"])), 0) % ids.size()])
		if not hurt.has(who):
			hurt.append(who)
		var u := _roll(seed, int(h["id"]), 2)
		var part: String = "arm_right" if u < 0.45 else ("arm_left" if u < 0.9 else "torso")
		wounds.append({"person": who, "part": part, "kind": String(h["kind"])})
	return {"held": true, "people": ids.duplicate(), "hurt": hurt, "dead": [], "wounds": wounds}


## A stop nobody goes out on: the same defence of the bodies its kind of
## place would send (arrival_horde.gd). Its receipt is written with write().
static func auto(kind: String, hands: int, seed: int, form: String = "city") -> Dictionary:
	return resolve(ArrivalHorde.auto_bodies(kind, form), hands, seed)


static func _roll(seed: int, id: int, salt: int) -> float:
	var h: int = ("%d:%d:%d:train_guard" % [seed, id, salt]).hash()
	return float(h & 0xFFFFFF) / float(0x1000000)
