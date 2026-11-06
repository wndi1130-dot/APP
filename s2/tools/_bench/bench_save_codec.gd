extends Node
## Measuring build only (draft PR, never merged): the main scene of a debug APK that times
## reading field saves on the phone with the codec check of #1447, against the codec before it.
## The format 2 sample is put in user:// by adb (run-as), not in git: a 6.6 MB field save from a
## local slice resume test, about 200 000 int tags. The format 3 sample is the same stop written
## again by the current encoder, made on a first launch that only prepares it (reading the
## format 2 save there would warm the very first read the next launches time). The twelve cold
## launches after it each time one first read (old or new codec, format 2 or 3, three times each
## in turning order); the launches after those time repeats, a cut-off main file, old and new
## whole reads taking turns, the codec alone in turns, and the int text check alone. Each result
## is printed (adb logcat -s godot) and shown.

const FieldSave = preload("res://game/sim/field_save.gd")
## main 489404a0's game/sim/field_save.gd, the codec before #1447 (the same blob).
const OldSave = preload("res://tools/_bench/old_field_save.gd")
const V2: String = "user://probe_v2.json"
const V3: String = "user://probe_v3.json"
const BROKEN: String = "user://probe_broken.json"
const LAUNCH: String = "user://probe_launch.txt"
const BUILD: String = "#1454 probe on main 55b9d94a"
## The cold launches after the one that prepares: each does only the first read, with this codec
## on this format; every pair of the four comes three times, the order turning each round.
const COLD: Array = [
	["old", "v2"], ["new", "v2"], ["old", "v3"], ["new", "v3"],
	["new", "v2"], ["old", "v2"], ["new", "v3"], ["old", "v3"],
	["old", "v2"], ["new", "v2"], ["old", "v3"], ["new", "v3"],
]
const REPEAT: int = 5
const BROKEN_REPEAT: int = 3
const READ_PAIR_RUNS: int = 6
const PAIR_RUNS: int = 9
const INT_TEXTS: int = 200000

var _label: Label = null


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(24.0, 24.0)
	_label.add_theme_font_size_override("font_size", 20)
	add_child(_label)
	# Let the first frames settle before timing.
	for i: int in 30:
		await get_tree().process_frame
	await _run()
	# The phone keeps the results on screen until force-stop; a desktop run (the PC check before
	# the APK is built) ends by itself.
	if not OS.has_feature("android"):
		get_tree().quit()


func _run() -> void:
	var head: String = "%s %s user %s" % [OS.get_model_name(), String(Engine.get_version_info()["string"]), OS.get_user_data_dir()]
	if not FileAccess.file_exists(V2):
		_say("BENCH no sample %s · %s" % [V2, head])
		return
	if not FileAccess.file_exists(V3):
		_prepare(head)
		return
	var launch: int = _next_launch()
	_say("BENCH start launch %d · %s · %s" % [launch, BUILD, head])
	if launch <= COLD.size():
		_cold(launch, COLD[launch - 1][0], COLD[launch - 1][1])
		_say("BENCH done launch %d" % launch)
		return
	for path: String in [V2, V3]:
		await _repeat(launch, path)
	await _broken(launch)
	for path: String in [V2, V3]:
		await _read_pairs(launch, path)
	for path: String in [V2, V3]:
		await _pairs(launch, path)
	_int_texts(launch)
	_say("BENCH done launch %d" % launch)


## The first read in this process, the way boot meets a save, with one codec on one format.
## Only this one read happens in a cold launch, so nothing before it warms the codec.
func _cold(launch: int, which: String, format: String) -> void:
	var path: String = V2 if format == "v2" else V3
	var started: int = Time.get_ticks_usec()
	var read: Dictionary = OldSave.read(path) if which == "old" else FieldSave.read(path)
	var took: int = Time.get_ticks_usec() - started
	_say("BENCH launch %d cold first read %s %s codec: %.1f ms ok=%s" % [launch, _name(path), which, took / 1000.0, not read.is_empty()])


