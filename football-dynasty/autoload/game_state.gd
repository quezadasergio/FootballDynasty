extends Node

signal state_changed
signal season_ended
signal scout_offer_ready(offer: Dictionary)
signal settings_changed

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const StaffSvc = preload("res://scripts/core/staff_service.gd")
const StaffScript = preload("res://scripts/core/staff_member.gd")
const CurrencyScript = preload("res://scripts/core/currency.gd")
const NewsService = preload("res://scripts/core/news_service.gd")
const ClubFinance = preload("res://scripts/core/club_finance.gd")
const Medical = preload("res://scripts/core/medical_service.gd")
const Youth = preload("res://scripts/core/youth_service.gd")

const STAFF_CANDIDATES_PER_ROLE := 10

var clubs: Dictionary = {} ## id -> Club
var foreign_clubs: Dictionary = {} ## id -> Club (mercado internacional, no juegan ligas MX)
var leagues: Dictionary = {} ## id -> League
var seasons: Dictionary = {} ## league_id -> Season
var free_agents: Array[Player] = []
var player_club_id: String = ""
var last_match_summary: Dictionary = {}
var last_matchday_finance: Dictionary = {}
var last_matchday_news: Array = []
var last_matchday_roundup: Array = [] ## snapshot de resultados/stats por liga
var career_started: bool = false
var pending_scout_offer: Dictionary = {}
var coach_name: String = ""
## role_key -> Array[StaffMember]; se renueva solo al cambiar de jornada.
var staff_candidates: Dictionary = {}
var last_matchday_medical: Dictionary = {}
var last_matchday_youth: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Display currency (internal values remain EUR)
var currency_code: int = CurrencyScript.Code.EUR


func _ready() -> void:
	load_settings()


func format_money(amount_eur: int) -> String:
	return CurrencyScript.format(amount_eur, currency_code)


func set_currency(code: int) -> void:
	currency_code = CurrencyScript.normalize(code)
	save_settings()
	settings_changed.emit()
	state_changed.emit()


func save_settings() -> void:
	var data := {"currency": CurrencyScript.key_from_code(currency_code)}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	currency_code = CurrencyScript.code_from_key(str(data.get("currency", "eur")))


var player_club: Club:
	get:
		if player_club_id == "" or not clubs.has(player_club_id):
			return null
		return clubs[player_club_id]


func player_league() -> League:
	var club := player_club
	if club == null:
		return null
	return leagues.get(club.league_id)


func player_season() -> Season:
	var club := player_club
	if club == null:
		return null
	return seasons.get(club.league_id)


func start_new_career(club_id: String, seed_value: int = 0) -> void:
	var world: Dictionary = Database.create_world(seed_value)
	clubs = world["clubs"]
	foreign_clubs = world.get("foreign_clubs", {})
	leagues = world["leagues"]
	seasons = world["seasons"]
	free_agents.clear()
	for p in world["free_agents"]:
		free_agents.append(p)
	player_club_id = club_id
	career_started = true
	last_match_summary = {}
	last_matchday_finance = {}
	last_matchday_news = []
	last_matchday_roundup = []
	last_matchday_medical = {}
	last_matchday_youth = []
	pending_scout_offer = {}
	if coach_name.strip_edges() == "":
		coach_name = Database.random_coach_name()
	refresh_staff_candidates()
	_rng.randomize()
	state_changed.emit()


func refresh_staff_candidates() -> void:
	## Nuevos aspirantes por puesto. Se mantienen fijos hasta la siguiente jornada
	## para que cambiar de puesto en la pantalla no rehaga la lista.
	staff_candidates.clear()
	for role in StaffScript.ALL_ROLES:
		staff_candidates[StaffScript.role_key(role)] = Database.generate_staff_candidates(
			role, STAFF_CANDIDATES_PER_ROLE
		)


func candidates_for_role(role: int) -> Array:
	var key: String = StaffScript.role_key(role)
	if not staff_candidates.has(key):
		staff_candidates[key] = Database.generate_staff_candidates(role, STAFF_CANDIDATES_PER_ROLE)
	return staff_candidates[key]


func remove_staff_candidate(role: int, member) -> void:
	var key: String = StaffScript.role_key(role)
	if not staff_candidates.has(key):
		return
	(staff_candidates[key] as Array).erase(member)


