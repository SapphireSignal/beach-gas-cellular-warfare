extends Node
## Autoload: "Net"
##
## Owns everything network related: LAN host discovery, the lobby, and the
## authoritative match state.
##
## Authority model, deliberately simple because this is a friendly duel on a
## local network with people standing next to each other:
##   - Movement is client authoritative. Each player owns their own body and
##     tells everyone else where it is. Feels great, zero rubber-banding.
##   - Damage, kills, respawns and the score are host authoritative. Clients
##     *report* hits, the host decides whether they count.

const PORT := 27015
const DISCOVERY_PORT := 27016
const DISCOVERY_MAGIC := "LENSLETHAL1"

## Bump this whenever anything about the network conversation changes — an RPC
## signature, a packed flag, a field in the lobby record. Mixed versions produce
## confusing bugs, so we detect the mismatch and say so instead.
## 6: crouch added to the state flags (shifting the mode bits), and _show_beam
## gained the surface normal and material for impact effects.
const PROTOCOL_VERSION := 6
const MAX_PLAYERS := 8
## 0 means the match never ends on its own — the score just keeps climbing and
## you play until somebody quits. That's what a game on your break actually is.
const KILLS_TO_WIN := 0

## Practice opponents live in the players dictionary like anyone else, but they
## have no peer behind them — the host simulates them locally.
const BOT_ID_BASE := 9000
const RESPAWN_DELAY := 3.5
const SPAWN_COUNT := 8

# Server side sanity checks on reported hits. Not real anti-cheat, just enough
# that a desynced or buggy client can't delete somebody's health bar.
## Sanity bounds on a reported hit. These must track phone.gd: the cap sits just
## above ZAP_DAMAGE, and the interval just under ZAP_COOLDOWN so ordinary
## network jitter never eats a legitimate shot.
##
## These were left at beam-era values (12 damage, 70ms) after the weapon went
## back to single shots, which silently clamped every hit to a third of its
## damage — nine hits to kill instead of three.
const MAX_ZAP_RANGE := 70.0
const MAX_ZAP_DAMAGE := 40.0
const MIN_ZAP_INTERVAL_MS := 140

signal lobby_changed()
signal match_started()
signal match_over(winner_id: int)
signal net_error(msg: String)
signal feed(text: String)
signal hosts_found()
signal left_match()

## peer_id -> { name: String, kills: int, deaths: int, health: float }
var players: Dictionary = {}
var local_name := "Player"
var in_match := false
## Chosen by the host in the lobby and mirrored to everyone.
var selected_map := Maps.DEFAULT_ID

## Set by main.gd once the level exists so RPCs have something to spawn into.
var world = null

## Discovered LAN games: ip -> { name, ip, code, players, max, last_seen_ms }
var found_hosts: Dictionary = {}

var _connected := false
var _ready_peers := {}
var _last_hit_ms := {}

var _broadcaster: PacketPeerUDP = null
var _broadcast_targets: PackedStringArray = []
var _listener: UDPServer = null
var _beacon_accum := 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_server_left)


func _process(delta: float) -> void:
	_pump_beacon(delta)
	_pump_listener()


# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------

func is_host() -> bool:
	return _connected and multiplayer.multiplayer_peer != null and multiplayer.is_server()


func is_connected_to_game() -> bool:
	return _connected


func my_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()


func host_game(pname: String) -> bool:
	_teardown()
	local_name = _clean_name(pname)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		net_error.emit("Couldn't open port %d. Is the game already running?" % PORT)
		return false
	multiplayer.multiplayer_peer = peer
	_connected = true
	players = {1: _blank_record(local_name, Loadout.case_index, Loadout.character_index)}
	stop_looking_for_hosts()
	_start_beacon()
	lobby_changed.emit()
	return true


## Accepts a full address ("192.168.1.42") or a short join code ("1-42" / "1.42"),
## which expands to 192.168.<a>.<b>.
func join_game(pname: String, address: String) -> bool:
	_teardown()
	local_name = _clean_name(pname)
	var ip := expand_code(address.strip_edges())
	if ip == "":
		net_error.emit("'%s' isn't an address or a join code." % address)
		return false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		net_error.emit("Couldn't reach %s." % ip)
		return false
	multiplayer.multiplayer_peer = peer
	stop_looking_for_hosts()
	return true


func leave() -> void:
	_teardown()
	left_match.emit()
	lobby_changed.emit()


static func is_bot(pid: int) -> bool:
	return pid >= BOT_ID_BASE


func bot_count() -> int:
	var n := 0
	for id in players:
		if is_bot(int(id)):
			n += 1
	return n


