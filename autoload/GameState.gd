extends Node
class_name GameStateData

const SAVE_PATH: String = "user://quiz_save.json"

signal state_updated()
signal game_started()
signal round_changed(round_index: int, quiz_id: String)
signal player_active(player_id: int)

class PlayerData:
	var peer_id: int
	var player_id: int
	var persistent_id: String
	var name: String
	var score: int = 0
	var is_connected_true: bool = true
	var has_public_joker_quiz1: bool = true
	var has_public_joker_quiz3: bool = true
	var has_double_or_nothing: bool = true
	var pending_double_or_nothing: bool = false

	func _init(p_peer_id: int, p_persistent_id: String, p_name: String, p_player_id: int) -> void:
		peer_id = p_peer_id
		player_id = p_player_id
		persistent_id = p_persistent_id
		name = p_name

var players: Array[PlayerData] = []
var max_rounds: int = 0
var active_quiz_modes: Array[String] = []
var quiz_order: Array[String] = []
var double_points_round: int = -1
var current_round_index: int = -1
var current_quiz_id: String = ""
var current_player_turn: int = 0
var save_enabled: bool = true

var quiz_progress: Dictionary = {}
var lobby_settings: Dictionary = {
	"selected_modes": [] as Array[String],
	"rounds": 0
}

func _ready() -> void:
	randomize()

func reset_state() -> void:
	players.clear()
	max_rounds = 0
	active_quiz_modes.clear()
	quiz_order.clear()
	double_points_round = -1
	current_round_index = -1
	current_quiz_id = ""
	current_player_turn = 0
	quiz_progress.clear()
	lobby_settings = {"selected_modes": [] as Array[String], "rounds": 0}
	state_updated.emit()

func add_player(peer_id: int, player_name: String) -> void:
	for existing in players:
		if existing.peer_id == peer_id:
			existing.name = player_name
			state_updated.emit()
			return
	var assigned_id: int = NetworkManager.get_player_id(peer_id)
	var persistent_id: String = "pid_%d" % assigned_id
	var player: PlayerData = PlayerData.new(peer_id, persistent_id, player_name, assigned_id)
	players.append(player)
	state_updated.emit()

func remove_player(player_id: int) -> void:
	for player in players:
		if player.player_id == player_id or player.peer_id == player_id:
			player.is_connected_true = false
			state_updated.emit()
			return

func reconnect_player(peer_id: int, persistent_id: String) -> void:
	for player in players:
		if player.persistent_id == persistent_id:
			player.peer_id = peer_id
			player.is_connected_true = true
			state_updated.emit()
			return

func set_lobby_settings(rounds: int, modes: Array[String]) -> void:
	lobby_settings["selected_modes"] = modes
	lobby_settings["rounds"] = rounds
	state_updated.emit()

func initialize_game(rounds: int, modes: Array[String]) -> void:
	max_rounds = rounds
	active_quiz_modes = modes.duplicate()
	quiz_order = QuizRegistry.generate_quiz_order(modes)
	if quiz_order.size() > rounds:
		quiz_order = quiz_order.slice(0, rounds)
	double_points_round = randi_range(0, max_rounds - 1) if max_rounds > 0 else -1
	current_round_index = -1
	quiz_progress.clear()
	game_started.emit()
	_save_state()
	
func apply_remote_game(rounds: int, modes: Array[String], order: Array[String], double_round: int) -> void:
	max_rounds = rounds
	active_quiz_modes = modes.duplicate()
	quiz_order = order.duplicate()
	double_points_round = double_round
	current_round_index = -1
	current_quiz_id = ""
	current_player_turn = 0
	quiz_progress.clear()
	game_started.emit()
	_save_state()

func advance_round() -> void:
	if quiz_order.is_empty():
		return
	current_round_index += 1
	if current_round_index >= quiz_order.size():
		current_round_index = quiz_order.size() - 1
	current_quiz_id = quiz_order[current_round_index]
	if players.is_empty():
		return
	current_player_turn = current_round_index % max(players.size(), 1)
	round_changed.emit(current_round_index, current_quiz_id)
	player_active.emit(players[current_player_turn].peer_id)
	_save_state()

func get_active_player() -> PlayerData:
	if players.is_empty():
		return null
	return players[current_player_turn]

func get_player_by_id(player_id: int) -> PlayerData:
	for player in players:
		if player.player_id == player_id:
			return player
	return null

func award_points(player_id: int, points: int) -> void:
	for player in players:
		if player.player_id == player_id or player.peer_id == player_id:
			player.score += points
			break
	_save_state()
	state_updated.emit()

func toggle_double_or_nothing(player_id: int, enabled: bool) -> void:
	for player in players:
		if player.player_id == player_id and player.has_double_or_nothing:
			player.pending_double_or_nothing = enabled
			state_updated.emit()
			return

func consume_double_or_nothing(player_id: int, success: bool) -> void:
	for player in players:
		if player.player_id == player_id and player.pending_double_or_nothing:
			player.pending_double_or_nothing = false
			player.has_double_or_nothing = false
			if not success:
				pass
			state_updated.emit()
			return

func mark_public_joker(player_id: int, quiz_id: String) -> void:
	for player in players:
		if player.player_id == player_id:
			if quiz_id == "quiz1":
				player.has_public_joker_quiz1 = false
			elif quiz_id == "quiz3":
				player.has_public_joker_quiz3 = false
			state_updated.emit()
			return

func _save_state() -> void:
	if not save_enabled:
		return
	var data: Dictionary = {
		"players": []
	}
	for player in players:
		data["players"].append({
			"peer_id": player.peer_id,
			"player_id": player.player_id,
			"persistent_id": player.persistent_id,
			"name": player.name,
			"score": player.score,
			"connected": player.is_connected,
			"joker_q1": player.has_public_joker_quiz1,
			"joker_q3": player.has_public_joker_quiz3,
			"don_available": player.has_double_or_nothing,
			"don_pending": player.pending_double_or_nothing
		})
	data["rounds"] = max_rounds
	data["quiz_order"] = quiz_order
	data["double_round"] = double_points_round
	data["current_round"] = current_round_index
	data["current_quiz"] = current_quiz_id
	data["lobby"] = lobby_settings

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))

func load_state() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	reset_state()
	var player_array: Array = parsed.get("players", [])
	for entry in player_array:
		var player: PlayerData = PlayerData.new(entry.get("peer_id", 0), entry.get("persistent_id", ""), entry.get("name", "Player"), entry.get("player_id", entry.get("peer_id", 0)))
		player.score = entry.get("score", 0)
		player.is_connected_true = entry.get("connected", false)
		player.has_public_joker_quiz1 = entry.get("joker_q1", true)
		player.has_public_joker_quiz3 = entry.get("joker_q3", true)
		player.has_double_or_nothing = entry.get("don_available", true)
		player.pending_double_or_nothing = entry.get("don_pending", false)
		players.append(player)
	max_rounds = parsed.get("rounds", 0)
	quiz_order = parsed.get("quiz_order", [])
	double_points_round = parsed.get("double_round", -1)
	current_round_index = parsed.get("current_round", -1)
	current_quiz_id = parsed.get("current_quiz", "")
	lobby_settings = parsed.get("lobby", lobby_settings)
	state_updated.emit()
	return true