## Whole reads (file, JSON parse, codec, whole-save checks) with the old and the new codec
## taking turns, old-new then new-old, so a slow stretch of the phone falls on both.
func _read_pairs(launch: int, path: String) -> void:
	var olds: Array[int] = []
	var news: Array[int] = []
	var gaps: Array = []
	var ok: bool = true
	for i: int in READ_PAIR_RUNS:
		var turn: Array = ["old", "new"] if i % 2 == 0 else ["new", "old"]
		var took: Dictionary = {}
		for which: String in turn:
			var started: int = Time.get_ticks_usec()
			var read: Dictionary = OldSave.read(path) if which == "old" else FieldSave.read(path)
			took[which] = Time.get_ticks_usec() - started
			ok = ok and not read.is_empty()
			await get_tree().process_frame
		olds.append(int(took["old"]))
		news.append(int(took["new"]))
		gaps.append(float(int(took["new"]) - int(took["old"])) / float(maxi(int(took["old"]), 1)))
	gaps.sort()
	_say("BENCH launch %d read pairs %s (%d rounds, old-new/new-old): old median %.1f least %.1f ms · new median %.1f least %.1f ms · new vs old median %+.1f%% (least %+.1f%%, most %+.1f%%) ok=%s" % [
		launch, _name(path), READ_PAIR_RUNS, _median(olds) / 1000.0, _least(olds) / 1000.0, _median(news) / 1000.0, _least(news) / 1000.0,
		gaps[int(gaps.size() / 2.0)] * 100.0, gaps[0] * 100.0, gaps[gaps.size() - 1] * 100.0, ok])


## Makes the format 3 sample from the format 2 one: read with the current codec, written whole
## by the current encoder at the current version.
func _prepare(head: String) -> void:
	var saved: Dictionary = FieldSave.read(V2)
	if saved.is_empty():
		_say("BENCH prepare failed: %s does not read · %s" % [V2, head])
		return
	var again: Dictionary = saved.duplicate(true)
	again["version"] = FieldSave.VERSION
	var text: String = FieldSave.to_json(again)
	if not _store(V3, text):
		_say("BENCH prepare failed: %s not written · %s" % [V3, head])
		return
	var back: Dictionary = FieldSave.read(V3)
	_say("BENCH prepared %s bytes=%d int_tags=%d reads=%s · %s" % [V3, text.to_utf8_buffer().size(), _int_tags(text), not back.is_empty(), head])


## FieldSave.read again and again (file, JSON parse, codec, whole-save checks), and the JSON
## parse alone, so the codec's share shows.
func _repeat(launch: int, path: String) -> void:
	var reads: Array[int] = []
	var parses: Array[int] = []
	var ok: bool = true
	for i: int in REPEAT:
		var started: int = Time.get_ticks_usec()
		ok = ok and not FieldSave.read(path).is_empty()
		reads.append(Time.get_ticks_usec() - started)
		var text: String = FileAccess.get_file_as_string(path)
		started = Time.get_ticks_usec()
		var parsed: Variant = JSON.parse_string(text)
		parses.append(Time.get_ticks_usec() - started)
		ok = ok and parsed is Dictionary
		await get_tree().process_frame
	_say("BENCH launch %d repeat %s: read median %.1f least %.1f ms · JSON parse median %.1f least %.1f ms over %d ok=%s" % [
		launch, _name(path), _median(reads) / 1000.0, _least(reads) / 1000.0, _median(parses) / 1000.0, _least(parses) / 1000.0, REPEAT, ok])


## The main file cut off ("{") with a good backup beside it: read falls to the backup.
func _broken(launch: int) -> void:
	for source: String in [V3, V2]:
		var backup: String = FileAccess.get_file_as_string(source)
		if not _store(BROKEN, "{") or not _store(BROKEN + ".bak", backup):
			_say("BENCH launch %d broken: files not written" % launch)
			return
		var reads: Array[int] = []
		var ok: bool = true
		for i: int in BROKEN_REPEAT:
			var started: int = Time.get_ticks_usec()
			ok = ok and not FieldSave.read(BROKEN).is_empty()
			reads.append(Time.get_ticks_usec() - started)
			await get_tree().process_frame
		_say("BENCH launch %d broken main + %s backup: read median %.1f least %.1f ms over %d ok=%s" % [
			launch, _name(source), _median(reads) / 1000.0, _least(reads) / 1000.0, BROKEN_REPEAT, ok])
	for at: String in [BROKEN, BROKEN + ".bak"]:
		DirAccess.remove_absolute(at)


