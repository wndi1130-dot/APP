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


# Each of the dead is worn as its own (dead_weathered.gdshader): within its
# kind's span, the same every time, the fresh bloodier and less gone off than
# the long dead, one at a body bloodied, and the hands left alone in a body with
# none marked. The field draws them so (the multimesh colour, the weathered shader).
func test_each_of_the_dead_is_worn_as_its_own() -> void:
	var sums := {}
	for kind: String in DeadCast.TEAR:
		var lo: Vector3 = DeadCast.TEAR[kind][0]
		var hi: Vector3 = DeadCast.TEAR[kind][1]
		var sum := Vector3.ZERO
		for id in range(1, 201):
			var c := DeadCast.tear_of({"id": id, "kind": kind, "state": "wander"}, true)
			assert_eq(c, DeadCast.tear_of({"id": id, "kind": kind, "state": "wander"}, true), "the same every time")
			var v := Vector3(c.r, c.g, c.b)
			assert_true(v.x >= lo.x - 0.0001 and v.x <= hi.x + 0.0001 and v.y >= lo.y - 0.0001 and v.y <= hi.y + 0.0001 and v.z >= lo.z - 0.0001 and v.z <= hi.z + 0.0001, "%s %d within its span" % [kind, id])
			sum += v
		sums[kind] = sum / 200.0
	assert_gt(sums["fresh"].x, sums["dead"].x, "the fresh bloodier")
	assert_lt(sums["fresh"].z, sums["dead"].z, "and less gone off")
	assert_lt(sums["frozen"].z, sums["dead"].z, "the cold keeps them")
	assert_gte(DeadCast.tear_of({"id": 3, "kind": "dead", "state": "eat"}, true).r, DeadCast.TEAR_EATING - 0.0001, "one at a body is bloodied")
	assert_eq(DeadCast.tear_of({"id": 3, "kind": "dead"}, true).a, 1.0, "marked hands take the blood")
	assert_eq(DeadCast.tear_of({"id": 3, "kind": "dead"}, false).a, 0.0, "none marked: not the whole body")
	var z := Zombies.new()
	add_child_autofree(z)
	z.baked = true
	var looks: Dictionary = z._draws_of(DeadBody.assets())
	for look: String in looks:
		var node: MultiMeshInstance3D = looks[look]
		assert_true(node.multimesh.use_colors, look + ": each one's own wear")
		assert_eq((node.material_override as ShaderMaterial).shader.resource_path, "res://game/actors/dead_weathered.gdshader", look)


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
