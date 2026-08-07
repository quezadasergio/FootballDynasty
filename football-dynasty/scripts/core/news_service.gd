class_name NewsService
extends RefCounted

const TV_OUTLETS: Array[String] = ["TUDN", "ESPN México", "Azteca Deportes", "Fox Sports MX", "Claro Sports"]
const RADIO_OUTLETS: Array[String] = ["W Deportes", "Radio Fórmula Deportes", "Imagen Radio", "Stereo Cien Deportes"]
const WEB_OUTLETS: Array[String] = ["MedioTiempo", "Récord.com", "SoyFútbol", "Goal México", "Transfermarkt MX"]
const NATIONAL_PRESS: Array[String] = ["Reforma", "El Universal", "Milenio", "La Jornada", "Excélsior"]
const LOCAL_PRESS: Array[String] = [
	"Diario Local Deportivo", "Crónica Regional", "El Sol Deportivo", "La Voz del Estadio", "Noticias del Club"
]


## Titulares sobre el entrenador. %s se sustituye por su nombre y el club.
const COACH_GOOD_HEADLINES: Array[String] = [
	"Un gran trabajo del DT %s",
	"%s tiene al %s en modo campeón",
	"La mano de %s ya se nota en el %s",
	"%s, el técnico del momento",
	"El %s cree: %s encontró la fórmula",
	"Ovación para %s en el %s",
]

const COACH_BAD_HEADLINES: Array[String] = [
	"Crece la presión sobre %s",
	"¿Está en riesgo el puesto de %s en el %s?",
	"El %s no arranca y %s queda en el ojo del huracán",
	"La afición pide explicaciones a %s",
	"Fracaso en el %s: se cuestiona el proyecto de %s",
	"%s, sin respuestas ante la crisis del %s",
]

const COACH_NEUTRAL_HEADLINES: Array[String] = [
	"%s pide calma en el %s",
	"%s: «Vamos partido a partido»",
	"El proyecto de %s en el %s, a media construcción",
	"%s ajusta piezas en el %s",
]


static func generate_matchday_digest(game_state: Node) -> Array:
	## Lista de {medium, outlet, headline, body} — más cobertura a Liga MX.
	var news: Array = []
	var rng: RandomNumberGenerator = game_state._rng
	var player_club: Club = game_state.player_club
	if player_club == null:
		return news

	var player_league: League = game_state.player_league()
	var player_season: Season = game_state.player_season()
	var summary: Dictionary = game_state.last_match_summary

	## Noticias del club del jugador (siempre).
	_append_player_club_news(news, rng, game_state, player_club, player_league, summary)
	_append_coach_news(news, rng, game_state, player_club, player_league, summary)
	_append_youth_news(news, rng, game_state, player_club)
	_append_contract_news(news, rng, game_state, player_club)

	## Cobertura por liga: 1ª mucha, 2ª poca.
	for lid in game_state.leagues.keys():
		var league: League = game_state.leagues[lid]
		var season: Season = game_state.seasons.get(lid)
		if season == null:
			continue
		var count := 5 if league.tier <= 1 else 2
		if league.id == player_club.league_id:
			count += 1
		_append_league_roundup(news, rng, game_state, league, season, count, player_club.id)

	## Notas de prensa local / nacional genéricas.
	_append_press_notes(news, rng, player_club, player_league)

	## Mezclar un poco el orden pero dejando primero las del club propio.
	var own: Array = []
	var rest: Array = []
	for n in news:
		if n.get("about_player", false):
			own.append(n)
		else:
			rest.append(n)
	rest.shuffle()
	var ordered: Array = []
	ordered.append_array(own)
	ordered.append_array(rest)
	## Limitar volumen total.
	if ordered.size() > 14:
		ordered = ordered.slice(0, 14)
	return ordered


