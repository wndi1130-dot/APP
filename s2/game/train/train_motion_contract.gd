extends RefCounted
## A bridge, not an animation implementation. The gesture worker owns the backend.

const Backend = preload("res://game/train/train_gesture.gd")
const LEGACY := ["argue", "whisper", "turn_about", "arms_crossed", "back_turned", "hug_knees", "slump", "drag_walk", "bowl_sit", "rub_stamp"]
## window_watch borrows a gesture that keeps the body facing its pane.
const FALLBACK := {
	"chat_talk": "whisper", "chat_listen": "whisper", "look_around": "turn_about",
	"window_watch": "arms_crossed", "stand_point": "argue", "fist_raise": "argue",
	"shove_body": "argue", "bang_object": "argue", "stomp": "rub_stamp",
	"wave_hat": "arms_crossed", "wave_paper": "arms_crossed", "bang_table": "argue",
	"eat_bowl": "bowl_sit", "drink_cup": "bowl_sit", "catch_breath": "slump",
	"warm_hands_stand": "rub_stamp", "warm_hands_crouch": "rub_stamp",
	"drag_feet": "drag_walk",
}
const SEATED := ["sit_bench", "lie_bunk", "sleep_lean_wall", "read_book", "mend_cloth", "tend_sick"]
const FLOOR := ["sit_floor", "kneel", "mourn_kneel", "child_draw_floor"]
## Names that bow the head where the body already is, without naming a pose.
const BOWED := ["head_down", "mourn_stand", "hat_off"]


static func has_method_on(script: Script, method: String) -> bool:
	for row in script.get_script_method_list():
		if String(row["name"]) == method:
			return true
	return false


static func resolve(requested: String, script: Script = Backend) -> Dictionary:
	var pose := "floor" if FLOOR.has(requested) else ("sit" if SEATED.has(requested) else "stand")
	var native: bool = has_method_on(script, "knows") and bool(script.call("knows", requested))
	# An old name counts only while the real backend still draws it.
	var old: bool = LEGACY.has(requested) and Backend.knows(requested)
	var name: String = requested if native or old else String(FALLBACK.get(requested, ""))
	if name != "" and not native and not old and not Backend.knows(name):
		name = ""
	return {"requested": requested, "gesture": name, "pose": pose, "native": native, "fallback": not native and not old}


static func show(body: Node3D, requested: String, time: float, role: int = 0, phase: String = "loop") -> Dictionary:
	var resolved := resolve(requested)
	var facing: float = _base_facing(body)
	var rest: String = rest_pose(body, requested)
	# A borrowed old gesture brings its own base pose: where that is not the pose the
	# body's place gives it, it stood the body up, sat it down or dropped it to the
	# floor, so it is not drawn.
	if bool(resolved["fallback"]) and String(resolved["gesture"]) != "" and _moves_off(String(resolved["gesture"]), rest):
		resolved["gesture"] = ""
	body.set_meta("life_motion", resolved)
	body.set_meta("life_phase", phase)
	if String(resolved["gesture"]) != "":
		var name: String = resolved["gesture"]
		if bool(resolved["native"]) and not Backend.spec(name).is_empty():
			var row: Dictionary = Backend.spec(name)
			var part: String = phase if row["stages"].has(phase) else ("once" if row["kind"] == "once" else "loop")
			Backend.show_phase(body, name, part, time, role, facing, false, String(body.pose))
		else:
			Backend.show(body, name, time, role, facing)
	else:
		Backend.show(body, "", 0.0, 0, facing)
		# Only a name that means a pose changes it, and the place's pose with it; "" or
		# any other name takes the gesture's arms and turn off and puts the body back in
		# its place's pose.
		if SEATED.has(requested) or FLOOR.has(requested):
			body.set_pose(resolved["pose"], false)
			body.set_meta("life_rest_pose", String(resolved["pose"]))
		elif BOWED.has(requested):
			body.set_pose(rest, bool(body.huddled), true)
		elif String(body.pose) != rest:
			body.set_pose(rest, false)
	_turned(body)
	return resolved


