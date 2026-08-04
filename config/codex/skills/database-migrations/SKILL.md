---
name: database-migrations
description: Safe database migration patterns: zero-downtime, backward-compatible, rollback-ready. Use when writing migrations, reviewing schema changes, or planning data backfills.
---

# Database Migrations

Safe migrations focused on zero-downtime and rollback.

## When to Use

- Writing or reviewing migrations.
- Adding columns, tables, indexes.
- Modifying constraints in production.
- Planning data backfills.
- User asks about migrations or schema changes.

## Golden Rules

1. **Every migration must be reversible**. If you have `up`, you have `down`.
2. **Never block the table for more than 2 seconds**. Use lock-free strategies.
3. **Expand & Contract**: first add, then migrate data, then remove the old.
4. **Backfill in batches**. Never a single UPDATE over millions of rows.

## Patterns

### Adding a NOT NULL column

Bad:
```sql
ALTER TABLE users ADD COLUMN status VARCHAR NOT NULL;  -- blocks the entire table
```

Good:
```sql
-- Step 1: nullable with default
ALTER TABLE users ADD COLUMN status VARCHAR DEFAULT 'active';

-- Step 2: backfill in batches (in code, not in migration)
-- UPDATE users SET status = 'active' WHERE status IS NULL LIMIT 10000;

-- Step 3: add NOT NULL when all rows have a value (next deploy)
ALTER TABLE users ALTER COLUMN status SET NOT NULL;
```

### Renaming a column

```sql
-- Step 1: add new column
ALTER TABLE users ADD COLUMN full_name VARCHAR;

-- Step 2: write to both columns from the app
-- Step 3: backfill historical data
-- Step 4: migrate reads to new column
-- Step 5: drop old column (next deploy)
ALTER TABLE users DROP COLUMN name;
```

### Adding an index

```sql
-- CONCURRENTLY avoids blocking writes (PostgreSQL)
CREATE INDEX CONCURRENTLY idx_users_email ON users (email);
```

MySQL: `ALGORITHM=INPLACE, LOCK=NONE` on InnoDB.

### Dropping a column/table

Bad:
```sql
ALTER TABLE users DROP COLUMN old_field;  -- sure no one reads it?
```

Good:
1. Deploy 1: Stop writing to the column. App ignores reads.
2. Deploy 2: Drop column (no traffic anymore).

## Pre-deploy Validation

- `down` migration tested in staging.
- `EXPLAIN` for new queries. No full table scans on large tables.
- Constraints validated against production data (anonymized copy).
- Estimated migration time based on real table `ANALYZE`.

## Frameworks

| Framework | Nullable | Default | Concurrent Index | Rollback |
|---|---|---|---|---|
| **Prisma** | `?` in type | `@default()` | Not native | `prisma migrate diff` |
| **Django** | `null=True` | `default=` | `AddIndexConcurrently` | `migrate <app> <prev>` |
| **Laravel** | `->nullable()` | `->default()` | Manual (raw SQL) | `migrate:rollback` |
| **golang-migrate** | Pointer type `*string` | Default in SQL | Raw SQL in `.up.sql` | Explicit `.down.sql` |
| **Alembic** | `nullable=True` | `server_default=` | `postgresql_concurrently=True` | `alembic downgrade -1` |
