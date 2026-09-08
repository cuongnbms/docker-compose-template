# dbbackup

Scheduled PostgreSQL backups ([cuongnbms/dbbackup](https://github.com/cuongnbms/dbbackup)):
`pg_dump` every database, verify each dump with `pg_restore --list`, pack into one
zip, optionally encrypt with GPG and upload offsite (Azure Blob Storage / AWS S3),
then keep only the newest N backups. A failed dump aborts the run before anything
is uploaded or deleted, so a bad run never removes an older good backup.

## Start

```sh
cp .env.example .env   # first time only: fill in real values
docker compose up -d
```

Backups land in `./backup_data/<YYYYMMDD_HHMMSS>.zip[.gpg]`.

## Run now

```sh
docker exec -it dbbackup backup --now
```

Exit code is non-zero on failure; refuses to start if the scheduled job is already running.

## Configuration

- `config.yaml` — retention, cron, exclusions, remote destinations, notification events.
- `.env` (gitignored) — connection details and secrets. Template: `.env.example`.

Remote uploads and notifications are off by default: flip `remote_backup.*.enable`
in `config.yaml` and set the matching credentials / webhook URLs in `.env`.

## Restore

```sh
gpg --decrypt 20240101_000000.zip.gpg > 20240101_000000.zip   # if encrypted
unzip 20240101_000000.zip -d 20240101_000000   # one DBNAME.backup per database
psql -h HOST -U USER -d postgres -f 20240101_000000/globals.sql
pg_restore -h HOST -U USER -d DBNAME --clean --if-exists 20240101_000000/DBNAME.backup
```

> Restore `globals.sql` **first**. It holds the cluster's roles, tablespaces and
> grants, which no per-database `pg_dump` captures — skip it and every `OWNER TO`
> and `GRANT` fails.

Dumps are custom-format archives written by pg_dump 18 (archive version 1.16), so
restoring needs a `pg_restore` 17 or newer — use the client from this image
whatever major version the target server is.

## Upgrading from 1.0

`exclude_tables` was renamed to **`exclude_table_data`** and is now rejected at
startup, so a stale config fails loudly instead of quietly changing the archive.
The new key drops only a table's *rows* and keeps its definition, so views and
foreign keys referencing it still restore — but a table with a foreign key into an
emptied table will fail that constraint on restore.
