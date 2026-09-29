# Herramientas

Primero las nativas: `Read` / `Grep` / `Glob` para leer, buscar y listar — sin
prompt de permiso y el harness sigue el estado de los archivos.

Cuando la tarea necesita shell de verdad (pipes, builds, inspeccionar un árbol),
prefiere el reemplazo moderno: `eza`, `fd`, `rg`, `bat`, `uv`, `bun`. Disponibles
sin default que reemplazar: `jq`, `fzf`, `gh`, `delta`, `brew`, `ffmpeg`,
`magick`, `helm`, `actionlint`. Si falta una, no la instales: usa el runner local
del proyecto o reporta la limitación del host.

`z` (zoxide) es una función de shell y NO existe en la tool Bash. Usa rutas
absolutas; `cd` dentro de un comando compuesto además dispara prompt de permiso.
