# {{PROJECT_NAME}}

<!--
COMO USAR ESTE TEMPLATE
  1. Copialo a la raiz del proyecto como CLAUDE.md
  2. Llena solo lo que el agente NO puede deducir leyendo el codigo
  3. Borra las secciones que no apliquen — un template a medio llenar es peor que uno corto
  4. Objetivo: menos de 150 lineas. Se carga en CADA sesion, cada linea se paga siempre

REGLA DE ORO — el test de derivabilidad:
  Antes de escribir una linea, pregunta: "¿un agente leyendo el codigo lo descubriria solo?"
    SI  -> no lo escribas (stack, estructura de carpetas, scripts del package.json, firmas de API)
    NO  -> escribilo (por que existe, que reglas de negocio son inviolables, que rompe en produccion)

  El codigo dice QUE hace el sistema. Este archivo dice POR QUE, y que pasa si lo rompes.
-->

## Que es esto

<!-- 2-4 lineas. El negocio, no la tecnologia. Alguien ajeno al proyecto tiene que entender que problema resuelve. -->

{{Una o dos frases: que problema real resuelve y para quien.}}

**Usuario objetivo**: {{quien lo usa, en que contexto, con que nivel tecnico}}

**Como gana plata / cual es la metrica que importa**: {{revenue, retencion, tiempo ahorrado, cumplimiento normativo... lo que define el exito}}

## Reglas de dominio (inviolables)

<!--
Las reglas de NEGOCIO que el codigo debe respetar siempre, y que no son evidentes leyendolo.
Si se rompe una de estas, hay consecuencia real: plata perdida, multa, dato corrupto, usuario dañado.
Numeralas. Se especifico. Nada de "manejar bien los errores".

Ejemplos del formato correcto:
  1. Un pedido NUNCA se despacha sin pago confirmado. El estado `paid` es el unico que habilita `dispatch()`.
  2. Los precios se guardan en centavos (integer). Nunca float — un redondeo de 0.01 en 10k transacciones es una diferencia contable real.
  3. Un usuario no puede ver datos de otro tenant. Toda query lleva `WHERE tenant_id = ?`. Sin excepcion.
  4. Las boletas emitidas no se editan ni se borran. Correccion = nota de credito. Es requisito del SII.
-->

1. {{regla}}
2. {{regla}}
3. {{regla}}

## Que NO construir (anti-objetivos)

<!--
Decisiones ya tomadas de que queda FUERA. Evita que el agente "ayude" agregando cosas que no queres.
Incluye el por que: sin la razon, el agente lo interpreta como un pendiente en vez de una decision.

Ejemplos:
  - NO multi-idioma. Mercado unico Chile, agregar i18n ahora es complejidad sin retorno.
  - NO panel de admin propio. Se usa Retool, decision tomada para no mantener CRUD interno.
  - NO microservicios. Monolito modular hasta 50k usuarios, esta medido y alcanza.
-->

- NO {{cosa}} — {{por que}}
- NO {{cosa}} — {{por que}}

## Glosario de dominio

<!--
Terminos del negocio que aparecen en el codigo y significan algo especifico aca.
Solo los que un dev nuevo malinterpretaria. Si el termino es obvio, no lo pongas.

Ejemplos:
  | Termino | Significa aca |
  | "cliente" | La empresa que contrata, NO el usuario final. El usuario final es "beneficiario". |
  | "activo" | Pago al dia Y con sesion en los ultimos 30 dias. Un usuario pago pero inactivo NO es "activo". |
  | "ciclo" | Periodo de facturacion, no el ciclo de vida del pedido. |
-->

| Termino | Significa aca |
|---|---|
| {{termino}} | {{definicion precisa}} |

## Gotchas

<!--
Cosas que parecen un bug pero son intencionales, y trampas que ya costaron tiempo.
Cada una evita que el agente "arregle" algo que funciona, o que repita un error conocido.

Ejemplos:
  - `sync_legacy()` corre secuencial a proposito. El proveedor tira 429 con concurrencia. No lo paralelices.
  - Los tests de `billing/` necesitan `TZ=America/Santiago`. Con otra timezone fallan por el corte de medianoche.
  - El campo `status` tiene un valor `pending_v1` que parece muerto — lo usan 300 registros historicos. No lo saques.
-->

- {{gotcha}}
- {{gotcha}}

## Comandos no obvios

<!--
Solo los que el agente NO puede sacar del package.json / Makefile / pyproject.toml.
Si es `npm test`, no lo escribas. Si requiere un flag raro, una variable de entorno o un orden especifico, si.

Ejemplos:
  | Para | Comando |
  | Correr tests de integracion | `docker compose up -d db && TZ=America/Santiago npm run test:int` |
  | Regenerar tipos del schema | `npm run db:types` (despues de CADA migracion, sino el build falla en CI) |
  | Seed de datos realistas | `npm run seed -- --profile=demo` |
-->

| Para | Comando |
|---|---|
| {{tarea}} | `{{comando}}` |

## Setup del entorno

<!-- Solo lo que no esta en el README o que el README dice mal. Variables requeridas, servicios externos, credenciales. Borra esta seccion si el README ya alcanza. -->

{{requisitos no obvios}}

---

<!--
QUE NO PONER ACA (el agente ya lo sabe o lo deduce):
  - El stack (lo dice package.json / go.mod / pyproject.toml)
  - La estructura de carpetas (la ve con ls)
  - Como funciona React/Django/Laravel (lo sabe)
  - "escribi codigo limpio", "manejo de errores", "agrega tests" (esta en las reglas globales)
  - Documentacion de API copiada del codigo (se desactualiza y miente)
  - Reglas que el linter ya enforcea (redundante — el linter gana igual)

Si el agente hace algo mal repetidamente y la regla YA esta escrita aca, el archivo es muy largo
y la regla se pierde en el ruido. Recorta antes de agregar.
-->