static func _append_player_club_news(
	news: Array,
	rng: RandomNumberGenerator,
	game_state: Node,
	club: Club,
	league: League,
	summary: Dictionary
) -> void:
	var pos := _table_position(league, club.id)
	var pts := 0
	if league and league.standings.has(club.id):
		pts = int(league.standings[club.id].get("points", 0))

	if not summary.is_empty():
		var home: Club = game_state.get_club(summary["home_id"])
		var away: Club = game_state.get_club(summary["away_id"])
		var hg: int = int(summary["home_goals"])
		var ag: int = int(summary["away_goals"])
		var is_home: bool = str(summary["home_id"]) == club.id
		var my_g: int = hg if is_home else ag
		var their_g: int = ag if is_home else hg
		var opp: Club = away if is_home else home
		var result_word: String = "empate"
		if my_g > their_g:
			result_word = "victoria"
		elif my_g < their_g:
			result_word = "derrota"
		var score_line := "%s %d-%d %s" % [home.name if home else "?", hg, ag, away.name if away else "?"]
		news.append(_item(
			"TV", TV_OUTLETS[rng.randi_range(0, TV_OUTLETS.size() - 1)],
			"%s: %s ante %s" % [club.name, result_word, opp.name if opp else "rival"],
			"Transmisión en vivo. Marcador final %s. %s queda en la posición %d con %d pts." % [
				score_line, club.name, pos, pts
			],
			true
		))
		news.append(_item(
			"Radio", RADIO_OUTLETS[rng.randi_range(0, RADIO_OUTLETS.size() - 1)],
			"Análisis: el %s y su %s" % [club.short_name, result_word],
			"En la mesa deportiva debaten el rendimiento del %s. %s de %d-%d frente a %s." % [
				club.name, result_word.capitalize(), my_g, their_g, opp.name if opp else "el rival"
			],
			true
		))
		news.append(_item(
			"Internet", WEB_OUTLETS[rng.randi_range(0, WEB_OUTLETS.size() - 1)],
			"Lo que se dice en redes del %s" % club.short_name,
			"Fans reaccionan al %d-%d. Tendencia: «%s» y el cuerpo técnico bajo la lupa." % [
				my_g, their_g, club.short_name
			],
			true
		))
	else:
		news.append(_item(
			"Internet", WEB_OUTLETS[rng.randi_range(0, WEB_OUTLETS.size() - 1)],
			"%s sin titulares de partido" % club.name,
			"La jornada avanza y el club se concentra en entrenamiento y planificación.",
			true
		))

	## Lesiones / plantilla.
	var injured: Array = []
	for p in club.players:
		if p.injured:
			injured.append("%s (%s, %d jor.)" % [p.display_name(), p.injury_name, p.injury_matchdays])
	if injured.size() > 0:
		var inj_txt := ""
		for i in mini(3, injured.size()):
			if i > 0:
				inj_txt += "; "
			inj_txt += str(injured[i])
		news.append(_item(
			"Prensa local", LOCAL_PRESS[rng.randi_range(0, LOCAL_PRESS.size() - 1)],
			"Parte médico en el %s" % club.short_name,
			"Baja(s) reportada(s): %s. El cuerpo médico define cirugías y tratamientos." % inj_txt,
			true
		))

	## Posición en tabla.
	if league:
		var zone := ""
		if league.tier > 1 and pos <= 3:
			zone = "zona de ascenso"
		elif league.tier == 1 and pos > league.club_ids.size() - 3:
			zone = "zona de descenso"
		elif pos <= 4:
			zone = "zona alta"
		else:
			zone = "media tabla"
		news.append(_item(
			"Prensa nacional", NATIONAL_PRESS[rng.randi_range(0, NATIONAL_PRESS.size() - 1)],
			"%s en %s (%dº)" % [club.name, zone, pos],
			"La clasificación de %s muestra al %s con %d puntos tras la jornada." % [
				league.name, club.name, pts
			],
			true
		))


static func _coach_mood(league: League, club: Club, summary: Dictionary) -> int:
	## -1 mala racha · 0 normal · 1 buen momento.
	var score := 0
	if not summary.is_empty():
		var is_home: bool = str(summary.get("home_id", "")) == club.id
		var mine: int = int(summary.get("home_goals", 0)) if is_home else int(summary.get("away_goals", 0))
		var theirs: int = int(summary.get("away_goals", 0)) if is_home else int(summary.get("home_goals", 0))
		if mine > theirs:
			score += 2
		elif mine < theirs:
			score -= 2
		if theirs - mine >= 3:
			score -= 1
		elif mine - theirs >= 3:
			score += 1
	if league:
		var pos := _table_position(league, club.id)
		var total: int = league.club_ids.size()
		if pos > 0:
			if pos <= 4:
				score += 1
			elif pos > total - 4:
				score -= 1
	if score >= 2:
		return 1
	if score <= -2:
		return -1
	return 0


