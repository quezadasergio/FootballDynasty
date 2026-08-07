extends Control

@onready var body: RichTextLabel = $Margin/Scroll/VBox/Body


func _ready() -> void:
	$Margin/Scroll/VBox/BtnContinue.pressed.connect(_on_continue)
	_fill()


func _fill() -> void:
	var news: Array = GameState.last_matchday_news
	if news.is_empty():
		body.text = "No hay recortes de prensa esta jornada."
		return
	var text := "[b]Resumen de medios[/b]\nTV · Radio · Internet · Prensa local y nacional\n\n"
	for n in news:
		var medium: String = str(n.get("medium", ""))
		var outlet: String = str(n.get("outlet", ""))
		var headline: String = str(n.get("headline", ""))
		var article: String = str(n.get("body", ""))
		var mark := "★ " if n.get("about_player", false) else ""
		text += "[b]%s%s[/b]  —  [i]%s[/i]\n%s\n%s\n\n" % [mark, medium, outlet, headline, article]
	text += "[i]Continúa para volver a la oficina del club.[/i]"
	body.text = text


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/office/office_hub.tscn")
