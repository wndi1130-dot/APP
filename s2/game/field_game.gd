extends Node3D
## One direct stop at Sulechów (S2 graybox, s2_station.md). Owns the map,
## people, the dead, clocks and the receipt. Combat, AI, input and HUD live in
## helper scripts that read and write this node.

signal finished(result: Dictionary)
signal restart_requested
## The stop is built (at the end of _ready; a staged one some frames later).
signal built

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const StopGround = preload("res://game/world/stop_ground.gd")
const MapView = preload("res://game/world/map_view.gd")
const MapEdge = preload("res://fx/map_edge.gd")
const WoodsShade = preload("res://fx/woods_shade.gd")
const RoomStories = preload("res://game/world/room_stories.gd")
const SidePath = preload("res://game/world/side_path.gd")
const SideNote = preload("res://game/sim/side_note.gd")
const CoreScenes = preload("res://game/world/core_scenes.gd")
const RouteStops = preload("res://game/train/route_stops.gd")
const RouteBands = preload("res://game/train/route_bands.gd")
const WorkSpots = preload("res://game/world/work_spots.gd")
const Person = preload("res://game/actors/person.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const FieldClock = preload("res://game/sim/field_clock.gd")
const StopForm = preload("res://game/sim/stop_form.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const NoiseLedger = preload("res://game/sim/noise_ledger.gd")
const HordeDirector = preload("res://game/sim/horde_director.gd")
const Receipt = preload("res://game/sim/receipt.gd")
const Telemetry = preload("res://game/sim/telemetry.gd")
const FieldMission = preload("res://game/field_mission.gd")
const FieldWork = preload("res://game/field_work.gd")
const FieldHoldout = preload("res://game/field_holdout.gd")
const FieldTrainGuard = preload("res://game/field_train_guard.gd")
const FieldAlarms = preload("res://game/field_alarms.gd")
const FieldResidents = preload("res://game/field_residents.gd")
const Motion = preload("res://game/sim/motion.gd")
const Gait = preload("res://game/sim/gait.gd")
const MoveRules = preload("res://game/sim/move_rules.gd")
const Carry = preload("res://game/sim/carry.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const LootRules = preload("res://game/sim/loot_rules.gd")
const Wear = preload("res://game/sim/wear.gd")
const Weather = preload("res://game/sim/weather.gd")
const SmellRules = preload("res://game/sim/smell_rules.gd")
const FxState = preload("res://fx/fx_state.gd")
const SnowCover = preload("res://game/sim/snow_cover.gd")
const SeasonTable = preload("res://game/season_table.gd")
const LampLight = preload("res://game/sim/lamp_light.gd")
const NightLights = preload("res://game/world/night_lights.gd")
const NightLightView = preload("res://game/world/night_light_view.gd")
const SnowTracks = preload("res://game/sim/snow_tracks.gd")
const SoundRipple = preload("res://game/world/sound_ripple.gd")
## The squad's sounds whose reach shows on the ground (decision 471 H1): a door kicked in,
## glass broken, wood chopped — and the player's running steps (_footsteps).
const RIPPLE_TAGS: Array[String] = ["kick", "glass", "axe"]
const PrecipShader = preload("res://fx/shaders/precip.gdshader")
const W = preload("res://game/sim/weapons.gd")
const Combat = preload("res://game/field_combat.gd")
const HitFeel = preload("res://game/hit_feel.gd")
const AI = preload("res://game/field_ai.gd")
const Actions = preload("res://game/field_actions.gd")
const Hud = preload("res://game/ui/field_hud.gd")
const FieldAudio = preload("res://game/audio/field_audio.gd")
const MusicPlayer = preload("res://game/audio/music_player.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const StormLook = preload("res://fx/storm_look.gd")
const Atmosphere = preload("res://fx/atmosphere.gd")
const BreathFx = preload("res://fx/breath_fx.gd")
const BloodFx = preload("res://fx/blood_fx.gd")
const AllyLines = preload("res://game/sim/ally_lines.gd")
const LeaveScene = preload("res://game/ui/leave_scene.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const BuildPace = preload("res://game/world/build_pace.gd")
## The stop's outside air: the season table's stretch temperature (코디네이터
## 10-25; it was -14 C fixed), the same the stop scene and the pictures read.
const OutsideTemp = preload("res://game/sim/outside_temp.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")
const EdgeBand = preload("res://game/world/edge_band.gd")
const PeopleSeparation = preload("res://game/sim/people_separation.gd")
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
## How long the sight mask takes to come in over a field handed over from the
## stop scene (mask_in).
const MASK_IN_S: float = 2.0
const SIGHT_RADIUS: int = 18
const SIGHT_UPSTAIRS: int = 30
const SIGHT_CELLAR: int = 7             # a dark cellar: you see what is near
const NEAR_SIGHT: float = 2.0         # heard from behind (body_injury 8.3)
const VIEW_CONE_COS: float = 0.17       # about 160 degrees ahead (like reference game 1)
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
const STICK_BREAKS: Array = ["search", "salvage", "pry", "kick", "glass", "lid", "snow", "fire", "craft", "rub", "splint", "treat", "eat", "wear", "take"]
## Who comes down from the train: the laws it lives under go out with them
## (opts "laws", decision 430).
const TRAIN_ROLES: Array = ["chief", "companion", "carrier", "escort", "worker"]
## Under the emergency ration law a work crew that eats less hauls less a trip
## (decision 430 ②, card domestic Q1 가): the law's haulMult in S1 data.ts
## (LAWS_RES in the train tables; test_ration_law.gd holds the two together).
const RATION_HAUL: float = 0.8
## The field camera (결정 476, the diagonal view): orthographic, turned CAM_YAW from
## north so it looks across the map's axes from the south-east, CAM_PITCH down
## from level. One value each: the pitch was picked from 30, 35 and 40.
const CAM_PITCH: float = 35.0
const CAM_YAW: float = 45.0
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
## The low sun through the windows (decision 474 B8): gold at 14:50, deep orange
## (about 22 degrees) by sunset. Never red: red is the colour of want (atmosphere 6).
const WINDOW_GOLD := Color(1.0, 0.8, 0.52)
const WINDOW_SUNSET := Color(1.0, 0.46, 0.14)
const EXTRA_ITEMS: Dictionary = {
	"info_telegraph": {"name": "전신 기록", "weight": 0.5, "stock": "info"},
	"info_timetable": {"name": "시간표", "weight": 0.5, "stock": "info"},
	"flare": {"name": "철도 섬광", "weight": 0.5, "stock": ""},
	# What the four drives of the pass's plough give up together (user decision 188).
	"plow_core": {"name": "제설기 코어", "weight": 4.0, "stock": ""},
	# The cores of the fixed scenes at freight yards and works (decision 426, core_scenes.gd).
	"core_engine": {"name": "기관 코어", "weight": CoreScenes.WEIGHT, "stock": ""},
	"core_electric": {"name": "전기 코어", "weight": CoreScenes.WEIGHT, "stock": ""},
	"ammo_pistol": {"name": "권총탄 한 줌", "weight": 0.0, "stock": ""},
	"ammo_shell": {"name": "산탄 한 줌", "weight": 0.0, "stock": ""},
}
const STOCK_OF: Dictionary = {"food_pack": ["food", 0.5], "med_box": ["medicine", 0.5], "luxury_pack": ["luxury", 0.5], "symbol_bell": ["symbol", 1.0], "info_telegraph": ["info", 1.0], "info_timetable": ["info", 1.0], "medkit": ["medicine", 1.0], "document": ["info", 0.0], "plank": ["wood", 1.0], "bottle_spirit": ["luxury", 0.5], "cloth": ["cloth", 1.0]}
## A watch found still set (P19): it starts ringing this long (real seconds)
## after it is first carried, rings this many times this far apart at the one
## who carries it (a "normal" sound, as any), then is quiet. One key stops them all.
const ALARM_DELAY_MIN: float = 60.0
const ALARM_DELAY_MAX: float = 150.0
const ALARM_RINGS: int = 4
const ALARM_EVERY: float = 2.0

var opts: Dictionary = {}
var stop_form: String = "city"
## How far along the journey this stop is: 0 at the prologue's start, 1 at the third act's end
## (the acts in order, each its act_progress; decision 498's arrival cap grows with it).
var journey_progress: float = 0.0
## What this stop is for (opts["mission"]; content_variety_first_build 2부):
## "" is the stop as it always was, "survey" the track office, "depot" the
## loading yard. Anything else is read as "". With "" nothing is written that
## was not written before.
const MISSIONS: Array[String] = ["", "survey", "depot"]
var mission: String = ""
var mission_play: FieldMission      # the goals of this stop, in the field
var holdout: FieldHoldout           # holding the train while it gets ready (off on a plain stop)
var train_guard: FieldTrainGuard    # the brakes heard, and the train holding what they bring (decision 416)
var building_alarms: FieldAlarms    # buildings' alarms set off by breaking in (J17)
var residents: FieldResidents       # the people who live at the stop (J21)
var rng := RandomNumberGenerator.new()
var place: String = ""                 # which map this stop is played on (FieldMaps)
var map_script: Script                 # a map handed over as it is, in place of a place's (tests)
var data: Dictionary
var grid: FieldGrid                    # the ground level
var levels: Dictionary = {}            # level -> FieldGrid (0 ground, 1-2 upstairs, -1 cellar)
var stairs: Array = []                 # [{cell, low, high, ladder}]
var view: MapView
var map_edge: MapEdge                   # ground and fog past the map's edge (fx/map_edge.gd)
var night_view: NightLightView          # the hearts of the lights people left (decision 471 B4)
var zombies: Zombies
var camera: Camera3D
var environment: Environment
var sun: DirectionalLight3D
## The light from the camera's side that keeps the walls turned from the sun out
## of the black (Atmosphere.VIEW_FILL): no shadow, by day only.
var view_fill: DirectionalLight3D
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
var feel: HitFeel                      # a blow's hold, shake, buzz and sound (view only)
var ai: AI
var actions: Actions
var work: FieldWork
var hud: Hud
var audio: FieldAudio
var music: MusicPlayer                  # background music (briefs/bgm.md); silent with no files

var people: Array = []
var people_look  # person_visual.gd: the baked body the people wear
var squad: Array = []
var crew: Array = []
var raiders: Array = []
var player: Person
var paused: bool = false
var resume_pending: bool = false
var resume_wait_left: float = 0.0
var resume_ready_at_ms: int = 0
var resume_announce: bool = false
var slow: float = 1.0                    # the body picture up: the field runs at this rate (body_injury 4.6)
var hitstop: bool = false                # a blow's hold this frame (hit_feel.gd): the rules and pictures stand
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
## The sight mask coming in, 0..1 (1: in full). A field handed over from the
## stop scene starts at 0, as bright as the scene's last look down, and what
## is out of sight darkens over MASK_IN_S (결정 421-3: no dark cut at the
## hand-over). Picture only: what is in sight is never wider for it.
var mask_in: float = 1.0
var forecast_precision: int = 0
var roof_seen: bool = false           # up on a rooftop once this stop (house_layout.md 6.2)
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
## The cloth the squad went out with (decision 426 D2): the train gets what
## came back less this, so a strip torn for a bandage is its own and the
## kit is not new cloth every stop.
var cloth_start: int = 0
var unloaded: Dictionary = {}
## Clothes taken off by the train (decision 434, clothing.md 7장): they are not
## left lying there but go aboard as they are, worn and holed (wear.gd states).
var loaded_wear: Array = []
var blood: Array = []
var sounds: Array = []                 # recent sounds for the HUD: {pos, level, t}
var ripples: SoundRipple               # the reach of the squad's loud sounds, on the ground for a second (H1)
var ripple_run_t := -INF               # when the player's running last drew one
var shot_times: Array = []
var hordes: Dictionary = {}            # index -> {"t": arrival, "ids": [], "cleared": bool, "entry": key}
var pending_spawn: Array = []          # {"t", "pos", "horde", "target"}
var last_loud = null                   # where the last loud sound was (Vector3): hordes walk there
var rattle: Dictionary = {}            # manhole key -> seconds of rattling left
var lid_open: Dictionary = {}          # manhole key -> seconds the lid stays pushed aside (a body is coming up)
var ground_items: Array = []           # {pos, id, n}
var decisions: Array = []
## What LootDress did to this stop's boxes (empty when it was not asked).
var loot_report: Dictionary = {}
## Watches still set to ring, by who carries them: [{"who", "at", "left", "next"}]
## (P19). "at" is when it starts, "left" how many rings are still to come.
var alarms: Array = []
## Named things somebody has already said something about (once a stop).
var named_seen: Dictionary = {}
var eat_rng := RandomNumberGenerator.new()
## Under the snow out of doors, not yet seen (card 11): [{"cell", "id"}].
var glints: Array = []
## How each building with a locked door gives its key (LootDress.key_ways).
var key_ways: Dictionary = {}
## Where the note of this stop says a box is hidden at the next one ("" if none).
var note_spot: String = ""
## The scrawled map to the side path, read (side_note.gd, card M): {"at": where the way
## through the edge woods starts} while anyone in the squad holds it and nobody has got
## there yet, else {}. The HUD marks that side of the screen while it is set.
var side_hint: Dictionary = {}
var side_reached: bool = false
## Tins thrown, still to land and rattle: [{"pos", "at", "who"}]; and where
## they landed, shown a moment: [{"pos", "t"}].
var lures: Array = []
var lure_marks: Array = []
## Bodies gone through, and who saw it (card 12): [{"who", "seen": [pid]}].
var body_searches: Array = []
var cam_focus := Vector3.ZERO
var cam_push := Vector3.ZERO
var cam_size: float = 24.0
var zone_now: String = ""
var auto_paused_once: bool = false
var flash_t: float = 0.0
var dark_noise_t: float = 0.0
var safe_warned: bool = false
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
var dusk_pools_on: bool = false   # the low sun lies on some floor through a window
## The light the last look found (cell index -> 0..255) and, per floor, the
## indoor cells a window lights (rebuilt when that floor's doors and windows
## change): what dark_at reads (decision 439 card 1).
var lit_now: Dictionary = {}
var _window_lit: Dictionary = {}
var lantern: OmniLight3D
var firebox: OmniLight3D
var lamp_pulse: float = 0.0
var fx_light_night: Dictionary = {}
## Building the stop over frames (opts "staged", 결정 421-3): the same pieces in
## the same order, a frame's share at a time while the camera goes down, and
## then it stands still (standing_by) till go_live(). opts "map_data" hands over
## the map already built off the main thread (stop_loader.gd).
var pace: BuildPace
var is_built: bool = false
var standing_by: bool = false
## The atmosphere frame (fx/atmosphere.gd; picture only, rules never read it):
## the region band, the cold (opts "cold", else the act's from the scheme
## table), a fixed picture hour for check shots (opts "look_hour", -1: the
## clock's), the look now and the game minute it was made at.
var region: String = Atmosphere.DEFAULT_REGION
var cold: float = 1.0
## Which side of midwinter (0 autumn, 1 spring): day length, leaf and lying snow.
var side: float = 0.0
## The season state's name (the season table's, the same S1 and the train read).
var season_name: String = ""
## The photo sky the water gives back now (Atmosphere.SKY_PHOTOS key).
var sky_photo: String = ""
var look_hour: float = -1.0
var atmo: Dictionary = {}
## The player's brightness from the settings (decision 471 B5), -0.2..0.2; 0 is
## the picture as made, and the night's dark is set there. It bends the dark end
## of the grade's curve like a gamma. Only the play flow sets it
## (set_screen_lift): a field the tools, measures and bots make stays at 0.
var screen_lift: float = 0.0
const SCREEN_LIFT_MAX: float = 0.2
var atmo_min: float = -INF
var breath: Node3D
var blood_fx: Node3D                  # drops and marks off a blow (decision 444 D, view only)
## Frost creeping in at the screen's edges on cold nights (plain stops; a storm has its own).
var cold_frost: Control
var cold_frost_mat: ShaderMaterial


func _ready() -> void:
	pace = BuildPace.new(get_tree(), bool(opts.get("staged", false)))
	if pace.on:
		standing_by = true
		process_mode = Node.PROCESS_MODE_DISABLED
	rng.seed = int(opts.get("seed", Time.get_ticks_usec()))
	clock.speed = float(opts.get("clock_speed", 1.0))
	# When the train came in (decision 471 B0): the stop's own, else the departure contract's, else 10:30.
	var contract_min: float = float(FieldClock.ARRIVE_MIN)
	if opts.get("departure") is Dictionary:
		contract_min = float((opts["departure"] as Dictionary).get("arriveMin", contract_min))
	clock.arrive_min = float(opts.get("arrive_min", contract_min))
	# A storm stop plays by its stage's weather (clear, blizzard, clear) and
	# looks like the stage; without one the stop is as before.
	storm = StormLook.look(String(opts.get("storm", "")))
	var act := String(opts.get("act", "prologue"))
	journey_progress = clampf((float(maxi(Atmosphere.ACTS.find(act), 0)) + clampf(float(opts.get("act_progress", 0.0)), 0.0, 1.0)) / float(Atmosphere.ACTS.size()), 0.0, 1.0)
	cold = clampf(float(opts.get("cold", Atmosphere.cold_for(act, float(opts.get("act_progress", 0.0)), String(opts.get("cold_scheme", ""))))), 0.0, 1.0)
	side = clampf(float(opts.get("side", Atmosphere.side_for(act, String(opts.get("cold_scheme", ""))))), 0.0, 1.0)
	# The rules' air is the stretch's (outside_temp.gd): what falls, the body's
	# cold, smell and the cold in a fight read it.
	weather = Weather.new(storm.get("rules", opts.get("weather", ["fog", "snow"])), OutsideTemp.of(opts, cold, side), Vector2(1, 0.2), 0.4)
	# Picture inputs for the storm stops (weather_fx 14장): rules still read weather.
	look_kinds = opts.get("look", storm.get("kinds", weather.kinds))
	# The stop's band (decision 494): a stop's own map shows its own stop's band on any
	# stretch, any other map the band of the departure's stretch; a bare start the default.
	var map_id := FieldMaps.resolve(String(opts.get("place", "")))
	var departure_seg := int((opts["departure"] as Dictionary).get("segment", 0)) if opts.get("departure") is Dictionary else 0
	if opts.has("region"):
		region = Atmosphere.region_key(String(opts["region"]))
	elif opts.get("departure") is Dictionary or not RouteBands.place_stop(map_id).is_empty():
		region = RouteBands.band_of(map_id, act, departure_seg, float(opts.get("act_progress", 0.0)))
	else:
		region = Atmosphere.DEFAULT_REGION
	look_hour = float(opts.get("look_hour", -1.0))
	# Lying snow on arrival follows the cold, deeper stop by stop (picture: nothing
	# in the rules reads it). A storm stop keeps its season's depth.
	var open_ground := bool(Atmosphere.region(region)["open"])
	# The season table names the season by the act; a cold given outright (check
	# shots, tests) names it by that cold.
	if opts.has("cold"):
		season_name = Atmosphere.season_for(cold, side)
	else:
		season_name = Atmosphere.season_at(act, float(opts.get("act_progress", 0.0)), String(opts.get("cold_scheme", "")))
	var season := season_name if storm.is_empty() else SnowCover.DEFAULT_SEASON
	var old_cm := Atmosphere.cold_key(cold, "snow_cm", 1 if open_ground else 0, side) if storm.is_empty() else -1.0
	# The stretches before it laid snow or ate it (decision 474 N2, the departure's pastWeather).
	if storm.is_empty() and opts.get("departure") is Dictionary and (opts["departure"] as Dictionary).get("pastWeather") is Array:
		var past: Array = []
		for row: Dictionary in opts["departure"]["pastWeather"]:
			past.append({"weather": String(row["weather"]), "temp": float(SeasonTable.row(int(row["seg"])).get("temp", 0.0))})
		old_cm = SnowCover.after_past(old_cm, past)
	snow_cover = SnowCover.new(season, open_ground, float(opts.get("storm_cm", storm.get("storm_cm", 0.0))), old_cm)
	_apply_fx()
	cap = int(opts.get("cap", HordeDirector.CONCURRENT_CAP))
	Engine.max_fps = int(opts.get("fps_cap", 60))
	place = map_id
	# Now and then a way through the edge woods to a locked rare store (this run's seed, side_path.gd),
	# on a map built here or handed over built (the stop loader's): the same seed gives the same way.
	var stop_map: Dictionary = opts["map_data"] if opts.get("map_data") is Dictionary \
		else (FieldMaps.build_from(map_script) if map_script != null else FieldMaps.build(place))
	stop_map = shape_stop(stop_map, String(opts.get("stop_form", "")), rng.seed, float(opts.get("stop_form_m", -1.0)),
		func() -> Dictionary: return FieldMaps.build_from(map_script) if map_script != null else FieldMaps.build(place))
	_take_map(with_side_path(stop_map, rng.seed))
	set_stop_form(StopForm.resolve(opts, String(data["place_kind"])))
	# What the stop's place on the route forbids, whatever map came to it (route_stops.gd:
	# no fire at the first leg's fifth stop), before anything is put on the map.
	if opts.get("departure") is Dictionary:
		RouteStops.dress(data, int((opts["departure"] as Dictionary).get("segment", 0)))
	WorkSpots.dress(data, int((opts["departure"] as Dictionary).get("segment", 0)) if opts.get("departure") is Dictionary else -1, rng.seed)
	# Where the fallen stood is read into keys once (J06; the boxes' are in dress).
	LootRules.place_keys(data.get("buildings", []))
	# The boxes get their named things, from this run's seed (decision 423-8).
	# opts "loot_dress" false keeps the map's own bundles, as before.
	if bool(opts.get("loot_dress", true)):
		# The decks pick up where the last field stop left them (decision 474 S1, the contract's lootDeck).
		var deck: Dictionary = {}
		if opts.get("departure") is Dictionary:
			deck = (opts["departure"] as Dictionary).get("lootDeck", {})
		loot_report = LootDress.dress(data, rng.seed, deck)
		# The box a note of the last stop told of (card 10, opts "stash": its spot).
		if String(opts.get("stash", "")) != "":
			loot_report["stash"] = LootDress.place_stash(data, String(opts["stash"]), rng.seed)
	# Its own dice, so eating and the watches move nothing else of the run.
	eat_rng.seed = ("%d:eat" % rng.seed).hash()
	director = HordeDirector.new(rng)
	director.limit_sec = clock.limit_sec
	director.use_map(data)
	if opts.has("budget"):
		director.budget_left = int(opts["budget"])
	# The receipt knows six kinds of place (the S1 contract); a kind it does not
	# know yet is written as the freight stop it was drawn from.
	var kind: String = data["place_kind"]
	# Under the train's contract the receipt names the stop as the train named it (its placeId).
	var place_id: String = String(opts["departure"]["placeId"]) if contract_on() else String(data["place_id"])
	receipt = Receipt.new(place_id, kind if Receipt.PLACE_TYPES.has(kind) else "freight", "small_station_siding")
	receipt.set_source("direct")
	# Sent under the train's departure contract (v2, s3 contract 2): the receipt carries its ids
	# and goes back as v4/v5, which the train takes in once (field_return.gd).
	if contract_on():
		var dep: Dictionary = opts["departure"]
		receipt.set_ids(String(opts.get("receipt_id", "ret_" + String(dep["departureId"]).trim_prefix("dep_"))), String(dep["stopId"]), String(dep["departureId"]))
	# A place asked for that has no map was played on the default one: said so (R16).
	if String(opts.get("place", "")) != "" and String(opts.get("place", "")) != place:
		receipt.place_note("placeAsked", String(opts["place"]))
	if not Receipt.PLACE_TYPES.has(kind):
		receipt.place_note("placeKind", kind)   # what it really is, beside the type the contract knows
	# Room stories on the maps laid out by rule (house_layout.md 4): this run's own dice for this
	# place, so a resumed stop gets the same ones; what was picked stays in the place's state.
	if data.has("room_stats"):
		var stories := RoomStories.apply(data, ("%d:stories:%s" % [rng.seed, data["place_id"]]).hash())
		receipt.place_note("roomStories", stories)
		# What a looted house tipped out lies on its floors (loot_junk.gd, card J); out in _give_finds.
		data["loose"] = LootDress.LootJunk.spill_looted(data, stories, rng.seed)
	# A freight yard's or works' one fixed core scene (decision 426): the place is the map's,
	# whether a core is left in it is this run's dice, kept in the place's state like the stories;
	# the visible core turns a card of the decks dress handed back (474 S3), so the receipt carries it on.
	var core_note := CoreScenes.apply(data, ("%d:core:%s" % [rng.seed, data["place_id"]]).hash(), loot_report.get("loot_deck", {}))
	if not core_note.is_empty():
		receipt.place_note("coreScene", core_note)
	telemetry = Telemetry.new("s2-%d" % rng.seed)
	mission = String(opts.get("mission", ""))
	if not MISSIONS.has(mission):
		mission = ""
	telemetry.mission = mission
	mission_play = FieldMission.new(self)
	mission_play.place()
	holdout = FieldHoldout.new(self)
	train_guard = FieldTrainGuard.new(self)
	building_alarms = FieldAlarms.new(self)
	residents = FieldResidents.new(self)
	_build_world()
	await BuildPace.rest(pace)
	view = MapView.new()
	add_child(view)
	view.pace = pace
	# The woods past the edge grow as the stretch's region band does (edge_band.look_of).
	data["region_band"] = region
	await view.setup(data)
	# A stop the route marks no_fire (RouteStops.dress, s3-link) gets its lights
	# planned again without fires (decision 471 B4).
	if data.get("no_fire", false):
		NightLights.replan(data)
	night_view = NightLightView.new()
	night_view.name = "NightLights"
	add_child(night_view)
	night_view.build(data)
	# Past the map's edge the ground goes on under fog, not a flat slab (결정 448 17).
	map_edge = MapEdge.new()
	add_child(map_edge)
	map_edge.setup(view.grid, view.material)
	blood_fx = BloodFx.new()
	add_child(blood_fx)
	blood_fx.begin_stop(int(opts.get("seed", 1)))
	blood_fx.set_sight(view.vis_texture, Vector2(view.grid.width, view.grid.height))
	ripples = SoundRipple.new()
	add_child(ripples)
	map_edge.set_fog(fx_light["fog_color"])
	map_edge.set_field_fog(Atmosphere.field_fog(atmo), SIGHT_RADIUS * eye_mult(), fx_light)
	# The shade under the side path's trees: the gap reads as the light way in.
	if data.get("side_path") is Dictionary:
		var shade := WoodsShade.new()
		add_child(shade)
		shade.setup(data["side_path"])
	zombies = Zombies.new()
	add_child(zombies)
	# The stand-in bodies, baked off the main thread when handed over (stop_loader.gd).
	zombies.setup(self, opts["vat"] if opts.get("vat") is Dictionary else VatBaker.build(int(opts.get("vertices", 1500))))
	await BuildPace.rest(pace)
	combat = Combat.new(self)
	feel = HitFeel.new(self)
	ai = AI.new(self)
	actions = Actions.new(self)
	work = FieldWork.new(self)
	await BuildPace.heavy(pace)
	await _spawn_people()
	residents.place()
	people_look = PersonVisual.new()
	add_child(people_look)
	people_look.setup(self)
	await BuildPace.rest(pace)
	_spawn_dead()
	_give_finds()
	_ammo_from_train()
	# What is under a loose board (card K): room_stories.gd lays the place after the dressing,
	# floor_stash.gd fills its box.
	if bool(opts.get("loot_dress", true)):
		preload("res://game/sim/floor_stash.gd").fill(data, rng.seed)
	ammo_start = ammo.duplicate()
	loaded_start = loaded_totals()
	cloth_start = 0
	for p in squad:
		cloth_start += int(p.items.get("cloth", 0))
	await BuildPace.rest(pace)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	_say_bare_coats()
	await BuildPace.rest(pace)
	audio = FieldAudio.new()
	add_child(audio)
	audio.setup(self)
	music = MusicPlayer.new()
	music.director.safe_sec = clock.safe_sec
	add_child(music)
	music.setup("field", self)
	await BuildPace.rest(pace)
	set_radio("기관사: " + driver_forecast(0.0, 0) + lid_tip(), "say")
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
	# Coming back to a stop left mid-play (S3 spec 4): only when the start hands a save over.
	if opts.get("field_resume") is Dictionary:
		FieldSave.apply(self, opts["field_resume"])
		# A version-1 save kept no guard state: the brakes were heard before it was left.
		if not FieldSave.exact(opts["field_resume"]):
			train_guard.resumed()
	elif data["anchors"].has("whistle") and bool(opts.get("arrival_horde", true)):
		# The train has just stood: its brakes are heard as the clock starts,
		# the scene of it rolling in or not (decision 416).
		train_guard.brake()
	pace.finish()
	is_built = true
	built.emit()


## A staged stop, built, starts: its clock, its people and its touches. A stop
## built in one go is live from the start and this does nothing.
func go_live() -> void:
	if not standing_by:
		return
	standing_by = false
	process_mode = Node.PROCESS_MODE_INHERIT
	# Shown from under the stop scene: as bright as its last look, the mask coming in.
	mask_in = 0.0
	view.set_mask_shade(0.0)


## Weather is fixed for the whole stop, so the shader globals are set once;
## only lying snow moves afterwards (_update_snow).
func _apply_fx() -> void:
	var hour := clock.game_minutes() / 60.0
	snow_at_min = clock.game_minutes()
	if storm.is_empty():
		# The atmosphere frame draws a plain stop; a storm stage keeps its own look.
		atmo = atmosphere_at(picture_hour())
		_take_air()
		# The first light update sets the lights, the floors and the grade.
		atmo_min = -INF
		fx_params = Atmosphere.params(atmo, weather.wind_dir, snow_cover.cover())
		FxState.apply(fx_params)
		fx_light = Atmosphere.light(atmo)
		fx_light_night = Atmosphere.light(atmosphere_at(0.0))
		return
	# A storm keeps its stage's light; the look is still made for breath and the like.
	atmo = atmosphere_at(picture_hour())
	_set_sky_photo()
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
	# Lying snow is picture only: on a plain stop it goes by what is drawn and
	# the picture temperature (rain eats it), a storm by its stage's rules.
	var kinds_now: Array = weather.kinds
	var temp_now := weather.ambient_c
	if storm.is_empty() and not atmo.is_empty():
		kinds_now = atmo["kinds"]
		temp_now = float(atmo["temp_c"])
	snow_cover.advance(now - snow_at_min, kinds_now, temp_now)
	if snow_tracks != null:
		snow_tracks.refill(now - snow_at_min, SnowCover.rate_cm_h(kinds_now, temp_now))
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
		lamp_fixed = LampLight.fixed_cells(lights, grid.width, grid.height, now, fire, raid, grid)
		for kind in ["car_window", "firebox", "hideout"]:
			var on := false
			for l in lights:
				if l["kind"] == kind and LampLight.is_on(l, now, fire, raid):
					on = true
			view.set_light_on(kind, on)
		for l: Dictionary in lights:
			if NightLights.KINDS.has(String(l["kind"])):
				night_view.set_on(String(l["id"]), LampLight.is_on(l, now, fire, raid))
	var cells := lamp_fixed.duplicate()
	var dark := clock.is_dark()
	for p in people:
		if not p.lamp_lit(dark, level_of(p.position) < 0):
			continue
		var only: Dictionary = sight if p == player else {}
		LampLight.stamp(cells, grid.width, grid.height, FieldGrid.cell_of(p.position), Vector2i.ZERO, float(p.lamp["strength"]), float(p.lamp["reach"]), only)
		if p == player:
			_stamp_beam(cells)
	return cells


## The chief's torch throws a beam ahead beside the lantern (decision 471 B4),
## not through walls. Its cells count as lamp light, so it also lets the eye
## further into a dark room along it (decision 439 card 1).
func _stamp_beam(cells: Dictionary) -> void:
	var b: Dictionary = LampLight.BEAM
	var ahead := Vector2(sin(player.facing), cos(player.facing))
	var origin := FieldGrid.cell_of(player.position)
	var reach := float(b["reach"])
	var los := grid_at(player.position).visible_cells(origin, int(ceil(reach)), ahead, cos(deg_to_rad(float(b["half_deg"]))), 0.0)
	LampLight.beam(cells, grid.width, grid.height, origin, ahead, float(b["strength"]), reach, float(b["half_deg"]), los)


## The chief's lantern is a real light, so people and the dead near it are lit
## too; it dips for a moment when the night's light sound goes out.
func _update_lantern(delta: float) -> void:
	lamp_pulse = move_toward(lamp_pulse, 0.0, delta * 2.0)
	lantern.visible = player.lamp_lit(clock.is_dark(), level_of(player.position) < 0)
	lantern.position = player.position + Vector3(0, 1.4, 0)
	lantern.light_energy = float(player.lamp.get("strength", 1.0)) * (1.0 - 0.3 * lamp_pulse)
	var night := maxf(clampf((clock.game_minutes() - 900.0) / 90.0, 0.0, 1.0), float(storm.get("lamp_gain", 0.0)))
	# The pools show through the mask in full from sunset (night 0.5 at 15:45).
	view.set_lamp_gain(lerpf(LAMP_GAIN_DAY, 1.0, night), clampf(night * 2.0, 0.0, 1.0), level_of(player.position))


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


## The atmosphere frame's look of this stop at an hour (the rules' midday air
## and the table's night frost, so the picture's air is the rules' air).
func atmosphere_at(hour: float) -> Dictionary:
	return Atmosphere.look(hour, look_kinds, region, cold, {"wind": weather.wind, "side": side, "season": season_name, "midday_c": weather.midday_c, "night_frost": OutsideTemp.frost_of(opts)})


## The rules' air follows the hour: colder at dusk and night (outside_temp.gd at_hour).
func _take_air() -> void:
	weather.ambient_c = OutsideTemp.at_hour(weather.midday_c, picture_hour(), cold, side, look_kinds, OutsideTemp.frost_of(opts))


## The puddles give back the look's strongest photo sky (only when it changes).
func _set_sky_photo() -> void:
	var key := Atmosphere.sky_main(atmo)
	if key != sky_photo and FxState.set_sky(Atmosphere.sky_texture(key)):
		sky_photo = key


## The hour the picture is drawn at: the field clock's, or a fixed one for check
## shots (opts "look_hour": an hour, or -2 sunrise, -3 low sun before sunset,
## -4 night, by this stop's cold).
func picture_hour() -> float:
	if look_hour >= 0.0:
		return look_hour
	if look_hour <= -1.5:
		var t := Atmosphere.sun_times(cold, side)
		return [t.x + 0.25, t.y - 0.4, t.y + 1.7][clampi(int(round(-look_hour)) - 2, 0, 2)]
	return clock.game_minutes() / 60.0


## A plain stop follows the atmosphere frame through the day, a game minute at
## a time: sun, fill, sky light and cloud shadows move with the hour. The gray
## box has no lamps everywhere yet, so after dark the light keeps the field's
## floors (NIGHT_SUN_MIN, NIGHT_AMBIENT_MIN) as far as the hour is night.
func _update_atmosphere() -> void:
	var m := clock.game_minutes()
	if absf(m - atmo_min) >= 1.0:
		atmo_min = m
		atmo = atmosphere_at(picture_hour())
		_take_air()
		fx_light = Atmosphere.light(atmo)
		var p := Atmosphere.params(atmo, weather.wind_dir, float(fx_params.get("fx_snow", 0.0)))
		var changed := {}
		for key in ["fx_tint", "fx_sky", "fx_cloud", "fx_cold", "fx_frost", "fx_sight"]:
			if p[key] != fx_params.get(key):
				fx_params[key] = p[key]
				changed[key] = p[key]
		FxState.apply(changed)
		_set_sky_photo()
		_set_cold_frost(float(atmo["edge_frost"]))
		# Lights and the grade change only with the look (the grade's curve is a
		# texture: remade every frame it cost the phone a few milliseconds).
		var night := float(atmo["weights"]["night"])
		sun.light_color = fx_light["sun_color"]
		sun.light_energy = maxf(float(fx_light["sun_energy"]), NIGHT_SUN_MIN * night)
		sun.rotation_degrees = Vector3(float(fx_light["sun_pitch"]), float(fx_light["sun_yaw"]), 0.0)
		sun.shadow_opacity = float(fx_light.get("shadow", 1.0))
		_set_view_fill()
		_update_window_light()
		environment.ambient_light_color = fx_light["ambient_color"]
		environment.ambient_light_energy = maxf(float(fx_light["ambient_energy"]), NIGHT_AMBIENT_MIN * night)
		environment.background_color = fx_light["background"]
		if map_edge != null:
			map_edge.set_fog(fx_light["fog_color"])
			map_edge.set_field_fog(Atmosphere.field_fog(atmo), SIGHT_RADIUS * eye_mult(), fx_light)
		_apply_grade(atmo["grade"])
	if cold_frost != null and cold_frost.visible:
		_fit_frost_strips(cold_frost, float(cold_frost.get_meta("amount", 0.0)))


## The view fill follows the look; a storm stage keeps its own light (none).
func _set_view_fill() -> void:
	if view_fill == null:
		return
	view_fill.light_energy = float(fx_light.get("fill_energy", 0.0)) if storm.is_empty() else 0.0
	view_fill.light_color = fx_light.get("fill_color", Color.WHITE)
	view_fill.visible = view_fill.light_energy > 0.001


## Low sun through the windows (decision 474 B8): from 14:50 the pools on the
## floor warm from gold to deep orange and draw back to the sill, gone at
## sunset. Clouds hold it back as they hold back the sun (Atmosphere sun_visible).
func _update_window_light() -> void:
	var z := sun.global_transform.basis.z
	var sunny := 1.0 - smoothstep(0.55, 0.95, float(atmo["cloud"]))
	var cells := LampLight.window_cells(grid, Vector2(z.x, z.z), clock.game_minutes(), sunny)
	if cells.is_empty() and not dusk_pools_on:
		return
	dusk_pools_on = not cells.is_empty()
	view.update_window_light(cells, WINDOW_GOLD.lerp(WINDOW_SUNSET, clock.dusk_share()))


## The look's colour grade on the WorldEnvironment: saturation and contrast, and
## a three-stop curve that leans the shadows to the fill's hue and the lights to the sun's.
func _apply_grade(g: Dictionary) -> void:
	environment.adjustment_enabled = true
	environment.adjustment_saturation = float(g["saturation"])
	environment.adjustment_contrast = float(g["contrast"])
	environment.adjustment_brightness = float(g["brightness"])
	var tex := environment.adjustment_color_correction as GradientTexture1D
	if tex == null:
		tex = GradientTexture1D.new()
		tex.width = 64
		tex.gradient = Gradient.new()
		environment.adjustment_color_correction = tex
	var k := float(g["strength"])
	var shadow: Color = Color(0.3, 0.3, 0.3).lerp(Color(g["shadow"]) * (0.3 / maxf(Color(g["shadow"]).v, 0.05)), k * 0.35)
	var lit: Color = Color(0.85, 0.85, 0.85).lerp(Color(g["light"]) * (0.85 / maxf(Color(g["light"]).v, 0.05)), k * 0.3)
	var gr := tex.gradient
	# The player's brightness reads the input as x^(1/(1+lift)): each stop moves to o^(1+lift).
	var bend := 1.0 + screen_lift
	gr.offsets = PackedFloat32Array([0.0, pow(0.3, bend), pow(0.85, bend), 1.0])
	gr.colors = PackedColorArray([Color(0, 0, 0), shadow, lit, Color(1, 1, 1)])


## The player's brightness (decision 471 B5), from the settings row. A storm
## stage has no grade of its own, so the brightness alone bends its curve.
func set_screen_lift(lift: float) -> void:
	screen_lift = clampf(lift, -SCREEN_LIFT_MAX, SCREEN_LIFT_MAX)
	if environment == null:
		return
	if storm.is_empty() and atmo.has("grade"):
		_apply_grade(atmo["grade"])
		return
	environment.adjustment_enabled = screen_lift != 0.0
	if not environment.adjustment_enabled:
		return
	environment.adjustment_saturation = 1.0
	environment.adjustment_contrast = 1.0
	environment.adjustment_brightness = 1.0
	var tex := GradientTexture1D.new()
	tex.width = 64
	tex.gradient = Gradient.new()
	tex.gradient.offsets = PackedFloat32Array([0.0, pow(0.5, 1.0 + screen_lift), 1.0])
	tex.gradient.colors = PackedColorArray([Color(0, 0, 0), Color(0.5, 0.5, 0.5), Color(1, 1, 1)])
	environment.adjustment_color_correction = tex


## Out of doors by day the sight mask is one soft ring round the eye (decision 491:
## the sight cone's straight sides drew a bright wedge); the rules' sight is as it
## was. Its reach is the sight's; at night the cells rule again. Dawn and dusk
## (daylight about 0.5) are fully round too: only the last of the dusk blends.
func _set_sight_round() -> void:
	var day: float
	if atmo.has("lum"):
		day = clampf(inverse_lerp(0.09, 1.0, float(atmo["lum"])), 0.0, 1.0)
	else:
		day = 1.0 - clampf((clock.game_minutes() - 900.0) / 90.0, 0.0, 1.0)
	day = smoothstep(0.15, 0.45, day)
	var eye := Vector2(player.position.x, player.position.z)
	# The same reach as _refresh_vision's: upstairs sees farther, a cellar nearer.
	var lv := level_of(player.position)
	var base := SIGHT_UPSTAIRS if lv > 0 else (SIGHT_CELLAR if lv < 0 else SIGHT_RADIUS)
	var reach := maxf(float(base) * (eye_mult() if lv >= 0 else 1.0), 1.0)
	view.set_sight_round(eye, reach, day, FxState.SIGHT_OUT_DAY)
	if map_edge != null:
		map_edge.set_sight_round(eye, reach, day, FxState.SIGHT_OUT_DAY)


## Dusk dims the arrival light towards the night band between 15:00 and 16:30.
func _update_light() -> void:
	if storm.is_empty():
		_update_atmosphere()
		return
	var t := clampf((clock.game_minutes() - 900.0) / 90.0, 0.0, 1.0)
	# The night band is lamps only; the gray-box field has no lamps yet, so the
	# floors keep people, doors and the platform edge readable after dark.
	sun.light_energy = lerpf(float(fx_light["sun_energy"]), maxf(float(fx_light_night["sun_energy"]), NIGHT_SUN_MIN), t)
	environment.ambient_light_energy = lerpf(float(fx_light["ambient_energy"]), maxf(float(fx_light_night["ambient_energy"]), NIGHT_AMBIENT_MIN), t)


func _build_world() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.tonemap_exposure = Atmosphere.EXPOSURE
	environment.background_color = fx_light.get("background", Color(fx_params["fx_tint"]).darkened(0.75))
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
	if storm.is_empty():
		# The atmosphere frame moves the sun with the hour (FxState.SUN_PITCH at midday in deep winter).
		sun.rotation_degrees = Vector3(float(fx_light["sun_pitch"]), float(fx_light["sun_yaw"]), 0.0)
		sun.shadow_opacity = float(fx_light.get("shadow", 1.0))
		_apply_grade(atmo["grade"])
	elif screen_lift != 0.0:
		# A brightness handed over before the world was built.
		set_screen_lift(screen_lift)
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	view_fill = DirectionalLight3D.new()
	view_fill.shadow_enabled = false
	var back := cam_back()
	var toward := Vector3(-back.x, 0.0, -back.z).normalized() + Vector3(0.0, -tan(deg_to_rad(Atmosphere.VIEW_FILL_TILT)), 0.0)
	view_fill.transform = Transform3D(Basis.looking_at(toward, Vector3.UP), Vector3.ZERO)
	add_child(view_fill)
	_set_view_fill()
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
	snow.amount = maxi(weather.particles(), 1) * 3  # the rules' count is thin from 52° up (precip.gdshader)
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
	# What falls is the picture temperature's (atmosphere frame): rain streaks
	# when it is warm, small quick wet flakes for sleet. The count is the rules'.
	var falls := String(atmo.get("falls", "snow"))
	if falls == "rain":
		flake.size = Vector2(0.025, 0.5)
		fm.set_shader_parameter("shape", 0)
		fm.set_shader_parameter("opacity", 0.6)
		pm.initial_velocity_min = 7.0
		pm.initial_velocity_max = 9.0
		pm.gravity = Vector3(0.0, -4.0, 0.0)
		snow.lifetime = 1.6
	elif falls == "sleet":
		flake.size = Vector2(0.07, 0.07)
		fm.set_shader_parameter("opacity", 0.7)
		pm.initial_velocity_min = 3.5
		pm.initial_velocity_max = 4.5
		snow.lifetime = 2.6
	add_child(snow)
	_build_storm()
	if storm.is_empty():
		_build_cold_frost()
	breath = BreathFx.new()
	add_child(breath)


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
	# The wind on the ground as it runs across the screen (the camera is turned CAM_YAW).
	var wind: Vector2 = weather.wind_dir.rotated(deg_to_rad(CAM_YAW))
	m.set_shader_parameter("storm_dir", Vector2(wind.x, wind.y * 0.7))
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
	_fit_frost_strips(storm_frost, float(storm["edge_frost"]))


## Four full-size frost strips along the edges, only as deep as frost of this
## amount can reach. Top and bottom run the whole width; left and right fill in between.
func _fit_frost_strips(holder: Control, amount: float) -> void:
	var view := Vector2(get_viewport().get_visible_rect().size)
	var deep := minf(ceilf((amount * FROST_REACH + FROST_MARGIN) * view.y), view.y * 0.5)
	if holder.get_child(0).size == Vector2(view.x, deep):
		return
	var rects := [Rect2(0, 0, view.x, deep), Rect2(0, view.y - deep, view.x, deep),
			Rect2(0, deep, deep, view.y - deep * 2.0), Rect2(view.x - deep, deep, deep, view.y - deep * 2.0)]
	for i in range(4):
		var strip: ColorRect = holder.get_child(i)
		strip.position = rects[i].position
		strip.size = rects[i].size


## Frost creeping in at the edges on a plain stop (the atmosphere's edge_frost:
## the coldest stages, more at night). Same strips as a storm's; off below a trace.
func _build_cold_frost() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5   # over the world, under the HUD (10)
	add_child(layer)
	cold_frost = Control.new()
	cold_frost.set_anchors_preset(Control.PRESET_FULL_RECT)
	cold_frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cold_frost_mat = ShaderMaterial.new()
	cold_frost_mat.shader = load("res://fx/shaders/screen_overlay.gdshader")
	cold_frost_mat.set_shader_parameter("vignette", 0.0)
	cold_frost_mat.set_shader_parameter("grain", 0.0)
	for _i in range(4):
		var strip := ColorRect.new()
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.material = cold_frost_mat
		cold_frost.add_child(strip)
	layer.add_child(cold_frost)
	_set_cold_frost(float(atmo.get("edge_frost", 0.0)))


const COLD_FROST_MIN: float = 0.06


func _set_cold_frost(amount: float) -> void:
	if cold_frost == null:
		return
	var on := amount >= COLD_FROST_MIN
	cold_frost.visible = on
	cold_frost_mat.set_shader_parameter("edge_frost", amount if on else 0.0)
	cold_frost.set_meta("amount", amount)
	if on:
		_fit_frost_strips(cold_frost, amount)


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
	var loadout: Array = squad_rows(opts["departure"]["roster"]) if contract_on() else opts.get("squad", default_squad("crude"))
	var spots: Array = data["spawns"]["squad"]
	for i in range(loadout.size()):
		var row: Dictionary = loadout[i]
		var p := make_person(row, FieldGrid.center(spots[i % spots.size()]))
		squad.append(p)
		receipt.person("sent", p.pid)
		lines.rel_of[p.pid] = AllyLines.rel_stage(float(row.get("rel", 0.0)))
		if row.has("voice"):
			lines.voice_by[p.pid] = String(row["voice"])
		# Their own memory of the chief, when the departure sheet carries one (people memory).
		lines.names_by[p.pid] = String(row.get("name", p.pid))
		if row.has("stance"):
			lines.stance_by[p.pid] = String(row["stance"])
		if row.get("cues") is Array:
			lines.cues_by[p.pid] = (row["cues"] as Array).duplicate()
		await BuildPace.rest(pace)
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
			await BuildPace.rest(pace)


## "comm": the car a companion comes from; "rel": how that car stands with the
## chief (what they say to him, ally_lines.gd), the train's first (s1 REL0).
## The slice hands over the train's own (slice_flow.gd). "voice": how they
## speak, each their own (coordinator, 2026-10-18).
func default_squad(pipe_quality: String) -> Array:
	return [
		{"id": "p_chief", "name": "열차장", "role": "chief", "skills": {"strength": 5, "melee": 3, "shooting": 2, "stealth": 2, "search": 2}, "hands": [["axe", "factory", 0.9], ["pistol", "factory", 0.8]], "items": {"bandage": 2, "cloth": 1}},
		{"id": "p_guard_marek", "name": "마레크", "role": "companion", "comm": "guard", "rel": 15.0, "voice": "rough", "skills": {"strength": 6, "melee": 2, "shooting": 4, "stealth": 1, "search": 1}, "hands": [["pipe_shotgun", pipe_quality, 0.9], ["knife", "factory", 0.8]], "items": {"bandage": 1}},
		{"id": "p_med_joanna", "name": "요안나", "role": "companion", "comm": "medtech", "rel": 5.0, "voice": "quiet", "medical": "skilled", "skills": {"strength": 4, "melee": 1, "shooting": 4, "stealth": 3, "search": 3}, "hands": [["bow", "factory", 0.9], ["crowbar", "factory", 0.9]], "items": {"bandage": 3, "medkit": 1, "tweezers": 1, "needle_thread": 3}},
		{"id": "p_tail_tomasz", "name": "토마시", "role": "companion", "comm": "tail", "rel": -20.0, "voice": "fear", "skills": {"strength": 7, "melee": 3, "shooting": 1, "stealth": 1, "search": 2}, "hands": [["crowbar", "factory", 0.8], ["knife", "factory", 0.7]], "items": {"bandage": 1}, "bag": "big_pack"},
	]


## Is this stop sent under the train's departure contract v2 (the people the train picked)?
## The wardrobe ran short (decision 443, card E 가): who went out with no coat over them is
## said once at the start — they feel the cold sooner.
func _say_bare_coats() -> void:
	if not contract_on() or hud == null:
		return
	var bare: Array = []
	for p in squad:
		if not p.worn.has("jacket") and not p.worn.has("coat"):
			bare.append(p.display_name)
	if not bare.is_empty():
		hud.toast("외투 없음 — 추위: %s" % ", ".join(bare))


## The rounds the train hands over (the contract's train.ammo, kit_pick.gd, PR 5): the guns of
## those who went out are loaded first, as far as the rounds go, and the rest is the pool. A stop
## without them keeps the field's own pool (and the guns as they were loaded).
func _ammo_from_train() -> void:
	if not contract_on():
		return
	var given: Variant = (opts["departure"].get("train", {}) as Dictionary).get("ammo")
	if not given is Dictionary:
		return
	for k: String in ["pistol", "shell", "craft"]:
		var left := int(given.get(k, 0))
		for p in squad:
			for h in p.hands:
				var id: String = String(h.get("id", ""))
				if id != "" and W.is_ranged(id) and String(W.get_data(id).get("ammo", "")) == k:
					var n := mini(int(h.get("loaded", 0)), left)
					h["loaded"] = n
					left -= n
		ammo[k] = left


func contract_on() -> bool:
	var dep: Variant = opts.get("departure")
	return dep is Dictionary and int((dep as Dictionary).get("version", 0)) == 2


## How each car's people speak (ally_lines.gd), the field's first squad's by car.
const VOICE_OF_COMM := {"guard": "rough", "medtech": "quiet", "tail": "fear", "engine": "rough", "front": "quiet"}
const MEDICAL_OF_SKILL := ["none", "apprentice", "skilled", "master"]


## The field's rows for people of the departure contract (field_departure.gd person): the same
## id and name as the train's roll, their body skills, kit, car and how it stands with the chief,
## what they know of medicine and how hungry and sore they go out. One of the medical staff with
## no knowledge on record still goes as an apprentice (the car's own work).
static func squad_rows(people: Array) -> Array:
	var out: Array = []
	for person: Dictionary in people:
		var role: String = String(person["role"])
		var row := {
			"id": person["id"], "name": person["name"], "role": "chief" if role == "chief" else ("worker" if role == "carrier" else role),
			"comm": person["comm"], "rel": float(person["rel"]), "skills": (person["body"] as Dictionary).duplicate(),
			"hands": (person["gear"]["hands"] as Array).duplicate(true), "items": (person["gear"]["items"] as Dictionary).duplicate(),
			"bag": String(person["gear"]["bag"]), "wear": (person["gear"]["wear"] as Dictionary).duplicate(),
			"hunger": int(person["hunger"]), "sore": maxi(int(person["sore"]), int(person["rest"])),
		}
		if role != "chief":
			row["voice"] = VOICE_OF_COMM.get(String(person["comm"]), "quiet")
		var know: Variant = person.get("know")
		var level := 0
		if know is Dictionary and String(know.get("field", "")) == "med":
			level = clampi(int(know["skill"]), 0, 3)
		elif String(person["comm"]) == "medtech":
			level = 1
		row["medical"] = MEDICAL_OF_SKILL[level]
		out.append(row)
	return out


## The work crew the train can send down (carriers, then escorts), as field rows; empty off the contract.
func work_rows() -> Array:
	if not contract_on():
		return []
	return squad_rows(opts["departure"].get("workCrew", []))


func make_person(row: Dictionary, at: Vector3) -> Person:
	var p := Person.new()
	add_child(p)
	p.setup(String(row["id"]), String(row["name"]), String(row["role"]), at)
	p.skills = row.get("skills", p.skills).duplicate()
	p.medical = String(row.get("medical", "none"))
	p.hunger_level = clampi(int(row.get("hunger", 0)), 0, 2)
	p.sore_level = clampi(int(row.get("sore", 0)), 0, 2)
	p.bag = String(row.get("bag", "pack"))
	# The emergency ration law (decision 430): an underfed body tires sooner.
	p.body.ration_cut = TRAIN_ROLES.has(String(row["role"])) and (opts.get("laws", []) as Array).has("emergency_ration")
	# What they go out in (wear.gd): a row may say, place by place, else what everyone wears.
	Wear.dress_from(p, row.get("wear", {}))
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
	# The padded ones: the two lists of before first, as they were, then any
	# other "clothed_..." list a map has (where they stood shows in what they
	# have on, loot_tables.gd WEAR_PLACE).
	var clothed: Array[String] = ["clothed_station", "clothed_shed"]
	for key: String in s:
		if key.begins_with("clothed_") and not clothed.has(key):
			clothed.append(key)
	for key in clothed:
		for c in s.get(key, []):
			zombies.spawn("clothed", FieldGrid.center(c))
	# The dead indoors, on every floor and in the cellar.
	for row in s.get("dead_levels", []):
		zombies.spawn("dead", lift(row[0], int(row[1])))
	for c in s.get("frozen_siding", []):
		zombies.spawn("frozen", FieldGrid.center(c), {"depth": rng.randf_range(0.6, 1.0)})
	# Now and then one of them has an axe in its back (zombies.gd EMBED_*).
	zombies.embed_weapons()
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

## What the stop loader makes ahead from a map off the main thread (stop_loader.gd
## make_ready): the building plan, the ground's details or arrays, the floors' arrays,
## the rooms' finish, the walk from the train and the trees to fell (work_spots.gd).
const AHEAD_KEYS: Array[String] = ["_building_plan", "_ground_details", "_ground_arrays", "_ground_key",
	"_floor_arrays", "_floor_keys", "_room_finish", "_walk_field", "_walk_key", "fell_groves"]


## The ground of the stop's form (stop_ground.gd), put on before the side path
## (with_side_path). An edge stop grows and shifts the map, so what the loader made
## ahead from it is dropped first, and a map handed over with its side path already on
## is built again bare by `fresh`; a city or siding stop keeps all of it.
static func shape_stop(map: Dictionary, form: String, run_seed: int, target_m: float, fresh: Callable) -> Dictionary:
	if form.is_empty() or form == String(map.get("stop_form", "")) or form == String(map.get("stop_form_asked", "")):
		return map
	if form == "edge":
		if map.has("side_path"):
			map = fresh.call()
		for key in AHEAD_KEYS:
			map.erase(key)
	return StopGround.apply(map, form, run_seed, target_m)


## The side path on a map built here or handed over (side_path.gd). The loader puts it
## on when it knows the field's seed (stop_loader.gd make_ready); else it goes on here,
## and as it can grow the map, shift it and put its store on it, what the loader made
## ahead from the map as it was no longer fits: dropped first (a shift would move it
## all), made again from the map as it is now.
static func with_side_path(map: Dictionary, run_seed: int) -> Dictionary:
	var place_id := String(map.get("place_id", ""))
	if not map.has("side_path") and place_id not in ["", SidePath.FIRST_STOP] and SidePath.rolls(place_id, run_seed):
		for key in AHEAD_KEYS:
			map.erase(key)
	return SidePath.add(map, run_seed)


## Reapply derived times after a saved stop is restored (decision 494).
func set_stop_form(form: String) -> void:
	stop_form = StopForm.resolve({"stop_form": form}, String(data["place_kind"]))
	clock.safe_sec = StopForm.safe_sec(stop_form)
	clock.limit_sec = StopForm.limit_sec(stop_form)
	if director != null:
		director.limit_sec = clock.limit_sec
	if music != null:
		music.director.safe_sec = clock.safe_sec


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
	# Still being built or not yet shown: nothing runs to stop (the slice holds it).
	if not is_built or standing_by:
		return
	# A call, the home button or a dropped screen stops the field (reference harvest r1, #16).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		interrupt()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		welcome_back()


func interrupt() -> void:
	# Fingers down when the app goes away never come back up, paused or not.
	if hud != null:
		hud.drop_touch()
	# The one save slot, before the app may be shut (S3 spec 4). Off until the train side reads it.
	if bool(opts.get("field_save", false)):
		FieldSave.write(FieldSave.capture(self), String(opts.get("field_save_path", FieldSave.PATH)))
	if ended:
		return
	if not away:
		resume_announce = not paused
	paused = true
	away = true


## Back from an interrupt: one line, once (ui_states N4). Only when the app
## paused the field; a pause the player chose is not announced again.
func welcome_back() -> void:
	if not away:
		return
	away = false
	if not ended:
		if resume_announce and hud != null:
			hud.toast("멈춰 둔 자리다.")
		begin_resume()


## One entry path for both an app interruption and a restored slot. This clock
## is real foreground time, independent of the field clock's rate and pause.
func begin_resume() -> void:
	resume_pending = true
	resume_wait_left = 1.0
	paused = true
	if hud != null:
		hud.show_resume()
	paused = true
	# Arm on the first visible field frame, after restoration/building has finished.
	resume_ready_at_ms = -1


func continue_resume() -> bool:
	if not resume_pending or resume_ready_at_ms < 0 or away:
		return false
	resume_wait_left = maxf(0.0, float(resume_ready_at_ms - Time.get_ticks_msec()) / 1000.0)
	if resume_wait_left > 0.0:
		return false
	if hud != null:
		hud.close_resume()
	resume_pending = false
	paused = false
	return true


func _process(delta: float) -> void:
	if resume_pending:
		if not away and resume_ready_at_ms >= 0:
			resume_wait_left = maxf(0.0, float(resume_ready_at_ms - Time.get_ticks_msec()) / 1000.0)
		if hud != null:
			hud.tick_resume()
		if not away and resume_ready_at_ms < 0:
			resume_ready_at_ms = Time.get_ticks_msec() + 1000
		return
	delta = minf(delta, 0.1)
	if arrive_t >= 0.0:
		_arrive(delta)
	elif not ended and not paused:
		# Held as the frame starts: a hold shorter than a frame still stands one.
		hitstop = feel.holding()
		feel.tick(delta, true)
		if not hitstop:
			_step(delta * slow)
			_update_snow()
	else:
		hitstop = false
		feel.tick(delta, false)
	_update_fade(delta)
	if leave_t >= 0.0:
		leave_t += delta
		view.slide_train(train_roll(leave_t))
	_update_lantern(delta)
	_update_camera(delta)
	breath.tick(delta, self)
	vis_t -= delta
	if vis_t <= 0.0:
		vis_t = 0.1
		_refresh_vision()
	if mask_in < 1.0:
		mask_in = minf(1.0, mask_in + delta / MASK_IN_S)
		view.set_mask_shade(smoothstep(0.0, 1.0, mask_in))
	zombies.render(camera, seen_now, mask_on)
	for p in people:
		p.visible = level_shown(level_of(p.position)) and _person_visible(p) and not rode_off.has(p) and arrive_t < 0.0
		p.refresh_view(p.visible)
	hud.tick(delta)
	audio.tick(delta)
	music.tick(delta)


## The drawn bodies of the AI people come round on the rules' clock, each at
## its own rate near TURN_DEG_PER_S (decision 442 card C2: it was the frame's,
## so the rules that wait on a turn did not play in a field run on _step alone).
func _turn_people(delta: float) -> void:
	for p in people:
		if p != player and p.turn_rate <= 0.0:
			p.turn_rate = deg_to_rad(TURN_DEG_PER_S) * (0.85 + 0.3 * p.name_unit())
			p.look = p.facing
		p.turn_tick(delta)


func _step(delta: float) -> void:
	clock.advance(delta)
	weather.dusk = clock.dusk_share()
	var now := clock.elapsed
	_turn_people(delta)
	radio_t -= delta
	_tick_radio(delta)
	for p in people:
		_update_person(p, delta)
	_separate_people(delta)
	zombies.update(delta)
	ai.update(delta)
	_left_behind()
	combat.update(delta)
	_update_hordes(delta)
	_update_spawns(delta)
	train_guard.tick()
	building_alarms.tick()
	_update_blood(delta)
	_update_night(delta)
	_update_zone(delta)
	_watch_named()
	_reveal_glints()
	_read_side_note()
	_land_lures()
	actions.update(delta)
	work.update(delta)
	holdout.tick(delta)
	residents.tick(delta)
	holdout.watch(delta)
	holdout.den_watch()
	_check_end()
	var keep: Array = []
	for s in sounds:
		if now - float(s["t"]) < SimNoise.EVENT_DISPLAY_SECONDS:
			keep.append(s)
	sounds = keep


## The living standing still keep out of each other's bodies (people_separation.gd),
## once everyone has moved: only where they stand changes, never onto a cell people
## cannot walk, through a wall or onto a stair. Anyone on the way somewhere passes
## through as before, and the player, anyone at work at a spot, carrying someone
## or in a fight stays put: the other one standing steps aside. (Easing walkers
## and fighters too changed the fights the 40 runs measure, 10-26.)
func _separate_people(delta: float) -> void:
	var bodies: Array = []
	var positions := PackedVector3Array()
	var floors := PackedInt32Array()
	var ids := PackedInt64Array()
	var speeds := PackedFloat32Array()
	var fixed := PackedByteArray()
	for p in people:
		if not p.visible or not p.is_alive() or p.body.downed or p.fallen_t > 0.0 or not p.grabbers.is_empty():
			continue
		if p.moving or not p.path.is_empty():
			continue
		bodies.append(p)
		positions.append(p.position)
		floors.append(level_of(p.position))
		ids.append(hash(String(p.pid)))
		speeds.append(p.speed(grid_at(p.position).floor_at(FieldGrid.cell_of(p.position))))
		var fighting: bool = not p.target_zombie.is_empty() or p.target_person != null or p.swing_t > 0.0 or p.strike_t > 0.0 or p.shove_t > 0.0
		fixed.append(1 if p == player or p.action != "" or p.carrying_wounded != null or fighting else 0)
	if bodies.size() < 2:
		return
	var pushes := PeopleSeparation.pushes(positions, floors, ids, speeds, fixed, delta)
	for i in range(bodies.size()):
		if pushes[i] == Vector3.ZERO:
			continue
		var dest := positions[i] + pushes[i]
		var cell := FieldGrid.cell_of(dest)
		var lg := grid_at(positions[i])
		if level_of(dest) != floors[i] or not lg.people_can_walk(cell) or not lg.body_line_clear(FieldGrid.cell_of(positions[i]), cell):
			continue
		if _on_stair(cell, floors[i]):
			continue
		bodies[i].position = dest


## A stair or ladder end on that floor (the dead are never pushed onto one either).
func _on_stair(cell: Vector2i, level: int) -> bool:
	for stair in stairs:
		if stair["cell"] == cell and (int(stair["low"]) == level or int(stair["high"]) == level):
			return true
	return false


func _update_zone(delta: float) -> void:
	var z := grid.zone_at(FieldGrid.cell_of(player.position))
	if z != zone_now:
		zone_now = z
		telemetry.zone_enter(z, clock.elapsed)
	telemetry.zone_tick(z, delta)
	var looted := false
	for id in player.items:
		if STOCK_OF.has(id) or String(FieldItems.stock_of(id)[0]) != "":
			looted = true
	if looted and player.moving:
		telemetry.carry_time(delta)
	var pl := level_of(player.position)
	view.show_levels(pl)
	view.cut_away(grid_at(player.position).building_at(FieldGrid.cell_of(player.position)), pl)
	view.update_ground(ground_items)


# ---------------------------------------------------------------- people

func _update_person(p: Person, delta: float) -> void:
	actions.validate_work(p)
	if not p.is_alive():
		return
	var cell := FieldGrid.cell_of(p.position)
	var lg := grid_at(p.position)
	var indoor := lg.indoor(cell)
	var stove := near_stove(p.position)
	var ctx := {"running": p.is_running_now(), "swinging": p.swing_t > 0.0, "carry_state": p.carry_state(), "cold_level": p.cold_level(), "indoor_rest": indoor and not p.moving}
	for ev in p.body.tick(delta, ctx):
		_on_body_event(p, ev)
	var sheltered: bool = indoor and not building_open(lg.building_at(cell))
	# Rain and sleet under the open sky, and sweat dressed warm at a run or at work (wear.gd).
	var wetter: float = Wear.wet_gain(p, delta, weather.wets_clothes() and not sheltered and not stove, p.is_running_now() or p.action != "")
	if wetter > 0.0:
		p.heat.soak(wetter)
	p.heat.tick(delta, {"ambient_c": weather.ambient_c, "indoor": sheltered, "stove": stove, "warmth": Wear.warmth(p, p.heat.wet), "windproof": Wear.windproof(p), "moving": p.moving, "wind": 0.0 if indoor else weather.wind})
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
	# Pushing the stick walks away from slow work (search, prying, treating);
	# a hat, a scarf, a mask or gloves go on and off at a walk (decision 434),
	# the feet free while the hands work, but not at a run.
	var walking_work: bool = actions.walk_work(p)
	var breaks: bool = (p.running and p.stick != Vector2.ZERO) if walking_work else p.stick.length() > 0.3
	if breaks and STICK_BREAKS.has(p.action):
		p.cancel_action()
	if p.action != "":
		# Each action takes its body multiplier once, here (not also in its length).
		var rate := 1.0 if p.action == "climb" else float(p.mults()["swap" if p.action == "swap" else "hands"])
		if p.action == "search":
			actions.search_noise(p, delta)
		p.action_t -= delta * rate
		if p.action_t <= 0.0:
			actions.complete_work(p)
			var done := p.action_done
			p.cancel_action()
			if done.is_valid():
				done.call()
		if not walking_work:
			return
	if p.stick != Vector2.ZERO or p.drive_speed > 0.0:
		_drive(p, delta)
	else:
		_move_person(p, delta)


## A door a walk stops at to deal with on the way (field_actions
## open_door_on_way): a shut one, and for the player a locked one too, as a
## tap on it would — the key opens it, else 「잠김」 (the coordinator's call
## under decision 442, 2026-10-30). A companion's way goes round a locked
## door as before.
func _meets_door(p: Person, door: Dictionary) -> bool:
	var state := String(door.get("state", ""))
	return state == "closed" or (state == "locked" and p == player)


## Left-thumb walking (field_unified 10, user 17:32): the direction follows
## the thumb at once; the body takes a moment to get going and to stop, more
## so loaded, worn out or on ice. A hard turn at a run drops to a walk first.
func _drive(p: Person, delta: float) -> void:
	var push := p.stick.length()
	# A melee blow holds the feet from part way through it to its end (decision 425).
	if push > 0.05 and combat.feet_held(p):
		p.drive_speed = 0.0
		p.moving = false
		return
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
	if lg == grid and grid.doors.has(dc) and _meets_door(p, grid.doors[dc]):
		p.drive_speed = 0.0
		actions.open_door_on_way(p, dc)
		return
	if lg.blocks_body(dc):
		dest = _slide(p.position, step)
	dc = FieldGrid.cell_of(dest)
	if lg == grid and grid.windows.has(dc) and FieldGrid.cell_of(p.position) != dc:
		if not actions.can_vault_window(p, dc):
			return
		actions.vault_window(p, dc)
	var gone := p.position.distance_to(dest)
	p.position = dest
	p.moving = true
	_footsteps(p, delta, dc, gone)


func _move_person(p: Person, delta: float) -> void:
	# A walk along a path keeps the weapon's planted-feet span too (결정 441 (1)).
	if combat.feet_held(p):
		p.moving = false
		return
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
			hud.toast("너무 무거움")
			p.stop()
		return
	var way := atan2(d.x, d.z)
	var face := way
	if p != player:
		# One the AI walks turns into the way before it goes (move_rules.gd); backing
		# off a crowd it keeps its face to them and steps back (field_ai.gd _engage).
		var hold: Variant = p.brain.get("face_hold")
		if hold is Vector3 and clock.elapsed - float(p.brain.get("face_hold_t", -INF)) < MoveRules.FACE_HOLD:
			var them: Vector3 = hold
			face = atan2(them.x - p.position.x, them.z - p.position.z)
			if absf(angle_difference(face, way)) > PI * 0.5:
				spd = minf(spd, MoveRules.BACKPEDAL)   # none runs backwards
		elif p.turn_rate > 0.0:
			spd *= MoveRules.heading_share(absf(angle_difference(p.look, way)))
		p.facing = face
		if spd <= 0.0:
			p.moving = false   # a half turn is made standing, not gliding off the other way meanwhile
			return
	var step := d.normalized() * minf(spd * delta, d.length())
	var dest := p.position + step
	var dc := FieldGrid.cell_of(dest)
	if lg == grid and grid.doors.has(dc) and _meets_door(p, grid.doors[dc]):
		actions.open_door_on_way(p, dc)
		return
	if lg.blocks_body(dc):
		dest = _slide(p.position, step)
	dc = FieldGrid.cell_of(dest)
	if lg == grid and grid.windows.has(dc) and FieldGrid.cell_of(p.position) != dc:
		if not actions.can_vault_window(p, dc):
			return
		actions.vault_window(p, dc)
	p.facing = face
	var gone := p.position.distance_to(dest)
	if absf(angle_difference(face, way)) > PI * 0.5:
		gone = -gone   # stepping back: the walk's round runs back, so it is drawn backwards
	p.position = dest
	p.moving = true
	_footsteps(p, delta, dc, gone)


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


## A footstep as the walk puts a foot down (decision 425): the walk goes round
## by the ground covered (`gone`), two steps to a round (SimNoise.STEP_AT).
## The round's place is kept on the body (brain "step_r") for the drawing too.
## Each person walks at their own stride and starts from their own place in the
## round (gait.gd, decision 423 card 3), so two who go together are not in step.
static func steps_in(p, gone: float) -> int:
	var size: float = float(SimNoise.STEP_ROUND["run" if p.is_running_now() else ("crouch" if p.crouched else "walk")]) * Gait.stride(p)
	var was := float(p.brain.get("step_r", Gait.first_step(p)))
	var now := was + gone / maxf(size, 0.01)
	p.brain["step_r"] = fposmod(now, 1.0)
	var n := 0
	for at: float in SimNoise.STEP_AT:
		n += absi(int(floorf(now - at)) - int(floorf(was - at)))   # a step back is a step too
	return n


func _footsteps(p: Person, delta: float, cell: Vector2i, gone: float = 0.0) -> void:
	var running := p.is_running_now()
	var lg := grid_at(p.position)
	var floor_kind := lg.floor_at(cell)
	if steps_in(p, gone) > 0:
		var glass: bool = lg.windows.has(cell) and lg.windows[cell]["glass"]
		var trait_mult := 1.0
		var r := SimNoise.footstep_radius(running, FieldGrid.FLOOR_SOUND[floor_kind], trait_mult, p.crouched, int(p.skills["stealth"]), glass, lg.indoor(cell)) * weather.sound_mult(true)
		var level := SimNoise.footstep_level(running, glass)
		var reacted: int = zombies.hear(p.position, level, r)
		ledger.observe(level, "run" if running else ("crouch" if p.crouched else "walk"), r, reacted)
		if running:
			_ripple_run(p, r)
		if p == player and audio != null:
			audio.footstep(p.position, running)
		_wake_frozen_near(p)
		_floor_creak(p, cell)
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
		elif p.carry_state() >= 2 and rng.randf() < delta * 0.03:
			combat.fall(p, "짐에 눌려 넘어졌다")


## A loose board with something under it (room_stories.gd, card K) creaks when stepped on
## or beside, softly and not again for a while; once searched it is quiet.
const CREAK_AGAIN: float = 3.0


func _floor_creak(p: Person, cell: Vector2i) -> void:
	for s: Dictionary in data.get("floor_stashes", []):
		var box: Dictionary = data["containers"].get(s["id"], {})
		var d: Vector2i = (cell - (s["cell"] as Vector2i)).abs()
		if box.is_empty() or box["searched"] or maxi(d.x, d.y) > 1 or int(s["level"]) != level_of(p.position):
			continue
		if clock.elapsed < float(s.get("quiet_until", -INF)):
			continue
		s["quiet_until"] = clock.elapsed + CREAK_AGAIN
		var at := lift(s["cell"], int(s["level"]))
		make_sound(at, SimNoise.Level.QUIET, "floor_creak", p)
		if audio != null:
			audio.floor_creak(at)


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


## A building with a broken or open window no longer keeps the warmth
## (body_injury 3.1); boarded to the third plank on a face it keeps it again
## (field_actions._note_cold keeps the row's flag). Found by id, not list place.
func building_open(b: int) -> bool:
	if b < 0:
		return true
	return bool(BuildingRules.building(data, b).get("window_broken", false))


func _on_body_event(p: Person, ev: String) -> void:
	match ev:
		"downed":
			p.cancel_action()
			p.stop()
			say(p, "%s 쓰러졌다." % p.display_name, false, "downed")
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
				say(p, "%s 열이 오른다." % p.display_name, false, "window_closed")
		"exhausted_heavy":
			if p == player:
				hud.toast("숨참")


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
	# It gets up in what it wore, and that is what can be taken off it (decision 434).
	z["worn"] = p.worn.duplicate(true)
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
## The player's running shows its reach on the ground, a ring a second at most (H1).
func _ripple_run(p: Person, r: float) -> void:
	if p != player or ripples == null or clock.elapsed - ripple_run_t < SoundRipple.SECONDS:
		return
	ripple_run_t = clock.elapsed
	ripples.show_ring(p.position, r)


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
			set_radio("기관사: 굴 쪽이 울립니다. 다음 것들은 %s에서 나옵니다." % director.name_of(hole), "info", entry_pos(hole))
	var radius := SimNoise.radius(level, indoor, director.call_range_mult(now)) * weather.sound_mult(false) * SimNoise.reach(tag)
	var reacted: int = zombies.hear(at, level, radius)
	ledger.observe(level, tag, radius, reacted)
	_score(level, tag)
	sounds.append({"pos": at, "level": level, "t": now, "tag": tag})
	if from != null and squad.has(from) and RIPPLE_TAGS.has(tag) and ripples != null:
		ripples.show_ring(at, radius)
	# The train's own sounds (noise.gd SOURCES) call the dead to the train and
	# pull nothing: they tell nobody where the squad is.
	var noticed: bool = level >= SimNoise.Level.LOUD and SimNoise.notices(tag)
	if noticed:
		last_loud = at
		director.noticed(now)
	if audio != null:
		audio.on_sound(at, level, tag)
	if noticed:
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
## event shape as the minute pulse; falling snow weakens older drops (8.1),
## rain washes every drop to half its pull (decision 445).
func strongest_scent(at: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_score := 0.0
	var now := clock.elapsed
	var snowing := weather.kinds.has("snow") or weather.kinds.has("blizzard")
	var raining := weather.kinds.has("rain")
	for b in blood:
		var reach: float = BLOOD_SCENT_R * weather.scent_mult(b["pos"], at)
		if snowing and now - float(b["t"]) > 30.0:
			reach *= 0.7
		if raining:
			reach *= SmellRules.RAIN_FADE
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
## They start lit: a stop reached after dark asks before the people are made.
func lamps_on() -> bool:
	return player == null or player.lamp_on


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
		set_radio("기관사: 놓친 것 같습니다. 다음 것들이 늦어집니다. 숨 돌리십시오.")
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
			set_radio("기관사: 한 무리 지나갔습니다. " + driver_forecast(now, forecast_precision) + lid_tip())


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
			if FieldMaps.lid(key) and view.manhole_nodes.has(key):
				view.jolt_manhole(key)   # they push at it from under, and it holds
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
			set_radio("기관사: " + driver_forecast(now, forecast_precision) + lid_tip())
	deaf_t = maxf(0.0, deaf_t - delta)


func _someone_near(at: Vector3, r: float) -> bool:
	for p in people:
		if p.is_alive() and p.position.distance_to(at) < r:
			return true
	return false


## The driver's forecast, said to the chief politely like the user's own line
## for him (decisions 486). horde_director words it so, but its no-more line
## stays plain for the signal box and a roof, so the driver's is said here.
func driver_forecast(now: float, precision: int) -> String:
	if director.is_exhausted():
		return "더 오는 기척은 없습니다."
	return director.forecast(now, precision, clock)


## Once per field, when the next wave comes up the open street manhole: how to
## shut it (H3 2026-10-09: the player never found that it can be shut).
func lid_tip() -> String:
	if lid_tip_told or not FieldMaps.lid(director.next_entry) or not director.is_open(director.next_entry) or director.is_exhausted():
		return ""
	lid_tip_told = true
	return " 맨홀은 판자나 고철로 누르면 막힙니다."


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
			audio.lid_scrape(view.manhole_nodes[key].global_position)
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
## raiders and the dead keep quiet. `name`: who fell, for the lines that call them.
func shout(p, event: String, always: bool = false, name: String = "") -> void:
	if hud == null or p == player or p.body.dead or not (squad.has(p) or always and crew.has(p)):
		return
	var line: String = lines.pick(String(p.pid), event, clock.elapsed, always, name)
	if line != "":
		hud.shout(p, line)


## One of the squad fell: the companion nearest to them, if near, rages.
func shout_near(fallen, event: String) -> void:
	shout_nearest(fallen.position, event, AllyLines.RAGE_NEAR, fallen, false, fallen.display_name)


## The companion on their feet nearest `at`, within `reach`, says it (not `but`).
func shout_nearest(at: Vector3, event: String, reach: float, but = null, always: bool = false, name: String = "") -> void:
	var best = null
	var best_d: float = reach
	for o in squad:
		if o == but or o == player or not o.is_alive() or o.body.downed:
			continue
		var d: float = o.position.distance_to(at)
		if d < best_d:
			best_d = d
			best = o
	if best != null:
		shout(best, event, always, name)


## Lying hurt or held while the chief walks off.
func _left_behind() -> void:
	for o in squad:
		if o == player or o.body.dead or not (o.body.downed or not o.grabbers.is_empty()):
			continue
		if o.position.distance_to(player.position) > AllyLines.LEFT_BEHIND_M:
			shout(o, "left_behind")


# ---------------------------------------------------------------- vision & camera

## Sight: a wide cone ahead, a small circle all round, walls hide.
## Upstairs the eye reaches further (out of the windows, over the yards);
## the signal box top sees all round. Down in the cellar it is dark.
func _refresh_vision() -> void:
	var origin := FieldGrid.cell_of(player.position)
	var lv := level_of(player.position)
	var lg := grid_at(player.position)
	var tower: bool = lv > 0 and BuildingRules.role_of(data, lg.building_at(origin)) == "lookout"
	var base := SIGHT_UPSTAIRS if lv > 0 else (SIGHT_CELLAR if lv < 0 else SIGHT_RADIUS)
	var radius := maxi(3, int(round(base * (eye_mult() if lv >= 0 else 1.0))))
	if not mask_on:
		seen_now = {}
		view.set_mask_enabled(false)
		view.update_vis(seen_now, seen_memory, lamp_cells())
		return
	view.set_mask_enabled(true)
	var forward := Vector2.ZERO if tower else Vector2(sin(player.facing), cos(player.facing))
	# At night the eye still sees, past its short reach and out to the day's,
	# what a light shows it with no wall between (decision 479): the dead by a
	# fire, the ground in the torch's beam.
	var lit_far := lv >= 0 and clock.is_dark() and radius < base
	var result := lg.visible_cells(origin, base if lit_far else radius, forward, VIEW_CONE_COS, NEAR_SIGHT)
	lit_now = lamp_cells(result)
	if lit_far:
		var near2 := radius * radius
		for i: int in result.keys():
			var c := Vector2i(i % lg.width, i / lg.width)
			if Vector2(c - origin).length_squared() > near2 and int(lit_now.get(i, 0)) < BuildingRules.LIT_MIN:
				result.erase(i)
	# Indoors after dark the eye reaches into an unlit room only as far as in a cellar.
	if lv >= 0 and clock.is_dark():
		var reach2 := BuildingRules.DARK_SIGHT * BuildingRules.DARK_SIGHT
		for i: int in result.keys():
			var c := Vector2i(i % lg.width, i / lg.width)
			if Vector2(c - origin).length_squared() > reach2 and _dark_cell(lg, lv, c):
				result.erase(i)
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
	# The room the eye stands in is drawn as seen whichever way the eye faces
	# (decision 469 D3): its floor, furniture and walls keep their outline. Only
	# the picture: who and what the rules see stays the cone's (seen_now).
	var shown := seen_now
	var room := _room_cells(lg, lv, origin)
	if not room.is_empty():
		shown = seen_now.duplicate()
		for i in room:
			shown[(lv + 1) * n + i] = true
	view.update_vis(shown, seen_memory, lit_now)
	view.update_labels(seen_memory, mask_on)


## Indoors after dark, out of a window's light and any lamp's (decision 439 card 1).
## The cellar has its own short sight and is not counted here.
func dark_at(at: Vector3) -> bool:
	if not clock.is_dark():
		return false
	var lv := level_of(at)
	return lv >= 0 and _dark_cell(grid_at(at), lv, FieldGrid.cell_of(at))


## The room round the eye on its floor (decision 469 D3): floor cells of the
## same building reached from it side by side without passing a wall, door or
## window, and the walls, doors and windows round them. None outdoors, in a
## doorway or in the cellar, and none past ROOM_SHOWN_MAX cells (a hall is not
## one room). Kept until the eye moves or the floor changes.
const ROOM_SHOWN_MAX: int = 400
var _room_cache: Dictionary = {}


func _room_cells(lg: FieldGrid, lv: int, origin: Vector2i) -> Array[int]:
	var at := Vector3i(origin.x, origin.y, lv)
	if _room_cache.get("at") == at and int(_room_cache.get("rev", -1)) == lg.revision:
		return _room_cache["cells"]
	var out: Array[int] = []
	var b := lg.building_at(origin)
	if lv >= 0 and b >= 0 and _room_floor(lg, origin, b):
		var done := {lg.index(origin): true}
		var todo: Array[Vector2i] = [origin]
		while not todo.is_empty() and out.size() <= ROOM_SHOWN_MAX:
			var c: Vector2i = todo.pop_back()
			out.append(lg.index(c))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var d := c + Vector2i(dx, dy)
					if (dx == 0 and dy == 0) or not lg.inside(d) or done.has(lg.index(d)):
						continue
					var floor_cell := _room_floor(lg, d, b)
					# Floor goes on side by side; across a corner only the wall shows.
					if floor_cell and dx != 0 and dy != 0:
						continue
					if not floor_cell and lg.building_at(d) != b:
						continue
					done[lg.index(d)] = true
					if floor_cell:
						todo.append(d)
					else:
						out.append(lg.index(d))
		if out.size() > ROOM_SHOWN_MAX:
			out = []
	_room_cache = {"at": at, "rev": lg.revision, "cells": out}
	return out


func _room_floor(lg: FieldGrid, c: Vector2i, b: int) -> bool:
	var solid := lg.solid_at(c)
	return lg.building_at(c) == b and (solid == FieldGrid.Solid.NONE or solid == FieldGrid.Solid.BLOCK or solid == FieldGrid.Solid.LOW)


func _dark_cell(lg: FieldGrid, lv: int, c: Vector2i) -> bool:
	if not lg.indoor(c):
		return false
	var i := lg.index(c)
	if int(lit_now.get(i, 0)) >= BuildingRules.LIT_MIN:
		return false
	var row: Dictionary = _window_lit.get(lv, {})
	if int(row.get("rev", -1)) != lg.revision:
		row = {"rev": lg.revision, "cells": BuildingRules.window_lit_cells(lg)}
		_window_lit[lv] = row
	return not (row["cells"] as Dictionary).has(i)


func _person_visible(p: Person) -> bool:
	if p.team != "raider" and p.team != "survivor":
		return true
	if not mask_on:
		return true
	return seen_now.has(seen_key(p.position))


func cell_seen(at: Vector3) -> bool:
	return not mask_on or seen_now.has(seen_key(at))


## The footprint of the building whose walls are cut away round the player
## (building_view open_b); empty outside or with grey boxes.
func _open_room() -> Rect2i:
	var bv = view.buildings
	if bv == null or int(bv.open_b) < 0 or not bv.footprints.has(bv.open_b):
		return Rect2i(0, 0, -1, -1)
	return bv.footprints[bv.open_b]


func _update_camera(delta: float) -> void:
	var focus := player.position + cam_push
	# The view ends inside the woods round the map, never past them (edge_band.gd).
	var screen := get_viewport().get_visible_rect().size
	var aspect := screen.x / maxf(screen.y, 1.0)
	focus = EdgeBand.clamp_focus(focus, EdgeBand.view_half(cam_size, aspect, CAM_PITCH, CAM_YAW), grid.width, grid.height)
	focus = EdgeBand.keep_on_screen(focus, player.position, cam_size, aspect, CAM_PITCH, CAM_YAW)
	cam_focus = cam_focus.lerp(focus, clampf(delta * 4.0, 0.0, 1.0))
	if map_edge != null:
		map_edge.set_eye(player.position)
		map_edge.set_room(_open_room())
	_set_sight_round()
	camera.size = lerpf(camera.size, cam_size, clampf(delta * 6.0, 0.0, 1.0))
	var back := cam_back() * 60.0
	# A blow's kick moves the eye, not the place it follows (hit_feel.gd).
	var kick: Vector3 = feel.camera_offset() * camera.size if feel != null else Vector3.ZERO
	camera.position = cam_focus + back + kick
	camera.look_at(cam_focus + kick, Vector3.UP)
	snow.position = cam_focus + Vector3(0, 9, 0)
	_update_storm()
	_update_light()


## Which way the camera stands from what it looks at, one metre out: south-east
## (CAM_YAW) and up (CAM_PITCH).
static func cam_back() -> Vector3:
	var pitch := deg_to_rad(CAM_PITCH)
	var yaw := deg_to_rad(CAM_YAW)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


## A direction on the screen (x right, y down) as one on the ground (x, z): the
## camera is turned CAM_YAW, so up on the screen is north-west on the map.
func screen_dir(v: Vector2) -> Vector2:
	return v.rotated(-deg_to_rad(CAM_YAW))


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



## One blow on a building door, by `by` (one of the dead). As on the train's
## doors (decision 314, the user's morning answer for houses): it wears the door
## only with another of the dead on its feet within CROWD_R of the one striking;
## one alone just knocks, and the knock is still heard.
func on_door_banged(c: Vector2i, by: Dictionary = {}) -> void:
	var door: Dictionary = grid.doors[c]
	if door["state"] == "open" or door["state"] == "broken":
		return
	make_sound(FieldGrid.center(c), SimNoise.Level.NORMAL, "bang")
	if not by.is_empty():
		# The dead on their feet within CROWD_R of the one striking, it counted.
		var near := 0
		for o in zombies.list:
			if not zombies.active(o) or o["state"] == "downed" or level_of(o["pos"]) != level_of(by["pos"]):
				continue
			var d: Vector3 = o["pos"] - by["pos"]
			if Vector2(d.x, d.z).length() <= FieldHoldout.CROWD_R:
				near += 1
		if near < FieldHoldout.CROWD_MIN:
			return
	door["hp"] = int(door["hp"]) - 1
	# The planks on the face they strike from give way first (building_rules.gd).
	var had: int = BuildingRules.planks_total(door)
	var toppled := BuildingRules.wear_defences(door, grid.face_toward(c, by.get("pos", FieldGrid.center(c))))
	if not toppled.is_empty():
		actions.topple_furniture(toppled, c)
	if BuildingRules.planks_total(door) != had:
		grid.refresh_cell(c)
		view.update_door(c)
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
		set_radio("기관사: 이제 떠나야 합니다. 오래는 못 기다립니다.", "must")


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
## What a work crew's trip carries for the laws the train lives under (1.0 with none).
func haul_mult() -> float:
	return RATION_HAUL if (opts.get("laws", []) as Array).has("emergency_ration") else 1.0


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
		audio.train_brake(ARRIVE_BRAKE_S)
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
			receipt.add_wound(p.pid, row["part"], row["kind"], bool(row.get("festering", false)), row.get("treat", {}))
	var stock: Dictionary = {}
	var fragments: Array = []
	for id in unloaded:
		if STOCK_OF.has(id):
			var row: Array = STOCK_OF[id]
			stock[row[0]] = float(stock.get(row[0], 0.0)) + float(row[1]) * int(unloaded[id])
		elif FieldItems.has(id):
			# A named thing melts into the number it was cut from (decision 423-8).
			var melt: Array = FieldItems.stock_of(id)
			if String(melt[0]) != "":
				stock[melt[0]] = float(stock.get(melt[0], 0.0)) + float(melt[1]) * int(unloaded[id])
			if FieldItems.kept_by_name(id):
				for k in range(int(unloaded[id])):
					receipt.gain_item(id)
			# A blueprint piece is one entry of its field on extras.fragments (S1 domestic 5.2).
			var piece: String = FieldItems.fragment_of(id)
			if piece != "":
				for k in range(int(unloaded[id])):
					fragments.append(piece)
		if id in ["symbol_bell", "info_telegraph", "info_timetable"]:
			receipt.gain_item(id)
		elif CoreScenes.CORE_ITEMS.has(id):
			# One entry a core, so the count reads off the list (CoreScenes.count).
			for k in range(int(unloaded[id])):
				receipt.gain_item(id)
	# What the food was before it melted into stock.food (s3 contract 3 foodIn, J07): the
	# train's pot reads fresh, wilted, spoiled, raw, frozen or dented from the id.
	if contract_on():
		var food_in := {}
		for id in unloaded:
			var into: String = String(STOCK_OF[id][0]) if STOCK_OF.has(id) else (String(FieldItems.stock_of(id)[0]) if FieldItems.has(id) else "")
			if into == "food" and int(unloaded[id]) > 0:
				food_in[String(id)] = int(unloaded[id])
		receipt.set_food_in(food_in)
		# Where the decks stand after this stop rides back to the train for the next contract (474 S1).
		receipt.set_loot_deck(loot_report.get("loot_deck", {}))
	# The cores' count and the blueprint pieces go into extras here and only here (decision
	# 426), on a stop receipt, one that has its ids: setting extras on a field receipt without
	# ids would make it a stop receipt with empty ones, which the receipt check turns down.
	# set_extras keeps the documents already found.
	if receipt.is_stop_receipt():
		var so_far := receipt.to_dict()
		var extras: Dictionary = so_far.get("extras", {})
		receipt.set_extras(int(extras.get("symbolCount", 0)), Array(extras.get("fragments", [])) + fragments, CoreScenes.count(so_far["items"]["gained"]))
	stock["coal"] = float(stock.get("coal", 0.0)) + actions.coal_delivered - actions.coal_spent - int(holdout.cost_paid["coal"])
	stock["scrap"] = float(stock.get("scrap", 0.0)) + float(unloaded.get("scrap", 0))
	stock["wood"] = float(stock.get("wood", 0.0)) + float(unloaded.get("wood", 0)) + actions.wood_delivered
	stock["cloth"] = float(stock.get("cloth", 0.0)) - cloth_start
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
	# A hidden core looked at without the engine hand (field_unified 3장): one line, a reason to bring them.
	if String(data["spots"].get(CoreScenes.SPOT, {}).get("state", "")) == "seen_hidden":
		receipt.place_note("coreHint", true)
	# The side path's rare store goes on the receipt only when someone got to it.
	if SidePath.visited(data):
		receipt.place_note("sidePath", "rareStore")
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
	_receipt_finds(boarded)
	_contract_end(boarded)
	train_guard.write_receipt()
	receipt.set_end(reason)
	for d in decisions:
		receipt.decision(d["id"], d["choice"])
	var on_track := track_dead()
	telemetry.track(on_track["west"], on_track["east"])
	telemetry.end(reason, now)
	var result := {"reason": reason, "receipt": receipt.to_dict(), "receipt_json": receipt.to_json(), "telemetry": telemetry.to_json_line(), "boarded": boarded.size(), "stay": clock.stay_game_minutes(), "real_seconds": now, "unloaded": unloaded.duplicate(), "noise": ledger.total, "hordes": hordes.size(), "holdout_lines": holdout.end_lines(), "places": data["containers"].size(), "dead_about": zombies.alive_count()}
	_save(result)
	if bool(opts.get("field_save", false)):
		# The stop is over: the slot says so, and the next start does not come back to it.
		FieldSave.write(FieldSave.capture(self), String(opts.get("field_save_path", FieldSave.PATH)))
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


## The contract's side of the receipt (s3 contract 3): each departure promise as seen by those of
## the squad who came back (the train judges it), how each one aboard came back (v5 crew rows,
## with what they wear of the wardrobe's places), the outer things put aboard, the lures back.
func _contract_end(boarded: Array) -> void:
	if not contract_on():
		return
	var back: Array = []
	for p in boarded:
		if squad.has(p):
			back.append(p.pid)
	for promise: Dictionary in opts["departure"].get("promises", []):
		receipt.see_promise(String(promise["id"]), String(promise["kind"]), back, [String(promise["madeTo"])])
	for p in boarded:
		var hands: Array = []
		for h: Dictionary in p.hands:
			if String(h.get("id", "")) != "":
				hands.append([String(h["id"]), String(h.get("quality", "factory")), snappedf(float(h.get("condition", 1.0)), 0.01)])
		receipt.set_crew_row(p.pid, p.body.exhaustion_level(), p.hunger_level, {}, hands, p.items, Wear.back_of(p))
	# The outer things put aboard at the platform go to the wardrobe; the rest of what was put
	# aboard has no place there.
	var into: Array = []
	for g: Dictionary in loaded_wear:
		if Wear.OUTER_PLACES.has(Wear.slot_of(String(g.get("id", "")))):
			var e := Wear.to_wardrobe(g)
			if not e.is_empty():
				into.append(e)
	receipt.set_wardrobe_in(into)
	# The train's lures are not handed out in the field yet: all come back.
	var given_lures := int((opts["departure"].get("train", {}) as Dictionary).get("lures", 0))
	if given_lures > 0:
		receipt.set_lures_back({"clockwork": given_lures})


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
	if FieldItems.is_key(id):
		# A key says whose door it opens.
		var b: int = FieldItems.key_building(id)
		var buildings: Array = data.get("buildings", [])
		var where: String = String((buildings[b] as Dictionary).get("name", "")) if b >= 0 and b < buildings.size() else ""
		return "%s 열쇠" % where if where != "" else FieldItems.item_name(id)
	if FieldItems.has(id):
		return FieldItems.item_name(id)
	return String(Carry.ITEM_NAMES.get(id, W.get_data(id).get("name", id)))


## The picture of a thing in the bag or a box ("" for one with none of its own).
func item_icon(id: String) -> String:
	if FieldItems.has(id):
		return FieldItems.icon(id)
	return String(BUNDLE_ICONS.get(id, ""))


# ---------------------------------------------------------------- named things

## The old field things' pictures (hud_icons.gd), so a row never stands bare.
const BUNDLE_ICONS: Dictionary = {
	"food_pack": "food", "med_box": "med", "luxury_pack": "lux", "bandage": "bandage", "medkit": "med",
	"bottle_spirit": "lux", "document": "papers", "info_telegraph": "papers", "info_timetable": "papers",
	"cloth": "it_cloth", "plank": "it_plank", "wood": "it_plank", "scrap": "wrench", "flare": "lamp",
	"needle_thread": "it_needle", "tweezers": "it_needle", "symbol_bell": "it_bell",
	"frying_pan": "it_pan", "broken_bottle": "it_bottle_broken", "wood_stake": "it_stake",
	"knife": "it_knife", "crowbar": "wrench", "axe": "axe",
	"plow_core": "gear", "core_engine": "gear", "core_electric": "gear",
}


## A set watch in somebody's pack starts its count when first carried and rings
## at whoever carries it unless switched off (P19); a named find gets its line
## from the one who has it, once (P14).
func _watch_named() -> void:
	var now := clock.elapsed
	for p in squad:
		if not p.is_alive():
			continue
		for id: String in p.items:
			if FieldItems.rings(id):
				var have := 0
				for a: Dictionary in alarms:
					if a["who"] == p and a["id"] == id:
						have += 1
				for k in range(int(p.items[id]) - have):
					alarms.append({"who": p, "id": id, "at": now + eat_rng.randf_range(ALARM_DELAY_MIN, ALARM_DELAY_MAX), "left": ALARM_RINGS})
			elif FieldItems.line(id) != "" and not named_seen.has(id):
				named_seen[id] = true
				say(p, "%s: %s" % [p.display_name, FieldItems.line(id)])
			elif id == "note_map" and note_line() != "" and not named_seen.has(id):
				named_seen[id] = true
				say(p, "%s: 쪽지다. 「%s」" % [p.display_name, note_line()])
			elif FieldItems.fragment_of(id) != "" and not named_seen.has(id):
				# As S1 has it: the train can use it for its research.
				named_seen[id] = true
				say(p, "%s: %s을 찾았다." % [p.display_name, FieldItems.item_name(id)])
	var keep: Array = []
	for a: Dictionary in alarms:
		var who = a["who"]
		# Put down, loaded on the train, or switched off: it is no one's worry now.
		if not is_instance_valid(who) or not who.is_alive() or int(who.items.get(a["id"], 0)) <= 0:
			continue
		if now >= float(a["at"]):
			if int(a["left"]) == ALARM_RINGS and hud != null:
				hud.toast("%s의 가방 속 시계가 울린다." % who.display_name)
			make_sound(who.position, SimNoise.Level.NORMAL, "alarm", who)
			a["left"] = int(a["left"]) - 1
			a["at"] = now + ALARM_EVERY
			if int(a["left"]) <= 0:
				# Rung out: that watch is quiet from now on.
				who.take_item(a["id"])
				who.add_item(FieldItems.silenced(a["id"]))
				continue
		keep.append(a)
	alarms = keep


## Is a watch in the squad still set? (the key that stops them shows then)
func alarm_set() -> bool:
	for p in squad:
		if p.is_alive():
			for id: String in p.items:
				if FieldItems.rings(id):
					return true
	return false


## One key stops every set watch the squad carries.
func alarm_off() -> void:
	for p in squad:
		for id: String in p.items.keys():
			if FieldItems.rings(id):
				var n: int = int(p.items[id])
				p.take_item(id, n)
				p.add_item(FieldItems.silenced(id), n)
	alarms.clear()


## What the hands and the pack give for opening a tin (field_items.eat_plan).
func eat_tools(p) -> Dictionary:
	var knife := false
	var blunt := false
	for h: Dictionary in p.hands:
		var hid: String = String(h.get("id", ""))
		if String(W.get_data(hid).get("kind", "")) != "melee":
			continue
		if hid == "knife":
			knife = true
		else:
			blunt = true
	return {"opener": int(p.items.get("can_opener", 0)) > 0, "knife": knife, "blunt": blunt}


## Eat one of `id` there and then (survival_detail 3.5): a short while with the
## hands busy, less exhaustion after; a tin opened by a blow is heard.
func eat(p, id: String) -> void:
	if p == null or not p.can_act() or p.action != "" or int(p.items.get(id, 0)) <= 0:
		return
	var plan: Dictionary = FieldItems.eat_plan(id, eat_tools(p))
	if not bool(plan["ok"]):
		if p == player and hud != null:
			hud.toast("%s." % String(plan["why"]))
		return
	p.start_action("eat", "먹기", float(plan["seconds"]), _ate.bind(p, id, plan))


func _ate(p, id: String, plan: Dictionary) -> void:
	if not p.is_alive() or not p.take_item(id):
		return
	if bool(plan["loud"]):
		make_sound(p.position, SimNoise.Level.NORMAL, "can_bash", p)
	if float(plan["slip"]) > 0.0 and eat_rng.randf() < float(plan["slip"]):
		p.body.apply_cut(false, clock.elapsed, "arm_left")
		if p == player and hud != null:
			hud.toast("칼날이 미끄러져 손을 베었다.")
	# What is left of a tin is a lure to throw (P22).
	if String(FieldItems.row(id).get("eat", "")) == "can":
		p.add_item("can_empty")
	var result: Dictionary = FieldItems.eat_result(id, float(plan["spill"]))
	if bool(result["bad"]):
		if p == player and hud != null:
			hud.toast("상해 있었다.")
		return
	p.body.add_fatigue(-float(result["rest"]))


# ---------------------------------------------------------------- keys, the snow, notes, lures

## Things under the snow show to one of the squad this near (card 11), less
## after dark and in a blizzard. No key asks for it: walking by is enough.
const GLINT_REACH: float = 3.0
const GLINT_DARK: float = 0.6
const GLINT_STORM: float = 0.5
## An empty tin flies this far where the thrower faces (short of a wall), lands
## after a moment and rattles there; where it landed shows a little while.
const THROW_REACH: float = 8.0
const THROW_FLIGHT: float = 0.6
const LURE_MARK_S: float = 3.0


## Out the keys of the buildings with a locked door (P12), the things under
## the snow (card 11) and the note of the next stop (card 10), from the seed.
func _give_finds() -> void:
	if not bool(opts.get("loot_dress", true)):
		return
	for g: Dictionary in data.get("loose", []):
		ground_items.append(g.duplicate())
	glints = LootDress.glints(data, rng.seed)
	key_ways = LootDress.key_ways(grid.doors, rng.seed)
	var who := RandomNumberGenerator.new()
	who.seed = ("%d:finds:who" % rng.seed).hash()
	for b: int in key_ways:
		var key := FieldItems.key_for(b)
		var way: String = key_ways[b]
		if way == "dead":
			var inside: Array = []
			for z in zombies.list:
				if z["kind"] != "frozen" and grid_at(z["home"]).building_at(FieldGrid.cell_of(z["home"])) == b:
					inside.append(z)
			if inside.is_empty():
				way = "box"
			else:
				var holder: Dictionary = inside[who.randi_range(0, inside.size() - 1)]
				holder["carry"] = (holder.get("carry", []) as Array) + [key]
		if way == "snow":
			var at := _outside_door(b)
			if at.x < 0:
				way = "box"
			else:
				glints.append({"cell": at, "id": key})
		if way == "box":
			var boxes: Array = []
			for id: String in data["containers"]:
				var c: Dictionary = data["containers"][id]
				if int(c.get("building", -1)) == b and not bool(c.get("locked", false)) and not c.has("pick"):
					boxes.append(id)
			if boxes.is_empty():
				way = "none"
			else:
				(data["containers"][boxes[who.randi_range(0, boxes.size() - 1)]]["items"] as Array).append(key)
		key_ways[b] = way
	if who.randf() < LootDress.NOTE_CHANCE:
		var dead: Array = []
		for z in zombies.list:
			if z["kind"] != "frozen":
				dead.append(z)
		if not dead.is_empty():
			var holder: Dictionary = dead[who.randi_range(0, dead.size() - 1)]
			holder["carry"] = (holder.get("carry", []) as Array) + ["note_map"]
			note_spot = LootDress.NOTE_SPOTS[who.randi_range(0, LootDress.NOTE_SPOTS.size() - 1)]
	# A scrawled map to this stop's side path, on its own dice (card M).
	var carriers: Array = []
	for z in zombies.list:
		if z["kind"] != "frozen":
			carriers.append(z)
	SideNote.place(data, carriers, rng.seed)


## Who holds the scrawled map and whether anyone has reached the way in (card M).
func _read_side_note() -> void:
	if not data.has("side_path"):
		return
	var held := false
	var at := SideNote.way_in(data)
	for p in squad:
		if not p.is_alive():
			continue
		if p.items.has(SideNote.ID):
			held = true
		if not side_reached and at != Vector3.INF and Vector2(p.position.x - at.x, p.position.z - at.z).length() < SideNote.REACHED:
			side_reached = true
	side_hint = SideNote.hint(data, held, side_reached, SidePath.visited(data))


## A snow cell two steps out of a door of building b, or (-1, -1).
func _outside_door(b: int) -> Vector2i:
	for c: Vector2i in grid.doors:
		if int(grid.doors[c].get("building", -1)) != b:
			continue
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var o: Vector2i = c + d * 2
			if grid.inside(o) and grid.people_can_walk(o) and not grid.indoor(o):
				return o
	return Vector2i(-1, -1)


func glint_reach() -> float:
	var r := GLINT_REACH
	if clock.is_dark():
		r *= GLINT_DARK
	if weather.kinds.has("blizzard"):
		r *= GLINT_STORM
	return r


## What lies under the snow comes up where one of the squad walks close (a
## thing on the ground from then on, picked up as any).
func _reveal_glints() -> void:
	if glints.is_empty():
		return
	var reach := glint_reach()
	var keep: Array = []
	for g: Dictionary in glints:
		var at := lift(g["cell"], 0)
		var seen := false
		for p in squad:
			if p.is_alive() and level_of(p.position) == 0 and p.position.distance_to(at) <= reach:
				seen = true
				break
		if seen:
			ground_items.append({"pos": at, "id": String(g["id"]), "n": 1, "glint": true})
		else:
			keep.append(g)
	glints = keep


## Throw an empty tin where `p` faces (P22): it lands short of a wall and
## rattles there a moment later; the dead go to the sound.
func throw_lure(p, id: String) -> void:
	if p == null or not p.can_act() or p.action != "" or not FieldItems.throwable(id) or not p.take_item(id):
		return
	var lg := grid_at(p.position)
	var from := FieldGrid.cell_of(p.position)
	var fwd := Vector3(sin(p.facing), 0, cos(p.facing))
	var land: Vector3 = p.position
	var step := 0.5
	while step <= THROW_REACH:
		var at: Vector3 = p.position + fwd * step
		var c := FieldGrid.cell_of(at)
		if not lg.inside(c) or lg.blocks_body(c) or not lg.line_clear(from, c):
			break
		land = at
		step += 0.5
	lures.append({"pos": land, "at": clock.elapsed + THROW_FLIGHT, "who": p, "id": id})


func _land_lures() -> void:
	var now := clock.elapsed
	var keep: Array = []
	for l: Dictionary in lures:
		if now < float(l["at"]):
			keep.append(l)
			continue
		var who = l["who"]
		make_sound(l["pos"], SimNoise.Level.NORMAL, "lure", who if is_instance_valid(who) else null)
		ground_items.append({"pos": l["pos"], "id": String(l["id"]), "n": 1})
		lure_marks.append({"pos": l["pos"], "t": now})
	lures = keep
	var marks: Array = []
	for m: Dictionary in lure_marks:
		if now - float(m["t"]) < LURE_MARK_S:
			marks.append(m)
	lure_marks = marks


## On the receipt (decision 423): who saw the dead gone through, one row a
## searcher and only those who came back to tell it (card 12); and the note of
## the next stop as a document, when the stop knows which stop comes next and
## writes a stop receipt (card 10; opts "next_stop", "segment").
func _receipt_finds(boarded: Array) -> void:
	var back: Dictionary = {}
	for q in boarded:
		back[String(q.pid)] = true
	var by_who: Dictionary = {}
	for row: Dictionary in body_searches:
		var seen: Array = by_who.get(row["who"], [])
		for pid: String in row["seen"]:
			if back.has(pid) and not seen.has(pid):
				seen.append(pid)
		by_who[row["who"]] = seen
	for who: String in by_who:
		if not (by_who[who] as Array).is_empty():
			receipt.witness(who, "body_search", String(data["place_id"]), clock.label(), "searched_the_dead", by_who[who], "body_search")
	var next: String = String(opts.get("next_stop", ""))
	if int(unloaded.get("note_map", 0)) > 0 and note_spot != "" and next != "" and receipt.is_stop_receipt():
		var seg: int = int(opts.get("segment", 0))
		receipt.add_document({"id": "note_" + String(data["place_id"]), "sourcePlaceId": String(data["place_id"]), "segment": seg,
			"bodyKey": "note_stash", "choices": [], "targetId": null, "state": "pending", "kind": "next_stop",
			"nextStop": {"stopId": next, "observedSegment": seg, "blankKey": "stash", "confirmed": false}})


## What the note says, when it is read (card 10).
func note_line() -> String:
	if note_spot == "":
		return ""
	return "다음 역 %s에 상자를 숨겼다." % note_spot
