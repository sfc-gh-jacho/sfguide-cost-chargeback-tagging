# Cost Chargeback with Tags in Snowflake

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
- **ACCOUNTADMIN**, or a custom role with `CREATE WAREHOUSE`, `CREATE DATABASE`, `CREATE USER`, `CREATE ROLE` and `APPLY TAG` on the account. Resource monitors can only be created by ACCOUNTADMIN.
- Access to `SNOWFLAKE.ACCOUNT_USAGE` (`IMPORTED PRIVILEGES` on the `SNOWFLAKE` database for non-ACCOUNTADMIN roles)

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

## Disclaimer

All business units, object names and credit figures are synthetic and illustrative only. The repository contains no credentials, account identifiers or connection details.
