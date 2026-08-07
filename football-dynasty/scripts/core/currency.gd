extends RefCounted
class_name CurrencyUtil

## Economía interna siempre en euros; la UI convierte al mostrar.

enum Code { EUR, USD, GBP }

## 1 EUR → moneda destino (tasas fijas de juego)
const RATE_FROM_EUR := {
	Code.EUR: 1.0,
	Code.USD: 1.08,
	Code.GBP: 0.86,
}

const SYMBOL := {
	Code.EUR: "€",
	Code.USD: "$",
	Code.GBP: "£",
}

const LABEL := {
	Code.EUR: "Euros (€)",
	Code.USD: "Dólares ($)",
	Code.GBP: "Libras esterlinas (£)",
}


static func normalize(code: int) -> int:
	if code == Code.USD or code == Code.GBP or code == Code.EUR:
		return code
	return Code.EUR


static func convert_from_eur(amount_eur: int, code: int) -> int:
	var c: int = normalize(code)
	var rate: float = float(RATE_FROM_EUR[c])
	if amount_eur < 0:
		return -int(round(abs(amount_eur) * rate))
	return int(round(amount_eur * rate))


static func format(amount_eur: int, code: int) -> String:
	var c: int = normalize(code)
	var converted: int = convert_from_eur(amount_eur, c)
	var sym: String = str(SYMBOL[c])
	var sign := "-" if converted < 0 else ""
	var abs_n: int = abs(converted)
	# $ y £ delante; € detrás (estilo europeo)
	if c == Code.EUR:
		return "%s%d %s" % [sign, abs_n, sym]
	return "%s%s%d" % [sign, sym, abs_n]


static func code_from_key(key: String) -> int:
	match key:
		"usd": return Code.USD
		"gbp": return Code.GBP
		_: return Code.EUR


static func key_from_code(code: int) -> String:
	match normalize(code):
		Code.USD: return "usd"
		Code.GBP: return "gbp"
		_: return "eur"
