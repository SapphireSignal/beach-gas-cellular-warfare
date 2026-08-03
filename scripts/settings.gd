extends Node
## Autoload: "Settings"
##
## Graphics, framerate and audio, saved between sessions.
##
## Quality is deliberately coarse. Three presets you can understand at a glance
## beat a page of individual toggles nobody will ever touch — and on a phone
## the only decision that actually matters is "is this cooking my battery".

signal changed()

const PATH := "user://settings.cfg"

enum Quality { LOW, GOOD, AWESOME }

## TAP  - drag the right side to look, quick tap anywhere there to fire.
## AUTO - fires by itself whenever somebody is under your crosshair.
##
## Tap is the default on purpose. Auto is a real accessibility option, but with
## everyone using it a match stops being about aiming at all.
enum Fire { TAP, AUTO }
const FIRE_NAMES := ["Tap", "Auto"]

const QUALITY_NAMES := ["Low", "Good", "Awesome"]
const QUALITY_BLURBS := [
	"No shadows or bloom. Coolest and longest battery life.",
	"Bloom on, shadows on desktop. The intended look.",
	"Everything on, sharpest edges. Warmest on a phone.",
]

## 0 means uncapped.
const FPS_OPTIONS := [30, 60, 90, 120, 240, 0]
const FPS_NAMES := ["30", "60", "90", "120", "240", "Max"]

var quality := Quality.GOOD
var fps_index := 1
var master_volume := 0.9
var sfx_volume := 0.9
var look_sensitivity := 1.0
var show_fps := true
var fire_mode := Fire.TAP
## Slows your drag and pulls gently toward a target your crosshair is already
## near. Touch only — on a mouse it just feels like the game grabbing the aim.
var aim_assist := true


func _ready() -> void:
	_ensure_buses()
	load_settings()
	# Phones default to 60 and Good the first time; there's no sensible reason
	# for a 60Hz panel to render 240 frames it will never show.
	if OS.has_feature("mobile") and not FileAccess.file_exists(PATH):
		fps_index = 1
	apply_all()


func quality_name() -> String:
	return QUALITY_NAMES[quality]


## True when this quality level should draw real-time shadows at all. Phones
## never get them — shadow mapping is the single most expensive thing here.
func shadows_enabled() -> bool:
	if OS.has_feature("mobile"):
		return false
	return quality != Quality.LOW


func glow_enabled() -> bool:
	return quality != Quality.LOW


func shadow_distance() -> float:
	return 55.0 if quality == Quality.AWESOME else 42.0


func msaa() -> Viewport.MSAA:
	match quality:
		Quality.LOW: return Viewport.MSAA_DISABLED
		Quality.AWESOME: return Viewport.MSAA_4X
		_: return Viewport.MSAA_2X


func fps_cap() -> int:
	return FPS_OPTIONS[clampi(fps_index, 0, FPS_OPTIONS.size() - 1)]


# ---------------------------------------------------------------------------

func apply_all() -> void:
	apply_framerate()
	apply_audio()
	apply_video()
	changed.emit()


## Phones default to 60 — their panels are 60Hz anyway, and running flat out
## cooks the battery on a device somebody has to work a shift with. This is the
## only place the cap is set: main.gd used to force 60 on mobile at startup as
## well, which quietly threw away a saved choice of 30 every time the game
## launched.
func apply_framerate() -> void:
	Engine.max_fps = fps_cap()


func apply_audio() -> void:
	_set_bus("Master", master_volume)
	_set_bus("SFX", sfx_volume)


func apply_video() -> void:
	var tree := get_tree()
	if tree != null and tree.root != null:
		tree.root.msaa_3d = msaa()


func _set_bus(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))


## Sound effects live on their own bus so they can be turned down without
## silencing everything. Created at runtime — no need for a bus layout asset.
func _ensure_buses() -> void:
	if AudioServer.get_bus_index("SFX") >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, "SFX")
	AudioServer.set_bus_send(index, "Master")


# ---------------------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	quality = clampi(int(cfg.get_value("video", "quality", Quality.GOOD)), 0, 2) as Quality
	fps_index = clampi(int(cfg.get_value("video", "fps", 1)), 0, FPS_OPTIONS.size() - 1)
	show_fps = bool(cfg.get_value("video", "show_fps", true))
	master_volume = clampf(float(cfg.get_value("audio", "master", 0.9)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 0.9)), 0.0, 1.0)
	look_sensitivity = clampf(float(cfg.get_value("input", "sensitivity", 1.0)), 0.25, 3.0)
	fire_mode = clampi(int(cfg.get_value("input", "fire_mode", Fire.TAP)), 0, 1) as Fire
	aim_assist = bool(cfg.get_value("input", "aim_assist", true))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", int(quality))
	cfg.set_value("video", "fps", fps_index)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("input", "sensitivity", look_sensitivity)
	cfg.set_value("input", "fire_mode", int(fire_mode))
	cfg.set_value("input", "aim_assist", aim_assist)
	cfg.save(PATH)
	apply_all()
