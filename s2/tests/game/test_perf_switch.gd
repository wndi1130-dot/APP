extends "res://addons/gut/test.gd"
## 개발용 스위치의 파일을 격리하고 전역 그림자 설정은 시험 뒤 복원한다.

const Switch = preload("res://game/perf_switch.gd")

var path: String = ""
var sun: DirectionalLight3D
var fill: Node3D
var renderer_before: Dictionary = {}
var cache_before: Dictionary = {}
var cloud_touched: bool = false


func before_each() -> void:
	path = "user://test_perf_switch_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	sun = DirectionalLight3D.new()
	fill = Node3D.new()
	add_child_autofree(sun)
	add_child_autofree(fill)
	renderer_before = {}
	cloud_touched = false


func after_each() -> void:
	if FileAccess.file_exists(path):
		assert_eq(DirAccess.remove_absolute(path), OK)
	assert_false(FileAccess.file_exists(path))
	if not renderer_before.is_empty():
		RenderingServer.directional_shadow_atlas_set_size(int(renderer_before["atlas_size"]), bool(renderer_before["atlas_16_bits"]))
		var quality: RenderingServer.ShadowQuality = renderer_before["soft_quality"]
		RenderingServer.directional_soft_shadow_filter_set_quality(quality)
		Switch._renderer_state = cache_before
	if cloud_touched:
		var defaults: Dictionary = ProjectSettings.get_setting("shader_globals/fx_cloud")
		RenderingServer.global_shader_parameter_set("fx_cloud", defaults["value"])


func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(text)
		file.close()


func _save_renderer() -> void:
	cache_before = Switch._renderer_state.duplicate()
	renderer_before = Switch.renderer_state()


func test_read_missing_file_is_empty() -> void:
	assert_eq(Switch.FILE, "user://perf_switch.json")
	assert_eq(Switch.read(path), {})
	assert_false(FileAccess.file_exists(path))


func test_read_broken_json_and_non_object_are_empty() -> void:
	for text in ["{broken", "", "[]", "null", "false", "42"]:
		_write(text)
		assert_eq(Switch.read(path), {}, text)


func test_read_keeps_known_values_and_ignores_unknown_keys() -> void:
	_write('{"sun_shadow":false,"shadow_mode":"2split","shadow_distance":30.0,"atlas_size":2048,"atlas_16_bits":true,"soft_quality":"hard","view_fill":false,"cloud":false,"unknown":7}')
	assert_eq(Switch.read(path), {
		"sun_shadow": false, "shadow_mode": "2split", "shadow_distance": 30.0,
		"atlas_size": 2048, "atlas_16_bits": true, "soft_quality": "hard",
		"view_fill": false, "cloud": false,
	})


func test_invalid_types_and_values_are_ignored() -> void:
	var invalid: Dictionary = {
		"sun_shadow": 0, "shadow_mode": "wide", "shadow_distance": -1,
		"atlas_size": 2048.5, "atlas_16_bits": "true", "soft_quality": "soft_unknown",
		"view_fill": "false", "cloud": 0,
	}
	_write(JSON.stringify(invalid))
	assert_eq(Switch.read(path), {})
	assert_eq(Switch.apply(sun, fill, invalid), {})
	for size in [0, -1, 3, INF]:
		assert_eq(Switch.apply(sun, fill, {"atlas_size": size}), {})
	assert_eq(Switch.apply(sun, fill, {"shadow_distance": NAN}), {})


func test_sun_shadow_changes_and_reports_only_changes() -> void:
	sun.shadow_enabled = true
	assert_eq(Switch.apply(sun, fill, {"sun_shadow": false}), {"sun_shadow": false})
	assert_false(sun.shadow_enabled)
	assert_eq(Switch.apply(sun, fill, {"sun_shadow": false}), {})
	assert_eq(Switch.apply(sun, fill, {"sun_shadow": true}), {"sun_shadow": true})
	assert_true(sun.shadow_enabled)


func test_each_shadow_mode_maps_to_the_directional_light_enum() -> void:
	var modes: Dictionary = {
		"ortho": DirectionalLight3D.SHADOW_ORTHOGONAL,
		"2split": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		"4split": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
	}
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	for mode in modes:
		assert_eq(Switch.apply(sun, fill, {"shadow_mode": mode}), {"shadow_mode": mode})
		assert_eq(sun.directional_shadow_mode, modes[mode])
		assert_eq(Switch.apply(sun, fill, {"shadow_mode": mode}), {})


func test_shadow_distance_changes_without_touching_other_light_properties() -> void:
	sun.directional_shadow_max_distance = 60.0
	sun.light_energy = 2.5
	assert_eq(Switch.apply(sun, fill, {"shadow_distance": 30}), {"shadow_distance": 30.0})
	assert_eq(sun.directional_shadow_max_distance, 30.0)
	assert_eq(sun.light_energy, 2.5)
	assert_eq(Switch.apply(sun, fill, {"shadow_distance": 30.0}), {})


