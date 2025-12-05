extends BaseQuiz

const QUESTIONS_PATH: String = "res://data/quiz3_questions.json"
const VALUES: Array[int] = [100, 200, 300, 400, 500]

@onready var board: GridContainer = $VBox/Board
@onready var question_label: Label = $VBox/QuestionLabel
@onready var status_label: Label = $VBox/StatusLabel

var _questions_by_category: Dictionary = {}
var _selected_category: String = ""
var _selected_value: int = 0
var _current_question: Dictionary = {}

func _ready() -> void:
	id = "quiz3"
	display_name = "Kategorien"
	can_be_first_round = false
	_build_board()
	_load_questions()

func start_quiz_round(new_game_state: GameStateData) -> void:
	self.game_state = new_game_state
	status_label.text = "Kategorie auswählen"

func handle_host_input(action: String, _data: Dictionary) -> void:
	if action == "next" and not _current_question.is_empty():
		_current_question = {}
		status_label.text = "Nächster Spieler wählt eine Kategorie"

func handle_player_input(player_id: int, _data: Dictionary) -> void:
	pass

func is_round_finished() -> bool:
	return false

func get_results() -> Dictionary:
	return {}

func _build_board() -> void:
	for child in board.get_children():
		child.queue_free()
	for value in VALUES:
		var button: Button = Button.new()
		button.text = "%d" % value
		button.pressed.connect(_on_category_pressed.bind(value))
		board.add_child(button)

func _load_questions() -> void:
	if not FileAccess.file_exists(QUESTIONS_PATH):
		return
	var file: FileAccess = FileAccess.open(QUESTIONS_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return
	for entry in parsed:
		var category: String = entry.get("category", "Allgemein")
		if not _questions_by_category.has(category):
			_questions_by_category[category] = {}
		_questions_by_category[category][entry.get("value", 100)] = entry

func _on_category_pressed(value: int) -> void:
	_selected_value = value
	question_label.text = "Frage Wert %d" % value
	status_label.text = "Frage anzeigen"
