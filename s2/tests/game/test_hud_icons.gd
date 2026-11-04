extends "res://addons/gut/test.gd"
## The icons (hud_icons.gd): every one is drawn at the size asked for, the
## names the screens ask for are all there, and an unknown one draws nothing.

const HudIcons = preload("res://game/ui/hud_icons.gd")


func test_every_icon_draws_at_the_size_asked_for() -> void:
	for id in HudIcons.PATHS.keys():
		var tex: Texture2D = HudIcons.texture(id, 24, Color.WHITE)
		assert_not_null(tex, id)
		if tex != null:
			assert_eq(tex.get_size(), Vector2(48, 48), id + ": drawn at twice its size for a sharp edge")
	assert_null(HudIcons.texture("nothing_like_it", 24, Color.WHITE))


func test_the_names_the_screens_ask_for_are_there() -> void:
	# The top band's six, the field's keys, the paper's marks and the context pad.
	for id in ["fist", "hand", "coal", "food", "med", "lux",
			"aim", "bandage", "compass", "crouch", "gear", "gun", "inv", "lamp", "pause", "play", "promise", "radio", "run", "search", "shove", "train",
			"people", "fetch", "eye", "back", "fwd", "door", "stairs"]:
		assert_true(HudIcons.PATHS.has(id), id)
	for label in ["붕대 감기", "문 열기", "위로 가기", "열차로", "뒤지기"]:
		assert_true(HudIcons.PATHS.has(HudIcons.context_icon(label)), label)


func test_a_see_through_colour_is_the_whole_icons_alpha() -> void:
	var tex: Texture2D = HudIcons.texture("dot", 24, Color(1, 1, 1, 0.5))
	var img: Image = tex.get_image()
	var top: float = 0.0
	for y in img.get_height():
		for x in img.get_width():
			top = maxf(top, img.get_pixel(x, y).a)
	assert_almost_eq(top, 0.5, 0.02, "no part is more solid than the colour says")


func test_sled_context_icons_resolve_and_draw_visible_pixels() -> void:
	for label: String in ["썰매 엮기", "썰매 짐", "끈다", "놓는다"]:
		assert_eq(HudIcons.context_icon(label), "sled", label)
		assert_ne(HudIcons.context_icon(label), "search", label)
	var tex: Texture2D = HudIcons.texture("sled", 24, Color.WHITE)
	assert_not_null(tex)
	if tex == null:
		return
	assert_eq(tex.get_size(), Vector2(48, 48))
	var img: Image = tex.get_image()
	var visible: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				visible += 1
	assert_gt(visible, 0, "the sled path must produce a nonempty picture")


## Every thing the situation pad can offer shows a picture of that thing, not
## the magnifier (user 2026-10-25: a key whose picture does not say what it does).
func test_each_situation_shows_its_own_picture() -> void:
	var want := {
		"맨홀 막기": "manhole", "창": "window", "옥상으로": "ladder", "사다리 내려가기": "ladder",
		"줍기": "pickup", "입기": "wear", "문 따기": "unlock", "문 막기": "barricade", "문 열기": "door", "문 닫기": "door",
		"말뚝 깎기": "stake", "방벽 세우기": "wall", "뒤지기": "rummage", "품 뒤지기": "body",
		"올라가기": "stairs", "내려가기": "stairs", "열차 넘기 4초": "train",
		"붕대": "bandage", "부목": "bandage", "눈으로 문지름": "bandage", "다리 치료": "bandage",
	}
	for label in want:
		assert_eq(HudIcons.context_icon(label), want[label], label)
	assert_eq(HudIcons.context_icon("우물"), "search", "a place by its own name: look at it")
	for row in HudIcons.CONTEXT_ICONS:
		assert_true(HudIcons.PATHS.has(String(row[2])), String(row[2]))
