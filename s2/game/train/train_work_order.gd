extends RefCounted
## S1's task order, repaired on read without changing the saved board.
const DEFAULT: Array[String] = ["parts", "restore", "modify"]
const TASKS: Array[String] = ["parts", "restore", "modify", "sup"]


static func is_order(v: Variant) -> bool:
	if not v is Array:
		return false
	var seen := {}
	for task: Variant in v:
		if not task is String or not TASKS.has(task) or seen.has(task):
			return false
		seen[task] = true
	return true


static func normalized(g: Dictionary) -> Array[String]:
	var d: Dictionary = g.get("dom", {})
	var out: Array[String] = []
	var saved: Variant = d.get("order", DEFAULT)
	if is_order(saved):
		out.assign(saved)
	for i: int in range(DEFAULT.size()):
		if not out.has(DEFAULT[i]):
			out.insert(mini(i, out.size()), DEFAULT[i])
	if d.get("techs", {}).get("w6", {}).get("stage") in ["done", "defective"] and not out.has("sup"):
		out.append("sup")
	return out


static func move(g: Dictionary, task: String, step: int) -> void:
	if not bool(g.get("supOn", false)) or not (step == -1 or step == 1):
		return
	# Loaded here to avoid a preload cycle with train_dom.gd.
	var dom_script = load("res://game/train/train_dom.gd")
	if not dom_script.is_store(g.get("dom")):
		return
	var order: Array[String] = normalized(g)
	var i: int = order.find(task)
	var j: int = i + step
	if i < 0 or j < 0 or j >= order.size():
		return
	order[i] = order[j]
	order[j] = task
	g["dom"]["order"] = order
