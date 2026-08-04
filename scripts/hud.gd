extends Control
## In-match UI and all touch input routing.
##
## Every finger on the screen is handled here in one `_input` method with
## explicit hit tests, rather than by letting Controls consume events. That's
## the only reliable way to have several fingers doing different things at once
## in Godot — and this game needs a thumb on the stick and a thumb on ZAP.
##
## Left ~45% of the screen is a stick that appears wherever you put your thumb.
## Everything to the right of that, minus the buttons, drags the camera.

const STICK_ZONE := 0.45
const STICK_RADIUS := 78.0
const STICK_DEADZONE := 0.14

## A touch in the look area that lifts quickly without travelling far was a tap,
## not a drag — so it fires. This is the thing that makes a phone playable: one
## thumb aims and shoots without ever reaching for a button.
const TAP_MAX_SECONDS := 0.26
const TAP_MAX_TRAVEL := 22.0
## Auto-fire only engages when somebody is genuinely under the reticle.
const AUTO_FIRE_CONE := 4.5

const BAR_WIDTH := 210.0
const BAR_HEIGHT := 14.0
const HEALTH_COLOR := Color(0.95, 0.28, 0.34)
const HEAT_COOL := Color(0.40, 0.78, 1.00)
const HEAT_WARM := Color(1.00, 0.72, 0.25)
const HEAT_LOCKED := Color(1.00, 0.32, 0.22)

@onready var radar = $Radar
@onready var score_label: Label = $ScoreLabel
@onready var feed_label: Label = $FeedLabel
@onready var status_label: Label = $StatusLabel
@onready var result_label: Label = $ResultLabel
@onready var hint_label: Label = $HintLabel
@onready var damage_flash: ColorRect = $DamageFlash
@onready var call_overlay: Control = $CallOverlay
@onready var call_tint: ColorRect = $CallOverlay/Tint
@onready var caller_label: Label = $CallOverlay/CallerLabel
@onready var call_hint: Label = $CallOverlay/CallHint


@onready var zap_btn: ActionButton = $ZapBtn
@onready var track_btn: ActionButton = $TrackBtn
@onready var call_btn: ActionButton = $CallBtn
@onready var jump_btn: ActionButton = $JumpBtn
@onready var crouch_btn: ActionButton = $CrouchBtn
@onready var score_btn: ActionButton = $ScoreBtn
@onready var quit_btn: ActionButton = $QuitBtn
@onready var settings_btn: ActionButton = $SettingsBtn

## In-match setup. Only the three settings worth changing without leaving a
## game: how fast you turn, whether the game helps you aim, and how you fire.
## Quality and volume stay in the menu — nobody retunes shadows mid-duel, and
## every row added here is another thing to mis-tap with a thumb.
@onready var settings_panel: Control = $SettingsPanel
@onready var sens_btn: ActionButton = $SettingsPanel/SensBtn
@onready var assist_btn: ActionButton = $SettingsPanel/AssistBtn
@onready var fire_btn: ActionButton = $SettingsPanel/FireBtn
@onready var close_btn: ActionButton = $SettingsPanel/CloseBtn

