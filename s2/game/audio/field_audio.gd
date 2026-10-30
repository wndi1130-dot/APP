extends Node3D
## Graybox sound (sound_music 12.1): the least that makes a horde felt.
## Files are dropped into res://audio/<group>/ (CC0 only, rights_ledger);
## a missing group is simply silent, so the field runs with no files at all.
##   moan       single moans, the nearest few dead the player can see get
##              their own (max 6); farther ones are lower and duller
##              (MOAN_BANDS). Dead out of sight make no voice (user 2026-10-24)
##   horde_bed  one loop for the mass, louder with more and nearer dead in sight
##   birds      a flock taking off when a horde sets off; with it a far thud
##              (impact, low and dull). No far moans: the horde is told by
##              these, the radio and the screen's sound marks
##   impact     noisy actions (kick, glass, pry, lid, pickaxe); from
##              behind a wall they come through duller (SFX_MID)
##   swing_light, swing_heavy  a weapon coming round (or a shove), light
##              under 2 kg, heavy from it (hit_feel.gd)
##   hit_blunt, hit_blade, hit_stomp  a melee blow landing, by the weapon;
##              made here from noise and tones (rights_ledger), not recorded.
##              Heard only while the rules tell no blow of their own (below)
##   blow_*     a blow on one of the dead, as the rules tell it (combat
##              `struck`): by the weapon, what it hit and what came of it,
##              and the weapon's own state (blow, BLOW_FAMILY)
##   gun        shots (falls back to impact, lower)
##   step_snow  the player's footsteps
##   wind       outdoor bed, wandering, with gusts over it (WIND_DRIFT, _gust);
##              indoors heard through the building (openness_at, the WIND bus)
##   train_idle the waiting engine, placed on the train
##   whistle    departure
##   pen        the pen stroke when '떠난다' is pressed
##   radio_hiss the set hissing before the driver speaks (the dead do not hear it)
##   radio      the call itself, where the chief stands; an urgent one is louder
## While the depart note is up (sound_music 5): the horde bed holds low where
## it was, moans and steps only fade out, wind and the engine go on; '기다린다'
## comes back in 0.3 s; '떠난다' is impact, pen, a gap, then the whistle.
## Buses: Master and SFX. Indoor gunfire's deafness (field 8.2) ducks SFX.

