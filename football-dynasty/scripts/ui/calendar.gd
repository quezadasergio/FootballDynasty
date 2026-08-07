extends Control

@onready var list: ItemList = $Margin/Scroll/VBox/FixtureList
@onready var info: Label = $Margin/Scroll/VBox/Info


func _ready() -> void:
	$Margin/Scroll/VBox/BtnPlay.pressed.connect(_on_play)
	$Margin/Scroll/VBox/BtnAdvance.pressed.connect(_on_advance)
	_refresh()


func _refresh() -> void:
	list.clear()
	var season := GameState.player_season()
	var league := GameState.player_league()
	if season == null or league == null:
		info.text = "Sin temporada."
		return
	if season.finished:
		info.text = "Temporada terminada. Usa Avanzar jornada para la siguiente temporada."
		$Margin/Scroll/VBox/BtnPlay.disabled = true
		$Margin/Scroll/VBox/BtnAdvance.disabled = false
		return
	info.text = "Jornada %d de %d — Temporada %d" % [season.current_matchday + 1, season.total_matchdays, season.year]
	for fx in season.get_current_fixtures():
		var home: Club = GameState.get_club(fx["home_id"])
		var away: Club = GameState.get_club(fx["away_id"])
		var mark := ""
		if fx["home_id"] == GameState.player_club_id or fx["away_id"] == GameState.player_club_id:
			mark = " ◄ TU PARTIDO"
		var score := ""
		if fx["played"]:
			score = "  %d-%d" % [fx["home_goals"], fx["away_goals"]]
		list.add_item("%s vs %s%s%s" % [home.name if home else "?", away.name if away else "?", score, mark])
	var mine := season.get_club_fixture(GameState.player_club_id)
	$Margin/Scroll/VBox/BtnPlay.disabled = mine.is_empty() or bool(mine.get("played", false))
	$Margin/Scroll/VBox/BtnAdvance.disabled = mine.is_empty() or not bool(mine.get("played", false))


func _on_play() -> void:
	var season := GameState.player_season()
	if season == null or season.finished:
		return
	var fx := season.get_club_fixture(GameState.player_club_id)
	if fx.is_empty():
		info.text = "No tienes partido esta jornada."
		return
	if fx["played"]:
		info.text = "Tu partido ya se jugó. Pulsa Avanzar jornada."
		return
	get_tree().change_scene_to_file("res://scenes/match/match_prep.tscn")


func _on_advance() -> void:
	GameState.advance_after_matchday()
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/office/matchday_finance.tscn")
