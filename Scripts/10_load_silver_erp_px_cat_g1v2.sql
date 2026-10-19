-- =================================================================================
-- PROJECT: Medallion Architecture Data Warehouse (MySQL Implementation)
-- SECTION: SILVER LAYER - TRANSFORM & LOAD (ERP PRODUCT CATEGORY DATA)
-- DESCRIPTION: Recreates the Silver product category table, trims any minor 
--              whitespace from text fields, and loads clean data from the Bronze layer.
-- =================================================================================

USE DataWarehouse;

-- =========================================================
-- 1. INITIALIZE TABLE DDL
-- =========================================================
DROP TABLE IF EXISTS silver_erp_px_cat_g1v2;

CREATE TABLE silver_erp_px_cat_g1v2 (
    id             VARCHAR(50),
    cat            VARCHAR(50),
    subcat         VARCHAR(50),
    maintenance    VARCHAR(50),
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 2. TRANSFORM & LOAD BRONZE TO SILVER
-- =========================================================
INSERT INTO silver_erp_px_cat_g1v2 (
    id,
    cat,
    subcat,
    maintenance
)
SELECT
    TRIM(id) AS id,
    TRIM(cat) AS cat,
    TRIM(subcat) AS subcat,
    TRIM(maintenance) AS maintenance
FROM bronze_erp_px_cat_g1v2;

-- =========================================================
-- 3. DATA QUALITY VERIFICATION
-- =========================================================
-- Verify row counts and inspect sample rows in the Silver table
SELECT COUNT(*) AS total_rows FROM silver_erp_px_cat_g1v2;

SELECT * FROM silver_erp_px_cat_g1v2 LIMIT 10;
