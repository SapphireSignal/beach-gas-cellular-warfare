extends Node
## Root. Owns the swap between menu and match.

const HUD_SCENE := preload("res://scenes/hud.tscn")
const BACKDROP_SCRIPT := preload("res://scripts/menu_backdrop.gd")
const LOADING_SCRIPT := preload("res://scripts/loading.gd")
const POST_MATCH_SECONDS := 6.0

@onready var menu_layer: CanvasLayer = $MenuLayer
@onready var hud_layer: CanvasLayer = $HudLayer
@onready var game_root: Node3D = $GameRoot
@onready var menu = $MenuLayer/Menu

var world: Node3D = null
var hud: Control = null
var backdrop: Node3D = null
## Its own layer, above the HUD, so it covers the match being torn down as well
## as the menu being rebuilt.
var loading_layer: CanvasLayer = null
var loading: Control = null


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

	# Its own layer above the HUD, because it has to cover a match being torn
	# down as well as the menu being rebuilt.
	loading_layer = CanvasLayer.new()
	loading_layer.layer = 100
	add_child(loading_layer)

	# Where the grey screen at launch actually goes. Everything before this point
	# is engine boot plus the autoloads (Sfx synthesises the whole sound bank in
	# its _ready); the backdrop is a live 3D scene built behind the menu.
	if "--audit" in OS.get_cmdline_user_args():
		print("AUDIT Boot | engine+autoloads %dms" % Time.get_ticks_msec())

	_boot_sequence()
	_handle_command_line()


## The launch screen, and the warm-up that hides behind it.
##
## Jay's report: the first couple of seconds of a match drop frames, and so does
## the first incoming call. Both are first-use costs — Godot compiles material
## variants and rasterises font glyphs the first time something is drawn, and
## the game was paying for all of it the moment a player could see.
##
## The menu backdrop is the lever here, and it's an accident of how it was
## built: it loads the *real Beach Gas level*, so simply letting it render for a
## few frames pushes every one of the game's materials through the pipeline. By
## the time anyone taps Play, that work is done.
##
## So: cover the screen, build the backdrop, hold for a handful of frames while
## it renders, then reveal the menu. The cost was always there — this just moves
## it somewhere it reads as loading rather than as the game stuttering.
func _boot_sequence() -> void:
	# Headless and scripted runs have nothing to show and nobody to show it to,
	# and the extra frames would only slow the checks down.
	#
	# Read the flags directly rather than trusting _driven_from_cli: this is
	# called before _handle_command_line() sets it, and getting that wrong meant
	# a windowed --practice run tore down the *match's* loading screen mid-build.
	var args := OS.get_cmdline_user_args()
	var scripted: bool = "--practice" in args or "--autohost" in args
	for a in args:
		if a.begins_with("--autojoin="):
			scripted = true
	if scripted or DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		if _want_backdrop:
			_start_backdrop()
		return

	_show_loading("BEACH GAS", "warming up")
	await get_tree().process_frame
	await get_tree().process_frame

	if _want_backdrop:
		_start_backdrop()

	# Let the level actually render behind the loading screen. Each frame here
	# is one the player doesn't pay for later.
	for i in 8:
		_set_loading(0.15 + 0.85 * (float(i) / 8.0), "warming up")
		await get_tree().process_frame

	_hide_loading()


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


## Building a level takes seconds on a phone and blocks the main thread the
## whole time. Before this there was nothing on screen while it happened — the
## menu just sat there, unresponsive, which reads as a crash.
##
## The `await` calls are the entire trick and they are not decorative: showing
## the loading screen and building in the same frame paints nothing, because
## the frame never finishes. Each await lets one frame actually reach the glass
## before the next blocking chunk starts. Remove them and this silently goes
## back to a frozen menu.
func _on_match_started() -> void:
	_show_loading("ENTERING", Maps.display_name(Net.selected_map))
	await get_tree().process_frame
	await get_tree().process_frame

	_teardown_match()
	_stop_backdrop()   # two WorldEnvironments would fight over the sky
	menu_layer.hide()

	_set_loading(0.25, "building the level")
	await get_tree().process_frame

	# Whichever map the host picked. Net.selected_map is already synced to
	# everyone by the time the match starts.
	world = load(Maps.scene_path(Net.selected_map)).instantiate()
	world.audit = _audit
	game_root.add_child(world)
	Net.world = world

	_set_loading(0.80, "laying out the controls")
	await get_tree().process_frame

	hud = HUD_SCENE.instantiate()
	hud_layer.add_child(hud)

	# Draw the HUD's mid-match pieces once while they're still hidden behind the
	# loading screen. The call overlay in particular is a full-screen tint and
	# two labels nobody has drawn yet, and paying for that during an incoming
	# call is exactly when you can least afford a dropped frame.
	_set_loading(0.88, "warming up")

	# Every player builds their whole body at spawn - each box, sphere and
	# material created from scratch in player.gd - and they all spawn at once,
	# which is the drop Jay reported in the first seconds of a match.
	#
	# Building one here pays the first-time costs behind the loading screen:
	# shader variants for skin, hair and clothing, and the mesh primitives
	# themselves. The per-player work still happens at spawn, but the expensive
	# first-of-each-kind part is already done.
	var warm := CharacterBuilder.build(Characters.get_entry(Loadout.character_index), true)
	game_root.add_child(warm)
	await get_tree().process_frame
	warm.queue_free()

	_set_loading(0.92, "warming up the HUD")
	if hud.has_method("warm_up"):
		await hud.warm_up()

	_set_loading(1.0, "waiting for everyone")
	await get_tree().process_frame

	_hide_loading()

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


## Quitting is the other freeze Jay reported. Tearing down a merged level and
## rebuilding the menu backdrop both cost real time, and it happened with the
## dead match still on screen.
func _back_to_menu() -> void:
	_show_loading("LEAVING", "")
	await get_tree().process_frame
	await get_tree().process_frame

	# Snapshot the standings before the lobby is torn down, so there's always a
	# "last game" to look at.
	if Net.players.size() > 1:
		Stats.record_match_end()

	_set_loading(0.4, "packing up")
	await get_tree().process_frame
	_teardown_match()

	_set_loading(0.85, "back to the forecourt")
	await get_tree().process_frame
	_start_backdrop()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_layer.show()
	menu.refresh_after_match()

	_set_loading(1.0, "")
	await get_tree().process_frame
	_hide_loading()


# ---------------------------------------------------------------------------
# Loading screen
# ---------------------------------------------------------------------------

func _show_loading(title: String, detail: String) -> void:
	if loading == null:
		loading = LOADING_SCRIPT.new()
		loading_layer.add_child(loading)
	loading.set_title(title)
	loading.set_progress(0.05, detail)
	loading.show()


func _set_loading(amount: float, detail: String) -> void:
	if loading != null:
		loading.set_progress(amount, detail)


func _hide_loading() -> void:
	if loading != null:
		loading.queue_free()
		loading = null


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
