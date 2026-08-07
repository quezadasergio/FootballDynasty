extends Control

@onready var market: ItemList = $Margin/Scroll/VBox/HBox/MarketBox/MarketList
@onready var squad: ItemList = $Margin/Scroll/VBox/HBox/SquadBox/SquadList
@onready var info: Label = $Margin/Scroll/VBox/Info
@onready var filter_box: OptionButton = $Margin/Scroll/VBox/FilterRow/Filter
var _targets: Array = []
var _all_targets: Array = []


func _ready() -> void:
	$Margin/Scroll/VBox/BtnBuy.pressed.connect(_on_buy)
	$Margin/Scroll/VBox/BtnSell.pressed.connect(_on_sell)
	filter_box.clear()
	filter_box.add_item("Todos los mercados", 0)
	filter_box.add_item("México", 1)
	filter_box.add_item("Europa (caro)", 2)
	filter_box.add_item("Sudamérica (caro)", 3)
	filter_box.add_item("Agentes libres", 4)
	filter_box.add_item("Asia (accesible)", 5)
	filter_box.add_item("África (accesible)", 6)
	filter_box.item_selected.connect(func(_i): _apply_filter())
	_refresh()


func _refresh() -> void:
	squad.clear()
	var club := GameState.player_club
	if club == null:
		return
	info.text = "Presupuesto: %s  ·  Plantilla: %d  ·  Extranjeros: %d/%d\nEuropa ~7× valor · Sudamérica ~3.4× valor · Asia y África ~1.1× valor (nivel y precio de mercado mexicano)" % [
		_money(club.budget), club.players.size(), club.count_foreigners(), _foreigner_limit()
	]
	_all_targets = TransferMarket.list_transfer_targets(
		GameState.clubs, club.id, GameState.free_agents, GameState.foreign_clubs
	)
	_apply_filter()
	for p2 in club.players:
		squad.add_item("%s %s (%d) · %s" % [p2.position_label(), p2.display_name(), p2.overall(), _money(p2.value)])
		squad.set_item_metadata(squad.item_count - 1, p2.id)


func _apply_filter() -> void:
	market.clear()
	_targets.clear()
	var mode: int = filter_box.get_selected_id() if filter_box.selected >= 0 else 0
	var shown := 0
	for t in _all_targets:
		var m: String = str(t.get("market", "MEX"))
		var ok := false
		match mode:
			0:
				ok = true
			1:
				ok = m == "MEX"
			2:
				ok = m == "EUR"
			3:
				ok = m == "SUD"
			4:
				ok = m == "LIB"
			5:
				ok = m == "ASI"
			6:
				ok = m == "AFR"
		if not ok:
			continue
		if shown >= 60:
			break
		var p: Player = t["player"]
		var label: String = str(t.get("label", "?"))
		market.add_item("%s %s (%d) · %s · %s" % [
			p.position_label(), p.display_name(), p.overall(), label, _money(t["price"])
		])
		market.set_item_metadata(market.item_count - 1, shown)
		_targets.append(t)
		shown += 1
	$Margin/Scroll/VBox/HBox/MarketBox/MT.text = "Mercado (%d)" % market.item_count


func _on_buy() -> void:
	var sel := market.get_selected_items()
	if sel.is_empty():
		info.text = "Selecciona un jugador del mercado."
		return
	var idx: int = market.get_item_metadata(sel[0])
	if idx < 0 or idx >= _targets.size():
		return
	var t: Dictionary = _targets[idx]
	var buyer := GameState.player_club
	var seller: Club = null
	if t["seller_id"] != "":
		seller = GameState.get_club(t["seller_id"])
		if seller == null:
			info.text = "Club vendedor no encontrado."
			return
	var err := TransferMarket.buy_player(buyer, seller, t["player"], t["price"], GameState.free_agents, _player_tier())
	if err != "":
		info.text = err
		return
	var mkt: String = str(t.get("market", "MEX"))
	if mkt in ["EUR", "SUD", "ASI", "AFR"]:
		info.text = "Fichaje internacional (%s): %s desde %s. Pagaste %s." % [
			str(TransferMarket.REGION_LABELS.get(mkt, mkt)),
			t["player"].display_name(), t.get("label", ""), _money(int(t["price"]))
		]
	else:
		info.text = "Fichaje completado: %s por %s." % [t["player"].display_name(), _money(int(t["price"]))]
	GameState.save_game()
	_refresh()


func _on_sell() -> void:
	var sel := squad.get_selected_items()
	if sel.is_empty():
		info.text = "Selecciona un jugador de tu plantilla."
		return
	var pid: String = squad.get_item_metadata(sel[0])
	var club := GameState.player_club
	var player := club.get_player(pid)
	if player == null:
		return
	var price := int(player.value * 0.85)
	var err := TransferMarket.sell_player(club, null, player, price, GameState.free_agents)
	if err != "":
		info.text = err
		return
	info.text = "Vendido %s por %s (agente libre)." % [player.display_name(), _money(price)]
	GameState.save_game()
	_refresh()


func _player_tier() -> int:
	var league := GameState.player_league()
	return league.tier if league else 2


func _foreigner_limit() -> int:
	return Database.foreigner_limit_for_tier(_player_tier())


func _money(n: int) -> String:
	return GameState.format_money(n)
