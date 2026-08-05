extends Control
class_name LoadingScreen
## The screen that covers level generation.
##
## Everything in this game is built at runtime — the whole forecourt, every
## character, every sound — and that work blocks the main thread. Play and Quit
## each spent a couple of seconds showing the player nothing at all, which reads
## as the app having crashed rather than as it working.
##
## This does not make generation faster. It makes it *legible*: something is on
## screen within one frame, it says what is happening, and it animates so the
## phone doesn't look frozen. That distinction is most of the perceived
## difference between an unfinished game and a finished one.
##
## The order matters and is easy to get wrong: show this, then **wait for it to
## actually draw**, and only then start building. Calling show() and building in
## the same frame paints nothing, because the frame never completes.

const FADE_TIME := 0.18

var _label: Label
var _detail: Label
var _bar_fill: ColorRect
var _bar_head: ColorRect
var _bar_back: ColorRect
var _spinner: ColorRect
var _elapsed := 0.0
var _progress := 0.0
var _target := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Palette.SKY_TOP
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# A slab of asphalt across the bottom, so even this screen looks like the
	# game rather than a generic engine splash.
	var ground := ColorRect.new()
	ground.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ground.offset_top = -220.0
	ground.offset_bottom = 0.0
	ground.color = Palette.ASPHALT
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.offset_left = -400.0
	_label.offset_right = 400.0
	_label.offset_top = -60.0
	_label.offset_bottom = -10.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 44)
	_label.add_theme_color_override("font_color", Palette.SIGN_WHITE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	_detail = Label.new()
	_detail.set_anchors_preset(Control.PRESET_CENTER)
	_detail.offset_left = -400.0
	_detail.offset_right = 400.0
	_detail.offset_top = 4.0
	_detail.offset_bottom = 44.0
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_theme_font_size_override("font_size", 26)
	_detail.add_theme_color_override("font_color", Color(0.62, 0.66, 0.78))
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail)

	# Progress track. Deliberately wide and thin — a phone held in landscape has
	# plenty of width and the eye reads a long bar's movement more easily than a
	# short one's.
	_bar_back = ColorRect.new()
	_bar_back.set_anchors_preset(Control.PRESET_CENTER)
	_bar_back.offset_left = -300.0
	_bar_back.offset_right = 300.0
	_bar_back.offset_top = 70.0
	_bar_back.offset_bottom = 78.0
	_bar_back.color = Color(1, 1, 1, 0.10)
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_back)

	_bar_fill = ColorRect.new()
	_bar_fill.color = Palette.ZAP
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.size = Vector2(0.0, 8.0)
	_bar_back.add_child(_bar_fill)

	_bar_head = ColorRect.new()
	_bar_head.color = Color(1.0, 0.86, 0.84)
	_bar_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_head.size = Vector2(18.0, 8.0)
	_bar_back.add_child(_bar_head)

	# A travelling dash above the bar. Progress here is a guess — generation
	# can't report how far along it is — so this carries "still working" while
	# the bar carries "roughly this far".
	_spinner = ColorRect.new()
	_spinner.color = Palette.TRACK
	_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spinner.size = Vector2(64.0, 3.0)
	_spinner.position = Vector2(0.0, -14.0)
	_bar_back.add_child(_spinner)

	# Opaque from frame one. This used to start transparent and fade in, which
	# meant the menu was visible through it for the first fifth of a second -
	# exactly the "why can I see the buttons" Jay reported. A loading screen has
	# nothing to fade in from.
	modulate.a = 1.0


## The bar is driven by wall-clock time, not by frames.
##
## This is the whole trick, and it's why the first version looked frozen: level
## generation *blocks the main thread*, so no frames render while it runs. A bar
## that only advances in _process therefore cannot move during the very work it
## is reporting — it sits still, then jumps at the end.
##
## So the bar creeps forward on its own toward the next milestone, using real
## elapsed time, and each completed stage snaps the floor up. It never goes
## backwards and never reaches 100% early, which is what a bar has to promise.
func _process(delta: float) -> void:
	_elapsed += delta

	# Creep toward the target, slowing as it approaches so it never arrives
	# before the work does. Asymptotic, so it can idle just short of a stage
	# boundary for as long as that stage takes.
	var gap: float = _target - _progress
	if gap > 0.0:
		_progress += gap * (1.0 - exp(-delta * 3.2))
	if _bar_back != null:
		var w: float = _bar_back.size.x
		_bar_fill.size = Vector2(w * _progress, _bar_back.size.y)
		# A brighter head on the leading edge, so the eye has something to track
		# even when the fill is barely moving.
		_bar_head.position.x = maxf(0.0, w * _progress - _bar_head.size.x)
		_bar_head.visible = _progress > 0.02 and _progress < 0.995
		# The travelling dash carries "still working" while the bar carries
		# "roughly this far". It runs on its own clock so it keeps moving even
		# when progress doesn't.
		var span: float = w - _spinner.size.x
		_spinner.position.x = span * (0.5 - 0.5 * cos(_elapsed * 2.2))
		_spinner.modulate.a = 0.35 + 0.35 * sin(_elapsed * 5.0)

	# The title breathes very slightly. Static text on a still screen is the
	# thing that makes a phone look hung.
	if _label != null:
		_label.modulate.a = 0.86 + 0.14 * sin(_elapsed * 2.6)


## `amount` is 0..1 and approximate — nothing here can truthfully report how far
## through a level build it is. It is honest about *stages*, not percentages.
func set_progress(amount: float, detail := "") -> void:
	# Monotonic. A bar that goes backwards reads as a bug even when the number
	# behind it is honest.
	_target = maxf(_target, clampf(amount, 0.0, 1.0))
	if _detail != null and not detail.is_empty():
		_detail.text = detail


func set_title(text: String) -> void:
	if _label != null:
		_label.text = text
