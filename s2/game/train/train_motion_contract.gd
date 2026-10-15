extends RefCounted
## A bridge, not an animation implementation. The gesture worker owns the backend.

const Backend = preload("res://game/train/train_gesture.gd")
const LEGACY := ["argue", "whisper", "turn_about", "arms_crossed", "back_turned", "hug_knees", "slump", "drag_feet", "bowl_sit", "rub_stamp"]
const FALLBACK := {
	"chat_talk": "whisper", "chat_listen": "whisper", "look_around": "turn_about",
	"window_watch": "turn_about", "stand_point": "argue", "fist_raise": "argue",
	"shove_body": "argue", "bang_object": "argue", "stomp": "rub_stamp",
	"wave_hat": "arms_crossed", "wave_paper": "arms_crossed", "bang_table": "argue",
	"eat_bowl": "bowl_sit", "drink_cup": "bowl_sit", "catch_breath": "slump",
	"warm_hands_stand": "rub_stamp", "warm_hands_crouch": "rub_stamp",
}
const SEATED := ["sit_bench", "lie_bunk", "sleep_lean_wall", "read_book", "mend_cloth", "tend_sick"]
const FLOOR := ["sit_floor", "kneel", "mourn_kneel", "child_draw_floor"]


static func has_method_on(script: Script, method: String) -> bool:
	for row in script.get_script_method_list():
		if String(row["name"]) == method:
			return true
	return false


static func resolve(requested: String, script: Script = Backend) -> Dictionary:
	var pose := "floor" if FLOOR.has(requested) else ("sit" if SEATED.has(requested) else "stand")
	var native: bool = has_method_on(script, "knows") and bool(script.call("knows", requested))
	var name: String = requested if native or LEGACY.has(requested) else String(FALLBACK.get(requested, ""))
	return {"requested": requested, "gesture": name, "pose": pose, "native": native, "fallback": not native and not LEGACY.has(requested)}


static func show(body: Node3D, requested: String, time: float, role: int = 0, phase: String = "loop") -> Dictionary:
	var resolved := resolve(requested)
	body.set_meta("life_motion", resolved)
	body.set_meta("life_phase", phase)
	var facing: float = body.rotation.y
	if String(resolved["gesture"]) != "":
		Backend.show(body, resolved["gesture"], time, role, facing)
	else:
		Backend.show(body, "", 0.0, 0, facing)
		body.set_pose(resolved["pose"], false, requested in ["head_down", "mourn_stand", "hat_off"])
	return resolved