## Sensitivity is a cycle rather than a slider: a slider needs a drag, and every
## drag in this HUD is already spoken for by looking and moving.
const SENS_STEPS := [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

var player = null
var phone = null
var touch_mode := true

## finger index -> what that finger is doing
var _roles: Dictionary = {}
## finger index -> { at: Vector2, travel: float, started: float } for look taps
var _look_touches: Dictionary = {}
var _stick_origin := Vector2.ZERO
var _stick_point := Vector2.ZERO
var _stick_active := false

var _flash := 0.0
var _hitmark := 0.0
var _feed_timer := 0.0
var _status_timer := 0.0
var _damage_dirs: Array = []   ## [{ dir: Vector2, until: float }]
var _connected_to = null
var _killer_id := 0
var _respawn_at := 0.0
var _kill_flash := 0.0
var _kill_name := ""
var _scoreboard_pinned := false   ## tapped SCORE on touch
var _scoreboard_held := false     ## holding Tab on desktop
var _match_finished := false
## Slowest frame in the last second, for the perf readout.
var _worst_frame_ms := 0.0
var _worst_window := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_mode = OS.has_feature("mobile")
	_apply_input_mode()
	result_label.hide()
	call_overlay.hide()
	status_label.text = ""
	feed_label.text = ""

	zap_btn.label = "ZAP"
	zap_btn.color = Phone.MODE_COLORS[Phone.MODE_ZAP]
	track_btn.label = "TRACK"
	track_btn.sublabel = "sensor"
	track_btn.color = Phone.MODE_COLORS[Phone.MODE_TRACK]
	call_btn.label = "CALL"
	call_btn.sublabel = "ring them"
	call_btn.color = Phone.MODE_COLORS[Phone.MODE_CALL]
	jump_btn.label = "JUMP"
	jump_btn.color = Color(0.8, 0.82, 0.9)
	crouch_btn.label = "CROUCH"
	crouch_btn.color = Color(0.62, 0.72, 0.95)
	score_btn.label = "SCORE"

	score_btn.color = Color(0.75, 0.78, 0.9)
	quit_btn.label = "QUIT"
	quit_btn.color = Color(0.9, 0.5, 0.45)
	settings_btn.label = "SETUP"
	settings_btn.color = Color(0.72, 0.76, 0.85)
	settings_panel.visible = false

	Net.kill_confirmed.connect(_on_kill)
	Net.feed.connect(_on_feed)
	Net.reconnecting.connect(_on_reconnecting)
	Net.match_over.connect(_on_match_over)
	Net.lobby_changed.connect(_refresh_score)
	_refresh_score()

	_apply_safe_area()
	get_tree().root.size_changed.connect(_apply_safe_area)


## Keep the whole HUD inside the phone's usable screen.
##
## An iPhone in landscape has a notch down one side and a home indicator along
## the bottom, and iOS will happily draw underneath both. The radar sits top
## left and ZAP sits bottom right, which is exactly where those two live.
##
## Insetting this Control moves every child with it, because they're all
## anchored to it — including the stick zone, which is measured from `size`.
## On desktop the safe area is the whole window, so every inset is zero and
## nothing moves.
func _apply_safe_area() -> void:
	var window := DisplayServer.window_get_size()
	if window.x <= 0 or window.y <= 0:
		return
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return

	# The safe area comes back in real screen pixels; this Control lives in the
	# 1280x720 stretch viewport, so the insets have to be scaled across.
	var viewport := get_viewport_rect().size
	var scale_x := viewport.x / float(window.x)
	var scale_y := viewport.y / float(window.y)

	offset_left = safe.position.x * scale_x
	offset_top = safe.position.y * scale_y
	offset_right = -float(window.x - safe.end.x) * scale_x
	offset_bottom = -float(window.y - safe.end.y) * scale_y


func _apply_input_mode() -> void:
	# The buttons stay on screen in desktop mode as pure readouts — they're the
	# only place the cooldown numbers live, and hit testing is touch-only anyway.
	for b in [zap_btn, track_btn, call_btn, jump_btn, crouch_btn, score_btn, quit_btn]:
		b.visible = true
		b.dim = not touch_mode
	jump_btn.visible = touch_mode
	crouch_btn.visible = touch_mode
	score_btn.visible = touch_mode
	quit_btn.visible = touch_mode
	# Touch only. On desktop these three already have keys and a menu, and the
	# panel's rows are hit-tested by finger position — there's no mouse path.
	settings_btn.visible = touch_mode
	if not touch_mode:
		_close_settings()

	hint_label.visible = not touch_mode
	hint_label.text = "WASD move  ·  Mouse look  ·  LMB zap  ·  Q track  ·  E call  ·  Ctrl crouch  ·  Tab scores  ·  Alt cursor  ·  Esc leave  ·  F1 touch layout"
	if touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	_acquire_player()
	_tick_timers(delta)
	if player != null:
		_drive_player()
		_update_buttons()
		_update_call_overlay()
	queue_redraw()


func _acquire_player() -> void:
	if player != null and is_instance_valid(player):
		return
	if Net.world == null:
		return
	player = Net.world.local_player()
	if player == null:
		return
	phone = player.get_node_or_null("Head/Camera/Phone")
	radar.player = player
	radar.phone = phone
	if _connected_to != player:
		_connected_to = player
		player.took_damage.connect(_on_took_damage)
		player.hit_confirmed.connect(_on_hit_confirmed)
		player.was_scanned.connect(_on_scanned)
		player.call_started.connect(_on_call_started)
		player.call_ended.connect(_on_call_ended)
		player.died.connect(_on_died)
		player.respawned.connect(_on_respawned)


func _tick_timers(delta: float) -> void:
	# Worst frame over a rolling second, reset at the end of each window so a
	# single bad frame doesn't sit on screen forever.
	_worst_window += delta
	_worst_frame_ms = maxf(_worst_frame_ms, delta * 1000.0)
	if _worst_window >= 1.0:
		_worst_window = 0.0
		_worst_frame_ms = delta * 1000.0

	_flash = maxf(0.0, _flash - delta * 2.6)
	_hitmark = maxf(0.0, _hitmark - delta * 4.0)
	_kill_flash = maxf(0.0, _kill_flash - delta * 0.62)
	damage_flash.modulate.a = _flash * 0.42
	damage_flash.visible = _flash > 0.001

	if _feed_timer > 0.0:
		_feed_timer -= delta
		feed_label.modulate.a = clampf(_feed_timer, 0.0, 1.0)
		if _feed_timer <= 0.0:
			feed_label.text = ""

	if _status_timer > 0.0:
		_status_timer -= delta
		if _status_timer <= 0.0:
			status_label.text = ""

	var now := _now()
	_damage_dirs = _damage_dirs.filter(func(d): return now < d["until"])


# ---------------------------------------------------------------------------
# Feeding input into the player
# ---------------------------------------------------------------------------

func _drive_player() -> void:
	player.aim_assist = touch_mode and Settings.aim_assist

	# Auto-fire: pull the trigger for you, but only when a target is genuinely
	# under the reticle and with a clear line to them.
	# Not while the setup panel is up — otherwise the moment you open it to turn
	# auto-fire off, it keeps shooting at whatever the crosshair was left on.
	if (Settings.fire_mode == Settings.Fire.AUTO and phone != null
			and not settings_panel.visible
			and phone.can_zap() and player.aim_target(AUTO_FIRE_CONE) != null):
		phone.try_zap()

	if not touch_mode:
		return
	if _stick_active:
		var offset := (_stick_point - _stick_origin) / STICK_RADIUS
		if offset.length() < STICK_DEADZONE:
			offset = Vector2.ZERO
		offset = offset.limit_length(1.0)
		player.input_move = Vector2(offset.x, -offset.y)
		# Push the stick most of the way out and you break into a run.
		player.input_sprint = offset.length() > 0.86
	else:
		player.input_move = Vector2.ZERO
		player.input_sprint = false


func _update_buttons() -> void:
	if phone == null:
		return
	var overheated: bool = phone.is_overheated()
	zap_btn.cooldown = phone.heat_ratio()
	zap_btn.cooldown_seconds = phone.overheat_seconds() if overheated else 0.0
	# Only greys out when it's actually locked, not during the fire-rate floor
	# — a button flickering off every tap reads as the game fighting you.
	zap_btn.enabled = not overheated and player.alive and not player.is_busy()
	if overheated:
		zap_btn.sublabel = "overheated"
	else:
		zap_btn.sublabel = "auto" if Settings.fire_mode == Settings.Fire.AUTO else "or tap screen"

	track_btn.cooldown = phone.track_cooldown_ratio()
	track_btn.cooldown_seconds = phone.track_cooldown_seconds()
	track_btn.enabled = phone.can_track()

	call_btn.cooldown = phone.call_cooldown_ratio()
	call_btn.cooldown_seconds = phone.call_cooldown_seconds()
	call_btn.enabled = phone.can_call()
	call_btn.sublabel = "ring them" if phone.can_call() else "no target"

	jump_btn.enabled = player.alive
	crouch_btn.enabled = player.alive
	crouch_btn.held = bool(player.input_crouch)


func _update_call_overlay() -> void:
	var ringing: bool = player.is_ringing()
	call_overlay.visible = ringing
	if not ringing:
		return
	var left: float = maxf(0.0, player.ring_until - _now())
	caller_label.text = "%s is calling" % Net.display_name(player.caller_id)
	call_hint.text = "slowed and can't shoot  ·  %.1fs" % left
	call_tint.modulate.a = 0.26 + 0.13 * sin(_now() * 18.0)


# ---------------------------------------------------------------------------
# Touch routing
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_finger_down(event.index, event.position)
		else:
			_finger_up(event.index)
		return
	if event is InputEventScreenDrag:
		_finger_move(event.index, event.position, event.relative)
		return
	if event is InputEventKey:
		if event.keycode == KEY_TAB:
			_scoreboard_held = event.pressed
		if event.pressed and not event.echo:
			_key(event.keycode)
		return
	if event is InputEventMouseButton and not touch_mode:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and phone != null:
			if not phone.try_zap():
				_say(phone.zap_block_reason(), 1.4)


func _finger_down(index: int, at: Vector2) -> void:
	if not touch_mode or player == null:
		return

	# An open panel takes the whole screen. Testing its rows first and returning
	# unconditionally is what stops a thumb reaching for AIM ASSIST from also
	# being read as a look-drag or a stick — the fall-through below has no idea
	# the panel exists.
	if settings_panel.visible:
		for entry in [["sens", sens_btn], ["assist", assist_btn],
				["fire", fire_btn], ["close", close_btn]]:
			var row: ActionButton = entry[1]
			if row.contains_point(at):
				_roles[index] = entry[0]
				row.held = true
				_press_setting(entry[0])
				return
		# Anywhere else closes it, which is what a tap outside a sheet should do
		# and saves aiming at BACK with a thumb.
		_close_settings()
		return

	for entry in [["zap", zap_btn], ["track", track_btn], ["call", call_btn],
			["jump", jump_btn], ["crouch", crouch_btn], ["score", score_btn],
			["quit", quit_btn], ["settings", settings_btn]]:
		var btn: ActionButton = entry[1]
		if btn.visible and btn.contains_point(at):
			_roles[index] = entry[0]
			btn.held = true
			_press(entry[0])
			return

	if at.x < size.x * STICK_ZONE:
		if _stick_active:
			return   # one stick at a time
		_roles[index] = "move"
		_stick_active = true
		_stick_origin = at
		_stick_point = at
	else:
		_roles[index] = "look"
		_look_touches[index] = {"travel": 0.0, "started": _now()}


func _finger_move(index: int, at: Vector2, relative: Vector2) -> void:
	if not touch_mode:
		return
	match _roles.get(index, ""):
		"move":
			# Let the thumb drag past the ring instead of pinning it, so the
			# stick tracks where your thumb actually is.
			_stick_point = _stick_origin + (at - _stick_origin).limit_length(STICK_RADIUS * 1.35)
		"look":
			if player != null:
				player.input_look += relative
			if _look_touches.has(index):
				_look_touches[index]["travel"] += relative.length()


func _finger_up(index: int) -> void:
	match _roles.get(index, ""):
		"move":
			_stick_active = false
		"look":
			_finish_look_touch(index)
		"zap":
			zap_btn.held = false
		"track":
			track_btn.held = false
		"call":
			call_btn.held = false
		"jump":
			jump_btn.held = false
		"crouch":
			crouch_btn.held = false
		"score":
			score_btn.held = false
		"quit":
			quit_btn.held = false
		"settings":
			settings_btn.held = false
		"sens":
			sens_btn.held = false
		"assist":
			assist_btn.held = false
		"fire":
			fire_btn.held = false
		"close":
			close_btn.held = false
	_roles.erase(index)


## A look touch that lifted quickly without travelling was a tap: fire.
func _finish_look_touch(index: int) -> void:
	var info = _look_touches.get(index)
	_look_touches.erase(index)
	if info == null or phone == null:
		return
	if Settings.fire_mode != Settings.Fire.TAP:
		return
	if float(info["travel"]) > TAP_MAX_TRAVEL:
		return
	if _now() - float(info["started"]) > TAP_MAX_SECONDS:
		return
	phone.try_zap()


func _press(what: String) -> void:
	if phone == null:
		return
	match what:
		"zap":
			if not phone.try_zap():
				_say(phone.zap_block_reason(), 1.4)
		"track":
			if not phone.try_track():
				_say(phone.track_block_reason(), 1.4)
		"call":
			if not phone.try_call():
				_say(phone.call_block_reason(), 1.6)
		"jump":
			player.input_jump = true
		"crouch":
			# Toggle on touch: nobody wants to hold a thumb down to stay low.
			player.input_crouch = not player.input_crouch
		"score":
			_scoreboard_pinned = not _scoreboard_pinned
		"quit":
			Net.leave()
		"settings":
			_open_settings()


# ---------------------------------------------------------------------------
# In-match setup
# ---------------------------------------------------------------------------

func _open_settings() -> void:
	# Drop the stick before the panel covers it, or the thumb that opened this
	# leaves the player walking into a wall behind the tint.
	_stick_active = false
	if player != null:
		player.input_move = Vector2.ZERO
	_refresh_settings()
	settings_panel.visible = true


func _close_settings() -> void:
	if not settings_panel.visible:
		return
	settings_panel.visible = false
	Settings.save()


## Each row shows its own current value, so the panel needs no separate labels
## and stays readable at a glance with a thumb over half of it.
func _refresh_settings() -> void:
	sens_btn.label = "LOOK SPEED   %.2fx" % Settings.look_sensitivity
	assist_btn.label = "AIM ASSIST   %s" % ("ON" if Settings.aim_assist else "OFF")
	fire_btn.label = "FIRE   %s" % Settings.FIRE_NAMES[Settings.fire_mode].to_upper()

	sens_btn.color = Palette.SIGN_WHITE
	assist_btn.color = Palette.TRACK if Settings.aim_assist else Color(0.55, 0.57, 0.62)
	fire_btn.color = Palette.CALL
	close_btn.color = Palette.SIGN_WHITE


func _press_setting(what: String) -> void:
	match what:
		"sens":
			# Cycle rather than clamp, so there's always a next tap — running
			# into a silent end-stop reads as the button being broken.
			var i := SENS_STEPS.find(snappedf(Settings.look_sensitivity, 0.01))
			Settings.look_sensitivity = SENS_STEPS[(i + 1) % SENS_STEPS.size()]
		"assist":
			Settings.aim_assist = not Settings.aim_assist
		"fire":
			Settings.fire_mode = (Settings.fire_mode + 1) % Settings.FIRE_NAMES.size()
		"close":
			_close_settings()
			return
	Settings.changed.emit()
	_refresh_settings()


func _key(code: int) -> void:
	match code:
		KEY_F1:
			touch_mode = not touch_mode
			_apply_input_mode()
		KEY_ALT:
			# Alt frees the cursor; Escape is for leaving, which is what people
			# reach for it expecting.
			if not touch_mode:
				Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE
					if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
					else Input.MOUSE_MODE_CAPTURED)
		KEY_ESCAPE:
			Net.leave()
			return
	if touch_mode or phone == null:
		return
	match code:
		KEY_Q:
			if not phone.try_track():
				_say(phone.track_block_reason(), 1.4)
		KEY_E:
			if not phone.try_call():
				_say(phone.call_block_reason(), 1.6)