## Solo mode: host a match against locally simulated opponents. Useful for
## learning the controls, and for playing at all when nobody else is around.
func start_practice(pname: String, bots := 1) -> bool:
	if not host_game(pname):
		return false
	_stop_beacon()   # practice games aren't advertised
	for i in bots:
		# Give bots a different face and case from yours so you can tell at a
		# glance which body is which.
		var who := (Loadout.character_index + 1 + i) % Characters.count()
		players[BOT_ID_BASE + 1 + i] = _blank_record(Characters.display_name(who),
			(Loadout.case_index + 3 + i) % Loadout.CASES.size(), who)
	lobby_changed.emit()
	begin_match()
	return true


## After a match ends we drop back to the lobby rather than disconnecting, so
## start advertising again and let stragglers find us.
func reopen_lobby() -> void:
	if is_host() and _broadcaster == null:
		_start_beacon()


func _teardown() -> void:
	_stop_beacon()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_connected = false
	in_match = false
	players.clear()
	_ready_peers.clear()
	_last_hit_ms.clear()
	world = null


func _on_connected_ok() -> void:
	_connected = true
	_register.rpc_id(1, local_name, PROTOCOL_VERSION, Loadout.case_index, Loadout.character_index)


func _on_connect_failed() -> void:
	_teardown()
	net_error.emit("Couldn't join. Are you both on the same WiFi?")
	lobby_changed.emit()


func _on_server_left() -> void:
	_teardown()
	net_error.emit("The host left the game.")
	lobby_changed.emit()


func _on_peer_connected(_id: int) -> void:
	pass  # We wait for their _register call so we know their name.


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var who: String = players.get(id, {}).get("name", "Someone")
	players.erase(id)
	_ready_peers.erase(id)
	_sync_lobby.rpc(players)
	_feed.rpc("%s left" % who)
	if in_match:
		if world and world.has_method("despawn_player"):
			world.despawn_player(id)
		_despawn.rpc(id)
		if players.size() < 2:
			in_match = false
			_finish.rpc(-1)


@rpc("any_peer", "reliable")
func _register(pname: String, version: int, case_index: int, character_index: int) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if version != PROTOCOL_VERSION:
		_reject.rpc_id(id, "Different game version. Everyone needs the same build installed.")
		_boot_peer(id)
		return
	if players.size() >= MAX_PLAYERS:
		_reject.rpc_id(id, "That game is full (%d players)." % MAX_PLAYERS)
		_boot_peer(id)
		return
	if in_match:
		_reject.rpc_id(id, "That match already started. Wait for the next round.")
		_boot_peer(id)
		return
	players[id] = _blank_record(_unique_name(_clean_name(pname)), case_index, character_index)
	_sync_lobby.rpc(players)
	_feed.rpc("%s joined" % players[id]["name"])


@rpc("authority", "reliable")
func _reject(reason: String) -> void:
	_teardown()
	net_error.emit(reason)
	lobby_changed.emit()


## Give the rejection message a moment to land before cutting the peer off.
func _boot_peer(id: int) -> void:
	await get_tree().create_timer(0.4).timeout
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.disconnect_peer(id)


@rpc("authority", "call_local", "reliable")
func _sync_lobby(data: Dictionary) -> void:
	players = data
	lobby_changed.emit()


## Host picks the map; everyone else is told. Guests can't change it.
func choose_map(id: String) -> void:
	if not is_host() or not Maps.is_available(id):
		return
	_sync_map.rpc(id)


@rpc("authority", "call_local", "reliable")
func _sync_map(id: String) -> void:
	selected_map = id
	lobby_changed.emit()


@rpc("authority", "call_local", "reliable")
func _feed(text: String) -> void:
	feed.emit(text)


# ---------------------------------------------------------------------------
# LAN discovery
#
# The host shouts a small JSON blob over UDP broadcast a couple times a second.
# Everyone sitting on the join screen listens for it, so nobody has to read an
# IP address off somebody else's screen.
# ---------------------------------------------------------------------------

func _start_beacon() -> void:
	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)
	_broadcast_targets = _broadcast_addresses()
	_beacon_accum = 999.0


func _stop_beacon() -> void:
	if _broadcaster:
		_broadcaster.close()
	_broadcaster = null


func _pump_beacon(delta: float) -> void:
	if _broadcaster == null or in_match:
		return
	_beacon_accum += delta
	if _beacon_accum < 0.6:
		return
	_beacon_accum = 0.0
	var payload := JSON.stringify({
		"magic": DISCOVERY_MAGIC,
		"name": local_name,
		"ip": local_ip(),
		"code": join_code(),
		"players": players.size(),
		"max": MAX_PLAYERS,
		"version": PROTOCOL_VERSION,
		"map": Maps.display_name(selected_map),
	}).to_utf8_buffer()
	for addr in _broadcast_targets:
		_broadcaster.set_dest_address(addr, DISCOVERY_PORT)
		_broadcaster.put_packet(payload)


