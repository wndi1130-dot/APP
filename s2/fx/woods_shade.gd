extends MeshInstance3D
## The shade under the side path's trees (game/world/side_path.gd; 결정 450, the side
## path's fog and light are the look's). The belt round the clearing is darkest; a
## sparse-woods tree shades its cell and, less, the cells round it; the gap and the
## clearing stay open to the sky, so the way in reads as the light opening in a dark
## tree line. One sheet a hair over the ground that multiplies it (woods_shade.gdshader);
## the trees, the store and people stand over it. Soft at its edges: a corner takes the
## mean of its four cells.

const SHADER := preload("res://fx/shaders/woods_shade.gdshader")
## How much of the ground's light the trees take: under the belt, under a sparse-woods
## tree, and in the cells round one.
const BELT := 0.5
const TREE := 0.28
const NEAR := 0.14
## Over the ground (m), under anything that stands on it.
const LIFT := 0.03

## Cell -> how much light the trees take there (0..1).
var dark: Dictionary = {}


## The side path's shade by cell (side_path.gd keys belt, woods, gap).
static func darkness(sp: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for c: Vector2i in sp.get("woods", []):
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				out[n] = maxf(float(out.get(n, 0.0)), TREE if n == c else NEAR)
	for c: Vector2i in sp.get("belt", []):
		out[c] = BELT
	for c: Vector2i in sp.get("gap", []):
		out.erase(c)
	return out


func setup(sp: Dictionary) -> void:
	name = "WoodsShade"
	dark = darkness(sp)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if dark.is_empty():
		return
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := -lo
	for c: Vector2i in dark:
		lo = lo.min(c)
		hi = hi.max(c)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(lo.y, hi.y + 2):
		for x in range(lo.x, hi.x + 2):
			var k := [_corner(x, y), _corner(x + 1, y), _corner(x + 1, y + 1), _corner(x, y + 1)]
			if k[0] + k[1] + k[2] + k[3] <= 0.0:
				continue
			var p := [Vector3(x, LIFT, y), Vector3(x + 1, LIFT, y), Vector3(x + 1, LIFT, y + 1), Vector3(x, LIFT, y + 1)]
			for i in [0, 2, 1, 0, 3, 2]:
				st.set_color(Color(1, 1, 1, k[i]))
				st.set_normal(Vector3.UP)
				st.add_vertex(p[i])
	mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = SHADER
	material_override = m


## A grid corner (x, y) takes the mean of the four cells round it.
func _corner(x: int, y: int) -> float:
	var s := 0.0
	for c in [Vector2i(x - 1, y - 1), Vector2i(x, y - 1), Vector2i(x - 1, y), Vector2i(x, y)]:
		s += float(dark.get(c, 0.0))
	return s * 0.25
