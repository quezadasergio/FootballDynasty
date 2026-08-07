extends Node

## Instancia todas las pantallas para detectar rutas de nodo rotas.

const StaffScript = preload("res://scripts/core/staff_member.gd")

const SCENES: Array[String] = [
	"res://scenes/main_menu.tscn",
	"res://scenes/club_select.tscn",
	"res://scenes/office/office_hub.tscn",
	"res://scenes/office/squad.tscn",
	"res://scenes/office/youth.tscn",
	"res://scenes/office/infirmary.tscn",
	"res://scenes/office/finances.tscn",
	"res://scenes/office/transfers.tscn",
	"res://scenes/office/contracts.tscn",
	"res://scenes/office/tactics.tscn",
	"res://scenes/office/league_table.tscn",
	"res://scenes/office/calendar.tscn",
	"res://scenes/office/settings.tscn",
	"res://scenes/office/matchday_finance.tscn",
	"res://scenes/office/matchday_results.tscn",
	"res://scenes/office/matchday_news.tscn",
	"res://scenes/match/match_prep.tscn",
	"res://scenes/match/match_summary.tscn",
]


func _ready() -> void:
	var selectable: Array = GameState.list_selectable_clubs()
	GameState.coach_name = "Fulano Prueba"
	GameState.start_new_career(str(selectable[0]["id"]), 99)
	var club: Club = GameState.player_club
	# Estados que las pantallas puedan necesitar.
	club.budget += 3000000
	club.players[0].injured = true
	club.players[0].injury_id = "menisco"
	club.players[0].injury_name = "Lesión de menisco"
	club.players[0].injury_severity = 3
	club.players[0].injury_matchdays = 9
	club.players[0].injury_total = 9
	for role in StaffScript.ALL_ROLES:
		club.hire_staff(Database.generate_staff_candidates(role, 1)[0])
	var season := GameState.player_season()
	var fx := season.get_club_fixture(GameState.player_club_id)
	var home: Club = GameState.get_club(fx["home_id"])
	var away: Club = GameState.get_club(fx["away_id"])
	var engine := MatchEngine.new()
	engine.setup(home, away)
	engine.simulate_full()
	GameState.apply_player_match_result(
		home, away, engine.home_goals, engine.away_goals,
		engine.home_goal_scorers, engine.away_goal_scorers
	)
	GameState.advance_after_matchday()

	# Estados de contrato para que las pantallas rendericen todas sus ramas.
	club.budget += 50000000
	club.players[1].transfer_listed = true
	var targets: Array = TransferMarket.list_transfer_targets(
		GameState.clubs, club.id, GameState.free_agents, GameState.foreign_clubs
	)
	for t in targets:
		if str(t.get("market", "")) == "MEX":
			GameState.agree_transfer_fee(t)
			break

	for path in SCENES:
		var packed: PackedScene = load(path)
		if packed == null:
			print("FAIL cargando ", path)
			continue
		var node: Node = packed.instantiate()
		add_child(node)
		print("OK ", path)
		node.queue_free()
	print("=== ESCENAS PROBADAS ===")
	get_tree().quit(0)
