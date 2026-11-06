/*
================================================================================
 COST CHARGEBACK WITH TAGS - DEMO SCRIPT
 Tag-based cost attribution, guardrails and chargeback across business units:
 - Object tags (COST_CENTER, ENVIRONMENT, PROJECT)
 - Tagging warehouses, users and databases
 - Resource monitors and warehouse best-practice settings
 - Tag-based custom budgets (compute + serverless)
 - Chargeback and abuse-detection queries on ACCOUNT_USAGE

 Sample business units: SALES, MARKETING, FINANCE, ENGINEERING
 Plus SHARED (multi-BU resources) and PLATFORM_TEAM (central data platform)

 This script creates its own demo objects, all prefixed CB_ (warehouses,
 databases, users) plus the CHARGEBACK_DEMO_DB database for tags and budgets.
 It does NOT modify any existing objects in your account. Step 10 removes
 everything it creates.

 Requires Enterprise Edition (or higher) and ACCOUNTADMIN, or <YOUR_ROLE>
 with equivalent privileges (see README).
================================================================================
*/

-- [step:resources]
-- ============================================================================
-- STEP 1: DEMO RESOURCES - Warehouses, Databases and Users per Business Unit
-- ============================================================================
-- In a real account these already exist. Here we create small stand-ins.
-- Warehouses are XSMALL and start suspended, so they cost nothing until used.

USE ROLE ACCOUNTADMIN;

-- Governance database that will hold the tags and budgets
CREATE DATABASE IF NOT EXISTS CHARGEBACK_DEMO_DB;
CREATE SCHEMA IF NOT EXISTS CHARGEBACK_DEMO_DB.GOVERNANCE;

-- Dedicated PROD and DEV warehouses for each business unit
CREATE WAREHOUSE IF NOT EXISTS CB_SALES_WH_PROD        WAREHOUSE_SIZE = XSMALL INITIALLY_SUSPENDED = TRUE;
CREATE WAREHOUSE IF NOT EXISTS CB_SALES_WH_DEV         WAREHOUSE_SIZE = XSMALL INITIALLY_SUSPENDED = TRUE;
CREATE WAREHOUSE IF NOT EXISTS CB_MARKETING_WH_PROD    WAREHOUSE_SIZE = XSMALL INITIALLY_SUSPENDED = TRUE;
CREATE WAREHOUSE IF NOT EXISTS CB_MARKETING_WH_DEV     WAREHOUSE_SIZE = XSMALL INITIALLY_SUSPENDED = TRUE;
CREATE WAREHOUSE IF NOT EXISTS CB_FINANCE_WH_PROD      WAREHOUSE_SIZE = XSMALL INITIALLY_SUSPENDED = TRUE;
CREATE WAREHOUSE IF NOT EXISTS CB_FINANCE_WH_DEV       WAREHOUSE_SIZE = XSMALL INITIALLY_SUSPENDED = TRUE;
CREATE WAREHOUSE IF NOT EXISTS CB_ENGINEERING_WH_PROD  WAREHOUSE_SIZE = XSMALL INITIALLY_SUSPENDED = TRUE;
CREATE WAREHOUSE IF NOT EXISTS CB_ENGINEERING_WH_DEV   WAREHOUSE_SIZE = XSMALL INITIALLY_SUSPENDED = TRUE;

-- Shared warehouses used by several business units
CREATE WAREHOUSE IF NOT EXISTS CB_SHARED_REPORTING_WH  WAREHOUSE_SIZE = XSMALL INITIALLY_SUSPENDED = TRUE;
CREATE WAREHOUSE IF NOT EXISTS CB_SHARED_ETL_WH        WAREHOUSE_SIZE = XSMALL INITIALLY_SUSPENDED = TRUE;

-- One database per business unit, plus shared reference data
CREATE DATABASE IF NOT EXISTS CB_SALES_DB;
CREATE DATABASE IF NOT EXISTS CB_MARKETING_DB;
CREATE DATABASE IF NOT EXISTS CB_FINANCE_DB;
CREATE DATABASE IF NOT EXISTS CB_ENGINEERING_DB;
CREATE DATABASE IF NOT EXISTS CB_SHARED_REFERENCE_DB;

-- Demo users. TYPE = SERVICE with no password or key: they cannot log in.
-- They exist only so you can practice user-level tagging.
CREATE USER IF NOT EXISTS CB_SALES_ANALYST       TYPE = SERVICE COMMENT = 'Chargeback demo user';
CREATE USER IF NOT EXISTS CB_MARKETING_ANALYST   TYPE = SERVICE COMMENT = 'Chargeback demo user';
CREATE USER IF NOT EXISTS CB_FINANCE_ANALYST     TYPE = SERVICE COMMENT = 'Chargeback demo user';
CREATE USER IF NOT EXISTS CB_ENGINEERING_DEV     TYPE = SERVICE COMMENT = 'Chargeback demo user';
CREATE USER IF NOT EXISTS CB_PLATFORM_ADMIN      TYPE = SERVICE COMMENT = 'Chargeback demo user';

-- [step:tags]
-- ============================================================================
-- STEP 2: CREATE COST TAGS
-- ============================================================================
-- Tags can live in any database/schema. A dedicated governance schema keeps
-- them easy to find, secure and replicate.

USE SCHEMA CHARGEBACK_DEMO_DB.GOVERNANCE;

-- COST_CENTER: who pays. ALLOWED_VALUES prevents typos like 'Sales ' or 'SLS'.
-- To add a business unit later:
--   ALTER TAG CHARGEBACK_DEMO_DB.GOVERNANCE.COST_CENTER ADD ALLOWED_VALUES 'NEW_BU';
CREATE TAG IF NOT EXISTS COST_CENTER
    ALLOWED_VALUES 'SALES', 'MARKETING', 'FINANCE', 'ENGINEERING', 'SHARED', 'PLATFORM_TEAM'
    COMMENT = 'Business unit responsible for the cost of this object';

