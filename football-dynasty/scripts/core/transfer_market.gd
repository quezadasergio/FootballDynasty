class_name TransferMarket
extends RefCounted

## Multiplicadores base sobre el valor del jugador (mercados extranjeros caros).
const MULT_SUD := 3.4
const MULT_EUR := 7.2


static func list_transfer_targets(
	clubs: Dictionary,
	player_club_id: String,
	free_agents: Array[Player],
	foreign_clubs: Dictionary = {}
) -> Array:
	var targets: Array = []
	for p in free_agents:
		targets.append({
			"player": p,
			"seller_id": "",
			"price": int(p.value * 0.6),
			"market": "LIB",
			"label": "Libre",
		})
	for cid in clubs.keys():
		if cid == player_club_id:
			continue
		var club: Club = clubs[cid]
		for p in club.players:
			if p.overall() < 45:
				continue
			targets.append({
				"player": p,
				"seller_id": cid,
				"price": p.value,
				"market": "MEX",
				"label": club.short_name,
			})
	for cid in foreign_clubs.keys():
		var fclub: Club = foreign_clubs[cid]
		for p in fclub.players:
			## Solo salen jugadores útiles del mercado internacional.
			if p.overall() < 62:
				continue
			targets.append({
				"player": p,
				"seller_id": cid,
				"price": foreign_asking_price(p, fclub),
				"market": fclub.market_region,
				"label": "%s·%s" % [fclub.short_name, fclub.market_region],
			})
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["player"].overall() > b["player"].overall()
	)
	return targets


static func foreign_asking_price(player: Player, club: Club) -> int:
	var mult: float = MULT_EUR if club.market_region == "EUR" else MULT_SUD
	## Prestigio del club (Real Madrid / City más caros que Porto / Racing).
	mult *= 1.0 + maxf(0.0, float(club.reputation - 78) * 0.045)
	var ovr := player.overall()
	if ovr >= 88:
		mult *= 1.55
	elif ovr >= 84:
		mult *= 1.35
	elif ovr >= 80:
		mult *= 1.2
	elif ovr >= 75:
		mult *= 1.08
	## Recargo por edad joven (potencial).
	if player.age <= 23:
		mult *= 1.15
	elif player.age >= 32:
		mult *= 0.82
	return maxi(250000, int(float(player.value) * mult))


static func can_buy(buyer: Club, price: int, player: Player = null, buyer_tier: int = 2) -> String:
	if buyer.budget < price:
		return "Presupuesto insuficiente."
	if player != null and player.is_foreign() and not buyer.can_add_foreigner(buyer_tier):
		var limit := Database.foreigner_limit_for_tier(buyer_tier)
		return "Cupo de extranjeros lleno (%d/%d)." % [buyer.count_foreigners(), limit]
	return ""


static func buy_player(
	buyer: Club,
	seller: Club,
	player: Player,
	price: int,
	free_agents: Array[Player],
	buyer_tier: int = 2
) -> String:
	var err := can_buy(buyer, price, player, buyer_tier)
	if err != "":
		return err
	if seller == null:
		var idx := -1
		for i in free_agents.size():
			if free_agents[i].id == player.id:
				idx = i
				break
		if idx < 0:
			return "Jugador no disponible."
		free_agents.remove_at(idx)
	else:
		var min_keep := 8 if seller.is_foreign_market_club() else 16
		if seller.players.size() <= min_keep:
			return "El club vendedor no puede quedarse sin plantilla mínima."
		var found := false
		for i in seller.players.size():
			if seller.players[i].id == player.id:
				seller.players.remove_at(i)
				found = true
				break
		if not found:
			return "Jugador no encontrado."
		seller.budget += price
		seller.lineup_ids.erase(player.id)
		seller.bench_ids.erase(player.id)
		seller.ensure_default_lineup()
	buyer.budget -= price
	player.club_id = buyer.id
	buyer.players.append(player)
	buyer.bench_ids.append(player.id)
	return ""


static func sell_player(seller: Club, buyer: Club, player: Player, price: int, free_agents: Array[Player]) -> String:
	if seller.players.size() <= 16:
		return "Necesitas al menos 16 jugadores en plantilla."
	if seller.lineup_ids.has(player.id) and seller.lineup_ids.size() <= 11:
		pass
	var found := false
	for i in seller.players.size():
		if seller.players[i].id == player.id:
			seller.players.remove_at(i)
			found = true
			break
	if not found:
		return "Jugador no encontrado."
	seller.lineup_ids.erase(player.id)
	seller.bench_ids.erase(player.id)
	seller.budget += price
	seller.ensure_default_lineup()
	if buyer:
		buyer.budget -= price
		player.club_id = buyer.id
		buyer.players.append(player)
		buyer.bench_ids.append(player.id)
		buyer.ensure_default_lineup()
	else:
		player.club_id = ""
		free_agents.append(player)
	return ""
