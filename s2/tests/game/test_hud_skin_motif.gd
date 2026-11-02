extends GutTest
## Material marks change the rim, not the plate's shape.

const HudSkin = preload("res://game/ui/hud_skin.gd")
const MOTIFS: Array[String] = ["stitch", "tape", "hammered", "twine", "rivet"]


func test_motifs_keep_the_plain_plate_shape() -> void:
	for round_key: bool in [true, false]:
		for seen: Vector2 in [Vector2.ZERO, Vector2(84, 84), Vector2(124, 48)]:
			for rect: Rect2 in [Rect2(13, 19, 128, 112), Rect2(-7, 5, 44, 32)]:
				for sink: float in [0.0, HudSkin.PRESS_SINK]:
					var plain := HudSkin.Plate.new()
					plain.setup(seen, round_key, HudSkin.Light.NONE)
					plain.sink = sink
					for motif: String in MOTIFS:
						var plate := HudSkin.Plate.new()
						plate.setup(seen, round_key, HudSkin.Light.NONE)
						plate.motif = motif
						plate.sink = sink
						assert_eq(plate._shape(rect), plain._shape(rect), "%s keeps the same rect" % motif)


func test_key_styles_passes_motif_to_all_four_plates() -> void:
	for motif: String in MOTIFS:
		var styles: Dictionary = HudSkin.key_styles(Vector2(84, 84), true, HudSkin.Light.BRASS, HudSkin.Light.NONE, motif)
		for state: String in ["normal", "down", "pressed", "disabled"]:
			var plate: HudSkin.Plate = styles[state]
			assert_eq(plate.motif, motif, "%s carries %s" % [state, motif])
		assert_eq(styles["hover"], styles["normal"])
		assert_eq(styles["hover_pressed"], styles["pressed"])
		assert_eq(styles["down"].sink, HudSkin.PRESS_SINK)
		assert_eq(styles["disabled"].dim, 0.34)


func test_ring_and_rim_colours_have_low_saturation() -> void:
	var colours := {"RING": HudSkin.RING, "RIM1": HudSkin.RIM1, "RIM2": HudSkin.RIM2, "RIM3": HudSkin.RIM3}
	for name: String in colours:
		var colour: Color = colours[name]
		assert_lt(colour.s, 0.25, "%s stays quiet on snow" % name)