-- ENVIRONMENT: separate production from development spend
CREATE TAG IF NOT EXISTS ENVIRONMENT
    ALLOWED_VALUES 'PROD', 'DEV', 'STAGING'
    COMMENT = 'Deployment environment';

-- PROJECT: optional, free-form, finer-grained attribution
CREATE TAG IF NOT EXISTS PROJECT
    COMMENT = 'Free-form tag for project-level cost tracking';

SHOW TAGS IN SCHEMA CHARGEBACK_DEMO_DB.GOVERNANCE;

-- [step:apply]
-- ============================================================================
-- STEP 3: TAG WAREHOUSES, USERS AND DATABASES
-- ============================================================================
-- Tag every resource when it is provisioned, ideally in your onboarding
-- automation, so nothing ever runs untagged.

-- 3a. Dedicated warehouses: cost belongs to one business unit
ALTER WAREHOUSE CB_SALES_WH_PROD        SET TAG COST_CENTER = 'SALES',       ENVIRONMENT = 'PROD';
ALTER WAREHOUSE CB_SALES_WH_DEV         SET TAG COST_CENTER = 'SALES',       ENVIRONMENT = 'DEV';
ALTER WAREHOUSE CB_MARKETING_WH_PROD    SET TAG COST_CENTER = 'MARKETING',   ENVIRONMENT = 'PROD';
ALTER WAREHOUSE CB_MARKETING_WH_DEV     SET TAG COST_CENTER = 'MARKETING',   ENVIRONMENT = 'DEV';
ALTER WAREHOUSE CB_FINANCE_WH_PROD      SET TAG COST_CENTER = 'FINANCE',     ENVIRONMENT = 'PROD';
ALTER WAREHOUSE CB_FINANCE_WH_DEV       SET TAG COST_CENTER = 'FINANCE',     ENVIRONMENT = 'DEV';
ALTER WAREHOUSE CB_ENGINEERING_WH_PROD  SET TAG COST_CENTER = 'ENGINEERING', ENVIRONMENT = 'PROD';
ALTER WAREHOUSE CB_ENGINEERING_WH_DEV   SET TAG COST_CENTER = 'ENGINEERING', ENVIRONMENT = 'DEV';

-- 3b. Shared warehouses: cost is split later using user tags (Step 7)
ALTER WAREHOUSE CB_SHARED_REPORTING_WH  SET TAG COST_CENTER = 'SHARED', ENVIRONMENT = 'PROD';
ALTER WAREHOUSE CB_SHARED_ETL_WH        SET TAG COST_CENTER = 'SHARED', ENVIRONMENT = 'PROD',
                                            PROJECT = 'NIGHTLY_INGEST';

-- 3c. Users: the key to splitting shared warehouse cost fairly
ALTER USER CB_SALES_ANALYST      SET TAG COST_CENTER = 'SALES';
ALTER USER CB_MARKETING_ANALYST  SET TAG COST_CENTER = 'MARKETING';
ALTER USER CB_FINANCE_ANALYST    SET TAG COST_CENTER = 'FINANCE';
ALTER USER CB_ENGINEERING_DEV    SET TAG COST_CENTER = 'ENGINEERING';
ALTER USER CB_PLATFORM_ADMIN     SET TAG COST_CENTER = 'PLATFORM_TEAM';

-- 3d. Databases: used for storage cost attribution
ALTER DATABASE CB_SALES_DB             SET TAG COST_CENTER = 'SALES';
ALTER DATABASE CB_MARKETING_DB         SET TAG COST_CENTER = 'MARKETING';
ALTER DATABASE CB_FINANCE_DB           SET TAG COST_CENTER = 'FINANCE';
ALTER DATABASE CB_ENGINEERING_DB       SET TAG COST_CENTER = 'ENGINEERING';
ALTER DATABASE CB_SHARED_REFERENCE_DB  SET TAG COST_CENTER = 'SHARED';

-- 3e. Verify immediately (ACCOUNT_USAGE.TAG_REFERENCES can lag up to 2 hours)
SELECT 'CB_SALES_WH_PROD'      AS object_name, 'WAREHOUSE' AS domain,
       SYSTEM$GET_TAG('CHARGEBACK_DEMO_DB.GOVERNANCE.COST_CENTER', 'CB_SALES_WH_PROD', 'WAREHOUSE') AS cost_center
UNION ALL
SELECT 'CB_SHARED_ETL_WH', 'WAREHOUSE',
       SYSTEM$GET_TAG('CHARGEBACK_DEMO_DB.GOVERNANCE.COST_CENTER', 'CB_SHARED_ETL_WH', 'WAREHOUSE')
UNION ALL
SELECT 'CB_FINANCE_ANALYST', 'USER',
       SYSTEM$GET_TAG('CHARGEBACK_DEMO_DB.GOVERNANCE.COST_CENTER', 'CB_FINANCE_ANALYST', 'USER')
UNION ALL
SELECT 'CB_ENGINEERING_DB', 'DATABASE',
       SYSTEM$GET_TAG('CHARGEBACK_DEMO_DB.GOVERNANCE.COST_CENTER', 'CB_ENGINEERING_DB', 'DATABASE');

-- [step:monitors]
-- ============================================================================
-- STEP 4: RESOURCE MONITORS AND WAREHOUSE GUARDRAILS
-- ============================================================================
-- Resource monitors enforce hard credit caps on warehouse compute.
-- They do not cover serverless features; budgets (Step 5) fill that gap.

