## GameManager.gd
## 游戏管理器 - 协调各系统（简化版，用于原型验证）

extends Node2D

## 信号
signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal destruction_changed(percent: float)
signal game_over(victory: bool)
signal judgment_displayed(judgment: String)

## 引用（不使用类型注解）
var rhythm_engine
var machine
var building_container
var ui

## 游戏配置
@export var start_bpm: float = 120.0
@export var buildings_to_destroy: int = 5
@export var game_duration: float = 60.0  # 0 = 无限制

## 游戏状态
enum GameState { READY, PLAYING, PAUSED, GAME_OVER, VICTORY }
var current_state: GameState = GameState.READY

var score: int = 0
var combo: int = 0
var destruction_percent: float = 0.0
var total_building_hp: float = 0.0
var destroyed_building_hp: float = 0.0

## 计时
var game_timer: float = 0.0

## 输入映射
var input_to_action: Dictionary = {
	"beat_up": "up",
	"beat_down": "down", 
	"beat_left": "left",
	"beat_right": "right"
}

func _ready() -> void:
	# 获取节点引用
	rhythm_engine = $RhythmEngine
	machine = $Machine
	building_container = $Buildings
	ui = $UI
	
	_setup_signals()
	_create_buildings()
	_update_ui()
	
	# 显示开始提示
	$UI/StartHint.visible = true

func _setup_signals() -> void:
	# 连接节奏引擎信号
	rhythm_engine.beat_triggered.connect(_on_beat)
	rhythm_engine.beat_window_opened.connect(_on_beat_window)
	rhythm_engine.input_judged.connect(_on_input_judged)
	rhythm_engine.miss_triggered.connect(_on_miss)
	rhythm_engine.combo_changed.connect(_on_combo_changed)

func _process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return
	
	# 计时器
	game_timer += delta
	if game_duration > 0 and game_timer >= game_duration:
		_check_victory()

func _input(event: InputEvent) -> void:
	# 开始游戏
	if event.is_action_pressed("ui_accept") and current_state == GameState.READY:
		start_game()
		$UI/StartHint.visible = false
		return
	
	if event.is_action_pressed("ui_cancel"):
		if current_state == GameState.PLAYING:
			pause_game()
		elif current_state == GameState.PAUSED:
			resume_game()
		return
	
	if current_state != GameState.PLAYING:
		return
	
	# 检查节奏输入
	for input_name in input_to_action.keys():
		if event.is_action_pressed(input_name):
			_handle_rhythm_input(input_name)

func _handle_rhythm_input(input_name: String) -> void:
	var action = input_to_action[input_name]
	var result = rhythm_engine.check_input(action)
	
	# 显示判定结果
	_show_judgment(result.judgment)
	
	if result.success:
		machine.execute_action(action)
	else:
		if result.judgment == "miss":
			machine.trigger_stun()

func _on_beat(beat_num: int) -> void:
	# 节拍触发 - 屏幕边缘闪一下
	var beat_rect = $UI/BeatIndicator/BeatRect
	var tween = create_tween()
	tween.tween_property(beat_rect, "modulate:a", 0.8, 0.05)
	tween.tween_property(beat_rect, "modulate:a", 0.3, 0.1)

func _on_beat_window(expected: String) -> void:
	# 显示预期的输入
	var expected_labels = {
		"up": "↑",
		"down": "↓",
		"left": "←",
		"right": "→"
	}
	if ui.has_node("Panel/ExpectedLabel"):
		ui.get_node("Panel/ExpectedLabel").text = "Next: " + expected_labels.get(expected, "?")
		# 动画
		var tween = create_tween()
		tween.tween_property(ui.get_node("Panel/ExpectedLabel"), "scale", Vector2(1.3, 1.3), 0.1)
		tween.tween_property(ui.get_node("Panel/ExpectedLabel"), "scale", Vector2(1.0, 1.0), 0.15)

func _on_input_judged(judgment: String, timing_ms: float) -> void:
	emit_signal("judgment_displayed", judgment)

func _on_miss() -> void:
	machine.trigger_stun()

func _on_combo_changed(new_combo: int) -> void:
	combo = new_combo
	machine.set_combo_multiplier(1.0 + (combo * 0.1))
	emit_signal("combo_changed", combo)
	_update_combo_ui()

