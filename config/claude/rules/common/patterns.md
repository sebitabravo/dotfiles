---
description: "Patrones de arquitectura y diseño — SOLID, composición, capas"
globs: []
alwaysApply: true
---

# Architecture Patterns

## SOLID aplicado

1. **Single Responsibility**: una clase/módulo = una razón para cambiar. Si el nombre tiene "y", dividilo.
2. **Open/Closed**: extensible sin modificar. Nuevo comportamiento = nueva clase, no editar la existente.
3. **Liskov**: subtipos deben ser sustituibles por su base. Si necesitás `instanceof`, rompiste LSP.
4. **Interface Segregation**: interfaces chicas y específicas. No obligues a implementar lo que no se usa.
5. **Dependency Inversion**: dependé de abstracciones, no de implementaciones concretas.

## Composición sobre herencia

- **Herencia**: relación "es-un". Jerarquías planas, máximo 2 niveles de profundidad.
- **Composición**: relación "tiene-un". Inyectá comportamientos, no los heredes.
- Si necesitás herencia múltiple → composición.

## Separación por capas

```
Controller → Service → Repository → Data Source
   ↓            ↓
  HTTP       Lógica de     Acceso a     DB/API
  request     negocio       datos        externa
```

- **Controllers**: parsean input, delegan a service, formatean response. Sin lógica de negocio.
- **Services**: lógica de negocio pura. Sin conocimiento de HTTP o DB.
- **Repositories**: acceso a datos. Sin lógica de negocio.

## Principios de diseño

- **YAGNI**: no construyas para "por las dudas". Solo lo que se necesita ahora.
- **KISS**: la solución más simple que funciona. Sin abstracciones prematuras.
- **Polymorphism > conditionals**: un `switch`/`if-else` gigante = candidate a polimorfismo.
- **Tell, Don't Ask**: decile al objeto qué hacer, no le preguntes su estado para decidir vos.
