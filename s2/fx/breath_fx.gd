extends Node3D
## Breath in the cold (the atmosphere frame, 사용자 2026-10-24 「점점 추워짐」): a
## puff of breath before each living person's face, thicker the colder and the
## darker it is, quicker and fuller when they run. One node for everyone, one
## draw (a MultiMesh of soft cards the shader puffs out and fades), no
## particles leased: it is not smoke (fx/smoke.gd keeps its four kinds) and it
## does not touch the body picture (person_visual.gd). Picture only.

const SHADER := preload("res://fx/shaders/breath.gdshader")
## Most people breathing on screen at once; more are skipped.
const MAX_PUFFS: int = 24
## Head height and how far before the face the puff starts (metres).
const MOUTH_UP: float = 1.52
const MOUTH_OUT: float = 0.22
## Below this strength nothing shows (warm weather).
const MIN_STRENGTH: float = 0.05

var puffs: MultiMeshInstance3D
var material: ShaderMaterial
## How many puffs were drawn last tick (tests, the frame check).
var shown: int = 0


func _init() -> void:
	name = "BreathFx"
	puffs = MultiMeshInstance3D.new()
	puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	mm.mesh = q
	mm.instance_count = MAX_PUFFS
	mm.visible_instance_count = 0
	puffs.multimesh = mm
	material = ShaderMaterial.new()
	material.shader = SHADER
	puffs.material_override = material
	add_child(puffs)


## Every frame from the field: where the living, shown people's faces are and
## how hard they breathe. field: field_game.gd (people, atmo).
func tick(_delta: float, field) -> void:
	var look: Dictionary = field.atmo
	var strength := float(look.get("breath", 0.0))
	var mm := puffs.multimesh
	if strength < MIN_STRENGTH:
		mm.visible_instance_count = 0
		shown = 0
		return
	# Lit by the hour: grey-white by day, dim at night (lanterns light their own).
	material.set_shader_parameter("light", clampf(float(look.get("lum", 1.0)) * 0.9 + 0.12, 0.15, 1.0))
	var n := 0
	for p in field.people:
		if n >= MAX_PUFFS:
			break
		if not is_instance_valid(p) or not p.is_alive() or not p.visible:
			continue
		var fwd := Vector3(sin(p.look), 0.0, cos(p.look))
		var at: Vector3 = p.position + Vector3(0.0, MOUTH_UP, 0.0) + fwd * MOUTH_OUT
		mm.set_instance_transform(n, Transform3D(Basis(), at))
		var run := 1.0 if p.is_running_now() else 0.0
		# x: the person's own breathing phase, y: strength, z: running, w: facing x/z packed.
		mm.set_instance_custom_data(n, Color(p.name_unit(), strength * (1.0 + 0.3 * run), run, 0.0))
		n += 1
	mm.visible_instance_count = n
	shown = n
