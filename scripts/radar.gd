extends Control
## The heartbeat sensor readout.
##
## Only shows contacts while a TRACK ping is live, and the dots are the *pulsed*
## positions from phone.gd rather than live ones — so a target who keeps moving
## leaves you chasing where they were half a second ago. That gap is the whole
## reason tracking doesn't just win the game.

const RANGE_METRES := 48.0
const BG := Color(0.04, 0.06, 0.08, 0.58)
## Contacts stay red whatever your theme is — a target has to read as a target.
const CONTACT := Color(1.0, 0.32, 0.36)
## Sonar green is the radar's own identity, not the phone theme.
const SONAR_A := Color(0.28, 0.95, 0.72, 0.30)
const SONAR_B := Color(0.28, 0.95, 0.72, 0.16)
const SONAR_C := Color(0.28, 0.95, 0.72, 0.14)

var player = null
var phone = null

var _sweep_angle := 0.0
var _was_active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	# Off-ping the radar is a static ring and the words NO SIGNAL. Only the live
	# sweep needs a frame-by-frame redraw.
	var active: bool = phone != null and phone.tracking_active()
	if not active:
		if _was_active:
			_was_active = false
			queue_redraw()
		return
	_was_active = true
	_sweep_angle = fmod(_sweep_angle + delta * 2.4, TAU)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	var active: bool = phone != null and phone.tracking_active()

	draw_circle(c, r, BG)
	draw_arc(c, r, 0.0, TAU, 48, SONAR_A, 2.0, true)
	draw_arc(c, r * 0.62, 0.0, TAU, 40, SONAR_B, 1.0, true)
	draw_arc(c, r * 0.30, 0.0, TAU, 32, SONAR_B, 1.0, true)
	draw_line(c - Vector2(r, 0), c + Vector2(r, 0), SONAR_C, 1.0)
	draw_line(c - Vector2(0, r), c + Vector2(0, r), SONAR_C, 1.0)

	# You, always dead centre, always pointing up.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -7), c + Vector2(5, 5), c + Vector2(0, 2), c + Vector2(-5, 5),
	]), Color(0.85, 0.95, 1.0, 0.92))

	if active:
		var tip := c + Vector2(sin(_sweep_angle), -cos(_sweep_angle)) * r
		draw_line(c, tip, Color(0.30, 1.0, 0.72, 0.60), 2.0)
		_draw_contacts(c, r)
	else:
		var font := ThemeDB.fallback_font
		var text := "NO SIGNAL"
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, c + Vector2(-w * 0.5, r - 8.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.80, 0.68, 0.5))


func _draw_contacts(c: Vector2, r: float) -> void:
	if player == null or phone == null:
		return
	var origin: Vector3 = player.global_position
	var yaw: float = player.yaw
	var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 7.0)

	for pid in phone.revealed:
		var world_pos: Vector3 = phone.revealed[pid]
		var offset := Vector2(world_pos.x - origin.x, world_pos.z - origin.z)
		var distance := offset.length()
		# Rotate into view space so "up" on the radar is where you're facing.
		var local := offset.rotated(yaw)
		var screen := c + Vector2(local.x, local.y) / RANGE_METRES * r

		var clamped := distance > RANGE_METRES
		if clamped:
			screen = c + (screen - c).normalized() * (r - 5.0)

		draw_circle(screen, 9.0 * pulse, Color(CONTACT.r, CONTACT.g, CONTACT.b, 0.25))
		draw_circle(screen, 4.0, Color(CONTACT.r, CONTACT.g, CONTACT.b, 0.95))

		var font := ThemeDB.fallback_font
		var text := "%dm" % int(distance)
		draw_string(font, screen + Vector2(6, -5), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.8, 0.8, 0.8))