func get_div2_clubs() -> Array[Club]:
	var result: Array[Club] = []
	var league: League = leagues.get("div2")
	if league == null:
		return result
	for cid in league.club_ids:
		result.append(clubs[cid])
	return result


func list_selectable_clubs() -> Array:
	## Todos los clubes de Liga MX y Expansión.
	var result: Array = []
	for league_data in Database.leagues_template:
		for c in league_data["clubs"]:
			var entry: Dictionary = c.duplicate()
			entry["league_id"] = league_data["id"]
			entry["league_name"] = league_data["name"]
			entry["tier"] = int(league_data["tier"])
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["tier"]) != int(b["tier"]):
			return int(a["tier"]) < int(b["tier"])
		return str(a["name"]) < str(b["name"])
	)
	return result


func get_club(club_id: String) -> Club:
	if clubs.has(club_id):
		return clubs[club_id]
	return foreign_clubs.get(club_id)


func simulate_cpu_fixtures_except_player() -> void:
	## Simulate unfinished fixtures in the player's current matchday only.
	var season := player_season()
	if season == null:
		return
	_simulate_season_cpu(season, true)


func simulate_all_leagues_cpu(skip_player_fixture: bool = true) -> void:
	var player_lid := ""
	if player_club:
		player_lid = player_club.league_id
	for lid in seasons.keys():
		var season: Season = seasons[lid]
		if season.finished:
			continue
		var skip: bool = false
		if skip_player_fixture and str(lid) == player_lid:
			skip = true
		_simulate_season_cpu(season, skip)


func _simulate_season_cpu(season: Season, skip_player_fixture: bool) -> void:
	for fx in season.get_current_fixtures():
		if fx["played"]:
			continue
		if skip_player_fixture and (fx["home_id"] == player_club_id or fx["away_id"] == player_club_id):
			continue
		var home: Club = clubs[fx["home_id"]]
		var away: Club = clubs[fx["away_id"]]
		home.ensure_default_lineup()
		away.ensure_default_lineup()
		var engine := MatchEngine.new()
		engine.setup(home, away)
		engine.simulate_full()
		_apply_match_result(
			home, away, engine.home_goals, engine.away_goals, false,
			engine.home_goal_scorers, engine.away_goal_scorers
		)


func apply_player_match_result(
	home: Club,
	away: Club,
	home_goals: int,
	away_goals: int,
	home_scorers: Array = [],
	away_scorers: Array = []
) -> void:
	_apply_match_result(home, away, home_goals, away_goals, true, home_scorers, away_scorers)


func _apply_match_result(
	home: Club,
	away: Club,
	home_goals: int,
	away_goals: int,
	is_player_match: bool,
	home_scorers: Array = [],
	away_scorers: Array = []
) -> void:
	var season: Season = seasons[home.league_id]
	var league: League = leagues[home.league_id]
	season.mark_fixture_played(home.id, away.id, home_goals, away_goals, home_scorers, away_scorers)
	league.apply_result(home.id, away.id, home_goals, away_goals)

	var home_income := Finance.apply_match_income(home, true, away.reputation, home_goals, away_goals)
	var away_income := Finance.apply_match_income(away, false, home.reputation, home_goals, away_goals)

	if is_player_match:
		last_match_summary = {
			"home_id": home.id,
			"away_id": away.id,
			"home_goals": home_goals,
			"away_goals": away_goals,
			"home_scorers": home_scorers.duplicate(true),
			"away_scorers": away_scorers.duplicate(true),
			"home_income": home_income,
			"away_income": away_income,
		}


