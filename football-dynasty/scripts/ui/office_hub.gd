extends Control

@onready var header: Label = $Margin/Scroll/VBox/Header
@onready var status: Label = $Margin/Scroll/VBox/Status
@onready var scout_box: VBoxContainer = $Margin/Scroll/VBox/ScoutBox
@onready var scout_label: Label = $Margin/Scroll/VBox/ScoutBox/ScoutLabel


func _ready() -> void:
	_refresh()
	$Margin/Scroll/VBox/Buttons/BtnSquad.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/office/squad.tscn"))
	$Margin/Scroll/VBox/Buttons/BtnTactics.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/office/tactics.tscn"))
	$Margin/Scroll/VBox/Buttons/BtnTable.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/office/league_table.tscn"))
	$Margin/Scroll/VBox/Buttons/BtnCalendar.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/office/calendar.tscn"))
	$Margin/Scroll/VBox/Buttons/BtnFinances.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/office/finances.tscn"))
	$Margin/Scroll/VBox/Buttons/BtnTransfers.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/office/transfers.tscn"))
	$Margin/Scroll/VBox/Buttons/BtnSettings.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/office/settings.tscn"))
	$Margin/Scroll/VBox/Buttons/BtnSave.pressed.connect(_on_save)
	$Margin/Scroll/VBox/ScoutBox/BtnAccept.pressed.connect(_on_accept_scout)
	$Margin/Scroll/VBox/ScoutBox/BtnReject.pressed.connect(_on_reject_scout)
	GameState.state_changed.connect(_refresh)
	GameState.settings_changed.connect(_refresh)
	GameState.season_ended.connect(_on_season_ended)
	GameState.scout_offer_ready.connect(func(_o): _refresh())


func _refresh() -> void:
	var club := GameState.player_club
	var league := GameState.player_league()
	var season := GameState.player_season()
	if club == null:
		header.text = "Sin club"
		return
	header.text = "%s  ·  %s  ·  DT %s" % [club.name, league.name if league else "", GameState.coach_name]
	var md := season.current_matchday + 1 if season else 0
	var total := season.total_matchdays if season else 0
	var finished := season.finished if season else false
	status.text = "Temporada %d  |  Jornada %d/%d  |  Presupuesto: %s  |  Nómina (jugadores+staff)/jornada: %s%s" % [
		season.year if season else 0,
		md,
		total,
		_money(club.budget),
		_money(club.weekly_wage_bill()),
		"  |  TEMPORADA FINALIZADA" if finished else "",
	]
	_refresh_scout()


func _refresh_scout() -> void:
	var offer: Dictionary = GameState.pending_scout_offer
	if offer.is_empty():
		scout_box.visible = false
		return
	scout_box.visible = true
	var p := Player.from_dict(offer["player"])
	scout_label.text = "Scouting (%s): %s · %s · %d años · OVR %d · Coste %s" % [
		offer.get("region", "?"), p.display_name(), p.position_label(), p.age, p.overall(), _money(int(offer["cost"]))
	]


func _on_accept_scout() -> void:
	status.text = GameState.accept_scout_offer()
	GameState.save_game()
	_refresh()


func _on_reject_scout() -> void:
	GameState.reject_scout_offer()
	_refresh()


func _on_save() -> void:
	if GameState.save_game():
		status.text += "  ·  Partida guardada."


func _on_season_ended() -> void:
	status.text = "¡Nueva temporada! Ascensos, descensos, edad y retiros aplicados. Presupuesto: %s" % _money(GameState.player_club.budget)


func _money(n: int) -> String:
	return GameState.format_money(n)