-- 4a. (OPTIONAL - read before running) Account-level safety net.
--     WARNING: this applies to EVERY warehouse in the account and SUSPENDS
--     them all at 100%. Size the quota to your real monthly usage first.
-- CREATE RESOURCE MONITOR IF NOT EXISTS CB_ACCOUNT_MONTHLY_MONITOR
--     WITH CREDIT_QUOTA = <YOUR_MONTHLY_CREDITS>
--     FREQUENCY = MONTHLY
--     START_TIMESTAMP = IMMEDIATELY
--     TRIGGERS
--         ON 75 PERCENT DO NOTIFY
--         ON 90 PERCENT DO NOTIFY
--         ON 100 PERCENT DO SUSPEND;
-- ALTER ACCOUNT SET RESOURCE_MONITOR = CB_ACCOUNT_MONTHLY_MONITOR;

-- 4b. One monitor per business unit, shared by its PROD and DEV warehouses
CREATE OR REPLACE RESOURCE MONITOR CB_SALES_MONITOR
    WITH CREDIT_QUOTA = 500 FREQUENCY = MONTHLY START_TIMESTAMP = IMMEDIATELY
    TRIGGERS ON 75 PERCENT DO NOTIFY
             ON 90 PERCENT DO NOTIFY
             ON 100 PERCENT DO SUSPEND;
ALTER WAREHOUSE CB_SALES_WH_PROD SET RESOURCE_MONITOR = CB_SALES_MONITOR;
ALTER WAREHOUSE CB_SALES_WH_DEV  SET RESOURCE_MONITOR = CB_SALES_MONITOR;

CREATE OR REPLACE RESOURCE MONITOR CB_MARKETING_MONITOR
    WITH CREDIT_QUOTA = 400 FREQUENCY = MONTHLY START_TIMESTAMP = IMMEDIATELY
    TRIGGERS ON 75 PERCENT DO NOTIFY
             ON 90 PERCENT DO NOTIFY
             ON 100 PERCENT DO SUSPEND;
ALTER WAREHOUSE CB_MARKETING_WH_PROD SET RESOURCE_MONITOR = CB_MARKETING_MONITOR;
ALTER WAREHOUSE CB_MARKETING_WH_DEV  SET RESOURCE_MONITOR = CB_MARKETING_MONITOR;

CREATE OR REPLACE RESOURCE MONITOR CB_FINANCE_MONITOR
    WITH CREDIT_QUOTA = 400 FREQUENCY = MONTHLY START_TIMESTAMP = IMMEDIATELY
    TRIGGERS ON 75 PERCENT DO NOTIFY
             ON 90 PERCENT DO NOTIFY
             ON 100 PERCENT DO SUSPEND;
ALTER WAREHOUSE CB_FINANCE_WH_PROD SET RESOURCE_MONITOR = CB_FINANCE_MONITOR;
ALTER WAREHOUSE CB_FINANCE_WH_DEV  SET RESOURCE_MONITOR = CB_FINANCE_MONITOR;

CREATE OR REPLACE RESOURCE MONITOR CB_ENGINEERING_MONITOR
    WITH CREDIT_QUOTA = 350 FREQUENCY = MONTHLY START_TIMESTAMP = IMMEDIATELY
    TRIGGERS ON 75 PERCENT DO NOTIFY
             ON 90 PERCENT DO NOTIFY
             ON 100 PERCENT DO SUSPEND;
ALTER WAREHOUSE CB_ENGINEERING_WH_PROD SET RESOURCE_MONITOR = CB_ENGINEERING_MONITOR;
ALTER WAREHOUSE CB_ENGINEERING_WH_DEV  SET RESOURCE_MONITOR = CB_ENGINEERING_MONITOR;

CREATE OR REPLACE RESOURCE MONITOR CB_SHARED_MONITOR
    WITH CREDIT_QUOTA = 250 FREQUENCY = MONTHLY START_TIMESTAMP = IMMEDIATELY
    TRIGGERS ON 75 PERCENT DO NOTIFY
             ON 90 PERCENT DO NOTIFY
             ON 100 PERCENT DO SUSPEND;
ALTER WAREHOUSE CB_SHARED_REPORTING_WH SET RESOURCE_MONITOR = CB_SHARED_MONITOR;
ALTER WAREHOUSE CB_SHARED_ETL_WH       SET RESOURCE_MONITOR = CB_SHARED_MONITOR;

-- 4c. Warehouse guardrails: suspend quickly when idle, kill runaway queries
--     PROD: 5 min auto-suspend, 30 min timeout. DEV: 1 min, 15 min.
ALTER WAREHOUSE CB_SALES_WH_PROD        SET AUTO_SUSPEND = 300 AUTO_RESUME = TRUE STATEMENT_TIMEOUT_IN_SECONDS = 1800;
ALTER WAREHOUSE CB_MARKETING_WH_PROD    SET AUTO_SUSPEND = 300 AUTO_RESUME = TRUE STATEMENT_TIMEOUT_IN_SECONDS = 1800;
ALTER WAREHOUSE CB_FINANCE_WH_PROD      SET AUTO_SUSPEND = 300 AUTO_RESUME = TRUE STATEMENT_TIMEOUT_IN_SECONDS = 1800;
ALTER WAREHOUSE CB_ENGINEERING_WH_PROD  SET AUTO_SUSPEND = 300 AUTO_RESUME = TRUE STATEMENT_TIMEOUT_IN_SECONDS = 1800;

ALTER WAREHOUSE CB_SALES_WH_DEV         SET AUTO_SUSPEND = 60  AUTO_RESUME = TRUE STATEMENT_TIMEOUT_IN_SECONDS = 900;
ALTER WAREHOUSE CB_MARKETING_WH_DEV     SET AUTO_SUSPEND = 60  AUTO_RESUME = TRUE STATEMENT_TIMEOUT_IN_SECONDS = 900;
ALTER WAREHOUSE CB_FINANCE_WH_DEV       SET AUTO_SUSPEND = 60  AUTO_RESUME = TRUE STATEMENT_TIMEOUT_IN_SECONDS = 900;
ALTER WAREHOUSE CB_ENGINEERING_WH_DEV   SET AUTO_SUSPEND = 60  AUTO_RESUME = TRUE STATEMENT_TIMEOUT_IN_SECONDS = 900;