func build_matchday_roundup() -> Array:
	## Snapshot de la jornada actual (antes de avanzar el calendario).
	var out: Array = []
	var ordered: Array = leagues.values()
	ordered.sort_custom(func(a: League, b: League) -> bool: return a.tier < b.tier)
	for league in ordered:
		var season: Season = seasons.get(league.id)
		if season == null:
			continue
		var results: Array = []
		for fx in season.get_current_fixtures():
			if not fx.get("played", false):
				continue
			var home: Club = get_club(fx["home_id"])
			var away: Club = get_club(fx["away_id"])
			results.append({
				"home_id": fx["home_id"],
				"away_id": fx["away_id"],
				"home_name": home.name if home else "?",
				"away_name": away.name if away else "?",
				"home_short": home.short_name if home else "?",
				"away_short": away.short_name if away else "?",
				"home_goals": int(fx.get("home_goals", 0)),
				"away_goals": int(fx.get("away_goals", 0)),
				"home_scorers": fx.get("home_scorers", []).duplicate(true),
				"away_scorers": fx.get("away_scorers", []).duplicate(true),
				"is_player": fx["home_id"] == player_club_id or fx["away_id"] == player_club_id,
			})
		var top_scorers: Array = []
		for cid in league.club_ids:
			var club: Club = get_club(cid)
			if club == null:
				continue
			for p in club.players:
				if p.goals <= 0:
					continue
				top_scorers.append({
					"name": p.display_name(),
					"club": club.short_name,
					"goals": p.goals,
					"assists": p.assists,
					"is_player_club": club.id == player_club_id,
				})
		top_scorers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["goals"]) != int(b["goals"]):
				return int(a["goals"]) > int(b["goals"])
			return int(a["assists"]) > int(b["assists"])
		)
		if top_scorers.size() > 10:
			top_scorers = top_scorers.slice(0, 10)
		var table_rows: Array = []
		var ranked: Array = league.sorted_table()
		for i in ranked.size():
			var row: Dictionary = ranked[i]
			var c: Club = get_club(row["club_id"])
			table_rows.append({
				"pos": i + 1,
				"club_id": row["club_id"],
				"name": c.name if c else str(row["club_id"]),
				"played": int(row["played"]),
				"won": int(row["won"]),
				"drawn": int(row["drawn"]),
				"lost": int(row["lost"]),
				"gf": int(row["gf"]),
				"ga": int(row["ga"]),
				"gd": int(row["gd"]),
				"points": int(row["points"]),
				"is_player": row["club_id"] == player_club_id,
			})
		out.append({
			"league_id": league.id,
			"league_name": league.name,
			"tier": league.tier,
			"matchday": season.current_matchday + 1,
			"total_matchdays": season.total_matchdays,
			"year": season.year,
			"results": results,
			"table": table_rows,
			"top_scorers": top_scorers,
		})
	return out


func advance_after_matchday() -> void:
	var season := player_season()
	if season == null:
		return
	simulate_all_leagues_cpu(true)
	last_matchday_roundup = build_matchday_roundup()

	var player_report_budget_before := 0
	if player_club:
		player_report_budget_before = player_club.budget

	## Ingresos mediáticos + sueldos + préstamo para todos los clubes domésticos.
	for cid in clubs.keys():
		var club: Club = clubs[cid]
		var league: League = leagues.get(club.league_id)
		var media := Finance.apply_media_rights(club, league, cid == player_club_id)
		var wages := Finance.apply_matchday_wages_split(club)
		var loan_pay := ClubFinance.apply_loan_payment(club)
		var medical: Dictionary = Medical.tick_matchday(club, _rng)
		var youth_improved: Array = Youth.develop_matchday(club, _rng)
		_recover_players(club)
		_maybe_training_injury(club)
		_update_happiness(club)
		club.trained_this_matchday = false
		if cid == player_club_id:
			last_matchday_medical = medical
			last_matchday_youth = youth_improved
			var match_income: Dictionary = {}
			if not last_match_summary.is_empty():
				if last_match_summary.get("home_id", "") == player_club_id:
					match_income = last_match_summary.get("home_income", {})
				else:
					match_income = last_match_summary.get("away_income", {})
			last_matchday_finance = Finance.build_player_matchday_finance(
				club, league, match_income, wages, media,
				player_report_budget_before, loan_pay
			)
		## El libro de la jornada se cierra tras liquidar.
		club.reset_matchday_ledger()

	last_matchday_news = NewsService.generate_matchday_digest(self)

	_roll_scout_offer()
	refresh_staff_candidates()

	for lid in seasons.keys():
		var s: Season = seasons[lid]
		if s.finished:
			continue
		s.advance_matchday()
	if player_season() and player_season().finished:
		_finish_remaining_leagues()
		_end_season()
	state_changed.emit()


