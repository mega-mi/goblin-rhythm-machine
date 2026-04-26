## Building.gd
## 可破坏建筑 - 拥有耐久度，被攻击时减少

extends Node2D

## 信号
signal destroyed(building)
signal damaged(hp_remaining: float, max_hp: float)

## 配置
@export var max_hp: float = 5.0
@export var building_type: String = "wooden_house"
@export var points_value: int = 100

## 状态
var current_hp: float
var is_destroyed: bool = false

## 视觉
var sprite: ColorRect
var hp_bar: ProgressBar
var damage_label: Label

## 预设配置
const BUILDING_PRESETS: Dictionary = {
	"wooden_house": {
		"hp": 3.0,
		"color": Color(0.6, 0.4, 0.2),
		"size": Vector2(60, 50),
		"points": 100
	},
	"stone_house": {
		"hp": 6.0,
		"color": Color(0.5, 0.5, 0.5),
		"size": Vector2(70, 60),
		"points": 200
	},
	"tower": {
		"hp": 10.0,
		"color": Color(0.4, 0.4, 0.55),
		"size": Vector2(40, 80),
		"points": 300
	},
	"castle_gate": {
		"hp": 15.0,
		"color": Color(0.3, 0.3, 0.4),
		"size": Vector2(100, 100),
		"points": 500
	}
}

func _ready() -> void:
	# 创建必要的子节点
	_ensure_child_nodes()
	
	current_hp = max_hp
	
	# 应用预设
	if BUILDING_PRESETS.has(building_type):
		var preset = BUILDING_PRESETS[building_type]
		max_hp = preset.hp
		current_hp = max_hp
		points_value = preset.points
		
		if sprite:
			sprite.color = preset.color
			sprite.size = preset.size
	
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
		hp_bar.visible = false
	
	# 随机位置
	var screen_size = get_viewport_rect().size
	position = Vector2(
		randf_range(screen_size.x * 0.55, screen_size.x * 0.85),
		randf_range(screen_size.y * 0.2, screen_size.y * 0.8)
	)
	
	print("[Building] Created %s at %s with HP %.1f" % [building_type, position, max_hp])

func _ensure_child_nodes() -> void:
	# 创建 Sprite（ColorRect）
	sprite = ColorRect.new()
	sprite.name = "Sprite"
	sprite.anchors_preset = Control.PRESET_CENTER
	sprite.size = Vector2(64, 64)
	sprite.position = Vector2(-32, -32)  # 使用 position 而不是 offset
	sprite.color = Color(0.6, 0.4, 0.2)
	add_child(sprite)
	
	# 创建 HP Bar
	hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.offset_top = -45
	hp_bar.custom_minimum_size = Vector2(60, 8)
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	add_child(hp_bar)
	
	# 创建伤害数字 Label
	damage_label = Label.new()
	damage_label.name = "DamageLabel"
	damage_label.text = "0"
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.custom_minimum_size = Vector2(60, 20)
	add_child(damage_label)

func take_damage(amount: float) -> void:
	if is_destroyed:
		return
	
	current_hp -= amount
	
	print("[Building] Took %.1f damage, HP: %.1f / %.1f" % [amount, current_hp, max_hp])
	
	# 显示伤害数字
	_show_damage_number(amount)
	
	# 更新血条
	if hp_bar:
		hp_bar.visible = true
		hp_bar.value = current_hp
	
	emit_signal("damaged", current_hp, max_hp)
	
	# 闪烁效果
	_flicker()
	
	# 检查是否摧毁
	if current_hp <= 0:
		_destroy()

func _show_damage_number(amount: float) -> void:
	if not damage_label:
		return
	
	damage_label.text = "-%.0f" % amount
	damage_label.visible = true
	damage_label.position.y = -60
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 30, 0.5)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.5)
	
	await tween.finished
	damage_label.visible = false
	damage_label.modulate.a = 1.0

func _flicker() -> void:
	if not sprite:
		return
	
	var original_color = sprite.color
	var tween = create_tween()
	for i in range(3):
		tween.tween_property(sprite, "color", Color.RED, 0.05)
		tween.tween_property(sprite, "color", original_color, 0.05)
	sprite.color = original_color

func _destroy() -> void:
	is_destroyed = true
	emit_signal("destroyed", self)
	print("[Building] Destroyed!")
	
	# 摧毁动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "position:y", position.y + 50, 0.3)
	
	await tween.finished
	queue_free()

func get_points() -> int:
	return points_value