# ---------------------------------------------------------------------------
# Reactions
# ---------------------------------------------------------------------------

func _on_took_damage(attacker_id: int) -> void:
	_flash = 1.0
	var attacker = Net.player_node(attacker_id)
	if attacker != null and player != null:
		var offset: Vector3 = attacker.global_position - player.global_position
		var local: Vector2 = Vector2(offset.x, offset.z).rotated(float(player.yaw))
		_damage_dirs.append({"dir": local.normalized(), "until": _now() + 1.6})


func _on_hit_confirmed() -> void:
	_hitmark = 1.0


## You downed somebody. Loud on purpose — a hitmarker means you connected, this
## means it's over, and in a burst of fire those need to feel different.
func _on_kill(victim_id: int) -> void:
	_kill_flash = 1.0
	_kill_name = Net.display_name(victim_id)
	_hitmark = 1.0
	Sfx.play("kill", -5.0)
	Sfx.buzz(45)


func _on_scanned(by_id: int) -> void:
	_say("SCANNED by %s" % Net.display_name(by_id), 2.2)


func _on_call_started(from_id: int) -> void:
	_say("%s is calling you" % Net.display_name(from_id), 1.4)


func _on_call_ended() -> void:
	pass


func _on_died(killer_id: int) -> void:
	_killer_id = killer_id
	_respawn_at = _now() + Net.RESPAWN_DELAY
	_say("", 0.0)   # the death overlay says it louder


