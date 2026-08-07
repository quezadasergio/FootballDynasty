class_name MatchEngine
extends RefCounted

signal event_generated(event: MatchEvent)
signal match_finished(home_goals: int, away_goals: int)

const MedicalSvc = preload("res://scripts/core/medical_service.gd")

var home: Club
var away: Club
var home_goals: int = 0
var away_goals: int = 0
var minute: int = 0
var paused: bool = false
var finished: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## [{name, minute, assist}] por equipo
var home_goal_scorers: Array = []
var away_goal_scorers: Array = []

var _home_lineup: Array[Player] = []
var _away_lineup: Array[Player] = []
var _subs_used_home: int = 0
var _subs_used_away: int = 0
const MAX_SUBS := 5


func setup(home_club: Club, away_club: Club, seed_value: int = 0) -> void:
	home = home_club
	away = away_club
	home.ensure_default_lineup()
	away.ensure_default_lineup()
	_home_lineup = home.get_lineup_players()
	_away_lineup = away.get_lineup_players()
	home_goals = 0
	away_goals = 0
	home_goal_scorers.clear()
	away_goal_scorers.clear()
	minute = 0
	paused = false
	finished = false
	_subs_used_home = 0
	_subs_used_away = 0
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for p in _home_lineup + _away_lineup:
		p.stamina = maxf(35.0, 100.0 - p.fatigue * 0.35)


func set_mentality(club_id: String, mentality: int) -> void:
	if club_id == home.id:
		home.mentality = mentality
	elif club_id == away.id:
		away.mentality = mentality


func make_substitution(club_id: String, out_id: String, in_id: String) -> String:
	var is_home := club_id == home.id
	var club: Club = home if is_home else away
	var lineup: Array[Player] = _home_lineup if is_home else _away_lineup
	var used: int = _subs_used_home if is_home else _subs_used_away
	if used >= MAX_SUBS:
		return "No quedan cambios."
	var out_p: Player = null
	var out_idx := -1
	for i in lineup.size():
		if lineup[i].id == out_id:
			out_p = lineup[i]
			out_idx = i
			break
	if out_p == null:
		return "Jugador titular no encontrado."
	if not club.bench_ids.has(in_id):
		return "El suplente no está en el banquillo."
	var in_p := club.get_player(in_id)
	if in_p == null or in_p.injured:
		return "Suplente no disponible."
	lineup[out_idx] = in_p
	club.lineup_ids[out_idx] = in_id
	club.bench_ids.erase(in_id)
	club.bench_ids.append(out_id)
	if is_home:
		_home_lineup = lineup
		_subs_used_home += 1
	else:
		_away_lineup = lineup
		_subs_used_away += 1
	var ev := _make_event(MatchEvent.Type.COMMENTARY, club_id, in_id, "%s entra por %s." % [in_p.display_name(), out_p.display_name()])
	event_generated.emit(ev)
	return ""


func simulate_full() -> Array[MatchEvent]:
	var events: Array[MatchEvent] = []
	while not finished:
		var batch := tick()
		for e in batch:
			events.append(e)
	return events


func tick() -> Array[MatchEvent]:
	var events: Array[MatchEvent] = []
	if finished or paused:
		return events
	minute += 1
	_decay_stamina()
	if minute == 45:
		var ht := _make_event(MatchEvent.Type.HALFTIME, "", "", "Descanso. %d-%d" % [home_goals, away_goals])
		events.append(ht)
		event_generated.emit(ht)
		return events
	if minute == 90:
		# stoppage
		pass
	if minute > 90 + rng.randi_range(1, 4):
		_apply_post_match_load()
		var ft := _make_event(MatchEvent.Type.FULLTIME, "", "", "Final del partido. %d-%d" % [home_goals, away_goals])
		events.append(ft)
		event_generated.emit(ft)
		finished = true
		match_finished.emit(home_goals, away_goals)
		return events

	# AI substitutions around 60-75
	if minute == 65 and away.id != GameState.player_club_id:
		_ai_maybe_sub(away)
	if minute == 70 and home.id != GameState.player_club_id:
		_ai_maybe_sub(home)

	var home_att := _attack_rating(_home_lineup, home.mentality, true)
	var away_att := _attack_rating(_away_lineup, away.mentality, false)
	var home_def := _defense_rating(_home_lineup, home.mentality)
	var away_def := _defense_rating(_away_lineup, away.mentality)

	# Chance each minute
	var home_chance := clampf((home_att - away_def * 0.85) / 120.0, 0.02, 0.18)
	var away_chance := clampf((away_att - home_def * 0.85) / 120.0, 0.02, 0.16)

	if rng.randf() < home_chance:
		events.append_array(_resolve_chance(true))
	elif rng.randf() < away_chance:
		events.append_array(_resolve_chance(false))
	elif rng.randf() < 0.015:
		events.append_array(_random_card())
	elif rng.randf() < 0.004:
		events.append_array(_random_injury())

	return events


