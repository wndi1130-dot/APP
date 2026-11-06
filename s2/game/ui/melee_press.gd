extends RefCounted
## 결정 564: 근접 한 번 누름 = 한 번 휘두름. 기본은 연타(false).
## 저장값은 boot·slice_flow가 필드를 만든 뒤에만 얹는다. 도구·봇·시험의 직접 생성은 opts만 따른다.

const FILE: String = "user://melee_press.cfg"
const SECTION: String = "melee"
const KEY: String = "one_swing"
const OPTION: String = "melee_one_swing"
static var where: String = FILE     # 시험은 고유 파일로 바꾼 뒤 원래 경로를 돌려놓는다.


## 현재 판의 판단은 파일·시계·플레이어 상태를 읽지 않는다.
static func enabled(opts: Dictionary) -> bool:
	return _only_true(opts.get(OPTION, false))


static func load_enabled(path: String = "") -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(_at(path)) != OK:
		return false
	return _only_true(cfg.get_value(SECTION, KEY, false))


## 같은 폴더의 임시 파일을 완성한 뒤 교체한다. 실패하면 기존 파일을 보존하고 오류를 돌려준다.
## 프로세스별 이름으로 다른 실행의 임시 파일을 피하며 마지막 성공한 값이 남는다.
static func save_enabled(on: bool, path: String = "", write_config: Callable = Callable(),
		replace_file: Callable = Callable()) -> Error:
	var at: String = _at(path)
	var temp: String = "%s.%d.%d.tmp" % [at, OS.get_process_id(), Time.get_ticks_usec()]
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY, on)
	# 호출별 파일 동작 주입: 시험도 정상 목적지 파일을 둔 채 실패 경로를 거친다.
	var error: Error = write_config.call(cfg, temp) if write_config.is_valid() else cfg.save(temp)
	if error == OK:
		error = replace_file.call(temp, at) if replace_file.is_valid() else DirAccess.rename_absolute(temp, at)
	if error != OK and FileAccess.file_exists(temp):
		var cleanup: Error = DirAccess.remove_absolute(temp)
		if cleanup != OK:
			push_warning("근접 설정 임시 파일을 지우지 못했습니다: %s (%s)" % [temp, error_string(cleanup)])
	return error


## 플레이 흐름의 명시 호출에서는 저장값이 이전 정차의 opts보다 우선한다.
static func apply_saved(game: Object, path: String = "") -> void:
	var opts: Dictionary = game.get("opts")
	opts[OPTION] = load_enabled(path)


static func _only_true(value: Variant) -> bool:
	return value is bool and value == true


static func _at(path: String) -> String:
	return where if path == "" else path
