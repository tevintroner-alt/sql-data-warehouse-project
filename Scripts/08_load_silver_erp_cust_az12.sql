-- =================================================================================
-- PROJECT: Medallion Architecture Data Warehouse (MySQL Implementation)
-- SECTION: SILVER LAYER - TRANSFORM & LOAD (ERP CUSTOMER DATA)
-- DESCRIPTION: Cleans customer IDs by stripping unwanted 'NAS' prefixes, validates 
--              birth dates against future dates, and standardizes gender codes.
-- =================================================================================

USE DataWarehouse;

-- 1. Initialize or reset the Silver ERP Customer table DDL
DROP TABLE IF EXISTS silver_erp_cust_az12;
CREATE TABLE silver_erp_cust_az12 (
    cid            VARCHAR(50),
    bdate          DATE,
    gen            VARCHAR(50),
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Clear existing data before reloading
TRUNCATE TABLE silver_erp_cust_az12;

-- 3. Insert transformed and validated data into Silver
INSERT INTO silver_erp_cust_az12 (
    cid,
    bdate,
    gen
)
SELECT
    -- Data Quality Rule: If customer ID starts with 'NAS', remove it (keeping characters from position 4 onwards)
    CASE 
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4)
        ELSE cid
    END AS cid,
    
    -- Data Quality Rule: If birth date is in the future, set to NULL; otherwise cast to DATE
    CASE 
        WHEN bdate > CURDATE() THEN NULL
        ELSE CAST(bdate AS DATE)
    END AS bdate,
    
    -- Data Quality Rule: Standardize gender variants ('F', 'FEMALE') and ('M', 'MALE') into uniform terms
    CASE 
        WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
        ELSE 'n/a'
    END AS gen

FROM bronze_erp_cust_az12;
