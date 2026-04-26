## RhythmEngine.gd
## 节奏引擎核心 - 处理节拍定时和输入判定

extends Node

## 信号
signal beat_triggered(beat_number: int)
signal beat_window_opened(expected_input: String)
signal input_judged(judgment: String, timing_ms: float)
signal combo_changed(new_combo: int)
signal miss_triggered()

## 配置
@export var bpm: float = 120.0
@export var beats_per_bar: int = 4
@export var input_window_ms: float = 150.0  # Good窗口
@export var perfect_window_ms: float = 50.0
@export var great_window_ms: float = 100.0

## 状态
var beat_interval: float
var current_beat: int = 0
var current_bar: int = 0
var timer: float = 0.0
var is_running: bool = false
var combo: int = 0
var max_combo: int = 0

## 当前节拍窗口状态
var beat_window_start: float = 0.0
var beat_window_active: bool = false
var expected_input: String = ""

## 连击加成
var combo_multiplier: float = 1.0

## 谱面数据 - 简化版，每4拍一个指令
var beat_pattern: Array[String] = ["up", "right", "down", "left"]
var current_pattern_index: int = 0

func _ready() -> void:
	beat_interval = 60.0 / bpm
	print("[RhythmEngine] BPM: %d, Beat Interval: %.3fs" % [bpm, beat_interval])

func _process(delta: float) -> void:
	if not is_running:
		return
	
	timer += delta
	
	# 节拍触发点
	if timer >= beat_interval:
		_on_beat()

func _on_beat() -> void:
	timer -= beat_interval
	current_beat += 1
	
	# 每4拍（1小节）切换指令
	if current_beat % beats_per_bar == 0:
		current_pattern_index = (current_pattern_index + 1) % beat_pattern.size()
	
	emit_signal("beat_triggered", current_beat)
	
	# 开启输入窗口
	_open_beat_window()

func _open_beat_window() -> void:
	beat_window_start = timer
	beat_window_active = true
	expected_input = beat_pattern[current_pattern_index]
	emit_signal("beat_window_opened", expected_input)
	
	# 窗口持续时间（稍长于perfect窗口，确保有反应时间）
	var window_duration = (input_window_ms / 1000.0) + 0.1
	await get_tree().create_timer(window_duration).timeout
	beat_window_active = false

## 检查输入是否在窗口内
func check_input(input_name: String) -> Dictionary:
	if not beat_window_active:
		return {"judgment": "miss", "timing_ms": -1, "success": false}
	
	var timing_ms = abs(timer - beat_interval / 2) * 1000  # 相对于节拍中心的timing
	
	var judgment: String
	var success: bool
	
	if timing_ms <= perfect_window_ms:
		judgment = "perfect"
		success = true
		_on_hit()
	elif timing_ms <= great_window_ms:
		judgment = "great"
		success = true
		_on_hit()
	elif timing_ms <= input_window_ms:
		judgment = "good"
		success = true
		_on_hit()
	else:
		judgment = "miss"
		success = false
		_on_miss()
	
	emit_signal("input_judged", judgment, timing_ms)
	
	if input_name != expected_input and success:
		# 按对了时机但按错了键
		judgment = "miss"
		success = false
		_on_miss()
		emit_signal("input_judged", "miss", timing_ms)
	
	return {"judgment": judgment, "timing_ms": timing_ms, "success": success, "expected": expected_input, "input": input_name}

func _on_hit() -> void:
	combo += 1
	if combo > max_combo:
		max_combo = combo
	combo_multiplier = 1.0 + (combo * 0.1)
	if combo_multiplier > 3.0:
		combo_multiplier = 3.0
	emit_signal("combo_changed", combo)

func _on_miss() -> void:
	combo = 0
	combo_multiplier = 1.0
	emit_signal("combo_changed", combo)
	emit_signal("miss_triggered")

func start() -> void:
	is_running = true
	timer = 0.0
	current_beat = 0
	current_bar = 0
	current_pattern_index = 0
	combo = 0
	max_combo = 0

func stop() -> void:
	is_running = false

func reset() -> void:
	stop()
	timer = 0.0
	current_beat = 0
	combo = 0
	combo_multiplier = 1.0

func get_beat_fraction() -> float:
	# 返回当前节拍的进度（0.0 - 1.0）
	return timer / beat_interval

func set_bpm(new_bpm: float) -> void:
	bpm = new_bpm
	beat_interval = 60.0 / bpm
	print("[RhythmEngine] BPM changed to: %d" % bpm)
