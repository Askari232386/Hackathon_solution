# NovaMart Remediation Report

## Short Summary
This report explains the main problems in the NovaMart case study and what has been fixed in the six SQL files inside the `sql` folder. I used easy English and kept each part simple.

## What Each File Fixes

| File | Main Problem It Fixes |
|---|---|
| `security.sql` | Security, login, audit logs, TLS, and backup recovery settings |
| `tuning.sql` | Slow PostgreSQL settings, bad autovacuum settings, and poor performance tuning |
| `schema_migration.sql` | Bad table design, mixed product types, and broken customer JSON data |
| `concurrency.sql` | Race conditions, double inventory selling, and lost updates |
| `reconciliation.sql` | Orphan NovaPay records and broken foreign key rules |
| `olap_queries.sql` | Wrong warehouse reports, revenue errors, and bad OLAP numbers |

## Part-by-Part Report

### Part One and Part Two: Company Crisis and Case Background
These parts explain the business problem, the rushed migration, and the data center split. They are the story of the case study.

What I did:
- Read the case and identified the main technical problems.
- Used those problems to plan the SQL fixes.

What was fixed in SQL files:
- Not fixed directly in SQL.
- These parts are the background for the rest of the work.

### Part Three: Infrastructure Tuning and Query Planner Problems
This part talks about bad PostgreSQL settings, too many dead rows, and very slow queries.

What I did:
- Changed PostgreSQL memory and planner settings.
- Turned autovacuum back on.
- Set better checkpoint and statistics settings.

File used:
- [`tuning.sql`](tuning.sql)

Simple fix idea:
- Make PostgreSQL use the real server power instead of default settings.
- Keep statistics fresh so the query planner can choose a better plan.

### Part Four: Data Design Problems
This part talks about the large mixed `Products` table and broken `Customers.profile_data` JSON.

What I did:
- Split `Products` into smaller tables by product type.
- Created cleaner tables for customer profiles and broken JSON rows.
- Moved good data into structured tables and kept bad rows for cleanup.

File used:
- [`schema_migration.sql`](schema_migration.sql)

Simple fix idea:
- Do not keep all product types in one huge table.
- Do not store JSON-like data in a broken `VARCHAR` column.

### Part Five: Slow Search and Bad Query Plans
This part explains why product search is extremely slow.

What I did:
- Tuned PostgreSQL settings to help the planner.
- Enabled autovacuum so table stats stay fresh.
- Gave more memory for sorts and joins.

File used:
- [`tuning.sql`](tuning.sql)

Simple fix idea:
- Let PostgreSQL see the right row counts and use better join methods.

### Part Six: Race Conditions and Deadlocks
This part covers inventory problems, lost updates, and deadlocks.

What I did:
- Added a transaction that locks stock before creating an order.
- Used `FOR UPDATE` so two users cannot sell the same stock at the same time.
- Added a version column idea to reduce lost updates on loan balances.

File used:
- [`concurrency.sql`](concurrency.sql)

Simple fix idea:
- Lock the row first, then change it.
- Do not let two requests update the same value without checking first.

### Part Seven: Integrity Problems and Orphan Records
This part covers disabled foreign keys and orphan NovaPay records.

What I did:
- Found orphan plan rows and moved them to a quarantine table.
- Re-added foreign key rules in a safe way using `NOT VALID` first.
- Kept collectible debts visible instead of deleting them.

File used:
- [`reconciliation.sql`](reconciliation.sql)

Simple fix idea:
- Clean the bad rows first.
- Then turn foreign keys back on safely.

### Part Eight: Distributed Access and NoSQL Layers
This part covers cross-node joins, Elasticsearch lag, Redis cache problems, and graph queries.

What I did:
- This part is not fully solved in the SQL files yet.
- The SQL work does not cover Node.js join logic, Redis, or Elasticsearch recovery.

Current status:
- Partly covered by the wider architecture plan.
- Needs extra non-SQL work later.

### Part Nine: Warehouse and OLAP Reporting Problems
This part covers wrong revenue, wrong tax reporting, wrong city reporting, and bad default-rate math.

What I did:
- Wrote OLAP views for real revenue after refunds and discounts.
- Used payment date for tax reporting.
- Added better logic for inventory turnover and basket size.
- Added a better view for NovaPay default rate.

File used:
- [`olap_queries.sql`](olap_queries.sql)

Simple fix idea:
- Do not count cancelled or refunded sales as real revenue.
- Use the right date and the right business rules.

### Part Ten: Security and Compliance
This part covers the superuser account, plain-text credentials, PAN storage, audit logs, TLS, and WAL recovery.

What I did:
- Removed superuser rights from the app account.
- Created lower-privilege roles.
- Turned on audit logging.
- Added TLS settings.
- Turned on WAL archiving for point-in-time recovery.
- Added `pgcrypto` support for card encryption.

File used:
- [`security.sql`](security.sql)

Simple fix idea:
- Give the app only the access it needs.
- Keep secrets out of plain text.
- Keep logs and backups so attacks can be traced and recovery is possible.

## Final Result
The six SQL files now cover the main database problems from the case study:
- security
- performance tuning
- data cleanup and schema redesign
- race conditions
- orphan data and foreign keys
- OLAP and reporting fixes

## What Is Still Missing
The SQL files do not yet cover everything in the full PDF.
Missing or only partly covered items include:
- PgBouncer deployment
- PostgreSQL replication across data centers
- Node.js middleware join redesign
- Redis cache cleanup
- Elasticsearch recovery
- monitoring stack
- load test scripts
- benchmark CSV files
- full test runner

## Short Conclusion
The database side of the project is now organized into six clear SQL files. Each file matches one major problem area from the report. The main fixes are easier security, better performance, cleaner data design, safer transactions, better integrity, and more correct OLAP reporting.
