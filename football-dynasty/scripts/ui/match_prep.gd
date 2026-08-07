extends Control

@onready var info: Label = $Margin/Scroll/VBox/Info
@onready var mentality: OptionButton = $Margin/Scroll/VBox/Mentality


func _ready() -> void:
	var season := GameState.player_season()
	var fx := season.get_club_fixture(GameState.player_club_id)
	var home: Club = GameState.get_club(fx["home_id"])
	var away: Club = GameState.get_club(fx["away_id"])
	info.text = "%s vs %s\nRevisa tu alineación y mentalidad antes del silbato." % [home.name, away.name]
	mentality.clear()
	mentality.add_item("Defensiva", 0)
	mentality.add_item("Normal", 1)
	mentality.add_item("Ofensiva", 2)
	mentality.select(GameState.player_club.mentality)
	$Margin/Scroll/VBox/BtnTactics.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/office/tactics.tscn"))
	$Margin/Scroll/VBox/BtnKickoff.pressed.connect(_on_kickoff)


func _on_kickoff() -> void:
	GameState.player_club.mentality = mentality.get_item_id(mentality.selected)
	GameState.player_club.ensure_default_lineup()
	get_tree().change_scene_to_file("res://scenes/match/match_view.tscn")
