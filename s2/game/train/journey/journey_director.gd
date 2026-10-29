extends RefCounted
## Which outside event comes and when (결정 495 2절, presentation_motion.md 7b 바깥
## 사건 규칙·드묾 단계): one at a time, never begun while a decision card is up (one
## under way goes on and out of sight), now and then with gaps that do not keep a
## beat, only where the land ahead fits it and not in a stretch passed without
## showing. Scenes rarer than common are rolled once a stretch pass by their tier's
## chance and come at most once in it; common ones come again, a different variant
## each time till all have come. Over runs the scene not yet seen comes first (the
## bag). Times are seconds on the train's screen while it runs. It only picks:
## what an event looks like is the journey's (journey.gd), and nothing here touches
## the rules.

## A tier's chance that a scene is in a stretch pass at all (7b 드묾 단계, 가안).
const TIERS: Dictionary = {"common": 1.0, "occasional": 0.3, "rare": 0.09, "very_rare": 0.01}
## Seconds from one event's end to the next one's start, skewed to the short end
## so the gaps do not keep a beat (gauge: spread 0.3~0.7, never under 30 s). About
## a minute and a half on average; now and then one close behind, now and then a
## long quiet (spread about 0.5 over half an hour).
const GAP := Vector2(35.0, 210.0)
const GAP_SKEW: float = 2.4
## The first event of a stretch waits this long after the land starts running.
const FIRST := Vector2(20.0, 45.0)
## A card just put away: the next event waits this much more (not the moment it closes).
const AFTER_CARD := Vector2(4.0, 9.0)
## Nothing fits the land ahead: look again this much later.
const RETRY_S: float = 4.0

## What can come (7b 바깥 사건, 결정 495). kinds: the sections of land it fits;
## light: the hour bands it may come in ([] any); not_in: weathers it never comes in.
## Rarer and stranger scenes join the list as their models and sounds come (설계 4장).
const EVENTS: Array = [
	{"id": "dead_rush", "tier": "common", "kinds": ["village", "field"], "light": [], "not_in": [],
		"variants": {"village": ["chasers", "runner", "walkers", "straggler"], "field": ["straggler", "walkers"]}, "len_s": 16.0},
	{"id": "crows_rise", "tier": "common", "kinds": ["field", "lake", "wood"], "light": ["dawn", "day", "dusk"], "not_in": ["blizzard"],
		"variants": {"field": ["field_clump", "fence"], "lake": ["tree_line", "field_clump"], "wood": ["tree_line"]}, "len_s": 11.0},
	{"id": "dead_wagons", "tier": "occasional", "kinds": ["village"], "light": [], "not_in": [],
		"variants": {"village": ["coal", "flats", "mixed"]}, "len_s": 22.0},
]

var rng := RandomNumberGenerator.new()
var catalog: Array = []
## The scenes (rarer than common) this stretch pass has.
var drawn: Array = []
var used: Array = []
## id -> times seen over runs (the bag: the least seen comes first).
var seen: Dictionary = {}
## Screen time before which no event begins.
var due: float = 0.0
## The event under way ({} none): {id, variant, kind, at, until}.
var playing: Dictionary = {}
## Every event begun: {id, variant, kind, at, quiet} (the gauges read it).
var started: Array = []
var _was_quiet: bool = false
var _variant_bags: Dictionary = {}


## A new stretch pass: `seen` is what earlier runs saw (it is kept up here).
func setup(seed_value: int, seen_before: Dictionary = {}, events: Array = EVENTS, now: float = 0.0) -> void:
	rng.seed = seed_value
	catalog = events.duplicate(true)
	seen = seen_before
	drawn.clear()
	used.clear()
	started.clear()
	playing = {}
	_variant_bags.clear()
	_was_quiet = false
	for row: Dictionary in catalog:
		var tier: String = String(row.get("tier", "common"))
		if tier != "common" and rng.randf() < float(TIERS.get(tier, 0.0)):
			drawn.append(String(row["id"]))
	due = now + rng.randf_range(FIRST.x, FIRST.y)


