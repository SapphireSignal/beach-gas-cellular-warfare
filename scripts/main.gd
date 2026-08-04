extends Node
## Root. Owns the swap between menu and match.

const HUD_SCENE := preload("res://scenes/hud.tscn")
const BACKDROP_SCRIPT := preload("res://scripts/menu_backdrop.gd")
const POST_MATCH_SECONDS := 6.0

@onready var menu_layer: CanvasLayer = $MenuLayer
@onready var hud_layer: CanvasLayer = $HudLayer
@onready var game_root: Node3D = $GameRoot
@onready var menu = $MenuLayer/Menu

var world: Node3D = null
var hud: Control = null
var backdrop: Node3D = null


var _autostart := false
## True for a scripted run (--practice / --autohost / --autojoin). Network
## errors are fatal in that mode so a headless check can't pass by accident.
var _driven_from_cli := false
## `--audit`: print what the level costs to build and to draw.
var _audit := false
## How many players an `--autohost` run waits for before starting.
##
## Two by default, which is what a scripted check wants. It exists because the
## game had never once been tested above two players — and it couldn't be: the
## host started the moment the second peer registered, so every later guest
## arrived into a match already in progress and was testing late-join rather
## than a four-player game. `--min-players=4` holds the lobby open until
## everyone's actually there.
var _min_players := 2
## False once a match owns the sky, so the deferred backdrop build knows not to
## fire into a live level.
var _want_backdrop := true


func _ready() -> void:
	Net.match_started.connect(_on_match_started)
	Net.match_over.connect(_on_match_over)
	Net.net_error.connect(_on_net_error)
	Net.left_match.connect(_on_left_match)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Where the grey screen at launch actually goes. Everything before this point
	# is engine boot plus the autoloads (Sfx synthesises the whole sound bank in
	# its _ready); the backdrop is a live 3D scene built behind the menu.
	if "--audit" in OS.get_cmdline_user_args():
		print("AUDIT Boot | engine+autoloads %dms" % Time.get_ticks_msec())

	_start_backdrop_when_menu_is_up()
	_handle_command_line()


## The menu backdrop is a live 3D scene, and building it costs ~390ms on the dev
## Mac — more on a phone. Doing that inside _ready spends it before the first
## frame is ever drawn, so it lands as grey screen on top of the ~1.4s the
## engine and autoloads already take.
##
## Waiting a frame turns it into 390ms of *visible menu* instead. The backdrop
## fades in behind a menu that's already on screen, which is what it does when
## you come back from a match anyway.
##
## The guard matters: a --practice or --autohost run starts a match immediately,
## and without it this would build a backdrop into a live match a frame later —
## two WorldEnvironments fighting over the sky, which is exactly what
## _on_match_started tears the backdrop down to avoid.
func _start_backdrop_when_menu_is_up() -> void:
	await get_tree().process_frame
	if _want_backdrop:
		_start_backdrop()


func _process(_delta: float) -> void:
	# The backdrop owns its own cut timing; the menu just draws the fade.
	if backdrop != null and menu != null:
		menu.set_backdrop_fade(backdrop.fade)


func _start_backdrop() -> void:
	_want_backdrop = true
	if backdrop != null:
		return
	backdrop = Node3D.new()
	backdrop.name = "MenuBackdrop"
	backdrop.set_script(BACKDROP_SCRIPT)
	add_child(backdrop)


func _stop_backdrop() -> void:
	_want_backdrop = false
	if backdrop != null:
		backdrop.queue_free()
		backdrop = null
	if menu != null:
		menu.set_backdrop_fade(0.0)


