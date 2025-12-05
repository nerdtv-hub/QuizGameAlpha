extends Node

class QuizMeta extends RefCounted:
	var id: String
	var display_name: String
	var can_be_first_round: bool = true
	var supports_public_joker: bool = true
	var supports_double_or_nothing: bool = true
	var scene_path: String

	func _init(p_id: String, p_display_name: String, p_scene_path: String, p_can_be_first_round: bool = true, p_supports_public_joker: bool = true, p_supports_double_or_nothing: bool = true) -> void:
		id = p_id
		display_name = p_display_name
		scene_path = p_scene_path
		can_be_first_round = p_can_be_first_round
		supports_public_joker = p_supports_public_joker
		supports_double_or_nothing = p_supports_double_or_nothing

var _registry: Dictionary[String, QuizMeta] = {}
var _active_modes: Array[String] = []

func _ready() -> void:
	register_default_quizzes()

func register_default_quizzes() -> void:
	register_quiz("quiz1", "Multiple Choice", "res://scenes/Quiz1_MultipleChoice.tscn")
	register_quiz("quiz2", "Schätzfragen", "res://scenes/Quiz2_Estimation.tscn")
	register_quiz("quiz3", "Kategorien", "res://scenes/Quiz3_Categories.tscn", false)

func register_quiz(p_id: String, quiz_name: String, p_scene_path: String, can_be_first_round: bool = true, supports_public_joker: bool = true, supports_double_or_nothing: bool = true) -> void:
	var meta: QuizMeta = QuizMeta.new(p_id, quiz_name, p_scene_path, can_be_first_round, supports_public_joker, supports_double_or_nothing)
	_registry[p_id] = meta

func set_active_modes(modes: Array[String]) -> void:
	_active_modes = modes.duplicate()

func get_active_modes() -> Array[String]:
	return _active_modes.duplicate()

func get_quiz_meta(id: String) -> QuizMeta:
	return _registry.get(id, null)

func generate_quiz_order(modes: Array[String]) -> Array[String]:
	var shuffled: Array[String] = modes.duplicate()
	shuffled.shuffle()
	if shuffled.is_empty():
		return []
	var first_mode: String = shuffled[0]
	if not _registry[first_mode].can_be_first_round:
		for i in range(shuffled.size()):
			if _registry[shuffled[i]].can_be_first_round:
				var temp: String = shuffled[0]
				shuffled[0] = shuffled[i]
				shuffled[i] = temp
				break
	return shuffled

func get_scene_path(id: String) -> String:
	var meta: QuizMeta = _registry.get(id, null)
	return meta.scene_path if meta else ""
