extends GutTest
## Each of the field's living wears a body of their own (body_cast.gd), drawn
## by person_visual.gd from that body's own folder pair.

const BodyCast = preload("res://game/actors/body_cast.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const Person = preload("res://game/actors/person.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const Wear = preload("res://game/sim/wear.gd")


func _person(pid: String, role: String) -> Node3D:
	var p := Person.new()
	add_child_autofree(p)
	p.setup(pid, "시험", role, Vector3.ZERO)
	return p


func _line_up(list: Array) -> Array:
	var out := []
	for clip: Dictionary in list:
		out.append([clip["name"], clip["start"], clip["frames"], clip["loop"]])
	return out


# Every body named here is in the build: the living's motions under the same
# numbers as the reference folder's, its colour picture, the dead's folder of
# the same mesh beside it, the right hand found for the weapon; and none is
# the body the dead wear.
func test_every_body_is_baked_with_the_living_motions_and_its_colour() -> void:
	var reference := _line_up(BodyBake.load_baked(PersonVisual.OWN_FOLDER)["clips"])
	for body: String in BodyCast.ALL:
		assert_ne(BodyCast.dead_folder(body), DeadBody.BUILT_IN, body)
		var own := DeadBody.with_albedo(BodyBake.load_baked(BodyCast.own_folder(body)), BodyCast.own_folder(body))
		assert_false(own.is_empty(), body)
		if own.is_empty():
			continue
		assert_eq(_line_up(own["clips"]), reference, body + " has the motions under the same numbers")
		assert_true(own.get("albedo") is Texture2D, body + " has its colour picture")
		var dead := BodyBake.load_baked(BodyCast.dead_folder(body))
		assert_eq(int(dead.get("vertices", -1)), int(own["vertices"]), body + "'s dead folder is the same mesh")
		assert_false(PersonVisual.hand_of(own).is_empty(), body + "'s right hand is found")
	for list: Array in BodyCast.BY_ROLE.values():
		for body: String in list:
			assert_has(BodyCast.ALL, body)
	for body: String in BodyCast.BY_ID.values():
		assert_has(BodyCast.ALL, body)


# The squad, the raiders and the work party (thirteen at most) all differ; past
# every body, the next shares the one fewest wear.
func test_no_two_of_the_field_wear_the_same_body() -> void:
	var taken := {}
	var picked := []
	for row in [["p_chief", "chief"], ["p_guard_marek", "companion"], ["p_med_joanna", "companion"], ["p_tail_tomasz", "companion"],
			["npc_raider_1", "raider"], ["npc_raider_2", "raider"], ["npc_raider_3", "raider"],
			["s2_crew_01", "worker"], ["s2_crew_02", "worker"], ["s2_crew_03", "worker"], ["s2_crew_04", "worker"],
			["s2_escort_01", "escort"], ["s2_escort_02", "escort"]]:
		picked.append(BodyCast.pick(row[0], row[1], taken))
	assert_eq(picked[0], "n5-crew_railman-old")
	assert_eq(picked[1], "n5-crew_guard")
	assert_eq(picked[2], "n5-crew_medic")
	assert_eq(picked[4], "n3-body_lumberjack", "a raider in plain clothes")
	for i in picked.size():
		assert_eq(picked.count(picked[i]), 1, "%s worn once" % picked[i])
	var next := BodyCast.pick("someone", "worker", taken)
	assert_eq(int(taken[next]), 2, "the fourteenth shares a body")


# A phone that cannot hold every body sets a cap: past it, a new person wears
# the body fewest wear of those already worn, and the named ones still come first.
func test_a_cap_on_bodies_shares_the_least_worn() -> void:
	var taken := {}
	var picked := []
	for row in [["p_chief", "chief"], ["p_guard_marek", "companion"], ["p_med_joanna", "companion"], ["p_tail_tomasz", "companion"],
			["npc_raider_1", "raider"], ["npc_raider_2", "raider"], ["npc_raider_3", "raider"],
			["s2_crew_01", "worker"], ["s2_crew_02", "worker"], ["s2_crew_03", "worker"], ["s2_crew_04", "worker"],
			["s2_escort_01", "escort"], ["s2_escort_02", "escort"]]:
		picked.append(BodyCast.pick(row[0], row[1], taken, 8))
	var bodies := {}
	for b: String in picked:
		bodies[b] = true
	assert_eq(bodies.size(), 8, "eight bodies for thirteen people")
	assert_eq(picked[0], "n5-crew_railman-old")
	for b: String in taken:
		assert_between(int(taken[b]), 1, 2, b + " worn once or twice")


func test_the_cap_is_read_from_the_project_setting() -> void:
	var was = ProjectSettings.get_setting(PersonVisual.BODIES_SETTING, 0)
	ProjectSettings.set_setting(PersonVisual.BODIES_SETTING, 2)
	var v := PersonVisual.new()
	add_child_autofree(v)
	v.setup(null)
	for row in [["p_chief", "chief"], ["p_guard_marek", "companion"], ["p_med_joanna", "companion"]]:
		v.worn_of(_person(row[0], row[1]))
	ProjectSettings.set_setting(PersonVisual.BODIES_SETTING, was)
	assert_eq(v.taken.size(), 2, "the third shares one of two bodies")


# Drawn: each person is put in their own body's multimesh, read in once.
func test_each_one_is_drawn_in_their_own_body() -> void:
	var v := PersonVisual.new()
	add_child_autofree(v)
	v.setup(null)
	assert_true(v.is_worn())
	var chief := _person("p_chief", "chief")
	var guard := _person("p_guard_marek", "companion")
	var a: Dictionary = v.worn_of(chief)
	var b: Dictionary = v.worn_of(guard)
	assert_eq(String(v.body_by[chief]), "n5-crew_railman-old")
	assert_ne(a["own_draw"], b["own_draw"], "two bodies, two multimeshes")
	assert_same(v.worn_of(chief), a, "read in once")
	assert_true((a["own_vat"] as Dictionary).has("arm"), "the weapon goes in this body's hand")
	assert_ne(a["own_draw"], v.own_draw, "not the reference body")
	# A frame that has read one in already leaves the next for later.
	var raider := _person("npc_raider_1", "raider")
	assert_true(v.worn_of(raider, false).is_empty(), "not read in while it may not be")
	assert_false(v.worn_of(raider).is_empty(), "read in when it may")


# What is worn over the body (WEAR_TINTS) is baked against each body: every
# body has the four garments, cut from its own mesh and lined up with its own
# motions, and its hands marked for the shader's gloves in both its folders
# (the same marks), with no second, gloved colour picture.
func test_every_body_has_its_own_garments_and_its_hands_marked() -> void:
	for body: String in BodyCast.ALL + [PersonVisual.OWN_FOLDER.get_file().trim_suffix(BodyCast.OWN_SUFFIX)]:
		var dir := BodyCast.own_folder(body)
		var own := BodyBake.load_baked(dir)
		var clips := _line_up(own["clips"])
		if body in BodyCast.ALL:
			for kind: String in PersonVisual.WEAR_TINTS:
				var shell := BodyBake.load_baked(dir.path_join("wear").path_join(kind))
				assert_false(shell.is_empty(), body + " " + kind)
				if shell.is_empty():
					continue
				assert_eq(_line_up(shell["clips"]), clips, body + " " + kind + " lines up with the body")
				assert_lt(int(shell["vertices"]), int(own["vertices"]), body + " " + kind + " covers a part of it")
				assert_false(PersonVisual.hands_marked(shell["mesh"]), body + " " + kind + " has no hands to glove")
		var mesh: Mesh = own["mesh"]
		assert_true(PersonVisual.hands_marked(mesh), body + " has its hands marked")
		if not PersonVisual.hands_marked(mesh):
			continue
		var marks: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var hands := 0
		for c in marks:
			hands += 1 if c.a > 0.5 else 0
		assert_between(hands, 20, int(marks.size() * 0.2), body + ": the hands, and only them")
		assert_true(mesh.has_meta(BodyBake.HAND_LIGHT) and float(mesh.get_meta(BodyBake.HAND_LIGHT)) > 0.0, body + " knows the light of its hands")
		var dead: Mesh = BodyBake.load_baked(BodyCast.dead_folder(body))["mesh"]
		assert_true(PersonVisual.hands_marked(dead) and dead.surface_get_arrays(0)[Mesh.ARRAY_COLOR] == marks, body + "'s dead folder has the same marks")
		assert_false(ResourceLoader.exists(dir.path_join("albedo_gloves.png")), body + ": no gloved picture any more")


# Drawn: each body draws its own garments, never the reference body's (which
# would not fit it), and reads one in only when someone in it wears it.
func test_garments_are_drawn_over_the_body_they_were_baked_for() -> void:
	var v := PersonVisual.new()
	add_child_autofree(v)
	v.setup(null)
	assert_true(v.wear_draws.is_empty(), "nothing read in before anyone wears it")
	var chief := _person("p_chief", "chief")
	var marek := _person("p_guard_marek", "companion")
	chief.hat = Wear.make("hat_knit")
	marek.gloves = false
	v.game = {"people": [chief, marek]}
	v._process(0.016)
	v._process(0.016)                     # one body read in a frame
	for p in [chief, marek]:
		var d: Dictionary = v.worn_of(p, false)
		assert_false(d.is_empty(), String(p.pid) + " is drawn")
		assert_ne(d["own_draw"], v.own_draw, String(p.pid) + " in a body of their own")
		var looks := PersonVisual.looks_of(p)
		for kind: String in PersonVisual.WEAR_TINTS:
			assert_eq(d["wear"].has(kind), looks.has(kind), kind + " read in only when " + String(p.pid) + " wears it")
		for worn_look: Dictionary in PersonVisual.looks_on(p):
			var kind: String = worn_look["shell"]
			assert_not_null(d["wear"][kind], kind + " of this body")
			assert_eq(int(d["worn_n"].get(kind, 0)), 1, kind + " drawn over " + String(p.pid))
			var garment := d["wear"][kind] as MultiMeshInstance3D
			assert_eq(garment.multimesh.visible_instance_count, 1, kind + " on show")
			# Each in their own colour (the headless test server keeps no instance colours to read back).
			assert_true(garment.multimesh.use_colors, kind + " in the look of what " + String(p.pid) + " wears")
			assert_true(bool((garment.material_override as ShaderMaterial).get_shader_parameter("worn_look")), kind)
		assert_eq(int(d["k"]), 1, String(p.pid) + " drawn once, gloved or not")
		assert_true(d["own_draw"].multimesh.use_colors, "each one's gloves their own")
		var mat := d["own_draw"].material_override as ShaderMaterial
		assert_true(bool(mat.get_shader_parameter("gloves")), "the shader paints the marked hands")
		assert_false(bool(mat.get_shader_parameter("worn_look")), "the body keeps its own picture")
	assert_eq(PersonVisual.looks_of(chief), ["jacket_short", "hat_knit"] as Array[String])
	assert_true(v.wear_draws.is_empty(), "the reference body's garments are not drawn over another body")
	assert_not_null(v.garment_of(v.worn[""], "coat_long"), "the reference body has its own when worn")


# The bag one carries is on their back (decision 448): every body has both
# bags baked against it, lined up with its motions, behind it and off it, and
# the one carried is drawn over the body as a garment is; with pockets only, none.
func test_the_bag_carried_is_drawn_on_the_back() -> void:
	assert_eq(PersonVisual.BAG_TINTS.keys(), BodyBake.BAG_SHELLS.keys(), "a colour for each bag baked")
	for body: String in BodyCast.ALL + [PersonVisual.OWN_FOLDER.get_file().trim_suffix(BodyCast.OWN_SUFFIX)]:
		var dir := BodyCast.own_folder(body)
		var own := BodyBake.load_baked(dir)
		var rest: PackedVector3Array = (own["mesh"] as Mesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var back := INF
		for p in rest:
			back = minf(back, p.z)
		for kind: String in PersonVisual.BAG_TINTS:
			var bag := BodyBake.load_baked(dir.path_join("wear").path_join(kind))
			assert_false(bag.is_empty(), body + " " + kind)
			if bag.is_empty():
				continue
			assert_eq(_line_up(bag["clips"]), _line_up(own["clips"]), body + " " + kind + " lines up with the body")
			assert_lt(int(bag["width"]), 80, body + " " + kind + " is a few corners")
			var shape: PackedVector3Array = (bag["mesh"] as Mesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var front := -INF
			var rear := INF
			for p in shape:
				front = maxf(front, p.z)
				rear = minf(rear, p.z)
			assert_lt(front, 0.0, body + " " + kind + " is behind the body's middle")
			assert_lt(rear, back, body + " " + kind + " stands out past the back")
			assert_false(PersonVisual.hands_marked(bag["mesh"]), body + " " + kind)
	var v := PersonVisual.new()
	add_child_autofree(v)
	v.setup(null)
	var tomasz := _person("p_tail_tomasz", "companion")
	tomasz.bag = "big_pack"
	var marek := _person("p_guard_marek", "companion")
	marek.bag = "pockets"
	assert_eq(PersonVisual.bag_on(tomasz)[0]["shell"], "big_pack")
	assert_true(PersonVisual.bag_on(marek).is_empty(), "pockets only: no bag")
	v.game = {"people": [tomasz, marek]}
	v._process(0.016)
	v._process(0.016)
	var d: Dictionary = v.worn_of(tomasz, false)
	assert_eq(int(d["worn_n"].get("big_pack", 0)), 1, "the big pack drawn on his back")
	assert_false(d["wear"].has("pack"), "the other bag not read in")
	var m: Dictionary = v.worn_of(marek, false)
	assert_false(m["wear"].has("pack") or m["wear"].has("big_pack"), "nothing on the back with pockets only")


# Each garment over the body is drawn in its own colour and pattern (wear.gd
# look) person by person: the outermost of coat and jacket that has a shell,
# then what is on the head. The gloves are painted in the kind's colour, else
# in the dark wool the gloved picture had.
func test_what_is_worn_is_drawn_in_its_own_colour_and_pattern() -> void:
	var chief := _person("p_chief", "chief")
	chief.worn["coat"] = Wear.make("coat_padded")
	chief.hat = Wear.make("hat_knit")
	var looks := PersonVisual.looks_on(chief)
	assert_eq(PersonVisual.looks_of(chief), ["coat_long", "hat_knit"] as Array[String], "the padded coat over the railway jacket")
	var tint: Array = Wear.look("coat_padded")["look_tint"]
	var coat: Color = looks[0]["colour"]
	assert_true(coat.is_equal_approx(Color(float(tint[0]), float(tint[1]), float(tint[2]), 1.0)), "its own colour, quilted")
	var hat: Color = looks[1]["colour"]
	assert_almost_eq(hat.a, 2.0 / 3.0, 0.0001, "knit")
	chief.worn["coat"] = Wear.make("vest_armor")
	assert_eq(PersonVisual.looks_of(chief)[0], "jacket_short", "a vest with no shell leaves the jacket under it on show")
	assert_almost_eq(PersonVisual.looks_on(chief)[0]["colour"].a, 0.0, 0.0001, "the railway jacket is plain")
	var gloves := PersonVisual.hands_colour(chief)
	assert_true(gloves.is_equal_approx(Color(BodyBake.GLOVE_COLOUR.srgb_to_linear(), 1.0)), "the dark wool of before")
	chief.gloves = false
	assert_eq(PersonVisual.hands_colour(chief).a, 0.0, "bare hands")
	# The dead and the train's people keep the shader as it was: what is worn is
	# the living's alone (person_vat.gdshader defines WORN).
	var dead_shader := FileAccess.get_file_as_string("res://game/actors/dead_vat.gdshader")
	var person_shader := FileAccess.get_file_as_string("res://game/actors/person_vat.gdshader")
	assert_false(dead_shader.contains("#define WORN"))
	assert_true(person_shader.contains("#define WORN"))
	for shader: String in [dead_shader, person_shader]:
		assert_string_contains(shader, "#include \"res://game/actors/dead_vat.gdshaderinc\"")
