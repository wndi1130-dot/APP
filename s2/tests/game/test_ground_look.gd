extends "res://addons/gut/test.gd"
## What lies on the ground is drawn (ground_look.gd, map_view.update_ground): a
## shape of its kind on its floor, no heaps, the shining ones left to their light.

const GroundLook = preload("res://game/world/ground_look.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const TwoLids = preload("res://tests/game/fixtures/two_lids_map.gd")
const MapView = preload("res://game/world/map_view.gd")
const GroundModels = preload("res://game/world/ground_models.gd")
## A mesh keeps vertex colours in 8 bits a channel.
const COLOUR_STEP: float = 1.0 / 255.0

var _old_cache: Dictionary = {}


func before_each() -> void:
	_old_cache = GroundModels.cache_snapshot()
	GroundModels.restore_cache({})


func after_each() -> void:
	GroundModels.restore_cache(_old_cache)


func test_ground_rim_shader_loads_with_its_two_float_controls() -> void:
	var path := "res://fx/shaders/ground_rim.gdshader"
	assert_true(ResourceLoader.exists(path), "ground rims have their own shader")
	if not ResourceLoader.exists(path):
		return
	var shader := load(path) as Shader
	assert_not_null(shader)
	if shader == null:
		return
	var material := ShaderMaterial.new()
	material.shader = shader
	assert_eq(shader.get_mode(), Shader.MODE_SPATIAL)
	# Uniform reflection requests parsing, as in test_fx; GPU drawing is separate.
	var uniforms: Dictionary = {}
	for entry: Dictionary in shader.get_shader_uniform_list():
		uniforms[String(entry["name"])] = entry["type"]
	# Unset defaults are not read back without a renderer (headless gives null),
	# so the declared default is read from the source itself.
	# The shader's own defaults are the game's values, so a bare material looks the same.
	var defaults := {"core": GroundLook.RIM_CORE, "snow_keep": GroundLook.RIM_SNOW_KEEP}
	var declared := RegEx.create_from_string("uniform\\s+float\\s+(\\w+)\\s*:[^=;]*=\\s*([0-9.]+)\\s*;")
	var found: Dictionary = {}
	for hit: RegExMatch in declared.search_all(shader.code):
		found[hit.get_string(1)] = float(hit.get_string(2))
	for name: String in defaults:
		assert_eq(int(uniforms.get(name, -1)), TYPE_FLOAT, name)
		assert_true(found.has(name), name + " declares a default")
		assert_almost_eq(float(found.get(name, -1.0)), float(defaults[name]), 0.000001, name + " default")
	assert_false(uniforms.has("per_instance"))
	assert_false(uniforms.has("rect_custom"))


func test_each_thing_has_a_shape_of_its_kind() -> void:
	var kinds := {
		"knife": "weapon", "undershirt_wool": "garment", "cloth": "cloth", "note_map": "paper",
		"key_3": "paper", "plank": "board", "oats": "sack", "can_beans": "small",
		"ammo_craft": "small", "can_empty": "small", "food_pack": "crate", "rare_can_crate": "big",
		"core_engine": "big",
	}
	for id: String in kinds:
		assert_eq(GroundLook.kind_of({"id": id, "n": 1}), kinds[id], id)
	assert_eq(GroundLook.kind_of({"id": "pipe", "n": 1, "weapon": {"id": "pipe"}}), "weapon", "a dropped weapon row")


func test_no_bag_or_bundle_shape_among_the_looks() -> void:
	# 금지선: no case, bundle or bag by the train; sacks and crates are allowed.
	for kind: String in GroundLook.LOOKS:
		assert_false(kind in ["bag", "case", "bundle", "suitcase"], kind)
	assert_eq(GroundLook.kind_of({"id": "found_big_pack", "n": 1}), "small", "a found pack is not drawn as a bag")


func test_the_shining_ones_are_left_to_their_light() -> void:
	var items := [
		{"pos": Vector3(5.5, 0, 5.5), "id": "hare_frozen", "n": 1, "glint": true},
		{"pos": Vector3(9.5, 0, 9.5), "id": "plank", "n": 1},
	]
	var out: Array = GroundLook.pieces(items)
	assert_eq(out.size(), 1)
	var c: Color = out[0]["color"]
	var seen: Color = GroundLook.LOOKS["board"][1]
	assert_almost_eq(c.r, seen.r, 0.0001, "as seen (sRGB): the world shader makes it linear")
	assert_almost_eq(c.b, seen.b, 0.0001)
	assert_eq(c.a, 0.0, "no snow laid over it in the world shader")


func test_things_at_one_spot_are_spread_and_never_more_than_three_drawn() -> void:
	# What a fallen one had all falls where it fell (field_game.gd): no heap.
	var at := Vector3(12.4, 0, 7.6)
	var items: Array = []
	for id: String in ["can_beans", "plank", "cloth", "oats", "knife", "note_map"]:
		items.append({"pos": at, "id": id, "n": 1})
	var out: Array = GroundLook.pieces(items)
	assert_eq(out.size(), GroundLook.PER_CELL)
	var biggest: Dictionary = out[0]
	for piece: Dictionary in out:
		if (piece["size"] as Vector3).x * (piece["size"] as Vector3).z > (biggest["size"] as Vector3).x * (biggest["size"] as Vector3).z:
			biggest = piece
	assert_almost_eq(Vector2(biggest["at"].x, biggest["at"].z).distance_to(Vector2(at.x, at.z)), 0.0, 0.001, "the biggest lies where it was put")
	var spots := {}
	for piece: Dictionary in out:
		var flat := Vector2(piece["at"].x, piece["at"].z)
		assert_true(flat.distance_to(Vector2(at.x, at.z)) < 0.9, "within a tap of where it lies")
		spots[flat.snapped(Vector2(0.01, 0.01))] = true
	assert_eq(spots.size(), out.size(), "none on top of another")
	_assert_gaps(out)
	# Another cell gets its own three.
	items.append({"pos": at + Vector3(3, 0, 0), "id": "cloth", "n": 1})
	assert_eq(GroundLook.pieces(items).size(), GroundLook.PER_CELL + 1)


## 11-07 shots: three clothes at real size on one cell lay on one another (a heap,
## the 금지선) and a knife was lost under a shirt. Now each lies clear of the rest.
func test_clothes_and_a_knife_on_one_cell_lie_clear_of_one_another() -> void:
	var at := Vector3(20.5, 0, 9.5)
	for ids: Array in [["coat_long", "shirt_flannel", "trousers_work", "boots_work"], ["knife", "shirt_cotton", "can_beans"]]:
		var items: Array = []
		for id: String in ids:
			items.append({"pos": at, "id": id, "n": 1})
		var out: Array = GroundLook.pieces(items)
		# Open floor and nothing else near: there is room for all three, so none is
		# left undrawn (omitting is only for a spot with no clear room at all).
		assert_eq(out.size(), mini(ids.size(), GroundLook.PER_CELL), "all three drawn on open floor")
		for i: int in out.size():
			var a: Dictionary = out[i]
			var flat_a := Vector2(a["at"].x, a["at"].z)
			assert_lte(flat_a.distance_to(Vector2(at.x, at.z)), GroundLook.SPREAD_MAX + 0.0001, "%s within reach of its spot" % ids[i])
			for j: int in range(i + 1, out.size()):
				var b: Dictionary = out[j]
				var gap: float = GroundLook.footprint_gap(flat_a, Vector2(a["size"].x, a["size"].z), a["yaw"],
					Vector2(b["at"].x, b["at"].z), Vector2(b["size"].x, b["size"].z), b["yaw"])
				assert_gte(gap, GroundLook.SPREAD_GAP - 0.000001, "%s and %s keep their rims apart" % [ids[i], ids[j]])
		assert_eq(GroundLook.pieces(items), out, "the same list lies the same")
		_assert_gaps(out)


func test_footprint_gap_is_the_room_between_turned_rectangles() -> void:
	assert_almost_eq(GroundLook.footprint_gap(Vector2.ZERO, Vector2.ONE, 0.0, Vector2(3, 0), Vector2.ONE, 0.0), 2.0, 0.0001, "side by side")
	assert_almost_eq(GroundLook.footprint_gap(Vector2.ZERO, Vector2(2, 1), 0.0, Vector2(0, 2), Vector2(2, 1), 0.0), 1.0, 0.0001, "one above the other")
	assert_lt(GroundLook.footprint_gap(Vector2.ZERO, Vector2.ONE, 0.0, Vector2(0.5, 0), Vector2.ONE, 0.0), 0.0, "overlapping")
	# A long thin thing turned a quarter lies along z: it clears one beside it on x.
	assert_gt(GroundLook.footprint_gap(Vector2.ZERO, Vector2(2, 0.2), PI * 0.5, Vector2(0.5, 0), Vector2(0.2, 0.2), 0.0), 0.0)
	assert_lt(GroundLook.footprint_gap(Vector2.ZERO, Vector2(2, 0.2), 0.0, Vector2(0.5, 0), Vector2(0.2, 0.2), 0.0), 0.0, "unturned it covers it")
	# Two squares turned 45 degrees, 2 m apart on x: measured along their own edge
	# normals (the separating axes), 2·cos45 apart less a side each.
	assert_almost_eq(GroundLook.footprint_gap(Vector2.ZERO, Vector2.ONE, PI * 0.25, Vector2(2, 0), Vector2.ONE, PI * 0.25), sqrt(2.0) - 1.0, 0.0001)
	# Turned unlike each other: a square on its corner reaches √2/2 along x, so to a
	# straight one 2 m off it is 2 - √2/2 - 1/2, measured either way round.
	var mixed: float = 1.5 - sqrt(2.0) * 0.5
	assert_almost_eq(GroundLook.footprint_gap(Vector2.ZERO, Vector2.ONE, PI * 0.25, Vector2(2, 0), Vector2.ONE, 0.0), mixed, 0.0001, "corner to side")
	assert_almost_eq(GroundLook.footprint_gap(Vector2(2, 0), Vector2.ONE, 0.0, Vector2.ZERO, Vector2.ONE, PI * 0.25), mixed, 0.0001, "side to corner")


## The quick gap (each rectangle's sides turned once, its own reach taken as its
## half side) agrees with the plain one on long, thin, turned things at any angle.
func test_footprint_gap_agrees_with_the_plain_working() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1107
	for n: int in 300:
		var ca := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		var cb := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		var sa := Vector2(rng.randf_range(0.02, 1.2), rng.randf_range(0.02, 1.2))
		var sb := Vector2(rng.randf_range(0.02, 1.2), rng.randf_range(0.02, 1.2))
		var ya: float = rng.randf_range(-TAU, TAU)
		var yb: float = rng.randf_range(-TAU, TAU)
		assert_almost_eq(GroundLook.footprint_gap(ca, sa, ya, cb, sb, yb), _plain_gap(ca, sa, ya, cb, sb, yb), 0.00001, "case %d" % n)


## The quick checks that skip far pairs give the four-axis answer: clear exactly
## when the gap is SPREAD_GAP or more, and the same burial whenever one overlaps.
func test_the_far_pair_shortcut_agrees_with_the_full_gap() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1508
	for n: int in 400:
		var a := GroundLook.Footprint.new(Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)), Vector2(rng.randf_range(0.02, 1.2), rng.randf_range(0.02, 1.2)), rng.randf_range(-TAU, TAU))
		var b := GroundLook.Footprint.new(Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)), Vector2(rng.randf_range(0.02, 1.2), rng.randf_range(0.02, 1.2)), rng.randf_range(-TAU, TAU))
		var full: float = a.gap_to(b)
		var pair: Array[GroundLook.Footprint] = [b]
		assert_eq(GroundLook._clear_of(a, pair, GroundLook.SPREAD_GAP), full >= GroundLook.SPREAD_GAP, "case %d" % n)
		var room: float = GroundLook._wall_room(a, pair)
		if full < 0.0:
			assert_almost_eq(room, full, 0.000001, "case %d buried" % n)
		else:
			assert_gte(room, 0.0, "case %d clear" % n)


