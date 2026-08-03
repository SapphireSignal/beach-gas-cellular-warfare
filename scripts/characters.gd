extends Node
class_name Characters
## The roster.
##
## Everyone is built from primitives at runtime — same as the level — so the
## whole game still ships with zero binary assets. Each entry is pure data;
## character_builder.gd turns it into a body and character_props.gd builds the
## thing they're posing with.
##
## `prop` is showcase only. You bring your haircut and your hat into a match.
## You do not bring your car.

const ROSTER: Array[Dictionary] = [
	{
		"id": "jay", "name": "Jay",
		"blurb": "AirPods in, cap down, entirely unbothered.",
		"female": false, "seated": false,
		"skin": Color(0.72, 0.54, 0.40), "hair": Color(0.12, 0.10, 0.09),
		"hair_style": "short", "shirt": Color(0.16, 0.18, 0.26), "pants": Color(0.20, 0.22, 0.30),
		"accessories": ["cap", "airpods"], "accent": Color(0.90, 0.30, 0.35),
		"cap_color": Color(0.06, 0.065, 0.08),
		"prop": "music", "vibe": "chill",
	},
	{
		"id": "josh", "name": "Josh",
		"blurb": "Out back. Says he's on his fifteen.",
		"female": false, "seated": false,
		"skin": Color(0.80, 0.63, 0.50), "hair": Color(0.32, 0.20, 0.12),
		"hair_style": "curly", "shirt": Color(0.30, 0.42, 0.28), "pants": Color(0.24, 0.24, 0.28),
		"accessories": ["beard"], "accent": Color(0.55, 0.80, 0.40),
		"prop": "joint", "vibe": "smoke",
	},
	{
		"id": "david", "name": "David",
		"blurb": "Third one today. It's 11am.",
		"female": false, "seated": false,
		"skin": Color(0.76, 0.58, 0.45), "hair": Color(0.16, 0.13, 0.10),
		"hair_style": "buzz", "shirt": Color(0.14, 0.15, 0.17), "pants": Color(0.18, 0.20, 0.24),
		"accessories": [], "accent": Color(0.45, 0.95, 0.30),
		"prop": "monster", "vibe": "buzz",
	},
	{
		"id": "roger", "name": "Roger",
		"blurb": "Brought the laptop. Says the WiFi here is better.",
		"female": false, "seated": true,
		"skin": Color(0.82, 0.66, 0.54), "hair": Color(0.42, 0.40, 0.38),
		"hair_style": "short", "shirt": Color(0.22, 0.30, 0.42), "pants": Color(0.20, 0.20, 0.24),
		"accessories": ["glasses"], "accent": Color(0.40, 0.75, 1.00),
		"prop": "computer", "vibe": "tech",
	},
	{
		"id": "edward", "name": "Edward",
		"blurb": "The mohawk matches the bike. On purpose.",
		"female": false, "seated": false,
		"skin": Color(0.74, 0.56, 0.44), "hair": Color(0.85, 0.20, 0.22),
		"hair_style": "mohawk", "shirt": Color(0.12, 0.12, 0.14), "pants": Color(0.15, 0.15, 0.18),
		"accessories": ["earrings"], "accent": Color(1.00, 0.25, 0.20),
		"prop": "sportbike", "vibe": "sparks",
	},
	{
		"id": "eddie", "name": "Eddie",
		"blurb": "Washed it this morning. Will mention it.",
		"female": false, "seated": false,
		"skin": Color(0.70, 0.52, 0.40), "hair": Color(0.20, 0.16, 0.12),
		"hair_style": "short", "shirt": Color(0.86, 0.86, 0.88), "pants": Color(0.22, 0.30, 0.48),
		"accessories": [], "accent": Color(0.25, 0.45, 0.95),
		"prop": "car", "vibe": "calm",
	},
	{
		"id": "cheree", "name": "Cheree",
		"blurb": "Two orange, one black, zero regrets.",
		"female": true, "seated": false,
		"skin": Color(0.84, 0.68, 0.56), "hair": Color(0.35, 0.22, 0.14),
		"hair_style": "long", "shirt": Color(0.62, 0.34, 0.52), "pants": Color(0.24, 0.24, 0.30),
		"accessories": [], "accent": Color(0.95, 0.55, 0.25),
		"prop": "cats", "vibe": "warm",
	},
	{
		"id": "gary", "name": "Gary",
		"blurb": "Electrolytes. It's what plants crave.",
		"female": false, "seated": false,
		"skin": Color(0.78, 0.60, 0.47), "hair": Color(0.55, 0.52, 0.48),
		"hair_style": "buzz", "shirt": Color(0.30, 0.46, 0.36), "pants": Color(0.26, 0.26, 0.28),
		"accessories": ["beard"], "accent": Color(1.00, 0.60, 0.15),
		"prop": "gatorade", "vibe": "buzz",
	},
	{
		"id": "jeanette", "name": "Jeanette",
		"blurb": "Drawing you. No, keep doing what you were doing.",
		"female": true, "seated": false,
		"skin": Color(0.86, 0.70, 0.58), "hair": Color(0.14, 0.11, 0.10),
		"hair_style": "bun", "shirt": Color(0.90, 0.86, 0.78), "pants": Color(0.30, 0.34, 0.42),
		"accessories": [], "accent": Color(0.95, 0.75, 0.40),
		"prop": "art", "vibe": "paint",
	},
	{
		"id": "jared", "name": "Jared",
		"blurb": "Large fries. Ate them in the car. Again.",
		"female": false, "seated": false,
		"skin": Color(0.80, 0.62, 0.48), "hair": Color(0.26, 0.18, 0.12),
		"hair_style": "short", "shirt": Color(0.72, 0.24, 0.22), "pants": Color(0.20, 0.22, 0.26),
		"accessories": [], "accent": Color(1.00, 0.78, 0.10),
		"prop": "mcdonalds", "vibe": "warm",
	},
	{
		"id": "alli", "name": "Alli",
		"blurb": "Has a two year old. Runs on very little sleep.",
		"female": true, "seated": false,
		"skin": Color(0.88, 0.72, 0.60), "hair": Color(0.52, 0.36, 0.18),
		"hair_style": "long", "shirt": Color(0.36, 0.60, 0.66), "pants": Color(0.22, 0.24, 0.30),
		"accessories": [], "accent": Color(0.98, 0.62, 0.72),
		"prop": "daughter", "vibe": "warm",
	},
	{
		"id": "kerissa", "name": "Kerissa",
		"blurb": "Found the one good chair. Not giving it up.",
		"female": true, "seated": true,
		"skin": Color(0.82, 0.65, 0.53), "hair": Color(0.10, 0.09, 0.09),
		"hair_style": "long", "shirt": Color(0.46, 0.32, 0.58), "pants": Color(0.18, 0.20, 0.26),
		"accessories": [], "accent": Color(0.72, 0.50, 1.00),
		"prop": "rocker", "vibe": "calm",
	},
]


static func count() -> int:
	return ROSTER.size()


static func get_entry(index: int) -> Dictionary:
	return ROSTER[clampi(index, 0, ROSTER.size() - 1)]


static func display_name(index: int) -> String:
	return str(get_entry(index)["name"])
