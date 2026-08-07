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
	club.budget -= players + staff
	return {"players": players, "staff": staff, "total": players + staff}


static func _auto_media_amount(type_key: String, club: Club, league: League, pos_bonus: int) -> int:
	var tier: int = league.tier if league else 2
	var tier_mult := 1.0 if tier <= 1 else 0.42
	var rep_mult := 0.7 + club.reputation / 120.0
	match type_key:
		"tv":
			return int((28000 + club.reputation * 420 + pos_bonus * 1800) * tier_mult * rep_mult)
		"radio":
			return int((6000 + club.reputation * 90 + pos_bonus * 350) * tier_mult * rep_mult)
		"streaming":
			return int((12000 + club.reputation * 180 + pos_bonus * 700) * tier_mult * rep_mult)
		"sponsor", "commercial":
			return int((8000 + club.reputation * 140 + pos_bonus * 500) * tier_mult * rep_mult)
	return 0


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
	var partners: Dictionary = {"tv": "", "radio": "", "streaming": "", "commercial": ""}
	var amounts: Dictionary = {"tv": 0, "radio": 0, "streaming": 0, "commercial": 0}
	var types: Array[String] = ["tv", "radio", "streaming", "sponsor"]
	for type_key in types:
		var out_key: String = "commercial" if type_key == "sponsor" else type_key
		if club.media_contracts.has(type_key):
			var c: Dictionary = club.media_contracts[type_key]
			amounts[out_key] = int(c.get("per_matchday", 0))
			partners[out_key] = str(c.get("partner", ""))
		else:
			var mult: float = 0.35 if managed_contracts else 1.0
			amounts[out_key] = int(float(_auto_media_amount(type_key, club, league, pos_bonus)) * mult)
			partners[out_key] = "sin contrato" if managed_contracts else "mercado"
	var total: int = int(amounts["tv"]) + int(amounts["radio"]) + int(amounts["streaming"]) + int(amounts["commercial"])
	return {
		"tv": amounts["tv"],
		"radio": amounts["radio"],
		"streaming": amounts["streaming"],
		"commercial": amounts["commercial"],
		"tv_partner": partners["tv"],
		"radio_partner": partners["radio"],
		"streaming_partner": partners["streaming"],
		"commercial_partner": partners["commercial"],
		"total": total,
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
	var wage_total: int = int(wages.get("total", 0))
	var expense: int = wage_total + loan_payment
	var settlement_net := income_media - expense
	return {
		"budget_before": budget_before,
		"gate": gate,
		"prize": prize,
		"tv": int(media.get("tv", 0)),
		"radio": int(media.get("radio", 0)),
		"streaming": int(media.get("streaming", 0)),
		"commercial": int(media.get("commercial", 0)),
		"tv_partner": str(media.get("tv_partner", "")),
		"radio_partner": str(media.get("radio_partner", "")),
		"streaming_partner": str(media.get("streaming_partner", "")),
		"commercial_partner": str(media.get("commercial_partner", "")),
		"player_wages": int(wages.get("players", 0)),
		"staff_wages": int(wages.get("staff", 0)),
		"loan_payment": loan_payment,
		"loan_remaining": club.owner_loan_remaining,
		"match_income_total": gate + prize,
		"media_total": income_media,
		"income_total": gate + prize + income_media,
		"expense_total": expense,
		"net": settlement_net,
		"budget_after": club.budget,
		"league_name": league.name if league else "",
		"tier": league.tier if league else 2,
	}
