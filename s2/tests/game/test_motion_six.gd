extends "res://addons/gut/test.gd"
## Decision 425: six rules from the reference game's motions, the user's
## answer to card 2 (every row 가). A blow holds the feet; at a run it is a
## shove; the dead draw back before the first blow on a door; one getting up
## can be shoved again; a crawler bites later and none bite one just seen;
## footsteps go by the walk.

const FieldGame = preload("res://game/field_game.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const Motion = preload("res://game/sim/motion.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const W = preload("res://game/sim/weapons.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const Gait = preload("res://game/sim/gait.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")

var game
var p


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)


func _dead_at(at: Vector3, state: String = "wander") -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", at)
	z["state"] = state
	return z


func test_a_blow_holds_the_feet_from_part_way_to_its_end() -> void:
	assert_eq(p.weapon_id(), "axe")
	var row: Dictionary = Motion.swing_row("axe")
	var mult: float = float(p.mults()["swing"])
	game.combat.start_swing(p, {})
	assert_false(game.combat.feet_held(p), "drawn back at first, the feet are free")
	game.clock.elapsed += (float(row["feet"].x) + 0.02) / mult
	assert_true(game.combat.feet_held(p), "from feet_from of the swing on, held")
	p.stick = Vector2(1, 0)
	var at: Vector3 = p.position
	game._drive(p, 0.1)
	assert_eq(p.position, at, "the stick does not walk it off")
	assert_false(p.moving)
	game.clock.elapsed += float(row["len"]) / mult
	assert_false(game.combat.feet_held(p), "after the swing they are free")
	p.strike_t = 0.0
	p.swing_t = 0.0
	game._drive(p, 0.1)
	assert_ne(p.position, at, "and it walks")
	# A knife holds them only for the back half of its swing.
	assert_almost_eq(float(Motion.swing_row("knife")["feet"].x) / float(W.get_data("knife")["swing"]), 0.5, 0.001)


func test_at_a_run_a_blow_goes_out_as_a_shove() -> void:
	p.running = true
	p.moving = true
	assert_true(p.is_running_now())
	game.combat.start_swing(p, {})
	assert_gt(p.shove_t, 0.0, "a shove")
	assert_eq(p.strike_t, 0.0, "not a swing")
	p.shove_t = 0.0
	p.swing_t = 0.0
	p.running = false
	game.combat.start_swing(p, {})
	assert_gt(p.strike_t, 0.0, "stopped, it swings")


func test_the_dead_draw_back_before_the_first_blow_on_a_door() -> void:
	var door := Vector2i(-1, -1)
	for c in game.grid.doors:
		if String(game.grid.doors[c]["state"]) == "closed":
			door = c
			break
	var z := _dead_at(p.position + Vector3(30, 0, 0))
	var row: Dictionary = Motion.row("dead_thump")
	var bangs: Array = []
	var t := 0.0
	var was: float = -1.0
	while t < 4.0:
		z["age"] = float(z["age"]) + 0.05
		game.zombies._bang(z, door, 0.05)
		t += 0.05
		if float(z["bang_t"]) > was + 0.5 and was >= 0.0:
			bangs.append(t)
		was = float(z["bang_t"])
	assert_gt(bangs.size(), 1)
	assert_almost_eq(float(bangs[0]), float(row["hit"]), 0.06, "the first blow lands as the picture's does")
	assert_almost_eq(float(bangs[1]) - float(bangs[0]), float(row["len"]), 0.06, "then one a round")
	# Gone from the door and back: it draws back again.
	z["age"] = float(z["age"]) + 2.0
	game.zombies._bang(z, door, 0.05)
	assert_almost_eq(float(z["bang_t"]), float(row["hit"]) - 0.05, 0.001)


func test_one_getting_up_can_be_shoved_again_and_one_lying_cannot() -> void:
	var rise: float = float(Motion.row("dead_rise")["len"])
	var up := _dead_at(p.position + Vector3(sin(p.facing), 0, cos(p.facing)) * 0.8, "downed")
	up["t"] = rise * 0.5
	var low := _dead_at(p.position + Vector3(sin(p.facing), 0, cos(p.facing)) * 0.9, "downed")
	low["t"] = rise + 2.0
	assert_true(game.zombies.getting_up(up))
	assert_false(game.zombies.getting_up(low))
	game.combat.shove(p)
	assert_gt(float(up.get("shoved_t", 0.0)), 0.0, "getting up, it is shoved")
	assert_true(String(up["state"]) in ["chase", "downed"], "it reels, or goes down again by the shove's own chance")
	assert_eq(String(low["state"]), "downed", "lying, it is not")
	assert_eq(float(low.get("shoved_t", 0.0)), 0.0)
	var crawler := _dead_at(p.position, "downed")
	crawler["crawl"] = true
	crawler["t"] = rise * 0.5
	assert_false(game.zombies.getting_up(crawler), "a crawler does not get up")