func _on_respawned() -> void:
	_say("", 0.0)
	_respawn_at = 0.0
	_damage_dirs.clear()


func _on_feed(text: String) -> void:
	feed_label.text = text
	feed_label.modulate.a = 1.0
	_feed_timer = 3.0


func _refresh_score() -> void:
	var parts: Array[String] = []
	for row in Net.sorted_scoreboard():
		var who: String = "You" if int(row["id"]) == Net.my_id() else str(row["name"])
		parts.append("%s %d" % [who, int(row["kills"])])
	score_label.text = "   ·   ".join(parts)


func _on_match_over(winner_id: int) -> void:
	_match_finished = true
	result_label.show()
	if winner_id < 0:
		result_label.text = "everyone left"
	elif winner_id == Net.my_id():
		result_label.text = "YOU WIN"
		Sfx.play("win", -3.0)
	else:
		result_label.text = "%s WINS" % Net.display_name(winner_id).to_upper()
		Sfx.play("lose", -3.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _say(text: String, seconds: float) -> void:
	status_label.text = text
	_status_timer = seconds


## The phone was locked or took a call, and we're trying to get back into the
## game before telling the player anything went wrong.
##
## Held on screen for longer than the reconnect window can last, rather than
## timed like other status text — a banner that faded on its own would read as
## "it worked" at exactly the moment it hadn't. Net always emits false when the
## attempt resolves either way, so this can't get stuck.
func _on_reconnecting(active: bool) -> void:
	if active:
		_say("RECONNECTING...", 999.0)
	else:
		status_label.text = ""
		_status_timer = 0.0


# ---------------------------------------------------------------------------
# Drawing: crosshair, bars, stick, damage arcs
# ---------------------------------------------------------------------------

func _draw() -> void:
	_draw_bars()
	_draw_perf()
	_draw_crosshair()
	_draw_kill_banner()
	_draw_speed_lines()
	_draw_damage_arcs()
	if touch_mode and _stick_active:
		_draw_stick()
	if player != null and not player.alive and not _match_finished:
		_draw_death_screen()
	if _scoreboard_visible():
		_draw_scoreboard()


## Dying used to be a small line of text you could miss entirely. Now the
## screen goes red, says so, and counts you back in.
func _draw_death_screen() -> void:
	var font := ThemeDB.fallback_font
	var centre := size * 0.5
	var remaining: float = maxf(0.0, _respawn_at - _now())
	var age: float = clampf((Net.RESPAWN_DELAY - remaining) / 0.45, 0.0, 1.0)

	# One full-screen blend, not two. Alpha over the whole screen is pure fill
	# rate, which is exactly what a phone GPU is short of — and the death screen
	# was drawing two stacked passes of it every frame. Pre-mixing the red and
	# the black into a single colour looks the same and halves the cost.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.01, 0.02, 0.71 * age))

	# Two bands framing the message, wiping open as it appears.
	var band := size.x * age
	draw_rect(Rect2(centre.x - band * 0.5, centre.y - 74.0, band, 3.0), Color(1, 0.25, 0.3, 0.85))
	draw_rect(Rect2(centre.x - band * 0.5, centre.y + 66.0, band, 3.0), Color(1, 0.25, 0.3, 0.85))

	_centred(font, "YOU'RE DOWN", centre.y - 12.0, 62, Color(1.0, 0.92, 0.92, age))

	var by := "zapped by %s" % Net.display_name(_killer_id)
	_centred(font, by, centre.y + 34.0, 20, Color(1.0, 0.62, 0.62, 0.9 * age))

	if remaining > 0.05:
		_centred(font, "back in %.1f" % remaining, centre.y + 116.0, 26,
			Color(1, 1, 1, 0.75 * age))
		# Countdown ring, so the wait reads as progress rather than dead air.
		var progress: float = 1.0 - clampf(remaining / Net.RESPAWN_DELAY, 0.0, 1.0)
		draw_arc(centre + Vector2(0, 108.0), 46.0, -PI / 2.0, -PI / 2.0 + TAU * progress,
			48, Color(1, 0.35, 0.4, 0.55 * age), 4.0, true)


func _centred(font: Font, text: String, y: float, font_size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - w) * 0.5, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _scoreboard_visible() -> bool:
	return _scoreboard_pinned or _scoreboard_held or _match_finished


## Full standings. Held on Tab, toggled with the SCORE button, and forced up
## when the match ends so the last thing you see is who won.
func _draw_scoreboard() -> void:
	var rows := Net.sorted_scoreboard()
	var font := ThemeDB.fallback_font
	var row_h := 34.0
	var width := 470.0
	var height := 78.0 + row_h * rows.size()
	var top_left := Vector2((size.x - width) * 0.5, (size.y - height) * 0.5 - 20.0)
	var panel := Rect2(top_left, Vector2(width, height))

	draw_rect(panel, Color(0.04, 0.05, 0.08, 0.90))
	draw_rect(panel, Color(1, 1, 1, 0.16), false, 2.0)

	draw_string(font, top_left + Vector2(22, 34), "SCOREBOARD",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.92))
	var goal := ("first to %d" % Net.KILLS_TO_WIN) if Net.KILLS_TO_WIN > 0 else "no round limit"
	var goal_w := font.get_string_size(goal, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, top_left + Vector2(width - goal_w - 22, 32), goal,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.45))

	var header_y := top_left.y + 58.0
	draw_string(font, Vector2(top_left.x + 22, header_y), "PLAYER",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.40))
	draw_string(font, Vector2(top_left.x + width - 168, header_y), "KILLS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.40))
	draw_string(font, Vector2(top_left.x + width - 86, header_y), "DEATHS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.40))
	draw_line(Vector2(top_left.x + 18, header_y + 10),
		Vector2(top_left.x + width - 18, header_y + 10), Color(1, 1, 1, 0.14), 1.0)

	var y := header_y + 34.0
	for row in rows:
		var pid := int(row["id"])
		var mine := pid == Net.my_id()
		if mine:
			draw_rect(Rect2(top_left.x + 12, y - 20.0, width - 24, row_h - 4.0),
				Color(0.55, 0.72, 1.0, 0.14))

		var who: String = str(row["name"])
		if mine:
			who += "   (you)"
		if pid == 1:
			who += "   · host"
		var tint := Color(1, 1, 1, 0.95) if mine else Color(0.86, 0.88, 0.95, 0.9)
		draw_string(font, Vector2(top_left.x + 22, y), who,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, tint)
		draw_string(font, Vector2(top_left.x + width - 162, y), str(int(row["kills"])),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.4, 1.0, 0.65, 0.95))
		draw_string(font, Vector2(top_left.x + width - 76, y), str(int(row["deaths"])),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.5, 0.5, 0.85))
		y += row_h


