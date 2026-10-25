extends RefCounted
## The dead the brakes bring to the train (decision 416). The train coming to
## a stand is a loud sound at its engine end (noise.gd SOURCES "train_brake"):
## the dead within its reach turn and walk to the train in the stop's first
## minutes, and the train's guards put them down there (train_guard.gd). So
## the ground by the station is empty a while, and that is why the first
## horde is minutes off; the dead far off heard it too and come late, as the
## hordes from the roads and the track end.
##
## How many come is the place's: a map that has fewer of them within reach
## than its kind of place does gets the rest walking in along the nearest way
## in, out of sight (the fair spawn rule, zombies.md). The most only bounds
## that and the maps (a test): the dead that really heard always come.

const SimNoise = preload("res://game/sim/noise.gd")

const LEVEL := SimNoise.Level.LOUD
## Least and most dead that come to the train, by kind of place (the
## receipt's PLACE_TYPES). The towns stand among streets of the dead; the
## stops on the way are emptier. The most is what the maps have: the first
## leg's yard and the fifth pass have eight within reach of their engines.
const SIZE := {
	"freight": [3, 8], "houses": [3, 6], "hospital": [3, 6], "factory": [3, 6],
	"church": [3, 6], "office": [3, 6],
	"mine": [2, 4], "lodge": [2, 4], "sawmill": [2, 4], "lake": [2, 4], "summit": [2, 8],
}
const OTHER_SIZE := [2, 4]
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
static func fill(heard: int, kind: String) -> int:
	var b: Array = band(kind)
	return clampi(int(b[0]) - maxi(heard, 0), 0, int(b[1]))


## How far the brakes reach: loud, out of doors, by the weather (as any sound).
static func reach(sound_mult: float = 1.0) -> float:
	return SimNoise.radius(LEVEL, false) * sound_mult


## The bodies of a stop nobody goes out on (train_guard.gd resolve's input):
## the least of its kind, one after another along the train.
static func auto_bodies(kind: String) -> Array:
	var out: Array = []
	var n: int = int(band(kind)[0])
	var posts: Array = ["plow", "cab_door", "car_door"]
	for i in range(n):
		out.append({"id": i + 1, "t": AUTO_FIRST_S + AUTO_GAP_S * float(i), "post": posts[i % posts.size()], "taken": INF})
	return out