const Motion = preload("res://game/sim/motion.gd")
const DeadPose = preload("res://game/actors/dead_pose.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const Atmosphere = preload("res://fx/atmosphere.gd")
const W = preload("res://game/sim/weapons.gd")
const Grid = preload("res://game/world/field_grid.gd")

const GROUPS: Array[String] = ["moan", "horde_bed", "birds", "impact", "gun", "step_snow", "wind", "train_idle", "whistle", "train_brake", "pen", "radio_hiss", "radio", "fall_hit", "fall_reel", "fall_knee", "fall_land", "door_bang", "door_wall", "door_break", "building_alarm", "swing_light", "swing_heavy", "hit_blunt", "hit_blade", "hit_stomp", "blow_cut", "blow_chop", "blow_thud", "blow_clang", "blow_wood", "blow_shove", "blow_stomp", "blow_head", "blow_finish", "blow_blocked", "blow_shatter", "blow_stuck", "blow_miss", "blow_ground", "blow_breaking"]
## One of the dead going down is heard in four beats, as it is drawn (the
## fall's own times: dead_pose, motion "dead_fall"). Only the player hears it:
## it is no sound of the rules. Each: group, loudness, lowest and highest pitch.
const FALL_BEATS: Array = [["fall_hit", 0.7, 0.92, 1.08], ["fall_reel", 0.4, 0.92, 1.08], ["fall_knee", 0.5, 0.92, 1.08], ["fall_land", 0.8, 0.9, 1.05]]
const FALL_REEL_AT: float = 0.05
const FALL_AFTER_BLOW: float = 0.03   # a hand weapon's own sound comes first
const FALL_GUN_HIT: float = 0.4       # shot down: the gun is the loud one
const FALL_GUN_WINDOW: float = 0.15
const FALL_RANGE: float = 40.0
const FALL_FAR: float = 25.0          # farther than this only the ground is heard
const FALL_AT_ONCE: int = 3           # this many falls are followed, the nearest
const FALL_SAME: float = 0.06         # one beat is not played twice within this
## The doors of a held train (field_holdout): group, loudness, pitch low and
## high. A blow is as loud as any knock of its level, times the number here;
## a wall going down and a door giving way have their own loudness.
const DOOR_VOICES: Dictionary = {
	"door": ["door_bang", 1.0, 0.9, 1.1],
	"low": ["door_bang", 1.0, 0.8, 0.95],        # a damaged door sounds lower
	"wall": ["door_bang", 0.8, 1.1, 1.25],       # thin planks
	"wall_down": ["door_wall", 0.9, 0.95, 1.05],
	"break": ["door_break", 1.0, 0.95, 1.05],
}
const DOOR_BLOWS: Array[String] = ["door", "low", "wall"]
## A building's door turned by a hand (field_actions _set_door), for the
## player's ear only: no rule hears it, so no make_sound tag and no noise.gd
## SOURCES row (as a box's opening and shutting). Group, loudness, pitch low
## and high, and the impact file that stands in until a file is in its group.
const DOOR_TURN: Dictionary = {
	"open": ["door_open", 0.45, 0.78, 0.86, "wooden"],
	"closed": ["door_close", 0.55, 0.66, 0.74, "wooden"],
}
## A key turned in a locked door (field_actions _key_opened, P12): a small
## click, then the door going quietly, softer than a door opened by hand, so
## the player does not take it for a noise the dead heard (they hear none).
## The click's group and stand-in as DOOR_TURN's; the door's loudness times
## DOOR_KEY_HUSH, DOOR_KEY_LAG s after the click. First values.
const DOOR_KEY: Array = ["door_unlock", 0.25, 1.6, 1.8, "metal"]
const DOOR_KEY_HUSH: float = 0.5
const DOOR_KEY_LAG: float = 0.18
## A building's window opened or shut, or its curtain drawn or opened, by
## someone (field_actions _set_window_open, _curtain_set): the player's ear
## only, as DOOR_TURN. Until a file is in its group the stand-in is the impact
## file whose name begins so, or with "@" a group of its own (a curtain: cloth
## swung through the air, low). First values.
const WINDOW_TURN: Dictionary = {
	"open": ["window_open", 0.3, 1.15, 1.3, "wooden"],
	"closed": ["window_close", 0.4, 1.02, 1.12, "wooden"],
	"curtain": ["curtain", 0.25, 0.7, 0.8, "@swing_light"],
}
## A door or a window that will not give to the player's hand, as the note
## says so (field_actions): a locked door rattles in its frame, a boarded one
## thuds against its planks. The player's ear only, as DOOR_TURN.
const SHUT_FAST: Dictionary = {
	"locked": ["door_locked", 0.4, 0.92, 1.02, "wooden"],
	"boarded": ["boarded", 0.4, 0.6, 0.7, "slam"],
}
## The same door (or window) for the same reason is heard again only after
## this many ms: a stick held against it asks every frame (field_game _drive).
const SHUT_FAST_GAP_MS: int = 800
## A bite on someone (hit_feel bitten): until its files are in, a blow's
## stand-in layer, its group and pitch low and high; the coat taking it
## (bite_blocked) is a duller thud.
const FEEL_STANDINS: Dictionary = {
	"bite": ["blow_cut", 0.78, 0.88],
	"bite_blocked": ["blow_thud", 1.05, 1.15],
}
## A manhole lid dragged aside by one of the dead coming up (decision 422 M9):
## group, loudness, pitch low and high. Until a file is in its group it is the
## impact set's iron, pitched down.
const LID_VOICE: Array = ["lid_scrape", 0.7, 0.55, 0.65]
const LID_STANDIN: String = "metal"    # the impact file that stands in for it
## A loose floorboard creaking underfoot (room_stories card K): group, loudness, pitch low
## and high. Until a file is in its group it is the impact set's wood, pitched well down.
const CREAK_VOICE: Array = ["floor_creak", 0.35, 0.45, 0.55]
const CREAK_STANDIN: String = "wooden"
## A step by the floor underfoot (FieldGrid.Floor: SNOW, ROAD, PLATFORM, WOOD,
## RAIL, DEEP_SNOW, ICE, GRAVEL): the groups to try in turn, loudness and pitch.
## Rails are on ballast; deep snow is the snow, lower and muffled (as the dead
## hear it, FieldGrid.FLOOR_SOUND). A group with
## no files yet falls to the next, and in the end to the snow there always was.
const STEP_FLOORS: Array = [
	[["step_snow"], 1.0, 1.0],
	[["step_concrete", "step_snow"], 1.0, 1.0],
	[["step_concrete", "step_snow"], 1.0, 1.0],
	[["step_wood", "step_snow"], 1.0, 1.0],
	[["step_gravel", "step_snow"], 1.1, 1.0],
	[["step_snow"], 0.8, 0.88],
	[["step_ice", "step_concrete", "step_snow"], 0.9, 1.08],
	[["step_gravel", "step_snow"], 1.0, 1.0],
]
## Glass on the floor crunching under a step: group, loudness, pitch low and
## high; until it has files, the impact set's glass, quiet and high.
const STEP_GLASS: Array = ["step_glass", 0.25, 1.2, 1.4]
const GLASS_STANDIN: String = "glass"
const STEPS_KEPT: int = 256            # steps remembered (tests); older ones go
## The dead in sight are heard walking, as they are heard speaking (결정 509,
## user 2026-10-24: only the dead the player can see; out of sight their feet
## are silent too): the nearest few of the voiced dead that move, by the floor under them,
## softer and lower than the player's own. Each step comes after a stride drawn
## new for it, and a shambling one now and then drags without a sound, so the
## feet keep no beat (user 2026-10-24: 「규칙적이니까 귀가피곤함」). A crawler
## makes no step. Heard only; nothing in the rules hears it.
const DEAD_STEP_RANGE: float = 12.0    # m: no step heard from farther (an ally's too)
const DEAD_STEPPERS: int = 3           # at most this many of the dead are heard stepping
const DEAD_STEP_JUMP: float = 2.0      # m in one tick: a jump (a stair, a spawn), not a walk
## An ally's step (squad or crew, field_game _footsteps) is the player's own,
## this much softer; a raider's or a stranger's feet stay unheard.
const COMPANY_STEP_LOUD: float = 0.7
const FEET_PLAYERS: int = 5            # players the steps of others than the player go out on
## By its gait: stride in m (low, high), loudness, the share of steps without a
## sound, and pitch (low, high; times its floor's) — never above the player's
## lowest (0.9), so the ear tells their feet from its own. First values.
const DEAD_GAITS: Dictionary = {
	"shamble": {"stride": [0.45, 0.8], "loud": 0.16, "skip": 0.3, "pitch": [0.72, 0.86]},
	"chase": {"stride": [0.6, 0.9], "loud": 0.22, "skip": 0.12, "pitch": [0.78, 0.88]},
	"dash": {"stride": [0.9, 1.3], "loud": 0.3, "skip": 0.0, "pitch": [0.82, 0.9]},
}
## The rasp of one of the dead that is about to run (lunger_rules): the group
## its file goes in, how loud, heard to this many metres, and the pitch of the
## moan that stands in for it. First values.
const TELL_GROUP: String = "lunge_tell"
const TELL_LOUD: float = 0.9
const FEEL_GROUP: String = "chief_feel_%02d"
const BRAKE_LOUD: float = 0.8
## Seconds into the brake file at which the train stands: its wheels' beat
## stopped, the squeal choked, the couplers running in
## (tools/sound/synth_stop_sounds.py STOP_AT).
const BRAKE_STAND_AT: float = 2.4
const FEEL_LOUD: float = 0.25
const TELL_RANGE: float = 40.0
const TELL_STANDIN_PITCH: float = 1.5
const DEPART_BEATS: Array = [["impact", 0.0], ["pen", 0.12], ["whistle", 0.75]]
const MOAN_SLOTS: int = 6
const MOAN_RANGE: float = 25.0
## How far a moan is, by ear (user 2026-10-11: far ones lower and duller).
## Each row: from this many metres on, the pitch is times this and the voice
## goes through this bus. The two far buses are SFX with a low-pass on them.
const MOAN_BANDS: Array = [[0.0, 1.0, "SFX"], [8.0, 0.9, "SFX_MID"], [16.0, 0.75, "SFX_FAR"]]
const DULL_BUSES: Dictionary = {"SFX_MID": 2400.0, "SFX_FAR": 900.0}   # low-pass cutoff, Hz
## Inside, the player hears the room (the reference's sound takes the room's
## size into its reverb): a sound made in the player's own room (room_of: its
## floor reached through open doors, within one building) goes through ROOM, a
## reverb sized by that floor (ROOM_AREA m², a closet to a hall), sent to SFX.
## Outdoors, and from behind a wall, there is no tail. Nothing in the rules hears it.
const ROOM_BUS: String = "ROOM"
const ROOM_DULL_BUS: String = "ROOM_MID"
const ROOM_AREA: Array = [9.0, 300.0]       # m² of floor: a closet .. a hall
const ROOM_SIZE: Array = [0.2, 0.7]         # the reverb's room_size, small .. large
const ROOM_DAMP: Array = [0.75, 0.4]
const ROOM_WET: Array = [0.1, 0.28]
const ROOM_PREDELAY: Array = [8.0, 35.0]    # ms
const ROOM_LOOK: int = 400                  # cells of floor counted at most
## Past the map's edge the danger is heard, not walled off: a few places past the
## woods (EdgeBand.build's sound_spots) keep a far, dull horde bed going, louder as
## the player walks toward the nearest, gone this far from it.
const EDGE_RANGE: float = 45.0
const EDGE_LOUD: float = 0.35
const EDGE_PITCH: float = 0.85
const BED_RANGE: float = 40.0
const BED_FULL: float = 12.0          # this much weighted crowd is a full bed
## A voice is given only to one of the dead in sight; one that has a voice
## keeps it this long after it was last seen, so a body at the edge of the
## sight cone is not cut off mid-moan every tenth of a second.
const VOICE_KEEP: float = 1.0
## The states that have no voice of their own (a fall has its own beats).
const MUTE_STATES: Array[String] = ["frozen", "downed", "dead", "rising", "waking"]
## How each of the dead sounds, decided once from the seed (its spawn's
## "phase"): one of three voices, low, middle and high, and the fresh ones a
## rough fourth. Each voice has its own files out of the eight (sorted by
## their measured pitch and brightness) and its own pitch; each body sits a
## little above or below its voice (VOICE_SPREAD).
const VOICES: Dictionary = {
	"low": {"pitch": 0.86, "files": ["moan_03", "moan_04", "moan_05"]},
	"mid": {"pitch": 1.0, "files": ["moan_02", "moan_05", "moan_07", "moan_08"]},
	"high": {"pitch": 1.12, "files": ["moan_01", "moan_02", "moan_06"]},
	"rough": {"pitch": 1.06, "files": ["moan_01", "moan_06", "moan_08"]},
}
const PLAIN_VOICES: Array[String] = ["low", "mid", "high"]
const VOICE_SPREAD: float = 0.04
## What one says by what it is doing: loudness, pitch (times its voice's), the
## gap before it speaks again (s, low and high) and how much of the file is
## heard (s; 0 = all of it). "notice" is the call as it starts after you, "hit"
## the grunt as a blow lands, "fall" the breath out as it goes down.
## A dead that eats has no state of its own yet (decision 423 (4)).
const SAYS: Dictionary = {
	"idle": {"loud": 0.55, "pitch": 0.96, "gap": [3.5, 8.0], "cut": 0.0},
	"chase": {"loud": 0.9, "pitch": 1.04, "gap": [1.4, 3.2], "cut": 0.0},
	"bite": {"loud": 1.0, "pitch": 1.15, "gap": [0.6, 1.3], "cut": 0.45},
	"notice": {"loud": 0.95, "pitch": 1.12, "gap": [1.0, 2.0], "cut": 0.55},
	"hit": {"loud": 0.85, "pitch": 0.92, "gap": [1.0, 2.2], "cut": 0.3},
	"fall": {"loud": 0.7, "pitch": 0.82, "gap": [0.0, 0.0], "cut": 0.5},
}
const STATE_SAYS: Dictionary = {"chase": "chase", "dash": "chase", "attack": "bite", "grab": "bite"}   # the rest: idle
const CUT_FADE: float = 400.0         # dB a second: a cut voice ends without a click
## A horde setting off: birds at most this often, and a far thud each time
## (an impact file this low, through the dullest bus).
const BIRDS_EVERY: float = 45.0
const FAR_THUD: Array = ["slam", 0.45, 0.42, 0.5]   # file prefix, loudness, pitch low and high
## From this near a sound is never behind a wall (the player's own).
const THROUGH_WALL_FROM: float = 1.5
## The wind never comes round the same way (user 2026-10-24: 「지금
## 규칙적이니까 귀가피곤함」). The bed's level and pitch wander on a slow
## noise (as the reference's wind intensity does) and it starts again each
## time at a new place in its file; over it come gusts at random gaps, each
## its own place in the file, length, loudness and pitch bend, never the
## shape just heard. A blizzard stop comes in with a howl of one to three
## gusts laid together, a new shape every time. Heard only; nothing hears it.
## Nor does a stop open the same way (user 2026-10-25: 「처음내릴떄 휘오오옹
## 하는거 스타트가 매번똑같은니까 귀가피곤함」): the bed comes up from nothing
## over its own length, its wandering starts at a random place (so its first
## loudness and pitch are new), and the first gust, or a blizzard's howl,
## waits its own few seconds after getting down.
## And it is not one wind (결정 434 1절: 「패턴 여러게 + 오프닝 달라지게」):
## beds of their own grain in audio/wind (wind_<name>; wind.ogg is "plain") and
## gusts in audio/wind_gust (gust_<name>; tools/sound/synth_wind.py). A stop
## takes a bed by what blows and the ground it blows over, never the bed the
## stop before had (pick_bed); gusts come from the gust files and the bed,
## never the same file twice running, a howl's layers each its own.
## Nor is a bed a loop (user 2026-10-28: 「지금 루프 형태라싸구려겜같음」): it is
## heard as pieces of uneven length cut from its file (and now and then from a
## kin bed that fits the same weather), each cross-fading into the next on a
## second player. A piece never starts inside the stretch just heard, nor where
## one of the last few started, and no two pieces follow each other the way two
## like them already did (repeats_in counts it: 0 over ten minutes).
## Near a building's corner, a tree or the gap between two wagons the wind is
## heard from that place too (SPOTS, audio/wind_spot), swelling with the gusts.
## Others follow the wind by gust_started and wind_now (snow, trees); this
## reads nothing back.
const WIND_IN: Array = [0.8, 3.0]     # s the bed takes to come up as the stop starts
const PIECE_LEN: Array = [4.0, 9.0]   # s of a bed heard as one piece, cross-fades included
const PIECE_XF: Array = [0.9, 2.0]    # s one piece takes to cross into the next
const PIECE_SAME: float = 1.0         # s: pieces of a file starting closer than this are the same piece
const PIECE_RECENT: int = 4           # nor where one of the last this many started
const PIECE_TRIES: int = 24
const KIN_SHARE: float = 0.3          # of pieces cut from the stop's kin beds
const KIN_BEDS: int = 2
const WIND_STOOD_S: float = 1.0       # s of real time with no tick: the field stood still
const FIRST_AFTER: Array = [2.0, 10.0]   # s after getting down to the first gust, or the howl
const WIND_PHASE: float = 1000.0      # the wandering starts somewhere in this much of its noise
const WIND_DRIFT_HZ: float = 0.07     # how fast the bed wanders
const WIND_DRIFT: float = 0.35        # this far below and above its level
const WIND_PITCH_DRIFT: float = 0.05
const GUST_GAP: Array = [4.0, 13.0]   # s between gusts at strength 0.5; stronger is closer
const GUST_LEN: Array = [1.6, 4.5]
const GUST_LOUD: Array = [0.35, 0.8]  # of the bed's level, at the gust's top
const GUST_PITCH: Array = [0.82, 1.22]   # where a gust starts and ends: its bend
const GUST_APART: float = 0.25        # of the file: a gust starts this far from the last one's place
const GUST_PITCH_APART: float = 0.06  # and its starting pitch more than this from the last one's
const GUST_GAP_APART: float = 0.15    # of the gap's range: no two gaps running this alike
const GUST_LOUD_APART: float = 0.08   # nor two gusts running this alike in strength
const HOWL_LAYERS: Array = [1, 3]
const HOWL_LEN: Array = [3.0, 6.5]
const GUSTS: int = 3                  # players for gusts (a howl lays up to three)
## The places the wind is heard from (audio/wind_spot/spot_<kind>): the nearest
## of each kind within SPOT_RANGE m, loudest from SPOT_FULL m in, at this share
## of the bed's level, and a gust swells it (SPOT_GUST). Under SPOT_MIN_WIND
## they keep still; inside, they are far off (SPOT_INDOOR).
const SPOTS: Dictionary = {"corner": 0.7, "tree": 0.55, "car": 0.6}
const SPOT_RANGE: float = 14.0
const SPOT_FULL: float = 3.0
const SPOT_GUST: float = 0.8
const SPOT_MIN_WIND: float = 0.3
const SPOT_INDOOR: float = 0.15
const SPOT_LOOK: float = 0.5          # s between looks for the nearest places
const SPOT_REREAD: float = 4.0        # s between readings of the map (the ring grows)
## Indoors the wind is heard through the building, not cut to a third at the
## door (user 2026-10-28: 「싸구려겜같음」; the reference's wind follows being
## inside and the nearest outside wall): loud and open in a doorway or by a
## broken window, lower and more muffled the more air there is between the
## player and the nearest opening (OPEN_REACH), a little nearer an outside wall
## (WALL_REACH, WALL_SHARE), and only a little in a cellar. Going in or out it
## follows over WIND_IN_TAU, never in one step. It goes through a bus of its own
## (WIND, sent to SFX) whose low-pass closes in with it (WIND_CUT).
const WIND_BUS: String = "WIND"
const OPEN_REACH: float = 7.0         # m of air from an opening to where its wind is gone
const WALL_REACH: float = 4.0         # m from an outside wall to where its wind is gone
const WALL_SHARE: float = 0.35        # what a wall lets through, of an opening's
const INDOOR_OPEN: float = 0.8        # openness in a doorway (outdoors 1, deep inside 0)
const INDOOR_LOW: float = 0.12        # the bed's level deep inside, of outdoors'
const CELLAR_SHARE: float = 0.3       # a cellar is this open, of the floor above
const WIND_IN_TAU: float = 0.18       # s: going in or out, the wind follows this fast
const WIND_CUT: Array = [450.0, 20000.0]   # Hz: the low-pass deep inside, outdoors
const EXPOSE_LOOK: int = 9            # cells of air searched for an opening
## A blow on one of the dead (user 2026-10-28: 「좀비 때릴때마다 … 사운드
## 이펙트가 있어야돼 / 무기마다 달라야되고 / 상태에 따라 달라져야돼」): the
## combat tells each (`struck`: weapon, target, result, edge) and it is heard
## in layers — the body hit by the weapon's kind, what came of it (a head
## giving, the end, a thick coat, ice), the ground under one that is down and a
## weapon about to give; a dull weapon is heard lower and duller. Each layer
## its own few files, never the same one twice running, pitch and loudness
## a little different each time. A melee weapon not in BLOW_FAMILY is an edge
## or a blunt one by its data; anything else shoves (a gun).
const BLOW_FAMILY: Dictionary = {"knife": "blow_cut", "broken_bottle": "blow_cut", "axe": "blow_chop", "crowbar": "blow_thud", "frying_pan": "blow_clang", "wood_stake": "blow_wood", "boot": "blow_stomp", "": "blow_shove"}
const BLOW_LAYER: Dictionary = {"head": "blow_head", "finish": "blow_finish", "blocked": "blow_blocked", "shatter": "blow_shatter", "stuck": "blow_stuck"}
## What the body hit is worth under a layer that takes over (a coat, ice).
const BLOW_UNDER: Dictionary = {"blocked": 0.35, "shatter": 0.5, "stuck": 0.4}
const BLOW_LOUD: float = 0.85         # as hit_feel's blow
const BLOW_REACH: float = 40.0
const BLOW_PITCH: Array = [0.94, 1.06]
const BLOW_GAIN: Array = [0.85, 1.0]
const BLOW_DULL_PITCH: float = 0.92   # a dull weapon, lower (and through the duller bus)
const BLOW_DOWN_PITCH: float = 0.94   # one that is down, lower
const BLOW_SAME_M: float = 2.0        # hit_* this near a blow in the same frame is that blow
## Melee blows ("melee", "fight") are not here: hit_feel.gd voices them by
## the weapon (a miss: the swing and a short breath of air, blow_miss, no
## hit_*), where any of these files would do.
const IMPACT_TAGS: Array[String] = ["kick", "glass", "pry", "bang", "lid", "salvage", "pickaxe", "fall", "impact", "ladder", "bell", "train_guard"]
## Sounds the dead hear that had none for the ear (on_sound: what the dead
## can hear, the player hears too): nails hammered in (boarding), a window's
## latch worked at, a can bashed open, a thrown lure coming down, a clock
## ringing in a pack, a bow loosed. Each: its own group once it has files,
## else a stand-in — the impact file whose name begins so, or with "@" a group
## of its own — pitch low and high, how many times and that far apart (s), and
## how much of a stand-in group's file is heard (s; 0 = all). First values.
## The hammer knocks for as long as that boarding goes on (_hammer).
const TAG_VOICES: Dictionary = {
	"hammer": ["hammer", "metal", 0.95, 1.1, 1, 0.0, 0.0],
	"latch": ["latch", "metal", 1.3, 1.45, 1, 0.0, 0.0],
	"can_bash": ["can_bash", "metal", 0.82, 0.92, 2, 0.22, 0.0],
	"lure": ["lure_land", "metal", 1.2, 1.4, 1, 0.0, 0.0],
	"alarm": ["alarm_clock", "@building_alarm", 1.45, 1.55, 1, 0.0, 1.2],
	"bow": ["bow_shot", "@swing_light", 1.2, 1.35, 1, 0.0, 0.0],
}
const HAMMER_GAP: Array = [0.42, 0.7]  # s between two knocks, low and high

static var last_bed: String = ""       # the bed the last stop had: the next takes another
var game
var lib: Dictionary = {}               # group -> Array[AudioStream]
var beds: Dictionary = {}              # wind bed name -> AudioStream
var gust_files: Dictionary = {}        # gust name -> AudioStream
var bed_name: String = ""              # this stop's bed
var bed_kin: Array = []                # beds that fit the same weather, a piece now and then
var bed_players: Array = []            # two AudioStreamPlayers, crossing one into the other
var piece: Dictionary = {}             # the piece in front: {"bed", "from", "len", "xf", "t", "player"}
var piece_out: Dictionary = {}         # the one going out under it
var bed_log: Array = []                # every piece [bed, from, len, xf] (tests, repeats_in)
var spot_players: Dictionary = {}      # spot kind -> AudioStreamPlayer3D
var spot_at: Dictionary = {}           # spot kind -> Array[Vector3] on the map
var spot_look_t: float = 0.0
var spot_read_t: float = 0.0
var gust_gaps: Array = []              # every gap between gusts (tests)
var blow_wired: bool = false           # the combat tells its blows (struck): hit_* stay quiet
var blow_last: Dictionary = {}         # blow group -> index of the file it played last
var blow_log: Array = []               # every layer played [group, file index] (tests)
var blow_mark: Array = [-1, Vector3.ZERO]          # frame and place of the last blow
var hit_mark: Array = [-1, Vector3.ZERO, null, 0]  # frame, place, player and its cut of the last hit_*
var hits_stopped: int = 0              # hit_* stopped for a blow told after them (tests)
var last_shot: AudioStreamPlayer3D     # the player the last one-shot went out on (null: none)
var wind_clock_ms: int = -1            # real time of the last wind tick (WIND_STOOD_S)
var openness: float = -1.0             # how open to the wind the player is, as heard (-1: not yet)
var expose_key: Array = []             # [level, cell, grid revision] it was last read at
var expose_last: float = 1.0
var wind_cut: float = 20000.0          # the WIND bus's low-pass now, Hz (tests)
var room_cells: Dictionary = {}        # the player's room: cell -> true (empty outdoors)
var room_key: Array = []               # [level, cell, grid revision] it was found at
var room_area: float = 0.0             # m² of it (tests)
var slots: Array = []                  # {"player": AudioStreamPlayer3D, "z": Dictionary, "wait": float}
var bed: AudioStreamPlayer
var edge_bed: AudioStreamPlayer        # the danger past the map's edge (_tick_edge)
var edge_spots: Array = []             # Vector3 places past the woods (map_view.edge_band)
var wind: AudioStreamPlayer
var engine: AudioStreamPlayer3D
var one_shots: Array = []
var birds_t: float = 0.0
var heard_t: float = 0.0               # the ear's own clock (VOICE_KEEP)
var seen_at: Dictionary = {}           # zombie id -> heard_t it was last in sight
var pick_t: float = 0.0
var crowd: float = 0.0                 # weighted dead near the player (for the bed)
var last_tag_group: String = ""        # what the last make_sound played (tests)
var tag_knocks: int = 0                # TAG_VOICES sounds played (tests)
var hammering: Dictionary = {}         # place (dm) -> the hammer's knock chain there (_hammer): one a place
var hammer_chains: int = 0             # knock chains begun, each its own number
var held: bool = false                 # the depart note is up
var departing: bool = false            # '떠난다' plays its own whistle
var played: Array = []                 # groups played, in order (tests)
var steps: Array = []                  # the player's steps heard [group, file] (tests)
var step_last: Dictionary = {}         # step group -> the file it played last
var feet: Array = []                   # AudioStreamPlayer3D the steps of others go out on
var feet_n: int = 0                    # those steps played (which of feet is next)
var feet_strides: int = 0              # strides the voiced dead have gone, heard or not (tests)
var dead_steps: Array = []             # the dead's steps heard [zombie id, group, file] (tests)
var dead_step_last: Dictionary = {}    # step group -> the file a dead's step played last
var company_steps: Array = []          # allies' steps heard [group, file] (tests)
var company_step_last: Dictionary = {} # step group -> the file an ally's step played last
var door_creaks: Array = []             # building doors beaten on: true when it was about to give (tests)
var shut_heard: Dictionary = {}        # "x,y,why" -> Time ms a door's no was last heard (SHUT_FAST_GAP_MS)

## The music steps aside for a sound that matters (the music frame's ducking
## connects here; nothing in the rules reads it). kind: "brake" (the train
## coming to a stand), "radio" (a call), "near" (a loud sound of the field
## near enough to hear); seconds: how long.
signal hush(kind: String, seconds: float)
## A gust (or a layer of a blizzard's howl) starts: peak 0..1 of the bed's
## level at its top, length in seconds. For the snow and the trees to gust
## with it (mood, openworld); nothing in the rules reads it.
signal gust_started(peak: float, length: float, howl_layer: bool)
var wind_level: float = 0.0            # wind_now()
const HUSH_BRAKE_S: float = 3.0
const HUSH_RADIO_S: float = 2.5
const HUSH_LOUD_S: float = 1.5
var last_bus: String = ""              # the bus the last one-shot went through (tests)
var said: Array = []                   # what the dead said, in order: [id, what, file] (tests)
var voices: Dictionary = {}            # zombie id -> {"kind", "pitch"}
var recent: Array[int] = []            # the last moan files heard, from anyone
var cut_n: int = 0
var drift := FastNoiseLite.new()       # the wind bed's wandering, a new seed each stop
var wind_t: float = 0.0
var gusts: Array = []                  # {"player", "t", "len", "peak", "p0", "p1", "top"}
var gust_t: float = 0.0                # s to the next gust
var gust_log: Array = []               # every gust's shape [at, len, peak, p0, p1, howl, file, wind_up] (tests)
var howled: bool = false
var wind_in: float = 1.0               # this stop's coming up (WIND_IN)
var wind_up: float = 0.0               # s the wind has been heard this stop
var howl_wait: float = 0.0             # s after the train stands before a blizzard howls
var quiet: bool = false                # the caller voices this sound itself
var falls: Array = []                  # falls being followed: {"z", "i": next beat, "gun"}
var fall_heard: Dictionary = {}        # zombie id -> the fall of its that was taken up
var fall_last: Dictionary = {}         # group -> field time it last played


func setup(field_game) -> void:
	game = field_game
	_ensure_bus()
	_ensure_wind_bus()
	_ensure_room_bus()
	for g in GROUPS:
		lib[g] = _load_group(g)
	for i in range(MOAN_SLOTS):
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		add_child(p)
		slots.append({"player": p, "z": {}, "wait": randf_range(0.5, 3.0)})
	for row: Array in STEP_FLOORS:
		for step_group: String in row[0]:
			if not lib.has(step_group):
				lib[step_group] = _load_group(step_group)
	bed = _loop_player("horde_bed")
	edge_bed = _loop_player("horde_bed")
	edge_bed.bus = "SFX_FAR" if AudioServer.get_bus_index("SFX_FAR") >= 0 else "SFX"
	edge_bed.pitch_scale = EDGE_PITCH
	# This stop's wind: one bed of many, never the last stop's.
	beds = _load_named("wind", "wind")
	gust_files = _load_named("wind_gust", "gust")
	bed_name = pick_bed(beds.keys(), game.weather.kinds, wind_strength(), _open_ground(), last_bed, randf())
	last_bed = bed_name
	bed_kin = kin_beds(beds.keys(), bed_name, game.weather.kinds, wind_strength(), _open_ground())
	for i in range(2):
		var b := AudioStreamPlayer.new()
		b.bus = WIND_BUS
		b.volume_db = -80.0
		add_child(b)
		bed_players.append(b)
	wind = bed_players[0]
	if bed_name != "":
		_next_piece()
	for kind in SPOTS:
		var s := AudioStreamPlayer3D.new()
		s.bus = WIND_BUS
		s.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		s.volume_db = -80.0
		add_child(s)
		var file: AudioStream = load("res://audio/wind_spot/spot_%s.wav" % kind) if ResourceLoader.exists("res://audio/wind_spot/spot_%s.wav" % kind) else null
		if file != null:
			s.stream = file
			# Round again from a new place each time: no beat to it.
			s.finished.connect(func() -> void: s.play(randf() * file.get_length()))
			s.play(randf() * file.get_length())
		spot_players[kind] = s
	drift.seed = randi()
	drift.frequency = WIND_DRIFT_HZ
	# The noise is level at its start: begin somewhere along it instead.
	wind_t = randf_range(0.0, WIND_PHASE)
	wind_in = randf_range(float(WIND_IN[0]), float(WIND_IN[1]))
	howl_wait = randf_range(float(FIRST_AFTER[0]), float(FIRST_AFTER[1]))
	for i in range(GUSTS):
		var g := AudioStreamPlayer.new()
		g.bus = WIND_BUS
		g.volume_db = -80.0
		add_child(g)
		gusts.append({"player": g, "t": 0.0, "len": 0.0})
	gust_t = randf_range(float(FIRST_AFTER[0]), float(FIRST_AFTER[1]))
	var combat = game.get("combat")
	if combat != null and combat.has_signal("struck"):
		combat.struck.connect(blow)
		blow_wired = true
	engine = AudioStreamPlayer3D.new()
	engine.bus = "SFX"
	engine.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	add_child(engine)
	engine.position = game.FieldGrid.center(game.data["anchors"]["engine"])
	if has("train_idle"):
		engine.stream = lib["train_idle"][0]
		engine.finished.connect(engine.play)
		engine.play()
	# Blows come quick and with their swings: room for a few at once.
	for i in range(10):
		var o := AudioStreamPlayer3D.new()
		o.bus = "SFX"
		o.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		add_child(o)
		one_shots.append(o)
	# Others' feet have players of their own: a step never cuts a blow short.
	for i in range(FEET_PLAYERS):
		var f := AudioStreamPlayer3D.new()
		f.bus = "SFX"
		f.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		add_child(f)
		feet.append(f)


func has(group: String) -> bool:
	return not (lib.get(group, []) as Array).is_empty()


static func _ensure_bus() -> void:
	if AudioServer.get_bus_index("SFX") >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "SFX")
	AudioServer.set_bus_send(i, "Master")
	for dull in DULL_BUSES:
		AudioServer.add_bus()
		var d := AudioServer.bus_count - 1
		AudioServer.set_bus_name(d, dull)
		AudioServer.set_bus_send(d, "SFX")
		var low := AudioEffectLowPassFilter.new()
		low.cutoff_hz = float(DULL_BUSES[dull])
		AudioServer.add_bus_effect(d, low)


