extends BaseQuiz

const QUESTIONS_PATH: String = "res://data/quiz2_questions.json"

@onready var question_label: Label = $VBox/QuestionLabel
@onready var status_label: Label = $VBox/StatusLabel

var _questions: Array[Dictionary] = []
var _current_question: Dictionary = {}
var _answers: Dictionary = {}
var _result_points: Dictionary = {}

func _ready() -> void:
	id = "quiz2"
	display_name = "Schätzfragen"
	can_be_first_round = true
	_questions = _load_questions()

func start_quiz_round(new_game_state: GameStateData) -> void:
	self.game_state = new_game_state
	_current_question = _questions.pick_random() if not _questions.is_empty() else {}
	_answers.clear()
	_result_points.clear()
	question_label.text = _current_question.get("text", "Keine Frage")
	status_label.text = "Alle Spieler geben ihre Zahl ein."

func handle_host_input(action: String, _data: Dictionary) -> void:
	if action == "lock":
		_evaluate_answers()
		status_label.text = "Auswertung abgeschlossen"

func handle_player_input(player_id: int, data: Dictionary) -> void:
	if data.has("value"):
		_answers[player_id] = float(data["value"])

func is_round_finished() -> bool:
	return not _result_points.is_empty()

func get_results() -> Dictionary:
	return _result_points

func _evaluate_answers() -> void:
	var solution: float = float(_current_question.get("solution_number", 0))
	var best_distance: float = INF
	var winners: Array[int] = []
	for player_id in _answers.keys():
		var distance: float = abs(_answers[player_id] - solution)
		if distance < best_distance:
			best_distance = distance
			winners = [player_id]
		elif distance == best_distance:
			winners.append(player_id)
	_result_points.clear()
	for player_id in winners:
		var exact: bool = _answers[player_id] == solution
		_result_points[player_id] = 300 if exact else 100
	status_label.text = "Lösung: %s" % solution

func _load_questions() -> Array[Dictionary]:
	if not FileAccess.file_exists(QUESTIONS_PATH):
		return []
	var file: FileAccess = FileAccess.open(QUESTIONS_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		var typed_array: Array[Dictionary] = []
		for entry in parsed:
			if entry is Dictionary:
				typed_array.append(entry)
		return typed_array
	return []
