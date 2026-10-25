extends RefCounted
## How loud each kind of sound is, set by the player in the settings (결정 448: 「정지-설정에
## 소리조절버튼없음」) and kept between runs. One bus each, all under Master:
##   Master 전체   everything
##   Music  음악   the background music (music_player.gd); a car's own song is not music
##   SFX    효과   the world: steps, the dead, doors, the train, the wind
##   Voice  목소리 people speaking: the radio, the driver (sound_music 6, layer 2)
## Steps of 10 %; 0 is off. The music's own ducking moves its players, never this bus.

const FieldAudio = preload("res://game/audio/field_audio.gd")

const FILE: String = "user://sound.cfg"
static var where: String = FILE     # tests point this at their own file
const SECTION: String = "levels"
const BUSES: Array[String] = ["Master", "Music", "SFX", "Voice"]
const NAMES: Dictionary = {"Master": "전체", "Music": "음악", "SFX": "효과", "Voice": "목소리"}
const STEP: int = 10
const DEFAULT: int = 100


## Every bus the game sends to, made once with its sends (the SFX bus with its two dull ones).
static func ensure_buses() -> void:
	FieldAudio._ensure_bus()
	for bus in ["Music", "Voice"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


## The saved level of each bus, 0..100 (DEFAULT where nothing is saved).
static func load_levels(path: String = "") -> Dictionary:
	var cfg := ConfigFile.new()
	var ok := cfg.load(_at(path)) == OK
	var out := {}
	for bus in BUSES:
		var v: int = int(cfg.get_value(SECTION, bus, DEFAULT)) if ok else DEFAULT
		out[bus] = clampi(snappedi(v, STEP), 0, 100)
	return out


static func save_levels(levels: Dictionary, path: String = "") -> void:
	var cfg := ConfigFile.new()
	cfg.load(_at(path))
	for bus in BUSES:
		cfg.set_value(SECTION, bus, int(levels.get(bus, DEFAULT)))
	cfg.save(_at(path))


## A level in percent as the bus's dB; 0 mutes it.
static func db_of(percent: int) -> float:
	return -80.0 if percent <= 0 else linear_to_db(percent / 100.0)


static func apply(levels: Dictionary) -> void:
	ensure_buses()
	for bus in BUSES:
		var i := AudioServer.get_bus_index(bus)
		var p := int(levels.get(bus, DEFAULT))
		AudioServer.set_bus_volume_db(i, db_of(p))
		AudioServer.set_bus_mute(i, p <= 0)


## Set one bus, apply and keep it.
static func set_level(bus: String, percent: int, path: String = "") -> Dictionary:
	var levels := load_levels(path)
	levels[bus] = clampi(snappedi(percent, STEP), 0, 100)
	apply(levels)
	save_levels(levels, path)
	return levels


static func apply_saved(path: String = "") -> void:
	apply(load_levels(path))


static func _at(path: String) -> String:
	return where if path == "" else path
