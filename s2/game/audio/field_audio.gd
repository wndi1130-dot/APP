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
##              made here from noise and tones (rights_ledger), not recorded
##   gun        shots (falls back to impact, lower)
##   step_snow  the player's footsteps
##   wind       outdoor bed, wandering, with gusts over it (WIND_DRIFT, _gust)
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

const GROUPS: Array[String] = ["moan", "horde_bed", "birds", "impact", "gun", "step_snow", "wind", "train_idle", "whistle", "train_brake", "pen", "radio_hiss", "radio", "fall_hit", "fall_reel", "fall_knee", "fall_land", "door_bang", "door_wall", "door_break", "building_alarm", "swing_light", "swing_heavy", "hit_blunt", "hit_blade", "hit_stomp"]
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
## A manhole lid dragged aside by one of the dead coming up (decision 422 M9):
## group, loudness, pitch low and high. Until a file is in its group it is the
## impact set's iron, pitched down.
const LID_VOICE: Array = ["lid_scrape", 0.7, 0.55, 0.65]
const LID_STANDIN: String = "metal"    # the impact file that stands in for it
## A loose floorboard creaking underfoot (room_stories card K): group, loudness, pitch low
## and high. Until a file is in its group it is the impact set's wood, pitched well down.
const CREAK_VOICE: Array = ["floor_creak", 0.35, 0.45, 0.55]
const CREAK_STANDIN: String = "wooden"
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
const WIND_IN: Array = [0.8, 3.0]     # s the bed takes to come up as the stop starts
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
const HOWL_LAYERS: Array = [1, 3]
const HOWL_LEN: Array = [3.0, 6.5]
const GUSTS: int = 3                  # players for gusts (a howl lays up to three)
## Melee blows ("melee", "fight") are not here: hit_feel.gd voices them by
## the weapon (a miss, the swing alone), where any of these files would do.
const IMPACT_TAGS: Array[String] = ["kick", "glass", "pry", "bang", "lid", "salvage", "pickaxe", "fall", "impact", "ladder", "bell", "train_guard"]

var game
var lib: Dictionary = {}               # group -> Array[AudioStream]
var slots: Array = []                  # {"player": AudioStreamPlayer3D, "z": Dictionary, "wait": float}
var bed: AudioStreamPlayer
var wind: AudioStreamPlayer
var engine: AudioStreamPlayer3D
var one_shots: Array = []
var birds_t: float = 0.0
var heard_t: float = 0.0               # the ear's own clock (VOICE_KEEP)
var seen_at: Dictionary = {}           # zombie id -> heard_t it was last in sight
var pick_t: float = 0.0
var crowd: float = 0.0                 # weighted dead near the player (for the bed)
var last_tag_group: String = ""        # what the last make_sound played (tests)
var held: bool = false                 # the depart note is up
var departing: bool = false            # '떠난다' plays its own whistle
var played: Array = []                 # groups played, in order (tests)
var door_creaks: Array = []             # building doors beaten on: true when it was about to give (tests)

## The music steps aside for a sound that matters (the music frame's ducking
## connects here; nothing in the rules reads it). kind: "brake" (the train
## coming to a stand), "radio" (a call), "near" (a loud sound of the field
## near enough to hear); seconds: how long.
signal hush(kind: String, seconds: float)
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
var gust_log: Array = []               # every gust's shape [at, len, peak, p0, p1, howl] (tests)
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
	for g in GROUPS:
		lib[g] = _load_group(g)
	for i in range(MOAN_SLOTS):
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		add_child(p)
		slots.append({"player": p, "z": {}, "wait": randf_range(0.5, 3.0)})
	bed = _loop_player("horde_bed")
	wind = _loop_player("wind")
	drift.seed = randi()
	drift.frequency = WIND_DRIFT_HZ
	# The noise is level at its start: begin somewhere along it instead.
	wind_t = randf_range(0.0, WIND_PHASE)
	wind_in = randf_range(float(WIND_IN[0]), float(WIND_IN[1]))
	howl_wait = randf_range(float(FIRST_AFTER[0]), float(FIRST_AFTER[1]))
	if wind.finished.is_connected(wind.play):
		wind.finished.disconnect(wind.play)
		wind.finished.connect(_wind_again)
		_wind_again()
	for i in range(GUSTS):
		var g := AudioStreamPlayer.new()
		g.bus = "SFX"
		g.volume_db = -80.0
		add_child(g)
		gusts.append({"player": g, "t": 0.0, "len": 0.0})
	gust_t = randf_range(float(FIRST_AFTER[0]), float(FIRST_AFTER[1]))
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