func _recover_players(club: Club) -> void:
	## La curación de lesiones la lleva el servicio médico; aquí solo forma y descanso.
	var doctor = club.get_staff(StaffScript.Role.DOCTOR)
	var doc_bonus: float = 0.0
	if doctor:
		doc_bonus = float(doctor.skill) * 0.12
	for p in club.players:
		p.stamina = minf(100.0, 55.0 + (100.0 - p.fatigue) * 0.4)
		p.fatigue = maxf(0.0, p.fatigue - (8.0 + doc_bonus + randf_range(0, 4)))
		p.form = clampi(p.form + randi_range(-3, 4), 40, 95)
		p.morale = clampi(p.morale + randi_range(-2, 3), 30, 95)
	for y in club.youth_players:
		y.fatigue = maxf(0.0, y.fatigue - (10.0 + randf_range(0, 5)))
		y.stamina = minf(100.0, 60.0 + (100.0 - y.fatigue) * 0.4)


func _maybe_training_injury(club: Club) -> void:
	## Trabajar con la plantilla fundida cuesta lesiones.
	for p in club.players:
		if p.injured:
			continue
		var risk := 0.004
		if p.fatigue >= 70.0:
			risk += (p.fatigue - 70.0) * 0.0012
		if p.age >= 33:
			risk += 0.003
		if _rng.randf() < risk:
			Medical.assign_injury(p, _rng, false)


func _update_happiness(club: Club) -> void:
	var season := seasons.get(club.league_id) as Season
	var played_mds := 1
	if season:
		played_mds = maxi(1, season.current_matchday + 1)
	for p in club.players:
		var wage_ratio := float(p.salary) / float(maxi(1, p.expected_salary()))
		var wage_mood := 0
		if wage_ratio >= 1.05:
			wage_mood = 4
		elif wage_ratio >= 0.9:
			wage_mood = 1
		elif wage_ratio < 0.7:
			wage_mood = -5
		else:
			wage_mood = -2
		var play_ratio := float(p.matches_played) / float(played_mds)
		var play_mood := 0
		if p.overall() >= 62:
			if play_ratio >= 0.65:
				play_mood = 3
			elif play_ratio < 0.25:
				play_mood = -6
			elif play_ratio < 0.45:
				play_mood = -2
		else:
			if play_ratio >= 0.3:
				play_mood = 2
		p.happiness = clampi(p.happiness + wage_mood + play_mood + randi_range(-1, 1), 15, 100)
		p.morale = clampi(int((p.morale * 0.6) + (p.happiness * 0.4)), 20, 100)


func _roll_scout_offer() -> void:
	var club := player_club
	if club == null:
		return
	if not pending_scout_offer.is_empty():
		return
	var hint: Dictionary = StaffSvc.maybe_scout_find(club, _rng)
	if hint.is_empty():
		return
	var youth := Database.make_youth_prospect(str(hint["region"]), int(hint["scout_skill"]))
	var cost := int(youth.value * (0.7 + _rng.randf_range(0.0, 0.35)))
	pending_scout_offer = {
		"player": youth.to_dict(),
		"cost": cost,
		"region": hint["region"],
	}
	scout_offer_ready.emit(pending_scout_offer)


func accept_scout_offer() -> String:
	if pending_scout_offer.is_empty():
		return "No hay propuesta activa."
	var club := player_club
	var cost: int = int(pending_scout_offer["cost"])
	if club.budget < cost:
		return "Presupuesto insuficiente."
	var p := Player.from_dict(pending_scout_offer["player"])
	club.budget -= cost
	club.transfer_out_acc += cost
	p.club_id = club.id
	var to_youth: bool = p.age < Youth.RETURN_AGE_LIMIT and club.youth_players.size() < Youth.MAX_SQUAD
	if to_youth:
		p.is_youth = true
		p.youth_eligible = true
		club.youth_players.append(p)
	else:
		p.is_youth = false
		club.players.append(p)
		club.bench_ids.append(p.id)
	pending_scout_offer = {}
	state_changed.emit()
	var destino := "fuerzas básicas" if to_youth else "primer equipo"
	return "Fichaste a %s (%s) para %s." % [p.display_name(), p.origin_region, destino]


func reject_scout_offer() -> void:
	pending_scout_offer = {}
	state_changed.emit()


func _finish_remaining_leagues() -> void:
	## Completa jornadas pendientes de otras divisiones (calendarios de distinta longitud).
	for lid in seasons.keys():
		var s: Season = seasons[lid]
		var guard := 0
		while not s.finished and guard < 80:
			_simulate_season_cpu(s, false)
			if not s.advance_matchday():
				break
			guard += 1