ALTER WAREHOUSE CB_SHARED_REPORTING_WH  SET AUTO_SUSPEND = 300 AUTO_RESUME = TRUE STATEMENT_TIMEOUT_IN_SECONDS = 1800;
ALTER WAREHOUSE CB_SHARED_ETL_WH        SET AUTO_SUSPEND = 300 AUTO_RESUME = TRUE STATEMENT_TIMEOUT_IN_SECONDS = 3600;

SHOW WAREHOUSES LIKE 'CB\\_%';

-- [step:budgets]
-- ============================================================================
-- STEP 5: TAG-BASED CUSTOM BUDGETS
-- ============================================================================
-- Custom budgets track warehouse AND serverless spend and send alerts.
-- Because they follow the COST_CENTER tag, newly tagged resources are
-- included automatically.

-- 5a. A dedicated role for the central platform team to manage budgets
CREATE ROLE IF NOT EXISTS CB_BUDGET_ADMIN;
GRANT DATABASE ROLE SNOWFLAKE.BUDGET_CREATOR TO ROLE CB_BUDGET_ADMIN;
GRANT USAGE ON DATABASE CHARGEBACK_DEMO_DB TO ROLE CB_BUDGET_ADMIN;
GRANT USAGE ON SCHEMA CHARGEBACK_DEMO_DB.GOVERNANCE TO ROLE CB_BUDGET_ADMIN;
GRANT CREATE SNOWFLAKE.CORE.BUDGET ON SCHEMA CHARGEBACK_DEMO_DB.GOVERNANCE TO ROLE CB_BUDGET_ADMIN;
GRANT APPLYBUDGET ON TAG CHARGEBACK_DEMO_DB.GOVERNANCE.COST_CENTER TO ROLE CB_BUDGET_ADMIN;
GRANT USAGE ON WAREHOUSE CB_SHARED_ETL_WH TO ROLE CB_BUDGET_ADMIN;
GRANT ROLE CB_BUDGET_ADMIN TO ROLE ACCOUNTADMIN;

USE ROLE CB_BUDGET_ADMIN;
USE WAREHOUSE CB_SHARED_ETL_WH;
USE SCHEMA CHARGEBACK_DEMO_DB.GOVERNANCE;