func test_diagonal_clearance_uses_the_four_axis_gap() -> void:
	var foot := GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.2, 0.2), 0.0)
	var other := GroundLook.Footprint.new(Vector2(0.23, 0.23), Vector2(0.2, 0.2), 0.0)
	var laid: Array[GroundLook.Footprint] = [other]
	assert_almost_eq(foot.gap_to(other), 0.03, 0.000001)
	assert_lt(foot.gap_to(other), GroundLook.SPREAD_GAP)
	assert_eq(GroundLook._clear_of(foot, laid, GroundLook.SPREAD_GAP), foot.gap_to(other) >= GroundLook.SPREAD_GAP)


func test_diagonal_clearance_skips_the_first_far_spot() -> void:
	var foot := GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.2, 0.2), 0.0)
	var laid: Array[GroundLook.Footprint] = [GroundLook.Footprint.new(Vector2(0.27, -0.23), Vector2(0.2, 0.2), 0.0)]
	assert_true(GroundLook._clear_spot(foot, 0.0, laid))
	assert_almost_eq(foot.centre.x, 0.55, 0.000001, "the 0.5 m candidate has only 0.03 m on either axis")
	assert_almost_eq(foot.centre.y, 0.0, 0.000001)
	assert_eq(foot.yaw, 0.0)
	assert_gte(foot.gap_to(laid[0]), GroundLook.SPREAD_GAP)


## Aim at diagonal boundaries deliberately; random centres rarely land here.
func test_diagonal_boundaries_agree_with_the_full_gap_at_several_rotations() -> void:
	for yaw: float in [0.0, 0.37, PI * 0.5, -1.1]:
		for relative_yaw: float in [0.0, -0.03, 0.03]:
			var foot := GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.2, 0.2), yaw)
			var other := GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.2, 0.2), yaw + relative_yaw)
			var laid: Array[GroundLook.Footprint] = [other]
			var reverse: Array[GroundLook.Footprint] = [foot]
			for degrees: float in [44.0, 45.0, 46.0]:
				var angle: float = deg_to_rad(degrees)
				var direction: Vector2 = foot.along_x * cos(angle) + foot.along_z * sin(angle)
				for gap: float in [0.02, GroundLook.SPREAD_GAP, 0.06]:
					for offset: float in [-0.01, -0.001, 0.0, 0.001, 0.01]:
						other.centre = direction * sqrt(2.0) * (0.2 + gap + offset)
						var context := "yaw %.2f relative %.2f direction %.0f gap %.3f offset %.3f" % [yaw, relative_yaw, degrees, gap, offset]
						assert_eq(GroundLook._clear_of(foot, laid, gap), foot.gap_to(other) >= gap, context)
						assert_eq(GroundLook._clear_of(other, reverse, gap), other.gap_to(foot) >= gap, context + " reversed")


func test_padded_gap_matches_plain_sat_and_clearance_uses_bare_feet() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1508
	for n: int in 400:
		var ca := Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
		var sa := Vector2(rng.randf_range(0.02, 1.2), rng.randf_range(0.02, 1.2))
		var ya: float = rng.randf_range(-TAU, TAU)
		var cb := Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
		var sb := Vector2(rng.randf_range(0.02, 1.2), rng.randf_range(0.02, 1.2))
		var yb: float = rng.randf_range(-TAU, TAU)
		var a := GroundLook.Footprint.new(ca, sa, ya, GroundLook.RIM)
		var b := GroundLook.Footprint.new(cb, sb, yb, GroundLook.RIM)
		var pair: Array[GroundLook.Footprint] = [b]
		var reverse: Array[GroundLook.Footprint] = [a]
		var full: float = a.rim_gap_to(b)
		var pad := Vector2.ONE * (2.0 * GroundLook.RIM)
		assert_almost_eq(full, _plain_gap(ca, sa + pad, ya, cb, sb + pad, yb), 0.00001, "padded case %d" % n)
		assert_almost_eq(GroundLook.rim_gap(ca, sa, ya, cb, sb, yb), full, 0.00001)
		assert_eq(GroundLook._clear_of(a, pair, GroundLook.SPREAD_GAP), a.gap_to(b) >= GroundLook.SPREAD_GAP, "padded case %d" % n)
		assert_eq(GroundLook._clear_of(b, reverse, GroundLook.SPREAD_GAP), b.gap_to(a) >= GroundLook.SPREAD_GAP, "reversed case %d" % n)
		# Padding must not change the footprint used against walls.
		var bare: float = _plain_gap(ca, sa, ya, cb, sb, yb)
		assert_almost_eq(a.gap_to(b), bare, 0.00001)
		if bare < 0.0:
			assert_almost_eq(GroundLook._wall_room(a, pair), bare, 0.00001)
		else:
			assert_gte(GroundLook._wall_room(a, pair), 0.0)
		assert_almost_eq(GroundLook.Footprint.new(ca, sa, ya).rim_gap_to(GroundLook.Footprint.new(cb, sb, yb)), bare, 0.00001, "zero padding keeps the old gap")


