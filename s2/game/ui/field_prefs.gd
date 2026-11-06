extends RefCounted
## 설정 창의 스틱·무전·상태 아이콘: 플레이어가 고른 값은 정차 사이·판 사이에 남는다(user://controls.cfg
## [field]). 슬라이스·캠페인이 정차마다 새 필드를 만들 때(slice_flow._field_opts) fill이 남긴 값을 넣고
## 그 필드에 opts["prefs"]를 단다. 그렇게 만든 필드에서 설정을 바꿀 때만 keep이 남긴다 — 밝기
## (screen_lift.gd)처럼, 촬영 도구·시험·봇이 만든 필드는 이 파일을 읽지도 쓰지도 않는다.
## 값이 맞는지는 읽는 쪽이 본다(field_game.radio_mode, field_hud.status_diameter·stick_floats). 여기서는
## 종류(bool·String·int)만 보고, 다른 종류나 모르는 키는 필드에 넣지 않는다.

const FILE: String = "user://controls.cfg"
static var where: String = FILE     # tests point this at their own file
const SECTION: String = "field"
## The kept settings and the kind each must be.
const KINDS: Dictionary = {"stick_float": TYPE_BOOL, "radio": TYPE_STRING, "status_size": TYPE_INT}
## The mark on a field made by the play flow: its changes are kept.
const MARK: String = "prefs"


## The values kept, of the right kind only; none (no file, a broken one) is {}.
static func load_all(path: String = "") -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(_at(path)) != OK:
		return {}
	var out: Dictionary = {}
	for key: String in KINDS:
		var value: Variant = cfg.get_value(SECTION, key, null)
		if typeof(value) == int(KINDS[key]):
			out[key] = value
	return out


## A field the play flow makes: the kept values it is not already made with, and the mark.
static func fill(opts: Dictionary, path: String = "") -> void:
	var kept: Dictionary = load_all(path)
	for key: String in kept:
		if not opts.has(key):
			opts[key] = kept[key]
	opts[MARK] = true


## A setting changed on `game`'s field: kept when the play flow made that field.
static func keep(game: Object, key: String, path: String = "") -> void:
	if game == null or not KINDS.has(key):
		return
	var opts: Dictionary = game.get("opts")
	if not bool(opts.get(MARK, false)) or typeof(opts.get(key)) != int(KINDS[key]):
		return
	var cfg := ConfigFile.new()
	cfg.load(_at(path))
	cfg.set_value(SECTION, key, opts[key])
	cfg.save(_at(path))


static func _at(path: String) -> String:
	return where if path == "" else path
