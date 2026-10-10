extends Node3D
## Shader gallery: one graybox yard showing every fx shader under the
## situations of docs/design/briefs/shaders.md 2장. Keys 1-9 and 0 switch preset;
## on the phone the buttons top-left step presets and go back to the start menu
## (the Android back gesture does the same).
## Headless capture (CI or a cloud check, needs a GPU or llvmpipe):
##   godot --path s2 --rendering-driver opengl3 res://fx/gallery.tscn -- --shots=/tmp/shots
## writes one PNG per preset and quits.

const FxState = preload("res://fx/fx_state.gd")
const Smoke = preload("res://fx/smoke.gd")
const StormLook = preload("res://fx/storm_look.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")
const SH := "res://fx/shaders/"

## name, weather kinds, air C, hour, ground snow (-1 = from temperature),
## horde edge frost, tactical pause, train speed m/s.
const PRESETS: Array[Dictionary] = [
	{"name": "1_fog_snow_noon", "kinds": ["fog", "snow"], "c": -14.0, "hour": 12.0, "snow": -1.0, "frost_edge": 0.0, "pause": 0.0, "speed": 12.0},
	{"name": "2_sleet_dusk", "kinds": ["sleet"], "c": -1.0, "hour": 16.0, "snow": 0.3, "frost_edge": 0.0, "pause": 0.0, "speed": 12.0},
	{"name": "3_thaw_rain", "kinds": ["rain"], "c": 4.0, "hour": 11.0, "snow": 0.0, "frost_edge": 0.0, "pause": 0.0, "speed": 18.0},
	{"name": "4_blizzard_night", "kinds": ["blizzard"], "c": -22.0, "hour": 22.0, "snow": -1.0, "frost_edge": 0.0, "pause": 0.0, "speed": 0.0},
	{"name": "5_clear_cold_dawn", "kinds": ["clear"], "c": -8.0, "hour": 7.0, "snow": -1.0, "frost_edge": 0.0, "pause": 0.0, "speed": 0.0},
	{"name": "6_horde_right", "kinds": ["fog"], "c": -6.0, "hour": 13.0, "snow": 0.4, "frost_edge": 0.8, "pause": 0.0, "speed": 0.0},
	{"name": "7_tactical_pause", "kinds": ["fog", "snow"], "c": -14.0, "hour": 12.0, "snow": -1.0, "frost_edge": 0.0, "pause": 1.0, "speed": 12.0},
	# Snow layer thickness 0 / 1 / 2 (seasons_regions.md 7장), overcast -6 C.
	{"name": "8_snow_level_0", "kinds": ["overcast"], "c": -6.0, "hour": 12.0, "snow": 0.0, "frost_edge": 0.0, "pause": 0.0, "speed": 0.0},
	{"name": "9_snow_level_1", "kinds": ["overcast"], "c": -6.0, "hour": 12.0, "snow": 0.38, "frost_edge": 0.0, "pause": 0.0, "speed": 0.0},
	{"name": "10_snow_level_2", "kinds": ["overcast"], "c": -6.0, "hour": 12.0, "snow": 0.9, "frost_edge": 0.0, "pause": 0.0, "speed": 0.0},
	# Three stops around a storm (weather_fx.md 14장). Optional keys: wind
	# (default 0.6), shadows (default true), storm (a StormLook stage: light,
	# snow layers, snow-fog and edge frost come from there). Snow is
	# SnowCover.cover_for of 25 cm before and during, 50 cm after.
	{"name": "11_storm_before", "kinds": ["overcast"], "c": -10.0, "hour": 12.0, "snow": 0.8, "frost_edge": 0.0, "pause": 0.0, "speed": 0.0, "wind": 0.15, "storm": "before"},
	{"name": "12_storm_during", "kinds": ["blizzard"], "c": -22.0, "hour": 12.0, "snow": 0.8, "frost_edge": 0.0, "pause": 0.0, "speed": 0.0, "wind": 0.9, "shadows": false, "storm": "during"},
	{"name": "13_storm_after", "kinds": ["clear"], "c": -25.0, "hour": 12.0, "snow": 0.93, "frost_edge": 0.0, "pause": 0.0, "speed": 0.0, "wind": 0.1, "storm": "after"},
]

