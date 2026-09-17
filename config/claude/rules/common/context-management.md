# Manejo de contexto

La compactación es automática y no la controlas. Lo que sí controlas es qué queda
escrito antes de que la ventana se dé vuelta: `mem_save` (Engram) y `/handoff`.
**Escribe el razonamiento antes, no después.**

## Qué tiene que contener lo que guardas

Un resumen que solo enumera acciones es truncamiento disfrazado — el modelo ve
qué pasó pero no cómo llegó ahí, y vuelve a derivar todo de cero.

1. **Razonamiento**: qué se decidió, por qué sobre las alternativas, y qué se
   descartó con su motivo.
2. **Descubrimientos**: hallazgos no obvios, casos borde, rarezas de una API o
   una config. Lo que le ahorraría a una sesión futura repetir un error.
3. **Pendientes**: qué quedó sin resolver y qué preguntas siguen abiertas.

```text
// MAL — truncamiento con otro nombre.
"Arreglado el bug del middleware de auth. Tests agregados. Todo verde."

// BIEN — preserva la cadena de razonamiento.
"Bug en middleware de auth: el chequeo de expiry usaba < en vez de <= en L42.
 Descartado: offset de timezone (los datos tz estaban bien), bug de la librería
 JWT (los logs de decode estaban limpios).
 Fix: cambio de operador + test de borde en medianoche.
 Trade-off: una validación extra en el caso borde, evita rechazos falsos."
```

## Cuándo guardar

Apenas una sección queda genuinamente cerrada: tarea terminada, decisión tomada,
exploración agotada. No esperes a que la ventana se llene.

## Después de una compactación

1. Relee los archivos que estabas editando. No confíes en tu resumen del
   contenido por sobre el archivo.
2. `mem_context` y `mem_search` para recuperar el porqué de decisiones ya
   tomadas, en vez de re-derivarlas.
3. No re-litigues una decisión que el usuario ya aprobó.

## Mantener la ventana usable

Delega la exploración pesada de archivos a subagentes (20 lecturas cuestan un
resumen), acota las investigaciones, y prefiere `codegraph explore` o un `rg`
dirigido antes que leer un archivo entero para encontrar un símbolo.