func test_padded_diagonal_boundaries_agree_with_the_full_rim_gap() -> void:
	for yaw: float in [0.0, 0.37, PI * 0.5, -1.1]:
		for relative_yaw: float in [0.0, -0.03, 0.03]:
			var foot := GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.2, 0.2), yaw, GroundLook.RIM)
			var other := GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.2, 0.2), yaw + relative_yaw, GroundLook.RIM)
			var laid: Array[GroundLook.Footprint] = [other]
			var reverse: Array[GroundLook.Footprint] = [foot]
			for degrees: float in [44.0, 45.0, 46.0]:
				var angle: float = deg_to_rad(degrees)
				var direction: Vector2 = foot.along_x * cos(angle) + foot.along_z * sin(angle)
				for gap: float in [0.01, GroundLook.SPREAD_GAP, 0.06]:
					for offset: float in [-0.01, -0.001, 0.0, 0.001, 0.01]:
						other.centre = direction * sqrt(2.0) * (0.2 + 2.0 * GroundLook.RIM + gap + offset)
						var context := "padded yaw %.2f relative %.2f direction %.0f gap %.3f offset %.3f" % [yaw, relative_yaw, degrees, gap, offset]
						var size := Vector2.ONE * (0.2 + 2.0 * GroundLook.RIM)
						var plain: float = _plain_gap(foot.centre, size, foot.yaw, other.centre, size, other.yaw)
						assert_almost_eq(foot.rim_gap_to(other), plain, 0.000001, context)
						assert_almost_eq(other.rim_gap_to(foot), plain, 0.000001, context + " reversed")
						assert_eq(GroundLook._clear_of(foot, laid, gap), foot.gap_to(other) >= gap, context)
						assert_eq(GroundLook._clear_of(other, reverse, gap), other.gap_to(foot) >= gap, context + " reversed")


func test_turned_rim_corners_overlap_despite_twice_the_padding_between_feet() -> void:
	var size := Vector2(0.2, 0.2)
	var corner_pad: float = (1.0 + sqrt(2.0)) * GroundLook.RIM
	var bare_gap: float = (2.0 * GroundLook.RIM + GroundLook.SPREAD_GAP + corner_pad) * 0.5
	var centre := Vector2(0.1 + sqrt(2.0) * 0.1 + bare_gap, 0.0)
	var foot := GroundLook.Footprint.new(Vector2.ZERO, size, 0.0, GroundLook.RIM)
	var other := GroundLook.Footprint.new(centre, size, PI * 0.25, GroundLook.RIM)
	var laid: Array[GroundLook.Footprint] = [other]
	assert_gt(foot.gap_to(other), 2.0 * GroundLook.RIM + GroundLook.SPREAD_GAP)
	assert_almost_eq(foot.rim_gap_to(other), bare_gap - corner_pad, 0.000001)
	assert_lt(foot.rim_gap_to(other), 0.0, "the rotated rim reaches further than twice RIM")
	assert_true(GroundLook._clear_of(foot, laid, GroundLook.SPREAD_GAP), "rims shrink after placement")


func test_rim_may_enter_a_wall_when_the_footprint_fits() -> void:
	var foot := GroundLook.Footprint.new(Vector2(0.89, 0.5), Vector2(0.2, 0.2), 0.0, GroundLook.RIM)
	var wall := GroundLook.Footprint.new(Vector2(1.5, 0.5), Vector2.ONE, 0.0)
	var walls: Array[GroundLook.Footprint] = [wall]
	var none: Array[GroundLook.Footprint] = []
	assert_lt(foot.rim_gap_to(wall), 0.0)
	assert_almost_eq(GroundLook._wall_room(foot, walls), 0.01, 0.000001)
	assert_true(GroundLook._clear_spot(foot, 0.0, none, walls, true))
	assert_eq(foot.centre, Vector2(0.89, 0.5), "rim overlap alone must not move the thing")


## Every one of the four side directions, each rectangle reaching along it by
## both its sides.
func _plain_gap(ca: Vector2, sa: Vector2, ya: float, cb: Vector2, sb: Vector2, yb: float) -> float:
	var sides: Array = []
	for yaw: float in [ya, yb]:
		var turn := Basis(Vector3.UP, yaw)
		var x3: Vector3 = turn * Vector3.RIGHT
		var z3: Vector3 = turn * Vector3.BACK
		sides.append([Vector2(x3.x, x3.z), Vector2(z3.x, z3.z)])
	var best: float = -INF
	for axis: Vector2 in sides[0] + sides[1]:
		var reach_a: float = absf(axis.dot(sides[0][0])) * sa.x * 0.5 + absf(axis.dot(sides[0][1])) * sa.y * 0.5
		var reach_b: float = absf(axis.dot(sides[1][0])) * sb.x * 0.5 + absf(axis.dot(sides[1][1])) * sb.y * 0.5
		best = maxf(best, absf(axis.dot(cb - ca)) - reach_a - reach_b)
	return best


## Start at half a metre; never keep a spot that overlaps another thing.
func test_a_clear_spot_starts_far_and_omits_overlap() -> void:
	var laid: Array[GroundLook.Footprint] = [GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.2, 0.2), 0.0)]
	var small := GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.2, 0.2), 0.0)
	assert_true(GroundLook._clear_spot(small, 0.0, laid))
	assert_almost_eq(small.centre.x, 0.5, 0.0001, "clear at the first far try")
	assert_almost_eq(small.centre.y, 0.0, 0.0001)
	var down := GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.2, 0.2), PI * 0.5)
	assert_true(GroundLook._clear_spot(down, PI * 0.5, laid))
	assert_almost_eq(down.centre.y, 0.5, 0.0001, "out along its own angle")
	var under: Array[GroundLook.Footprint] = [GroundLook.Footprint.new(Vector2.ZERO, Vector2(2, 2), 0.0)]
	var lost := GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.5, 0.5), 0.0)
	assert_false(GroundLook._clear_spot(lost, 0.0, under), "no clear candidate means no drawing")
	var crowded: Array = [_piece(0, Vector3.ZERO, Vector3(2, 0.1, 2)), _piece(1, Vector3.ZERO, Vector3(0.5, 0.1, 0.5))]
	assert_eq(GroundLook._lay_apart(crowded, {Vector3i.ZERO: [0, 1]}, Callable()).size(), 1)
	# The review's 22 degree counterexample: the eight angles round 22 degrees miss
	# the clear spot straight along x (0.05 m of room) and the old search laid it
	# overlapping; the wide search finds a spot SPREAD_GAP clear.
	var square := GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.65, 0.65), 0.0)
	var squares: Array[GroundLook.Footprint] = [GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.65, 0.65), 0.0)]
	assert_true(GroundLook._clear_spot(square, deg_to_rad(22.0), squares))
	assert_gte(square.gap_to(squares[0]), GroundLook.SPREAD_GAP - 0.000001)
	assert_lte(square.centre.length(), GroundLook.SPREAD_MAX + 0.0001)


