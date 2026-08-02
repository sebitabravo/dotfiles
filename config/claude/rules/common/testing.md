# Testing

## Cuando un test se pone rojo: orden de diagnóstico

**El test tiene la razón hasta que se demuestre lo contrario.** Es la única parte del repo que codifica lo que el sistema DEBE hacer; el código solo dice lo que hace hoy. Cuando discrepan, el sospechoso por defecto es el código.

Recorré las hipótesis **en este orden** y no saltees ninguna:

1. **¿El código nuevo está mal?** Es el caso en la enorme mayoría. Leé el assert, entendé qué comportamiento esperaba, arreglá el código para que lo cumpla. **No toques el test.**
2. **¿El código está bien pero rompió un contrato que otro código dependía?** El test está señalando un efecto colateral real. Adaptá tu implementación para no romperlo, o traelo a la conversación si el contrato tiene que cambiar de verdad.
3. **¿El test es frágil, no incorrecto?** Depende del orden, del reloj, de un mock desactualizado, de un puerto ocupado. Arreglá la fragilidad **sin tocar lo que verifica**. Un test que pasa a verificar menos no se arregló, se apagó.
4. **¿El test está mal escrito?** Recién acá. Existe: un assert que codificó un malentendido, o un requisito que cambió de verdad. **PARÁ Y PEDÍ AUTORIZACIÓN** diciendo qué test, por qué creés que está mal, y qué cubre después del cambio.

**Nunca saltes directo al 4 porque es el camino más corto al verde.** Si el primer instinto es editar el assert, casi siempre significa que todavía no entendiste por qué falla.

**Verde no es la meta, es la evidencia.** Un test comentado, con `skip`, con el assert relajado o con el timeout inflado produce el mismo verde que un test que pasa — y esa es exactamente la razón por la que no sirve como prueba.

## Antes de decir "listo"

Tres preguntas. Cualquier "no" significa que no terminaste:

1. **¿Corrí los tests después del último cambio?** No antes: después. Un cambio posterior a la corrida invalida la corrida.
2. **¿Vi el resultado con mis ojos, no lo asumí?** "Debería pasar" no es una corrida.
3. **Si el cambio es visible (UI, layout, texto, estilo), ¿lo miré?** Un cambio visual se verifica viéndolo — screenshot o navegador. Deducir que un layout quedó bien porque el CSS "parece correcto" es lo que convierte un arreglo en veinte idas y vueltas.

## Rules

- **ALL code requires tests. No exceptions.** Even a "hello world" has a test verifying it returns "hello world". The goal is code built to the highest standard with no errors, and tests are the only evidence of that.
- **Every bug fix requires a regression test** that fails without the fix.
- **Tests must be deterministic**. No `Math.random()`, no real-time dependencies.
- **Fast tests**. If a test takes >2s, mock the slow dependency.
- **No tests that depend on execution order**. Each test runs in isolation.
- **If the project has no test runner configured, configure it BEFORE writing code**. No test runner is not an excuse to skip tests.

## What requires tests

- **ALL production code**: functions, endpoints, components, utilities, helpers, scripts.
- **Trivial code too**: a `hello()` returning "hello" has a test `expect(hello()).toBe("hello")`.
- **Config that affects behavior**: if it changes how the system behaves, it has a test.
- **Bug fixes**: regression test that fails without the fix.

## What does NOT require tests

- **Documentation** (README, comments, ADRs).
- **Static config** that does not affect behavior (format, style, metadata).
- **Generated code** (ORM models, protobuf, OpenAPI stubs).
- **Tests of tests** (do not test mocks, fixtures, or test helpers).

## What to test

1. **Black box** for business logic — expected inputs and outputs.
2. **Edge cases**: empty, null, boundaries, special characters.
3. **Errors**: what happens when things fail, not just the happy path.
4. **API contracts**: response schema, status codes, headers.
5. **Trivial cases**: the simplest happy path. If `add(1, 1)` should return `2`, there is a test that verifies it.

## Structure

- One test file per module/component.
- `describe` nests scenarios. `it` describes the specific case.
- Test names describe expected behavior, not implementation.
  - Good: `it("returns 404 when user does not exist")`
  - Bad: `it("test getUser with invalid id")`

## Coverage

- **Line coverage >= 80%**. Non-negotiable floor for production code.
- **Branch coverage >= 70%**. More important than line coverage.
- **Function coverage >= 90%**. Every public function must have at least one test.
- 100% coverage is NOT the goal. Coverage measures execution, not quality. Invoke the `mutation-testing` skill.
- Exclude from coverage: tests, mocks, fixtures, config, migrations, generated code.
- Invoke the `quality-metrics` skill for full thresholds and tools by language.

## BDD / Gherkin

- Complex features with business logic require tests in Gherkin format (`.feature`).
- Do NOT apply to internal utilities, trivial CRUD, or purely technical refactors.
- Invoke the `bdd-gherkin` skill for full rules and the workflow.

## Mutation Testing

- Mutation testing measures test QUALITY, not just coverage.
- **Mutation score >= 80%** on critical features.
- Run in CI, not on every commit (it's expensive).
- Invoke the `mutation-testing` skill for full rules and configuration.