static func _append_coach_news(
	news: Array,
	rng: RandomNumberGenerator,
	game_state: Node,
	club: Club,
	league: League,
	summary: Dictionary
) -> void:
	var coach: String = str(game_state.coach_name)
	if coach.strip_edges() == "":
		return
	var mood := _coach_mood(league, club, summary)
	var pos := _table_position(league, club.id)
	var headline := ""
	var body := ""
	match mood:
		1:
			headline = COACH_GOOD_HEADLINES[rng.randi_range(0, COACH_GOOD_HEADLINES.size() - 1)]
			body = "Los analistas destacan la lectura de partido de %s. El %s marcha %dº y el vestidor respalda al cuerpo técnico." % [
				coach, club.name, pos
			]
		-1:
			headline = COACH_BAD_HEADLINES[rng.randi_range(0, COACH_BAD_HEADLINES.size() - 1)]
			body = "En la mesa se cuestionan las decisiones de %s. El %s aparece %dº y la directiva guarda silencio." % [
				coach, club.name, pos
			]
		_:
			headline = COACH_NEUTRAL_HEADLINES[rng.randi_range(0, COACH_NEUTRAL_HEADLINES.size() - 1)]
			body = "%s insiste en el trabajo diario. El %s ocupa el lugar %d de la tabla." % [
				coach, club.name, pos
			]
	## Los titulares llevan uno o dos huecos: nombre del DT y, a veces, el club.
	if headline.count("%s") >= 2:
		if headline.begins_with("El %s") or headline.begins_with("Fracaso"):
			headline = headline % [club.short_name, coach]
		else:
			headline = headline % [coach, club.short_name]
	else:
		headline = headline % coach

	var medium := "Prensa nacional"
	var outlet: String = NATIONAL_PRESS[rng.randi_range(0, NATIONAL_PRESS.size() - 1)]
	var roll := rng.randf()
	if roll < 0.3:
		medium = "Radio"
		outlet = RADIO_OUTLETS[rng.randi_range(0, RADIO_OUTLETS.size() - 1)]
	elif roll < 0.6:
		medium = "Internet"
		outlet = WEB_OUTLETS[rng.randi_range(0, WEB_OUTLETS.size() - 1)]
	news.append(_item(medium, outlet, headline, body, true))

	## De vez en cuando, una segunda nota de opinión sobre el técnico.
	if rng.randf() < 0.45:
		var extra_body := ""
		match mood:
			1:
				extra_body = "Columna de opinión: «%s ha ordenado al %s. Si mantiene el bloque, pelea arriba»." % [coach, club.short_name]
			-1:
				extra_body = "Columna de opinión: «El %s necesita reaccionar. La paciencia con %s se agota»." % [club.short_name, coach]
			_:
				extra_body = "Columna de opinión: «%s todavía busca su once ideal en el %s»." % [coach, club.short_name]
		news.append(_item(
			"Prensa local", LOCAL_PRESS[rng.randi_range(0, LOCAL_PRESS.size() - 1)],
			"Opinión: el momento de %s" % coach, extra_body, true
		))


static func _append_youth_news(news: Array, rng: RandomNumberGenerator, game_state: Node, club: Club) -> void:
	var improved: Array = game_state.last_matchday_youth
	if improved.is_empty() or rng.randf() > 0.6:
		return
	var names := ""
	for i in mini(3, improved.size()):
		if i > 0:
			names += ", "
		names += str(improved[i])
	news.append(_item(
		"Internet", WEB_OUTLETS[rng.randi_range(0, WEB_OUTLETS.size() - 1)],
		"Cantera del %s: nombres que suben" % club.short_name,
		"En fuerzas básicas destacan %s. El cuerpo técnico sigue su evolución de cerca." % names,
		true
	))


static func _append_contract_news(news: Array, rng: RandomNumberGenerator, game_state: Node, club: Club) -> void:
	## La prensa se ceba con los contratos: vencimientos, transferibles y estrellas.
	var expiring: PackedStringArray = []
	var listed: PackedStringArray = []
	var no_contract: PackedStringArray = []
	for p in club.players:
		if not p.has_contract():
			no_contract.append(p.display_name())
		elif p.contract_years_left <= 1:
			expiring.append(p.display_name())
		if p.transfer_listed:
			listed.append(p.display_name())

	if not no_contract.is_empty():
		news.append(_item(
			"Prensa nacional", NATIONAL_PRESS[rng.randi_range(0, NATIONAL_PRESS.size() - 1)],
			"Lío contractual en el %s" % club.short_name,
			"Hay futbolistas sin contrato vigente: %s. La liga exige regularizar la situación antes de la próxima jornada." % ", ".join(no_contract),
			true
		))
	if not listed.is_empty() and rng.randf() < 0.7:
		news.append(_item(
			"Internet", WEB_OUTLETS[rng.randi_range(0, WEB_OUTLETS.size() - 1)],
			"El %s pone en el mercado a %d jugador(es)" % [club.short_name, listed.size()],
			"Fuentes cercanas al club señalan como transferibles a %s. Se esperan ofertas en los próximos días." % ", ".join(listed),
			true
		))
	if not expiring.is_empty() and rng.randf() < 0.5:
		var who: String = expiring[rng.randi_range(0, expiring.size() - 1)]
		news.append(_item(
			"Radio", RADIO_OUTLETS[rng.randi_range(0, RADIO_OUTLETS.size() - 1)],
			"%s entra en su último año de contrato" % who,
			"En el %s se habla de renovación. El entorno del jugador escucha propuestas mientras la directiva calcula el esfuerzo salarial." % club.name,
			true
		))


