extends Control
class_name BaseQuiz

## Abstract base class for quiz mode scenes.

var id: String = ""
var display_name: String = ""
var can_be_first_round: bool = true
var game_state: GameStateData

func start_quiz_round(new_game_state: GameStateData) -> void:
	"""Called when the quiz should start its round logic."""
	self.game_state = new_game_state

func handle_host_input(_action: String, _data: Dictionary) -> void:
	"""Allows the host control panel to forward events to the quiz."""
	pass

func handle_player_input(_player_id: int, _data: Dictionary) -> void:
	"""Called for player-originated events (buttons, inputs)."""
	pass

func is_round_finished() -> bool:
	return false

func get_results() -> Dictionary:
	return {}
