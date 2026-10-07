extends Node3D

signal sequence_finished
const Graybox = preload("res://scripts/graybox.gd")
var camera: Camera3D
var actor: Node3D
var torso: Node3D
var head: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var posture_weight: float = 1.0
var walking_time: float = 0.0
var walking: bool = true
var environment: Environment
var start_camera_transform: Transform3D
var end_camera_transform: Transform3D

func _ready() -> void:
	environment = Graybox.environment_for(self, true)
	Graybox.box(self, Vector3(60, 0.2, 38), Vector3(0, -0.2, 0), 0.3)
	Graybox.train(self)
	Graybox.box(self, Vector3(28, 0.4, 4), Vector3(0, 0, 4), 0.45)
	for index in range(4):
		Graybox.box(self, Vector3(3, 3 + index % 2, 3), Vector3(index * 5 - 8, 1.5, -7), 0.37)
	camera = Graybox.camera_for(self, Vector3(0, 4, 22), Vector3(0, 1, 0), 16)
	start_camera_transform = camera.transform
	camera.position = Vector3(12, 9, 18)
	camera.look_at(Vector3(0, 1, 1), Vector3.UP)
	end_camera_transform = camera.transform
	camera.transform = start_camera_transform
	_build_actor()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_camera_blend, 0.0, 1.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(actor, "position", Vector3(0, 0.2, 4.5), 3.2).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(_finish)

func _build_actor() -> void:
	actor = Node3D.new()
	add_child(actor)
	actor.position = Vector3(0, 0.5, 0.4)
	torso = Node3D.new()
	actor.add_child(torso)
	torso.position.y = 1.1
	Graybox.box(torso, Vector3(0.55, 0.6, 0.3), Vector3.ZERO, 0.7)
	head = Graybox.box(torso, Vector3(0.3, 0.32, 0.3), Vector3(0, 0.5, 0), 0.75)
	left_arm = Graybox.box(torso, Vector3(0.15, 0.65, 0.2), Vector3(-0.38, -0.05, 0), 0.63)
	right_arm = Graybox.box(torso, Vector3(0.15, 0.65, 0.2), Vector3(0.38, -0.05, 0), 0.63)
	left_leg = Graybox.box(actor, Vector3(0.2, 0.65, 0.22), Vector3(-0.17, 0.47, 0), 0.6)
	right_leg = Graybox.box(actor, Vector3(0.2, 0.65, 0.22), Vector3(0.17, 0.47, 0), 0.6)

func _camera_blend(weight: float) -> void:
	camera.transform = start_camera_transform.interpolate_with(end_camera_transform, weight)

func _finish() -> void:
	walking = false
	sequence_finished.emit()

func set_posture(confident: bool) -> void:
	posture_weight = 1.0 if confident else 0.0

func set_fog(enabled: bool) -> void:
	environment.fog_enabled = enabled

func _process(delta: float) -> void:
	# Base locomotion stays independent from the additive upper-body layer.
	walking_time += delta
	var stride := sin(walking_time * 7.0) * (0.3 if walking else 0.0)
	left_leg.rotation.x = stride
	right_leg.rotation.x = -stride
	left_arm.rotation.x = -stride * 0.5
	right_arm.rotation.x = stride * 0.5
	var slump := 1.0 - posture_weight
	torso.rotation.x = slump * 0.22
	head.rotation.x = lerpf(0.22, -0.16, posture_weight)
	left_arm.position.y = -0.05 - slump * 0.12
	right_arm.position.y = -0.05 - slump * 0.12
	# Sigh slot: procedural chest motion, intentionally silent.
	torso.position.y = 1.1 - slump * 0.08 + slump * sin(walking_time * 2.0) * 0.015
