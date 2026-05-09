---
description: "SOLID, composition, layered architecture — design patterns"
globs: []
alwaysApply: true
---

# Architecture Patterns

## SOLID applied

1. **Single Responsibility**: one class/module = one reason to change. If the name has "and", split it.
2. **Open/Closed**: extensible without modification. New behavior = new class, don't edit existing one.
3. **Liskov**: subtypes must be substitutable for their base. If you need `instanceof`, LSP is broken.
4. **Interface Segregation**: small, specific interfaces. Don't force implementing what isn't used.
5. **Dependency Inversion**: depend on abstractions, not concrete implementations.

## Composition over inheritance

- **Inheritance**: "is-a" relationship. Flat hierarchies, max 2 levels deep.
- **Composition**: "has-a" relationship. Inject behaviors, don't inherit them.
- If you need multiple inheritance → composition.

## Layered separation

```
Controller → Service → Repository → Data Source
   ↓            ↓
  HTTP       Business      Data        DB/API
  request     logic        access      external
```

- **Controllers**: parse input, delegate to service, format response. No business logic.
- **Services**: pure business logic. No knowledge of HTTP or DB.
- **Repositories**: data access. No business logic.

## Design principles

- **YAGNI**: don't build for "just in case". Only what's needed now.
- **KISS**: the simplest solution that works. No premature abstractions.
- **Polymorphism > conditionals**: a giant `switch`/`if-else` = candidate for polymorphism.
- **Tell, Don't Ask**: tell the object what to do, don't ask its state to decide yourself.
