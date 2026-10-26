extends RefCounted
## S1 ration_cut.ts: the tail's demand after 비상식량감축법 stands (결정 091·430)
## and the answer it gets. The answer moves the cars' ration standing and
## what the law saves; repealing the law takes the standing back (politics
## council_vote.gd repeal_law). Values are the tables' RATION_CUT.


static func apply(g: Dictionary, t: Dictionary, pick: String) -> void:
	if not (g.get("passed", {}) as Dictionary).has("emergency_ration") or g.get("rationCut") != null:
		return
	var sit: float = float(t["RATION_CUT"]["sit"])
	var base: Dictionary = {}
	if pick == "spare_tail":
		base = {"tail": sit}
	elif pick == "front_first":
		base = {"tail": sit, "front": -sit}
	for c: String in base:
		g["comms"][c]["base"][1] = float(g["comms"][c]["base"][1]) + float(base[c])
	g["rationCut"] = {"pick": pick, "base": base}


## Repealing the law: take back what the answer gave and the demand not yet answered.
static func revert(g: Dictionary) -> void:
	g["cards"] = (g["cards"] as Array).filter(func(row: Dictionary) -> bool: return row["kind"] != "ration_cut")
	var rc: Variant = g.get("rationCut")
	if not rc is Dictionary:
		return
	for c: String in rc["base"]:
		g["comms"][c]["base"][1] = float(g["comms"][c]["base"][1]) - float(rc["base"][c])
	g.erase("rationCut")


## The law's foodAdd under the answer: sparing the tail saves less.
static func food(g: Dictionary, t: Dictionary, v: float) -> float:
	var rc: Variant = g.get("rationCut")
	return float(t["RATION_CUT"]["spareFood"]) if rc is Dictionary and rc.get("pick") == "spare_tail" else v
