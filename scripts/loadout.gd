extends Node
## Autoload: "Loadout"
##
## Cosmetics and the saved player name.
##
## Two separate things on purpose:
##   CASE   the shell of your phone. Everyone sees it, so it's how people tell
##          each other apart across the lot.
##   THEME  your HUD accent. Only you see it.
##
## What is deliberately NOT customisable: the phone *screen* colour. Red/green/
## blue mean zap/track/call, and reading a stranger's glowing screen across the
## forecourt is real information. Letting people recolour that would quietly
## delete a mechanic.

const SETTINGS_PATH := "user://player.cfg"

const CASES: Array[Dictionary] = [
	{"name": "Midnight", "color": Color(0.09, 0.09, 0.12)},
	{"name": "Ember", "color": Color(0.72, 0.22, 0.14)},
	{"name": "Mint", "color": Color(0.36, 0.78, 0.62)},
	{"name": "Ice", "color": Color(0.72, 0.82, 0.90)},
	{"name": "Gold", "color": Color(0.78, 0.62, 0.22)},
	{"name": "Carbon", "color": Color(0.20, 0.21, 0.24)},
	{"name": "Bubblegum", "color": Color(0.92, 0.45, 0.68)},
	{"name": "Toxic", "color": Color(0.65, 0.85, 0.18)},
]

const THEMES: Array[Dictionary] = [
	{"name": "Classic", "accent": Color(1.00, 1.00, 1.00)},
	{"name": "Cyan", "accent": Color(0.35, 0.90, 1.00)},
	{"name": "Amber", "accent": Color(1.00, 0.74, 0.30)},
	{"name": "Violet", "accent": Color(0.72, 0.58, 1.00)},
	{"name": "Lime", "accent": Color(0.62, 1.00, 0.40)},
	{"name": "Rose", "accent": Color(1.00, 0.50, 0.62)},
]

var player_name := ""
var case_index := 0
var theme_index := 0
var character_index := 0


func _ready() -> void:
	load_settings()


func case_color() -> Color:
	return CASES[clampi(case_index, 0, CASES.size() - 1)]["color"]


static func case_color_for(index: int) -> Color:
	return CASES[clampi(index, 0, CASES.size() - 1)]["color"]


func accent() -> Color:
	return THEMES[clampi(theme_index, 0, THEMES.size() - 1)]["accent"]


## Accent at a given opacity — most HUD drawing wants this.
func accent_a(alpha: float) -> Color:
	var c := accent()
	return Color(c.r, c.g, c.b, alpha)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	player_name = str(cfg.get_value("player", "name", ""))
	case_index = int(cfg.get_value("player", "case", 0))
	theme_index = int(cfg.get_value("player", "theme", 0))
	character_index = int(cfg.get_value("player", "character", 0))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "case", case_index)
	cfg.set_value("player", "theme", theme_index)
	cfg.set_value("player", "character", character_index)
	cfg.save(SETTINGS_PATH)
