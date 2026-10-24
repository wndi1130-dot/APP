extends Node3D
## How the train's people look (user request 2026-10-24): the field's baked body in place of
## the capsule and ball, with the train's own motions (train_clips.gd, folder
## n5-crew_seamstress_t). It only reads the bodies the train scene moves (where
## each is, which way it faces, its pose, its gesture, the life activity it is
## at) and the car's numbers, and decides nothing. A car shows its state by
## what its few drawn people do: cold huddles, shivers and crowds round the
## stove; hunger holds an empty bowl; exposure coughs; tension argues; the
## guard car keeps watch, the dining car cooks, the medical car tends the sick.
## Four multimeshes, one a coat, carry every drawn body of the train.
## Without the folder, or with the field's switch off, nothing is drawn here
## and the capsules stay.

const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const TrainClips = preload("res://game/train/train_clips.gd")
const Gesture = preload("res://game/train/train_gesture.gd")
const Look = preload("res://game/train/train_look.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const Rules = preload("res://game/train/train_rules.gd")

const SETTING: String = "visuals/baked_people_enabled"   # the field's switch (person_visual.gd)
const MAX_PEOPLE: int = 240
## Four worn coats over the one body's picture (tint / 0.5): faded neutral, brown,
## grey-blue and dark, so a bench of people is not one colour. No uniform among them.
const COATS: Array = [Vector3(0.44, 0.43, 0.41), Vector3(0.6, 0.46, 0.34), Vector3(0.34, 0.4, 0.5), Vector3(0.3, 0.3, 0.31)]
const SIT_FORWARD: float = 0.3           # metres: the baked seat is this far behind the feet
const BED_HEIGHT: float = 0.47           # one lying on a bench or a bed lies on its top
const COUGH_FROM: float = 60.0           # exposure from which some of a cold car cough (first value)
const STOVE_NEAR: float = 1.6            # metres: one huddled this close to the stove holds its hands out to it

var scene                                 # train_scene.gd
var baked: Dictionary = {}
var draws: Array = []
var clip_index: Dictionary = {}
var drawn: Dictionary = {}                # body -> clip name last drawn, for the tests and the shots


static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, true)) and ResourceLoader.exists(TrainClips.FOLDER.path_join("clips.json"))


func setup(train_scene) -> void:
	scene = train_scene
	name = "PeopleView"
	process_priority = 100               # after the scene has moved and posed everyone
	baked = DeadBody.with_albedo(BodyBake.load_baked(TrainClips.FOLDER), TrainClips.FOLDER)
	if baked.is_empty():
		return
	var clips: Array = baked["clips"]
	for n in clips.size():
		clip_index[String(clips[n]["name"])] = n
	var tables := VatBaker.shader_tables(baked)
	for coat in COATS:
		var one := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = baked["mesh"]
		mm.instance_count = MAX_PEOPLE
		mm.visible_instance_count = 0
		mm.custom_aabb = AABB(Vector3(-20, -3, -5), Vector3(400, 10, 10))
		one.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://game/actors/dead_vat.gdshader")
		mat.set_shader_parameter("vat", baked["texture"])
		for key in tables:
			mat.set_shader_parameter(key, tables[key])
		mat.set_shader_parameter("tint", coat)
		one.material_override = mat
		one.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(one)
		draws.append(one)


func is_worn() -> bool:
	return not draws.is_empty()


func _process(_delta: float) -> void:
	if draws.is_empty() or scene == null:
		return
	var counts: Array = []
	counts.resize(COATS.size())
	counts.fill(0)
	drawn.clear()
	for c in scene.cars:
		var state := car_state(c)
		for b in c["bodies"]:
			if not is_instance_valid(b):
				continue
			_hide_boxes(b)
			if not b.visible:
				continue
			var key: int = absi(b.get_instance_id())
			var coat: int = key % COATS.size()
			if counts[coat] >= MAX_PEOPLE:
				continue
			var clip := clip_for(b, state, activity_of(b), key)
			drawn[b] = clip
			var mm: MultiMesh = (draws[coat] as MultiMeshInstance3D).multimesh
			mm.set_instance_transform(counts[coat], place_of(b, clip, state))
			var shade: float = lerpf(0.72, 1.0, float(key % 97) / 96.0) * (0.9 if state["freezing"] else 1.0)
			var phase: float = float(key % 1009) / 1009.0
			mm.set_instance_custom_data(counts[coat], Color(phase, VatBaker.pack_motion(int(clip_index.get(clip, 0))), 0.0, shade))
			counts[coat] += 1
	for i in draws.size():
		(draws[i] as MultiMeshInstance3D).multimesh.visible_instance_count = counts[i]