func _draw_bars() -> void:
	var health := 0.0
	if player != null:
		health = float(player.health) / float(player.MAX_HEALTH)

	var origin := Vector2(24, 26)
	_bar(origin, health, HEALTH_COLOR, "HP")

	if phone == null:
		return
	var heat: float = phone.heat_ratio()
	var label := "HEAT"
	var color := HEAT_COOL.lerp(HEAT_WARM, heat)
	if phone.is_overheated():
		# Pulsing red bar with the lockout counting down beside it.
		color = HEAT_LOCKED
		color.a = 0.55 + 0.45 * sin(_now() * 12.0)
		label = "OVERHEATED %.1f" % phone.overheat_seconds()
	_bar(origin + Vector2(0, BAR_HEIGHT + 10), heat, color, label)


## On screen so "it feels choppy" can be answered with a number instead of a
## guess. Green is smooth, amber is playable, red is a real problem.
##
## Two numbers, because one is misleading. The average settles at whatever cap
## you picked and tells you nothing; the slowest frame in the last second is the
## one you actually felt. A steady 60 with a 40ms spike every time you shoot
## reads as "60 fps" on any normal counter, and reads as stuttering in the hand.
func _draw_perf() -> void:
	if not Settings.show_fps:
		return
	var fps := Engine.get_frames_per_second()
	var color := Color(1.0, 0.45, 0.40, 0.9)
	if fps >= 55:
		color = Color(0.45, 1.0, 0.60, 0.75)
	elif fps >= 40:
		color = Color(1.0, 0.85, 0.40, 0.85)

	var at := Vector2(24, 26 + (BAR_HEIGHT + 10) * 2 + 16)
	var font := ThemeDB.fallback_font
	draw_string(font, at, "%d fps" % fps, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

	# Worst frame in the last second, in milliseconds. Anything over ~17ms is a
	# frame you missed at 60.
	var spike := Color(0.55, 0.60, 0.72, 0.75)
	if _worst_frame_ms > 33.0:
		spike = Color(1.0, 0.45, 0.40, 0.9)
	elif _worst_frame_ms > 17.0:
		spike = Color(1.0, 0.85, 0.40, 0.85)
	draw_string(font, at + Vector2(58, 0), "worst %.0fms" % _worst_frame_ms,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, spike)


func _bar(at: Vector2, ratio: float, color: Color, label: String) -> void:
	draw_rect(Rect2(at, Vector2(BAR_WIDTH, BAR_HEIGHT)), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(at, Vector2(BAR_WIDTH * clampf(ratio, 0.0, 1.0), BAR_HEIGHT)),
		Color(color.r, color.g, color.b, 0.92))
	draw_rect(Rect2(at, Vector2(BAR_WIDTH, BAR_HEIGHT)), Color(1, 1, 1, 0.18), false, 1.0)
	draw_string(ThemeDB.fallback_font, at + Vector2(BAR_WIDTH + 8, BAR_HEIGHT - 2),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.55))