var env: Environment
var sun: DirectionalLight3D
var overlay: ColorRect
var backdrop_mat: ShaderMaterial
var window_mats: Array[ShaderMaterial] = []
var snow_fx: GPUParticles3D
var snowcap: MeshInstance3D
var rain_fx: GPUParticles3D
## Storm snow layers by name (StormLook layers), made the first time they show.
var storm_fx: Dictionary = {}
var loco_run: GPUParticles3D
var loco_idle: GPUParticles3D
var ink_mat: ShaderMaterial
var caption: Label
var current := 0
var scroll := 0.0
var speed := 0.0
var _quit_on_back := true


func _ready() -> void:
	# The back gesture returns to the menu instead of closing the app.
	_quit_on_back = get_tree().is_quit_on_go_back()
	get_tree().set_quit_on_go_back(false)
	_build_world()
	_build_props()
	_build_ui()
	apply_preset(0)
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	if shots != "":
		_capture_all.call_deferred(shots)


func _mat(file: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SH + file)
	return m


func _box(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = m
	add_child(mi)
	return mi


## A snow cap for a box top, laid out like tools/blender/tripo_prep.py
## --snowcap makes them: the rim (vertex colour R 0) sits on the surface and
## the inside (R 1) is lifted to the full depth.
func _snowcap_box(top: Vector2, at: Vector3, depth := 0.25, rim := 0.06) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := top.x * 0.5
	var hz := top.y * 0.5
	var outer: Array[Vector3] = [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	var inner: Array[Vector3] = []
	for v in outer:
		inner.append(Vector3(v.x - signf(v.x) * rim, depth, v.z - signf(v.z) * rim))
	var quads: Array = [[inner[0], inner[1], inner[2], inner[3], 1.0, 1.0]]
	for i in range(4):
		var j := (i + 1) % 4
		quads.append([outer[i], outer[j], inner[j], inner[i], 0.0, 1.0])
	for q in quads:
		var shares: Array[float] = [q[4], q[4], q[5], q[5]]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(shares[k], shares[k], shares[k]))
			st.add_vertex(q[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "SnowCap"
	mi.mesh = st.commit()
	mi.position = at
	mi.material_override = _mat("snowcap.gdshader")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _weathered(color: Color, porosity := 0.6, extra := {}) -> ShaderMaterial:
	var m := _mat("weathered.gdshader")
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("porosity", porosity)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return m


func _build_world() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 26.0
	cam.position = Vector3(0, 18, 16)
	cam.rotation_degrees = Vector3(-45, 0, 0)
	cam.far = 200.0
	add_child(cam)
	cam.current = true


func _build_props() -> void:
	# Ground with puddles, a brick house with soot at its foot and a sheltered
	# porch floor, a tarp-covered crate, a rail and sleepers.
	_box(Vector3(60, 0.2, 40), Vector3(0, -0.1, 0), _weathered(Color(0.36, 0.34, 0.31), 0.7, {"puddles": 1.0}))
	_box(Vector3(6, 4, 4), Vector3(-8, 2, -3), _weathered(Color(0.42, 0.33, 0.28), 0.65, {"grime": 0.9, "grime_height": 1.4}))
	_box(Vector3(7, 0.3, 5), Vector3(-8, 4.15, -3), _weathered(Color(0.30, 0.29, 0.29), 0.3))
	_box(Vector3(3, 0.15, 2), Vector3(-8, 0.08, 0.2), _weathered(Color(0.40, 0.38, 0.35), 0.6, {"sheltered": 1.0}))
	_box(Vector3(1.2, 1.0, 1.2), Vector3(-3, 0.5, 2), _weathered(Color(0.45, 0.36, 0.26), 0.8))
	# Snow cap on the crate: grows and shrinks with lying snow (presets 8-10, 13).
	snowcap = _snowcap_box(Vector2(1.2, 1.2), Vector3(-3, 1.0, 2))
	_box(Vector3(1.0, 0.8, 1.6), Vector3(-1.4, 0.4, 2.4), _weathered(Color(0.28, 0.30, 0.32), 0.1, {"metallic": 0.6, "roughness_base": 0.5}))
	for i in range(14):
		_box(Vector3(0.25, 0.12, 2.4), Vector3(-6 + i * 1.6, 0.06, 6.5), _weathered(Color(0.30, 0.26, 0.22), 0.8))
	for z in [5.8, 7.2]:
		_box(Vector3(24, 0.15, 0.08), Vector3(4.4, 0.19, z), _weathered(Color(0.32, 0.30, 0.29), 0.05, {"metallic": 0.8, "roughness_base": 0.45}))
	# A shed with a pitched roof: snow level 2 should take the slopes too.
	_box(Vector3(3, 2, 3), Vector3(-13, 1, 2.5), _weathered(Color(0.38, 0.34, 0.30), 0.8))
	for side in [-1.0, 1.0]:
		var roof := _box(Vector3(1.9, 0.15, 3.4), Vector3(-13 + side * 0.75, 2.45, 2.5), _weathered(Color(0.30, 0.27, 0.25), 0.5))
		roof.rotation_degrees.z = -side * 35.0
	# A passenger car (lived in: lamp on behind frost) and a cold car.
	var car := _weathered(Color(0.25, 0.22, 0.2), 0.5, {"grime": 0.5})
	_box(Vector3(9, 2.6, 2.6), Vector3(5, 1.6, 6.5), car)
	for j in range(4):
		var w := _mat("window_glass.gdshader")
		w.set_shader_parameter("glow_energy", 1.4)
		w.set_shader_parameter("cold_car", 1.0 if j == 3 else 0.0)
		if j == 3:
			w.set_shader_parameter("glow_energy", 0.0)
		window_mats.append(w)
		var pane := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.3, 0.9)
		pane.mesh = q
		pane.material_override = w
		pane.position = Vector3(1.6 + j * 2.2, 2.0, 7.81)
		add_child(pane)
	# Locomotive: running smoke from the chimney, standing steam by the wheels.
	var loco := _weathered(Color(0.16, 0.16, 0.17), 0.1, {"metallic": 0.5, "roughness_base": 0.6, "grime": 0.6})
	_box(Vector3(5, 2.4, 2.4), Vector3(13, 1.5, 6.5), loco)
	_box(Vector3(0.5, 1.0, 0.5), Vector3(14.6, 3.2, 6.5), loco)
	loco_run = Smoke.build("loco_run")
	loco_run.position = Vector3(14.6, 3.8, 6.5)
	loco_run.preprocess = 4.0
	add_child(loco_run)
	loco_idle = Smoke.build("loco_idle")
	loco_idle.position = Vector3(13, 0.3, 7.8)
	loco_idle.preprocess = 2.0
	add_child(loco_idle)
	var stove := Smoke.build("stove")
	stove.position = Vector3(7.5, 3.0, 6.5)
	stove.preprocess = 2.0
	add_child(stove)
	var drift := Smoke.build("low_drift")
	drift.position = Vector3(-5.2, 0.4, -0.8)
	drift.preprocess = 3.0
	add_child(drift)
	# Grass and bare-bush cards.
	var grass := _mat("foliage_wind.gdshader")
	grass.set_shader_parameter("height", 0.7)
	grass.set_shader_parameter("sway", 0.2)
	for i in range(18):
		for r in [0.0, 90.0]:
			var g := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.9, 0.7)
			q.center_offset = Vector3(0, 0.35, 0)
			g.mesh = q
			g.material_override = grass
			g.position = Vector3(-14 + (i % 6) * 1.1, 0, -6 + (i / 6) * 1.3)
			g.rotation_degrees.y = r + i * 23.0
			add_child(g)
	# River strip in front.
	var river := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 6)
	plane.subdivide_width = 1
	river.mesh = plane
	river.position = Vector3(0, 0.02, 12)
	river.material_override = _mat("river_water.gdshader")
	add_child(river)
	snow_fx = _precip(1, 600, Vector2(0.06, 0.06), 4.0, 2.0)
	rain_fx = _precip(0, 700, Vector2(0.03, 0.6), 0.9, 14.0)


