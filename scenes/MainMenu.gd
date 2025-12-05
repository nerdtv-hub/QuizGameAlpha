extends Control

@onready var host_password_field: LineEdit = $Panel/VBox/HostPassword
@onready var host_button: Button = $Panel/VBox/HostButton
@onready var join_ip_field: LineEdit = $Panel/VBox/JoinIP
@onready var join_password_field: LineEdit = $Panel/VBox/JoinPassword
@onready var join_name_field: LineEdit = $Panel/VBox/JoinName
@onready var join_button: Button = $Panel/VBox/JoinButton
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var resume_button: Button = $Panel/VBox/ResumeButton

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.host_disconnected.connect(_on_host_disconnect)

func _on_host_pressed() -> void:
	NetworkManager.host_game(host_password_field.text)
	status_label.text = "Status: Hosting..."
	GameState.add_player(NetworkManager.get_local_player_id(), "Host")
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_join_pressed() -> void:
	var player_name: String = join_name_field.text
	NetworkManager.join_game(join_ip_field.text, join_password_field.text)
	status_label.text = "Status: Verbinden..."
	multiplayer.connected_to_server.connect(
		Callable(self, "_on_connected_to_server").bind(player_name),
		CONNECT_ONE_SHOT
	)
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
	
func _on_connected_to_server(player_name: String) -> void:
	NetworkManager.rpc_update_player_name(player_name)

func _on_player_joined(peer_id: int, player_id: int, player_name: String) -> void:
	status_label.text = "Status: Spieler %d verbunden" % player_id

func _on_host_disconnect() -> void:
	status_label.text = "Status: Verbindung verloren"

func _on_resume_pressed() -> void:
	if GameState.load_state():
		status_label.text = "Status: Spielstand geladen"
		get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
	else:
		status_label.text = "Status: Kein Spielstand"
