extends RefCounted
## S1 domestic/pipe.ts: E3 waits for a council result, even after its work is done.

const TrainResearch = preload("res://game/train/train_research.gd")
const TrainWorkshop = preload("res://game/train/train_workshop.gd")
const CouncilLog = preload("res://game/politics/council_log.gd")


static func pending(g: Dictionary) -> Variant:
	var dom: Dictionary = g["dom"] if g.get("dom") is Dictionary else {}
	var st: Dictionary = dom.get("techs", {}).get("e3", {})
	return st.get("variant") if bool(st.get("pending", false)) else null


static func ratify(g: Dictionary, t: Dictionary, passed: bool) -> void:
	var asked: Variant = pending(g)
	if asked == null:
		return
	var dom: Dictionary = g["dom"]
	var st: Dictionary = dom["techs"]["e3"]
	var result: String = String(asked) if passed else ("b" if asked == "a" else "a")
	st["pending"] = false
	st["variant"] = result
	if not passed:
		dom["pipeFlip"] = result
	if dom.get("pipeMoved") != result:
		var sides: Dictionary = TrainResearch.rel_sides("e3", result)
		for comm: String in sides["like"]:
			CouncilLog._bump_rel(g, comm, float(TrainResearch.D["techRel"]), "tech")
		for comm: String in sides["dislike"]:
			CouncilLog._bump_rel(g, comm, -float(TrainResearch.D["techRel"]), "tech")
	dom["pipeMoved"] = result
	if passed:
		if not g.get("contentFlags") is Dictionary:
			g["contentFlags"] = {}
		g["contentFlags"]["ev_achieved"] = true
	var heading: String = "의회가 %s 배관을 추인했다." if passed else "의회가 추인하지 않았다. 배관은 반대쪽으로 놓는다: %s."
	CouncilLog._journal(g, heading % TrainResearch.title(g, "e3") + TrainResearch.reaction("e3", result, t), "good" if passed else "bad")
	if dom.get("restoring") == "e3" and float(st["progress"]) >= float(st["need"]) - 1e-9:
		var finishing: bool = TrainResearch.finish(g, "e3")
		TrainWorkshop.after_restore(g, t, "e3", finishing)
