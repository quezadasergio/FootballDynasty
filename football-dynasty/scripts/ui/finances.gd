extends Control

const ClubFinance = preload("res://scripts/core/club_finance.gd")

@onready var body: RichTextLabel = $Margin/Scroll/VBox/Body
@onready var status: Label = $Margin/Scroll/VBox/Status
@onready var contract_list: ItemList = $Margin/Scroll/VBox/ContractsBox/ContractList
@onready var loan_list: ItemList = $Margin/Scroll/VBox/LoanBox/LoanList
@onready var stadium_list: ItemList = $Margin/Scroll/VBox/StadiumBox/StadiumList

var _offers: Array = []
var _loans: Array = []
var _upgrades: Array = []


func _ready() -> void:
	$Margin/Scroll/VBox/ContractsBox/BtnSign.pressed.connect(_on_sign)
	$Margin/Scroll/VBox/ContractsBox/BtnCancel.pressed.connect(_on_cancel_contract)
	$Margin/Scroll/VBox/LoanBox/BtnLoan.pressed.connect(_on_loan)
	$Margin/Scroll/VBox/StadiumBox/BtnUpgrade.pressed.connect(_on_upgrade)
	_refresh()


func _refresh() -> void:
	var club := GameState.player_club
	var league := GameState.player_league()
	if club == null:
		return
	var wages := club.weekly_wage_bill()
	var staff_w := club.staff_wage_bill()
	var contracts_txt := ""
	for type_key in ClubFinance.CONTRACT_TYPES:
		if club.media_contracts.has(type_key):
			var c: Dictionary = club.media_contracts[type_key]
			contracts_txt += "  • %s: %s — %s/jornada (%d jornadas restantes)\n" % [
				ClubFinance.type_label(type_key), c.get("partner", "?"),
				_money(int(c.get("per_matchday", 0))), int(c.get("remaining", 0))
			]
		else:
			contracts_txt += "  • %s: sin contrato (ingreso reducido de mercado)\n" % ClubFinance.type_label(type_key)
	var loan_txt := "Sin préstamo activo."
	if club.owner_loan_remaining > 0:
		loan_txt = "Deuda con el dueño: %s (pago %s/jornada)" % [
			_money(club.owner_loan_remaining), _money(club.owner_loan_payment)
		]
	body.text = "[b]%s — Finanzas[/b]\n\nPresupuesto: [b]%s[/b]\nNómina jugadores/jornada: %s\nNómina staff/jornada: %s\nTotal nómina/jornada: %s\nCapacidad estadio: %d\nPrecio entrada: %s\nReputación: %d\n\n[b]Contratos activos[/b]\n%s\n[b]Préstamo[/b]\n%s\n\nSin contrato cobras ~35%% del valor de mercado. Firmar mejora TV/radio/streaming/patrocinio en el resumen de cada jornada." % [
		club.name, _money(club.budget),
		_money(Finance.player_wage_bill(club)), _money(staff_w), _money(wages),
		club.stadium_capacity, _money(club.ticket_price), club.reputation,
		contracts_txt, loan_txt,
	]

	_offers = ClubFinance.list_contract_offers(club, league)
	contract_list.clear()
	for o in _offers:
		contract_list.add_item("%s %s — %s · %s/jor. · %d jor." % [
			ClubFinance.type_label(str(o["type"])), o["level_name"], o["partner"],
			_money(int(o["per_matchday"])), int(o["duration"])
		])

	_loans = ClubFinance.loan_options(club)
	loan_list.clear()
	for o in _loans:
		loan_list.add_item("Recibir %s → devolver %s (%d× %s/jor.)" % [
			_money(int(o["amount"])), _money(int(o["total_repay"])),
			int(o["payments"]), _money(int(o["per_matchday"]))
		])

	_upgrades = ClubFinance.stadium_upgrade_options(club)
	stadium_list.clear()
	for o in _upgrades:
		stadium_list.add_item("+%d asientos → cap. %d · costo %s" % [
			int(o["seats"]), club.stadium_capacity + int(o["seats"]), _money(int(o["cost"]))
		])


func _on_sign() -> void:
	var sel := contract_list.get_selected_items()
	if sel.is_empty():
		status.text = "Selecciona una oferta de contrato."
		return
	var msg: String = ClubFinance.sign_contract(GameState.player_club, _offers[sel[0]])
	status.text = msg
	GameState.save_game()
	_refresh()


func _on_cancel_contract() -> void:
	var sel := contract_list.get_selected_items()
	if sel.is_empty():
		status.text = "Selecciona una oferta del mismo tipo que quieres cancelar (o el contrato activo vía tipo)."
		return
	var type_key: String = str(_offers[sel[0]]["type"])
	var msg: String = ClubFinance.cancel_contract(GameState.player_club, type_key)
	status.text = msg
	GameState.save_game()
	_refresh()


func _on_loan() -> void:
	var sel := loan_list.get_selected_items()
	if sel.is_empty():
		status.text = "Selecciona un préstamo."
		return
	var msg: String = ClubFinance.take_owner_loan(GameState.player_club, _loans[sel[0]])
	if msg == "Préstamo aceptado.":
		var o: Dictionary = _loans[sel[0]]
		status.text = "El dueño te prestó %s. Se descontará %s por jornada." % [
			_money(int(o["amount"])), _money(int(o["per_matchday"]))
		]
	else:
		status.text = msg
	GameState.save_game()
	GameState.state_changed.emit()
	_refresh()


func _on_upgrade() -> void:
	var sel := stadium_list.get_selected_items()
	if sel.is_empty():
		status.text = "Selecciona una reforma."
		return
	var msg: String = ClubFinance.upgrade_stadium(GameState.player_club, _upgrades[sel[0]])
	status.text = msg
	GameState.save_game()
	GameState.state_changed.emit()
	_refresh()


func _money(n: int) -> String:
	return GameState.format_money(n)