func _on_attack_hit(target_pos: Vector2, damage: float) -> void:
	# 检查是否有建筑在攻击范围内
	for building in building_container.get_children():
		if building.has_method("take_damage") and not building.is_destroyed:
			var dist = building.position.distance_to(target_pos)
			if dist < 150:  # 攻击范围
				building.take_damage(damage)
				_add_score(building.get_points())
				_update_destruction()

func _create_buildings() -> void:
	# 创建测试用建筑
	var types = ["wooden_house", "stone_house", "tower", "castle_gate"]
	var screen_size = get_viewport_rect().size
	
	for i in range(buildings_to_destroy):
		var building = Node2D.new()
		building.set_script(load("res://scripts/building.gd"))
		building.building_type = types[i % types.size()]
		building.max_hp = randf_range(3.0, 10.0)
		building.current_hp = building.max_hp
		total_building_hp += building.max_hp
		building_container.add_child(building)
	
	print("[GameManager] Created %d buildings, total HP: %.1f" % [buildings_to_destroy, total_building_hp])

func _add_score(points: int) -> void:
	score += points
	emit_signal("score_changed", score)
	_update_score_ui()

func _update_destruction() -> void:
	# 计算已破坏的血量
	destroyed_building_hp = 0.0
	for building in building_container.get_children():
		if building.has_method("is_destroyed"):
			if building.is_destroyed:
				destroyed_building_hp += building.max_hp
			else:
				destroyed_building_hp += (building.max_hp - building.current_hp)
	
	destruction_percent = (destroyed_building_hp / total_building_hp) * 100.0
	emit_signal("destruction_changed", destruction_percent)
	_update_destruction_ui()
	
	# 检查胜利条件
	if destruction_percent >= 100.0:
		_victory()

func _check_victory() -> void:
	if destruction_percent >= 100.0:
		_victory()
	else:
		_game_over()

func _victory() -> void:
	if current_state == GameState.VICTORY:
		return
	current_state = GameState.VICTORY
	rhythm_engine.stop()
	emit_signal("game_over", true)
	_show_end_screen(true)

func _game_over() -> void:
	if current_state == GameState.GAME_OVER:
		return
	current_state = GameState.GAME_OVER
	rhythm_engine.stop()
	emit_signal("game_over", false)
	_show_end_screen(false)

func _show_end_screen(victory: bool) -> void:
	var result_str = "VICTORY" if victory else "GAME OVER"
	print("[GameManager] %s! Final Score: %d" % [result_str, score])
	$UI/StartHint.text = result_str + "! Press SPACE to restart"
	$UI/StartHint.visible = true

## UI 更新方法
func _update_ui() -> void:
	_update_score_ui()
	_update_combo_ui()
	_update_destruction_ui()

func _update_score_ui() -> void:
	if ui.has_node("Panel/ScoreLabel"):
		ui.get_node("Panel/ScoreLabel").text = "Score: %d" % score

func _update_combo_ui() -> void:
	if ui.has_node("Panel/ComboLabel"):
		ui.get_node("Panel/ComboLabel").text = "Combo: %dx" % combo

func _update_destruction_ui() -> void:
	if ui.has_node("Panel/DestructionBar"):
		ui.get_node("Panel/DestructionBar").value = destruction_percent

## 判定显示
func _show_judgment(judgment: String) -> void:
	if ui.has_node("Panel/JudgmentLabel"):
		var label = ui.get_node("Panel/JudgmentLabel")
		label.text = judgment.to_upper()
		label.modulate = _get_judgment_color(judgment)
		
		# 动画
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(label, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)

func _get_judgment_color(judgment: String) -> Color:
	match judgment:
		"perfect":
			return Color.GREEN
		"great":
			return Color.CYAN
		"good":
			return Color.YELLOW
		_:
			return Color.RED

## 游戏控制
func start_game() -> void:
	current_state = GameState.PLAYING
	rhythm_engine.start()

func pause_game() -> void:
	current_state = GameState.PAUSED
	rhythm_engine.stop()

func resume_game() -> void:
	current_state = GameState.PLAYING
	rhythm_engine.start()

func reset_game() -> void:
	get_tree().reload_current_scene()
