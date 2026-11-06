extends RefCounted
## 설정 창의 스틱·무전·상태 아이콘: 플레이어가 고른 값은 정차 사이·판 사이에 남는다(user://controls.cfg
## [field]). 슬라이스·캠페인이 정차마다 새 필드를 만들 때(slice_flow._field_opts)와 저장에서 필드를 다시
## 세울 때 fill이 남긴 값을 넣고 그 필드에 opts["prefs"]를 단다. 그렇게 만든 필드에서 설정을 바꿀 때만
## keep이 남긴다 — 밝기(screen_lift.gd)처럼, 촬영 도구·시험·봇이 직접 만든 필드는 이 파일을 쓰지 않는다.
## 스크립트로 띄운 실행(-s: 시험 실행기·촬영 도구·봇)은 슬라이스를 거쳐도 플레이어의 파일을 읽지도
## 쓰지도 않는다(path_for). 시험은 where를 제 파일로 돌려 그 파일만 쓴다.
## 값이 맞는지는 읽는 쪽이 본다(field_game.radio_mode, field_hud.status_diameter·stick_floats). 여기서는
## 종류(bool·String·int)만 보고, 다른 종류나 모르는 키는 필드에 넣지 않는다.
## 쓰기가 실패하면(공간·권한) 고른 값은 이 실행 동안 기억해 다음 정차에 주고, 다음 keep이 다시 쓴다.
## 읽을 수 없는 파일은 덮어쓰지 않고 옆(.broken)으로 옮긴 뒤 새로 쓴다.

const FILE: String = "user://controls.cfg"
static var where: String = FILE     # tests point this at their own file
const SECTION: String = "field"
## The kept settings and the kind each must be.
const KINDS: Dictionary = {"stick_float": TYPE_BOOL, "radio": TYPE_STRING, "status_size": TYPE_INT}
## The mark on a field made by the play flow: its changes are kept.
const MARK: String = "prefs"
## Where an unreadable file goes before a fresh one is written.
const BROKEN_SUFFIX: String = ".broken"

## Values chosen but not yet on disk, by file: fill gives them, the next keep writes them again.
static var _unsaved: Dictionary = {}


## The file to use: none (off) for the player's own file when the run is a script's
## (a test runner, a shot tool, a bot) — a file a test points at is used as it is.
static func path_for(at: String, scripted: bool) -> String:
	return "" if scripted and at == FILE else at


## The values kept, of the right kind only, with any not yet written; none (no file,
## a broken one, a script's run) is {}.
static func load_all(path: String = "") -> Dictionary:
	var at: String = _at(path)
	if at == "":
		return {}
	var out: Dictionary = {}
	var cfg := ConfigFile.new()
	if cfg.load(at) == OK:
		for key: String in KINDS:
			# A file holds only what was changed (a missing key with a null default is an engine error).
			if not cfg.has_section_key(SECTION, key):
				continue
			var value: Variant = cfg.get_value(SECTION, key)
			if typeof(value) == int(KINDS[key]):
				out[key] = value
	out.merge(_unsaved.get(at, {}) as Dictionary, true)
	return out


## A field the play flow makes: the kept values it is not already made with, and the mark.
static func fill(opts: Dictionary, path: String = "") -> void:
	var kept: Dictionary = load_all(path)
	for key: String in kept:
		if not opts.has(key):
			opts[key] = kept[key]
	opts[MARK] = true


## A setting changed on `game`'s field: kept when the play flow made that field.
## OK when it is on disk; ERR_SKIP when this field or run keeps nothing; else why the
## write failed (the value is then held for the next stop and written again on the next keep).
static func keep(game: Object, key: String, path: String = "") -> Error:
	if game == null or not KINDS.has(key):
		return ERR_SKIP
	var opts: Dictionary = game.get("opts")
	if not bool(opts.get(MARK, false)) or typeof(opts.get(key)) != int(KINDS[key]):
		return ERR_SKIP
	var at: String = _at(path)
	if at == "":
		return ERR_SKIP
	var values: Dictionary = (_unsaved.get(at, {}) as Dictionary).duplicate()
	values[key] = opts[key]
	var err: Error = _write(at, values)
	if err == OK:
		_unsaved.erase(at)
	else:
		_unsaved[at] = values
		push_warning("field settings not saved to %s (%s); held for this run" % [at, error_string(err)])
	return err


## `values` into the [field] section of `at`, the file's other values kept. A file
## that is there but cannot be read is moved aside first, never written over.
static func _write(at: String, values: Dictionary) -> Error:
	var cfg := ConfigFile.new()
	if cfg.load(at) != OK and FileAccess.file_exists(at):
		if FileAccess.file_exists(at + BROKEN_SUFFIX):
			DirAccess.remove_absolute(at + BROKEN_SUFFIX)   # the one before it gives way
		var moved: Error = DirAccess.rename_absolute(at, at + BROKEN_SUFFIX)
		if moved != OK:
			return moved
		cfg = ConfigFile.new()
	for key: String in values:
		cfg.set_value(SECTION, key, values[key])
	return cfg.save(at)


static func _at(path: String) -> String:
	return path_for(where if path == "" else path, _scripted())


## A run whose main loop is a script's (godot -s …) rather than the game's own.
static func _scripted() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	return loop != null and loop.get_script() != null
