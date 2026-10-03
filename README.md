# Flyway + PostgreSQL demo

A small demo of managing PostgreSQL schema changes with [Flyway](https://flywaydb.org/) and GitHub Actions.
On every push to `main` and every pull request, GitHub Actions starts a throwaway Postgres 16 container
and applies all migrations from an empty database.

## Layout

```
.github/workflows/flyway.yml   CI pipeline
docker-compose.yml             local Postgres + Flyway
flyway.conf                    Flyway settings (no secrets)
sql/
  V1__create_customer_table.sql
  V2__create_orders_table.sql
  V3__add_customer_email_index.sql
  V4__seed_sample_data.sql
  R__customer_order_summary_view.sql
```

Naming rules: `V<version>__<description>.sql` (two underscores) runs once, in version order.
`R__<description>.sql` is repeatable and re-runs whenever its contents change.

## Run locally (Docker required)

```bash
docker compose up --abort-on-container-exit
docker compose run --rm flyway -url=jdbc:postgresql://postgres:5432/demo -user=demo -password=demo info
```

Inspect the result:

```bash
docker compose exec postgres psql -U demo -d demo -c "select * from customer_order_summary;"
```

Reset everything:

```bash
docker compose down -v
```

## Publish to GitHub

```bash
git init
git checkout -b main
git add .
git commit -m "Initial Flyway demo"
gh repo create flyway-postgres-demo --public --source=. --push
# or: git remote add origin https://github.com/<you>/flyway-postgres-demo.git && git push -u origin main
```

Then open the **Actions** tab to watch the workflow run.

## Things to try

1. **Add a migration via PR.** Create a branch and add `sql/V5__add_order_status.sql`:
   `ALTER TABLE orders ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'NEW';`
   Open a PR; CI proves it applies cleanly on top of V1-V4.
2. **See checksum protection.** Edit an already-applied `V` file and run `migrate` against the local
   compose database. Flyway fails with a checksum mismatch. Applied migrations are immutable; fix forward
   with a new version.
3. **Repeatable migration.** Edit `R__customer_order_summary_view.sql` and re-run. Flyway re-applies it.
4. **Version collision.** Have two branches both add `V5__...`; the second to merge shows why version
   numbers need coordination (or `outOfOrder` with care).

## Taking it further

- Real target database: store the URL/user/password as repository secrets and reference them as
  `${{ secrets.DB_URL }}` etc. Add a GitHub Environment with required reviewers for an approval gate.
- Branch protection: require the Flyway check to pass before merging to `main`.
- Existing database: `flyway baseline -baselineVersion=1` marks its current state as the starting point.
- Rollbacks: undo migrations (`U__`) are a paid Flyway edition feature; with Community edition,
  roll forward with a corrective migration.