## Reticle that grows with your actual inaccuracy: movement opens it, firing
## kicks it, overheating turns it hostile.
func _draw_crosshair() -> void:
	var c := size * 0.5
	var busy: bool = player != null and player.is_busy()
	var overheated: bool = phone != null and phone.is_overheated()

	# Neutral on purpose. The theme colour belongs to your phone's screen, not
	# to the reticle — a crosshair has one job and needs to read the same
	# whatever you picked.
	var col := Color(1, 1, 1, 0.80)
	if overheated:
		col = Color(1.0, 0.40, 0.25, 0.45 + 0.25 * sin(_now() * 12.0))
	elif busy:
		col = Color(1, 1, 1, 0.28)
	if _hitmark > 0.0:
		# Hit feedback ignores your theme — it has to read the same for everyone.
		col = Color(1.0, 0.35, 0.35, 0.4 + 0.6 * _hitmark)

	var gap := 5.0
	var length := 8.0
	if player != null:
		gap += clampf(float(player.horizontal_speed()) / float(player.SPRINT_SPEED), 0.0, 1.0) * 9.0
		if not player.is_on_floor():
			gap += 6.0
	if phone != null:
		gap += phone.recoil() * 9.0   # recoil bloom

	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(c + dir * gap, c + dir * (gap + length), col, 2.0)
	draw_circle(c, 1.4, col)

	if _hitmark > 0.0:
		var spread: float = 6.0 + (1.0 - _hitmark) * 5.0
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + d * spread, c + d * (spread + 6.0), Color(1, 0.4, 0.4, _hitmark), 2.5)