## One look at `now`: the event to begin ({} none) as {id, variant, kind, at, until}.
## quiet: a decision card is up. kind_ahead: the land where an event would come
## into sight. light: the hour band. weather: the stretch's. neutral: a stretch
## passed without showing (no events at all). busy: the last event is still in sight
## (its actor says when it has gone by, and finished() is called then).
func tick(now: float, quiet: bool, kind_ahead: String, light: String, weather: String, neutral: bool = false, busy: bool = false) -> Dictionary:
	if not playing.is_empty() and now >= float(playing["until"]) and not busy:
		finished(now)
	watch(now, quiet)
	if quiet or neutral or busy or not playing.is_empty() or now < due:
		return {}
	var fits: Array = []
	for row: Dictionary in catalog:
		if _fits(row, kind_ahead, light, weather):
			fits.append(row)
	if fits.is_empty():
		due = now + RETRY_S
		return {}
	var row: Dictionary = _choose(fits)
	var id: String = String(row["id"])
	var variant: String = _variant(row, kind_ahead)
	playing = {"id": id, "variant": variant, "kind": kind_ahead, "at": now, "until": now + float(row.get("len_s", 12.0))}
	started.append({"id": id, "variant": variant, "kind": kind_ahead, "at": now, "quiet": quiet})
	seen[id] = int(seen.get(id, 0)) + 1
	if String(row.get("tier", "common")) != "common":
		used.append(id)
	return playing.duplicate()


## The card state, every tick and while the train stands too (no event begins then,
## but a card put away still holds the next one off for AFTER_CARD of running time).
func watch(now: float, quiet: bool) -> void:
	if _was_quiet and not quiet:
		due = maxf(due, now + rng.randf_range(AFTER_CARD.x, AFTER_CARD.y))
	_was_quiet = quiet


## The event under way has gone by (its actor is done, or its time is up).
func finished(now: float) -> void:
	playing = {}
	due = now + GAP.x + (GAP.y - GAP.x) * pow(rng.randf(), GAP_SKEW)


func _fits(row: Dictionary, kind_ahead: String, light: String, weather: String) -> bool:
	var id: String = String(row["id"])
	if String(row.get("tier", "common")) != "common" and (not drawn.has(id) or used.has(id)):
		return false
	if not (row.get("kinds", []) as Array).has(kind_ahead):
		return false
	var lights: Array = row.get("light", [])
	if not lights.is_empty() and not lights.has(light):
		return false
	return not (row.get("not_in", []) as Array).has(weather)


## A drawn scene that fits comes before the common ones (it is rare already and the
## land that fits it passes); among the rest the least seen over runs, then by chance.
func _choose(fits: Array) -> Dictionary:
	var scenes: Array = fits.filter(func(r: Dictionary) -> bool: return String(r.get("tier", "common")) != "common")
	var pool: Array = scenes if not scenes.is_empty() else fits
	var least: int = 1 << 30
	for r: Dictionary in pool:
		least = mini(least, int(seen.get(String(r["id"]), 0)))
	var fewest: Array = pool.filter(func(r: Dictionary) -> bool: return int(seen.get(String(r["id"]), 0)) == least)
	return fewest[rng.randi_range(0, fewest.size() - 1)]


## The next variant of `row` for this land, each once before any comes again.
func _variant(row: Dictionary, kind: String) -> String:
	var by_kind: Dictionary = row.get("variants", {})
	var choices: Array = by_kind.get(kind, [])
	if choices.is_empty():
		return ""
	var key: String = String(row["id"]) + ":" + kind
	var bag: Array = _variant_bags.get(key, [])
	if bag.is_empty():
		bag = choices.duplicate()
		for i in range(bag.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: Variant = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
	var picked: String = String(bag.pop_back())
	_variant_bags[key] = bag
	return picked


## Gauges (결정 495 6절) over `begun` (started): kinds of (id, variant) seen; the
## spread of the gaps between starts (standard deviation over mean) and the
## shortest; how many began while quiet.
static func distinct(begun: Array) -> int:
	var keys: Dictionary = {}
	for e: Dictionary in begun:
		keys[String(e["id"]) + "/" + String(e["variant"])] = true
	return keys.size()


static func gaps(begun: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(1, begun.size()):
		out.append(float(begun[i]["at"]) - float(begun[i - 1]["at"]))
	return out


static func spread(begun: Array) -> float:
	var g := gaps(begun)
	if g.size() < 2:
		return 0.0
	var mean: float = 0.0
	for x: float in g:
		mean += x
	mean /= float(g.size())
	var v: float = 0.0
	for x: float in g:
		v += (x - mean) * (x - mean)
	return sqrt(v / float(g.size())) / maxf(mean, 0.001)


static func began_quiet(begun: Array) -> int:
	return begun.filter(func(e: Dictionary) -> bool: return bool(e["quiet"])).size()
