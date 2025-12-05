extends Control

@onready var player_list: VBoxContainer = $Panel/HBox/PlayerList
@onready var rounds_spinner: SpinBox = $Panel/HBox/Settings/Rounds
@onready var modes_container: VBoxContainer = $Panel/HBox/Settings/QuizModes
@onready var start_button: Button = $Panel/HBox/Settings/StartButton
@onready var status_label: Label = $Panel/HBox/Settings/Status

var mode_checkboxes: Dictionary[String, CheckBox]= {}

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	_build_mode_list()
	_refresh_player_list()

func _build_mode_list() -> void:
	for child in modes_container.get_children():
		child.queue_free()
	mode_checkboxes.clear()
	for mode_id in ["quiz1", "quiz2", "quiz3"]:
		var meta: QuizRegistry.QuizMeta = QuizRegistry.get_quiz_meta(mode_id)
		if meta == null:
			continue
		var checkbox: CheckBox = CheckBox.new()
		checkbox.text = meta.display_name
		checkbox.button_pressed = true
		modes_container.add_child(checkbox)
		mode_checkboxes[mode_id] = checkbox

func _refresh_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()
	for player in GameState.players:
		var label: Label = Label.new()
		var status: String = "verbunden" if player.is_connected else "getrennt"
		label.text = "%s (%s)" % [player.name, status]
		player_list.add_child(label)

func _on_player_joined(_peer_id: int, player_id: int, player_name: String) -> void:
	GameState.add_player(_peer_id, player_name)
	_refresh_player_list()

func _on_player_left(_peer_id: int, player_id: int) -> void:
	GameState.remove_player(player_id)
	_refresh_player_list()

func _on_start_pressed() -> void:
	if not NetworkManager.is_host():
		status_label.text = "Nur der Host kann starten."
		return
	var selected: Array[String] = []
	for mode_id in mode_checkboxes.keys():
		var checkbox: CheckBox = mode_checkboxes[mode_id]
		if checkbox.button_pressed:
			selected.append(mode_id)
	if selected.is_empty():
		status_label.text = "Mindestens ein Quizmodus muss aktiv sein."
		return
	var rounds: int = int(rounds_spinner.value)
	rounds = min(rounds, selected.size())
	if rounds <= 0:
		status_label.text = "Rundenanzahl ungültig."
		return
	GameState.set_lobby_settings(rounds, selected)
	QuizRegistry.set_active_modes(selected)
	GameState.initialize_game(rounds, selected)
	rpc("rpc_begin_game", rounds, selected, GameState.quiz_order, GameState.double_points_round)

@rpc("authority", "call_local")
func rpc_begin_game(rounds: int, modes: Array[String], order: Array[String], double_round: int) -> void:
	QuizRegistry.set_active_modes(modes)
	GameState.set_lobby_settings(rounds, modes)
	GameState.apply_remote_game(rounds, modes, order, double_round)
	get_tree().change_scene_to_file("res://scenes/GameScreen.tscn")
