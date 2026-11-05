extends "res://game/actors/person_visual.gd"

var read_events: Array = []
var after_read: Callable


## The frame probes use separate body draw nodes for each person. Report a
## shared node as ambiguous instead of guessing which person an instance is.
## Counts also work with the headless renderer, without reading GPU transforms.
static func appearance(visual, people: Array) -> Dictionary:
	var drawn: Array[String] = []
	var incomplete: Array[String] = []
	var missing := 0
	var ambiguous := 0
	var seen := {}
	for p in people:
		if not is_instance_valid(p) or not p.visible or not visual.body_by.has(p):
			continue
		var d: Dictionary = visual.worn.get(visual.body_by[p], {})
		if d.is_empty():
			continue
		var body_id: int = d["draw"].get_instance_id()
		if seen.has(body_id):
			ambiguous += 1
		seen[body_id] = true
		var count: int = d["draw"].multimesh.visible_instance_count
		if d["own_draw"] != null:
			count += d["own_draw"].multimesh.visible_instance_count
		if count <= 0:
			continue
		drawn.append(String(p.pid))
		var complete := true
		for look: Dictionary in visual.looks_on(p) + visual.bag_on(p):
			var kind: String = look["shell"]
			if not d["wear"].has(kind):
				missing += 1
				complete = false
			elif d["wear"][kind] != null and d["wear"][kind].multimesh.visible_instance_count <= 0:
				complete = false
		if not complete:
			incomplete.append(String(p.pid))
	return {"drawn": drawn, "incomplete": incomplete, "missing": missing, "ambiguous": ambiguous}


func _record_read(kind: String, path: String) -> void:
	read_events.append({"kind": kind, "path": path, "frame": Engine.get_process_frames(),
		"preparing": game != null and game.is_built and game.standing_by})


func _dress(dead_dir: String, own_dir: String) -> Dictionary:
	_record_read("body", own_dir)
	var d: Dictionary = super._dress(dead_dir, own_dir)
	if after_read.is_valid():
		after_read.call("body")
	return d


func garment_of(d: Dictionary, kind: String) -> MultiMeshInstance3D:
	var missing: bool = not d["wear"].has(kind)
	if missing:
		_record_read("garment", String(d["wear_dir"]).path_join(kind))
	var garment: MultiMeshInstance3D = super.garment_of(d, kind)
	if missing and after_read.is_valid():
		after_read.call("garment")
	return garment