func _precip(shape: int, amount: int, size: Vector2, life: float, fall: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.position = Vector3(0, 12, 0)
	p.visibility_aabb = AABB(Vector3(-32, -14, -22), Vector3(64, 16, 44))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, 0.5, 20)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 6.0
	pm.initial_velocity_min = fall * 0.8
	pm.initial_velocity_max = fall
	pm.gravity = Vector3(0, -0.5, 0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = size
	var m := _mat("precip.gdshader")
	m.set_shader_parameter("shape", shape)
	m.set_shader_parameter("opacity", 0.85 if shape == 1 else 0.55)
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p


## One layer of storm snow (StormLook): made once, then only switched and re-aimed.
func _storm_layer(spec: Dictionary, wind_dir: Vector2) -> GPUParticles3D:
	var key := String(spec["name"])
	var p: GPUParticles3D = storm_fx.get(key)
	if p == null:
		p = GPUParticles3D.new()
		p.process_material = ParticleProcessMaterial.new()
		var q := QuadMesh.new()
		q.material = _mat("precip.gdshader")
		p.draw_pass_1 = q
		p.visibility_aabb = AABB(Vector3(-60, -14, -40), Vector3(120, 30, 80))
		add_child(p)
		storm_fx[key] = p
	var dir := StormLook.fall_dir(wind_dir, float(spec["lean"]))
	var fast := float(spec["speed"])
	var high := float(spec["height"])
	# Long enough to cross the yard, whichever way it flies.
	var life := clampf(maxf(high / maxf(-dir.y * fast, 0.01), 0.0) if dir.y < -0.3 else 44.0 / fast, 1.2, 12.0)
	p.amount = int(spec["amount"])
	p.lifetime = life
	p.preprocess = life
	# Start upwind so the layer fills the view as it flies.
	p.position = Vector3(0, high, 0) - Vector3(dir.x, 0, dir.z) * fast * life * 0.5
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, minf(high * 0.4, 3.0), 20)
	pm.direction = dir
	pm.spread = 4.0
	pm.initial_velocity_min = fast * 0.75
	pm.initial_velocity_max = fast
	pm.gravity = Vector3.ZERO
	var q := p.draw_pass_1 as QuadMesh
	q.size = spec["size"]
	var m := q.material as ShaderMaterial
	m.set_shader_parameter("shape", int(spec["shape"]))
	m.set_shader_parameter("opacity", float(spec["opacity"]))
	m.set_shader_parameter("axis", dir)
	m.set_shader_parameter("twinkle", float(spec.get("twinkle", 0.0)))
	return p