## The band a moan this far away is heard in: [from, pitch, bus].
static func moan_band(d: float) -> Array:
	var band: Array = MOAN_BANDS[0]
	for b in MOAN_BANDS:
		if d >= float(b[0]):
			band = b
	return band


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
		for p in [bed, wind]:
			p.volume_db = -80.0
		for g: Dictionary in gusts:
			(g["player"] as AudioStreamPlayer).volume_db = -80.0
		return
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
		_tick_slot(s, at, delta)
	_tick_falls(at)
	# The mass: one bed scaled by how many dead are near and how near.
	bed.volume_db = lerpf(bed.volume_db, _db(clampf(crowd / BED_FULL, 0.0, 1.0) * 0.8), minf(1.0, delta * 2.0))
	birds_t = maxf(0.0, birds_t - delta)
	_tick_wind(at, delta)
	engine.volume_db = _db(clampf(1.0 - at.distance_to(engine.position) / 70.0, 0.0, 1.0) * 0.5)
	# Indoor gunfire leaves the ears ringing: everything else ducks.
	var bus := AudioServer.get_bus_index("SFX")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, -18.0 if game.deaf_t > 0.0 else 0.0)


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
	p.bus = String(band[2])
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
	_one_shot("moan", z["pos"], float(row["loud"]) * clampf(1.0 - d / MOAN_RANGE, 0.0, 1.0), float(v["pitch"]) * float(row["pitch"]) * float(band[1]), lib["moan"][i], String(band[2]), float(row["cut"]))


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


## The bed comes round again at a new place in its file, never the start.
func _wind_again() -> void:
	if wind.stream == null:
		return
	wind.play(randf_range(0.0, 0.6) * wind.stream.get_length())


func _tick_wind(at: Vector3, delta: float) -> void:
	wind_t += delta
	wind_up += delta
	var outdoor: bool = not game.grid_at(at).indoor(game.FieldGrid.cell_of(at))
	var level: float = (0.25 + 0.5 * wind_strength()) * (1.0 if outdoor else 0.35)
	# Getting down: the wind comes up from nothing, not on at once.
	level *= smoothstep(0.0, 1.0, clampf(wind_up / wind_in, 0.0, 1.0))
	# The bed wanders on a slow noise: no two stretches alike, no beat to it.
	var n: float = drift.get_noise_1d(wind_t)
	var n2: float = drift.get_noise_1d(wind_t + 977.0)
	wind.volume_db = _db(level * (1.0 + WIND_DRIFT * n))
	wind.pitch_scale = 1.0 + WIND_PITCH_DRIFT * n2
	# Once the train stands (not under the brakes of its coming in), and its
	# own few seconds after (FIRST_AFTER), never the moment one gets down.
	if not howled and game.arrive_t < 0.0 and game.weather.kinds.has("blizzard"):
		howl_wait -= delta
		if howl_wait <= 0.0:
			howled = true
			howl()
	gust_t -= delta
	if gust_t <= 0.0:
		var gap := gust_gap(wind_strength())
		gust_t = randf_range(gap.x, gap.y)
		_gust(randf_range(float(GUST_LEN[0]), float(GUST_LEN[1])), randf_range(float(GUST_LOUD[0]), float(GUST_LOUD[1])), false)
	for g: Dictionary in gusts:
		var p: AudioStreamPlayer = g["player"]
		if float(g["len"]) <= 0.0:
			continue
		g["t"] = float(g["t"]) + delta
		var k: float = float(g["t"]) / float(g["len"])
		if k >= 1.0:
			g["len"] = 0.0
			p.stop()
			continue
		# Up to its top and away again, slower on the way out; the pitch bends.
		var top: float = float(g["top"])
		var env: float = sin(0.5 * PI * k / top) if k < top else cos(0.5 * PI * (k - top) / (1.0 - top))
		p.volume_db = _db(level * float(g["peak"]) * env)
		p.pitch_scale = lerpf(float(g["p0"]), float(g["p1"]), smoothstep(0.0, 1.0, k))