func look_for_hosts() -> void:
	if _listener != null:
		return
	found_hosts.clear()
	_listener = UDPServer.new()
	if _listener.listen(DISCOVERY_PORT) != OK:
		_listener = null


func stop_looking_for_hosts() -> void:
	if _listener:
		_listener.stop()
	_listener = null


func _pump_listener() -> void:
	if _listener == null:
		return
	_listener.poll()
	while _listener.is_connection_available():
		var peer := _listener.take_connection()
		var raw := peer.get_packet().get_string_from_utf8()
		var data = JSON.parse_string(raw)
		if typeof(data) != TYPE_DICTIONARY or data.get("magic", "") != DISCOVERY_MAGIC:
			continue
		var ip: String = str(data.get("ip", ""))
		var from := peer.get_packet_ip()
		if from != "":
			ip = from  # Trust where it actually came from over what it claims.
		if ip == "" or ip in local_addresses():
			continue  # Don't list our own beacon back to us.
		found_hosts[ip] = {
			"name": str(data.get("name", "Someone")),
			"ip": ip,
			"code": str(data.get("code", "")),
			"players": int(data.get("players", 1)),
			"max": int(data.get("max", MAX_PLAYERS)),
			"version": int(data.get("version", 0)),
			"map": str(data.get("map", "")),
			"last_seen_ms": Time.get_ticks_msec(),
		}
		hosts_found.emit()

	# Forget hosts that have gone quiet.
	var now := Time.get_ticks_msec()
	var stale := []
	for ip in found_hosts:
		if now - int(found_hosts[ip]["last_seen_ms"]) > 3000:
			stale.append(ip)
	if not stale.is_empty():
		for ip in stale:
			found_hosts.erase(ip)
		hosts_found.emit()


static func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.begins_with("127.") or a.contains(":"):
			continue
		out.append(a)
	return out


## Best guess at the address other phones on this WiFi should dial.
static func local_ip() -> String:
	var all := local_addresses()
	for a in all:
		if a.begins_with("192.168."):
			return a
	for a in all:
		if a.begins_with("172.") or a.begins_with("10."):
			return a
	return all[0] if all.size() > 0 else ""


## Short human-readable code for the common 192.168.x.y case, e.g. "1-42".
static func join_code() -> String:
	var ip := local_ip()
	var parts := ip.split(".")
	if parts.size() == 4 and parts[0] == "192" and parts[1] == "168":
		return "%s-%s" % [parts[2], parts[3]]
	return ip


## Inverse of join_code(). Also passes full IPs straight through.
static func expand_code(text: String) -> String:
	if text == "":
		return ""
	if text.count(".") == 3:
		return text
	var parts := text.replace(".", "-").split("-")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return "192.168.%s.%s" % [parts[0], parts[1]]
	return ""


static func _broadcast_addresses() -> PackedStringArray:
	var out := PackedStringArray(["255.255.255.255"])
	# Some routers drop the global broadcast, so also target each subnet directly.
	for a in local_addresses():
		var parts := a.split(".")
		if parts.size() == 4:
			var subnet := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
			if not subnet in out:
				out.append(subnet)
	return out


# ---------------------------------------------------------------------------
# Match flow
# ---------------------------------------------------------------------------

func begin_match() -> void:
	if not is_host() or players.size() < 2:
		return
	for id in players:
		players[id]["kills"] = 0
		players[id]["deaths"] = 0
		players[id]["health"] = 100.0
	_ready_peers.clear()
	_stop_beacon()  # Lobby is closed once the round is live.
	_start_match.rpc(players, selected_map)


@rpc("authority", "call_local", "reliable")
func _start_match(data: Dictionary, map_id: String) -> void:
	players = data
	selected_map = map_id
	in_match = true
	match_started.emit()


## main.gd calls this once the level and HUD exist on this peer.
func notify_world_ready() -> void:
	_world_ready.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _world_ready() -> void:
	if not multiplayer.is_server():
		return
	_ready_peers[_sender()] = true
	# Bots have no device to report in, so only real peers are counted.
	if _ready_peers.size() < players.size() - bot_count():
		return
	var index := 0
	for id in players:
		_spawn.rpc(int(id), index)
		index += 1


@rpc("authority", "call_local", "reliable")
func _spawn(pid: int, spawn_index: int) -> void:
	if world and world.has_method("spawn_player"):
		world.spawn_player(pid, spawn_index)


@rpc("authority", "call_local", "reliable")
func _despawn(pid: int) -> void:
	if world and world.has_method("despawn_player"):
		world.despawn_player(pid)


# ---------------------------------------------------------------------------
# Combat (host authoritative)
# ---------------------------------------------------------------------------

