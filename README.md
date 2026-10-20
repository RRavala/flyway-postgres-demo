# Flyway + PostgreSQL demo

Manage PostgreSQL schema changes as versioned SQL files with [Flyway](https://flywaydb.org/) and
GitHub Actions. Two pipelines work together:

| Pipeline | File | Trigger | What it does |
|---|---|---|---|
| **CI check** | `.github/workflows/flyway.yml` | Every pull request and every push to `main` | Proves the migrations apply cleanly on a throwaway Postgres 16 container |
| **Environment deploy** | `.github/workflows/flyway-deploy.yml` | Manual (Actions tab > Run workflow) | Applies migrations to the environment you pick: `dev`, `stage` or `prod` |

The databases themselves (RDS/Aurora or anything else) are created outside this repo. This repo only
changes what is *inside* them.

## Layout

```
.github/workflows/
  flyway.yml          CI check on PRs and main
  flyway-deploy.yml   Manual deploy to dev / stage / prod
docker-compose.yml    Local Postgres + Flyway
flyway.conf           Flyway settings (no secrets)
sql/
  V1__create_customer_table.sql
  V2__create_orders_table.sql
  V3__add_customer_email_index.sql
  V4__seed_sample_data.sql
  V5__add_order_status.sql
  R__customer_order_summary_view.sql
```

Naming rules: `V<version>__<description>.sql` (two underscores) runs once, in version order.
`R__<description>.sql` is repeatable and re-runs whenever its contents change.

## How the pipeline works

### 1. CI check (`flyway.yml`)

Runs automatically on every PR and every push to `main`:

1. Starts a fresh Postgres 16 service container (empty database).
2. `flyway info` shows what is pending.
3. `flyway migrate` applies every file in `sql/` from scratch.
4. `flyway validate` confirms applied checksums match the files.
5. `flyway info` shows the final state.

If any migration has a syntax error, a bad dependency or a version problem, the check fails
before the change can be merged. Nothing real is touched.

### 2. Environment deploy (`flyway-deploy.yml`)

Run it from **Actions > Flyway deploy (choose environment) > Run workflow** and choose:

- **Target environment**: `dev`, `stage` or `prod`
- **Flyway command**: `info` (show status only), `validate` (check checksums only) or `migrate` (apply pending changes, default)

The workflow has two jobs:

1. **verify**: rehearses all migrations on a throwaway Postgres container. If this fails, the
   deploy job never starts. For `stage` and `prod` this job also refuses to run unless the workflow was started from the `main` branch,
   so unmerged changes cannot reach those environments. `dev` can be deployed from any branch, which is handy for testing a PR.
2. **deploy**: runs in the GitHub Environment you chose, reads that environment's database
   credentials, and runs `info`, then your chosen command, then `info` again (after a `migrate`) so the
   log shows exactly what changed.

Because the job is tied to a GitHub Environment, you can require reviewer approval for `stage` and
`prod` so a person has to click Approve before anything runs.

## One-time setup

1. **Create three GitHub Environments**: Settings > Environments > New environment, named exactly
   `dev`, `stage` and `prod`.
2. **Add these secrets to each environment** (values differ per environment):

   | Secret | Example |
   |---|---|
   | `DB_JDBC_URL` | `jdbc:postgresql://<host>:5432/<database>` |
   | `DB_USER` | the Flyway/deploy user for that database |
   | `DB_PASSWORD` | that user's password |

3. **(Recommended) Protect stage and prod**: in those environments enable *Required reviewers*, and
   optionally limit *Deployment branches* to `main`.
4. **(If the databases are private) Use a runner inside your network**: GitHub-hosted runners use changing public
   IPs and cannot reach a private database. Register a self-hosted runner that can reach the
   databases, then set a repository variable (Settings > Secrets and variables > Actions > Variables)
   named `RUNNER_LABEL` to that runner's label. Without it, the deploy job uses `ubuntu-latest`.
   The runner needs Docker, since Flyway runs from the `redgate/flyway` image.
5. **(Recommended) Branch protection**: require the `Flyway migrate` check to pass before merging to `main`.

The deploy user needs enough rights to create and alter objects in the target schema
(`public`, per `flyway.conf`). Flyway also creates its own `flyway_schema_history` table there.

## Typical change flow

1. Branch from `main` and add a new file in `sql/`, for example `V6__add_order_notes.sql`.
2. Open a PR. The CI check proves it applies on top of V1-V5.
3. Merge to `main`.
4. Run **Flyway deploy** with `dev` + `migrate`, verify, then repeat for `stage`, then `prod`.

Applied `V` files are immutable: Flyway stores a checksum for each one and fails if it changes.
To correct a mistake, add a new, higher-numbered migration (roll forward).

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

## Things to try

1. **Add a migration via PR.** Add `sql/V6__...sql`, open a PR, and watch the CI check apply it.
2. **See checksum protection.** Edit an already-applied `V` file and run `migrate` against the local
   compose database. Flyway fails with a checksum mismatch.
3. **Repeatable migration.** Edit `R__customer_order_summary_view.sql` and re-run. Flyway re-applies it.
4. **Version collision.** Have two branches both add the same `V` number; the second to merge shows why
   version numbers need coordination (or `outOfOrder` with care).
5. **Dry run on an environment.** Run the deploy workflow with `info` to see pending migrations without changing anything.

## Notes

- Existing database that was not created by Flyway: run `flyway baseline -baselineVersion=1` once to
  mark its current state as the starting point.
- Rollbacks: undo migrations (`U__`) are a paid Flyway edition feature; with Community edition,
  roll forward with a corrective migration.
