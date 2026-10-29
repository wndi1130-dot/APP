extends RefCounted
## The dead the brakes bring to the train (decisions 416, 494). The train coming
## to a stand is a loud sound at its engine end (noise.gd SOURCES "train_brake"):
## the dead within its reach turn and walk to the train in the stop's first
## minutes, and the train's guards put them down there (train_guard.gd). Past
## that reach the sound fades out to FAR_M: the farther one stands, the less
## likely it comes, so a town by the station sends many and a halt far from its
## village few. So the ground by the station is empty a while, and that is why
## the first horde is minutes off; the dead far off heard it too and come late,
## as the hordes from the roads and the track end.
##
## How many come is the place's: a map that has fewer of them within reach
## than its kind of place does gets the rest walking in along the nearest way
## in, out of sight (the fair spawn rule, zombies.md), as much of that as the
## stop's form lets (stop_form.gd: none at a remote halt). The dead within the
## near reach always come; the far ones stop at a cap that grows along the
## journey (decision 498: 8 at the first stop, 30 at the end).

const SimNoise = preload("res://game/sim/noise.gd")
const StopForm = preload("res://game/sim/stop_form.gd")
const SeasonTable = preload("res://game/season_table.gd")

const LEVEL := SimNoise.Level.LOUD
## Where the pull has faded to nothing: full within reach(), none past this.
const FAR_M := 250.0
## Least and most dead that come to the train, by kind of place (the
## receipt's PLACE_TYPES). The towns stand among streets of the dead; the
## stops on the way are emptier. The most is what the maps have by their
## engines (the first leg's yard and the fifth pass: eight; a test).
const SIZE := {
	"freight": [3, 8], "houses": [3, 6], "hospital": [3, 6], "factory": [3, 6],
	"church": [3, 6], "office": [3, 6],
	"mine": [2, 4], "lodge": [2, 4], "sawmill": [2, 4], "lake": [2, 4], "summit": [2, 8],
}
const OTHER_SIZE := [2, 4]
## The most the far pull brings, by how far along the journey the stop is
## (decision 498): a straight line from the first stop to the end.
const CAP_FIRST := 8
const CAP_LAST := 30
## Where that line starts: the first leg's first stop stands at 54 km, in the season
## table's fifth stretch of 13 km (decision 494), and is as far along the journey as
## that stretch is into the prologue.
const FIRST_SEG := 5
## The first minutes: one of them that gets to the train later than this is
## no longer the guards' (they are back inside), it is one of the stop's dead.
const WINDOW_S := 180.0
## Seconds between two of the rest walking in along the same way.
const FILL_GAP_S := 2.5
## The guards' line at a stop the squad does not go out on: how long after
## the stand the first of them gets to the train, and each next one.
const AUTO_FIRST_S := 30.0
const AUTO_GAP_S := 8.0
## Spoken once the briefing has been heard (the radio's rules: "off" hears none).
const RADIO_LINE := "기관사: 제동 소리를 들었을 거다. 근처 것들이 열차로 온다."
const RADIO_AT_S := 6.0


## [least, most] for a kind of place.
static func band(kind: String) -> Array:
	return SIZE.get(kind, OTHER_SIZE)


## How many more walk in, when `heard` of the dead already heard the brakes.
static func fill(heard: int, kind: String, form: String = "city") -> int:
	var least := floori(float(band(kind)[0]) * StopForm.fill_share(form))
	return maxi(least - maxi(heard, 0), 0)


## How far along the journey (field_game.journey_progress) the first stop stands: its
## stretch's share of the prologue, the first of the four acts (Atmosphere.ACTS).
static func first_progress() -> float:
	return SeasonTable.seg_progress(FIRST_SEG) / 4.0


## The far pull's cap at `progress` (field_game.journey_progress): CAP_FIRST at the first
## stop and before it, CAP_LAST at the journey's end, a straight line between.
static func cap(progress: float) -> int:
	var first := first_progress()
	return roundi(lerpf(float(CAP_FIRST), float(CAP_LAST), clampf((progress - first) / (1.0 - first), 0.0, 1.0)))


## How far the brakes reach: loud, out of doors, by the weather (as any sound).
static func reach(sound_mult: float = 1.0) -> float:
	return SimNoise.radius(LEVEL, false) * sound_mult


static func far_reach(sound_mult: float = 1.0) -> float:
	return FAR_M * sound_mult


static func chance(d: float, sound_mult: float = 1.0) -> float:
	var near := reach(sound_mult)
	var far := far_reach(sound_mult)
	return clampf((far - d) / (far - near), 0.0, 1.0) if far > near else 0.0


## An independent roll: no draws from the field's random stream.
static func attracted(d: float, seed: int, id: int, sound_mult: float = 1.0) -> bool:
	var h: int = ("%d:%d:arrival_pull" % [seed, id]).hash()
	var roll := float(h & 0xFFFFFF) / float(0x1000000)
	return roll < chance(d, sound_mult)


## The bodies of a stop nobody goes out on (train_guard.gd resolve's input):
## the form's share of the least, one after another along the train.
static func auto_bodies(kind: String, form: String = "city") -> Array:
	var out: Array = []
	var n := floori(float(band(kind)[0]) * StopForm.fill_share(form))
	var posts: Array = ["plow", "cab_door", "car_door"]
	for i in range(n):
		out.append({"id": i + 1, "t": AUTO_FIRST_S + AUTO_GAP_S * float(i), "post": posts[i % posts.size()], "taken": INF})
	return out
