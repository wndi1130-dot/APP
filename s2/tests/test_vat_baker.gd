extends "res://addons/gut/test.gd"

const VatBaker = preload("res://scripts/vat_baker.gd")

func test_default_box_zombie_keeps_one_row_per_frame() -> void:
	var assets := VatBaker.build()
	assert_eq(int(assets["vertices"]), 144)
	assert_eq(int(assets["rows_per_frame"]), 1)
	assert_eq(int(assets["height"]), VatBaker.FRAMES * 2)

func test_dense_zombie_folds_rows_and_writes_last_vertex() -> void:
	var assets := VatBaker.build(1500, 1024)
	var vertices := int(assets["vertices"])
	var rows := int(assets["rows_per_frame"])
	assert_true(vertices >= 1500, "vertices %d" % vertices)
	assert_eq(int(assets["width"]), 1024)
	assert_eq(rows, ceili(vertices / 1024.0))
	assert_true(rows > 1)
	assert_eq(int(assets["height"]), VatBaker.FRAMES * 2 * rows)
	# Chase clip, quarter phase: the last vertex is on a swinging leg.
	var image: Image = assets["image"]
	var last := vertices - 1
	var texel := image.get_pixel(last % 1024, (VatBaker.FRAMES + VatBaker.FRAMES / 4) * rows + last / 1024)
	assert_eq(texel.a, 1.0)
	assert_true(absf(texel.g - 0.5) + absf(texel.b - 0.5) > 0.01)
	gut.p("VAT 1500 target: %d vertices, %dx%d" % [vertices, int(assets["width"]), int(assets["height"])])

func test_device_levels_fit_without_folding() -> void:
	var assets := VatBaker.build(3000)
	assert_true(int(assets["vertices"]) >= 3000)
	assert_true(int(assets["width"]) <= VatBaker.MAX_WIDTH)
	gut.p("VAT 3000 target: %d vertices, rows %d" % [int(assets["vertices"]), int(assets["rows_per_frame"])])
