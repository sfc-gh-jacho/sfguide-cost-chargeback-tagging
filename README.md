# Cost Chargeback with Tags in Snowflake

**Owner:** Janet Cho · **Last reviewed:** November 2026 · **License:** [Apache 2.0](LICENSE)

A customer-facing, step-by-step guide to tag-based cost attribution and chargeback in Snowflake:

- **Object tags** (`COST_CENTER`, `ENVIRONMENT`, `PROJECT`) with governed allowed values
- **Tagging** warehouses (dedicated compute), users (shared warehouse split) and databases (storage)
- **Resource monitors** and warehouse guardrails (auto-suspend, statement timeouts)
- **Tag-based custom budgets** covering compute and serverless spend
- **Chargeback queries** on `SNOWFLAKE.ACCOUNT_USAGE`, including a shared-warehouse split via `QUERY_ATTRIBUTION_HISTORY`
- **Abuse detection**: top queries, heavy users, idle warehouses, budget status, week-over-week spikes
- **Optional multi-account** tag replication and an org-wide rollup

**Live guide:** https://sfc-gh-jacho.github.io/sfguide-cost-chargeback-tagging/

The site is fully static. It does not connect to any Snowflake account. Its result tables are **illustrative** examples built from synthetic numbers.

## Prerequisites

- **Snowflake Enterprise Edition or higher** (object tagging and tag-based budgets)
- **A role to run it.** ACCOUNTADMIN is simplest in a sandbox. For regulated environments, use the least-privilege option below.

### Least-privilege option (no ACCOUNTADMIN for most steps)

The script starts with `SET demo_role = 'ACCOUNTADMIN';`. To run without ACCOUNTADMIN, an administrator runs the commented block at the top of Step 1 once:

```sql
USE ROLE ACCOUNTADMIN;
CREATE ROLE IF NOT EXISTS CB_DEMO_ROLE;
GRANT CREATE DATABASE  ON ACCOUNT TO ROLE CB_DEMO_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE CB_DEMO_ROLE;
GRANT CREATE USER      ON ACCOUNT TO ROLE CB_DEMO_ROLE;               -- demo service users
GRANT DATABASE ROLE SNOWFLAKE.USAGE_VIEWER      TO ROLE CB_DEMO_ROLE; -- metering, query attribution
GRANT DATABASE ROLE SNOWFLAKE.GOVERNANCE_VIEWER TO ROLE CB_DEMO_ROLE; -- TAG_REFERENCES, QUERY_HISTORY
GRANT DATABASE ROLE SNOWFLAKE.OBJECT_VIEWER     TO ROLE CB_DEMO_ROLE; -- TABLE_STORAGE_METRICS
GRANT ROLE CB_DEMO_ROLE TO USER <YOUR_USER>;
```

Then change the first line to `SET demo_role = 'CB_DEMO_ROLE';`.

**Two blocks still need ACCOUNTADMIN**, and the script switches to it explicitly for them:
- **Step 4b, resource monitors.** Only ACCOUNTADMIN can create resource monitors and assign them to warehouses.
- **Step 5a, the budget admin role.** Granting the `SNOWFLAKE.BUDGET_CREATOR` database role requires an administrator.

If the person running the demo doesn't have ACCOUNTADMIN, an administrator runs those two blocks for them, or they skip them. Everything else, including tagging, budgets and every chargeback query, runs as `CB_DEMO_ROLE`. This path was tested end to end.

## Run the demo in Snowsight

1. Download [`sql/cost_chargeback_setup.sql`](sql/cost_chargeback_setup.sql).
2. In Snowsight, open **Projects → Worksheets** and create a new SQL worksheet.
3. Paste the script and run Steps 1–5 in order. No find-and-replace is needed: the script creates its own objects.
4. Optionally run Step 6 to generate a small workload (well under 1 credit).
5. Run the Step 7–8 queries. `ACCOUNT_USAGE` lags by minutes to hours, so re-run them later for fuller results.
6. Step 9 (multi-account) is optional and needs your org and account names in place of the `<YOUR_ORG>` / `<..._ACCOUNT>` placeholders.
7. When you're done, uncomment and run Step 10 (Cleanup).

**Safety:** The script only creates objects prefixed `CB_` plus the `CHARGEBACK_DEMO_DB` database. The account-level resource monitor is commented out because it would apply to every warehouse in the account.

## What gets created

| Object | Names |
|---|---|
| Governance database | `CHARGEBACK_DEMO_DB.GOVERNANCE` (tags and budgets) |
| Tags | `COST_CENTER`, `ENVIRONMENT`, `PROJECT` |
| Warehouses (XSMALL, initially suspended) | `CB_<BU>_WH_PROD`, `CB_<BU>_WH_DEV` for SALES, MARKETING, FINANCE, ENGINEERING; `CB_SHARED_REPORTING_WH`, `CB_SHARED_ETL_WH` |
| Databases | `CB_SALES_DB`, `CB_MARKETING_DB`, `CB_FINANCE_DB`, `CB_ENGINEERING_DB`, `CB_SHARED_REFERENCE_DB` |
| Users (`TYPE = SERVICE`, no credentials) | `CB_SALES_ANALYST`, `CB_MARKETING_ANALYST`, `CB_FINANCE_ANALYST`, `CB_ENGINEERING_DEV`, `CB_PLATFORM_ADMIN` |
| Resource monitors | `CB_SALES_MONITOR`, `CB_MARKETING_MONITOR`, `CB_FINANCE_MONITOR`, `CB_ENGINEERING_MONITOR`, `CB_SHARED_MONITOR` |
| Budgets | `SALES_BUDGET`, `MARKETING_BUDGET`, `FINANCE_BUDGET`, `ENGINEERING_BUDGET`, `SHARED_BUDGET` |
| Role | `CB_BUDGET_ADMIN` |

## Repository layout

```
LICENSE                        Apache License 2.0
vendor/prism/                  Prism.js (MIT), served locally
index.html                     Single-page guide
styles.css                     Styling (Snowflake palette)
script.js                      Loads SQL steps, Prism highlighting, copy buttons, example tables
sql/cost_chargeback_setup.sql  Full demo script (split into steps by "-- [step:<id>]" markers)
data/sample_results.json       Illustrative example output for the chargeback and abuse queries
```

To preview locally, serve the folder over HTTP (the page fetches the SQL and JSON files):

```
python3 -m http.server 8000
```

## Customize with Cortex Code

[Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) can adapt this guide to your own data. Open the repo folder in Cortex Code and try prompts like:

- "Map my existing warehouses, users and databases to business units, propose COST_CENTER tag values, and show me the ALTER statements before running any of them."
- "Run the chargeback summary for last month against my real usage and flag anything untagged that I should assign to a cost center."
- "Set custom budget limits per cost center based on my last three months of spend plus 15% headroom, and explain how you calculated them."

Ask it to review the plan with you before it creates or changes any objects in your account.

## License

Licensed under the [Apache License, Version 2.0](LICENSE). Prism.js, used for syntax highlighting, is bundled in `vendor/prism/` under its own MIT license, so the pages make no third-party requests.

## Disclaimer

All business units, object names and credit figures are synthetic and illustrative only. The repository contains no credentials, account identifiers or connection details.
