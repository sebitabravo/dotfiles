# Estilo de código

## Comentarios

**Los comentarios van en español**, porque quien los lee es quien lee este chat.

**El ruido generado por IA está prohibido.** Borra cualquier comentario que
duplique lo que el código ya dice. Si el comentario es más largo que el código
que describe, lo que hace falta es refactorizar, no comentar.

- Nada de narración por línea (`// recorre los items`, `// chequea si es null`).
- Nada de anotaciones de llave de cierre (`} // if`, `} // for`).
- Solo sobreviven los que explican: (a) el porqué de un diseño, (b) un workaround
  no obvio con referencia al issue, (c) una referencia externa (RFC, URL), (d) un
  TODO o FIXME con contexto.

Ante la duda, borra el comentario. Confía en el código.

## Umbrales concretos

- **Más de 4 parámetros** → pasa un objeto o DTO.
- **DRY a escala de módulo, no de proyecto.** 3 líneas duplicadas en 2 lugares =
  helper. 2 líneas en 1 lugar = déjalo.
- **Máximo 120 caracteres por línea** (salvo URLs y strings largos).
- Si el nombre de una función necesita un "y", divídela.

## Edición

- **Ediciones dirigidas antes que reescrituras.** Prefiere `Edit` sobre `Write` en
  un archivo que ya existe. Una reescritura completa convierte un cambio de tres
  líneas en un diff irrevisable, y cada línea que reformatea en silencio es una
  línea que nadie revisó.
- **Nada de refactors de paso.** Toca solo lo que la tarea exige. Un bug fix no
  limpia el código de alrededor; una feature chica no gana configurabilidad
  extra. Los cambios no pedidos esconden el arreglo real.
- **Diagnostica antes de arreglar.** Cuando el código tiene un defecto real,
  nombra el anti-patrón y explica la causa técnica antes de proponer el fix más
  chico que sea seguro. Un parche sin diagnóstico no enseña nada y se vuelve a
  romper la próxima vez.

## Formato

Manda el formateador del lenguaje. Sin debates. Una línea en blanco entre
funciones de nivel superior, ninguna dentro de bloques cortos.
