extends Node3D
class_name Shift
## Working a shift at Beach Gas. No weapon — you pump gas.
##
## This is the core loop only, deliberately: clock in, a car arrives, you fill
## it, they pay, and if they pay cash you walk inside for change. Jerry cans,
## windscreens, the cigarette counter, restocking and the fuel truck all hang
## off this same state machine and are not built yet.
##
## It runs on the *same scene* as the shooting map — `beach_gas_real.tscn` — so
## every prop added to the station shows up here automatically. The candy rack,
## the bins, the squeegees and the till are already standing where they need to
## be; this mode just gives you reasons to walk to them.
##
## Single player and entirely local. No `Net` involvement at all: a shift has
## nobody to sync with, and dragging the lobby into it would mean a protocol
## bump for a mode that never leaves the device.

const WORLD_SCENE := "res://scenes/beach_gas_real.tscn"
const PLAYER_SCENE := preload("res://scenes/player.tscn")

## Where you clock in and where the register is — both the shop counter, which
## the map builds at this position.
const TILL := Vector3(-12.8, 1.2, -20.5)

## The two pump islands, and which side of each a car stops on.
const PUMP_SPOTS: Array[Vector3] = [
	Vector3(-13.0, 0.0, 0.0),
	Vector3(13.0, 0.0, 0.0),
]

## How close you have to be to act on something.
const REACH := 2.6
## Seconds of holding the button to fill a tank.
const FILL_SECONDS := 9.0

const PRICE_PER_LITRE := 1.539

enum State { CLOCK_IN, WAITING, DRIVING_IN, PUMPING, TAKE_PAYMENT, GET_CHANGE, RETURN_CHANGE, DRIVING_OUT }

signal objective_changed(text: String, hint: String)
signal money_changed(cash_on_hand: float, earned: float)
signal finished()

var player: Node = null

var _world: Node3D = null
var _state := State.CLOCK_IN
var _customer: Node3D = null
var _customer_spot := Vector3.ZERO
var _fill := 0.0
var _litres := 0.0
var _owed := 0.0
var _held_cash := 0.0
var _earned := 0.0
var _wait := 0.0
var _marker: Node3D = null
var _drive_t := 0.0
var _drive_from := Vector3.ZERO


func _ready() -> void:
	_world = load(WORLD_SCENE).instantiate()
	add_child(_world)

	var spawn: Vector3 = Vector3(-8.0, 0.3, -8.0)
	player = PLAYER_SCENE.instantiate()
	player.name = "1"
	player.peer_id = 1
	player.is_bot = false
	player.case_color = Loadout.case_color_for(Loadout.case_index)
	player.character_index = Loadout.character_index
	_world.get_node("Players").add_child(player)
	player.set_multiplayer_authority(1)
	player.global_position = spawn
	player.setup()

	# No weapon on shift. The phone still exists because player.gd expects it —
	# it is just never drawn and never fires, which is cheaper and far less
	# fragile than making the player scene conditional.
	if player.phone != null:
		player.phone.visible = false

	_marker = _build_marker()
	add_child(_marker)

	_set_state(State.CLOCK_IN)


func _process(delta: float) -> void:
	match _state:
		State.WAITING:
			_wait -= delta
			if _wait <= 0.0:
				_send_a_customer()
		State.DRIVING_IN:
			_drive_customer(delta)
		State.DRIVING_OUT:
			_drive_customer_out(delta)
		_:
			pass
	_update_marker()


# ---------------------------------------------------------------------------
# What you're being asked to do
# ---------------------------------------------------------------------------

func _set_state(next: int) -> void:
	_state = next
	match _state:
		State.CLOCK_IN:
			objective_changed.emit("CLOCK IN", "Head inside to the register")
		State.WAITING:
			_wait = randf_range(3.0, 7.0)
			objective_changed.emit("WAIT FOR A CUSTOMER", "Someone will pull in shortly")
		State.DRIVING_IN:
			objective_changed.emit("CUSTOMER ARRIVING", "Meet them at the pump")
		State.PUMPING:
			objective_changed.emit("PUMP THE GAS",
				"Hold FILL at the car — %d litres" % int(_litres))
		State.TAKE_PAYMENT:
			objective_changed.emit("TAKE PAYMENT",
				"$%.2f — cash, so you owe them change" % _owed)
		State.GET_CHANGE:
			objective_changed.emit("GET THE CHANGE", "Register inside the store")
		State.RETURN_CHANGE:
			objective_changed.emit("RETURN THE CHANGE", "Back to the car")
		State.DRIVING_OUT:
			objective_changed.emit("THANKS", "They're on their way")
	money_changed.emit(_held_cash, _earned)


## Where the player is currently meant to be. Drives both the on-screen marker
## and the interact prompt, so they can never disagree about the objective.
## Re-emit the current objective. The HUD calls this once it has connected,
## since the first _set_state() happens before it exists.
func announce() -> void:
	_set_state(_state)


func target_position() -> Vector3:
	match _state:
		State.CLOCK_IN, State.GET_CHANGE:
			return TILL
		State.DRIVING_IN, State.PUMPING, State.TAKE_PAYMENT, State.RETURN_CHANGE:
			if _customer != null and is_instance_valid(_customer):
				return _customer.global_position
			return _customer_spot
		_:
			return Vector3.ZERO


func has_target() -> bool:
	return _state != State.WAITING and _state != State.DRIVING_OUT


func in_reach() -> bool:
	if player == null or not has_target():
		return false
	var flat_player: Vector3 = player.global_position
	var flat_target := target_position()
	flat_player.y = 0.0
	flat_target.y = 0.0
	return flat_player.distance_to(flat_target) <= REACH


