extends Node3D
## Graybox sound (sound_music 12.1): the least that makes a horde felt.
## Files are dropped into res://audio/<group>/ (CC0 only, rights_ledger);
## a missing group is simply silent, so the field runs with no files at all.
##   moan       single moans, the nearest few dead get their own (max 6);
##              farther ones are lower and duller (MOAN_BANDS)
##   horde_bed  one loop for the mass, louder with more and nearer dead
##   gather     far moans gathering, raised when a horde sets off
##   birds      a flock taking off, once when a horde sets off
##   impact     noisy actions (kick, glass, pry, lid, pickaxe, fights)
##   gun        shots (falls back to impact, lower)
##   step_snow  the player's footsteps
##   wind       outdoor bed
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

const GROUPS: Array[String] = ["moan", "horde_bed", "gather", "birds", "impact", "gun", "step_snow", "wind", "train_idle", "whistle", "pen", "radio_hiss", "radio", "fall_hit", "fall_reel", "fall_knee", "fall_land", "door_bang", "door_wall", "door_break"]
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
const GATHER_TIME: float = 14.0
const IMPACT_TAGS: Array[String] = ["kick", "glass", "pry", "bang", "lid", "salvage", "pickaxe", "fight", "fall", "melee", "impact", "ladder", "bell"]

var game
var lib: Dictionary = {}               # group -> Array[AudioStream]
var slots: Array = []                  # {"player": AudioStreamPlayer3D, "z": Dictionary, "wait": float}
var bed: AudioStreamPlayer
var gather: AudioStreamPlayer
var wind: AudioStreamPlayer
var engine: AudioStreamPlayer3D
var one_shots: Array = []
var gather_t: float = 0.0
var birds_t: float = 0.0
var pick_t: float = 0.0
var crowd: float = 0.0                 # weighted dead near the player (for the bed)
var last_tag_group: String = ""        # what the last make_sound played (tests)
var held: bool = false                 # the depart note is up
var departing: bool = false            # '떠난다' plays its own whistle
var played: Array = []                 # groups played, in order (tests)
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
	gather = _loop_player("gather")
	wind = _loop_player("wind")
	engine = AudioStreamPlayer3D.new()
	engine.bus = "SFX"
	engine.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	add_child(engine)
	engine.position = game.FieldGrid.center(game.data["anchors"]["engine"])
	if has("train_idle"):
		engine.stream = lib["train_idle"][0]
		engine.finished.connect(engine.play)
		engine.play()
	for i in range(6):
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
		for p in [bed, gather, wind]:
			p.volume_db = -80.0
		return
	if held:
		# The note is up: the bed stays where it was, lower; nothing new starts.
		for s in slots:
			var p: AudioStreamPlayer3D = s["player"]
			p.volume_db = maxf(-80.0, p.volume_db - 40.0 * delta)
		return
	pick_t -= delta
	if pick_t <= 0.0:
		pick_t = 0.4
		_assign_moans(at)
	for s in slots:
		_tick_slot(s, at, delta)
	_tick_falls(at)
	# The mass: one bed scaled by how many dead are near and how near.
	bed.volume_db = lerpf(bed.volume_db, _db(clampf(crowd / BED_FULL, 0.0, 1.0) * 0.8), minf(1.0, delta * 2.0))
	gather_t = maxf(0.0, gather_t - delta)
	birds_t = maxf(0.0, birds_t - delta)
	gather.volume_db = lerpf(gather.volume_db, _db(clampf(gather_t / GATHER_TIME, 0.0, 1.0) * 0.6), minf(1.0, delta * 1.5))
	var outdoor: bool = not game.grid_at(at).indoor(game.FieldGrid.cell_of(at))
	wind.volume_db = _db((0.25 + 0.5 * float(game.weather.wind)) * (1.0 if outdoor else 0.35))
	engine.volume_db = _db(clampf(1.0 - at.distance_to(engine.position) / 70.0, 0.0, 1.0) * 0.5)
	# Indoor gunfire leaves the ears ringing: everything else ducks.
	var bus := AudioServer.get_bus_index("SFX")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, -18.0 if game.deaf_t > 0.0 else 0.0)


