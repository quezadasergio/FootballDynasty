extends Node

const Medical = preload("res://scripts/core/medical_service.gd")
const Youth = preload("res://scripts/core/youth_service.gd")
const StaffScript = preload("res://scripts/core/staff_member.gd")
const ClubFinance = preload("res://scripts/core/club_finance.gd")

var _err := 0


func _ready() -> void:
	var err := 0
	print("=== Football Dynasty smoke test ===")
	if Database.leagues_template.is_empty():
		push_error("Database leagues_template empty")
		err += 1
	var selectable := GameState.list_selectable_clubs()
	if selectable.is_empty():
		push_error("no selectable clubs")
		get_tree().quit(1)
		return
	GameState.coach_name = "Fulano Prueba"
	GameState.start_new_career(str(selectable[selectable.size() - 1]["id"]), 42)
	if GameState.player_club == null:
		push_error("player_club null")
		get_tree().quit(1)
		return
	print("Club: ", GameState.player_club.name, " players=", GameState.player_club.players.size())
	print("Cantera: ", GameState.player_club.youth_players.size())
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
	err += _check_markets(targets)
	err += _check_coach_news()
	err += _check_contracts()
	err += _check_medical()
	err += _check_youth()
	err += _check_matchday_report()
	err += _check_full_season()
	if err == 0:
		print("=== OK ===")
	else:
		print("=== FAILED errors=", err, " ===")
	get_tree().quit(err)


func _check_full_season() -> int:
	## Corre lo que resta de temporada y comprueba el cambio de año.
	var errs := 0
	var start_year: int = GameState.player_season().year
	var guard := 0
	while GameState.player_season().year == start_year and guard < 80:
		GameState.simulate_all_leagues_cpu(false)
		GameState.advance_after_matchday()
		guard += 1
	var club := GameState.player_club
	print("Nueva temporada: ", GameState.player_season().year, " (", guard, " jornadas)")
	print("Plantilla=", club.players.size(), " cantera=", club.youth_players.size())
	if GameState.player_season().year <= start_year:
		errs += _fail("la temporada no avanzó de año")
	for cid in GameState.clubs.keys():
		var c: Club = GameState.clubs[cid]
		if c.youth_players.size() < Youth.MIN_SQUAD:
			errs += _fail("%s se quedó sin cantera mínima" % c.short_name)
			break
		for y in c.youth_players:
			if y.age > 19 or y.age < 14:
				errs += _fail("%s tiene un juvenil de %d años" % [c.short_name, y.age])
				break
	if not GameState.save_game() or not GameState.load_game():
		errs += _fail("guardado/carga falló tras cambiar de temporada")
	return errs


func _fail(msg: String) -> int:
	push_error(msg)
	print("FAIL: ", msg)
	return 1


func _check_markets(targets: Array) -> int:
	var per_market: Dictionary = {}
	var price_sum: Dictionary = {}
	for t in targets:
		var m: String = str(t.get("market", "?"))
		per_market[m] = int(per_market.get(m, 0)) + 1
		price_sum[m] = int(price_sum.get(m, 0)) + int(t["price"])
	print("Mercados: ", per_market)
	var errs := 0
	for needed in ["ASI", "AFR", "EUR", "SUD", "MEX"]:
		if int(per_market.get(needed, 0)) <= 0:
			errs += _fail("mercado %s vacío" % needed)
	## Asia y África deben costar como México, no como Europa.
	if int(per_market.get("ASI", 0)) > 0 and int(per_market.get("EUR", 0)) > 0:
		var asi_avg: int = int(price_sum["ASI"]) / int(per_market["ASI"])
		var eur_avg: int = int(price_sum["EUR"]) / int(per_market["EUR"])
		print("Precio medio ASI=", asi_avg, " EUR=", eur_avg)
		if asi_avg >= eur_avg:
			errs += _fail("Asia no debería ser más cara que Europa")
	return errs


func _check_coach_news() -> int:
	var found := false
	for n in GameState.last_matchday_news:
		if str(n.get("headline", "")).contains(GameState.coach_name) \
				or str(n.get("body", "")).contains(GameState.coach_name):
			found = true
			break
	print("Noticias: ", GameState.last_matchday_news.size(), " mencionan al DT=", found)
	if not found:
		return _fail("ninguna noticia menciona al entrenador")
	return 0


func _check_contracts() -> int:
	var club := GameState.player_club
	var league := GameState.player_league()
	var errs := 0
	for type_key in ClubFinance.CONTRACT_TYPES:
		var offers := ClubFinance.offers_for_type(club, league, type_key)
		if offers.size() != 3:
			errs += _fail("se esperaban 3 ofertas de %s" % type_key)
	for kit in ["kit_chest", "kit_sleeve", "kit_shorts"]:
		var offers := ClubFinance.offers_for_type(club, league, kit)
		ClubFinance.sign_contract(club, offers[2])
		if not club.media_contracts.has(kit):
			errs += _fail("no se firmó el contrato %s" % kit)
	print("Contratos activos: ", club.media_contracts.keys())
	return errs


