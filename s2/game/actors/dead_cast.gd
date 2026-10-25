extends RefCounted
## Which baked body each of the dead wears (decision 428: not one body for all
## of them). BODIES are the body the build carries for the dead (dead_body.gd
## BUILT_IN) and others in worn, everyday winter clothes; none of them is a
## body the field's living (body_cast.gd) or the train's people (the _t
## folders) wear, so none of the dead looks like a companion. Each folder has
## the dead's motions under the same numbers as BUILT_IN (body_bake.gd
## OWN_CLIPS), so dead_body.gd's tables serve them all; one that does not line
## up is left out. A body is picked by the dead one's own number, so it is the
## same body every time it is drawn (and after a load).

const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")

const ROOT: String = "res://models/people/"
## BUILT_IN first. Few vertices each, since the dead are many on screen: the
## eight together have fewer on average than BUILT_IN alone.
const BODIES: Array[String] = ["n3-body_tracksuit", "n10-body_denim-m", "n10-body_sunday-m", "n3-body_gilet",
	"n3-body_hoodie", "n5-crew_carpenter", "n5-crew_forewoman", "n10-body_poncho-f"]
## How many of them a scene's dead wear at most (0: all). A phone that cannot
## hold every body's pictures sets fewer; 1 is BUILT_IN alone, as before.
const SETTING: String = "visuals/dead_bodies_max"


## The folders the dead wear past the first: none when the first is not the
## build's own (a folder put in place of it to try a body, dead_body.gd assets).
static func others() -> Array[String]:
	var out: Array[String] = []
	if OS.get_environment(DeadBody.FOLDER_ENV) != "" or DirAccess.dir_exists_absolute(DeadBody.FOLDER) or DeadBody.built_in() != ROOT + BODIES[0]:
		return out
	var cap := int(ProjectSettings.get_setting(SETTING, 0))
	var count := BODIES.size() if cap <= 0 else clampi(cap, 1, BODIES.size())
	for i in range(1, count):
		out.append(ROOT + BODIES[i])
	return out


## One more body, read with its colour picture; {} when it is not in the build
## or its motions do not line up with `first`'s.
static func read(dir: String, first: Dictionary) -> Dictionary:
	var got := DeadBody.with_albedo(BodyBake.load_baked(dir), dir)
	if got.is_empty() or not lined_up(got, first):
		return {}
	return got


## The same motions in the same places of the picture as `first`.
static func lined_up(got: Dictionary, first: Dictionary) -> bool:
	var a: Array = got.get("clips", [])
	var b: Array = first.get("clips", [])
	if a.size() != b.size():
		return false
	for i in a.size():
		for key in ["name", "start", "frames", "loop"]:
			if a[i][key] != b[i][key]:
				return false
	return true


## Which of `count` bodies the dead one numbered `id` wears.
static func body_of(id: int, count: int) -> int:
	if count <= 1:
		return 0
	return posmod(hash(id * 7919 + 17), count)
