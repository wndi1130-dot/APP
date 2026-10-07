extends Node3D
## Graybox sound (sound_music 12.1): the least that makes a horde felt.
## Files are dropped into res://audio/<group>/ (CC0 only, rights_ledger);
## a missing group is simply silent, so the field runs with no files at all.
##   moan       single moans, the nearest few dead get their own (max 6)
##   horde_bed  one loop for the mass, louder with more and nearer dead
##   gather     far moans gathering, raised when a horde sets off
##   birds      a flock taking off, once when a horde sets off
##   impact     noisy actions (kick, glass, pry, lid, pickaxe, fights)
##   gun        shots (falls back to impact, lower)
##   step_snow  the player's footsteps
##   wind       outdoor bed
##   train_idle the waiting engine, placed on the train
##   whistle    departure
## Buses: Master and SFX. Indoor gunfire's deafness (field 8.2) ducks SFX.

const GROUPS: Array[String] = ["moan", "horde_bed", "gather", "birds", "impact", "gun", "step_snow", "wind", "train_idle", "whistle"]
const MOAN_SLOTS: int = 6
const MOAN_RANGE: float = 25.0
const BED_RANGE: float = 40.0
const BED_FULL: float = 12.0          # this much weighted crowd is a full bed
const GATHER_TIME: float = 14.0
const IMPACT_TAGS: Array[String] = ["kick", "glass", "pry", "bang", "lid", "salvage", "pickaxe", "fight", "fall", "melee", "impact", "ladder", "bell"]
const ENGINE_CELL := Vector2i(92, 2)

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
	engine.position = game.FieldGrid.center(ENGINE_CELL)
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
	pick_t -= delta
	if pick_t <= 0.0:
		pick_t = 0.4
		_assign_moans(at)
	for s in slots:
		_tick_slot(s, at, delta)
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
		p.stream = _pick("moan")
		p.pitch_scale = randf_range(0.85, 1.1)
		p.play()


# ---------------------------------------------------------------- events

## A horde sets off: far moans gather, and once in a while birds go up.
func horde_started() -> void:
	gather_t = GATHER_TIME
	if birds_t <= 0.0 and has("birds"):
		birds_t = 90.0
		_one_shot("birds", game.player.position + Vector3(0, 0, -20), 0.7, 1.0)


## A sound the dead can hear is also one the player hears (field make_sound).
func on_sound(at: Vector3, level: int, tag: String) -> void:
	var group := ""
	if tag == "whistle":
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
	if lin <= 0.01:
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
