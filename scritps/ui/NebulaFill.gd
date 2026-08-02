extends RefCounted
class_name NebulaFill

## One seamless nebula image, stretched across the primary CTA.
## Baked once so the fill cannot show procedural / tiled UV seams.

const WIDTH := 1024
const HEIGHT := 384

static var _cached: ImageTexture


static func texture() -> ImageTexture:
	if _cached != null:
		return _cached
	_cached = ImageTexture.create_from_image(_bake())
	return _cached


static func _bake() -> Image:
	var img := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var n1 := FastNoiseLite.new()
	n1.seed = 720
	n1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n1.frequency = 0.0035
	n1.fractal_type = FastNoiseLite.FRACTAL_FBM
	n1.fractal_octaves = 4

	var n2 := FastNoiseLite.new()
	n2.seed = 931
	n2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n2.frequency = 0.0055
	n2.fractal_type = FastNoiseLite.FRACTAL_FBM
	n2.fractal_octaves = 3

	var n3 := FastNoiseLite.new()
	n3.seed = 144
	n3.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n3.frequency = 0.008

	var deep := Color(0.03, 0.015, 0.08)
	var navy := Color(0.05, 0.09, 0.30)
	var violet := Color(0.28, 0.07, 0.42)
	var magenta := Color(0.62, 0.12, 0.44)
	var hot_pink := Color(0.85, 0.28, 0.58)
	var electric := Color(0.22, 0.40, 0.88)

	for y in HEIGHT:
		for x in WIDTH:
			var u := float(x) / float(WIDTH)
			var v := float(y) / float(HEIGHT)
			var a := (n1.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var b := (n2.get_noise_2d(float(x) * 1.1 + 40.0, float(y) * 0.9) + 1.0) * 0.5
			var c := (n3.get_noise_2d(float(x) * 0.7, float(y) * 1.2 + 20.0) + 1.0) * 0.5

			var col := deep
			col = col.lerp(navy, smoothstep(0.05, 0.85, a))
			col = col.lerp(violet, smoothstep(0.1, 0.95, b) * 0.8)
			col = col.lerp(magenta, smoothstep(0.25, 1.05, b) * 0.55)
			col = col.lerp(hot_pink, smoothstep(0.35, 1.1, c) * 0.4)
			col = col.lerp(electric, smoothstep(0.15, 0.75, a) * smoothstep(0.2, 0.9, 1.0 - b) * 0.22)

			## Soft static bloom — no traveling edge.
			var gx := (u - 0.42) * 1.05
			var gy := (v - 0.38) * 1.25
			var glow := exp(-(gx * gx + gy * gy) * 2.2)
			col += Color(0.12, 0.06, 0.16) * glow * 0.35

			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))

	## Stars are animated in the button shader (twinkle in place) — keep bake nebula-only.
	return img
