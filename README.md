# Flyway + PostgreSQL demo

A small demo of managing PostgreSQL schema changes with [Flyway](https://flywaydb.org/) and GitHub Actions.
On every push to `main` and every pull request, GitHub Actions starts a throwaway Postgres 16 container
and applies all migrations from an empty database.

## Layout

```
.github/workflows/flyway.yml       CI: proves migrations on a throwaway Postgres container
.github/workflows/flyway-rds.yml   manual: applies migrations to pilot-test-pg on AWS RDS
scripts/migrate-rds.sh             same thing from your laptop
docker-compose.yml                 local Postgres + Flyway
flyway.conf                        Flyway settings (no secrets)
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

## Deploy to the pilot database on AWS RDS

This repo only deploys database changes. The database itself (`pilot-test-pg`, RDS PostgreSQL) is
created and destroyed by the **pilot-infra** repo, so run its `apply` first. Nothing here creates
AWS resources.

`.github/workflows/flyway-rds.yml` (Actions > **Flyway migrate (pilot-test-pg)** > Run workflow):

1. Assumes the AWS role from pilot-infra through GitHub OIDC (no AWS keys, no database secrets in GitHub).
2. Waits for the instance to be available, then reads its endpoint, master user and the
   Secrets Manager password.
3. Allows the runner's IP on port 5432 for the length of the job and removes it afterwards, even if Flyway fails.
4. Runs `info`, `validate` or `migrate` against database `test`.

One-time setup:

- Repo variable `AWS_ROLE_ARN` = the pilot-infra role ARN
  (`arn:aws:iam::<account>:role/pilot-infra-github-actions`).
- The role's trust policy must allow this repo. Re-run pilot-infra's `bootstrap/bootstrap.sh` with both
  repos (see that repo's README), or add `repo:RRavala@*/flyway-postgres-demo@*:*` to the `sub` condition.
- If `pilot-infra` has been destroyed (it is by default every night when `NIGHTLY_DESTROY` is on), the job stops with
  "RDS instance not found". Run `apply` there, then re-run this workflow. A new instance starts empty, so
  `migrate` re-applies V1 onward.

### From your laptop instead

Your IP must be the `allowed_cidr` pilot-infra was applied with.

```bash
export FLYWAY_URL='jdbc:postgresql://<endpoint>:5432/test?sslmode=require'
export FLYWAY_USER=rravala
export FLYWAY_PASSWORD='<master password from Secrets Manager>'
scripts/migrate-rds.sh info
scripts/migrate-rds.sh migrate
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

- Approval gate: add `environment: <name>` to the RDS workflow job and put required reviewers on that
  GitHub Environment.
- Least privilege: the role shared with pilot-infra can manage RDS. A separate role limited to describe,
  read one secret and edit one security group would be tighter.
- Branch protection: require the Flyway check to pass before merging to `main`.
- Existing database: `flyway baseline -baselineVersion=1` marks its current state as the starting point.
- Rollbacks: undo migrations (`U__`) are a paid Flyway edition feature; with Community edition,
  roll forward with a corrective migration.
