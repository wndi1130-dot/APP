extends "res://addons/gut/test.gd"
## 개발용 스위치의 파일을 격리하고 전역 그림자 설정은 시험 뒤 복원한다.

const Switch = preload("res://game/perf_switch.gd")

class FieldProbe extends "res://game/field_game.gd":
	func _ready() -> void:
		set_process(false)


var path: String = ""
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var renderer_before: Dictionary = {}
var cloud_touched: bool = false
var fields: Array[Node] = []


func before_each() -> void:
	path = "user://test_perf_switch_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	sun = DirectionalLight3D.new()
	fill = DirectionalLight3D.new()
	add_child_autofree(sun)
	add_child_autofree(fill)
	renderer_before = {}
	cloud_touched = false
	Switch.restore_renderer()   # start from the project baseline whatever ran before
	fields = []


func after_each() -> void:
	for field: Node in fields:
		if is_instance_valid(field):
			field.free()
	if FileAccess.file_exists(path):
		assert_eq(DirAccess.remove_absolute(path), OK)
	assert_false(FileAccess.file_exists(path))
	Switch.restore_renderer()   # every test leaves the project baseline, touched or not
	if not renderer_before.is_empty():
		assert_eq(Switch.renderer_state(), renderer_before, "project baseline restored")
	if cloud_touched:
		# 실행 중 전역값을 되읽을 수 없어 기본값으로 둔다.
		var defaults: Dictionary = ProjectSettings.get_setting("shader_globals/fx_cloud")
		RenderingServer.global_shader_parameter_set("fx_cloud", defaults["value"])


func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(text)
		file.close()


func _save_renderer() -> void:
	Switch.restore_renderer()
	renderer_before = Switch.renderer_state()


func _renderer_config() -> Dictionary:
	return {
		"atlas_size": 2048 if int(renderer_before["atlas_size"]) != 2048 else 1024,
		"atlas_16_bits": not bool(renderer_before["atlas_16_bits"]),
		"soft_quality": "soft_low" if int(renderer_before["soft_quality"]) == RenderingServer.SHADOW_QUALITY_HARD else "hard",
	}


func _field(hidden: bool = true) -> FieldProbe:
	var field: FieldProbe = FieldProbe.new()
	field.visible = not hidden
	field.process_mode = Node.PROCESS_MODE_DISABLED
	field.sun = DirectionalLight3D.new()
	field.view_fill = DirectionalLight3D.new()
	field.fx_params = {"fx_cloud": Vector4(0.8, 0.6, -0.4, 0.7)}
	field.add_child(field.sun)
	field.add_child(field.view_fill)
	fields.append(field)
	add_child(field)
	return field


func _free_field(field: FieldProbe) -> void:
	fields.erase(field)
	field.free()


func test_read_missing_file_changes_nothing_and_has_no_reason() -> void:
	var diagnostic: Dictionary = {}
	fill.light_energy = 2.5
	fill.light_specular = 0.75
	var old_cache: Dictionary = Switch._renderer_state.duplicate()
	var old_baseline: Dictionary = Switch._renderer_baseline.duplicate()
	var shadow_before: bool = sun.shadow_enabled
	assert_eq(Switch.FILE, "user://perf_switch.json")
	assert_eq(Switch.read(path, diagnostic), {})
	assert_eq(diagnostic, {})
	assert_eq(Switch.apply(sun, fill, Switch.read(path)), {})
	assert_eq(Switch.restore_renderer(), {})
	assert_eq(sun.shadow_enabled, shadow_before)
	assert_true(fill.visible)
	assert_eq(fill.light_energy, 2.5)
	assert_eq(fill.light_specular, 0.75)
	assert_false(fill.has_meta(Switch.FILL_ENERGY))
	assert_false(sun.has_meta(Switch.CLOUD_OFF))
	assert_eq(Switch._renderer_state, old_cache)
	assert_eq(Switch._renderer_baseline, old_baseline)
	assert_false(FileAccess.file_exists(path))


func test_read_broken_json_and_non_object_report_reasons() -> void:
	for text in ["{broken", "", "[]", "null", "false", "42"]:
		var diagnostic: Dictionary = {}
		_write(text)
		assert_eq(Switch.read(path, diagnostic), {}, text)
		assert_true(String(diagnostic.get("reason", "")).begins_with("JSON"), text)
		assert_false(String(diagnostic["reason"]).contains("\n"))


