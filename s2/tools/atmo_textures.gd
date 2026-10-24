extends SceneTree
## Makes the atmosphere frame's photo textures from CC0 originals kept outside
## the repository (C:\dev\zombie\assets_raw\polyhaven, Poly Haven, 결정 424):
## - sky bands: the half of each 2k sky that faces the sun, from the horizon up
##   to 40 degrees, tone-mapped to 1024x256 (fx/textures/sky/<name>.jpg);
## - ground detail: four 1k ground photos reduced to their light and dark
##   (512, one per channel: R snow, G autumn leaf, B wet soil, A grit) in
##   fx/textures/ground_detail.png, so the field reads them in one fetch.
##   godot --headless --path s2 -s res://tools/atmo_textures.gd -- --src=<folder>
## The picture rules that read them are in fx/atmosphere.gd and the shaders.

const Atmosphere = preload("res://fx/atmosphere.gd")

## Up to how high the band reaches (degrees above the horizon).
const BAND_TOP_DEG := 40.0
const BAND_SIZE := Vector2i(1024, 256)
const GROUND_SIZE := 512
## The blur that finds the broad marks: the tile shrunk this many times.
const BROAD_DIV := 32
## R, G, B, A of the ground detail.
const GROUND: Array = ["snow_02_diff_1k.jpg", "forest_leaves_02_diffuse_1k.jpg", "brown_mud_02_diff_1k.jpg", "ground_grey_diff_1k.jpg"]

var src := "C:/dev/zombie/assets_raw/polyhaven"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--src="):
			src = a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://fx/textures/sky"))
	for key in Atmosphere.SKY_PHOTOS:
		var row: Dictionary = Atmosphere.SKY_PHOTOS[key]
		_sky(src.path_join(String(row["source"]) + "_2k.hdr"), Atmosphere.sky_path(key))
	_ground()
	quit()