## The wind's own bus: sent to SFX (so it ducks with the rest), a low-pass on it
## that openness moves (_set_wind_cut).
static func _ensure_wind_bus() -> void:
	if AudioServer.get_bus_index(WIND_BUS) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, WIND_BUS)
	AudioServer.set_bus_send(i, "SFX")
	var low := AudioEffectLowPassFilter.new()
	low.cutoff_hz = float(WIND_CUT[1])
	AudioServer.add_bus_effect(i, low)


## The room's bus: a reverb (set to the player's room by _tick_room), sent to SFX;
## and ROOM_MID, as dull as SFX_MID and sent into the room (a dull weapon's own
## hit in the player's room: duller, and still the room's).
static func _ensure_room_bus() -> void:
	if AudioServer.get_bus_index(ROOM_BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, ROOM_BUS)
		AudioServer.set_bus_send(i, "SFX")
		var verb := AudioEffectReverb.new()
		verb.dry = 1.0
		verb.spread = 0.8
		verb.hipass = 0.25   # no boom from the low end, which a phone cannot play anyway
		AudioServer.add_bus_effect(i, verb)
	if AudioServer.get_bus_index(ROOM_DULL_BUS) < 0:
		AudioServer.add_bus()
		var d := AudioServer.bus_count - 1
		AudioServer.set_bus_name(d, ROOM_DULL_BUS)
		AudioServer.set_bus_send(d, ROOM_BUS)
		var low := AudioEffectLowPassFilter.new()
		low.cutoff_hz = float(DULL_BUSES["SFX_MID"])
		AudioServer.add_bus_effect(d, low)


## The player's room from indoor cell c: the floor of the same building the air
## goes through (air_passes: open doors join rooms), up to ROOM_LOOK cells.
static func room_of(g, c: Vector2i) -> Dictionary:
	var b: int = g.building_at(c)
	var cells: Dictionary = {c: true}
	if b < 0:
		return {}
	var front: Array[Vector2i] = [c]
	while not front.is_empty() and cells.size() < ROOM_LOOK:
		var next: Array[Vector2i] = []
		for p: Vector2i in front:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if cells.has(q) or not g.inside(q) or g.building_at(q) != b or not air_passes(g, q):
					continue
				cells[q] = true
				next.append(q)
		front = next
	return cells


## The reverb for a room of `area` m² of floor: room_size, damping, wet and
## predelay (ms), from a closet's to a hall's by the floor's log.
static func room_reverb(area: float) -> Dictionary:
	var k: float = clampf(log(maxf(area, 1.0) / float(ROOM_AREA[0])) / log(float(ROOM_AREA[1]) / float(ROOM_AREA[0])), 0.0, 1.0)
	return {"size": lerpf(float(ROOM_SIZE[0]), float(ROOM_SIZE[1]), k), "damp": lerpf(float(ROOM_DAMP[0]), float(ROOM_DAMP[1]), k),
		"wet": lerpf(float(ROOM_WET[0]), float(ROOM_WET[1]), k), "predelay": lerpf(float(ROOM_PREDELAY[0]), float(ROOM_PREDELAY[1]), k)}


## Find the player's room again when the cell, the floor or a door changes, and
## set the ROOM bus's reverb to it.
func _tick_room(at: Vector3) -> void:
	var g = game.grid_at(at)
	var cell: Vector2i = game.FieldGrid.cell_of(at)
	var key: Array = [game.level_of(at), cell, g.revision]
	if key == room_key:
		return
	if not room_key.is_empty() and room_cells.has(cell) and key[0] == room_key[0] and key[2] == room_key[2]:
		room_key = key   # a step within the same room
		return
	room_key = key
	room_cells = room_of(g, cell) if g.indoor(cell) else {}
	room_area = float(room_cells.size())
	var i := AudioServer.get_bus_index(ROOM_BUS)
	if room_cells.is_empty() or i < 0 or AudioServer.get_bus_effect_count(i) == 0:
		return
	var verb := AudioServer.get_bus_effect(i, 0) as AudioEffectReverb
	if verb == null:
		return
	var r: Dictionary = room_reverb(room_area)
	verb.room_size = float(r["size"])
	verb.damping = float(r["damp"])
	verb.wet = float(r["wet"])
	verb.predelay_msec = float(r["predelay"])


## A sound from `at` is in the player's room: on its floor or at its edge (a
## piece of furniture, a shut door or window of it — cells the air does not
## pass, so not in room_cells, but a room's own sounds).
func in_room(at: Vector3) -> bool:
	if room_cells.is_empty() or game.level_of(at) != int(room_key[0]):
		return false
	var c: Vector2i = game.FieldGrid.cell_of(at)
	if room_cells.has(c):
		return true
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if room_cells.has(c + d):
			return true
	return false


## The band a moan this far away is heard in: [from, pitch, bus].
static func moan_band(d: float) -> Array:
	var band: Array = MOAN_BANDS[0]
	for b in MOAN_BANDS:
		if d >= float(b[0]):
			band = b
	return band


## How well a bed fits what blows (a blizzard, a hard or a light wind) and the
## ground it blows over (open, or trees and walls to blow through); 0: not at all.
## The old short file ("plain", wind.ogg, 6.6 s) is no bed while there are
## others: too short to cut pieces from, it is the loop that was heard.
static func bed_weight(name: String, kinds: Array, strength: float, open_ground: bool) -> float:
	var storm := kinds.has("blizzard")
	match name:
		"plain":
			return 0.0
		"blizzard":
			return 6.0 if storm else 0.0
		"gusty":
			return 1.0 + 3.0 * strength + (2.0 if storm else 0.0)
		"breeze":
			return 0.0 if storm else 3.0 * (1.0 - strength)
		"low":
			return 1.5 + (1.0 if open_ground else 0.0) + (1.5 if storm else 0.0)
		"whistle":
			return 1.2 + (0.0 if open_ground else 1.0)
		"forest":
			return 0.3 if storm else (0.6 if open_ground else 2.0)
	return 1.2