func _ai_maybe_sub(club: Club) -> void:
	if club == null:
		return
	var is_home := club.id == home.id
	var used := _subs_used_home if is_home else _subs_used_away
	if used >= MAX_SUBS:
		return
	var lineup: Array[Player] = _home_lineup if is_home else _away_lineup
	var bench := club.get_bench_players()
	if bench.is_empty() or lineup.is_empty():
		return
	# Sub lowest stamina out for best bench
	var worst: Player = lineup[0]
	for p in lineup:
		if p.stamina < worst.stamina:
			worst = p
	if worst.stamina > 55:
		return
	bench.sort_custom(func(a: Player, b: Player) -> bool: return a.overall() > b.overall())
	make_substitution(club.id, worst.id, bench[0].id)


func _apply_post_match_load() -> void:
	for p in _home_lineup:
		p.matches_played += 1
		p.fatigue = minf(100.0, p.fatigue + rng.randf_range(10.0, 18.0) + (100.0 - p.stamina) * 0.08)
	for p in _away_lineup:
		p.matches_played += 1
		p.fatigue = minf(100.0, p.fatigue + rng.randf_range(10.0, 18.0) + (100.0 - p.stamina) * 0.08)


func _attack_rating(lineup: Array[Player], mentality: int, is_home: bool) -> float:
	var sum := 0.0
	var count := 0
	for p in lineup:
		if p.position == Player.Position.GK:
			continue
		var base := 0.0
		match p.position:
			Player.Position.ATT:
				base = p.attack * 1.0 + p.speed * 0.35 + p.talent * 0.25 + p.physical * 0.15
			Player.Position.MID:
				base = p.midfield * 0.65 + p.attack * 0.35 + p.speed * 0.25 + p.talent * 0.2
			Player.Position.DEF:
				base = p.attack * 0.2 + p.midfield * 0.25 + p.speed * 0.2
		base *= p.performance_modifier() * (p.stamina / 100.0)
		sum += base
		count += 1
	var rating: float = sum / float(maxi(count, 1))
	var ment_mod: Array[float] = [0.85, 1.0, 1.15]
	rating *= ment_mod[clampi(mentality, 0, 2)]
	if is_home:
		rating *= 1.06
	return rating


func _defense_rating(lineup: Array[Player], mentality: int) -> float:
	var sum := 0.0
	var count := 0
	for p in lineup:
		var base := 0.0
		match p.position:
			Player.Position.GK:
				base = p.defense * 1.15 + p.physical * 0.25 + p.talent * 0.2
			Player.Position.DEF:
				base = p.defense * 1.05 + p.strength * 0.3 + p.physical * 0.2 + p.speed * 0.15
			Player.Position.MID:
				base = p.defense * 0.55 + p.midfield * 0.35 + p.strength * 0.15
			Player.Position.ATT:
				base = p.defense * 0.2 + p.speed * 0.1
		base *= p.performance_modifier() * (p.stamina / 100.0)
		sum += base
		count += 1
	var rating: float = sum / float(maxi(count, 1))
	var ment_mod: Array[float] = [1.15, 1.0, 0.88]
	rating *= ment_mod[clampi(mentality, 0, 2)]
	return rating


