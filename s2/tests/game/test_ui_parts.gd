extends "res://addons/gut/test.gd"
## The parts the 「성에 낀 계기」 screens are made of (UI 3단계 시안 2차): the
## mockup's faces at its sizes, the lamp key, the sheet of paper and what is
## drawn on it, and the stop card laid out on the mockup's lines.

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const LampKey = preload("res://game/ui/lamp_key.gd")
const PaperSheet = preload("res://game/ui/paper_sheet.gd")
const Paper = preload("res://game/ui/paper_parts.gd")
const StopPickCard = preload("res://game/ui/stop_pick_card.gd")


func test_mockup_px_turn_into_game_px() -> void:
	assert_almost_eq(UiFonts.K, 720.0 / 390.0, 0.0001)
	assert_almost_eq(UiFonts.px(390.0), 720.0, 0.001, "the mockup's stage is the game's height")
	assert_eq(UiFonts.size(12.0), 22, "a 12 px word is 22 on the phone")


func test_the_faces_are_the_mockups_with_their_licences() -> void:
	var word: FontVariation = UiFonts.face(UiFonts.WORD, 400)
	assert_true(word.base_font.resource_path.ends_with("IBMPlexSansKR-Regular.ttf"))
	assert_true((UiFonts.face(UiFonts.WORD, 600) as FontVariation).base_font.resource_path.ends_with("IBMPlexSansKR-SemiBold.ttf"))
	var num: FontVariation = UiFonts.face(UiFonts.NUMBER, 500)
	assert_true(num.base_font.resource_path.ends_with("BarlowCondensed-Medium.ttf"))
	assert_eq(num.fallbacks.size(), 1, "the number face falls back to the word face for Korean")
	var ts := TextServerManager.get_primary_interface()
	assert_eq(int(num.opentype_features.get(ts.name_to_tag("tnum"), 0)), 1, "numbers in even columns")
	var hand: FontVariation = UiFonts.face(UiFonts.HAND, 400)
	assert_true(hand.base_font.resource_path.ends_with("NanumPenScript-Regular.ttf"))
	assert_same(UiFonts.face(UiFonts.WORD, 400), word, "a face is made once")
	for f in ["OFL_IBMPlexSansKR.txt", "OFL_BarlowCondensed.txt", "OFL_NanumPenScript.txt"]:
		assert_true(FileAccess.file_exists(UiFonts.DIR + f), f)


func test_font_release_keeps_labels_and_recreates_equal_faces() -> void:
	var labels: Array[Label] = []
	var fonts: Array[FontVariation] = []
	for kind in [UiFonts.WORD, UiFonts.NUMBER, UiFonts.HAND]:
		var label: Label = autofree(UiFonts.label("열차 123", kind, 600, 13.0, Color.WHITE, 0.5))
		labels.append(label)
		fonts.append(label.get_theme_font("font"))
	assert_false(UiFonts._made.is_empty())
	assert_false(UiFonts._files.is_empty())
	for i in 2:
		UiFonts.release()
		assert_true(UiFonts._made.is_empty())
		assert_true(UiFonts._files.is_empty())
	for kind in [UiFonts.WORD, UiFonts.NUMBER, UiFonts.HAND]:
		var old: FontVariation = fonts[kind]
		assert_true(is_instance_valid(labels[kind]))
		assert_same(labels[kind].get_theme_font("font"), old)
		assert_false(old.get_font_name().is_empty())
		assert_eq(labels[kind].get_theme_font_size("font_size"), UiFonts.size(13.0))
		var label: Label = autofree(UiFonts.label("열차 123", kind, 600, 13.0, Color.WHITE, 0.5))
		var fresh: FontVariation = label.get_theme_font("font")
		assert_not_same(fresh, old, "the variation is recreated")
		assert_eq(fresh.get_font_name(), old.get_font_name())
		assert_eq(fresh.get_font_style_name(), old.get_font_style_name())
		assert_eq(fresh.base_font.resource_path, old.base_font.resource_path)
		assert_eq(label.get_theme_font_size("font_size"), labels[kind].get_theme_font_size("font_size"))
		for property: String in ["spacing_glyph", "variation_opentype", "variation_embolden",
				"variation_transform", "variation_face_index", "opentype_features"]:
			assert_eq(fresh.get(property), old.get(property), property)
		assert_eq(fresh.fallbacks.size(), old.fallbacks.size())
		for i in fresh.fallbacks.size():
			assert_eq(fresh.fallbacks[i].get_font_name(), old.fallbacks[i].get_font_name())
			assert_eq(fresh.fallbacks[i].resource_path, old.fallbacks[i].resource_path)


