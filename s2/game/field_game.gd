extends Node3D
## One direct stop at Sulechów (S2 graybox, s2_station.md). Owns the map,
## people, the dead, clocks and the receipt. Combat, AI, input and HUD live in
## helper scripts that read and write this node.

signal finished(result: Dictionary)
signal restart_requested

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const MapView = preload("res://game/world/map_view.gd")
const Person = preload("res://game/actors/person.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const FieldClock = preload("res://game/sim/field_clock.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const NoiseLedger = preload("res://game/sim/noise_ledger.gd")
const HordeDirector = preload("res://game/sim/horde_director.gd")
const Receipt = preload("res://game/sim/receipt.gd")
const Telemetry = preload("res://game/sim/telemetry.gd")
const FieldMission = preload("res://game/field_mission.gd")
const FieldHoldout = preload("res://game/field_holdout.gd")
const Motion = preload("res://game/sim/motion.gd")
const Carry = preload("res://game/sim/carry.gd")
const Weather = preload("res://game/sim/weather.gd")
const FxState = preload("res://fx/fx_state.gd")
const SnowCover = preload("res://game/sim/snow_cover.gd")
const LampLight = preload("res://game/sim/lamp_light.gd")
const SnowTracks = preload("res://game/sim/snow_tracks.gd")
const PrecipShader = preload("res://fx/shaders/precip.gdshader")
const W = preload("res://game/sim/weapons.gd")
const Combat = preload("res://game/field_combat.gd")
const AI = preload("res://game/field_ai.gd")
const Actions = preload("res://game/field_actions.gd")
const Hud = preload("res://game/ui/field_hud.gd")
const FieldAudio = preload("res://game/audio/field_audio.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const StormLook = preload("res://fx/storm_look.gd")
const AllyLines = preload("res://game/sim/ally_lines.gd")
const LeaveScene = preload("res://game/ui/leave_scene.gd")

const AMBIENT_C: float = -14.0
## Everyone but the player turns their body at this pace (about 0.45 s to turn round).
const TURN_DEG_PER_S: float = 400.0
# The train rolling away in the stop's closing scene: it pulls at this much
# (m/s2) for this long, then holds that pace. Looks only; nothing reads it.
const TRAIN_PULL: float = 1.0
const TRAIN_UP_S: float = 6.0
# A train that stopped on open line is seen coming to its stand (user decision
# 200; only where it halts, 204): it rolls in from off the screen, slowing, the
# brakes cry for the last of it, and then it is quiet a moment. A touch skips
# it. Looks and one sound; the clock does not run and nothing hears it.
const ARRIVE_KINDS: Array[String] = ["bare_line"]
const ARRIVE_ROLL_S: float = 3.0
const ARRIVE_BRAKE_S: float = 1.1
const ARRIVE_HUSH_S: float = 0.8
const SIGHT_RADIUS: int = 18
const SIGHT_UPSTAIRS: int = 30
const SIGHT_CELLAR: int = 7             # a dark cellar: you see what is near
const NEAR_SIGHT: float = 2.0         # heard from behind (body_injury 8.3)
const VIEW_CONE_COS: float = 0.17       # about 160 degrees ahead (zomboid-like)
const SEWER_CLEAR: float = 6.0          # no one climbs out within this of a person (field_unified 6)
const BLOOD_SCENT_R: float = 12.0       # excessive blood smell event radius (body_injury 8.1)
const CULVERT_WIDTH: int = 2            # dead out of a culvert at once; every other way lets one out
const ALLY_CAP: int = 12
## Stick body weight (field_unified 10, numbers are S2 starting values).
const DRIVE_START: float = 0.2          # seconds to get up to speed
const DRIVE_STOP: float = 0.25          # seconds to stop from a walk
const DRIVE_STOP_RUN: float = 0.4       # seconds to stop from a run
## Start-screen choice to compare by hand (coordinator 18:19): heavy (the
## first build's, default since the user's 10-08 morning answer C), middle, short.
const INERTIA: Dictionary = {
	"now": [0.2, 0.25, 0.4],
	"mid": [0.12, 0.15, 0.25],
	"short": [0.10, 0.12, 0.20],
}
const STICK_BREAKS: Array = ["search", "salvage", "pry", "kick", "glass", "lid", "snow", "fire", "craft", "rub", "splint", "treat"]
const CAM_PITCH: float = 52.0
const FADE_TIME: float = 0.25           # seconds for the pause fade to come and go
const NIGHT_SUN_MIN: float = 0.1
# The radio (user 2026-10-11, decisions 032): it can be turned down, and when
# it crackles the dead near you hear it. More talk is more to know and more rings.
const RADIO_MODES: Array[String] = ["urgent", "often", "off"]
const RADIO_NAMES: Dictionary = {"urgent": "급한 것만", "often": "자주", "off": "끔"}
const RADIO_GAP: Dictionary = {"urgent": 90.0, "often": 20.0, "off": 0.0}   # least seconds between two calls
const RADIO_RING: float = 8.0          # how far a call is heard, from the one who carries the set
const RADIO_RING_URGENT: float = 14.0  # a horde coming in, time to leave: louder
const RADIO_HISS: float = 1.0          # the set hisses this long before it speaks (the dead do not hear the hiss)
const RADIO_NEAR_M: float = 60.0
const LAMP_OFF_SIGHT: float = 0.42     # how far the eye reaches at night with the lanterns out (0.55 with them; 0.3 was too blind, build 89)
const NIGHT_AMBIENT_MIN: float = 0.2
const LAMP_GAIN_DAY: float = 0.25       # how much of the lamp light shows on the ground by day
const EXTRA_ITEMS: Dictionary = {
	"info_telegraph": {"name": "전신 기록", "weight": 0.5, "stock": "info"},
	"info_timetable": {"name": "시간표", "weight": 0.5, "stock": "info"},
	"flare": {"name": "철도 섬광", "weight": 0.5, "stock": ""},
	# What the four drives of the pass's plough give up together (user decision 188).
	"plow_core": {"name": "제설기 코어", "weight": 4.0, "stock": ""},
	"ammo_pistol": {"name": "권총탄 한 줌", "weight": 0.0, "stock": ""},
	"ammo_shell": {"name": "산탄 한 줌", "weight": 0.0, "stock": ""},
}
const STOCK_OF: Dictionary = {"food_pack": ["food", 0.5], "med_box": ["medicine", 0.5], "luxury_pack": ["luxury", 0.5], "symbol_bell": ["symbol", 1.0], "info_telegraph": ["info", 1.0], "info_timetable": ["info", 1.0], "medkit": ["medicine", 1.0], "document": ["info", 0.0]}

var opts: Dictionary = {}
## What this stop is for (opts["mission"]; content_variety_first_build 2부):
## "" is the stop as it always was, "survey" the track office, "depot" the
## loading yard. Anything else is read as "". With "" nothing is written that
## was not written before.
const MISSIONS: Array[String] = ["", "survey", "depot"]
var mission: String = ""
var mission_play: FieldMission      # the goals of this stop, in the field
var holdout: FieldHoldout           # holding the train while it gets ready (off on a plain stop)
var rng := RandomNumberGenerator.new()
var place: String = ""                 # which map this stop is played on (FieldMaps)
var map_script: Script                 # a map handed over as it is, in place of a place's (tests)
var data: Dictionary
var grid: FieldGrid                    # the ground level
var levels: Dictionary = {}            # level -> FieldGrid (0 ground, 1-2 upstairs, -1 cellar)
var stairs: Array = []                 # [{cell, low, high, ladder}]
var view: MapView
var zombies: Zombies
var camera: Camera3D
var environment: Environment
var sun: DirectionalLight3D
var snow: GPUParticles3D
## Storm stop (weather_fx 14장, opts["storm"]: before, during, after): its look,
## the snow layers with their place relative to the view, and the screen layer
## under the HUD that carries the dark bank, the snow-fog and the edge frost.
var storm: Dictionary = {}
var storm_layers: Array = []
var storm_screen: ColorRect
## The screen layer is drawn small and stretched over the view: at full size its
## noise cost 9~12 ms a frame on the phone (S22, 2026-10-11: 35 fps with a horde
## about, 55 with this layer off). Snow-fog and the dark bank are soft; they
## bear it. Frost has fine veins, so it is drawn at full size, but only on four
## strips along the edges: as far in as frost can reach (FROST_REACH of the
## view's height at edge_frost 1, plus the noise's margin).
const STORM_SCREEN_SCALE: float = 0.35
var storm_port: SubViewport
var storm_view: TextureRect
const FROST_REACH: float = 0.22
const FROST_MARGIN: float = 0.07
var storm_frost: Control
## Test key (D panel): which storm layers are drawn, to see on the phone what
## each costs. 0 all, 1 no screen layer, 2 no falling snow, 3 neither.
const STORM_CUTS: Array[String] = ["다 켬", "화면 층 끔", "눈발 끔", "둘 다 끔"]
var storm_cut: int = 0
var clock := FieldClock.new()
var ledger := NoiseLedger.new()
var director: HordeDirector
var receipt: Receipt
var telemetry: Telemetry
var lines := AllyLines.new()
var combat: Combat
var ai: AI
var actions: Actions
var hud: Hud
var audio: FieldAudio

var people: Array = []
var people_look  # person_visual.gd: the baked body the people wear
var squad: Array = []
var crew: Array = []
var raiders: Array = []
var player: Person
var paused: bool = false
var slow: float = 1.0                    # the body picture up: the field runs at this rate (body_injury 4.6)
var away: bool = false             # the app pushed the field into a pause; say so once on return
var ended: bool = false
var leave_t: float = -1.0          # since the train began to roll away (-1: it stands)
var arrive_t: float = -1.0         # since the train came into sight (-1: it stands)
var rode_off: Array = []           # who went with it: not drawn on the platform any more
var seen_now: Dictionary = {}
var seen_memory := PackedByteArray()
var vis_t: float = 0.0
var hud_t: float = 0.0
var mask_on: bool = true
var forecast_precision: int = 0
var weather: Weather
var cap: int = HordeDirector.CONCURRENT_CAP
var waiting: int = 0                   # bodies held at entries by the concurrent cap
var deaf_t: float = 0.0                # player can't hear sound cues (indoor gunfire, 8.2)
var casings: int = 0
var last_gun_t: float = -INF
var radio: String = ""
var radio_wait: Dictionary = {}        # the call the set is hissing before: {text, ring}
var radio_wait_t: float = 0.0
var radio_last: float = -INF           # field time of the last call that rang
var radio_rings: Array = []            # [{t, r}] calls that rang (tests, the receipt)
## What "only what is near" means (decisions 032, still to be confirmed):
## "horde" = a horde whose way in is far from you is not called at all;
## "train" = far from the train the set only hisses, nothing can be made out.
var radio_near: String = "horde"
var radio_t: float = 0.0
var ammo: Dictionary = {"pistol": 8, "shell": 4, "craft": 8}
var ammo_start: Dictionary = {}
var loaded_start: Dictionary = {}      # rounds already in the squad's guns at the start
var unloaded: Dictionary = {}
var blood: Array = []
var sounds: Array = []                 # recent sounds for the HUD: {pos, level, t}
var shot_times: Array = []
var hordes: Dictionary = {}            # index -> {"t": arrival, "ids": [], "cleared": bool, "entry": key}
var pending_spawn: Array = []          # {"t", "pos", "horde", "target"}
var last_loud = null                   # where the last loud sound was (Vector3): hordes walk there
var rattle: Dictionary = {}            # manhole key -> seconds of rattling left
var lid_open: Dictionary = {}          # manhole key -> seconds the lid stays pushed aside (a body is coming up)
var ground_items: Array = []           # {pos, id, n}
var decisions: Array = []
var cam_focus := Vector3.ZERO
var cam_push := Vector3.ZERO
var cam_size: float = 24.0
var zone_now: String = ""
var auto_paused_once: bool = false
var flash_t: float = 0.0
var dark_noise_t: float = 0.0
var safe_warned: bool = false
var ice_warned: bool = false
var glass_warned: bool = false
var player_downed_t: float = 0.0
var spotted_events: int = 0
var unseen_rattle: bool = false
var lid_tip_told: bool = false           # the driver has said once how the street manhole is shut
var light_t: float = 0.0
## What the stop wrote into the fx_* shader globals (the server cannot be read back at runtime).
var fx_params: Dictionary = {}
## Sun, fill and haze colours of the arrival hour and of full night (FxState.lighting_for).
var fx_light: Dictionary = {}
## Lying snow of this stop and the game minute it was last advanced to.
var snow_cover: SnowCover = SnowCover.new()
## Weather kinds the picture is drawn with: weather.kinds unless opts["look"]
## gives others (overcast before a storm plays by clear rules).
var look_kinds: Array = []
var snow_at_min: float = 0.0
## Footprints in the lying snow (weather_fx 15장), and the cell each walker was
## last seen in ("p<instance id>" or "z<id>" -> cell index). Picture only.
var snow_tracks: SnowTracks
var track_last: Dictionary = {}
## Warm light (weather_fx 12장): fixed lights that are on, their cells, and the
## two real lights (the chief's lantern and the firebox).
var lamp_key: String = "-"
var lamp_fixed: Dictionary = {}
var lantern: OmniLight3D
var firebox: OmniLight3D
var lamp_pulse: float = 0.0
var fx_light_night: Dictionary = {}


func _ready() -> void:
	rng.seed = int(opts.get("seed", Time.get_ticks_usec()))
	clock.speed = float(opts.get("clock_speed", 1.0))
	# A storm stop plays by its stage's weather (clear, blizzard, clear) and
	# looks like the stage; without one the stop is as before.
	storm = StormLook.look(String(opts.get("storm", "")))
	weather = Weather.new(storm.get("rules", opts.get("weather", ["fog", "snow"])), AMBIENT_C, Vector2(1, 0.2), 0.4)
	# Picture inputs for the storm stops (weather_fx 14장): rules still read weather.
	look_kinds = opts.get("look", storm.get("kinds", weather.kinds))
	snow_cover = SnowCover.new(SnowCover.DEFAULT_SEASON, false, float(opts.get("storm_cm", storm.get("storm_cm", 0.0))))
	_apply_fx()
	cap = int(opts.get("cap", HordeDirector.CONCURRENT_CAP))
	Engine.max_fps = int(opts.get("fps_cap", 60))
	place = FieldMaps.resolve(String(opts.get("place", "")))
	_take_map(FieldMaps.build_from(map_script) if map_script != null else FieldMaps.build(place))
	director = HordeDirector.new(rng)
	director.use_map(data)
	if opts.has("budget"):
		director.budget_left = int(opts["budget"])
	# The receipt knows six kinds of place (the S1 contract); a kind it does not
	# know yet is written as the freight stop it was drawn from.
	var kind: String = data["place_kind"]
	receipt = Receipt.new(data["place_id"], kind if Receipt.PLACE_TYPES.has(kind) else "freight", "small_station_siding")
	receipt.set_source("direct")
	if not Receipt.PLACE_TYPES.has(kind):
		receipt.place_note("placeKind", kind)   # what it really is, beside the type the contract knows
	telemetry = Telemetry.new("s2-%d" % rng.seed)
	mission = String(opts.get("mission", ""))
	if not MISSIONS.has(mission):
		mission = ""
	telemetry.mission = mission
	mission_play = FieldMission.new(self)
	mission_play.place()
	holdout = FieldHoldout.new(self)
	_build_world()
	view = MapView.new()
	add_child(view)
	view.setup(data)
	zombies = Zombies.new()
	add_child(zombies)
	zombies.setup(self, VatBaker.build(int(opts.get("vertices", 1500))))
	combat = Combat.new(self)
	ai = AI.new(self)
	actions = Actions.new(self)
	_spawn_people()
	people_look = PersonVisual.new()
	add_child(people_look)
	people_look.setup(self)
	_spawn_dead()
	ammo_start = ammo.duplicate()
	loaded_start = loaded_totals()
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	audio = FieldAudio.new()
	add_child(audio)
	audio.setup(self)
	set_radio("기관사: " + director.forecast(0.0, 0, clock) + lid_tip(), "say")
	if holdout.feel_line() != "":
		audio.chief_feel(holdout.feel_number())
	if mission_play.active():
		hud.toast(mission_play.opening_line())
	if holdout.mode == "start":
		holdout.begin()
	if ARRIVE_KINDS.has(kind) and bool(opts.get("arrive", true)):
		arrive_t = 0.0
		hud.visible = false
		view.slide_train(-train_in(0.0, arrive_far()))
	cam_focus = player.position
	_update_camera(1.0)
	_refresh_vision()
	telemetry.zone_enter(grid.zone_at(FieldGrid.cell_of(player.position)), 0.0)


## Weather is fixed for the whole stop, so the shader globals are set once;
## only lying snow moves afterwards (_update_snow).
func _apply_fx() -> void:
	var hour := clock.game_minutes() / 60.0
	snow_at_min = clock.game_minutes()
	fx_params = FxState.params_for(look_kinds, weather.ambient_c, weather.wind_dir, weather.wind, hour, snow_cover.cover())
	FxState.apply(fx_params)
	fx_light = FxState.lighting_for(look_kinds, hour)
	fx_light_night = FxState.lighting_for(look_kinds, 0.0)
	if not storm.is_empty():
		# The stage sets how strong and what colour the daylight is.
		var clear_sky := FxState.lighting_for(["clear"], hour)
		fx_light["sun_energy"] = float(clear_sky["sun_energy"]) * float(storm["sun"])
		fx_light["sun_color"] = Color(fx_light["sun_color"]).lerp(storm["sun_color"], 0.6)
		fx_light["ambient_color"] = Color(fx_light["ambient_color"]).lerp(storm["ambient_color"], 0.6)


## Snow keeps falling through the stop: lying snow deepens with the field clock
## and the shader global follows once the change would show.
func _update_snow() -> void:
	var now := clock.game_minutes()
	if now - snow_at_min < 1.0:
		return
	snow_cover.advance(now - snow_at_min, weather.kinds, weather.ambient_c)
	if snow_tracks != null:
		snow_tracks.refill(now - snow_at_min, SnowCover.rate_cm_h(weather.kinds, weather.ambient_c))
	snow_at_min = now
	var p := FxState.params_for(look_kinds, weather.ambient_c, weather.wind_dir, weather.wind, now / 60.0, snow_cover.cover())
	if absf(float(p["fx_snow"]) - float(fx_params["fx_snow"])) < 0.002:
		return
	fx_params["fx_snow"] = p["fx_snow"]
	FxState.apply({"fx_snow": p["fx_snow"]})


func _warm_light(reach: float, strength: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = FxState.LAMP
	l.light_energy = strength
	l.omni_range = reach
	l.shadow_enabled = false
	add_child(l)
	return l


func _tower_fire() -> bool:
	return String(data["spots"].get("water_tower", {}).get("state", "")) == "fire"


## Is a living raider still inside the hideout (the building its light names)?
func _raiders_in() -> bool:
	var hideout := -1
	for l in data["lights"]:
		if l["kind"] == "hideout":
			hideout = int(l.get("building", -1))
	for r in raiders:
		if r.is_alive() and grid.building_at(FieldGrid.cell_of(r.position)) == hideout:
			return true
	return false


## The hour the fixed lights go by. Inside a storm it is dark enough at noon
## that the windows are lit all day: they show where the train is.
func _light_minutes() -> float:
	return 1440.0 if bool(storm.get("windows_lit", false)) else clock.game_minutes()


## Warm light for the sight mask: fixed lights (stamped again only when one
## comes on or goes out) plus every lit lantern. sight: the chief's own sight
## cells, so their lantern does not shine through walls.
func lamp_cells(sight: Dictionary = {}) -> Dictionary:
	var now := _light_minutes()
	var fire := _tower_fire()
	var raid := _raiders_in()
	var lights: Array = data["lights"]
	var key := LampLight.on_key(lights, now, fire, raid)
	if key != lamp_key:
		lamp_key = key
		lamp_fixed = LampLight.fixed_cells(lights, grid.width, grid.height, now, fire, raid)
		for kind in ["car_window", "firebox", "hideout"]:
			var on := false
			for l in lights:
				if l["kind"] == kind and LampLight.is_on(l, now, fire, raid):
					on = true
			view.set_light_on(kind, on)
	var cells := lamp_fixed.duplicate()
	var dark := clock.is_dark()
	for p in people:
		if not p.lamp_lit(dark, level_of(p.position) < 0):
			continue
		var only: Dictionary = sight if p == player else {}
		LampLight.stamp(cells, grid.width, grid.height, FieldGrid.cell_of(p.position), Vector2i.ZERO, float(p.lamp["strength"]), float(p.lamp["reach"]), only)
	return cells


## The chief's lantern is a real light, so people and the dead near it are lit
## too; it dips for a moment when the night's light sound goes out.
func _update_lantern(delta: float) -> void:
	lamp_pulse = move_toward(lamp_pulse, 0.0, delta * 2.0)
	lantern.visible = player.lamp_lit(clock.is_dark(), level_of(player.position) < 0)
	lantern.position = player.position + Vector3(0, 1.4, 0)
	lantern.light_energy = float(player.lamp.get("strength", 1.0)) * (1.0 - 0.3 * lamp_pulse)
	var night := maxf(clampf((clock.game_minutes() - 900.0) / 90.0, 0.0, 1.0), float(storm.get("lamp_gain", 0.0)))
	view.set_lamp_gain(lerpf(LAMP_GAIN_DAY, 1.0, night))


## Whoever crossed into a new outdoor ground cell leaves a mark: people (deeper
## when running, deepest where one went down) and the dead alike. Nothing reads
## the marks back; falling snow fills them (_update_snow).
func _mark_tracks() -> void:
	if snow_tracks == null:
		snow_tracks = SnowTracks.new(grid.width * grid.height)
	for p in people:
		if not p.is_alive():
			continue
		_mark_step("p%d" % p.get_instance_id(), p.position, "drag" if p.downed_marked else ("run" if p.is_running_now() else "walk"))
	for z in zombies.list:
		if String(z["state"]) in ["dead", "frozen"]:
			continue
		_mark_step("z%d" % int(z["id"]), z["pos"], "walk")
	view.update_tracks(snow_tracks.take_changed())


func _mark_step(who: String, at: Vector3, kind: String) -> void:
	var cell := FieldGrid.cell_of(at)
	if level_of(at) != 0 or not grid.inside(cell) or grid.indoor(cell):
		track_last.erase(who)
		return
	var i := grid.index(cell)
	if int(track_last.get(who, -1)) == i:
		return
	track_last[who] = i
	snow_tracks.press(i, kind)


## Tactical pause fades the world like an old photo (shaders.md 2장); people,
## the dead and the HUD do not read fx_fade and keep their colour.
func _update_fade(delta: float) -> void:
	var target := 1.0 if paused and not ended else 0.0
	var fade: float = fx_params["fx_fade"]
	if is_equal_approx(fade, target):
		return
	fx_params["fx_fade"] = move_toward(fade, target, delta / FADE_TIME)
	FxState.apply({"fx_fade": fx_params["fx_fade"]})


## Dusk dims the arrival light towards the night band between 15:00 and 16:30.
func _update_light() -> void:
	var t := clampf((clock.game_minutes() - 900.0) / 90.0, 0.0, 1.0)
	# The night band is lamps only; the gray-box field has no lamps yet, so the
	# floors keep people, doors and the platform edge readable after dark.
	sun.light_energy = lerpf(float(fx_light["sun_energy"]), maxf(float(fx_light_night["sun_energy"]), NIGHT_SUN_MIN), t)
	environment.ambient_light_energy = lerpf(float(fx_light["ambient_energy"]), maxf(float(fx_light_night["ambient_energy"]), NIGHT_AMBIENT_MIN), t)


func _build_world() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(fx_params["fx_tint"]).darkened(0.75)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = fx_light["ambient_color"]
	environment.ambient_light_energy = fx_light["ambient_energy"]
	# Weather fog lives in the sight mask (weather.gd); depth fog would wash
	# the whole oblique view out, so it stays off unless asked for.
	environment.fog_enabled = bool(opts.get("fog", false))
	environment.fog_density = 0.012
	environment.fog_light_color = fx_light["fog_color"]
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(FxState.SUN_PITCH, -30, 0)
	sun.light_energy = fx_light["sun_energy"]
	sun.light_color = fx_light["sun_color"]
	sun.shadow_enabled = bool(opts.get("shadows", true)) and bool(storm.get("shadows", true))
	sun.rotation_degrees.x = float(storm.get("sun_pitch", FxState.SUN_PITCH))
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	# Real lights stay at two (Mobile: eight a mesh); every other lamp is the mask.
	lantern = _warm_light(float(Person.LAMP_CHIEF["reach"]), float(Person.LAMP_CHIEF["strength"]))
	lantern.visible = false
	firebox = _warm_light(4.0, 0.8)
	for l in data["lights"]:
		if l["kind"] == "firebox":
			firebox.omni_range = float(l["reach"])
			firebox.light_energy = float(l["strength"])
			firebox.position = FieldGrid.center(l["cell"]) + Vector3(0, 0.8, 0.6)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = cam_size
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)
	camera.current = true
	snow = GPUParticles3D.new()
	snow.amount = maxi(weather.particles(), 1)
	snow.lifetime = 4.0
	snow.visibility_aabb = AABB(Vector3(-30, -2, -20), Vector3(60, 14, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 0.5, 20)
	pm.direction = Vector3(weather.wind_dir.x * weather.wind, -1, weather.wind_dir.y * weather.wind)
	pm.spread = 10.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0.2, -0.6, 0)
	snow.process_material = pm
	# Flakes take the weather tint and the pause fade from the fx library.
	var flake := QuadMesh.new()
	flake.size = Vector2(0.1, 0.1)
	var fm := ShaderMaterial.new()
	fm.shader = PrecipShader
	fm.set_shader_parameter("shape", 1)
	fm.set_shader_parameter("opacity", 0.85)
	flake.material = fm
	snow.draw_pass_1 = flake
	snow.emitting = bool(opts.get("snow", true)) and weather.particles() > 0
	add_child(snow)
	_build_storm()


## Snow layers and the screen layer of a storm stop; nothing on other stops.
func _build_storm() -> void:
	if storm.is_empty():
		return
	# The stage's layers stand in for the plain snowfall.
	snow.emitting = false
	if bool(opts.get("snow", true)):
		for spec in storm["layers"]:
			var p := StormLook.new_layer()
			var at := StormLook.aim_layer(p, spec, weather.wind_dir)
			add_child(p)
			storm_layers.append([p, at])
	var layer := CanvasLayer.new()
	layer.layer = 5   # over the world, under the HUD (10)
	add_child(layer)
	storm_port = SubViewport.new()
	storm_port.transparent_bg = true
	storm_port.disable_3d = true
	storm_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(storm_port)
	storm_view = TextureRect.new()
	storm_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	storm_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	storm_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	storm_view.stretch_mode = TextureRect.STRETCH_SCALE
	storm_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	storm_view.texture = storm_port.get_texture()
	# What a see-through viewport holds is already weighted by its alpha.
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	storm_view.material = blend
	layer.add_child(storm_view)
	if float(storm["edge_frost"]) > 0.0:
		storm_frost = Control.new()
		storm_frost.set_anchors_preset(Control.PRESET_FULL_RECT)
		storm_frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fm := ShaderMaterial.new()
		fm.shader = load("res://fx/shaders/screen_overlay.gdshader")
		fm.set_shader_parameter("vignette", 0.0)
		fm.set_shader_parameter("grain", 0.0)
		fm.set_shader_parameter("edge_frost", float(storm["edge_frost"]))
		for _i in range(4):
			var strip := ColorRect.new()
			strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			strip.material = fm
			storm_frost.add_child(strip)
		layer.add_child(storm_frost)
	storm_screen = ColorRect.new()
	storm_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_storm_port()
	var m := ShaderMaterial.new()
	m.shader = load("res://fx/shaders/screen_overlay.gdshader")
	m.set_shader_parameter("vignette", 0.0)
	m.set_shader_parameter("grain", 0.0)
	m.set_shader_parameter("front", float(storm["front"]))
	m.set_shader_parameter("whiteout", float(storm["whiteout"]))
	# Frost is the full-size strips' (storm_frost); here it would only blur.
	m.set_shader_parameter("edge_frost", 0.0)
	# The camera looks north from above: world z runs down the screen.
	m.set_shader_parameter("storm_dir", Vector2(weather.wind_dir.x, weather.wind_dir.y * 0.7))
	storm_screen.material = m
	storm_port.add_child(storm_screen)


func _fit_storm_port() -> void:
	var want := Vector2i((Vector2(get_viewport().get_visible_rect().size) * STORM_SCREEN_SCALE).ceil()).max(Vector2i(8, 8))
	if storm_port.size != want:
		storm_port.size = want
		storm_screen.position = Vector2.ZERO
		storm_screen.size = Vector2(want)
	if storm_frost == null:
		return
	# Top and bottom run the whole width; left and right fill in between.
	var view := Vector2(get_viewport().get_visible_rect().size)
	var deep := minf(ceilf((float(storm["edge_frost"]) * FROST_REACH + FROST_MARGIN) * view.y), view.y * 0.5)
	if storm_frost.get_child(0).size == Vector2(view.x, deep):
		return
	var rects := [Rect2(0, 0, view.x, deep), Rect2(0, view.y - deep, view.x, deep),
			Rect2(0, deep, deep, view.y - deep * 2.0), Rect2(view.x - deep, deep, deep, view.y - deep * 2.0)]
	for i in range(4):
		var strip: ColorRect = storm_frost.get_child(i)
		strip.position = rects[i].position
		strip.size = rects[i].size


## Lamps that are on, nearest the middle of the view first (at most 8): where
## each is on the screen (0..1), its reach as a share of the screen height and
## its strength. The snow-fog thins round them (screen_overlay glow).
func storm_glows() -> Array:
	var out: Array = []
	if storm_screen == null or float(storm["whiteout"]) <= 0.0:
		return out
	var now := _light_minutes()
	var fire := _tower_fire()
	var raid := _raiders_in()
	var spots: Array = []
	for l in data["lights"]:
		if LampLight.is_on(l, now, fire, raid):
			spots.append([FieldGrid.center(l["cell"]) + Vector3(0, 1.2, 0), float(l.get("reach", 3.0)), float(l.get("strength", 0.6))])
	var dark := clock.is_dark()
	for p in people:
		if p.is_alive() and p.lamp_lit(dark, level_of(p.position) < 0):
			spots.append([p.position + Vector3(0, 1.2, 0), float(p.lamp["reach"]), float(p.lamp["strength"])])
	spots.sort_custom(func(a, b): return a[0].distance_squared_to(cam_focus) < b[0].distance_squared_to(cam_focus))
	var size := get_viewport().get_visible_rect().size
	for spot in spots:
		if out.size() >= 8:
			break
		var uv: Vector2 = camera.unproject_position(spot[0]) / size
		if uv.x < -0.1 or uv.x > 1.1 or uv.y < -0.1 or uv.y > 1.1:
			continue
		out.append(Vector4(uv.x, uv.y, spot[1] / maxf(camera.size, 0.01), clampf(spot[2], 0.0, 1.0)))
	return out


func set_storm_cut(n: int) -> void:
	storm_cut = posmod(n, STORM_CUTS.size())
	for row in storm_layers:
		row[0].visible = storm_cut < 2
		row[0].emitting = storm_cut < 2
	if storm_screen != null:
		var on := storm_cut == 0 or storm_cut == 2
		storm_screen.visible = on
		storm_view.visible = on
		if storm_frost != null:
			storm_frost.visible = on
		storm_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _update_storm() -> void:
	for row in storm_layers:
		row[0].position = cam_focus + row[1]
	if storm_screen == null:
		return
	_fit_storm_port()
	var glows := storm_glows()
	var m := storm_screen.material as ShaderMaterial
	m.set_shader_parameter("glow_count", glows.size())
	while glows.size() < 8:
		glows.append(Vector4.ZERO)
	m.set_shader_parameter("glow", glows)


func _spawn_people() -> void:
	var loadout: Array = opts.get("squad", default_squad("crude"))
	var spots: Array = data["spawns"]["squad"]
	for i in range(loadout.size()):
		var row: Dictionary = loadout[i]
		var p := make_person(row, FieldGrid.center(spots[i % spots.size()]))
		squad.append(p)
		receipt.person("sent", p.pid)
	player = squad[0]
	if bool(opts.get("raiders", true)):
		var rows := [
			{"id": "npc_raider_1", "name": "약탈자", "role": "raider", "skills": {"strength": 5, "melee": 2, "shooting": 3, "stealth": 1, "search": 1}, "hands": [["pipe_shotgun", "crude", 1.0]], "brain": "shooter"},
			{"id": "npc_raider_2", "name": "약탈자", "role": "raider", "skills": {"strength": 5, "melee": 2, "shooting": 2, "stealth": 2, "search": 1}, "hands": [["pistol", "crude", 0.7]], "brain": "advancer"},
			{"id": "npc_raider_3", "name": "약탈자", "role": "raider", "skills": {"strength": 6, "melee": 4, "shooting": 1, "stealth": 2, "search": 1}, "hands": [["axe", "factory", 0.8]], "brain": "flanker"},
		]
		# A map with no place for them has none.
		var rs: Array = data["spawns"].get("raiders", [])
		for i in range(mini(rows.size(), rs.size())):
			var r := make_person(rows[i], FieldGrid.center(rs[i]))
			r.brain = {"role": rows[i]["brain"], "state": "idle", "aware": 0.0, "morale": 1.0, "seen_t": 0.0, "last_seen": Vector3.ZERO, "home": r.position, "aim_t": 0.0, "target": null, "fight_t": 0.0}
			r.add_item("med_box", 1)
			raiders.append(r)


func default_squad(pipe_quality: String) -> Array:
	return [
		{"id": "p_chief", "name": "열차장", "role": "chief", "skills": {"strength": 5, "melee": 3, "shooting": 2, "stealth": 2, "search": 2}, "hands": [["axe", "factory", 0.9], ["pistol", "factory", 0.8]], "items": {"bandage": 2, "cloth": 1}},
		{"id": "p_guard_marek", "name": "마레크", "role": "companion", "skills": {"strength": 6, "melee": 2, "shooting": 4, "stealth": 1, "search": 1}, "hands": [["pipe_shotgun", pipe_quality, 0.9], ["knife", "factory", 0.8]], "items": {"bandage": 1}},
		{"id": "p_med_joanna", "name": "요안나", "role": "companion", "medical": "skilled", "skills": {"strength": 4, "melee": 1, "shooting": 4, "stealth": 3, "search": 3}, "hands": [["bow", "factory", 0.9], ["crowbar", "factory", 0.9]], "items": {"bandage": 3, "medkit": 1, "tweezers": 1, "needle_thread": 3}},
		{"id": "p_tail_tomasz", "name": "토마시", "role": "companion", "skills": {"strength": 7, "melee": 3, "shooting": 1, "stealth": 1, "search": 2}, "hands": [["crowbar", "factory", 0.8], ["knife", "factory", 0.7]], "items": {"bandage": 1}, "bag": "big_pack"},
	]


func make_person(row: Dictionary, at: Vector3) -> Person:
	var p := Person.new()
	add_child(p)
	p.setup(String(row["id"]), String(row["name"]), String(row["role"]), at)
	p.skills = row.get("skills", p.skills).duplicate()
	p.medical = String(row.get("medical", "none"))
	p.bag = String(row.get("bag", "pack"))
	var slots: Array = []
	for h in row.get("hands", []):
		var id: String = h[0]
		var mag: int = int(W.get_data(id).get("mag", 0))
		slots.append({"id": id, "quality": h[1] if h.size() > 1 else "factory", "condition": float(h[2]) if h.size() > 2 else 1.0, "loaded": mag})
	p.set_weapon_slots(slots)
	for id in row.get("items", {}):
		p.add_item(id, int(row["items"][id]))
	p.facing = PI
	people.append(p)
	return p


func _spawn_dead() -> void:
	var s: Dictionary = data["spawns"]
	# Every "dead_..." list of cells is a group standing about out of doors.
	for key: String in s:
		if not key.begins_with("dead_") or key == "dead_levels":
			continue
		for c in s[key]:
			zombies.spawn("dead", FieldGrid.center(c))
	for key in ["clothed_station", "clothed_shed"]:
		for c in s.get(key, []):
			zombies.spawn("clothed", FieldGrid.center(c))
	# The dead indoors, on every floor and in the cellar.
	for row in s.get("dead_levels", []):
		zombies.spawn("dead", lift(row[0], int(row[1])))
	for c in s.get("frozen_siding", []):
		zombies.spawn("frozen", FieldGrid.center(c), {"depth": rng.randf_range(0.6, 1.0)})
	# Those first put inside the place (the zones a map names in
	# "interior_kind_slots"): waking one of them is counted (user decision 177).
	var inside: Array = []
	for slot: Dictionary in data.get("interior_kind_slots", []):
		inside.append(String(slot.get("zone", "")))
	for z in zombies.list:
		if inside.has(grid_at(z["pos"]).zone_at(FieldGrid.cell_of(z["pos"]))):
			z["interior"] = true
	# A switch of the start screen, for looking at them: with the lungers on,
	# every one of the dead put here that stands is one.
	if bool(opts.get("lungers", false)) and bool(opts.get("lungers_many", false)):
		for z in zombies.list:
			if z["kind"] != "frozen" and z["stander"]:
				z["lunger"] = true


func people_alive() -> Array:
	var out: Array = []
	for p in people:
		if p.is_alive():
			out.append(p)
	return out


func allies_alive() -> Array:
	var out: Array = []
	for p in people:
		if p.is_alive() and p.team != "raider":
			out.append(p)
	return out


# ---------------------------------------------------------------- levels

## The map the field stands on. Everything that reads the ground goes through
## these four, so a stop of several joined maps can hand over a new one here.
func _take_map(d: Dictionary) -> void:
	data = d
	grid = data["grid"]
	levels = data["levels"]
	stairs = data["stairs"]
	seen_memory.resize(grid.width * grid.height * 4)


## Floors are stacked LEVEL_H apart; position.y says which one a body is on.
func level_of(at: Vector3) -> int:
	return clampi(roundi(at.y / FieldMaps.LEVEL_H), -1, 2)


func grid_at(at: Vector3) -> FieldGrid:
	return levels.get(level_of(at), grid)


func level_y(lv: int) -> float:
	return lv * FieldMaps.LEVEL_H


## Centre of cell c on level lv.
func lift(c: Vector2i, lv: int) -> Vector3:
	return FieldGrid.center(c) + Vector3(0, lv * FieldMaps.LEVEL_H, 0)


## Sight and memory keys: one slice of the map per level, cellar first.
func seen_key(at: Vector3) -> int:
	return (level_of(at) + 1) * grid.width * grid.height + grid.index(FieldGrid.cell_of(at))


## What the camera draws from where the player stands: the cellar alone, or
## the ground and every floor up to the player's own (nothing above it).
func level_shown(lv: int) -> bool:
	var pl := level_of(player.position)
	return lv == -1 if pl < 0 else lv >= 0 and lv <= pl


## A walkable cell for people (or the dead) near at, on at's level.
func walkable_near(at: Vector3, for_dead: bool = false, r: int = 2) -> Vector3:
	var c: Vector2i = grid_at(at).nearest_walkable(FieldGrid.cell_of(at), for_dead, r)
	return at if c == FieldGrid.cell_of(at) else lift(c, level_of(at))


## Line of sight between two bodies: only on the same floor, except that from
## upstairs the eye goes out of a window and down to the ground (open air).
func sight_clear(a: Vector3, b: Vector3) -> bool:
	var la := level_of(a)
	var lb := level_of(b)
	if la == lb or (la > 0 and lb == 0) or (lb > 0 and la == 0):
		return levels[maxi(la, lb)].line_clear(FieldGrid.cell_of(a), FieldGrid.cell_of(b)) and (la == lb or _open_below(b if la > lb else a, maxi(la, lb)))
	return false


## The cell under a ground body is open air on the upper level (no floor over it).
func _open_below(ground: Vector3, upper: int) -> bool:
	return levels[upper].solid_at(FieldGrid.cell_of(ground)) == FieldGrid.Solid.AIR


## Path across floors: walk to a stair, step onto the other level, go on.
## Ladders are not taken by a path (the dead cannot climb; people use the
## ladder spot): a goal up a ladder ends at the foot of it, under the goal.
func find_path(from: Vector3, to: Vector3, for_dead: bool = false) -> PackedVector3Array:
	var lv := level_of(from)
	var goal := level_of(to)
	var out := PackedVector3Array()
	var at := from
	var guard := 0
	while lv != goal and guard < 4:
		guard += 1
		var next_lv := lv + (1 if goal > lv else -1)
		var best: Dictionary = {}
		var best_cost := INF
		for s in stairs:
			if s["ladder"] or not ((s["low"] == lv and s["high"] == next_lv) or (s["high"] == lv and s["low"] == next_lv)):
				continue
			if not _joined(lv, FieldGrid.cell_of(at), s["cell"]) or not _reaches(s["cell"], next_lv, FieldGrid.cell_of(to), goal):
				continue
			var c := FieldGrid.center(s["cell"])
			var cost := Vector2(at.x - c.x, at.z - c.z).length() + Vector2(c.x - to.x, c.z - to.z).length()
			if cost < best_cost:
				best_cost = cost
				best = s
		if best.is_empty():
			# No stair (only a ladder up there): go as near as this floor allows.
			goal = lv
			break
		var foot := lift(best["cell"], lv)
		if FieldGrid.cell_of(at) != best["cell"]:
			var leg: PackedVector3Array = levels[lv].find_path(at, foot, for_dead)
			if leg.is_empty():
				return PackedVector3Array()
			_append_level(out, leg, lv)
		out.append(foot)
		at = lift(best["cell"], next_lv)
		out.append(at)
		lv = next_lv
	if lv != goal:
		return PackedVector3Array()
	if FieldGrid.cell_of(at) == FieldGrid.cell_of(to) and not out.is_empty():
		return out
	var last: PackedVector3Array = levels[lv].find_path(at, to, for_dead)
	if last.is_empty() and not out.is_empty():
		return PackedVector3Array()
	_append_level(out, last, lv)
	return out


## Upstairs and the cellar have no doors, so which rooms join never
## changes: label them once. The ground is taken as one piece (A* decides).
var _rooms_of: Dictionary = {}


func _joined(lv: int, a: Vector2i, b: Vector2i) -> bool:
	if lv == 0:
		return true
	if not _rooms_of.has(lv):
		_rooms_of[lv] = _label_rooms(levels[lv])
	var lg: FieldGrid = levels[lv]
	var labels: PackedInt32Array = _rooms_of[lv]
	var la := labels[lg.index(lg.nearest_walkable(a, false, 2))] if lg.inside(a) else -1
	var lb := labels[lg.index(lg.nearest_walkable(b, false, 2))] if lg.inside(b) else -1
	return la >= 0 and la == lb


## From cell c on level lv, can a body get to cell to on level goal by stairs?
func _reaches(c: Vector2i, lv: int, to: Vector2i, goal: int) -> bool:
	if lv == goal:
		return _joined(lv, c, to)
	var next_lv := lv + (1 if goal > lv else -1)
	for s in stairs:
		if s["ladder"] or not ((s["low"] == lv and s["high"] == next_lv) or (s["high"] == lv and s["low"] == next_lv)):
			continue
		if _joined(lv, c, s["cell"]) and _reaches(s["cell"], next_lv, to, goal):
			return true
	return false


static func _label_rooms(lg: FieldGrid) -> PackedInt32Array:
	var labels := PackedInt32Array()
	labels.resize(lg.width * lg.height)
	labels.fill(-1)
	var next := 0
	for i in range(labels.size()):
		var c := Vector2i(i % lg.width, i / lg.width)
		if labels[i] >= 0 or not lg.people_can_walk(c):
			continue
		var todo: Array[Vector2i] = [c]
		labels[i] = next
		while not todo.is_empty():
			var q: Vector2i = todo.pop_back()
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = q + o
				if lg.inside(n) and labels[lg.index(n)] < 0 and lg.people_can_walk(n):
					labels[lg.index(n)] = next
					todo.append(n)
		next += 1
	return labels


func _append_level(out: PackedVector3Array, leg: PackedVector3Array, lv: int) -> void:
	for q in leg:
		out.append(Vector3(q.x, lv * FieldMaps.LEVEL_H, q.z))


## The straight line on the screen through a point, moved to height y
## (a finger on the floor you stand on, read against a body on another).
func shift_to_height(world: Vector3, y: float) -> Vector3:
	var dir := -camera.global_transform.basis.z
	if absf(dir.y) < 0.0001:
		return world
	return world + dir * ((y - world.y) / dir.y)


# ---------------------------------------------------------------- loop

func _notification(what: int) -> void:
	# A call, the home button or a dropped screen stops the field (reference harvest r1, #16).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		interrupt()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		welcome_back()


func interrupt() -> void:
	# Fingers down when the app goes away never come back up, paused or not.
	if hud != null:
		hud.drop_touch()
	if ended or paused:
		return
	paused = true
	away = true


## Back from an interrupt: one line, once (ui_states N4). Only when the app
## paused the field; a pause the player chose is not announced again.
func welcome_back() -> void:
	if not away:
		return
	away = false
	if hud != null and not ended:
		hud.toast("멈춰 둔 자리다.")


func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	if arrive_t >= 0.0:
		_arrive(delta)
	elif not ended and not paused:
		_step(delta * slow)
		_update_snow()
	_update_fade(delta)
	if leave_t >= 0.0:
		leave_t += delta
		view.slide_train(train_roll(leave_t))
	_update_lantern(delta)
	_update_camera(delta)
	vis_t -= delta
	if vis_t <= 0.0:
		vis_t = 0.1
		_refresh_vision()
	zombies.render(camera, seen_now, mask_on)
	for p in people:
		if p != player and p.turn_rate <= 0.0:
			p.turn_rate = deg_to_rad(TURN_DEG_PER_S) * (0.85 + 0.3 * p.name_unit())
			p.look = p.facing
		p.visible = level_shown(level_of(p.position)) and _person_visible(p) and not rode_off.has(p) and arrive_t < 0.0
		p.refresh_view(p.visible)
	hud.tick(delta)
	audio.tick(delta)


func _step(delta: float) -> void:
	clock.advance(delta)
	weather.dusk = clock.dusk_share()
	var now := clock.elapsed
	radio_t -= delta
	_tick_radio(delta)
	for p in people:
		_update_person(p, delta)
	zombies.update(delta)
	ai.update(delta)
	_left_behind()
	combat.update(delta)
	_update_hordes(delta)
	_update_spawns(delta)
	_update_blood(delta)
	_update_night(delta)
	_update_zone(delta)
	actions.update(delta)
	holdout.tick(delta)
	holdout.watch(delta)
	holdout.den_watch()
	_check_end()
	var keep: Array = []
	for s in sounds:
		if now - float(s["t"]) < 1.6:
			keep.append(s)
	sounds = keep


func _update_zone(delta: float) -> void:
	var z := grid.zone_at(FieldGrid.cell_of(player.position))
	if z != zone_now:
		zone_now = z
		telemetry.zone_enter(z, clock.elapsed)
	telemetry.zone_tick(z, delta)
	var looted := false
	for id in player.items:
		if STOCK_OF.has(id):
			looted = true
	if looted and player.moving:
		telemetry.carry_time(delta)
	var pl := level_of(player.position)
	view.show_levels(pl)
	view.cut_away(grid_at(player.position).building_at(FieldGrid.cell_of(player.position)), pl)


# ---------------------------------------------------------------- people

func _update_person(p: Person, delta: float) -> void:
	if not p.is_alive():
		return
	var cell := FieldGrid.cell_of(p.position)
	var lg := grid_at(p.position)
	var indoor := lg.indoor(cell)
	var stove := near_stove(p.position)
	var ctx := {"running": p.is_running_now(), "swinging": p.swing_t > 0.0, "carry_state": p.carry_state(), "cold_level": p.cold_level(), "indoor_rest": indoor and not p.moving}
	for ev in p.body.tick(delta, ctx):
		_on_body_event(p, ev)
	p.heat.tick(delta, {"ambient_c": AMBIENT_C, "indoor": indoor and not building_open(lg.building_at(cell)), "stove": stove, "warmth": float(p.coat["warmth"]) + (0.1 if p.gloves else 0.0), "windproof": float(p.coat["windproof"]), "moving": p.moving, "wind": 0.0 if indoor else weather.wind})
	if weather.always_cold() and not indoor and not stove:
		p.heat.heat = minf(p.heat.heat, 60.0)
	p.panic = maxf(0.0, p.panic - delta * 0.08)
	if not p.grabbers.is_empty():
		p.grab_left -= delta
		if p.grab_left <= 0.0:
			combat.bite(p)
		return
	if p.fallen_t > 0.0:
		p.fallen_t -= delta
		return
	if p.body.downed:
		return
	# Pushing the stick walks away from slow work (search, prying, treating).
	if p.stick.length() > 0.3 and STICK_BREAKS.has(p.action):
		p.cancel_action()
	if p.action != "":
		# Each action takes its body multiplier once, here (not also in its length).
		var rate := 1.0 if p.action == "climb" else float(p.mults()["swap" if p.action == "swap" else "hands"])
		p.action_t -= delta * rate
		if p.action_t <= 0.0:
			var done := p.action_done
			p.cancel_action()
			if done.is_valid():
				done.call()
		return
	if p.stick != Vector2.ZERO or p.drive_speed > 0.0:
		_drive(p, delta)
	else:
		_move_person(p, delta)


## Left-thumb walking (field_unified 10, user 17:32): the direction follows
## the thumb at once; the body takes a moment to get going and to stop, more
## so loaded, worn out or on ice. A hard turn at a run drops to a walk first.
func _drive(p: Person, delta: float) -> void:
	var push := p.stick.length()
	var lg := grid_at(p.position)
	var cell := FieldGrid.cell_of(p.position)
	var floor_kind := lg.floor_at(cell)
	var heavy := 1.0 + 0.35 * maxi(0, p.carry_state()) + maxf(0.0, 1.0 - float(p.mults()["move"]))
	var fast := p.drive_speed > Person.WALK * 1.1
	var want := 0.0
	if push > 0.05:
		p.path = PackedVector3Array()
		p.brain.erase("goal")
		var dir := Vector3(p.stick.x, 0, p.stick.y).normalized()
		if fast and p.drive_dir.dot(dir) < 0.0:
			p.drive_speed = minf(p.drive_speed, Person.WALK * 0.6)
		p.drive_dir = dir
		if not p.aim.active:
			p.facing = atan2(dir.x, dir.z)   # aiming, you walk and keep the gun on it
		want = p.speed(floor_kind) * clampf(push * 1.6, 0.35, 1.0)
	var feel: Array = INERTIA.get(String(opts.get("inertia", "now")), INERTIA["now"])
	if want > p.drive_speed:
		p.drive_speed = minf(want, p.drive_speed + want / (float(feel[0]) * heavy) * delta)
	else:
		var stop_t := float(feel[2] if fast else feel[1]) * heavy * (2.0 if floor_kind == FieldGrid.Floor.ICE else 1.0)
		p.drive_speed = maxf(want, p.drive_speed - maxf(p.drive_speed, Person.WALK) / stop_t * delta)
	if p.drive_speed <= 0.01:
		p.drive_speed = 0.0
		p.moving = false
		return
	var step := p.drive_dir * p.drive_speed * delta
	var dest := p.position + step
	var dc := FieldGrid.cell_of(dest)
	if lg == grid and grid.doors.has(dc) and grid.doors[dc]["state"] == "closed":
		p.drive_speed = 0.0
		actions.open_door_on_way(p, dc)
		return
	if lg.blocks_body(dc):
		dest = _slide(p.position, step)
	if lg == grid and grid.windows.has(dc) and grid.windows[dc]["broken"] and not p.brain.get("vaulted_" + str(dc), false):
		actions.vault_window(p, dc)
	p.position = dest
	p.moving = true
	_footsteps(p, delta, dc)


func _move_person(p: Person, delta: float) -> void:
	if p.path.is_empty():
		p.moving = false
		return
	var next := p.path[0]
	var d := next - p.position
	d.y = 0
	if d.length() < 0.12:
		# A stair: the next point is the same spot one floor up or down.
		p.position.y = next.y
		p.path.remove_at(0)
		if p.path.is_empty():
			p.moving = false
		return
	var cell := FieldGrid.cell_of(p.position)
	var lg := grid_at(p.position)
	var spd := p.speed(lg.floor_at(cell))
	if spd <= 0.0:
		p.moving = false
		if p == player:
			hud.toast("너무 무겁다. 짐을 덜어야 움직인다.")
			p.stop()
		return
	var step := d.normalized() * minf(spd * delta, d.length())
	var dest := p.position + step
	var dc := FieldGrid.cell_of(dest)
	if lg == grid and grid.doors.has(dc) and grid.doors[dc]["state"] == "closed":
		actions.open_door_on_way(p, dc)
		return
	if lg.blocks_body(dc):
		dest = _slide(p.position, step)
	if lg == grid and grid.windows.has(dc) and grid.windows[dc]["broken"] and not p.brain.get("vaulted_" + str(dc), false):
		actions.vault_window(p, dc)
	p.facing = atan2(step.x, step.z)
	p.position = dest
	p.moving = true
	_footsteps(p, delta, dc)


func _slide(at: Vector3, step: Vector3) -> Vector3:
	var lg := grid_at(at)
	var r := at
	var cand := r + Vector3(step.x, 0, 0)
	if not lg.blocks_body(FieldGrid.cell_of(cand)):
		r.x = cand.x
	cand = r + Vector3(0, 0, step.z)
	if not lg.blocks_body(FieldGrid.cell_of(cand)):
		r.z = cand.z
	return r


func _footsteps(p: Person, delta: float, cell: Vector2i) -> void:
	var running := p.is_running_now()
	var lg := grid_at(p.position)
	var floor_kind := lg.floor_at(cell)
	p.brain["step_t"] = float(p.brain.get("step_t", 0.0)) - delta
	if p.brain["step_t"] <= 0.0:
		p.brain["step_t"] = 0.5
		var glass: bool = lg.windows.has(cell) and lg.windows[cell]["glass"]
		var trait_mult := 1.0
		var r := SimNoise.footstep_radius(running, FieldGrid.FLOOR_SOUND[floor_kind], trait_mult, p.crouched, int(p.skills["stealth"]), glass) * weather.sound_mult(true)
		zombies.hear(p.position, SimNoise.footstep_level(running, glass), r)
		if p == player and audio != null:
			audio.footstep(p.position, running)
		_wake_frozen_near(p)
	if running:
		p.brain["run_score_t"] = float(p.brain.get("run_score_t", 0.0)) + delta
		if p.brain["run_score_t"] >= 5.0:
			p.brain["run_score_t"] = 0.0
			_score(SimNoise.Level.NORMAL, "run")
		# Ice: running on ice can throw you down (body_injury 3.2).
		if floor_kind == FieldGrid.Floor.ICE:
			p.ice_t += delta
			if p.ice_t >= 3.0:
				p.ice_t = 0.0
				if rng.randf() < 0.1:
					combat.fall(p, "얼음에 미끄러졌다")
			if p == player and not ice_warned:
				ice_warned = true
				hud.toast("얼음 위에선 걷는 게 좋다.")
		elif p.carry_state() >= 2 and rng.randf() < delta * 0.03:
			combat.fall(p, "짐에 눌려 넘어졌다")


## Frozen ones wake when someone walks right up to them (crouching gets closer).
func _wake_frozen_near(p: Person) -> void:
	var reach := 0.8 if p.crouched else 1.7
	for z in zombies.list:
		if z["state"] == "frozen" and z["pos"].distance_to(p.position) < reach:
			zombies.wake(z)


func near_stove(at: Vector3) -> bool:
	for s in data["stoves"]:
		if s["lit"] and lift(s["cell"], int(s.get("level", 0))).distance_to(at) < 4.0:
			var b: int = s["building"]
			if b < 0 or not building_open(b):
				return true
	# The first stop's water tower, while its fire burns.
	var tower: Dictionary = data["spots"].get("water_tower", {})
	if tower.get("state", "") == "fire" and FieldGrid.center(tower["cell"]).distance_to(at) < 3.5:
		return true
	return false


## A building with a broken window no longer keeps the warmth (body_injury 3.1).
func building_open(b: int) -> bool:
	if b < 0:
		return true
	return bool(data["buildings"][b]["window_broken"])


func _on_body_event(p: Person, ev: String) -> void:
	match ev:
		"downed":
			p.cancel_action()
			p.stop()
			say(p, "%s 쓰러졌다." % p.display_name)
			telemetry.injury(clock.elapsed, p.pid, "downed")
			if p.team == "raider":
				ai.raider_downed(p)
		"died":
			on_person_died(p)
		"bleed_stopped":
			if p.team != "raider":
				say(p, "%s 피가 멎었다." % p.display_name)
		"window_closed":
			if p.body.infected and p.team != "raider":
				say(p, "%s 열이 오른다." % p.display_name)
		"exhausted_heavy":
			if p == player:
				hud.toast("숨이 차서 더는 뛰지 못한다.")


func on_person_died(p: Person) -> void:
	p.body.dead = true
	p.cancel_action()
	p.stop()
	for z in p.grabbers.duplicate():
		zombies.release(z, p.position, false)
	p.grabbers.clear()
	telemetry.injury(clock.elapsed, p.pid, "dead")
	if p.team != "raider":
		receipt.person("dead", p.pid)
		say(p, "%s 죽었다." % p.display_name)
		if squad.has(p):
			shout_near(p, "rage")
	# Everyone is already infected: the body stands up again (zombies.md).
	var z := zombies.add_rising(p.position, p.display_name)
	p.brain["rising_id"] = z["id"]
	if p.team == "raider":
		# What a raider had stays on it until someone goes through it (user 2026-10-11).
		var loot: Array = []
		for h in p.hands:
			loot.append({"id": h["id"], "n": 1, "weapon": h.duplicate()})
		for item in p.items:
			loot.append({"id": item, "n": p.items[item]})
		p.set_weapon_slots([])
		zombies.set_loot(z, loot)
	else:
		for item in p.items:
			ground_items.append({"pos": p.position, "id": item, "n": p.items[item]})
	p.items.clear()
	if p == player:
		_check_end()


# ---------------------------------------------------------------- sound, blood, night

## Every noise goes through here: the dead hear it, the next horde comes
## earlier, the frozen wake, raiders turn, the HUD shows it. The dead walk to
## where the sound was, not to whoever made it (body_injury 8.2).
func make_sound(at: Vector3, level: int, tag: String, from: Person = null) -> void:
	var now := clock.elapsed
	var indoor := grid_at(at).indoor(FieldGrid.cell_of(at))
	# Next to a sewer mouth the sound rings in the tunnel: one step louder,
	# and a loud one wakes that hole for the next horde (field_unified 6).
	var hole := sewer_near(at, 12.0)
	if hole != "" and sewer_near(at, 4.0) != "" and level >= SimNoise.Level.NORMAL:
		level = SimNoise.clamp_level(level + 1)
	if hole != "" and level >= SimNoise.Level.LOUD and director.call_from(hole):
		if forecast_precision > 0 or player.position.distance_to(at) < 14.0:
			set_radio("기관사: 굴 쪽이 울린다. 다음 것들은 %s에서 나온다." % director.name_of(hole), "info", entry_pos(hole))
	var radius := SimNoise.radius(level, indoor, director.call_range_mult(now)) * weather.sound_mult(false)
	zombies.hear(at, level, radius)
	_score(level, tag)
	sounds.append({"pos": at, "level": level, "t": now, "tag": tag})
	if level >= SimNoise.Level.LOUD:
		last_loud = at
		director.noticed(now)
	if audio != null:
		audio.on_sound(at, level, tag)
	if level >= SimNoise.Level.LOUD:
		ai.raiders_hear(at, radius, from)
	if tag == "gun":
		shot_times.append(now)
		casings += 1
		last_gun_t = now
		# Indoor gunfire deafens the shooter and anyone within 2 m for 5 s.
		if indoor and from != null and (from == player or from.position.distance_to(player.position) < 2.0):
			deaf_t = 5.0


## Key of an open sewer mouth within r metres of at, or "".
func sewer_near(at: Vector3, r: float) -> String:
	for key in data["manholes"]:
		if not director.is_open(key):
			continue
		if sewer_pos(key).distance_to(at) <= r:
			return key
	return ""


func sewer_pos(key: String) -> Vector3:
	return lift(data["manholes"][key], int(data["manhole_levels"].get(key, 0)))


## Where bodies come in through an entry, on the entry's level.
func entry_pos(key: String, i: int = 0) -> Vector3:
	var cells: Array = data["entries"][key]
	return lift(cells[i % cells.size()], int(data["entry_levels"].get(key, 0)))


func _score(level: int, tag: String) -> void:
	var now := clock.elapsed
	var pts := ledger.add(level, now, tag)
	if pts > 0:
		director.add_noise(pts, now)
		telemetry.noise(now, ledger.total)


## Excessive blood calls the dead (user 2026-10-07, body_injury 8.1): heavy
## bleeding not yet stopped, or clothes soaked from several close kills. It
## leaves a dark trail the dead follow, and every minute it counts as a normal
## sound at that spot, stretched downwind. Light bleeding calls nobody.
func _update_blood(delta: float) -> void:
	var now := clock.elapsed
	for p in people_alive():
		var excessive: bool = p.body.bleed >= 2 or p.blood_soaked
		if not excessive:
			p.brain["blood_noise_t"] = 60.0
			continue
		p.brain["blood_t"] = float(p.brain.get("blood_t", 0.0)) - delta
		if p.brain["blood_t"] <= 0.0:
			p.brain["blood_t"] = 1.5
			blood.append({"pos": p.position, "t": now, "s": 2})
		p.brain["blood_noise_t"] = float(p.brain.get("blood_noise_t", 60.0)) - delta
		if p.brain["blood_noise_t"] <= 0.0:
			p.brain["blood_noise_t"] = 60.0
			zombies.smell(p.position, BLOOD_SCENT_R)
			_score(SimNoise.Level.NORMAL, "blood")
	while blood.size() > 0 and now - float(blood[0]["t"]) > 120.0:
		blood.pop_front()
	while blood.size() > 200:
		blood.pop_front()


## Freshest, closest trail point a zombie at `at` can smell: the same 12 m
## event shape as the minute pulse; falling snow weakens older drops (8.1).
func strongest_scent(at: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_score := 0.0
	var now := clock.elapsed
	var snowing := weather.kinds.has("snow") or weather.kinds.has("blizzard")
	for b in blood:
		var reach: float = BLOOD_SCENT_R * weather.scent_mult(b["pos"], at)
		if snowing and now - float(b["t"]) > 30.0:
			reach *= 0.7
		var d: float = at.distance_to(b["pos"])
		if d > reach:
			continue
		var fresh := 1.0 - (now - float(b["t"])) / 120.0
		var score := fresh * (1.0 - d / reach) + float(b["t"]) * 0.0001
		if score > best_score:
			best_score = score
			best = b
	return best


## After dusk every light-carrier counts as a normal sound each minute.
func _update_night(delta: float) -> void:
	if not clock.is_dark():
		return
	light_t -= delta
	if light_t <= 0.0:
		light_t = 60.0
		lamp_pulse = 1.0
		for p in squad:
			if p.is_alive() and p.lamp_on:
				make_sound(p.position, SimNoise.Level.NORMAL, "light")


## The lanterns go out and on together, the chief's and everyone's (user 2026-10-10).
func lamps_on() -> bool:
	return player.lamp_on


func set_lamps(on: bool) -> void:
	for p in squad + crew:
		p.lamp_on = on
	vis_t = 0.0


## How far the eye reaches of what it would on a clear day: the weather, the
## dark, and the dark with no lantern.
func eye_mult() -> float:
	var dark: bool = clock.is_dark()
	weather.dusk = clock.dusk_share()
	var mult: float = weather.sight_mult(dark)
	return minf(mult, LAMP_OFF_SIGHT) if dark and not lamps_on() else mult


# ---------------------------------------------------------------- hordes

func _update_hordes(delta: float) -> void:
	var now := clock.elapsed
	# Telegraph: a sewer lid rattles 3 s before anything climbs out, and keeps
	# rattling while bodies come through (field_unified 6 '예고 있는 입장').
	var next_key := director.next_entry
	if director.seconds_to_next(now) < 3.0 and director.sewer(next_key):
		rattle[next_key] = maxf(float(rattle.get(next_key, 0.0)), 0.5)
	for s in pending_spawn:
		if director.sewer(s["entry"]) and float(s["t"]) - now < 3.0:
			rattle[s["entry"]] = maxf(float(rattle.get(s["entry"], 0.0)), 0.5)
	for key in rattle.keys():
		rattle[key] -= delta
		if FieldMaps.lid(key) and view.manhole_nodes.has(key):
			var node: MeshInstance3D = view.manhole_nodes[key]
			node.position.y = absf(sin(now * 31.0)) * 0.08 if rattle[key] > 0.0 else 0.0
		if rattle[key] <= 0.0:
			rattle.erase(key)
	for key in lid_open.keys():
		lid_open[key] -= delta
		if lid_open[key] <= 0.0:
			lid_open.erase(key)
			view.update_manhole(key, false)
	if _squad_hunted():
		director.noticed(now)
	elif director.update_lost(now):
		telemetry.lost_at(now)
		set_radio("기관사: 놓친 것 같다. 다음 것들이 늦어진다. 숨 돌려라.")
	var h := director.update(now)
	if not h.is_empty():
		_start_horde(h)
	for idx in hordes:
		var info: Dictionary = hordes[idx]
		if info["cleared"]:
			continue
		var left := 0
		for z in zombies.list:
			if int(z["horde"]) == int(idx) and zombies.threat(z):
				left += 1
		var spawned_all := true
		for s in pending_spawn:
			if int(s["horde"]) == int(idx):
				spawned_all = false
		if spawned_all and (left <= 1 or now - float(info["t"]) > 150.0):
			info["cleared"] = true
			var recent := 0
			for t in shot_times:
				if now - float(t) < 60.0:
					recent += 1
			director.horde_cleared(now, recent)
			telemetry.rest(now, director.rest_until)
			set_radio("기관사: 한 무리 지나갔다. " + director.forecast(now, forecast_precision, clock) + lid_tip())


## Is anything after the squad right now (chasing, or already at someone)?
func _squad_hunted() -> bool:
	for z in zombies.list:
		if z["state"] in ["chase", "attack", "grab"]:
			var v = z["victim"]
			if v == null or v.team != "raider":
				return true
	return false


## Where a horde walks: the last loud sound, or the platform if there was none.
## Not to the squad: hiding has to be worth something (user, build 47).
func horde_target() -> Vector3:
	if last_loud != null:
		return last_loud
	return FieldGrid.center(horde_home())


## The cell by the train a horde walks to with no sound to follow; the radio's
## "near the train" is measured from it too.
func horde_home() -> Vector2i:
	return data["anchors"]["horde_home"]


## Is this place above the train (the side of its upper doors)?
func above_train(at: Vector3) -> bool:
	return at.z < data["train"].position.y + data["train"].size.y * 0.5


## Where what comes in at `from` heads with no sound to follow: the train's
## own side of it, where the train has doors on both.
func horde_home_from(from: Vector3) -> Vector3:
	var anchors: Dictionary = data["anchors"]
	if anchors.has("horde_home_upper") and above_train(from):
		return FieldGrid.center(anchors["horde_home_upper"])
	return FieldGrid.center(horde_home())


## Ways in that are not sewers, in the order the fair spawn tries them.
func road_entries() -> Array:
	var out: Array = []
	for key in director.entries:
		if not director.sewer(key):
			out.append(key)
	return out


func _start_horde(h: Dictionary) -> void:
	var now := clock.elapsed
	var key: String = h["entry"]
	# Fair spawn: roads and the track end never let anything in on screen; pick
	# another road out of sight. Sewer mouths may be on screen: they rattle first.
	if not director.sewer(key) and _entry_on_screen(key):
		for other in road_entries():
			if not _entry_on_screen(other):
				key = other
				break
	hordes[h["index"]] = {"t": now, "cleared": false, "entry": key, "size": h["size"]}
	telemetry.horde(now, int(h["index"]), int(h["size"]), key)
	audio.horde_started()
	var target: Vector3 = last_loud if last_loud != null else horde_home_from(entry_pos(key))
	var gap: float = float(data["entry_gap"].get(key, 0.6))
	var lead := 3.0 if director.sewer(key) else 0.0
	for i in range(int(h["size"])):
		# While the train is held the horde walks to its doors, each body to one.
		pending_spawn.append({"t": now + lead + i * gap, "pos": entry_pos(key, i), "horde": h["index"], "target": holdout.target(i, entry_pos(key, i)) if holdout.on else target, "entry": key})
	if director.sewer(key):
		set_radio("기관사: %s이 덜컹거린다. 올라온다." % director.name_of(key) if FieldMaps.lid(key) else "기관사: %s에서 소리가 울린다. 올라온다." % director.name_of(key), "urgent", entry_pos(key))
	else:
		set_radio("기관사: %s, 저것들이 들어온다." % director.name_of(key), "urgent", entry_pos(key))
	# The first wave also pulls the dead of the street toward the train (front wave).
	if int(h["index"]) == 0:
		for z in zombies.list:
			if z["state"] == "wander" and grid.zone_at(FieldGrid.cell_of(z["pos"])) == "D":
				z["state"] = "investigate"
				z["target"] = FieldGrid.center(horde_home())
				z["linger"] = 30.0
				z["speed"] = Zombies.SPEED_SHAMBLE
	forecast_t = 6.0


func _entry_on_screen(key: String) -> bool:
	return camera.is_position_in_frustum(entry_pos(key) + Vector3(0, 0.5, 0))


var forecast_t: float = 0.0


## Bodies come out one by one; the concurrent cap (60 on screen and round the
## train, 2026-10-07 review) holds the rest at the entry until room frees up.
func _update_spawns(delta: float) -> void:
	var now := clock.elapsed
	var keep: Array = []
	var alive := 0
	for z in zombies.list:
		if zombies.threat(z) and z["state"] != "frozen":
			alive += 1
	waiting = 0
	var gate: Dictionary = {}
	for s in pending_spawn:
		var key: String = s["entry"]
		# A manhole closed mid-horde sends the rest out of the culvert.
		if director.sewer(key) and not director.is_open(key):
			key = _other_way(key)
			s["entry"] = key
			s["pos"] = entry_pos(key)
		if now < float(s["t"]):
			keep.append(s)
			continue
		if alive >= cap or int(gate.get(key, 0)) >= (CULVERT_WIDTH if key.begins_with("culvert") else 1):
			waiting += 1
			s["t"] = now + 0.5
			keep.append(s)
			continue
		# Nobody climbs out right under someone's feet: that exit passes its
		# share to the other open one (field_unified 6). Pressure stays the same.
		if director.sewer(key) and _someone_near(s["pos"], SEWER_CLEAR):
			var other := _free_sewer(key)
			if other != "":
				var other_pos := entry_pos(other)
				s["entry"] = other
				s["pos"] = other_pos
				s["t"] = now + 3.0   # the other lid rattles first
			else:
				s["t"] = now + 0.5
				waiting += 1
			keep.append(s)
			continue
		var z := zombies.spawn("dead", s["pos"] + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)), {"horde": s["horde"], "target": s["target"]})
		z["stander"] = false
		if director.sewer(key):
			_climb_out(z, key, s)
		alive += 1
		gate[key] = int(gate.get(key, 0)) + 1
	pending_spawn = keep
	if forecast_t > 0.0:
		forecast_t -= delta
		if forecast_t <= 0.0:
			set_radio("기관사: " + director.forecast(now, forecast_precision, clock) + lid_tip())
	deaf_t = maxf(0.0, deaf_t - delta)


func _someone_near(at: Vector3, r: float) -> bool:
	for p in people:
		if p.is_alive() and p.position.distance_to(at) < r:
			return true
	return false


## Once per field, when the next wave comes up the open street manhole: how to
## shut it (H3 2026-10-09: the player never found that it can be shut).
func lid_tip() -> String:
	if lid_tip_told or not FieldMaps.lid(director.next_entry) or not director.is_open(director.next_entry) or director.is_exhausted():
		return ""
	lid_tip_told = true
	return " 맨홀은 판자나 고철로 누르면 막힌다."


## Out of a sewer hole a body climbs: straight up out of a lid or a drain,
## flat out of a culvert the way its mouth opens. While one comes up a lid,
## the lid lies pushed aside. What can be done to it meanwhile is as it was.
func _climb_out(z: Dictionary, key: String, s: Dictionary) -> void:
	var way := "culvert" if key.begins_with("culvert") else "lid"
	if way == "lid":
		z["pos"] = zombies._floor_y(s["pos"])
	var to: Vector3 = s["target"] - z["pos"]
	to.y = 0.0
	if way == "culvert" and data["hole_faces"].has(key):
		var face: Vector2i = data["hole_faces"][key]
		to = Vector3(face.x, 0, face.y)
	if to.length() > 0.01:
		z["angle"] = atan2(to.x, to.z)
	zombies.start_climb(z, way)
	if FieldMaps.lid(key) and view.manhole_nodes.has(key):
		if not lid_open.has(key):
			view.update_manhole(key, false, true)
		lid_open[key] = float(Motion.row("dead_climb_lid")["len"])


## Where the rest of a horde comes when its lid is shut under it: the culvert
## if the map has one open, else another open hole, else the next way in.
func _other_way(shut: String) -> String:
	for wide in [true, false]:
		for key: String in data["manholes"]:
			if key != shut and key.begins_with("culvert") == wide and director.is_open(key):
				return key
	return director.next_entry


## Another open sewer mouth with nobody near it, culvert first, or "".
func _free_sewer(not_this: String) -> String:
	var order: Array = ["culvert", "manhole", "cellar"]
	for key in data["manholes"]:
		if not order.has(key):
			order.append(key)
	for key in order:
		if key != not_this and data["manholes"].has(key) and director.is_open(key) and not _someone_near(entry_pos(key), SEWER_CLEAR):
			return key
	return ""


func radio_mode() -> String:
	var m := String(opts.get("radio", "urgent"))
	return m if RADIO_MODES.has(m) else "urgent"


## A line on the radio. kind: "say" is said to your face (the briefing on the
## platform, the one up the signal box): no set, no ring. "must" (time to
## leave) always comes through. "reply" answers something you just did.
## "urgent" is a horde coming in; "info" is the rest (forecasts, one gone by).
## at: where it is about (a way in), for the near rule.
func set_radio(text: String, kind: String = "info", at = null) -> void:
	if kind == "say":
		_radio_show(text)
		return
	var mode := radio_mode()
	var now := clock.elapsed
	if kind != "must":
		if mode == "off" or (mode == "urgent" and kind == "info"):
			return
		if kind != "reply" and now - radio_last < float(RADIO_GAP[mode]):
			return
		if radio_near == "horde" and at != null and player != null and player.position.distance_to(at) > RADIO_NEAR_M:
			return
	var ring := RADIO_RING_URGENT if kind == "urgent" or kind == "must" else RADIO_RING
	if radio_near == "train" and kind != "must" and player != null and player.position.distance_to(FieldGrid.center(horde_home())) > RADIO_NEAR_M:
		text = "…치직… (멀어서 알아들을 수 없다)"
		ring = RADIO_RING
	radio_last = now
	radio_wait = {"text": text, "ring": ring}
	radio_wait_t = RADIO_HISS
	hud.radio("…치직")
	audio.radio("hiss")


func _tick_radio(delta: float) -> void:
	if radio_wait.is_empty():
		return
	radio_wait_t -= delta
	if radio_wait_t > 0.0:
		return
	var call: Dictionary = radio_wait
	radio_wait = {}
	_radio_show(String(call["text"]))
	# The set is on the chief: the dead within the ring hear it, crouched or not.
	if player != null and player.is_alive():
		radio_rings.append({"t": clock.elapsed, "r": float(call["ring"])})
		audio.radio("urgent" if float(call["ring"]) > RADIO_RING else "call")
		zombies.hear(player.position, SimNoise.Level.NORMAL, float(call["ring"]))


func _radio_show(text: String) -> void:
	radio = text
	radio_t = 8.0
	hud.radio(text)


## What happened to p, in a few words. `hurt`: it is a wound (the hud shows
## those of the chief at the screen's edges, not as a note). `event`: what a
## companion shouts about it (ally_lines.gd), if anything.
func say(p, text: String, hurt: bool = false, event: String = "") -> void:
	if hud != null:
		hud.say(p, text, hurt)
	if event != "":
		shout(p, event)


## A companion shouts a line over their head (words only). The chief, the
## raiders and the dead keep quiet.
func shout(p, event: String, always: bool = false) -> void:
	if hud == null or p == player or p.body.dead or not (squad.has(p) or always and crew.has(p)):
		return
	var line: String = lines.pick(String(p.pid), event, clock.elapsed, always)
	if line != "":
		hud.shout(p, line)


## One of the squad fell: the companion nearest to them, if near, rages.
func shout_near(fallen, event: String) -> void:
	var best = null
	var best_d: float = AllyLines.RAGE_NEAR
	for o in squad:
		if o == fallen or o == player or not o.is_alive() or o.body.downed:
			continue
		var d: float = o.position.distance_to(fallen.position)
		if d < best_d:
			best_d = d
			best = o
	if best != null:
		shout(best, event)


## Lying hurt or held while the chief walks off.
func _left_behind() -> void:
	for o in squad:
		if o == player or o.body.dead or not (o.body.downed or not o.grabbers.is_empty()):
			continue
		if o.position.distance_to(player.position) > AllyLines.LEFT_BEHIND_M:
			shout(o, "left_behind")


# ---------------------------------------------------------------- vision & camera

## Zomboid-like sight: a wide cone ahead, a small circle all round, walls hide.
## Upstairs the eye reaches further (out of the windows, over the yards);
## the signal box top sees all round. Down in the cellar it is dark.
func _refresh_vision() -> void:
	var origin := FieldGrid.cell_of(player.position)
	var lv := level_of(player.position)
	var lg := grid_at(player.position)
	var tower: bool = lv > 0 and lg.building_at(origin) == 1
	var base := SIGHT_UPSTAIRS if lv > 0 else (SIGHT_CELLAR if lv < 0 else SIGHT_RADIUS)
	var radius := maxi(3, int(round(base * (eye_mult() if lv >= 0 else 1.0))))
	if not mask_on:
		seen_now = {}
		view.set_mask_enabled(false)
		view.update_vis(seen_now, seen_memory, lamp_cells())
		return
	view.set_mask_enabled(true)
	var forward := Vector2.ZERO if tower else Vector2(sin(player.facing), cos(player.facing))
	var result := lg.visible_cells(origin, radius, forward, VIEW_CONE_COS, NEAR_SIGHT)
	var n := grid.width * grid.height
	seen_now = {}
	for i in result:
		# Open air upstairs is a look down to the floor below it.
		var k := lv
		while k > 0 and levels[k].solid[i] == FieldGrid.Solid.AIR:
			k -= 1
		var key: int = (k + 1) * n + i
		seen_now[key] = true
		seen_memory[key] = 1
	if not ended and not paused:
		_mark_tracks()
	view.update_vis(seen_now, seen_memory, lamp_cells(result))
	view.update_labels(seen_memory, mask_on)


func _person_visible(p: Person) -> bool:
	if p.team != "raider" and p.team != "survivor":
		return true
	if not mask_on:
		return true
	return seen_now.has(seen_key(p.position))


func cell_seen(at: Vector3) -> bool:
	return not mask_on or seen_now.has(seen_key(at))


func _update_camera(delta: float) -> void:
	var focus := player.position + cam_push
	cam_focus = cam_focus.lerp(focus, clampf(delta * 4.0, 0.0, 1.0))
	camera.size = lerpf(camera.size, cam_size, clampf(delta * 6.0, 0.0, 1.0))
	var pitch := deg_to_rad(CAM_PITCH)
	var back := Vector3(0, sin(pitch), cos(pitch)) * 60.0
	camera.position = cam_focus + back
	camera.look_at(cam_focus, Vector3.UP)
	snow.position = cam_focus + Vector3(0, 9, 0)
	_update_storm()
	_update_light()


func screen_to_ground(screen: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Vector3.ZERO
	# The floor the player stands on is the plane a finger lands on.
	var t := (level_of(player.position) * FieldMaps.LEVEL_H - origin.y) / dir.y
	return origin + dir * t


func pixels_per_metre() -> float:
	return get_viewport().get_visible_rect().size.y / camera.size


# ---------------------------------------------------------------- frozen, risen, doors

func on_frozen_wake(z: Dictionary) -> void:
	sounds.append({"pos": z["pos"], "level": SimNoise.Level.NORMAL, "t": clock.elapsed, "tag": "ice"})
	if player.position.distance_to(z["pos"]) < 14.0:
		hud.toast("눈 속에서 얼음이 갈라진다.")


## One of the dead has dropped low and will run (zombies.gd, the tell). The
## HUD marks it for as long as it stays low; here it is voiced. No rule hears
## this and nothing is scored: the tell itself calls the dead near it.
func on_lunge_tell(z: Dictionary) -> void:
	audio.lunge_tell(z["pos"])


func on_risen(z: Dictionary) -> void:
	if z["name"] != "":
		hud.toast("%s 일어났다." % z["name"])


func on_zombie_killed(z: Dictionary) -> void:
	pass


func on_door_banged(c: Vector2i) -> void:
	var door: Dictionary = grid.doors[c]
	if door["state"] == "open" or door["state"] == "broken":
		return
	door["hp"] = int(door["hp"]) - 1
	make_sound(FieldGrid.center(c), SimNoise.Level.NORMAL, "bang")
	if door["hp"] <= 0:
		grid.set_door_state(c, "broken")
		view.update_door(c)


func telemetry_note_spotted() -> void:
	spotted_events += 1


## A zombie's hand reaches a person: grab, scratch or blocked (body_injury 2장).
func zombie_reaches(z: Dictionary, p: Person) -> String:
	return combat.zombie_reaches(z, p)


# ---------------------------------------------------------------- end

func _check_end() -> void:
	if ended:
		return
	var squad_up := 0
	for p in squad:
		if p.is_alive() and not p.body.downed:
			squad_up += 1
	if squad_up == 0:
		finish("wiped")
		return
	# Held, the train's own clock is the limit.
	if clock.past_limit() and not holdout.on:
		finish("limit")
		return
	if clock.past_safe() and not safe_warned:
		safe_warned = true
		set_radio("기관사: 이제 떠나야 한다. 오래는 못 기다린다.", "must")


## Walking dead on the main track (rows 1-3, ground level) west and east of
## the train at this moment: what a plough would push through on leaving
## (s1c_domestic 6.6). Which way the train leaves is S3's to say.
func track_dead() -> Dictionary:
	var train: Rect2i = data["train"]
	var out := {"west": 0, "east": 0}
	for z in zombies.list:
		if z["state"] == "dead" or level_of(z["pos"]) != 0:
			continue
		var c := FieldGrid.cell_of(z["pos"])
		if c.y < train.position.y or c.y >= train.end.y:
			continue
		if c.x < train.position.x:
			out["west"] += 1
		elif c.x >= train.end.x:
			out["east"] += 1
	return out


## Leaving is called. Where the train has to be held first, that opens; called
## again while it is held, the train goes before it is ready.
func depart() -> void:
	if holdout.opens_on_leaving():
		holdout.begin()
		return
	# A held train: a last call first, and whoever misses it stays.
	if holdout.on:
		holdout.last_call()
		return
	holdout.slipped = holdout.mode == "roll" and holdout.rolled and not holdout.opened
	holdout.leaving_early()
	audio.depart()
	finish("departed")


## The line under the weather: the held train's clock and doors, or the stop's goals.
func goal_text() -> String:
	if holdout.enabled() and (holdout.opened or not mission_play.active()):
		return holdout.goal_line()
	# A rolled stop says its risk beside the stop's goals.
	if holdout.mode == "roll":
		return holdout.goal_line() + " · " + mission_play.goal_line()
	return mission_play.goal_line() if mission_play.active() else ""


## At the train (or already in it) and on their feet: goes with it when it leaves.
## How far short of its stand the train still is this long after it came into
## sight, from `far` metres out: fast at first, slowing all the way to a stop.
static func train_in(t: float, far: float) -> float:
	var left: float = 1.0 - clampf(t / ARRIVE_ROLL_S, 0.0, 1.0)
	return far * left * left


## From its own length away: none of it is on the screen at first.
func arrive_far() -> float:
	return float((data["train"] as Rect2i).size.x)


func _arrive(delta: float) -> void:
	var cry_at: float = ARRIVE_ROLL_S - ARRIVE_BRAKE_S
	if arrive_t < cry_at and arrive_t + delta >= cry_at:
		audio.train_brake()
	arrive_t += delta
	view.slide_train(-train_in(arrive_t, arrive_far()))
	if arrive_t >= ARRIVE_ROLL_S + ARRIVE_HUSH_S:
		skip_arrival()


## The train stands, and the stop begins (the scene over, or a touch).
func skip_arrival() -> void:
	if arrive_t < 0.0:
		return
	arrive_t = -1.0
	view.slide_train(0.0)
	hud.visible = true


## How far the train has rolled this long after the whistle: slowly from a
## stand, then steadily.
static func train_roll(t: float) -> float:
	var up: float = minf(t, TRAIN_UP_S)
	return 0.5 * TRAIN_PULL * up * up + TRAIN_PULL * TRAIN_UP_S * maxf(t - TRAIN_UP_S, 0.0)


func aboard(p) -> bool:
	if p.brain.get("boarded", false):
		return true
	return FieldMaps.by_train(data, FieldGrid.cell_of(p.position)) and not p.body.downed


## How many would stay if the train left now (the chief aside).
func outside() -> int:
	var n := 0
	for p in squad + crew:
		if p != player and p.is_alive() and not aboard(p):
			n += 1
	return n


## Departure: whistle (very loud), people on the platform board, the rest stay.
func finish(reason: String) -> void:
	if ended:
		return
	ended = true
	var now := clock.elapsed
	if reason == "departed":
		make_sound(FieldGrid.center(data["anchors"]["whistle"]), SimNoise.Level.VERY_LOUD, "whistle")
	var boarded: Array = []
	for p in squad + crew:
		if not p.is_alive():
			continue
		var on_board: bool = aboard(p)
		if on_board or reason == "wiped" and false:
			boarded.append(p)
			for id in p.items:
				unloaded[id] = int(unloaded.get(id, 0)) + int(p.items[id])
		else:
			receipt.person("leftBehind", p.pid)
			# A held train going without them: they shout after it (user decision
			# 143). "left_behind" in the brain is for the protest motion to read.
			if reason == "departed" and holdout.opened and p != player:
				holdout.left_people += 1
				p.brain["left_behind"] = true
				shout(p, "left_platform", true)
		# A confirmed infection from a scratch goes back as a bite would (body_injury 2.1).
		if p.body.infection == "bite" or p.body.infected:
			receipt.person("bitten", p.pid)
		if p.body.bleed >= 2 or p.body.leg_fracture or p.body.arm_fracture or p.body.downed:
			receipt.person("injured", p.pid)
		# Wounds go on as they are; the receipt folds bites and serious ones into the lists.
		for row: Dictionary in p.body.receipt_wounds():
			receipt.add_wound(p.pid, row["part"], row["kind"], bool(row.get("festering", false)))
	var stock: Dictionary = {}
	for id in unloaded:
		if STOCK_OF.has(id):
			var row: Array = STOCK_OF[id]
			stock[row[0]] = float(stock.get(row[0], 0.0)) + float(row[1]) * int(unloaded[id])
		if id in ["symbol_bell", "info_telegraph", "info_timetable", "plow_core"]:
			receipt.gain_item(id)
	stock["coal"] = float(stock.get("coal", 0.0)) + actions.coal_delivered - actions.coal_spent - int(holdout.cost_paid["coal"])
	stock["scrap"] = float(stock.get("scrap", 0.0)) + float(unloaded.get("scrap", 0))
	stock["wood"] = float(stock.get("wood", 0.0)) + float(unloaded.get("wood", 0))
	# Ammo is the pool plus what sits in the guns: rounds fired from a magazine
	# count, and so do the ones in a gun that stays behind with its carrier.
	var boarded_squad: Array = []
	for p in boarded:
		if squad.has(p):
			boarded_squad.append(p)
	var loaded_end := loaded_totals(boarded_squad)
	for k in ["pistol", "shell", "craft"]:
		var used: int = int(ammo_start[k]) + int(loaded_start.get(k, 0)) - int(ammo[k]) - int(loaded_end.get(k, 0))
		var key: String = "ammo_" + k
		stock[key] = float(stock.get(key, 0.0)) - used
		telemetry.ammo(k, used)
	for key in stock:
		var v := roundi(float(stock[key]))
		if v != 0:
			receipt.add_stock(key, v)
	var depart_label := clock.label()
	receipt.set_time(clock.minutes_label(0.0), depart_label, clock.stay_game_minutes())
	var searched := 0
	for id in data["containers"]:
		if data["containers"][id]["searched"]:
			searched += 1
	# A map with nothing to search has had nothing searched.
	receipt.set_place_state(snappedf(float(searched) / maxi(data["containers"].size(), 1), 0.01), clampi(zombies.alive_count() / 10, 0, 5))
	if data["spots"].has("water_tower"):
		receipt.place_note("waterTower", data["spots"]["water_tower"]["state"])
	if mission != "":
		receipt.place_note("mission", mission)
	mission_play.finish(reason)
	holdout.on = false
	if holdout.opened:
		holdout.note_leaving(reason == "departed")
		receipt.place_note("holdout", holdout.result())
		telemetry.holdout = holdout.result()
	elif holdout.mode == "roll":
		holdout.note_leaving()
		telemetry.holdout = holdout.roll_note()
	receipt.set_end(reason)
	for d in decisions:
		receipt.decision(d["id"], d["choice"])
	var on_track := track_dead()
	telemetry.track(on_track["west"], on_track["east"])
	telemetry.end(reason, now)
	var result := {"reason": reason, "receipt": receipt.to_dict(), "receipt_json": receipt.to_json(), "telemetry": telemetry.to_json_line(), "boarded": boarded.size(), "stay": clock.stay_game_minutes(), "real_seconds": now, "unloaded": unloaded.duplicate(), "noise": ledger.total, "hordes": hordes.size(), "holdout_lines": holdout.end_lines(), "places": data["containers"].size(), "dead_about": zombies.alive_count()}
	_save(result)
	# The train going is the stop's full stop: a beat before the card, with
	# what the stop came to side by side (user decision 183). A held train
	# keeps its own lines over it.
	if reason == "departed":
		# The train rolls away with whoever boarded; who stayed stands where they are.
		rode_off = boarded
		leave_t = 0.0
		hud.leave_beat(result, holdout.leave_lines() if holdout.opened else LeaveScene.head(result), LeaveScene.columns(result))
	else:
		hud.show_end(result)
	finished.emit(result)


func _save(result: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("user://runs")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var f := FileAccess.open("user://runs/receipt_%s.json" % stamp, FileAccess.WRITE)
	if f:
		f.store_string(result["receipt_json"])
	elif hud != null:
		# The run is over but its record is not on disk: say so once (ui_states N2).
		hud.toast("기록 파일을 적지 못했다. 영수증은 끝 화면에서 복사할 수 있다.", hud.TOAST_WARN)
	var t := FileAccess.open("user://runs/telemetry.jsonl", FileAccess.READ_WRITE if FileAccess.file_exists("user://runs/telemetry.jsonl") else FileAccess.WRITE)
	if t:
		t.seek_end()
		t.store_line(result["telemetry"])


## Rounds loaded in the guns of `who` (the whole squad when null), by ammo kind.
func loaded_totals(who = null) -> Dictionary:
	var out := {"pistol": 0, "shell": 0, "craft": 0}
	for p in (squad if who == null else who):
		for h in p.hands:
			var id: String = String(h.get("id", ""))
			if id != "" and W.is_ranged(id):
				var kind: String = String(W.get_data(id).get("ammo", ""))
				if out.has(kind):
					out[kind] += int(h.get("loaded", 0))
	return out


func item_name(id: String) -> String:
	if EXTRA_ITEMS.has(id):
		return EXTRA_ITEMS[id]["name"]
	if id == "scrap":
		return "고철"
	if id == "wood":
		return "목재"
	return String(Carry.ITEM_NAMES.get(id, W.get_data(id).get("name", id)))