## The nearest moving dead on the floors you see get a voice of their own.
func _assign_moans(at: Vector3) -> void:
	var near: Array = []
	crowd = 0.0
	for z in game.zombies.list:
		if not game.zombies.threat(z) or z["state"] == "frozen" or z["state"] == "downed":
			continue
		var d: float = z["pos"].distance_to(at)
		if d < BED_RANGE:
			crowd += 1.0 - d / BED_RANGE
		if d < MOAN_RANGE and game.level_shown(game.level_of(z["pos"])):
			near.append([d, z])
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
		free.pop_back()["z"] = z


func _tick_slot(s: Dictionary, at: Vector3, delta: float) -> void:
	var z: Dictionary = s["z"]
	var p: AudioStreamPlayer3D = s["player"]
	if z.is_empty():
		return
	p.position = z["pos"]
	var d: float = z["pos"].distance_to(at)
	p.volume_db = _db(clampf(1.0 - d / MOAN_RANGE, 0.0, 1.0) * (1.0 if z["state"] in ["chase", "attack", "grab"] else 0.6))
	s["wait"] = float(s["wait"]) - delta
	if s["wait"] <= 0.0 and has("moan"):
		s["wait"] = randf_range(2.5, 6.0) if z["state"] != "chase" else randf_range(1.5, 3.5)
		var band: Array = moan_band(d)
		p.stream = _pick("moan")
		p.pitch_scale = randf_range(0.85, 1.1) * float(band[1])
		p.bus = String(band[2])
		p.play()


# ---------------------------------------------------------------- events

## The depart note goes up (true) or away (false; the mix is back in 0.3 s).
func hold(on: bool) -> void:
	held = on
	if on:
		bed.volume_db -= 9.0
		gather.volume_db -= 9.0
	else:
		bed.volume_db += 9.0
		gather.volume_db += 9.0


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
	_one_shot(group, where, loud * clampf(1.0 - d / FALL_RANGE, 0.0, 1.0), randf_range(float(beat[2]), float(beat[3])))


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


## A horde sets off: far moans gather, and once in a while birds go up.
func horde_started() -> void:
	gather_t = GATHER_TIME
	if birds_t <= 0.0 and has("birds"):
		birds_t = 90.0
		_one_shot("birds", game.player.position + Vector3(0, 0, -20), 0.7, 1.0)


## The radio on the chief (decisions 032): "hiss" before a call, then the call;
## an urgent one (a horde coming in, time to leave) is the loudest.
const RADIO_LOUD: Dictionary = {"hiss": 0.35, "call": 0.6, "urgent": 1.0}


func radio(kind: String) -> void:
	var group := "radio_hiss" if kind == "hiss" else "radio"
	played.append(group)
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
	_one_shot(group if has(group) else "impact", at, loud * clampf(1.0 - d / 60.0, 0.0, 1.0), randf_range(float(v[2]), float(v[3])))


## A sound the dead can hear is also one the player hears (field make_sound).
func on_sound(at: Vector3, level: int, tag: String) -> void:
	if quiet:
		return
	var group := ""
	if tag == "whistle":
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
	_one_shot(group, at, lin, 0.7 if tag == "gun" and group == "impact" else randf_range(0.9, 1.1))


func footstep(at: Vector3, running: bool) -> void:
	if has("step_snow"):
		_one_shot("step_snow", at, 0.5 if running else 0.3, randf_range(0.9, 1.1))


func _one_shot(group: String, at: Vector3, lin: float, pitch: float) -> void:
	if lin <= 0.01 or not has(group):
		return
	var o: AudioStreamPlayer3D = one_shots[0]
	for p in one_shots:
		if not p.playing:
			o = p
			break
	o.position = at
	o.stream = _pick(group)
	o.volume_db = _db(lin)
	o.pitch_scale = pitch
	o.play()
