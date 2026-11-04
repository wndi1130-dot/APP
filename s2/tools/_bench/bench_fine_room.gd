extends Node
## Measuring build only (draft PR, never merged): the main scene of a debug APK that times the
## good-goods preview (council_vote.gd fine_room: a deep copy and one workshop stretch) and
## open_conditions for the front car on the phone. Same board as the PC run: the S1 conditions
## board front/true/1 with w6~w8 done, a skill-3 craftsman and supFine 1.0, as it is and with
## every list twenty times as long. Each result is printed (adb logcat -s godot) and shown.

const CouncilVote = preload("res://game/politics/council_vote.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
## A copy of tests/fixtures/train/supplies_vectors.json: the export leaves tests/ out.
const FIXTURE: String = "res://tools/_bench/supplies_vectors.json"
const N: int = 400
const WARMUP: int = 10

var _label: Label = null


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(24.0, 24.0)
	_label.add_theme_font_size_override("font_size", 22)
	add_child(_label)
	# Let the first frames settle before timing.
	for i: int in 30:
		await get_tree().process_frame
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not data is Dictionary:
		_say("BENCH no fixture")
		return
	var t: Dictionary = data["tables"]
	var g: Dictionary = {}
	for row: Dictionary in data["groups"]["conditions"]:
		if row["name"] == "front/true/1":
			g = row["before"].duplicate(true)
	if g.is_empty():
		_say("BENCH no board")
		return
	g["dom"] = TrainDom.start()
	for id: String in ["w6", "w7", "w8"]:
		g["dom"]["techs"][id] = {"stage": "done", "defect": false, "progress": 3, "need": 3}
	g["dom"]["experts"] = [{"field": "craft", "skill": 3}]
	g["supFine"] = 1.0
	_bench("as is", g, t)
	var big: Dictionary = g.duplicate(true)
	for key: Variant in big:
		if big[key] is Array and not (big[key] as Array).is_empty():
			var a: Array = big[key]
			var base: Array = a.duplicate(true)
			for i: int in 19:
				a.append_array(base.duplicate(true))
	_bench("lists x20", big, t)
	_say("BENCH done %s %s" % [OS.get_model_name(), String(Engine.get_version_info()["string"])])


func _bench(label: String, g: Dictionary, t: Dictionary) -> void:
	for which: String in ["fine_room", "open_conditions"]:
		var first: int = _one(which, g, t)
		for i: int in WARMUP - 1:
			_one(which, g, t)
		var took: Array[int] = []
		for i: int in N:
			took.append(_one(which, g, t))
		took.sort()
		var total: int = 0
		for v: int in took:
			total += v
		_say("BENCH %s · %s: first %.3f ms; after warm-up mean %.3f ms, p95 %.3f ms, max %.3f ms over %d" % [label, which, first / 1000.0, float(total) / N / 1000.0, took[int(N * 0.95)] / 1000.0, took[N - 1] / 1000.0, N])


func _one(which: String, g: Dictionary, t: Dictionary) -> int:
	var started: int = Time.get_ticks_usec()
	if which == "fine_room":
		CouncilVote.fine_room(g, t)
	else:
		CouncilVote.open_conditions(g, t, "front")
	return Time.get_ticks_usec() - started


func _say(line: String) -> void:
	print(line)
	_label.text += line + "\n"
