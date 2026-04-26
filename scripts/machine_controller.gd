## MachineController.gd
## 机器控制器 - 根据节奏指令执行动作

extends Node2D

## 信号
signal action_started(action: String)
signal action_completed(action: String)
signal attack_hit(target_position: Vector2, damage: float)

## 机器配置
@export var move_speed: float = 100.0
@export var attack_power: float = 10.0
@export var combo_multiplier: float = 1.0

## 状态
enum MachineState { IDLE, MOVING, ATTACKING, SPECIAL, STUNNED }
var current_state: MachineState = MachineState.IDLE

## 动画
var anim_player
var hitbox
var goblin_container

## 视觉
var machine_sprite: ColorRect
var screen_size: Vector2

## 动作映射
var action_animations: Dictionary = {
	"up": "move_up",
	"down": "move_down", 
	"left": "move_left",
	"right": "move_right",
	"attack_up": "attack_up",
	"attack_down": "attack_down",
	"attack_left": "attack_left",
	"attack_right": "attack_right",
	"stun": "stun",
	"idle": "idle"
}

func _ready() -> void:
	# 获取子节点
	anim_player = $AnimationPlayer
	hitbox = $Hitbox
	goblin_container = $Goblins
	machine_sprite = $Sprite
	
	screen_size = get_viewport_rect().size
	position = Vector2(screen_size.x * 0.3, screen_size.y * 0.6)  # 机器在屏幕左侧
	print("[MachineController] Initialized at: ", position)

## 根据指令执行动作
func execute_action(action: String) -> void:
	if current_state == MachineState.STUNNED:
		return
	
	print("[Machine] Executing action: ", action)
	emit_signal("action_started", action)
	
	match action:
		"up":
			_move_vertical(-1)
		"down":
			_move_vertical(1)
		"left":
			_move_horizontal(-1)
		"right":
			_move_horizontal(1)
		"attack_up", "attack_down", "attack_left", "attack_right":
			_perform_attack(action)
		_:
			pass

func _move_vertical(direction: int) -> void:
	current_state = MachineState.MOVING
	var target_y = position.y + (direction * move_speed)
	target_y = clamp(target_y, 100, screen_size.y - 100)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", target_y, 0.3)
	await tween.finished
	current_state = MachineState.IDLE
	emit_signal("action_completed", "move")

func _move_horizontal(direction: int) -> void:
	current_state = MachineState.MOVING
	var target_x = position.x + (direction * move_speed * 0.5)
	target_x = clamp(target_x, 100, screen_size.x * 0.6)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:x", target_x, 0.3)
	await tween.finished
	current_state = MachineState.IDLE
	emit_signal("action_completed", "move")

func _perform_attack(action: String) -> void:
	current_state = MachineState.ATTACKING
	
	# 触发命中信号（延迟到动画峰值时刻）
	await get_tree().create_timer(0.15).timeout
	
	# 确定攻击方向和目标位置
	var attack_dir = action.replace("attack_", "")
	var target_pos: Vector2
	match attack_dir:
		"up":
			target_pos = position + Vector2(0, -200)
		"down":
			target_pos = position + Vector2(0, 200)
		"left":
			target_pos = position + Vector2(-150, 0)
		"right":
			target_pos = position + Vector2(150, 0)
	
	# 计算伤害
	var final_damage = attack_power * combo_multiplier
	emit_signal("attack_hit", target_pos, final_damage)
	
	await get_tree().create_timer(0.3).timeout
	current_state = MachineState.IDLE
	emit_signal("action_completed", "attack")

func trigger_stun() -> void:
	current_state = MachineState.STUNNED
	
	# 抖动效果
	var original_pos = position
	var tween = create_tween()
	for i in range(5):
		tween.tween_property(self, "position:x", original_pos.x + (randf() - 0.5) * 20, 0.05)
		tween.tween_property(self, "position:x", original_pos.x - (randf() - 0.5) * 20, 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)
	
	print("[Machine] STUNNED!")
	await get_tree().create_timer(0.5).timeout
	current_state = MachineState.IDLE

func set_combo_multiplier(mult: float) -> void:
	combo_multiplier = mult
	print("[Machine] Combo multiplier: ", mult)