## The tries worked out one at a time (try_at, a turned table) are the list the
## plain working gives — own angle far then near, eight round at SPREAD_MAX, the
## wide rings, then all again a quarter turned; home tries both yaws in place first.
## Only the first wide ring's repeats of the earlier eight directions are removed.
func test_tries_one_at_a_time_match_the_plain_list() -> void:
	assert_almost_eq(GroundLook.SPREAD + GroundLook.SPREAD_STEP * (GroundLook.FAR_TRIES - 1), GroundLook.SPREAD_MAX, 0.00001)
	assert_almost_eq(GroundLook.SPREAD_NEAR + GroundLook.SPREAD_STEP * (GroundLook.NEAR_TRIES - 1), GroundLook.SPREAD_NEAR_MAX, 0.00001)
	assert_eq(GroundLook.WIDE_RINGS.size(), 3, "SPIN_TRIES counts three wide rings")
	assert_eq(GroundLook.WIDE_RINGS[0], GroundLook.SPREAD_MAX, "only this wide ring repeats the earlier eight directions")
	for turn: float in [0.0, 0.7, -2.4, 5.9]:
		for home: bool in [false, true]:
			var plain: Array[Vector3] = []
			if home:
				plain.append_array([Vector3.ZERO, Vector3(0, 0, 1)])
			for spin: int in 2:
				for k: int in GroundLook.FAR_TRIES:
					var d: float = GroundLook.SPREAD + GroundLook.SPREAD_STEP * k
					plain.append(Vector3(cos(turn) * d, sin(turn) * d, spin))
				for k: int in GroundLook.NEAR_TRIES:
					var d: float = GroundLook.SPREAD_NEAR + GroundLook.SPREAD_STEP * k
					plain.append(Vector3(cos(turn) * d, sin(turn) * d, spin))
				for step: int in 8:
					var angle: float = turn + TAU * step / 8.0
					plain.append(Vector3(cos(angle) * GroundLook.SPREAD_MAX, sin(angle) * GroundLook.SPREAD_MAX, spin))
				for ring: float in GroundLook.WIDE_RINGS:
					for step: int in GroundLook.WIDE_ANGLES:
						var angle: float = turn + TAU * step / float(GroundLook.WIDE_ANGLES)
						plain.append(Vector3(cos(angle) * ring, sin(angle) * ring, spin))
			# Build the old full list above, then keep the first of each repeated
			# outer-ring candidate. Straight-range candidates keep their old order.
			var unique: Array[Vector3] = []
			var home_count: int = 2 if home else 0
			var old_spin_count: int = GroundLook.FAR_TRIES + GroundLook.NEAR_TRIES + 8 + GroundLook.WIDE_ANGLES * GroundLook.WIDE_RINGS.size()
			var round_start: int = GroundLook.FAR_TRIES + GroundLook.NEAR_TRIES
			for index: int in plain.size():
				var repeated := false
				if index >= home_count:
					var within_spin: int = (index - home_count) % old_spin_count
					if within_spin >= round_start + 8 and within_spin < round_start + 8 + GroundLook.WIDE_ANGLES:
						var first_round: int = index - within_spin + round_start
						for earlier: int in range(first_round, first_round + 8):
							if plain[index].distance_to(plain[earlier]) < 0.000001:
								repeated = true
								break
				if not repeated:
					unique.append(plain[index])
			assert_eq(plain.size() - unique.size(), 16, "eight later duplicates removed at each yaw")
			assert_eq(GroundLook.try_count(home), unique.size())
			var way := Vector2(cos(turn), sin(turn))
			for index: int in unique.size():
				var got: Vector3 = GroundLook.try_at(index, home, way)
				assert_true(got.is_equal_approx(unique[index]) or got.distance_to(unique[index]) < 0.000001, "try %d at %.1f" % [index, turn])


func test_home_turns_in_place_before_moving_away_from_a_wall() -> void:
	var origin := Vector2(10.5, 10.5)
	var size := Vector2(1.2, 0.2)
	var foot := GroundLook.Footprint.new(origin, size, 0.0)
	var walls: Array[GroundLook.Footprint] = [GroundLook.Footprint.new(Vector2(11.5, 10.5), Vector2.ONE, 0.0)]
	var none: Array[GroundLook.Footprint] = []
	assert_lt(GroundLook._wall_room(foot, walls), 0.0, "the original yaw is buried")
	var moved := GroundLook.Footprint.new(Vector2(10.0, 10.5), size, 0.0)
	assert_gte(GroundLook._wall_room(moved, walls), 0.0, "moving left would also fit")
	assert_true(GroundLook._clear_spot(foot, PI, none, walls, true))
	assert_eq(foot.centre, origin, "keep the biggest thing at its pick-up position")
	assert_almost_eq(foot.yaw, PI * 0.5, 0.000001)
	assert_gte(GroundLook._wall_room(foot, walls), 0.0)


## A 1.2 m plank in a one-metre corridor stays on its spot after a quarter turn.
func test_a_quarter_turn_is_tried_before_giving_up() -> void:
	var walls: Array[GroundLook.Footprint] = []
	for x: int in range(-3, 4):
		walls.append(GroundLook.Footprint.new(Vector2(x + 0.5, -0.5), Vector2.ONE, 0.0))
		walls.append(GroundLook.Footprint.new(Vector2(x + 0.5, 1.5), Vector2.ONE, 0.0))
	var none: Array[GroundLook.Footprint] = []
	var plank := GroundLook.Footprint.new(Vector2(0.5, 0.5), Vector2(0.1, 1.2), 0.0)
	assert_true(GroundLook._clear_spot(plank, 0.3, none, walls, true))
	assert_almost_eq(plank.yaw, PI * 0.5, 0.0001, "turned along the corridor")
	assert_eq(plank.centre, Vector2(0.5, 0.5), "on its own spot")
	assert_gte(GroundLook._room_among(plank, walls), 0.0, "off both walls")
	var pieces: Array = GroundLook.pieces([{"id": "no_art_550", "pos": Vector3(0.5, 0, 0.5)}])
	assert_eq(pieces.size(), 1)
	assert_true(pieces[0].has("yaw"), "the piece carries the yaw it was laid at")


func _piece(item: int, at: Vector3, size: Vector3, turn: float = 0.0) -> Dictionary:
	return {"item": item, "lv": roundi(at.y / 3.0), "at": at, "size": size, "yaw": 0.0, "turn": turn}


func test_far_then_near_then_ring_and_wall_fallback() -> void:
	var none: Array[GroundLook.Footprint] = []
	var foot := GroundLook.Footprint.new(Vector2(0.5, 0.5), Vector2(0.2, 0.2), 0.0)
	var wall: Array[GroundLook.Footprint] = [GroundLook.Footprint.new(Vector2(1.5, 0.5), Vector2.ONE, 0.0)]
	assert_true(GroundLook._clear_spot(foot, 0.0, none, wall))
	assert_almost_eq(foot.centre.x, 0.8, 0.00001, "only after all far tries touch the wall")
	var other: Array[GroundLook.Footprint] = [GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.9, 0.1), 0.0)]
	foot = GroundLook.Footprint.new(Vector2.ZERO, Vector2(0.5, 0.1), 0.0)
	assert_true(GroundLook._clear_spot(foot, 0.0, other))
	assert_almost_eq(foot.centre.distance_to(Vector2.ZERO), 0.7, 0.00001, "turn round only after both straight ranges")
	assert_gt(foot.centre.y, 0.0)
	var coat: Array = [_piece(0, Vector3(0.5, 0, 0.5), Vector3(1.2, 0.1, 1.1))]
	var corridor := func(c: Vector2i, _lv: int) -> bool: return c.x != 0
	var out: Array = GroundLook._lay_apart(coat, {Vector3i.ZERO: [0]}, corridor)
	assert_eq(out.size(), 1, "a wide coat still lies in a one metre corridor")
	assert_eq(out[0]["at"], Vector3(0.5, 0, 0.5), "the least buried candidate wins, first of equals")
	assert_almost_eq(out[0]["yaw"], PI * 0.5, 0.00001, "the narrower side buries least")
	for x: float in [-0.5, 1.5]:
		assert_almost_eq(GroundLook.footprint_gap(Vector2(0.5, 0.5), Vector2(1.2, 1.1), out[0]["yaw"], Vector2(x, 0.5), Vector2(1, 10), 0.0), -0.05, 0.00001)
	var fitting: Array = GroundLook._lay_apart([_piece(0, Vector3(0.5, 0, 0.5), Vector3(1.2, 0.1, 0.6))], {Vector3i.ZERO: [0]}, corridor)
	assert_almost_eq(fitting[0]["yaw"], PI * 0.5, 0.00001, "a narrower coat fits after turning")


