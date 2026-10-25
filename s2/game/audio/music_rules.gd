extends RefCounted
## What the music would play, read from what is on screen (docs/design/briefs/bgm.md). Pure rules:
## no nodes, no clock, no files. music_director.gd keeps the time; music_player.gd plays.
## Every value here is a first value (the brief's 「제안」), fixed by tests/game/test_music.gd.

const Look = preload("res://game/train/train_look.gd")

## The pieces (bgm.md 7): id = the trial file's stem, kind = its group. A field piece says which
## bands, weathers and seasons it fits; an empty list fits all. under: a cellar or sewer piece.
## No file is in the repository (bgm.md 9.3): a piece with no file is never picked.
const SONGS: Array = [
	{"id": "BGM01_TITLE_A", "kind": "title"},
	{"id": "BGM02_TITLE_B", "kind": "title"},
	{"id": "BGM03_TITLE_C", "kind": "title"},
	{"id": "BGM04_TRAIN_A", "kind": "hearth"},
	{"id": "BGM05_TRAIN_B", "kind": "night"},
	{"id": "BGM06_CRISIS_A", "kind": "crisis"},
	{"id": "BGM07_CRISIS_B", "kind": "decision"},
	{"id": "BGM08_FIELD_DAY_A", "kind": "explore", "bands": ["dawn", "day", "dusk"], "weathers": ["overcast", "rain", "sleet", "clear"], "seasons": ["late_autumn"]},
	{"id": "BGM09_FIELD_DAY_B", "kind": "explore", "bands": ["dawn", "day", "dusk"], "weathers": ["snow", "overcast", "sleet"], "seasons": ["early_winter"]},
	{"id": "BGM10_FIELD_DAY_C", "kind": "explore", "bands": ["dawn", "day", "dusk"], "weathers": ["snow", "overcast", "clear"], "seasons": ["deep_winter", "late_winter", "early_thaw"]},
	{"id": "BGM11_FIELD_NIGHT_A", "kind": "explore", "bands": ["night", "dusk"], "weathers": ["fog", "overcast", "snow", "clear", "rain", "sleet"], "seasons": []},
	{"id": "BGM12_FIELD_NIGHT_B", "kind": "explore", "under": true},
	{"id": "BGM13_THREAT_SEEN", "kind": "threat_seen"},
	{"id": "BGM14_THREAT_CHASE", "kind": "threat_chase"},
	{"id": "BGM15_THREAT_HORDE", "kind": "threat_horde"},
	{"id": "BGM16_RETURN_A", "kind": "return"},
	{"id": "BGM17_RETURN_B", "kind": "return"},
	{"id": "BGM18_LOSS_A", "kind": "loss"},
	{"id": "BGM19_LOSS_B", "kind": "loss_end"},
	{"id": "BGM20_TRAIN_COLD", "kind": "cold"},
	{"id": "BGM21_TRAIN_HUNGER", "kind": "hunger"},
	{"id": "BGM22_TRAIN_TENSION", "kind": "tension"},
]

## Threat (bgm.md 5): what is coming at you weighs most; what is not shown is not counted.
const SEEN_EACH: float = 1.0         # a dead in sight
const SEEN_MAX: float = 10.0
const COMING_FAR: float = 8.0        # one coming at you, 10 m or farther
const COMING_NEAR: float = 15.0      # one coming at you, nearer than 10 m
const NEAR_M: float = 10.0
const ON_TOP_M: float = 3.0          # this near: stage 3 at once
const GRABBED: float = 70.0
const HURT_MAX: float = 10.0
const PRESSURE_MAX: float = 15.0     # the horde bar, as far as it is on screen
const STAGE_FROM: Array = [10.0, 30.0, 60.0]   # stage 1 seen, 2 chased, 3 on you; 4 is a horde arriving

## The train (bgm.md 3.1): the first row that holds wins.
const FEAR_SILENCE: float = 80.0     # even the humming stops (sound_music 9.3 「허밍도 멎음」); the cars' own hush is Look.FEAR_FROZEN 60
const POT_OFF_COAL: float = 20.0     # s1 CALM.potOffCoal: the stove pot goes out — 「석탄 바닥」
const FREEZING_SHARE: float = 0.5    # this share of the cars under Look.WARM_FREEZING: 「얼어 가는 칸이 많음」
const RICH: float = 50.0             # s1 CALM.ledgerRich: coal and food both this much or more
const CALM_BELOW: float = 40.0       # tension and fear under this: 「낮음」 (Look.UNREST_FROM's second step)
const ROWS: Array[String] = ["fear", "crisis", "cold", "hunger", "tension", "night", "hearth", "none"]
## The kind each row plays; "" is no music. A row the user hears better as silence goes in
## SILENT_ROWS (bgm.md 9.1, answer pending: the brief's pick is cold and hunger silent).
const ROW_KIND: Dictionary = {"fear": "", "crisis": "crisis", "cold": "cold", "hunger": "hunger", "tension": "tension", "night": "night", "hearth": "hearth", "none": ""}
const SILENT_ROWS: Array[String] = []

## Picking (bgm.md 1.5): the best-fitting share of the pieces, never the one just heard. A piece
## fitting a whole axis worse than the best is never in the share, however few pieces there are.
const BEST_SHARE: float = 0.3
const FIT_SLACK: float = 0.5