func _check_medical() -> int:
	var club := GameState.player_club
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var errs := 0
	## Fuerza una lesión grave operable y aplica cirugía.
	var patient: Player = club.players[0]
	patient.injured = true
	patient.injury_id = "ligamento"
	patient.injury_name = "Rotura de ligamento cruzado"
	patient.injury_severity = 3
	patient.injury_matchdays = 18
	patient.injury_total = 18
	patient.treatment = ""
	club.hire_staff(Database.generate_staff_candidates(StaffScript.Role.DOCTOR, 1)[0])
	var opts := Medical.treatment_options(club, patient)
	print("Opciones de tratamiento: ", opts.size())
	if opts.size() != 3:
		errs += _fail("la lesión grave debería ofrecer reposo, terapia y cirugía")
	club.budget += 5000000
	var before := patient.injury_matchdays
	var msg := Medical.apply_treatment(club, patient, "cirugia", rng)
	print("Cirugía: ", msg)
	if patient.injury_matchdays >= before:
		errs += _fail("la cirugía debería acortar la baja")
	if club.medical_acc <= 0:
		errs += _fail("la cirugía no se registró en los gastos médicos")
	## Y que la baja se consuma jornada a jornada.
	var tick := Medical.tick_matchday(club, rng)
	if patient.injury_matchdays >= before:
		errs += _fail("la baja no avanzó al pasar la jornada")
	print("Baja restante: ", patient.injury_matchdays, " altas=", tick["recovered"].size())
	return errs


func _check_youth() -> int:
	var club := GameState.player_club
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var errs := 0
	if club.youth_players.size() < Youth.MIN_SQUAD or club.youth_players.size() > Youth.MAX_SQUAD:
		errs += _fail("la cantera debe tener entre %d y %d chicos" % [Youth.MIN_SQUAD, Youth.MAX_SQUAD])
	for y in club.youth_players:
		if y.age < 14 or y.age > 19:
			errs += _fail("juvenil con edad fuera de rango: %d" % y.age)
			break
	club.hire_staff(Database.generate_staff_candidates(StaffScript.Role.YOUTH, 1)[0])
	var advice := Youth.suggest_plan(club)
	print("Plan sugerido: ", advice.get("plan_id", "-"), " ok=", advice.get("ok", false))
	if not bool(advice.get("ok", false)):
		errs += _fail("el entrenador de cantera no propuso plan")
	Youth.set_plan(club, str(advice.get("plan_id", "integral")))

	## Progresión gradual y con tope.
	var tracked: Player = club.youth_players[0]
	tracked.potential = tracked.overall() + 8
	var start_ovr := tracked.overall()
	for i in 60:
		Youth.develop_matchday(club, rng)
	print("Juvenil: OVR ", start_ovr, " → ", tracked.overall(), " (tope ", tracked.potential_cap(), ")")
	if tracked.overall() <= start_ovr:
		errs += _fail("los juveniles no mejoraron con el plan activo")
	if tracked.overall() > tracked.potential_cap():
		errs += _fail("un juvenil superó su tope")

	## Un menor de 17 no puede subir; uno de 17+ sí, y puede volver.
	var minor: Player = null
	for y in club.youth_players:
		if y.age < Youth.PROMOTE_AGE:
			minor = y
			break
	if minor:
		var blocked := Youth.promote(club, minor.id)
		if blocked.begins_with("%s sube" % minor.display_name()):
			errs += _fail("un menor de %d años no debería subir" % Youth.PROMOTE_AGE)
	var ready_player: Player = null
	for y in club.youth_players:
		if y.age >= Youth.PROMOTE_AGE:
			ready_player = y
			break
	if ready_player == null:
		print("Sin juveniles de 17+ en esta camada; se omite el ascenso")
		return errs
	print("Ascenso: ", Youth.promote(club, ready_player.id))
	if club.get_player(ready_player.id) == null:
		errs += _fail("el juvenil no llegó al primer equipo")
	if ready_player.age < Youth.RETURN_AGE_LIMIT:
		print("Regreso: ", Youth.demote(club, ready_player.id))
		if club.get_youth_player(ready_player.id) == null:
			errs += _fail("el juvenil no pudo volver a la cantera")
	return errs


func _check_matchday_report() -> int:
	var club := GameState.player_club
	var errs := 0
	## Una compra debe aparecer en el reporte de la jornada.
	var targets := TransferMarket.list_transfer_targets(
		GameState.clubs, club.id, GameState.free_agents, GameState.foreign_clubs
	)
	var bought := 0
	for t in targets:
		if str(t.get("market", "")) != "ASI":
			continue
		var seller: Club = GameState.get_club(str(t["seller_id"]))
		club.budget = int(t["price"]) + 2000000
		if TransferMarket.buy_player(club, seller, t["player"], int(t["price"]), GameState.free_agents, 1) == "":
			bought = int(t["price"])
		break
	if bought <= 0:
		print("No se pudo comprar en Asia (cupo de extranjeros o plantilla); se omite")

	var season := GameState.player_season()
	var fx := season.get_club_fixture(club.id)
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

	var f: Dictionary = GameState.last_matchday_finance
	for key in [
		"transfers_in", "transfers_out", "medical_cost", "youth_wages",
		"academy_cost", "kit_total", "broadcast_total", "contract_amounts",
	]:
		if not f.has(key):
			errs += _fail("falta '%s' en el reporte de la jornada" % key)
	print("Reporte: compras=", f.get("transfers_out", 0), " medico=", f.get("medical_cost", 0),
		" uniforme=", f.get("kit_total", 0), " juveniles=", f.get("youth_wages", 0),
		" academia=", f.get("academy_cost", 0), " balance=", f.get("net", 0))
	if bought > 0 and int(f.get("transfers_out", 0)) < bought:
		errs += _fail("la compra no se reflejó en el reporte")
	if int(f.get("kit_total", 0)) <= 0:
		errs += _fail("la publicidad del uniforme no aportó ingresos")
	if club.transfer_out_acc != 0 or club.medical_acc != 0:
		errs += _fail("el libro de la jornada no se cerró")
	return errs
