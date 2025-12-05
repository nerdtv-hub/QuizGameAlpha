extends BaseQuiz

const QUESTIONS_PATH: String = "res://data/quiz1_questions.json"

@onready var question_label: Label = $VBox/QuestionLabel
@onready var status_label: Label = $VBox/StatusLabel
@onready var answers_container: GridContainer = $VBox/Answers

var _questions: Array[Dictionary] = []
var _current_question: Dictionary = {}
var _selected_index: int = -1
var _locked: bool = false
var _revealed: bool = false

func _ready() -> void:
	id = "quiz1"
	display_name = "Multiple Choice"
	can_be_first_round = true
	_questions = _load_questions()
	_connect_answer_buttons()

func start_quiz_round(new_game_state: GameStateData) -> void:
	self.game_state = new_game_state
	_current_question = _questions.pick_random() if not _questions.is_empty() else {}
	_selected_index = -1
	_locked = false
	_revealed = false
	_present_question()

func handle_host_input(action: String, _data: Dictionary) -> void:
	match action:
		"next":
			start_quiz_round(game_state)
		"lock":
			_locked = true
			status_label.text = "Antwort fixiert"
		"reveal":
			_revealed = true
			_locked = true
			_show_correct_answer()
		"timer_finished":
			if not _locked:
				_locked = true
				status_label.text = "Zeit abgelaufen"

func handle_player_input(_player_id: int, data: Dictionary) -> void:
	pass

func is_round_finished() -> bool:
	return _revealed

func get_results() -> Dictionary:
	if _revealed and _selected_index == _current_question.get("correct_index", -1):
		var player: GameStateData.PlayerData = game_state.get_active_player()
		if player:
			return {player.player_id: 100}
	return {}

func _connect_answer_buttons() -> void:
	for index in range(4):
		var button: Button = answers_container.get_child(index)
		button.pressed.connect(_on_answer_pressed.bind(index))

func _present_question() -> void:
	if _current_question.is_empty():
		question_label.text = "Keine Fragen"
		return
	question_label.text = _current_question.get("text", "")
	status_label.text = "Wähle eine Antwort"
	var answers: Array = _current_question.get("answers", [])
	for i in range(4):
		var button: Button = answers_container.get_child(i)
		button.text = answers[i] if i < answers.size() else "--"
		button.modulate = Color(0.2, 0.4, 0.8)

func _on_answer_pressed(index: int) -> void:
	if _locked:
		return
	_selected_index = index
	_update_answer_colors()

func _update_answer_colors() -> void:
	for i in range(4):
		var button: Button = answers_container.get_child(i)
		if i == _selected_index:
			button.modulate = Color(1.0, 0.9, 0.2)
		else:
			button.modulate = Color(0.2, 0.4, 0.8)

func _show_correct_answer() -> void:
	var correct_index: int = _current_question.get("correct_index", -1)
	for i in range(4):
		var button: Button = answers_container.get_child(i)
		if i == correct_index:
			button.modulate = Color(0.2, 0.8, 0.2)
		elif i == _selected_index:
			button.modulate = Color(0.4, 0.0, 0.0)
		else:
			button.modulate = Color(0.2, 0.4, 0.8)

func _load_questions() -> Array[Dictionary]:
	if not FileAccess.file_exists(QUESTIONS_PATH):
		push_warning("Quiz1 questions missing")
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
