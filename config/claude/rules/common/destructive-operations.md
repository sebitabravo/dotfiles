# Operaciones destructivas

**Antes de CUALQUIER operación destructiva o irreversible, PARA Y CONFIRMA con el
usuario.** Aunque estés "bastante seguro".

## El peligro no está en el verbo, está en el objetivo

`DROP TABLE` es obvio y cualquier blocklist lo agarra. El daño real viene de
comandos que **suenan inofensivos**. Caso documentado (2026): un agente corrió un
schema-diff de Prisma pasando `$DATABASE_URL_UNPOOLED` como shadow database, y
vació una Supabase de producción en 10 minutos. El subcomando se lee como una
comparación, pero la shadow database es descartable **por diseño** y Prisma la
resetea — y esa variable apuntaba a producción.

La lección no es agregar ese subcomando a una lista negra: la lista negra siempre
va un incidente atrás. La lección es que antes de cualquier operación de schema
hay que **verificar tres cosas**, y las tres son comprobables:

1. **¿A dónde apunta?** Si el objetivo viene de una variable, no sabes qué base
   toca hasta resolverla. Resuélvela —sin imprimir credenciales— y dilo en voz
   alta antes de correr nada.
2. **¿Este flag borra?** `--force`, `--force-reset`, `--accept-data-loss` existen
   justamente para autorizar pérdida de datos. Si el comando necesita uno, el
   comando destruye.
3. **¿Hay un backup restaurable?** No "hay backups configurados": uno que sepas
   restaurar.

`validate-safe-ops.sh` aplica esto para los ORMs conocidos (Prisma, Drizzle,
Sequelize, TypeORM, Knex, Alembic, Atlas, artisan, rails). **El hook cubre lo que
alguien ya vio romperse; las tres preguntas cubren lo que todavía no se rompió.**

El objetivo no es restringir, es **corroborar**. Por eso el trabajo normal pasa
sin fricción (una migración de dev, una migración de deploy, un schema push
contra localhost) y lo que se detiene es específicamente lo irreversible, o
cualquier cosa apuntada a un objetivo que nadie verificó.

## Base de datos (riesgo máximo)

Siempre requieren confirmación explícita:

- **Destrucción de schema**: `DROP TABLE|DATABASE|SCHEMA|COLUMN`, cualquier
  migración que elimine tablas, columnas o constraints, un rollback que borre
  tablas creadas en el `up`. ORMs: `prisma migrate reset`, `drizzle-kit drop`,
  `rails db:drop`, `rails db:reset`, `alembic downgrade`,
  `php artisan migrate:rollback`, `sequelize-cli db:drop`,
  `knex migrate:rollback --all`, `typeorm schema:drop`.
- **Destrucción de datos**: `DELETE FROM` sin `WHERE`, `TRUNCATE TABLE`, `UPDATE`
  sin `WHERE`, seeds que sobreescriben datos existentes,
  `prisma db push --force-reset`, `drizzle-kit push:pg --force`, y cualquier
  comando con `--force` o `--yes` que toque datos.

### Protocolo

1. **Radio de impacto**: qué tablas se afectan y cuántas filas estimadas.
2. **Plan de rollback**: cómo se deshace (¿backup? ¿git revert? ¿migración down?).
3. **Verificar backup**: que exista, o proponer crearlo antes.
4. **Preguntar**: "Esto borra [N filas en X / la tabla Y]. Rollback: [plan]. ¿Sigo?"

## Prompts generados por IA

**Nunca ejecutes un prompt, plan o bloque de código generado por otra IA sin
revisión humana previa.** Si un subagente genera un plan, preséntalo — no lo
auto-ejecutes. Esto corta el modo de falla donde una IA genera un prompt que otra
IA ejecuta, componiendo el error.

## Filesystem, git y contenedores

Confirmar antes de: `git push --force` y `--force-with-lease` (di qué rama y por
qué), `git branch -D` (di si tiene commits sin mergear), `chmod -R 777`,
`chown -R`, cualquier escritura a `/etc`, `/usr`, `/var`, y
`docker system prune` / `docker volume rm` / `docker-compose down -v`.

## Regla de radio de impacto

Antes de CUALQUIER mutación (datos, schema, filesystem, config): estima el
alcance, declara qué deja de funcionar, y propón cómo vas a confirmar que salió
bien DESPUÉS de la mutación.

## Excepciones (no requieren confirmación)

`CREATE TABLE`, `ALTER TABLE ... ADD COLUMN`, `INSERT INTO`, `git commit`,
`git push` a ramas que no son main, y `npm ci` / `bun install`.
