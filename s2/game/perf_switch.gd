## 폰에서 해 그림자 비용을 비교하는 개발용 파일 스위치.
## 예: user://perf_switch.json → {"sun_shadow":false,"shadow_mode":"ortho","shadow_distance":30.0,"atlas_size":2048,"atlas_16_bits":true,"soft_quality":"hard","view_fill":false,"cloud":false}
class_name PerfSwitch
extends RefCounted

const FILE := "user://perf_switch.json"
const CLOUD_SOURCE := &"_perf_cloud_source"
const CLOUD_OFF := &"_perf_cloud_off"
const MODES: Dictionary = {
	"ortho": DirectionalLight3D.SHADOW_ORTHOGONAL,
	"2split": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
	"4split": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
}
const QUALITIES: Dictionary = {
	"hard": RenderingServer.SHADOW_QUALITY_HARD,
	"soft_very_low": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
	"soft_low": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	"soft_medium": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
	"soft_high": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
	"soft_ultra": RenderingServer.SHADOW_QUALITY_SOFT_ULTRA,
}

# RenderingServer has setters only: start from effective project settings and
# remember this switch's writes, including across consecutive fields.
static var _renderer_state: Dictionary = {}


static func read(path: String = FILE) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	if error != OK or not json.data is Dictionary:
		return {}
	return _valid(json.data)


static func _valid(s: Dictionary) -> Dictionary:
	var valid: Dictionary = {}
	for key in ["sun_shadow", "atlas_16_bits", "view_fill", "cloud"]:
		if s.get(key) is bool:
			valid[key] = s[key]
	if s.get("shadow_mode") is String and MODES.has(s["shadow_mode"]):
		valid["shadow_mode"] = s["shadow_mode"]
	if s.get("soft_quality") is String and QUALITIES.has(s["soft_quality"]):
		valid["soft_quality"] = s["soft_quality"]
	for key in ["shadow_distance", "atlas_size"]:
		var value: Variant = s.get(key)
		if not (value is int or value is float):
			continue
		var number: float = float(value)
		if not is_finite(number) or number <= 0.0:
			continue
		if key == "shadow_distance":
			valid[key] = number
		elif number <= 2147483647.0 and number == floor(number):
			var size: int = int(number)
			if (size & (size - 1)) == 0:
				valid[key] = size
	return valid


static func renderer_state() -> Dictionary:
	if _renderer_state.is_empty():
		var prefix: String = "rendering/lights_and_shadows/directional_shadow/"
		_renderer_state = {
			"atlas_size": int(ProjectSettings.get_setting_with_override(prefix + "size")),
			"atlas_16_bits": bool(ProjectSettings.get_setting_with_override(prefix + "16_bits")),
			"soft_quality": int(ProjectSettings.get_setting_with_override(prefix + "soft_shadow_filter_quality")),
		}
	return _renderer_state.duplicate()


static func apply(sun: DirectionalLight3D, view_fill: Node3D, s: Dictionary) -> Dictionary:
	var settings: Dictionary = _valid(s)
	var changed: Dictionary = {}
	if settings.has("sun_shadow") and sun.shadow_enabled != settings["sun_shadow"]:
		sun.shadow_enabled = settings["sun_shadow"]
		changed["sun_shadow"] = sun.shadow_enabled
	if settings.has("shadow_mode") and sun.directional_shadow_mode != MODES[settings["shadow_mode"]]:
		sun.directional_shadow_mode = MODES[settings["shadow_mode"]]
		changed["shadow_mode"] = settings["shadow_mode"]
	if settings.has("shadow_distance") and sun.directional_shadow_max_distance != settings["shadow_distance"]:
		sun.directional_shadow_max_distance = settings["shadow_distance"]
		changed["shadow_distance"] = sun.directional_shadow_max_distance
	if settings.has("atlas_size") or settings.has("atlas_16_bits"):
		var previous: Dictionary = renderer_state()
		var size: int = settings.get("atlas_size", previous["atlas_size"])
		var bits: bool = settings.get("atlas_16_bits", previous["atlas_16_bits"])
		if size != previous["atlas_size"] or bits != previous["atlas_16_bits"]:
			RenderingServer.directional_shadow_atlas_set_size(size, bits)
			_renderer_state["atlas_size"] = size
			_renderer_state["atlas_16_bits"] = bits
			if size != previous["atlas_size"]:
				changed["atlas_size"] = size
			if bits != previous["atlas_16_bits"]:
				changed["atlas_16_bits"] = bits
	if settings.has("soft_quality"):
		var previous: Dictionary = renderer_state()
		var quality: RenderingServer.ShadowQuality = QUALITIES[settings["soft_quality"]]
		if quality != previous["soft_quality"]:
			RenderingServer.directional_soft_shadow_filter_set_quality(quality)
			_renderer_state["soft_quality"] = quality
			changed["soft_quality"] = settings["soft_quality"]
	if settings.has("view_fill"):
		var visible: bool = settings["view_fill"]
		var locked: bool = view_fill.visibility_changed.is_connected(view_fill.hide)
		if not visible and not locked:
			view_fill.visibility_changed.connect(view_fill.hide)
		elif visible and locked:
			view_fill.visibility_changed.disconnect(view_fill.hide)
		if view_fill.visible != visible or locked == visible:
			view_fill.visible = visible
			changed["view_fill"] = visible
	if settings.has("cloud"):
		var enabled: bool = settings["cloud"]
		var locked: bool = sun.has_meta(CLOUD_OFF)
		if locked == enabled:
			var defaults: Dictionary = ProjectSettings.get_setting("shader_globals/fx_cloud", {"value": Vector4.ZERO})
			var cloud: Vector4 = sun.get_meta(CLOUD_SOURCE, defaults["value"])
			if enabled:
				sun.remove_meta(CLOUD_OFF)
			else:
				sun.set_meta(CLOUD_OFF, true)
				sun.set_meta(CLOUD_SOURCE, cloud)
				cloud.y = 0.0
				cloud.z = 0.0
			RenderingServer.global_shader_parameter_set("fx_cloud", cloud)
			changed["cloud"] = enabled
	return changed


static func cloud_params(sun: DirectionalLight3D, params: Dictionary) -> Dictionary:
	if not sun.has_meta(CLOUD_OFF) or not params.get("fx_cloud") is Vector4:
		return params
	var cloud: Vector4 = params["fx_cloud"]
	sun.set_meta(CLOUD_SOURCE, cloud)
	cloud.y = 0.0
	cloud.z = 0.0
	var filtered: Dictionary = params.duplicate()
	filtered["fx_cloud"] = cloud
	return filtered