## Light, snow layers, snow-fog and edge frost of a storm stage ("" = none).
func _apply_storm(stage: String, wind_dir: Vector2, base_sun: float) -> void:
	var look := StormLook.look(stage)
	var shown: Dictionary = {}
	for spec in look.get("layers", []):
		var p := _storm_layer(spec, wind_dir)
		p.emitting = true
		p.visible = true
		p.restart()
		shown[String(spec["name"])] = true
	for key in storm_fx:
		if not shown.has(key):
			storm_fx[key].emitting = false
			storm_fx[key].visible = false
	var om := overlay.material as ShaderMaterial
	om.set_shader_parameter("front", float(look.get("front", 0.0)))
	om.set_shader_parameter("whiteout", float(look.get("whiteout", 0.0)))
	# The camera looks down the -Z axis from above: world z runs down the screen.
	om.set_shader_parameter("storm_dir", Vector2(wind_dir.x, wind_dir.y * 0.7))
	sun.rotation_degrees.x = float(look.get("sun_pitch", -50.0))
	if look.is_empty():
		return
	sun.light_color = look["sun_color"]
	sun.light_energy = base_sun * float(look["sun"])
	sun.shadow_enabled = bool(look["shadows"])
	env.ambient_light_color = look["ambient_color"]
	om.set_shader_parameter("edge_frost", float(look["edge_frost"]))
	om.set_shader_parameter("frost_dir", Vector2.ZERO)
	# The storm layers stand in for the plain snowfall.
	snow_fx.emitting = false


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.material = _mat("screen_overlay.gdshader")
	layer.add_child(overlay)
	# UI samples, bottom-left: an inked card, a gauge with soot, a frosted panel.
	var row := HBoxContainer.new()
	row.position = Vector2(16, 560)
	row.add_theme_constant_override("separation", 16)
	layer.add_child(row)
	var paper := ColorRect.new()
	paper.color = Color(0.86, 0.82, 0.72)
	paper.custom_minimum_size = Vector2(220, 130)
	ink_mat = _mat("ui_ink.gdshader")
	ink_mat.set_shader_parameter("origin", Vector2(0.15, 0.8))
	ink_mat.set_shader_parameter("rect_aspect", Vector2(220.0 / 130.0, 1.0))
	ink_mat.set_shader_parameter("progress", 0.62)
	paper.material = ink_mat
	row.add_child(paper)
	var gauge := Control.new()
	gauge.custom_minimum_size = Vector2(130, 130)
	row.add_child(gauge)
	var soot := ColorRect.new()
	soot.size = Vector2(130, 130)
	var sm := _mat("ui_soot.gdshader")
	sm.set_shader_parameter("amount", 0.8)
	soot.material = sm
	gauge.add_child(soot)
	var dial := ColorRect.new()
	dial.color = Color(0.82, 0.80, 0.74)
	dial.position = Vector2(35, 35)
	dial.size = Vector2(60, 60)
	gauge.add_child(dial)
	var panel := ColorRect.new()
	panel.color = Color(0.20, 0.19, 0.18)
	panel.custom_minimum_size = Vector2(220, 130)
	row.add_child(panel)
	var fr := ColorRect.new()
	fr.size = Vector2(220, 130)
	var fm := _mat("ui_frost.gdshader")
	fm.set_shader_parameter("amount", 0.7)
	fm.set_shader_parameter("rect_aspect", Vector2(220.0 / 130.0, 1.0))
	fr.material = fm
	panel.add_child(fr)
	# Train window inset, top right: the far horizon card seen from a car.
	var box := SubViewportContainer.new()
	box.position = Vector2(820, 56)
	box.size = Vector2(440, 170)
	box.stretch = true
	layer.add_child(box)
	var vp := SubViewport.new()
	vp.size = Vector2i(440, 170)
	vp.own_world_3d = true
	box.add_child(vp)
	var vcam := Camera3D.new()
	vcam.position = Vector3(0, 0, 10)
	vcam.fov = 40.0
	vp.add_child(vcam)
	var back := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(20, 8)
	back.mesh = bq
	backdrop_mat = _mat("horizon_backdrop.gdshader")
	back.material_override = backdrop_mat
	vp.add_child(back)
	caption = Label.new()
	caption.position = Vector2(16, 12)
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	layer.add_child(caption)
	# Touch controls under the caption: the phone has no number keys.
	var bar := HBoxContainer.new()
	bar.position = Vector2(16, 48)
	bar.theme = UiTheme.make(22)
	bar.add_theme_constant_override("separation", 10)
	layer.add_child(bar)
	for spec in [["BackButton", "메뉴로", back_to_menu], ["PrevButton", "◀ 이전", step.bind(-1)], ["NextButton", "다음 ▶", step.bind(1)]]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.custom_minimum_size = Vector2(120, 56)
		b.pressed.connect(spec[2])
		bar.add_child(b)


