extends RefCounted
## What a companion shouts when something happens to them (user 2026-10-12:
## 'lines too: the companions, as it would really sound'). Words on the screen
## only: no voice. This is the slot; the bank of lines comes from the content
## stream. Until it does, LINES holds the user's own examples.
##
## Who speaks: the one it happened to (or, for "rage", the companion nearest
## to one who fell). The chief does not speak. The one place he does is not
## here: his aside beside the stop's risk line (user decision 187, the lines
## are FieldHoldout.RISK_FEEL). Nowhere else is he given words.
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
## What the companions say of what they see (decision 406, bundle 4). Lines
## from the content stream's bank (coord/fun/콘텐츠_다양성_동료_대사.md, decision
## 117), three voices: each person keeps one voice (voice_of). "{이름}" is the
## name of the one who fell; a line that needs it is not said without one.
const VOICED: Dictionary = {
	"horde_near": {
		"fear": ["저, 저기... 저게 다 뭐야...", "너무 많아... 너무 많아!", "떼로 와요! 떼로!!", "도망가야 해, 지금!"],
		"rough": ["시발... 저게 다 몇이냐.", "이 개새끼들... 떼로 온다!", "망했다, 다 튀어!!"],
		"quiet": ["...무리다.", "많다. 셀 수가 없어.", "조용히. 지금 빠진다."],
	},
	"ammo_out": {
		"fear": ["총알! 총알이 없어!!", "안 나가, 안 나간다고!", "어떡해, 다 썼어...!"],
		"rough": ["시발, 비었어!!", "탄! 탄 남은 사람!!", "에이 씨... 몸으로 때운다!"],
		"quiet": ["...비었다.", "탄 없다. 붙는다.", "마지막 발이었다."],
	},
	"kill": {
		"fear": ["주, 죽었어...? 죽은 거지?", "했어... 내가 했어...", "다시 안 일어나겠지...?"],
		"rough": ["뒈져, 뒈지라고!!", "꺼져, 이 개새끼들아!", "하나 보냈다! 다음!!"],
		"quiet": ["...하나.", "됐다. 다음.", "조용해졌다."],
	},
	"freed": {
		"fear": ["하악, 하악... 떨어졌어...", "죽는 줄 알았어...", "손이... 아직 떨려..."],
		"rough": ["하... 시발, 살았다.", "떨어져, 이 개새끼야!", "한 번만 더 붙어 봐라..."],
		"quiet": ["...풀렸다.", "괜찮다. 안 물렸다.", "...가까웠다."],
	},
	"ally_down": {
		"fear": ["{이름}! 눈 떠, 눈 좀 떠!", "안 돼, 안 돼, 안 돼...!", "누가 좀 도와줘요!!", "{이름}...? 대답 좀 해..."],
		"rough": ["{이름}! 야, 정신 차려!!", "시발... 쓰러졌어, 쓰러졌다고!", "일으켜! 끌고 간다!!"],
		"quiet": ["...{이름}.", "쓰러졌다. 내가 업는다.", "...아직 숨은 붙어 있다."],
	},
	"retreat": {
		"fear": ["가요, 가요! 얼른 가요!", "열차다... 살았다...", "기다려요, 같이 가요!"],
		"rough": ["들었지! 다 튀어!!", "알았어, 간다, 가!", "아직 덜 챙겼는데, 에이 씨."],
		"quiet": ["...간다.", "알았다. 뒤는 내가 본다.", "짐 챙겼다. 돌아간다."],
	},
}
const VOICES: Array = ["fear", "rough", "quiet"]
## An event with no lines of its own borrows another's.
const FALLBACK: Dictionary = {"bite": "hurt"}
const GAP_SELF: float = 6.0
const GAP_SQUAD: float = 2.0
## Lying hurt or held, and the chief this far off: "left_behind", this often.
const LEFT_BEHIND_M: float = 10.0
const LEFT_BEHIND_GAP: float = 12.0
## A companion this near to one who fell is the one who rages.
const RAGE_NEAR: float = 8.0
## Said often, so one person says it at most this often (the bank's 4th part).
const EVENT_GAP: Dictionary = {"left_behind": LEFT_BEHIND_GAP, "kill": 30.0}
## Seen by several at once, so only one of the squad says it this often.
const SQUAD_GAP: Dictionary = {"horde_near": 20.0, "ally_down": 3.0}

var _last_self: Dictionary = {}     # pid -> when they last spoke
var _last_event: Dictionary = {}    # "pid/event" -> when
var _last_any: float = -1000.0
var _last_line: Dictionary = {}     # pid -> the line they said last
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0x11e5) -> void:
	_rng.seed = seed_value


static func lines_for(event: String, voice: String = "") -> Array:
	if VOICED.has(event):
		var by: Dictionary = VOICED[event]
		if by.has(voice):
			return by[voice]
		var all: Array = []
		for v in VOICES:
			all.append_array(by[v])
		return all
	if LINES.has(event):
		return LINES[event]
	return LINES.get(String(FALLBACK.get(event, "")), [])


## The voice a person keeps, from their id (until people carry one).
static func voice_of(pid: String) -> String:
	return String(VOICES[absi(pid.hash()) % VOICES.size()])


## The line `pid` shouts for `event` at `now`, or "" if they keep quiet (no
## such line, or someone has only just spoken).
## `always`: this one is shouted whoever spoke just before (everyone left on
## the platform shouts at once).
## `name`: who fell, for the lines that call them by name.
func pick(pid: String, event: String, now: float, always: bool = false, name: String = "") -> String:
	var bank: Array = []
	for line in lines_for(event, voice_of(pid)):
		if name != "" or not String(line).contains("{이름}"):
			bank.append(line)
	if bank.is_empty():
		return ""
	if not always and (now - float(_last_self.get(pid, -1000.0)) < GAP_SELF or now - _last_any < GAP_SQUAD):
		return ""
	var key: String = pid + "/" + event
	if now - float(_last_event.get(key, -1000.0)) < float(EVENT_GAP.get(event, 0.0)):
		return ""
	if now - float(_last_event.get("*/" + event, -1000.0)) < float(SQUAD_GAP.get(event, 0.0)):
		return ""
	_last_self[pid] = now
	_last_event[key] = now
	_last_event["*/" + event] = now
	_last_any = now
	# Not the same line twice running.
	var line: String = String(bank[_rng.randi() % bank.size()])
	if bank.size() > 1 and line == String(_last_line.get(pid, "")):
		line = String(bank[(bank.find(line) + 1) % bank.size()])
	_last_line[pid] = line
	return line.replace("{이름}", name)
