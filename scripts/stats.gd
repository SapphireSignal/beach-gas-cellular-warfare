extends Node
## Autoload: "Stats"
##
## Career records, kept on this device.
##
## A true cross-player leaderboard would need a server none of us want to run,
## so this tracks two things that are actually knowable locally: everything
## you've ever done, broken down by character, and the final standings of the
## last match you played. Between them you get "am I getting better" and "who
## won last time", which is what a leaderboard is for anyway.

const PATH := "user://stats.cfg"

signal changed()

var kills := 0
var deaths := 0
var matches := 0
var best_streak := 0
var best_match_kills := 0

## character index -> { kills, deaths }
var by_character: Dictionary = {}
## Final standings of the last match: [{ name, character, kills, deaths }]
var last_match: Array = []

var _streak := 0


func _ready() -> void:
	load_stats()
	Net.kill_confirmed.connect(_on_kill)
	Net.match_started.connect(_on_match_started)


func kd() -> float:
	return float(kills) if deaths == 0 else float(kills) / float(deaths)


## Characters you've actually played, best first. The list is built from the
## record rather than the roster, so it only shows people you've used.
func character_ranking() -> Array:
	var rows := []
	for index in by_character:
		var row: Dictionary = by_character[index].duplicate()
		row["character"] = int(index)
		row["name"] = Characters.display_name(int(index))
		rows.append(row)
	rows.sort_custom(func(a, b): return int(a["kills"]) > int(b["kills"]))
	return rows


# ---------------------------------------------------------------------------

func _on_match_started() -> void:
	matches += 1
	_streak = 0
	save()


func _on_kill(_victim_id: int) -> void:
	kills += 1
	_streak += 1
	best_streak = maxi(best_streak, _streak)
	_bump(Loadout.character_index, 1, 0)
	changed.emit()
	save()


## Called by the player when it goes down. Not a Net signal because dying is a
## thing that happens to your body, not to the lobby.
func record_death() -> void:
	deaths += 1
	_streak = 0
	_bump(Loadout.character_index, 0, 1)
	changed.emit()
	save()


## Snapshot the standings as a match ends, so there's always a "last game" to
## point at even after everyone has left.
func record_match_end() -> void:
	last_match.clear()
	var mine := 0
	for row in Net.sorted_scoreboard():
		var id := int(row["id"])
		last_match.append({
			"name": str(row["name"]),
			"character": Net.character_of(id),
			"kills": int(row["kills"]),
			"deaths": int(row["deaths"]),
			"you": id == Net.my_id(),
		})
		if id == Net.my_id():
			mine = int(row["kills"])
	best_match_kills = maxi(best_match_kills, mine)
	changed.emit()
	save()


func _bump(character: int, k: int, d: int) -> void:
	if not by_character.has(character):
		by_character[character] = {"kills": 0, "deaths": 0}
	by_character[character]["kills"] = int(by_character[character]["kills"]) + k
	by_character[character]["deaths"] = int(by_character[character]["deaths"]) + d


func reset() -> void:
	kills = 0
	deaths = 0
	matches = 0
	best_streak = 0
	best_match_kills = 0
	by_character.clear()
	last_match.clear()
	_streak = 0
	changed.emit()
	save()


# ---------------------------------------------------------------------------

func load_stats() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	kills = int(cfg.get_value("career", "kills", 0))
	deaths = int(cfg.get_value("career", "deaths", 0))
	matches = int(cfg.get_value("career", "matches", 0))
	best_streak = int(cfg.get_value("career", "best_streak", 0))
	best_match_kills = int(cfg.get_value("career", "best_match_kills", 0))
	by_character = cfg.get_value("career", "by_character", {})
	last_match = cfg.get_value("career", "last_match", [])


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("career", "kills", kills)
	cfg.set_value("career", "deaths", deaths)
	cfg.set_value("career", "matches", matches)
	cfg.set_value("career", "best_streak", best_streak)
	cfg.set_value("career", "best_match_kills", best_match_kills)
	cfg.set_value("career", "by_character", by_character)
	cfg.set_value("career", "last_match", last_match)
	cfg.save(PATH)