## The stop's kin beds: KIN_BEDS other fitting ones, drawn by how well they fit,
## that a piece is now and then cut from, so the bed is not one file over and over.
static func kin_beds(names: Array, own: String, kinds: Array, strength: float, open_ground: bool) -> Array:
	var rows: Array = []
	for n in names:
		var w := bed_weight(String(n), kinds, strength, open_ground)
		if String(n) != own and w >= 1.0:
			rows.append([pow(randf(), 1.0 / w), String(n)])   # a draw weighted by w
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var out: Array = []
	for r in rows.slice(0, KIN_BEDS):
		out.append(r[1])
	return out


## A group's files by name: "<prefix>_<name>.<ext>" is <name>, the bare
## "<prefix>.<ext>" is "plain".
func _load_named(group: String, prefix: String) -> Dictionary:
	var out: Dictionary = {}
	var dir := "res://audio/" + group
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in ResourceLoader.list_directory(dir):
		var file := String(f)
		if not (file.ends_with(".ogg") or file.ends_with(".wav") or file.ends_with(".mp3")):
			continue
		var s = load(dir + "/" + file)
		if not s is AudioStream:
			continue
		var base := file.get_basename()
		out["plain" if base == prefix else base.trim_prefix(prefix + "_")] = s
	return out


## Which bed a stop takes (roll in [0, 1)): each by what blows (a blizzard, a
## hard or a light wind) and the ground it blows over (open, or trees and
## walls to blow through), never `last` while there is another.
static func pick_bed(names: Array, kinds: Array, strength: float, open_ground: bool, last: String, roll: float) -> String:
	var weights: Array = []
	var total := 0.0
	for n in names:
		var w := bed_weight(String(n), kinds, strength, open_ground)
		if String(n) == last and names.size() > 1:
			w = 0.0
		weights.append(w)
		total += w
	if names.is_empty():
		return ""
	if total <= 0.0:
		for n in names:
			if String(n) != last:
				return String(n)
		return String(names[0])
	var at := clampf(roll, 0.0, 0.999999) * total
	for i in names.size():
		at -= float(weights[i])
		if at < 0.0:
			return String(names[i])
	return String(names[names.size() - 1])


## The stop's ground is open (the region's open steppe) rather than among trees and walls.
func _open_ground() -> bool:
	var region: Variant = game.get("region")
	return region != null and bool(Atmosphere.region(String(region)).get("open", false))


func _load_group(group: String) -> Array:
	var out: Array = []
	var dir := "res://audio/" + group
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in ResourceLoader.list_directory(dir):
		var name := String(f)
		if name.ends_with(".ogg") or name.ends_with(".wav") or name.ends_with(".mp3"):
			var s = load(dir + "/" + name)
			if s is AudioStream:
				out.append(s)
	return out


func _loop_player(group: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.volume_db = -80.0
	add_child(p)
	if has(group):
		p.stream = lib[group][0]
		p.finished.connect(p.play)
		p.play()
	return p


func _pick(group: String) -> AudioStream:
	var list: Array = lib.get(group, [])
	return null if list.is_empty() else list[randi() % list.size()]


static func _db(lin: float) -> float:
	return -80.0 if lin <= 0.001 else linear_to_db(lin)


# ---------------------------------------------------------------- per frame

func tick(delta: float) -> void:
	if game == null or game.player == null:
		return
	var at: Vector3 = game.player.position
	if game.ended:
		for p in [bed, edge_bed] + bed_players + spot_players.values():
			p.volume_db = -80.0
		for g: Dictionary in gusts:
			(g["player"] as AudioStreamPlayer).volume_db = -80.0
		return
	_tick_room(at)
	if held:
		# The note is up: the bed stays where it was, lower; nothing new starts.
		for s in slots:
			var p: AudioStreamPlayer3D = s["player"]
			p.volume_db = maxf(-80.0, p.volume_db - 40.0 * delta)
		_tick_wind(at, delta)   # the wind goes on (it is not the field's time)
		return
	heard_t += delta
	pick_t -= delta
	if pick_t <= 0.0:
		pick_t = 0.4
		_assign_moans(at)
	for s in slots:
		_move_feet(s)   # all of them first: who walks is known alike when each steps
	for s in slots:
		_tick_slot(s, at, delta)
	_tick_falls(at)
	# The mass: one bed scaled by how many dead are near and how near.
	bed.volume_db = lerpf(bed.volume_db, _db(clampf(crowd / BED_FULL, 0.0, 1.0) * 0.8), minf(1.0, delta * 2.0))
	_tick_edge(at, delta)
	birds_t = maxf(0.0, birds_t - delta)
	_tick_wind(at, delta)
	engine.volume_db = _db(clampf(1.0 - at.distance_to(engine.position) / 70.0, 0.0, 1.0) * 0.5)
	# Indoor gunfire leaves the ears ringing: everything else ducks.
	var bus := AudioServer.get_bus_index("SFX")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, -18.0 if game.deaf_t > 0.0 else 0.0)


## The edge bed, by the nearest place past the edge (EDGE_RANGE). The places come
## with the map's drawing, so they are read the first time there are any.
func _tick_edge(at: Vector3, delta: float) -> void:
	if edge_spots.is_empty() and game.view != null:
		edge_spots = game.view.edge_band.get("sound_spots", [])
	var near := INF
	for s: Vector3 in edge_spots:
		near = minf(near, Vector2(s.x - at.x, s.z - at.z).length())
	var want := _db(clampf(1.0 - near / EDGE_RANGE, 0.0, 1.0) * EDGE_LOUD)
	edge_bed.volume_db = lerpf(edge_bed.volume_db, want, minf(1.0, delta * 2.0))


## Can the player see this spot as one of the dead is drawn there? The same
## three tests zombies.render draws by: the sight mask, the floors shown and
## the camera's frame.
func in_view(at: Vector3) -> bool:
	if not game.cell_seen(at) or not game.level_shown(game.level_of(at)):
		return false
	return game.camera == null or game.camera.is_position_in_frustum(at + Vector3(0, 0.6, 0))


## A sound with a wall (or a floor) between it and the player comes through
## duller. Not a rule: the dead hear it as they always did.
func through_wall(at: Vector3) -> bool:
	return at.distance_to(game.player.position) > THROUGH_WALL_FROM and not game.sight_clear(game.player.position, at)


## The nearest moving dead in sight get a voice of their own; the bed is the
## crowd in sight. Dead out of sight are silent here (their knocks and falls
## are heard as they are, duller through a wall).
func _assign_moans(at: Vector3) -> void:
	var near: Array = []
	var voiced: Dictionary = {}
	for s in slots:
		if not s["z"].is_empty():
			voiced[s["z"]["id"]] = true
	crowd = 0.0
	for z in game.zombies.list:
		if not game.zombies.threat(z) or MUTE_STATES.has(z["state"]):
			continue
		var d: float = z["pos"].distance_to(at)
		if d >= BED_RANGE:
			continue
		var id: int = z["id"]
		if in_view(z["pos"]):
			seen_at[id] = heard_t
			crowd += 1.0 - d / BED_RANGE
		elif not (voiced.has(id) and heard_t - float(seen_at.get(id, -INF)) < VOICE_KEEP):
			continue
		if d < MOAN_RANGE:
			near.append([d, z])
	if seen_at.size() > 400:
		seen_at.clear()
	near.sort_custom(func(a, b): return a[0] < b[0])
	var keep: Array = []
	for i in range(mini(MOAN_SLOTS, near.size())):
		keep.append(near[i][1])
	# Slots already on one of the kept dead stay; the rest take the newcomers.
	var free: Array = []
	for s in slots:
		if keep.has(s["z"]):
			keep.erase(s["z"])
		else:
			s["z"] = {}
			free.append(s)
	for z in keep:
		if free.is_empty():
			break
		var s: Dictionary = free.pop_back()
		s["z"] = z
		s["was"] = ""
		s["stun"] = float(z.get("stun", 0.0))
		# Its feet start where it is, part way through a stride.
		s["feet_at"] = z["pos"]
		s["feet_left"] = randf_range(0.0, float(DEAD_GAITS["shamble"]["stride"][1]))
		s["feet_moving"] = false


## The voice of one of the dead: its kind and its own pitch, the same every
## time it is heard and every time the stop is played with this seed.
func voice_of(z: Dictionary) -> Dictionary:
	var id: int = int(z["id"])
	if voices.has(id):
		return voices[id]
	var u: float = float(z.get("phase", 0.0))
	var kind: String = "rough" if z["kind"] == "fresh" else PLAIN_VOICES[int(u * 3.0) % 3]
	var spread: float = (fposmod(u * 7.31, 1.0) * 2.0 - 1.0) * VOICE_SPREAD
	voices[id] = {"kind": kind, "pitch": float(VOICES[kind]["pitch"]) * (1.0 + spread)}
	if voices.size() > 400:
		voices.clear()
	return voices[id]


## What its state has it say: idle, chase or bite.
static func says_for(state: String) -> String:
	return String(STATE_SAYS.get(state, "idle"))


## The files (indices into the moan set) a voice speaks with; all of them when
## none of its own are in (a test's single tone).
func files_of(kind: String) -> Array[int]:
	var out: Array[int] = []
	var list: Array = lib.get("moan", [])
	var own: Array = VOICES[kind]["files"]
	for i in range(list.size()):
		var name: String = (list[i] as AudioStream).resource_path.get_file()
		for f in own:
			if name.begins_with(String(f)):
				out.append(i)
				break
	if out.is_empty():
		for i in range(list.size()):
			out.append(i)
	return out


## The next file for a voice: not the one it said last, nor one just heard
## from anyone else, while it has others to choose from.
func _next_file(kind: String, last: int) -> int:
	var own := files_of(kind)
	var just: int = recent.back() if not recent.is_empty() else -1
	var fresh: Array[int] = []
	for avoid in [recent, [just], []]:
		for i in own:
			if i != last and not (avoid as Array).has(i):
				fresh.append(i)
		if not fresh.is_empty():
			break
	if fresh.is_empty():
		fresh = own
	var pick: int = fresh[randi() % fresh.size()]
	recent.append(pick)
	while recent.size() > 2:
		recent.pop_front()
	return pick


## One of the dead says something through its slot.
func _say(s: Dictionary, z: Dictionary, what: String, d: float) -> void:
	var row: Dictionary = SAYS[what]
	var v := voice_of(z)
	var p: AudioStreamPlayer3D = s["player"]
	var band: Array = moan_band(d)
	var i := _next_file(String(v["kind"]), int(s.get("file", -1)))
	s["file"] = i
	s["loud"] = float(row["loud"])
	s["cut"] = float(row["cut"])
	s["wait"] = randf_range(float(row["gap"][0]), float(row["gap"][1]))
	p.stream = lib["moan"][i]
	p.pitch_scale = float(v["pitch"]) * float(row["pitch"]) * float(band[1]) * randf_range(0.97, 1.03)
	p.bus = ROOM_BUS if String(band[2]) == "SFX" and in_room(z["pos"]) else String(band[2])
	p.volume_db = _db(clampf(1.0 - d / MOAN_RANGE, 0.0, 1.0) * float(s["loud"]))
	p.play()
	said.append([int(z["id"]), what, i])


func _tick_slot(s: Dictionary, at: Vector3, delta: float) -> void:
	var z: Dictionary = s["z"]
	var p: AudioStreamPlayer3D = s["player"]
	if z.is_empty():
		# Its body went out of sight: what it was saying fades, nothing new.
		if p.playing:
			p.volume_db = maxf(-80.0, p.volume_db - 60.0 * delta)
		return
	p.position = z["pos"]
	var d: float = z["pos"].distance_to(at)
	_tick_feet(s, z, d)
	var row := says_for(String(z["state"]))
	# A short call (a bite, a grunt) ends after its length, fading out fast.
	if float(s.get("cut", 0.0)) > 0.0:
		s["cut"] = float(s["cut"]) - delta
		if float(s["cut"]) <= 0.0:
			s["fading"] = true
	if bool(s.get("fading", false)):
		p.volume_db = maxf(-80.0, p.volume_db - CUT_FADE * delta)
		if p.volume_db <= -79.0 or not p.playing:
			p.stop()
			s["fading"] = false
	else:
		p.volume_db = _db(clampf(1.0 - d / MOAN_RANGE, 0.0, 1.0) * float(s.get("loud", SAYS[row]["loud"])))
	# What makes it speak at once: a blow landing, or its starting after you.
	var cue := ""
	if float(z.get("stun", 0.0)) > float(s.get("stun", 0.0)) + 0.05:
		cue = "hit"
	elif row != "idle" and String(s.get("was", "")) == "idle":
		cue = "notice"
	s["was"] = row
	s["stun"] = float(z.get("stun", 0.0))
	s["wait"] = float(s["wait"]) - delta
	if not has("moan") or z["state"] == "tell":
		return   # about to run: its own rasp is heard (lunge_tell)
	if cue != "" or float(s["wait"]) <= 0.0:
		s["fading"] = false
		_say(s, z, cue if cue != "" else row, d)


## One of the dead in sight goes down: a short breath out in its own voice,
## under the fall's beats. Not through a slot (the slot lets go of it).
func _fall_voice(z: Dictionary, at: Vector3) -> void:
	if not has("moan") or not in_view(z["pos"]):
		return
	var row: Dictionary = SAYS["fall"]
	var v := voice_of(z)
	var d: float = at.distance_to(z["pos"])
	var i := _next_file(String(v["kind"]), -1)
	var band: Array = moan_band(d)
	said.append([int(z["id"]), "fall", i])
	var bus: String = ROOM_BUS if String(band[2]) == "SFX" and in_room(z["pos"]) else String(band[2])
	_one_shot("moan", z["pos"], float(row["loud"]) * clampf(1.0 - d / MOAN_RANGE, 0.0, 1.0), float(v["pitch"]) * float(row["pitch"]) * float(band[1]), lib["moan"][i], bus, float(row["cut"]))


# ---------------------------------------------------------------- wind

## How hard the wind blows for the ear, 0..1: the weather's wind, and a
## blizzard is a storm whatever its number.
func wind_strength() -> float:
	var w: float = float(game.weather.wind)
	if game.weather.kinds.has("blizzard"):
		w = maxf(w, 0.9)
	return clampf(w, 0.0, 1.0)


