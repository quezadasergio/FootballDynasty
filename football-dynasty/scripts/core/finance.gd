class_name Finance
extends RefCounted

const WIN_BONUS := 15000
const DRAW_BONUS := 5000
const LOSS_BONUS := 2000
const ClubFinanceScript = preload("res://scripts/core/club_finance.gd")


static func match_gate_receipts(club: Club, is_home: bool, opponent_rep: int) -> int:
	if not is_home:
		return 0
	var interest := clampf((club.reputation + opponent_rep) / 200.0, 0.35, 1.0)
	var attendance := int(club.stadium_capacity * interest)
	return attendance * club.ticket_price


static func match_prize(home_goals: int, away_goals: int, is_home: bool) -> int:
	var my_goals := home_goals if is_home else away_goals
	var their_goals := away_goals if is_home else home_goals
	if my_goals > their_goals:
		return WIN_BONUS
	if my_goals == their_goals:
		return DRAW_BONUS
	return LOSS_BONUS


static func player_wage_bill(club: Club) -> int:
	var total := 0
	for p in club.players:
		total += p.salary
	return total


static func apply_matchday_wages(club: Club) -> int:
	var wages := club.weekly_wage_bill()
	club.budget -= wages
	return wages


static func apply_matchday_wages_split(club: Club) -> Dictionary:
	var players := player_wage_bill(club)
	var staff := club.staff_wage_bill()
	var youth := club.youth_wage_bill()
	var academy := club.academy_cost()
	var total := players + staff + youth + academy
	club.budget -= total
	return {
		"players": players,
		"staff": staff,
		"youth": youth,
		"academy": academy,
		"total": total,
	}


static func _auto_media_amount(type_key: String, club: Club, league: League, pos_bonus: int) -> int:
	## Valor de mercado sin contrato firmado.
	var tier: int = league.tier if league else 2
	var tier_mult := 1.0 if tier <= 1 else 0.42
	var rep_mult := 0.7 + club.reputation / 120.0
	var base := float(ClubFinanceScript.base_amount(type_key, club.reputation)) * 1.25
	## Estar arriba en la tabla revaloriza sobre todo TV y streaming.
	var pos_weight := 0.02
	if type_key == "radio" or ClubFinanceScript.is_kit_type(type_key):
		pos_weight = 0.008
	return int(base * (1.0 + float(pos_bonus) * pos_weight) * tier_mult * rep_mult)


static func media_rights_for_club(club: Club, league: League, managed_contracts: bool = false) -> Dictionary:
	## Si managed_contracts: usa contratos firmados; sin contrato → ~35% mercado.
	## Clubs CPU (managed_contracts=false): siempre mercado completo.
	var pos_bonus := 0
	if league:
		var table: Array = league.sorted_table()
		for i in table.size():
			if table[i]["club_id"] == club.id:
				pos_bonus = maxi(0, 18 - i)
				break
	var amounts: Dictionary = {}
	var partners: Dictionary = {}
	for type_key in ClubFinanceScript.CONTRACT_TYPES:
		if club.media_contracts.has(type_key):
			var c: Dictionary = club.media_contracts[type_key]
			amounts[type_key] = int(c.get("per_matchday", 0))
			partners[type_key] = str(c.get("partner", ""))
		else:
			var mult: float = 0.35 if managed_contracts else 1.0
			amounts[type_key] = int(float(_auto_media_amount(type_key, club, league, pos_bonus)) * mult)
			partners[type_key] = "sin contrato" if managed_contracts else "mercado"

	var broadcast_total: int = int(amounts["tv"]) + int(amounts["radio"]) + int(amounts["streaming"])
	var kit_total: int = int(amounts["kit_chest"]) + int(amounts["kit_sleeve"]) + int(amounts["kit_shorts"])
	var commercial: int = int(amounts["sponsor"])
	return {
		"amounts": amounts,
		"partners": partners,
		"broadcast_total": broadcast_total,
		"kit_total": kit_total,
		"commercial": commercial,
		"commercial_partner": str(partners["sponsor"]),
		"total": broadcast_total + kit_total + commercial,
	}


static func apply_media_rights(club: Club, league: League, managed_contracts: bool = false) -> Dictionary:
	var media := media_rights_for_club(club, league, managed_contracts)
	club.budget += int(media["total"])
	ClubFinanceScript.tick_contracts(club)
	return media


static func apply_match_income(club: Club, is_home: bool, opponent_rep: int, home_goals: int, away_goals: int) -> Dictionary:
	var gate := match_gate_receipts(club, is_home, opponent_rep)
	var prize := match_prize(home_goals, away_goals, is_home)
	club.budget += gate + prize
	return {"gate": gate, "prize": prize, "total": gate + prize}


static func build_player_matchday_finance(
	club: Club,
	league: League,
	match_income: Dictionary,
	wages: Dictionary,
	media: Dictionary,
	budget_before: int,
	loan_payment: int = 0
) -> Dictionary:
	var gate: int = int(match_income.get("gate", 0))
	var prize: int = int(match_income.get("prize", 0))
	var income_media: int = int(media.get("total", 0))
	var transfers_in: int = club.transfer_in_acc
	var transfers_out: int = club.transfer_out_acc
	var medical: int = club.medical_acc
	var facilities: int = club.facility_acc
	var wage_total: int = int(wages.get("total", 0))
	var expense: int = wage_total + loan_payment + medical + transfers_out + facilities
	var income: int = gate + prize + income_media + transfers_in
	return {
		"budget_before": budget_before,
		"gate": gate,
		"prize": prize,
		"contract_amounts": (media.get("amounts", {}) as Dictionary).duplicate(),
		"contract_partners": (media.get("partners", {}) as Dictionary).duplicate(),
		"broadcast_total": int(media.get("broadcast_total", 0)),
		"kit_total": int(media.get("kit_total", 0)),
		"commercial": int(media.get("commercial", 0)),
		"commercial_partner": str(media.get("commercial_partner", "")),
		"player_wages": int(wages.get("players", 0)),
		"staff_wages": int(wages.get("staff", 0)),
		"youth_wages": int(wages.get("youth", 0)),
		"academy_cost": int(wages.get("academy", 0)),
		"medical_cost": medical,
		"transfers_in": transfers_in,
		"transfers_out": transfers_out,
		"transfers_net": transfers_in - transfers_out,
		"facilities_cost": facilities,
		"loan_payment": loan_payment,
		"loan_remaining": club.owner_loan_remaining,
		"match_income_total": gate + prize,
		"media_total": income_media,
		"income_total": income,
		"expense_total": expense,
		"net": income - expense,
		"budget_after": club.budget,
		"league_name": league.name if league else "",
		"tier": league.tier if league else 2,
	}
