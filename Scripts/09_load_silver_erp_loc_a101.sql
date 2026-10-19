-- =================================================================================
-- PROJECT: Medallion Architecture Data Warehouse (MySQL Implementation)
-- SECTION: SILVER LAYER - TRANSFORM & LOAD (ERP LOCATION DATA)
-- DESCRIPTION: Recreates the Silver location table, strips hidden control characters 
--              (carriage returns, newlines, tabs) and whitespace from raw Bronze data, 
--              standardizes country codes into readable names, and verifies results.
-- =================================================================================

USE DataWarehouse;

-- =========================================================
-- 1. INITIALIZE TABLE DDL
-- =========================================================
DROP TABLE IF EXISTS silver_erp_loc_a101;

CREATE TABLE silver_erp_loc_a101 (
    cid            VARCHAR(50),
    cntry          VARCHAR(50),
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 2. TRANSFORM & LOAD BRONZE TO SILVER
-- =========================================================
INSERT INTO silver_erp_loc_a101 (
    cid, 
    cntry
)
SELECT
    -- Clean customer ID: Remove hyphens and trim surrounding whitespace/control characters
    REPLACE(REGEXP_REPLACE(cid, '[[:cntrl:]]', ''), '-', '') AS cid,

    -- Standardize country names while cleaning hidden control characters and spaces
    CASE 
        WHEN UPPER(TRIM(REGEXP_REPLACE(cntry, '[[:cntrl:]]', ''))) = 'DE' 
            THEN 'Germany'
            
        WHEN UPPER(TRIM(REGEXP_REPLACE(cntry, '[[:cntrl:]]', ''))) IN ('US', 'USA') 
            THEN 'United States'
            
        WHEN TRIM(REGEXP_REPLACE(cntry, '[[:cntrl:]]', '')) = '' 
             OR cntry IS NULL 
            THEN 'n/a'
            
        ELSE TRIM(REGEXP_REPLACE(cntry, '[[:cntrl:]]', ''))
    END AS cntry

FROM bronze_erp_loc_a101;

-- =========================================================
-- 3. DATA QUALITY VERIFICATION
-- =========================================================
-- Check row distribution per country to ensure cleaning worked properly
SELECT 
    cntry, 
    COUNT(*) AS total_rows
FROM silver_erp_loc_a101
GROUP BY cntry
ORDER BY cntry;