## Where the shot came from, as an arc on a ring around the reticle. Close
## enough to the centre that you read it without looking away from your aim.
func _draw_damage_arcs() -> void:
	var c := size * 0.5
	var now := _now()
	for d in _damage_dirs:
		var strength: float = clampf(float(d["until"]) - now, 0.0, 1.0)
		var dir: Vector2 = d["dir"]
		var angle := atan2(dir.y, dir.x)
		var radius := 96.0 - strength * 8.0     # snaps inward then settles
		draw_arc(c, radius, angle - 0.36, angle + 0.36, 18,
			Color(1.0, 0.22, 0.26, 0.28 * strength), 14.0, true)
		draw_arc(c, radius, angle - 0.30, angle + 0.30, 16,
			Color(1.0, 0.55, 0.55, 0.85 * strength), 3.0, true)


## Kill confirmation: a ring snapping shut around the reticle, then the name of
## whoever you dropped. Sits above the crosshair so it never covers your aim.
func _draw_kill_banner() -> void:
	if _kill_flash <= 0.01:
		return
	var c := size * 0.5
	var age: float = 1.0 - _kill_flash                 # 0 at the moment of the kill
	var pop: float = clampf(age / 0.18, 0.0, 1.0)      # fast snap inward
	var fade: float = clampf(_kill_flash / 0.55, 0.0, 1.0)

	# Ring collapsing onto the crosshair.
	var radius: float = lerpf(74.0, 34.0, pop)
	draw_arc(c, radius, 0.0, TAU, 40, Color(1.0, 0.86, 0.35, 0.85 * fade), 3.0, true)
	for i in 4:
		var angle := PI * 0.25 + i * PI * 0.5
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(c + dir * (radius - 9.0), c + dir * (radius + 9.0),
			Color(1.0, 0.92, 0.55, 0.9 * fade), 3.0)

	var font := ThemeDB.fallback_font
	var rise: float = lerpf(0.0, -14.0, pop)
	_centred(font, "ELIMINATED", c.y - 104.0 + rise, 26, Color(1.0, 0.86, 0.35, fade))
	_centred(font, _kill_name, c.y - 78.0 + rise, 19, Color(1, 1, 1, 0.85 * fade))


