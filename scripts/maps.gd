extends Node
class_name Maps
## The map roster.
##
## Only Beach Gas is built. The rest are listed deliberately — a locked slot
## says "more coming" far better than an empty screen does, and the plumbing
## (selection, syncing to everyone in the lobby, protocol) is already live, so
## adding a real one later is just a scene and a flag.

const LIST: Array[Dictionary] = [
	{
		"id": "beach_gas",
		"name": "Beach Gas",
		"blurb": "24-hour forecourt. Store, canopy, and nowhere good to hide.",
		"scene": "res://scenes/beach_gas.tscn",
		"available": true,
	},
	{
		"id": "level_three",
		"name": "Level 3 Parking",
		"blurb": "Low ceiling, pillars everywhere, and a deck above half of it.",
		"scene": "res://scenes/level_three.tscn",
		"available": true,
	},
	{
		"id": "beach_gas_real",
		"name": "Beach Gas (Real)",
		"blurb": "The actual station. Gravel, forest, four pumps and nowhere to hide.",
		"scene": "res://scenes/beach_gas_real.tscn",
		"available": true,
	},
	{
		"id": "sudz",
		"name": "Sudz Car Wash",
		"blurb": "Coming soon.",
		"scene": "",
		"available": false,
	},
	{
		"id": "sunset_motel",
		"name": "Sunset Motel",
		"blurb": "Coming soon.",
		"scene": "",
		"available": false,
	},
]

const DEFAULT_ID := "beach_gas"


static func get_map(id: String) -> Dictionary:
	for m in LIST:
		if m["id"] == id:
			return m
	return LIST[0]


static func display_name(id: String) -> String:
	return str(get_map(id)["name"])


static func is_available(id: String) -> bool:
	return bool(get_map(id)["available"])


## Scene to load for a map, falling back to the default if the id is unknown or
## the map isn't built yet.
static func scene_path(id: String) -> String:
	var path := str(get_map(id).get("scene", ""))
	return path if path != "" else str(get_map(DEFAULT_ID)["scene"])
