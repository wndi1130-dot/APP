## 폰에서 해 그림자 비용을 비교하는 개발용 파일 스위치.
## 예: user://perf_switch.json → {"sun_shadow":false,"shadow_mode":"ortho","shadow_distance":30.0,"atlas_size":2048,"atlas_16_bits":true,"soft_quality":"hard","view_fill":false,"cloud":false}
class_name PerfSwitch
extends RefCounted

const FILE := "user://perf_switch.json"
const CLOUD_SOURCE := &"_perf_cloud_source"
const CLOUD_OFF := &"_perf_cloud_off"
const ATLAS_SIZES: Array[int] = [1024, 2048, 4096, 8192]
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

# RenderingServer has setters only. Keep the project baseline separate from
# this switch's writes; an older field must not restore a newer field's values.
static var _renderer_baseline: Dictionary = {}
static var _renderer_state: Dictionary = {}
static var _renderer_owner: int = 0


static func read(path: String = FILE, diagnostic: Dictionary = {}) -> Dictionary:
	diagnostic.clear()
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return _read_opened(file, FileAccess.get_open_error(), diagnostic)


static func _read_opened(file: FileAccess, open_error: Error, diagnostic: Dictionary) -> Dictionary:
	if file == null:
		_ignored("open failed: " + error_string(open_error), diagnostic)
		return {}
	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	if error != OK:
		_ignored("JSON line %d: %s" % [json.get_error_line(), json.get_error_message()], diagnostic)
		return {}
	if not json.data is Dictionary:
		_ignored("JSON root must be an object", diagnostic)
		return {}
	var valid: Dictionary = _valid(json.data)
	var reasons: PackedStringArray = []
	for key: String in json.data:
		if valid.has(key):
			continue
		if key == "atlas_size":
			reasons.append("atlas_size must be 1024, 2048, 4096 or 8192")
		else:
			reasons.append("unsupported key or invalid value: " + key)
	if valid.is_empty():
		reasons.append("no supported settings remain")
	if not reasons.is_empty():
		_ignored("; ".join(reasons), diagnostic)
	return valid


static func _ignored(reason: String, diagnostic: Dictionary) -> void:
	# Even a malformed key or parser message produces only one log line.
	var line: String = reason.replace("\r", " ").replace("\n", " ")
	diagnostic["reason"] = line
	print("PERF_SWITCH ignored: " + line)


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
		else:
			# Array[int] membership coerces floats; compare before any int conversion.
			for size: int in ATLAS_SIZES:
				if number == float(size):
					valid[key] = size
					break
	return valid


static func renderer_state() -> Dictionary:
	if _renderer_state.is_empty():
		var prefix: String = "rendering/lights_and_shadows/directional_shadow/"
		_renderer_baseline = {
			"atlas_size": int(ProjectSettings.get_setting_with_override(prefix + "size")),
			"atlas_16_bits": bool(ProjectSettings.get_setting_with_override(prefix + "16_bits")),
			"soft_quality": int(ProjectSettings.get_setting_with_override(prefix + "soft_shadow_filter_quality")),
		}
		_renderer_state = _renderer_baseline.duplicate()
	return _renderer_state.duplicate()


static func has_renderer_overrides() -> bool:
	return not _renderer_baseline.is_empty() and _renderer_state != _renderer_baseline


static func needs_renderer(s: Dictionary) -> bool:
	return has_renderer_overrides() or s.has("atlas_size") or s.has("atlas_16_bits") or s.has("soft_quality")


static func _set_renderer(target: Dictionary) -> Dictionary:
	var changed: Dictionary = {}
	if target["atlas_size"] != _renderer_state["atlas_size"] or target["atlas_16_bits"] != _renderer_state["atlas_16_bits"]:
		RenderingServer.directional_shadow_atlas_set_size(int(target["atlas_size"]), bool(target["atlas_16_bits"]))
	if target["soft_quality"] != _renderer_state["soft_quality"]:
		var quality: RenderingServer.ShadowQuality = target["soft_quality"]
		RenderingServer.directional_soft_shadow_filter_set_quality(quality)
	for key: String in target:
		if target[key] != _renderer_state[key]:
			changed[key] = target[key]
	_renderer_state = target.duplicate()
	return changed


## A complete field configuration: omitted keys return to the project baseline.
static func apply_renderer(s: Dictionary, owner: int = 0) -> Dictionary:
	var settings: Dictionary = _valid(s)
	if not needs_renderer(settings):
		return {}
	renderer_state()
	var target: Dictionary = _renderer_baseline.duplicate()
	for key in ["atlas_size", "atlas_16_bits"]:
		if settings.has(key):
			target[key] = settings[key]
	if settings.has("soft_quality"):
		target["soft_quality"] = QUALITIES[settings["soft_quality"]]
	var changed: Dictionary = _set_renderer(target)
	_renderer_owner = owner if has_renderer_overrides() else 0
	if changed.has("soft_quality") and settings.has("soft_quality"):
		changed["soft_quality"] = settings["soft_quality"]
	return changed


static func restore_renderer(owner: int = 0) -> Dictionary:
	if (owner != 0 and owner != _renderer_owner) or not has_renderer_overrides():
		return {}
	var changed: Dictionary = _set_renderer(_renderer_baseline)
	_renderer_owner = 0
	return changed


static func apply(sun: DirectionalLight3D, view_fill: Node3D, s: Dictionary, include_renderer: bool = true) -> Dictionary:
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
	if include_renderer:
		changed.merge(apply_renderer(settings, sun.get_instance_id()))
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
				cloud.w = 0.0
			RenderingServer.global_shader_parameter_set("fx_cloud", cloud)
			changed["cloud"] = enabled
	return changed


static func cloud_params(sun: DirectionalLight3D, params: Dictionary) -> Dictionary:
	if not sun.has_meta(CLOUD_OFF) or not params.get("fx_cloud") is Vector4:
		return params
	var cloud: Vector4 = params["fx_cloud"]
	sun.set_meta(CLOUD_SOURCE, cloud)
	cloud.w = 0.0
	var filtered: Dictionary = params.duplicate()
	filtered["fx_cloud"] = cloud
	return filtered
