-- =================================================================================
-- PROJECT: Medallion Architecture Data Warehouse (MySQL Implementation)
-- SECTION: SILVER LAYER - TRANSFORM & LOAD (CRM PRODUCT INFO)
-- DESCRIPTION: Cleans, standardizes product lines, derives category IDs, handles 
--              missing costs, and calculates historical product end dates.
-- =================================================================================

USE DataWarehouse;

-- 1. Initialize or reset the Silver Product table DDL
DROP TABLE IF EXISTS silver_crm_prd_info;
CREATE TABLE silver_crm_prd_info (
    prd_id         INT,
    cat_id         VARCHAR(50),
    prd_key        VARCHAR(50),
    prd_nm         VARCHAR(50),
    prd_cost       INT,
    prd_line       VARCHAR(50),
    prd_start_dt   DATE,
    prd_end_dt     DATE,
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Clear existing data before reloading
TRUNCATE TABLE silver_crm_prd_info;

-- 3. Insert transformed data into Silver
INSERT INTO silver_crm_prd_info (
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt
)
SELECT
    prd_id,
    -- Extract category ID from the first 5 characters and replace hyphens with underscores
    REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
    -- Extract the core product key starting from character 7 onwards
    SUBSTRING(prd_key, 7) AS prd_key,
    -- Map bronze column 'prd_name' to silver column 'prd_nm'
    prd_name AS prd_nm,
    -- Default missing product costs to 0
    IFNULL(prd_cost, 0) AS prd_cost,
    -- Standardize product line codes into readable business terms
    CASE UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other Sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a'
    END AS prd_line,
    CAST(prd_start_dt AS DATE) AS prd_start_dt,
    -- Derive historical end date as 1 day before the next version's start date
    CAST(
        DATE_SUB(
            LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt),
            INTERVAL 1 DAY
        ) AS DATE
    ) AS prd_end_dt
FROM bronze_crm_prd_info;
