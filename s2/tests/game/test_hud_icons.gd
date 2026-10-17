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