## What a car is in, for picking motions: its numbers and kind, read only.
func car_state(c: Dictionary) -> Dictionary:
	var comm := Rules.comm_of(scene.rules, c["def"])
	var w := Look.warmth(comm)
	var view: Dictionary = scene.rules.get("view", {})
	return {
		"layout": Catalog.layout_id(c["def"]), "warmth": w, "cold": w < Look.WARM_COLD, "freezing": w < Look.WARM_FREEZING,
		"exposure": float((comm.get("sit", [0, 0, 0, 0]) as Array)[3]) if not comm.is_empty() else 0.0,
		"night": String(view.get("daytime", "day")) == "night", "stove_x": _stove_x(c),
	}


func _stove_x(c: Dictionary) -> float:
	var at: float = 7.85
	for row in Catalog.layout(c["def"])["props"]:
		if String(row.get("system", "")) == "stove":
			at = float(row["at"][0])
	return float(c["x0"]) + at


func activity_of(b) -> String:
	var a: Dictionary = scene.life.actors.get(b.get_instance_id(), {})
	return String(a.get("activity", ""))


## The motion one body is in, from its pose, its gesture, the activity it is at
## and its car's state. `key` picks among equals the same way every frame.
static func clip_for(b, state: Dictionary, activity: String, key: int) -> String:
	var pose: String = String(b.pose)
	var gesture: String = String(b.gesture)
	if pose == "walk":
		return "t_carry" if activity == "carry" or String(b.errand.get("id", "")) in ["carry", "coal", "food"] else "t_walk"
	match activity:
		"warm":
			return "t_warm_hands"
		"sleep", "heal":
			return "t_lie"
		"cook":
			return "t_stir"
		"serve", "eat":
			return "t_eat"
		"care", "work", "mend":
			return "t_kneel_work"
		"chat", "teach":
			return "t_talk" if pose == "stand" else "t_sit_talk"
		"refuge":
			return "t_crouch"
		"mourn":
			return "t_fold"
		"watch":
			return "t_lantern" if state["layout"] == "guard" else ("t_shiver" if state["freezing"] else "t_stand")
	match pose:
		"sit":
			if gesture == Gesture.BOWL_SIT:
				return "t_eat"
			if b.huddled or b.bowed:
				return "t_sit_huddle"
			if String(b.act) == "lean":
				return "t_sit_talk"
			if state["freezing"] and key % 2 == 0:
				return "t_sit_huddle"
			if state["night"] and key % 3 != 0:
				return "t_sit_doze"
			return "t_sit_talk" if key % 4 == 0 else "t_sit"
		"floor":
			if gesture == Gesture.SLUMP:
				return "t_lie"
			if gesture == Gesture.HUG_KNEES:
				return "t_floor_sit"
			if b.huddled:
				return "t_warm_hands" if absf(b.global_position.x - float(state["stove_x"])) < STOVE_NEAR else "t_crouch"
			return "t_floor_sit"
	# On its feet.
	match gesture:
		Gesture.ARGUE:
			return "t_talk" if Gesture.speaking(Time.get_ticks_msec() / 1000.0, int(b.gesture_role)) > 0.5 else "t_no"
		Gesture.WHISPER:
			return "t_talk"
		Gesture.ARMS_CROSSED, Gesture.BACK_TURNED:
			return "t_fold"
		Gesture.RUB_STAMP:
			return "t_shiver"
		Gesture.TURN_ABOUT:
			return "t_stand"
	if gesture != "" and Gesture.knows(gesture):
		# The rest and protest gestures: a body that speaks up or holds itself still.
		return "t_talk" if gesture.contains("riot") or gesture.contains("protest") or gesture.contains("shout") else "t_stand"
	if String(b.act) == "rise":
		return "t_talk"
	if state["cold"] and float(state["exposure"]) >= COUGH_FROM and key % 3 == 0:
		return "t_cough"
	if state["layout"] == "guard":
		return "t_lantern" if state["night"] else "t_fold"
	if state["freezing"]:
		return "t_shiver"
	if state["cold"] and key % 2 == 0:
		return "t_fold"
	return "t_stand"


## Where the baked body stands for a body of the scene: its place and facing,
## the seat brought over the bench, the lying turned along the bunk.
func place_of(b, clip: String, _state: Dictionary) -> Transform3D:
	var yaw: float = b.global_rotation.y
	var at: Vector3 = b.global_position
	var basis := Basis(Vector3.UP, yaw)
	match clip:
		"t_sit", "t_sit_talk", "t_sit_huddle", "t_sit_doze", "t_eat":
			if String(b.pose) == "sit":
				at += basis * Vector3(0, 0, SIT_FORWARD)
		"t_lie":
			# Along the car, on the bench or bed it was sat on, or on the floor.
			basis = Basis(Vector3.UP, PI * 0.5)
			if String(b.pose) == "sit":
				at.y += BED_HEIGHT
	return Transform3D(basis, at)


## The capsule, the ball, the gesture's arm boxes and the held bowl go while a body is worn.
func _hide_boxes(b) -> void:
	for child in b.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