func test_read_open_failure_reports_a_reason() -> void:
	var diagnostic: Dictionary = {}
	assert_eq(Switch._read_opened(null, ERR_FILE_CANT_OPEN, diagnostic), {})
	assert_true(String(diagnostic["reason"]).begins_with("open failed:"))


func test_read_empty_or_rejected_settings_report_reasons() -> void:
	for text in ['{}', '{"unknown":7}', '{"cloud":0}', JSON.stringify({"unknown\nkey": 1})]:
		var diagnostic: Dictionary = {}
		_write(text)
		assert_eq(Switch.read(path, diagnostic), {})
		assert_true(String(diagnostic["reason"]).contains("no supported settings remain"))
		assert_false(String(diagnostic["reason"]).contains("\n"))


func test_read_keeps_known_values_and_ignores_unknown_keys() -> void:
	var diagnostic: Dictionary = {}
	_write('{"sun_shadow":false,"shadow_mode":"2split","shadow_distance":30.0,"atlas_size":2048,"atlas_16_bits":true,"soft_quality":"hard","view_fill":false,"cloud":false,"unknown":7}')
	assert_eq(Switch.read(path, diagnostic), {
		"sun_shadow": false, "shadow_mode": "2split", "shadow_distance": 30.0,
		"atlas_size": 2048, "atlas_16_bits": true, "soft_quality": "hard",
		"view_fill": false, "cloud": false,
	})
	assert_true(String(diagnostic["reason"]).contains("unknown"))
	_write('{"sun_shadow":false}')
	assert_eq(Switch.read(path, diagnostic), {"sun_shadow": false})
	assert_eq(diagnostic, {}, "a valid read clears the previous reason")


func test_invalid_types_and_values_are_ignored() -> void:
	var old_cache: Dictionary = Switch._renderer_state.duplicate()
	var old_baseline: Dictionary = Switch._renderer_baseline.duplicate()
	var invalid: Dictionary = {
		"sun_shadow": 0, "shadow_mode": "wide", "shadow_distance": -1,
		"atlas_size": 2048.5, "atlas_16_bits": "true", "soft_quality": "soft_unknown",
		"view_fill": "false", "cloud": 0,
	}
	_write(JSON.stringify(invalid))
	assert_eq(Switch._valid(invalid), {})
	assert_eq(Switch.read(path), {})
	assert_eq(Switch.apply(sun, fill, invalid), {})
	for size in [0, -1, 3, 512, 1024.5, 2048.5, 4096.5, 8192.5, 16384, 1073741824, INF]:
		assert_eq(Switch._valid({"atlas_size": size}), {})
		assert_eq(Switch.apply(sun, fill, {"atlas_size": size}), {})
	assert_eq(Switch.apply(sun, fill, {"shadow_distance": NAN}), {})
	assert_eq(Switch._renderer_state, old_cache, "invalid input leaves the cache untouched")
	assert_eq(Switch._renderer_baseline, old_baseline)
	assert_false(Switch.has_renderer_overrides())
	for size: int in Switch.ATLAS_SIZES:
		assert_eq(Switch._valid({"atlas_size": float(size)}), {"atlas_size": size})

	_save_renderer()
	assert_eq(Switch.apply(sun, fill, invalid), {}, "already at the project baseline")
	assert_eq(Switch.renderer_state(), renderer_before)
	Switch.apply(sun, fill, _renderer_config())
	assert_true(Switch.has_renderer_overrides())
	assert_eq(Switch.apply(sun, fill, invalid), renderer_before, "only prior overrides are restored")
	assert_eq(Switch.renderer_state(), renderer_before)
	assert_false(Switch.has_renderer_overrides())
	assert_eq(Switch.apply(sun, fill, invalid), {}, "restoration is idempotent")


func test_atlas_allowlist_rejects_large_power_of_two_with_reason() -> void:
	for size: int in [1024, 2048, 4096, 8192]:
		assert_eq(Switch._valid({"atlas_size": size}), {"atlas_size": size})
	var diagnostic: Dictionary = {}
	_write('{"atlas_size":1073741824,"sun_shadow":false}')
	assert_eq(Switch.read(path, diagnostic), {"sun_shadow": false})
	assert_true(String(diagnostic["reason"]).contains("atlas_size must be 1024, 2048, 4096 or 8192"))


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