## What the interact button should say right now, or "" when there's nothing to
## do here. The HUD reads this every frame rather than being told, so the button
## can never be left showing a stale verb.
func prompt() -> String:
	if not in_reach():
		return ""
	match _state:
		State.CLOCK_IN:
			return "CLOCK IN"
		State.PUMPING:
			return "FILL"
		State.TAKE_PAYMENT:
			return "TAKE CASH"
		State.GET_CHANGE:
			return "OPEN TILL"
		State.RETURN_CHANGE:
			return "GIVE CHANGE"
		_:
			return ""


## Progress 0..1 for anything that's held rather than tapped.
func fill_ratio() -> float:
	return clampf(_fill / FILL_SECONDS, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Doing it
# ---------------------------------------------------------------------------

## Called by the HUD while the interact button is held. Tap-style actions fire
## once on press; FILL is the only one that accumulates.
func interact(held: bool, delta: float) -> void:
	if not in_reach():
		return
	match _state:
		State.PUMPING:
			if held:
				_fill += delta
				if _fill >= FILL_SECONDS:
					_owed = _litres * PRICE_PER_LITRE
					Sfx.play("ping", -6.0)
					_set_state(State.TAKE_PAYMENT)
		_:
			pass


## Called once per press, for everything that isn't a hold.
func interact_pressed() -> void:
	if not in_reach():
		return
	match _state:
		State.CLOCK_IN:
			Sfx.play("dial", -6.0)
			_set_state(State.WAITING)
		State.TAKE_PAYMENT:
			# They pay with a note, so there's change to fetch.
			_held_cash = ceilf(_owed / 20.0) * 20.0
			Sfx.play("hitmark", -8.0)
			_set_state(State.GET_CHANGE)
		State.GET_CHANGE:
			Sfx.play("dial", -8.0)
			_set_state(State.RETURN_CHANGE)
		State.RETURN_CHANGE:
			_earned += _owed
			_held_cash = 0.0
			Sfx.play("ping", -8.0)
			_start_driving_out()
		_:
			pass


# ---------------------------------------------------------------------------
# Customers
# ---------------------------------------------------------------------------

func _send_a_customer() -> void:
	_customer_spot = PUMP_SPOTS[randi() % PUMP_SPOTS.size()]
	_litres = float(randi_range(18, 62))
	_fill = 0.0

	if _world.has_method("build_car"):
		_customer = _world.build_car(Color(
			randf_range(0.2, 0.8), randf_range(0.2, 0.8), randf_range(0.2, 0.8)))
		_world.add_child(_customer)
		# Come in off the road, so a car appears from somewhere rather than
		# materialising on the forecourt.
		_drive_from = Vector3(_customer_spot.x * 2.4, 0.0, 30.0)
		_customer.global_position = _drive_from
		_drive_t = 0.0
	_set_state(State.DRIVING_IN)


func _drive_customer(delta: float) -> void:
	if _customer == null or not is_instance_valid(_customer):
		_set_state(State.PUMPING)
		return
	_drive_t = minf(1.0, _drive_t + delta * 0.35)
	var eased := _drive_t * _drive_t * (3.0 - 2.0 * _drive_t)
	_customer.global_position = _drive_from.lerp(_customer_spot, eased)
	if _drive_t >= 1.0:
		_set_state(State.PUMPING)


## They pull out and drive off rather than vanishing on the spot.
func _start_driving_out() -> void:
	if _customer == null or not is_instance_valid(_customer):
		_set_state(State.WAITING)
		return
	_drive_from = _customer.global_position
	_drive_t = 0.0
	_set_state(State.DRIVING_OUT)


func _drive_customer_out(delta: float) -> void:
	if _customer == null or not is_instance_valid(_customer):
		_set_state(State.WAITING)
		return
	_drive_t = minf(1.0, _drive_t + delta * 0.30)
	var eased := _drive_t * _drive_t * (3.0 - 2.0 * _drive_t)
	# Out the way they came in, onto the road and off the map.
	var exit_point := Vector3(_drive_from.x * 2.4, 0.0, 34.0)
	_customer.global_position = _drive_from.lerp(exit_point, eased)
	if _drive_t >= 1.0:
		_customer.queue_free()
		_customer = null
		_set_state(State.WAITING)


# ---------------------------------------------------------------------------
# The marker
# ---------------------------------------------------------------------------

## A floating beam over wherever you're meant to be. Unshaded and always drawn
## so it reads through the store wall — the point is to be findable, not to be
## physically plausible.
func _build_marker() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(Palette.TRACK.r, Palette.TRACK.g, Palette.TRACK.b, 0.45)
	mat.emission_enabled = true
	mat.emission = Palette.TRACK
	mat.emission_energy_multiplier = 2.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 5

	var beam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	# Slimmer and shorter than it was. Jay measured 60fps dropping to 40 both
	# times he was close to this thing, and a wide always-on-top transparent
	# column is exactly the overdraw that does that on a phone.
	mesh.size = Vector3(0.22, 4.0, 0.22)
	beam.mesh = mesh
	beam.material_override = mat
	beam.position = Vector3(0, 2.0, 0)
	root.add_child(beam)
	return root


func _update_marker() -> void:
	if _marker == null:
		return
	if not has_target() or player == null:
		_marker.visible = false
		return

	var to := target_position()
	# Fade it out as you approach and switch it off entirely once you're there.
	# You don't need a signpost while standing on the thing it points at, and
	# not drawing it is what actually buys the frames back — at arm's length it
	# was covering most of the screen.
	var d: float = player.global_position.distance_to(to)
	if d <= REACH:
		_marker.visible = false
		return
	_marker.visible = true
	_marker.global_position = to
	var fade: float = clampf((d - REACH) / 6.0, 0.0, 1.0)
	_marker.scale = Vector3(fade, 1.0, fade)