func test_rotated_search_keeps_neighbours_across_the_cell_boundary() -> void:
	var pieces: Array = [
		_piece(0, Vector3(10.5, 0, 9.96), Vector3(0.02, 0.1, 0.02)),
		_piece(1, Vector3(10.5, 0, 10.8), Vector3(1.7, 0.1, 0.1)),
	]
	var blocked := func(c: Vector2i, _lv: int) -> bool: return c == Vector2i(11, 10)
	var out: Array = GroundLook._lay_apart(pieces, {Vector3i(10, 9, 0): [0], Vector3i(10, 10, 0): [1]}, blocked)
	assert_eq(out.size(), 2, "both fit without dropping the small neighbour")
	_assert_gaps(_with_rims(out))
	for piece: Dictionary in out:
		assert_gte(GroundLook.footprint_gap(Vector2(piece["at"].x, piece["at"].z), Vector2(piece["size"].x, piece["size"].z), piece["yaw"], Vector2(11.5, 10.5), Vector2.ONE, 0.0), -0.000001)


func test_cell_order_cross_cell_gap_and_blocked_cells() -> void:
	var items := [{"id": "no_art_550", "pos": Vector3(0.9, 0, 0.5)}, {"id": "no_art_550", "pos": Vector3(1.1, 0, 0.5)}]
	var out: Array = GroundLook.pieces(items)
	assert_eq(out.size(), 2)
	_assert_gaps(out)
	var pieces: Array = [_piece(0, Vector3(1.1, 0, 0.5), Vector3(0.3, 0.1, 0.3)), _piece(1, Vector3(0.9, 0, 0.5), Vector3(0.3, 0.1, 0.3)), _piece(2, Vector3(0.9, 0, 0.5), Vector3(0.2, 0.1, 0.2))]
	out = GroundLook._lay_apart(pieces, {Vector3i(1, 0, 0): [0], Vector3i.ZERO: [2, 1]}, Callable())
	assert_eq(out[1]["at"], Vector3(0.9, 0, 0.5), "left cell's biggest is placed before the right cell")
	_assert_gaps(_with_rims(out))
	var blocked := func(c: Vector2i, lv: int) -> bool: return lv == 0 and c == Vector2i.ZERO
	out = GroundLook.pieces([{"id": "no_art_550", "pos": Vector3(0.9, 0, 0.5)}], blocked)
	assert_eq(out.size(), 1)
	var p: Dictionary = out[0]
	assert_gte(GroundLook.footprint_gap(Vector2(p["at"].x, p["at"].z), Vector2(p["size"].x, p["size"].z), p["yaw"], Vector2(0.5, 0.5), Vector2.ONE, 0.0), 0.0)
	assert_eq(GroundLook.pieces(items), GroundLook.pieces(items), "same list, same positions")


func _assert_gaps(out: Array) -> void:
	for piece: Dictionary in out:
		assert_true(piece.has("rim"), "every drawn piece carries its width")
		assert_gte(float(piece.get("rim", -1.0)), 0.0)
		assert_lte(float(piece.get("rim", INF)), GroundLook.RIM)
	for i: int in out.size():
		for j: int in range(i + 1, out.size()):
			var a: Dictionary = out[i]
			var b: Dictionary = out[j]
			if a["lv"] == b["lv"]:
				assert_gte(GroundLook.footprint_gap(Vector2(a["at"].x, a["at"].z), Vector2(a["size"].x, a["size"].z), a["yaw"], Vector2(b["at"].x, b["at"].z), Vector2(b["size"].x, b["size"].z), b["yaw"]), GroundLook.SPREAD_GAP - 0.000001)
				# Use the actual drawn quads and an independent SAT, not the clearance shortcut.
				var ra: Dictionary = GroundLook.rim(a)
				var rb: Dictionary = GroundLook.rim(b)
				var ca := Vector2(ra["at"].x, ra["at"].z)
				var cb := Vector2(rb["at"].x, rb["at"].z)
				var gap: float = _plain_gap(ca, ra["size"], ra["yaw"], cb, rb["size"], rb["yaw"])
				assert_gte(gap, GroundLook.RIM_SPACE - 0.00001, "drawn rims %d and %d" % [i, j])


## Internal placement tests apply the same separate width pass as pieces().
func _with_rims(out: Array) -> Array:
	var widths: Array[float] = GroundLook._rim_widths(out)
	for i: int in out.size():
		out[i]["rim"] = widths[i]
	return out


func test_three_hundred_drawn_things_keep_all_rim_pairs_apart() -> void:
	var pieces: Array = []
	var items: Array = []
	var on_cell: Dictionary = {}
	for y: int in 10:
		for x: int in 10:
			var cell := Vector3i(x * 3, y * 3, 0)
			var at := Vector3(cell.x + 0.5, 0, cell.y + 0.5)
			var slots: Array = []
			for k: int in 3:
				items.append({"id": "no_art_550", "pos": at})
				slots.append(pieces.size())
				var piece := _piece(pieces.size(), at, Vector3(0.2, 0.1, 0.2), TAU * k / 3.0)
				piece["yaw"] = deg_to_rad(float((x * 17 + y * 23 + k * 31) % 360))
				pieces.append(piece)
			on_cell[cell] = slots
	var out: Array = GroundLook._lay_apart(pieces, on_cell, Callable())
	assert_eq(out.size(), 300, "three small things fit on each open cell")
	_assert_gaps(_with_rims(out))
	var drawn: Array = GroundLook.pieces(items)
	assert_eq(drawn.size(), 300, "the public path keeps every item too")
	_assert_gaps(drawn)
	assert_eq(GroundLook.pieces(items), drawn, "same list, same positions and widths")


func test_rim_width_pair_limit_is_exact_for_three_hundred_random_pairs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41107
	for n: int in 300:
		var ca := Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
		var sa := Vector2(rng.randf_range(0.02, 1.2), rng.randf_range(0.02, 1.2))
		var sb := Vector2(rng.randf_range(0.02, 1.2), rng.randf_range(0.02, 1.2))
		var ya: float = rng.randf_range(-TAU, TAU)
		var yb: float = rng.randf_range(-TAU, TAU)
		var direction := Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
		var bare_gap: float = rng.randf_range(0.04, 0.16)
		# Find a separated pair using independent SAT, without the width formula.
		var low := 0.0
		var high := 4.0
		for step: int in 28:
			var mid: float = (low + high) * 0.5
			if _plain_gap(ca, sa, ya, ca + direction * mid, sb, yb) < bare_gap:
				low = mid
			else:
				high = mid
		var cb: Vector2 = ca + direction * high
		var a := GroundLook.Footprint.new(ca, sa, ya)
		var b := GroundLook.Footprint.new(cb, sb, yb)
		var width: float = GroundLook._rim_limit(a, b)
		assert_gt(width, 0.0, "case %d has an interior limit" % n)
		assert_lt(width, GroundLook.RIM)
		assert_almost_eq(width, GroundLook._rim_limit(b, a), 0.000001)
		var padded_a := GroundLook.Footprint.new(ca, sa, ya, width)
		var padded_b := GroundLook.Footprint.new(cb, sb, yb, width)
		assert_almost_eq(padded_a.rim_gap_to(padded_b), GroundLook.RIM_SPACE, 0.00001)
		var pad := Vector2.ONE * (2.0 * width)
		assert_almost_eq(_plain_gap(ca, sa + pad, ya, cb, sb + pad, yb), GroundLook.RIM_SPACE, 0.00001)
		var wider_a := GroundLook.Footprint.new(ca, sa, ya, width + 0.001)
		var wider_b := GroundLook.Footprint.new(cb, sb, yb, width + 0.001)
		assert_lt(wider_a.rim_gap_to(wider_b), GroundLook.RIM_SPACE)