func _resolve_chance(for_home: bool) -> Array[MatchEvent]:
	var events: Array[MatchEvent] = []
	var club: Club = home if for_home else away
	var lineup: Array[Player] = _home_lineup if for_home else _away_lineup
	var opp_lineup: Array[Player] = _away_lineup if for_home else _home_lineup
	var attackers: Array[Player] = []
	for p in lineup:
		if p.position == Player.Position.ATT or p.position == Player.Position.MID:
			attackers.append(p)
	if attackers.is_empty():
		attackers = lineup.duplicate()
	var shooter: Player = attackers[rng.randi_range(0, attackers.size() - 1)]
	var gk: Player = null
	for p in opp_lineup:
		if p.position == Player.Position.GK:
			gk = p
			break
	var chance_ev := _make_event(MatchEvent.Type.CHANCE, club.id, shooter.id, "Ocasión de %s (%s)." % [shooter.display_name(), club.short_name])
	events.append(chance_ev)
	event_generated.emit(chance_ev)

	var finish := (shooter.attack + shooter.form * 0.3) / 100.0
	var save := 0.45
	if gk:
		save = (gk.defense + gk.physical * 0.2) / 140.0
	var goal_prob := clampf(finish * 0.55 - save * 0.35 + 0.22, 0.12, 0.55)
	if rng.randf() < goal_prob:
		if for_home:
			home_goals += 1
		else:
			away_goals += 1
		shooter.goals += 1
		var assister: Player = null
		if attackers.size() > 1 and rng.randf() < 0.6:
			assister = attackers[rng.randi_range(0, attackers.size() - 1)]
			if assister.id == shooter.id:
				assister = null
			else:
				assister.assists += 1
		var goal := _make_event(MatchEvent.Type.GOAL, club.id, shooter.id, "¡GOL de %s! %d-%d" % [shooter.display_name(), home_goals, away_goals])
		if assister:
			goal.assist_id = assister.id
			goal.text = "¡GOL de %s! Asistencia de %s. %d-%d" % [shooter.display_name(), assister.display_name(), home_goals, away_goals]
		var scorer_entry := {
			"name": shooter.display_name(),
			"minute": minute,
			"assist": assister.display_name() if assister else "",
		}
		if for_home:
			home_goal_scorers.append(scorer_entry)
		else:
			away_goal_scorers.append(scorer_entry)
		events.append(goal)
		event_generated.emit(goal)
	else:
		var miss := _make_event(MatchEvent.Type.COMMENTARY, club.id, shooter.id, "Remate de %s... ¡fuera!" % shooter.display_name())
		if gk and rng.randf() < 0.5:
			miss.text = "%s detiene el disparo de %s." % [gk.display_name(), shooter.display_name()]
		events.append(miss)
		event_generated.emit(miss)
	return events


func _random_card() -> Array[MatchEvent]:
	var events: Array[MatchEvent] = []
	var for_home := rng.randf() < 0.5
	var club: Club = home if for_home else away
	var lineup: Array[Player] = _home_lineup if for_home else _away_lineup
	if lineup.is_empty():
		return events
	var p: Player = lineup[rng.randi_range(0, lineup.size() - 1)]
	var red := rng.randf() < 0.12
	if red:
		p.red_cards += 1
		var ev := _make_event(MatchEvent.Type.CARD_RED, club.id, p.id, "Roja para %s." % p.display_name())
		events.append(ev)
		event_generated.emit(ev)
		# Remove from lineup
		for i in lineup.size():
			if lineup[i].id == p.id:
				lineup.remove_at(i)
				break
		if for_home:
			_home_lineup = lineup
		else:
			_away_lineup = lineup
	else:
		p.yellow_cards += 1
		var ev2 := _make_event(MatchEvent.Type.CARD_YELLOW, club.id, p.id, "Amarilla para %s." % p.display_name())
		events.append(ev2)
		event_generated.emit(ev2)
	return events


func _random_injury() -> Array[MatchEvent]:
	var events: Array[MatchEvent] = []
	var for_home := rng.randf() < 0.5
	var club: Club = home if for_home else away
	var lineup: Array[Player] = _home_lineup if for_home else _away_lineup
	if lineup.is_empty():
		return events
	var p: Player = lineup[rng.randi_range(0, lineup.size() - 1)]
	MedicalSvc.assign_injury(p, rng, true)
	var ev := _make_event(
		MatchEvent.Type.INJURY, club.id, p.id,
		"%s se lesiona: %s. Baja estimada: %d jornadas." % [
			p.display_name(), p.injury_name, p.injury_matchdays
		]
	)
	events.append(ev)
	event_generated.emit(ev)
	# Force sub if possible
	var bench := club.get_bench_players()
	if not bench.is_empty():
		make_substitution(club.id, p.id, bench[0].id)
	return events


func _decay_stamina() -> void:
	for p in _home_lineup:
		p.stamina = maxf(20.0, p.stamina - rng.randf_range(0.15, 0.35) * (1.0 + home.mentality * 0.1))
	for p in _away_lineup:
		p.stamina = maxf(20.0, p.stamina - rng.randf_range(0.15, 0.35) * (1.0 + away.mentality * 0.1))


func _make_event(type: MatchEvent.Type, team_id: String, player_id: String, text: String) -> MatchEvent:
	var e := MatchEvent.new()
	e.type = type
	e.minute = minute
	e.team_id = team_id
	e.player_id = player_id
	e.home_goals = home_goals
	e.away_goals = away_goals
	e.text = text
	return e
