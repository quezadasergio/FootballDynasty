extends Control

@onready var body: RichTextLabel = $Margin/Scroll/VBox/Body


func _ready() -> void:
	$Margin/Scroll/VBox/BtnAdvance.pressed.connect(_on_advance)
	var s: Dictionary = GameState.last_match_summary
	if s.is_empty():
		body.text = "Sin resumen disponible."
		return
	var home: Club = GameState.get_club(s["home_id"])
	var away: Club = GameState.get_club(s["away_id"])
	var income: Dictionary = s["home_income"] if s["home_id"] == GameState.player_club_id else s["away_income"]
	body.text = "[b]Resultado final[/b]\n\n%s  %d - %d  %s\n\nTaquilla: %s\nPremio: %s\nTotal ingresos del partido: %s\n\nPresupuesto actual: %s\n\nPulsa «Avanzar jornada» para liquidar sueldos y derechos, ver noticias y volver a la oficina." % [
		home.name, s["home_goals"], s["away_goals"], away.name,
		_money(income.get("gate", 0)), _money(income.get("prize", 0)), _money(income.get("total", 0)),
		_money(GameState.player_club.budget),
	]


func _on_advance() -> void:
	GameState.advance_after_matchday()
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/office/matchday_finance.tscn")


func _money(n: int) -> String:
	return GameState.format_money(n)