func _end_season() -> void:
	_apply_promotion_relegation()
	for cid in clubs.keys():
		var club: Club = clubs[cid]
		var survivors: Array[Player] = []
		for p in club.players:
			p.age += 1
			p.apply_age_decline()
			p.goals = 0
			p.assists = 0
			p.yellow_cards = 0
			p.red_cards = 0
			p.matches_played = 0
			p.fatigue = maxf(0.0, p.fatigue - 20.0)
			p.youth_eligible = p.age < Youth.RETURN_AGE_LIMIT
			if p.should_retire(_rng):
				continue
			survivors.append(p)
		club.players = survivors
		_age_youth_squad(club)
		# Reponer si plantilla corta (nivel acorde a división y reputación)
		var min_size := 20 if leagues[club.league_id].tier <= 1 else 18
		while club.players.size() < min_size:
			var tier: int = leagues[club.league_id].tier
			var base: int = Database.skill_base_for_club(tier, club.reputation)
			var foreigners := club.count_foreigners()
			var np := Database.make_squad_replacement(club.id, base + randi_range(-6, 2), tier, foreigners)
			club.players.append(np)
		club.lineup_ids.clear()
		club.bench_ids.clear()
		club.ensure_default_lineup()

	var old_year := 2026
	var ps := player_season()
	if ps:
		old_year = ps.year
	for lid in leagues.keys():
		var league: League = leagues[lid]
		league.init_standings()
		var season := Season.new()
		season.year = old_year + 1
		season.generate_round_robin(league.club_ids)
		seasons[lid] = season

	season_ended.emit()
	state_changed.emit()


func _age_youth_squad(club: Club) -> void:
	## Los juveniles cumplen años; al pasar de 19 salen de la cantera:
	## los buenos suben al primer equipo, el resto se marcha.
	var league: League = leagues.get(club.league_id)
	var tier: int = league.tier if league else 2
	var staying: Array[Player] = []
	for y in club.youth_players:
		y.age += 1
		y.goals = 0
		y.assists = 0
		y.matches_played = 0
		y.fatigue = maxf(0.0, y.fatigue - 20.0)
		if y.age < 20:
			y.youth_eligible = true
			staying.append(y)
			continue
		var bar := 58 if tier <= 1 else 48
		if y.overall() >= bar:
			y.is_youth = false
			y.youth_eligible = false
			y.club_id = club.id
			y.salary = maxi(y.salary, int(float(y.expected_salary()) * 0.7))
			club.players.append(y)
	club.youth_players = staying
	## Nueva camada para cubrir las bajas.
	while club.youth_players.size() < Youth.MIN_SQUAD:
		club.youth_players.append(Database.make_youth_player(club.id, 30 + int(round(float(club.reputation) * 0.18))))


func _apply_promotion_relegation() -> void:
	var ordered: Array = leagues.values()
	ordered.sort_custom(func(a: League, b: League) -> bool: return a.tier < b.tier)
	# Between adjacent tiers: top 3 up, bottom 3 down
	for i in range(ordered.size() - 1):
		var upper: League = ordered[i]
		var lower: League = ordered[i + 1]
		var upper_table: Array = upper.sorted_table()
		var lower_table: Array = lower.sorted_table()
		var to_relegate: Array = []
		var to_promote: Array = []
		var n_down: int = mini(3, upper_table.size())
		var n_up: int = mini(3, lower_table.size())
		for j in n_down:
			to_relegate.append(upper_table[upper_table.size() - 1 - j]["club_id"])
		for j in n_up:
			to_promote.append(lower_table[j]["club_id"])
		for cid in to_relegate:
			_move_club(cid, upper.id, lower.id)
		for cid in to_promote:
			_move_club(cid, lower.id, upper.id)


func _move_club(club_id: String, from_league_id: String, to_league_id: String) -> void:
	var from_l: League = leagues[from_league_id]
	var to_l: League = leagues[to_league_id]
	from_l.club_ids.erase(club_id)
	if not to_l.club_ids.has(club_id):
		to_l.club_ids.append(club_id)
	var club: Club = clubs[club_id]
	club.league_id = to_league_id
	if to_l.tier < from_l.tier:
		club.reputation = mini(99, club.reputation + 4)
		club.budget += 80000
	else:
		club.reputation = maxi(20, club.reputation - 3)