func test_the_lamp_key_is_148_by_48_and_goes_dim_when_off() -> void:
	var k = LampKey.new("보내기")
	add_child_autofree(k)
	assert_eq(k.custom_minimum_size, LampKey.CSS_SIZE * UiFonts.K)
	assert_eq(k.text, "보내기", "the arrow is drawn by the key, not written")
	k.set_off(true)
	assert_true(k.disabled)
	assert_true(bool((k.face.material as ShaderMaterial).get_shader_parameter("off")))


func test_a_lamp_key_sized_before_it_is_in_the_tree_lays_its_face_to_that_size() -> void:
	var k = LampKey.new("처음으로")
	k.size = k.custom_minimum_size
	add_child_autofree(k)
	var reach: float = UiFonts.px(LampKey.REACH_CSS)
	assert_eq((k.face.material as ShaderMaterial).get_shader_parameter("key_size"), k.size, "the face drawn to the key")
	assert_eq(k.face.size, k.size + Vector2(reach, reach) * 2.0)


func test_two_way_particles_settle_by_the_letter_before_them() -> void:
	assert_eq(UiFonts.josa("꼬리칸과(와)의 약속"), "꼬리칸과의 약속")
	assert_eq(UiFonts.josa("경비대과(와)의 약속"), "경비대와의 약속")
	assert_eq(UiFonts.josa("기관실을(를) 거쳐 열차(으)로"), "기관실을 거쳐 열차로")
	assert_eq(UiFonts.josa("길(으)로, 역(으)로"), "길로, 역으로", "로 after ㄹ")
	assert_eq(UiFonts.josa("앞칸이(가) 둘, 의무진은(는)"), "앞칸이 둘, 의무진은")
	assert_eq(UiFonts.josa("3(으)로 1(으)로 2과(와)"), "3으로 1로 2와", "a digit read as its number")
	assert_eq(UiFonts.josa("A과(와)"), "A과(와)", "after anything else the two-way form stays")


func test_two_way_particles_after_a_bracket_settle_by_the_word_before_it() -> void:
	assert_eq(UiFonts.josa("블라스타 스트르나도바(기관실)이(가) 안건을 냈다"), "블라스타 스트르나도바(기관실)가 안건을 냈다")
	assert_eq(UiFonts.josa("의무진(둘)이(가) 남았다"), "의무진(둘)이 남았다", "by 진, not by 둘")
	assert_eq(UiFonts.josa("중환자 분류(기준)을(를) 올릴 때"), "중환자 분류(기준)를 올릴 때")
	assert_eq(UiFonts.josa("중환자 분류(기준)(으)로 고쳤다"), "중환자 분류(기준)로 고쳤다")
	assert_eq(UiFonts.josa("아동 노동(짐 꾸리기만)(으)로 고쳤다"), "아동 노동(짐 꾸리기만)으로 고쳤다")
	assert_eq(UiFonts.josa("복사기(1)을(를)"), "복사기(1)를")
	assert_eq(UiFonts.josa("블라스티밀 투레크(85)이(가) 굶어 죽었다"), "블라스티밀 투레크(85)가 굶어 죽었다")
	assert_eq(UiFonts.josa("기관실(앞칸(둘))은(는)"), "기관실(앞칸(둘))은", "brackets inside brackets")
	assert_eq(UiFonts.josa("기관실)이(가)"), "기관실)이(가)", "a closing bracket with no opening one stays")
	assert_eq(UiFonts.josa("알리 슈테판(34)(기관실)이(가) 냈다"), "알리 슈테판(34)(기관실)이 냈다", "brackets one after another")
	assert_eq(UiFonts.josa("기관실)(둘)이(가)"), "기관실)(둘)이(가)", "the first of two brackets has no opening one")
	assert_eq(UiFonts.josa("기관실(앞칸(둘))(34)(으)로"), "기관실(앞칸(둘))(34)로")
	assert_eq(UiFonts.josa("3(34)(기관실)(으)로"), "3(34)(기관실)으로", "a digit before the brackets")
	assert_eq(UiFonts.josa("(34)이(가)"), "(34)이(가)", "brackets with no word before them")


