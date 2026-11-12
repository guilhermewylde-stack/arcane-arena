extends SceneTree
## Roda todos os testes: godot --headless --path . -s tests/run_tests.gd


func _initialize() -> void:
	var passed := 0
	var failed := 0
	var files := DirAccess.get_files_at("res://tests")
	files.sort()
	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			print("ERRO  %s não carregou" % file)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			var case: RefCounted = script.new()
			case.call(name)
			if case.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for failure: String in case.failures:
					print("FALHOU  %s :: %s — %s" % [file, name, failure])
	print("%d passaram, %d falharam" % [passed, failed])
	quit(1 if failed > 0 else 0)
