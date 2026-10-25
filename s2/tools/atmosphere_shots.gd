extends SceneTree
## Check shots of the atmosphere frame (fx/atmosphere.gd): hour band 4 x
## weather 6 x the cold's stages, the field at one stop and the world outside
## the running train. Picture-only opts; the HUD and the train's keys are hidden.
##   godot --path s2 --resolution 1688x780 -s res://tools/atmosphere_shots.gd -- --out=<folder>
## Optional: --what=field|travel|both --stages=autumn,early,deep,thaw
##   --bands=dawn,day,dusk,night --weathers=clear,overcast,fog,snow,blizzard,sleet
##   --region=K1 --place=<map id> --edge (the field at the map's west edge)
##   --ref (only the three reference scenes, REF_SCENES)
## Writes <what>_<stage>_<band>_<weather>.jpg and index.json (what each cell drew).

const FieldGame = preload("res://game/field_game.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const Atmosphere = preload("res://fx/atmosphere.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")

## Rules weather and the drawn look for each column (overcast plays by clear
## rules, as the storm's "before" stop does).
const WEATHERS: Dictionary = {
	"clear": [["clear"], ["clear"]],
	"overcast": [["clear"], ["overcast"]],
	"fog": [["fog"], ["fog"]],
	"snow": [["snow"], ["snow"]],
	"blizzard": [["blizzard"], ["blizzard"]],
	"sleet": [["sleet"], ["sleet"]],
}

var out := ""
var what := "both"
## The cold's stages along the season answer of 10-24: [cold, side].
const STAGES: Dictionary = {
	"autumn": [0.0, 0.0],   # the prologue's first stop: late autumn, rain and leaf
	"early": [0.5, 0.0],    # act 1: early winter, first snow lying, nights freezing
	"deep": [1.0, 0.5],     # act 2: deep winter
	"thaw": [0.36, 1.0],    # act 3: the early thaw, slush and dripping eaves
}
var stages: Array = ["autumn", "early", "deep", "thaw"]
var bands: Array = ["dawn", "day", "dusk", "night"]
var weathers: Array = ["clear", "overcast", "fog", "snow", "blizzard", "sleet"]
var region := "K1"
var place := ""
## --bare: the travel shot without the weather, frost and film over it (to judge the card).
var bare := false
## --mask: keep the field's sight mask (default off, so the whole stop shows its light).
var mask := false
## --edge: look at the map's west edge, half the screen past it (결정 448 17).
var edge := false
## The reference scenes the look (mood) and the materials (art3d) both judge by
## (색감 루프, 2026-10-26): late autumn K1, a street at midday under overcast,
## indoors at dusk by a curtained window, a rainy night. The rules clock is the
## picture hour, so lamps and lit windows go with it. Written as ref_<name>.jpg.
const REF_SCENES: Array = [
	{"name": "street_noon", "hour": 12.0, "rules": ["clear"], "look": ["overcast"], "indoor": false},
	{"name": "indoor_dusk", "hour": 16.0 + 10.0 / 60.0, "rules": ["clear"], "look": ["clear"], "indoor": true},
	{"name": "rain_night", "hour": 19.0, "rules": ["rain"], "look": ["rain"], "indoor": false},
]
## --ref: only the reference scenes.
var ref := false
var index: Array = []


func _initialize() -> void:
	_run()


## The hour that shows a band best at this cold: the sun on the line at dawn,
## low at dusk, high at midday, well into the night.
static func band_hour(band: String, cold: float, side: float) -> float:
	var t := Atmosphere.sun_times(cold, side)
	match band:
		"dawn":
			return t.x + 0.25
		"dusk":
			return t.y - 0.4
		"night":
			return t.y + 1.7
	return 12.0


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--what="):
			what = a.substr(7)
		elif a.begins_with("--stages="):
			stages = Array(a.substr(9).split(","))
		elif a.begins_with("--bands="):
			bands = Array(a.substr(8).split(","))
		elif a.begins_with("--weathers="):
			weathers = Array(a.substr(11).split(","))
		elif a.begins_with("--region="):
			region = a.substr(9)
		elif a.begins_with("--place="):
			place = a.substr(8)
		elif a == "--bare":
			bare = true
		elif a == "--mask":
			mask = true
		elif a == "--edge":
			edge = true
		elif a == "--ref":
			ref = true
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	if ref:
		stages = []
		for s: Dictionary in REF_SCENES:
			await _field_shot(String(s["name"]), float(STAGES["autumn"][0]), float(STAGES["autumn"][1]), float(s["hour"]), "", "", s)
	for st in stages:
		var c := float(STAGES[st][0])
		var side := float(STAGES[st][1])
		for b in bands:
			for w in weathers:
				var hour := band_hour(String(b), c, side)
				var tag := "%s_%s_%s" % [st, b, w]
				if what in ["field", "both"]:
					await _field_shot(tag, c, side, hour, String(b), String(w))
				if what in ["travel", "both"]:
					await _travel_shot(tag, c, side, hour, String(w))
	var f := FileAccess.open(out.path_join("index.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(index, "  "))
	f.close()
	quit()


func _save(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_jpg(out.path_join(name + ".jpg"), 0.86)


## scene: one of REF_SCENES (then w and band are unused and tag is its name).
func _field_shot(tag: String, c: float, side: float, hour: float, band: String, w: String, scene := {}) -> void:
	var game = FieldGame.new()
	var rules: Array = scene.get("rules", WEATHERS.get(w, [[]])[0])
	var look: Array = scene.get("look", WEATHERS.get(w, [[], []])[1])
	var o := {"seed": 5, "raiders": false, "auto_pause": false, "arrive": false,
		"weather": rules, "look": look, "cold": c, "side": side, "look_hour": hour, "region": region}
	if place != "":
		o["place"] = place
	game.opts = o
	root.add_child(game)
	# Lamps and lit windows go by the rules clock: after dark for night shots,
	# the dusk band for dusk ones (the picture hour stays as asked); a reference
	# scene's rules clock is its picture hour.
	if not scene.is_empty():
		game.clock.elapsed = maxf(hour - 10.5, 0.0) * 240.0
	elif band == "night":
		game.clock.elapsed = (17.5 - 10.5) * 240.0
	elif band == "dusk":
		game.clock.elapsed = (15.3 - 10.5) * 240.0
	game.set_process(true)
	game.paused = true
	game.hud.visible = false
	# The same patch of the stop every time: south of the train, the yard and its buildings.
	game.cam_push = Vector3(0, 0, 16)
	if edge:
		game.cam_push = Vector3(2.0 - game.player.position.x, 0, 16)
	if bool(scene.get("indoor", false)):
		# Inside by a curtained window, the walls cut away round the player.
		var at := indoor_cell(game.view.grid)
		if at.x >= 0:
			game.player.position = FieldGrid.center(at)
			game.cam_push = Vector3.ZERO
	if not mask:
		game.mask_on = false
		game.view.set_mask_enabled(false)
	# The rules drop sleet below -3 C (the rules temperature stays the stop's);
	# the shot still shows what the picture would let fall.
	if String(game.atmo["falls"]) != "none" and not game.snow.emitting:
		game.snow.amount = 400
		game.snow.emitting = true
	for _i in range(4):
		await process_frame
	game.paused = false
	game.set_process(false)
	if bool(scene.get("indoor", false)):
		var b: int = game.view.grid.building_at(FieldGrid.cell_of(game.player.position))
		game.view.show_levels(0)
		game.view.cut_away(b, 0)
		game._update_camera(1.0)
	game._update_light()
	await create_timer(2.6).timeout
	var shot := ("ref_" if not scene.is_empty() else "field_") + tag
	await _save(shot)
	index.append({"shot": shot, "cold": c, "side": side, "hour": hour, "band": game.atmo["band"], "weather": w if scene.is_empty() else look,
		"drawn": game.atmo["kinds"], "falls": game.atmo["falls"], "temp_c": snappedf(float(game.atmo["temp_c"]), 0.1),
		"season": game.atmo["season"], "breath": snappedf(float(game.atmo["breath"]), 0.01), "breaths": game.breath.shown})
	game.queue_free()
	await process_frame


## An open floor cell just inside a curtained window, first by row then
## column, a window in a north wall first (the camera looks north, so its
## inside face shows). (-1, -1) when the map has none.
static func indoor_cell(g: FieldGrid) -> Vector2i:
	var keys: Array = g.windows.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for pass_dirs in [[Vector2i(0, 1)], [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]]:
		for w: Vector2i in keys:
			var win: Dictionary = g.windows[w]
			if not BuildingRules.has_curtain(win):
				continue
			for d: Vector2i in pass_dirs:
				var c: Vector2i = w + d
				if g.inside(c) and g.building_at(c) == int(win["building"]) and g.solid_at(c) == FieldGrid.Solid.NONE:
					return c
	return Vector2i(-1, -1)


func _travel_shot(tag: String, c: float, side: float, hour: float, w: String) -> void:
	var flow = SliceFlow.new()
	flow.opts = {"skip_field": true, "seed": 3, "look": {"hour": hour, "kinds": WEATHERS[w][1], "cold": c, "side": side, "region": region}}
	root.add_child(flow)
	await process_frame
	# The world and the weather over it; not the keys, gauges or pane.
	for child in flow.layer.get_children():
		if child not in [flow.weather, flow.frost, flow.film] or bare:
			child.visible = false
	await create_timer(2.0).timeout
	await _save("travel_" + tag)
	var l: Dictionary = flow.outside.look if flow.outside != null else {}
	index.append({"shot": "travel_" + tag, "cold": c, "side": side, "hour": hour, "band": l.get("band", ""), "weather": w,
		"drawn": l.get("kinds", []), "falls": l.get("falls", ""), "temp_c": snappedf(float(l.get("temp_c", 0.0)), 0.1)})
	flow.queue_free()
	await process_frame