func test_a_sheet_leans_from_its_bottom_left_and_writes_inside_its_margins() -> void:
	var s = PaperSheet.new()
	add_child_autofree(s)
	assert_eq(s.size, PaperSheet.SIZE * UiFonts.K)
	assert_eq(s.pivot_offset, Vector2(0, s.size.y), "it leans from its bottom left corner")
	assert_almost_eq(s.rotation, deg_to_rad(-0.45), 0.0001)
	assert_eq(s.inner.position, Vector2(32, 12) * UiFonts.K)
	assert_eq(s.inner.size, Vector2(386, 318) * UiFonts.K, "446 × 346 less 32 + 28 across and 12 + 16 down")


func test_chips_are_touched_44_high_whatever_is_drawn() -> void:
	assert_almost_eq(Paper.chip("꼬리", false).custom_minimum_size.y, UiFonts.px(44.0), 0.01, "34 drawn, 5 more above and below")
	assert_almost_eq(Paper.target_chip("석탄", true, -1.0).custom_minimum_size.y, UiFonts.px(44.0), 0.01, "38 drawn, 3 more above and below")
	var st: Label = Paper.stamp("고른 것과 같음")
	assert_almost_eq(st.custom_minimum_size.y, UiFonts.px(20.0), 0.01)


## Where `n` is inside `body`, through its parents (no turn or scale between).
func _in(n: Control, body: Control) -> Vector2:
	var p := Vector2.ZERO
	var c: Node = n
	while c != body:
		p += (c as Control).position
		c = c.get_parent()
	return p


func test_the_stop_card_falls_on_the_mockups_lines() -> void:
	var c = StopPickCard.new()
	c.promises = [{"kind": "prologue", "subjects": ["a", "b"]}]
	add_child_autofree(c)
	await wait_frames(3)
	var body: Control = c.body
	var k: float = UiFonts.K
	assert_almost_eq(body.size.y, 318.0 * k, 0.6, "nothing pushes the card past its paper")
	var at := func(name: String, up: int) -> float:
		var n: Node = c.find_child(name, true, false)
		for i in up:
			n = n.get_parent()
		return _in(n as Control, body).y / k
	# c2.css with the kick line and the place's hint taken out (결정 417): 12 over
	# the title line (26), three .frow of 46, .crewline 22, .promline 24, and the
	# keys (48) at the foot. A box row rounds its height up to a whole game px, so
	# a line may come up to 1 mockup px late.
	assert_almost_eq(at.call("Title", 0), 12.0, 1.0, "the title line, with room over the pen")
	assert_null(c.find_child("Scene", true, false), "a stop with no name of its own: no line under it")
	assert_almost_eq(at.call("Target_coal", 1), 38.0, 1.0)
	assert_almost_eq(at.call("Stay_short", 1), 84.0, 1.0)
	assert_almost_eq(at.call("Crew_tail", 1), 130.0, 1.0)
	assert_almost_eq(at.call("CrewLine", 0), 176.0, 1.0)
	assert_almost_eq(at.call("Promises", 1), 198.0, 1.0)
	assert_almost_eq(at.call("Send", 1), 270.0, 1.0, "the keys at the foot (margin-top auto)")
