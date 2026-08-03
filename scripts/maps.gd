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
		"available": true,
	},
	{
		"id": "sudz",
		"name": "Sudz Car Wash",
		"blurb": "Coming soon.",
		"available": false,
	},
	{
		"id": "sunset_motel",
		"name": "Sunset Motel",
		"blurb": "Coming soon.",
		"available": false,
	},
	{
		"id": "level_three",
		"name": "Level 3 Parking",
		"blurb": "Coming soon.",
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