func apply_preset(i: int) -> void:
	current = clampi(i, 0, PRESETS.size() - 1)
	var p: Dictionary = PRESETS[current]
	var params := FxState.params_for(p["kinds"], p["c"], Vector2(1, 0.3), float(p.get("wind", 0.6)), p["hour"], p["snow"])
	params["fx_fade"] = p["pause"]
	FxState.apply(params)
	var light := FxState.lighting_for(p["kinds"], p["hour"])
	sun.light_color = light["sun_color"]
	sun.light_energy = light["sun_energy"]
	sun.shadow_enabled = bool(p.get("shadows", true))
	env.ambient_light_color = light["ambient_color"]
	env.ambient_light_energy = light["ambient_energy"]
	env.background_color = Color(params["fx_tint"]).darkened(0.55)
	var night := 1.0 if light["band"] == "night" else 0.0
	backdrop_mat.set_shader_parameter("night", night)
	backdrop_mat.set_shader_parameter("haze", 0.9 if p["kinds"].has("fog") or p["kinds"].has("blizzard") else 0.5)
	for w in window_mats:
		w.set_shader_parameter("speed", p["speed"])
	speed = p["speed"]
	Smoke.update_locomotive(loco_run, loco_idle, speed)
	# Gallery only: hide the switched-off emitter so its old trail is not mistaken
	# for the new state in a capture. In the game the trail fades on its own.
	loco_run.visible = loco_run.emitting
	loco_idle.visible = loco_idle.emitting
	var kinds: Array = p["kinds"]
	snow_fx.emitting = kinds.has("snow") or kinds.has("blizzard") or kinds.has("sleet")
	snow_fx.amount_ratio = 1.0 if kinds.has("blizzard") else 0.5
	rain_fx.emitting = kinds.has("rain") or kinds.has("sleet")
	# Tactical pause: particles hang in the air.
	var frozen: float = 0.0 if float(p["pause"]) > 0.5 else 1.0
	for n in [snow_fx, rain_fx, loco_run, loco_idle]:
		n.speed_scale = frozen if frozen == 0.0 else n.speed_scale
	var om := overlay.material as ShaderMaterial
	om.set_shader_parameter("edge_frost", p["frost_edge"])
	om.set_shader_parameter("frost_dir", Vector2(1, 0) if float(p["frost_edge"]) > 0.0 else Vector2.ZERO)
	om.set_shader_parameter("pause_dim", p["pause"])
	om.set_shader_parameter("vignette", 0.5 if night > 0.0 else 0.3)
	var day_sun: float = FxState.lighting_for(["clear"], p["hour"])["sun_energy"]
	_apply_storm(String(p.get("storm", "")), Vector2(1, 0.3), day_sun)
	caption.text = "%s  |  wet %.2f snow %.2f frost %.2f  |  %s" % [p["name"], params["fx_wet"], params["fx_snow"], params["fx_frost"], light["band"]]


## Next or previous preset, wrapping around.
func step(by: int) -> void:
	apply_preset(posmod(current + by, PRESETS.size()))


func menu_scene() -> String:
	return String(ProjectSettings.get_setting("application/run/main_scene"))


func back_to_menu() -> void:
	get_tree().change_scene_to_file(menu_scene())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_to_menu()


func _exit_tree() -> void:
	get_tree().set_quit_on_go_back(_quit_on_back)


func _process(delta: float) -> void:
	scroll += speed * delta / 400.0
	backdrop_mat.set_shader_parameter("scroll", scroll)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k: int = event.keycode
		if k >= KEY_1 and k <= KEY_9:
			apply_preset(k - KEY_1)
		elif k == KEY_0:
			apply_preset(9)


func _capture_all(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for i in range(PRESETS.size()):
		apply_preset(i)
		for _f in range(12):
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir.path_join(String(PRESETS[i]["name"]) + ".png"))
	get_tree().quit()
