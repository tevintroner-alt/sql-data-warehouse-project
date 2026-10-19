-- =================================================================================
-- PROJECT: Medallion Architecture Data Warehouse (MySQL Implementation)
-- SECTION: SILVER LAYER - TRANSFORM & LOAD (ERP LOCATION DATA)
-- DESCRIPTION: Cleans customer IDs by removing hyphens and standardizes country 
--              codes into uniform, human-readable country names.
-- =================================================================================

USE DataWarehouse;

-- 1. Initialize or reset the Silver ERP Location table DDL
DROP TABLE IF EXISTS silver_erp_loc_a101;
CREATE TABLE silver_erp_loc_a101 (
    cid            VARCHAR(50),
    cntry          VARCHAR(50),
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Clear existing data before reloading
TRUNCATE TABLE silver_erp_loc_a101;

-- 3. Insert transformed and validated data into Silver
INSERT INTO silver_erp_loc_a101 (
    cid,
    cntry
)
SELECT
    -- Data Quality Rule: Remove hyphens from customer IDs to match formatting across systems
    REPLACE(cid, '-', '') AS cid,
    
    -- Data Quality Rule: Standardize country shorthand codes and handle blanks/nulls
    CASE 
        WHEN TRIM(cntry) = 'DE' THEN 'Germany'
        WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
        WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
        ELSE TRIM(cntry)
    END AS cntry

FROM bronze_erp_loc_a101;
