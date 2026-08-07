extends Control

const CurrencyScript = preload("res://scripts/core/currency.gd")

@onready var currency_opt: OptionButton = $Margin/Scroll/VBox/CurrencyRow/Currency
@onready var info: Label = $Margin/Scroll/VBox/Info


func _ready() -> void:
	currency_opt.clear()
	currency_opt.add_item(CurrencyScript.LABEL[CurrencyScript.Code.EUR], CurrencyScript.Code.EUR)
	currency_opt.add_item(CurrencyScript.LABEL[CurrencyScript.Code.USD], CurrencyScript.Code.USD)
	currency_opt.add_item(CurrencyScript.LABEL[CurrencyScript.Code.GBP], CurrencyScript.Code.GBP)
	_select_current()
	currency_opt.item_selected.connect(_on_currency)
	_refresh_info()


func _select_current() -> void:
	for i in currency_opt.item_count:
		if currency_opt.get_item_id(i) == GameState.currency_code:
			currency_opt.select(i)
			return
	currency_opt.select(0)


func _on_currency(index: int) -> void:
	GameState.set_currency(currency_opt.get_item_id(index))
	_refresh_info()


func _refresh_info() -> void:
	var sample := 100000
	info.text = "Los valores del juego se guardan en euros y se convierten al mostrar.\nEjemplo: %s → %s\nTasas (1 €): 1,00 € · 1,08 $ · 0,86 £\nPuedes cambiar la moneda cuando quieras." % [
		CurrencyScript.format(sample, CurrencyScript.Code.EUR),
		GameState.format_money(sample),
	]