## The threat score of a field snapshot: {"seen", "coming_far", "coming_near", "grabbed", "hurt"
## (0..1), "pressure" (0..1, as shown)}.
static func threat_score(s: Dictionary) -> float:
	var v := minf(float(s.get("seen", 0)) * SEEN_EACH, SEEN_MAX)
	v += float(s.get("coming_far", 0)) * COMING_FAR + float(s.get("coming_near", 0)) * COMING_NEAR
	if bool(s.get("grabbed", false)):
		v += GRABBED
	v += clampf(float(s.get("hurt", 0.0)), 0.0, 1.0) * HURT_MAX
	v += clampf(float(s.get("pressure", 0.0)), 0.0, 1.0) * PRESSURE_MAX
	return v


## 0 none, 1 seen, 2 chased, 3 on you, 4 a horde arriving.
static func threat_stage(s: Dictionary) -> int:
	if bool(s.get("horde", false)):
		return 4
	if bool(s.get("grabbed", false)) or int(s.get("on_top", 0)) > 0:
		return 3
	var v := threat_score(s)
	var st := 0
	for i in range(STAGE_FROM.size()):
		if v >= float(STAGE_FROM[i]):
			st = i + 1
	return st


static func threat_kind(stage: int) -> String:
	return ["", "threat_seen", "threat_chase", "threat_chase", "threat_horde"][clampi(stage, 0, 4)]


## The train row (bgm.md 3.1) of a snapshot: {"fear", "tension", "coal", "food", "hunger",
## "stranded", "crisis", "riot" (none, protest, riot), "night", "warmth" and "ration" (each car's,
## 0..100)}.
static func train_row(s: Dictionary) -> String:
	if float(s.get("fear", 0)) >= FEAR_SILENCE:
		return "fear"
	if bool(s.get("crisis", false)):
		return "crisis"
	var warmth: Array = s.get("warmth", [])
	var freezing := 0
	for w in warmth:
		if float(w) < Look.WARM_FREEZING:
			freezing += 1
	if bool(s.get("stranded", false)) or float(s.get("coal", 100)) <= POT_OFF_COAL or (not warmth.is_empty() and float(freezing) / warmth.size() >= FREEZING_SHARE):
		return "cold"
	if int(s.get("hunger", 0)) > 0 or float(s.get("food", 100)) < 1.0 or _mean(s.get("ration", [])) < Look.LOW_BELOW:
		return "hunger"
	if float(s.get("tension", 0)) >= Look.TENSION_STIR or String(s.get("riot", "none")) != "none":
		return "tension"
	if bool(s.get("night", false)):
		return "night"
	if _hearth(s):
		return "hearth"
	return "none"


## The hearth piece only when it is warm and fed (user 2026-10-25: not when the coal is gone):
## coal and food both rich, no car cold or hungry, tension and fear low.
static func _hearth(s: Dictionary) -> bool:
	if float(s.get("coal", 0)) < RICH or float(s.get("food", 0)) < RICH:
		return false
	if float(s.get("tension", 0)) >= CALM_BELOW or float(s.get("fear", 0)) >= CALM_BELOW:
		return false
	for w in s.get("warmth", []):
		if float(w) < Look.WARM_COLD:
			return false
	for r in s.get("ration", []):
		if float(r) < Look.LOW_BELOW:
			return false
	return true


static func row_kind(row: String) -> String:
	if SILENT_ROWS.has(row):
		return ""
	return String(ROW_KIND.get(row, ""))


## A row nearer the top is worse: going there the piece fades now, coming back it plays out.
static func worse(row: String, than: String) -> bool:
	return ROWS.find(row) < ROWS.find(than)


static func songs_of(kind: String, have: Dictionary) -> Array:
	var out: Array = []
	for song in SONGS:
		if song["kind"] == kind and have.has(song["id"]):
			out.append(song)
	return out


## How well a field piece fits {"band", "weathers", "season", "under"}: under must match; then a
## point for each axis the piece names and the moment has, and a half for an axis it leaves open.
static func fit(song: Dictionary, m: Dictionary) -> float:
	if bool(song.get("under", false)) != bool(m.get("under", false)):
		return -1.0
	var v := 0.0
	var bands: Array = song.get("bands", [])
	v += 0.5 if bands.is_empty() else (1.0 if bands.has(m.get("band", "day")) else 0.0)
	var weathers: Array = song.get("weathers", [])
	var w := 0.0
	for k in m.get("weathers", []):
		if weathers.has(k):
			w = 1.0
	v += 0.5 if weathers.is_empty() else w
	var seasons: Array = song.get("seasons", [])
	v += 0.5 if seasons.is_empty() else (1.0 if seasons.has(m.get("season", "")) else 0.0)
	return v


## The piece to play: the best-fitting share (at least one), never `last` unless it is the only
## one; "" when there is none.
static func pick(kind: String, have: Dictionary, m: Dictionary, last: String, rng: RandomNumberGenerator) -> String:
	var pool: Array = []
	for song in songs_of(kind, have):
		var f := fit(song, m) if kind == "explore" else 0.0
		if f >= 0.0:
			pool.append([f, song["id"]])
	if pool.size() > 1:
		pool = pool.filter(func(p): return p[1] != last)
	if pool.is_empty():
		return ""
	pool.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var best: float = pool[0][0]
	pool = pool.filter(func(p): return p[0] >= best - FIT_SLACK)
	var top := maxi(1, int(ceil(pool.size() * BEST_SHARE)))
	# Ties with the last of the best share are as good: they are in too.
	while top < pool.size() and pool[top][0] == pool[top - 1][0]:
		top += 1
	return String(pool[rng.randi_range(0, top - 1)][1])


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 100.0
	var v := 0.0
	for x in values:
		v += float(x)
	return v / values.size()
