class_name ContractService
extends RefCounted

## Contratos de jugadores: duración en temporadas, bono de firma y sueldo anual
## que se liquida jornada a jornada. El sueldo por jornada (`Player.salary`)
## sigue siendo el coste real; el anual es la unidad de negociación.

const StaffScript = preload("res://scripts/core/staff_member.gd")

const MIN_YEARS := 1
const MAX_YEARS := 6
## Por debajo de este tirón comercial el jugador no mueve publicidad.
const MARKETING_FLOOR := 45
## Al rescindir se paga esta parte de lo que faltaba por pagar.
const RELEASE_RATIO := 0.35
## Nunca se puede bajar de aquí al rescindir contratos.
const MIN_SQUAD_AFTER_RELEASE := 14


static func annual_from_matchday(per_matchday: int) -> int:
	return per_matchday * Player.MATCHDAYS_PER_YEAR


static func matchday_from_annual(annual: int) -> int:
	return maxi(1, int(round(float(annual) / float(Player.MATCHDAYS_PER_YEAR))))


static func expected_annual(p: Player) -> int:
	return annual_from_matchday(p.expected_salary())


static func _quirk(p: Player) -> float:
	## Rasgo estable por jugador: sus exigencias no cambian entre pantallas.
	return float(absi(hash(p.id)) % 1000) / 1000.0


static func desired_years(p: Player) -> int:
	var quirk := _quirk(p)
	var years := 3
	if p.age <= 21:
		years = 5
	elif p.age <= 25:
		years = 4
	elif p.age <= 29:
		years = 3
	elif p.age <= 32:
		years = 2
	else:
		years = 1
	if quirk > 0.72:
		years += 1
	elif quirk < 0.18:
		years -= 1
	return clampi(years, MIN_YEARS, MAX_YEARS)


static func demands(p: Player, club: Club) -> Dictionary:
	## Lo que el jugador pide para firmar. Determinista: la misma oferta siempre
	## recibe la misma respuesta.
	var ovr := p.overall()
	var quirk := _quirk(p)
	var base := expected_annual(p)
	## Un jugador molesto exige más; uno contento se conforma con menos.
	var mood := 1.0 + float(70 - p.happiness) * 0.004
	var star := 1.0
	if ovr >= 80:
		star = 1.28
	elif ovr >= 72:
		star = 1.15
	elif ovr >= 64:
		star = 1.06
	## En un club grande todos aceptan cobrar algo menos.
	var prestige := clampf(1.16 - float(club.reputation) * 0.0022, 0.9, 1.18)
	var annual := int(float(base) * mood * star * prestige * (0.92 + quirk * 0.18))
	var bonus_ratio := 0.15 + quirk * 0.2
	if ovr >= 78:
		bonus_ratio += 0.15
	if p.age >= 31:
		bonus_ratio += 0.1
	return {
		"years": desired_years(p),
		"annual": maxi(1, annual),
		"bonus": maxi(0, int(float(annual) * bonus_ratio)),
	}


static func default_offer(p: Player, club: Club) -> Dictionary:
	var d := demands(p, club)
	return {"years": int(d["years"]), "annual": int(d["annual"]), "bonus": int(d["bonus"])}


static func first_year_cost(offer: Dictionary) -> int:
	return int(offer.get("annual", 0)) + int(offer.get("bonus", 0))


static func total_cost(offer: Dictionary) -> int:
	return int(offer.get("annual", 0)) * int(offer.get("years", 1)) + int(offer.get("bonus", 0))


static func evaluate_offer(p: Player, club: Club, offer: Dictionary) -> Dictionary:
	## verdict: accept · counter · refuse. En «counter» viene la contraoferta lista.
	var d := demands(p, club)
	if p.renewal_refused:
		return {
			"verdict": "refuse",
			"demands": d,
			"text": "%s ya decidió no renovar. Solo queda venderlo o dejarlo salir libre." % p.display_name(),
		}
	var years := clampi(int(offer.get("years", 1)), MIN_YEARS, MAX_YEARS)
	var annual := maxi(0, int(offer.get("annual", 0)))
	var bonus := maxi(0, int(offer.get("bonus", 0)))

	var money_score := (float(annual) / float(maxi(1, int(d["annual"]))) - 1.0) * 100.0
	var bonus_score := (float(bonus) / float(maxi(1, int(d["bonus"]))) - 1.0) * 22.0
	var years_score := -float(absi(years - int(d["years"]))) * 9.0
	## Quien está a gusto perdona una oferta discreta.
	var loyalty := float(p.happiness - 60) * 0.25 + float(p.morale - 60) * 0.15
	var score := money_score + bonus_score + years_score + loyalty

	if score >= 0.0:
		return {
			"verdict": "accept",
			"demands": d,
			"score": score,
			"text": "%s acepta: %d años por %s al año más %s de bono." % [
				p.display_name(), years, _plain(annual), _plain(bonus)
			],
		}
	if score >= -24.0:
		return {
			"verdict": "counter",
			"demands": d,
			"score": score,
			"counter": {"years": int(d["years"]), "annual": int(d["annual"]), "bonus": int(d["bonus"])},
			"text": "%s no firma así. Su representante contraoferta: %d años, %s al año y %s de bono." % [
				p.display_name(), int(d["years"]), _plain(int(d["annual"])), _plain(int(d["bonus"]))
			],
		}
	return {
		"verdict": "refuse",
		"demands": d,
		"score": score,
		"counter": {"years": int(d["years"]), "annual": int(d["annual"]), "bonus": int(d["bonus"])},
		"text": "%s rechaza la oferta de plano: está muy por debajo de lo que pide." % p.display_name(),
	}


