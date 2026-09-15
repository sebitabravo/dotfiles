# Testing

## Cuando un test se pone rojo: orden de diagnóstico

**El test tiene razón hasta que se pruebe lo contrario.** Es la única parte del
repo que codifica lo que el sistema DEBE hacer; el código solo dice lo que hace
hoy. Cuando se contradicen, el sospechoso por defecto es el código.

Recorre las hipótesis **en este orden** y no te saltes ninguna:

1. **¿El código nuevo está mal?** Es el caso la gran mayoría de las veces. Lee el
   assert, entiende qué comportamiento esperaba, arregla el código. **No toques
   el test.**
2. **¿El código está bien pero rompió un contrato del que otro código dependía?**
   El test está señalando un efecto secundario real. Adapta tu implementación, o
   trae el tema a la conversación si el contrato de verdad tiene que cambiar.
3. **¿El test es flaky, no está equivocado?** Dependiente del orden, del reloj, de
   un mock viejo, de un puerto ocupado. Arregla la inestabilidad **sin tocar lo
   que verifica**. Un test que pasa a verificar menos no se arregló, se silenció.
4. **¿El test está equivocado?** Recién acá. Pasa: un assert que codificó un
   malentendido, o un requisito que de verdad cambió. **PARA Y PIDE
   AUTORIZACIÓN**, diciendo qué test es, por qué crees que está mal, y qué queda
   cubierto después del cambio.

**Nunca saltes directo al 4 porque es el camino más corto al verde.** Si el
primer impulso es editar el assert, casi siempre significa que todavía no
entendiste por qué falla.

**El verde no es la meta, es la evidencia.** Un test comentado, un `skip`, un
assert relajado o un timeout inflado producen el mismo verde que un test que
pasa — que es justamente por qué el verde solo no cuenta como prueba.

## Antes de decir "listo"

Tres preguntas. Cualquier "no" significa que no terminaste:

1. **¿Corrí los tests después del último cambio?** No antes: después.
2. **¿Vi el resultado con mis propios ojos, o lo asumí?**
3. **Si el cambio es visible (UI, layout, texto, estilos), ¿lo miré?** Un cambio
   visual se verifica viéndolo — screenshot o navegador. Deducir que un layout
   está bien porque el CSS "se ve correcto" es lo que convierte un fix en veinte
   idas y vueltas.

## Reglas

- **Todo el código de producción lleva tests.** Funciones, endpoints,
  componentes, utilidades, scripts. Incluso lo trivial: un `hello()` que devuelve
  "hello" tiene su `expect(hello()).toBe("hello")`.
- **Todo bug fix lleva un test de regresión** que falle sin el fix. Escríbelo
  ANTES de tocar el código de aplicación: un fix sin un test que haya fallado
  primero es una adivinanza.
- **Los tests son deterministas.** Sin `Math.random()`, sin dependencia del reloj
  real, sin depender del orden de ejecución.
- **Tests rápidos.** Si uno tarda más de 2s, mockea la dependencia lenta.
- **Si el proyecto no tiene runner configurado, configúralo ANTES de escribir
  código.** No tener runner no es excusa para saltarse los tests.

## Qué NO lleva tests

Documentación, config estática que no afecta comportamiento, config de CI/infra
(se valida con linters y con la corrida de CI), código generado (modelos de ORM,
protobuf, stubs de OpenAPI), y los propios mocks, fixtures y helpers de test.

## Qué testear

1. **Caja negra** para lógica de negocio: entradas y salidas esperadas.
2. **Casos borde**: vacío, null, límites, caracteres especiales.
3. **Errores**: qué pasa cuando las cosas fallan, no solo el camino feliz.
4. **Contratos de API**: schema de respuesta, status codes, headers.
5. **El caso trivial**: el camino feliz más simple.

## Estructura

Un archivo de test por módulo. `describe` anida escenarios, `it` describe el caso
específico. Los nombres describen comportamiento esperado, no implementación:

- Bien: `it("returns 404 when user does not exist")`
- Mal: `it("test getUser with invalid id")`

## Cobertura

Líneas >= 80%, ramas >= 70%, funciones >= 90%. El 100% NO es la meta: la
cobertura mide ejecución, no calidad. Excluye tests, mocks, fixtures, config,
migraciones y código generado.

Para medir si los tests **detectan** cambios reales en el código, carga la skill
`mutation-testing` (score objetivo >= 80% en features críticas, se corre en CI,
no en cada commit). Una suite en verde prueba el comportamiento, nunca el diseño.