static func _append_league_roundup(
	news: Array,
	rng: RandomNumberGenerator,
	game_state: Node,
	league: League,
	season: Season,
	count: int,
	player_club_id: String
) -> void:
	var fixtures: Array = season.get_current_fixtures()
	var played: Array = []
	for fx in fixtures:
		if fx.get("played", false):
			played.append(fx)
	if played.is_empty():
		return
	played.shuffle()
	var added := 0
	for fx in played:
		if added >= count:
			break
		if fx["home_id"] == player_club_id or fx["away_id"] == player_club_id:
			continue ## ya cubierto en noticias del club
		var home: Club = game_state.get_club(fx["home_id"])
		var away: Club = game_state.get_club(fx["away_id"])
		if home == null or away == null:
			continue
		var hg: int = int(fx["home_goals"])
		var ag: int = int(fx["away_goals"])
		var medium := "TV" if league.tier <= 1 else "Internet"
		var outlet: String
		if league.tier <= 1:
			outlet = TV_OUTLETS[rng.randi_range(0, TV_OUTLETS.size() - 1)] if rng.randf() < 0.55 else WEB_OUTLETS[rng.randi_range(0, WEB_OUTLETS.size() - 1)]
			medium = "TV" if outlet in TV_OUTLETS else "Internet"
		else:
			outlet = WEB_OUTLETS[rng.randi_range(0, WEB_OUTLETS.size() - 1)] if rng.randf() < 0.6 else LOCAL_PRESS[rng.randi_range(0, LOCAL_PRESS.size() - 1)]
			medium = "Internet" if outlet in WEB_OUTLETS else "Prensa local"
		var tag := "Liga MX" if league.tier <= 1 else "Expansión"
		var headline := "%s: %s %d-%d %s" % [tag, home.short_name, hg, ag, away.short_name]
		var body := "En %s, %s recibió a %s y el marcador terminó %d-%d." % [
			league.name, home.name, away.name, hg, ag
		]
		if abs(hg - ag) >= 3:
			body += " Goleada que da de qué hablar en los medios."
		elif hg == ag:
			body += " Reparto de puntos."
		news.append(_item(medium, outlet, headline, body, false))
		added += 1

	## Nota de tabla general (más en 1ª).
	if league.tier <= 1 or rng.randf() < 0.45:
		var table: Array = league.sorted_table()
		if table.size() >= 3:
			var top: Club = game_state.get_club(table[0]["club_id"])
			var second: Club = game_state.get_club(table[1]["club_id"])
			news.append(_item(
				"Prensa nacional" if league.tier <= 1 else "Internet",
				NATIONAL_PRESS[rng.randi_range(0, NATIONAL_PRESS.size() - 1)] if league.tier <= 1 else WEB_OUTLETS[rng.randi_range(0, WEB_OUTLETS.size() - 1)],
				"Tabla %s: lidera %s" % [league.name, top.short_name if top else "?"],
				"%s comanda con %d pts; %s acecha con %d. La pelea por el título (o el ascenso) sigue abierta." % [
					top.name if top else "?", int(table[0]["points"]),
					second.name if second else "?", int(table[1]["points"])
				],
				false
			))


static func _append_press_notes(news: Array, rng: RandomNumberGenerator, club: Club, league: League) -> void:
	news.append(_item(
		"Prensa local",
		LOCAL_PRESS[rng.randi_range(0, LOCAL_PRESS.size() - 1)],
		"Ambiente en la afición del %s" % club.short_name,
		"Comerciantes y aficionados locales comentan la jornada del %s en %s. Expectativa por el próximo partido en casa." % [
			club.name, league.name if league else "la liga"
		],
		true
	))
	if league and league.tier <= 1:
		news.append(_item(
			"Radio",
			RADIO_OUTLETS[rng.randi_range(0, RADIO_OUTLETS.size() - 1)],
			"Derechos y audiencia de Liga MX",
			"Las emisoras destacan el interés por la jornada. Clubs como %s concentran minutos al aire." % club.name,
			false
		))


static func _table_position(league: League, club_id: String) -> int:
	if league == null:
		return 0
	var table: Array = league.sorted_table()
	for i in table.size():
		if table[i]["club_id"] == club_id:
			return i + 1
	return 0


static func _item(medium: String, outlet: String, headline: String, body: String, about_player: bool) -> Dictionary:
	return {
		"medium": medium,
		"outlet": outlet,
		"headline": headline,
		"body": body,
		"about_player": about_player,
	}