## The facing a gesture turns the body from. Each frame draws the gesture's own
## turn on top of it, so it is read off the body only when something else has
## turned or moved the body since this file last did (a walk, a seat, the scene):
## read off a body a gesture still held turned, that turn was added again every
## frame, and a seated body spun round and sat on facing wherever it had stopped.
## A body set down somewhere else counts as turned even when its new facing
## happens to be the one last drawn.
static func _base_facing(body: Node3D) -> float:
	var ours: bool = body.has_meta("life_turned") and is_equal_approx(body.rotation.y, float(body.get_meta("life_turned")))
	if ours:
		ours = (body.position as Vector3).is_equal_approx(body.get_meta("life_turned_at"))
	if not ours or not body.has_meta("life_facing"):
		body.set_meta("life_facing", body.rotation.y)
	return float(body.get_meta("life_facing"))


## Where this file last left the body facing, and where the body stood, for _base_facing.
static func _turned(body: Node3D) -> void:
	body.set_meta("life_turned", body.rotation.y)
	body.set_meta("life_turned_at", body.position)


## The pose a body's place gives it: the one a requested name means, else the one
## the life side set where the body arrived or came back, else the one it is in.
## Gestures change body.pose as they draw, so it is not read off that alone.
static func rest_pose(body: Node3D, requested: String = "") -> String:
	if FLOOR.has(requested):
		return "floor"
	if SEATED.has(requested):
		return "sit"
	if body.has_meta("life_rest_pose"):
		return String(body.get_meta("life_rest_pose"))
	return String(body.pose)


## True when drawing `requested` leaves a body in `pose`: nothing drawn, an upper
## body clip, or a gesture whose base is that pose.
static func keeps_pose(requested: String, pose: String) -> bool:
	if FLOOR.has(requested):
		return pose == "floor"
	if SEATED.has(requested):
		return pose == "sit"
	var name: String = String(resolve(requested)["gesture"])
	if name == "":
		return true
	var row: Dictionary = Backend.spec(name)
	if not row.is_empty() and bool(row.get("upper", false)):
		return true
	return String(Backend.base_of(name)["base"]) == pose


## True when an old gesture with no keyed clip (Backend.show() sets its base
## pose) would put a body into another pose than `pose`.
static func _moves_off(name: String, pose: String) -> bool:
	if not Backend.spec(name).is_empty():
		return false
	return String(Backend.base_of(name)["base"]) != pose


## A caller-owned display run. The game chooses when a motion may start or stop;
## the display keeps its own segment and run id so old exits cannot end a new act.
static func start(body: Node3D, requested: String, run_id: int, role: int = 0, context: Dictionary = {}) -> bool:
	var resolved: Dictionary = resolve(requested)
	var name: String = resolved["gesture"]
	if not bool(resolved["native"]) or Backend.spec(name).is_empty():
		return false
	if int(Backend.spec(name)["people"]) == 2:
		return false
	if body.has_meta("life_player") and bool(body.get_meta("life_player").call("active")):
		return false
	var player = Backend.new()
	if not player.begin(name, role, run_id, String(body.pose), context):
		return false
	body.set_meta("life_player", player)
	_base_facing(body)
	body.set_meta("life_motion", resolved)
	body.set_meta("life_phase", player.segment)
	return true


## Both sides are admitted together, using actual positions and readiness facts
## supplied by the scene. A rejected second role cannot leave A running alone.
static func start_shove_pair(a: Node3D, b: Node3D, run_id: int, ready_a: Dictionary, ready_b: Dictionary, name: String = "shove_body") -> bool:
	if not _pair_clip(name):
		return false
	if a == null or b == null or a == b or a.get_parent() != b.get_parent():
		return false
	if a.position.is_equal_approx(b.position):
		return false
	if a.has_meta("life_player") or b.has_meta("life_player"):
		return false
	var anchors: Array = [a.position, b.position]
	var a_context: Dictionary = ready_a.duplicate(true)
	var b_context: Dictionary = ready_b.duplicate(true)
	a_context["anchors"] = anchors
	b_context["anchors"] = anchors
	var first = Backend.new()
	var second = Backend.new()
	if not first.begin(name, 0, run_id, String(a.pose), a_context):
		return false
	if not second.begin(name, 1, run_id, String(b.pose), b_context):
		return false
	for actor in [a, b]:
		actor.set_meta("life_facing", actor.rotation.y)
		actor.set_meta("life_motion", resolve(name))
		actor.set_meta("life_phase", "once")
	a.set_meta("life_player", first)
	b.set_meta("life_player", second)
	return true


