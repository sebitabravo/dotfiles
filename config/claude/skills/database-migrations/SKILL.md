---
name: database-migrations
description: Safe database migration patterns: zero-downtime, backward-compatible, rollback-ready. Use when writing migrations, reviewing schema changes, or planning data backfills.
---

# Database Migrations

Migraciones seguras con foco en zero-downtime y rollback.

## When to Use

- Escribir o revisar migraciones.
- Agregar columnas, tablas, índices.
- Modificar constraints en producción.
- Planificar backfill de datos.
- El usuario pregunta sobre migraciones o schema changes.

## Golden Rules

1. **Toda migración debe ser reversible**. Si tenés `up`, tenés `down`.
2. **Nunca bloquear la tabla por más de 2 segundos**. Usar estrategias sin lock.
3. **Expand & Contract**: primero agregar, luego migrar datos, luego eliminar lo viejo.
4. **Backfill en batches**. Nunca un solo UPDATE sobre millones de filas.

## Patterns

### Agregar columna NOT NULL

Mal:
```sql
ALTER TABLE users ADD COLUMN status VARCHAR NOT NULL;  -- bloquea toda la tabla
```

Bien:
```sql
-- Paso 1: nullable con default
ALTER TABLE users ADD COLUMN status VARCHAR DEFAULT 'active';

-- Paso 2: backfill en batches (en código, no en migración)
-- UPDATE users SET status = 'active' WHERE status IS NULL LIMIT 10000;

-- Paso 3: agregar NOT NULL cuando todos los registros tienen valor (próximo deploy)
ALTER TABLE users ALTER COLUMN status SET NOT NULL;
```

### Renombrar columna

```sql
-- Paso 1: agregar nueva columna
ALTER TABLE users ADD COLUMN full_name VARCHAR;

-- Paso 2: escribe en ambas columnas desde la app
-- Paso 3: backfill de datos históricos
-- Paso 4: migrar lecturas a nueva columna
-- Paso 5: eliminar columna vieja (próximo deploy)
ALTER TABLE users DROP COLUMN name;
```

### Agregar índice

```sql
-- CONCURRENTLY evita bloquear escrituras (PostgreSQL)
CREATE INDEX CONCURRENTLY idx_users_email ON users (email);
```

MySQL: `ALGORITHM=INPLACE, LOCK=NONE` en InnoDB.

### Eliminar columna/tabla

Mal:
```sql
ALTER TABLE users DROP COLUMN old_field;  -- ¿seguro que nadie la lee?
```

Bien:
1. Deploy 1: Dejar de escribir en la columna. App ignora reads.
2. Deploy 2: Eliminar columna (ya sin tráfico).

## Validación pre-deploy

- `down` migration testeada en staging.
- `EXPLAIN` para nuevas queries. Sin full table scans en tablas grandes.
- Constraints validados con datos de producción (copia anonimizada).
- Tiempo estimado de migración basado en `ANALYZE` de la tabla real.

## Frameworks

| Framework | Nullable | Default | Concurrent Index | Rollback |
|---|---|---|---|---|
| **Prisma** | `?` en tipo | `@default()` | No nativo | `prisma migrate diff` |
| **Django** | `null=True` | `default=` | `AddIndexConcurrently` | `migrate <app> <prev>` |
| **Laravel** | `->nullable()` | `->default()` | Manual (raw SQL) | `migrate:rollback` |
| **golang-migrate** | Tipo puntero `*string` | Default en SQL | Raw SQL en `.up.sql` | `.down.sql` explícito |
| **Alembic** | `nullable=True` | `server_default=` | `postgresql_concurrently=True` | `alembic downgrade -1` |