func save_game() -> bool:
	var clubs_data: Dictionary = {}
	for cid in clubs.keys():
		clubs_data[cid] = (clubs[cid] as Club).to_dict()
	var foreign_data: Dictionary = {}
	for cid in foreign_clubs.keys():
		foreign_data[cid] = (foreign_clubs[cid] as Club).to_dict()
	var leagues_data: Dictionary = {}
	for lid in leagues.keys():
		leagues_data[lid] = (leagues[lid] as League).to_dict()
	var seasons_data: Dictionary = {}
	for lid in seasons.keys():
		seasons_data[lid] = (seasons[lid] as Season).to_dict()
	var fa: Array = []
	for p in free_agents:
		fa.append(p.to_dict())
	var candidates_data: Dictionary = {}
	for key in staff_candidates.keys():
		var arr: Array = []
		for member in staff_candidates[key]:
			arr.append(member.to_dict())
		candidates_data[key] = arr
	var data := {
		"player_club_id": player_club_id,
		"career_started": career_started,
		"coach_name": coach_name,
		"staff_candidates": candidates_data,
		"clubs": clubs_data,
		"foreign_clubs": foreign_data,
		"leagues": leagues_data,
		"seasons": seasons_data,
		"free_agents": fa,
		"last_match_summary": last_match_summary,
		"pending_scout_offer": pending_scout_offer,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	if data == null:
		return false
	clubs.clear()
	for cid in data.get("clubs", {}).keys():
		clubs[cid] = Club.from_dict(data["clubs"][cid])
	foreign_clubs.clear()
	for cid in data.get("foreign_clubs", {}).keys():
		foreign_clubs[cid] = Club.from_dict(data["foreign_clubs"][cid])
	## Partidas antiguas sin mercado internacional: regenerar.
	if foreign_clubs.is_empty() and not Database.foreign_clubs_template.is_empty():
		var existing_players: Array = []
		for cid in clubs.keys():
			existing_players.append_array(clubs[cid].players)
		existing_players.append_array(free_agents)
		Database.bump_player_counter_from_players([existing_players])
		foreign_clubs = Database._create_foreign_market_clubs()
	else:
		var all_p: Array = []
		for cid in clubs.keys():
			all_p.append_array(clubs[cid].players)
			all_p.append_array(clubs[cid].youth_players)
		for cid in foreign_clubs.keys():
			all_p.append_array(foreign_clubs[cid].players)
		all_p.append_array(free_agents)
		Database.bump_player_counter_from_players([all_p])
	leagues.clear()
	for lid in data.get("leagues", {}).keys():
		leagues[lid] = League.from_dict(data["leagues"][lid])
	seasons.clear()
	for lid in data.get("seasons", {}).keys():
		seasons[lid] = Season.from_dict(data["seasons"][lid])
	free_agents.clear()
	for pd in data.get("free_agents", []):
		free_agents.append(Player.from_dict(pd))
	player_club_id = data.get("player_club_id", "")
	career_started = bool(data.get("career_started", true))
	last_match_summary = data.get("last_match_summary", {})
	pending_scout_offer = data.get("pending_scout_offer", {})
	coach_name = str(data.get("coach_name", ""))
	if coach_name.strip_edges() == "":
		coach_name = Database.random_coach_name()
	staff_candidates.clear()
	var candidates_data: Dictionary = data.get("staff_candidates", {})
	for key in candidates_data.keys():
		var arr: Array = []
		for md in candidates_data[key]:
			arr.append(StaffScript.from_dict(md))
		staff_candidates[str(key)] = arr
	if staff_candidates.is_empty():
		refresh_staff_candidates()
	_ensure_youth_squads()
	state_changed.emit()
	return true


func _ensure_youth_squads() -> void:
	## Partidas anteriores a las fuerzas básicas: crear la camada inicial.
	for cid in clubs.keys():
		var club: Club = clubs[cid]
		if not club.youth_players.is_empty():
			continue
		var league: League = leagues.get(club.league_id)
		var tier: int = league.tier if league else 2
		club.youth_players = Database.generate_youth_squad(club.id, tier, club.reputation)