## One gust over the bed: a place in the wind file it has not just started at,
## its own length, loudness and bend.
func _gust(length: float, peak: float, howl_layer: bool) -> void:
	if not has("wind"):
		return
	var g: Dictionary = gusts[0]
	for other: Dictionary in gusts:
		if float(other["len"]) <= 0.0:
			g = other
			break
	var stream: AudioStream = lib["wind"][0]
	var full: float = maxf(stream.get_length(), 0.1)
	var last: Array = gust_log.back() if not gust_log.is_empty() else []
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
	gust_log.append([from, length, peak, p0, p1, howl_layer])


## A blizzard comes in: one to three gusts laid together, long, each bending
## its own way, a new shape every time it is heard.
func howl() -> void:
	var layers := randi_range(int(HOWL_LAYERS[0]), int(HOWL_LAYERS[1]))
	for i in range(layers):
		_gust(randf_range(float(HOWL_LEN[0]), float(HOWL_LEN[1])), randf_range(0.6, 1.0), true)
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


## A loose board creaking, for the player's ear (the rule sound is field_game's
## "floor_creak"): its own group once there is one, else the impact set's wood.
func floor_creak(at: Vector3) -> void:
	_voice_or_standin(CREAK_VOICE, CREAK_STANDIN, at)


## A lid dragged off a manhole, for the player's ear only: no rule hears it
## (the dead's coming up is heard as it was).
func lid_scrape(at: Vector3) -> void:
	_voice_or_standin(LID_VOICE, LID_STANDIN, at)


## A one-shot of its own group [group, loudness, pitch low, pitch high], or, until that
## group has a file, the impact file whose name begins with `standin`.
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
	_one_shot(TELL_GROUP if own else "moan", at, TELL_LOUD * clampf(1.0 - d / TELL_RANGE, 0.0, 1.0), 1.0 if own else TELL_STANDIN_PITCH)


## A blow's own sound (hit_feel.gd), heard to `reach` m and duller through a
## wall. The dead hear the blow by make_sound, not by this.
func feel_sound(group: String, at: Vector3, loud: float, reach: float) -> void:
	if quiet:
		return
	played.append(group)
	var d: float = at.distance_to(game.player.position)
	_one_shot(group, at, loud * clampf(1.0 - d / reach, 0.0, 1.0), randf_range(0.92, 1.08), null, _bus_at(at))


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


func footstep(at: Vector3, running: bool) -> void:
	if has("step_snow"):
		_one_shot("step_snow", at, 0.5 if running else 0.3, randf_range(0.9, 1.1))


## The bus a sound from here goes through: plain, or duller through a wall.
func _bus_at(at: Vector3) -> String:
	return "SFX_MID" if through_wall(at) else "SFX"


## cut > 0: only that many seconds of it are heard, then it fades out fast.
## from: where in the file it starts (seconds).
func _one_shot(group: String, at: Vector3, lin: float, pitch: float, stream: AudioStream = null, bus: String = "SFX", cut: float = 0.0, from: float = 0.0) -> void:
	if lin <= 0.01 or not has(group):
		return
	var o: AudioStreamPlayer3D = one_shots[0]
	for p in one_shots:
		if not p.playing:
			o = p
			break
	o.bus = bus
	last_bus = bus
	o.position = at
	o.stream = stream if stream != null else _pick(group)
	o.volume_db = _db(lin)
	o.pitch_scale = pitch
	o.play(from)
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
