---
description: "Estándares de código universales — aplican a todos los lenguajes"
globs: []
alwaysApply: true
---

# Coding Style

## Principios

- **Legibilidad primero**. Código se lee 10x más de lo que se escribe.
- **Nombres expresivos**. Sin abreviaturas crípticas. `getUserById` no `gUBI`.
- **Funciones cortas**. Una responsabilidad, un nivel de abstracción. Si necesitás "y" en el nombre, dividila.
- **Menos de 4 parámetros**. Si necesitás más, usá un objeto/dto.
- **Sin comentarios obvios**. El código debe explicarse solo. Comentarios solo para el WHY no el WHAT.

## Estructura

- **DRY a escala de módulo**, no de proyecto. 3 líneas duplicadas en 2 lados = helper. 2 líneas en 1 solo = dejalo.
- **Inmutabilidad por defecto**. `const` > `let`. Evitar mutación de parámetros.
- **Early returns** sobre if/else anidados.
- **Sin magic numbers**. Constantes nombradas o enums.

## Formato

- El formateador del lenguaje manda. Sin discusiones.
- Líneas de máximo 120 caracteres (salvo URLs, strings largos).
- Un espacio entre funciones de nivel superior. Sin líneas en blanco dentro de bloques cortos.
