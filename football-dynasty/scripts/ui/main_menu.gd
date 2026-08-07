extends Control

func _ready() -> void:
	$Center/VBox/Title.text = "Football Dynasty"
	$Center/VBox/Subtitle.text = "Construye tu dinastía mexicana"
	$Center/VBox/BtnNew.pressed.connect(_on_new)
	$Center/VBox/BtnContinue.pressed.connect(_on_continue)
	$Center/VBox/BtnContinue.disabled = not GameState.has_save()
	$Center/VBox/BtnQuit.pressed.connect(func(): get_tree().quit())


func _on_new() -> void:
	get_tree().change_scene_to_file("res://scenes/club_select.tscn")


func _on_continue() -> void:
	if GameState.load_game():
		get_tree().change_scene_to_file("res://scenes/office/office_hub.tscn")