static func sign(club: Club, p: Player, offer: Dictionary) -> Dictionary:
	var ev := evaluate_offer(p, club, offer)
	if str(ev["verdict"]) != "accept":
		return {"ok": false, "text": str(ev["text"]), "evaluation": ev}
	var bonus := maxi(0, int(offer.get("bonus", 0)))
	if club.budget < bonus:
		return {
			"ok": false,
			"text": "El bono de firma (%s) no cabe en el presupuesto." % _plain(bonus),
			"evaluation": ev,
		}
	var years := clampi(int(offer.get("years", 1)), MIN_YEARS, MAX_YEARS)
	club.budget -= bonus
	club.contract_acc += bonus
	p.contract_years = years
	p.contract_years_left = years
	p.set_annual_salary(maxi(1, int(offer.get("annual", 0))))
	p.contract_signing_bonus = bonus
	p.contract_formative = false
	p.renewal_refused = false
	p.transfer_listed = false
	p.happiness = clampi(p.happiness + 6, 15, 100)
	p.morale = clampi(p.morale + 4, 20, 100)
	return {"ok": true, "text": str(ev["text"]), "evaluation": ev}


static func auto_sign(p: Player, rng: RandomNumberGenerator, staggered: bool = true) -> void:
	## Contrato de fondo (mundo inicial y clubes de la CPU). Respeta el sueldo
	## por jornada que ya tiene el jugador para no alterar la economía.
	var years := desired_years(p)
	if rng:
		years = clampi(years + rng.randi_range(-1, 1), MIN_YEARS, MAX_YEARS)
	p.contract_years = years
	p.contract_years_left = years
	if staggered and rng:
		## Escalonar para que no venza toda la plantilla la misma temporada.
		p.contract_years_left = rng.randi_range(1, years)
	p.contract_annual_salary = annual_from_matchday(p.salary)
	p.contract_signing_bonus = int(float(p.contract_annual_salary) * 0.2)
	p.contract_formative = false
	p.renewal_refused = false


static func sign_formative(p: Player, rng: RandomNumberGenerator) -> void:
	## Los juveniles firman contrato de formación y se renueva solo.
	var years := 2
	if rng:
		years = rng.randi_range(1, 3)
	p.contract_years = years
	p.contract_years_left = years
	p.contract_annual_salary = annual_from_matchday(p.salary)
	p.contract_signing_bonus = 0
	p.contract_formative = true
	p.renewal_refused = false
	p.transfer_listed = false


static func clear_contract(p: Player) -> void:
	p.contract_years = 0
	p.contract_years_left = 0
	p.contract_signing_bonus = 0
	p.contract_formative = false


static func ensure_contract(p: Player, rng: RandomNumberGenerator) -> bool:
	## Partidas viejas o jugadores generados sin contrato.
	if p.has_contract():
		return false
	if p.is_youth:
		sign_formative(p, rng)
	else:
		auto_sign(p, rng)
	return true


static func release_cost(p: Player) -> int:
	if not p.has_contract() or p.contract_formative:
		return 0
	return int(float(p.annual_salary()) * float(p.contract_years_left) * RELEASE_RATIO)


static func release(club: Club, p: Player, free_agents: Array[Player]) -> Dictionary:
	if club.get_player(p.id) == null:
		return {"ok": false, "text": "Ese jugador no está en tu primer equipo."}
	if club.players.size() <= MIN_SQUAD_AFTER_RELEASE:
		return {
			"ok": false,
			"text": "No puedes bajar de %d jugadores. Ficha antes de soltar a nadie más." % MIN_SQUAD_AFTER_RELEASE,
		}
	var cost := release_cost(p)
	if cost > 0 and club.budget < cost:
		return {"ok": false, "text": "La indemnización cuesta %s y no te alcanza." % _plain(cost)}
	club.budget -= cost
	club.contract_acc += cost
	club.players.erase(p)
	club.lineup_ids.erase(p.id)
	club.bench_ids.erase(p.id)
	club.ensure_default_lineup()
	clear_contract(p)
	p.club_id = ""
	p.transfer_listed = false
	p.renewal_refused = false
	free_agents.append(p)
	var extra := ""
	if cost > 0:
		extra = " Indemnización pagada: %s." % _plain(cost)
	return {"ok": true, "text": "%s queda libre.%s" % [p.display_name(), extra], "cost": cost}


