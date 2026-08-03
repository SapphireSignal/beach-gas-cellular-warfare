extends Control
class_name ActionButton
## A round thumb button. Draws itself, including a cooldown wipe.
##
## These deliberately aren't `Button` nodes. All touch routing in the HUD goes
## through a single `_input` handler doing explicit hit tests, because Godot's
## normal Control input path doesn't cope well with several fingers at once —
## and this game needs a thumb on the stick and a thumb on ZAP simultaneously.

@export var label := "ZAP"
@export var sublabel := ""
@export var color := Color(1.0, 0.35, 0.32)
@export var font_size := 20

## 0 = ready, 1 = just fired. Drawn as a wipe that empties clockwise.
var cooldown := 0.0
## Seconds left, printed in the middle of the button so you know how long.
var cooldown_seconds := 0.0
var enabled := true
var held := false
## Shown but not interactive — how these read on desktop, where the mouse and
## keyboard drive everything and the buttons are pure readouts.
var dim := false

var radius := 60.0

## What the last _draw() was built from. Redrawing a canvas item costs the same
## whether anything changed or not, and there are seven of these — so they only
## rebuild when they'd actually look different. Idle, that's zero work a frame
## instead of seven full redraws.
var _drawn: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_recalc)
	_recalc()


func _recalc() -> void:
	radius = minf(size.x, size.y) * 0.5
	queue_redraw()


func contains_point(point: Vector2) -> bool:
	if not visible:
		return false
	return point.distance_to(global_position + size * 0.5) <= radius * 1.12


func _process(_delta: float) -> void:
	# Cooldown seconds are quantised to the tenth that actually gets printed, so
	# a button counting down redraws ten times a second rather than sixty.
	var now := [label, sublabel, enabled, held, dim,
		roundi(cooldown * 120.0), roundi(cooldown_seconds * 10.0)]
	if now == _drawn:
		return
	_drawn = now
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var tint := color if enabled else color.darkened(0.55)
	var alpha := 1.0 if enabled else 0.45
	if dim:
		alpha *= 0.6

	# Body.
	var fill := Color(tint.r, tint.g, tint.b, (0.30 if held else 0.16) * alpha)
	draw_circle(c, radius, fill)

	# Cooldown wipe: the unavailable part of the button is visibly missing.
	if cooldown > 0.001:
		draw_arc(c, radius * 0.80, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - cooldown),
			32, Color(tint.r, tint.g, tint.b, 0.75 * alpha), 5.0, true)
	else:
		draw_arc(c, radius * 0.80, 0.0, TAU, 40, Color(tint.r, tint.g, tint.b, 0.35 * alpha), 2.0, true)

	# Rim.
	draw_arc(c, radius, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, 0.9 * alpha), 3.0, true)

	var font := ThemeDB.fallback_font
	var text_color := Color(1, 1, 1, alpha)

	# While it's recharging the countdown takes the middle and the name drops
	# underneath, so the number is what your eye lands on.
	var counting := cooldown_seconds > 0.05
	var main := label
	var under := sublabel
	var main_size := font_size
	if counting:
		main = "%.1f" % cooldown_seconds if cooldown_seconds < 10.0 else "%d" % ceil(cooldown_seconds)
		under = label
		main_size = font_size + 6

	var w := font.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, main_size).x
	var y_offset := -2.0 if under.is_empty() else -8.0
	draw_string(font, c + Vector2(-w * 0.5, main_size * 0.35 + y_offset),
		main, HORIZONTAL_ALIGNMENT_LEFT, -1, main_size, text_color)

	if not under.is_empty():
		var sw := font.get_string_size(under, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, c + Vector2(-sw * 0.5, main_size * 0.35 + 10.0),
			under, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.62 * alpha))