static func _luma(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


## The column (0..w) where the sky is brightest low down: the sun's side.
static func _sun_column(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var best := 0
	var best_v := -1.0
	var y0 := int(h * (0.5 - 30.0 / 180.0))
	var y1 := int(h * 0.5)
	var cols := PackedFloat32Array()
	cols.resize(w)
	for x in range(0, w, 2):
		var s := 0.0
		for y in range(y0, y1, 4):
			s += minf(_luma(img.get_pixel(x, y)), 50.0)
		cols[x] = s
	# Smooth over about 20 degrees so one bright cloud edge does not win.
	var span := int(w / 18.0)
	for x in range(0, w, 2):
		var s := 0.0
		for dx in range(-span, span + 1, 4):
			s += cols[posmod(x + dx, w) & ~1]
		if s > best_v:
			best_v = s
			best = x
	return best


func _sky(path: String, out: String) -> void:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		push_error("no sky at " + path)
		return
	img.convert(Image.FORMAT_RGBF)
	var w := img.get_width()
	var h := img.get_height()
	var centre := _sun_column(img)
	var top := int(h * (0.5 - BAND_TOP_DEG / 180.0))
	var rows := int(h * 0.5) - top
	# Half the round sky, centred on the sun (it wraps past the seam).
	var half := w / 2
	var band := Image.create(half, rows, false, Image.FORMAT_RGBF)
	var x0 := posmod(centre - half / 2, w)
	for x in range(half):
		band.blit_rect(img, Rect2i(posmod(x0 + x, w), top, 1, rows), Vector2i(x, 0))
	band.resize(BAND_SIZE.x, BAND_SIZE.y, Image.INTERPOLATE_CUBIC)
	# Exposure from the middle light, then a soft shoulder: clouds keep their
	# shape, the sun goes to a white blob, the night stays dark.
	var lums := PackedFloat32Array()
	for y in range(0, BAND_SIZE.y, 4):
		for x in range(0, BAND_SIZE.x, 4):
			lums.append(_luma(band.get_pixel(x, y)))
	lums.sort()
	var median := maxf(lums[lums.size() / 2], 0.0001)
	var exposure := 0.42 / median
	var out_img := Image.create(BAND_SIZE.x, BAND_SIZE.y, false, Image.FORMAT_RGB8)
	var mean := 0.0
	for y in range(BAND_SIZE.y):
		for x in range(BAND_SIZE.x):
			var c := band.get_pixel(x, y) * exposure
			var l := _luma(c)
			var k := (1.0 + l / 9.0) / (1.0 + l)
			var t := Color(c.r * k, c.g * k, c.b * k)
			t = Color(clampf(t.r, 0.0, 1.0), clampf(t.g, 0.0, 1.0), clampf(t.b, 0.0, 1.0)).linear_to_srgb()
			out_img.set_pixel(x, y, t)
			mean += _luma(t)
	out_img.save_jpg(ProjectSettings.globalize_path(out), 0.9)
	print("%s <- %s: sun column %d of %d, median %.4f, mean %.3f" % [out, path.get_file(), centre, w, median, mean / float(BAND_SIZE.x * BAND_SIZE.y)])


func _ground() -> void:
	var out := Image.create(GROUND_SIZE, GROUND_SIZE, false, Image.FORMAT_RGBA8)
	var chans: Array = []
	for f in GROUND:
		var img := Image.load_from_file(src.path_join(String(f)))
		if img == null or img.is_empty():
			push_error("no ground photo " + String(f))
			return
		img.convert(Image.FORMAT_RGB8)
		img.resize(GROUND_SIZE, GROUND_SIZE, Image.INTERPOLATE_LANCZOS)
		# The broad marks (ruts, big blotches) would line up into a grid when
		# the tile repeats: take the light of a blurred copy away, keep the grain.
		# The blur runs over the tile laid three by three, so it wraps at the edges.
		var n := GROUND_SIZE
		var broad := Image.create(n * 3, n * 3, false, Image.FORMAT_RGB8)
		for ty in 3:
			for tx in 3:
				broad.blit_rect(img, Rect2i(0, 0, n, n), Vector2i(tx * n, ty * n))
		var side := n * 3
		while side > n * 3 / BROAD_DIV:
			side /= 2
			broad.resize(side, side, Image.INTERPOLATE_BILINEAR)
		broad.resize(n * 3, n * 3, Image.INTERPOLATE_CUBIC)
		broad = broad.get_region(Rect2i(n, n, n, n))
		# Light and dark only, centred on 0.5 with the same spread for all four,
		# so the shader can lay each over the map's own colours.
		var vals := PackedFloat32Array()
		vals.resize(GROUND_SIZE * GROUND_SIZE)
		var mean := 0.0
		for y in range(GROUND_SIZE):
			for x in range(GROUND_SIZE):
				var v := _luma(img.get_pixel(x, y).srgb_to_linear()) - _luma(broad.get_pixel(x, y).srgb_to_linear())
				vals[y * GROUND_SIZE + x] = v
				mean += v
		mean /= float(vals.size())
		var var_sum := 0.0
		for v in vals:
			var_sum += (v - mean) * (v - mean)
		var sd := maxf(sqrt(var_sum / float(vals.size())), 0.0001)
		# A few deep marks (holes in the snow) must not set the spread for the rest.
		var_sum = 0.0
		for i in vals.size():
			vals[i] = clampf(vals[i] - mean, -1.6 * sd, 1.6 * sd)
			var_sum += vals[i] * vals[i]
		sd = maxf(sqrt(var_sum / float(vals.size())), 0.0001)
		for i in vals.size():
			vals[i] = clampf(0.5 + vals[i] / sd * 0.16, 0.0, 1.0)
		chans.append(vals)
		print("ground %s: mean %.3f, spread %.3f" % [f, mean, sd])
	for y in range(GROUND_SIZE):
		for x in range(GROUND_SIZE):
			var i := y * GROUND_SIZE + x
			out.set_pixel(x, y, Color(chans[0][i], chans[1][i], chans[2][i], chans[3][i]))
	out.save_png(ProjectSettings.globalize_path(Atmosphere.GROUND_DETAIL))
	print("ground detail -> " + Atmosphere.GROUND_DETAIL)
