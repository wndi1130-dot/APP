extends "res://game/actors/person_visual.gd"

var read_events: Array = []


func _record_read(kind: String, path: String) -> void:
	read_events.append({"kind": kind, "path": path, "frame": Engine.get_process_frames(),
		"preparing": game != null and game.is_built and game.standing_by})


func _dress(dead_dir: String, own_dir: String) -> Dictionary:
	_record_read("body", own_dir)
	return super._dress(dead_dir, own_dir)


func garment_of(d: Dictionary, kind: String) -> MultiMeshInstance3D:
	if not d["wear"].has(kind):
		_record_read("garment", String(d["wear_dir"]).path_join(kind))
	return super.garment_of(d, kind)
