extends VBoxContainer
class_name PlayerSlot

@onready var name_label: Label = $NameLabel
@onready var score_label: Label = $ScoreLabel
@onready var joker_label: Label = $JokerLabel
@onready var input_field: LineEdit = $InputField
@onready var camera_rect: ColorRect = $CameraRect

var player_id: int = -1
var peer_id: int = -1
var is_active: bool = false

func set_player(player: GameStateData.PlayerData) -> void:
	player_id = player.player_id
	peer_id = player.peer_id
	name_label.text = player.name
	score_label.text = "Punkte: %d" % player.score
	var joker_text: String = "Publikumsjoker Q1: %s | Q3: %s" % ["verfügbar" if player.has_public_joker_quiz1 else "benutzt", "verfügbar" if player.has_public_joker_quiz3 else "benutzt"]
	joker_text += "\nDouble or Nothing: %s" % ("verfügbar" if player.has_double_or_nothing else "benutzt")
	joker_label.text = joker_text
	
func set_active(active: bool) -> void:
	is_active = active
	camera_rect.modulate = Color(1, 1, 1) if active else Color(0.2, 0.2, 0.2)

func get_input_value() -> String:
	return input_field.text

func clear_input() -> void:
	input_field.text = ""
