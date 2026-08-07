extends Node

func _ready() -> void:
	var err := 0
	print("=== Football Dynasty smoke test ===")
	if Database.leagues_template.is_empty():
		push_error("Database leagues_template empty")
		err += 1
	GameState.start_new_career("c_aldea", 42)
	if GameState.player_club == null:
		push_error("player_club null")
		err += 1
	else:
		print("Club: ", GameState.player_club.name, " players=", GameState.player_club.players.size())
	var season := GameState.player_season()
	print("Matchdays: ", season.total_matchdays)
	var fx := season.get_club_fixture(GameState.player_club_id)
	var home: Club = GameState.get_club(fx["home_id"])
	var away: Club = GameState.get_club(fx["away_id"])
	home.ensure_default_lineup()
	away.ensure_default_lineup()
	var engine := MatchEngine.new()
	engine.setup(home, away)
	var events := engine.simulate_full()
	print("Match %s %d-%d %s events=%d" % [home.short_name, engine.home_goals, engine.away_goals, away.short_name, events.size()])
	GameState.apply_player_match_result(
		home, away, engine.home_goals, engine.away_goals,
		engine.home_goal_scorers, engine.away_goal_scorers
	)
	GameState.advance_after_matchday()
	print("After advance matchday=", GameState.player_season().current_matchday, " budget=", GameState.player_club.budget)
	if not GameState.save_game():
		push_error("save failed")
		err += 1
	if not GameState.load_game():
		push_error("load failed")
		err += 1
	print("Reload club=", GameState.player_club.name)
	var targets := TransferMarket.list_transfer_targets(
		GameState.clubs, GameState.player_club_id, GameState.free_agents, GameState.foreign_clubs
	)
	print("Transfer targets: ", targets.size(), " foreign clubs=", GameState.foreign_clubs.size())
	if err == 0:
		print("=== OK ===")
	else:
		print("=== FAILED errors=", err, " ===")
	get_tree().quit(err)