func test_view_fill_diagnostic_ranges_accept_boundaries_and_clear_reasons() -> void:
	var values: Dictionary = {"view_fill_specular": [0, 0.5, 1.0], "view_fill_energy": [0.002, 2.5, 4.0, 4]}
	for key: String in values:
		for value in values[key]:
			var settings: Dictionary = {}
			settings[key] = value
			var expected: Dictionary = {}
			expected[key] = float(value)
			var diagnostic: Dictionary = {"reason": "previous read"}
			assert_eq(Switch._valid(settings), expected)
			_write(JSON.stringify(settings))
			assert_eq(Switch.read(path, diagnostic), expected)
			assert_eq(diagnostic, {})


func test_invalid_fill_diagnostics_keep_other_valid_keys_and_report_reasons() -> void:
	var invalid: Dictionary = {
		"view_fill_specular": [-0.001, 1.001, "0", false, null, [], {}, INF, -INF, NAN],
		"view_fill_energy": [0, 0.001, 4.001, "0.002", true, null, [], {}, INF, -INF, NAN],
	}
	fill.light_energy = 2.5
	fill.light_specular = 0.75
	for key: String in invalid:
		for value in invalid[key]:
			var settings: Dictionary = {"sun_shadow": false}
			settings[key] = value
			assert_eq(Switch._valid(settings), {"sun_shadow": false})
			sun.shadow_enabled = true
			assert_eq(Switch.apply(sun, fill, settings, false), {"sun_shadow": false})
			assert_false(sun.shadow_enabled)
			assert_eq(fill.light_energy, 2.5)
			assert_eq(fill.light_specular, 0.75)
			assert_false(fill.has_meta(Switch.FILL_ENERGY))
			# JSON has no non-finite literals; exercise those through _valid/apply.
			if value is float and not is_finite(value):
				continue
			var diagnostic: Dictionary = {}
			_write(JSON.stringify(settings))
			assert_eq(Switch.read(path, diagnostic), {"sun_shadow": false})
			assert_true(String(diagnostic["reason"]).contains(key))
			assert_false(String(diagnostic["reason"]).contains("\n"))


func test_view_fill_specular_applies_and_reports_only_changes() -> void:
	fill.light_specular = 0.5
	fill.light_energy = 2.5
	for specular: float in [0.0, 1.0]:
		var settings: Dictionary = {"view_fill_specular": specular}
		assert_eq(Switch.apply(sun, fill, settings, false), settings)
		assert_eq(fill.light_specular, specular)
		assert_eq(fill.light_energy, 2.5)
		assert_true(fill.visible)
		assert_eq(Switch.apply(sun, fill, settings, false), {})


func test_view_fill_energy_applies_and_reports_only_changes() -> void:
	fill.light_energy = 2.5
	fill.light_specular = 0.75
	# Even matching the current energy must install the minute-update override.
	for energy: float in [2.5, 0.002, 4.0]:
		var settings: Dictionary = {"view_fill_energy": energy}
		assert_eq(Switch.apply(sun, fill, settings, false), settings)
		assert_almost_eq(fill.light_energy, energy, 0.000001)
		assert_eq(fill.get_meta(Switch.FILL_ENERGY), energy)
		assert_eq(fill.light_specular, 0.75)
		assert_true(fill.visible)
		assert_eq(Switch.apply(sun, fill, settings, false), {})


func test_fill_energy_survives_minute_updates_and_keeps_specular() -> void:
	var field: FieldProbe = _field()
	field.fx_light = {"fill_energy": 2.0, "fill_color": Color.RED}
	field._set_view_fill()
	field._apply_perf_settings({"view_fill_energy": 0.002, "view_fill_specular": 0.0})
	assert_almost_eq(field.view_fill.light_energy, 0.002, 0.000001)
	for source_energy: float in [1.4, 2.5]:
		field.fx_light["fill_energy"] = source_energy
		field._set_view_fill()
		assert_almost_eq(field.view_fill.light_energy, 0.002, 0.000001)
		assert_eq(field.view_fill.light_specular, 0.0)
		assert_eq(field.view_fill.light_color, Color.RED)
		assert_true(field.view_fill.visible)
		assert_eq(field.fx_light["fill_energy"], source_energy)


