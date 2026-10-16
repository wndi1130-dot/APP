extends Node3D

signal braking_finished
const Graybox = preload("res://scripts/graybox.gd")
const TrainModels = preload("res://game/world/train_model_kit.gd")
var speed: float = 8.0
var braking: bool = false
var background: Array[MeshInstance3D] = []

func _ready() -> void:
	# The low sun casts shadows here too (decision 323).
	Graybox.environment_for(self, false, true)
	Graybox.box(self, Vector3(80, 0.2, 25), Vector3(0, -0.2, 0), 0.23)
	TrainModels.create_stage(self, true)
	for index in range(12):
		background.append(Graybox.box(self, Vector3(1.8, 4, 1.5), Vector3(index * 4.5 - 27, 1.8, -5), 0.32))
	Graybox.camera_for(self, Vector3(0, 4, 22), Vector3(0, 1, 0), 16)

func brake() -> void:
	braking = true
	# Brake audio placeholder: no external sound resource.

func _process(delta: float) -> void:
	if braking:
		speed = move_toward(speed, 0.0, delta * 4.0)
		if is_zero_approx(speed):
			braking = false
			braking_finished.emit()
	for item in background:
		item.position.x -= speed * delta
		if item.position.x < -29.0:
			item.position.x += 54.0