## Seconds between gusts at this strength (low, high): stronger, closer.
static func gust_gap(strength: float) -> Vector2:
	var k := 1.0 / (0.5 + clampf(strength, 0.0, 1.0))
	return Vector2(float(GUST_GAP[0]) * k, float(GUST_GAP[1]) * k)


## Two pieces are the same piece: one file, starting within PIECE_SAME.
static func same_piece(a: Array, b: Array) -> bool:
	return not a.is_empty() and not b.is_empty() and a[0] == b[0] and absf(float(a[1]) - float(b[1])) < PIECE_SAME


## The stretch of its file a piece is heard over (its pitch wanders up to
## WIND_PITCH_DRIFT, so a little more than its length).
static func piece_span(p: Array) -> Vector2:
	return Vector2(float(p[1]), float(p[1]) + float(p[2]) * (1.0 + WIND_PITCH_DRIFT))


## How many times two pieces follow each other the way two like them already
## did: the bed going round in the same order (user 2026-10-28). Each such seam
## counts once.
static func repeats_in(pieces: Array) -> int:
	var n := 0
	for j in range(1, pieces.size() - 1):
		for i in range(j):
			if same_piece(pieces[i], pieces[j]) and same_piece(pieces[i + 1], pieces[j + 1]):
				n += 1
				break
	return n


## The next piece after `pieces` ([bed, from, len, xf] each), cut from
## `own` or now and then (KIN_SHARE) from one of `kin`; `lengths` is each bed's
## file length. Of its own length and cross-fade; never what followed a piece
## like the one in front before (repeats_in), not inside the stretch of either
## of the last two (no going back over what was just heard), and if it can be,
## not where one of the last PIECE_RECENT started.
static func pick_piece(pieces: Array, lengths: Dictionary, own: String, kin: Array) -> Array:
	if not lengths.has(own):
		return []
	var kins: Array = kin.filter(func(k) -> bool: return lengths.has(k))
	var now: Array = pieces.back() if not pieces.is_empty() else []
	var before: Array = pieces[pieces.size() - 2] if pieces.size() > 1 else []
	var followed: Array = []
	if not now.is_empty():
		for i in range(pieces.size() - 1):
			if same_piece(pieces[i], now):
				followed.append(pieces[i + 1])
	var recent: Array = pieces.slice(maxi(0, pieces.size() - PIECE_RECENT))
	var best: Array = []
	var best_bad := 1 << 30
	for t in range(PIECE_TRIES):
		var pick: String = own
		if not kins.is_empty() and randf() < KIN_SHARE:
			pick = String(kins[randi() % kins.size()])
		var full: float = float(lengths[pick])
		var length: float = minf(randf_range(float(PIECE_LEN[0]), float(PIECE_LEN[1])), full / (1.0 + WIND_PITCH_DRIFT))
		var from: float = randf_range(0.0, maxf(0.0, full - length * (1.0 + WIND_PITCH_DRIFT)))
		var c: Array = [pick, from, length, minf(randf_range(float(PIECE_XF[0]), float(PIECE_XF[1])), length * 0.45)]
		var bad := 0
		for f in followed:
			if same_piece(f, c):
				bad += 1000
		for r in [now, before]:
			if not r.is_empty() and r[0] == pick:
				var a := piece_span(r)
				var b := piece_span(c)
				if b.x < a.y and a.x < b.y:
					bad += 100
		for r in recent:
			if same_piece(r, c):
				bad += 1
		if bad < best_bad:
			best = c
			best_bad = bad
		if bad == 0:
			break
	return best


## The next piece of the bed comes in on the other player, crossing over the
## one in front as long as that one's own cross-fade.
func _next_piece() -> void:
	var lengths: Dictionary = {}
	for b in beds:
		lengths[b] = (beds[b] as AudioStream).get_length()
	var c: Array = pick_piece(bed_log, lengths, bed_name, bed_kin)
	if c.is_empty():
		return
	var player: AudioStreamPlayer = bed_players[1] if not piece.is_empty() and piece["player"] == bed_players[0] else bed_players[0]
	piece_out = piece
	piece = {"bed": c[0], "from": c[1], "len": c[2], "xf": c[3], "t": 0.0, "player": player,
		"in": float(piece_out["xf"]) if not piece_out.is_empty() else 0.0}
	player.stream = beds[c[0]]
	player.volume_db = -80.0
	player.play(float(c[1]))
	wind = player
	bed_log.append(c)


## The bed this frame at `lin` (its level with its wandering): the piece in
## front rising over the one going out, equal in power as they cross.
## stood: the field stood still a while (the resume screen does not tick the
## ear) while the players went on, so the piece in front may have run out of
## its file: the next one comes at once, not seconds of silence after.
func _tick_pieces(lin: float, pitch: float, delta: float, stood: bool = false) -> void:
	if piece.is_empty():
		return
	piece["t"] = float(piece["t"]) + delta
	if stood or float(piece["t"]) >= float(piece["len"]) - float(piece["xf"]):
		_next_piece()
	var p: AudioStreamPlayer = piece["player"]
	var k_in: float = 1.0 if float(piece["in"]) <= 0.0 else clampf(float(piece["t"]) / float(piece["in"]), 0.0, 1.0)
	p.volume_db = _db(lin * sin(0.5 * PI * k_in))
	p.pitch_scale = pitch
	if piece_out.is_empty():
		return
	piece_out["t"] = float(piece_out["t"]) + delta
	var o: AudioStreamPlayer = piece_out["player"]
	var k_out: float = (float(piece_out["t"]) - (float(piece_out["len"]) - float(piece_out["xf"]))) / float(piece_out["xf"])
	if k_out >= 1.0 or stood:
		o.stop()
		o.volume_db = -80.0
		piece_out = {}
		return
	o.volume_db = _db(lin * cos(0.5 * PI * clampf(k_out, 0.0, 1.0)))
	o.pitch_scale = pitch


## The bed's loudness as heard, dB: both players, crossing or not (tests).
func bed_db() -> float:
	var power := 0.0
	for p: AudioStreamPlayer in bed_players:
		if p.volume_db > -79.9:
			power += db_to_linear(p.volume_db) ** 2
	return _db(sqrt(power))


## How hard the wind sounds right now, 0..1, gusts and all, whether the player
## is in or out: what the snow and the trees can follow (with gust_started).
func wind_now() -> float:
	return wind_level


## The places on the map the wind is heard from, by kind: a building's four
## corners, each tree, the gaps between the train's cars and a wagon's corners.
func spot_places() -> Dictionary:
	var out: Dictionary = {"corner": [], "tree": [], "car": []}
	var d: Dictionary = game.data
	for b: Dictionary in d.get("buildings", []):
		var r := Rect2i(b["rect"])
		for c in [r.position, Vector2i(r.end.x, r.position.y), Vector2i(r.position.x, r.end.y), r.end]:
			out["corner"].append(Vector3(c.x, 0.0, c.y))
	for t in d.get("trees", []):
		out["tree"].append(game.FieldGrid.center(t))
	var cars: Array = d.get("train_cars", [])
	for i in range(cars.size() - 1):
		var r := Rect2i(cars[i]["rect"])
		out["car"].append(Vector3(r.end.x, 0.0, r.position.y))
		out["car"].append(Vector3(r.end.x, 0.0, r.end.y))
	for w: Dictionary in d.get("wagons", []):
		var r := Rect2i(w["rect"])
		for c in [r.position, Vector2i(r.end.x, r.position.y), Vector2i(r.position.x, r.end.y), r.end]:
			out["car"].append(Vector3(c.x, 0.0, c.y))
	return out


## Each place's voice at its nearest place within SPOT_RANGE, at `lin` (the
## bed's level here) times how near, how hard it blows and the gust now. One
## that has to move to another place fades out where it was first.
func _tick_spots(at: Vector3, lin: float, gust_now: float, delta: float) -> void:
	spot_read_t -= delta
	if spot_read_t <= 0.0:
		spot_read_t = SPOT_REREAD
		spot_at = spot_places()
	spot_look_t -= delta
	var look := spot_look_t <= 0.0
	if look:
		spot_look_t = SPOT_LOOK
	var blow: float = clampf((wind_strength() - SPOT_MIN_WIND) / (1.0 - SPOT_MIN_WIND), 0.0, 1.0)
	for kind in spot_players:
		var s: AudioStreamPlayer3D = spot_players[kind]
		if s.stream == null:
			continue
		if look:
			var near := Vector3.INF
			var best := SPOT_RANGE
			for q: Vector3 in spot_at.get(kind, []):
				var dq: float = Vector2(q.x - at.x, q.z - at.z).length()
				if dq < best:
					best = dq
					near = q
			s.set_meta("to", near)
		var to: Vector3 = s.get_meta("to") if s.has_meta("to") else Vector3.INF
		var want := -80.0
		if to != Vector3.INF:
			if s.position.distance_to(to) > 2.0 and s.volume_db > -60.0:
				want = -80.0   # going elsewhere: quiet first
			else:
				s.position = to
				var d: float = Vector2(to.x - at.x, to.z - at.z).length()
				var close: float = clampf((SPOT_RANGE - d) / (SPOT_RANGE - SPOT_FULL), 0.0, 1.0)
				want = _db(lin * float(SPOTS[kind]) * close * blow * (1.0 + SPOT_GUST * gust_now))
		s.volume_db = move_toward(s.volume_db, want, 60.0 * delta)


## How open to the wind the player is here, 0..1: 1 outdoors; indoors by the
## air between here and the nearest open door or broken or open window and by
## the nearest outside wall (exposure), at most INDOOR_OPEN. A cellar has no
## openings of its own: it hears CELLAR_SHARE of the ground floor above it. Read
## again only when the cell, the floor or a door or window changes.
func openness_at(at: Vector3) -> float:
	var level: int = game.level_of(at)
	var g = game.grid if level < 0 else game.grid_at(at)
	var cell: Vector2i = game.FieldGrid.cell_of(at)
	var share: float = CELLAR_SHARE if level < 0 else 1.0
	if not g.indoor(cell):
		return share
	var key: Array = [level, cell, g.revision]
	if key == expose_key:
		return expose_last
	expose_key = key
	expose_last = INDOOR_OPEN * exposure(open_distance(g, cell), wall_distance(g, cell)) * share
	return expose_last


## The wind's reach indoors, 0..1, from an opening `d_open` m of air away and
## an outside wall `d_wall` m away (INF: none near).
static func exposure(d_open: float, d_wall: float) -> float:
	var e_open: float = clampf(1.0 - (d_open - 1.0) / OPEN_REACH, 0.0, 1.0)
	var e_wall: float = clampf(1.0 - (d_wall - 1.0) / WALL_REACH, 0.0, 1.0)
	return maxf(e_open, WALL_SHARE * e_wall)


## Air goes through cell c: open ground, floor, the air outside an upper floor,
## an open or broken door, an open or broken window with no planks on it.
static func air_passes(g, c: Vector2i) -> bool:
	var s: int = g.solid_at(c)
	if s == Grid.Solid.NONE or s == Grid.Solid.LOW or s == Grid.Solid.AIR:
		return true
	if s == Grid.Solid.DOOR:
		var d: Dictionary = g.doors.get(c, {})
		return String(d.get("state", "closed")) in ["open", "broken"]
	if s == Grid.Solid.WINDOW:
		var w: Dictionary = g.windows.get(c, {})
		return Grid.BuildingRules.window_passable(w)
	return false


## Steps of air (m) from indoor cell c to the outside, through cells the air
## goes through; INF when no way out is within EXPOSE_LOOK.
static func open_distance(g, c: Vector2i) -> float:
	var seen: Dictionary = {c: true}
	var front: Array[Vector2i] = [c]
	for step in range(1, EXPOSE_LOOK + 1):
		var next: Array[Vector2i] = []
		for p: Vector2i in front:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if seen.has(q) or not g.inside(q) or not air_passes(g, q):
					continue
				if not g.indoor(q):
					return float(step)
				seen[q] = true
				next.append(q)
		front = next
		if front.is_empty():
			break
	return INF


## Metres from indoor cell c to the nearest outside wall: a wall with open air
## outside it, within WALL_REACH and a cell over; INF when none.
static func wall_distance(g, c: Vector2i) -> float:
	var best := INF
	var r: int = ceili(WALL_REACH) + 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q: Vector2i = c + Vector2i(dx, dy)
			if not g.inside(q) or g.solid_at(q) != Grid.Solid.WALL:
				continue
			var far: float = Vector2(dx, dy).length()
			if far >= best:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var o: Vector2i = q + d
				if g.inside(o) and not g.indoor(o) and air_passes(g, o):
					best = far
					break
	return best


## The bed's level at openness o (0 deep inside, 1 outdoors), of outdoors'.
static func indoor_gain(o: float) -> float:
	return lerpf(INDOOR_LOW, 1.0, clampf(o, 0.0, 1.0))


## The WIND bus's low-pass at openness o, Hz: wide open outdoors, closing in
## the deeper inside.
static func wind_cutoff(o: float) -> float:
	var k: float = pow(clampf(o, 0.0, 1.0), 1.5)
	return float(WIND_CUT[0]) * pow(float(WIND_CUT[1]) / float(WIND_CUT[0]), k)


## The openness heard after `delta` s, following `target` (WIND_IN_TAU).
static func follow_open(now: float, target: float, delta: float) -> float:
	return target + (now - target) * exp(-maxf(delta, 0.0) / WIND_IN_TAU)


func _set_wind_cut(hz: float) -> void:
	wind_cut = hz
	var i := AudioServer.get_bus_index(WIND_BUS)
	if i < 0 or AudioServer.get_bus_effect_count(i) == 0:
		return
	var low := AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter
	if low != null:
		low.cutoff_hz = hz