func test_rim_buckets_match_all_pairs_without_moving_or_mutating_pieces() -> void:
	var pieces: Array = [
		_piece(0, Vector3(-4, 0, -1), Vector3(8, 0.1, 0.2)),
		_piece(1, Vector3(0.15, 0, -1), Vector3(0.2, 0.1, 0.2)),
		_piece(2, Vector3(0.15, 3, -1), Vector3(0.2, 0.1, 0.2)),
		_piece(3, Vector3(-0.15, 0, 2), Vector3(0.2, 0.1, 0.2)),
		_piece(4, Vector3(0.15, 0, 2), Vector3(0.2, 0.1, 0.2)),
	]
	pieces[4]["yaw"] = PI * 0.25
	var rng := RandomNumberGenerator.new()
	rng.seed = 41108
	for n: int in 48:
		var piece := _piece(pieces.size(), Vector3(rng.randf_range(-5, 5), 3.0 * (n % 4 - 1), rng.randf_range(-5, 5)), Vector3(rng.randf_range(0.02, 3), 0.1, rng.randf_range(0.02, 3)))
		piece["yaw"] = rng.randf_range(-TAU, TAU)
		pieces.append(piece)
	var before: Array = pieces.duplicate(true)
	var widths: Array[float] = GroundLook._rim_widths(pieces)
	assert_eq(widths.size(), pieces.size())
	assert_eq(pieces, before, "width calculation is pure")
	assert_eq(GroundLook._rim_widths(pieces), widths, "repeatable widths")
	for i: int in pieces.size():
		var a: Dictionary = pieces[i]
		var expected: float = GroundLook.RIM
		for j: int in pieces.size():
			var b: Dictionary = pieces[j]
			if i == j or a["lv"] != b["lv"]:
				continue
			# Independent bisection includes pairs in distant footprint buckets.
			var low := 0.0
			var high: float = GroundLook.RIM
			for step: int in 24:
				var mid: float = (low + high) * 0.5
				var pad := Vector2.ONE * (2.0 * mid)
				if _plain_gap(Vector2(a["at"].x, a["at"].z), Vector2(a["size"].x, a["size"].z) + pad, a["yaw"], Vector2(b["at"].x, b["at"].z), Vector2(b["size"].x, b["size"].z) + pad, b["yaw"]) >= GroundLook.RIM_SPACE:
					low = mid
				else:
					high = mid
			expected = minf(expected, low)
		assert_almost_eq(widths[i], expected, 0.00001, "bucket width %d" % i)
	pieces.reverse()
	widths.reverse()
	assert_eq(GroundLook._rim_widths(pieces), widths, "pair order cannot change widths")
	assert_eq(GroundLook._rim_widths([]), [])


## No buckets or distance shortcut; the existing SAT tests check _rim_limit itself.
func _all_pair_rim_widths(pieces: Array) -> Array[float]:
	var feet: Array[GroundLook.Footprint] = []
	var widths: Array[float] = []
	for piece: Dictionary in pieces:
		var at: Vector3 = piece["at"]
		var size: Vector3 = piece["size"]
		feet.append(GroundLook.Footprint.new(Vector2(at.x, at.z), Vector2(size.x, size.z), piece["yaw"]))
		widths.append(GroundLook.RIM)
	for i: int in pieces.size():
		for j: int in range(i + 1, pieces.size()):
			if pieces[i]["lv"] != pieces[j]["lv"]:
				continue
			var width: float = clampf(GroundLook._rim_limit(feet[i], feet[j]), 0.0, GroundLook.RIM)
			widths[i] = minf(widths[i], width)
			widths[j] = minf(widths[j], width)
	return widths


func test_rim_distance_skip_matches_all_pairs_on_seeded_layouts() -> void:
	for seed_value: int in [51107, 51108, 51109, 51110]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var pieces: Array = []
		for n: int in 64:
			var extent: float = 0.8 if n < 32 else 8.0
			var at := Vector3(rng.randf_range(-extent, extent), 3.0 * (n % 4 - 1), rng.randf_range(-extent, extent))
			var size := Vector3(rng.randf_range(0.02, 3.0), 0.1, rng.randf_range(0.02, 3.0))
			var piece := _piece(n, at, size)
			piece["yaw"] = rng.randf_range(-TAU, TAU)
			pieces.append(piece)
		var before: Array = pieces.duplicate(true)
		assert_eq(GroundLook._rim_widths(pieces), _all_pair_rim_widths(pieces), "seed %d" % seed_value)
		assert_eq(pieces, before, "width pass leaves inputs unchanged")
		pieces.reverse()
		assert_eq(GroundLook._rim_widths(pieces), _all_pair_rim_widths(pieces), "reversed seed %d" % seed_value)


func test_rim_distance_skip_boundary_keeps_full_and_narrow_widths() -> void:
	var size := Vector3(0.02, 0.1, 0.02)
	var reach: float = Vector2(size.x, size.z).length() * 0.5
	var threshold: float = 2.0 * reach + sqrt(2.0) * (2.0 * GroundLook.RIM + GroundLook.RIM_SPACE)
	for yaw: float in [0.0, PI * 0.25, PI * 0.5]:
		# All pairs share a bucket; include overlap, a narrowed rim and the skip boundary.
		for distance: float in [0.0, 0.08, threshold - 0.00001, threshold, threshold + 0.00001, 0.7]:
			var pieces: Array = [_piece(0, Vector3(0.1, 0, 0.1), size), _piece(1, Vector3(0.1 + distance, 0, 0.1), size)]
			pieces[0]["yaw"] = yaw
			pieces[1]["yaw"] = -yaw
			assert_eq(GroundLook._rim_widths(pieces), _all_pair_rim_widths(pieces), "yaw %f distance %f" % [yaw, distance])


func test_rim_buckets_find_two_diagonal_squares_across_an_integer_edge() -> void:
	var pieces: Array = [
		_piece(0, Vector3(0.60, 0, 0.5), Vector3(0.2, 0.1, 0.2)),
		_piece(1, Vector3(1.15, 0, 0.5), Vector3(0.2, 0.1, 0.2)),
	]
	for piece: Dictionary in pieces:
		piece["yaw"] = PI * 0.25
	# Both diagonal rims grow sqrt(2)*RIM along world x. The ordered margin
	# RIM*(1+sqrt(2))+RIM_SPACE leaves the first query below cell 1 here.
	var expected: float = (0.55 / sqrt(2.0) - 0.2 - GroundLook.RIM_SPACE) * 0.5
	var widths: Array[float] = GroundLook._rim_widths(pieces)
	assert_almost_eq(widths[0], expected, 0.000001)
	assert_almost_eq(widths[1], expected, 0.000001)
	_assert_gaps(_with_rims(pieces))


func test_isolated_rims_and_separate_floors_keep_full_width() -> void:
	var items := [{"id": "no_art_550", "pos": Vector3(-0.1, 0, -0.1)}, {"id": "no_art_550", "pos": Vector3(-0.1, 3, -0.1)}]
	for piece: Dictionary in GroundLook.pieces(items):
		assert_eq(float(piece.get("rim", -1.0)), GroundLook.RIM)
	var single: Array = GroundLook.pieces([items[0]])
	assert_eq(float(single[0].get("rim", -1.0)), GroundLook.RIM)


func test_rim_uses_explicit_width_including_zero_and_keeps_bar_default() -> void:
	var piece := _piece(0, Vector3(2, 0.5, 3), Vector3.ONE)
	assert_eq(GroundLook.rim(piece)["size"], Vector2.ONE * (1.0 + 2.0 * GroundLook.RIM))
	for width: float in [0.0, 0.015, GroundLook.RIM]:
		piece["rim"] = width
		var rim: Dictionary = GroundLook.rim(piece)
		assert_eq(rim["size"], Vector2.ONE * (1.0 + 2.0 * width))
		assert_almost_eq(rim["inner"].x * rim["size"].x, 1.0, 0.000001)
		assert_almost_eq(rim["inner"].y * rim["size"].y, 1.0, 0.000001)