## Lets you skip the menu when testing on one machine:
##   BeachGas.exe -- --autohost --name=Host
##   BeachGas.exe -- --autojoin=127.0.0.1 --name=Guest
##   BeachGas.exe -- --practice --name=Me
##   BeachGas.exe -- --practice --port=27100     (avoid a port already in use)
## The host starts the match by itself as soon as somebody joins.
##
## A command-line session that can't start quits with a failing exit code. It
## used to return 0 whichever way it went, so a headless check stayed green
## while the game never got past "couldn't open the port" — the one thing those
## checks exist to catch.
func _handle_command_line() -> void:
	var args := OS.get_cmdline_user_args()
	var who := "Player"
	var join_target := ""
	_audit = "--audit" in args
	for a in args:
		if a.begins_with("--name="):
			who = a.substr(7)
		elif a.begins_with("--autojoin="):
			join_target = a.substr(11)
		elif a.begins_with("--min-players="):
			var want := a.substr(14)
			if want.is_valid_int():
				_min_players = clampi(int(want), 2, Net.MAX_PLAYERS)
		elif a.begins_with("--port="):
			var port := a.substr(7)
			if port.is_valid_int():
				Net.use_port(int(port))
		elif a.begins_with("--map="):
			# Jump straight onto a given map, for testing one without clicking
			# through the lobby.
			var id := a.substr(6)
			if Maps.is_available(id):
				Net.selected_map = id

	if "--practice" in args:
		# The menu's practice button drops you in the lobby so you still get the
		# map picker. From the command line there's nobody to press start, so the
		# flag goes all the way into the match — that's the whole point of it,
		# and it's what makes the headless check actually exercise a level.
		_driven_from_cli = true
		_autostart = true
		Net.lobby_changed.connect(_maybe_autostart)
		if not Net.start_practice(who, 1):
			_fail("--practice could not start a local game")
	elif "--autohost" in args:
		_driven_from_cli = true
		_autostart = true
		Net.lobby_changed.connect(_maybe_autostart)
		if not Net.host_game(who):
			_fail("--autohost could not open the port")
	elif not join_target.is_empty():
		_driven_from_cli = true
		if not Net.join_game(who, join_target):
			_fail("--autojoin could not reach %s" % join_target)


## Anything that goes wrong during a scripted run has to be loud and has to
## fail the process, or the checks are theatre.
func _fail(reason: String) -> void:
	push_error("startup failed: %s" % reason)
	printerr("startup failed: %s" % reason)
	get_tree().quit(1)


func _maybe_autostart() -> void:
	if _autostart and Net.is_host() and not Net.in_match and Net.players.size() >= _min_players:
		_autostart = false
		Net.begin_match()


func _on_match_started() -> void:
	_teardown_match()
	_stop_backdrop()   # two WorldEnvironments would fight over the sky
	menu_layer.hide()

	# Whichever map the host picked. Net.selected_map is already synced to
	# everyone by the time the match starts.
	world = load(Maps.scene_path(Net.selected_map)).instantiate()
	world.audit = _audit
	game_root.add_child(world)
	Net.world = world

	hud = HUD_SCENE.instantiate()
	hud_layer.add_child(hud)

	# Tell the host this device is ready. Players spawn once everyone reports in,
	# so nobody drops into a level that hasn't finished building.
	Net.notify_world_ready()


func _on_match_over(_winner_id: int) -> void:
	await get_tree().create_timer(POST_MATCH_SECONDS).timeout
	_back_to_menu()


func _on_net_error(msg: String) -> void:
	if _driven_from_cli:
		_fail(msg)
		return
	if Net.in_match or world != null:
		_back_to_menu()


## Quit button inside a match.
func _on_left_match() -> void:
	if world != null:
		_back_to_menu()


func _back_to_menu() -> void:
	# Snapshot the standings before the lobby is torn down, so there's always a
	# "last game" to look at.
	if Net.players.size() > 1:
		Stats.record_match_end()
	_teardown_match()
	_start_backdrop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_layer.show()
	menu.refresh_after_match()


func _teardown_match() -> void:
	if world != null:
		# Before the world goes: the positional voices are parented inside it
		# while they play, and freeing the level would take the whole pool.
		Sfx.release_voices()
		world.queue_free()
		world = null
	if hud != null:
		hud.queue_free()
		hud = null
	Net.world = null
	Sfx.stop_ringing()