## The codec alone on the parsed JSON, three pairs taking turns in one loop: old/old and new/new
## give the noise of this phone at this moment, old/new the codec's gap inside it.
func _pairs(launch: int, path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_say("BENCH launch %d pairs %s: does not parse" % [launch, _name(path)])
		return
	var old_value: Variant = OldSave.decode_checked(parsed)
	var new_value: Variant = FieldSave.decode_checked(parsed)
	var same: bool = old_value != null and new_value != null and old_value == new_value
	old_value = null
	new_value = null
	var gaps: Dictionary = {"old_old": [], "new_new": [], "old_new": []}
	var olds: Array[int] = []
	var news: Array[int] = []
	for i: int in PAIR_RUNS:
		for key: String in gaps:
			var first: int = _decode_time(key.get_slice("_", 0), parsed, olds, news)
			var second: int = _decode_time(key.get_slice("_", 1), parsed, olds, news)
			(gaps[key] as Array).append(float(second - first) / float(maxi(first, 1)))
		await get_tree().process_frame
	var line: String = "BENCH launch %d pairs %s (%d rounds, same=%s): old median %.1f least %.1f ms · new median %.1f least %.1f ms" % [
		launch, _name(path), PAIR_RUNS, same, _median(olds) / 1000.0, _least(olds) / 1000.0, _median(news) / 1000.0, _least(news) / 1000.0]
	for key: String in gaps:
		var g: Array = (gaps[key] as Array).duplicate()
		g.sort()
		line += " · %s median %+.1f%% (p25 %+.1f%%, p75 %+.1f%%)" % [key, g[int(g.size() / 2.0)] * 100.0, g[int(g.size() / 4.0)] * 100.0, g[int(g.size() * 3 / 4.0)] * 100.0]
	_say(line)


func _decode_time(which: String, parsed: Variant, olds: Array[int], news: Array[int]) -> int:
	var started: int = Time.get_ticks_usec()
	if which == "old":
		OldSave.decode_checked(parsed)
	else:
		FieldSave.decode_checked(parsed)
	var took: int = Time.get_ticks_usec() - started
	if which == "old":
		olds.append(took)
	else:
		news.append(took)
	return took


## The int tag text check alone against the unchecked int() it replaced, per text.
func _int_texts(launch: int) -> void:
	var texts: Array[String] = []
	for i: int in INT_TEXTS:
		texts.append(str(i * 7919 - 100000000))
	var started: int = Time.get_ticks_usec()
	var checked: int = 0
	for text: String in texts:
		if FieldSave._int_of_text(text) != null:
			checked += 1
	var check_took: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var total: int = 0
	for text: String in texts:
		total += int(text)
	var plain_took: int = Time.get_ticks_usec() - started
	_say("BENCH launch %d int text x%d: checked %.1f ms (%.2f us each, %d read) · plain int() %.1f ms (%.2f us each, sum %d)" % [
		launch, INT_TEXTS, check_took / 1000.0, float(check_took) / INT_TEXTS, checked, plain_took / 1000.0, float(plain_took) / INT_TEXTS, total])


func _next_launch() -> int:
	var launch: int = 1
	if FileAccess.file_exists(LAUNCH):
		launch = FileAccess.get_file_as_string(LAUNCH).strip_edges().to_int() + 1
	_store(LAUNCH, str(launch))
	return launch


func _store(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	var error: Error = file.get_error()
	file.close()
	return error == OK


func _int_tags(text: String) -> int:
	return text.count("\"$type\":\"int\"")


func _name(path: String) -> String:
	return "format 2" if path == V2 else "format 3"


func _median(values: Array[int]) -> float:
	var sorted: Array[int] = values.duplicate()
	sorted.sort()
	return float(sorted[int(sorted.size() / 2.0)])


func _least(values: Array[int]) -> float:
	var sorted: Array[int] = values.duplicate()
	sorted.sort()
	return float(sorted[0])


func _say(line: String) -> void:
	print(line)
	_label.text += line + "\n"