func test_a_narrowed_rim_is_drawn_darker_down_to_no_width() -> void:
	assert_almost_eq(GroundLook.rim_strength(GroundLook.RIM), GroundLook.GROUND_RIM_STRENGTH, 0.000001, "full width")
	assert_almost_eq(GroundLook.rim_strength(0.0), GroundLook.NARROW_RIM_STRENGTH, 0.000001, "no width")
	assert_almost_eq(GroundLook.rim_strength(GroundLook.RIM * 2.0), GroundLook.GROUND_RIM_STRENGTH, 0.000001, "never lighter than full")
	assert_almost_eq(GroundLook.rim_strength(-0.01), GroundLook.NARROW_RIM_STRENGTH, 0.000001, "never darker than none")
	var last: float = GroundLook.rim_strength(0.0)
	for step: int in range(1, 11):
		var strength: float = GroundLook.rim_strength(GroundLook.RIM * step / 10.0)
		assert_lte(strength, last, "thinner is never lighter")
		last = strength
	assert_lte(GroundLook.NARROW_RIM_STRENGTH, 1.0, "an alpha")
	assert_gte(GroundLook.NARROW_RIM_STRENGTH, GroundLook.GROUND_RIM_STRENGTH)


func test_item_numbers_far_spread_empty_glints_and_floors() -> void:
	var at := Vector3(5.5, 0, 5.5)
	var items: Array = [{"id": "no_art_550", "pos": at, "glint": true}]
	assert_eq(GroundLook.pieces([]), [])
	assert_eq(GroundLook.pieces(items), [])
	for i: int in 4:
		items.append({"id": "no_art_550", "pos": at})
	var out: Array = GroundLook.pieces(items)
	assert_eq(out.size(), 3)
	for i: int in out.size():
		assert_eq(out[i]["item"], i + 1)
		if i > 0:
			assert_gte((out[i]["at"] as Vector3).distance_to(at), 0.5 - 0.000001)
	_assert_gaps(out)
	items.append({"id": "no_art_550", "pos": at + Vector3(0, 3, 0)})
	out = GroundLook.pieces(items, func(_c: Vector2i, _lv: int) -> bool: return true)
	assert_gt(out.size(), 0, "blocked everywhere still keeps nonoverlapping things")
	_assert_gaps(out)
	assert_eq(out.back()["item"], 5, "another floor has its own space")
	assert_eq(out.back()["lv"], 1)
	assert_eq((out.back()["at"] as Vector3).y, 3.0)


func test_press_off_rectangle_segment_and_rotation() -> void:
	var piece := _piece(0, Vector3.ZERO, Vector3(2, 0.2, 1))
	assert_eq(GroundLook.press_off(piece, Vector2.ZERO, Vector2.ZERO), 0.0)
	assert_almost_eq(GroundLook.press_off(piece, Vector2(2, 0), Vector2(2, 0)), 1.0, 0.00001)
	assert_almost_eq(GroundLook.press_off(piece, Vector2(2, 1.5), Vector2(2, 1.5)), sqrt(2.0), 0.00001)
	assert_eq(GroundLook.press_off(piece, Vector2(-2, 0), Vector2(2, 0)), 0.0)
	assert_almost_eq(GroundLook.press_off(piece, Vector2(-2, 1), Vector2(2, 1)), 0.5, 0.00001)
	assert_eq(GroundLook.press_off(piece, Vector2(-2, 0.5), Vector2(2, 0.5)), 0.0)
	piece["yaw"] = PI * 0.5
	assert_almost_eq(GroundLook.press_off(piece, Vector2(1, 0), Vector2(1, 0)), 0.5, 0.00001)


func test_press_on_coat_edge_beats_nearer_turned_knife() -> void:
	var coat := _piece(0, Vector3.ZERO, Vector3(1.0, 0.04, 0.6))
	var knife := _piece(1, Vector3(0.75, 0, 0), Vector3(0.75, 0.06, 0.1))
	knife["yaw"] = PI * 0.5
	var press := Vector2(0.45, 0)
	var coat_off: float = GroundLook.press_off(coat, press, press)
	var knife_off: float = GroundLook.press_off(knife, press, press)
	assert_eq(coat_off, 0.0)
	assert_almost_eq(knife_off, 0.25, 0.00001)
	assert_eq(GroundLook.pick([
		{"item": 0, "off": coat_off, "reach": 0.45, "order": 0},
		{"item": 1, "off": knife_off, "reach": 0.3, "order": 1},
	]), 0, "the coat under the finger wins over the nearer knife centre")


func test_pick_visible_order_reach_glint_and_hidden() -> void:
	var a := {"item": 0, "off": 0.0, "reach": 0.2, "order": 0}
	var b := {"item": 1, "off": 0.00005, "reach": 0.4, "order": 1}
	assert_eq(GroundLook.pick([a, b]), 1, "later drawn wins a footprint tie")
	b["order"] = 0
	assert_eq(GroundLook.pick([b, a]), 0, "equal drawing order uses reach")
	a["reach"] = 0.9
	b["reach"] = 1.0
	assert_eq(GroundLook.pick([a, b]), -1)
	assert_eq(GroundLook.pick([]), -1)
	a.merge({"off": 0.6, "reach": 0.7}, true)
	b.merge({"off": 0.2, "reach": 0.2, "order": 2}, true)
	var hidden := {"item": 2, "off": 0.0, "reach": 0.01, "order": -1}
	assert_eq(GroundLook.pick([a, b, hidden]), 1, "a glint point beats a more distant footprint")
	assert_eq(GroundLook.pick([a, hidden]), 0, "hidden cannot beat visible")
	assert_eq(GroundLook.pick([hidden]), 2)
	assert_eq(GroundLook.pick([hidden, {"item": 3, "off": 0.0, "reach": 0.005, "order": -1}]), 3)
	var chain := [{"item": 0, "off": 0.0, "reach": 0.1, "order": 0}, {"item": 1, "off": 0.00008, "reach": 0.1, "order": 1}, {"item": 2, "off": 0.00016, "reach": 0.1, "order": 2}]
	assert_eq(GroundLook.pick(chain), 1, "ties stay within tolerance of the nearest")
	chain.reverse()
	assert_eq(GroundLook.pick(chain), 1)


func test_it_lies_on_its_own_floor() -> void:
	var items := [
		{"pos": Vector3(4.5, 3.0, 4.5), "id": "can_beans", "n": 1},
		{"pos": Vector3(4.5, -3.0, 4.5), "id": "plank", "n": 1},
	]
	var out: Array = GroundLook.pieces(items)
	assert_eq(out[0]["lv"], 1)
	assert_almost_eq(float(out[0]["at"].y), 3.0, 0.001, "footprint centre on the upper floor")
	assert_eq(out[1]["lv"], -1)
	assert_almost_eq(float(out[1]["at"].y), -3.0, 0.001)
	assert_eq(GroundLook.pieces(items).hash(), out.hash(), "the same list, the same spots")


func test_each_thing_has_a_dark_rim_round_it_on_its_floor() -> void:
	# T0-6: a quad a little wider than the thing, flat on the thing's own floor (ground_rim darkens it).
	var piece: Dictionary = GroundLook.pieces([{"pos": Vector3(4.5, 3.0, 4.5), "id": "undershirt_wool", "n": 1}])[0]
	var rim: Dictionary = GroundLook.rim(piece)
	var size: Vector3 = piece["size"]
	assert_eq(rim["lv"], piece["lv"])
	assert_almost_eq(rim["size"].x, size.x + 2.0 * GroundLook.RIM, 0.0001, "wider on both sides")
	assert_almost_eq(rim["size"].y, size.z + 2.0 * GroundLook.RIM, 0.0001)
	assert_almost_eq(float(rim["at"].y), 3.0 + GroundLook.RIM_LIFT, 0.0001, "flat on the thing's own floor")
	assert_true(GroundLook.RIM_LIFT < size.y, "under the thing's top, so the thing shows over it")
	assert_almost_eq(rim["inner"].x * rim["size"].x, size.x, 0.0001, "the thing's share of the quad")
	assert_almost_eq(rim["inner"].y * rim["size"].y, size.z, 0.0001)


