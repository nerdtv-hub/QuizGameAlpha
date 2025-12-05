extends Control

const PLAYER_SLOT_SCENE: PackedScene = preload("res://components/PlayerSlot.tscn")

@onready var host_area: ColorRect = $Background/HostArea
@onready var host_question_label: Label = $Background/HostArea/HostVBox/HostQuestion
@onready var next_button: Button = $Background/HostArea/HostVBox/HostButtons/NextButton
@onready var lock_button: Button = $Background/HostArea/HostVBox/HostButtons/LockButton
@onready var reveal_button: Button = $Background/HostArea/HostVBox/HostButtons/RevealButton
@onready var timer_spin: SpinBox = $Background/HostArea/HostVBox/TimerHBox/TimerInput
@onready var timer_button: Button = $Background/HostArea/HostVBox/TimerHBox/TimerButton
@onready var joker_box: VBoxContainer = $Background/HostArea/HostVBox/JokerHBox
@onready var quiz_title: Label = $Background/QuizArea/QuizTitle
@onready var quiz_container: Control = $Background/QuizArea/QuizContainer
@onready var overlay_label: Label = $Background/QuizArea/OverlayLabel
@onready var timer_label: Label = $Background/QuizArea/TimerLabel
@onready var player_slots_container: HBoxContainer = $Background/PlayerSlots
@onready var round_timer: Timer = $RoundTimer

var _current_quiz: BaseQuiz
var _player_slots: Dictionary = {}
var _timer_remaining: int = 0

func _ready() -> void:
	host_area.visible = NetworkManager.is_host()
	next_button.pressed.connect(_on_next_pressed)
	lock_button.pressed.connect(_on_lock_pressed)
	reveal_button.pressed.connect(_on_reveal_pressed)
	timer_button.pressed.connect(_on_timer_start)
	round_timer.timeout.connect(_on_round_timer_timeout)
	GameState.state_updated.connect(_refresh_players)
	GameState.round_changed.connect(_on_round_changed)
	GameState.player_active.connect(_on_player_active)
	_build_player_slots()
	_refresh_players()
	if NetworkManager.is_host() and GameState.current_round_index < 0:
		GameState.advance_round()

func _build_player_slots() -> void:
	for child in player_slots_container.get_children():
		child.queue_free()
	_player_slots.clear()
	for player in GameState.players:
		var player_slot: PlayerSlot = PLAYER_SLOT_SCENE.instantiate()
		player_slots_container.add_child(player_slot)
		player_slot.set_player(player)
		_player_slots[player.player_id] = player_slot

func _refresh_players() -> void:
	for player in GameState.players:
		if not _player_slots.has(player.player_id):
			var new_slot: PlayerSlot = PLAYER_SLOT_SCENE.instantiate()
			player_slots_container.add_child(new_slot)
			_player_slots[player.player_id] = new_slot
		var player_slot: PlayerSlot = _player_slots[player.player_id]
		player_slot.set_player(player)

func _on_round_changed(round_index: int, quiz_id: String) -> void:
	var meta: QuizRegistry.QuizMeta = QuizRegistry.get_quiz_meta(quiz_id)
	quiz_title.text = "Frage (%s)" % (meta.display_name if meta else quiz_id)
	overlay_label.text = "Runde %d / %d - Quiz: %s" % [round_index + 1, GameState.max_rounds, meta.display_name if meta else quiz_id]
	if GameState.double_points_round == round_index:
		overlay_label.text += "\nDiese Runde: Doppelte Punkte!"
	_load_quiz_scene(quiz_id)

func _load_quiz_scene(quiz_id: String) -> void:
	if _current_quiz:
		_current_quiz.queue_free()
	var scene_path: String = QuizRegistry.get_scene_path(quiz_id)
	if scene_path == "":
		push_error("Missing scene for quiz %s" % quiz_id)
		return
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("Failed to load quiz scene: %s" % scene_path)
		return
	_current_quiz = packed.instantiate()
	quiz_container.add_child(_current_quiz)
	_current_quiz.start_quiz_round(GameState)

func _on_player_active(player_id: int) -> void:
	for slot in _player_slots.values():
		var player_slot: PlayerSlot = slot
		var active: bool = player_slot.peer_id == player_id or player_slot.player_id == player_id
		player_slot.set_active(active)

func _on_next_pressed() -> void:
	if _current_quiz:
		if _current_quiz.is_round_finished() and NetworkManager.is_host():
			_apply_results()
			GameState.advance_round()
		else:
			_current_quiz.handle_host_input("next", {})

func _on_lock_pressed() -> void:
	if _current_quiz:
		_current_quiz.handle_host_input("lock", {})

func _on_reveal_pressed() -> void:
	if _current_quiz:
		_current_quiz.handle_host_input("reveal", {})

func _on_timer_start() -> void:
	_timer_remaining = int(timer_spin.value)
	timer_label.text = "Timer: %ds" % _timer_remaining
	round_timer.start()

func _on_round_timer_timeout() -> void:
	if _timer_remaining <= 0:
		round_timer.stop()
		timer_label.text = "Timer: --"
		if _current_quiz:
			_current_quiz.handle_host_input("timer_finished", {})
		return
	_timer_remaining -= 1
	timer_label.text = "Timer: %ds" % max(_timer_remaining, 0)
	if _current_quiz:
		_current_quiz.handle_host_input("timer_tick", {"seconds": _timer_remaining})

func _apply_results() -> void:
	if not _current_quiz:
		return
	var results: Dictionary = _current_quiz.get_results()
	var round_multiplier: int = 2 if GameState.double_points_round == GameState.current_round_index else 1
	for player_id in results.keys():
		var delta: int = int(results[player_id]) * round_multiplier
		var player: GameStateData.PlayerData = GameState.get_player_by_id(player_id)
		if player and player.pending_double_or_nothing:
			delta *= 2
			GameState.consume_double_or_nothing(player_id, delta > 0)
		GameState.award_points(player_id, delta)
