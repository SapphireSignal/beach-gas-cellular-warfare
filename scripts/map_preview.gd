extends Control
## Top-down schematic of the selected map, drawn rather than shipped as an
## image — so it costs nothing, scales to any screen, and can never fall out of
## sync with the level, because it reads the same coordinates world.gd builds.

const WORLD_W := 62.0    ## Beach Gas spans x -31..31
const WORLD_H := 48.0    ## and z -24..24

var map_id := Maps.DEFAULT_ID
## World size the drawing is currently scaled against. Each map sets its own.
var _extents := Vector2(WORLD_W, WORLD_H)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_map(id: String) -> void:
	map_id = id
	queue_redraw()


func _draw() -> void:
	var accent := Loadout.accent()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.06, 0.92))

	if not Maps.is_available(map_id):
		_draw_locked(accent)
		return

	match map_id:
		"beach_gas": _draw_beach_gas(accent)
		"level_three": _draw_level_three(accent)
		_: _draw_locked(accent)

	draw_rect(Rect2(Vector2.ZERO, size), Color(accent.r, accent.g, accent.b, 0.35), false, 2.0)


func _draw_locked(accent: Color) -> void:
	var font := ThemeDB.fallback_font
	var text := "COMING SOON"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, (size - Vector2(w, -5)) * 0.5, text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(accent.r, accent.g, accent.b, 0.35))
	# Hatching, so a locked slot reads as deliberately empty rather than broken.
	var step := 14.0
	var x := -size.y
	while x < size.x:
		draw_line(Vector2(x, size.y), Vector2(x + size.y, 0.0),
			Color(accent.r, accent.g, accent.b, 0.07), 1.0)
		x += step
	draw_rect(Rect2(Vector2.ZERO, size), Color(accent.r, accent.g, accent.b, 0.18), false, 2.0)


func _draw_beach_gas(accent: Color) -> void:
	_extents = Vector2(WORLD_W, WORLD_H)
	var building := Color(accent.r, accent.g, accent.b, 0.30)
	var outline := Color(accent.r, accent.g, accent.b, 0.75)
	var prop := Color(accent.r, accent.g, accent.b, 0.45)

	# Tarmac.
	_rect(-31, -24, 62, 48, Color(accent.r, accent.g, accent.b, 0.05), true)
	_rect(-31, -24, 62, 48, Color(accent.r, accent.g, accent.b, 0.30), false)

	# Store and its aisles.
	_rect(-24, -23, 22, 12, building, true)
	_rect(-24, -23, 22, 12, outline, false)
	for row in 4:
		_rect(-22.75, -20.5 + row * 2.4, 6.5, 1.0, prop, true)
		_rect(-13.25, -20.5 + row * 2.4, 7.5, 1.0, prop, true)
	_rect(-8, -13.5, 5, 1, prop, true)

	# Loading dock.
	_rect(-2, -23, 8, 8, Color(accent.r, accent.g, accent.b, 0.26), true)
	_rect(-2, -23, 8, 8, outline, false)

	# Summerleaf, with the plant tables out front.
	_rect(12, -22, 14, 14, building, true)
	_rect(12, -22, 14, 14, outline, false)
	_rect(13.2, -13.5, 4.6, 1.0, prop, true)
	_rect(20.4, -13.5, 4.6, 1.0, prop, true)
	_rect(16, -18, 6, 1, prop, true)
	for i in 5:
		_rect(12.2 + i * 3.0, -7.15, 2.4, 1.5, prop, true)

	# Canopy footprint and the three pump islands under it.
	_rect(-18, -4, 24, 16, Color(accent.r, accent.g, accent.b, 0.13), true)
	_rect(-18, -4, 24, 16, Color(accent.r, accent.g, accent.b, 0.45), false)
	for island in 3:
		_rect(-15.5, -2.2 + island * 5.0, 19, 2.4, prop, true)

	# Parked cars.
	for entry in [[12.5, 8.0], [18.3, 8.0], [24.1, 8.0], [14.5, 18.0], [20.3, 18.0]]:
		_rect(entry[0] - 0.95, entry[1] - 2.2, 1.9, 4.4, prop, true)
	_rect(-10.5, -7.7, 4.4, 1.9, prop, true)
	_rect(6.4, -10.5, 2.2, 5.0, prop, true)

	# Dumpster corral and air island.
	_rect(-28, 14, 10, 8, Color(accent.r, accent.g, accent.b, 0.22), true)
	_rect(-28, 14, 10, 8, outline, false)
	_rect(7.3, 4.7, 4.4, 2.6, prop, true)

	# The pylon sign, the one landmark visible from anywhere on the lot.
	draw_circle(_to_screen(-28.0, 20.0), 4.0, Color(1.0, 0.35, 0.4, 0.9))

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(10, size.y - 10), "BEACH GAS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(accent.r, accent.g, accent.b, 0.7))


# ---------------------------------------------------------------------------

## Level 3 Parking is 56 x 44, so it's drawn against its own extents rather than
## the forecourt's — otherwise the garage would float in the middle of a frame
## sized for a different map.
func _draw_level_three(accent: Color) -> void:
	var previous := Vector2(WORLD_W, WORLD_H)
	_extents = Vector2(56.0, 44.0)

	var slab := Color(accent.r, accent.g, accent.b, 0.07)
	var outline := Color(accent.r, accent.g, accent.b, 0.75)
	var prop := Color(accent.r, accent.g, accent.b, 0.45)

	_rect(-28, -22, 56, 44, slab, true)
	_rect(-28, -22, 56, 44, outline, false)

	# Mezzanine over the northern third, drawn brighter because it's above you.
	_rect(-14, -22, 28, 18, Color(accent.r, accent.g, accent.b, 0.24), true)
	_rect(-14, -22, 28, 18, outline, false)

	# Ramp up the west side.
	_rect(-24, -12, 6, 16, Color(accent.r, accent.g, accent.b, 0.18), true)

	# Pillar grid — the thing that defines the map.
	for col in 7:
		for row in 4:
			_rect(-21.45 + col * 7.0, -13.95 + row * 9.0, 0.9, 0.9, outline, true)

	# Stair and lift core.
	_rect(-18, 5, 8, 6, Color(accent.r, accent.g, accent.b, 0.30), true)
	_rect(-18, 5, 8, 6, outline, false)

	# Parked cars in the two ranks.
	for entry in [[-21.5, -9.0], [-14.5, -9.0], [-0.5, -9.0], [13.0, -9.0], [20.0, -9.0],
			[-17.5, 9.0], [-3.0, 9.0], [4.5, 9.0], [18.0, 9.0], [24.5, 9.0]]:
		_rect(entry[0] - 0.95, entry[1] - 2.2, 1.9, 4.4, prop, true)

	# Street-side opening along the south wall.
	var a := _to_screen(-28.0, 22.0)
	var b := _to_screen(28.0, 22.0)
	draw_line(a, b, Color(1.0, 0.82, 0.35, 0.85), 3.0)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(10, size.y - 10), "LEVEL 3 PARKING",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(accent.r, accent.g, accent.b, 0.7))

	_extents = previous


func _to_screen(x: float, z: float) -> Vector2:
	return Vector2((x + _extents.x * 0.5) / _extents.x * size.x,
		(z + _extents.y * 0.5) / _extents.y * size.y)


func _rect(x: float, z: float, w: float, h: float, color: Color, filled: bool) -> void:
	var a := _to_screen(x, z)
	var b := _to_screen(x + w, z + h)
	var r := Rect2(a, b - a)
	if filled:
		draw_rect(r, color)
	else:
		draw_rect(r, color, false, 1.5)