func _rim_alphas(rim: Dictionary) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MapView._rim_quad(st, rim)
	return Array(st.commit().surface_get_arrays(0)[Mesh.ARRAY_COLOR]).map(func(c: Color) -> float: return c.a)


func test_a_rim_under_a_roof_says_so_in_its_alpha() -> void:
	# ground_rim lightens a rim on snow out of doors only (alpha 1); under a roof (0) no snow lies
	# on the floor, so the rim keeps its strength in deep winter too.
	var piece: Dictionary = GroundLook.pieces([{"pos": Vector3(4.5, 0.0, 4.5), "id": "cloth", "n": 1}])[0]
	var rim: Dictionary = GroundLook.rim(piece)
	assert_eq(_rim_alphas(rim), [1.0, 1.0, 1.0, 1.0, 1.0, 1.0], "open to the sky unless told")
	rim["sky"] = 0.0
	assert_eq(_rim_alphas(rim), [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "under a roof")


func test_a_thing_put_down_shows_on_the_map_and_goes_when_picked_up() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 4, "auto_pause": false}
	game.map_script = TwoLids
	add_child_autofree(game)
	game.set_process(false)
	var p = game.player
	game._update_zone(0.1)
	assert_false(game.view.ground_nodes.has(0) and game.view.ground_nodes[0].mesh != null, "nothing lies there yet")
	game.ground_items.append({"pos": p.position + Vector3(0.4, 0, 0.4), "id": "plank", "n": 1})
	game._update_zone(0.1)
	assert_true(game.view.ground_nodes.has(0))
	assert_not_null(game.view.ground_nodes[0].mesh, "a plank put down is seen where it lies")
	assert_not_null((game.view.ground_nodes[0].get_node("Rim") as MeshInstance3D).mesh, "on its dark rim")
	var sky := MapView.sky_alpha(game.view.grid, FieldGrid.cell_of(p.position + Vector3(0.4, 0, 0.4)))
	var rim_mesh: Mesh = (game.view.ground_nodes[0].get_node("Rim") as MeshInstance3D).mesh
	for c: Color in rim_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		assert_eq(c.a, sky, "open to the sky or under a roof, as the floor it lies on")
	game.ground_items.clear()
	game._update_zone(0.1)
	assert_null(game.view.ground_nodes[0].mesh, "picked up, it is gone")
	assert_null((game.view.ground_nodes[0].get_node("Rim") as MeshInstance3D).mesh, "its rim with it")


func test_the_map_draws_each_rim_as_dark_as_its_width() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 4, "auto_pause": false}
	game.map_script = TwoLids
	add_child_autofree(game)
	game.set_process(false)
	var at: Vector3 = game.player.position + Vector3(0.4, 0, 0.4)
	game.ground_items.append({"pos": at, "id": "plank", "n": 1})
	game._update_zone(0.1)
	var rim_node := game.view.ground_nodes[0].get_node("Rim") as MeshInstance3D
	for c: Color in rim_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		assert_almost_eq(c.b, GroundLook.GROUND_RIM_STRENGTH, COLOUR_STEP, "alone: full width, ground strength")
	# Three on one cell: the spread lays them close, so some rims narrow.
	game.ground_items.append({"pos": at, "id": "knife", "n": 1})
	game.ground_items.append({"pos": at, "id": "can_beans", "n": 1})
	game._update_zone(0.1)
	var pieces: Array = game.view._drawn_ground.values()
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	var colours: PackedColorArray = rim_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_eq(colours.size(), pieces.size() * 6, "one quad each")
	var narrowed: int = 0
	for index: int in pieces.size():
		var width: float = float(pieces[index]["rim"])
		if width < GroundLook.RIM:
			narrowed += 1
		for corner: int in 6:
			assert_almost_eq(colours[index * 6 + corner].b, GroundLook.rim_strength(width), COLOUR_STEP, "as dark as its width")
	assert_gt(narrowed, 0, "the three lie close enough to narrow a rim")


func _template() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex: Vector3 in [Vector3(-0.6, 0, -0.2), Vector3(0.6, 0, -0.2), Vector3(0, 0.08, 0.2)]:
		surface.set_normal(Vector3.UP)
		surface.set_color(Color(0.4, 0.3, 0.2, 0))
		surface.add_vertex(vertex)
	return surface.commit()


func test_model_name_footprint_yaw_and_floor_are_from_the_shared_template() -> void:
	assert_true(GroundModels.cache_template("knife", _template()))
	var items: Array = [{"id": "knife", "n": 1, "pos": Vector3(5.5, 3, 7.5)}]
	var piece: Dictionary = GroundLook.pieces(items)[0]
	assert_eq(piece["model"], "knife")
	assert_eq(piece["size"], Vector3(1.2, 0.08, 0.4))
	assert_eq(piece["at"], Vector3(5.5, 3, 7.5))
	assert_eq(GroundLook.pieces(items)[0]["yaw"], piece["yaw"])
	assert_gte(float(piece["yaw"]), 0.0)
	assert_lt(float(piece["yaw"]), TAU)
	var rim: Dictionary = GroundLook.rim(piece)
	assert_eq(rim["yaw"], piece["yaw"])
	assert_almost_eq(rim["size"].x, 1.2 + GroundLook.RIM * 2.0, 0.00001)
	assert_almost_eq(rim["size"].y, 0.4 + GroundLook.RIM * 2.0, 0.00001)
	assert_almost_eq(rim["at"].y, 3.0 + GroundLook.RIM_LIFT, 0.00001)


func test_missing_models_and_box_only_ids_and_bags_keep_boxes() -> void:
	GroundModels.cache_template("no_art_550", null)
	var missing: Dictionary = GroundLook.pieces([{"id": "no_art_550", "n": 1, "pos": Vector3.ZERO}])[0]
	assert_eq(missing["model"], "")
	assert_eq(missing["size"], GroundLook.LOOKS["small"][0])
	var ids: Array = GroundModels.BOX_ONLY_IDS.keys()
	ids.append("found_big_pack")
	for id: String in ids:
		assert_true(GroundModels.cache_template(id, _template()))
		var piece: Dictionary = GroundLook.pieces([{"id": id, "n": 1, "pos": Vector3.ZERO}])[0]
		assert_eq(piece["model"], "", id + " stays a box even with a baked resource")


func test_rim_rotates_all_four_corners_and_keeps_uvs_attached() -> void:
	var rim: Dictionary = {"at": Vector3(5, 3, 7), "size": Vector2(2, 1), "inner": Vector2(0.8, 0.6), "yaw": PI * 0.5}
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	MapView._rim_quad(surface, rim)
	var arrays: Array = surface.commit().surface_get_arrays(0)
	var rotation := Basis(Vector3.UP, PI * 0.5)
	var corners: Array[Vector3] = [Vector3(-1, 0, -0.5), Vector3(1, 0, -0.5), Vector3(1, 0, 0.5), Vector3(-1, 0, 0.5)]
	var order: Array[int] = [0, 1, 2, 0, 2, 3]
	var uvs: Array[Vector2] = [Vector2.ZERO, Vector2(1, 0), Vector2.ONE, Vector2(0, 1)]
	for offset: int in order.size():
		assert_almost_eq((arrays[Mesh.ARRAY_VERTEX][offset] as Vector3).distance_to(rim["at"] + rotation * corners[order[offset]]), 0.0, 0.00001)
		assert_eq(arrays[Mesh.ARRAY_TEX_UV][offset], uvs[order[offset]])


func test_existing_container_rims_still_accept_box_centres() -> void:
	var rim: Dictionary = GroundLook.rim({"lv": 0, "at": Vector3(2, 0.5, 3), "size": Vector3.ONE})
	assert_almost_eq(rim["at"].y, GroundLook.RIM_LIFT, 0.00001)
	assert_eq(rim["yaw"], 0.0)
