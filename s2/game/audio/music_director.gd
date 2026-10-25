extends RefCounted
## The music's clock (docs/design/briefs/bgm.md 2, 3, 3.1, 5): when a piece starts, how it fades,
## the quiet between pieces, how fast threat music comes and how slowly it goes. It only says what
## to do (`cmds`); music_player.gd does it. Time is the delta it is given and every die is its own
## rng, so a test runs it exactly. With no piece to play it says nothing: silence is the fallback.

const Rules = preload("res://game/audio/music_rules.gd")

## Quiet between pieces (bgm.md 2.1, 4): the gap after a piece ends; night is longer, a clear day
## longer still. An explore piece starts only if, played whole, music stays within MAX_SHARE of the
## stop so far, counted as at least the safe stay (bgm.md 2.1: a 20 min stop, at most half).
const GAP: Array = [60.0, 180.0]
const NIGHT_GAP: float = 1.5
const CLEAR_GAP: float = 2.0
const MAX_SHARE: float = 0.5
const SAFE_STAY: float = 1200.0
const READ_BEAT: float = 45.0        # the stop's first reading beat has no music (bgm.md 3, 30-60 s)
const HORDE_REST: float = 90.0       # no explore piece this long after a horde is gone
const LOSS_REST: float = 180.0       # nor anything after a loss
const TITLE_GAP: float = 20.0
## Threat (bgm.md 2.2, 3): up at once, down only after HOLD, then a stage per STEP; a stage is kept
## at least MIN_STAGE. Fades: seconds for the new piece to come up / the old one to go.
const HOLD: float = 20.0
const STEP: float = 10.0             # 8-12 s a stage
const MIN_STAGE: float = 8.0
const FADE_UP: Array = [0.0, 2.0, 1.0, 0.3, 4.0]   # by stage
const HORDE_DOWN: float = 12.0
const EXPLORE_IN: float = 4.0
const WORSE_FADE: float = 3.0        # the train going worse: the piece goes in 3 s (bgm.md 3.1)
const INDOOR_FADE: float = 3.0
## Levels under the effects bed (bgm.md 6), dB.
const GAIN: Dictionary = {"explore": -6.0, "threat_seen": -3.0, "threat_chase": -3.0, "threat_horde": -3.0, "": 0.0}
const ON_TOP_DB: float = -6.0        # stage 3: only the pulse is meant to stay; one mix, so lower it
const INDOOR_DB: float = -3.0
const UNDER_THREAT_DB: float = -10.0 # chased with no threat piece: the explore piece goes down
const CAR_SONG_DB: float = -12.0     # a car's own song or gramophone is on (bgm.md 3.1, 6)

var rng := RandomNumberGenerator.new()
var have: Dictionary = {}            # piece id -> its length in seconds (the pieces that have a file)
var scene: String = ""               # field, train, title
var now: float = 0.0
var cmds: Array = []                 # {"do": play|fade|gain, "id", "fade", "db"}, taken by the player
var log: Array = []                  # every cmd with its time (tests)
var playing: String = ""
var playing_kind: String = ""
var piece_end: float = 0.0
var db: float = 0.0                  # the level the playing piece was last set to
var last: String = ""
var quiet_until: float = 0.0
var cue_until: float = -1.0          # a cue (return, loss) plays out before anything else
var scene_t: float = 0.0
var music_t: float = 0.0
var stage: int = 0                   # the threat stage the music follows
var stage_since: float = 0.0
var next_down: float = -1.0          # when the next step down is due, -1 while not going down
var row: String = "none"


func start(what: String, pieces: Dictionary, seed_value: int = 0) -> void:
	scene = what
	have = pieces
	rng.seed = seed_value if seed_value != 0 else randi()
	now = 0.0
	scene_t = 0.0
	music_t = 0.0
	stage = 0
	next_down = -1.0
	row = "none"
	quiet_until = READ_BEAT if what == "field" else 0.0


func take() -> Array:
	var out := cmds
	cmds = []
	return out


func tick(delta: float, s: Dictionary = {}) -> void:
	now += delta
	scene_t += delta
	if playing != "":
		music_t += delta
		if now >= piece_end:
			_ended()
	if cue_until >= 0.0:
		if now < cue_until:
			return
		cue_until = -1.0
	match scene:
		"field":
			_field(s)
		"train":
			_train(s)
		"title":
			if playing == "" and now >= quiet_until:
				_play(Rules.pick("title", have, {}, last, rng), 3.0, 0.0)


## A piece played once over whatever was on: return, loss, loss_end, decision (bgm.md 3).
func cue(kind: String) -> void:
	var id := Rules.pick(kind, have, {}, last, rng)
	if id == "":
		return
	_play(id, 2.0, 0.0)
	cue_until = piece_end
	if kind == "loss" or kind == "loss_end":
		quiet_until = piece_end + LOSS_REST


## The brake, the whistle, the omens (bgm.md 6): the music stops and nothing starts for `seconds`.
func hush(seconds: float, fade: float = 0.5) -> void:
	if playing != "":
		_fade_out(fade)
	quiet_until = maxf(quiet_until, now + seconds)


