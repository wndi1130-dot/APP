extends MeshInstance3D
## The world outside the train (presentation_motion.md 7b, the atmosphere
## frame): one card hung behind the train from its camera, painted by
## outside_view.gdshader from an Atmosphere look and the region band. It keeps
## to the camera's size and aim, and the ground runs by while the train runs.
## Only the train's look changes it; it adds no light and no rules.
##   var outside := OutsideView.attach(train.camera, look)

const Atmosphere = preload("res://fx/atmosphere.gd")
const SHADER := preload("res://fx/shaders/outside_view.gdshader")
## How far behind the camera the card hangs (the train camera sees 120 m).
const DEPTH: float = 105.0
## Ground speed while running (m/s): fence posts 3.2 m apart pass about four a second.
const RUN_SPEED: float = 13.0
## How fast the run eases in and out when the train starts or stops.
const EASE: float = 0.6

var camera: Camera3D
var material: ShaderMaterial
var look: Dictionary = {}
## Running (the ground flows) or standing at a stop.
var moving: bool = true
var speed: float = 0.0
var scroll: float = 0.0


static func attach(cam: Camera3D, l: Dictionary, running := true) -> MeshInstance3D:
	var v = load("res://fx/outside_view.gd").new()
	v.camera = cam
	v.moving = running
	v.speed = RUN_SPEED if running else 0.0
	cam.add_child(v)
	v.set_look(l)
	return v


func _init() -> void:
	name = "OutsideView"
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	mesh = q
	material = ShaderMaterial.new()
	material.shader = SHADER
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3(0, 0, -DEPTH)
	# Behind everything: it never hides the train however its box is sorted.
	sorting_offset = -1000.0
	extra_cull_margin = 400.0


## Paint from this look (Atmosphere.look).
func set_look(l: Dictionary) -> void:
	look = l
	var reg: Dictionary = Atmosphere.region(String(l.get("region", Atmosphere.DEFAULT_REGION)))
	var w: Dictionary = l["weights"]
	var m := material
	m.set_shader_parameter("sky_top", l["sky_top"])
	m.set_shader_parameter("sky_low", l["sky_low"])
	m.set_shader_parameter("sun_glow", l["sun_glow"])
	_set_photo_skies(l.get("skies", []))
	m.set_shader_parameter("lamp", l["lamp"])
	m.set_shader_parameter("sun_col", l["sun_color"])
	m.set_shader_parameter("sun_e", float(l["sun_energy"]))
	m.set_shader_parameter("fill_col", l["ambient_color"])
	m.set_shader_parameter("fill_e", float(l["ambient_energy"]))
	# The view looks across the line to the south: morning sun to the left.
	m.set_shader_parameter("sun_at", Vector2(-float(l["sun_azimuth"]) / 55.0, float(l["sun_height"])))
	m.set_shader_parameter("sun_vis", float(l["sun_visible"]))
	m.set_shader_parameter("cloud", float(l["cloud"]))
	m.set_shader_parameter("haze", float(l["haze"]))
	m.set_shader_parameter("veil", float(l["veil"]))
	m.set_shader_parameter("lum", float(l["lum"]))
	m.set_shader_parameter("night", float(w["night"]))
	m.set_shader_parameter("snow", FxSnow.cover(int(l["snow_level"])))
	m.set_shader_parameter("ice", float(l["ice"]))
	m.set_shader_parameter("wet", clampf(float(l["fall"]) * float(l["wet_ground"]) + (0.4 if String(l["season"]) in ["early_thaw", "late_autumn"] else 0.0) * float(l["wet_ground"]), 0.0, 1.0))
	m.set_shader_parameter("leaves", float(l["leaves"]))
	for key in ["forest", "conifer", "birch", "water", "town", "hills", "spire", "silo", "mist"]:
		m.set_shader_parameter(key, float(reg[key]))
	m.set_shader_parameter("catenary", 1.0 if String(reg["poles"]) == "catenary" else 0.0)
	m.set_shader_parameter("falling", float(l["fall"]) if String(l["falls"]) in ["rain", "sleet"] else float(l["fall"]) * 0.5)


## The look's photo skies on the card's three slots (the drawn sky alone if
## none is in this build).
func _set_photo_skies(skies: Array) -> void:
	var slots: Array = ["sky_a", "sky_b", "sky_c"]
	var w := Vector3.ZERO
	var hue := Vector3(0.25, 0.25, 0.25)
	var n := 0
	for row in skies:
		if n >= slots.size():
			break
		var key := String(row[0])
		var tex := Atmosphere.sky_texture(key)
		if tex == null or float(row[1]) <= 0.0:
			continue
		material.set_shader_parameter(slots[n], tex)
		w[n] = float(row[1])
		hue[n] = float(Atmosphere.SKY_PHOTOS[key]["hue"])
		n += 1
	var total := w.x + w.y + w.z
	material.set_shader_parameter("sky_w", w / total if total > 0.0 else Vector3(1, 0, 0))
	material.set_shader_parameter("sky_hue", hue)
	material.set_shader_parameter("photo_on", 1.0 if n > 0 else 0.0)


func _process(delta: float) -> void:
	speed = move_toward(speed, RUN_SPEED if moving else 0.0, RUN_SPEED * delta / EASE)
	scroll += speed * delta
	fit()


## Fill the camera's view and tell the shader where the camera is.
func fit() -> void:
	if camera == null:
		return
	var vp := camera.get_viewport()
	var size := Vector2(vp.get_visible_rect().size) if vp != null else Vector2(16, 9)
	var aspect := size.x / maxf(size.y, 1.0)
	var h := camera.size * 1.1
	scale = Vector3(h * aspect * 0.5, h * 0.5, 1.0)
	var m := material
	m.set_shader_parameter("view_dir", -camera.global_transform.basis.z)
	m.set_shader_parameter("cam_x", camera.global_position.x)
	m.set_shader_parameter("scroll", scroll)


## Lying snow by thickness level, as the field's shaders have it.
class FxSnow:
	static func cover(level: int) -> float:
		return [0.0, 0.55, 0.95][clampi(level, 0, 2)]
