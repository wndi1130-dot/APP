extends "res://addons/gut/test.gd"

const FillMaterial = preload("res://fx/fill_material.gd")


func test_make_selects_shader_and_sets_defaults() -> void:
	var material: ShaderMaterial = FillMaterial.make(Color.WHITE)
	assert_eq(material.shader, preload("res://fx/shaders/fill_std.gdshader"))
	assert_eq(FillMaterial.color_of(material), Color.WHITE)
	assert_eq(material.get_shader_parameter("roughness"), 1.0)
	assert_eq(material.get_shader_parameter("metallic"), 0.0)
	assert_false(material.get_shader_parameter("has_tex"))
	assert_false(material.get_shader_parameter("use_vertex_color"))
	var two_sided: ShaderMaterial = FillMaterial.make(Color.RED, 0.3, 0.7, true)
	assert_eq(two_sided.shader, preload("res://fx/shaders/fill_std_two_sided.gdshader"))
	assert_eq(FillMaterial.color_of(two_sided), Color.RED)
	assert_almost_eq(float(two_sided.get_shader_parameter("roughness")), 0.3, 0.000001)
	assert_almost_eq(float(two_sided.get_shader_parameter("metallic")), 0.7, 0.000001)


func test_color_round_trip_for_fill_and_standard_materials() -> void:
	var materials: Array[Material] = [FillMaterial.make(Color.RED), StandardMaterial3D.new()]
	var tint: Color = Color(0.25, 0.5, 0.75, 0.8)
	for material: Material in materials:
		FillMaterial.set_color(material, tint)
		assert_eq(FillMaterial.color_of(material), tint)
	var other: ShaderMaterial = ShaderMaterial.new()
	FillMaterial.set_color(other, tint)
	assert_eq(FillMaterial.color_of(other), Color.WHITE)
	assert_eq(FillMaterial.color_of(null), Color.WHITE)


func test_from_standard_copies_supported_surface_properties() -> void:
	var source: StandardMaterial3D = StandardMaterial3D.new()
	var texture: GradientTexture2D = GradientTexture2D.new()
	source.albedo_color = Color(0.2, 0.4, 0.6)
	source.albedo_texture = texture
	source.roughness = 0.35
	source.metallic = 0.65
	source.vertex_color_use_as_albedo = true
	source.cull_mode = BaseMaterial3D.CULL_DISABLED
	var material: ShaderMaterial = FillMaterial.from_standard(source) as ShaderMaterial
	assert_not_null(material)
	if material == null:
		return
	assert_eq(material.shader, FillMaterial.TWO_SIDED_SHADER)
	assert_eq(FillMaterial.color_of(material), source.albedo_color)
	assert_eq(material.get_shader_parameter("albedo_tex"), texture)
	assert_true(material.get_shader_parameter("has_tex"))
	assert_true(material.get_shader_parameter("use_vertex_color"))
	assert_almost_eq(float(material.get_shader_parameter("roughness")), source.roughness, 0.000001)
	assert_almost_eq(float(material.get_shader_parameter("metallic")), source.metallic, 0.000001)


func test_same_source_reuses_material_and_refreshes_values() -> void:
	var source: StandardMaterial3D = StandardMaterial3D.new()
	var first: Material = FillMaterial.from_standard(source)
	assert_true(first is ShaderMaterial)
	assert_eq(FillMaterial.from_standard(source), first)
	source.albedo_color = Color.BLUE
	assert_eq(FillMaterial.from_standard(source), first)
	assert_eq(FillMaterial.color_of(first), Color.BLUE)
	var second_source: StandardMaterial3D = StandardMaterial3D.new()
	assert_ne(FillMaterial.from_standard(second_source), first)


func test_transparent_source_is_returned_unchanged() -> void:
	var source: StandardMaterial3D = StandardMaterial3D.new()
	source.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	assert_eq(FillMaterial.from_standard(source), source)


func test_uncopied_features_keep_the_original_material() -> void:
	var settings: Array[Dictionary] = [
		{"emission_enabled": true}, {"normal_enabled": true},
		{"uv1_scale": Vector3(2.0, 1.0, 1.0)}, {"metallic_specular": 0.8},
		{"cull_mode": BaseMaterial3D.CULL_FRONT}, {"next_pass": StandardMaterial3D.new()},
	]
	for setting: Dictionary in settings:
		var source: StandardMaterial3D = StandardMaterial3D.new()
		for property_name: String in setting:
			source.set(property_name, setting[property_name])
		assert_eq(FillMaterial.from_standard(source), source)
	var orm: ORMMaterial3D = ORMMaterial3D.new()
	assert_eq(FillMaterial.from_standard(orm), orm)


func test_cache_does_not_keep_source_alive_and_prunes_dead_entries() -> void:
	var source: StandardMaterial3D = StandardMaterial3D.new()
	var source_id: int = source.get_instance_id()
	var source_ref: WeakRef = weakref(source)
	var material: Material = FillMaterial.from_standard(source)
	assert_true(material is ShaderMaterial)
	assert_true(FillMaterial._cache.has(source_id))
	source = null
	assert_null(source_ref.get_ref())
	assert_null(FillMaterial.from_standard(null))
	assert_false(FillMaterial._cache.has(source_id))
