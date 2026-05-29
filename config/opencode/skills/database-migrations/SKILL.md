---
name: database-migrations
description: Database migration patterns, schema evolution, rollback strategies, seed data management, and migration testing across PostgreSQL, MySQL, and SQLite.
---

## Migration Conventions

### Naming

```
migrations/
├── 001_create_users_table.sql
├── 002_add_email_to_users.sql
├── 003_create_orders_table.sql
└── seed/
    └── 001_dev_users.sql
```

- Sequential numeric prefix (zero-padded)
- Snake_case description
- Each migration: UP + DOWN

### Structure (SQL)

```sql
-- UP: 005_add_status_to_orders.sql
ALTER TABLE orders ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'pending';
CREATE INDEX idx_orders_status ON orders(status);

-- DOWN: 005_add_status_to_orders.sql
DROP INDEX IF EXISTS idx_orders_status;
ALTER TABLE orders DROP COLUMN IF EXISTS status;
```

### Structure (Prisma)

```prisma
// schema.prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  posts Post[]
}

model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  published Boolean  @default(false)
  authorId  String
  author    User     @relation(fields: [authorId], references: [id], onDelete: Cascade)

  @@index([authorId])
  @@map("posts")
}
```

## Safe Migration Patterns

### Add Column (Non-Breaking)

```sql
-- SAFE: Add nullable column
ALTER TABLE users ADD COLUMN phone VARCHAR(20);

-- SAFE: Add column with default (instant on PG 11+)
ALTER TABLE users ADD COLUMN role VARCHAR(20) NOT NULL DEFAULT 'user';
```

### Remove Column (3-Step)

```sql
-- Step 1: Stop writing to column (deploy code change)
-- Step 2: Remove column
ALTER TABLE users DROP COLUMN phone;
-- Step 3: Clean up (if needed)
```

### Rename Column (3-Step)

```sql
-- Step 1: Add new column alongside old
ALTER TABLE users ADD COLUMN email_address VARCHAR(255);
-- Step 2: Migrate data + dual-write in code
UPDATE users SET email_address = email WHERE email_address IS NULL;
-- Step 3: Drop old column after code migration
ALTER TABLE users DROP COLUMN email;
```

### Add Index Without Locking

```sql
-- PostgreSQL: CONCURRENTLY (no write lock)
CREATE INDEX CONCURRENTLY idx_users_email_lower ON users (LOWER(email));

-- MySQL: ALGORITHM=INPLACE, LOCK=NONE
ALTER TABLE users ADD INDEX idx_email (email), ALGORITHM=INPLACE, LOCK=NONE;
```

### Data Migration

```sql
-- Batched migration (avoids locking)
-- Do in application code or script
BEGIN;
UPDATE orders SET status = 'pending' WHERE status IS NULL LIMIT 1000;
COMMIT;
-- Repeat until 0 rows affected
```

## Orm-Specific Patterns

### Prisma

```bash
npx prisma migrate dev --name add_user_roles    # Dev: create + apply
npx prisma migrate deploy                         # Prod: apply only
npx prisma migrate status                         # Check state
npx prisma migrate reset                          # Dev: reset DB
```

### Drizzle

```typescript
import { pgTable, uuid, varchar, timestamp } from 'drizzle-orm/pg-core'

export const users = pgTable('users', {
  id: uuid('id').defaultRandom().primaryKey(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  name: varchar('name', { length: 100 }),
  createdAt: timestamp('created_at').defaultNow().notNull(),
})

// Migration generation
// npx drizzle-kit generate
// npx drizzle-kit migrate
```

### Knex

```typescript
import { Knex } from 'knex'

export async function up(knex: Knex): Promise<void> {
  await knex.schema.createTable('users', (table) => {
    table.uuid('id').primary().defaultTo(knex.raw('gen_random_uuid()'))
    table.string('email', 255).notNullable().unique()
    table.string('name', 100)
    table.timestamps(true, true)
  })
}

export async function down(knex: Knex): Promise<void> {
  await knex.schema.dropTableIfExists('users')
}
```

## Testing Migrations

```typescript
// Test migration up + down is idempotent
import { migrate } from 'drizzle-orm/postgres-js/migrator'

test('migration is reversible', async () => {
  await migrate(db, { migrationsFolder: './drizzle' })
  await migrate(db, { migrationsFolder: './drizzle' }) // idempotent
  // Verify schema
  const result = await db.execute(sql`SELECT column_name FROM information_schema.columns WHERE table_name = 'users'`)
  expect(result.rows).toContainEqual(expect.objectContaining({ column_name: 'email' }))
})
```

## Rules

- Every migration needs a rollback (DOWN).
- Non-breaking changes only: add columns, add indexes, add tables.
- Breaking changes = multi-step migration over multiple deploys.
- Batch data migrations to avoid locks.
- Test migration up + down in CI.
- Never modify a committed migration. Create a new one.
- `CONCURRENTLY` for index creation on large tables.
- Seed data separate from migrations.
