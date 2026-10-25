extends RefCounted
## What the music reads from a scene (bgm.md 8): only what the player can already see or hear
## (bgm.md 2.3). The dead out of sight, a horde not yet on the screen's rim and hidden results are
## not read, so the music never tells a rule. Nothing here is a new ledger: existing values only.

const FieldGrid = preload("res://game/world/field_grid.gd")
const Rules = preload("res://game/audio/music_rules.gd")

const COMING_STATES: Array[String] = ["chase", "dash", "attack", "grab"]
const MUTE_STATES: Array[String] = ["frozen", "downed", "dead", "rising", "waking"]
const RIM_FROM: float = 0.5          # the horde bar shows as a darker rim from here (field_hud)


## A field snapshot for music_rules / music_director.
static func field(game) -> Dictionary:
	var p: Vector3 = game.player.position
	var seen := 0
	var far := 0
	var near := 0
	var on_top := 0
	for z in game.zombies.list:
		if MUTE_STATES.has(String(z["state"])):
			continue
		var at: Vector3 = z["pos"]
		if not shown(game, at):
			continue
		seen += 1
		if not COMING_STATES.has(String(z["state"])):
			continue
		var d := at.distance_to(p)
		if d < Rules.ON_TOP_M:
			on_top += 1
		if d < Rules.NEAR_M:
			near += 1
		else:
			far += 1
	var now: float = game.clock.elapsed
	var horde := false
	for h in game.hordes.values():
		if not bool(h.get("cleared", false)):
			horde = true
	return {
		"seen": seen, "coming_far": far, "coming_near": near, "on_top": on_top,
		"grabbed": not game.player.grabbers.is_empty(),
		"hurt": clampf(float(game.player.body.bleed) / 2.0, 0.0, 1.0),
		"pressure": clampf((game.director.pressure(now) - RIM_FROM) / (1.0 - RIM_FROM), 0.0, 1.0),
		"horde": horde,
		"indoor": game.grid_at(p).indoor(FieldGrid.cell_of(p)),
		"under": game.level_of(p) < 0,
		"band": String(game.atmo.get("band", "day")),
		"weathers": (game.look_kinds as Array).duplicate(),
		"season": String(game.season_name),
	}


## As field_audio's in_view: on a cell the player sees, on a shown level, inside the camera.
static func shown(game, at: Vector3) -> bool:
	if not game.cell_seen(at) or not game.level_shown(game.level_of(at)):
		return false
	return game.camera == null or game.camera.is_position_in_frustum(at + Vector3(0, 0.6, 0))


## A train snapshot from the train scene's rules (s1's own key names, train_context.gd).
static func train(scene) -> Dictionary:
	var rules: Dictionary = scene.rules
	var t: Dictionary = rules.get("train", {})
	var view: Dictionary = rules.get("view", {})
	var warmth: Array = []
	var ration: Array = []
	for c in (rules.get("comms", {}) as Dictionary).values():
		var sit: Array = (c as Dictionary).get("sit", [70, 70, 0, 0])
		warmth.append(float(sit[0]))
		ration.append(float(sit[1]))
	return {
		"fear": float(t.get("fear", 0)), "tension": float(t.get("tension", 0)),
		"coal": float(t.get("coal", 100)), "food": float(t.get("food", 100)),
		"hunger": int(t.get("hunger", 0)), "stranded": t.get("stranded") != null,
		"crisis": t.get("trustCrisis") != null or bool(view.get("crisis", false)),
		"riot": String(view.get("riot_stage", "none")),
		"night": String(view.get("daytime", "day")) == "night",
		"warmth": warmth, "ration": ration,
		"car_song": bool(view.get("car_song", false)),
	}
