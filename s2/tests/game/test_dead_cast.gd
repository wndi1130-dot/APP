extends GutTest
## The dead wear bodies of their own (dead_cast.gd), drawn by zombies.gd one
## body's multimeshes at a time.

const DeadCast = preload("res://game/actors/dead_cast.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const BodyCast = preload("res://game/actors/body_cast.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const FieldGame = preload("res://game/field_game.gd")
const Wear = preload("res://game/sim/wear.gd")
const LootTables = preload("res://game/sim/loot_tables.gd")


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


# Every body of the dead has each garment beside it (dead_cast.gd SHELLS), its
# motions lined up with the body's, and fewer vertices than the body.
func test_every_body_of_the_dead_has_its_garments_lined_up() -> void:
	if not _build_bodies_in_use():
		pending("a folder put in place of the build's own: no garments beside it")
		return
	var first := BodyBake.load_baked(DeadBody.BUILT_IN)
	for b in DeadCast.BODIES.size():
		var body := BodyBake.load_baked(DeadCast.ROOT + DeadCast.BODIES[b])
		for kind: String in DeadCast.SHELLS:
			assert_true(BodyBake.SHELLS.has(kind), kind + " is a shell the bake knows")
			var dir := DeadCast.garment_dir(b, kind)
			assert_eq(dir, DeadCast.ROOT + DeadCast.BODIES[b] + "/wear/" + kind)
			var got := DeadCast.read_garment(dir, first)
			assert_false(got.is_empty(), "%s %s lines up with the first" % [DeadCast.BODIES[b], kind])
			if not got.is_empty() and not body.is_empty():
				assert_lt(int(got["vertices"]), int(body["vertices"]), "%s %s: fewer vertices than the body" % [DeadCast.BODIES[b], kind])
	assert_eq(DeadCast.garment_dir(0, "hood"), "", "no garment the dead are not drawn in")
	assert_eq(DeadCast.garment_dir(DeadCast.BODIES.size(), "vest"), "", "no body past the last")


# Drawn over the body is the outermost of coat and jacket the dead have a
# garment for, as the living's is picked: every coat the dead can come in
# (loot_tables.gd WEAR_*) is drawn, a short jacket not; in the garment's own
# colour, in the body's look, its pattern in alpha.
func test_what_is_drawn_over_the_body_is_what_is_worn() -> void:
	var grey := Color(0.5, 0.5, 0.5)
	assert_true(DeadCast.garment_of({}, grey).is_empty(), "nothing on: nothing drawn")
	var coats := {}
	for rows: Dictionary in [LootTables.WEAR_PLAIN] + LootTables.WEAR_KIND.values() + LootTables.WEAR_PLACE.values():
		for r: Array in rows.get("coat", []):
			coats[String(r[0])] = true
	coats.erase("")
	assert_true(coats.has("vest_armor") and coats.has("fire_suit") and coats.has("coat_padded"), "the vest, the fire suit and the padded coat among them")
	for id: String in coats:
		var over := DeadCast.garment_of({"coat": Wear.make(id)}, grey)
		assert_false(over.is_empty(), id + " is drawn")
		if over.is_empty():
			continue
		var tint: Array = Wear.KINDS[id]["tint"]
		assert_almost_eq(Vector3(over["colour"].r, over["colour"].g, over["colour"].b), Vector3(tint[0], tint[1], tint[2]), Vector3.ONE * 0.0001, id + " in its own colour")
		assert_almost_eq(float(over["colour"].a) * 3.0, float(PersonVisual.PATTERNS[String(Wear.KINDS[id].get("pattern", "plain"))]), 0.0001, id + " in its own pattern")
	assert_eq(DeadCast.garment_of({"coat": Wear.make("vest_armor")}, grey)["shell"], "vest")
	assert_eq(DeadCast.garment_of({"coat": Wear.make("fire_suit")}, grey)["shell"], "coat_long", "the fire suit to the knees")
	assert_eq(DeadCast.garment_of({"coat": Wear.make("coat_padded")}, grey)["shell"], "coat_long")
	assert_true(DeadCast.garment_of({"jacket": Wear.make("jacket_plain")}, grey).is_empty(), "a short jacket is not drawn")
	assert_eq(DeadCast.garment_of({"jacket": Wear.make("coat_leather")}, grey)["shell"], "coat_long", "a long one in the jacket's place is")
	assert_eq(DeadCast.garment_of({"coat": Wear.make("vest_armor"), "jacket": Wear.make("coat_leather")}, grey)["shell"], "vest", "the outermost")
	var frozen := DeadCast.garment_of({"coat": Wear.make("coat_long")}, Zombies.TINTS["frozen"])["colour"] as Color
	var corpse := DeadCast.garment_of({"coat": Wear.make("coat_long")}, Zombies.TINTS["corpse"])["colour"] as Color
	assert_gt(frozen.get_luminance(), corpse.get_luminance(), "in the body's look: the frozen frosted, the lying dead darker")


# The field draws each of the dead in what it has on now (zombies.gd worn_of):
# one garment multimesh per body and garment, as many in it as have it on, each
# where its body is drawn, in the same frame of the same motion, in the
# garment's colour in the body's look; standing, frozen, crawling or lying, and
# the bodies read first, one read a frame, body or garment; taken off a body,
# it is drawn without.
func test_the_dead_are_drawn_in_what_they_have_on() -> void:
	if not _build_bodies_in_use():
		pending("a folder put in place of the build's own: no garments beside it")
		return
	var was = ProjectSettings.get_setting(DeadCast.SETTING, 0)
	ProjectSettings.set_setting(DeadCast.SETTING, 0)
	var game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	var z = game.zombies
	ProjectSettings.set_setting(DeadCast.SETTING, was)
	z.list.clear()
	game.pending_spawn.clear()
	assert_true(z.baked, "the baked bodies")
	assert_eq(z.bodies_planned, DeadCast.BODIES.size(), "every body")
	var at: Vector3 = game.lift(Vector2i(60, 7), 0)
	var cam := Camera3D.new()
	add_child_autofree(cam)
	cam.look_at_from_position(at + Vector3(0, 40, 0.01), at)
	var on := [{}, {"coat": Wear.make("coat_long")}, {"coat": Wear.make("coat_padded")}, {"coat": Wear.make("vest_armor")},
		{"coat": Wear.make("fire_suit")}, {"jacket": Wear.make("jacket_plain")}]
	var dead: Array[Dictionary] = []
	for i in 64:
		var one: Dictionary = z.spawn(["dead", "clothed", "fresh", "frozen"][i % 4], at + Vector3(float(i % 8) * 0.9 - 3.2, 0, floorf(float(i) / 8.0) * 0.9 - 3.2))
		if i < 48:
			one["worn"] = (on[i % on.size()] as Dictionary).duplicate(true)   # the rest as their own dice have it
		if i % 8 == 5:
			one["state"] = "dead"      # lying, drawn as the corpse
		elif i % 8 == 6 and one["kind"] != "frozen":
			one["crawl"] = true
		dead.append(one)
	var reads: int = _reads(z)
	for frame in DeadCast.BODIES.size() * (1 + DeadCast.SHELLS.size()) + 2:
		var reading: bool = not z.bodies_to_read.is_empty()
		z.render(cam, {}, false)   # every body and garment read in, one a frame
		assert_lte(_reads(z) - reads, 1, "one read in frame %d" % frame)
		reads = _reads(z)
		if reading:
			assert_true(_drawn_in(z).is_empty(), "the bodies are read first, then the garments (frame %d)" % frame)
	var drawn := _drawn_in(z)
	for i in range(48, dead.size()):
		assert_false(dead[i].has("worn"), "drawn, its clothes are not put in its record")
	_assert_on_their_bodies(z, "all read")
	assert_eq(drawn, _wearing(z, cam), "each garment drawn as many times as it is worn")
	assert_gt(_wearing(z, cam).size(), 8, "garments on several bodies")
	for b in z.wear_draws.size():
		for kind: String in z.wear_draws[b]:
			if z.wear_draws[b][kind] != null:
				assert_gte((z.wear_draws[b][kind] as MultiMeshInstance3D).multimesh.instance_count, Zombies.MAX_DRAW * 5, "room for as many as the body's five looks")
	var vests := 0
	for one: Dictionary in dead:
		if String(z.worn_of(one).get("coat", {}).get("id", "")) == "vest_armor":
			vests += 1
	assert_gt(vests, 4, "armour vests among them")
	var stripped := 0
	for one: Dictionary in dead:
		if z.worn_of(one).has("coat"):
			z.worn_of(one).erase("coat")
			stripped += 1
	assert_gt(stripped, 10)
	z.render(cam, {}, false)
	assert_eq(_drawn_in(z), {}, "taken off, drawn without")
	assert_eq(_wearing(z, cam), {})


# Bodies and garments read in so far.
func _reads(z) -> int:
	var n: int = z.draws.size()
	for wear: Dictionary in z.wear_draws:
		n += wear.size()
	return n


# Every garment drawn is drawn where one of its body's drawn is, with the same
# frame of the same motion (custom data), in a garment colour in that one's look.
func _assert_on_their_bodies(z, when: String) -> void:
	var colours := {}   # look -> the garment colours the dead have in it
	for look: String in Zombies.TINTS:
		colours[look] = []
		for one: Dictionary in z.list:
			var over := DeadCast.garment_of(z.drawn_worn(one), Zombies.TINTS[look])
			if not over.is_empty():
				colours[look].append(over["colour"])
	var garments := 0
	for b in z.wear_draws.size():
		var bodies := []
		for look: String in z.draws[b]:
			var mm: MultiMesh = (z.draws[b][look] as MultiMeshInstance3D).multimesh
			for n in mm.visible_instance_count:
				bodies.append([mm.get_instance_transform(n), mm.get_instance_custom_data(n), look])
		for kind: String in z.wear_draws[b]:
			if z.wear_draws[b][kind] == null:
				continue
			var gm: MultiMesh = (z.wear_draws[b][kind] as MultiMeshInstance3D).multimesh
			for w in gm.visible_instance_count:
				garments += 1
				var found: Array = []
				for body: Array in bodies:
					if (body[0] as Transform3D).is_equal_approx(gm.get_instance_transform(w)) and (body[1] as Color).is_equal_approx(gm.get_instance_custom_data(w)):
						found = body
						break
				assert_false(found.is_empty(), "%s: body %d %s %d on a body" % [when, b, kind, w])
				if not found.is_empty():
					var c: Color = gm.get_instance_color(w)
					assert_true((colours[String(found[2])] as Array).any(func(k: Color) -> bool: return k.is_equal_approx(c)), "%s: body %d %s %d in its look" % [when, b, kind, w])
	assert_gt(garments, 0, when + ": some drawn")


# body:garment -> how many the field drew in it.
func _drawn_in(z) -> Dictionary:
	var out := {}
	for b in z.wear_draws.size():
		for kind: String in z.wear_draws[b]:
			var node: MultiMeshInstance3D = z.wear_draws[b][kind]
			if node != null and node.multimesh.visible_instance_count > 0:
				out["%d:%s" % [b, kind]] = node.multimesh.visible_instance_count
	return out


# body:garment -> how many in sight have it on (worn_of), in the body each is drawn in.
func _wearing(z, cam: Camera3D) -> Dictionary:
	var out := {}
	for one: Dictionary in z.list:
		if not cam.is_position_in_frustum(one["pos"] + Vector3(0, 0.6, 0)):
			continue
		var over := DeadCast.garment_of(z.worn_of(one), Zombies.TINTS["dead"])
		if over.is_empty():
			continue
		var b := DeadCast.body_of(int(one["id"]), z.bodies_planned)
		if b >= z.draws.size() or (z.draws[b] as Dictionary).is_empty():
			b = 0
		var key := "%d:%s" % [b, over["shell"]]
		out[key] = int(out.get(key, 0)) + 1
	return out
