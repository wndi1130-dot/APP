extends RefCounted
## One shared clock and role table. Invitation is atomic in the caller's place pool.

var kind: String = ""
var spec: Dictionary = {}
var members: Array = []
var phase: String = "invite"
var elapsed: float = 0.0
var ended: bool = false
var reason: String = ""
var response: String = ""


func setup(p_kind: String, definition: Dictionary) -> void:
	kind = p_kind
	spec = definition
	phase = "invite"
	elapsed = 0.0
	members.clear()
	ended = false


func invite(actor: int, role_index: int) -> bool:
	if phase != "invite" or role_index < 0 or role_index >= spec["roles"].size():
		return false
	for m in members:
		if int(m["actor"]) == actor or int(m["index"]) == role_index:
			return false
	members.append({"actor": actor, "index": role_index, "role": spec["roles"][role_index], "arrived": false})
	return true


func arrive(actor: int) -> void:
	for m in members:
		if int(m["actor"]) == actor:
			m["arrived"] = true
	if phase == "invite" and members.size() == spec["roles"].size() and members.all(func(m): return m["arrived"]):
		_enter("enter")


func advance(delta: float) -> void:
	if ended:
		return
	elapsed += maxf(delta, 0.0)
	match phase:
		"invite":
			if elapsed >= float(spec["invite_timeout"]):
				interrupt("invite_timeout")
		"enter":
			if elapsed >= float(spec["enter"]):
				_enter("loop")
		"loop":
			if elapsed >= float(spec["loop"]):
				_enter("exit")
		"exit":
			if elapsed >= float(spec["exit"]):
				phase = "done"
				ended = true


func interrupt(why: String) -> void:
	if ended or phase == "exit":
		return
	reason = why
	_enter("exit")


func receive(cue: String) -> void:
	response = cue
	if cue in ["interrupt", "accident", "vote", "closed", "depart", "bell", "wrench"]:
		interrupt(cue)


func gesture(actor: int) -> String:
	if ended or phase == "invite":
		return ""
	for m in members:
		if int(m["actor"]) != actor:
			continue
		if response in ["bell", "wrench", "vote"]:
			if m["role"] == "chair" and response != "vote":
				return "ring_bell" if response == "bell" else "bang_flue_wrench"
			return "freeze_look"
		return String(spec["gestures"][int(m["index"])])
	return ""


func role(actor: int) -> int:
	for m in members:
		if int(m["actor"]) == actor:
			var index: int = int(m["index"])
			return int(spec.get("gesture_roles", [])[index]) if spec.has("gesture_roles") else index
	return 0


func _enter(next_phase: String) -> void:
	phase = next_phase
	elapsed = 0.0