## Called by a shooter on their own machine after their local raycast connects.
## "Trust the shooter" hit detection: whoever pulled the trigger decides what
## they hit, which is what makes shooting feel responsive online.
@rpc("any_peer", "call_local", "reliable")
func report_zap(victim_id: int, damage: float, distance: float, claimed_shooter := 0) -> void:
	if not multiplayer.is_server() or not in_match:
		return
	var sender := _sender()
	var shooter := sender
	# A peer may only ever shoot as itself. The one exception is the host
	# attributing a shot to a bot it is simulating on everyone's behalf.
	if claimed_shooter != 0 and sender == 1 and is_bot(claimed_shooter):
		shooter = claimed_shooter
	if shooter == victim_id:
		return
	if not players.has(victim_id) or not players.has(shooter):
		return
	if distance > MAX_ZAP_RANGE:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_hit_ms.get(shooter, -99999)) < MIN_ZAP_INTERVAL_MS:
		return
	_last_hit_ms[shooter] = now

	var victim: Dictionary = players[victim_id]
	if float(victim["health"]) <= 0.0:
		return
	victim["health"] = maxf(0.0, float(victim["health"]) - clampf(damage, 0.0, MAX_ZAP_DAMAGE))
	_apply_health.rpc(victim_id, float(victim["health"]), shooter)
	if float(victim["health"]) <= 0.0:
		_handle_death(victim_id, shooter)


@rpc("authority", "call_local", "reliable")
func _apply_health(pid: int, hp: float, attacker: int) -> void:
	if players.has(pid):
		players[pid]["health"] = hp
	var node = player_node(pid)
	if node:
		node.on_health_changed(hp, attacker)


func _handle_death(victim_id: int, killer_id: int) -> void:
	players[victim_id]["deaths"] = int(players[victim_id]["deaths"]) + 1
	players[killer_id]["kills"] = int(players[killer_id]["kills"]) + 1
	_died.rpc(victim_id, killer_id, players)

	if KILLS_TO_WIN > 0 and int(players[killer_id]["kills"]) >= KILLS_TO_WIN:
		in_match = false
		_finish.rpc(killer_id)
		return

	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if not in_match or not players.has(victim_id):
		return
	players[victim_id]["health"] = 100.0
	_respawn.rpc(victim_id, randi() % SPAWN_COUNT)


@rpc("authority", "call_local", "reliable")
func _died(victim_id: int, killer_id: int, data: Dictionary) -> void:
	players = data
	var node = player_node(victim_id)
	if node:
		node.on_died(killer_id)
	feed.emit("%s zapped %s" % [name_of(killer_id), name_of(victim_id)])
	lobby_changed.emit()


@rpc("authority", "call_local", "reliable")
func _respawn(pid: int, spawn_index: int) -> void:
	if players.has(pid):
		players[pid]["health"] = 100.0
	var node = player_node(pid)
	if node and world:
		node.on_respawn(world.spawn_point(spawn_index))


@rpc("authority", "call_local", "reliable")
func _finish(winner_id: int) -> void:
	in_match = false
	match_over.emit(winner_id)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func player_node(pid: int):
	if world == null:
		return null
	return world.get_player(pid)


func name_of(pid: int) -> String:
	if pid == my_id():
		return "You"
	return str(players.get(pid, {}).get("name", "Someone"))


## Name as it should appear when it's the subject of a sentence about you.
func display_name(pid: int) -> String:
	return str(players.get(pid, {}).get("name", "Someone"))


func sorted_scoreboard() -> Array:
	var rows := []
	for id in players:
		var r: Dictionary = players[id].duplicate()
		r["id"] = int(id)
		rows.append(r)
	rows.sort_custom(func(a, b): return int(a["kills"]) > int(b["kills"]))
	return rows


func _sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return 1 if s == 0 else s


func _blank_record(pname: String, case_index := 0, character_index := 0) -> Dictionary:
	return {"name": pname, "kills": 0, "deaths": 0, "health": 100.0,
		"case": case_index, "character": character_index}


func case_of(pid: int) -> int:
	return int(players.get(pid, {}).get("case", 0))


func character_of(pid: int) -> int:
	return int(players.get(pid, {}).get("character", 0))


## Your character is your name, so two people picking Jay would both be "Jay".
## The second one becomes "Jay 2".
func _unique_name(base: String) -> String:
	var taken := []
	for id in players:
		taken.append(str(players[id].get("name", "")))
	if not base in taken:
		return base
	for suffix in range(2, MAX_PLAYERS + 2):
		var candidate := "%s %d" % [base, suffix]
		if not candidate in taken:
			return candidate
	return base


static func _clean_name(pname: String) -> String:
	var n := pname.strip_edges()
	if n.is_empty():
		n = "Player"
	return n.substr(0, 14)