func test_empty_and_unknown_settings_leave_the_light_and_fill_unchanged() -> void:
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 73.0
	sun.light_energy = 2.5
	var old_cache: Dictionary = Switch._renderer_state.duplicate()
	for settings in [{}, {"unknown": false}]:
		assert_eq(Switch.apply(sun, fill, settings), {})
		assert_true(sun.shadow_enabled)
		assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
		assert_eq(sun.directional_shadow_max_distance, 73.0)
		assert_eq(sun.light_energy, 2.5)
		assert_true(fill.visible)
		assert_false(fill.visibility_changed.is_connected(fill.hide))
		assert_false(sun.has_meta(Switch.CLOUD_OFF))
		assert_eq(Switch._renderer_state, old_cache)


func test_view_fill_stays_hidden_when_the_atmosphere_sets_it_visible() -> void:
	assert_eq(Switch.apply(sun, fill, {"view_fill": false}), {"view_fill": false})
	assert_false(fill.visible)
	fill.visible = true
	assert_false(fill.visible)
	assert_eq(Switch.apply(sun, fill, {"view_fill": false}), {})
	assert_eq(Switch.apply(sun, fill, {"view_fill": true}), {"view_fill": true})
	assert_true(fill.visible)
	assert_false(fill.visibility_changed.is_connected(fill.hide))


func test_atlas_fields_preserve_the_unspecified_partner() -> void:
	_save_renderer()
	var size: int = 2048 if int(renderer_before["atlas_size"]) != 2048 else 1024
	assert_eq(Switch.apply(sun, fill, {"atlas_size": size}), {"atlas_size": size})
	assert_eq(Switch.renderer_state()["atlas_16_bits"], renderer_before["atlas_16_bits"])
	var bits: bool = not bool(renderer_before["atlas_16_bits"])
	assert_eq(Switch.apply(sun, fill, {"atlas_16_bits": bits}), {"atlas_16_bits": bits})
	assert_eq(Switch.renderer_state()["atlas_size"], size)
	assert_eq(Switch.apply(sun, fill, {"atlas_size": size, "atlas_16_bits": bits}), {})


func test_all_soft_quality_names_map_to_rendering_server_enums() -> void:
	_save_renderer()
	var qualities: Dictionary = {
		"hard": RenderingServer.SHADOW_QUALITY_HARD,
		"soft_very_low": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		"soft_low": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"soft_medium": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"soft_high": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		"soft_ultra": RenderingServer.SHADOW_QUALITY_SOFT_ULTRA,
	}
	for quality_name in qualities:
		var before: Dictionary = Switch.renderer_state()
		var expected: Dictionary = {} if before["soft_quality"] == qualities[quality_name] else {"soft_quality": quality_name}
		assert_eq(Switch.apply(sun, fill, {"soft_quality": quality_name}), expected)
		assert_eq(Switch.renderer_state()["soft_quality"], qualities[quality_name])
		assert_eq(Switch.apply(sun, fill, {"soft_quality": quality_name}), {})


func test_cloud_masks_y_z_at_start_and_on_later_atmosphere_updates() -> void:
	cloud_touched = true
	var original: Vector4 = Vector4(0.8, 0.6, -0.4, 12.0)
	sun.set_meta(Switch.CLOUD_SOURCE, original)
	assert_eq(Switch.apply(sun, fill, {"cloud": false}), {"cloud": false})
	assert_eq(Switch.apply(sun, fill, {"cloud": false}), {})
	for cloud in [original, Vector4(0.3, -0.2, 0.9, 15.0)]:
		var params: Dictionary = {"fx_cloud": cloud, "fx_snow": 0.4}
		var filtered: Dictionary = Switch.cloud_params(sun, params)
		assert_eq(filtered["fx_cloud"], Vector4(cloud.x, 0.0, 0.0, cloud.w))
		assert_eq(filtered["fx_snow"], 0.4)
		assert_eq(params["fx_cloud"], cloud, "source values stay intact")
		assert_eq(sun.get_meta(Switch.CLOUD_SOURCE), cloud)
	assert_eq(Switch.cloud_params(sun, {"fx_snow": 0.2}), {"fx_snow": 0.2})
	assert_eq(Switch.apply(sun, fill, {"cloud": true}), {"cloud": true})
	assert_false(sun.has_meta(Switch.CLOUD_OFF))
	assert_eq(Switch.cloud_params(sun, {"fx_cloud": original}), {"fx_cloud": original})


func test_cloud_without_a_switch_leaves_params_and_metadata_unchanged() -> void:
	var params: Dictionary = {"fx_cloud": Vector4(0.4, 0.8, 0.6, 9.0)}
	assert_eq(Switch.cloud_params(sun, params), params)
	assert_false(sun.has_meta(Switch.CLOUD_SOURCE))
