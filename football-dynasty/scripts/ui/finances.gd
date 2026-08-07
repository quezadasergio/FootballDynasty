extends Control

const ClubFinance = preload("res://scripts/core/club_finance.gd")

@onready var body: RichTextLabel = $Margin/Scroll/VBox/Body
@onready var status: Label = $Margin/Scroll/VBox/Status
@onready var contracts_box: VBoxContainer = $Margin/Scroll/VBox/ContractsBox
@onready var loan_pick: OptionButton = $Margin/Scroll/VBox/LoanBox/LoanPick
@onready var stadium_pick: OptionButton = $Margin/Scroll/VBox/StadiumBox/StadiumPick

var _loans: Array = []
var _upgrades: Array = []
## type_key -> {picker: OptionButton, offers: Array, current: Label}
var _rows: Dictionary = {}


func _ready() -> void:
	$Margin/Scroll/VBox/LoanBox/BtnLoan.pressed.connect(_on_loan)
	$Margin/Scroll/VBox/StadiumBox/BtnUpgrade.pressed.connect(_on_upgrade)
	_build_contract_rows()
	_refresh()


func _build_contract_rows() -> void:
	## Una fila por tipo de contrato, agrupadas por familia.
	for child in contracts_box.get_children():
		child.queue_free()
	_rows.clear()
	for group in ClubFinance.CONTRACT_GROUPS:
		var header := Label.new()
		header.text = str(group["label"])
		header.add_theme_font_size_override("font_size", 18)
		contracts_box.add_child(header)
		for type_key in group["types"]:
			contracts_box.add_child(_make_contract_row(str(type_key)))


func _make_contract_row(type_key: String) -> VBoxContainer:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)

	var current := Label.new()
	current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wrapper.add_child(current)

	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = ClubFinance.type_label(type_key)
	name_label.custom_minimum_size = Vector2(170, 0)
	row.add_child(name_label)

	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(picker)

	var sign_btn := Button.new()
	sign_btn.text = "Firmar"
	sign_btn.pressed.connect(_on_sign.bind(type_key))
	row.add_child(sign_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.pressed.connect(_on_cancel.bind(type_key))
	row.add_child(cancel_btn)

	wrapper.add_child(row)
	_rows[type_key] = {"picker": picker, "offers": [], "current": current}
	return wrapper


func _refresh() -> void:
	var club := GameState.player_club
	var league := GameState.player_league()
	if club == null:
		return

	var kit_income := 0
	for type_key in ["kit_chest", "kit_sleeve", "kit_shorts"]:
		if club.media_contracts.has(type_key):
			kit_income += int(club.media_contracts[type_key].get("per_matchday", 0))

	var loan_txt := "Sin préstamo activo."
	if club.owner_loan_remaining > 0:
		loan_txt = "Deuda con el dueño: %s (pago %s/jornada)" % [
			_money(club.owner_loan_remaining), _money(club.owner_loan_payment)
		]

	body.text = "[b]%s — Finanzas[/b]\n\nPresupuesto: [b]%s[/b]\n\n[b]Nómina por jornada[/b]\n  Jugadores: %s\n  Cuerpo técnico: %s\n  Juveniles: %s\n  Academia (fuerzas básicas): %s\n  Total: [b]%s[/b]\n\n[b]Publicidad de uniforme[/b]: %s/jornada\n\nCapacidad estadio: %d\nPrecio entrada: %s\nReputación: %d\n\n[b]Préstamo[/b]\n%s\n\nSin contrato firmado cobras solo ~35%% del valor de mercado de ese espacio." % [
		club.name, _money(club.budget),
		_money(Finance.player_wage_bill(club)),
		_money(club.staff_wage_bill()),
		_money(club.youth_wage_bill()),
		_money(club.academy_cost()),
		_money(club.weekly_wage_bill()),
		_money(kit_income),
		club.stadium_capacity, _money(club.ticket_price), club.reputation,
		loan_txt,
	]

	for type_key in _rows.keys():
		_refresh_contract_row(club, league, str(type_key))

	_loans = ClubFinance.loan_options(club)
	loan_pick.clear()
	for o in _loans:
		loan_pick.add_item("Recibir %s → devolver %s (%d× %s/jor.)" % [
			_money(int(o["amount"])), _money(int(o["total_repay"])),
			int(o["payments"]), _money(int(o["per_matchday"]))
		])

	_upgrades = ClubFinance.stadium_upgrade_options(club)
	stadium_pick.clear()
	for o in _upgrades:
		stadium_pick.add_item("+%d asientos → cap. %d · costo %s" % [
			int(o["seats"]), club.stadium_capacity + int(o["seats"]), _money(int(o["cost"]))
		])


func _refresh_contract_row(club: Club, league: League, type_key: String) -> void:
	var row: Dictionary = _rows[type_key]
	var picker: OptionButton = row["picker"]
	var current: Label = row["current"]
	var offers: Array = ClubFinance.offers_for_type(club, league, type_key)
	row["offers"] = offers

	var selected := maxi(0, picker.selected)
	picker.clear()
	for o in offers:
		picker.add_item("%s — %s · %s/jor. · %d jor." % [
			o["level_name"], o["partner"], _money(int(o["per_matchday"])), int(o["duration"])
		])
	if picker.item_count > 0:
		picker.select(mini(selected, picker.item_count - 1))

	if club.media_contracts.has(type_key):
		var c: Dictionary = club.media_contracts[type_key]
		current.text = "  Activo: %s (%s) — %s/jornada · quedan %d jornadas" % [
			c.get("partner", "?"), c.get("level_name", ""),
			_money(int(c.get("per_matchday", 0))), int(c.get("remaining", 0))
		]
	else:
		current.text = "  Sin contrato (cobras ingreso reducido de mercado)"


func _on_sign(type_key: String) -> void:
	var row: Dictionary = _rows[type_key]
	var picker: OptionButton = row["picker"]
	var offers: Array = row["offers"]
	if picker.selected < 0 or picker.selected >= offers.size():
		status.text = "Elige una oferta de %s." % ClubFinance.type_label(type_key)
		return
	status.text = ClubFinance.sign_contract(GameState.player_club, offers[picker.selected])
	GameState.save_game()
	GameState.state_changed.emit()
	_refresh()


func _on_cancel(type_key: String) -> void:
	status.text = ClubFinance.cancel_contract(GameState.player_club, type_key)
	GameState.save_game()
	GameState.state_changed.emit()
	_refresh()


func _on_loan() -> void:
	if loan_pick.selected < 0 or loan_pick.selected >= _loans.size():
		status.text = "Selecciona un préstamo."
		return
	var option: Dictionary = _loans[loan_pick.selected]
	var msg: String = ClubFinance.take_owner_loan(GameState.player_club, option)
	if msg == "Préstamo aceptado.":
		status.text = "El dueño te prestó %s. Se descontará %s por jornada." % [
			_money(int(option["amount"])), _money(int(option["per_matchday"]))
		]
	else:
		status.text = msg
	GameState.save_game()
	GameState.state_changed.emit()
	_refresh()


func _on_upgrade() -> void:
	if stadium_pick.selected < 0 or stadium_pick.selected >= _upgrades.size():
		status.text = "Selecciona una reforma."
		return
	status.text = ClubFinance.upgrade_stadium(GameState.player_club, _upgrades[stadium_pick.selected])
	GameState.save_game()
	GameState.state_changed.emit()
	_refresh()


func _money(n: int) -> String:
	return GameState.format_money(n)