static func step(body: Node3D, delta: float, confirmed: bool = false) -> Dictionary:
	if not body.has_meta("life_player"):
		return {}
	var player = body.get_meta("life_player")
	player.advance(delta)
	var phase: String = player.segment
	body.set_meta("life_phase", phase)
	if not player.active():
		var pose: String = player._exit_base
		body.set_pose(pose, false)
		Backend.show(body, "", 0.0, 0, float(body.get_meta("life_facing", body.rotation.y)))
		_turned(body)
		body.remove_meta("life_player")
		return {"phase": "done", "run_id": player.run_id}
	var rendered: Dictionary = player.frame(confirmed)
	Backend.show_sample(body, rendered, float(body.get_meta("life_facing", body.rotation.y)))
	_turned(body)
	player.observed(rendered)
	return {"phase": phase, "run_id": player.run_id}


static func cancel(body: Node3D, run_id: int, next_pose: String = "stand") -> bool:
	if not body.has_meta("life_player"):
		return false
	var player = body.get_meta("life_player")
	var ended: bool = player.cancel(run_id, next_pose)
	if ended:
		body.set_meta("life_phase", "exit")
	return ended


## Both bodies are sampled at one time from their real, distinct places.
## The caller owns the contact result and does not move the two here.
static func show_shove_pair(a: Node3D, b: Node3D, time: float, confirmed: bool = false, run_id: int = 0, name: String = "shove_body") -> bool:
	if not _pair_clip(name):
		return false
	if a == null or b == null or a == b or a.get_parent() != b.get_parent():
		return false
	for body in [a, b]:
		if not body.has_meta("life_player"):
			return false
		var player = body.get_meta("life_player")
		if player.run_id != run_id or player.clip != name or player.segment != "once":
			return false
		if player.role != (0 if body == a else 1):
			return false
		if player.pair_anchors.size() != 2:
			return false
		if not (player.pair_anchors[0] as Vector3).is_equal_approx(a.position):
			return false
		if not (player.pair_anchors[1] as Vector3).is_equal_approx(b.position):
			return false
	var joined: Dictionary = Backend.pair_at(name, a.position, b.position, time, confirmed, run_id)
	if joined.is_empty():
		return false
	a.set_meta("life_facing", float(joined["facings"][0]))
	b.set_meta("life_facing", float(joined["facings"][1]))
	Backend.show_sample(a, joined["roles"][0], joined["facings"][0])
	Backend.show_sample(b, joined["roles"][1], joined["facings"][1])
	_turned(a)
	_turned(b)
	a.get_meta("life_player").observed(joined["roles"][0], time)
	b.get_meta("life_player").observed(joined["roles"][1], time)
	return true


static func cancel_shove_pair(a: Node3D, b: Node3D, run_id: int, next_pose: String = "stand") -> bool:
	var first = a.get_meta("life_player") if a != null and a.has_meta("life_player") else null
	var second = b.get_meta("life_player") if b != null and b.has_meta("life_player") else null
	return Backend.cancel_pair(first, second, run_id, next_pose)


static func finish_removed(body: Node3D, run_id: int) -> bool:
	if not body.has_meta("life_player"):
		return false
	var player = body.get_meta("life_player")
	if not player.finish_offscreen(run_id):
		return false
	body.remove_meta("life_player")
	return true


## Two-person one-off rows go through the pair entries above, never start().
static func _pair_clip(name: String) -> bool:
	var row: Dictionary = Backend.spec(name)
	return not row.is_empty() and int(row["people"]) == 2 and row["kind"] == "once"
