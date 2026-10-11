extends RefCounted
## What a companion shouts when something happens to them (user 2026-10-12:
## 'lines too: the companions, as it would really sound'). Words on the screen
## only: no voice. This is the slot; the bank of lines comes from the content
## stream. Until it does, LINES holds the user's own examples.
##
## Who speaks: the one it happened to (or, for "rage", the companion nearest
## to one who fell). The chief does not speak.
## How often: one person at most once in GAP_SELF seconds, the squad at most
## once in GAP_SQUAD, so four people hurt at once do not all shout at once.

const LINES: Dictionary = {
	"hurt": ["시발", "시이이이발..."],
	"bite_leg": ["다리가 물렸어!!"],
	"grabbed": ["살려줘 살려줘!!"],
	"rage": ["이 개새끼들"],
	"left_behind": ["제발... 두고가지마"],
	# Left on the platform as the train goes (user 2026-10-12, in these words).
	"left_platform": ["나도 데리고가 시발새끼들아!!"],
}
## An event with no lines of its own borrows another's.
const FALLBACK: Dictionary = {"bite": "hurt"}
const GAP_SELF: float = 6.0
const GAP_SQUAD: float = 2.0
## Lying hurt or held, and the chief this far off: "left_behind", this often.
const LEFT_BEHIND_M: float = 10.0
const LEFT_BEHIND_GAP: float = 12.0
## A companion this near to one who fell is the one who rages.
const RAGE_NEAR: float = 8.0

var _last_self: Dictionary = {}     # pid -> when they last spoke
var _last_event: Dictionary = {}    # "pid/event" -> when
var _last_any: float = -1000.0
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0x11e5) -> void:
	_rng.seed = seed_value


static func lines_for(event: String) -> Array:
	if LINES.has(event):
		return LINES[event]
	return LINES.get(String(FALLBACK.get(event, "")), [])


## The line `pid` shouts for `event` at `now`, or "" if they keep quiet (no
## such line, or someone has only just spoken).
## `always`: this one is shouted whoever spoke just before (everyone left on
## the platform shouts at once).
func pick(pid: String, event: String, now: float, always: bool = false) -> String:
	var bank: Array = lines_for(event)
	if bank.is_empty():
		return ""
	if not always and (now - float(_last_self.get(pid, -1000.0)) < GAP_SELF or now - _last_any < GAP_SQUAD):
		return ""
	var key: String = pid + "/" + event
	if event == "left_behind" and now - float(_last_event.get(key, -1000.0)) < LEFT_BEHIND_GAP:
		return ""
	_last_self[pid] = now
	_last_event[key] = now
	_last_any = now
	return String(bank[_rng.randi() % bank.size()])