func gap(s: Dictionary = {}) -> float:
	var g := rng.randf_range(float(GAP[0]), float(GAP[1]))
	if String(s.get("band", "day")) == "night":
		g *= NIGHT_GAP
	if (s.get("weathers", []) as Array).has("clear"):
		g *= CLEAR_GAP
	return g


func _field(s: Dictionary) -> void:
	var raw := Rules.threat_stage(s)
	var rose := false
	if raw > stage:
		stage = raw
		stage_since = now
		next_down = -1.0
		rose = true
	elif raw < stage:
		if next_down < 0.0:
			# Released from a grab goes straight back to being chased (bgm.md 3).
			next_down = now + (0.0 if stage == 3 else HOLD)
		if now >= next_down and now - stage_since >= MIN_STAGE:
			var from := stage
			stage = raw if from == 4 else stage - 1
			stage = maxi(stage, raw)
			stage_since = now
			next_down = now + STEP if stage > raw else -1.0
			if from == 4:
				quiet_until = maxf(quiet_until, now + HORDE_REST)
			if stage == 0:
				_fade_out(HORDE_DOWN if from == 4 else STEP)
				if from != 4:
					quiet_until = maxf(quiet_until, now + gap(s))
				return
	else:
		next_down = -1.0
	if stage > 0:
		_threat(s, rose)
		return
	if playing_kind.begins_with("threat"):
		_fade_out(STEP)
		return
	var want := INDOOR_DB if bool(s.get("indoor", false)) else 0.0
	if playing_kind == "explore" and not is_equal_approx(db, float(GAIN["explore"]) + want):
		_gain(float(GAIN["explore"]) + want, INDOOR_FADE)
	if playing == "" and now >= quiet_until:
		var id := Rules.pick("explore", have, s, last, rng)
		if id != "" and _may_explore(s, float(have.get(id, 0.0))):
			_play(id, EXPLORE_IN, float(GAIN["explore"]) + want)


func _threat(s: Dictionary, rising: bool) -> void:
	var kind := Rules.threat_kind(stage)
	var want := float(GAIN[kind]) + (ON_TOP_DB if stage == 3 else 0.0)
	if playing_kind == kind:
		if not is_equal_approx(db, want):
			_gain(want, 1.0)
		return
	var id := Rules.pick(kind, have, s, "", rng)
	if id == "":
		# No threat piece: an explore piece still on goes down under the chase.
		if playing_kind == "explore" and stage >= 2 and not is_equal_approx(db, UNDER_THREAT_DB):
			_gain(UNDER_THREAT_DB, 1.0)
		return
	# Coming up, or again after the piece ran out under a long threat: the short fade. Stepping
	# down from another threat piece: the long cross.
	_play(id, float(FADE_UP[stage]) if rising or playing == "" else STEP, want)


## Explore pieces: none in a blizzard (the wind is the music, bgm.md 4) and not past the share.
func _may_explore(s: Dictionary, length: float) -> bool:
	if (s.get("weathers", []) as Array).has("blizzard"):
		return false
	return music_t + length <= MAX_SHARE * maxf(scene_t + length, SAFE_STAY)


func _train(s: Dictionary) -> void:
	var r := Rules.train_row(s)
	var kind := Rules.row_kind(r)
	var song: bool = bool(s.get("car_song", false))
	if r != row:
		var going_worse := Rules.worse(r, row)
		row = r
		if going_worse:
			# Worse comes at once: the piece on goes in 3 s and the new row needs no gap.
			quiet_until = now
			if playing != "" and playing_kind != kind:
				_fade_out(WORSE_FADE)
	if playing != "":
		var want := CAR_SONG_DB if song else 0.0
		if not is_equal_approx(db, want):
			_gain(want, 0.5 if song else 2.0)
		return
	if kind != "" and not song and now >= quiet_until:
		_play(Rules.pick(kind, have, s, last, rng), WORSE_FADE, 0.0)


func _ended() -> void:
	var was := playing_kind
	playing = ""
	playing_kind = ""
	if was.begins_with("threat") and stage > 0:
		return   # the threat goes on: the next tick plays it again
	if scene == "title":
		quiet_until = now + TITLE_GAP
	else:
		quiet_until = maxf(quiet_until, now + gap())


func _play(id: String, fade: float, level: float) -> void:
	if id == "":
		return
	if playing != "" and playing != id:
		_fade_out(maxf(fade, 0.3))   # one piece at a time: the old one crosses out as the new comes
	_emit({"do": "play", "id": id, "fade": fade, "db": level})
	playing = id
	playing_kind = _kind_of(id)
	piece_end = now + float(have.get(id, 0.0))
	db = level
	last = id


func _fade_out(fade: float) -> void:
	if playing == "":
		return
	_emit({"do": "fade", "id": playing, "fade": fade, "db": -80.0})
	playing = ""
	playing_kind = ""


func _gain(level: float, fade: float) -> void:
	_emit({"do": "gain", "id": playing, "fade": fade, "db": level})
	db = level


func _emit(c: Dictionary) -> void:
	cmds.append(c)
	var logged := c.duplicate()
	logged["t"] = now
	log.append(logged)


static func _kind_of(id: String) -> String:
	for song in Rules.SONGS:
		if song["id"] == id:
			return String(song["kind"])
	return ""
