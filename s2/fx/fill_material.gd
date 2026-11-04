extends RefCounted
## Opaque standard surfaces with the field's optional shader fill.

const SHADER: Shader = preload("res://fx/shaders/fill_std.gdshader")
const TWO_SIDED_SHADER: Shader = preload("res://fx/shaders/fill_std_two_sided.gdshader")
const COPIED: Array[StringName] = [
	&"albedo_color", &"albedo_texture", &"roughness", &"metallic",
	&"vertex_color_use_as_albedo", &"cull_mode",
]
const IDENTITY: Array[StringName] = [&"resource_name", &"resource_path", &"resource_scene_unique_id"]

static var _baseline: StandardMaterial3D = StandardMaterial3D.new()
static var _cache: Dictionary = {}


static func make(color: Color, roughness: float = 1.0, metallic: float = 0.0, two_sided: bool = false) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = TWO_SIDED_SHADER if two_sided else SHADER
	material.set_shader_parameter("albedo_color", color)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("metallic", metallic)
	material.set_shader_parameter("has_tex", false)
	material.set_shader_parameter("use_vertex_color", false)
	return material


static func from_standard(src: BaseMaterial3D) -> Material:
	_prune_cache()
	if src == null:
		return null
	var source_id: int = src.get_instance_id()
	if not _supported(src):
		_cache.erase(source_id)
		return src
	var material: ShaderMaterial
	if _cache.has(source_id):
		var material_ref: WeakRef = _cache[source_id]["material"]
		material = material_ref.get_ref() as ShaderMaterial
	if material == null:
		material = make(src.albedo_color)
		_cache[source_id] = {"source": weakref(src), "material": weakref(material)}
	# Refresh values without replacing the cached material's identity.
	material.shader = TWO_SIDED_SHADER if src.cull_mode == BaseMaterial3D.CULL_DISABLED else SHADER
	material.set_shader_parameter("albedo_color", src.albedo_color)
	material.set_shader_parameter("albedo_tex", src.albedo_texture)
	material.set_shader_parameter("has_tex", src.albedo_texture != null)
	material.set_shader_parameter("roughness", src.roughness)
	material.set_shader_parameter("metallic", src.metallic)
	material.set_shader_parameter("use_vertex_color", src.vertex_color_use_as_albedo)
	return material


static func _supported(src: BaseMaterial3D) -> bool:
	# Transparency, emission, ORM and scripted materials need their original shader.
	if not src is StandardMaterial3D or src.get_script() != null:
		return false
	if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or src.emission_enabled:
		return false
	if src.cull_mode not in [BaseMaterial3D.CULL_BACK, BaseMaterial3D.CULL_DISABLED]:
		return false
	# Uncopied render settings must match the standard defaults: normal maps,
	# UV transforms, extra textures/passes and other features cannot be dropped.
	for property: Dictionary in src.get_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var property_name: StringName = StringName(property["name"])
		if property_name in COPIED or property_name in IDENTITY or String(property_name).begins_with("metadata/"):
			continue
		if src.get(property_name) != _baseline.get(property_name):
			return false
	return true


static func _prune_cache() -> void:
	# Neither source nor derived material is owned here; sweep dead entries on conversion.
	for source_id: int in _cache.keys():
		var entry: Dictionary = _cache[source_id]
		var source_ref: WeakRef = entry["source"]
		var material_ref: WeakRef = entry["material"]
		if source_ref.get_ref() == null or material_ref.get_ref() == null:
			_cache.erase(source_id)


static func _is_fill(mat: Material) -> bool:
	return mat is ShaderMaterial and (mat.shader == SHADER or mat.shader == TWO_SIDED_SHADER)


static func color_of(mat: Material) -> Color:
	if _is_fill(mat):
		var fill: ShaderMaterial = mat as ShaderMaterial
		var value: Variant = fill.get_shader_parameter("albedo_color")
		if value is Color:
			return value
		if value is Vector4:
			return Color(value.x, value.y, value.z, value.w)
	elif mat is StandardMaterial3D:
		return mat.albedo_color
	return Color.WHITE


static func set_color(mat: Material, c: Color) -> void:
	if _is_fill(mat):
		var fill: ShaderMaterial = mat as ShaderMaterial
		fill.set_shader_parameter("albedo_color", c)
	elif mat is StandardMaterial3D:
		mat.albedo_color = c
