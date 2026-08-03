extends Node
## Root. Owns the swap between menu and match.

const WORLD_SCENE := preload("res://scenes/world.tscn")
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


func _ready() -> void:
	Net.match_started.connect(_on_match_started)
	Net.match_over.connect(_on_match_over)
	Net.net_error.connect(_on_net_error)
	Net.left_match.connect(_on_left_match)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_frame_cap()
	_start_backdrop()
	_handle_command_line()


## Phones get 60: their panels are 60Hz anyway, and running flat out would cook
## the battery on a device somebody has to work a shift with.
func _apply_frame_cap() -> void:
	Engine.max_fps = 60 if OS.has_feature("mobile") else 240


func _process(_delta: float) -> void:
	# The backdrop owns its own cut timing; the menu just draws the fade.
	if backdrop != null and menu != null:
		menu.set_backdrop_fade(backdrop.fade)


func _start_backdrop() -> void:
	if backdrop != null:
		return
	backdrop = Node3D.new()
	backdrop.name = "MenuBackdrop"
	backdrop.set_script(BACKDROP_SCRIPT)
	add_child(backdrop)


func _stop_backdrop() -> void:
	if backdrop != null:
		backdrop.queue_free()
		backdrop = null
	if menu != null:
		menu.set_backdrop_fade(0.0)


## Lets you skip the menu when testing on one machine:
##   LensLethal.exe -- --autohost --name=Host
##   LensLethal.exe -- --autojoin=127.0.0.1 --name=Guest
##   LensLethal.exe -- --practice --name=Me
## The host starts the match by itself as soon as somebody joins.
func _handle_command_line() -> void:
	var args := OS.get_cmdline_user_args()
	var who := "Player"
	var join_target := ""
	for a in args:
		if a.begins_with("--name="):
			who = a.substr(7)
		elif a.begins_with("--autojoin="):
			join_target = a.substr(11)

	if "--practice" in args:
		Net.start_practice(who, 1)
	elif "--autohost" in args:
		_autostart = true
		Net.lobby_changed.connect(_maybe_autostart)
		Net.host_game(who)
	elif not join_target.is_empty():
		Net.join_game(who, join_target)


func _maybe_autostart() -> void:
	if _autostart and Net.is_host() and not Net.in_match and Net.players.size() >= 2:
		_autostart = false
		Net.begin_match()


func _on_match_started() -> void:
	_teardown_match()
	_stop_backdrop()   # two WorldEnvironments would fight over the sky
	menu_layer.hide()

	world = WORLD_SCENE.instantiate()
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


func _on_net_error(_msg: String) -> void:
	if Net.in_match or world != null:
		_back_to_menu()


## Quit button inside a match.
func _on_left_match() -> void:
	if world != null:
		_back_to_menu()


func _back_to_menu() -> void:
	_teardown_match()
	_start_backdrop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_layer.show()
	menu.refresh_after_match()


func _teardown_match() -> void:
	if world != null:
		world.queue_free()
		world = null
	if hud != null:
		hud.queue_free()
		hud = null
	Net.world = null
	Sfx.stop_ringing()