func _tick_wind(at: Vector3, delta: float) -> void:
	wind_t += delta
	wind_up += delta
	# In or out: the wind follows, heard through the building (openness_at).
	var open_now: float = openness_at(at)
	openness = open_now if openness < 0.0 else follow_open(openness, open_now, delta)
	_set_wind_cut(wind_cutoff(openness))
	var base: float = 0.25 + 0.5 * wind_strength()
	# Getting down: the wind comes up from nothing, not on at once.
	var up: float = smoothstep(0.0, 1.0, clampf(wind_up / wind_in, 0.0, 1.0))
	var level: float = base * indoor_gain(openness) * up
	# The bed wanders on a slow noise: no two stretches alike, no beat to it.
	var n: float = drift.get_noise_1d(wind_t)
	var n2: float = drift.get_noise_1d(wind_t + 977.0)
	var now_ms: int = Time.get_ticks_msec()
	var stood: bool = wind_clock_ms >= 0 and float(now_ms - wind_clock_ms) > 1000.0 * (delta + WIND_STOOD_S)
	wind_clock_ms = now_ms
	_tick_pieces(level * (1.0 + WIND_DRIFT * n), 1.0 + WIND_PITCH_DRIFT * n2, delta, stood)
	var gust_now := 0.0
	for g: Dictionary in gusts:
		if float(g["len"]) > 0.0:
			gust_now = maxf(gust_now, float(g["peak"]) * float(g.get("env", 0.0)))
	wind_level = clampf(wind_strength() * (1.0 + WIND_DRIFT * n) * (1.0 + 0.6 * gust_now), 0.0, 1.0)
	_tick_spots(at, base * lerpf(SPOT_INDOOR, 1.0, openness) * up, gust_now, delta)
	# Once the train stands (not under the brakes of its coming in), and its
	# own few seconds after (FIRST_AFTER), never the moment one gets down.
	if not howled and game.arrive_t < 0.0 and game.weather.kinds.has("blizzard"):
		howl_wait -= delta
		if howl_wait <= 0.0:
			howled = true
			howl()
	gust_t -= delta
	if gust_t <= 0.0:
		gust_t = _next_gust_gap()
		_gust(randf_range(float(GUST_LEN[0]), float(GUST_LEN[1])), _next_gust_loud(), false)
	for g: Dictionary in gusts:
		var p: AudioStreamPlayer = g["player"]
		if float(g["len"]) <= 0.0:
			continue
		g["t"] = float(g["t"]) + delta
		var k: float = float(g["t"]) / float(g["len"])
		if k >= 1.0:
			g["len"] = 0.0
			g["env"] = 0.0
			p.stop()
			continue
		# Up to its top and away again, slower on the way out; the pitch bends.
		var top: float = float(g["top"])
		var env: float = sin(0.5 * PI * k / top) if k < top else cos(0.5 * PI * (k - top) / (1.0 - top))
		g["env"] = env
		p.volume_db = _db(level * float(g["peak"]) * env)
		p.pitch_scale = lerpf(float(g["p0"]), float(g["p1"]), smoothstep(0.0, 1.0, k))


## One gust over the bed: a file the last gust was not (a gust file, or the
## bed's own; `avoid` keeps a howl's layers apart), a place in it the last gust
## of that file did not start at, its own length, loudness and bend.
func _gust(length: float, peak: float, howl_layer: bool, avoid: Array = []) -> void:
	var last: Array = gust_log.back() if not gust_log.is_empty() else []
	var source := _pick_gust(String(last[6]) if last.size() > 6 else "", avoid)
	var stream: AudioStream = gust_stream(source)
	if stream == null:
		return
	avoid.append(source)
	var g: Dictionary = gusts[0]
	for other: Dictionary in gusts:
		if float(other["len"]) <= 0.0:
			g = other
			break
	var full: float = maxf(stream.get_length(), 0.1)
	if last.size() > 6 and String(last[6]) != source:
		last = last.duplicate()
		last[0] = -INF   # another file: no place to keep away from
	var lo: float = float(GUST_PITCH[0])
	var hi: float = float(GUST_PITCH[1])
	var from: float = randf_range(0.0, full * 0.7)
	var p0: float = randf_range(lo, hi)
	var p1: float = randf_range(lo, hi)
	if not last.is_empty():
		# Too near the last one's place or pitch: step away from it, so no two
		# gusts in a row ever have the same shape. The first 70% of the file is
		# wider than two steps, so one way always fits.
		var was: float = float(last[0])
		if absf(from - was) < GUST_APART * full:
			var away: float = (GUST_APART + 0.1 * randf()) * full
			from = was + away if was + away <= full * 0.7 else was - away
		var pitch_was: float = float(last[3])
		if absf(p0 - pitch_was) <= GUST_PITCH_APART:
			p0 = pitch_was + 2.0 * GUST_PITCH_APART if pitch_was + 2.0 * GUST_PITCH_APART <= hi else pitch_was - 2.0 * GUST_PITCH_APART
	# Never so late in the file that it runs out before the gust has died away
	# (its length at its highest pitch, and a little over).
	from = clampf(from, 0.0, maxf(0.0, full - length * maxf(p0, p1) * 1.05))
	var p: AudioStreamPlayer = g["player"]
	g["t"] = 0.0
	g["len"] = length
	g["peak"] = peak
	g["p0"] = p0
	g["p1"] = p1
	g["top"] = randf_range(0.25, 0.5)
	p.stream = stream
	p.pitch_scale = p0
	p.volume_db = -80.0
	p.play(from)
	gust_log.append([from, length, peak, p0, p1, howl_layer, source, wind_up])
	gust_started.emit(peak, length, howl_layer)


## The gap to the next gust: as gust_gap has it at this strength, never as
## like the gap before as GUST_GAP_APART of its range.
func _next_gust_gap() -> float:
	var gap := gust_gap(wind_strength())
	var t: float = randf_range(gap.x, gap.y)
	var apart: float = GUST_GAP_APART * (gap.y - gap.x)
	if not gust_gaps.is_empty():
		var was: float = float(gust_gaps.back())
		if absf(t - was) < apart:
			t = was + 2.0 * apart if was + 2.0 * apart <= gap.y else maxf(gap.x, was - 2.0 * apart)
	gust_gaps.append(t)
	return t


## A gust's strength: its own, never as like the last gust's as GUST_LOUD_APART.
func _next_gust_loud() -> float:
	var lo: float = float(GUST_LOUD[0])
	var hi: float = float(GUST_LOUD[1])
	var peak: float = randf_range(lo, hi)
	for k in range(gust_log.size() - 1, -1, -1):
		if bool(gust_log[k][5]):
			continue   # a howl's layer is no gust to keep apart from
		var was: float = float(gust_log[k][2])
		if absf(peak - was) < GUST_LOUD_APART:
			peak = was + 2.0 * GUST_LOUD_APART if was + 2.0 * GUST_LOUD_APART <= hi else was - 2.0 * GUST_LOUD_APART
		break
	return peak


## A gust's file: a gust file by name, or "bed" for this stop's bed.
func gust_stream(source: String) -> AudioStream:
	if source == "bed":
		return beds.get(bed_name)
	return gust_files.get(source)


## Which file a gust comes from: any gust file or the bed, not `last`, not one
## of `avoid`, while another is there.
func _pick_gust(last: String, avoid: Array) -> String:
	var all: Array = gust_files.keys()
	if beds.has(bed_name):
		all.append("bed")
	if all.is_empty():
		return ""
	var free: Array = all.filter(func(n) -> bool: return n != last and not avoid.has(n))
	if free.is_empty():
		free = all.filter(func(n) -> bool: return n != last)
	if free.is_empty():
		free = all
	return String(free[randi() % free.size()])


## A blizzard comes in: one to three gusts laid together, long, each bending
## its own way and from its own file, a new shape every time it is heard.
func howl() -> void:
	var layers := randi_range(int(HOWL_LAYERS[0]), int(HOWL_LAYERS[1]))
	var used: Array = []
	for i in range(layers):
		_gust(randf_range(float(HOWL_LEN[0]), float(HOWL_LEN[1])), randf_range(0.6, 1.0), true, used)
	gust_t = maxf(gust_t, float(HOWL_LEN[0]))


# ---------------------------------------------------------------- events

## The depart note goes up (true) or away (false; the mix is back in 0.3 s).
func hold(on: bool) -> void:
	held = on
	bed.volume_db += -9.0 if on else 9.0


## When each beat of a fall comes, in seconds from its start.
static func fall_times(gun: bool) -> Array:
	var length: float = float(Motion.row("dead_fall")["len"])
	return [0.0 if gun else FALL_AFTER_BLOW, FALL_REEL_AT, DeadPose.BUCKLE * length, DeadPose.LAND * length]


## Take up the falls that have just begun (the nearest few) and play the beats
## of those being followed as their time comes.
func _tick_falls(at: Vector3) -> void:
	var now: float = game.clock.elapsed
	for z in game.zombies.list:
		if not z.has("fell_at") or fall_heard.get(z["id"], -1.0) == z["fell_at"]:
			continue
		fall_heard[z["id"]] = z["fell_at"]
		var d: float = at.distance_to(z["pos"])
		if d > FALL_RANGE:
			continue
		_fall_voice(z, at)
		var row := {"z": z, "i": 0, "gun": now - float(game.last_gun_t) < FALL_GUN_WINDOW}
		if falls.size() < FALL_AT_ONCE:
			falls.append(row)
			continue
		var far := 0
		for k in range(falls.size()):
			if at.distance_to(falls[k]["z"]["pos"]) > at.distance_to(falls[far]["z"]["pos"]):
				far = k
		if d < at.distance_to(falls[far]["z"]["pos"]):
			falls[far] = row
	if fall_heard.size() > 400:
		fall_heard.clear()
	var keep: Array = []
	for f: Dictionary in falls:
		var z: Dictionary = f["z"]
		if not z.has("fell_at"):
			continue
		var since: float = float(z["age"]) - float(z["fell_at"])
		var times: Array = fall_times(bool(f["gun"]))
		while int(f["i"]) < FALL_BEATS.size() and since >= float(times[int(f["i"])]):
			_fall_beat(int(f["i"]), z["pos"], at, bool(f["gun"]), now)
			f["i"] = int(f["i"]) + 1
		if int(f["i"]) < FALL_BEATS.size():
			keep.append(f)
	falls = keep


func _fall_beat(i: int, where: Vector3, at: Vector3, gun: bool, now: float) -> void:
	var beat: Array = FALL_BEATS[i]
	var group: String = beat[0]
	var d: float = at.distance_to(where)
	if d > FALL_FAR and group != "fall_land":
		return
	if now - float(fall_last.get(group, -INF)) < FALL_SAME:
		return
	fall_last[group] = now
	played.append(group)
	var loud: float = FALL_GUN_HIT if gun and i == 0 else float(beat[1])
	_one_shot(group, where, loud * clampf(1.0 - d / FALL_RANGE, 0.0, 1.0), randf_range(float(beat[2]), float(beat[3])), null, _bus_at(where))


## '떠난다': impact, pen stroke, a gap, the whistle.
func depart() -> void:
	departing = true
	for beat in DEPART_BEATS:
		var g: String = beat[0]
		if float(beat[1]) <= 0.0:
			_play_beat(g)
		else:
			get_tree().create_timer(float(beat[1]), true).timeout.connect(_play_beat.bind(g))


func _play_beat(group: String) -> void:
	played.append(group)
	if has(group):
		_one_shot(group, game.player.position, 0.9 if group != "pen" else 0.6, 1.0)


## A horde sets off: no voice (they are far and out of sight) but a far thud,
## and birds going up now and then. The radio and the screen's marks say the rest.
func horde_started() -> void:
	var far: Vector3 = game.player.position + Vector3(0, 0, -20)
	for s: AudioStream in lib.get("impact", []):
		if s.resource_path.get_file().begins_with(String(FAR_THUD[0])):
			played.append("far_thud")
			_one_shot("impact", far, float(FAR_THUD[1]), randf_range(float(FAR_THUD[2]), float(FAR_THUD[3])), s, "SFX_FAR")
			break
	if birds_t <= 0.0 and has("birds"):
		birds_t = BIRDS_EVERY
		played.append("birds")
		_one_shot("birds", far, 0.7, randf_range(0.92, 1.08))


## The radio on the chief (decisions 032): "hiss" before a call, then the call;
## an urgent one (a horde coming in, time to leave) is the loudest.
const RADIO_LOUD: Dictionary = {"hiss": 0.35, "call": 0.6, "urgent": 1.0}


func radio(kind: String) -> void:
	var group := "radio_hiss" if kind == "hiss" else "radio"
	played.append(group)
	if kind != "hiss":
		hush.emit("radio", HUSH_RADIO_S)
	_one_shot(group, game.player.position, float(RADIO_LOUD.get(kind, 0.6)), 1.0)


## A door of the held train, for the player's ear only: no rule hears it.
## Until the files are in, it is the knock there was.
func door(kind: String, at: Vector3, level: int) -> void:
	var v: Array = DOOR_VOICES[kind]
	var group: String = v[0]
	played.append(group)
	var loud: float = float(v[1])
	if DOOR_BLOWS.has(kind):
		loud *= clampf(0.35 + 0.2 * level, 0.3, 1.0)
	var d: float = at.distance_to(game.player.position)
	_one_shot(group if has(group) else "impact", at, loud * clampf(1.0 - d / 60.0, 0.0, 1.0), randf_range(float(v[2]), float(v[3])), null, _bus_at(at))


## A building's door opened or shut by someone (state "open" or "closed"), heard
## from the door, in the player's room when it is one of the room's doors.
## by_key: opened with its key (DOOR_KEY), the click and then the door, softer.
func door_turn(c: Vector2i, state: String, by_key: bool = false) -> void:
	if quiet or game == null or game.player == null or not DOOR_TURN.has(state):
		return
	var voice: Array = DOOR_TURN[state]
	var at: Vector3 = game.FieldGrid.center(c)
	if not by_key:
		_voice_or_standin(voice, String(voice[4]), at)
		return
	_voice_or_standin(DOOR_KEY, String(DOOR_KEY[4]), at)
	var soft: Array = voice.duplicate()
	soft[1] = float(voice[1]) * DOOR_KEY_HUSH
	if is_inside_tree():
		get_tree().create_timer(DOOR_KEY_LAG, false).timeout.connect(_key_door_goes.bind(c, soft, at))
	else:
		_key_door_goes(c, soft, at)


## The door a key turned goes, a moment after the click: not if the stop
## has ended or the door is shut again meanwhile.
func _key_door_goes(c: Vector2i, soft: Array, at: Vector3) -> void:
	if game == null or game.ended or String((game.grid.doors.get(c, {}) as Dictionary).get("state", "")) != "open":
		return
	_voice_or_standin(soft, String(soft[4]), at)


