# Pack: Ley 21.595 — Delitos Económicos (Modelo de Prevención de Delitos)

> **Ya vigente** (desde 1-sep-2024). Amplía la Ley 20.393 y puede generar responsabilidad penal de la
> persona jurídica. El alcance debe clasificarse por delito y categoría: el artículo 6 excluye los
> Títulos II y III para los delitos de los artículos 2 y 3, y para los números 2 y 3 del artículo 4,
> cuando se cometen en el contexto o beneficio de una micro o pequeña empresa. Por eso una SpA de una
> persona no se clasifica automáticamente sólo por su forma jurídica; el **Modelo de Prevención de
> Delitos (MPD)** debe ser **idóneo, eficaz y proporcional** al tamaño y a los riesgos concretos.

## Controles que exige (ver `references/controls.md`)
`gov-responsable` (oficial de prevención), `gov-registro` (matriz de riesgos), `gov-politicas` (código de
ética), `gov-denuncias` (canal anónimo), `gov-capacitacion`, `gov-auditoria` (supervisión externa),
`gov-disciplinario`, `ctrl-interno` (segregación de funciones / autorizaciones).

## Componentes mínimos del MPD
1. Encargado de Prevención designado con autonomía (acta).
2. Identificación de riesgos por proceso (matriz).
3. Controles internos (autorizaciones, segregación de funciones, control financiero).
4. Canal de denuncias anónimo + protección al denunciante (reglamento).
5. Capacitación periódica.
6. Régimen disciplinario.
7. **Supervisión externa periódica (anual) por un tercero independiente** — reemplazó a la antigua
   certificación; sin ella el modelo no se considera "adecuado". (Único componente NO self-service:
   requiere un tercero, ~UF 3-5; no necesariamente abogado.)

## Foco de riesgo para un SaaS
Delitos informáticos (acceso/uso indebido de datos de terceros), tributarios, lavado/cohecho, fraude,
y el cruce con la Ley 21.719 (uso indebido de datos personales).

## Documentos a generar (templates/ → `<repo>/.compliance/docs/` con prefijo `21595-`)
`modelo-prevencion-delitos.md`, `codigo-etica.md`, `matriz-riesgos.md`,
`acta-encargado-prevencion.md`, `reglamento-canal-denuncias.md`.

## Nota
La parte central es **organizacional** (designar, operar el canal, capacitar, supervisión externa anual).
La skill genera los documentos base; la implementación y la supervisión externa las ejecuta la empresa.
