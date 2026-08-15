.PHONY: test lint

# Declara como se verifica este repo. quality-gate.sh busca un target `test:`
# aca antes que cualquier otra deteccion: sin el, un repo cuyas suites viven
# fuera de Git parece un repo sin runner.
test:
	@bash config/claude/scripts/run-all-tests.sh

lint:
	@shellcheck -S warning $$(git ls-files '*.sh' ':!:config/claude/skills/*')