## A building's window opened or shut by someone ("open", "closed"), or its
## curtain drawn or opened ("curtain"), heard from the window.
func window_turn(c: Vector2i, what: String) -> void:
	if quiet or game == null or game.player == null or not WINDOW_TURN.has(what):
		return
	var voice: Array = WINDOW_TURN[what]
	_voice_or_standin(voice, String(voice[4]), game.FieldGrid.center(c))


## A door or a window that would not give to the player's hand (SHUT_FAST:
## "locked" or "boarded"), heard from it; once in SHUT_FAST_GAP_MS for the
## same one and reason.
func shut_fast(c: Vector2i, why: String) -> void:
	if quiet or game == null or game.player == null or not SHUT_FAST.has(why):
		return
	var key := "%d,%d,%s" % [c.x, c.y, why]
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - int(shut_heard.get(key, -SHUT_FAST_GAP_MS)) < SHUT_FAST_GAP_MS:
		return
	shut_heard[key] = now_ms
	var voice: Array = SHUT_FAST[why]
	_voice_or_standin(voice, String(voice[4]), game.FieldGrid.center(c))


## A loose board creaking, for the player's ear (the rule sound is field_game's
## "floor_creak"): its own group once there is one, else the impact set's wood.
func floor_creak(at: Vector3) -> void:
	_voice_or_standin(CREAK_VOICE, CREAK_STANDIN, at)


## A lid dragged off a manhole, for the player's ear only: no rule hears it
## (the dead's coming up is heard as it was).
func lid_scrape(at: Vector3) -> void:
	_voice_or_standin(LID_VOICE, LID_STANDIN, at)


## A piece of furniture opened, shut, put into and taken from (card R3 가, decision 469;
## reference 8: four sounds a container): for the player's ear only — no rule hears it,
## so no make_sound tag and no noise.gd SOURCES row. Its kind by its furniture; one not
## listed (open shelves, racks, a bench, a bin) opens and shuts with no sound.
const BOX_KIND: Dictionary = {
	"": "lid", "crate_stack": "lid", "tin_crate": "lid", "part_crate": "lid", "ammo_crate": "lid",
	"relief_crate": "lid", "blanket_crate": "lid", "blanket_chest": "lid", "parish_chest": "lid",
	"vestry_chest": "lid", "conductor_log_chest": "lid", "ration_ledger_chest": "lid",
	"medicine_crate": "lid", "cask_stack": "lid", "freezer_chest": "lid", "tool_chest": "lid",
	"nightstand": "drawer", "side_table": "drawer", "dresser": "drawer", "desk": "drawer",
	"typewriter_desk": "drawer", "office_desk": "drawer", "file_cabinet": "drawer", "map_cabinet": "drawer",
	"drawer_chest_spilled": "drawer", "counter": "drawer", "shop_counter": "drawer",
	"service_counter": "drawer", "checkout": "drawer",
	"wardrobe": "door", "cupboard": "door", "medicine_cabinet": "door", "washstand": "door",
	"glass_cabinet": "door", "office_cabinet": "door",
	"toolbox": "metal", "strongbox": "metal",
}
## Each kind's opening and shutting: group, loudness, pitch low and high, and the impact
## file that stands in until a file is in its group. First values, quiet — a hand's work.
const BOX_VOICES: Dictionary = {
	"lid": {"open": ["box_open_lid", 0.35, 0.95, 1.05, "wooden"], "close": ["box_close_lid", 0.4, 0.8, 0.9, "wooden"]},
	"drawer": {"open": ["box_open_drawer", 0.3, 1.3, 1.45, "wooden"], "close": ["box_close_drawer", 0.35, 1.1, 1.2, "wooden"]},
	"door": {"open": ["box_open_door", 0.3, 0.7, 0.8, "wooden"], "close": ["box_close_door", 0.35, 0.9, 1.0, "wooden"]},
	"metal": {"open": ["box_open_metal", 0.3, 1.2, 1.3, "metal"], "close": ["box_close_metal", 0.35, 1.0, 1.1, "metal"]},
}
## A thing going in or coming out, whatever the furniture.
const BOX_RUSTLE: Dictionary = {"put": ["box_put", 0.25, 1.5, 1.7, "hit"], "take": ["box_take", 0.25, 1.7, 1.9, "hit"]}
## Opening and shutting come no closer than this (reference 8's 0.5), so flicking through a
## room's boxes never piles them up. Real time: the pane holds the field still.
const BOX_GAP_MS: int = 500
var box_quiet_until: int = 0


## Box `c` sounds `what` ("open", "close", "put", "take"); false when it is no box on the
## map, its kind has no such sound or an opening or shutting comes too soon after the last.
func box_sound(c: Dictionary, what: String) -> bool:
	if not c.has("cell"):
		return false
	var voice: Array = BOX_RUSTLE.get(what, [])
	if voice.is_empty():
		var kind := String(BOX_KIND.get(String(c.get("furniture", "")), ""))
		if kind == "" or not (BOX_VOICES[kind] as Dictionary).has(what):
			return false
		var now := Time.get_ticks_msec()
		if now < box_quiet_until:
			return false
		box_quiet_until = now + BOX_GAP_MS
		voice = BOX_VOICES[kind][what]
	if not lib.has("impact"):
		lib["impact"] = _load_group("impact")
	_voice_or_standin(voice, String(voice[4]), game.actions._container_at(c))
	return true


## A one-shot of its own group [group, loudness, pitch low, pitch high], or, until that
## group has a file, the impact file whose name begins with `standin` (with
## "@": a file of that group of its own).
func _voice_or_standin(voice: Array, standin: String, at: Vector3) -> void:
	var group: String = voice[0]
	if not lib.has(group):
		lib[group] = _load_group(group)
	played.append(group)
	var d: float = at.distance_to(game.player.position)
	var lin: float = float(voice[1]) * clampf(1.0 - d / 60.0, 0.0, 1.0)
	var pitch := randf_range(float(voice[2]), float(voice[3]))
	if has(group):
		_one_shot(group, at, lin, pitch, null, _bus_at(at))
		return
	if standin.begins_with("@"):
		var own: String = standin.substr(1)
		if not lib.has(own):
			lib[own] = _load_group(own)
		var pick: int = _fresh_file(own)
		if pick >= 0:
			_one_shot(own, at, lin, pitch, lib[own][pick], _bus_at(at))
		return
	for s: AudioStream in lib.get("impact", []):
		if s.resource_path.get_file().begins_with(standin):
			_one_shot("impact", at, lin, pitch, s, _bus_at(at))
			return


## The brakes as the train comes to its stand on open line (user decision
## 141's file), the ear's half of the opening scene. The rules' half is the
## loud sound at the engine end the dead do hear (decision 416, field
## train_guard brake, noise.gd SOURCES "train_brake"): made once as the clock
## starts, so skipping the scene changes nothing; it plays no sound of its own.
## `lead`: how long before the train stands this is called; the file starts
## so its own standing (BRAKE_STAND_AT) falls on the train's.
func train_brake(lead: float = BRAKE_STAND_AT) -> void:
	played.append("train_brake")
	hush.emit("brake", HUSH_BRAKE_S)
	_one_shot("train_brake", game.player.position, BRAKE_LOUD, 1.0, null, "SFX", 0.0, maxf(0.0, BRAKE_STAND_AT - lead))


## The chief's aside beside the risk line, muttered very low (user decision
## 187). The voice file is found by the line's number ("chief_feel_07"); with
## no file there is no sound. Not a sound of the field: nothing hears it.
func chief_feel(number: int) -> void:
	if number <= 0:
		return
	var group: String = FEEL_GROUP % number
	if not lib.has(group):
		lib[group] = _load_group(group)
	if not has(group):
		return
	played.append(group)
	_one_shot(group, game.player.position, FEEL_LOUD, 1.0)


## One of the dead drops low before it runs: its rasp, for the player's ear
## only. Until the file is in, it is a moan pitched up.
func lunge_tell(at: Vector3) -> void:
	played.append(TELL_GROUP)
	var own: bool = has(TELL_GROUP)
	var d: float = at.distance_to(game.player.position)
	_one_shot(TELL_GROUP if own else "moan", at, TELL_LOUD * clampf(1.0 - d / TELL_RANGE, 0.0, 1.0), 1.0 if own else TELL_STANDIN_PITCH, null, ROOM_BUS if in_room(at) else "SFX")


## A blow's own sound (hit_feel.gd), heard to `reach` m and duller through a
## wall. The dead hear the blow by make_sound, not by this.
## A blow on one of the dead the combat has told (blow) is heard by its own
## layers: hit_* at the same place in the same frame is listed but not
## played again (a door or a person struck is told by no one: heard as ever).
func feel_sound(group: String, at: Vector3, loud: float, reach: float) -> void:
	if quiet:
		return
	played.append(group)
	var hit: bool = blow_wired and group.begins_with("hit_")
	if hit and _same_blow(blow_mark, at):
		return
	var d: float = at.distance_to(game.player.position)
	var lin: float = loud * clampf(1.0 - d / reach, 0.0, 1.0)
	if not lib.has(group):
		lib[group] = _load_group(group)
	if not has(group) and FEEL_STANDINS.has(group):
		# Until its files are in, a blow's layer stands in for it.
		var stand: Array = FEEL_STANDINS[group]
		var pick: int = _fresh_file(String(stand[0]))
		if pick >= 0:
			_one_shot(String(stand[0]), at, lin, randf_range(float(stand[1]), float(stand[2])), lib[String(stand[0])][pick], _bus_at(at))
		return
	_one_shot(group, at, lin, randf_range(0.92, 1.08), null, _bus_at(at))
	if hit and last_shot != null:
		hit_mark = [Engine.get_process_frames(), at, last_shot, int(last_shot.get_meta("cut", 0))]


## mark [frame, place, …] was made this frame within BLOW_SAME_M of at.
static func _same_blow(mark: Array, at: Vector3) -> bool:
	return int(mark[0]) == Engine.get_process_frames() and (mark[1] as Vector3).distance_to(at) < BLOW_SAME_M


## The layers of one blow [group, loudness, pitch] from what the combat tells
## of it (`struck`'s info): weapon, target, result, edge (-1 none, 0 keen,
## 1 dull, 2 about to give).
static func blow_layers(info: Dictionary) -> Array:
	var result: String = String(info.get("result", "body"))
	if result == "miss":
		return [["blow_miss", 0.6, 1.0]]
	var target: String = String(info.get("target", "standing"))
	var edge: int = int(info.get("edge", -1))
	var wid: String = String(info.get("weapon", ""))
	var family: String = String(BLOW_FAMILY.get(wid, ""))
	if family == "":
		var d: Dictionary = W.get_data(wid)
		family = ("blow_cut" if bool(d.get("blade", false)) else "blow_thud") if d.get("kind", "") == "melee" else "blow_shove"
	var pitch: float = 1.0
	if edge >= 1:
		pitch *= BLOW_DULL_PITCH
	if target == "downed":
		pitch *= BLOW_DOWN_PITCH
	var out: Array = [[family, float(BLOW_UNDER.get(result, 1.0)), pitch]]
	# Decision 501: only the body's first layer follows the blow's tier.
	var tier: int = int(info.get("tier", -1))
	if tier == 0 or tier == 2:
		out[0][1] *= 0.6 if tier == 0 else 1.12
		out[0][2] *= 1.1 if tier == 0 else 0.95
	if BLOW_LAYER.has(result):
		out.append([BLOW_LAYER[result], 0.9, 1.0])
	if target == "frozen" and result != "shatter" and result != "stuck":
		out.append(["blow_stuck", 0.5, 1.0])   # frozen flesh is heard as ice
	if target == "downed" and family != "blow_stomp":
		out.append(["blow_ground", 0.6, 1.0])
	if edge == 2:
		out.append(["blow_breaking", 0.7, 1.0])
	return out


## One blow on one of the dead (combat `struck`), heard from where it landed
## to BLOW_REACH m, duller through a wall or from a dull weapon.
func blow(info: Dictionary) -> void:
	if quiet or game == null or game.player == null:
		return
	var at: Vector3 = info.get("at", game.player.position)
	# Its hit_* went first this frame (a stomp is felt before it is told): the
	# blow's own layers take its place.
	if blow_wired and _same_blow(hit_mark, at):
		var o = hit_mark[2]
		# Only if that player still has that sound (not another since).
		if is_instance_valid(o) and int(o.get_meta("cut", 0)) == int(hit_mark[3]):
			o.stop()
			hits_stopped += 1
		hit_mark = [-1, Vector3.ZERO, null, 0]   # a second blow there stops nothing
	blow_mark = [Engine.get_process_frames(), at]
	var d: float = at.distance_to(game.player.position)
	var near: float = clampf(1.0 - d / BLOW_REACH, 0.0, 1.0)
	var plain: String = _bus_at(at)
	# A dull weapon's own hit is duller; what came of it is heard as it is.
	var dull: String = (ROOM_DULL_BUS if plain == ROOM_BUS else "SFX_MID") if int(info.get("edge", -1)) >= 1 else plain
	var layers: Array = blow_layers(info)
	for i in layers.size():
		var layer: Array = layers[i]
		var group: String = layer[0]
		var bus: String = dull if i == 0 else plain
		var file: int = _fresh_file(group)
		played.append(group)
		if file < 0:
			continue
		blow_log.append([group, file])
		_one_shot(group, at, BLOW_LOUD * float(layer[1]) * near * randf_range(float(BLOW_GAIN[0]), float(BLOW_GAIN[1])), float(layer[2]) * randf_range(float(BLOW_PITCH[0]), float(BLOW_PITCH[1])), lib[group][file], bus)


## A file of the group other than the one it played last (-1: none there).
func _fresh_file(group: String) -> int:
	var count: int = (lib.get(group, []) as Array).size()
	if count == 0:
		return -1
	var last: int = int(blow_last.get(group, -1))
	var pick: int = randi() % count
	if count > 1 and pick == last:
		pick = (pick + 1 + randi() % (count - 1)) % count
	blow_last[group] = pick
	return pick