static func set_transfer_listed(p: Player, listed: bool) -> String:
	p.transfer_listed = listed
	if listed:
		return "%s entra en la lista de transferibles." % p.display_name()
	return "%s sale de la lista de transferibles." % p.display_name()


static func players_without_contract(club: Club) -> Array:
	var out: Array = []
	for p in club.players:
		if not p.has_contract():
			out.append(p)
	return out


static func expiring_players(club: Club) -> Array:
	## Están en su último año: conviene renovar o venderlos ya.
	var out: Array = []
	for p in club.players:
		if p.has_contract() and p.contract_years_left <= 1:
			out.append(p)
	return out


static func _wants_to_leave(p: Player, rng: RandomNumberGenerator) -> bool:
	var chance := 0.10
	if p.happiness < 45:
		chance += 0.35
	elif p.happiness < 60:
		chance += 0.15
	if p.morale < 45:
		chance += 0.10
	if p.age >= 34:
		chance += 0.18
	if p.matches_played <= 3:
		chance += 0.12
	var wage_ratio := float(p.salary) / float(maxi(1, p.expected_salary()))
	if wage_ratio < 0.75:
		chance += 0.15
	return rng.randf() < clampf(chance, 0.0, 0.85)


static func expire_season(club: Club, rng: RandomNumberGenerator, managed: bool) -> Dictionary:
	## Fin de temporada: descuenta un año a cada contrato. Los clubes de la CPU
	## renuevan solos; en el club del jugador los vencidos quedan pendientes y
	## quien no quiera seguir pasa a la lista de transferibles.
	var expired: Array = []
	var refused: Array = []
	for p in club.players:
		p.contract_years_left = maxi(0, p.contract_years_left - 1)
		if p.contract_years_left > 0:
			continue
		if not managed:
			auto_sign(p, rng, false)
			continue
		expired.append(p.display_name())
		if _wants_to_leave(p, rng):
			p.renewal_refused = true
			p.transfer_listed = true
			refused.append(p.display_name())
	for y in club.youth_players:
		y.contract_years_left = maxi(0, y.contract_years_left - 1)
		if y.contract_years_left <= 0:
			sign_formative(y, rng)
	return {"expired": expired, "refused": refused}


static func marketability_for(p: Player, rng: RandomNumberGenerator) -> int:
	var base := int(float(p.overall()) * 0.72) + int(float(p.talent) * 0.12)
	if p.is_foreign():
		base += 8
	if p.age <= 22:
		base += 4
	if rng:
		base += rng.randi_range(-12, 14)
	return clampi(base, 8, 99)


static func player_marketing_income(p: Player, club: Club) -> int:
	## Solo las figuras venden camisetas y atraen anunciantes.
	if not p.has_contract() or p.is_youth:
		return 0
	if p.marketability < MARKETING_FLOOR:
		return 0
	var rep := 0.6 + float(club.reputation) / 120.0
	var goals_bonus := 1.0 + clampf(float(p.goals) * 0.02, 0.0, 0.4)
	return int(float(p.marketability - MARKETING_FLOOR + 5) * 26.0 * rep * goals_bonus)


static func squad_marketing_income(club: Club) -> int:
	var total := 0
	for p in club.players:
		total += player_marketing_income(p, club)
	return total


static func advisor(club: Club):
	return club.get_staff(StaffScript.Role.LEGAL)


