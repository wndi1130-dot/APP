extends GutTest
## The dead wear bodies of their own (dead_cast.gd), drawn by zombies.gd one
## body's multimeshes at a time.

const DeadCast = preload("res://game/actors/dead_cast.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const BodyCast = preload("res://game/actors/body_cast.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const Zombies = preload("res://game/actors/zombies.gd")


func _build_bodies_in_use() -> bool:
	return OS.get_environment(DeadBody.FOLDER_ENV) == "" and not DirAccess.dir_exists_absolute(DeadBody.FOLDER)


# Every body the dead wear is in the build with the dead's motions lined up
# with the first's (BUILT_IN), and its colour picture; none is a body the
# field's living or the train's people wear; and together they have no more
# vertices on average than the first alone.
func test_every_body_of_the_dead_is_baked_like_the_first_and_worn_by_no_one_living() -> void:
	assert_eq(DeadCast.ROOT + DeadCast.BODIES[0], DeadBody.BUILT_IN)
	var first := BodyBake.load_baked(DeadBody.BUILT_IN)
	var total := 0
	for body: String in DeadCast.BODIES:
		var dir := DeadCast.ROOT + body
		var got := DeadCast.read(dir, first)
		assert_false(got.is_empty(), body + " lines up with the first")
		if got.is_empty():
			continue
		assert_true(got.get("albedo") is Texture2D, body + " has its colour picture")
		assert_false(BodyCast.ALL.has(body), body + " is not a body the living wear")
		assert_ne(dir + BodyCast.OWN_SUFFIX, PersonVisual.OWN_FOLDER, body)
		assert_false(FileAccess.file_exists(dir + "_t/clips.json"), body + " is not a body the train's people wear")
		total += int(got["vertices"])
	assert_lte(float(total) / DeadCast.BODIES.size(), float(first["vertices"]), "no more vertices on average than the first alone")
	assert_true(DeadCast.read(DeadCast.ROOT + "n5-crew_driver", first).is_empty(), "a folder of fewer motions is left out")


# Picked by the dead one's own number: the same body every time, and spread
# over all of them.
func test_each_of_the_dead_wears_one_body_and_they_spread_over_all() -> void:
	var n := DeadCast.BODIES.size()
	var worn := {}
	var same := true
	for id in range(1, 801):
		var b := DeadCast.body_of(id, n)
		same = same and DeadCast.body_of(id, n) == b
		worn[b] = int(worn.get(b, 0)) + 1
	assert_true(same, "the same body each time")
	for b in n:
		assert_between(int(worn.get(b, 0)), 60, 140, "body %d of 800 dead" % b)
	assert_eq(DeadCast.body_of(5, 1), 0, "one body: the first")


# A phone that cannot hold every body sets a cap; 1 is the first alone, as before.
func test_a_cap_on_the_bodies_the_dead_wear() -> void:
	if not _build_bodies_in_use():
		pending("a folder put in place of the build's own: the dead wear that alone")
		return
	var was = ProjectSettings.get_setting(DeadCast.SETTING, 0)
	ProjectSettings.set_setting(DeadCast.SETTING, 3)
	var three := DeadCast.others().size()
	ProjectSettings.set_setting(DeadCast.SETTING, 1)
	var one := DeadCast.others().size()
	ProjectSettings.set_setting(DeadCast.SETTING, was)
	assert_eq(three, 2)
	assert_eq(one, 0, "the first alone")
	assert_eq(DeadCast.others().size(), DeadCast.BODIES.size() - 1, "all of them with no cap")


# Read in one a frame, each body with its own five looks and its own walk's
# stride; a dead one whose body is not read yet is drawn in the first.
class NoField:
	var opts := {}


# With the baked bodies off (the boxes drawn instead) there are no others to
# read in, and setting up does not stop on the empty list.
func test_with_the_baked_bodies_off_no_others_are_read() -> void:
	var boxes := DeadBody.assets()
	if boxes.is_empty():
		pending("no baked body to stand in for the boxes")
		return
	var was := OS.get_environment(DeadBody.FOLDER_ENV)
	OS.set_environment(DeadBody.FOLDER_ENV, "user://no_such_dead_body")
	var z := Zombies.new()
	add_child_autofree(z)
	z.setup(NoField.new(), boxes)
	OS.set_environment(DeadBody.FOLDER_ENV, was)
	assert_false(z.baked)
	assert_true(z.bodies_to_read.is_empty())
	assert_eq(z.bodies_planned, 1)


func test_the_bodies_are_read_one_a_frame_each_with_its_looks_and_stride() -> void:
	if not _build_bodies_in_use():
		pending("a folder put in place of the build's own")
		return
	var z := Zombies.new()
	add_child_autofree(z)
	z.baked = true
	z.vat = DeadBody.assets()
	z.draw = z._draws_of(z.vat)
	z.draws = [z.draw]
	z.body_rounds = [DeadBody.rounds]
	z.bodies_to_read = DeadCast.others()
	z.bodies_planned = 1 + z.bodies_to_read.size()
	assert_eq(z.bodies_planned, DeadCast.BODIES.size())
	for frame in DeadCast.BODIES.size() - 1:
		assert_eq(z.draws.size(), frame + 1, "one body a frame")
		z._read_a_body()
	z._read_a_body()
	assert_eq(z.draws.size(), DeadCast.BODIES.size(), "all read, and no more")
	var crawl := int(DeadBody.CRAWL)
	var strides := {}
	var meshes := {}
	for b in z.draws.size():
		var looks: Dictionary = z.draws[b]
		assert_eq(looks.size(), 5, "body %d in its five looks" % b)
		meshes[(looks["dead"] as MultiMeshInstance3D).multimesh.mesh] = true
		strides[float((z.body_rounds[b] as Dictionary).get(crawl, 0.0))] = true
	assert_eq(meshes.size(), DeadCast.BODIES.size(), "each body its own mesh")
	assert_gt(strides.size(), 1, "each body crawls by its own stride")
