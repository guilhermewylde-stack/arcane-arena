extends RefCounted
## Base dos testes. Cada arquivo `tests/test_*.gd` estende esta classe e define métodos `test_*`.

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (esperado %s, veio %s)" % [message, expected, actual])


func check_near(actual: float, expected: float, message: String, tolerance := 0.0001) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s (esperado ~%s, veio %s)" % [message, expected, actual])