static func advisor_report(club: Club, p: Player, offer: Dictionary) -> Dictionary:
	var legal = advisor(club)
	if legal == null:
		return {
			"ok": false,
			"text": "Contrata un consejero legal y financiero para que revise el contrato, te diga lo que pide el jugador y qué impacto tiene en las cuentas.",
		}
	var skill: int = int(legal.skill)
	var d := demands(p, club)
	## Un asesor flojo solo da un rango amplio; uno bueno acierta casi al peso.
	var margin := clampf(0.30 - float(skill) * 0.003, 0.02, 0.30)
	var want: int = int(d["annual"])
	var low := int(float(want) * (1.0 - margin))
	var high := int(float(want) * (1.0 + margin))
	var annual := maxi(0, int(offer.get("annual", 0)))
	var bonus := maxi(0, int(offer.get("bonus", 0)))
	var years := clampi(int(offer.get("years", 1)), MIN_YEARS, MAX_YEARS)

	var lines: PackedStringArray = []
	lines.append("[b]%s[/b] (hab. %d)" % [legal.staff_name, skill])
	lines.append("Pide alrededor de %s–%s al año y unos %d años de contrato." % [
		_plain(low), _plain(high), int(d["years"])
	])
	lines.append("")
	lines.append("[b]Coste de tu oferta[/b]")
	lines.append("  Sueldo anual: %s  (%s por jornada)" % [_plain(annual), _plain(matchday_from_annual(annual))])
	lines.append("  Bono de firma: %s (pago único)" % _plain(bonus))
	lines.append("  Primer año: %s" % _plain(first_year_cost(offer)))
	lines.append("  Contrato completo (%d años): %s" % [years, _plain(total_cost(offer))])

	var wage_bill := maxi(1, club.weekly_wage_bill())
	var share := float(matchday_from_annual(annual)) / float(wage_bill) * 100.0
	lines.append("  Peso en la nómina de la jornada: %.1f%%" % share)
	if bonus > club.budget:
		lines.append("  [color=red]El bono no cabe en el presupuesto actual.[/color]")
	elif first_year_cost(offer) > club.budget:
		lines.append("  [color=orange]Cuidado: el primer año supera tu presupuesto de caja.[/color]")

	lines.append("")
	lines.append("[b]Impacto deportivo[/b]")
	lines.append("  %s" % _sporting_impact(club, p, skill))
	lines.append("")
	lines.append("[b]Impacto comercial[/b]")
	lines.append("  %s" % _commercial_impact(club, p, skill))
	lines.append("")
	lines.append("[b]Veredicto[/b]")
	lines.append("  %s" % _verdict(p, club, offer, skill))
	return {"ok": true, "text": "\n".join(lines), "demands": d, "skill": skill}


static func _sporting_impact(club: Club, p: Player, skill: int) -> String:
	var ovr := p.overall()
	var squad_avg := 0.0
	var same_pos := 0
	var better_same_pos := 0
	for other in club.players:
		squad_avg += float(other.overall())
		if other.position == p.position and other.id != p.id:
			same_pos += 1
			if other.overall() >= ovr:
				better_same_pos += 1
	if not club.players.is_empty():
		squad_avg /= float(club.players.size())
	var gap := float(ovr) - squad_avg
	var level := "en la media de la plantilla"
	if gap >= 8.0:
		level = "claramente por encima de la plantilla"
	elif gap >= 3.0:
		level = "por encima de la media"
	elif gap <= -8.0:
		level = "muy por debajo de la plantilla"
	elif gap <= -3.0:
		level = "por debajo de la media"
	var txt := "OVR %d, %s (media %.0f). En su puesto tienes %d jugadores, %d igual o mejores." % [
		ovr, level, squad_avg, same_pos, better_same_pos
	]
	if skill >= 60:
		var cap := p.potential_cap()
		if cap > ovr + 4:
			txt += " Aún puede crecer hasta ~%d." % cap
		elif p.age >= 32:
			txt += " A su edad lo normal es que baje de nivel cada temporada."
	return txt


static func _commercial_impact(club: Club, p: Player, skill: int) -> String:
	var income := player_marketing_income(p, club)
	if income <= 0:
		return "No moverá la aguja: no atrae anunciantes ni venta de camisetas."
	var per_year := annual_from_matchday(income)
	var txt := "Aporta unos %s por jornada en publicidad y camisetas (~%s al año)." % [
		_plain(income), _plain(per_year)
	]
	if skill >= 60:
		if p.marketability >= 80:
			txt += " Es cara de marca: sirve para renegociar el patrocinio del pecho."
		elif p.is_foreign():
			txt += " Su fichaje abre mercado en su país de origen."
	return txt


static func _verdict(p: Player, club: Club, offer: Dictionary, skill: int) -> String:
	var d := demands(p, club)
	var want: int = maxi(1, int(d["annual"]))
	var annual := maxi(0, int(offer.get("annual", 0)))
	var ratio := float(annual) / float(want)
	var market := float(annual) / float(maxi(1, expected_annual(p)))
	var base := ""
	if ratio < 0.85:
		base = "No va a firmar por esto; te falta dinero en la mesa."
	elif ratio < 1.0:
		base = "Está justo por debajo de lo que pide: puede aceptar si está a gusto, o contraofertar."
	elif ratio <= 1.15:
		base = "Contrato sano: paga lo que vale sin pasarse."
	else:
		base = "Estás pagando por encima del mercado. Firmará, pero encarece la nómina."
	if skill >= 55:
		if market > 1.35:
			base += " Ojo: %.0f%% por encima de su valor de mercado." % ((market - 1.0) * 100.0)
		elif market < 0.8:
			base += " Es una ganga si acepta."
	return base


static func _plain(amount: int) -> String:
	return GameState.format_money(amount)
