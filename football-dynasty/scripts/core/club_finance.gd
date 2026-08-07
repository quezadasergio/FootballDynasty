class_name ClubFinance
extends RefCounted

const CONTRACT_TYPES: Array[String] = ["sponsor", "tv", "radio", "streaming"]

const TYPE_LABELS := {
	"sponsor": "Patrocinio",
	"tv": "Televisión",
	"radio": "Radio",
	"streaming": "Streaming",
}

const PARTNERS := {
	"sponsor": ["Caliente", "Cemex", "Telcel", "BBVA México", "Coca-Cola", "Nike México", "Puma MX"],
	"tv": ["TUDN", "ESPN México", "Azteca Deportes", "Fox Sports MX", "Claro Sports"],
	"radio": ["W Deportes", "Radio Fórmula", "Imagen Radio", "Stereo Cien"],
	"streaming": ["Vix+", "Disney+ Deportes", "Prime Video MX", "YouTube TV MX"],
}


static func type_label(type_key: String) -> String:
	return str(TYPE_LABELS.get(type_key, type_key))


static func list_contract_offers(club: Club, league: League) -> Array:
	## 3 ofertas por tipo (básica / media / premium).
	var offers: Array = []
	var tier: int = league.tier if league else 2
	var tier_mult := 1.0 if tier <= 1 else 0.45
	var rep := club.reputation
	for type_key in CONTRACT_TYPES:
		var partners: Array = PARTNERS.get(type_key, ["Socio"])
		for level in range(3):
			var base := 0
			match type_key:
				"sponsor":
					base = 9000 + rep * 110
				"tv":
					base = 22000 + rep * 280
				"radio":
					base = 5000 + rep * 70
				"streaming":
					base = 10000 + rep * 140
			var level_mult: float = 0.7 + float(level) * 0.45
			var per: int = int(float(base) * tier_mult * level_mult)
			var duration: int = 10 + level * 4
			var partner: String = str(partners[(club.reputation + level * 3 + type_key.length()) % partners.size()])
			var level_names: Array[String] = ["Básico", "Estándar", "Premium"]
			var level_name: String = level_names[level]
			offers.append({
				"type": type_key,
				"partner": partner,
				"level": level,
				"level_name": level_name,
				"per_matchday": per,
				"duration": duration,
			})
	return offers


static func sign_contract(club: Club, offer: Dictionary) -> String:
	var type_key: String = str(offer.get("type", ""))
	if not CONTRACT_TYPES.has(type_key):
		return "Tipo de contrato inválido."
	club.media_contracts[type_key] = {
		"partner": str(offer.get("partner", "Socio")),
		"per_matchday": int(offer.get("per_matchday", 0)),
		"remaining": int(offer.get("duration", 10)),
		"level_name": str(offer.get("level_name", "")),
	}
	return "Contrato firmado: %s con %s." % [type_label(type_key), offer.get("partner", "")]


static func cancel_contract(club: Club, type_key: String) -> String:
	if not club.media_contracts.has(type_key):
		return "No hay contrato activo de ese tipo."
	club.media_contracts.erase(type_key)
	return "Contrato de %s cancelado." % type_label(type_key)


static func loan_options(club: Club) -> Array:
	var base := maxi(100000, club.reputation * 18000)
	var opts: Array = []
	for mult in [1.0, 2.0, 3.5]:
		var amount := int(base * mult)
		var interest := 0.12 + (0.03 if mult > 2.0 else 0.0)
		var total := int(amount * (1.0 + interest))
		var payments := 12
		var per := int(ceil(float(total) / float(payments)))
		opts.append({
			"amount": amount,
			"total_repay": total,
			"payments": payments,
			"per_matchday": per,
		})
	return opts


static func take_owner_loan(club: Club, option: Dictionary) -> String:
	if club.owner_loan_remaining > 0:
		return "Ya tienes un préstamo activo con el dueño. Liquídalo primero."
	var amount: int = int(option.get("amount", 0))
	if amount <= 0:
		return "Monto inválido."
	club.budget += amount
	club.owner_loan_remaining = int(option.get("total_repay", amount))
	club.owner_loan_payment = int(option.get("per_matchday", 0))
	return "Préstamo aceptado."


static func apply_loan_payment(club: Club) -> int:
	if club.owner_loan_remaining <= 0:
		return 0
	var pay: int = mini(club.owner_loan_payment, club.owner_loan_remaining)
	club.budget -= pay
	club.owner_loan_remaining -= pay
	if club.owner_loan_remaining <= 0:
		club.owner_loan_remaining = 0
		club.owner_loan_payment = 0
	return pay


static func stadium_upgrade_options(club: Club) -> Array:
	var opts: Array = []
	for seats in [2000, 5000, 10000]:
		var cost := int(seats * (18 + club.reputation / 8) + club.stadium_capacity * 0.35)
		if club.stadium_capacity + seats > 120000:
			continue
		opts.append({
			"seats": seats,
			"cost": cost,
		})
	return opts


static func upgrade_stadium(club: Club, option: Dictionary) -> String:
	var cost: int = int(option.get("cost", 0))
	var seats: int = int(option.get("seats", 0))
	if seats <= 0:
		return "Obra inválida."
	if club.budget < cost:
		return "Presupuesto insuficiente para la reforma."
	club.budget -= cost
	club.stadium_capacity += seats
	club.reputation = mini(99, club.reputation + (1 if seats >= 5000 else 0))
	return "Reforma lista: +%d asientos. Nueva capacidad: %d." % [seats, club.stadium_capacity]


static func tick_contracts(club: Club) -> void:
	var keys: Array = club.media_contracts.keys()
	for k in keys:
		var c: Dictionary = club.media_contracts[k]
		c["remaining"] = int(c.get("remaining", 1)) - 1
		if int(c["remaining"]) <= 0:
			club.media_contracts.erase(k)
		else:
			club.media_contracts[k] = c