func test_fill_energy_preserves_night_and_storm_hiding() -> void:
	var field: FieldProbe = _field()
	for source_energy: float in [0.0, 2.0]:
		field.fx_light = {"fill_energy": source_energy}
		field.storm = {"stage": 1} if source_energy == 2.0 else {}
		field._set_view_fill()
		# Explicit true must not override the source's night/storm hiding.
		field._apply_perf_settings({"view_fill": true, "view_fill_energy": 0.002})
		assert_false(field.view_fill.visible)
		field._set_view_fill()
		assert_false(field.view_fill.visible)
		assert_almost_eq(field.view_fill.light_energy, 0.0 if source_energy == 2.0 else source_energy, 0.000001)
		assert_eq(field.view_fill.get_meta(Switch.FILL_ENERGY), 0.002)
	field.storm = {}
	field.fx_light["fill_energy"] = 2.0
	field._set_view_fill()
	assert_true(field.view_fill.visible)
	assert_almost_eq(field.view_fill.light_energy, 0.002, 0.000001)


func test_view_fill_false_wins_over_diagnostics_on_minute_updates() -> void:
	var field: FieldProbe = _field()
	field.fx_light = {"fill_energy": 2.0}
	field._set_view_fill()
	field._apply_perf_settings({"view_fill": false, "view_fill_energy": 0.002, "view_fill_specular": 0.0})
	assert_false(field.view_fill.visible)
	field.fx_light["fill_energy"] = 2.5
	field._set_view_fill()
	assert_false(field.view_fill.visible)
	assert_true(field.view_fill.visibility_changed.is_connected(field.view_fill.hide))
	assert_almost_eq(field.view_fill.light_energy, 0.002, 0.000001)
	assert_eq(field.view_fill.light_specular, 0.0)


func test_missing_file_keeps_field_fill_properties_and_normal_updates() -> void:
	var field: FieldProbe = _field()
	field.fx_light = {"fill_energy": 2.0}
	field.view_fill.light_specular = 0.75
	field._set_view_fill()
	field._apply_perf_settings(Switch.read(path))
	assert_eq(field.view_fill.light_energy, 2.0)
	assert_eq(field.view_fill.light_specular, 0.75)
	assert_false(field.view_fill.has_meta(Switch.FILL_ENERGY))
	field.fx_light["fill_energy"] = 1.5
	field._set_view_fill()
	assert_eq(field.view_fill.light_energy, 1.5)
	assert_eq(field.view_fill.light_specular, 0.75)
	assert_true(field.view_fill.visible)


func test_omitted_atlas_partner_and_filter_return_to_baseline() -> void:
	_save_renderer()
	var settings: Dictionary = _renderer_config()
	Switch.apply(sun, fill, settings)
	Switch.apply(sun, fill, {"atlas_16_bits": settings["atlas_16_bits"]})
	assert_eq(Switch.renderer_state()["atlas_size"], renderer_before["atlas_size"])
	assert_eq(Switch.renderer_state()["soft_quality"], renderer_before["soft_quality"])
	assert_eq(Switch.renderer_state()["atlas_16_bits"], settings["atlas_16_bits"])
	Switch.apply(sun, fill, {"atlas_size": settings["atlas_size"]})
	assert_eq(Switch.renderer_state()["atlas_16_bits"], renderer_before["atlas_16_bits"])
	assert_eq(Switch.apply(sun, fill, {"atlas_size": settings["atlas_size"]}), {})


func test_removed_file_restores_all_renderer_baselines() -> void:
	_save_renderer()
	_write(JSON.stringify(_renderer_config()))
	Switch.apply(sun, fill, Switch.read(path))
	assert_true(Switch.has_renderer_overrides())
	assert_eq(DirAccess.remove_absolute(path), OK)
	Switch.apply(sun, fill, Switch.read(path))
	assert_eq(Switch.renderer_state(), renderer_before)
	assert_false(Switch.has_renderer_overrides())


func test_renderer_restore_is_idempotent_and_owner_scoped() -> void:
	_save_renderer()
	var settings: Dictionary = _renderer_config()
	Switch.apply_renderer(settings, 11)
	assert_eq(Switch.apply_renderer(settings, 22), {})
	assert_eq(Switch.restore_renderer(11), {}, "old field cannot reset its successor")
	assert_true(Switch.has_renderer_overrides())
	assert_false(Switch.restore_renderer(22).is_empty())
	assert_eq(Switch.renderer_state(), renderer_before)
	assert_eq(Switch.restore_renderer(22), {})


