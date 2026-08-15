.PHONY: test lint

# El target se llama `test` porque quality-gate.sh busca exactamente ese nombre
# antes que cualquier otra deteccion; sin el, un repo cuyas suites viven fuera
# de Git parece un repo sin runner y el gate bloquea todo commit.
#
# Lo que corre es la validacion de la configuracion. Si clonaste esto para usar
# la config, `make test` te dice si tus manifiestos y scripts estan sanos.
test:
	@bash config/claude/scripts/validate.sh

lint:
	@shellcheck -S warning $$(git ls-files '*.sh' ':!:config/claude/skills/*')
