extends Node

signal player_joined(peer_id: int, player_id: int, player_name: String)
signal player_left(peer_id: int, player_id: int)
signal host_disconnected()

const DEFAULT_PORT: int = 24500
const MAX_CLIENTS: int = 4

var _multiplayer_peer: ENetMultiplayerPeer
var _player_id_map: Dictionary = {}
var _peer_to_player: Dictionary = {}
var _next_player_id: int = 1
var _is_host: bool = false
var _password: String = ""
var _pending_player_name: String = "" # Name, den der Client beim Verbinden senden möchte
var _local_player_name: String = "" # Letzter lokal ausgewählter Name

# Namensdatenfluss (zentralisiert hier):
# - MainMenu setzt _local_player_name/_pending_player_name, bevor eine Verbindung aufgebaut wird.
# - Clients senden ihren Namen nach connected_to_server per rpc_update_player_name an den Host.
# - Host speichert peer_id -> name und verteilt rpc_sync_player an alle Peers.
# - _register_player überschreibt lokale Spieler nicht mehr mit Platzhaltern, wenn bereits ein Name vorliegt.

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_host_disconnected)

func is_host() -> bool:
	return _is_host

func get_local_player_id() -> int:
	return multiplayer.get_unique_id()

func host_game(password: String, host_name: String = "Host") -> void:
        var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
        var err: Error = peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
        if err != OK:
                push_error("Failed to host server: %s" % err)
                return
        _is_host = true
        _password = password
        _local_player_name = host_name
        _multiplayer_peer = peer
        multiplayer.multiplayer_peer = peer
        # Host trägt sich selbst mit dem ausgewählten Namen ein
        _register_player(multiplayer.get_unique_id(), host_name)

func join_game(ip: String, password: String, player_name: String) -> void:
        var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
        var err: Error = peer.create_client(ip, DEFAULT_PORT)
        if err != OK:
                push_error("Failed to join server: %s" % err)
                return
        _is_host = false
        _password = password
        _pending_player_name = player_name
        _local_player_name = player_name
        _multiplayer_peer = peer
        multiplayer.multiplayer_peer = peer

func close_disconnect() -> void:
        if multiplayer.multiplayer_peer:
                multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null
        _multiplayer_peer = null
        _player_id_map.clear()
        _peer_to_player.clear()
        _next_player_id = 1
        _is_host = false
        _pending_player_name = ""
        _local_player_name = ""

func _register_player(peer_id: int, player_name: String, forced_player_id: int = -1) -> void:
	# Lokale Spieler behalten ihren eingegebenen Namen, auch wenn der Host zunächst Platzhalter schickt
	if peer_id == multiplayer.get_unique_id() and _local_player_name != "":
		player_name = _local_player_name
	# Wenn es den Peer schon gibt, nur den Namen aktualisieren und Signal feuern
	if _player_id_map.has(peer_id):
		_player_id_map[peer_id]["name"] = player_name
		var existing_id: int = _player_id_map[peer_id].get("player_id", peer_id)
		# GameState immer hier synchronisieren, damit alle Szenen denselben Namen sehen
		GameState.add_player(peer_id, player_name)
		player_joined.emit(peer_id, existing_id, player_name)
		return

	var player_id: int = forced_player_id if forced_player_id > 0 else _next_player_id
	_next_player_id = max(_next_player_id, player_id + 1)
	_player_id_map[peer_id] = {"name": player_name, "player_id": player_id}
	_peer_to_player[peer_id] = player_id
	# GameState immer hier synchronisieren, damit alle Szenen denselben Namen sehen
	GameState.add_player(peer_id, player_name)
	player_joined.emit(peer_id, player_id, player_name)

func _remove_player(peer_id: int) -> void:
	if not _player_id_map.has(peer_id):
		return
	var player_id: int = _player_id_map[peer_id].get("player_id", peer_id)
	_player_id_map.erase(peer_id)
	_peer_to_player.erase(peer_id)
	# Halte GameState-Status in allen Szenen konsistent
	GameState.remove_player(player_id)
	player_left.emit(peer_id, player_id)

func get_player_id(peer_id: int) -> int:
	return _peer_to_player.get(peer_id, peer_id)

func get_player_name(peer_id: int) -> String:
	var info: Dictionary = _player_id_map.get(peer_id, {})
	return info.get("name", "Spieler %d" % peer_id)

func _on_peer_connected(peer_id: int) -> void:
	if _is_host:
		_register_player(peer_id, "Spieler %d" % peer_id)
		for existing_peer in _player_id_map.keys():
			var info: Dictionary = _player_id_map[existing_peer]
			rpc_id(peer_id, "rpc_sync_player", existing_peer, info.get("player_id", existing_peer), info.get("name", "Spieler"))
		for target_peer in multiplayer.get_peers():
			rpc_id(target_peer, "rpc_sync_player", peer_id, _peer_to_player[peer_id], _player_id_map[peer_id].get("name", "Spieler"))

func _on_peer_disconnected(peer_id: int) -> void:
	_remove_player(peer_id)

func _on_host_disconnected() -> void:
	host_disconnected.emit()
	close_disconnect()

func _on_connection_failed() -> void:
	host_disconnected.emit()
	close_disconnect()
	
@rpc("any_peer", "call_local")
func rpc_sync_player(peer_id: int, player_id: int, player_name: String) -> void:
	_register_player(peer_id, player_name, player_id)
	
@rpc("any_peer")
func rpc_update_player_name(player_name: String) -> void:
	if not _is_host:
		return

	var peer_id: int = multiplayer.get_remote_sender_id()

	# Falls der Peer noch nicht registriert ist, jetzt registrieren
	if not _player_id_map.has(peer_id):
		_register_player(peer_id, player_name)
	else:
		_player_id_map[peer_id]["name"] = player_name
		var player_id: int = _player_id_map[peer_id].get("player_id", peer_id)
		# An alle Peers die aktualisierten Daten schicken
		for target_peer in multiplayer.get_peers():
			rpc_id(target_peer, "rpc_sync_player", peer_id, player_id, player_name)

	# Hostseitig GameState aktualisieren
	GameState.add_player(peer_id, player_name)
