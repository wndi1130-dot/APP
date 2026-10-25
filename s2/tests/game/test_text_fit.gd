extends "res://addons/gut/test.gd"
## 단추 글자 넘침(text_fit.gd, 사용자 2026-10-25: 버튼 안의 글자가 튀어나오는 것들이 있다):
## 단추가 보이는 판(원판의 가운데 폭, 알약의 길이) 안에 글자가 들어가게 글자 크기를 줄이고,
## 그래도 넘치면 단추 안에서 말줄임으로 끝낸다. 단추 크기는 그대로다.

const TextFit = preload("res://game/ui/text_fit.gd")
const HudSkin = preload("res://game/ui/hud_skin.gd")
const FieldGame = preload("res://game/field_game.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


func _pill(text: String, seen: Vector2, font_size: int = 22, round_key: bool = false) -> Button:
	var b: Button = add_child_autofree(Button.new())
	b.text = text
	b.custom_minimum_size = seen + Vector2(20, 20)
	b.size = b.custom_minimum_size
	# The HUD's own word face: the engine's default has no Korean on a bare machine.
	b.add_theme_font_override("font", UiFonts.face(UiFonts.WORD, 400))
	b.add_theme_font_size_override("font_size", font_size)
	var st: Dictionary = HudSkin.key_styles(seen, round_key)
	b.add_theme_stylebox_override("normal", st["normal"])
	return b


func _fits(b: Button) -> bool:
	var size: int = b.get_theme_font_size("font_size")
	return TextFit.widest(b.get_theme_font("font"), b.text, size) <= TextFit.room_of(b) + 0.5


func test_a_long_word_steps_down_to_fit_its_plate() -> void:
	var fit: Node = add_child_autofree(TextFit.new())
	var b := _pill("모두 열차로", Vector2(110, 52))
	var room: float = TextFit.room_of(b)
	assert_lt(room, 110.0, "the room is the plate's, less a little clear")
	assert_gt(TextFit.widest(b.get_theme_font("font"), b.text, 22), room, "the test needs a word too wide at first")
	fit.fit(b)
	assert_true(_fits(b), "now it fits")
	assert_lt(b.get_theme_font_size("font_size"), 22)
	assert_false(b.clip_text)
	assert_eq(b.custom_minimum_size, Vector2(130, 72), "the key keeps its size")
	b.text = "출발"
	fit.fit(b)
	assert_eq(b.get_theme_font_size("font_size"), 22, "a short word goes back to its own size")


func test_a_disc_gives_its_middle_not_its_box() -> void:
	var round_key := _pill("RUN", Vector2(82, 82), 22, true)
	var pill := _pill("RUN", Vector2(82, 82), 22, false)
	assert_lt(TextFit.room_of(round_key), TextFit.room_of(pill))


func test_a_word_that_cannot_fit_ends_inside_the_key() -> void:
	var fit: Node = add_child_autofree(TextFit.new())
	var b := _pill("아주 길고 긴 행동 이름이 여기 있다", Vector2(90, 52))
	fit.fit(b)
	assert_eq(b.get_theme_font_size("font_size"), maxi(TextFit.LEAST, int(ceil(22.0 * TextFit.SMALLEST))), "no smaller than its least")
	assert_true(b.clip_text, "cut inside the key")
	assert_eq(b.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)


## The whole field HUD, with the settings pane open: no key's word sticks out.
func test_no_key_on_the_field_hud_sticks_out() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	var hud = game.hud
	assert_not_null(hud.text_fit)
	for panel in ["", "settings"]:
		if panel == "settings":
			hud.settings_panel()
		hud.text_fit.fit_all()
		var out: Array = []
		for b in hud.root.find_children("*", "Button", true, false):
			var key := b as Button
			if key.text == "" or not key.is_visible_in_tree():
				continue
			if not _fits(key) and not key.clip_text:
				out.append("%s「%s」" % [key.name, key.text])
		assert_eq(out, [], "%s: every word inside its key" % (panel if panel != "" else "field"))


## The words that change with the moment, at their longest (found too wide
## before: 「뒤에서! 밀쳐!」 by 9 px, 「작업조 12 / 석탄」 by 8 px).
func test_the_changing_words_fit_at_their_longest() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	var hud = game.hud
	var tries := {
		"grab_button": ["밀쳐!", "뒤에서! 밀쳐!"], "crew_button": ["작업조 3\n석탄", "작업조 12\n석탄"],
		"all_aboard_button": ["모두 열차로"], "bag_button": ["12.4/16", "128.5/160"],
	}
	for key in tries:
		var b: Button = hud.get(key)
		b.visible = true
		for word in tries[key]:
			b.text = word
			hud.text_fit.fit(b)
			assert_true(_fits(b) or b.clip_text, "%s 「%s」" % [key, word])
			assert_false(b.clip_text and word != "128.5/160", "%s 「%s」 fits by its size alone" % [key, word])