-- 5b. One budget per cost center, scoped by the COST_CENTER tag
CREATE SNOWFLAKE.CORE.BUDGET IF NOT EXISTS SALES_BUDGET();
CALL SALES_BUDGET!SET_SPENDING_LIMIT(600);
CALL SALES_BUDGET!SET_RESOURCE_TAGS(
    [[(SELECT SYSTEM$REFERENCE('TAG', 'CHARGEBACK_DEMO_DB.GOVERNANCE.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'SALES']],
    'UNION');

CREATE SNOWFLAKE.CORE.BUDGET IF NOT EXISTS MARKETING_BUDGET();
CALL MARKETING_BUDGET!SET_SPENDING_LIMIT(500);
CALL MARKETING_BUDGET!SET_RESOURCE_TAGS(
    [[(SELECT SYSTEM$REFERENCE('TAG', 'CHARGEBACK_DEMO_DB.GOVERNANCE.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'MARKETING']],
    'UNION');

CREATE SNOWFLAKE.CORE.BUDGET IF NOT EXISTS FINANCE_BUDGET();
CALL FINANCE_BUDGET!SET_SPENDING_LIMIT(500);
CALL FINANCE_BUDGET!SET_RESOURCE_TAGS(
    [[(SELECT SYSTEM$REFERENCE('TAG', 'CHARGEBACK_DEMO_DB.GOVERNANCE.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'FINANCE']],
    'UNION');

CREATE SNOWFLAKE.CORE.BUDGET IF NOT EXISTS ENGINEERING_BUDGET();
CALL ENGINEERING_BUDGET!SET_SPENDING_LIMIT(400);
CALL ENGINEERING_BUDGET!SET_RESOURCE_TAGS(
    [[(SELECT SYSTEM$REFERENCE('TAG', 'CHARGEBACK_DEMO_DB.GOVERNANCE.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'ENGINEERING']],
    'UNION');

CREATE SNOWFLAKE.CORE.BUDGET IF NOT EXISTS SHARED_BUDGET();
CALL SHARED_BUDGET!SET_SPENDING_LIMIT(300);
CALL SHARED_BUDGET!SET_RESOURCE_TAGS(
    [[(SELECT SYSTEM$REFERENCE('TAG', 'CHARGEBACK_DEMO_DB.GOVERNANCE.COST_CENTER', 'SESSION', 'APPLYBUDGET')), 'SHARED']],
    'UNION');

-- 5c. (Optional) Email alerts when projected spend crosses the limit.
--     The address must be verified in Snowflake first.
-- CALL SALES_BUDGET!SET_EMAIL_NOTIFICATIONS('<YOUR_NOTIFICATION_INTEGRATION>', '<YOUR_EMAIL>');

-- 5d. Confirm what each budget tracks
CALL SALES_BUDGET!GET_BUDGET_SCOPE();

USE ROLE ACCOUNTADMIN;

-- [step:workload]
-- ============================================================================
-- STEP 6: (OPTIONAL) GENERATE A SMALL SAMPLE WORKLOAD
-- ============================================================================
-- A brand-new account has no usage history, so Steps 7-8 return few rows.
-- These short queries put a little metering on the dedicated warehouses.
-- Cost: well under 1 credit in total. Results appear in ACCOUNT_USAGE
-- after its normal latency (minutes to a few hours).

USE WAREHOUSE CB_SALES_WH_PROD;
SELECT COUNT(*) FROM TABLE(GENERATOR(ROWCOUNT => 200000000));

USE WAREHOUSE CB_FINANCE_WH_PROD;
SELECT COUNT(*) FROM TABLE(GENERATOR(ROWCOUNT => 150000000));

USE WAREHOUSE CB_ENGINEERING_WH_PROD;
SELECT COUNT(*) FROM TABLE(GENERATOR(ROWCOUNT => 300000000));

USE WAREHOUSE CB_MARKETING_WH_PROD;
SELECT COUNT(*) FROM TABLE(GENERATOR(ROWCOUNT => 100000000));

-- To see shared-warehouse attribution, tag YOUR OWN user, then run a query
-- on the shared warehouse. Step 11 removes this tag again.
-- SET my_user = CURRENT_USER();
-- ALTER USER IDENTIFIER($my_user) SET TAG CHARGEBACK_DEMO_DB.GOVERNANCE.COST_CENTER = 'SALES';
-- USE WAREHOUSE CB_SHARED_REPORTING_WH;
-- SELECT COUNT(*) FROM TABLE(GENERATOR(ROWCOUNT => 100000000));

-- [step:chargeback]
-- ============================================================================
-- STEP 7: CHARGEBACK QUERIES
-- ============================================================================
-- These read built-in SNOWFLAKE.ACCOUNT_USAGE views; nothing else is needed.
-- Latency: TAG_REFERENCES up to 2 h, QUERY_ATTRIBUTION_HISTORY up to 8 h,
--          WAREHOUSE_METERING_HISTORY up to 3 h.
-- The date filters use the CURRENT month so the demo shows data today.
-- For monthly billing, switch to the previous full month:
--   start_time >= DATE_TRUNC('MONTH', DATEADD(MONTH, -1, CURRENT_DATE))
--   AND start_time < DATE_TRUNC('MONTH', CURRENT_DATE)

-- 7a. DEDICATED WAREHOUSE COSTS BY BUSINESS UNIT
--     Warehouse-level tags attribute every credit to one cost center
SELECT
    tr.tag_value                                        AS business_unit,
    wmh.warehouse_name,
    SUM(wmh.credits_used_compute)                       AS compute_credits,
    SUM(wmh.credits_used_cloud_services)                AS cloud_services_credits,
    SUM(wmh.credits_used_compute
        + wmh.credits_used_cloud_services)              AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY  wmh
JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES              tr
    ON wmh.warehouse_id = tr.object_id
    AND tr.domain       = 'WAREHOUSE'
    AND tr.tag_database = 'CHARGEBACK_DEMO_DB'
    AND tr.tag_schema   = 'GOVERNANCE'
    AND tr.tag_name     = 'COST_CENTER'
WHERE wmh.start_time >= DATE_TRUNC('MONTH', CURRENT_DATE)
  AND tr.tag_value   != 'SHARED'                        -- shared handled in 7b
GROUP BY tr.tag_value, wmh.warehouse_name
ORDER BY total_credits DESC;

-- 7b. SHARED WAREHOUSE COSTS SPLIT BY BUSINESS UNIT
--     QUERY_ATTRIBUTION_HISTORY assigns credits to each query; user tags
--     then map each query to the cost center that ran it
SELECT
    COALESCE(user_tr.tag_value, 'UNTAGGED')             AS business_unit,
    qah.warehouse_name,
    COUNT(*)                                            AS query_count,
    SUM(qah.credits_attributed_compute)                 AS attributed_credits,
    ROUND(
        SUM(qah.credits_attributed_compute)
        / NULLIF(SUM(SUM(qah.credits_attributed_compute)) OVER (PARTITION BY qah.warehouse_name), 0)
        * 100, 2
    )                                                   AS pct_of_warehouse_cost
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY   qah
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES         user_tr
    ON qah.user_name        = user_tr.object_name
    AND user_tr.domain       = 'USER'
    AND user_tr.tag_database = 'CHARGEBACK_DEMO_DB'
    AND user_tr.tag_schema   = 'GOVERNANCE'
    AND user_tr.tag_name     = 'COST_CENTER'
JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES              wh_tr
    ON qah.warehouse_id    = wh_tr.object_id
    AND wh_tr.domain       = 'WAREHOUSE'
    AND wh_tr.tag_database = 'CHARGEBACK_DEMO_DB'
    AND wh_tr.tag_schema   = 'GOVERNANCE'
    AND wh_tr.tag_name     = 'COST_CENTER'
    AND wh_tr.tag_value    = 'SHARED'
WHERE qah.start_time >= DATE_TRUNC('MONTH', CURRENT_DATE)
GROUP BY COALESCE(user_tr.tag_value, 'UNTAGGED'), qah.warehouse_name
ORDER BY attributed_credits DESC;

-- 7c. STORAGE BY BUSINESS UNIT (database-level tags)
SELECT
    COALESCE(tr.tag_value, 'UNTAGGED')                  AS business_unit,
    tsm.table_catalog                                   AS database_name,
    ROUND(SUM(tsm.active_bytes)      / POWER(1024, 4), 4) AS active_tb,
    ROUND(SUM(tsm.time_travel_bytes) / POWER(1024, 4), 4) AS time_travel_tb,
    ROUND(SUM(tsm.failsafe_bytes)    / POWER(1024, 4), 4) AS failsafe_tb,
    ROUND(SUM(tsm.active_bytes + tsm.time_travel_bytes
              + tsm.failsafe_bytes)  / POWER(1024, 4), 4) AS total_tb
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS       tsm
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES         tr
    ON tsm.table_catalog = tr.object_name
    AND tr.domain        = 'DATABASE'
    AND tr.tag_database  = 'CHARGEBACK_DEMO_DB'
    AND tr.tag_schema    = 'GOVERNANCE'
    AND tr.tag_name      = 'COST_CENTER'
WHERE tsm.active_bytes > 0
GROUP BY COALESCE(tr.tag_value, 'UNTAGGED'), tsm.table_catalog
ORDER BY total_tb DESC;

-- 7d. SERVERLESS COSTS BY SERVICE TYPE
--     METERING_DAILY_HISTORY has no object identifiers, so serverless spend
--     is usually split by each BU's share of compute (7e) or treated as
--     platform overhead. Tag-based budgets (Step 5) do track it per BU.
SELECT
    service_type,
    SUM(credits_used)                                   AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE usage_date >= DATE_TRUNC('MONTH', CURRENT_DATE)
  AND service_type != 'WAREHOUSE_METERING'              -- already in 7a
GROUP BY service_type
ORDER BY total_credits DESC;

-- 7e. MONTHLY CHARGEBACK SUMMARY
--     Dedicated credits + attributed share of shared warehouses, per BU
WITH dedicated_costs AS (
    SELECT
        tr.tag_value                                    AS business_unit,
        SUM(wmh.credits_used_compute
            + wmh.credits_used_cloud_services)          AS dedicated_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY  wmh
    JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES              tr
        ON wmh.warehouse_id = tr.object_id
        AND tr.domain       = 'WAREHOUSE'
        AND tr.tag_database = 'CHARGEBACK_DEMO_DB'
        AND tr.tag_schema   = 'GOVERNANCE'
        AND tr.tag_name     = 'COST_CENTER'
    WHERE wmh.start_time >= DATE_TRUNC('MONTH', CURRENT_DATE)
      AND tr.tag_value NOT IN ('SHARED', 'PLATFORM_TEAM')
    GROUP BY tr.tag_value
),
shared_costs AS (
    SELECT
        COALESCE(user_tr.tag_value, 'UNTAGGED')         AS business_unit,
        SUM(qah.credits_attributed_compute)             AS shared_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY  qah
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES        user_tr
        ON qah.user_name        = user_tr.object_name
        AND user_tr.domain       = 'USER'
        AND user_tr.tag_database = 'CHARGEBACK_DEMO_DB'
        AND user_tr.tag_schema   = 'GOVERNANCE'
        AND user_tr.tag_name     = 'COST_CENTER'
    JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES             wh_tr
        ON qah.warehouse_id    = wh_tr.object_id
        AND wh_tr.domain       = 'WAREHOUSE'
        AND wh_tr.tag_database = 'CHARGEBACK_DEMO_DB'
        AND wh_tr.tag_schema   = 'GOVERNANCE'
        AND wh_tr.tag_name     = 'COST_CENTER'
        AND wh_tr.tag_value    = 'SHARED'
    WHERE qah.start_time >= DATE_TRUNC('MONTH', CURRENT_DATE)
    GROUP BY COALESCE(user_tr.tag_value, 'UNTAGGED')
)
SELECT
    COALESCE(d.business_unit, s.business_unit)          AS business_unit,
    COALESCE(d.dedicated_credits, 0)                    AS dedicated_credits,
    COALESCE(s.shared_credits, 0)                       AS shared_credits,
    COALESCE(d.dedicated_credits, 0)
        + COALESCE(s.shared_credits, 0)                 AS total_credits,
    ROUND(
        (COALESCE(d.dedicated_credits, 0) + COALESCE(s.shared_credits, 0))
        / NULLIF(SUM(COALESCE(d.dedicated_credits, 0) + COALESCE(s.shared_credits, 0)) OVER (), 0)
        * 100, 2
    )                                                   AS pct_of_total
FROM dedicated_costs d
FULL OUTER JOIN shared_costs s
    ON d.business_unit = s.business_unit
WHERE COALESCE(d.business_unit, s.business_unit) NOT IN ('UNTAGGED', 'PLATFORM_TEAM')
ORDER BY total_credits DESC;

-- [step:abuse]
-- ============================================================================
-- STEP 8: ABUSE DETECTION AND ACCOUNTABILITY
-- ============================================================================
-- Find over-consumption, runaway queries and wasted (idle) compute.

-- 8a. TOP 50 MOST EXPENSIVE QUERIES, WITH OWNING BUSINESS UNIT
SELECT
    COALESCE(user_tr.tag_value, 'UNTAGGED')             AS business_unit,
    qah.user_name,
    qah.query_id,
    qah.warehouse_name,
    qah.credits_attributed_compute,
    qah.start_time,
    DATEDIFF('second', qah.start_time, qah.end_time)    AS duration_seconds
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY   qah
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES         user_tr
    ON qah.user_name        = user_tr.object_name
    AND user_tr.domain       = 'USER'
    AND user_tr.tag_database = 'CHARGEBACK_DEMO_DB'
    AND user_tr.tag_schema   = 'GOVERNANCE'
    AND user_tr.tag_name     = 'COST_CENTER'
WHERE qah.start_time >= DATE_TRUNC('MONTH', CURRENT_DATE)
ORDER BY qah.credits_attributed_compute DESC
LIMIT 50;

-- 8b. USERS ABOVE A MONTHLY CREDIT THRESHOLD (adjust 100 to your policy)
SELECT
    COALESCE(user_tr.tag_value, 'UNTAGGED')             AS business_unit,
    qah.user_name,
    COUNT(*)                                            AS query_count,
    SUM(qah.credits_attributed_compute)                 AS total_credits,
    ROUND(AVG(qah.credits_attributed_compute), 6)       AS avg_credits_per_query
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY   qah
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES         user_tr
    ON qah.user_name        = user_tr.object_name
    AND user_tr.domain       = 'USER'
    AND user_tr.tag_database = 'CHARGEBACK_DEMO_DB'
    AND user_tr.tag_schema   = 'GOVERNANCE'
    AND user_tr.tag_name     = 'COST_CENTER'
WHERE qah.start_time >= DATE_TRUNC('MONTH', CURRENT_DATE)
GROUP BY COALESCE(user_tr.tag_value, 'UNTAGGED'), qah.user_name
HAVING SUM(qah.credits_attributed_compute) > 100
ORDER BY total_credits DESC;

-- 8c. WAREHOUSES BURNING CREDITS WITH FEW OR NO QUERIES (idle waste)
WITH metering AS (
    SELECT warehouse_name, warehouse_id,
           SUM(credits_used_compute)                    AS total_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
    WHERE start_time >= DATE_TRUNC('MONTH', CURRENT_DATE)
    GROUP BY warehouse_name, warehouse_id
),
query_counts AS (
    SELECT warehouse_name, COUNT(*)                     AS total_queries
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE start_time >= DATE_TRUNC('MONTH', CURRENT_DATE)
    GROUP BY warehouse_name
)
SELECT
    COALESCE(tr.tag_value, 'UNTAGGED')                  AS business_unit,
    m.warehouse_name,
    m.total_credits,
    COALESCE(qc.total_queries, 0)                       AS total_queries,
    CASE
        WHEN COALESCE(qc.total_queries, 0) = 0 THEN 'NO QUERIES - 100% IDLE'
        ELSE ROUND(m.total_credits / qc.total_queries, 4)::VARCHAR
    END                                                 AS credits_per_query
FROM metering m
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES         tr
    ON m.warehouse_id   = tr.object_id
    AND tr.domain       = 'WAREHOUSE'
    AND tr.tag_database = 'CHARGEBACK_DEMO_DB'
    AND tr.tag_schema   = 'GOVERNANCE'
    AND tr.tag_name     = 'COST_CENTER'
LEFT JOIN query_counts qc
    ON m.warehouse_name = qc.warehouse_name
ORDER BY m.total_credits DESC;

-- 8d. BUSINESS UNITS APPROACHING OR OVER THEIR BUDGET (current month)
--     Allocations match the spending limits set in Step 5
WITH bu_allocations AS (
    SELECT 'SALES'       AS business_unit, 600 AS monthly_budget UNION ALL
    SELECT 'MARKETING',                    500                   UNION ALL
    SELECT 'FINANCE',                      500                   UNION ALL
    SELECT 'ENGINEERING',                  400
),
bu_actual AS (
    SELECT
        tr.tag_value                                    AS business_unit,
        SUM(wmh.credits_used_compute
            + wmh.credits_used_cloud_services)          AS actual_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY  wmh
    JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES              tr
        ON wmh.warehouse_id = tr.object_id
        AND tr.domain       = 'WAREHOUSE'
        AND tr.tag_database = 'CHARGEBACK_DEMO_DB'
        AND tr.tag_schema   = 'GOVERNANCE'
        AND tr.tag_name     = 'COST_CENTER'
    WHERE wmh.start_time >= DATE_TRUNC('MONTH', CURRENT_DATE)
      AND tr.tag_value NOT IN ('SHARED', 'PLATFORM_TEAM')
    GROUP BY tr.tag_value
)
SELECT
    a.business_unit,
    a.monthly_budget,
    ROUND(COALESCE(act.actual_credits, 0), 2)           AS credits_used,
    ROUND(a.monthly_budget - COALESCE(act.actual_credits, 0), 2) AS credits_remaining,
    ROUND(COALESCE(act.actual_credits, 0) / a.monthly_budget * 100, 1) AS pct_used,
    CASE
        WHEN COALESCE(act.actual_credits, 0) / a.monthly_budget >= 1.0  THEN 'EXCEEDED'
        WHEN COALESCE(act.actual_credits, 0) / a.monthly_budget >= 0.9  THEN 'CRITICAL'
        WHEN COALESCE(act.actual_credits, 0) / a.monthly_budget >= 0.75 THEN 'WARNING'
        ELSE 'OK'
    END                                                 AS status
FROM bu_allocations a
LEFT JOIN bu_actual act ON a.business_unit = act.business_unit
ORDER BY pct_used DESC;

-- 8e. WEEK-OVER-WEEK SPEND TREND (spot sudden spikes; last 3 months)
SELECT
    DATE_TRUNC('WEEK', wmh.start_time)                  AS week_start,
    tr.tag_value                                        AS business_unit,
    SUM(wmh.credits_used_compute)                       AS weekly_credits,
    LAG(SUM(wmh.credits_used_compute)) OVER (
        PARTITION BY tr.tag_value ORDER BY DATE_TRUNC('WEEK', wmh.start_time)
    )                                                   AS prev_week_credits,
    ROUND(
        (SUM(wmh.credits_used_compute)
         - LAG(SUM(wmh.credits_used_compute)) OVER (
               PARTITION BY tr.tag_value ORDER BY DATE_TRUNC('WEEK', wmh.start_time)))
        / NULLIF(LAG(SUM(wmh.credits_used_compute)) OVER (
               PARTITION BY tr.tag_value ORDER BY DATE_TRUNC('WEEK', wmh.start_time)), 0)
        * 100, 1
    )                                                   AS pct_change
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY  wmh
JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES              tr
    ON wmh.warehouse_id = tr.object_id
    AND tr.domain       = 'WAREHOUSE'
    AND tr.tag_database = 'CHARGEBACK_DEMO_DB'
    AND tr.tag_schema   = 'GOVERNANCE'
    AND tr.tag_name     = 'COST_CENTER'
WHERE wmh.start_time >= DATEADD(MONTH, -3, CURRENT_DATE)
  AND tr.tag_value NOT IN ('SHARED', 'PLATFORM_TEAM')
GROUP BY DATE_TRUNC('WEEK', wmh.start_time), tr.tag_value
ORDER BY tr.tag_value, week_start;

-- [step:multiaccount]
-- ============================================================================
-- STEP 9: (OPTIONAL) GOING MULTI-ACCOUNT
-- ============================================================================
-- If each business unit has its own Snowflake account, create the tags once
-- and replicate them, then roll up costs from the organization account.
-- Replace <YOUR_ORG> and the <..._ACCOUNT> names with your identifiers.

-- 9a. In the account that owns the tags: replicate the governance database
-- CREATE REPLICATION GROUP IF NOT EXISTS CB_TAG_REPL_GROUP
--     OBJECT_TYPES = DATABASES
--     ALLOWED_DATABASES = CHARGEBACK_DEMO_DB
--     ALLOWED_ACCOUNTS = <YOUR_ORG>.<SALES_ACCOUNT>,
--                        <YOUR_ORG>.<MARKETING_ACCOUNT>,
--                        <YOUR_ORG>.<FINANCE_ACCOUNT>,
--                        <YOUR_ORG>.<ENGINEERING_ACCOUNT>
--     REPLICATION_SCHEDULE = '10 MINUTE';

-- 9b. In each business-unit account: create and refresh the replica
-- CREATE REPLICATION GROUP CB_TAG_REPL_GROUP
--     AS REPLICA OF <YOUR_ORG>.<TAG_OWNER_ACCOUNT>.CB_TAG_REPL_GROUP;
-- ALTER REPLICATION GROUP CB_TAG_REPL_GROUP REFRESH;

-- 9c. From the organization account: org-wide costs by business unit
-- SELECT
--     wmh.account_name,
--     COALESCE(tr.tag_value, 'UNTAGGED')              AS business_unit,
--     wmh.warehouse_name,
--     SUM(wmh.credits_used_compute
--         + wmh.credits_used_cloud_services)          AS total_credits
-- FROM SNOWFLAKE.ORGANIZATION_USAGE.WAREHOUSE_METERING_HISTORY  wmh
-- LEFT JOIN SNOWFLAKE.ORGANIZATION_USAGE.TAG_REFERENCES         tr
--     ON wmh.warehouse_id  = tr.object_id
--     AND tr.account_name  = wmh.account_name
--     AND tr.domain        = 'WAREHOUSE'
--     AND tr.tag_database  = 'CHARGEBACK_DEMO_DB'
--     AND tr.tag_schema    = 'GOVERNANCE'
--     AND tr.tag_name      = 'COST_CENTER'
-- WHERE wmh.start_time >= DATE_TRUNC('MONTH', CURRENT_DATE)
-- GROUP BY wmh.account_name, COALESCE(tr.tag_value, 'UNTAGGED'), wmh.warehouse_name
-- ORDER BY total_credits DESC;

-- [step:cleanup]
-- ============================================================================
-- STEP 10: CLEANUP (Optional - uncomment to remove all demo objects)
-- ============================================================================
-- Order matters: drop tagged objects before the database that holds the tags.

-- USE ROLE ACCOUNTADMIN;
-- -- If you tagged your own user in Step 6:
-- -- SET my_user = CURRENT_USER();
-- -- ALTER USER IDENTIFIER($my_user) UNSET TAG CHARGEBACK_DEMO_DB.GOVERNANCE.COST_CENTER;
-- DROP WAREHOUSE IF EXISTS CB_SALES_WH_PROD;
-- DROP WAREHOUSE IF EXISTS CB_SALES_WH_DEV;
-- DROP WAREHOUSE IF EXISTS CB_MARKETING_WH_PROD;
-- DROP WAREHOUSE IF EXISTS CB_MARKETING_WH_DEV;
-- DROP WAREHOUSE IF EXISTS CB_FINANCE_WH_PROD;
-- DROP WAREHOUSE IF EXISTS CB_FINANCE_WH_DEV;
-- DROP WAREHOUSE IF EXISTS CB_ENGINEERING_WH_PROD;
-- DROP WAREHOUSE IF EXISTS CB_ENGINEERING_WH_DEV;
-- DROP WAREHOUSE IF EXISTS CB_SHARED_REPORTING_WH;
-- DROP WAREHOUSE IF EXISTS CB_SHARED_ETL_WH;
-- DROP RESOURCE MONITOR IF EXISTS CB_SALES_MONITOR;
-- DROP RESOURCE MONITOR IF EXISTS CB_MARKETING_MONITOR;
-- DROP RESOURCE MONITOR IF EXISTS CB_FINANCE_MONITOR;
-- DROP RESOURCE MONITOR IF EXISTS CB_ENGINEERING_MONITOR;
-- DROP RESOURCE MONITOR IF EXISTS CB_SHARED_MONITOR;
-- DROP USER IF EXISTS CB_SALES_ANALYST;
-- DROP USER IF EXISTS CB_MARKETING_ANALYST;
-- DROP USER IF EXISTS CB_FINANCE_ANALYST;
-- DROP USER IF EXISTS CB_ENGINEERING_DEV;
-- DROP USER IF EXISTS CB_PLATFORM_ADMIN;
-- DROP DATABASE IF EXISTS CB_SALES_DB;
-- DROP DATABASE IF EXISTS CB_MARKETING_DB;
-- DROP DATABASE IF EXISTS CB_FINANCE_DB;
-- DROP DATABASE IF EXISTS CB_ENGINEERING_DB;
-- DROP DATABASE IF EXISTS CB_SHARED_REFERENCE_DB;
-- DROP DATABASE IF EXISTS CHARGEBACK_DEMO_DB;   -- tags and budgets
-- DROP ROLE IF EXISTS CB_BUDGET_ADMIN;