## Sprint streaks. Short lines raked in from the edges, brightest at the
## corners — the cheapest possible sense of speed, and no shader involved.
func _draw_speed_lines() -> void:
	if player == null or not player.alive:
		return
	var speed: float = float(player.horizontal_speed())
	var amount: float = clampf((speed - float(player.SPEED) * 0.95)
		/ (float(player.SPRINT_SPEED) - float(player.SPEED) * 0.95), 0.0, 1.0)
	if amount < 0.05:
		return

	var c := size * 0.5
	var reach: float = minf(size.x, size.y) * 0.5
	for i in 16:
		var angle := TAU * (float(i) + 0.5) / 16.0
		var dir := Vector2(cos(angle), sin(angle))
		var wobble: float = 0.75 + 0.25 * sin(_now() * 9.0 + float(i))
		var outer: float = reach * 1.35
		var inner: float = outer - (52.0 + 46.0 * amount) * wobble
		draw_line(c + dir * inner, c + dir * outer,
			Color(1, 1, 1, 0.16 * amount * wobble), 2.0)

	# Slight vignette so the edges close in as you run.
	for i in 5:
		var t := float(i) / 4.0
		draw_arc(c, reach * (1.02 + t * 0.16), 0.0, TAU, 48,
			Color(0, 0, 0, 0.05 * amount * (1.0 - t)), 26.0, false)


func _draw_stick() -> void:
	var sprinting: bool = player != null and player.input_sprint
	var pulse: float = 0.5 + 0.5 * sin(_now() * 7.0)
	var ring := Color(1, 1, 1, 0.24 + (0.22 * pulse if sprinting else 0.0))

	draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.07))
	draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 40, ring, 2.0, true)
	if sprinting:
		# Second ring blooms outward while you're at a run.
		draw_arc(_stick_origin, STICK_RADIUS + 6.0 + pulse * 7.0, 0.0, TAU, 40,
			Color(1, 1, 1, 0.20 * (1.0 - pulse)), 3.0, true)

	var offset := (_stick_point - _stick_origin).limit_length(STICK_RADIUS)
	var knob := _stick_origin + offset
	draw_line(_stick_origin, knob, Color(1, 1, 1, 0.18), 3.0)
	draw_circle(knob, 30.0, Color(1, 1, 1, 0.22 + 0.12 * offset.length() / STICK_RADIUS))
	draw_arc(knob, 30.0, 0.0, TAU, 24, Color(1, 1, 1, 0.55), 2.0, true)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