func test_field_defers_globals_until_visible_and_restores_on_exit() -> void:
	_save_renderer()
	cloud_touched = true
	var field: FieldProbe = _field()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	field.sun.shadow_enabled = true
	var settings: Dictionary = _renderer_config()
	settings.merge({"sun_shadow": false, "view_fill": false, "cloud": false})
	field._apply_perf_settings(settings)
	assert_false(field.sun.shadow_enabled)
	assert_false(field.view_fill.visible)
	var cloud_params: Dictionary = Switch.cloud_params(field.sun, field.fx_params)
	assert_eq(cloud_params["fx_cloud"], Vector4(0.8, 0.6, -0.4, 0.0))
	assert_eq(Switch.renderer_state(), renderer_before, "hidden build leaves the renderer alone")
	field.visible = true
	assert_true(Switch.has_renderer_overrides())
	assert_eq(Switch.renderer_state()["atlas_size"], settings["atlas_size"])
	assert_eq(Switch.renderer_state()["atlas_16_bits"], settings["atlas_16_bits"])
	assert_eq(Switch.renderer_state()["soft_quality"], Switch.QUALITIES[settings["soft_quality"]])
	_free_field(field)
	assert_eq(Switch.renderer_state(), renderer_before)


func test_abandoned_hidden_field_does_not_restore_visible_field() -> void:
	_save_renderer()
	var active: FieldProbe = _field(false)
	active._apply_perf_settings(_renderer_config())
	var before: Dictionary = Switch.renderer_state()
	var hidden: FieldProbe = _field()
	hidden._apply_perf_settings({})
	_free_field(hidden)
	assert_eq(Switch.renderer_state(), before)
	_free_field(active)
	assert_eq(Switch.renderer_state(), renderer_before)


func test_next_visible_field_without_settings_restores_prior_overrides() -> void:
	_save_renderer()
	var next: FieldProbe = _field()
	next._apply_perf_settings({})
	var active: FieldProbe = _field(false)
	active._apply_perf_settings(_renderer_config())
	assert_true(Switch.has_renderer_overrides())
	next.visible = true
	assert_eq(Switch.renderer_state(), renderer_before)
	_free_field(active)
	assert_eq(Switch.renderer_state(), renderer_before)


func test_desktop_field_never_reads_the_real_switch_file() -> void:
	if OS.has_feature("android"):
		pending("desktop-only file isolation")
		return
	var field: FieldProbe = _field()
	field._configure_perf_switch()
	assert_eq(field._perf_settings, {})
	assert_false(field.visibility_changed.is_connected(field._apply_perf_renderer))


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


func test_cloud_masks_w_at_start_and_on_later_atmosphere_updates() -> void:
	cloud_touched = true
	var original: Vector4 = Vector4(0.8, 0.6, -0.4, 12.0)
	sun.set_meta(Switch.CLOUD_SOURCE, original)
	assert_eq(Switch.apply(sun, fill, {"cloud": false}), {"cloud": false})
	assert_eq(Switch.apply(sun, fill, {"cloud": false}), {})
	for cloud in [original, Vector4(0.3, -0.2, 0.9, 15.0)]:
		var params: Dictionary = {"fx_cloud": cloud, "fx_snow": 0.4}
		var filtered: Dictionary = Switch.cloud_params(sun, params)
		assert_eq(filtered["fx_cloud"], Vector4(cloud.x, cloud.y, cloud.z, 0.0))
		assert_eq(filtered["fx_snow"], 0.4)
		assert_eq(params["fx_cloud"], cloud, "source values stay intact")
		assert_eq(sun.get_meta(Switch.CLOUD_SOURCE), cloud)
	assert_eq(Switch.cloud_params(sun, {"fx_snow": 0.2}), {"fx_snow": 0.2})
	assert_eq(Switch.apply(sun, fill, {"cloud": true}), {"cloud": true})
	assert_false(sun.has_meta(Switch.CLOUD_OFF))
	assert_eq(sun.get_meta(Switch.CLOUD_SOURCE), Vector4(0.3, -0.2, 0.9, 15.0), "latest unmasked value is kept for restoration")
	assert_eq(Switch.cloud_params(sun, {"fx_cloud": original}), {"fx_cloud": original})


func test_cloud_without_a_switch_leaves_params_and_metadata_unchanged() -> void:
	var params: Dictionary = {"fx_cloud": Vector4(0.4, 0.8, 0.6, 9.0)}
	assert_eq(Switch.cloud_params(sun, params), params)
	assert_false(sun.has_meta(Switch.CLOUD_SOURCE))