func test_a_crawler_bites_later_and_none_bite_one_just_seen() -> void:
	assert_almost_eq(Zombies.WINDUP_CRAWL, Zombies.WINDUP * 2.5, 0.001)
	for crawl in [false, true]:
		var z := _dead_at(p.position + Vector3(0, 0, 0.5))
		z["crawl"] = crawl
		z["lunger"] = false
		z["angle"] = PI
		z["sense_t"] = 0.0
		game.zombies._sense(z, game.people_alive(), 0.1)
		assert_eq(String(z["state"]), "chase", "just seen: it comes on, it does not bite yet")
		z["age"] = float(z["age"]) + Zombies.SEEN_GRACE
		z["sense_t"] = 0.0
		game.zombies._sense(z, game.people_alive(), 0.1)
		assert_eq(String(z["state"]), "attack", "seen a while: it bites")
		assert_almost_eq(float(z["windup"]), Zombies.WINDUP_CRAWL if crawl else Zombies.WINDUP, 0.001)
		game.zombies.list.erase(z)


## Every body the living are drawn in goes round with the footsteps (decision 425):
## each walk, run and crouched walk that follows the footsteps (person_visual.gd
## is_stepped) in every living body folder covers the rules' round within half a
## percent, so the planted foot does not slide whichever body or fallback the
## graphics settings pick (body_cast.gd), and the rules stay the one measure.
func test_every_living_body_goes_round_with_the_footsteps() -> void:
	var root := "res://models/people"
	var folders := 0
	for dir_name: String in DirAccess.get_directories_at(root):
		if not dir_name.ends_with("_p"):
			continue
		var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(dir_name).path_join("clips.json")))
		assert_true(info is Dictionary, dir_name + ": its clips can be read")
		if not info is Dictionary:
			continue
		folders += 1
		var seen := {}
		for clip: Dictionary in info["clips"]:
			var clip_name := String(clip["name"])
			if not PersonVisual.is_stepped(clip_name):
				continue
			seen[clip_name] = true
			var want := float(SimNoise.STEP_ROUND[_stepped_gait(clip_name)])
			assert_almost_eq(float(clip.get("round", 0.0)), want, 0.005 * want, "%s %s: the round is the footsteps' %.2f m" % [dir_name, clip_name, want])
		for must: String in [PersonVisual.OWN_WALK, PersonVisual.OWN_RUN, PersonVisual.OWN_CROUCH_WALK]:
			assert_true(seen.has(must), dir_name + ": has " + must)
	assert_gt(folders, 0, "the living's body folders are found")


## The footsteps' round a stepped clip goes by (field_game.gd steps_in): the runs
## at the run's, the crouched walks at the crouched walk's, the rest at the walk's.
func _stepped_gait(clip_name: String) -> String:
	if clip_name == PersonVisual.OWN_RUN or Gait.RUN.values().has(clip_name):
		return "run"
	if clip_name == PersonVisual.OWN_CROUCH_WALK or Gait.CROUCH_WALK.values().has(clip_name):
		return "crouch"
	return "walk"


func test_footsteps_go_by_the_walk_and_the_drawn_feet_with_them() -> void:
	var own: Array = BodyBake.load_baked(PersonVisual.OWN_FOLDER).get("clips", [])
	# From the start of the round, at this person's own stride (decision 423 card 3).
	p.brain["step_r"] = 0.0
	var walk: float = float(SimNoise.STEP_ROUND["walk"]) * Gait.stride(p)
	assert_eq(game.steps_in(p, walk * 0.1), 0, "not yet a foot down")
	assert_eq(game.steps_in(p, walk * 0.15), 1, "one at 0.2 of the round")
	assert_eq(game.steps_in(p, walk * 0.5), 1, "the other at 0.65")
	assert_eq(game.steps_in(p, walk * 1.0), 2, "two to a round")
	p.running = true
	p.moving = true
	var floor_kind: int = game.grid.floor_at(FieldGrid.cell_of(p.position))
	Gait.update_ground_run(p, p.speed(floor_kind), 1.0, floor_kind)
	assert_true(Gait.ground_runs(p), "a measured run uses the run round")
	var before := float(p.brain["step_r"])
	game.steps_in(p, 0.5)
	assert_almost_eq(fposmod(float(p.brain["step_r"]) - before, 1.0), 0.5 / (float(SimNoise.STEP_ROUND["run"]) * Gait.stride(p)), 0.001, "a run goes round by its own")
	# The drawn walk is where the footsteps are (the axe in the hand: its own walk).
	p.running = false
	p.moving = false
	Gait.update_ground_run(p, 0.0, 0.05, floor_kind)
	assert_false(Gait.ground_runs(p))
	var note := {}
	PersonVisual.motion_of(p, note, 0.05, [], own)
	p.position += Vector3(0.1, 0, 0)
	p.brain["step_r"] = 0.42
	var c := PersonVisual.motion_of(p, note, 0.05, [], own)
	assert_eq(String(own[int(c.y)]["name"]), "p_walk_axe")
	assert_almost_eq(c.x, 0.42, 0.001)
