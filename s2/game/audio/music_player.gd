extends Node
## Plays what music_director.gd says through its own `Music` bus (bgm.md 6), crossfading between
## two players. The pieces are files named by their id (BGM05_TRAIN_B.ogg, .mp3 or .wav) found in
## the first of these that has any: res://audio/music/ (empty until the user picks pieces and the
## terms are checked, bgm.md 9.3), the folder in ZOMBIE_BGM_DIR, user://music/. No file anywhere:
## silence, and the game runs the same.
## The rules' sounds come first (bgm.md 6): duck(kind) lowers the players and lets them back. The
## bus itself is the player's own music level (sound_levels.gd) and is never moved here.

const Director = preload("res://game/audio/music_director.gd")
const MusicInput = preload("res://game/audio/music_input.gd")
const SoundLevels = preload("res://game/audio/sound_levels.gd")

const BUS: String = "Music"
const DIRS: Array[String] = ["res://audio/music"]
const DIR_ENV: String = "ZOMBIE_BGM_DIR"
const USER_DIR: String = "user://music"
const EXTS: Array[String] = ["ogg", "mp3", "wav"]
## What a rule sound does to the music (bgm.md 6): dB, seconds to go down, seconds held after the
## sound, seconds to come back. The lowest held one wins; the same kind again restarts its hold.
const DUCKS: Dictionary = {
	"warning": [-12.0, 0.1, 1.5, 0.8],   # the caller's breath, a horde's warning, an urgent call
	"radio": [-8.0, 0.2, 0.5, 0.5],      # the radio, the doctor, a broadcast
	"near": [-3.0, 0.3, 2.0, 2.0],       # a moan within 8 m, a door broken, a shot
}

var director := Director.new()
var game                              # the field or train scene the input is read from
var streams: Dictionary = {}          # piece id -> AudioStream
var players: Array[AudioStreamPlayer] = []
var held: Array[String] = ["", ""]    # the piece each player has
var fades: Array = []                 # per player: {"to": dB, "rate": dB a second, "stop": bool}
var levels: Array[float] = [-80.0, -80.0]   # each player's faded level; heard at this + duck_db
var ducks: Dictionary = {}            # kind -> seconds left of its hold
var duck_db: float = 0.0
var back_rate: float = 15.0           # dB a second the bus comes back at (the last duck's)


func setup(what: String, scene_node = null, dirs: Array = []) -> void:
	game = scene_node
	SoundLevels.apply_saved()
	var files := find_files(dirs if not dirs.is_empty() else search_dirs())
	var lengths := {}
	for id in files:
		var stream := load_stream(String(files[id]))
		if stream != null and stream.get_length() > 0.0:
			streams[id] = stream
			lengths[id] = stream.get_length()
	for i in range(2):
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		p.volume_db = -80.0
		add_child(p)
		players.append(p)
		fades.append({"to": -80.0, "rate": 0.0, "stop": false})
	director.start(what, lengths)


static func search_dirs() -> Array:
	var out: Array = DIRS.duplicate()
	var env := OS.get_environment(DIR_ENV)
	if env != "":
		out.append(env)
	out.append(USER_DIR)
	return out


## Piece id -> path, from the first folder holding any piece.
static func find_files(dirs: Array) -> Dictionary:
	for dir_path in dirs:
		var found := {}
		var d := DirAccess.open(String(dir_path))
		if d == null:
			continue
		for f in d.get_files():
			var id := f.get_basename()
			if EXTS.has(f.get_extension().to_lower()) and not found.has(id) and Director._kind_of(id) != "":
				found[id] = String(dir_path).path_join(f)
		if not found.is_empty():
			return found
	return {}


static func load_stream(path: String) -> AudioStream:
	if path.begins_with("res://"):
		return load(path) as AudioStream if ResourceLoader.exists(path) else null
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
	return null


func tick(delta: float) -> void:
	var s: Dictionary = {}
	if game != null and director.scene == "field":
		s = MusicInput.field(game)
	elif game != null and director.scene == "train":
		s = MusicInput.train(game)
	director.tick(delta, s)
	for c in director.take():
		_do(c)
	_tick_fades(delta)
	_tick_ducks(delta)


func duck(kind: String) -> void:
	if DUCKS.has(kind):
		ducks[kind] = float(DUCKS[kind][2])


## The field sound's own call when a rule sound plays: the brake stops the music and nothing new
## starts while it lasts; the rest duck by their row and hold at least `seconds`.
func on_hush(kind: String, seconds: float) -> void:
	if kind == "brake":
		director.hush(seconds)
	elif DUCKS.has(kind):
		ducks[kind] = maxf(float(DUCKS[kind][2]), seconds)


## The lowest level the held ducks ask for, dB (0 with none).
static func duck_target(holding: Dictionary) -> float:
	var v := 0.0
	for kind in holding:
		v = minf(v, float(DUCKS[kind][0]))
	return v


func _tick_ducks(delta: float) -> void:
	var down_rate := 0.0
	for kind in ducks.keys():
		var row: Array = DUCKS[kind]
		down_rate = maxf(down_rate, absf(float(row[0])) / float(row[1]))
		back_rate = absf(float(row[0])) / float(row[3])
		ducks[kind] = float(ducks[kind]) - delta
		if float(ducks[kind]) <= 0.0:
			ducks.erase(kind)
	var target := duck_target(ducks)
	duck_db = move_toward(duck_db, target, (down_rate if target < duck_db else back_rate) * delta)
	for i in range(2):
		if players[i].playing:
			players[i].volume_db = levels[i] + duck_db


func _do(c: Dictionary) -> void:
	var id := String(c["id"])
	match String(c["do"]):
		"play":
			if not streams.has(id):
				return
			# The quiet player takes the new piece; the other goes on fading what it had.
			var i := 0
			if players[0].playing and (not players[1].playing or (bool(fades[1]["stop"]) and not bool(fades[0]["stop"]))):
				i = 1
			players[i].stream = streams[id]
			levels[i] = -80.0 if float(c["fade"]) > 0.0 else float(c["db"])
			players[i].volume_db = levels[i] + duck_db
			players[i].play()
			held[i] = id
			_fade_to(i, float(c["db"]), float(c["fade"]), false)
		"fade":
			for i in range(2):
				if held[i] == id and players[i].playing:
					_fade_to(i, -80.0, float(c["fade"]), true)
		"gain":
			for i in range(2):
				if held[i] == id and players[i].playing and not bool(fades[i]["stop"]):
					_fade_to(i, float(c["db"]), float(c["fade"]), false)


func _fade_to(i: int, to: float, seconds: float, stop: bool) -> void:
	var rate := absf(to - levels[i]) / seconds if seconds > 0.0 else 0.0
	fades[i] = {"to": to, "rate": rate, "stop": stop}
	if seconds <= 0.0:
		levels[i] = to


func _tick_fades(delta: float) -> void:
	for i in range(2):
		var p := players[i]
		if not p.playing:
			continue
		var f: Dictionary = fades[i]
		levels[i] = move_toward(levels[i], float(f["to"]), float(f["rate"]) * delta)
		p.volume_db = levels[i] + duck_db
		if bool(f["stop"]) and levels[i] <= -79.0:
			p.stop()
			held[i] = ""
