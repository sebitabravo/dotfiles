---
name: handoff
description: Crea un archivo HANDOFF.md con el estado actual del proyecto para un traspaso limpio entre sesiones. Usar cuando la sesión está larga, el modelo da vueltas con la misma solución, o antes de hacer /clear. El archivo se archiva automáticamente al iniciar la siguiente sesión.
---

# Handoff — Traspaso limpio entre sesiones

Genera un archivo `HANDOFF.md` en la raíz del proyecto con TODO el contexto necesario para que una sesión nueva continúe sin arrastrar basura.

## Cuándo usar

- Sesión larga (>30 min) y el modelo empieza a repetir patrones
- 3+ intentos fallidos con la misma solución
- Antes de hacer `/clear` o cerrar la sesión
- Cuando el usuario dice "handoff", "traspaso", o "crea handoff"

## Estructura del HANDOFF.md

Generar el archivo con ESTE formato exacto:

```markdown
# Handoff — [fecha/hora]

## Objetivo
[Qué estamos tratando de lograr. Una frase clara. Sin ambigüedad.]

## Estado Actual
[Dónde estamos. Qué funciona. Qué NO funciona. Sé honesto — esto es lo mas importante.]

## Archivos Clave
- `ruta/absoluta/archivo.ts` — qué es y por qué importa
- `ruta/absoluta/otro.tsx` — qué es y por qué importa

## Cambios Hechos
- [Cambio 1] — por qué se hizo
- [Cambio 2] — por qué se hizo

## Intentos Fallidos
- [Intento 1] — por qué falló. NO repetir este approach.
- [Intento 2] — por qué falló. NO repetir este approach.

## Próximos Pasos
1. [Paso concreto 1]
2. [Paso concreto 2]
3. [Paso concreto 3]

## Notas
[Cualquier contexto extra: convenciones, decisiones, advertencias, estado de git]
```

## Reglas

- **Sin ficción.** Si algo no se probó, decir "no verificado".
- **Fallos > éxitos.** Documentar lo que NO funcionó es más valioso que lo que sí.
- **Rutas absolutas.** Nada de `./` o `../`.
- **Sobrescribir sin miedo.** Si ya existe HANDOFF.md, pisarlo (es más fresco).
- **No hagas commit de HANDOFF.md.** Es temporal. Está en .gitignore o debería estarlo.

## Post-generación

1. Decir explícitamente: "HANDOFF.md creado. Cerrá esta sesión y abrí una nueva. Leerá el handoff automáticamente."
2. No seguir trabajando después de generar el handoff. El punto es CERRAR la sesión.