## A sound the dead can hear is also one the player hears (field make_sound).
func on_sound(at: Vector3, level: int, tag: String) -> void:
	if quiet:
		return
	# A building's door the dead are beating on: a door's own blow, lower and
	# duller once it is about to give (J17, the planks aside).
	if tag == "bang" and _building_door_bang(at, level):
		return
	var group := ""
	if tag == "building_alarm" or tag == "building_alarm_ring":
		group = "building_alarm"
	elif tag == "whistle":
		if departing:
			return
		group = "whistle"
	elif tag == "gun":
		group = "gun" if has("gun") else "impact"
	elif IMPACT_TAGS.has(tag):
		group = "impact"
	elif TAG_VOICES.has(tag):
		last_tag_group = String(TAG_VOICES[tag][0])
		var loud_tag: float = clampf(0.35 + 0.2 * level, 0.3, 1.0)
		if tag == "hammer":
			var place := Vector3i((at * 10.0).round())
			hammer_chains += 1
			hammering[place] = hammer_chains
			_hammer(at, loud_tag, place, hammer_chains)
		else:
			_tag_voice(TAG_VOICES[tag], at, loud_tag * clampf(1.0 - at.distance_to(game.player.position) / 60.0, 0.0, 1.0))
		return
	last_tag_group = group
	if group == "" or not has(group):
		return
	var d: float = at.distance_to(game.player.position)
	var loud := clampf(0.35 + 0.2 * level, 0.3, 1.0)
	var lin := loud * clampf(1.0 - d / 60.0, 0.0, 1.0) if group != "whistle" else 1.0
	if group == "building_alarm":
		# It carries twice as far as a loud sound (noise.gd SOURCES "reach").
		lin = ALARM_LOUD * clampf(1.0 - d / ALARM_HEARD_M, 0.0, 1.0)
	if level >= SimNoise.Level.LOUD and lin > 0.01:
		hush.emit("near", HUSH_LOUD_S)
	_one_shot(group, at, lin, 0.7 if tag == "gun" and group == "impact" else randf_range(0.9, 1.1), null, "SFX" if group == "whistle" else _bus_at(at))


## One of TAG_VOICES heard from `at` at on_sound's loudness, as many times as
## it says, that far apart.
func _tag_voice(v: Array, at: Vector3, lin: float) -> void:
	_tag_knock(v, at, lin)
	for i in range(1, int(v[4])):
		if is_inside_tree():
			get_tree().create_timer(float(v[5]) * i, false).timeout.connect(_tag_knock.bind(v, at, lin))
		else:
			_tag_knock(v, at, lin)


## One sound of a TAG_VOICES row: its group's file, or its stand-in's.
func _tag_knock(v: Array, at: Vector3, lin: float) -> void:
	if game == null or game.ended:
		return
	var group: String = v[0]
	if not lib.has(group):
		lib[group] = _load_group(group)
	var pitch := randf_range(float(v[2]), float(v[3]))
	tag_knocks += 1
	if has(group):
		_one_shot(group, at, lin, pitch, null, _bus_at(at))
		return
	var stand: String = v[1]
	if stand.begins_with("@"):
		var own: String = stand.substr(1)
		var pick: int = _fresh_file(own)
		if pick >= 0:
			_one_shot(own, at, lin, pitch, lib[own][pick], _bus_at(at), float(v[6]))
		return
	for s: AudioStream in lib.get("impact", []):
		if s.resource_path.get_file().begins_with(stand):
			_one_shot("impact", at, lin, pitch, s, _bus_at(at))
			return


## Nails going in: a knock now and again for as long as the boarding at `at`
## (the work the rule sound started) goes on, then no more — not on through
## another work of the hands after it. Each knock as loud as the player hears
## it from where they are then. One chain a place (hammering): a boarding
## begun again there before the next knock knocks at once as its own chain,
## and the old one stops at its next turn, so it is never twice the pace.
func _hammer(at: Vector3, loud: float, place: Vector3i, chain: int) -> void:
	if int(hammering.get(place, 0)) != chain:
		return
	if game == null or game.ended or not _boarding_at(at):
		hammering.erase(place)
		return
	_tag_knock(TAG_VOICES["hammer"], at, loud * clampf(1.0 - at.distance_to(game.player.position) / 60.0, 0.0, 1.0))
	if is_inside_tree():
		get_tree().create_timer(randf_range(float(HAMMER_GAP[0]), float(HAMMER_GAP[1])), false).timeout.connect(_hammer.bind(at, loud, place, chain))
	else:
		hammering.erase(place)


## Someone is at the boarding of the door or window at `at` (field_actions
## board_door / board_window: a "craft" work of that kind there).
func _boarding_at(at: Vector3) -> bool:
	for person in game.people:
		if not person.is_alive() or String(person.action) != "craft":
			continue
		var work: Dictionary = game.actions.ongoing.get(person.get_instance_id(), {})
		if not ["door", "window"].has(String(work.get("kind", ""))):
			continue
		var spot: Vector3 = work["at"]
		if spot.distance_to(at) < 0.5:
			return true
	return false


## A building's alarm (J17): loudness, and how far the player hears it.
const ALARM_LOUD: float = 0.75
const ALARM_HEARD_M: float = 120.0
## A building's door with this many blows of wear left or fewer sounds as
## about to give.
const DOOR_GIVING_HP: int = 2


## True if at is a building's door (not open, not broken) and its blow was
## played: the plain blow, or the lower one when it is about to give.
func _building_door_bang(at: Vector3, level: int) -> bool:
	var door: Dictionary = game.grid_at(at).doors.get(game.FieldGrid.cell_of(at), {})
	if door.is_empty() or int(door.get("building", -1)) < 0 or String(door.get("state", "")) in ["open", "broken"]:
		return false
	last_tag_group = DOOR_VOICES["low"][0]
	door_creaks.append(int(door.get("hp", 0)) <= DOOR_GIVING_HP)
	door("low" if int(door.get("hp", 0)) <= DOOR_GIVING_HP else "door", at, level)
	return true


## The player's own step, by what is underfoot (FieldGrid.Floor): its own
## group, or down the row to one that has files (snow at the last); glass on
## the floor crunches over it. Never the same file twice running.
func footstep(at: Vector3, running: bool) -> void:
	var g = game.grid_at(at)
	var cell: Vector2i = game.FieldGrid.cell_of(at)
	var found: Array = _step_group(at)
	var group: String = found[0]
	var row: Array = found[1]
	if group != "":
		var pick: int = _other_than(group, step_last)
		steps.append([group, pick])
		if steps.size() > STEPS_KEPT:
			steps = steps.slice(steps.size() - STEPS_KEPT)
		_one_shot(group, at, (0.5 if running else 0.3) * float(row[1]), randf_range(0.9, 1.1) * float(row[2]), lib[group][pick], _bus_at(at))
	if g.floor_glass.has(cell):
		_voice_or_standin(STEP_GLASS, GLASS_STANDIN, at)


## The step group for the floor at `at` and its row of STEP_FLOORS: the first
## of the row's groups that has files ("" when none has).
func _step_group(at: Vector3) -> Array:
	var kind: int = game.grid_at(at).floor_at(game.FieldGrid.cell_of(at))
	var row: Array = STEP_FLOORS[kind] if kind >= 0 and kind < STEP_FLOORS.size() else STEP_FLOORS[0]
	for try_group: String in row[0]:
		if not lib.has(try_group):
			lib[try_group] = _load_group(try_group)
		if has(try_group):
			return [try_group, row]
	return ["", row]


## Where one voiced body's feet have got to since the last tick: how far it
## went, and whether it walks in sight (a crawler, a jump or a body the player
## no longer sees does not, though its voice lingers a moment: VOICE_KEEP).
func _move_feet(s: Dictionary) -> void:
	var z: Dictionary = s["z"]
	if z.is_empty():
		s["feet_moving"] = false
		return
	var now: Vector3 = z["pos"]
	var was: Vector3 = s.get("feet_at", now)
	s["feet_at"] = now
	var gone: float = Vector2(now.x - was.x, now.z - was.z).length()
	s["feet_gone"] = gone
	s["feet_moving"] = gone > 0.0005 and gone <= DEAD_STEP_JUMP and not bool(z.get("crawl", false)) and in_view(now)


## One of the voiced dead walking (DEAD_GAITS): a step each time it has gone
## a stride, the stride drawn new for every step. Heard from DEAD_STEP_RANGE
## in, and only from the DEAD_STEPPERS nearest; a crawler, a jump or a body
## standing still makes none. Never the same file twice running.
func _tick_feet(s: Dictionary, z: Dictionary, d: float) -> void:
	if feet.is_empty() or not bool(s.get("feet_moving", false)):
		return
	var now: Vector3 = z["pos"]
	var gone: float = float(s.get("feet_gone", 0.0))
	var gait: Dictionary = DEAD_GAITS[gait_of(String(z["state"]))]
	var stride: Array = gait["stride"]
	if not s.has("feet_left"):
		s["feet_left"] = randf_range(0.0, float(stride[1]))
	s["feet_left"] = float(s["feet_left"]) - gone
	if float(s["feet_left"]) > 0.0:
		return
	s["feet_left"] = randf_range(float(stride[0]), float(stride[1]))
	feet_strides += 1
	if d >= DEAD_STEP_RANGE or randf() < float(gait["skip"]) or _nearer_feet(z, d) >= DEAD_STEPPERS:
		return
	var found: Array = _step_group(now)
	var group: String = found[0]
	if group == "":
		return
	var row: Array = found[1]
	var pick: int = _other_than(group, dead_step_last)
	if not _foot(group, pick, now, float(gait["loud"]) * float(row[1]) * (1.0 - d / DEAD_STEP_RANGE),
			randf_range(float(gait["pitch"][0]), float(gait["pitch"][1])) * float(row[2])):
		return
	dead_steps.append([int(z["id"]), group, pick])
	if dead_steps.size() > STEPS_KEPT:
		dead_steps = dead_steps.slice(dead_steps.size() - STEPS_KEPT)


## An ally's step (squad or crew, from field_game _footsteps): by the floor
## rows the player's own go by, COMPANY_STEP_LOUD of theirs, heard from
## DEAD_STEP_RANGE in and duller through a wall. Its run of files is its own,
## so the player's own never repeats for it.
func company_step(at: Vector3, running: bool) -> void:
	if game == null or game.player == null:
		return
	var d: float = at.distance_to(game.player.position)
	if d >= DEAD_STEP_RANGE:
		return
	var found: Array = _step_group(at)
	var group: String = found[0]
	if group == "":
		return
	var row: Array = found[1]
	var pick: int = _other_than(group, company_step_last)
	if not _foot(group, pick, at, (0.5 if running else 0.3) * COMPANY_STEP_LOUD * float(row[1]) * (1.0 - d / DEAD_STEP_RANGE),
			randf_range(0.9, 1.1) * float(row[2])):
		return
	company_steps.append([group, pick])
	if company_steps.size() > STEPS_KEPT:
		company_steps = company_steps.slice(company_steps.size() - STEPS_KEPT)


## A file of the group other than the one `last` says it played last, and
## noted there as the last now.
func _other_than(group: String, last: Dictionary) -> int:
	var count: int = (lib[group] as Array).size()
	var pick: int = randi() % count
	if count > 1 and pick == int(last.get(group, -1)):
		pick = (pick + 1 + randi() % (count - 1)) % count
	last[group] = pick
	return pick


## One step of someone else on the next of the feet players (false: too faint
## to play, or no players).
func _foot(group: String, pick: int, at: Vector3, lin: float, pitch: float) -> bool:
	if feet.is_empty() or lin <= 0.01:
		return false
	var o: AudioStreamPlayer3D = feet[feet_n % feet.size()]
	feet_n += 1
	o.bus = _bus_at(at)
	o.position = at
	o.stream = lib[group][pick]
	o.volume_db = _db(lin)
	o.pitch_scale = pitch
	o.play()
	return true


## How one of the dead walks, by what it is doing: running at you, after you
## (or at you), or shambling.
static func gait_of(state: String) -> String:
	if state == "dash":
		return "dash"
	return "shamble" if says_for(state) == "idle" else "chase"


## How many of the other voiced dead walking (as of their last tick) are
## nearer than d.
func _nearer_feet(z: Dictionary, d: float) -> int:
	var n := 0
	var at: Vector3 = game.player.position
	for s in slots:
		var other: Dictionary = s["z"]
		if other.is_empty() or int(other["id"]) == int(z["id"]) or not bool(s.get("feet_moving", false)):
			continue
		if other["pos"].distance_to(at) < d:
			n += 1
	return n


## The bus a sound from here goes through: duller through a wall, the room's
## reverb in the player's own room, else plain.
func _bus_at(at: Vector3) -> String:
	if through_wall(at):
		return "SFX_MID"
	return ROOM_BUS if in_room(at) else "SFX"


## cut > 0: only that many seconds of it are heard, then it fades out fast.
## from: where in the file it starts (seconds).
func _one_shot(group: String, at: Vector3, lin: float, pitch: float, stream: AudioStream = null, bus: String = "SFX", cut: float = 0.0, from: float = 0.0) -> void:
	last_shot = null
	if lin <= 0.01 or not has(group):
		return
	var o: AudioStreamPlayer3D = null
	for p in one_shots:
		if not p.playing:
			o = p
			break
	if o == null:
		# All busy: the one that started longest ago gives way.
		o = one_shots[0]
		for p in one_shots:
			if int(p.get_meta("cut", 0)) < int(o.get_meta("cut", 0)):
				o = p
	o.bus = bus
	last_bus = bus
	o.position = at
	o.stream = stream if stream != null else _pick(group)
	o.volume_db = _db(lin)
	o.pitch_scale = pitch
	o.play(from)
	last_shot = o
	cut_n += 1
	o.set_meta("cut", cut_n)
	if cut > 0.0 and is_inside_tree():
		get_tree().create_timer(cut, false).timeout.connect(_end_cut.bind(o, cut_n))


## The end of a cut one-shot, unless the player has gone on to another sound.
func _end_cut(o: AudioStreamPlayer3D, mine: int) -> void:
	if int(o.get_meta("cut", 0)) != mine or not o.playing:
		return
	var fade := o.create_tween()
	fade.tween_property(o, "volume_db", -80.0, 0.08)
	fade.tween_callback(_stop_if.bind(o, mine))


func _stop_if(o: AudioStreamPlayer3D, mine: int) -> void:
	if int(o.get_meta("cut", 0)) == mine:
		o.stop()
