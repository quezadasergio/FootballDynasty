extends Button

@export var target_scene: String = "res://scenes/office/office_hub.tscn"


func _ready() -> void:
	text = "←"
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	custom_minimum_size = Vector2(44, 44)
	add_theme_font_size_override("font_size", 28)
	tooltip_text = "Volver"
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	# Quedar por encima de márgenes/scroll a pantalla completa
	call_deferred("_bring_to_front")


func _bring_to_front() -> void:
	move_to_front()


func _on_pressed() -> void:
	if target_scene.is_empty():
		return
	get_tree().change_scene_to_file(target_scene)
